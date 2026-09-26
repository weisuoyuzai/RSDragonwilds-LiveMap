-- 分类下的细分 (网页里每个分类可以展开, 按细分单独显示/隐藏)
-- subOf(cls, cat, label) -> 细分名 或 nil (nil = 该分类不细分)
-- 规则按顺序匹配类名 (Lua 模式), 第一条命中生效

local M = {}

local ORE = {
    { "RuneEssence", "符文精华" }, { "Luminite", "流明矿" }, { "SoulStone", "灵魂石" },
    { "Coal", "煤矿" }, { "Copper", "铜矿" }, { "Tin", "锡矿" }, { "Iron", "铁矿" }, { "Silver", "银矿" },
    { "Gold", "金矿" }, { "Blurite", "蓝晶矿" }, { "Clay", "黏土" }, { "Mithril", "秘银矿" },
    { "Adamant", "精金矿" }, { "Runite", "符文矿" }, { "Dragon_Tooth", "龙牙" },
}

local RULES = {
    ore = ORE,
    stone = {
        { "Sandstone", "砂岩" }, { "Limestone", "石灰岩" }, { "Granite", "花岗岩" }, { "Gypsum", "石膏" },
        { "Dragon_Tooth", "龙牙" }, { "AviskCrystal", "Avisk 水晶" }, { "Stone", "石头" },
    },
    gather = {
        { "AnimaInfusedBark", "灵元树皮" }, { "BittercapMushroom", "苦帽菇" }, { "Onion", "洋葱" },
        { "Flax", "亚麻" }, { "SwampWeed", "沼泽草" }, { "Toadflax", "蟾蜍草" }, { "Snapdragon", "金鱼草" },
        { "Bone", "骨头" }, { "AshBranch", "白蜡树枝" }, { "Salvage_Metal", "废金属" }, { "Stone", "石块" },
    },
    teleporter = {
        { "VautEntrance", "宝库入口" }, { "NightmareCrucible", "梦魇熔炉" }, { "Spectral_Door", "幽灵门" },
        { "EnergyBarrier", "能量屏障" }, { "RequiresQuestStep", "任务传送门" }, { "Locked", "上锁的传送门" },
        { "Teleport", "传送门" },
    },
    shrine = {
        { "HealthShrine", "生命神殿" }, { "AnimaDepositPoint_Fire", "火灵元存放点" },
        { "AnimaDepositPoint_Air", "气灵元存放点" }, { "AnimaDepositPoint_Water", "水灵元存放点" },
        { "AnimaDepositPoint_Earth", "土灵元存放点" }, { "Altar", "祭坛" },
    },
    agility = { { "KebbitBurrow", "兔子地道" }, { "AgilityCourse", "敏捷赛道" } },
    respawn = { { "Graveyard", "复活墓地" }, { "Bed", "床" }, { "SpawnPoint", "出生点" } },
}

local CHEST_KIND = {
    { "RaidChest", "团队宝箱" }, { "Spectral", "幽灵宝箱" }, { "Buried", "埋藏宝箱" }, { "Vault", "宝库宝箱" },
    { "LootChest", "野外宝箱" },
}

local FISHING_REGION = {
    { "Brynmoor", "Brynmoor" }, { "Fellhollow", "Fellhollow" }, { "Ghornfell", "Ghornfell" },
    { "DowdunReach", "Dowdun Reach" }, { "UmbralSands", "Umbral Sands" }, { "ScornedWilderness", "Scorned Wilderness" },
}

local function firstMatch(rules, cls)
    for _, r in ipairs(rules) do
        if cls:find(r[1]) then return r[2] end
    end
end

-- BP_SpawnPoint_Giant_Rat_Poison_C -> "Giant Rat Poison", BP_AI_Kebbit_Character_02_C -> "Kebbit"
local function creatureName(cls)
    local core = cls:gsub("^BP_SpawnPoint_", ""):gsub("^BP_AI_", ""):gsub("^BP_NPC_", "")
        :gsub("_Character.*$", ""):gsub("_C$", ""):gsub("_%d+$", "")
    return (core:gsub("_", " "))
end

local cache = {}

function M.subOf(cls, cat, label)
    if cat == "anima" then return label end              -- 灵元泉: 按符文 (标签里已经是 "律法符文" 这样)
    local key = cat .. "|" .. cls
    local v = cache[key]
    if v ~= nil then return v or nil end
    if RULES[cat] then
        v = firstMatch(RULES[cat], cls) or "其他"
    elseif cat == "chest" then
        local kind = firstMatch(CHEST_KIND, cls) or "其他宝箱"
        local tier = cls:match("Tier(%d%+?)")
        v = tier and (kind .. " T" .. tier) or kind
    elseif cat == "fishing" then
        local how = cls:find("_Net") and "网捕" or "钓竿"
        local region = firstMatch(FISHING_REGION, cls)
        v = region and (how .. " · " .. region) or how
    elseif cat == "spawn" or cat == "creature" then
        v = creatureName(cls)
    else
        v = false
    end
    cache[key] = v
    return v or nil
end

return M
