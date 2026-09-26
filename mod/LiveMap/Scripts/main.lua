-- LiveMap: 把玩家和世界物品的位置实时写到 web/data/*.json, 由本地 PowerShell 服务器提供给浏览器地图页面

local MOD = "[LiveMap] "

local function log(fmt, ...)
    print(MOD .. string.format(fmt, ...) .. "\n")
end

------------------------------------------------------------------------
-- 路径
------------------------------------------------------------------------
local function fileExists(p)
    local f = io.open(p, "rb")
    if f then f:close() return true end
    return false
end

local function getModDir()
    -- 优先用脚本自身的路径
    local ok, src = pcall(function() return debug.getinfo(1, "S").source end)
    if ok and src then
        src = src:gsub("^@", ""):gsub("/", "\\")
        local dir = src:match("^(.*\\)Scripts\\[^\\]*$")
        if dir and dir:find(":") then return dir end
    end
    -- 兜底: 新版 UE4SS 在 Win64\ue4ss\Mods, 旧版在 Win64\Mods
    local ok2, win64 = pcall(function() return IterateGameDirectories().Game.Binaries.Win64.__absolute_path end)
    if ok2 and type(win64) == "string" then
        for _, sub in ipairs({ "\\ue4ss\\Mods\\LiveMap\\", "\\Mods\\LiveMap\\" }) do
            if fileExists(win64 .. sub .. "Scripts\\config.lua") then return win64 .. sub end
        end
    end
    return ".\\ue4ss\\Mods\\LiveMap\\"
end

local ModDir = getModDir()
local WebDir = ModDir .. "web\\"
local DataDir = WebDir .. "data\\"
local SavePath = ModDir .. "saved_pois.lua"

local Config = dofile(ModDir .. "Scripts\\config.lua")

------------------------------------------------------------------------
-- JSON 编码
------------------------------------------------------------------------
local function jsonStr(s)
    -- 只转义 ASCII 控制字符 (0-31). 不能用 %c: 它依赖系统区域设置, 在西文系统上会把 UTF-8 中文的某些字节当成控制字符
    return '"' .. tostring(s):gsub('[\0-\31"\\]', function(c)
        if c == '"' then return '\\"' end
        if c == "\\" then return "\\\\" end
        if c == "\n" then return "\\n" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end

local function jsonEncode(v)
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return tostring(v) end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "0" end
        if math.type and math.type(v) == "integer" then return tostring(v) end
        return string.format("%.1f", v)
    end
    if t == "string" then return jsonStr(v) end
    if t == "table" then
        local parts = {}
        if #v > 0 or next(v) == nil then
            for i = 1, #v do parts[i] = jsonEncode(v[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        for k, val in pairs(v) do
            parts[#parts + 1] = jsonStr(k) .. ":" .. jsonEncode(val)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

local function writeFile(path, content)
    local tmp = path .. ".tmp"
    local f = io.open(tmp, "wb")
    if not f then return false end
    f:write(content)
    f:close()
    os.remove(path)
    return os.rename(tmp, path)
end

------------------------------------------------------------------------
-- UObject 辅助 (全部用 pcall 包住, 对象随时可能失效)
------------------------------------------------------------------------
local function valid(o)
    if not o then return false end
    local ok, r = pcall(function() return o:IsValid() end)
    return ok and r
end

local function className(o)
    local ok, n = pcall(function() return o:GetClass():GetFName():ToString() end)
    return ok and n or nil
end

local function location(o)
    local ok, x, y, z = pcall(function()
        local l = o:K2_GetActorLocation()
        return l.X, l.Y, l.Z
    end)
    if ok and x then return x, y, z end
end

local function yaw(o)
    local ok, r = pcall(function() return o:K2_GetActorRotation().Yaw end)
    return ok and r or 0
end

local function worldName(o)
    local ok, n = pcall(function() return o:GetWorld():GetFName():ToString() end)
    return ok and n or "World"
end

local function toLuaString(v)
    if type(v) == "string" then return v end
    local ok, s = pcall(function() return v:ToString() end)
    return ok and s or ""
end

local function playerName(pawn)
    local ok, n = pcall(function()
        local ps = pawn.PlayerState
        if not valid(ps) then return "" end
        return toLuaString(ps:GetPlayerName())
    end)
    return ok and n or ""
end

local function isPlayerControlled(pawn)
    local ok, r = pcall(function() return pawn:IsPlayerControlled() end)
    return ok and r
end

------------------------------------------------------------------------
-- 状态
------------------------------------------------------------------------
local ScanQueue = {}          -- { {class=, cat=}, ... } 轮流扫描
local CatOfClass = {}         -- 类名 -> 分类 (同一个类出现在多个分类时取第一个)
for _, cat in ipairs(Config.Categories) do
    for _, cls in ipairs(cat.classes or {}) do
        if not CatOfClass[cls] then
            CatOfClass[cls] = cat.id
            ScanQueue[#ScanQueue + 1] = { class = cls, cat = cat.id }
        end
    end
end
local ScanIndex = 0

local Pois = {}               -- Pois[world][key] = {c,n,x,y,z,t}
local PoiVersion = 1
local PoiDirty = true
local SaveDirty = false
local LastPoiWrite = 0
local LastSave = os.time()

local Creatures = {}
local LastCreatureScan = 0
local CurrentWorld = "World"
local Trail = {}

local Icons = dofile(ModDir .. "Scripts\\icons.lua")
do
    local catDefaults = {}
    for _, c in ipairs(Config.Categories) do catDefaults[c.id] = c.icon end
    Icons.init({ dataDir = DataDir, valid = valid, log = log, config = Config, catDefaults = catDefaults,
        paths = dofile(ModDir .. "Scripts\\icon_paths.lua") })
end
local LastIconVersion = -1
local LastIconProcess = 0

local function writeCategories()
    local cats = {}
    for i, c in ipairs(Config.Categories) do
        cats[i] = { id = c.id, label = c.label, color = c.color, icon = c.icon, hidden = c.hidden or false }
        Icons.request(c.icon)
    end
    writeFile(DataDir .. "categories.json", jsonEncode(cats))
    Icons.request("T_NavIcons_Player_Self")
    Icons.request("T_Map_Icon_FriendArrow_1")
end

------------------------------------------------------------------------
-- 全地图数据 (Scripts/world_<世界>.lua, 由 tools/WorldExtract 从游戏资源提取)
------------------------------------------------------------------------
-- 游戏地图标记里跟全地图数据重复的 (地牢入口/神殿/敏捷赛道/兔子地道) 以及玩家自己/占位图标, 不显示
local SKIP_MARKERS = { T_NavIcons_Player_Self = true, T_Icon_Placeholder = true }
local function skipMarker(name)
    return SKIP_MARKERS[name] or name:find("Friend") or name:find("Player")
        or name:find("DungeonEntrance") or name:find("HealthAltar")
        or name:find("Agility") or name:find("Kebbit") or name:find("Lodestone")
end

local WorldData = {}          -- [world] = { static = { [key] = poi }, classes = { [cls] = 父类链 } }
local StaticVersion = 0
local ClassCatCache = {}

-- 按父类链分类: 链上离物体最近的、在某个分类 classes 里的类决定分类
local function classify(cls, chains, fallback)
    local cached = ClassCatCache[cls]
    if cached ~= nil then return cached or fallback end
    local chain = chains and chains[cls]
    local cat = false
    if chain then
        for _, n in ipairs(chain) do
            if CatOfClass[n] then cat = CatOfClass[n] break end
        end
        ClassCatCache[cls] = cat
    else
        cat = CatOfClass[cls] or false
    end
    return cat or fallback
end

local function poiKey(name, x, y, z)
    -- 按类名 + 1 米网格去重, 这样跨会话/重新加载/离线数据都能对上
    return string.format("%s|%d|%d|%d", name, math.floor(x / 100 + 0.5), math.floor(y / 100 + 0.5), math.floor(z / 100 + 0.5))
end

-- 同类物体 5 米内算同一个 (游戏里读到的坐标和资源里的根组件坐标可能差一点)
local GRID = 500
local function gridKey(cls, gx, gy) return cls .. "|" .. gx .. "|" .. gy end
local function nearStatic(wd, cls, x, y)
    local gx, gy = math.floor(x / GRID), math.floor(y / GRID)
    for dx = -1, 1 do
        for dy = -1, 1 do
            local list = wd.grid[gridKey(cls, gx + dx, gy + dy)]
            if list then
                for _, e in ipairs(list) do
                    if (e.x - x) ^ 2 + (e.y - y) ^ 2 < GRID * GRID then return true end
                end
            end
        end
    end
    return false
end

local function loadWorldData(world)
    local wd = { static = {}, classes = {}, grid = {} }
    WorldData[world] = wd
    local ok, data = pcall(dofile, ModDir .. "Scripts\\world_" .. world .. ".lua")
    if not ok or type(data) ~= "table" then return end
    wd.classes = data.classes or {}
    local arr = {}
    for _, a in ipairs(data.actors or {}) do
        local cls, x, y, z, extra = a[1], a[2], a[3], a[4], a[5]
        local cat = classify(cls, wd.classes)
        if cat then
            local icon, label = Icons.resolve(nil, cls, cat, extra)
            local e = { c = cat, n = cls, x = x, y = y, z = z, i = icon, l = label }
            wd.static[poiKey(cls, x, y, z)] = e
            local gk = gridKey(cls, math.floor(x / GRID), math.floor(y / GRID))
            wd.grid[gk] = wd.grid[gk] or {}
            table.insert(wd.grid[gk], e)
            arr[#arr + 1] = e
            Icons.request(icon)
        end
    end
    -- 以前记录下来的点, 全地图数据里已有的就不用再单独记了
    -- 其余的按新规则重新分类
    if Pois[world] then
        for k, p in pairs(Pois[world]) do
            if wd.static[k] or (p.c ~= "landmark" and nearStatic(wd, p.n, p.x, p.y)) then
                Pois[world][k] = nil
            elseif p.c ~= "landmark" then
                p.c = classify(p.n, wd.classes, p.c)
                p.i, p.l = Icons.resolve(nil, p.n, p.c)
            end
        end
        SaveDirty = true
        PoiDirty = true
    end
    StaticVersion = StaticVersion + 1
    writeFile(DataDir .. "static_" .. world .. ".json", jsonEncode({ version = StaticVersion, pois = arr }))
    log("全地图数据 %s: %d 个点", world, #arr)
end

local function loadSaved()
    if not Config.RememberPois then return end
    local ok, t = pcall(dofile, SavePath)
    if ok and type(t) == "table" then
        Pois = t
        for _, list in pairs(Pois) do
            for k, p in pairs(list) do
                if p.c == "landmark" then list[k] = nil end   -- 旧版本存下来的地图标记, 现在改为实时数据
            end
        end
        local n = 0
        for _, w in pairs(Pois) do for _ in pairs(w) do n = n + 1 end end
        log("载入已记录的 POI %d 个", n)
    end
end

local function savePois()
    if not Config.RememberPois then return end
    local out = { "return {\n" }
    for world, list in pairs(Pois) do
        out[#out + 1] = string.format("[%q]={\n", world)
        for key, p in pairs(list) do
            out[#out + 1] = string.format("[%q]={c=%q,n=%q,x=%.1f,y=%.1f,z=%.1f,t=%d%s%s},\n",
                key, p.c, p.n, p.x, p.y, p.z, p.t,
                p.i and string.format(",i=%q", p.i) or "", p.l and string.format(",l=%q", p.l) or "")
        end
        out[#out + 1] = "},\n"
    end
    out[#out + 1] = "}\n"
    writeFile(SavePath, table.concat(out))
end

-- keyName: 去重用的名字 (默认类名). 游戏地图标记的贴图会随状态变化, 用固定键避免同一位置出现重复点
local function addPoi(world, cat, cls, x, y, z, now, icon, label, keyName)
    Icons.request(icon)
    local key = poiKey(keyName or cls, x, y, z)
    local wd = WorldData[world]
    if wd and (wd.static[key] or (not keyName and nearStatic(wd, cls, x, y))) then return end
    Pois[world] = Pois[world] or {}
    local p = Pois[world][key]
    if not p then
        Pois[world][key] = { c = cat, n = cls, x = x, y = y, z = z, t = now, i = icon, l = label }
        PoiDirty = true
        SaveDirty = true
    else
        p.t = now
        p.c = cat
        if p.i ~= icon or p.l ~= label or p.n ~= cls then
            p.i, p.l, p.n = icon, label, cls
            PoiDirty = true
            SaveDirty = true
        end
    end
end

------------------------------------------------------------------------
-- 扫描
------------------------------------------------------------------------
local function scanNextClass(now)
    if #ScanQueue == 0 then return end
    ScanIndex = ScanIndex % #ScanQueue + 1
    local entry = ScanQueue[ScanIndex]
    local list = FindAllOf(entry.class)
    if not list then return end
    for _, a in pairs(list) do
        if valid(a) then
            local x, y, z = location(a)
            if x and not (x == 0 and y == 0 and z == 0) then
                local cls = className(a) or entry.class
                local world = worldName(a)
                local wd = WorldData[world]
                local cat = classify(cls, wd and wd.classes, entry.cat)
                local icon, label = Icons.resolve(a, cls, cat)
                addPoi(world, cat, cls, x, y, z, now, icon, label)
            end
        end
    end
end

local CharacterCache = {}

local function scanCharacters(refresh)
    local players, creatures = {}, {}
    if refresh then CharacterCache = FindAllOf("Character") or {} end
    for _, c in pairs(CharacterCache) do
        if valid(c) then
            local x, y, z = location(c)
            local cls = className(c) or "?"
            if x and not cls:find("Preview") then
                if isPlayerControlled(c) then
                    players[#players + 1] = { name = playerName(c), x = x, y = y, z = z, yaw = yaw(c), obj = c }
                elseif Config.ShowCreatures then
                    local cat = cls:find("^BP_NPC_") and "npc" or "creature"
                    local icon = Icons.resolve(nil, cls, cat)
                    Icons.request(icon)
                    creatures[#creatures + 1] = { c = cat, n = cls, x = x, y = y, z = z, i = icon }
                end
            end
        end
    end
    return players, creatures
end

-- 游戏大地图上自带的标记 (MinimapPlugin 的 MapIconComponent): 地牢入口/神殿/敏捷赛道/兔子地道等
local LastMarkerScan = 0
local Markers = {}            -- 游戏地图标记, 每次扫描整体替换 (会移动/变化, 不存档)

local function scanGameMarkers()
    local list = {}
    for _, c in ipairs(FindAllOf("MapIconComponent") or {}) do
        if valid(c) then
            local ok, owner = pcall(function() return c:GetOwner() end)
            local ownerCls = ok and valid(owner) and className(owner) or ""
            local tex = c.IconTexture
            if ownerCls == "MinimapPluginMapIcons" and valid(tex) then
                local name = tex:GetFName():ToString()
                local vis = true
                pcall(function() vis = c.bIconVisible end)
                if vis and not skipMarker(name) then
                    local l = c:K2_GetComponentLocation()
                    local path = tex:GetFullName():gsub("^%S+%s+", "")
                    Icons.addPath(name, path)
                    Icons.request(name)
                    list[#list + 1] = { c = "landmark", n = name, x = l.X, y = l.Y, z = l.Z, i = name }
                end
            end
        end
    end
    Markers = list
end

local LocalPC = nil

local function localPawn()
    if not valid(LocalPC) then
        LocalPC = nil
        for _, pc in pairs(FindAllOf("PlayerController") or {}) do
            if valid(pc) then
                local ok, isLocal = pcall(function() return pc:IsLocalController() end)
                if not ok or isLocal then LocalPC = pc break end
            end
        end
    end
    if LocalPC then
        local ok, pawn = pcall(function() return LocalPC.Pawn end)
        if ok and valid(pawn) then return pawn end
    end
end

------------------------------------------------------------------------
-- 游戏地图导出 (见 mapexport.lua)
------------------------------------------------------------------------
local MapExport = dofile(ModDir .. "Scripts\\mapexport.lua")
local MapState = {}          -- [world] = { entries = { [texName] = entry }, complete = bool }
local LastMapCheck = 0

local function serializeLua(v, indent)
    indent = indent or ""
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t ~= "table" then return tostring(v) end
    local parts = {}
    for k, x in pairs(v) do
        parts[#parts + 1] = indent .. "  [" .. serializeLua(k) .. "] = " .. serializeLua(x, indent .. "  ") .. ",\n"
    end
    return "{\n" .. table.concat(parts) .. indent .. "}"
end

local function updateMaps(me)
    local world = CurrentWorld
    if not me or world == "World" or world:find("FrontEnd") then return end
    local statePath = DataDir .. "maps_" .. world .. ".lua"
    local st = MapState[world]
    if not st then
        local ok, t = pcall(dofile, statePath)
        st = { entries = (ok and type(t) == "table") and t or {} }
        MapState[world] = st
    end
    if st.complete then return end

    local ctx = { world = world, dataDir = DataDir, worldContext = me, valid = valid, worldName = worldName, log = log }
    local items = MapExport.backgrounds(ctx)
    local changed, pending = false, 0
    for _, item in ipairs(items) do
        if not st.entries[item.key] then
            if MapExport.tryExport(ctx, item) then
                st.entries[item.key] = item.entry
                changed = true
            else
                pending = pending + 1
            end
        end
    end
    if changed then
        local arr = {}
        for _, e in pairs(st.entries) do arr[#arr + 1] = e end
        writeFile(DataDir .. "maps_" .. world .. ".json", jsonEncode(arr))
        writeFile(statePath, "return " .. serializeLua(st.entries) .. "\n")
    end
    if #items > 0 and pending == 0 then st.complete = true end
    if pending > 0 and not st.hinted then
        st.hinted = true
        log("有 %d 张地图贴图还没加载, 在游戏里打开一次大地图即可自动导出", pending)
    end
end

local Tick = 0
local function tick()
    Tick = Tick + 1
    local now = os.time()
    local clock = os.clock()

    local me = localPawn()
    if me then
        local w = worldName(me)
        if w ~= CurrentWorld then Trail = {} end -- 换地图(进地牢/回主菜单)时轨迹不再连着
        CurrentWorld = w
        if not WorldData[w] then
            local ok, err = pcall(loadWorldData, w)
            if not ok then log("全地图数据加载出错: %s", tostring(err)) end
        end
    end

    local refresh = clock - LastCreatureScan >= Config.CreatureIntervalMs / 1000
    if refresh then LastCreatureScan = clock end
    local players, creatures = scanCharacters(refresh)
    Creatures = creatures

    local out = {}
    for _, p in ipairs(players) do
        local isMe = me ~= nil and p.obj == me
        if not isMe and me then
            -- 同一个 UObject 在 Lua 里可能是不同的包装对象, 用坐标兜底比较
            local mx, my = location(me)
            isMe = mx ~= nil and math.abs(mx - p.x) < 1 and math.abs(my - p.y) < 1
        end
        out[#out + 1] = { name = p.name, x = p.x, y = p.y, z = p.z, yaw = p.yaw, me = isMe }
    end
    if me and #out == 0 then
        local x, y, z = location(me)
        if x then out[1] = { name = playerName(me), x = x, y = y, z = z, yaw = yaw(me), me = true } end
    end

    for _, p in ipairs(out) do
        if p.me and not (p.x == 0 and p.y == 0 and p.z == 0) then
            local last = Trail[#Trail]
            if not last or (p.x - last[1]) ^ 2 + (p.y - last[2]) ^ 2 > 300 ^ 2 then
                Trail[#Trail + 1] = { p.x, p.y }
                if #Trail > 2000 then table.remove(Trail, 1) end
            end
        end
    end

    scanNextClass(now)

    if Config.GameMapMarkers and me and clock - LastMarkerScan >= 10 then
        LastMarkerScan = clock
        local ok, err = pcall(scanGameMarkers)
        if not ok then log("地图标记扫描出错: %s", tostring(err)) end
    end

    if me and clock - LastIconProcess >= 1 then
        LastIconProcess = clock
        Icons.process(me, clock, 3)
    end
    if Icons.version() ~= LastIconVersion then
        LastIconVersion = Icons.version()
        writeFile(DataDir .. "icons.json", jsonEncode(Icons.exported()))
    end

    if clock - LastMapCheck >= 5 then
        LastMapCheck = clock
        local ok, err = pcall(updateMaps, me)
        if not ok then log("地图导出出错: %s", tostring(err)) end
    end

    -- 新增 POI 时尽快写; 否则每 10 秒刷新一次, 让网页知道哪些点仍在加载范围内
    if (PoiDirty and clock - LastPoiWrite > 2) or clock - LastPoiWrite > 10 then
        PoiDirty = false
        LastPoiWrite = clock
        PoiVersion = PoiVersion + 1
        local worlds = {}
        for w, list in pairs(Pois) do
            local arr = {}
            for _, p in pairs(list) do arr[#arr + 1] = p end
            worlds[w] = arr
        end
        writeFile(DataDir .. "pois.json", jsonEncode({ version = PoiVersion, worlds = worlds }))
    end

    local trail = {}
    for i, t in ipairs(Trail) do trail[i] = { math.floor(t[1]), math.floor(t[2]) } end
    writeFile(DataDir .. "live.json", jsonEncode({
        time = now,
        world = CurrentWorld,
        poiVersion = PoiVersion,
        iconVersion = LastIconVersion,
        staticVersion = StaticVersion,
        cycleSeconds = math.ceil(#ScanQueue * Config.LiveIntervalMs / 1000),
        players = out,
        creatures = Creatures,
        markers = Markers,
        trail = trail,
    }))

    if SaveDirty and now - LastSave > 30 then
        SaveDirty = false
        LastSave = now
        savePois()
    end
end

------------------------------------------------------------------------
-- 服务器 / 浏览器
------------------------------------------------------------------------
local function launchServer()
    local cmd = string.format(
        'start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%sserver.ps1" -Port %d -Root "%s" -Open',
        ModDir, Config.Port, WebDir:sub(1, -2))
    log("启动地图服务器: http://localhost:%d/", Config.Port)
    os.execute(cmd)
end

local function dumpClasses()
    local list = FindAllOf("Actor") or {}
    local counts, sample = {}, {}
    for _, a in pairs(list) do
        local cls = className(a)
        if cls then
            counts[cls] = (counts[cls] or 0) + 1
            if not sample[cls] then
                local x, y, z = location(a)
                if x then sample[cls] = string.format("%.0f, %.0f, %.0f", x, y, z) end
            end
        end
    end
    local names = {}
    for k in pairs(counts) do names[#names + 1] = k end
    table.sort(names)
    local lines = { string.format("# %d 个 Actor, %d 个类  (类名  数量  示例坐标)", #list, #names) }
    for _, k in ipairs(names) do
        lines[#lines + 1] = string.format("%s\t%d\t%s", k, counts[k], sample[k] or "")
    end
    writeFile(DataDir .. "classes.txt", table.concat(lines, "\n"))
    log("已导出 %d 个类到 %sclasses.txt", #names, DataDir)
end

------------------------------------------------------------------------
-- 启动
------------------------------------------------------------------------
writeCategories()
loadSaved()

if Config.AutoOpenBrowser then launchServer() end

local function safeTick()
    local ok, err = pcall(tick)
    if not ok then log("tick 出错: %s", tostring(err)) end
end

if LoopInGameThreadWithDelay then
    -- 新版 UE4SS: 直接在游戏线程循环, 不跨线程, 热重载时不会互相等待
    LoopInGameThreadWithDelay(Config.LiveIntervalMs, safeTick)
else
    local busy = false
    LoopAsync(Config.LiveIntervalMs, function()
        if not busy then
            busy = true
            ExecuteInGameThread(function() safeTick() busy = false end)
        end
        return false
    end)
end

RegisterKeyBind(Key.F7, { ModifierKey.CONTROL }, function() launchServer() end)
RegisterKeyBind(Key.F8, { ModifierKey.CONTROL }, function()
    ExecuteInGameThread(function()
        local ok, err = pcall(dumpClasses)
        if not ok then log("导出失败: %s", tostring(err)) end
    end)
end)
RegisterKeyBind(Key.F9, { ModifierKey.CONTROL }, function()
    ExecuteInGameThread(function()
        Pois = {}
        Trail = {}
        PoiDirty = true
        os.remove(SavePath)
        log("已清空记录的 POI 和轨迹")
    end)
end)

log("已加载. Ctrl+F7 打开地图, Ctrl+F8 导出类名, Ctrl+F9 清空记录. 目录: %s", ModDir)
