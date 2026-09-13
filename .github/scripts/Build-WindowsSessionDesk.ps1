[CmdletBinding()]
param([ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+-dev\.[0-9]+$')][string]$Version='0.2.0-dev.10')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$module=Join-Path $root '实用小工具/Codex会话交接评估/windows-local'
$releases=Join-Path $root '.planning/windows-first'
$destination=[IO.Path]::GetFullPath((Join-Path $releases ('Windows-SessionDesk-'+$Version)))
if(-not $destination.StartsWith($releases+[IO.Path]::DirectorySeparatorChar)){throw 'Release boundary mismatch'}
if((Test-Path -LiteralPath $destination) -or (Test-Path -LiteralPath ($destination+'.zip'))){throw 'Release already exists; no overwrite performed.'}
# Only services launched from this tool's source or release tree are eligible.
$stopped=0
foreach($process in @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'")){
    if($process.CommandLine -notmatch '(?i)-File\s+"([^"]+\\Start-SessionDesk\.ps1)"'){continue}
    $entry=[IO.Path]::GetFullPath($Matches[1])
    if($entry -ne (Join-Path $module 'Start-SessionDesk.ps1') -and -not $entry.StartsWith($releases+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){continue}
    $instance='main'
    if($process.CommandLine -match '(?i)-Instance\s+"?([a-zA-Z0-9-]{1,40})"?'){$instance=$Matches[1]}
    $connection=Join-Path ([IO.Path]::GetDirectoryName($entry)) ('.local/'+$instance+'/connection.json')
    try{
        $c=[IO.File]::ReadAllText($connection)|ConvertFrom-Json
        if($c.pid -ne $process.ProcessId -or $c.url -notmatch '^http://127\.0\.0\.1:([0-9]+)/#([a-f0-9]{64})$'){throw 'Service identity mismatch'}
        $uri='http://127.0.0.1:'+$Matches[1]+'/api/shutdown'
        $r=Invoke-RestMethod -Uri $uri -Headers @{'X-SessionDesk'=$Matches[2]} -Method Post -ContentType 'application/json' -Body '{}' -TimeoutSec 10
        if(-not $r.stopped){throw 'Shutdown not confirmed'}
        $running=Get-Process -Id $process.ProcessId -ErrorAction SilentlyContinue
        if($running -and -not $running.WaitForExit(10000)){throw 'Service still running'}
        $stopped++
    }catch{
        throw ('无法安全退出旧工作台。请在旧页面点击“退出工具”，看到退出提示后重试。不要结束所有 PowerShell 进程。 / Cannot safely stop the old desk. Click Exit tool in its page, then retry. '+$_.Exception.Message)
    }
}
[IO.Directory]::CreateDirectory((Join-Path $destination 'windows-local'))|Out-Null
$files=@('Start-SessionDesk.cmd','Start-SessionDesk.ps1','Invoke-IsolatedAnalyzer.ps1','Read-DeskMetadata.ps1','desk.html','README.md','README.en.md')
foreach($name in $files){Copy-Item -LiteralPath (Join-Path $module $name) -Destination (Join-Path $destination ('windows-local/'+$name))}
Copy-Item -LiteralPath (Join-Path $module '../check-codex-session.ps1') -Destination (Join-Path $destination 'check-codex-session.ps1')
$launcher=[IO.File]::ReadAllText((Join-Path $module 'Start-SessionDesk.cmd')).Replace('%~dp0Start-SessionDesk.ps1','%~dp0windows-local\Start-SessionDesk.ps1')
[IO.File]::WriteAllText((Join-Path $destination 'Start-SessionDesk.cmd'),$launcher,[Text.Encoding]::ASCII)
$help=@'
完整解压到较短路径，双击 Start-SessionDesk.cmd，不要单独打开 HTML。
本版本可以查询本机真实会话。只填任务 ID，保存后点击“查询/刷新”。
名称与项目取自 Codex 本地记录；Codex 保存改名后，页面约 3 秒核对一次。
源会话只读，报告仅保存在本地；报告可能含会话原文，不要直接公开。
仅关闭网页不会关闭后台服务。不再使用时点击“退出工具”；下次启动可恢复任务与已保存的查询结果，历史结果保留原查询时间。
保留旧清单：退出旧服务后，将旧 .local 复制到新包 windows-local/.local；不要覆盖已有新清单。
如提示文件占用，在旧网页点击“退出工具”。不要结束全部 PowerShell 进程。
启动失败时请提供错误文字，不发送真实日志。详细说明见 windows-local/README.md。

Extract to a short path and double-click Start-SessionDesk.cmd. Do not open HTML directly.
This version queries real local sessions. Enter a task ID, save, then click Query / Refresh.
Names and projects come from Codex local records, checked about every 3 seconds after Codex saves a rename.
Source sessions are read-only. Local reports may contain conversation text; do not publish them without review.
Closing the page does not stop the background service. Click Exit tool when finished; relaunching restores tasks and saved query results with their original query times.
To retain tasks, stop the old service and copy its .local folder to windows-local/.local in the new package. Do not overwrite an existing new list.
If files are locked, click Exit tool in the old page. Never stop all PowerShell processes.
Share startup error text, not real logs. See windows-local/README.en.md.
'@
[IO.File]::WriteAllText((Join-Path $destination 'START-HERE.txt'),$help,(New-Object Text.UTF8Encoding($true)))
Compress-Archive -LiteralPath $destination -DestinationPath ($destination+'.zip')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($destination+'.zip')
try{if($zip.Entries.Count -ne 10 -or @($zip.Entries|Where-Object {$_.FullName -match '\.local|connection\.json|tasks\.json'}).Count){throw 'Unexpected package contents'}}finally{$zip.Dispose()}
[pscustomobject]@{Version=$Version;StoppedServices=$stopped;Package=($destination+'.zip');SHA256=(Get-FileHash -LiteralPath ($destination+'.zip')).Hash;Files=10}
