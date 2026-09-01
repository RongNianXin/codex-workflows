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

            $resolved = [IO.Path]::GetFullPath((Join-Path (Split-Path $fullPath -Parent) $pathPart))
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
            Required = @('请帮我部署，我要人工核验', '下次仍可直接说')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/02-总指挥核心规则.md'
            Required = @('低信息部署请求与运行身份交付门禁', 'COMMIT-LEDGER', '保留级别：KEY_NODE', '并存实现决议矩阵')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/04-状态、目标变更与交接规范.md'
            Required = @('耐久 Commit 台账与关键节点', 'COMMIT-LEDGER', '保留级别：ROUTINE / KEY_NODE')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/10-自动状态索引规范.md'
            Required = @('COMMIT-LEDGER', '人工核验运行身份清单', '并存实现决议矩阵')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/07-总指挥交接记录模板.md'
            Required = @('KEY_NODE', '运行身份', '并存实现决议')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/总指挥轻量交接启动配置.md'
            Required = @('KEY_NODE', 'expected_candidate', 'commit_ledger')
        },
        @{
            Path = '总指挥工作流/第二代总指挥的工作模式/docs/PR_SUBMISSION_AND_REVIEW_STANDARD.md'
            Required = @('并存实现决议与实际运行身份', '代码已包含', '干净环境可复现')
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
    $source = Join-Path $repoRoot '故障排查与解决经验/对话无法归档/CodexArchiveRepairLauncher.cs'
    $resource = Join-Path $repoRoot '故障排查与解决经验/对话无法归档/Repair-CodexThreadArchive.ps1'
    if (-not (Test-Path -LiteralPath $source) -or -not (Test-Path -LiteralPath $resource)) {
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

Test-MarkdownFiles
Test-PowerShellFiles
Test-CommanderRuleVersion
Test-CommanderDurableWorkflowContract
Test-ArchiveRepairLauncher
Write-Host 'Repository quality checks: PASS'
