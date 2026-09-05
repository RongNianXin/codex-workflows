[CmdletBinding()]
param([switch]$NoBrowser, [ValidatePattern('^[a-zA-Z0-9-]{1,40}$')][string]$Instance = 'main')
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
$bom = New-Object Text.UTF8Encoding($true)
$data = Join-Path $PSScriptRoot ('.local/' + $Instance)
[IO.Directory]::CreateDirectory($data) | Out-Null
$connectionPath = Join-Path $data 'connection.json'
$lock = $null
$listener = $null
$jobs = @{}
$lockOwned = $false
function Write-Atomic([string]$Path, [string]$Text) {
    $temp = $Path + '.pending'
    [IO.File]::WriteAllText($temp, $Text, $utf8)
    if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temp, $Path, $Path + '.bak') }
    else { [IO.File]::Move($temp, $Path) }
}
function Valid-Id([string]$Id) { return $Id -cmatch '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' }
function Save-Tasks {
    Write-Atomic $tasksPath (@{schema=1;tasks=@($script:taskList)} | ConvertTo-Json -Depth 5)
}
function Send-Body($Context, [int]$Status, [string]$Text, [string]$Type = 'application/json; charset=utf-8') {
    $response = $Context.Response
    $response.StatusCode = $Status
    $response.ContentType = $Type
    $response.Headers['Cache-Control'] = 'no-store'
    $response.Headers['X-Content-Type-Options'] = 'nosniff'
    $response.Headers['Referrer-Policy'] = 'no-referrer'
    $response.Headers['Content-Security-Policy'] = "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
    $bytes = $utf8.GetBytes($Text)
    $response.ContentLength64 = $bytes.Length
    try { $response.OutputStream.Write($bytes, 0, $bytes.Length) } finally { $response.Close() }
}
function Send-Json($Context, $Value, [int]$Status = 200) { Send-Body $Context $Status ($Value | ConvertTo-Json -Depth 8 -Compress) }
function Read-Body($Request) {
    if ($Request.ContentType -notmatch '^application/json' -or $Request.ContentLength64 -lt 0 -or $Request.ContentLength64 -gt 32768) { throw '请求格式或大小无效。' }
    $reader = New-Object IO.StreamReader($Request.InputStream, $utf8)
    try { return ($reader.ReadToEnd() | ConvertFrom-Json) } finally { $reader.Dispose() }
}
function Update-Job($Job) {
    if ($Job.state -eq 'running') {
        if (-not $Job.process.HasExited -and (([DateTime]::UtcNow - $Job.started).TotalSeconds -gt 120)) {
            $Job.process.Kill()
            $Job.process.WaitForExit()
            $Job.timedOut = $true
        }
        if ($Job.process.HasExited) {
            $Job.process.WaitForExit()
            $Job.output = $Job.stdout.GetAwaiter().GetResult()
            $errorText = $Job.stderr.GetAwaiter().GetResult()
            $Job.state = if ($Job.process.ExitCode -eq 0 -and -not $Job.timedOut) { 'done' } else { 'failed' }
            $Job.error = if ($Job.timedOut) { '查询超过 120 秒，已终止。' } else { $errorText.Trim() }
            $Job.finished = [DateTime]::UtcNow.ToString('o')
            $Job.process.Dispose()
        }
    }
    return @{id=$Job.id;run=$Job.run;state=$Job.state;output=$Job.output;error=$Job.error;finished=$Job.finished;reportAvailable=($Job.state -eq 'done')}
}
try {
    try { $lock = [IO.File]::Open((Join-Path $data 'server.lock'), 'OpenOrCreate', 'ReadWrite', 'None'); $lockOwned=$true }
    catch {
        # An existing instance owns this exact state directory. Never start a second writer.
        if (-not $NoBrowser -and [IO.File]::Exists($connectionPath)) {
            $existing = [IO.File]::ReadAllText($connectionPath) | ConvertFrom-Json
            if ($existing.url -match '^http://127\.0\.0\.1:[0-9]+/#([a-f0-9]{64})$') { Start-Process $existing.url | Out-Null }
        }
        Write-Output 'The local desk is already running.'
        exit 0
    }
    $tasksPath = Join-Path $data 'tasks.json'
    $script:taskList = @()
    if ([IO.File]::Exists($tasksPath)) {
        $saved = [IO.File]::ReadAllText($tasksPath) | ConvertFrom-Json
        if ($saved.schema -ne 1) { throw '任务清单版本无效。原文件已保留，请勿覆盖。' }
        $seen = @{}
        foreach ($task in @($saved.tasks)) {
            if (-not (Valid-Id $task.id) -or $seen.ContainsKey($task.id) -or [string]::IsNullOrWhiteSpace($task.name) -or $task.name.Length -gt 80) { throw '任务清单内容无效。原文件已保留。' }
            $seen[$task.id]=$true
            $script:taskList += @{id=[string]$task.id;name=[string]$task.name}
        }
    } else { Save-Tasks }

    $profile = Join-Path $data 'fixtures'
    $sessions = Join-Path $profile '.codex/sessions'
    $runtime = Join-Path $data 'runtime'
    $reports = Join-Path $data 'reports'
    foreach ($directory in @($sessions,$runtime,$reports)) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    # Generate only synthetic session data. The third sample ID deliberately has no log.
    $indexLines = @()
    foreach ($number in @(1,2)) {
        $id = '00000000-0000-0000-0000-' + $number.ToString('000000000000')
        $records = @(
            @{timestamp='2025-01-01T00:00:00Z';type='session_meta';payload=@{id=$id;synthetic_test=$true;originator='fixture';source='fixture';model_provider='fixture'}},
            @{timestamp='2025-01-01T00:00:01Z';type='turn_context';payload=@{turn_id='fictional-turn'}},
            @{timestamp='2025-01-01T00:00:02Z';type='event_msg';payload=@{type='user_message';turn_id='fictional-turn';message='这是隔离的虚构测试输入。'}},
            @{timestamp='2025-01-01T00:00:03Z';type='event_msg';payload=@{type='token_count';info=@{total_token_usage=@{input_tokens=(100*$number);output_tokens=30;total_tokens=(100*$number+30)}}}},
            @{timestamp='2025-01-01T00:00:04Z';type='event_msg';payload=@{type='task_complete';turn_id='fictional-turn'}}
        )
        $lines = @($records | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress })
        [IO.File]::WriteAllText((Join-Path $sessions ('fictional-' + $id + '.jsonl')), ($lines -join "`n")+"`n", $utf8)
        $indexLines += (@{id=$id;thread_name=('虚构会话 '+$number);updated_at='2025-01-01T00:01:00Z'} | ConvertTo-Json -Compress)
    }
    [IO.File]::WriteAllText((Join-Path $profile '.codex/session_index.jsonl'),($indexLines -join "`n")+"`n",$utf8)
    $sourcePath = Join-Path $PSScriptRoot '../check-codex-session.ps1'
    $source = [IO.File]::ReadAllText($sourcePath)
    if ([regex]::Matches($source,[regex]::Escape('$env:USERPROFILE')).Count -ne 4) { throw '分析器的隔离锚点已变化，停止启动。' }
    $literal = "'" + $profile.Replace("'","''") + "'"
    $isolated = $source.Replace('$env:USERPROFILE',$literal)
    if ($isolated.Replace($literal,'$env:USERPROFILE') -cne $source) { throw '隔离副本校验失败。' }
    [IO.File]::WriteAllText((Join-Path $runtime 'isolated-analyzer.ps1'),$isolated,$bom)
    [IO.File]::WriteAllText((Join-Path $runtime 'Invoke-IsolatedAnalyzer.ps1'),[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Invoke-IsolatedAnalyzer.ps1')),$bom)
    $powershell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $rng=[Security.Cryptography.RandomNumberGenerator]::Create();$random=New-Object byte[] 32;$rng.GetBytes($random);$rng.Dispose()
    $token=([BitConverter]::ToString($random)).Replace('-','').ToLowerInvariant()
    $probe=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,0);$probe.Start();$port=$probe.LocalEndpoint.Port;$probe.Stop()
    $base="http://127.0.0.1:$port"
    $listener=New-Object Net.HttpListener;$listener.Prefixes.Add($base+'/');$listener.Start()
    Write-Atomic $connectionPath (@{url=($base+'/#'+$token);port=$port;mode='isolated-synthetic';pid=$PID} | ConvertTo-Json)
    if (-not $NoBrowser) { Start-Process ($base+'/#'+$token) | Out-Null }
    $stopping=$false
    $waiting=$listener.BeginGetContext($null,$null)
    while (-not $stopping) {
        if (-not $waiting.AsyncWaitHandle.WaitOne(250)) {
            foreach ($job in @($jobs.Values)) { Update-Job $job | Out-Null }
            continue
        }
        $context=$listener.EndGetContext($waiting)
        $waiting=$listener.BeginGetContext($null,$null)
        $request=$context.Request
        try {
            if ($request.UserHostName -ne "127.0.0.1:$port" -or -not [Net.IPAddress]::IsLoopback($request.RemoteEndPoint.Address)) { Send-Json $context @{error='仅允许本机访问。'} 403;continue }
            $origin=$request.Headers['Origin']
            if ($origin -and $origin -ne $base) { Send-Json $context @{error='请求来源不匹配。'} 403;continue }
            $route=$request.Url.AbsolutePath
            if ($route -eq '/' -and $request.HttpMethod -eq 'GET') { Send-Body $context 200 ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'desk.html'))) 'text/html; charset=utf-8';continue }
            if ($request.Headers['X-SessionDesk'] -cne $token) { Send-Json $context @{error='连接凭证无效，请双击启动入口重新打开。'} 403;continue }
            if ($request.HttpMethod -eq 'GET' -and $route -eq '/api/tasks') { Send-Json $context @{tasks=@($script:taskList);mode='isolated-synthetic';version='0.2.0-dev.1'};continue }
            if ($request.HttpMethod -eq 'POST' -and $route -eq '/api/tasks') {
                $body=Read-Body $request;$id=([string]$body.id).Trim().ToLowerInvariant()
                if (-not (Valid-Id $id)) { throw '请输入标准格式的任务 ID。' }
                if ($body.action -eq 'save') {
                    $name=([string]$body.name).Trim()
                    if (-not $name -or $name.Length -gt 80 -or $name -match '[\x00-\x1f]') { throw '名称应为 1 至 80 个字符，且不含控制字符。' }
                    $newList=@($script:taskList | Where-Object { $_.id -ne $id }) + @(@{id=$id;name=$name})
                } elseif ($body.action -eq 'delete') {
                    if ($jobs.ContainsKey($id) -and (Update-Job $jobs[$id]).state -eq 'running') { throw '该任务正在查询，请稍后删除。' }
                    $newList=@($script:taskList | Where-Object { $_.id -ne $id })
                    if ($jobs.ContainsKey($id)) { $jobs.Remove($id) }
                } else { throw '不支持的清单操作。' }
                $old=$script:taskList;$script:taskList=$newList
                try { Save-Tasks } catch { $script:taskList=$old;throw }
                Send-Json $context @{tasks=@($script:taskList)};continue
            }
            if ($request.HttpMethod -eq 'POST' -and $route -eq '/api/query') {
                $body=Read-Body $request;$id=([string]$body.id).Trim().ToLowerInvariant()
                if (-not (Valid-Id $id) -or -not @($script:taskList | Where-Object { $_.id -eq $id }).Count) { throw '请先保存该任务。' }
                if ($id -notmatch '^00000000-0000-0000-0000-00000000000[1-3]$') { throw '本首版固定隔离验证模式：该 ID 没有虚构输入，不会读取真实会话。' }
                if ($jobs.ContainsKey($id) -and (Update-Job $jobs[$id]).state -eq 'running') { Send-Json $context (Update-Job $jobs[$id]);continue }
                $active=0;foreach ($job in @($jobs.Values)) { if ((Update-Job $job).state -eq 'running') { $active++ } }
                if ($active -ge 2) { Send-Json $context @{error='已有两个查询正在运行，请稍后重试。'} 409;continue }
                $report=Join-Path $reports ($id+'.md')
                $info=New-Object Diagnostics.ProcessStartInfo
                $info.FileName=$powershell
                $info.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+(Join-Path $runtime 'Invoke-IsolatedAnalyzer.ps1')+'" -TaskId "'+$id+'" -ReportPath "'+$report+'"'
                $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
                $info.StandardOutputEncoding=$utf8;$info.StandardErrorEncoding=$utf8
                $process=New-Object Diagnostics.Process;$process.StartInfo=$info;[void]$process.Start()
                $job=@{id=$id;run=[guid]::NewGuid().ToString();state='running';output='';error='';finished=$null;started=[DateTime]::UtcNow;process=$process;stdout=$process.StandardOutput.ReadToEndAsync();stderr=$process.StandardError.ReadToEndAsync();report=$report;timedOut=$false}
                $jobs[$id]=$job;Send-Json $context (Update-Job $job);continue
            }
            if ($request.HttpMethod -eq 'GET' -and $route -eq '/api/job') {
                $id=$request.QueryString['id'];if (-not (Valid-Id $id) -or -not $jobs.ContainsKey($id)) { Send-Json $context @{error='尚无本次运行的查询。'} 404;continue }
                Send-Json $context (Update-Job $jobs[$id]);continue
            }
            if ($request.HttpMethod -eq 'GET' -and $route -eq '/api/report') {
                $id=$request.QueryString['id'];if (-not (Valid-Id $id) -or -not $jobs.ContainsKey($id) -or (Update-Job $jobs[$id]).state -ne 'done') { Send-Json $context @{error='当前查询没有可用报告。'} 404;continue }
                Send-Json $context @{text=[IO.File]::ReadAllText($jobs[$id].report)};continue
            }
            if ($request.HttpMethod -eq 'POST' -and $route -eq '/api/shutdown') { Send-Json $context @{stopped=$true};$stopping=$true;continue }
            Send-Json $context @{error='接口不存在。'} 404
        } catch { try { Send-Json $context @{error=$_.Exception.Message} 400 } catch {} }
    }
} catch {
    [IO.File]::WriteAllText((Join-Path $data 'startup-error.txt'),$_.Exception.Message,$utf8)
    if (-not $NoBrowser) { Add-Type -AssemblyName System.Windows.Forms;[Windows.Forms.MessageBox]::Show($_.Exception.Message,'本地工作台启动失败') | Out-Null }
    throw
} finally {
    foreach ($job in @($jobs.Values)) { if ($job.state -eq 'running') { try { if (-not $job.process.HasExited) { $job.process.Kill();$job.process.WaitForExit() };$job.process.Dispose() } catch {} } }
    if ($listener) { $listener.Close() }
    if ($lockOwned -and [IO.File]::Exists($connectionPath)) { [IO.File]::Delete($connectionPath) }
    if ($lock) { $lock.Dispose() }
}
