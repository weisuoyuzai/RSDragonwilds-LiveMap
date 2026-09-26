// 从游戏资源里离线提取 L_World 所有 World Partition 格子里的 Actor (类名, 父类链, 坐标)
// 用法: WorldExtract <Paks目录> <mappings.usmap> <输出目录> [LiveMap 的 config.lua] [只处理前 N 个格子]
using System.Text;
using CUE4Parse.FileProvider;
using CUE4Parse.UE4.Assets;
using CUE4Parse.MappingsProvider.Usmap;
using CUE4Parse.UE4.Assets.Exports;
using CUE4Parse.UE4.Objects.Core.Math;
using CUE4Parse.UE4.Objects.UObject;
using CUE4Parse.UE4.Versions;

// 图标模式: WorldExtract icons <Paks目录> <mappings.usmap> <名单文件 (每行: 名字<TAB>资源路径)> <输出目录> <尺寸>
var iconMode = args[0] == "icons";
if (iconMode) args = args[1..];
var pakDir = args[0];
var usmap = args[1];
var outDir = args[2];
if (!iconMode) Directory.CreateDirectory(outDir);

var provider = new DefaultFileProvider(pakDir, SearchOption.TopDirectoryOnly, new VersionContainer(EGame.GAME_UE5_6), StringComparer.OrdinalIgnoreCase);
provider.MappingsContainer = new FileUsmapTypeMappingsProvider(usmap);
provider.Initialize();
provider.Mount();
Console.Error.WriteLine($"files: {provider.Files.Count}");
if (iconMode)
{
    var names = File.ReadAllLines(args[2]).Select(l => l.Split('	')).Where(p => p.Length == 2)
        .ToDictionary(p => p[0], p => p[1]);
    IconExport.Run(provider, names, args[3], int.Parse(args[4]));
    return;
}

var mappings = provider.MappingsForGame!;
var superCache = new Dictionary<string, List<string>>();

// 类的父类链 (蓝图类加载类对象取 SuperStruct; 原生类用 mappings 里的 SuperType)
List<string> Chain(ResolvedObject? cls)
{
    var result = new List<string>();
    if (cls == null) return result;
    var name = cls.Name.Text;
    if (superCache.TryGetValue(name, out var cached)) return cached;
    result.Add(name);
    try
    {
        if (cls.Load() is UStruct st && st.SuperStruct is { IsNull: false } sup)
            result.AddRange(Chain(sup.ResolvedObject));
        else
        {
            var n = name;
            while (mappings.Types.TryGetValue(n, out var t) && !string.IsNullOrEmpty(t.SuperType))
            {
                n = t.SuperType!;
                result.Add(n);
            }
        }
    }
    catch { }
    superCache[name] = result;
    return result;
}

var cells = provider.Files.Keys
    .Where(k => k.EndsWith(".umap", StringComparison.OrdinalIgnoreCase) && k.Contains("/Maps/World/L_World", StringComparison.OrdinalIgnoreCase))
    .OrderBy(k => k).ToList();
if (args.Length > 4) cells = cells.Take(int.Parse(args[4])).ToList();
Console.Error.WriteLine($"cells: {cells.Count}");

// 只要玩法相关的 Actor: 父类链里含下面任一类
var roots = new HashSet<string> { "WorldActor", "AISpawnPoint", "WorldChest", "FishingNodeV2", "AnimaVent", "Graveyard",
    "AgilityCourseStarter", "KebbitBurrow", "WorldLodestone", "InteractableNPC", "HealthShrine", "OreNode" };
// 再加上 LiveMap 配置里各分类 classes 列出的类名, 这样直接继承 Actor 的类 (例如 BP_DK_VautEntrance_C) 也能提取到
if (args.Length > 3 && File.Exists(args[3]))
{
    var cfg = File.ReadAllText(args[3]);
    foreach (System.Text.RegularExpressions.Match block in System.Text.RegularExpressions.Regex.Matches(cfg, @"classes\s*=\s*\{([^}]*)\}"))
        foreach (System.Text.RegularExpressions.Match m in System.Text.RegularExpressions.Regex.Matches(block.Groups[1].Value, "\"([A-Za-z0-9_]+)\""))
            roots.Add(m.Groups[1].Value);
    Console.Error.WriteLine($"roots: {roots.Count}");
}
string LuaStr(string v) => "\"" + v.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
var lua = new StringBuilder("-- 由 WorldExtract 从游戏资源生成的全地图物体数据, 游戏更新后重新生成\nreturn {\n  actors = {\n");
var usedClasses = new HashSet<string>();
var actors = new StringBuilder();
var classCount = new Dictionary<string, int>();
int done = 0, failed = 0, total = 0;
foreach (var cell in cells)
{
    try
    {
        var pkg = provider.LoadPackage(cell);
        foreach (var lazy in pkg.ExportsLazy)
        {
            var exp = lazy.Value;
            if (!exp.TryGetValue(out FPackageIndex root, "RootComponent") || root.IsNull) continue;
            // 只要关卡里的顶层 Actor
            if (exp.Outer == null || exp.Outer.Name.Text != "PersistentLevel") continue;
            FVector loc = default;
            var rootObj = root.Load();
            if (rootObj != null) loc = rootObj.GetOrDefault<FVector>("RelativeLocation");
            var chain = Chain(exp.Class);
            var cls = chain.Count > 0 ? chain[0] : exp.ExportType;
            classCount[cls] = classCount.GetValueOrDefault(cls) + 1;
            var extra = "";
            if (exp.TryGetValue(out FPackageIndex data, "AnimaVentData") && !data.IsNull) extra = data.Name;
            if (chain.Any(roots.Contains))
            {
                usedClasses.Add(cls);
                lua.Append("    {").Append(LuaStr(cls)).Append(',').Append(loc.X.ToString("F0")).Append(',').Append(loc.Y.ToString("F0"))
                    .Append(',').Append(loc.Z.ToString("F0")).Append(extra.Length > 0 ? "," + LuaStr(extra) : "").Append("},\n");
            }
            actors.Append(cls).Append('\t').Append(loc.X.ToString("F0")).Append('\t').Append(loc.Y.ToString("F0")).Append('\t')
                .Append(loc.Z.ToString("F0")).Append('\t').Append(extra).Append('\t').Append(exp.Name).Append('\n');
            total++;
        }
    }
    catch (Exception e)
    {
        if (failed++ < 5) Console.Error.WriteLine($"FAIL {cell}: {e.GetType().Name} {e.Message}");
    }
    if (++done % 100 == 0) Console.Error.WriteLine($"{done}/{cells.Count} actors={total}");
}

File.WriteAllText(Path.Combine(outDir, "actors.tsv"), actors.ToString());
lua.Append("  },\n  classes = {\n");
foreach (var c in usedClasses.OrderBy(c => c))
    lua.Append("    [").Append(LuaStr(c)).Append("] = {").Append(string.Join(",", superCache[c].Select(LuaStr))).Append("},\n");
lua.Append("  },\n}\n");
File.WriteAllText(Path.Combine(outDir, "world_L_World.lua"), lua.ToString());
Console.Error.WriteLine($"lua: {usedClasses.Count} classes");
var classes = new StringBuilder();
foreach (var (cls, n) in classCount.OrderByDescending(p => p.Value))
    classes.Append(n).Append('\t').Append(string.Join(" < ", superCache.GetValueOrDefault(cls) ?? [cls])).Append('\n');
File.WriteAllText(Path.Combine(outDir, "classes.tsv"), classes.ToString());
Console.Error.WriteLine($"done cells={done} failed={failed} actors={total} classes={classCount.Count}");
