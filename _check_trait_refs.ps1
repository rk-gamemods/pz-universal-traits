$utPath = '.\UniversalTraits\media\scripts\UT_character_traits.txt'
$baseRoot = '..\PZCodebase'
$traitDefPattern = '^\s*character_trait_definition\s+([^\s\{]+)'
$mutexPattern = 'MutuallyExclusiveTraits\s*=\s*(.+?)\s*,?\s*$'
function Get-TraitDefs([string]$path) {
  $lines = Get-Content $path
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $traitDefPattern) {
      [pscustomobject]@{ Path=$path; LineNumber=$i+1; Id=$matches[1] }
    }
  }
}
$utDefs = @(Get-TraitDefs $utPath)
$baseFiles = Get-ChildItem $baseRoot -Recurse -File | Where-Object { $_.Extension -in '.txt','.script','.lua' } | Where-Object { Select-String -Path $_.FullName -Pattern 'character_trait_definition' -Quiet }
$baseDefs = foreach ($file in $baseFiles) { Get-TraitDefs $file.FullName }
$allDefs = @($utDefs + $baseDefs)
$allIds = $allDefs.Id | Sort-Object -Unique
$allIdSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$allIds | ForEach-Object { [void]$allIdSet.Add($_) }
$caseMap = @{}
$localMap = @{}
foreach ($id in $allIds) {
  $caseKey = $id.ToLowerInvariant()
  if (-not $caseMap.ContainsKey($caseKey)) { $caseMap[$caseKey] = @() }
  $caseMap[$caseKey] += $id
  $local = ($id -split ':')[-1].ToLowerInvariant()
  if (-not $localMap.ContainsKey($local)) { $localMap[$local] = @() }
  $localMap[$local] += $id
}
$lines = Get-Content $utPath
$currentTrait = $null
$issues = New-Object System.Collections.Generic.List[object]
for ($i = 0; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]
  if ($line -match $traitDefPattern) { $currentTrait = $matches[1]; continue }
  if ($line -match $mutexPattern) {
    $refs = $matches[1] -split '[;,]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    foreach ($ref in $refs) {
      if (-not $allIdSet.Contains($ref)) {
        $caseMatches = @($caseMap[$ref.ToLowerInvariant()] | Select-Object -Unique)
        $local = ($ref -split ':')[-1].ToLowerInvariant()
        $localMatches = @($localMap[$local] | Select-Object -Unique)
        $type = 'unresolved'
        $hint = $null
        if ($caseMatches.Count -gt 0) { $type = 'case-only mismatch'; $hint = ($caseMatches -join ', ') }
        elseif ($localMatches.Count -gt 0) { $type = 'namespace/local-name typo'; $hint = ($localMatches -join ', ') }
        $issues.Add([pscustomobject]@{ LineNumber=$i+1; OwnerTrait=$currentTrait; Ref=$ref; Type=$type; Candidate=$hint }) | Out-Null
      }
    }
  }
}
$issues | Sort-Object LineNumber,Ref | ConvertTo-Json -Depth 3
