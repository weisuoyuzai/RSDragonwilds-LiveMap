LiveMap - live web map for RuneScape: Dragonwilds (UE4SS mod)
=============================================================

When the game starts, a live map opens in your browser (http://localhost:8765/). It shows:
  - Your and your party's position, facing and movement trail
  - Every lodestone, anima vent (icon by rune type), rune essence geyser, chest,
    portal / vault entrance, shrine / altar, graveyard, agility course / kebbit burrow,
    ore / essence rock, fishing spot, lore item and NPC on the whole map
  - Stone, gatherables, monster spawn points and nearby creatures
    (hidden by default because there are thousands - toggle them in the layer list)
  - Your own beds / chests, death gravestones, current quest target (scanned live in game)

The full-map item data, the in-game map image and the icons are pre-extracted from the
game files and included, so it works right after install. In game the mod only scans
nearby dynamic things.


Requirement: UE4SS
------------------
This package does NOT include UE4SS. Install it first:
  1. Download a UE4SS *experimental* build (the normal zip is enough, zDEV is not needed):
     https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest
     It must be an experimental build with Unreal Engine 5.6 support - the old 3.0.1
     release does not work with this game. LiveMap was tested with v3.0.1-1142.
  2. Find the game folder: Steam library -> right-click the game -> Manage -> Browse local files.
  3. Extract the UE4SS zip (dwmapi.dll and the ue4ss folder) into
       <game folder>\RSDragonwilds\Binaries\Win64\
     i.e. next to RSDragonwilds-Win64-Shipping.exe.
     (Not into <game folder>\Engine\Binaries\Win64 - it is not loaded from there.)
  4. Recommended changes in ue4ss\UE4SS-settings.ini:
       EnableHotReloadSystem = 0      (hot reload with Ctrl+R can freeze the game)
       GuiConsoleVisible = 0          (hides the UE4SS debug window)
     and in ue4ss\Mods\mods.txt set KismetDebuggerMod and EventViewerMod to 0
     (debugging mods with noticeable overhead).


Install LiveMap
---------------
Copy the LiveMap folder from this zip to
  <game folder>\RSDragonwilds\Binaries\Win64\ue4ss\Mods\LiveMap\
It contains enabled.txt, so mods.txt does not need to be edited.
Start the game - the map page opens in your browser automatically.


Usage
-----
- Drag to pan, mouse wheel to zoom. "Follow player", "Show whole map" and rotate / mirror are in
  the left panel.
- The page is available in English and Chinese: use the 中文 / EN button in the title bar
  (defaults to your browser language). Item, creature and region names are the game's own
  official English / Chinese names.
- Toggle each layer in the left list. Click the ▸ in front of a layer to expand its
  sub-categories (anima vents by rune, gatherables by resource, chests by type and tier,
  monsters by species, ...) and toggle them individually. Adjust icon size with the slider,
  search by name.
- Hover an icon for its name, coordinates and distance from you.
- When zoomed out, the numerous items are drawn as small colored dots and turn into icons
  as you zoom in.

Hotkeys (in game)
  Ctrl+F7  Reopen the map page
  Ctrl+F8  Dump the class names of all loaded actors to LiveMap\web\data\classes.txt
           (useful when adding a new category)
  Ctrl+F9  Clear the points and trail recorded by the in-game scan (full-map data is kept)

Customization: categories, colors and icon rules are in LiveMap\Scripts\config.lua.


After a game update
-------------------
If items are missing or in the wrong place after a game update:
  1. In game press Ctrl+Numpad6 once (UE4SS writes a .usmap mappings file into the ue4ss folder).
  2. Double-click LiveMap\tools\UpdateWorldData.bat and wait about a minute (it refreshes both the
     full-map data and the official English / Chinese names).
  3. Restart the game.
After a major game update UE4SS itself may also need a newer experimental build.


Troubleshooting
---------------
- The page says "not connected" (未连接): make sure the game is running and a save is loaded,
  and check ue4ss\UE4SS.log for "[LiveMap]". No UE4SS.log at all means UE4SS is not
  installed in the right folder.
- The browser did not open: open http://localhost:8765/ yourself, or press Ctrl+F7 in game.
- The map server only listens on localhost, needs no admin rights and is not reachable
  from other machines.
- While the game window is in the background, a few new icons are filled in only after you
  return to the game window (almost all icons are pre-extracted).
- Uninstall: delete the ue4ss\Mods\LiveMap folder.


Third-party components
----------------------
- Requires UE4SS (MIT license)  https://github.com/UE4SS-RE/RE-UE4SS
- tools\WorldExtract.exe uses CUE4Parse (Apache-2.0 license, see tools\CUE4Parse-LICENSE.txt
  and tools\CUE4Parse-NOTICE.txt)  https://github.com/FabianFG/CUE4Parse
- Map and icon artwork belong to the game's developer; provided for personal play assistance only.
