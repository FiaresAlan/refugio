-- VillageBuilder.luau — REFÚGIO · Etapa 3.2 v2 (vila definitiva)
-- Gera a vila em modo de edição. Pode rodar de novo: só apaga/refaz o que ele mesmo criou.
-- Command Bar:
-- local m = game.ServerScriptService:FindFirstChild("VillageBuilder", true) require(m:Clone()).Build()

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Builder = {}

local CONFIG = {
    Radius = 150, -- raio da muralha (vila com ~300 studs de diâmetro)
    GateWidth = 16,
    Seed = 2026, -- mesma seed = mesma vila
    MaxTrees = 36,
}

local M = Enum.Material
local C = {
    Wood = Color3.fromRGB(124, 84, 54),
    WoodDark = Color3.fromRGB(82, 55, 38),
    Plaster = Color3.fromRGB(240, 228, 204),
    Stone = Color3.fromRGB(150, 145, 136),
    StoneDark = Color3.fromRGB(108, 104, 98),
    Warm = Color3.fromRGB(255, 196, 110),
    Leaf = Color3.fromRGB(88, 152, 74),
    LeafLight = Color3.fromRGB(122, 176, 84),
    Gold = Color3.fromRGB(255, 200, 60),
    Crystal = Color3.fromRGB(120, 230, 255),
    Iron = Color3.fromRGB(45, 45, 50),
    Hay = Color3.fromRGB(222, 190, 100),
    Cream = Color3.fromRGB(250, 245, 235),
    Soil = Color3.fromRGB(90, 62, 44),
}
local ROOFS = {
    Color3.fromRGB(178, 72, 56),
    Color3.fromRGB(70, 98, 150),
    Color3.fromRGB(78, 124, 76),
    Color3.fromRGB(196, 120, 58),
}
local CLOTH = {
    Color3.fromRGB(220, 70, 70), Color3.fromRGB(240, 190, 60), Color3.fromRGB(70, 140, 220),
    Color3.fromRGB(90, 180, 110), Color3.fromRGB(200, 100, 200), Color3.fromRGB(240, 130, 60),
}
local FLOWERS = {
    Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 220, 80),
    Color3.fromRGB(170, 120, 255), Color3.fromRGB(255, 255, 255),
}

local rng, BASE, root, nature
local plotsF, stallsF, zonesF, spawnsF
local reserved = {}

-- ===== utilidades =====
local function L(x, y, z, ry)
    return BASE * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(ry or 0), 0)
end

local function face(x, z, tx, tz) -- ângulo para a frente (-Z) olhar para (tx, tz)
    return math.deg(math.atan2(-(tx - x), -(tz - z)))
end

local function part(parent, size, cf, color, mat, o)
    o = o or {}
    local p = Instance.new(o.class or "Part")
    p.Anchored = true
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = mat or M.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    if o.shape then p.Shape = o.shape end
    if o.deco then
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
    end
    if o.noShadow then p.CastShadow = false end
    if o.transparency then p.Transparency = o.transparency end
    p.Name = o.name or "Part"
    p.Parent = parent
    return p
end

local function cyl(parent, diameter, height, cf, color, mat, o)
    o = o or {}
    o.shape = Enum.PartType.Cylinder
    return part(parent, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, mat, o)
end

local function model(name, parent)
    local m = Instance.new("Model")
    m.Name = name
    m.Parent = parent or root
    return m
end

local function reserve(x, z, w, d)
    table.insert(reserved, { x - w / 2, x + w / 2, z - d / 2, z + d / 2 })
end

local function isFree(x, z, margin)
    for _, r in reserved do
        if x > r[1] - margin and x < r[2] + margin and z > r[3] - margin and z < r[4] + margin then
            return false
        end
    end
    return true
end

local function sign(p, title, sub, o)
    o = o or {}
    local g = Instance.new("SurfaceGui")
    g.Name = "SignGui"
    g.Face = o.face or Enum.NormalId.Front
    g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    g.PixelsPerStud = 40
    g.LightInfluence = 0.4
    g.Parent = p
    local function label(name, text, y, h)
        local t = Instance.new("TextLabel")
        t.Name = name
        t.BackgroundTransparency = 1
        t.Position = UDim2.fromScale(0.05, y)
        t.Size = UDim2.fromScale(0.9, h)
        t.Font = Enum.Font.FredokaOne
        t.TextScaled = true
        t.TextColor3 = o.color or Color3.fromRGB(255, 240, 210)
        t.TextStrokeTransparency = 0.5
        t.Text = text
        t.Parent = g
    end
    if sub then
        label("Title", title, 0.06, 0.52)
        label(o.subName or "Sub", sub, 0.6, 0.34)
    else
        label("Title", title, 0.12, 0.76)
    end
end

local function lamp(parent, cf, range)
    local glass = part(parent, Vector3.new(1.1, 1.5, 1.1), cf, C.Warm, M.Neon, { deco = true, noShadow = true, name = "LampGlass" })
    local l = Instance.new("PointLight")
    l.Color = C.Warm
    l.Range = range or 18
    l.Brightness = 1.6
    l.Shadows = false
    l.Parent = glass
    CollectionService:AddTag(glass, "VillageLight")
    return glass
end

local function lampPost(parent, x, z)
    local m = model("LampPost", parent)
    part(m, Vector3.new(1.8, 0.8, 1.8), L(x, 0.2, z), C.StoneDark, M.Slate)
    part(m, Vector3.new(0.9, 9, 0.9), L(x, 4.5, z), C.WoodDark, M.Wood)
    part(m, Vector3.new(1.4, 0.3, 1.4), L(x, 9.05, z), C.Iron, M.Metal, { deco = true })
    lamp(m, L(x, 9.95, z))
    part(m, Vector3.new(1.6, 0.4, 1.6), L(x, 10.9, z), C.Iron, M.Metal, { deco = true })
    reserve(x, z, 3, 3)
end

-- ===== natureza (usa os modelos da 3.3 se existirem) =====
local function placeAsset(prefix, cf, height, parent)
    if not nature then return nil end
    local list = {}
    for _, c in nature:GetChildren() do
        if c:IsA("PVInstance") and string.sub(c.Name, 1, #prefix) == prefix then
            table.insert(list, c)
        end
    end
    if #list == 0 then return nil end
    local obj = list[rng:NextInteger(1, #list)]:Clone()
    if obj:IsA("BasePart") then
        local wrap = Instance.new("Model")
        wrap.Name = obj.Name
        obj.Parent = wrap
        obj = wrap
    end
    obj.Parent = parent
    local _, size = obj:GetBoundingBox()
    if height and size.Y > 0 then
        obj:ScaleTo(obj:GetScale() * (height / size.Y))
    end
    obj:PivotTo(cf)
    local bcf, bsize = obj:GetBoundingBox()
    local bottom = bcf.Position.Y - bsize.Y / 2
    obj:PivotTo(obj:GetPivot() + Vector3.new(0, cf.Position.Y - bottom - 0.2, 0))
    for _, d in obj:GetDescendants() do
        if d:IsA("BasePart") then d.Anchored = true end
    end
    return obj
end

local function tree(parent, x, z)
    local s = rng:NextNumber(0.85, 1.3)
    local cf = L(x, 0, z, rng:NextNumber(0, 360))
    if placeAsset("Tree", cf, 22 * s, parent) then return end
    local m = model("Tree", parent)
    part(m, Vector3.new(1.8, 9, 1.8) * s, cf * CFrame.new(0, 4.5 * s, 0), C.Wood, M.Wood, { name = "Trunk" })
    local layers = rng:NextNumber() < 0.5
        and { { 9, 3, 9 }, { 7, 3, 12 }, { 4.5, 3, 15 } }
        or { { 9, 7, 11 }, { 6.5, 5, 14.5 } }
    for i, l in layers do
        local rot = CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), math.rad(rng:NextNumber(0, 90)), math.rad(rng:NextNumber(-8, 8)))
        part(m, Vector3.new(l[1], l[2], l[1]) * s, cf * CFrame.new(0, l[3] * s, 0) * rot,
            (i % 2 == 0) and C.LeafLight or C.Leaf, M.SmoothPlastic, { deco = true, name = "Leaves" })
    end
end

local function bush(parent, x, z)
    local cf = L(x, 0, z, rng:NextNumber(0, 360))
    if placeAsset("Bush", cf, rng:NextNumber(3.5, 5.5), parent) then return end
    local s = rng:NextNumber(0.8, 1.3)
    part(parent, Vector3.new(4, 3, 4) * s, cf * CFrame.new(0, 1.3 * s, 0) * CFrame.Angles(0, math.rad(30), 0), C.Leaf, M.SmoothPlastic, { deco = true, name = "Bush" })
    part(parent, Vector3.new(2.8, 2.4, 2.8) * s, cf * CFrame.new(1.2 * s, 2 * s, 0.6 * s), C.LeafLight, M.SmoothPlastic, { deco = true, name = "Bush" })
end

local function rock(parent, x, z)
    local cf = L(x, 0, z, rng:NextNumber(0, 360))
    if placeAsset("Rock", cf, rng:NextNumber(2.5, 5), parent) then return end
    local s = rng:NextNumber(2, 4.5)
    part(parent, Vector3.new(s * 1.3, s, s), cf * CFrame.new(0, s * 0.35, 0) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), 0, math.rad(rng:NextNumber(-20, 20))), C.Stone, M.Slate, { name = "Rock" })
end

local function flowers(parent, cf, n, spread)
    for _ = 1, n do
        local fcf = cf * CFrame.new(rng:NextNumber(-spread, spread), 0, rng:NextNumber(-spread * 0.4, spread * 0.4))
        if not placeAsset("Flower", fcf, rng:NextNumber(1.4, 2.2), parent) then
            part(parent, Vector3.new(0.7, 0.7, 0.7), fcf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0),
                FLOWERS[rng:NextInteger(1, #FLOWERS)], M.SmoothPlastic, { deco = true, noShadow = true, name = "Flower" })
        end
    end
end

-- ===== peças de construção =====
local function fence(parent, ax, az, bx, bz)
    local dx, dz = bx - ax, bz - az
    local len = math.sqrt(dx * dx + dz * dz)
    local n = math.max(1, math.ceil(len / 7))
    local ry = math.deg(math.atan2(-dx, -dz))
    for i = 0, n do
        local t = i / n
        part(parent, Vector3.new(0.7, 3.4, 0.7), L(ax + dx * t, 1.5, az + dz * t, ry), C.Wood, M.Wood, { name = "FencePost" })
    end
    for _, y in { 1.3, 2.6 } do
        part(parent, Vector3.new(0.35, 0.45, len), L(ax + dx / 2, y, az + dz / 2, ry), C.WoodDark, M.Wood, { name = "FenceRail" })
    end
end

local function gableRoof(parent, cf, w, d, top, color, o)
    o = o or {}
    local th45 = math.rad(45)
    local slabLen = d / 2 * math.sqrt(2) + (o.overhang or 1.4)
    for _, s in { -1, 1 } do
        if o.skipSide ~= s then
            local th = s * th45
            local center = Vector3.new(0, top + d / 4, s * d / 4) + Vector3.new(0, math.cos(th), math.sin(th)) * 0.45
            part(parent, Vector3.new(w + 2.4, 0.9, slabLen), cf * CFrame.new(center) * CFrame.Angles(th, 0, 0), color, M.RoofShingles, { name = "Roof" })
        end
    end
    if not o.noGable then
        local side = d / math.sqrt(2)
        part(parent, Vector3.new(w, side, side), cf * CFrame.new(0, top, 0) * CFrame.Angles(th45, 0, 0), o.gableColor or C.Plaster, M.Plaster, { name = "Gable" })
    end
    part(parent, Vector3.new(w + 2.8, 0.9, 0.9), cf * CFrame.new(0, top + d / 2 + 0.55, 0), C.WoodDark, M.Wood, { name = "Ridge" })
end

local function window(parent, cf, shutterColor, withBox)
    part(parent, Vector3.new(3.2, 3.2, 0.25), cf * CFrame.new(0, 0, 0.05), C.WoodDark, M.Wood, { deco = true })
    local g = part(parent, Vector3.new(2.6, 2.6, 0.3), cf * CFrame.new(0, 0, -0.05), Color3.fromRGB(70, 88, 110), M.SmoothPlastic, { deco = true, name = "Window" })
    CollectionService:AddTag(g, "VillageWindow")
    part(parent, Vector3.new(0.22, 2.6, 0.36), cf * CFrame.new(0, 0, -0.1), C.WoodDark, M.Wood, { deco = true })
    part(parent, Vector3.new(2.6, 0.22, 0.36), cf * CFrame.new(0, 0, -0.1), C.WoodDark, M.Wood, { deco = true })
    for _, sx in { -1, 1 } do
        part(parent, Vector3.new(1, 3, 0.25), cf * CFrame.new(sx * 1.9, 0, -0.02), shutterColor, M.Wood, { deco = true })
    end
    if withBox then
        part(parent, Vector3.new(3.4, 0.8, 0.9), cf * CFrame.new(0, -1.95, -0.45), C.Wood, M.WoodPlanks, { deco = true })
        for k = -1, 1 do
            part(parent, Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(k * 1, -1.3, -0.45) * CFrame.Angles(0, math.rad(45), 0),
                FLOWERS[rng:NextInteger(1, #FLOWERS)], M.SmoothPlastic, { deco = true, noShadow = true })
        end
    end
end

local function house(x, z, ry, o)
    local w, d, h = o.w or 16, o.d or 12, o.h or 10
    local roof = o.roof or ROOFS[1]
    local m = model(o.name or "Casa")
    local cf = L(x, 0, z, ry)
    local top = 1.4 + h
    reserve(x, z, math.max(w, d) + 6, math.max(w, d) + 6)

    part(m, Vector3.new(w + 1.4, 2.2, d + 1.4), cf * CFrame.new(0, 0.3, 0), C.StoneDark, M.Slate, { name = "Foundation" })
    part(m, Vector3.new(w, h, d), cf * CFrame.new(0, 1.4 + h / 2, 0), o.wall or C.Plaster, M.Plaster, { name = "Walls" })
    for _, sx in { -1, 1 } do
        for _, sz in { -1, 1 } do
            part(m, Vector3.new(1.1, h, 1.1), cf * CFrame.new(sx * w / 2, 1.4 + h / 2, sz * d / 2), C.WoodDark, M.Wood, { deco = true })
        end
    end
    for _, sz in { -1, 1 } do
        for _, y in { 1.4 + h * 0.76, top - 0.4 } do
            part(m, Vector3.new(w + 0.6, 0.7, 0.5), cf * CFrame.new(0, y, sz * (d / 2 + 0.05)), C.WoodDark, M.Wood, { deco = true })
        end
    end

    -- porta
    part(m, Vector3.new(4.2, 7.2, 0.5), cf * CFrame.new(0, 1.4 + 3.6, -d / 2 - 0.2), C.WoodDark, M.WoodPlanks, { name = "Door" })
    part(m, Vector3.new(0.5, 0.5, 0.4), cf * CFrame.new(1.4, 1.4 + 3.4, -d / 2 - 0.55), C.Gold, M.Metal, { deco = true })
    part(m, Vector3.new(5.4, 1.4, 2.2), cf * CFrame.new(0, 0.6, -d / 2 - 1.6), C.Stone, M.Slate, { name = "Step" })

    -- janelas
    local wy = 1.4 + h * 0.45
    for _, sx in { -1, 1 } do
        window(m, cf * CFrame.new(sx * (w / 2 - 3.1), wy, -d / 2 - 0.15), roof, true)
        window(m, cf * CFrame.new(sx * (w / 2 + 0.15), wy, 0) * CFrame.Angles(0, math.rad(sx > 0 and -90 or 90), 0), roof, false)
    end

    -- lanterna da porta
    part(m, Vector3.new(0.3, 0.3, 1), cf * CFrame.new(3, 1.4 + 7.1, -d / 2 - 0.5), C.Iron, M.Metal, { deco = true })
    lamp(m, cf * CFrame.new(3, 1.4 + 6.2, -d / 2 - 0.9), 14)

    -- placa
    if o.sign then
        local s = part(m, Vector3.new(8, 1.25, 0.35), cf * CFrame.new(0, 1.4 + h * 0.76 + 1.05, -d / 2 - 0.4), C.Wood, M.WoodPlanks, { name = "Sign" })
        sign(s, o.sign)
    end

    -- telhado
    gableRoof(m, cf, w, d, top, roof, { skipSide = o.halfRoof and 1 or nil })

    -- chaminé com fumaça
    if o.chimney ~= false then
        part(m, Vector3.new(2.4, 8, 2.4), cf * CFrame.new(w * 0.28, top + d / 4 + 1.8, d / 4), C.Stone, M.Slate, { name = "Chimney" })
        part(m, Vector3.new(3, 0.6, 3), cf * CFrame.new(w * 0.28, top + d / 4 + 5.9, d / 4), C.StoneDark, M.Slate, { deco = true })
        local holder = part(m, Vector3.new(1, 1, 1), cf * CFrame.new(w * 0.28, top + d / 4 + 6.6, d / 4), C.Stone, nil, { deco = true, transparency = 1, name = "SmokeHolder" })
        local sm = Instance.new("Smoke")
        sm.Color = Color3.fromRGB(225, 225, 225)
        sm.Opacity = 0.12
        sm.RiseVelocity = 4
        sm.Size = 1.2
        sm.Parent = holder
    end

    -- oficina meio restaurada
    if o.halfRoof then
        local th = math.rad(45)
        local len = d / 2 * math.sqrt(2) + 1.4
        for _, rx in { -w / 2 + 1, -w / 6, w / 6, w / 2 - 1 } do
            local center = Vector3.new(rx, top + d / 4, d / 4) + Vector3.new(0, math.cos(th), math.sin(th)) * 0.3
            part(m, Vector3.new(0.6, 0.6, len), cf * CFrame.new(center) * CFrame.Angles(th, 0, 0), C.Wood, M.Wood, { deco = true, name = "Rafter" })
        end
        for _, rx in { -w / 2 + 1, 0, w / 2 - 1 } do
            part(m, Vector3.new(0.5, h + 3, 0.5), cf * CFrame.new(rx, (h + 3) / 2, d / 2 + 2.6), C.Wood, M.Wood, { deco = true })
        end
        for _, y in { h * 0.5, h + 0.6 } do
            part(m, Vector3.new(w, 0.4, 2.2), cf * CFrame.new(0, y, d / 2 + 1.7), C.Wood, M.WoodPlanks, { name = "Scaffold" })
        end
        for k = 0, 3 do
            part(m, Vector3.new(6, 0.4, 1.2), cf * CFrame.new(-w / 2 - 2.5, 0.2 + k * 0.42, -d / 2 - 2.5 + (k % 2) * 0.3) * CFrame.Angles(0, math.rad(90 + rng:NextNumber(-6, 6)), 0), C.Wood, M.WoodPlanks, { deco = true })
        end
        m:SetAttribute("Restored", false)
    end
    return m
end

local function tower(parent, x, z, h, o)
    o = o or {}
    local m = model("Torre", parent)
    local cf = L(x, 0, z, face(x, z, 0, 0))
    reserve(x, z, 12, 12)
    part(m, Vector3.new(9, 3, 9), cf * CFrame.new(0, 0.8, 0), C.StoneDark, M.Slate)
    for _, sx in { -1, 1 } do
        for _, sz in { -1, 1 } do
            part(m, Vector3.new(1.6, h + 6, 1.6), cf * CFrame.new(sx * 3.4, (h + 6) / 2, sz * 3.4), C.Wood, M.Wood)
        end
    end
    part(m, Vector3.new(9.6, 1, 9.6), cf * CFrame.new(0, h, 0), C.WoodDark, M.WoodPlanks, { name = "Floor" })
    for _, s in { -1, 1 } do
        part(m, Vector3.new(9.6, 2.4, 0.6), cf * CFrame.new(0, h + 1.7, s * 4.5), C.Wood, M.WoodPlanks)
        part(m, Vector3.new(0.6, 2.4, 9.6), cf * CFrame.new(s * 4.5, h + 1.7, 0), C.Wood, M.WoodPlanks)
    end
    local brace = math.atan2(6.8, h * 0.7)
    for _, s in { -1, 1 } do
        part(m, Vector3.new(0.6, math.sqrt(6.8 ^ 2 + (h * 0.7) ^ 2), 0.6), cf * CFrame.new(0, h * 0.45, 4.4) * CFrame.Angles(0, 0, s * brace), C.WoodDark, M.Wood, { deco = true })
    end
    gableRoof(m, cf, 9, 9, h + 6, o.roof or ROOFS[1], { noGable = true, overhang = 1.8 })
    lamp(m, cf * CFrame.new(0, h + 4.2, 0), 26)
end

local function crate(parent, cf, s)
    part(parent, Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), C.Wood, M.WoodPlanks, { name = "Crate" })
end

local function barrel(parent, cf)
    cyl(parent, 2.2, 2.8, cf * CFrame.new(0, 1.4, 0), C.WoodDark, M.Wood, { name = "Barrel" })
end

local function hay(parent, cf)
    part(parent, Vector3.new(3.2, 2.2, 2.2), cf * CFrame.new(0, 1.1, 0), C.Hay, M.Fabric, { name = "Hay" })
end

local function bunting(parent, ax, az, bx, bz, y)
    local pts = { Vector3.new(ax, y, az), Vector3.new((ax + bx) / 2, y - 1.6, (az + bz) / 2), Vector3.new(bx, y, bz) }
    for s = 1, 2 do
        local w1, w2 = BASE:PointToWorldSpace(pts[s]), BASE:PointToWorldSpace(pts[s + 1])
        local len = (w2 - w1).Magnitude
        part(parent, Vector3.new(0.12, 0.12, len), CFrame.lookAt((w1 + w2) / 2, w2), C.Cream, M.Fabric, { deco = true, noShadow = true })
        local n = math.floor(len / 1.4)
        for k = 1, n do
            local fp = w1:Lerp(w2, (k - 0.5) / n)
            local fcf = CFrame.lookAt(fp, fp + (w2 - w1).Unit)
            part(parent, Vector3.new(0.08, 0.9, 0.9), fcf * CFrame.new(0, -0.55, 0) * CFrame.Angles(math.rad(45), 0, 0),
                CLOTH[(k + s) % #CLOTH + 1], M.Fabric, { deco = true, noShadow = true })
        end
    end
end

local function bench(parent, x, z, ry)
    local m = model("Banco", parent)
    local cf = L(x, 0, z, ry)
    part(m, Vector3.new(6, 0.5, 2), cf * CFrame.new(0, 1.7, 0), C.Wood, M.WoodPlanks, { class = "Seat", name = "Seat" })
    part(m, Vector3.new(6, 2, 0.4), cf * CFrame.new(0, 3, 0.9), C.Wood, M.WoodPlanks)
    for _, sx in { -1, 1 } do
        part(m, Vector3.new(0.5, 1.6, 1.8), cf * CFrame.new(sx * 2.5, 0.8, 0), C.Iron, M.Metal)
    end
end

local function flowerBed(parent, x, z, ry)
    local m = model("Canteiro", parent)
    local cf = L(x, 0, z, ry)
    part(m, Vector3.new(7, 0.9, 3), cf * CFrame.new(0, 0.45, 0), C.WoodDark, M.Wood)
    part(m, Vector3.new(6.4, 0.3, 2.4), cf * CFrame.new(0, 0.95, 0), C.Soil, M.SmoothPlastic, { deco = true })
    flowers(m, cf * CFrame.new(0, 1.1, 0), 6, 2.6)
    local holder = part(m, Vector3.new(6, 1, 3), cf * CFrame.new(0, 3, 0), C.Leaf, nil, { deco = true, transparency = 1, name = "Fireflies" })
    local e = Instance.new("ParticleEmitter")
    e.Color = ColorSequence.new(Color3.fromRGB(220, 255, 120))
    e.LightEmission = 1
    e.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.18),
        NumberSequenceKeypoint.new(0.8, 0.18), NumberSequenceKeypoint.new(1, 0),
    })
    e.Lifetime = NumberRange.new(3, 5)
    e.Rate = 3
    e.Speed = NumberRange.new(0.3, 0.8)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Enabled = false
    e.Parent = holder
    CollectionService:AddTag(holder, "VillageNight")
end

-- ===== áreas =====
local function terrain()
    local T = workspace.Terrain
    local c = BASE.Position
    local R = CONFIG.Radius + 12
    for k = 5, 1, -1 do -- saia em degraus para fundir com o relevo
        T:FillCylinder(CFrame.new(c + Vector3.new(0, -k * 3 - 15, 0)), 30, R + k * 9, M.Grass)
    end
    for k = 5, 1, -1 do
        T:FillCylinder(CFrame.new(c + Vector3.new(0, k * 5 + 60, 0)), 120, R + k * 9, M.Air)
    end
    T:FillCylinder(CFrame.new(c + Vector3.new(0, 60, 0)), 120, R, M.Air)
    T:FillCylinder(CFrame.new(c + Vector3.new(0, -15, 0)), 30, R, M.Grass)

    local function path(x, z, w, d)
        T:FillBlock(L(x, -2, z), Vector3.new(w, 4, d), M.Cobblestone)
    end
    T:FillCylinder(L(0, -2, 0), 4, 33, M.Cobblestone) -- praça
    path(0, -91, 12, 122) -- rua do mercado até o portão
    path(0, 92, 10, 120) -- rua sul
    path(0, 71, 204, 10) -- rua dos terrenos
    path(-42, -6, 22, 6)
    path(42, -6, 22, 6)
    path(0, -CONFIG.Radius - 12, 12, 24) -- saída para a trilha
    T:FillCylinder(L(0, -2, 0), 4, 7.2, M.Air) -- poço da fonte
    T:FillCylinder(L(0, -2.5, 0), 3, 7, M.Water)
end

local function buildWall()
    local m = model("Muralha")
    local R = CONFIG.Radius
    local gap = (CONFIG.GateWidth / 2 + 5) / R
    local arcs = { { gap, math.pi - gap }, { math.pi + gap, 2 * math.pi - gap } }
    local function at(a, r, y)
        return Vector3.new(r * math.sin(a), y, -r * math.cos(a))
    end
    local function cfAt(a, r, y)
        return CFrame.lookAt(BASE:PointToWorldSpace(at(a, r, y)), BASE:PointToWorldSpace(Vector3.new(0, y, 0)))
    end
    for _, arc in arcs do
        local a0, a1 = arc[1], arc[2]
        local n = math.ceil((a1 - a0) * R / 18)
        local da = (a1 - a0) / n
        local chord = 2 * R * math.sin(da / 2) + 0.4
        for i = 0, n - 1 do
            local a = a0 + (i + 0.5) * da
            part(m, Vector3.new(chord, 3.4, 4.4), cfAt(a, R, 1), C.Stone, M.Slate, { name = "WallBase" })
            local col = part(m, Vector3.new(chord, 20, 3), cfAt(a, R, 10), C.Stone, nil, { name = "WallCollider", transparency = 1 })
            col.CastShadow = false
            for _, y in { 4, 9.5 } do
                part(m, Vector3.new(chord, 0.8, 0.7), cfAt(a, R - 1.6, y), C.WoodDark, M.Wood, { deco = true })
            end
        end
        local steps = math.floor((a1 - a0) * R / 3.4)
        for i = 0, steps do
            local a = a0 + (a1 - a0) * i / steps
            local hh = rng:NextNumber(12.5, 15)
            local colr = C.Wood:Lerp(C.WoodDark, rng:NextNumber(0, 0.6))
            local base = cfAt(a, R, hh / 2)
            part(m, Vector3.new(2.6, hh, 2.6), base * CFrame.Angles(0, math.rad(45), 0), colr, M.Wood, { deco = true })
            part(m, Vector3.new(1.85, 1.85, 1.85), base * CFrame.new(0, hh / 2, 0) * CFrame.Angles(0, 0, math.rad(45)), colr, M.Wood, { deco = true })
        end
    end
    for _, a in { math.pi / 3, math.pi / 2, 2 * math.pi / 3, 4 * math.pi / 3, 3 * math.pi / 2, 5 * math.pi / 3 } do
        local p = at(a, R - 5, 0)
        tower(m, p.X, p.Z, 20, { roof = ROOFS[2] })
    end
end

local function buildGates()
    local m = model("Portoes")
    local R = CONFIG.Radius
    local gx = CONFIG.GateWidth / 2 + 4.5
    reserve(0, -R + 14, 36, 30)
    reserve(0, R - 14, 36, 30)

    -- PORTÃO DA TRILHA (floresta)
    for _, sx in { -1, 1 } do
        tower(m, sx * gx, -R + 1, 22, { roof = ROOFS[1] })
    end
    part(m, Vector3.new(gx * 2 + 2, 2.2, 2.2), L(0, 16, -R + 1), C.WoodDark, M.Wood, { name = "Arch" })
    local inner = part(m, Vector3.new(15, 3.6, 0.6), L(0, 14.6, -R + 2.6, 180), C.Wood, M.WoodPlanks, { name = "GateSignInside" })
    sign(inner, "TRILHA DA FLORESTA", "Cuidado com o Oruk à noite")
    local outer = part(m, Vector3.new(15, 3.6, 0.6), L(0, 14.6, -R - 0.6, 0), C.Wood, M.WoodPlanks, { name = "GateSignOutside" })
    sign(outer, "VILA REFÚGIO", "Área segura")
    local hinge = CONFIG.GateWidth / 2 - 0.4
    local ang = math.rad(75)
    for _, sx in { -1, 1 } do
        local cx = sx * (hinge - 3.75 * math.cos(ang))
        local cz = -R + 1 + 3.75 * math.sin(ang)
        local dcf = L(cx, 6.4, cz, sx > 0 and -105 or -75)
        part(m, Vector3.new(7.5, 12, 0.8), dcf, C.Wood, M.WoodPlanks, { name = "GateDoor" })
        for _, y in { -3.5, 3.5 } do
            part(m, Vector3.new(7.6, 0.6, 1), dcf * CFrame.new(0, y, 0), C.Iron, M.Metal, { deco = true })
        end
    end

    -- PONTO DE GRUPO
    local gpz = -R + 22
    for i = 0, 15 do
        local a = i / 16 * 2 * math.pi
        local x, z = 6.5 * math.sin(a), gpz - 6.5 * math.cos(a)
        part(m, Vector3.new(2.6, 0.2, 0.6), L(x, 0.1, z, face(x, z, 0, gpz)), C.Crystal, M.Neon, { deco = true, noShadow = true })
    end
    cyl(m, 5, 0.5, L(0, 0.25, gpz), C.Stone, M.Slate, { name = "GroupStone" })
    part(m, Vector3.new(0.6, 6, 0.6), L(9, 3, gpz), C.WoodDark, M.Wood)
    local gs = part(m, Vector3.new(5, 2.6, 0.3), L(9, 5.4, gpz + 0.4, 180), C.Wood, M.WoodPlanks, { name = "GroupSign" })
    sign(gs, "PONTO DE GRUPO", "Espere aqui para entrar junto")
    local gz = part(zonesF, Vector3.new(13, 8, 13), L(0, 4, gpz), C.Crystal, nil, { name = "GroupPoint", transparency = 1 })
    gz.CanCollide = false
    gz.CanQuery = false
    gz:SetAttribute("Gen", "Village")
    gz:SetAttribute("ZoneType", "GroupPoint")

    -- PORTÃO DO PORTO (fechado, futuro)
    for _, sx in { -1, 1 } do
        tower(m, sx * gx, R - 1, 22, { roof = ROOFS[3] })
        part(m, Vector3.new(7.8, 12.5, 0.9), L(sx * 3.9, 6.4, R - 1), C.Wood, M.WoodPlanks, { name = "PortDoor" })
    end
    part(m, Vector3.new(gx * 2 + 2, 2.2, 2.2), L(0, 16, R - 1), C.WoodDark, M.Wood)
    part(m, Vector3.new(16, 1, 1.2), L(0, 6.4, R - 1.9), C.WoodDark, M.Wood, { deco = true })
    local ps = part(m, Vector3.new(14, 3.6, 0.6), L(0, 14.6, R - 2.6, 0), C.Wood, M.WoodPlanks, { name = "PortSign" })
    sign(ps, "PORTO", "Novas ilhas — em breve")
end

local function treasureBoard(parent, x, z)
    local m = model("TreasureBoard", parent)
    local cf = L(x, 0, z, face(x, z, 0, 0))
    part(m, Vector3.new(9, 1.4, 2.2), cf * CFrame.new(0, 0.7, 0), C.Stone, M.Slate)
    local tab = part(m, Vector3.new(8, 6.5, 1.2), cf * CFrame.new(0, 4.6, 0), C.StoneDark, M.Slate, { name = "Tablet" })
    sign(tab, "TESOURO DA CAVERNA", "0 itens", { subName = "Count", color = C.Gold })
    part(m, Vector3.new(4, 2, 2.6), cf * CFrame.new(0, 1, -3), C.Wood, M.WoodPlanks, { name = "Chest" })
    part(m, Vector3.new(4.2, 2.8, 0.5), cf * CFrame.new(0, 3.2, -1.6) * CFrame.Angles(math.rad(-15), 0, 0), C.WoodDark, M.WoodPlanks, { name = "Lid" })
    local gold = part(m, Vector3.new(3.6, 0.6, 2.2), cf * CFrame.new(0, 2.1, -3), C.Gold, M.Neon, { deco = true, name = "Gold" })
    local pl = Instance.new("PointLight")
    pl.Color = C.Gold
    pl.Range = 9
    pl.Brightness = 1.2
    pl.Parent = gold
    for k = 1, 5 do
        cyl(m, 0.8, 0.15, cf * CFrame.new(rng:NextNumber(-3, 3), 0.1, -4.8 + rng:NextNumber(-1, 1)), C.Gold, M.Metal, { deco = true })
    end
end

local function highlightBoard(parent, x, z)
    local m = model("HighlightBoard", parent)
    local cf = L(x, 0, z, face(x, z, 0, 0))
    for _, sx in { -1, 1 } do
        part(m, Vector3.new(0.9, 9, 0.9), cf * CFrame.new(sx * 4.6, 4.5, 0), C.WoodDark, M.Wood)
    end
    local b = part(m, Vector3.new(8.4, 5.4, 0.5), cf * CFrame.new(0, 5, 0), C.Wood, M.WoodPlanks, { name = "Board" })
    sign(b, "DESTAQUE DA SEMANA", "Em breve...", { subName = "Winner" })
    part(m, Vector3.new(10.4, 0.5, 2.4), cf * CFrame.new(0, 9.2, 0), ROOFS[1], M.RoofShingles)
    part(m, Vector3.new(1.4, 1.4, 0.3), cf * CFrame.new(0, 10.3, 0) * CFrame.Angles(0, 0, math.rad(45)), C.Gold, M.Neon, { deco = true, name = "Star" })
end

local function buildPlaza()
    local m = model("Praca")
    reserve(0, 0, 70, 70)
    -- fonte + pedestal vazio da Lanterna Mestra
    for i = 0, 11 do
        local a = i / 12 * 2 * math.pi
        local x, z = 7.6 * math.sin(a), -7.6 * math.cos(a)
        part(m, Vector3.new(4.3, 2.4, 1.6), L(x, 0.8, z, face(x, z, 0, 0)), C.Stone, M.Slate, { name = "FountainRim" })
    end
    cyl(m, 3.2, 12, L(0, 1, 0), C.Stone, M.Slate, { name = "Pillar" })
    cyl(m, 4.8, 1, L(0, 7.4, 0), C.StoneDark, M.Slate)
    for i = 0, 3 do
        part(m, Vector3.new(0.5, 3, 0.5), L(0, 0, 0, i * 90) * CFrame.new(0, 9.2, -1.5) * CFrame.Angles(math.rad(-25), 0, 0), C.Gold, M.Metal, { deco = true, name = "EmptyCradle" })
    end
    local shards = { { 2.2, 0.5, 9.4 }, { -3, 0.5, 9.8 }, { 9.8, 0.5, -2 }, { -9.6, 0.5, 3.5 }, { 0.8, 8.2, 0.6 } }
    for i, s in shards do
        local sh = part(m, Vector3.new(0.6, 1.5, 0.6), L(s[1], s[2], s[3]) * CFrame.Angles(math.rad(rng:NextNumber(-40, 40)), math.rad(rng:NextNumber(0, 180)), math.rad(rng:NextNumber(-40, 40))), C.Crystal, M.Neon, { deco = true, name = "Shard" })
        if i == #shards then
            local pl = Instance.new("PointLight")
            pl.Color = C.Crystal
            pl.Range = 10
            pl.Parent = sh
        end
    end
    local plaque = part(m, Vector3.new(5, 2.6, 0.8), L(0, 1.4, 11, 180) * CFrame.Angles(math.rad(-15), 0, 0), C.StoneDark, M.Slate, { name = "LanternPlaque" })
    sign(plaque, "A LANTERNA MESTRA", "Levada pelo Oruk. Traga-a de volta.")

    for i = 0, 3 do
        local a = math.rad(45 + i * 90)
        local bx, bz = 19 * math.sin(a), -19 * math.cos(a)
        bench(m, bx, bz, face(bx, bz, 0, 0))
        local fx, fz = 25 * math.sin(a), -25 * math.cos(a)
        flowerBed(m, fx, fz, face(fx, fz, 0, 0))
        tree(m, 36 * math.sin(a), -36 * math.cos(a))
    end
    for i = 0, 7 do
        local a = math.rad(22.5 + i * 45)
        lampPost(m, 30 * math.sin(a), -30 * math.cos(a))
    end
    highlightBoard(m, -22, 0)
    treasureBoard(m, 22, 0)
end

local function stall(i, x, z, ry, color)
    local m = model(string.format("Stall_%02d", i), stallsF)
    m:SetAttribute("Gen", "Village")
    m:SetAttribute("StallId", i)
    m:SetAttribute("Owner", 0)
    local cf = L(x, 0, z, ry)
    reserve(x, z, 12, 12)
    local counter = part(m, Vector3.new(8.6, 3.2, 3), cf * CFrame.new(0, 1.6, -2), C.Wood, M.WoodPlanks, { name = "Counter" })
    m.PrimaryPart = counter
    part(m, Vector3.new(9, 0.4, 3.4), cf * CFrame.new(0, 3.4, -2), C.WoodDark, M.Wood, { name = "CounterTop" })
    for _, sx in { -1, 1 } do
        part(m, Vector3.new(0.7, 8.5, 0.7), cf * CFrame.new(sx * 4.4, 4.25, -3.4), C.WoodDark, M.Wood)
        part(m, Vector3.new(0.7, 10.1, 0.7), cf * CFrame.new(sx * 4.4, 5.05, 3.9), C.WoodDark, M.Wood)
    end
    local rise, run = 1.6, 7.8
    local th = -math.atan2(rise, run)
    local len = math.sqrt(rise ^ 2 + run ^ 2) + 0.6
    for k = 0, 5 do
        local sx = -4 + k * 1.6
        local col = (k % 2 == 0) and color or C.Cream
        part(m, Vector3.new(1.62, 0.25, len), cf * CFrame.new(sx, 9.3, 0.2) * CFrame.Angles(th, 0, 0), col, M.Fabric, { deco = true, name = "Canopy" })
        part(m, Vector3.new(1.6, 0.9, 0.15), cf * CFrame.new(sx, 8.05, -3.75), col, M.Fabric, { deco = true, noShadow = true })
    end
    local s = part(m, Vector3.new(6.4, 1.4, 0.3), cf * CFrame.new(0, 9.4, -4.1), C.Wood, M.WoodPlanks, { name = "Sign" })
    sign(s, string.format("BANCA %02d", i), "Livre", { subName = "Status" })
    crate(m, cf * CFrame.new(-2.6, 0, 2.6), 2)
    barrel(m, cf * CFrame.new(2.6, 0, 2.8))
    local own = part(m, Vector3.new(2, 1, 2), cf * CFrame.new(0, 0.5, 1.2), C.Wood, nil, { deco = true, transparency = 1, name = "OwnerSpot" })
    own.CastShadow = false
    local cus = part(m, Vector3.new(2, 1, 2), cf * CFrame.new(0, 0.5, -6), C.Wood, nil, { deco = true, transparency = 1, name = "CustomerSpot" })
    cus.CastShadow = false
end

local function buildMarket()
    local m = model("Mercado")
    reserve(0, -89, 16, 126)
    local i = 0
    for _, side in { -1, 1 } do
        for _, z in { -46, -64, -82, -100 } do
            i += 1
            stall(i, side * 14, z, side < 0 and -90 or 90, CLOTH[(i - 1) % #CLOTH + 1])
        end
    end
    for _, z in { -37, -55, -73, -91, -109, -127, -141 } do
        lampPost(m, -8, z)
        lampPost(m, 8, z)
    end
    for _, z in { -55, -91, -127 } do
        bunting(m, -8, z, 8, z, 10.6)
    end
    -- carroça e feno perto do portão
    local wcf = L(-24, 0, -130, 20)
    reserve(-24, -130, 10, 10)
    part(m, Vector3.new(4.4, 1.6, 7), wcf * CFrame.new(0, 2.6, 0), C.Wood, M.WoodPlanks)
    for _, sx in { -1, 1 } do
        part(m, Vector3.new(0.4, 1.4, 7), wcf * CFrame.new(sx * 2.2, 3.9, 0), C.WoodDark, M.Wood, { deco = true })
        for _, sz in { -1, 1 } do
            part(m, Vector3.new(0.6, 3.4, 3.4), wcf * CFrame.new(sx * 2.5, 1.7, sz * 2.2), C.WoodDark, M.Wood, { shape = Enum.PartType.Cylinder })
        end
    end
    part(m, Vector3.new(0.4, 0.4, 5), wcf * CFrame.new(0, 2.2, -5.5), C.WoodDark, M.Wood)
    hay(m, wcf * CFrame.new(0, 3.4, 1.2))
    hay(m, L(24, 0, -128, 10))
    hay(m, L(26, 0, -124, -30))
    crate(m, L(22, 0, -120, 15), 2.4)
    reserve(24, -125, 10, 12)
end

local function buildHouses()
    house(-60, -6, -90, { name = "CasaDaLumen", w = 18, d = 14, h = 11, roof = Color3.fromRGB(112, 78, 140), sign = "CASA DA DONA LÚMEN" })
    house(60, -6, 90, { name = "Oficina", w = 18, d = 14, h = 10, roof = ROOFS[4], wall = Color3.fromRGB(225, 205, 175), sign = "OFICINA", halfRoof = true, chimney = false })
    house(-46, -62, -90, { name = "Padaria", roof = ROOFS[1], sign = "PADARIA" })
    house(46, -62, 90, { name = "Armazem", roof = ROOFS[3], sign = "ARMAZÉM" })
    house(-46, -106, -90, { roof = ROOFS[2] })
    house(46, -106, 90, { roof = ROOFS[1] })
    house(-94, -28, -90, { roof = ROOFS[3] })
    house(94, -28, 90, { roof = ROOFS[2] })
    house(-90, -74, -90, { roof = ROOFS[4] })
    house(90, -74, 90, { roof = ROOFS[3] })
    reserve(-42, -6, 22, 8)
    reserve(42, -6, 22, 8)
end

local function plot(id, x, z, side)
    local S, h, gap = 28, 14, 4
    local m = model(string.format("Plot_%02d", id), plotsF)
    m:SetAttribute("Gen", "Village")
    m:SetAttribute("PlotId", id)
    m:SetAttribute("Owner", 0)
    reserve(x, z, S + 3, S + 3)
    local base = part(m, Vector3.new(S, 1, S), L(x, -0.45, z), C.Leaf, M.Grass, { name = "Base", transparency = 1, deco = true })
    m.PrimaryPart = base
    local ez, oz = z + side * h, z - side * h
    fence(m, x - h, oz, x + h, oz)
    fence(m, x - h, oz, x - h, ez)
    fence(m, x + h, oz, x + h, ez)
    fence(m, x - h, ez, x - gap, ez)
    fence(m, x + gap, ez, x + h, ez)
    local sx = x + gap + 1.6
    part(m, Vector3.new(0.6, 5, 0.6), L(sx, 2.5, ez + side * 0.8), C.WoodDark, M.Wood)
    local board = part(m, Vector3.new(4.4, 2.4, 0.3), L(sx, 4.6, ez + side * 1.2, side > 0 and 180 or 0), C.Wood, M.WoodPlanks, { name = "Sign" })
    sign(board, string.format("TERRENO %02d", id), "Livre", { subName = "Status" })
    local mx = x - gap - 1.6
    part(m, Vector3.new(0.5, 3.4, 0.5), L(mx, 1.7, ez + side * 0.8), C.WoodDark, M.Wood)
    part(m, Vector3.new(1.4, 1.1, 2), L(mx, 3.8, ez + side * 0.8), ROOFS[(id % #ROOFS) + 1], M.SmoothPlastic, { name = "Mailbox" })
end

local function buildPlots()
    local m = model("Bairro")
    local id = 0
    for _, row in { { 52, 1 }, { 90, -1 } } do
        for _, x in { -84, -52, -20, 20, 52, 84 } do
            id += 1
            plot(id, x, row[1], row[2])
        end
    end
    reserve(0, 71, 214, 12)
    reserve(0, 92, 14, 124)
    for _, p in { { -68, 67 }, { 68, 67 }, { -36, 75.3 }, { 36, 75.3 }, { -7, 34 }, { 7, 34 }, { -7, 110 }, { 7, 110 } } do
        lampPost(m, p[1], p[2])
    end
    -- poço
    local wcf = L(-44, 0, 24)
    reserve(-44, 24, 10, 10)
    cyl(m, 6, 3, wcf * CFrame.new(0, 1.2, 0), C.Stone, M.Slate, { name = "Well" })
    cyl(m, 4.6, 0.3, wcf * CFrame.new(0, 2.6, 0), Color3.fromRGB(40, 70, 90), M.SmoothPlastic, { deco = true })
    for _, sx in { -1, 1 } do
        part(m, Vector3.new(0.7, 7, 0.7), wcf * CFrame.new(sx * 2.6, 3.5, 0), C.Wood, M.Wood)
    end
    part(m, Vector3.new(5.8, 0.5, 0.5), wcf * CFrame.new(0, 6.2, 0), C.WoodDark, M.Wood, { deco = true })
    part(m, Vector3.new(1, 1.1, 1), wcf * CFrame.new(0, 4.2, 0), C.Wood, M.Wood, { deco = true, name = "Bucket" })
    gableRoof(m, wcf, 6, 4.5, 7, ROOFS[1], { noGable = true, overhang = 1 })
end

local function scatterNature()
    local m = model("Natureza")
    local R = CONFIG.Radius
    local placed = 0
    for _ = 1, 400 do
        local a = rng:NextNumber(0, 2 * math.pi)
        local r = rng:NextNumber(38, R - 12)
        local x, z = r * math.sin(a), -r * math.cos(a)
        if isFree(x, z, 5) then
            tree(m, x, z)
            reserve(x, z, 6, 6)
            placed += 1
            if placed >= CONFIG.MaxTrees then break end
        end
    end
    for _ = 1, 90 do
        local a = rng:NextNumber(0, 2 * math.pi)
        local r = R - rng:NextNumber(4, 9)
        local x, z = r * math.sin(a), -r * math.cos(a)
        if isFree(x, z, 1.5) then
            if rng:NextNumber() < 0.7 then bush(m, x, z) else rock(m, x, z) end
            reserve(x, z, 3, 3)
        end
    end
    for _ = 1, 40 do
        local a = rng:NextNumber(0, 2 * math.pi)
        local r = rng:NextNumber(36, R - 14)
        local x, z = r * math.sin(a), -r * math.cos(a)
        if isFree(x, z, 2) then
            flowers(m, L(x, 0, z, rng:NextNumber(0, 360)), 4, 2)
        end
    end
end

-- ===== principal =====
function Builder.Build()
    local marker = workspace:FindFirstChild("VillageCenter")
    assert(marker and marker:IsA("BasePart"), "[VillageBuilder] Crie um Part chamado VillageCenter no Workspace.")
    rng = Random.new(CONFIG.Seed)
    reserved = {}
    local assets = ServerStorage:FindFirstChild("Assets")
    nature = assets and assets:FindFirstChild("Nature")

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { workspace.Terrain }
    local p = marker.Position
    local hit = workspace:Raycast(Vector3.new(p.X, p.Y + 500, p.Z), Vector3.new(0, -2000, 0), params)
    local y0 = math.floor((hit and hit.Position.Y or p.Y) / 4 + 0.5) * 4
    local look = marker.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
    local pos = Vector3.new(p.X, y0, p.Z)
    BASE = CFrame.lookAt(pos, pos + flat.Unit)
    marker.Anchored = true
    marker.Transparency = 1
    marker.CanCollide = false
    marker.CanQuery = false
    marker.CanTouch = false

    local map = workspace:FindFirstChild("Map")
    if not map then
        map = Instance.new("Folder")
        map.Name = "Map"
        map.Parent = workspace
    end
    local old = map:FindFirstChild("Village")
    if old then old:Destroy() end
    root = Instance.new("Model")
    root.Name = "Village"
    root:SetAttribute("Gen", "Village")
    root.Parent = map

    local function ensure(name)
        local f = workspace:FindFirstChild(name)
        if not f then
            f = Instance.new("Folder")
            f.Name = name
            f.Parent = workspace
        end
        for _, c in f:GetChildren() do
            if c:GetAttribute("Gen") == "Village" then c:Destroy() end
        end
        return f
    end
    plotsF, stallsF, zonesF, spawnsF = ensure("Plots"), ensure("Stalls"), ensure("Zones"), ensure("Spawns")

    terrain()
    buildWall()
    buildGates()
    buildPlaza()
    buildMarket()
    buildHouses()
    buildPlots()
    scatterNature()

    local zone = part(zonesF, Vector3.new(CONFIG.Radius * 2 + 10, 120, CONFIG.Radius * 2 + 10), L(0, 50, 0), C.Leaf, nil, { name = "Vila", transparency = 1 })
    zone.CanCollide = false
    zone.CanQuery = false
    zone.CastShadow = false
    zone:SetAttribute("Gen", "Village")
    zone:SetAttribute("ZoneType", "Village")
    zone:SetAttribute("Safe", true)

    local sp = Instance.new("SpawnLocation")
    sp.Name = "Spawn_Praca"
    sp.Anchored = true
    sp.Size = Vector3.new(6, 1, 6)
    sp.CFrame = L(0, -0.3, 18)
    sp.Transparency = 1
    sp.CanCollide = false
    sp.CanQuery = false
    sp.Neutral = true
    sp.Duration = 0
    sp:SetAttribute("Gen", "Village")
    sp:SetAttribute("Kind", "Respawn")
    sp.Parent = spawnsF

    local n = 0
    for _, inst in { root, plotsF, stallsF } do
        for _, d in inst:GetDescendants() do
            if d:IsA("BasePart") then n += 1 end
        end
    end
    print(string.format("[VillageBuilder] Vila pronta: %d peças | natureza da 3.3: %s", n, nature and "SIM" or "não (usando low-poly próprio)"))
end

return Builder
