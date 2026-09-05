[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$module = Join-Path $root '实用小工具/Codex会话交接评估'
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $module 'check-codex-session.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Analyzer syntax error' }
# Load only pure record helpers, never the session discovery or report entry point.
foreach ($name in @('Get-RecordShape', 'Get-HeadStringField')) {
    $functions = @($ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst]
    }, $true) | Where-Object Name -eq $name)
    if ($functions.Count -ne 1) { throw "Expected one function: $name" }
    Invoke-Expression $functions[0].Extent.Text
}
function Assert-Value($actual, $expected, $label) {
    if ($actual -cne $expected) { throw "Regression: $label" }
}
$corpus = Get-Content -LiteralPath (Join-Path $module 'compatibility-fixtures.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$case = @($corpus.cases | Where-Object name -eq 'json-key-order')[0]
$shapes = @($case.segments[0].text -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { Get-RecordShape $_ })
$tokenRecords = @($shapes | Where-Object { $_.TopType -eq 'event_msg' -and $_.PayloadType -eq 'token_count' })
Assert-Value $tokenRecords.Count 1 'reordered event must be counted'
Assert-Value $tokenRecords[0].Record.payload.info.total_token_usage.total_tokens 100 'reordered token value'
$padding = 'x' * 8192
$line = '{"payload":{"padding":"' + $padding + '","detail":{"type":"decoy"},"type":"token_count","turn_id":"fixture-turn"},"timestamp":"2025-01-01T00:00:00Z","type":"event_msg"}'
$shape = Get-RecordShape $line
Assert-Value $shape.TopType 'event_msg' 'outer type after long payload'
Assert-Value $shape.PayloadType 'token_count' 'nested decoy type'
Assert-Value $shape.TurnId 'fixture-turn' 'turn ID after long prefix'
Assert-Value ([datetimeoffset]::Parse($shape.Timestamp).ToUniversalTime().ToString('s')) '2025-01-01T00:00:00' 'timestamp across PowerShell versions'
$missing = Get-RecordShape '{"payload":{}}'
Assert-Value $missing.TopType '' 'missing type'
Assert-Value $missing.PayloadType '' 'missing payload type'
$broken = Get-RecordShape '{"type":"event_msg","payload":{"type":"token_count","info":'
Assert-Value $broken.TopType 'event_msg' 'existing malformed classification'
Assert-Value $broken.PayloadType 'token_count' 'existing malformed token classification'
Assert-Value $broken.Record $null 'malformed record must not become valid'
Write-Host 'Session record shape regression: PASS (synthetic data only)'
