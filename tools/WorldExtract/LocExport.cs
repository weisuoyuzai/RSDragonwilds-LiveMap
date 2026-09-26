// 官方中英文名称: 从游戏的 ItemData / JournalEntry 资源和语言包 (Game.locres) 提取
//   icons     图标名 -> {英文, 中文}           例: T_Icon_Rune_Law -> Law Rune / 律法符文
//   creatures 怪物数据类核心名 -> {英文, 中文, 图鉴头像}  例: BP_AI_Cow_Data -> Cow / 奶牛
//   ainames   怪物名字符串表 (ST_AI_Names*) 键 -> {英文, 中文}  例: GiantRat -> Giant Rat / 巨鼠
//   terms     指定的英文术语 -> 中文 (地区名等), 按英文原文在语言包里反查
using System.Text;
using CUE4Parse.FileProvider;
using CUE4Parse.UE4.Assets.Exports.Internationalization;
using CUE4Parse.UE4.Assets.Objects;
using CUE4Parse.UE4.Localization;
using CUE4Parse.UE4.Objects.Core.i18N;
using CUE4Parse.UE4.Objects.UObject;

public static class LocExport
{
    const string LocDir = "RSDragonwilds/Content/Localization/Game/";

    static Dictionary<(string, string), string> ReadLocres(IFileProvider provider, string culture)
    {
        var res = new FTextLocalizationResource(provider.CreateReader(LocDir + culture + "/Game.locres"));
        var d = new Dictionary<(string, string), string>();
        foreach (var (ns, keys) in res.Entries)
            foreach (var (key, entry) in keys)
                d[(ns.Str, key.Str)] = entry.LocalizedString;
        return d;
    }

    static string Lua(string s) => "\"" + s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "").Replace("\n", "\\n") + "\"";

    public static void Run(IFileProvider provider, string outLua, IEnumerable<string> terms)
    {
        var en = ReadLocres(provider, "en");
        var zh = ReadLocres(provider, "zh-CN");
        Console.Error.WriteLine($"locres en={en.Count} zh-CN={zh.Count}");

        // 字符串表 (ST_*) 的命名空间和原文, 按资源路径缓存
        var tables = new Dictionary<string, FStringTable?>(StringComparer.OrdinalIgnoreCase);
        FStringTable? Table(string tableId)
        {
            if (tables.TryGetValue(tableId, out var t)) return t;
            try { t = provider.LoadPackageObject<UStringTable>(tableId).StringTable; }
            catch { t = null; }
            return tables[tableId] = t;
        }

        (string en, string zh)? Translate(FText? text)
        {
            string ns, key, source;
            switch (text?.TextHistory)
            {
                case FTextHistory.Base b:
                    (ns, key, source) = (b.Namespace, b.Key, b.SourceString);
                    break;
                case FTextHistory.StringTableEntry st:
                    var table = Table(st.TableId.Text);
                    if (table == null) return null;
                    (ns, key) = (table.TableNamespace, st.Key);
                    source = table.KeysToEntries.GetValueOrDefault(st.Key) ?? "";
                    break;
                default:
                    return null;
            }
            var e = en.GetValueOrDefault((ns, key)) ?? source;
            if (string.IsNullOrWhiteSpace(e)) return null;
            var z = zh.GetValueOrDefault((ns, key)) ?? e;
            return (e.Trim(), z.Trim());
        }

        // 递归遍历属性 (结构体/数组里的也算)
        void Walk(string name, object? v, Action<string, object> visit, int depth = 0)
        {
            if (v == null || depth > 6) return;
            visit(name, v);
            switch (v)
            {
                case FScriptStruct ss: Walk(name, ss.StructType, visit, depth + 1); break;
                case FStructFallback sf:
                    foreach (var p in sf.Properties) Walk(p.Name.Text, p.Tag?.GenericValue, visit, depth + 1);
                    break;
                case UScriptArray arr:
                    foreach (var p in arr.Properties) Walk(name, p.GenericValue, visit, depth + 1);
                    break;
            }
        }

        var icons = new SortedDictionary<string, (string en, string zh)>(StringComparer.Ordinal);
        var creatures = new SortedDictionary<string, (string en, string zh, string icon)>(StringComparer.Ordinal);
        int scanned = 0, failed = 0;
        var files = provider.Files.Keys.Where(k => k.EndsWith(".uasset", StringComparison.OrdinalIgnoreCase))
            .Where(k => { var n = k[(k.LastIndexOf('/') + 1)..]; return n.StartsWith("ITEM_") || n.StartsWith("JOURNAL_"); })
            .OrderBy(k => k).ToList();
        foreach (var file in files)
        {
            try
            {
                var exp = provider.LoadPackage(file).GetExports().FirstOrDefault();
                if (exp == null) continue;
                scanned++;
                FText? name = null;
                string? icon = null, ai = null;
                // 名称只取顶层的 DisplayName/Name; 图标和怪物数据类可能嵌在结构体里
                foreach (var prop in exp.Properties)
                {
                    var pn = prop.Name.Text;
                    if (name == null && prop.Tag?.GenericValue is FText t && (pn == "DisplayName" || pn == "Name")) name = t;
                    Walk(pn, prop.Tag?.GenericValue, (_, v) =>
                    {
                        if (v is not FSoftObjectPath sp) return;
                        var path = sp.AssetPathName.Text;
                        var last = path[(path.LastIndexOf('/') + 1)..].Split('.')[0];
                        if (icon == null && last.StartsWith("T_Icon")) icon = last;
                        if (ai == null && last.StartsWith("BP_AI_") && last.EndsWith("_Data")) ai = last[6..^5];
                    });
                }
                var tr = Translate(name);
                if (tr == null) continue;
                if (icon != null && !icons.ContainsKey(icon)) icons[icon] = tr.Value;
                if (ai != null && !creatures.ContainsKey(ai)) creatures[ai] = (tr.Value.en, tr.Value.zh, icon ?? "");
            }
            catch (Exception e)
            {
                if (failed++ < 5) Console.Error.WriteLine($"loc FAIL {file}: {e.Message}");
            }
        }

        // 怪物数据类 BP_AI_<core>_Data 的默认对象里有 AIName (指向怪物名字符串表), 覆盖全部怪物
        // (跳过父类 BP_AI_Data 本身: 去掉前后缀后是空的)
        foreach (var file in provider.Files.Keys.Where(k => { var n = k[(k.LastIndexOf('/') + 1)..]; return n.StartsWith("BP_AI_") && n.EndsWith("_Data.uasset") && n.Length > "BP_AI__Data.uasset".Length; }))
        {
            try
            {
                var core = file[(file.LastIndexOf('/') + 1)..][6..^"_Data.uasset".Length];
                if (creatures.ContainsKey(core)) continue;
                var cdo = provider.LoadPackage(file).GetExports().FirstOrDefault(e => e.Name.StartsWith("Default__"));
                if (cdo != null && cdo.TryGetValue(out FText aiName, "AIName") && Translate(aiName) is { } tr)
                    creatures[core] = (tr.en, tr.zh, "");
            }
            catch (Exception ex) { if (failed++ < 10) Console.Error.WriteLine($"ai data FAIL {file}: {ex.Message}"); }
        }

        // 怪物名字符串表 (ST_AI_Names*, 本体和各 DLC 各一张): 键 -> {英文, 中文}
        var aiNames = new SortedDictionary<string, (string en, string zh)>(StringComparer.Ordinal);
        foreach (var file in provider.Files.Keys.Where(k => k[(k.LastIndexOf('/') + 1)..].StartsWith("ST_AI_Names") && k.EndsWith(".uasset")))
        {
            try
            {
                var st = provider.LoadPackage(file).GetExports().OfType<UStringTable>().First().StringTable;
                foreach (var (key, source) in st.KeysToEntries)
                {
                    var e = en.GetValueOrDefault((st.TableNamespace, key)) ?? source;
                    aiNames.TryAdd(key, (e.Trim(), (zh.GetValueOrDefault((st.TableNamespace, key)) ?? e).Trim()));
                }
            }
            catch (Exception ex) { Console.Error.WriteLine($"string table FAIL {file}: {ex.Message}"); }
        }

        // 术语: 英文原文 -> 中文
        var byEnglish = new Dictionary<string, (string, string)>(StringComparer.Ordinal);
        foreach (var (k, v) in en) byEnglish.TryAdd(v.Trim(), k);
        var termMap = new SortedDictionary<string, string>(StringComparer.Ordinal);
        foreach (var term in terms)
            if (byEnglish.TryGetValue(term, out var k) && zh.TryGetValue(k, out var z)) termMap[term] = z.Trim();

        var sb = new StringBuilder("-- 由 WorldExtract loc 从游戏资源和语言包生成的官方中英文名称, 游戏更新后重新生成\nreturn {\n  icons = {\n");
        foreach (var (k, v) in icons) sb.Append("    [").Append(Lua(k)).Append("] = { ").Append(Lua(v.en)).Append(", ").Append(Lua(v.zh)).Append(" },\n");
        sb.Append("  },\n  creatures = {\n");
        foreach (var (k, v) in creatures)
            sb.Append("    [").Append(Lua(k)).Append("] = { ").Append(Lua(v.en)).Append(", ").Append(Lua(v.zh)).Append(", ").Append(Lua(v.icon)).Append(" },\n");
        sb.Append("  },\n  ainames = {\n");
        foreach (var (k, v) in aiNames) sb.Append("    [").Append(Lua(k)).Append("] = { ").Append(Lua(v.en)).Append(", ").Append(Lua(v.zh)).Append(" },\n");
        sb.Append("  },\n  terms = {\n");
        foreach (var (k, v) in termMap) sb.Append("    [").Append(Lua(k)).Append("] = ").Append(Lua(v)).Append(",\n");
        sb.Append("  },\n}\n");
        File.WriteAllText(outLua, sb.ToString());
        Console.Error.WriteLine($"assets scanned={scanned} failed={failed} icons={icons.Count} creatures={creatures.Count} ainames={aiNames.Count} terms={termMap.Count}");
    }
}
