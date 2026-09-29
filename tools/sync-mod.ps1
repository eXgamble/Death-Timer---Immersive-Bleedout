# Mirror the working MO2 mod folder into this repository's mod/ folder, ready to commit.
# The MO2 folder is where the mod is edited and tested; mod/ is only a copy of it.
# MO2's own meta.ini is left out. Files deleted from the MO2 folder are deleted from mod/ too.

param(
    [string]$Source = "C:\Modding\MO2\mods\Death Timer - Immersive Bleedout"
)

$Target = Join-Path $PSScriptRoot "..\mod"
if (-not (Test-Path $Source)) {
    Write-Error "MO2 mod folder not found: $Source"
    exit 1
}

robocopy $Source $Target /MIR /XF meta.ini /NFL /NDL /NJH /NP
# robocopy: 0-7 = success (files copied / extra files removed), 8+ = failure
if ($LASTEXITCODE -ge 8) {
    Write-Error "robocopy failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
Write-Host "mod/ now matches $Source"
exit 0
