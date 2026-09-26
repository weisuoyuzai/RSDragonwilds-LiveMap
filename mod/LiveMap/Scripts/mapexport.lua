-- 导出 MinimapPlugin 的地图背景 (BP_MapBackground) 为 PNG, 并给出每张图对应的世界范围
-- 贴图坐标约定 (与编辑器顶视图一致): 图片向右 = 世界 +X, 图片向下 = 世界 +Y
-- 游戏关闭大地图后会释放大地图贴图的显存, 这时画出来是空的; 所以先用 probe 小图试画, 有内容再导出
--
-- ctx = { world, dataDir, worldContext, valid, worldName, log }

local M = {}
local MAX_SIZE = 4096

local function krl()
    return StaticFindObject("/Script/Engine.Default__KismetRenderingLibrary")
end

local RTCache = {}   -- 按尺寸复用渲染目标, 重试时不用反复分配大块显存

local function drawTexture(ctx, tex, w, h)
    local KRL = krl()
    local key = w .. "x" .. h
    local rt = RTCache[key]
    if not ctx.valid(rt) then
        rt = KRL:CreateRenderTarget2D(ctx.worldContext, w, h, 3, { R = 0, G = 0, B = 0, A = 0 }, false, false)
        RTCache[key] = rt
    else
        KRL:ClearRenderTarget2D(ctx.worldContext, rt, { R = 0, G = 0, B = 0, A = 0 })
    end
    local oCanvas = {}
    KRL:BeginDrawCanvasToRenderTarget(ctx.worldContext, rt, oCanvas, {}, {})
    if ctx.valid(oCanvas.Canvas) then
        oCanvas.Canvas:K2_DrawTexture(tex, { X = 0, Y = 0 }, { X = w, Y = h }, { X = 0, Y = 0 }, { X = 1, Y = 1 },
            { R = 1, G = 1, B = 1, A = 1 }, 0, 0, { X = 0.5, Y = 0.5 })
    end
    -- DrawEvent 指针不走反射, 传只含 RenderTarget 的结构体 (DrawEvent = nullptr, 引擎里 delete nullptr 安全)
    KRL:EndDrawCanvasToRenderTarget(ctx.worldContext, { RenderTarget = rt })
    return rt
end

-- 当前世界的所有地图背景
function M.backgrounds(ctx)
    local items = {}
    for _, bg in ipairs(FindAllOf("MapBackground") or FindAllOf("BP_MapBackground_C") or {}) do
        if ctx.valid(bg) and ctx.worldName(bg) == ctx.world then
            local tex
            pcall(function()
                bg.BackgroundLevels:ForEach(function(_, e)
                    local v = e:get()
                    if not tex and ctx.valid(v.BackgroundTexture) then tex = v.BackgroundTexture end
                end)
            end)
            local box = bg.AreaBounds
            if tex and ctx.valid(box) then
                local c = box:K2_GetComponentLocation()
                local ext = box:GetScaledBoxExtent()
                local tw, th = tex:Blueprint_GetSizeX(), tex:Blueprint_GetSizeY()
                local k = math.min(1, MAX_SIZE / math.max(tw, th))
                local prio = 0
                pcall(function() prio = bg.BackgroundPriority end)
                local name = tex:GetFName():ToString()
                items[#items + 1] = {
                    key = name,
                    tex = tex,
                    entry = {
                        image = string.format("data/map_%s_%s.png", ctx.world, name),
                        width = math.floor(tw * k), height = math.floor(th * k),
                        minX = c.X - ext.X, maxX = c.X + ext.X,
                        minY = c.Y - ext.Y, maxY = c.Y + ext.Y,
                        minZ = c.Z - ext.Z, maxZ = c.Z + ext.Z,
                        yaw = box:K2_GetComponentRotation().Yaw,
                        priority = prio,
                    },
                }
            end
        end
    end
    return items
end

-- 按最终尺寸画一次, 画面里有内容才导出 (贴图的高精度层可能还没加载好, 此时画出来是空的)
-- 返回 true 表示已导出
function M.tryExport(ctx, item)
    local KRL = krl()
    local e = item.entry
    local rt = drawTexture(ctx, item.tex, e.width, e.height)
    local hits = 0
    -- 每次读像素都要等 GPU, 只抽 3x3 个点
    for i = 1, 3 do
        for j = 1, 3 do
            local c = KRL:ReadRenderTargetPixel(ctx.worldContext, rt, math.floor(e.width * i / 4), math.floor(e.height * j / 4))
            if c.A > 0 then hits = hits + 1 end
        end
    end
    if hits < 2 then return false end
    local file = e.image:match("[^/]+$")
    KRL:ExportRenderTarget(ctx.worldContext, rt, ctx.dataDir:sub(1, -2), file)
    ctx.log("导出地图 %s (%dx%d) -> %s", item.key, e.width, e.height, file)
    return true
end

return M
