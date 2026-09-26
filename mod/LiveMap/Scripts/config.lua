-- LiveMap 配置
-- classes: 属于该分类的类名 (蓝图类以 _C 结尾, 也可以写原生父类名, 例如 WorldChest). 子类自动算进来.
--   一个物体同时匹配多个分类时, 取继承链上离它最近的那个 (例如符文精华泉也是 OreNode, 但归到 geyser).
--   全地图数据 (world_L_World.lua) 由 tools 里的 WorldExtract 从游戏资源提取, 带有每个类的父类链.
-- hidden: 网页里默认隐藏 (数量很多的分类)
-- icon: 该分类的默认图标 (游戏贴图名, 见 Scripts/icon_paths.lua)
-- 不知道类名时: 游戏里按 Ctrl+F8 导出当前加载的所有 Actor 类名到 Mods/LiveMap/web/data/classes.txt

return {
    Port = 8765,
    AutoOpenBrowser = true,     -- 模组加载时自动启动本地服务器并打开网页
    LiveIntervalMs = 250,       -- 玩家位置刷新间隔
    CreatureIntervalMs = 1000,  -- 生物/NPC 刷新间隔
    RememberPois = true,        -- 记住游戏里扫描到、但全地图数据里没有的点 (比如你自己建的床/箱子, 死亡墓碑)
    ShowCreatures = true,       -- 扫描敌人/动物/NPC
    GameMapMarkers = true,      -- 读取游戏大地图上自带的标记 (地牢入口/神殿/敏捷赛道/兔子地道等)
    IconSize = 64,              -- 导出图标的像素尺寸

    Categories = {
        { id = "lodestone", label = "传送石", color = "#4fc3f7", icon = "T_LodestoneMapIcon", classes = {
            "WorldLodestone", "BP_WorldLodestone_C", "BP_BaseBuilding_Lodestone_C" } },
        { id = "respawn", label = "重生点/床", color = "#81c784", icon = "T_NavIcons_Bed", classes = {
            "Graveyard", "BP_BaseBuilding_Bed_C", "BP_BaseBuilding_BedRoll_C", "BP_BaseBuilding_Decoration_UmS_Bed_01_C",
            "BP_CustomSpawnPoint_C" } },
        { id = "grave", label = "墓碑(死亡掉落)", color = "#e57373", icon = "T_NavIcons_Gravestone", classes = {
            "BP_PlayerGravestone_C" } },
        { id = "anima", label = "灵元泉", color = "#b388ff", icon = "T_Icon_Rune_Essence", classes = {
            "AnimaVent", "BP_AnimaVent_C" } },
        { id = "geyser", label = "符文精华泉", color = "#80deea", icon = "T_Icon_Journal_Rune_Geyser", classes = {
            "RuneEssenceGeyser", "BP_RuneEssenceGeyser_Base_C" } },
        { id = "teleporter", label = "传送门/入口", color = "#ba68c8", icon = "T_NavIcons_DungeonEntrance", classes = {
            "BP_InteractablePlayerTeleporter_C", "BP_InteractablePlayerTeleporter_RequiresQuestStep_C",
            "BP_InteractablePlayerTeleporter_Locked_C", "BP_DungeonTeleport_C", "BP_DK_VautEntrance_C",
            "BP_DK_VautEntrance_Locked_C", "BP_ExitFromDungeonDoor_C", "BP_LibraryQuestBarrierTeleporter_C",
            "BP_InteractableKuldraTeleportOut_C", "BP_SMBG_HomeTeleport_C" } },
        { id = "chest", label = "宝箱", color = "#ffd54f", icon = "T_Icon_Loot_Chest_01", classes = {
            "WorldChest", "BP_LootChest_Base_C", "BP_BuriedChest_Base_C", "BP_Dungeon_Treasure_Chest_C", "BP_DR_BuriedChest_C" } },
        { id = "shrine", label = "神殿/祭坛", color = "#ff8a65", icon = "T_HealthAltar_Map_Discovered", classes = {
            "HealthShrine", "AnimaDepositPoint", "BP_HealthShrine_C", "BP_BaseBossAltar_C", "BP_AnimaDepositPoint_C",
            "BP_Crafting_Rune_Altar_C", "BP_Dowdun_Altar_01_C" } },
        { id = "agility", label = "敏捷赛道/兔子地道", color = "#aed581", icon = "T_Agility_NewCourse", classes = {
            "AgilityCourseStarter", "KebbitBurrow" } },
        { id = "ore", label = "金属矿/精华石", color = "#ffb74d", icon = "T_Map_Icon_Ore", classes = {
            "OreNode", "BP_MiningRock_RuneEssence_Static_Base_C",
            "BP_DivineRock_Adamantite_C", "BP_DivineRock_Blurite_C", "BP_DivineRock_Clay_C", "BP_DivineRock_Coal_C",
            "BP_DivineRock_Copper_C", "BP_DivineRock_Gold_C", "BP_DivineRock_Iron_C", "BP_DivineRock_Mithril_C",
            "BP_DivineRock_Runite_C", "BP_DivineRock_Silver_C", "BP_DivineRock_Tin_C" } },
        { id = "stone", label = "石料", color = "#a1887f", icon = "T_Icon_Resource_Stone", hidden = true, classes = {
            "BP_MiningRock_Base_C" } },
        { id = "fishing", label = "钓鱼点", color = "#4db6ac", icon = "T_Icon_Fishing", classes = {
            "FishingNodeV2", "BP_FishingNodeV2_Net_Base_C", "BP_FishingNodeV2_Rod_Base_C" } },
        { id = "lore", label = "传说物品", color = "#f06292", icon = "T_Icon_Journal_Lore_Scraps", classes = { "BP_LoreItem_C" } },
        { id = "gather", label = "采集物", color = "#9ccc65", icon = "T_Map_Icon_Plant", hidden = true, classes = {
            "GatherableResource" } },
        { id = "spawn", label = "怪物刷新点", color = "#e57373", icon = "T_Map_Icon_Animal", hidden = true, classes = {
            "AISpawnPoint" } },
        { id = "base", label = "基地建筑", color = "#90a4ae", icon = "T_Map_Icon_Base", classes = {
            "BP_BaseBuilding_Chest_C", "BP_BaseBuilding_Chest_Iron_C", "BP_BaseBuilding_Chest_Small_C",
            "BP_BaseBuilding_PersonalChest_C", "BP_BaseBuilding_Campfire_C" } },
        -- landmark 来自游戏大地图自带标记; npc 另外还包括 Character 扫描到的 BP_NPC_ 角色; creature 来自 Character 扫描
        { id = "landmark", label = "游戏地图标记", color = "#ffe082", icon = "T_NavIcons_Marker", classes = {} },
        { id = "npc", label = "NPC/任务互动", color = "#fff176", icon = "T_Map_Primary_Quest_Icon_NPC", classes = {
            "InteractableNPC" } },
        { id = "creature", label = "敌人/生物", color = "#ef5350", icon = "T_Map_Icon_Animal", hidden = true, classes = {} },
    },

    -- 按类名匹配图标 (Lua 模式, 从上往下第一条命中生效; cat 限定只对这些分类生效, 空格分隔); 没命中就用分类默认图标
    -- 灵元泉按符文类型、生物/刷新点/采集物按图鉴头像自动匹配, 不用写在这里
    IconRules = {
        { match = "Tier[5-8]", icon = "T_Icon_Dragon_chest", cat = "chest" },
        { match = "BuriedChest", icon = "T_Icon_Chest", cat = "chest" },
        { match = "LootChest", icon = "T_Icon_Loot_Chest_01", cat = "chest" },
        { match = "KebbitBurrow", icon = "T_NavIcons_Kebbit_Tunnel", cat = "agility" },
        { match = "Copper", icon = "T_Icon_Resource_Ore_Copper", cat = "ore stone" },
        { match = "Tin", icon = "T_Icon_Resource_Ore_Tin", cat = "ore stone" },
        { match = "Iron", icon = "T_Icon_Resource_Ore_Iron", cat = "ore stone" },
        { match = "Silver", icon = "T_Icon_Resource_Ore_Silver", cat = "ore stone" },
        { match = "Gold", icon = "T_Icon_Resource_Ore_Gold", cat = "ore stone" },
        { match = "Blurite", icon = "T_Icon_Resource_Ore_Blurite", cat = "ore stone" },
        { match = "Coal", icon = "T_Icon_Coal", cat = "ore stone" },
        { match = "Clay", icon = "T_Icon_Resources_Clay", cat = "ore stone" },
        { match = "Mithril", icon = "T_Icon_Mithril_Ore", cat = "ore stone" },
        { match = "Adamant", icon = "T_Icon_Adamantite_Ore", cat = "ore stone" },
        { match = "Runite", icon = "T_Icon_Runite_Ore", cat = "ore stone" },
        { match = "Luminite", icon = "T_Icon_Luminute_Ore", cat = "ore stone" },
        { match = "SoulStone", icon = "T_Icon_Soul_Fragment", cat = "ore stone" },
        { match = "Dragon_Tooth", icon = "T_Icon_Resource_Dragon_Tooth", cat = "ore stone" },
        { match = "RuneEssence", icon = "T_Icon_Rune_Essence", cat = "ore stone" },
        { match = "Granite", icon = "T_Icon_Resource_Granite", cat = "ore stone" },
        { match = "Sandstone", icon = "T_Icon_Resource_Sandstone_Rock", cat = "ore stone" },
        { match = "Limestone", icon = "T_Icon_Limestone", cat = "ore stone" },
        { match = "Gypsum", icon = "T_Icon_Journal_Gypsum_Rock_2", cat = "ore stone" },
        { match = "OreNode_Stone", icon = "T_Icon_Resource_Stone", cat = "ore stone" },
        { match = "AnimaInfusedBark", icon = "T_Icon_Resource_Anima_Infused_Bark", cat = "gather" },
        { match = "BittercapMushroom", icon = "T_Icon_Bittercap_Mushroom", cat = "gather" },
        { match = "Onion", icon = "T_Icon_Onion", cat = "gather" },
        { match = "Toadflax", icon = "T_Icon_Resource_Toadflax", cat = "gather" },
        { match = "Flax", icon = "T_Icon_Resource_Flax", cat = "gather" },
        { match = "SwampWeed", icon = "T_Icon_Resource_Swamp_Weed", cat = "gather" },
        { match = "Snapdragon", icon = "T_Icon_Snapdragon_seeds", cat = "gather" },
        { match = "Bone", icon = "T_Icon_Animal_Bone", cat = "gather" },
        { match = "AshBranch", icon = "T_Icon_Ash_Logs", cat = "gather" },
        { match = "Salvage_Metal", icon = "T_Icon_Salvage_Iron", cat = "gather" },
        { match = "Spawner_Stone", icon = "T_Icon_Resource_Stone", cat = "gather" },
        { match = "FishingNodeV2_Net", icon = "T_Icon_Journal_Net_1_Course", cat = "fishing" },
        { match = "Graveyard", icon = "T_Icon_Tombstone", cat = "respawn" },
        { match = "Bed", icon = "T_NavIcons_Bed", cat = "respawn" },
        { match = "BossAltar", icon = "T_NavIcons_BossAlter", cat = "shrine" },
        { match = "Rune_Altar", icon = "T_Icon_Station_Rune_Altar", cat = "shrine" },
        { match = "PersonalChest", icon = "T_Icon_Storage_Chest_Sml_01v1", cat = "base" },
        { match = "BaseBuilding_Chest", icon = "T_Icon_Storage_Chest_01v2", cat = "base" },
    },
}
