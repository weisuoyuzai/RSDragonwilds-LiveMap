# RSDragonwilds LiveMap（龙之荒野实时地图）

[English](README.md)

一个给 **RuneScape: Dragonwilds（符文世界：龙之荒野）** 用的 [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua 模组，
玩游戏时在浏览器里打开一张实时地图（`http://localhost:8765/`）。

- 在游戏自带的世界地图上显示你和队友的位置、朝向、移动轨迹
- 中英文界面，物品/怪物/地区使用游戏官方译名；每个图层可展开细分
- **全地图**的传送石、灵元泉（按符文类型显示图标）、符文精华泉、宝箱、传送门/宝库入口、神殿、复活墓地、
  敏捷赛道/兔子地道、矿点、钓鱼点、传说物品、NPC —— 约 1.4 万个点，使用游戏自己的图标
- 石料、采集物、怪物刷新点、附近生物作为可选图层
- 你自己建的床/箱子、死亡墓碑、当前任务目标（游戏里实时扫描）

游戏用 World Partition 流式加载，内存里只有附近的物体，所以本模组附带了**离线从游戏资源里提取的全地图数据**，
游戏里的实时扫描只负责补充附近的动态物品。

## 安装（玩家）

1. 在 `<游戏目录>/RSDragonwilds/Binaries/Win64/` 安装支持虚幻 5.6 的 UE4SS **experimental** 版本（测试版本 v3.0.1-1142）。
2. 从 [Releases](../../releases) 下载 `LiveMap-RSDragonwilds-<版本>.zip`，把里面的 `LiveMap` 文件夹复制到
   `<游戏目录>/RSDragonwilds/Binaries/Win64/ue4ss/Mods/`。
3. 启动游戏，浏览器会自动打开地图。

完整说明见 [packaging/使用说明.txt](packaging/使用说明.txt)（英文版 [packaging/README.txt](packaging/README.txt)），发布的压缩包里也带着。

## 目录结构

| 路径 | 内容 |
|---|---|
| `mod/LiveMap/` | 模组源码：`Scripts/*.lua`（UE4SS Lua）、`web/index.html`（地图网页）、`server.ps1`（本地网页服务器） |
| `data/` | 从游戏提取的数据，打包时合并进模组：全地图物体（`Scripts/world_L_World.lua`）、来自游戏语言包的官方中英文名称（`Scripts/names.lua`）、图标路径表、地图底图、838 张图标 |
| `tools/package/` | 可选工具包里的文件（`UpdateWorldData.bat`、术语清单、说明） |
| `tools/WorldExtract/` | 基于 [CUE4Parse](https://github.com/FabianFG/CUE4Parse) 的 .NET 10 提取工具：World Partition 物体 → Lua 数据，贴图 → PNG 图标 |
| `external/CUE4Parse/` | CUE4Parse 子模块（固定版本） |
| `scripts/` | `build_package.py`（打包 / 开发安装）、`update_data.ps1`（重新生成 `data/`）、IoStore `.utoc` 目录读取 |
| `tests/` | 离线测试：用 Lua 5.4（`lupa`）在模拟的 UE4SS 接口上跑 `main.lua` |
| `packaging/` | 打进压缩包的玩家说明 |

## 开发

需要：Windows、游戏本体、UE4SS experimental、Python 3、.NET 10 SDK（提取工具）、Node.js（测试）。

```powershell
git clone --recurse-submodules https://github.com/<你>/RSDragonwilds-LiveMap
git config core.longpaths true            # CUE4Parse 里有很长的测试文件路径

# 测试
python -m pip install lupa
python tests/run_tests.py

# 把模组（源码 + 数据）装进游戏测试
python scripts/build_package.py --install "<游戏目录>\RSDragonwilds\Binaries\Win64\ue4ss\Mods"

# 本地打发布包（可带上提取工具）
dotnet publish tools/WorldExtract/WorldExtract.csproj -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o build/tools
python scripts/build_package.py --version v1.0.0 --tools-dir build/tools
```

### 游戏更新后更新数据

1. 游戏里（装着 UE4SS）按一次 **Ctrl+小键盘6**，生成 `.usmap` 映射文件。
2. `pwsh scripts/update_data.ps1 -GameDir "<游戏目录>"` —— 重新生成 `data/` 里的图标路径表、全地图数据、官方名称和图标。
3. 如果世界地图变了：删掉 `data/web/data/map_*.png` 和 `maps_*.json/.lua`，安装模组后在游戏里打开一次大地图（模组会导出），
   再把模组 `web/data/` 里的新文件复制回 `data/web/data/`。
4. `python tests/run_tests.py`，提交。

玩家也可以用可选的工具包（`LiveMap-Tools-<版本>.zip`：`WorldExtract.exe` + `UpdateWorldData.bat`，源文件在 `tools/package/`）自己更新数据。工具包单独下载，模组压缩包里不含任何可执行文件（符合 Nexus Mods 要求）。

## CI / 发布

- **CI**（`.github/workflows/ci.yml`）：每次推送/PR 跑离线测试（Lua 编译、模拟运行、网页和服务器脚本语法），并编译提取工具。
- **发布**（`.github/workflows/release.yml`）：推送 `v1.0.0` 这样的标签 → 测试，然后在 GitHub Release 上发布两个压缩包：
  `LiveMap-RSDragonwilds-v1.0.0.zip`（模组本体，不含可执行文件，上传 Nexus Mods 用这个）和
  `LiveMap-Tools-v1.0.0.zip`（自带运行时的 `WorldExtract.exe` + `UpdateWorldData.bat`）。手动运行只上传构建产物。

## 许可

源码采用 MIT（见 [LICENSE](LICENSE)）。`data/` 里的文件提取自 RuneScape: Dragonwilds，游戏美术和数据归其所有者，
不在本许可范围内。CUE4Parse 为 Apache-2.0，UE4SS 为 MIT。本项目为非官方同人工具，与 Jagex 无关。
