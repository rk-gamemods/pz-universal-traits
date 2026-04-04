$repo = Get-Location
$liveRoot = 'C:/Users/Admin/Zomboid/mods'
$explicit = @(
    @{ Mod='UniversalTraits'; RelPath='registries.lua' },
    @{ Mod='UniversalTraits'; RelPath='scripts/UT_character_traits.txt' },
    @{ Mod='UniversalTraits'; RelPath='lua/shared/UniversalTraits/UT_MET.lua' }
)
$utCoreSrc = Join-Path $repo 'UT_CORE/media'
$utCoreCount = if (Test-Path $utCoreSrc) { (Get-ChildItem -Path $utCoreSrc -Recurse -File | Measure-Object).Count } else { 0 }
'UT_CORE file count: ' + $utCoreCount
foreach ($item in $explicit) {
    $src = Join-Path $repo ($item.Mod + '/media/' + $item.RelPath)
    $rel = Join-Path $repo ($item.Mod + '/release/' + $item.Mod + '/42/media/' + $item.RelPath)
    $live = Join-Path $liveRoot ($item.Mod + '/42/media/' + $item.RelPath)
    [PSCustomObject]@{
        RelPath = $item.RelPath
        SourceHash = if (Test-Path $src) { (Get-FileHash -Algorithm SHA256 $src).Hash } else { 'MISSING' }
        ReleaseHash = if (Test-Path $rel) { (Get-FileHash -Algorithm SHA256 $rel).Hash } else { 'MISSING' }
        LiveHash = if (Test-Path $live) { (Get-FileHash -Algorithm SHA256 $live).Hash } else { 'MISSING' }
    } | Format-List
}