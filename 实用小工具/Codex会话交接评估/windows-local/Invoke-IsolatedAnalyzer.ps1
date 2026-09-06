[CmdletBinding()]
param([Parameter(Mandatory)][string]$TaskId, [Parameter(Mandatory)][string]$ReportPath,
    [ValidateSet('zh-CN','en-US')][string]$Language = 'zh-CN', [string]$MetadataPath)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
try {
    # This wrapper is copied beside the isolated analyzer, never run against the original.
    $script = Join-Path $PSScriptRoot 'isolated-analyzer.ps1'
    $output = . $script -TaskId $TaskId -ReportPath $ReportPath -Language $Language | Out-String -Width 180
    if ($MetadataPath) {
        $metadata = @{name=$taskNameInfo.TaskName;found=$taskNameInfo.IndexFound;warnings=$taskNameInfo.ParseWarnings}
        [IO.File]::WriteAllText($MetadataPath, ($metadata | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
    }
    [Console]::Out.Write($output)
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
