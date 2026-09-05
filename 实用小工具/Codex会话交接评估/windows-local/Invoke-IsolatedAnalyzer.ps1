[CmdletBinding()]
param([Parameter(Mandatory)][string]$TaskId, [Parameter(Mandatory)][string]$ReportPath)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
try {
    # This wrapper is copied beside the isolated analyzer, never run against the original.
    $script = Join-Path $PSScriptRoot 'isolated-analyzer.ps1'
    $output = & $script -TaskId $TaskId -ReportPath $ReportPath -Language zh-CN | Out-String -Width 180
    [Console]::Out.Write($output)
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
