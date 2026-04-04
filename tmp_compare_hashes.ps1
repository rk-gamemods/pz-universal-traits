$repo = Get-Location
$liveRoot = 'C:/Users/Admin/Zomboid/mods'
$items = @(
    @{ Mod='UniversalTraits'; RelPath='registries.lua'; Kind='explicit' },
    @{ Mod='UniversalTraits'; RelPath='scripts/UT_character_traits.txt'; Kind='explicit' },
    @{ Mod='UniversalTraits'; RelPath='lua/shared/UniversalTraits/UT_MET.lua'; Kind='explicit' }
)

$utCoreSrc = Join-Path $repo 'UT_CORE/media'
if (Test-Path $utCoreSrc) {
    Get-ChildItem -Path $utCoreSrc -Recurse -File | ForEach-Object {
        $rel = [System.IO.Path]::GetRelativePath($utCoreSrc, $_.FullName).Replace('\\','/')
        $items += @{ Mod='UT_CORE'; RelPath=$rel; Kind='ut_core' }
    }
}

$results = foreach ($item in $items) {
    $src = Join-Path $repo ($item.Mod + '/media/' + $item.RelPath)
    $rel = Join-Path $repo ($item.Mod + '/release/' + $item.Mod + '/42/media/' + $item.RelPath)
    $live = Join-Path $liveRoot ($item.Mod + '/42/media/' + $item.RelPath)

    $srcExists = Test-Path $src
    $relExists = Test-Path $rel
    $liveExists = Test-Path $live

    $srcHash = if ($srcExists) { (Get-FileHash -Algorithm SHA256 $src).Hash } else { $null }
    $relHash = if ($relExists) { (Get-FileHash -Algorithm SHA256 $rel).Hash } else { $null }
    $liveHash = if ($liveExists) { (Get-FileHash -Algorithm SHA256 $live).Hash } else { $null }

    $status = if (-not $srcExists) { 'missing-source' }
        elseif (-not $relExists -and -not $liveExists) { 'missing-release-live' }
        elseif (-not $relExists) { 'missing-release' }
        elseif (-not $liveExists) { 'missing-live' }
        elseif ($srcHash -eq $relHash -and $srcHash -eq $liveHash) { 'match-all' }
        else { 'hash-mismatch' }

    [PSCustomObject]@{
        Mod = $item.Mod
        RelPath = $item.RelPath
        Kind = $item.Kind
        Status = $status
        SourceExists = $srcExists
        ReleaseExists = $relExists
        LiveExists = $liveExists
        SourceHash = $srcHash
        ReleaseHash = $relHash
        LiveHash = $liveHash
    }
}

Write-Host 'SUMMARY'
$results | Group-Object Status | Sort-Object Name | ForEach-Object { '{0}: {1}' -f $_.Name, $_.Count }
Write-Host '--- MISMATCHES / MISSING ---'
$results | Where-Object { $_.Status -ne 'match-all' } | Sort-Object Mod, RelPath | Format-Table -AutoSize Mod, RelPath, Status, SourceExists, ReleaseExists, LiveExists
Write-Host '--- EXPLICIT FILES ---'
$results | Where-Object { $_.Kind -eq 'explicit' } | Sort-Object Mod, RelPath | Format-Table -AutoSize Mod, RelPath, Status, SourceHash, ReleaseHash, LiveHash
Write-Host '--- UT_CORE NON-MATCHING DETAILS ---'
$results | Where-Object { $_.Kind -eq 'ut_core' -and $_.Status -ne 'match-all' } | Sort-Object RelPath | Format-List Mod, RelPath, Status, SourceHash, ReleaseHash, LiveHash