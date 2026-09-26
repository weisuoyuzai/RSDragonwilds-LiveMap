-- 在普通 Lua 5.4 里模拟 UE4SS 的接口, 跑 LiveMap 的 main.lua
-- 参数: 组装好的 LiveMap 目录 (以路径分隔符结尾)
local MOD = ...
os.execute = function() return true end        -- 不启动地图服务器

local function obj(t)
    t.IsValid = function() return true end
    return t
end
local function fname(s) return { ToString = function() return s end } end
local function cls(name) return obj({ GetFName = function() return fname(name) end }) end
local world = obj({ GetFName = function() return fname("L_World") end })

local pawn = obj({
    K2_GetActorLocation = function() return { X = 5000, Y = 189000, Z = -3600 } end,
    K2_GetActorRotation = function() return { Yaw = 30 } end,
    GetWorld = function() return world end,
    GetClass = function() return cls("BP_PlayerCharacter_C") end,
    IsPlayerControlled = function() return true end,
    PlayerState = obj({ GetPlayerName = function() return "Tester" end }),
})
local pc = obj({ IsLocalController = function() return true end, Pawn = pawn })
-- 全地图数据里已有的灵元泉 (应被去重) 和玩家自己建的床 (应被记录)
local vent = obj({
    K2_GetActorLocation = function() return { X = 1256.4, Y = 187185.2, Z = -3123.7 } end,
    GetWorld = function() return world end, GetClass = function() return cls("BP_AnimaVent_C") end,
    AnimaVentData = obj({ GetFName = function() return fname("AVD_Law") end }),
})
local bed = obj({
    K2_GetActorLocation = function() return { X = 6000, Y = 189500, Z = -3600 } end,
    GetWorld = function() return world end, GetClass = function() return cls("BP_BaseBuilding_Bed_C") end,
})

FindAllOf = function(name)
    if name == "PlayerController" then return { pc } end
    if name == "Character" then return { pawn } end
    if name == "AnimaVent" or name == "BP_AnimaVent_C" then return { vent } end
    if name == "BP_BaseBuilding_Bed_C" then return { bed } end
    return nil
end
StaticFindObject = function() return nil end
LoadAsset = function() end
IterateGameDirectories = function() error("not available in tests") end
ExecuteInGameThread = function(f) f() end
local loopFn
LoopInGameThreadWithDelay = function(_, f) loopFn = f end
RegisterKeyBind = function() end
Key = setmetatable({}, { __index = function(_, k) return k end })
ModifierKey = { CONTROL = "CTRL" }
local logs = {}
print = function(s) logs[#logs + 1] = s end

-- 游戏里 os.clock 一直在走; 这里每次调用前进 0.3 秒, 让定时写文件的逻辑也能触发
local fake = 100
os.clock = function() fake = fake + 0.3 return fake end

dofile(MOD .. "Scripts" .. package.config:sub(1, 1) .. "main.lua")
assert(loopFn, "main.lua did not start its game-thread loop")
for _ = 1, 20 do loopFn() end
return table.concat(logs)
