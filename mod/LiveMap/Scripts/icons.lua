-- 图标: 给每个点找对应的游戏贴图, 并把贴图导出成 PNG 给网页用
-- 导出走 "画到渲染目标 -> 检查有内容 -> 保存" 的流程; 游戏窗口不在前台时引擎不执行这类绘制, 所以失败会自动重试

local M = {}

local opts          -- { dataDir, valid, log, paths, config, catDefaults, names }
local iconDir
local state = {}    -- [iconName] = "ok" | { tries = n, next = clock }
local queue = {}
local version = 0
local classCache = {}
local journal = {}  -- { norm = "kebbit", icon = "T_Icon_Journal_Kebbit" }

local function norm(s) return (s:lower():gsub("[^%w]", "")) end

local function fileExists(p)
    local f = io.open(p, "rb")
    if f then f:close() return true end
    return false
end

function M.init(o)
    opts = o
    iconDir = o.dataDir .. "icons\\"
    for name in pairs(o.paths) do
        local j = name:match("^T_Icon_Journal_(.+)$")
        if j then journal[#journal + 1] = { norm = norm(j), icon = name } end
    end
    table.sort(journal, function(a, b) return #a.norm > #b.norm end)
end

function M.version() return version end

-- 网页用的已导出图标列表
function M.exported()
    local t = {}
    for name, st in pairs(state) do
        if st == "ok" then t[#t + 1] = name end
    end
    table.sort(t)
    return t
end

-- 对照表里没有的贴图 (比如游戏地图标记直接给的贴图对象), 运行时补上路径
function M.addPath(name, path)
    if name and path and not opts.paths[name] then opts.paths[name] = path end
end

function M.request(name)
    if not name or state[name] ~= nil or not opts.paths[name] then return end
    if fileExists(iconDir .. name .. ".png") then
        state[name] = "ok"
        version = version + 1
        return
    end
    state[name] = { tries = 0, next = 0 }
    queue[#queue + 1] = name
end

-- 生物: 用图鉴头像. BP_AI_Kebbit_Character_02_C -> "kebbit" -> T_Icon_Journal_Kebbit
-- 刷新点/采集物同理: BP_SpawnPoint_Magpie_C -> magpie, BP_Spawner_BittercapMushroom_C -> bittercapmushroom
local JOURNAL_CATS = { creature = true, npc = true, spawn = true, gather = true }

local function creatureIcon(cls, allowPrefix)
    local core = cls:gsub("^BP_AI_", ""):gsub("^BP_NPC_", ""):gsub("^BP_SpawnPoint_", ""):gsub("^BP_Spawner_", "")
        :gsub("_Character.*$", ""):gsub("_C$", ""):gsub("_%d+$", "")
    local n = norm(core)
    for _, j in ipairs(journal) do
        if j.norm == n then return j.icon end
    end
    for _, j in ipairs(journal) do   -- 最长的包含匹配, 比如 GoblinArcherElite -> goblinarcher
        if #j.norm >= 4 and n:find(j.norm, 1, true) then return j.icon end
    end
    -- 采集物: 以类名开头的最短图鉴条目, 比如 Cabbage -> Cabbage_seeds (作物本身没有单独的图标)
    if allowPrefix and #n >= 4 then
        local best
        for _, j in ipairs(journal) do
            if j.norm:sub(1, #n) == n and (not best or #j.norm < #best.norm) then best = j end
        end
        return best and best.icon
    end
end

-- 返回 图标名, 附加说明
-- extra: 离线数据里带的附加信息 (灵元泉的 AnimaVentData 名, 例如 AVD_Law); 没有时从游戏对象读
function M.resolve(actor, cls, cat, extra)
    if cat == "anima" then
        local rune = extra and extra:match("^AVD_(.+)$")
        if not rune and actor then
            local ok, r = pcall(function() return actor.AnimaVentData:GetFName():ToString():match("^AVD_(.+)$") end)
            rune = ok and r or nil
        end
        if rune then
            local icon = "T_Icon_Rune_" .. rune
            return opts.paths[icon] and icon or opts.catDefaults[cat]
        end
    end
    local key = cat .. "|" .. cls
    local cached = classCache[key]
    if cached == nil then
        cached = false
        for _, r in ipairs(opts.config.IconRules or {}) do
            if (not r.cat or (" " .. r.cat .. " "):find(" " .. cat .. " ", 1, true)) and cls:find(r.match) then
                cached = r.icon
                break
            end
        end
        if not cached and JOURNAL_CATS[cat] then
            -- 优先用图鉴条目里记录的怪物数据类 (BP_AI_<core>_Data) 精确对应, 再退回按名字模糊匹配
            local core = opts.creatureCore and opts.creatureCore(cls)
            local n = core and opts.names and opts.names.creatures[core]
            cached = (n and n[3] ~= "" and opts.paths[n[3]] and n[3]) or creatureIcon(cls, cat == "gather") or false
        end
        if not cached then cached = opts.catDefaults[cat] or false end
        classCache[key] = cached
    end
    return cached or nil
end

local function krl() return StaticFindObject("/Script/Engine.Default__KismetRenderingLibrary") end

local function loadTexture(name)
    local p = opts.paths[name]
    local tex = StaticFindObject(p)
    if not opts.valid(tex) then
        pcall(LoadAsset, p)
        tex = StaticFindObject(p)
    end
    return opts.valid(tex) and tex or nil
end

local RT
-- 画一个图标并导出; 返回 true 成功, false 画面为空(稍后再试), nil 贴图不存在
local function exportOne(worldContext, name)
    local tex = loadTexture(name)
    if not tex then return nil end
    local KRL = krl()
    local S = opts.config.IconSize or 64
    if not opts.valid(RT) then
        RT = KRL:CreateRenderTarget2D(worldContext, S, S, 3, { R = 0, G = 0, B = 0, A = 0 }, false, false)
    else
        KRL:ClearRenderTarget2D(worldContext, RT, { R = 0, G = 0, B = 0, A = 0 })
    end
    -- 保持长宽比, 居中
    local tw, th = tex:Blueprint_GetSizeX(), tex:Blueprint_GetSizeY()
    local k = S / math.max(tw, th)
    local w, h = tw * k, th * k
    local oc = {}
    KRL:BeginDrawCanvasToRenderTarget(worldContext, RT, oc, {}, {})
    if opts.valid(oc.Canvas) then
        oc.Canvas:K2_DrawTexture(tex, { X = (S - w) / 2, Y = (S - h) / 2 }, { X = w, Y = h }, { X = 0, Y = 0 }, { X = 1, Y = 1 },
            { R = 1, G = 1, B = 1, A = 1 }, 0, 0, { X = 0.5, Y = 0.5 })
    end
    KRL:EndDrawCanvasToRenderTarget(worldContext, { RenderTarget = RT })
    local hits = 0
    for i = 1, 3 do
        for j = 1, 3 do
            if KRL:ReadRenderTargetPixel(worldContext, RT, math.floor(S * i / 4), math.floor(S * j / 4)).A > 0 then hits = hits + 1 end
        end
    end
    if hits == 0 then return false end
    KRL:ExportRenderTarget(worldContext, RT, iconDir:sub(1, -2), name .. ".png")
    return true
end

-- 每次最多处理 budget 个; 第一个失败说明现在画不了 (游戏在后台), 本轮直接停
function M.process(worldContext, clock, budget)
    local done = 0
    local i = 1
    while i <= #queue and done < budget do
        local name = queue[i]
        local st = state[name]
        if type(st) ~= "table" then
            table.remove(queue, i)
        elseif st.next > clock then
            i = i + 1
        else
            local ok, r = pcall(exportOne, worldContext, name)
            done = done + 1
            if ok and r then
                state[name] = "ok"
                version = version + 1
                table.remove(queue, i)
            elseif ok and r == nil then
                state[name] = "missing"
                table.remove(queue, i)
            else
                st.tries = st.tries + 1
                st.next = clock + math.min(60, 2 * st.tries)
                if not ok then opts.log("图标 %s 导出出错: %s", name, tostring(r)) end
                return
            end
        end
    end
end

return M
