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
Test-ArchiveRepairLauncher
Write-Host 'Repository quality checks: PASS'
