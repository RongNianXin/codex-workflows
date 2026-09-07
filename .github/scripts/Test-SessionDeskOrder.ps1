$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot '../../实用小工具/Codex会话交接评估/windows-local/Start-SessionDesk.ps1'
$tokens=$null;$parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'Parser errors'}
$definition=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-ProjectTaskOrder'},$true)
. ([scriptblock]::Create($definition.Extent.Text))
$count=0
function Check($names,$expected){
    $items=@(for($i=0;$i -lt $names.Count;$i++){@{id=[string]$i;name=$names[$i]}})
    $result=@(Get-ProjectTaskOrder $items)
    if(($result.id -join ',') -ne ($expected -join ',')){throw ('Order mismatch: '+($result.id -join ','))}
    if((@(Get-ProjectTaskOrder $result).id -join ',') -ne ($expected -join ',')){throw 'Not idempotent'}
    $script:count++
}
Check @('A','B','总指挥') @(2,0,1)
Check @('A','【虚构专项】专项审查者1号','B','【虚构专项】专项执行者1号') @(0,2,1,3)
Check @('A','【虚构专项】专项执行者1号','B','【虚构专项】专项审查者1号','总指挥2号','总指挥1号') @(4,5,0,2,1,3)
Check @('【甲】专项审查者1号','【乙】专项执行者2号','A','【甲】专项执行者1号','【乙】专项审查者2号') @(2,0,3,1,4)
Check @('【甲】专项审查者1号','A','【甲】专项执行者2号') @(0,1,2)
Check @('【甲】专项审查者1号','A','【乙】专项执行者1号') @(0,1,2)
Check @('【甲】专项审查者1号','A','【甲】专项执行者1号','【甲】专项审查者1号') @(0,1,2,3)
Check @('A','Commander 1','B','[甲] 专项执行者1号','【甲】专项审查者1号') @(1,0,2,3,4)
Check @('','A','【甲】专项审查者1号（旧）','【甲】专项执行者1号') @(0,1,2,3)
Check @() @()
Write-Output "Project role ordering: PASS ($count synthetic cases, including repeated sorting)"
