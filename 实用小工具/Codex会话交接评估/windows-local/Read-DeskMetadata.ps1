function Read-SharedText([string]$Path) {
    $stream=[IO.File]::Open($Path,'Open','Read','ReadWrite')
    $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8,$true)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Get-DeskMetadata([string]$CodexHome, [string[]]$Ids) {
    $result=@{};$invalid=@{}
    foreach($id in $Ids){$result[$id]=@{name='';project='';nameFound=$false;projectFound=$false}}
    if(-not $Ids.Count){return $result}
    # Local index data is never executed or used as a command/path.
    try {
        $reader=[IO.StreamReader]::new([IO.File]::Open((Join-Path $CodexHome 'session_index.jsonl'),'Open','Read','ReadWrite'),[Text.Encoding]::UTF8,$true)
        try {
            while($null -ne ($line=$reader.ReadLine())) {
                try {$entry=$line|ConvertFrom-Json} catch {foreach($candidate in $Ids){if($line.Contains($candidate)){$invalid[$candidate]=$true}};continue}
                $id=[string]$entry.id
                if(-not $id){$id=[string]$entry.thread_id}
                if(-not $id){$id=[string]$entry.session_id}
                if(-not $result.ContainsKey($id)){continue}
                foreach($key in @('thread_name','title','name')) {
                    $name=([string]$entry.$key -replace '[\x00-\x1f\x7f]',' ').Trim()
                    if($name -and $name.Length -le 4096){$result[$id].name=$name;$result[$id].nameFound=$true;break}
                }
            }
        } finally {$reader.Dispose()}
        foreach($id in $invalid.Keys){$result[$id].nameFound=$false}
    } catch {foreach($id in $Ids){$result[$id].nameFound=$false}}
    try {
        $state=(Read-SharedText (Join-Path $CodexHome '.codex-global-state.json'))|ConvertFrom-Json
        foreach($id in $Ids){
            $assignment=$state.'thread-project-assignments'.$id
            if($assignment.projectKind -ne 'local'){continue}
            $project=$state.'local-projects'.([string]$assignment.projectId)
            if($project.id -ne $assignment.projectId){continue}
            $name=([string]$project.name -replace '[\x00-\x1f\x7f]',' ').Trim()
            if($name -and $name.Length -le 4096){$result[$id].project=$name;$result[$id].projectFound=$true}
        }
    } catch {foreach($id in $Ids){$result[$id].projectFound=$false}}
    return $result
}
