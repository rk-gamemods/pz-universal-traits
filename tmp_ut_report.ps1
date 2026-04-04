$path = 'UniversalTraits\media\scripts\UT_character_traits.txt'
$lines = Get-Content $path

$defOrder = @{}
$defIds = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*character_trait_definition\s+([^\s\{]+)') {
        $id = $matches[1]
        if (-not $defOrder.ContainsKey($id)) {
            $defOrder[$id] = $defIds.Count
            $defIds.Add($id) | Out-Null
        }
    }
}

$currentTrait = $null
$changes = New-Object System.Collections.Generic.List[object]
$originalPairs = New-Object 'System.Collections.Generic.HashSet[string]'
$remainingPairs = New-Object 'System.Collections.Generic.HashSet[string]'

function Get-PairKey([string]$a, [string]$b) {
    if ([string]::CompareOrdinal($a, $b) -le 0) { return "$a|$b" }
    return "$b|$a"
}

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match '^\s*character_trait_definition\s+([^\s\{]+)') {
        $currentTrait = $matches[1]
        continue
    }
    if (-not $currentTrait) { continue }
    if ($line -match '^(?<prefix>\s*MutuallyExclusiveTraits\s*=\s*)(?<value>.*?)(?<suffix>\s*,\s*(?:--.*)?)$') {
        $prefix = $matches['prefix']
        $value = $matches['value']
        $suffix = $matches['suffix']
        $tokens = @()
        if ($value.Trim().Length -gt 0) {
            $tokens = $value.Split(';') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        }
        $kept = New-Object System.Collections.Generic.List[string]
        foreach ($token in $tokens) {
            $isUT = $token.StartsWith('UniversalTraits:')
            if ($isUT -and $defOrder.ContainsKey($currentTrait) -and $defOrder.ContainsKey($token)) {
                [void]$originalPairs.Add((Get-PairKey $currentTrait $token))
            }
            $keep = $true
            if ($isUT) {
                if ($defOrder.ContainsKey($token) -and $defOrder.ContainsKey($currentTrait) -and ($defOrder[$token] -lt $defOrder[$currentTrait])) {
                    $keep = $true
                } else {
                    $keep = $false
                }
            }
            if ($keep) {
                $kept.Add($token) | Out-Null
                if ($isUT -and $defOrder.ContainsKey($currentTrait) -and $defOrder.ContainsKey($token)) {
                    [void]$remainingPairs.Add((Get-PairKey $currentTrait $token))
                }
            }
        }
        $newValue = ($kept -join ';')
        $replacement = "$prefix$newValue$suffix"
        if ($replacement -ne $line) {
            $changes.Add([pscustomobject]@{
                LineNumber = $i + 1
                TraitId = $currentTrait
                CurrentLine = $line
                ReplacementLine = $replacement
            }) | Out-Null
        }
    }
}

$outPath = 'ut_mutuallyexclusive_report.txt'
$sb = New-Object System.Text.StringBuilder
foreach ($change in $changes) {
    [void]$sb.AppendLine("Line $($change.LineNumber)")
    [void]$sb.AppendLine("Trait: $($change.TraitId)")
    [void]$sb.AppendLine("Current: $($change.CurrentLine)")
    [void]$sb.AppendLine("Replace: $($change.ReplacementLine)")
    [void]$sb.AppendLine('')
}
$missingPairs = @($originalPairs | Where-Object { -not $remainingPairs.Contains($_) } | Sort-Object)
$status = if ($missingPairs.Count -eq 0) { 'OK - every intended UT-to-UT pair remains represented by at least one backward reference.' } else { 'INCOMPLETE - some intended UT-to-UT pairs would be lost.' }
[void]$sb.AppendLine("Pair coverage after transform: $status")
if ($missingPairs.Count -gt 0) {
    [void]$sb.AppendLine('Missing pairs:')
    foreach ($pair in $missingPairs) { [void]$sb.AppendLine($pair) }
}
Set-Content -Path $outPath -Value $sb.ToString()
Get-Item $outPath | Select-Object FullName,Length
