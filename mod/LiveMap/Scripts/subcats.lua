-- 分类下的细分 (网页里每个分类可以展开, 按细分单独显示/隐藏)
-- subOf(cls, cat, icon) -> 细分的英文名 (同时作为键) 或 nil; 中文名登记在 M.zh[英文名]
-- 名称优先用游戏官方译名 (Scripts/names.lua, 由 WorldExtract loc 从语言包生成), 没有的用下面的人工翻译

local M = { zh = {} }
local Names = { icons = {}, creatures = {}, terms = {} }
local version = 0

function M.init(names) Names = names or Names end
function M.version() return version end

local function reg(en, zh)
    if M.zh[en] == nil then
        M.zh[en] = zh or en
        version = version + 1
    end
    return en
end

-- 官方物品名 (按图标)
local function iconName(icon)
    local n = icon and Names.icons[icon]
    if n then return reg(n[1], n[2]) end
end

-- 规则: { 类名模式, 英文, 中文 }
local function rules(list, cls)
    for _, r in ipairs(list) do
        if cls:find(r[1]) then return reg(r[2], r[3]) end
    end
end

-- 矿石/石料/采集物: 这些图标本身就是对应资源, 用它的官方名
local RESOURCE_ICON = {
    "^T_Icon_Resource_Ore_", "_Ore$", "^T_Icon_Coal$", "^T_Icon_Resources_Clay$", "^T_Icon_Resource_Granite$",
    "^T_Icon_Resource_Sandstone_Rock$", "^T_Icon_Limestone$", "^T_Icon_Journal_Gypsum", "^T_Icon_Resource_Stone$",
    "^T_Icon_Rune_Essence$", "^T_Icon_Resource_Dragon_Tooth$",
    "^T_Icon_Resource_Anima", "^T_Icon_Bittercap", "^T_Icon_Onion$", "^T_Icon_Resource_Flax$", "^T_Icon_Resource_Swamp_Weed$",
    "^T_Icon_Resource_Toadflax$", "^T_Icon_Animal_Bone$", "^T_Icon_Ash_Logs$", "^T_Icon_Salvage_",
}
local function resourceName(icon)
    if not icon then return end
    for _, p in ipairs(RESOURCE_ICON) do
        if icon:find(p) then return iconName(icon) end
    end
end

local MATERIAL = {   -- 图标没有官方名时的后备
    { "SoulStone", "Soul Stone", "灵魂石" }, { "AviskCrystal", "Avisk Crystal", "阿维斯克水晶" },
    { "Snapdragon", "Snapdragon", "金鱼草" }, { "Luminite", "Luminite Ore", "光晶矿石" },
    { "RuneEssence", "Rune Essence", "符文精粹" }, { "Blue?rite", "Blurite Ore", "蓝晶矿石" },
    { "Silver", "Silver Ore", "银矿石" }, { "Gold", "Gold Ore", "金矿石" }, { "Stone", "Stone", "石头" },
}

local RUNES = {   -- 土系符文没有对应的物品图标名, 其余来自官方
    Law = { "Law Rune", "法则符文" }, Water = { "Water Rune", "水系符文" }, Air = { "Air Rune", "气系符文" },
    Earth = { "Earth Rune", "土系符文" }, Fire = { "Fire Rune", "火焰符文" }, Astral = { "Astral Rune", "星穹符文" },
    Nature = { "Nature Rune", "自然符文" },
}

local CHEST_KIND = {
    { "RaidChest", "Raid Chest", "团队宝箱" }, { "Spectral", "Spectral Chest", "幽灵宝箱" },
    { "Buried", "Buried Chest", "埋藏宝箱" }, { "Vault", "Vault Chest", "穹殿宝箱" }, { "LootChest", "Chest", "野外宝箱" },
}

local FISHING_REGION = {
    { "Brynmoor", "Brynmoor" }, { "Fellhollow", "Fellhollow" }, { "Ghornfell", "Ghornfell" },
    { "DowdunReach", "Dowdun Reach" }, { "UmbralSands", "Umbral Sands" }, { "ScornedWilderness", "Scorned Wilderness" },
}

local RULES = {
    teleporter = {
        { "VautEntrance", "Vault Entrance", "穹殿入口" }, { "NightmareCrucible", "Nightmare Crucible", "梦魇熔炉" },
        { "Spectral_Door", "Spectral Door", "幽灵门" }, { "EnergyBarrier", "Energy Barrier", "能量屏障" },
        { "RequiresQuestStep", "Quest Portal", "任务传送门" }, { "Locked", "Locked Portal", "上锁的传送门" },
        { "Teleport", "Portal", "传送门" },
    },
    shrine = {
        { "HealthShrine", "Health Shrine", "生命神殿" }, { "AnimaDepositPoint_Fire", "Fire Anima Deposit", "火灵元存放点" },
        { "AnimaDepositPoint_Air", "Air Anima Deposit", "气灵元存放点" },
        { "AnimaDepositPoint_Water", "Water Anima Deposit", "水灵元存放点" },
        { "AnimaDepositPoint_Earth", "Earth Anima Deposit", "土灵元存放点" }, { "Altar", "Altar", "祭坛" },
    },
    agility = { { "KebbitBurrow", "Kebbit Burrow", "凯比兔地道" }, { "AgilityCourse", "Agility Course", "敏捷试炼赛道" } },
    respawn = { { "Graveyard", "Graveyard", "复活墓地" }, { "Bed", "Bed", "床铺" }, { "SpawnPoint", "Spawn Point", "出生点" } },
}

-- BP_SpawnPoint_Giant_Rat_Poison_C / BP_AI_Kebbit_Character_02_C -> 数据类核心名 (Giant_Rat_Poison / Kebbit)
local function creatureCore(cls)
    return (cls:gsub("^BP_SpawnPoint_", ""):gsub("^BP_AI_", ""):gsub("^BP_NPC_", "")
        :gsub("_Character.*$", ""):gsub("_C$", ""):gsub("_%d+$", ""))
end
M.creatureCore = creatureCore

-- 拆成小写单词: "MeleeVaultGuardian_Colossal" -> {melee, vault, guardian, colossal}
local STOP = { nc = true, sw = true, dr = true, gd = true, ums = true, fh = true, bp = true, quest = true, statue = true,
    scornedwilderness = true, spawnpoint = true }
-- 同义词和游戏类名里的拼写错误 (beast = 加鲁族: 数据类 MediumBeast 的名字就是 Garou Berserker)
local SYNONYM = { skeletal = "skeleton", bluerite = "blurite", magic = "mage", ranger = "ranged", beast = "garou",
    spinning = "spinner", kinight = "knight", radient = "radiant" }
local function words(s)
    local t, n = {}, 0
    s = s:gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2"):gsub("(%a)(%d)", "%1 %2")
    for w in s:gmatch("%w+") do
        w = w:lower()
        w = SYNONYM[w] or w
        if not STOP[w] and not t[w] then t[w] = true n = n + 1 end
    end
    return t, n
end
local function subset(a, b)          -- a 的单词都在 b 里
    for w in pairs(a) do if not b[w] then return false end end
    return true
end

local aiIndex   -- { {words, count, name}, ... } 怪物名字符串表的键和英文名

-- 怪物名: 图鉴里的怪物数据类 -> 怪物名字符串表 (键或英文名的单词都出现在类名里, 取最具体的) -> 图鉴头像的名字 -> 英文类名
local function creatureName(cls, icon)
    local core = creatureCore(cls)
    local n = Names.creatures[core] or Names.creatures[(core:gsub("_", ""))]
    if not n then
        if not aiIndex then
            aiIndex = {}
            -- 怪物数据类名 (BP_AI_<core>_Data), 名字符串表的键, 以及它们的英文名
            for _, tbl in ipairs({ Names.creatures or {}, Names.ainames or {} }) do
                for k, v in pairs(tbl) do
                    for _, src in ipairs({ k, v[1] }) do
                        local w, c = words(src)
                        if c > 0 then aiIndex[#aiIndex + 1] = { w = w, c = c, name = v } end
                    end
                end
            end
        end
        local cw, cc = words(core)
        local best = 0
        for _, e in ipairs(aiIndex) do
            if e.c > best and subset(e.w, cw) then best, n = e.c, e.name end
        end
        -- 反过来: 类名的单词都在某个名字里 (Desert_Devil -> Desert Devil Kebbit), 取最短的
        if not n and cc > 0 then
            best = math.huge
            for _, e in ipairs(aiIndex) do
                if e.c < best and subset(cw, e.w) then best, n = e.c, e.name end
            end
        end
    end
    if not n and icon and icon:find("^T_Icon_Journal_") then n = Names.icons[icon] end
    if n then return reg(n[1], n[2]) end
    local en = core:gsub("_", " ")
    return reg(en, en)
end

local cache = {}

function M.subOf(cls, cat, icon)
    local key = cat .. "|" .. cls .. "|" .. (icon or "")
    local v = cache[key]
    if v ~= nil then return v or nil end
    if cat == "anima" then
        local rune = icon and icon:match("^T_Icon_Rune_(%a+)$")
        local r = rune and RUNES[rune]
        v = r and reg(r[1], r[2]) or iconName(icon)
    elseif cat == "ore" or cat == "stone" or cat == "gather" then
        v = resourceName(icon) or rules(MATERIAL, cls) or reg("Other", "其他")
    elseif RULES[cat] then
        v = rules(RULES[cat], cls) or reg("Other", "其他")
    elseif cat == "chest" then
        local kind = CHEST_KIND[#CHEST_KIND]
        for _, k in ipairs(CHEST_KIND) do
            if cls:find(k[1]) then kind = k break end
        end
        local tier = cls:match("Tier(%d%+?)")
        v = tier and reg(kind[2] .. " T" .. tier, kind[3] .. " T" .. tier) or reg(kind[2], kind[3])
    elseif cat == "fishing" then
        local net = cls:find("_Net") ~= nil
        local region
        for _, r in ipairs(FISHING_REGION) do
            if cls:find(r[1]) then region = r[2] break end
        end
        local how_en, how_zh = net and "Net" or "Rod", net and "网捕" or "钓竿"
        if region then
            v = reg(how_en .. " · " .. region, how_zh .. " · " .. (Names.terms[region] or region))
        else
            v = reg(how_en, how_zh)
        end
    elseif cat == "spawn" or cat == "creature" then
        v = creatureName(cls, icon)
    else
        v = false
    end
    cache[key] = v
    return v or nil
end

return M
