# Regenerate the pre-extracted data in data/ from an installed copy of the game (maintainers only).
#
#   pwsh scripts/update_data.ps1 -GameDir "D:\SteamLibrary\steamapps\common\RSDragonwilds"
#
# Needs: .NET 10 SDK, Python 3, and a mappings file (in game with UE4SS press Ctrl+Numpad6 once).
# Updates: data/Scripts/icon_paths.lua, world_L_World.lua, names.lua, data/web/data/icons/*.png
# Not updated: the map background images (exported in game by the mod itself, see README).
param(
    [Parameter(Mandatory = $true)][string]$GameDir,
    [string]$Usmap,
    [string]$Python = 'python',
    [string]$Dotnet = 'dotnet'
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Paks = Join-Path $GameDir 'RSDragonwilds\Content\Paks'
$Utoc = Join-Path $Paks 'RSDragonwilds-Windows.utoc'
if (-not (Test-Path $Utoc)) { throw "Game files not found: $Utoc" }

if (-not $Usmap) {
    $Usmap = Get-ChildItem (Join-Path $GameDir 'RSDragonwilds\Binaries\Win64') -Filter *.usmap -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Usmap) { throw 'No .usmap found. Press Ctrl+Numpad6 in game (UE4SS) once, or pass -Usmap.' }
Write-Host "Mappings: $Usmap"

$Tmp = Join-Path $Root 'build\update'
New-Item -ItemType Directory -Force $Tmp | Out-Null

Write-Host '== build WorldExtract'
& $Dotnet build (Join-Path $Root 'tools\WorldExtract\WorldExtract.csproj') -c Release -o (Join-Path $Tmp 'bin') | Out-Host
if ($LASTEXITCODE) { throw 'build failed' }
$Exe = Join-Path $Tmp 'bin\WorldExtract.exe'

Write-Host '== icon paths'
& $Python (Join-Path $Root 'scripts\gen_icon_paths.py') $Utoc (Join-Path $Root 'data\Scripts\icon_paths.lua')
if ($LASTEXITCODE) { throw 'gen_icon_paths failed' }

Write-Host '== world data'
& $Exe $Paks $Usmap (Join-Path $Tmp 'world') (Join-Path $Root 'mod\LiveMap\Scripts\config.lua')
if ($LASTEXITCODE) { throw 'world extraction failed' }
Copy-Item (Join-Path $Tmp 'world\world_L_World.lua') (Join-Path $Root 'data\Scripts\world_L_World.lua') -Force

Write-Host '== official names (en / zh-CN)'
& $Exe loc $Paks $Usmap (Join-Path $Root 'data\Scripts\names.lua') (Join-Path $Root 'mod\LiveMap\tools\loc_terms.txt')
if ($LASTEXITCODE) { throw 'name extraction failed' }

Write-Host '== icons'
$List = Join-Path $Tmp 'icons.tsv'
& $Python (Join-Path $Root 'scripts\make_icon_list.py') $Utoc (Join-Path $Root 'data\Scripts\icon_paths.lua') (Join-Path $Root 'mod\LiveMap\Scripts\config.lua') $List
if ($LASTEXITCODE) { throw 'make_icon_list failed' }
$Icons = Join-Path $Root 'data\web\data\icons'
Remove-Item (Join-Path $Icons '*.png') -ErrorAction SilentlyContinue
& $Exe icons $Paks $Usmap $List $Icons 64
if ($LASTEXITCODE) { throw 'icon extraction failed' }

Write-Host 'Done. Review with `git status`, then run `python tests/run_tests.py`.'
