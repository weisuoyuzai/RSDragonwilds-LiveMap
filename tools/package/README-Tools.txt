LiveMap Tools - regenerate the map data after a game update
===========================================================

Optional. The LiveMap mod already ships with pre-extracted data; you only need these tools if a
game update changed the world (items missing / in the wrong place) and no updated LiveMap
release is available yet.

Contents
  WorldExtract.exe      reads the game files (built on CUE4Parse, self-contained, no .NET needed)
  UpdateWorldData.bat   runs WorldExtract for you
  loc_terms.txt         extra English terms to translate (region names etc.)

How to use
  1. Extract this zip into your LiveMap mod folder, so that you get
       ...\ue4ss\Mods\LiveMap\tools\UpdateWorldData.bat
  2. Start the game with UE4SS and press Ctrl+Numpad6 once
     (UE4SS writes a .usmap mappings file into the ue4ss folder).
  3. Double-click tools\UpdateWorldData.bat and wait about a minute.
     It rewrites LiveMap\Scripts\world_L_World.lua and LiveMap\Scripts\names.lua.
  4. Restart the game.

Source code and licenses: https://github.com/weisuoyuzai/RSDragonwilds-LiveMap
WorldExtract uses CUE4Parse (Apache-2.0), see CUE4Parse-LICENSE.txt / CUE4Parse-NOTICE.txt.


LiveMap 工具 —— 游戏更新后重新生成地图数据
==========================================

可选。LiveMap 模组本身已经带了提取好的数据；只有游戏更新后地图物品缺失或位置不对、
而 LiveMap 还没发布新版时，才需要用这些工具。

内容
  WorldExtract.exe      读取游戏资源（基于 CUE4Parse，自带运行时，不需要安装 .NET）
  UpdateWorldData.bat   帮你运行 WorldExtract
  loc_terms.txt         额外需要翻译的英文术语（地区名等）

用法
  1. 把这个压缩包解压到 LiveMap 模组文件夹里，得到
       ...\ue4ss\Mods\LiveMap\tools\UpdateWorldData.bat
  2. 装着 UE4SS 启动游戏，按一次 Ctrl+小键盘6（UE4SS 会在 ue4ss 目录生成 .usmap 映射文件）。
  3. 双击 tools\UpdateWorldData.bat，等约 1 分钟。
     它会重写 LiveMap\Scripts\world_L_World.lua 和 LiveMap\Scripts\names.lua。
  4. 重启游戏。

源码和许可证：https://github.com/weisuoyuzai/RSDragonwilds-LiveMap
WorldExtract 使用 CUE4Parse（Apache-2.0 许可），见 CUE4Parse-LICENSE.txt / CUE4Parse-NOTICE.txt。
