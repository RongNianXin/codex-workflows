[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path

function Get-TrackedFiles {
    param([Parameter(Mandatory)][string]$Pattern)

    $files = @(git -c "safe.directory=$repoRoot" -c core.quotepath=false -C $repoRoot ls-files -- $Pattern)
    if ($LASTEXITCODE -ne 0) {
        throw "无法读取 Git 跟踪文件：$Pattern"
    }
    return $files
}

function Test-RepositoryPathPortability {
    $errors = [Collections.Generic.List[string]]::new()
    $trackedFiles = @(git -c "safe.directory=$repoRoot" -c core.quotepath=false -C $repoRoot ls-files)
    if ($LASTEXITCODE -ne 0) {
        throw '无法读取 Git 跟踪文件以核对路径可移植性。'
    }

    $textExtensions = [Collections.Generic.HashSet[string]]::new(
        [string[]]@('.md', '.txt', '.ps1', '.psm1', '.psd1', '.cs', '.cmd', '.bat', '.sh', '.mjs', '.cjs', '.js', '.ts', '.tsx', '.jsx', '.html', '.htm', '.yml', '.yaml', '.json', '.toml', '.xml', '.svg', '.css'),
        [StringComparer]::OrdinalIgnoreCase
    )

    foreach ($relativePath in $trackedFiles) {
        git -c "safe.directory=$repoRoot" -C $repoRoot check-ignore --no-index --quiet -- $relativePath 2>$null
        if ($LASTEXITCODE -eq 0) {
            $errors.Add("命中 .gitignore 的文件仍被 Git 跟踪：$relativePath")
        }

        $extension = [IO.Path]::GetExtension($relativePath)
        if (-not $textExtensions.Contains($extension)) { continue }

        $fullPath = Join-Path $repoRoot $relativePath
        $content = [IO.File]::ReadAllText($fullPath)
        if ($content -match '(?i)(?<![A-Za-z0-9])[A-Z]:[\\/](?!\.\.\.|<)') {
            $errors.Add("文本包含机器绑定的 Windows 绝对路径：$relativePath")
        }
        if ($content -match '(?i)(?<![A-Za-z0-9])/(?:Users|home)/(?!\.\.\.|<)') {
            $errors.Add("文本包含机器绑定的用户目录绝对路径：$relativePath")
        }
        if ($content -match '(?i)file:///(?:[A-Z]:|Users/|home/)') {
            $errors.Add("文本包含机器绑定的 file URI：$relativePath")
        }
    }

    if ($errors.Count -gt 0) {
        throw ($errors -join [Environment]::NewLine)
    }
    Write-Host "Tracked path portability ($($trackedFiles.Count) files): PASS"
}

function Test-MarkdownFiles {
    $errors = [Collections.Generic.List[string]]::new()
    foreach ($relativePath in (Get-TrackedFiles -Pattern '*.md')) {
        $fullPath = Join-Path $repoRoot $relativePath
        $content = Get-Content -LiteralPath $fullPath -Raw

        $fenceCount = ([regex]::Matches($content, '(?m)^```')).Count
        if (($fenceCount % 2) -ne 0) {
            $errors.Add("代码围栏未成对：$relativePath")
        }

        foreach ($match in [regex]::Matches($content, '\[[^\]]*\]\((?<target><[^>]+>|[^)\s]+)')) {
            $target = $match.Groups['target'].Value.Trim('<', '>')
            if ($target -match '^(https?://|mailto:|#)') { continue }

            $pathPart = [Uri]::UnescapeDataString(($target -split '#', 2)[0])
            if ([string]::IsNullOrWhiteSpace($pathPart)) { continue }
            if ([IO.Path]::IsPathRooted($pathPart)) {
                $errors.Add("Markdown 使用绝对本地链接：$relativePath -> $target")
                continue
            }

            try {
                $resolved = [IO.Path]::GetFullPath((Join-Path (Split-Path $fullPath -Parent) $pathPart))
            }
            catch {
                $errors.Add("Markdown 链接路径无效：$relativePath -> $target")
                continue
            }
            if (-not $resolved.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase) -or
                -not (Test-Path -LiteralPath $resolved)) {
                $errors.Add("Markdown 相对链接失效：$relativePath -> $target")
            }
        }
    }

    if ($errors.Count -gt 0) {
        throw ($errors -join [Environment]::NewLine)
    }
    Write-Host 'Markdown links and fences: PASS'
}

function Get-NormalizedTextSha256 {
    param([Parameter(Mandatory)][string]$Path)

    $content = Get-Content -LiteralPath $Path -Raw
    $normalized = $content.Replace("`r`n", "`n").Replace("`r", "`n")
    $bytes = [Text.Encoding]::UTF8.GetBytes($normalized)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-ReadmeSiblingPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$FileName
    )

    $directory = [IO.Path]::GetDirectoryName($Path)
    if ([string]::IsNullOrWhiteSpace($directory)) { return $FileName }
    return "$($directory.Replace('\', '/'))/$FileName"
}

function Test-BilingualReadmes {
    $errors = [Collections.Generic.List[string]]::new()
    $trackedFiles = @(git -c "safe.directory=$repoRoot" -c core.quotepath=false -C $repoRoot ls-files)
    if ($LASTEXITCODE -ne 0) {
        throw '无法读取 Git 跟踪文件以核对双语 README。'
    }

    $tracked = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($relativePath in $trackedFiles) { [void]$tracked.Add($relativePath) }

    $chineseReadmes = @($trackedFiles | Where-Object { [IO.Path]::GetFileName($_) -ceq 'README.md' })
    $englishReadmes = @($trackedFiles | Where-Object { [IO.Path]::GetFileName($_) -ceq 'README.en.md' })

    foreach ($relativePath in $chineseReadmes) {
        $englishPath = Get-ReadmeSiblingPath -Path $relativePath -FileName 'README.en.md'
        if (-not $tracked.Contains($englishPath)) {
            $errors.Add("缺少英文 README：$relativePath -> $englishPath")
            continue
        }

        $content = Get-Content -LiteralPath (Join-Path $repoRoot $relativePath) -Raw
        if ($content -notmatch '(?i)\[[^\]]+\]\((?:\./)?README\.en\.md(?:#[^)]+)?\)') {
            $errors.Add("中文 README 缺少英文切换链接：$relativePath")
        }
    }

    foreach ($relativePath in $englishReadmes) {
        $chinesePath = Get-ReadmeSiblingPath -Path $relativePath -FileName 'README.md'
        if (-not $tracked.Contains($chinesePath)) {
            $errors.Add("缺少中文 README：$relativePath -> $chinesePath")
            continue
        }

        $content = Get-Content -LiteralPath (Join-Path $repoRoot $relativePath) -Raw
        if ($content -notmatch '(?i)\[[^\]]+\]\((?:\./)?README\.md(?:#[^)]+)?\)') {
            $errors.Add("英文 README 缺少中文切换链接：$relativePath")
        }

        $hashMatch = [regex]::Match(
            $content,
            '(?im)^<!--\s*README-SOURCE-SHA256:\s*(?<hash>[0-9a-f]{64})\s*-->\s*$'
        )
        $expectedHash = Get-NormalizedTextSha256 -Path (Join-Path $repoRoot $chinesePath)
        if (-not $hashMatch.Success) {
            $errors.Add("英文 README 缺少中文源同步标记：$relativePath（应为 $expectedHash）")
        }
        elseif ($hashMatch.Groups['hash'].Value.ToLowerInvariant() -ne $expectedHash) {
            $errors.Add("英文 README 的中文源同步标记已过期：$relativePath（应为 $expectedHash）")
        }
    }

    if ($errors.Count -gt 0) {
        throw ($errors -join [Environment]::NewLine)
    }
    Write-Host "Bilingual README pairs, links and source hashes ($($chineseReadmes.Count)): PASS"
}

function Test-PowerShellFiles {
    $errors = [Collections.Generic.List[string]]::new()
    foreach ($relativePath in (Get-TrackedFiles -Pattern '*.ps1')) {
        $tokens = $null
        $parseErrors = $null
        [void][Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $repoRoot $relativePath),
            [ref]$tokens,
            [ref]$parseErrors
        )
        foreach ($parseError in @($parseErrors)) {
            $errors.Add("$relativePath：$($parseError.Message)")
        }
    }

    if ($errors.Count -gt 0) {
        throw ($errors -join [Environment]::NewLine)
    }
    Write-Host 'PowerShell syntax: PASS'
}

function Test-CommanderRuleVersion {
    $relativePaths = @(
        '总指挥工作流/第二代总指挥的工作模式/00-第二代工作流总览.md',
        '总指挥工作流/第二代总指挥的工作模式/02-总指挥核心规则.md',
        '总指挥工作流/第二代总指挥的工作模式/10-自动状态索引规范.md',
        '总指挥工作流/第二代总指挥的工作模式/总指挥轻量交接启动配置.md'
    )
    $versions = [Collections.Generic.List[string]]::new()

    foreach ($relativePath in $relativePaths) {
        $content = Get-Content -LiteralPath (Join-Path $repoRoot $relativePath) -Raw
        $match = [regex]::Match($content, '(?m)^版本：(?<version>\d{4}-\d{2}-\d{2}\.\d+)\s*$')
        if (-not $match.Success) {
            throw "规则入口缺少有效版本：$relativePath"
        }
        $versions.Add($match.Groups['version'].Value)
    }

    if (($versions | Sort-Object -Unique).Count -ne 1) {
        throw "第二代总指挥规则入口版本不一致：$($versions -join ', ')"
    }
    Write-Host "Commander rule version $($versions[0]): PASS"
}

function Test-CommanderDurableWorkflowContract {
    $contracts = @(
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/01-操作者操作手册.md'
            Required = @('场景 2E：把本轮成果运行起来，交给我检查', '【具体目标】', '低信息部署请求与运行身份交付门禁', '效果是否通过，由我实际查看后确认', '场景判断：场景编号', '场景 2F：跨窗口执行与独立审查协作', '两个不同 AI 窗口', '只要求当前窗口自己检查工作，也不自动创建 2F 配对', '专项执行者或独立审查者完成一阶段并把结果交给总指挥后', '已确认接收', '已发送待确认', '尚未送达', '直接发给专项窗口、仍属于当前阶段且不冲突的明确指令照常有效', '只给一个“现在立即做什么”', '换新聊天或归档前：先准备续接材料', '至少一种可续接材料', '准备归档，请先整理续接材料', '当前 AI 可能收不到这个操作', '紧凑文本执行图', '默认不生成矢量图', '单一整图', '静态 HTML 模板', '本步骤输出效果', '真实阶段结果尚未采集', '场景 6B：任务中断后恢复并继续', '不必使用场景 6B', '不得因为本提示词而改变身份', '恢复收益门禁', '直接重做 / 快速恢复 / 深度恢复 / 必须先核账', '不超过 150 字介绍一次', '不会创建定时任务或后台监控')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/02-总指挥核心规则.md'
            Required = @('为其他任务窗口准备提示词', '唯一模板选择规则', '参数自动核实与人工输入边界', '统一入口的场景与参数核验', '路由回执', '开始自然语言路由前', '当前任务未加载该修订', '自然语言路由别名', '两个不同 AI 窗口分别执行和独立审查', '普通的同窗口自检', '唯一当前行动与跨窗口冲突收敛', '候选建议永远不可直接执行', '当前阶段行动方（执行者或独立审查者）', '兼任收口方', '操作者直接发给专项窗口的有效指令', '已确认接收 / 已发送待确认 / 尚未送达', '消息到达较晚不代表更新', '某一维度相同不能推出完整测试对象相同', '换窗与归档前连续性触发', '不按固定关键词触发', '至少生成一段可直接发给新窗口的精简续接提示词', '使用者直接点击客户端侧栏归档不会形成模型可观察消息', '不能作为该动作的授权', '需要多个设备访问时', '低信息部署请求与运行身份交付门禁', '规范启动命令及自检输出', 'COMMIT-LEDGER', '保留级别：KEY_NODE', '并存实现决议矩阵', '紧凑文本执行图', '可翻页的本地静态 HTML', '先恢复原任务身份', '恢复提示词本身不得被解释为总指挥任命', '恢复收益门禁', '前台控制授权门禁', '不自动授权 Computer Use', '本地协作画像的一次询问与节点触发', '不再重复询问', '不创建定时任务、后台轮询或独立自动化', '克隆可移植性', '相对路径不是所有场景的强制格式', '下一步提示词和单项确认卡不得重置活跃请求清单', '不能关闭整轮任务', '强制状态回执与空输出兜底', '业务权限不足也返回 `BLOCKED`')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/03-专项任务卡模板.md'
            Required = @('中断恢复身份：保持本专项任务身份', '执行入口：沿用母任务场景', '恢复提示词不改变本任务身份', '不得执行总指挥接管', '待授权的单一可见浏览器', '待授权的 Computer Use', '给出出口前先回读 `02` 的活跃请求清单', '候选建议标明“候选、不可执行”', '候选不得包装成可直接复制执行的提示词', '候选已由收口方确认接收', '候选已发送待确认', '候选尚未送达', '操作者直接发给本专项窗口的明确指令', '现在只给一个最先动作', '换窗与归档前连续性门禁', '至少一种可续接材料')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/04-状态、目标变更与交接规范.md'
            Required = @('耐久 Commit 台账与关键节点', '规范启动命令及自检输出', 'COMMIT-LEDGER', '保留级别：ROUTINE / KEY_NODE', '通用任务中断恢复与无正式总指挥交接', '不是所有中断任务的必经步骤', '恢复任务”不等于“接管项目', '执行恢复收益门禁', '换窗与归档前连续性门禁', '精简续接提示词的最小字段', '已完成且不得重复', '结果未知', '无待续任务', '使用者未通过消息表达而直接点击客户端归档', '未更新/待复核', '首个主回复末尾介绍一次', 'RECEIVED / BLOCKED / COMPLETED / FAILED', '读取接口不可见与目标没有收到分别记录')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/10-自动状态索引规范.md'
            Required = @('COMMIT-LEDGER', '人工核验运行身份清单', '规范启动命令及自检输出', '并存实现决议矩阵', '节点覆盖状态', 'TASK-RESUME', 'CONTINUITY-PACK', '触发类型（总指挥交接 / 主线分支 / 归档）', '送达状态', '恢复提示词不能把普通或专项任务升级为总指挥', '恢复收益门禁', 'unasked / enabled / paused / disabled / unavailable', 'not-shown / shown / answered / ignored', 'profile_revision', '不发送画像正文', '不创建定时任务或后台轮询', '重新绑定到当前仓库根目录', '活跃请求清单中每项的来源', '单项卡完成后不得据此删除未覆盖项')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/07-总指挥交接记录模板.md'
            Required = @('KEY_NODE', '运行身份', '规范启动命令及自检输出', '并存实现决议', '当前分步展示产物', '节点维护结果', '新总指挥不会重新询问', '统一接管汇报模板', '固定四段标题与字段')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/总指挥轻量交接启动配置.md'
            Required = @('KEY_NODE', 'canonical_start_command', 'startup_check', 'commit_ledger', 'step_deck_pointer_and_hash', '场景 6B 是角色中立的任务中断恢复入口', '候选阶段不得询问是否启用', 'introduction: not-shown / shown / answered / ignored', '旧机器绝对路径', '## 7. 统一接管汇报模板', '1. 总指挥身份', '2. 交接结论', '3. 接续断点', '4. 下一步与边界', '当前任务 ID：', '当前范围交接条件：', '没有证据支持遗漏时写“无”', '不得承诺任意账号或窗口凭 ID 即可跨权限访问')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/docs/PR_SUBMISSION_AND_REVIEW_STANDARD.md'
            Required = @('并存实现决议与实际运行身份', '规范启动命令及自检输出', '代码已包含', '干净环境可复现')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/06-复盘与优化规则.md'
            Required = @('公开可复制提示词', '私聊中的临时示例', '专业表达与低操作负担', '不依赖未分发的私有指令', '减少人工步骤不减少安全、权限、测试或领域专业验收')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/05-模型选择与资源策略.md'
            Required = @('无头优先与前台控制升级', '不得以非阻断通知代替确认', '不延伸为现有浏览器会话控制或 Computer Use 授权')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/09-自动化授权与风险分级.md'
            Required = @('已有授权随委派传递', '一次确认，范围内执行', '不能单独证明授权成立', '原始要求的最小必要摘录及可访问来源', '任务名称和原文摘录本身不是身份或授权证明', '不重复执行有副作用的动作', '不得代理', '前台控制的独立授权门禁', '不得为方便观察而升级', '不自动授权控制已有个人浏览器会话')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/docs/AUTOMATED_TESTING_LESSONS.md'
            Required = @('单样本输入保真预检（默认无头）', '把可见工具当作默认测试器', '执行方式与前台授权')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/11-操作者协作画像规范.md'
            Required = @('两次操作者授权', '下一条独立消息', 'active_entry_limit', 'routing_alias_limit', '自然语言路由别名', 'profile_revision', '不得替代本轮授权', '独立应用能力未验证', 'unasked / enabled / paused / disabled / unavailable', '不再展示介绍', '不创建定时任务、后台轮询或独立自动化', '删除公开的 `11-操作者协作画像规范.md` 不是关闭方式')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/docs/EXECUTION_AND_INDEPENDENT_REVIEW.md'
            Required = @('跨窗口执行与独立审查协作规范', '逻辑角色，不覆盖窗口原身份', '审查者必须位于执行者之外的另一个 AI 窗口', '最少只需两个窗口', '唯一中央调度者和单写者', '只创建一个独立审查任务', '普通同窗口自检不触发 2F', '仅讨论或模拟场景不创建任务', '唯一当前行动与冲突收敛', '`advice_kind`', '`action_status`', '`affected_resource/conflict_domain`', '当前阶段行动方（执行者或独立审查者）', '兼任阶段行动方与收口方', '候选已由收口方确认接收', '候选已发送待确认', '候选尚未送达', '不削弱操作者直接指令本身', '“谁最后发消息听谁的”无效', '已发送待确认')
        },
        @{
            Path = 'README.md'
            Required = @('可选的本地操作者协作画像', '它默认关闭', '关闭并删除本地操作者协作画像', '第二次精确确认')
        },
        @{
            Path = 'README.en.md'
            Required = @('Optional local operator collaboration profile', 'It is off by default', 'Disable and delete local data', 'second precise approval')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/docs/PIPELINE_DIAGNOSIS_AND_ALGORITHM_TUNING_STANDARD.md'
            Required = @('分层展示与 HTML 步骤演示', 'PIPELINE_STEP_DECK_TEMPLATE.html', '唯一拓扑表', '默认不生成矢量图', '单一整图', '历史最大页高', '本步骤输出效果', '本步骤没有可展示的直观视觉样例', '真实阶段结果尚未采集', '示意，不是运行证据', '[node-description]', 'comparisonIdentity', 'executionIdentity', 'artifactIdentity', 'comparisonKey', '真实执行顺序', '诊断对照')
        }
    )

    foreach ($contract in $contracts) {
        $fullPath = Join-Path $repoRoot $contract.Path
        $content = Get-Content -LiteralPath $fullPath -Raw
        foreach ($requiredText in $contract.Required) {
            if (-not $content.Contains($requiredText)) {
                throw "第二代总指挥耐久契约缺失：$($contract.Path) -> $requiredText"
            }
        }
    }
    Write-Host 'Commander durable workflow contract: PASS'
}

function Test-CommanderScene2FRoutingCases {
    $cases = @(
        @{ Name = 'current window executes, create one reviewer'; Request = 'execute'; DistinctWindow = $true; IndependentReview = $true; CurrentCanExecute = $true; PairReady = $false; CreateAuthorized = $true; Expected = '2F:create-one-reviewer' },
        @{ Name = 'two commanders reuse existing pair'; Request = 'execute'; DistinctWindow = $true; IndependentReview = $true; CurrentCanExecute = $true; PairReady = $true; CreateAuthorized = $false; Expected = '2F:reuse-pair' },
        @{ Name = 'commander coordinates two existing tasks'; Request = 'execute'; DistinctWindow = $true; IndependentReview = $true; CurrentCanExecute = $false; PairReady = $true; CreateAuthorized = $false; Expected = '2F:reuse-pair' },
        @{ Name = 'same-window self-check'; Request = 'execute'; DistinctWindow = $false; IndependentReview = $false; CurrentCanExecute = $true; PairReady = $false; CreateAuthorized = $false; Expected = 'not-2F' },
        @{ Name = 'explain scene only'; Request = 'explain'; DistinctWindow = $true; IndependentReview = $true; CurrentCanExecute = $true; PairReady = $false; CreateAuthorized = $false; Expected = 'not-2F' },
        @{ Name = 'pair requested but creation not authorized'; Request = 'execute'; DistinctWindow = $true; IndependentReview = $true; CurrentCanExecute = $true; PairReady = $false; CreateAuthorized = $false; Expected = '2F:prepare-only' }
    )

    foreach ($case in $cases) {
        $actual = 'not-2F'
        if ($case.Request -eq 'execute' -and $case.DistinctWindow -and $case.IndependentReview) {
            if ($case.PairReady) {
                $actual = '2F:reuse-pair'
            }
            elseif (-not $case.CreateAuthorized) {
                $actual = '2F:prepare-only'
            }
            elseif ($case.CurrentCanExecute) {
                $actual = '2F:create-one-reviewer'
            }
            else {
                $actual = '2F:create-minimum-missing-roles'
            }
        }
        if ($actual -ne $case.Expected) {
            throw "场景 2F 虚构路由失败：$($case.Name)；expected=$($case.Expected) actual=$actual"
        }
    }
    Write-Host "Commander scene 2F routing: PASS ($($cases.Count) synthetic cases)"
}

function Test-CommanderNextActionConvergenceCases {
    function Get-SyntheticOperatorAdviceKind {
        param(
            [ValidateSet('executor', 'reviewer', 'closer', 'executor-closer', 'reviewer-closer')]
            [string]$ProducerRole,
            [ValidateSet('active', 'finished')]
            [string]$PhaseState = 'active',
            [bool]$NeedsNewUserDecision = $false,
            [bool]$IsCloserDecision = $false,
            [ValidateSet('operator', 'paired-window')]
            [string]$Audience = 'operator'
        )

        if ($Audience -eq 'paired-window') {
            return 'INTERNAL_ONLY'
        }
        if ($IsCloserDecision -and $ProducerRole -in @('closer', 'executor-closer', 'reviewer-closer')) {
            return 'CURRENT_ACTION'
        }
        if ($ProducerRole -in @('executor', 'reviewer', 'executor-closer', 'reviewer-closer') -and
            ($PhaseState -eq 'finished' -or $NeedsNewUserDecision)) {
            return 'CANDIDATE'
        }
        return 'CURRENT_ACTION'
    }

    function Get-SyntheticCandidateDeliveryMessage {
        param(
            [ValidateSet('confirmed', 'sent-pending-confirmation', 'not-sent')]
            [string]$DeliveryState
        )
        switch ($DeliveryState) {
            'confirmed' { return '候选已由收口方确认接收；你现在不用操作，等待统一安排。' }
            'sent-pending-confirmation' { return '候选已发送待确认；现在不要执行，等待收口方统一安排。' }
            'not-sent' { return '候选尚未送达；现在不要执行冲突部分。由收口方或最小人工转交继续。' }
        }
    }

    function Resolve-SyntheticDirectUserInstruction {
        param(
            [bool]$WithinCurrentStage,
            [bool]$AuthorizationValid,
            [bool]$ConflictsWithCentralState
        )
        if ($WithinCurrentStage -and $AuthorizationValid -and -not $ConflictsWithCentralState) {
            return 'EXECUTE_NOW'
        }
        return 'WAIT_FOR_CLOSER_UPDATE'
    }

    function Resolve-SyntheticCurrentActions {
        param([object[]]$Cards)

        $eligible = @($Cards | Where-Object {
            $_.AdviceKind -eq 'CURRENT_ACTION' -and
            $_.Status -in @('EXECUTE_NOW', 'WAIT', 'BLOCKED') -and
            $_.CurrentGeneration -and
            $_.CurrentStateVersion -and
            ($_.Status -ne 'EXECUTE_NOW' -or (
                $_.HardGateAllowed -and $_.AuthorizationValid -and
                $_.EvidenceValid -and $_.PreconditionsMet
            ))
        })

        $terminalHistory = @($Cards | Where-Object Status -in @('CANCELLED', 'SUPERSEDED'))
        $selected = [Collections.Generic.List[object]]::new()
        $ambiguousDomains = [Collections.Generic.List[string]]::new()
        foreach ($group in ($eligible | Group-Object ConflictDomain)) {
            $topAuthority = ($group.Group | Measure-Object AuthorityRank -Maximum).Maximum
            $authorityCandidates = @($group.Group | Where-Object AuthorityRank -eq $topAuthority)
            $topVersion = ($authorityCandidates | Measure-Object StateVersion -Maximum).Maximum
            $versionCandidates = @($authorityCandidates | Where-Object StateVersion -eq $topVersion)
            $distinctActions = @($versionCandidates | ForEach-Object { "$($_.Action)|$($_.Status)" } | Sort-Object -Unique)
            if ($distinctActions.Count -ne 1) {
                $ambiguousDomains.Add($group.Name)
                continue
            }
            $winner = $versionCandidates | Select-Object -First 1
            $selected.Add($winner)
        }

        $ordered = @($selected | Sort-Object Priority, ConflictDomain)
        [pscustomobject]@{
            Active = $ordered
            Immediate = @($ordered | Where-Object Status -eq 'EXECUTE_NOW' | Select-Object -First 1)
            AmbiguousDomains = @($ambiguousDomains)
            TerminalHistory = $terminalHistory
        }
    }

    function New-SyntheticAction {
        param(
            [string]$Name,
            [string]$ConflictDomain,
            [string]$Action,
            [string]$NextActor = 'assigned-role',
            [string]$Supersedes = 'none',
            [int]$AuthorityRank = 1,
            [int]$StateVersion = 1,
            [int]$ReceivedOrder = 1,
            [int]$Priority = 1,
            [string]$AdviceKind = 'CURRENT_ACTION',
            [string]$Status = 'EXECUTE_NOW',
            [bool]$CurrentGeneration = $true,
            [bool]$CurrentStateVersion = $true,
            [bool]$HardGateAllowed = $true,
            [bool]$AuthorizationValid = $true,
            [bool]$EvidenceValid = $true,
            [bool]$PreconditionsMet = $true,
            [string]$DeliveryState = 'confirmed'
        )
        [pscustomobject]@{
            Name = $Name
            ConflictDomain = $ConflictDomain
            Action = $Action
            NextActor = $NextActor
            Supersedes = $Supersedes
            AuthorityRank = $AuthorityRank
            StateVersion = $StateVersion
            ReceivedOrder = $ReceivedOrder
            Priority = $Priority
            AdviceKind = $AdviceKind
            Status = $Status
            CurrentGeneration = $CurrentGeneration
            CurrentStateVersion = $CurrentStateVersion
            HardGateAllowed = $HardGateAllowed
            AuthorizationValid = $AuthorizationValid
            EvidenceValid = $EvidenceValid
            PreconditionsMet = $PreconditionsMet
            DeliveryState = $DeliveryState
        }
    }

    $delayed = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'delayed old central action' -ConflictDomain 'artifact-a' -Action 'old-action' -AuthorityRank 2 -StateVersion 2 -ReceivedOrder 9 -CurrentStateVersion $false),
        (New-SyntheticAction -Name 'current central action' -ConflictDomain 'artifact-a' -Action 'current-action' -AuthorityRank 2 -StateVersion 3 -ReceivedOrder 2)
    )
    if ($delayed.Active.Count -ne 1 -or $delayed.Active[0].Action -ne 'current-action') {
        throw '下一步收敛失败：延迟到达的旧高权限消息覆盖了当前状态版本'
    }

    $duplicate = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'duplicate one' -ConflictDomain 'artifact-b' -Action 'same-action' -StateVersion 4 -ReceivedOrder 1),
        (New-SyntheticAction -Name 'duplicate two' -ConflictDomain 'artifact-b' -Action 'same-action' -StateVersion 4 -ReceivedOrder 2)
    )
    if ($duplicate.Active.Count -ne 1 -or $duplicate.Active[0].Action -ne 'same-action') {
        throw '下一步收敛失败：重复消息产生了多个当前行动'
    }

    $sameVersionConflict = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'same version action one' -ConflictDomain 'artifact-conflict' -Action 'action-one' -AuthorityRank 2 -StateVersion 5 -ReceivedOrder 1),
        (New-SyntheticAction -Name 'same version action two' -ConflictDomain 'artifact-conflict' -Action 'action-two' -AuthorityRank 2 -StateVersion 5 -ReceivedOrder 2)
    )
    if ($sameVersionConflict.Active.Count -ne 0 -or $sameVersionConflict.AmbiguousDomains -notcontains 'artifact-conflict') {
        throw '下一步收敛失败：同层级同版本的不同动作按到达顺序被错误选中'
    }

    $twoCommanders = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'old commander' -ConflictDomain 'central-state' -Action 'continue-old' -AuthorityRank 2 -StateVersion 8 -CurrentGeneration $false),
        (New-SyntheticAction -Name 'current commander' -ConflictDomain 'central-state' -Action 'pause-current' -AuthorityRank 2 -StateVersion 2 -Status 'BLOCKED')
    )
    if ($twoCommanders.Active.Count -ne 1 -or $twoCommanders.Active[0].Action -ne 'pause-current') {
        throw '下一步收敛失败：旧总指挥世代仍能签发当前行动'
    }

    $centralStop = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'executor continue' -ConflictDomain 'dataset-review' -Action 'start-manual-review' -AuthorityRank 1 -StateVersion 6),
        (New-SyntheticAction -Name 'central evidence gate' -ConflictDomain 'dataset-review' -Action 'design-evidence-capture' -NextActor 'evidence-capability-owner' -Supersedes 'start-manual-review' -AuthorityRank 2 -StateVersion 7 -Priority 1),
        (New-SyntheticAction -Name 'unrelated read-only' -ConflictDomain 'service-readonly' -Action 'inspect-service-readonly' -AuthorityRank 1 -StateVersion 1 -Priority 2)
    )
    if ($centralStop.Active.Count -ne 2 -or $centralStop.Immediate[0].Action -ne 'design-evidence-capture' -or
        $centralStop.Immediate[0].NextActor -ne 'evidence-capability-owner' -or
        $centralStop.Immediate[0].Supersedes -ne 'start-manual-review' -or
        $centralStop.Active.Action -contains 'start-manual-review' -or $centralStop.Active.Action -notcontains 'inspect-service-readonly') {
        throw '下一步收敛失败：证据门禁未替代人工复核建议，或无关只读核验被全局冻结'
    }

    $ackOnly = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'central ack only' -ConflictDomain 'artifact-c' -Action 'ack' -AuthorityRank 2 -AdviceKind 'CANDIDATE' -Status 'WAIT')
    )
    if ($ackOnly.Active.Count -ne 0) {
        throw '下一步收敛失败：中央 ACK 被误当成当前行动'
    }

    $noCommunicationAuthorization = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'central replacement' -ConflictDomain 'artifact-d' -Action 'wait-for-manual-forward' -AuthorityRank 2 -Status 'WAIT' -DeliveryState 'sent-pending-confirmation')
    )
    if ($noCommunicationAuthorization.Active[0].DeliveryState -ne 'sent-pending-confirmation') {
        throw '下一步收敛失败：投递未确认被误记为已确认撤回'
    }

    $hardGate = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'user requested but forbidden' -ConflictDomain 'remote-write' -Action 'push' -AuthorityRank 3 -HardGateAllowed $false)
    )
    if ($hardGate.Active.Count -ne 0) {
        throw '下一步收敛失败：行动卡或操作者请求越过了系统/项目硬门禁'
    }

    $artifactIdentityMismatch = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'same checkpoint but dirty worktree' -ConflictDomain 'artifact-identity' -Action 'accept-result' -AuthorityRank 2 -EvidenceValid $false)
    )
    if ($artifactIdentityMismatch.Active.Count -ne 0) {
        throw '下一步收敛失败：单一版本相同掩盖了工作区或运行身份差异'
    }

    $postClosure = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'closed action' -ConflictDomain 'artifact-e' -Action 'closed' -AuthorityRank 2 -Status 'SUPERSEDED'),
        (New-SyntheticAction -Name 'late executor suggestion' -ConflictDomain 'artifact-e' -Action 'reopen' -AuthorityRank 1 -AdviceKind 'CANDIDATE' -StateVersion 9)
    )
    if ($postClosure.Active.Count -ne 0 -or $postClosure.TerminalHistory.Count -ne 1 -or
        $postClosure.TerminalHistory[0].Status -ne 'SUPERSEDED') {
        throw '下一步收敛失败：收口后候选反馈重新激活了已结束动作'
    }

    $executorFinished = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'executor terminal recommendation' -ConflictDomain 'next-phase' -Action 'ask-user-to-review' -AdviceKind (Get-SyntheticOperatorAdviceKind -ProducerRole 'executor' -PhaseState 'finished') -AuthorityRank 1 -StateVersion 3),
        (New-SyntheticAction -Name 'closer current action' -ConflictDomain 'next-phase' -Action 'collect-missing-evidence' -NextActor 'closer-assigned-role' -Supersedes 'ask-user-to-review' -AuthorityRank 2 -StateVersion 4)
    )
    if ($executorFinished.Active.Count -ne 1 -or $executorFinished.Immediate[0].Action -ne 'collect-missing-evidence' -or
        $executorFinished.Active.Action -contains 'ask-user-to-review') {
        throw '下一步收敛失败：执行者完成阶段后仍向操作者签发并行行动'
    }

    $reviewerFinished = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'reviewer terminal recommendation' -ConflictDomain 'review-next-phase' -Action 'ask-user-to-approve' -AdviceKind (Get-SyntheticOperatorAdviceKind -ProducerRole 'reviewer' -PhaseState 'finished') -AuthorityRank 1 -StateVersion 2),
        (New-SyntheticAction -Name 'closer review decision' -ConflictDomain 'review-next-phase' -Action 'wait-for-evidence' -Supersedes 'ask-user-to-approve' -AuthorityRank 2 -StateVersion 3 -Status 'WAIT')
    )
    if ($reviewerFinished.Active.Count -ne 1 -or $reviewerFinished.Active[0].Action -ne 'wait-for-evidence' -or
        $reviewerFinished.Active[0].Supersedes -ne 'ask-user-to-approve' -or
        $reviewerFinished.Active.Action -contains 'ask-user-to-approve') {
        throw '下一步收敛失败：独立审查者结束后仍能与收口方并行要求操作者行动'
    }

    $noCloserDecision = Resolve-SyntheticCurrentActions @(
        (New-SyntheticAction -Name 'executor candidate only' -ConflictDomain 'await-closer' -Action 'executor-proposal' -AdviceKind (Get-SyntheticOperatorAdviceKind -ProducerRole 'executor' -PhaseState 'finished')),
        (New-SyntheticAction -Name 'reviewer candidate only' -ConflictDomain 'await-closer' -Action 'reviewer-proposal' -AdviceKind (Get-SyntheticOperatorAdviceKind -ProducerRole 'reviewer' -PhaseState 'finished'))
    )
    if ($noCloserDecision.Active.Count -ne 0) {
        throw '下一步收敛失败：收口方尚未裁定时把专项候选暴露为当前行动'
    }

    $dualRoleTerminalKind = Get-SyntheticOperatorAdviceKind -ProducerRole 'executor-closer' -PhaseState 'finished'
    $dualRoleCloserKind = Get-SyntheticOperatorAdviceKind -ProducerRole 'executor-closer' -PhaseState 'finished' -IsCloserDecision $true
    if ($dualRoleTerminalKind -ne 'CANDIDATE' -or $dualRoleCloserKind -ne 'CURRENT_ACTION') {
        throw '下一步收敛失败：兼任窗口未先收口就以阶段行动方身份签发当前行动'
    }

    $newDecisionKind = Get-SyntheticOperatorAdviceKind -ProducerRole 'reviewer' -PhaseState 'active' -NeedsNewUserDecision $true
    if ($newDecisionKind -ne 'CANDIDATE') {
        throw '下一步收敛失败：专项窗口把新增授权、选择或验收请求直接签发为当前行动'
    }

    $internalEvidenceRequest = Get-SyntheticOperatorAdviceKind -ProducerRole 'reviewer' -PhaseState 'active' -Audience 'paired-window'
    if ($internalEvidenceRequest -ne 'INTERNAL_ONLY') {
        throw '下一步收敛失败：审查者向执行者索取证据被误登记为操作者当前行动'
    }

    $deliveryMessages = @{
        confirmed = Get-SyntheticCandidateDeliveryMessage -DeliveryState 'confirmed'
        pending = Get-SyntheticCandidateDeliveryMessage -DeliveryState 'sent-pending-confirmation'
        notSent = Get-SyntheticCandidateDeliveryMessage -DeliveryState 'not-sent'
    }
    if ($deliveryMessages.confirmed -notlike '候选已由收口方确认接收*' -or
        $deliveryMessages.pending -notlike '候选已发送待确认*' -or
        $deliveryMessages.notSent -notlike '候选尚未送达*' -or
        $deliveryMessages.pending -like '*确认接收*' -or $deliveryMessages.notSent -like '*确认接收*') {
        throw '下一步收敛失败：候选投递三态产生了假接收声明'
    }

    $directInStage = Resolve-SyntheticDirectUserInstruction -WithinCurrentStage $true -AuthorizationValid $true -ConflictsWithCentralState $false
    if ($directInStage -ne 'EXECUTE_NOW') {
        throw '下一步收敛失败：操作者直接发给专项窗口的当前阶段指令被错误降级'
    }

    $directScopeChange = Resolve-SyntheticDirectUserInstruction -WithinCurrentStage $false -AuthorizationValid $true -ConflictsWithCentralState $true
    if ($directScopeChange -ne 'WAIT_FOR_CLOSER_UPDATE') {
        throw '下一步收敛失败：改变范围或冲突的操作者指令生成了第二条当前行动'
    }

    Write-Host 'Commander next-action convergence: PASS (19 synthetic cases)'
}

function Test-CommanderContinuityRoutingCases {
    $cases = @(
        @{ Name = 'formal commander handoff'; Role = 'commander'; Intent = 'handoff'; Active = $true; UiOnly = $false; Expected = 'snapshot-and-6A' },
        @{ Name = 'archive active commander'; Role = 'commander'; Intent = 'archive'; Active = $true; UiOnly = $false; Expected = 'snapshot-before-archive' },
        @{ Name = 'move ordinary mainline to new task'; Role = 'ordinary'; Intent = 'branch'; Active = $true; UiOnly = $false; Expected = 'continuation-prompt' },
        @{ Name = 'archive active specialist'; Role = 'specialist'; Intent = 'archive'; Active = $true; UiOnly = $false; Expected = 'continuation-prompt-before-archive' },
        @{ Name = 'archive completed ordinary task'; Role = 'ordinary'; Intent = 'archive'; Active = $false; UiOnly = $false; Expected = 'no-active-work-note' },
        @{ Name = 'direct sidebar archive click'; Role = 'ordinary'; Intent = 'archive'; Active = $true; UiOnly = $true; Expected = 'unobservable' }
    )

    foreach ($case in $cases) {
        if ($case.UiOnly) {
            $actual = 'unobservable'
        }
        elseif ($case.Intent -eq 'handoff' -and $case.Role -eq 'commander') {
            $actual = 'snapshot-and-6A'
        }
        elseif ($case.Intent -eq 'archive' -and $case.Role -eq 'commander' -and $case.Active) {
            $actual = 'snapshot-before-archive'
        }
        elseif ($case.Intent -eq 'archive' -and -not $case.Active) {
            $actual = 'no-active-work-note'
        }
        elseif ($case.Intent -eq 'archive' -and $case.Active) {
            $actual = 'continuation-prompt-before-archive'
        }
        elseif ($case.Intent -eq 'branch' -and $case.Active) {
            $actual = 'continuation-prompt'
        }
        else {
            $actual = 'no-continuity-action'
        }

        if ($actual -ne $case.Expected) {
            throw "换窗与归档虚构路由失败：$($case.Name)；expected=$($case.Expected) actual=$actual"
        }
    }
    Write-Host "Commander continuity routing: PASS ($($cases.Count) synthetic cases)"
}

function Test-TextFlowchartTemplateContract {
    $templatePath = '其他 Codex 技巧性提示词/文字版流程图提示词.md'
    $tracked = @(Get-TrackedFiles -Pattern $templatePath)
    if ($tracked.Count -ne 1) {
        throw "文字版流程图模板尚未被 Git 精确跟踪：$templatePath"
    }

    $contracts = @(
        @{
            Path = $templatePath
            Required = @(
                'template_id: text-flowchart-renderer',
                'interface_version: 1',
                '【调用方式】',
                '【工作流调用载荷】',
                '工作流调用失败时不要输出猜测图',
                '文字版流程图模块不可用：<最小精确缺口>'
            )
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/00-第二代工作流总览.md'
            Required = @('核心设计目标与新功能审查基线', '协作净收益', '不在总指挥启动时预加载')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/01-操作者操作手册.md'
            Required = @($templatePath, 'template_id: text-flowchart-renderer', 'interface_version: 1', '我不需要另行打开或复制该模板', '文字版流程图模块不可用')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/02-总指挥核心规则.md'
            Required = @($templatePath, 'template_id: text-flowchart-renderer', 'interface_version: 1', '不得静默使用另一套画法冒充同等结果')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/docs/PIPELINE_DIAGNOSIS_AND_ALGORITHM_TUNING_STANDARD.md'
            Required = @('文字版流程图提示词', 'template_id: text-flowchart-renderer', 'interface_version: 1', '同一任务内模板指纹未变化时可以复用已读结果', '不得静默改用另一套画法冒充同等结果')
        }
    )

    foreach ($contract in $contracts) {
        $content = Get-Content -LiteralPath (Join-Path $repoRoot $contract.Path) -Raw
        foreach ($requiredText in $contract.Required) {
            if (-not $content.Contains($requiredText)) {
                throw "文字版流程图调用契约缺失：$($contract.Path) -> $requiredText"
            }
        }
    }
    Write-Host 'Text flowchart template contract: PASS'
}

function Test-PipelineStepDeckTemplate {
    $relativePath = '总指挥工作流/第二代总指挥的工作模式/templates/PIPELINE_STEP_DECK_TEMPLATE.html'
    $tracked = @(Get-TrackedFiles -Pattern $relativePath)
    if ($tracked.Count -ne 1) {
        throw "链路分步演示模板尚未被 Git 精确跟踪：$relativePath"
    }

    $content = Get-Content -LiteralPath (Join-Path $repoRoot $relativePath) -Raw
    foreach ($requiredText in @(
        'Content-Security-Policy',
        'id="previousStep"',
        'id="nextStep"',
        'id="toggleOverview"',
        'ArrowLeft',
        'ArrowRight',
        'textContent',
        '本步骤输出效果',
        '本步骤没有可展示的直观视觉样例',
        '真实阶段结果尚未采集',
        'scene2c-compact-flush-b-v2',
        'captureNavigationPosition',
        'stageNavVisible',
        'window.scrollBy',
        'ensureActiveStageChipVisible',
        'ui.stageNav.scrollLeft = targetLeft',
        'window.requestAnimationFrame(restoreAndReveal)',
        'height: clamp(660px, calc(100vh - 100px), 820px)',
        'padding: 0 10px 8px',
        'comparison-output',
        'comparison-columns',
        'comparison-card-output',
        'synchronizeComparisonRows',
        'scheduleComparisonRowSync',
        'formatStepCounter',
        'button.dataset.stepId',
        'padding: 5px 9px 6px',
        'font-size: 11px',
        'overflow-wrap: anywhere',
        'kind === "comparison"',
        '对照运行证据',
        'visualLegend',
        'comparisonIdentity',
        'comparisonKey',
        'diagnostic-comparison',
        '__pipelineStep',
        '.comparison-card:not([hidden])'
    )) {
        if (-not $content.Contains($requiredText)) {
            throw "链路分步演示模板缺少耐久契约：$requiredText"
        }
    }

    if ($content.Contains('stableSingleViewHeight')) {
        throw '链路分步演示模板不得通过历史最大页高制造空白'
    }

    if ($content.Contains('ui.stageNav.scrollLeft = position.stageNavX')) {
        throw '链路分步演示模板不得把阶段索引锁在旧横向位置；当前节点标签必须自动进入可见区域。'
    }

    $contextStripIndex = $content.IndexOf('<section class="context-strip"')
    $topbarIndex = $content.IndexOf('<header class="topbar"')
    if ($contextStripIndex -lt 0 -or $topbarIndex -lt 0 -or $contextStripIndex -gt $topbarIndex) {
        throw '链路分步演示模板必须先显示基线信息栏，再显示步骤导航栏。'
    }

    if ($content.Contains('.innerHTML')) {
        throw '链路分步演示模板不得用 innerHTML 注入任务数据。'
    }
    if ($content -match '(?i)https?://') {
        throw '链路分步演示模板不得依赖远端资源。'
    }
    if ($content -match '(?i)[a-z]:\\') {
        throw '链路分步演示模板不得固化 Windows 绝对路径。'
    }
    Write-Host 'Pipeline step deck template: PASS'
}

function Test-PipelineStepDeckEnhancementTool {
    $runtimePath = '总指挥工作流/第二代总指挥的工作模式/tools/pipeline-step-deck/PIPELINE_STEP_DECK_ENHANCEMENTS.js'
    $builderPath = '总指挥工作流/第二代总指挥的工作模式/tools/pipeline-step-deck/build-enhanced-deck.mjs'
    foreach ($path in @($runtimePath, $builderPath)) {
        $tracked = @(Get-TrackedFiles -Pattern $path)
        if ($tracked.Count -ne 1) {
            throw "链路分步演示增强工具尚未被 Git 精确跟踪：$path"
        }
    }

    $runtime = Get-Content -LiteralPath (Join-Path $repoRoot $runtimePath) -Raw
    foreach ($requiredText in @(
        'const VERSION = "2.0.1"',
        '[comparison-context]',
        '[node-description]',
        'comparisonIdentity',
        'executionIdentity',
        'artifactIdentity',
        'comparisonKey',
        'keyParameters',
        'visualLegend',
        'showSaveFilePicker',
        'pipeline-step-deck-long-image',
        'synchronizeProgressCounter',
        'stage-chip[aria-current="step"]',
        'cardCount',
        '同产物记录',
        '.comparison-card[hidden]'
    )) {
        if (-not $runtime.Contains($requiredText)) {
            throw "链路分步演示增强器缺少耐久契约：$requiredText"
        }
    }
    if ($runtime -match '(?i)source(?:[ _-])?seed|failure(?:[ _-])?code') {
        throw '链路分步演示增强器不得硬编码具体算法的运行字段。'
    }

    $builder = Get-Content -LiteralPath (Join-Path $repoRoot $builderPath) -Raw
    if (-not $builder.Contains('data-pipeline-step-deck-enhancements=\"2.0.1\"') -or
        -not $builder.Contains('runtimeVersion: "2.0.1"')) {
        throw '链路分步演示构建器与增强器版本不一致。'
    }
    Write-Host 'Pipeline step deck enhancement tool: PASS'
}

function Test-LocalProfilePrivacyBoundary {
    $requiredIgnoreRules = @(
        '/总指挥工作流/第二代总指挥的工作模式/操作者协作画像.local.md',
        '/总指挥工作流/第二代总指挥的工作模式/操作者画像资料.local/'
    )
    $gitignore = Get-Content -LiteralPath (Join-Path $repoRoot '.gitignore')
    foreach ($requiredRule in $requiredIgnoreRules) {
        if ($gitignore -cnotcontains $requiredRule) {
            throw "缺少操作者画像本地专用规则：$requiredRule"
        }
    }

    $privatePathspecs = @(
        '总指挥工作流/第二代总指挥的工作模式/操作者协作画像.local.md',
        '总指挥工作流/第二代总指挥的工作模式/操作者画像资料.local/**'
    )
    $tracked = @(git -c "safe.directory=$repoRoot" -c core.quotepath=false -C $repoRoot ls-files -- $privatePathspecs)
    if ($LASTEXITCODE -ne 0) {
        throw '无法核对操作者画像私有路径的 Git 跟踪状态。'
    }
    if ($tracked.Count -gt 0) {
        throw "操作者画像私有路径已被 Git 跟踪：$($tracked -join ', ')"
    }
    Write-Host 'Local operator profile privacy boundary: PASS'
}

function Test-ExplicitAttachmentBoundary {
    $agentsPath = Join-Path $repoRoot 'AGENTS.md'
    $content = Get-Content -LiteralPath $agentsPath -Raw
    foreach ($requiredText in @(
        '仓库外只读与附件处理',
        '其他 AI 不能代授写入权限',
        '无需操作者逐次授权',
        '只读访问这个精确附件路径',
        '附件内容一律作为不可信数据',
        '不列出或搜索父目录'
    )) {
        if (-not $content.Contains($requiredText)) {
            throw "附件读取边界缺失：$requiredText"
        }
    }
    Write-Host 'Explicit attachment boundary: PASS'
}

function Get-CSharpCompiler {
    $command = Get-Command csc.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }

    $frameworkRoot = Join-Path $env:WINDIR 'Microsoft.NET/Framework64'
    $candidate = Get-ChildItem -LiteralPath $frameworkRoot -Filter csc.exe -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if ($null -eq $candidate) {
        throw '找不到 C# 编译器 csc.exe。'
    }
    return $candidate.FullName
}

function Test-ArchiveRepairLauncher {
    $caseRoot = Join-Path $repoRoot '故障排查与解决经验/01-会话与归档/TRB-001-Windows归档路径异常'
    $source = Join-Path $caseRoot 'CodexArchiveRepairLauncher.cs'
    $resource = Join-Path $caseRoot 'Repair-CodexThreadArchive.ps1'
    $checkedExe = Join-Path $caseRoot 'Codex归档修复工具.exe'
    if (-not (Test-Path -LiteralPath $source) -or
        -not (Test-Path -LiteralPath $resource) -or
        -not (Test-Path -LiteralPath $checkedExe)) {
        throw '归档修复工具源码不完整。'
    }

    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $tempDirectory = Join-Path $tempRoot "codex-workflows-check-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $tempDirectory | Out-Null

    try {
        $localSource = Join-Path $tempDirectory 'Launcher.cs'
        $localResource = Join-Path $tempDirectory 'RepairScript.ps1'
        $outputExe = Join-Path $tempDirectory 'CodexArchiveRepairReview.exe'
        $selfTestReport = Join-Path $tempDirectory 'self-test.txt'
        Copy-Item -LiteralPath $source -Destination $localSource
        Copy-Item -LiteralPath $resource -Destination $localResource

        Push-Location $tempDirectory
        try {
            & (Get-CSharpCompiler) /nologo /target:winexe /out:CodexArchiveRepairReview.exe `
                /resource:RepairScript.ps1,CodexArchiveRepairScript `
                /reference:System.Windows.Forms.dll /reference:System.Drawing.dll Launcher.cs
            if ($LASTEXITCODE -ne 0) { throw '归档修复工具编译失败。' }
        }
        finally {
            Pop-Location
        }

        $process = Start-Process -FilePath $outputExe -ArgumentList @('--self-test', $selfTestReport) `
            -Wait -PassThru -WindowStyle Hidden
        if ($process.ExitCode -ne 0) { throw "归档修复工具自检失败：$($process.ExitCode)" }

        $report = Get-Content -LiteralPath $selfTestReport -Raw
        foreach ($expected in @('resource=ok', 'powershell7=ok', 'node=ok')) {
            if ($report -notmatch [regex]::Escape($expected)) {
                throw "归档修复工具自检缺少：$expected"
            }
        }

        $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resource).Hash
        $assembly = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes($outputExe))
        $stream = $assembly.GetManifestResourceStream('CodexArchiveRepairScript')
        if ($null -eq $stream) { throw '编译结果缺少内嵌修复脚本。' }
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $embeddedHash = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '')
        }
        finally {
            $stream.Dispose()
            $sha.Dispose()
        }
        if ($sourceHash -ne $embeddedHash) { throw '编译结果内嵌脚本与源码不一致。' }

        $checkedAssembly = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes($checkedExe))
        $checkedStream = $checkedAssembly.GetManifestResourceStream('CodexArchiveRepairScript')
        if ($null -eq $checkedStream) { throw '仓库随附 EXE 缺少内嵌修复脚本。' }
        $checkedSha = [Security.Cryptography.SHA256]::Create()
        try {
            $checkedHash = ([BitConverter]::ToString($checkedSha.ComputeHash($checkedStream))).Replace('-', '')
        }
        finally {
            $checkedStream.Dispose()
            $checkedSha.Dispose()
        }
        if ($sourceHash -ne $checkedHash) { throw '仓库随附 EXE 内嵌脚本与当前源码不一致。' }
    }
    finally {
        $resolvedTemp = [IO.Path]::GetFullPath($tempDirectory)
        if ($resolvedTemp.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path $resolvedTemp -Leaf) -like 'codex-workflows-check-*') {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host 'Windows archive repair tool: PASS'
}

function Test-TroubleshootingKnowledgeBase {
    $root = Join-Path $repoRoot '故障排查与解决经验'
    $cases = @(
        @{ Id = 'TRB-001'; Path = '01-会话与归档/TRB-001-Windows归档路径异常/Codex 对话无法归档：thread-store 文件路径缺失.md'; Status = '已解决' },
        @{ Id = 'TRB-002'; Path = '01-会话与归档/TRB-002-thread-not-found/thread-not-found-恢复方案.md'; Status = '部分解决' },
        @{ Id = 'TRB-003'; Path = '02-账号与供应商切换/TRB-003-历史列表分裂/CC Switch 切换账号后无法共享对话——原理、恢复与长期配置.md'; Status = '部分解决' },
        @{ Id = 'TRB-004'; Path = '02-账号与供应商切换/TRB-004-旧对话无法继续/Codex 切换账号后旧对话无法继续.md'; Status = '部分解决' },
        @{ Id = 'TRB-005'; Path = '02-账号与供应商切换/TRB-005-迁移后分页谱系损坏/分页谱系损坏与迁移工具暂停.md'; Status = '未解决' },
        @{ Id = 'TRB-006'; Path = '03-跨任务通信/TRB-006-API登录后通信异常/排查记录与建议.md'; Status = '未解决' },
        @{ Id = 'TRB-007'; Path = '04-网络与上游错误/TRB-007-长任务断联与HTTP错误/CC Switch 长任务断联与 401 502 503 504 快速处理.md'; Status = '部分解决' }
    )

    $index = Get-Content -LiteralPath (Join-Path $root 'README.md') -Raw -Encoding utf8
    foreach ($case in $cases) {
        $path = Join-Path $root $case.Path
        if (-not (Test-Path -LiteralPath $path)) { throw "故障记录缺失：$($case.Id)" }
        $text = Get-Content -LiteralPath $path -Raw -Encoding utf8
        foreach ($required in @('| 故障编号 |', "``$($case.Id)``", '| 解决状态 |', '| 工具状态 |', '| 最后核验 |', '| 证据边界 |', $case.Status)) {
            if (-not $text.Contains($required)) { throw "故障记录 $($case.Id) 缺少：$required" }
        }
        if (-not $index.Contains("``$($case.Id)``")) { throw "故障索引缺少：$($case.Id)" }
        $indexRowPattern = "(?m)^\|\s*``$([regex]::Escape($case.Id))``\s*\|.*\*\*$([regex]::Escape($case.Status))"
        if ($index -notmatch $indexRowPattern) {
            throw "故障索引与案例状态不一致：$($case.Id) -> $($case.Status)"
        }
    }

    $template = Get-Content -LiteralPath (Join-Path $root '故障记录模板.md') -Raw -Encoding utf8
    foreach ($required in @('当前没有已验证的解决方案', '已确认事实', '合理推断', '待确认项', '证据登记', '配套工具', '失效与重验条件')) {
        if (-not $template.Contains($required)) { throw "故障模板缺少：$required" }
    }

    $historicalSplitCase = Get-Content -LiteralPath (Join-Path $root $cases[2].Path) -Raw -Encoding utf8
    foreach ($required in @('当前停止条件', '当前暂停真实执行', '当前版本不得照抄执行', '只在完整副本中研究')) {
        if (-not $historicalSplitCase.Contains($required)) {
            throw "TRB-003 缺少历史操作失败关闭说明：$required"
        }
    }

    $tracked = @(Get-TrackedFiles -Pattern '故障排查与解决经验/*')
    if ($tracked -match 'stage-a-report\.json$') { throw '本地扫描报告不得被 Git 跟踪。' }
    $forbiddenPatterns = @(
        @{ Pattern = '(?i)[A-Z]:\\Users\\(?!<)'; Label = '真实 Windows 用户路径' },
        @{ Pattern = '127\.0\.0\.1:\d{2,5}'; Label = '固定本地端口' },
        @{ Pattern = 'CC switch切换账号后，旧的对话无法继续/用法\.txt'; Label = '已删除的旧入口' }
    )
    foreach ($forbidden in $forbiddenPatterns) {
        foreach ($relative in $tracked) {
            $path = Join-Path $repoRoot $relative
            if ([IO.Path]::GetExtension($path) -notin @('.md', '.txt', '.mjs', '.ps1', '.cs', '.cmd', '.json')) { continue }
            if ((Get-Content -LiteralPath $path -Raw -Encoding utf8) -match $forbidden.Pattern) {
                throw "故障资料仍包含$($forbidden.Label)：$relative"
            }
        }
    }

    $migration = Join-Path $root '02-账号与供应商切换/TRB-005-迁移后分页谱系损坏/迁移工具研究材料-真实操作已暂停/install_bulk_codex_migration.mjs'
    $migrationRoot = Split-Path -Parent $migration
    foreach ($syntheticTest in @(
        @{ Path = (Join-Path $migrationRoot 'safety_tests.mjs'); Label = '内容保真与失败关闭' },
        @{ Path = (Join-Path $migrationRoot 'lineage_tests.mjs'); Label = '分页谱系' }
    )) {
        $syntheticOutput = & node $syntheticTest.Path 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or $syntheticOutput -notmatch 'PASS:') {
            throw "迁移工具$($syntheticTest.Label)虚构测试失败：$syntheticOutput"
        }
    }
    $selfTestOutput = & node $migration '--self-test' 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $selfTestOutput -notmatch 'self-test used synthetic values and a temporary file only') {
        throw "迁移安装器纯虚构自检失败：$selfTestOutput"
    }
    foreach ($gate in @(
        @{ Argument = '--apply'; Signature = '安装已暂停'; Label = '安装' },
        @{ Argument = '--rollback-latest'; Signature = '回滚已暂停'; Label = '回滚' }
    )) {
        $gateOutput = & node $migration $gate.Argument 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -or $gateOutput -notmatch [regex]::Escape($gate.Signature)) {
            throw "真实$($gate.Label)入口没有失败关闭。"
        }
    }
    Write-Host "Troubleshooting knowledge base: PASS ($($cases.Count) cases)"
}

Test-RepositoryPathPortability
Test-MarkdownFiles
Test-BilingualReadmes
Test-PowerShellFiles
& (Join-Path $PSScriptRoot 'Test-SessionRecordShape.ps1')
& (Join-Path $PSScriptRoot 'Test-SessionDeskOrder.ps1')
Test-CommanderRuleVersion
Test-CommanderDurableWorkflowContract
Test-CommanderScene2FRoutingCases
Test-CommanderNextActionConvergenceCases
Test-CommanderContinuityRoutingCases
& node (Join-Path $PSScriptRoot 'Test-HandoffIdentity.mjs')
if ($LASTEXITCODE -ne 0) { throw '成果连续性虚构检查失败。' }
Test-TextFlowchartTemplateContract
Test-PipelineStepDeckTemplate
Test-PipelineStepDeckEnhancementTool
Test-LocalProfilePrivacyBoundary
Test-ExplicitAttachmentBoundary
Test-ArchiveRepairLauncher
Test-TroubleshootingKnowledgeBase
Write-Host 'Repository quality checks: PASS'
# Expected rejection tests leave a nonzero native exit code. All checks above
# must complete before reporting success to the invoking PowerShell/CI shell.
$global:LASTEXITCODE = 0
