# RSDragonwilds LiveMap

[中文说明](README.zh-CN.md)

A [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod for **RuneScape: Dragonwilds** that opens a live map in your browser
(`http://localhost:8765/`) while you play.

- Your and your party's position, heading and trail, on top of the game's own world map
- English and Chinese UI using the game's official item / creature / region names; every layer can be split into sub-categories
- **Every** lodestone, anima vent (icon by rune type), rune essence geyser, chest, teleporter / vault entrance,
  shrine, graveyard, agility course / kebbit burrow, ore node, fishing spot, lore item and NPC on the whole map
  — about 14,000 points, using the game's own icons
- Stone, gatherables, monster spawn points and nearby creatures as optional layers
- Your own beds / chests, death gravestones and the current quest target from a live in-game scan

The game streams the world (World Partition), so only nearby actors exist in memory. LiveMap therefore ships
**pre-extracted full-map data** read offline from the game files, and the in-game scan only adds nearby dynamic things.

## Install (players)

1. Install a UE4SS **experimental** build with Unreal Engine 5.6 support into
   `<game>/RSDragonwilds/Binaries/Win64/` (tested with v3.0.1-1142).
2. Download `LiveMap-RSDragonwilds-<version>.zip` from [Releases](../../releases) and copy the `LiveMap` folder into
   `<game>/RSDragonwilds/Binaries/Win64/ue4ss/Mods/`.
3. Start the game — the map opens in your browser.

Full instructions (English and Chinese) are in [packaging/README.txt](packaging/README.txt) and
[packaging/使用说明.txt](packaging/使用说明.txt); they are included in the release zip.

## Repository layout

| Path | Contents |
|---|---|
| `mod/LiveMap/` | Mod source: `Scripts/*.lua` (UE4SS Lua), `web/index.html` (map page), `server.ps1` (local web server) |
| `data/` | Data extracted from the game, merged into the mod when packaging: full-map actors (`Scripts/world_L_World.lua`), official English/Chinese names from the game's language files (`Scripts/names.lua`), icon path table, map background images, 838 icons |
| `tools/package/` | Files of the optional tools zip (`UpdateWorldData.bat`, term list, readme) |
| `tools/WorldExtract/` | .NET 10 extractor built on [CUE4Parse](https://github.com/FabianFG/CUE4Parse): World Partition actors → Lua data, textures → PNG icons |
| `external/CUE4Parse/` | CUE4Parse git submodule (pinned) |
| `scripts/` | `build_package.py` (zip / dev install), `update_data.ps1` (regenerate `data/`), IoStore `.utoc` index reader |
| `tests/` | Offline tests: runs `main.lua` against a simulated UE4SS API with Lua 5.4 (`lupa`) |
| `packaging/` | Player-facing README files for the zip |

### How it works

- `Scripts/main.lua` runs in the game thread every 250 ms: reads the local player / characters, scans a rotating
  set of classes for dynamic points, and writes `web/data/*.json`. On entering a world it loads
  `world_<World>.lua`, classifies every actor by its class-inheritance chain against `config.lua`, and writes
  `static_<World>.json`.
- `server.ps1` (started by the mod) serves `web/` on localhost; the page polls the JSON files.
- Map backgrounds come from the game's MinimapPlugin (`BP_MapBackground`: texture + world bounds) and are drawn
  into a render target and exported in game (`mapexport.lua`); icons are exported the same way on demand
  (`icons.lua`) when a pre-extracted PNG is missing.

## Development

Requirements: Windows, the game, UE4SS experimental, Python 3, .NET 10 SDK (for the extractor), Node.js (tests).

```powershell
git clone --recurse-submodules https://github.com/<you>/RSDragonwilds-LiveMap
git config core.longpaths true            # CUE4Parse has long test-fixture paths

# tests
python -m pip install lupa
python tests/run_tests.py

# install the mod (source + data) into your game for testing
python scripts/build_package.py --install "<game>\RSDragonwilds\Binaries\Win64\ue4ss\Mods"

# build the release zip locally (optionally with the extractor)
dotnet publish tools/WorldExtract/WorldExtract.csproj -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o build/tools
python scripts/build_package.py --version v1.0.0 --tools-dir build/tools
```

### Updating the data after a game patch

1. In game (with UE4SS) press **Ctrl+Numpad6** once to write a `.usmap` mappings file.
2. `pwsh scripts/update_data.ps1 -GameDir "<game folder>"` — regenerates the icon path table, the full-map actor
   data, the official names and the icons in `data/`.
3. If the world map changed, delete `data/web/data/map_*.png` and `maps_*.json/.lua`, install the mod, open the
   in-game map once (the mod exports it), and copy the new files from the mod's `web/data/` back into `data/web/data/`.
4. `python tests/run_tests.py`, commit.

Players can also refresh the data themselves with the optional tools zip (`LiveMap-Tools-<version>.zip`: `WorldExtract.exe` + `UpdateWorldData.bat`, sources in `tools/package/`). It is a separate download so the mod zip itself contains no executables (Nexus Mods friendly).

## CI / releases

- **CI** (`.github/workflows/ci.yml`): offline tests (Lua compile, simulated run, page and server script parse)
  and an extractor build on every push / PR.
- **Release** (`.github/workflows/release.yml`): push a tag like `v1.0.0` → tests, then two zips attached to a
  GitHub release: `LiveMap-RSDragonwilds-v1.0.0.zip` (the mod, no executables - this is the one for Nexus Mods) and
  `LiveMap-Tools-v1.0.0.zip` (self-contained `WorldExtract.exe` + `UpdateWorldData.bat`). Manual runs upload them as
  artifacts.

## License

Source code: MIT (see [LICENSE](LICENSE)). Files in `data/` are extracted from RuneScape: Dragonwilds — the game's
artwork and data belong to their owners and are not covered by this license. CUE4Parse is Apache-2.0,
UE4SS is MIT. This is an unofficial fan project, not affiliated with Jagex.
