--!nocheck
-- VillageBuilder.luau — REFÚGIO · Vila Oficial de Altíssima Qualidade (Etapa 3.2 definitiva)
-- Gera a vila oficial completa com alto nível de detalhe arquitetônico, visual low-poly estilizado
-- e total compatibilidade com o loop de jogo (Oficina, Casa da Lúmen, Taverna, Padaria, Mercado,
-- Terrenos residenciais com caixas de correio, Muralha fortificada e Portões da Trilha).
--
-- Pode ser executado repetidamente (idempotente): remove apenas o que ele próprio gerou.
-- Command Bar (Studio modo Edit):
--   local m = game.ServerScriptService:FindFirstChild("VillageBuilder", true)
--   require(m:Clone()).Build()

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Builder = {}

local CONFIG = {
    Radius = 150,           -- Raio da muralha (vila circular com 300 studs de diâmetro)
    GateWidth = 18,         -- Vão livre dos portões principais
    Seed = 2026,            -- Seed consistente para mesma distribuição
    MaxTrees = 45,          -- Árvores espalhadas nos canteiros da vila
    FlattenTerrain = true,  -- Aplaina o platô no terreno garantindo fundações perfeitas
}

local M = Enum.Material

local C = {
    -- Madeiras
    Wood = Color3.fromRGB(118, 80, 50),
    WoodDark = Color3.fromRGB(76, 49, 32),
    WoodLight = Color3.fromRGB(158, 120, 82),
    WoodPlank = Color3.fromRGB(138, 98, 65),
    
    -- Paredes & Reboco
    Plaster = Color3.fromRGB(244, 236, 218),
    PlasterWarm = Color3.fromRGB(238, 222, 196),
    PlasterAged = Color3.fromRGB(218, 206, 184),
    
    -- Alvenaria & Pedras
    Stone = Color3.fromRGB(142, 140, 134),
    StoneDark = Color3.fromRGB(98, 96, 92),
    StoneLight = Color3.fromRGB(175, 172, 166),
    Cobble = Color3.fromRGB(120, 118, 114),
    
    -- Telhados & Tecidos
    Terracotta = Color3.fromRGB(176, 68, 52),
    Navy = Color3.fromRGB(64, 88, 136),
    ForestGreen = Color3.fromRGB(66, 112, 72),
    Ochre = Color3.fromRGB(192, 120, 52),
    TwilightPurple = Color3.fromRGB(105, 70, 132),
    Cream = Color3.fromRGB(250, 245, 235),
    
    -- Metais & Iluminação
    Iron = Color3.fromRGB(42, 42, 48),
    Brass = Color3.fromRGB(195, 150, 60),
    Gold = Color3.fromRGB(255, 204, 60),
    Crystal = Color3.fromRGB(115, 225, 255),
    WarmLight = Color3.fromRGB(255, 196, 110),
    Fire = Color3.fromRGB(255, 130, 40),
    
    -- Natureza
    Leaf = Color3.fromRGB(82, 146, 70),
    LeafLight = Color3.fromRGB(118, 172, 80),
    Soil = Color3.fromRGB(86, 58, 40),
}

local ROOFS = { C.Terracotta, C.Navy, C.ForestGreen, C.Ochre }
local CLOTH = {
    Color3.fromRGB(215, 65, 65),   -- Vermelho
    Color3.fromRGB(55, 125, 210),  -- Azul
    Color3.fromRGB(75, 160, 95),   -- Verde
    Color3.fromRGB(235, 175, 50),  -- Ouro / Amarelo
    Color3.fromRGB(170, 85, 185),  -- Roxo
    Color3.fromRGB(225, 120, 50),  -- Laranja
}
local FLOWERS = {
    Color3.fromRGB(255, 80, 100),  -- Rosa vibrante
    Color3.fromRGB(255, 215, 60),  -- Dourado
    Color3.fromRGB(165, 110, 255), -- Lavanda
    Color3.fromRGB(255, 255, 255), -- Branco puro
    Color3.fromRGB(80, 185, 255),  -- Celeste
}

local rng, BASE, root, nature
local plotsF, stallsF, zonesF, spawnsF
local reserved = {}

-- ===== Utilitários de Posicionamento e Espaço =====

local function L(x, y, z, ry)
    return BASE * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(ry or 0), 0)
end

local function face(x, z, tx, tz)
    return math.deg(math.atan2(-(tx - x), -(tz - z)))
end

local function reserve(x, z, w, d)
    table.insert(reserved, { x = x, z = z, hw = w / 2, hd = d / 2 })
end

local function isFree(x, z, margin)
    margin = margin or 0
    for _, r in ipairs(reserved) do
        if math.abs(x - r.x) < (r.hw + margin) and math.abs(z - r.z) < (r.hd + margin) then
            return false
        end
    end
    return true
end

-- ===== Construtores de Primitivas com Tags de Física e Performance =====

local function model(name, parent)
    local m = Instance.new("Model")
    m.Name = name
    m:SetAttribute("Gen", "Village")
    m.Parent = parent or root
    return m
end

local function part(parent, size, cf, color, mat, o)
    o = o or {}
    local p = Instance.new(o.class or "Part")
    p.Name = o.name or "Part"
    p.Anchored = true
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = mat or M.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p:SetAttribute("Gen", "Village")
    
    if o.shape then p.Shape = o.shape end
    if o.deco then
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
    end
    if o.noShadow then p.CastShadow = false end
    if o.transparency then p.Transparency = o.transparency end
    
    p.Parent = parent
    return p
end

local function wedge(parent, size, cf, color, mat, o)
    o = o or {}
    o.class = "WedgePart"
    return part(parent, size, cf, color, mat, o)
end

local function cyl(parent, diameter, height, cf, color, mat, o)
    o = o or {}
    o.shape = Enum.PartType.Cylinder
    return part(parent, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, mat, o)
end

-- ===== Placas Estilizadas com SurfaceGui Nítida =====

local function sign(p, title, sub, o)
    o = o or {}
    local gui = Instance.new("SurfaceGui")
    gui.Name = "SignGui"
    gui.Face = o.face or Enum.NormalId.Back
    gui.LightInfluence = 0.25
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 32
    gui.Parent = p

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = o.bgColor or Color3.fromRGB(36, 26, 18)
    bg.BorderSizePixel = 0
    bg.Parent = gui
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = o.strokeColor or C.Brass
    stroke.Thickness = 2.5
    stroke.Parent = bg

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = bg

    local function label(name, text, y, h, size, color, font)
        local l = Instance.new("TextLabel")
        l.Name = name
        l.Size = UDim2.new(1, 0, h, 0)
        l.Position = UDim2.new(0, 0, y, 0)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = color or Color3.new(1, 1, 1)
        l.Font = font or Enum.Font.FredokaOne
        l.TextScaled = true
        l.Parent = bg
        return l
    end

    label("Title", title, 0.05, 0.52, 22, o.color or C.Gold, Enum.Font.FredokaOne)
    if sub then
        label(o.subName or "Sub", sub, 0.58, 0.38, 14, o.subColor or Color3.fromRGB(220, 210, 195), Enum.Font.GothamMedium)
    end
    return gui
end

-- ===== Iluminação Quente e Ambiência Noturna =====

local function lamp(parent, cf, range, brightness)
    range = range or 22
    brightness = brightness or 1.5
    
    -- Suporte de ferro forjado
    part(parent, Vector3.new(0.3, 0.6, 0.3), cf * CFrame.new(0, 0.5, 0), C.Iron, M.Metal, { deco = true })
    
    -- Lanterna sextavada
    local lantern = part(parent, Vector3.new(0.8, 1.1, 0.8), cf, C.Iron, M.Metal, { deco = true, name = "Lantern" })
    
    -- Núcleo brilhante (vela interna)
    local glow = part(parent, Vector3.new(0.48, 0.75, 0.48), cf, C.WarmLight, M.Neon, { deco = true, noShadow = true, name = "LightGlow" })
    
    local pl = Instance.new("PointLight")
    pl.Color = C.WarmLight
    pl.Range = range
    pl.Brightness = brightness
    pl.Shadows = true
    pl.Parent = glow
    
    CollectionService:AddTag(glow, "VillageNight")
    return glow
end

local function lampPost(parent, x, z)
    local m = model("LampPost", parent)
    local cf = L(x, 0, z)
    
    -- Base de pedra esculpida
    cyl(m, 2.4, 1.2, cf * CFrame.new(0, 0.6, 0), C.Stone, M.Slate, { name = "Base" })
    part(m, Vector3.new(1.8, 0.4, 1.8), cf * CFrame.new(0, 1.4, 0), C.StoneDark, M.Slate, { deco = true })
    
    -- Poste de madeira nobre chanfrada
    part(m, Vector3.new(0.8, 10, 0.8), cf * CFrame.new(0, 6.4, 0), C.WoodDark, M.Wood, { name = "Post" })
    
    -- Suportes diagonais de ferro forjado
    part(m, Vector3.new(0.25, 1.6, 0.25), cf * CFrame.new(0, 2.2, 0.5) * CFrame.Angles(math.rad(30), 0, 0), C.Iron, M.Metal, { deco = true })
    part(m, Vector3.new(0.25, 1.6, 0.25), cf * CFrame.new(0, 2.2, -0.5) * CFrame.Angles(math.rad(-30), 0, 0), C.Iron, M.Metal, { deco = true })
    
    -- Braço curvo superior com lanternas duplas
    part(m, Vector3.new(3.6, 0.4, 0.4), cf * CFrame.new(0, 11.2, 0), C.Iron, M.Metal, { deco = true })
    part(m, Vector3.new(0.4, 0.6, 0.4), cf * CFrame.new(0, 11.7, 0), C.Brass, M.Metal, { deco = true })
    
    lamp(m, cf * CFrame.new(1.5, 10.3, 0), 24, 1.6)
    lamp(m, cf * CFrame.new(-1.5, 10.3, 0), 24, 1.6)
end

-- Chaminé estilizada com fumaça subindo suavemente
local function chimneyWithSmoke(parent, cf, height)
    height = height or 8
    local c = part(parent, Vector3.new(2.4, height, 2.4), cf * CFrame.new(0, height / 2, 0), C.StoneDark, M.Cobblestone, { name = "Chimney" })
    part(parent, Vector3.new(2.8, 0.6, 2.8), cf * CFrame.new(0, height + 0.3, 0), C.Stone, M.Slate, { deco = true })
    
    local emitterPart = part(parent, Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0, height + 0.8, 0), C.StoneDark, M.SmoothPlastic, { deco = true, transparency = 1 })
    
    local sm = Instance.new("ParticleEmitter")
    sm.Name = "Smoke"
    sm.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sm.Color = ColorSequence.new(Color3.fromRGB(220, 218, 215))
    sm.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(0.3, 0.4),
        NumberSequenceKeypoint.new(0.8, 0.7),
        NumberSequenceKeypoint.new(1, 1),
    })
    sm.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(0.4, 2.2),
        NumberSequenceKeypoint.new(1, 4.5),
    })
    sm.Lifetime = NumberRange.new(4, 6)
    sm.Rate = 2.5
    sm.Speed = NumberRange.new(2.5, 4.5)
    sm.SpreadAngle = Vector2.new(12, 12)
    sm.EmissionDirection = Enum.NormalId.Top
    sm.Parent = emitterPart
end

-- ===== Elementos de Cenário e Decoração Rústica =====

local function crate(parent, cf, s)
    s = s or 2.4
    local c = part(parent, Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), C.WoodLight, M.WoodPlanks, { name = "Crate" })
    part(parent, Vector3.new(s + 0.08, 0.25, s + 0.08), cf * CFrame.new(0, s * 0.25, 0), C.WoodDark, M.Wood, { deco = true })
    part(parent, Vector3.new(s + 0.08, 0.25, s + 0.08), cf * CFrame.new(0, s * 0.75, 0), C.WoodDark, M.Wood, { deco = true })
    return c
end

local function barrel(parent, cf)
    local m = cyl(parent, 2.3, 3.2, cf * CFrame.new(0, 1.6, 0), C.Wood, M.Wood, { name = "Barrel" })
    cyl(parent, 2.45, 0.25, cf * CFrame.new(0, 0.7, 0), C.Iron, M.Metal, { deco = true })
    cyl(parent, 2.45, 0.25, cf * CFrame.new(0, 2.5, 0), C.Iron, M.Metal, { deco = true })
    return m
end

local function hayBale(parent, cf)
    local hayColor = Color3.fromRGB(225, 192, 105)
    local ropeColor = Color3.fromRGB(145, 115, 65)

    local h = part(
        parent,
        Vector3.new(3.8, 2.4, 2.6),
        cf * CFrame.new(0, 1.2, 0),
        hayColor,
        M.Fabric,
        { name = "HayBale" }
    )

    part(
        parent,
        Vector3.new(3.85, 0.12, 2.65),
        cf * CFrame.new(0, 0.8, 0),
        ropeColor,
        M.Fabric,
        { deco = true }
    )

    part(
        parent,
        Vector3.new(3.85, 0.12, 2.65),
        cf * CFrame.new(0, 1.6, 0),
        ropeColor,
        M.Fabric,
        { deco = true }
    )

    return h
end
local function bench(parent, x, z, ry)
    local cf = L(x, 0, z, ry)
    local m = model("Bench", parent)
    -- Pés de ferro
    for _, sx in { -2.8, 2.8 } do
        part(m, Vector3.new(0.4, 1.6, 1.8), cf * CFrame.new(sx, 0.8, 0), C.Iron, M.Metal, { deco = true })
        part(m, Vector3.new(0.4, 2.2, 0.3), cf * CFrame.new(sx, 1.9, 0.85), C.Iron, M.Metal, { deco = true })
    end
    -- Assento
    part(m, Vector3.new(6.4, 0.3, 1.9), cf * CFrame.new(0, 1.6, 0), C.WoodLight, M.WoodPlanks, { name = "Seat" })
    -- Encosto
    part(m, Vector3.new(6.4, 1.2, 0.3), cf * CFrame.new(0, 2.5, 0.85), C.Wood, M.WoodPlanks, { deco = true })
end

local function flowerBed(parent, x, z, ry)
    local cf = L(x, 0, z, ry)
    local m = model("FlowerBed", parent)
    -- Borda de pedra
    part(m, Vector3.new(7.4, 0.8, 3.4), cf * CFrame.new(0, 0.4, 0), C.Stone, M.Slate, { name = "Rim" })
    -- Terra fofa
    part(m, Vector3.new(6.4, 0.7, 2.4), cf * CFrame.new(0, 0.5, 0), C.Soil, M.Ground, { deco = true })
    -- Flores coloridas
    for _ = 1, 14 do
        local fx, fz = rng:NextNumber(-2.8, 2.8), rng:NextNumber(-0.9, 0.9)
        local fcol = FLOWERS[rng:NextInteger(1, #FLOWERS)]
        cyl(m, 0.8, 0.6, cf * CFrame.new(fx, 1.0, fz), fcol, M.Grass, { deco = true, noShadow = true })
    end
end

local function bunting(parent, ax, az, bx, bz, y)
    local A, B = L(ax, y, az).Position, L(bx, y, bz).Position
    local dir = (B - A)
    local len = dir.Magnitude
    local steps = math.max(4, math.floor(len / 3.2))
    for i = 0, steps do
        local t = i / steps
        local sag = 1.4 * math.sin(t * math.pi)
        local p = A:Lerp(B, t) - Vector3.new(0, sag, 0)
        local col = CLOTH[(i % #CLOTH) + 1]
        wedge(parent, Vector3.new(0.12, 1.2, 1.1), CFrame.new(p) * CFrame.Angles(0, math.rad(i * 35), math.pi), col, M.Fabric, { deco = true, noShadow = true })
    end
end

-- ===== Arquitetura Modular de Alto Detalhe =====

local function timberWall(parent, cf, w, h, d, wallColor, beamColor)
    wallColor = wallColor or C.Plaster
    beamColor = beamColor or C.WoodDark
    
    -- Painel de estuque (recuado 0.2 studs para relevo real sob iluminação Future)
    part(parent, Vector3.new(w - 0.2, h, d - 0.3), cf, wallColor, M.SmoothPlastic, { name = "WallPanel" })
    
    -- Vigas horizontais estruturais (base e topo)
    part(parent, Vector3.new(w + 0.1, 0.7, d), cf * CFrame.new(0, -h / 2 + 0.35, 0), beamColor, M.Wood, { deco = true })
    part(parent, Vector3.new(w + 0.1, 0.7, d), cf * CFrame.new(0, h / 2 - 0.35, 0), beamColor, M.Wood, { deco = true })
    
    -- Colunas verticais nas extremidades
    part(parent, Vector3.new(0.7, h, d), cf * CFrame.new(-w / 2 + 0.35, 0, 0), beamColor, M.Wood, { deco = true })
    part(parent, Vector3.new(0.7, h, d), cf * CFrame.new(w / 2 - 0.35, 0, 0), beamColor, M.Wood, { deco = true })
end

local function detailedWindow(parent, cf, shutterColor)
    shutterColor = shutterColor or C.WoodDark
    
    -- Peitoril de pedra
    part(parent, Vector3.new(3.8, 0.4, 0.9), cf * CFrame.new(0, -2.1, 0), C.Stone, M.Slate, { deco = true })
    -- Moldura de madeira
    part(parent, Vector3.new(3.4, 3.8, 0.5), cf, C.WoodDark, M.Wood, { deco = true })
    -- Vidro aquecido com leve brilho aconchegante
    local glass = part(parent, Vector3.new(2.6, 3.0, 0.2), cf * CFrame.new(0, 0, 0.1), C.WarmLight, M.Neon, { deco = true, noShadow = true, name = "WindowGlass" })
    glass.Transparency = 0.15
    
    -- Cruzeta da janela
    part(parent, Vector3.new(0.2, 3.0, 0.25), cf * CFrame.new(0, 0, 0.15), C.WoodDark, M.Wood, { deco = true })
    part(parent, Vector3.new(2.6, 0.2, 0.25), cf * CFrame.new(0, 0, 0.15), C.WoodDark, M.Wood, { deco = true })
    
    -- Venezianas laterais abertas
    part(parent, Vector3.new(1.1, 3.4, 0.25), cf * CFrame.new(-2.1, 0, 0.1) * CFrame.Angles(0, math.rad(-15), 0), shutterColor, M.WoodPlanks, { deco = true })
    part(parent, Vector3.new(1.1, 3.4, 0.25), cf * CFrame.new(2.1, 0, 0.1) * CFrame.Angles(0, math.rad(15), 0), shutterColor, M.WoodPlanks, { deco = true })
    
    -- Jardineira de flores na janela
    part(parent, Vector3.new(3.2, 0.7, 0.8), cf * CFrame.new(0, -2.5, 0.35), C.WoodDark, M.Wood, { deco = true })
    for i = -1.2, 1.2, 0.6 do
        local fcol = FLOWERS[rng:NextInteger(1, #FLOWERS)]
        cyl(parent, 0.7, 0.5, cf * CFrame.new(i, -2.0, 0.45), fcol, M.Grass, { deco = true, noShadow = true })
    end
end

local function detailedDoor(parent, cf)
    -- Moldura de madeira maciça
    part(parent, Vector3.new(4.2, 7.8, 0.7), cf * CFrame.new(0, 3.9, 0), C.WoodDark, M.Wood, { deco = true })
    -- Folha da porta
    part(parent, Vector3.new(3.2, 7.0, 0.4), cf * CFrame.new(0, 3.8, 0.1), C.Wood, M.WoodPlanks, { name = "Door" })
    -- Dobradiças de ferro forjado
    part(parent, Vector3.new(2.6, 0.35, 0.5), cf * CFrame.new(-0.2, 5.8, 0.2), C.Iron, M.Metal, { deco = true })
    part(parent, Vector3.new(2.6, 0.35, 0.5), cf * CFrame.new(-0.2, 2.2, 0.2), C.Iron, M.Metal, { deco = true })
    -- Puxador / maçaneta
    part(parent, Vector3.new(0.3, 0.6, 0.4), cf * CFrame.new(1.1, 3.8, 0.25), C.Brass, M.Metal, { deco = true })
    -- Degrau de pedra na entrada
    part(parent, Vector3.new(4.8, 0.4, 2.2), cf * CFrame.new(0, 0.2, 1.0), C.Stone, M.Slate, { name = "Step" })
    -- Arandela com lanterna sobre a porta
    lamp(parent, cf * CFrame.new(0, 8.4, 0.8), 18, 1.4)
end

local function gableRoof(parent, cf, w, d, height, roofColor)
    roofColor = roofColor or C.Terracotta
    local over = 1.6 -- Beiral generoso
    local hw = (w + over * 2) / 2
    local totalD = d + over * 2
    local slopeLen = math.sqrt(hw ^ 2 + height ^ 2)
    local ang = math.atan2(height, hw)

    -- Água esquerda
    wedge(parent, Vector3.new(totalD, height, hw),
        cf * CFrame.new(-hw / 2, height / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0),
        roofColor, M.WoodPlanks, { name = "RoofLeft" })

    -- Água direita
    wedge(parent, Vector3.new(totalD, height, hw),
        cf * CFrame.new(hw / 2, height / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
        roofColor, M.WoodPlanks, { name = "RoofRight" })

    -- Viga de cumeeira no topo
    part(parent, Vector3.new(0.8, 0.8, totalD + 0.4), cf * CFrame.new(0, height + 0.3, 0), C.WoodDark, M.Wood, { deco = true })
    
    -- Frontões triangulares (fechamento do sótão)
    part(parent, Vector3.new(w - 0.2, height * 0.75, 0.6), cf * CFrame.new(0, height * 0.4, -d / 2), C.PlasterWarm, M.SmoothPlastic, { deco = true })
    part(parent, Vector3.new(w - 0.2, height * 0.75, 0.6), cf * CFrame.new(0, height * 0.4, d / 2), C.PlasterWarm, M.SmoothPlastic, { deco = true })
end

-- ===== Edifícios Especiais da Vila =====

-- 1. Sede de Dona Lúmen (Mansão de 2 Pavimentos com Torre de Sino)
local function buildLumenManor(x, z, ry)
    local m = model("CasaDaLumen")
    local cf = L(x, 0, z, ry)
    reserve(x, z, 26, 22)
    
    local w, d, h1, h2 = 20, 16, 11, 9
    
    -- Base e fundação de pedra de cantaria
    part(m, Vector3.new(w + 1.2, 1.4, d + 1.2), cf * CFrame.new(0, 0.7, 0), C.Stone, M.Slate, { name = "Foundation" })
    
    -- 1º Pavimento
    timberWall(m, cf * CFrame.new(0, 1.4 + h1 / 2, 0), w, h1, d, C.PlasterWarm, C.WoodDark)
    detailedDoor(m, cf * CFrame.new(0, 1.4, d / 2))
    detailedWindow(m, cf * CFrame.new(-5.5, 6.2, d / 2), C.TwilightPurple)
    detailedWindow(m, cf * CFrame.new(5.5, 6.2, d / 2), C.TwilightPurple)
    detailedWindow(m, cf * CFrame.new(-w / 2, 6.2, 0) * CFrame.Angles(0, math.rad(-90), 0), C.TwilightPurple)
    detailedWindow(m, cf * CFrame.new(w / 2, 6.2, 0) * CFrame.Angles(0, math.rad(90), 0), C.TwilightPurple)
    
    -- Faixa intermediária / beiral do 1º andar
    part(m, Vector3.new(w + 1.6, 0.8, d + 1.6), cf * CFrame.new(0, 1.4 + h1 + 0.4, 0), C.WoodDark, M.Wood, { deco = true })
    
    -- 2º Pavimento (Salão e aposentos de Dona Lúmen)
    local cf2 = cf * CFrame.new(0, 1.4 + h1 + 0.8, 0)
    timberWall(m, cf2 * CFrame.new(0, h2 / 2, 0), w - 1.2, h2, d - 1.2, C.Plaster, C.WoodDark)
    detailedWindow(m, cf2 * CFrame.new(-4.5, 4.8, (d - 1.2) / 2), C.TwilightPurple)
    detailedWindow(m, cf2 * CFrame.new(4.5, 4.8, (d - 1.2) / 2), C.TwilightPurple)
    
    -- Sacada central de madeira no 2º andar
    part(m, Vector3.new(6.4, 0.5, 3.2), cf2 * CFrame.new(0, 0.25, (d - 1.2) / 2 + 1.6), C.Wood, M.WoodPlanks, { name = "Balcony" })
    part(m, Vector3.new(6.4, 2.4, 0.3), cf2 * CFrame.new(0, 1.4, (d - 1.2) / 2 + 3.1), C.WoodDark, M.Wood, { deco = true })
    part(m, Vector3.new(0.3, 2.4, 3.0), cf2 * CFrame.new(-3.1, 1.4, (d - 1.2) / 2 + 1.6), C.WoodDark, M.Wood, { deco = true })
    part(m, Vector3.new(0.3, 2.4, 3.0), cf2 * CFrame.new(3.1, 1.4, (d - 1.2) / 2 + 1.6), C.WoodDark, M.Wood, { deco = true })
    
    -- Grande Telhado Roxo Místico
    gableRoof(m, cf2 * CFrame.new(0, h2, 0), w - 1.2, d - 1.2, 8.5, C.TwilightPurple)
    
    -- Torre lateral com Sino
    local twCf = cf * CFrame.new(w / 2 + 2.5, 0, -2)
    part(m, Vector3.new(6.2, 28, 6.2), twCf * CFrame.new(0, 14, 0), C.Stone, M.Slate, { name = "TowerBody" })
    part(m, Vector3.new(7.2, 1.2, 7.2), twCf * CFrame.new(0, 28.6, 0), C.StoneDark, M.Slate, { deco = true })
    -- Sino de bronze no topo da torre
    cyl(m, 2.2, 2.6, twCf * CFrame.new(0, 30.2, 0), C.Brass, M.Metal, { deco = true, name = "Bell" })
    -- Telhado piramidal da torre
    wedge(m, Vector3.new(7.4, 6, 3.7), twCf * CFrame.new(0, 34, 1.85), C.TwilightPurple, M.WoodPlanks, { deco = true })
    wedge(m, Vector3.new(7.4, 6, 3.7), twCf * CFrame.new(0, 34, -1.85) * CFrame.Angles(0, math.pi, 0), C.TwilightPurple, M.WoodPlanks, { deco = true })
    
    -- Chaminé nobre
    chimneyWithSmoke(m, cf * CFrame.new(-w / 2 + 2.8, 1.4 + h1 + h2, -3), 7)
    
    -- Placa Oficial da Mansão
    local s = part(m, Vector3.new(7.8, 2.2, 0.4), cf * CFrame.new(0, 11.2, d / 2 + 0.6), C.WoodDark, M.WoodPlanks, { name = "Sign" })
    sign(s, "SEDE DE DONA LÚMEN", "Governança & Sabedoria", { color = C.Gold, strokeColor = C.TwilightPurple })
end

-- 2. A Oficina do Marceneiro (Semi-Restaurada — Endowed Progress da Etapa 8)
local function buildWorkshop(x, z, ry)
    local m = model("Oficina")
    local cf = L(x, 0, z, ry)
    reserve(x, z, 26, 22)
    
    local w, d, h = 20, 16, 11
    
    -- Fundação
    part(m, Vector3.new(w + 1, 1.2, d + 1), cf * CFrame.new(0, 0.6, 0), C.Stone, M.Cobblestone, { name = "Foundation" })
    
    -- Galpão principal: paredes rebocadas e vigas grossas de carvalho
    timberWall(m, cf * CFrame.new(0, 1.2 + h / 2, 0), w, h, d, C.PlasterWarm, C.WoodDark)
    detailedDoor(m, cf * CFrame.new(-3.5, 1.2, d / 2))
    detailedWindow(m, cf * CFrame.new(4.5, 6.2, d / 2), C.Ochre)
    
    -- Telhado: metade restaurado com telhas Ocre, metade em ripas e vigas abertas (progresso visível!)
    local over = 1.4
    local hw = (w + over * 2) / 2
    local totalD = d + over * 2
    local roofCf = cf * CFrame.new(0, 1.2 + h, 0)
    
    -- Lado restaurado
    wedge(m, Vector3.new(totalD, 7.5, hw), roofCf * CFrame.new(-hw / 2, 3.75, 0) * CFrame.Angles(0, -math.pi / 2, 0), C.Ochre, M.WoodPlanks, { name = "RoofRestored" })
    -- Lado aberto (com vigas aparentes de restauração)
    for k = -totalD / 2, totalD / 2, 3.2 do
        part(m, Vector3.new(0.6, 0.6, hw * 1.3), roofCf * CFrame.new(hw / 2, 3.75, k) * CFrame.Angles(0, 0, math.rad(-35)), C.WoodDark, M.Wood, { deco = true })
    end
    part(m, Vector3.new(0.8, 0.8, totalD + 0.4), roofCf * CFrame.new(0, 7.8, 0), C.WoodDark, M.Wood, { deco = true })
    
    -- Área Externa de Trabalho (Pátio de Carpintaria)
    local yardCf = cf * CFrame.new(0, 0, d / 2 + 5)
    -- Bancada de trabalho de madeira maciça
    local benchP = part(m, Vector3.new(6.4, 2.6, 2.8), yardCf * CFrame.new(5.5, 1.3, 0), C.Wood, M.WoodPlanks, { name = "Workbench" })
    part(m, Vector3.new(6.8, 0.4, 3.2), yardCf * CFrame.new(5.5, 2.7, 0), C.WoodDark, M.Wood, { deco = true })
    -- Serra de arco e ferramentas na bancada
    part(m, Vector3.new(2.4, 0.6, 0.15), yardCf * CFrame.new(5.5, 3.2, 0) * CFrame.Angles(0, math.rad(25), 0), C.Iron, M.Metal, { deco = true })
    
    -- Cavalete com tora cortada
    local sawCf = yardCf * CFrame.new(-5.5, 0, 0)
    part(m, Vector3.new(0.4, 2.4, 2.4), sawCf * CFrame.new(-1.8, 1.2, 0) * CFrame.Angles(0, 0, math.rad(20)), C.WoodDark, M.Wood, { deco = true })
    part(m, Vector3.new(0.4, 2.4, 2.4), sawCf * CFrame.new(1.8, 1.2, 0) * CFrame.Angles(0, 0, math.rad(-20)), C.WoodDark, M.Wood, { deco = true })
    cyl(m, 2.2, 6.2, sawCf * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, math.rad(90), 0), C.Wood, M.Wood, { name = "Log" })
    
    -- Pilhas de tábuas de corte preparadas
    for i = 1, 5 do
        part(m, Vector3.new(2.4, 0.35, 7.2), yardCf * CFrame.new(-5.5, 0.2 + (i - 1) * 0.4, 4.2), C.WoodLight, M.WoodPlanks, { deco = true })
    end
    crate(m, yardCf * CFrame.new(6.2, 0, 3.4), 2.2)
    barrel(m, yardCf * CFrame.new(3.2, 0, 4.0))
    
    -- Placa Oficial da Oficina
    local s = part(m, Vector3.new(7.4, 2.2, 0.4), cf * CFrame.new(0, 10.4, d / 2 + 0.5), C.WoodDark, M.WoodPlanks, { name = "Sign" })
    sign(s, "OFICINA DO REFÚGIO", "Construção & Reparos", { color = C.Gold, strokeColor = C.Ochre })
end

-- 3. A Taverna do Refúgio (Espaço Social e Convivência com Varanda)
local function buildTavern(x, z, ry)
    local m = model("Taverna")
    local cf = L(x, 0, z, ry)
    reserve(x, z, 26, 24)
    
    local w, d, h = 20, 16, 12
    part(m, Vector3.new(w + 1, 1.2, d + 1), cf * CFrame.new(0, 0.6, 0), C.Stone, M.Slate, { name = "Foundation" })
    timberWall(m, cf * CFrame.new(0, 1.2 + h / 2, 0), w, h, d, C.PlasterWarm, C.WoodDark)
    detailedDoor(m, cf * CFrame.new(-3, 1.2, d / 2))
    detailedWindow(m, cf * CFrame.new(4.5, 6.2, d / 2), C.Terracotta)
    detailedWindow(m, cf * CFrame.new(-w / 2, 6.2, 0) * CFrame.Angles(0, math.rad(-90), 0), C.Terracotta)
    
    -- Grande Telhado de Telhas Terracota
    gableRoof(m, cf * CFrame.new(0, 1.2 + h, 0), w, d, 8, C.Terracotta)
    chimneyWithSmoke(m, cf * CFrame.new(w / 2 - 2.8, 1.2 + h, -2), 6.5)
    
    -- Varanda / Deck Externo com Mesas de Convivência
    local porchCf = cf * CFrame.new(0, 0, d / 2 + 4)
    part(m, Vector3.new(w, 0.6, 7.6), porchCf * CFrame.new(0, 0.3, 0), C.Wood, M.WoodPlanks, { name = "PorchFloor" })
    -- Pilares da varanda
    for _, sx in { -w / 2 + 0.6, 0, w / 2 - 0.6 } do
        part(m, Vector3.new(0.8, 8.5, 0.8), porchCf * CFrame.new(sx, 4.5, 3.4), C.WoodDark, M.Wood, { deco = true })
    end
    -- Cobertura da varanda
    part(m, Vector3.new(w + 0.8, 0.6, 8.2), porchCf * CFrame.new(0, 8.8, 0) * CFrame.Angles(math.rad(-8), 0, 0), C.Terracotta, M.WoodPlanks, { deco = true })
    
    -- Mesa rústica com bancos e canecas
    local tbl = part(m, Vector3.new(5.6, 2.4, 2.8), porchCf * CFrame.new(3.5, 1.2, 0), C.WoodLight, M.WoodPlanks, { name = "Table" })
    part(m, Vector3.new(6.0, 0.3, 3.2), porchCf * CFrame.new(3.5, 2.5, 0), C.WoodDark, M.Wood, { deco = true })
    bench(m, porchCf.Position.X + 3.5, porchCf.Position.Z - 2.2, ry)
    bench(m, porchCf.Position.X + 3.5, porchCf.Position.Z + 2.2, ry + 180)
    
    -- Barris empilhados na varanda
    barrel(m, porchCf * CFrame.new(-6.2, 0, 1.0))
    barrel(m, porchCf * CFrame.new(-6.2, 0, -1.8))
    barrel(m, porchCf * CFrame.new(-6.2, 2.8, -0.4))
    
    -- Placa da Taverna
    local s = part(m, Vector3.new(7.6, 2.2, 0.4), cf * CFrame.new(0, 10.6, d / 2 + 0.5), C.WoodDark, M.WoodPlanks, { name = "Sign" })
    sign(s, "TAVERNA DO REFÚGIO", "Pouso & Boa Conversa", { color = C.Gold, strokeColor = C.Terracotta })
end

-- 4. A Padaria do Vale (com Forno de Pedra Externo)
local function buildBakery(x, z, ry)
    local m = model("Padaria")
    local cf = L(x, 0, z, ry)
    reserve(x, z, 22, 20)
    
    local w, d, h = 16, 14, 10
    part(m, Vector3.new(w + 1, 1.2, d + 1), cf * CFrame.new(0, 0.6, 0), C.Stone, M.Slate, { name = "Foundation" })
    timberWall(m, cf * CFrame.new(0, 1.2 + h / 2, 0), w, h, d, C.Plaster, C.WoodDark)
    detailedDoor(m, cf * CFrame.new(-2.5, 1.2, d / 2))
    detailedWindow(m, cf * CFrame.new(3.5, 5.8, d / 2), C.Ochre)
    
    gableRoof(m, cf * CFrame.new(0, 1.2 + h, 0), w, d, 7, C.Terracotta)
    
    -- Forno de Pedra Rústico na Parede Lateral
    local ovenCf = cf * CFrame.new(-w / 2 - 2.8, 0, 0)
    cyl(m, 5.8, 3.4, ovenCf * CFrame.new(0, 1.7, 0), C.StoneDark, M.Cobblestone, { name = "Oven" })
    -- Boca do forno com brasas ardentes
    local fire = part(m, Vector3.new(1.4, 1.4, 0.4), ovenCf * CFrame.new(0, 1.4, 2.4), C.Fire, M.Neon, { deco = true, name = "OvenFire" })
    local fl = Instance.new("PointLight")
    fl.Color = C.Fire
    fl.Range = 12
    fl.Brightness = 2
    fl.Parent = fire
    chimneyWithSmoke(m, ovenCf * CFrame.new(0, 3.4, 0), 8)
    
    -- Pilha de lenha para o forno
    for k = 1, 6 do
        cyl(m, 0.9, 3.8, ovenCf * CFrame.new(rng:NextNumber(-1, 1), 0.4 + (k * 0.4), -3.2) * CFrame.Angles(0, math.rad(90), 0), C.Wood, M.Wood, { deco = true })
    end
    
    local s = part(m, Vector3.new(6.8, 2.0, 0.4), cf * CFrame.new(0, 9.4, d / 2 + 0.5), C.WoodDark, M.WoodPlanks, { name = "Sign" })
    sign(s, "PADARIA DO VALE", "Pães & Tortas Quentes", { color = C.Gold, strokeColor = C.Terracotta })
end

-- 5. Armazém Geral (com Doca Elevada de Carga)
local function buildWarehouse(x, z, ry)
    local m = model("Armazem")
    local cf = L(x, 0, z, ry)
    reserve(x, z, 22, 22)
    
    local w, d, h = 18, 14, 11
    part(m, Vector3.new(w + 1, 1.4, d + 1), cf * CFrame.new(0, 0.7, 0), C.StoneDark, M.Slate, { name = "Foundation" })
    timberWall(m, cf * CFrame.new(0, 1.4 + h / 2, 0), w, h, d, C.PlasterAged, C.WoodDark)
    
    -- Portão duplo de carga de mercadorias
    part(m, Vector3.new(6.4, 8.2, 0.6), cf * CFrame.new(0, 5.5, d / 2), C.WoodDark, M.WoodPlanks, { name = "CargoGate" })
    detailedWindow(m, cf * CFrame.new(-w / 2, 6.4, 0) * CFrame.Angles(0, math.rad(-90), 0), C.Navy)
    detailedWindow(m, cf * CFrame.new(w / 2, 6.4, 0) * CFrame.Angles(0, math.rad(90), 0), C.Navy)
    
    gableRoof(m, cf * CFrame.new(0, 1.4 + h, 0), w, d, 7.5, C.Navy)
    
    -- Doca Elevada de Madeira com Rampa
    local dockCf = cf * CFrame.new(0, 0, d / 2 + 3.8)
    part(m, Vector3.new(12, 1.6, 6.4), dockCf * CFrame.new(0, 0.8, 0), C.Wood, M.WoodPlanks, { name = "LoadingDock" })
    wedge(m, Vector3.new(4, 1.6, 6.4), dockCf * CFrame.new(8, 0.8, 0), C.Wood, M.WoodPlanks, { name = "Ramp" })
    
    crate(m, dockCf * CFrame.new(-3.5, 1.6, 0.8), 2.4)
    crate(m, dockCf * CFrame.new(-3.5, 3.8, 0.8), 1.8)
    barrel(m, dockCf * CFrame.new(2.8, 1.6, -0.6))
    hayBale(m, dockCf * CFrame.new(3.0, 1.6, 1.8))
    
    local s = part(m, Vector3.new(7.2, 2.0, 0.4), cf * CFrame.new(0, 10.2, d / 2 + 0.5), C.WoodDark, M.WoodPlanks, { name = "Sign" })
    sign(s, "ARMAZÉM CENTRAL", "Suprimentos & Estoque", { color = C.Gold, strokeColor = C.Navy })
end

-- 6. Botânica & Alquimia
local function buildApothecary(x, z, ry)
    local m = model("Botanica")
    local cf = L(x, 0, z, ry)
    reserve(x, z, 20, 20)
    
    local w, d, h = 15, 13, 9.5
    part(m, Vector3.new(w + 1, 1.2, d + 1), cf * CFrame.new(0, 0.6, 0), C.Stone, M.Slate, { name = "Foundation" })
    timberWall(m, cf * CFrame.new(0, 1.2 + h / 2, 0), w, h, d, C.PlasterWarm, C.WoodDark)
    detailedDoor(m, cf * CFrame.new(-2.2, 1.2, d / 2))
    detailedWindow(m, cf * CFrame.new(3.2, 5.5, d / 2), C.ForestGreen)
    
    gableRoof(m, cf * CFrame.new(0, 1.2 + h, 0), w, d, 6.8, C.ForestGreen)
    
    -- Canteiro de plantas medicinais na frente
    flowerBed(m, cf.Position.X + 4.5, cf.Position.Z + (d / 2 + 2.5), ry)
    
    local s = part(m, Vector3.new(6.8, 2.0, 0.4), cf * CFrame.new(0, 9.0, d / 2 + 0.5), C.WoodDark, M.WoodPlanks, { name = "Sign" })
    sign(s, "BOTÂNICA & ERVAS", "Poções, Mudas e Chás", { color = C.Gold, strokeColor = C.ForestGreen })
end

-- ===== A Praça Central (Coração da Vila) =====

local function treasureBoard(parent, x, z)
    local m = model("TreasureBoard", parent)
    local cf = L(x, 0, z, face(x, z, 0, 0))
    
    -- Altar de pedra de ardósia chanfrada
    part(m, Vector3.new(10.4, 1.6, 4.4), cf * CFrame.new(0, 0.8, 0), C.Stone, M.Slate)
    part(m, Vector3.new(9.6, 0.5, 3.8), cf * CFrame.new(0, 1.8, 0), C.StoneDark, M.Slate)
    
    -- Estela rúnica com o contador do tesouro
    local tab = part(m, Vector3.new(8.4, 7.2, 1.4), cf * CFrame.new(0, 5.4, 0.8), C.StoneDark, M.Slate, { name = "Tablet" })
    sign(tab, "TESOURO DA CAVERNA", "0 itens recuperados", {
        subName = "Count",
        color = C.Gold,
        strokeColor = C.Brass,
    })
    
    -- O Grande Baú do Tesouro entreaberto
    local chestCf = cf * CFrame.new(0, 2.1, -1.2)
    part(m, Vector3.new(4.6, 2.4, 3.0), chestCf, C.Wood, M.WoodPlanks, { name = "Chest" })
    part(m, Vector3.new(4.8, 0.4, 3.2), chestCf * CFrame.new(0, 1.3, 0), C.WoodDark, M.Wood, { deco = true })
    -- Tampa entreaberta
    part(m, Vector3.new(4.8, 3.0, 0.5), chestCf * CFrame.new(0, 2.8, 1.2) * CFrame.Angles(math.rad(-22), 0, 0), C.WoodDark, M.WoodPlanks, { name = "Lid" })
    
    -- Ouro e gemas brilhando dentro do baú
    local gold = part(m, Vector3.new(4.2, 0.8, 2.6), chestCf * CFrame.new(0, 1.2, 0), C.Gold, M.Neon, { deco = true, name = "GoldPile" })
    local pl = Instance.new("PointLight")
    pl.Color = C.Gold
    pl.Range = 14
    pl.Brightness = 1.6
    pl.Parent = gold
    
    -- Moedas derramadas sobre o altar
    for _ = 1, 7 do
        cyl(m, 0.9, 0.2, cf * CFrame.new(rng:NextNumber(-3.5, 3.5), 2.1, rng:NextNumber(-2.6, 0)), C.Gold, M.Metal, { deco = true })
    end
end

local function highlightBoard(parent, x, z)
    local m = model("HighlightBoard", parent)
    local cf = L(x, 0, z, face(x, z, 0, 0))
    
    -- Postes nobres de sustentação
    for _, sx in { -4.6, 4.6 } do
        part(m, Vector3.new(1.2, 10.5, 1.2), cf * CFrame.new(sx, 5.25, 0), C.WoodDark, M.Wood)
        part(m, Vector3.new(1.6, 0.6, 1.6), cf * CFrame.new(sx, 0.3, 0), C.Stone, M.Slate, { deco = true })
    end
    
    -- Mural de madeira nobre
    local b = part(m, Vector3.new(9.2, 6.4, 0.6), cf * CFrame.new(0, 6.0, 0), C.Wood, M.WoodPlanks, { name = "Board" })
    sign(b, "DESTAQUE DA SEMANA", "Aguardando Apuração...", {
        subName = "Winner",
        color = C.Gold,
        strokeColor = C.Brass,
    })
    
    -- Telhadinho protetor
    part(m, Vector3.new(11.2, 0.6, 2.8), cf * CFrame.new(0, 9.6, 0), C.Terracotta, M.RoofShingles)
    
    -- Estrela de Ouro no Topo
    local star = part(m, Vector3.new(1.8, 1.8, 0.4), cf * CFrame.new(0, 10.8, 0) * CFrame.Angles(0, 0, math.rad(45)), C.Gold, M.Neon, { deco = true, name = "Star" })
    local sl = Instance.new("PointLight")
    sl.Color = C.Gold
    sl.Range = 10
    sl.Brightness = 1.4
    sl.Parent = star
end

local function buildPlaza()
    local m = model("Praca")
    reserve(0, 0, 75, 75)
    
    -- Pavimento Decorativo em Mosaico
    cyl(m, 72, 0.5, L(0, 0.1, 0), C.Stone, M.Slate, { name = "PlazaRim", deco = true })
    cyl(m, 66, 0.6, L(0, 0.15, 0), C.Cobble, M.Cobblestone, { name = "PlazaCobble", deco = true })
    
    -- A Grande Fonte Monumental (Monumento da Lanterna Mestra)
    local fR = 8.5
    for i = 0, 15 do
        local a = i / 16 * 2 * math.pi
        local x, z = fR * math.sin(a), -fR * math.cos(a)
        part(m, Vector3.new(3.8, 2.6, 1.6), L(x, 1.1, z, face(x, z, 0, 0)), C.Stone, M.Slate, { name = "FountainRim" })
    end
    -- Água cristalina da fonte
    local water = cyl(m, (fR - 0.9) * 2, 2.0, L(0, 0.9, 0), Color3.fromRGB(60, 150, 175), M.Glass, { name = "FountainWater", deco = true })
    water.Transparency = 0.35
    
    -- Pedestal Central da Lanterna Mestra
    cyl(m, 3.8, 13.5, L(0, 1.5, 0), C.StoneDark, M.Slate, { name = "Pillar" })
    cyl(m, 5.6, 1.2, L(0, 8.4, 0), C.Stone, M.Slate)
    
    -- Garras Douradas Vazias (onde ficava a Lanterna Mestra antes de ser roubada pelo Oruk)
    for i = 0, 3 do
        part(m, Vector3.new(0.6, 3.6, 0.6), L(0, 0, 0, i * 90) * CFrame.new(0, 10.4, -1.8) * CFrame.Angles(math.rad(-25), 0, 0), C.Gold, M.Metal, { deco = true, name = "EmptyCradle" })
    end
    
    -- Fragmentos de Cristal Prismático caídos na fonte com pulso de luz suave
    local shards = {
        { 2.5, 0.8, 9.8 }, { -3.2, 0.8, 10.2 }, { 10.2, 0.8, -2.5 }, { -10.0, 0.8, 3.8 }, { 0.8, 9.4, 0.8 }
    }
    for i, s in ipairs(shards) do
        local sh = part(m, Vector3.new(0.7, 1.8, 0.7), L(s[1], s[2], s[3]) * CFrame.Angles(math.rad(rng:NextNumber(-35, 35)), math.rad(rng:NextNumber(0, 180)), math.rad(rng:NextNumber(-35, 35))), C.Crystal, M.Neon, { deco = true, name = "LanternShard" })
        if i == #shards or i == 1 then
            local pl = Instance.new("PointLight")
            pl.Color = C.Crystal
            pl.Range = 12
            pl.Brightness = 1.5
            pl.Parent = sh
        end
    end
    
    -- Placa Comemorativa de Lore
    local plaque = part(m, Vector3.new(5.8, 2.8, 0.8), L(0, 1.6, 11.5, 180) * CFrame.Angles(math.rad(-15), 0, 0), C.StoneDark, M.Slate, { name = "LanternPlaque" })
    sign(plaque, "A LANTERNA MESTRA", "Levada pelo Oruk. Traga-a de volta.", { color = C.Crystal, strokeColor = C.Gold })
    
    -- Bancos e Canteiros Radiais da Praça
    for i = 0, 3 do
        local a = math.rad(45 + i * 90)
        local bx, bz = 21 * math.sin(a), -21 * math.cos(a)
        bench(m, bx, bz, face(bx, bz, 0, 0))
        
        local fx, fz = 28 * math.sin(a), -28 * math.cos(a)
        flowerBed(m, fx, fz, face(fx, fz, 0, 0))
    end
    
    -- Postes de Iluminação Quente em Círculo
    for i = 0, 7 do
        local a = math.rad(22.5 + i * 45)
        lampPost(m, 32 * math.sin(a), -32 * math.cos(a))
    end
    
    -- Murais e Altares da Praça
    highlightBoard(m, -24, 0)
    treasureBoard(m, 24, 0)
end

-- ===== O Mercado Central (Distrito Comercial) =====

local function stall(i, x, z, ry, color)
    local m = model(string.format("Stall_%02d", i), stallsF)
    m:SetAttribute("Gen", "Village")
    m:SetAttribute("StallId", i)
    m:SetAttribute("Owner", 0)
    
    local cf = L(x, 0, z, ry)
    reserve(x, z, 14, 14)
    
    -- Balcão de carvalho maciço
    local counter = part(m, Vector3.new(9.2, 3.2, 3.2), cf * CFrame.new(0, 1.6, -2), C.Wood, M.WoodPlanks, { name = "Counter" })
    m.PrimaryPart = counter
    part(m, Vector3.new(9.8, 0.4, 3.6), cf * CFrame.new(0, 3.4, -2), C.WoodDark, M.Wood, { name = "CounterTop" })
    
    -- Colunas de sustentação do toldo
    for _, sx in { -4.6, 4.6 } do
        part(m, Vector3.new(0.8, 9.0, 0.8), cf * CFrame.new(sx, 4.5, -3.6), C.WoodDark, M.Wood)
        part(m, Vector3.new(0.8, 10.6, 0.8), cf * CFrame.new(sx, 5.3, 4.0), C.WoodDark, M.Wood)
    end
    
    -- Toldo arqueado de tecido listrado em duas cores
    local rise, run = 1.8, 8.2
    local th = -math.atan2(rise, run)
    local len = math.sqrt(rise ^ 2 + run ^ 2) + 0.8
    for k = 0, 5 do
        local sx = -4.2 + k * 1.68
        local col = (k % 2 == 0) and color or C.Cream
        part(m, Vector3.new(1.7, 0.25, len), cf * CFrame.new(sx, 9.6, 0.2) * CFrame.Angles(th, 0, 0), col, M.Fabric, { deco = true, name = "Canopy" })
        -- Franja pendurada na frente
        part(m, Vector3.new(1.68, 1.1, 0.15), cf * CFrame.new(sx, 8.3, -4.0), col, M.Fabric, { deco = true, noShadow = true })
    end
    
    -- Lanterna de teto suspensa sobre a banca
    lamp(m, cf * CFrame.new(0, 8.8, -1.8), 16, 1.3)
    
    -- Placa da Banca
    local s = part(m, Vector3.new(6.8, 1.6, 0.3), cf * CFrame.new(0, 9.8, -4.3), C.WoodDark, M.WoodPlanks, { name = "Sign" })
    sign(s, string.format("BANCA %02d", i), "Disponível para Comércio", { subName = "Status", color = C.Gold })
    
    -- Caixas de produtos temáticos e barril ao lado
    crate(m, cf * CFrame.new(-3.0, 0, 2.8), 2.2)
    barrel(m, cf * CFrame.new(3.0, 0, 3.0))
    
    -- Hitboxes de interação invisíveis
    local own = part(m, Vector3.new(2.4, 1, 2.4), cf * CFrame.new(0, 0.5, 1.4), C.Wood, nil, { deco = true, transparency = 1, name = "OwnerSpot" })
    own.CastShadow = false
    local cus = part(m, Vector3.new(2.4, 1, 2.4), cf * CFrame.new(0, 0.5, -6.2), C.Wood, nil, { deco = true, transparency = 1, name = "CustomerSpot" })
    cus.CastShadow = false
end

local function buildMarket()
    local m = model("Mercado")
    reserve(0, -90, 18, 130)
    
    -- 8 Bancas organizadas na alameda comercial (4 a oeste, 4 a leste)
    local i = 0
    for _, side in { -1, 1 } do
        for _, z in { -46, -66, -86, -106 } do
            i += 1
            stall(i, side * 15, z, side < 0 and -90 or 90, CLOTH[(i - 1) % #CLOTH + 1])
        end
    end
    
    -- Postes de luz ao longo da alameda
    for _, z in { -36, -56, -76, -96, -116, -136 } do
        lampPost(m, -8.5, z)
        lampPost(m, 8.5, z)
    end
    
    -- Bandeirolas festivas cruzando a rua do mercado
    for _, z in { -56, -96, -136 } do
        bunting(m, -8.5, z, 8.5, z, 11.2)
    end
    
    -- Carroça de mercador estacionada perto da saída do mercado
    local wcf = L(-26, 0, -132, 22)
    reserve(-26, -132, 12, 12)
    local cartBody = part(m, Vector3.new(4.8, 1.8, 7.6), wcf * CFrame.new(0, 2.8, 0), C.Wood, M.WoodPlanks, { name = "Cart" })
    for _, sx in { -1, 1 } do
        part(m, Vector3.new(0.4, 1.4, 7.6), wcf * CFrame.new(sx * 2.4, 4.2, 0), C.WoodDark, M.Wood, { deco = true })
        for _, sz in { -1, 1 } do
            cyl(m, 3.6, 0.6, wcf * CFrame.new(sx * 2.7, 1.8, sz * 2.4), C.WoodDark, M.Wood, { deco = true })
        end
    end
    part(m, Vector3.new(0.5, 0.5, 5.5), wcf * CFrame.new(0, 2.2, -6.0), C.WoodDark, M.Wood, { deco = true })
    hayBale(m, wcf * CFrame.new(0, 3.6, 1.2))
    crate(m, L(24, 0, -126, 15), 2.4)
    crate(m, L(26, 0, -122, -20), 1.8)
    barrel(m, L(23, 0, -130))
end

-- ===== Bairro Residencial dos Jogadores (Plots) =====

local function plot(id, x, z, side)
    local S, h, gap = 28, 14, 4.5
    local m = model(string.format("Plot_%02d", id), plotsF)
    m:SetAttribute("Gen", "Village")
    m:SetAttribute("PlotId", id)
    m:SetAttribute("Owner", 0)
    reserve(x, z, S + 4, S + 4)
    
    -- Base do terreno
    local base = part(m, Vector3.new(S, 0.8, S), L(x, -0.4, z), C.Leaf, M.Grass, { name = "Base", transparency = 1, deco = true })
    m.PrimaryPart = base
    
    -- Calçada de pedras ligando a rua ao interior do lote
    local ez, oz = z + side * h, z - side * h
    for k = 0, 4 do
        part(m, Vector3.new(3.8, 0.15, 2.0), L(x, 0.08, ez - side * (k * 2.4)), C.Cobble, M.Cobblestone, { deco = true })
    end
    
    -- Cercado rústico ao redor do terreno
    local function fenceSegment(ax, az, bx, bz)
        local A, B = L(ax, 0, az).Position, L(bx, 0, bz).Position
        local dir = (B - A)
        local len = dir.Magnitude
        local steps = math.max(2, math.floor(len / 3.4))
        for k = 0, steps do
            local p = A:Lerp(B, k / steps)
            part(m, Vector3.new(0.6, 3.4, 0.6), CFrame.new(p) * CFrame.new(0, 1.7, 0), C.WoodDark, M.Wood, { deco = true })
        end
        part(m, Vector3.new(0.4, 0.5, len), CFrame.lookAt((A + B) / 2, B) * CFrame.new(0, 1.2, 0), C.Wood, M.WoodPlanks, { deco = true })
        part(m, Vector3.new(0.4, 0.5, len), CFrame.lookAt((A + B) / 2, B) * CFrame.new(0, 2.5, 0), C.Wood, M.WoodPlanks, { deco = true })
    end
    
    fenceSegment(x - h, oz, x + h, oz)
    fenceSegment(x - h, oz, x - h, ez)
    fenceSegment(x + h, oz, x + h, ez)
    fenceSegment(x - h, ez, x - gap, ez)
    fenceSegment(x + gap, ez, x + h, ez)
    
    -- Placa Oficial do Terreno
    local sx = x + gap + 1.8
    part(m, Vector3.new(0.7, 5.5, 0.7), L(sx, 2.75, ez + side * 0.8), C.WoodDark, M.Wood)
    local board = part(m, Vector3.new(4.8, 2.6, 0.35), L(sx, 4.8, ez + side * 1.2, side > 0 and 180 or 0), C.Wood, M.WoodPlanks, { name = "Sign" })
    sign(board, string.format("TERRENO %02d", id), "Disponível para Construção", { subName = "Status", color = C.Gold })
    
    -- Caixa de Correio Charmosa com Bandeirinha Vermelha
    local mx = x - gap - 1.8
    part(m, Vector3.new(0.6, 3.8, 0.6), L(mx, 1.9, ez + side * 0.8), C.WoodDark, M.Wood)
    local mb = part(m, Vector3.new(1.6, 1.3, 2.2), L(mx, 4.2, ez + side * 0.8), ROOFS[(id % #ROOFS) + 1], M.SmoothPlastic, { name = "Mailbox" })
    part(m, Vector3.new(0.15, 0.9, 0.4), L(mx + 0.85, 4.6, ez + side * 0.8), Color3.fromRGB(220, 45, 45), M.Metal, { deco = true, name = "Flag" })
end

local function buildPlots()
    local m = model("Bairro")
    local id = 0
    
    -- 12 Lotes distribuídos em duas alamedas planejadas ao sul da praça
    for _, row in ipairs({ { 54, 1 }, { 96, -1 } }) do
        for _, x in ipairs({ -85, -51, -17, 17, 51, 85 }) do
            id += 1
            plot(id, x, row[1], row[2])
        end
    end
    
    reserve(0, 75, 214, 14)
    reserve(0, 96, 16, 126)
    
    -- Postes de luz ao longo das calçadas residenciais
    for _, p in ipairs({
        { -68, 75 }, { 68, 75 }, { -34, 75 }, { 34, 75 },
        { -8, 36 }, { 8, 36 }, { -8, 114 }, { 8, 114 }
    }) do
        lampPost(m, p[1], p[2])
    end
    
    -- Grande Poço Artesiano Comunitário do Bairro
    local wcf = L(-44, 0, 24)
    reserve(-44, 24, 12, 12)
    cyl(m, 6.8, 3.4, wcf * CFrame.new(0, 1.4, 0), C.Stone, M.Slate, { name = "WellRim" })
    cyl(m, 5.2, 0.4, wcf * CFrame.new(0, 2.8, 0), Color3.fromRGB(50, 100, 130), M.Glass, { deco = true, name = "Water" })
    for _, sx in { -1, 1 } do
        part(m, Vector3.new(0.8, 7.5, 0.8), wcf * CFrame.new(sx * 2.9, 4.0, 0), C.Wood, M.Wood)
    end
    part(m, Vector3.new(6.4, 0.6, 0.6), wcf * CFrame.new(0, 7.2, 0), C.WoodDark, M.Wood, { deco = true })
    part(m, Vector3.new(1.2, 1.3, 1.2), wcf * CFrame.new(0, 5.0, 0), C.Wood, M.Wood, { deco = true, name = "Bucket" })
    gableRoof(m, wcf * CFrame.new(0, 7.5, 0), 6.8, 5.2, 3.6, C.Terracotta)
end

-- ===== A Grande Muralha e Torres de Defesa =====

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

    -- Muralha fortificada com base espessa de pedra e ameias
    for _, arc in ipairs(arcs) do
        local a0, a1 = arc[1], arc[2]
        local n = math.ceil((a1 - a0) * R / 16)
        local da = (a1 - a0) / n
        local chord = 2 * R * math.sin(da / 2) + 0.5
        
        for i = 0, n - 1 do
            local a = a0 + (i + 0.5) * da
            
            -- Base e corpo principal de ardósia (altura 12 studs)
            part(m, Vector3.new(chord, 12, 4.6), cfAt(a, R, 5.5), C.Stone, M.Slate, { name = "WallSegment" })
            -- Ameias superiores de proteção
            part(m, Vector3.new(chord * 0.45, 2.4, 1.8), cfAt(a, R + 1.2, 12.4), C.StoneDark, M.Slate, { deco = true })
            
            -- Caminho de ronda de madeira no topo da muralha
            part(m, Vector3.new(chord, 0.6, 3.4), cfAt(a, R - 1.2, 10.8), C.WoodDark, M.WoodPlanks, { name = "Walkway" })
            -- Corrimão interno
            part(m, Vector3.new(chord, 1.8, 0.4), cfAt(a, R - 2.8, 12.0), C.WoodDark, M.Wood, { deco = true })
        end
    end

    -- 6 Torres de Vigia Fortificadas nas curvas da muralha
    local function tower(x, z, h, roofColor)
        local tw = model("Watchtower", m)
        local cf = L(x, 0, z)
        
        -- Corpo octogonal/cilíndrico de pedra
        cyl(tw, 11, h, cf * CFrame.new(0, h / 2, 0), C.Stone, M.Slate, { name = "TowerBase" })
        -- Plataforma superior alargada
        cyl(tw, 13, 1.4, cf * CFrame.new(0, h + 0.7, 0), C.StoneDark, M.Slate)
        -- Parapeito com ameias
        cyl(tw, 13, 2.6, cf * CFrame.new(0, h + 2.4, 0), C.Stone, M.Slate, { deco = true })
        -- Telhado cônico pontudo com tocha
        wedge(tw, Vector3.new(13.4, 8, 6.7), cf * CFrame.new(0, h + 7.2, 3.35), roofColor, M.WoodPlanks, { deco = true })
        wedge(tw, Vector3.new(13.4, 8, 6.7), cf * CFrame.new(0, h + 7.2, -3.35) * CFrame.Angles(0, math.pi, 0), roofColor, M.WoodPlanks, { deco = true })
        
        lamp(tw, cf * CFrame.new(0, h + 2.8, 5.6), 20, 1.5)
    end

    for _, a in ipairs({ math.pi / 3, math.pi / 2, 2 * math.pi / 3, 4 * math.pi / 3, 3 * math.pi / 2, 5 * math.pi / 3 }) do
        local p = at(a, R - 3, 0)
        tower(p.X, p.Z, 22, C.Navy)
    end
end

-- ===== Os Portões da Vila (Norte: Trilha / Sul: Porto) =====

local function buildGates()
    local m = model("Portoes")
    local R = CONFIG.Radius
    local gx = CONFIG.GateWidth / 2 + 5.5
    reserve(0, -R + 15, 38, 32)
    reserve(0, R - 15, 38, 32)

    -- 1. O PORTÃO DA TRILHA (Norte — Acesso à Floresta Selvagem)
    for _, sx in { -1, 1 } do
        -- Torres Gêmeas de Guarda
        local twCf = L(sx * gx, 0, -R + 1)
        cyl(m, 12, 24, twCf * CFrame.new(0, 12, 0), C.Stone, M.Slate, { name = "GateTower" })
        cyl(m, 14, 1.6, twCf * CFrame.new(0, 24.8, 0), C.StoneDark, M.Slate)
        wedge(m, Vector3.new(14.2, 8, 7.1), twCf * CFrame.new(0, 29.5, 3.55), C.Terracotta, M.WoodPlanks, { deco = true })
        wedge(m, Vector3.new(14.2, 8, 7.1), twCf * CFrame.new(0, 29.5, -3.55) * CFrame.Angles(0, math.pi, 0), C.Terracotta, M.WoodPlanks, { deco = true })
        
        -- Braseiros de Fogo nos pilares
        local brazier = cyl(m, 2.6, 1.4, twCf * CFrame.new(0, 10, -5.5), C.Iron, M.Metal, { deco = true })
        local fire = part(m, Vector3.new(1.2, 1.2, 1.2), twCf * CFrame.new(0, 11.2, -5.5), C.Fire, M.Neon, { deco = true, name = "BrazierFire" })
        local bpl = Instance.new("PointLight")
        bpl.Color = C.Fire
        bpl.Range = 22
        bpl.Brightness = 2
        bpl.Parent = fire
    end

    -- Grande Arco de Madeira e Ferro
    part(m, Vector3.new(gx * 2 + 3, 2.8, 2.8), L(0, 18, -R + 1), C.WoodDark, M.Wood, { name = "Arch" })
    
    -- Placas Oficiais Frente e Verso
    local inner = part(m, Vector3.new(16, 4.0, 0.7), L(0, 16.2, -R + 2.8, 180), C.WoodDark, M.WoodPlanks, { name = "GateSignInside" })
    sign(inner, "TRILHA DA FLORESTA", "Atenção: O Oruk caça pelo som após o entardecer!", { color = C.Gold, strokeColor = C.Terracotta })
    
    local outer = part(m, Vector3.new(16, 4.0, 0.7), L(0, 16.2, -R - 0.8, 0), C.WoodDark, M.WoodPlanks, { name = "GateSignOutside" })
    sign(outer, "VILA REFÚGIO", "Área Segura — O monstro nunca entra.", { color = C.Gold, strokeColor = C.Navy })

    -- Portas Maciças de Carvalho com Ferragens Abertas em Ângulo Convidativo
    local hinge = CONFIG.GateWidth / 2 - 0.5
    local ang = math.rad(72)
    for _, sx in { -1, 1 } do
        local cx = sx * (hinge - 4.2 * math.cos(ang))
        local cz = -R + 1 + 4.2 * math.sin(ang)
        local dcf = L(cx, 7.5, cz, sx > 0 and -108 or -72)
        part(m, Vector3.new(8.2, 14, 1.0), dcf, C.Wood, M.WoodPlanks, { name = "GateDoor" })
        for _, y in { -4.5, 4.5 } do
            part(m, Vector3.new(8.3, 0.8, 1.2), dcf * CFrame.new(0, y, 0), C.Iron, M.Metal, { deco = true })
        end
    end

    -- 2. PONTO DE REUNIÃO DE EXPEDIÇÕES (Ponto de Grupo)
    local gpz = -R + 24
    for i = 0, 15 do
        local a = i / 16 * 2 * math.pi
        local x, z = 7.5 * math.sin(a), gpz - 7.5 * math.cos(a)
        part(m, Vector3.new(2.8, 0.25, 0.7), L(x, 0.12, z, face(x, z, 0, gpz)), C.Crystal, M.Neon, { deco = true, noShadow = true })
    end
    cyl(m, 6, 0.5, L(0, 0.25, gpz), C.StoneDark, M.Slate, { name = "GroupStone" })
    part(m, Vector3.new(0.8, 7, 0.8), L(10, 3.5, gpz), C.WoodDark, M.Wood)
    local gs = part(m, Vector3.new(5.6, 3.0, 0.4), L(10, 6.0, gpz + 0.4, 180), C.Wood, M.WoodPlanks, { name = "GroupSign" })
    sign(gs, "PONTO DE GRUPO", "Reúna sua equipe aqui", { color = C.Crystal, strokeColor = C.Brass })
    
    local gz = part(zonesF, Vector3.new(15, 10, 15), L(0, 5, gpz), C.Crystal, nil, { name = "GroupPoint", transparency = 1 })
    gz.CanCollide = false
    gz.CanQuery = false
    gz:SetAttribute("Gen", "Village")
    gz:SetAttribute("ZoneType", "GroupPoint")

    -- 3. O PORTÃO DO PORTO (Sul — Futuras Ilhas & Expansões)
    for _, sx in { -1, 1 } do
        local twCf = L(sx * gx, 0, R - 1)
        cyl(m, 12, 22, twCf * CFrame.new(0, 11, 0), C.Stone, M.Slate, { name = "PortTower" })
        wedge(m, Vector3.new(13.2, 7, 6.6), twCf * CFrame.new(0, 25.5, 3.3), C.ForestGreen, M.WoodPlanks, { deco = true })
        wedge(m, Vector3.new(13.2, 7, 6.6), twCf * CFrame.new(0, 25.5, -3.3) * CFrame.Angles(0, math.pi, 0), C.ForestGreen, M.WoodPlanks, { deco = true })
    end
    part(m, Vector3.new(gx * 2 + 2, 2.5, 2.5), L(0, 17, R - 1), C.WoodDark, M.Wood)
    -- Portão fechado com tábuas reforçadas e temática de porto
    part(m, Vector3.new(CONFIG.GateWidth, 14, 1.2), L(0, 7.0, R - 1), C.WoodDark, M.WoodPlanks, { name = "PortDoorClosed" })
    part(m, Vector3.new(CONFIG.GateWidth + 1, 1.2, 1.5), L(0, 7.0, R - 1.8), C.Iron, M.Metal, { deco = true })
    local ps = part(m, Vector3.new(14, 3.8, 0.7), L(0, 15.2, R - 2.5, 0), C.WoodDark, M.WoodPlanks, { name = "PortSign" })
    sign(ps, "PORTO DO REFÚGIO", "Expedição Marítima — Em Breve", { color = C.Gold, strokeColor = C.ForestGreen })
end

-- ===== Natureza da Vila (Árvores e Canteiros Low-Poly) =====

local ALIASES = {
    Tree = { "tree" },
    Bush = { "plant_bush", "bush" },
    Rock = { "rock" },
    Flower = { "flower" }
}

local function matchesPrefix(name, prefix)
    local n = string.lower(name)
    for _, a in ALIASES[prefix] or { string.lower(prefix) } do
        if string.sub(n, 1, #a) == a then return true end
    end
    return false
end

local function placeAsset(prefix, cf, height, parent)
    if not nature then return nil end
    local list = {}
    for _, c in ipairs(nature:GetChildren()) do
        if c:IsA("PVInstance") and matchesPrefix(c.Name, prefix) then
            table.insert(list, c)
        end
    end
    if #list == 0 then return nil end
    local asset = list[rng:NextInteger(1, #list)]
    local inst = asset:Clone()
    
    if inst:IsA("Model") then
        local sz = inst:GetExtentsSize()
        local scale = height / math.max(sz.Y, 0.01)
        inst:ScaleTo(scale)
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Anchored = true
                d.CanCollide = false
                d.CanTouch = false
                d.CanQuery = false
            end
        end
        inst:PivotTo(cf)
    elseif inst:IsA("BasePart") then
        local scale = height / math.max(inst.Size.Y, 0.01)
        inst.Size = inst.Size * scale
        inst.Anchored = true
        inst.CanCollide = false
        inst.CFrame = cf
    end
    inst.Parent = parent
    return inst
end

local function tree(parent, x, z)
    local cf = L(x, 0, z, rng:NextNumber(0, 360))
    local h = rng:NextNumber(16, 26)
    if placeAsset("Tree", cf, h, parent) then return end

    local m = model("Tree", parent)
    cyl(m, h * 0.16, h * 0.45, cf * CFrame.new(0, h * 0.22, 0), C.WoodDark, M.Wood, { name = "Trunk", deco = true })
    local leafCol = C.Leaf:Lerp(C.LeafLight, rng:NextNumber(0, 0.5))
    part(m, Vector3.new(h * 0.65, h * 0.5, h * 0.65), cf * CFrame.new(0, h * 0.58, 0), leafCol, M.Grass, { deco = true, name = "Foliage1" })
    part(m, Vector3.new(h * 0.48, h * 0.4, h * 0.48), cf * CFrame.new(0, h * 0.82, 0), leafCol, M.Grass, { deco = true, name = "Foliage2" })
end

local function bush(parent, x, z)
    local cf = L(x, 0, z, rng:NextNumber(0, 360))
    if placeAsset("Bush", cf, rng:NextNumber(4, 7), parent) then return end
    part(parent, Vector3.new(rng:NextNumber(3.5, 5.5), rng:NextNumber(3, 4.5), rng:NextNumber(3.5, 5.5)), cf * CFrame.new(0, 1.5, 0), C.LeafLight, M.Grass, { deco = true, name = "Bush" })
end

local function rock(parent, x, z)
    local cf = L(x, 0, z, rng:NextNumber(0, 360))
    if placeAsset("Rock", cf, rng:NextNumber(2.5, 5), parent) then return end
    part(parent, Vector3.new(rng:NextNumber(3, 5), rng:NextNumber(2, 3.5), rng:NextNumber(3, 5)), cf * CFrame.new(0, 1.2, 0) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), 0, math.rad(rng:NextNumber(-15, 15))), C.Stone, M.Rock, { deco = true, name = "Rock" })
end

local function scatterNature()
    local m = model("Natureza")
    local R = CONFIG.Radius
    local placed = 0
    
    for _ = 1, 450 do
        local a = rng:NextNumber(0, 2 * math.pi)
        local r = rng:NextNumber(40, R - 14)
        local x, z = r * math.sin(a), -r * math.cos(a)
        if isFree(x, z, 5.5) then
            tree(m, x, z)
            reserve(x, z, 6, 6)
            placed += 1
            if placed >= CONFIG.MaxTrees then break end
        end
    end
    
    for _ = 1, 80 do
        local a = rng:NextNumber(0, 2 * math.pi)
        local r = R - rng:NextNumber(5, 11)
        local x, z = r * math.sin(a), -r * math.cos(a)
        if isFree(x, z, 2.0) then
            if rng:NextNumber() < 0.65 then bush(m, x, z) else rock(m, x, z) end
            reserve(x, z, 3, 3)
        end
    end
end

-- ===== Aplainamento e Modelagem do Terreno de Voxels =====

local function terrain()
    local T = workspace.Terrain
    local c = BASE.Position
    local R = CONFIG.Radius + 14
    
    if CONFIG.FlattenTerrain then
        -- Saia em degraus suaves para fusão orgânica com o relevo natural do TerrainGen
        for k = 5, 1, -1 do
            T:FillCylinder(CFrame.new(c + Vector3.new(0, -k * 3 - 15, 0)), 30, R + k * 8, M.Grass)
        end
        for k = 5, 1, -1 do
            T:FillCylinder(CFrame.new(c + Vector3.new(0, k * 5 + 60, 0)), 120, R + k * 8, M.Air)
        end
        T:FillCylinder(CFrame.new(c + Vector3.new(0, 60, 0)), 120, R, M.Air)
        T:FillCylinder(CFrame.new(c + Vector3.new(0, -15, 0)), 30, R, M.Grass)
    end

    local function path(x, z, w, d)
        T:FillBlock(L(x, -2, z), Vector3.new(w, 4, d), M.Cobblestone)
    end
    
    -- Praça Central
    T:FillCylinder(L(0, -2, 0), 4, 38, M.Cobblestone)
    
    -- Ruas Principais de Cobblestone
    path(0, -90, 14, 126)               -- Alameda do Mercado até o Portão da Trilha
    path(0, 94, 12, 124)                -- Alameda Sul até o Portão do Porto
    path(0, 75, 210, 12)                -- Alameda Central dos Terrenos Residenciais
    path(-45, -8, 24, 8)                -- Travessa Dona Lúmen
    path(45, -8, 24, 8)                 -- Travessa da Oficina
    path(0, -CONFIG.Radius - 14, 14, 28) -- Acesso externo à Trilha da Floresta
    
    -- Poço central da fonte da praça
    T:FillCylinder(L(0, -2, 0), 4, 8.5, M.Air)
    T:FillCylinder(L(0, -2.5, 0), 3, 8.0, M.Water)
end

-- ===== Ponto de Entrada Principal =====

function Builder.Build()
    -- 1. Localiza ou cria o marcador VillageCenter no Workspace
    local marker = workspace:FindFirstChild("VillageCenter")
    if not (marker and marker:IsA("BasePart")) then
        local plazaMarker = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Markers") and workspace.Map.Markers:FindFirstChild("Marker_Plaza")
        if plazaMarker and plazaMarker:IsA("BasePart") then
            marker = plazaMarker
        else
            marker = Instance.new("Part")
            marker.Name = "VillageCenter"
            marker.Anchored = true
            marker.CanCollide = false
            marker.Transparency = 1
            marker.Size = Vector3.new(4, 4, 4)
            marker.CFrame = CFrame.new(0, 8, 0)
            marker:SetAttribute("Radius", CONFIG.Radius)
            marker.Parent = workspace
            print("[VillageBuilder] Marcador VillageCenter criado automaticamente em (0, 8, 0).")
        end
    end

    rng = Random.new(CONFIG.Seed)
    reserved = {}
    
    local assets = ServerStorage:FindFirstChild("Assets")
    nature = assets and assets:FindFirstChild("Nature")

    -- Alinha a vila à altura real do terreno
    local p = marker.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { workspace.Terrain }
    local hit = workspace:Raycast(Vector3.new(p.X, p.Y + 500, p.Z), Vector3.new(0, -2000, 0), params)
    local y0 = math.floor((hit and hit.Position.Y or p.Y) / 4 + 0.5) * 4
    
    local look = marker.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
    BASE = CFrame.lookAt(Vector3.new(p.X, y0, p.Z), Vector3.new(p.X + flat.X, y0, p.Z + flat.Z))

    -- Prepara as pastas oficiais e limpa qualquer resquício antigo
    local map = workspace:FindFirstChild("Map")
    if not map then
        map = Instance.new("Folder")
        map.Name = "Map"
        map.Parent = workspace
    end

    local oldDirect = workspace:FindFirstChild("Village")
    if oldDirect then oldDirect:Destroy() end

    local oldVillage = map:FindFirstChild("Village")
    if oldVillage then oldVillage:Destroy() end

    for _, looseName in ipairs({ "Muralha", "Portoes", "Praca", "Mercado", "Bairro", "Casas", "Natureza", "CasaDaLumen", "Oficina", "Taverna", "Padaria", "Armazem", "Botanica" }) do
        local objW = workspace:FindFirstChild(looseName)
        if objW and objW ~= map then objW:Destroy() end
        local objM = map:FindFirstChild(looseName)
        if objM then objM:Destroy() end
    end

    root = Instance.new("Folder")
    root.Name = "Village"
    root:SetAttribute("Gen", "Village")
    root.Parent = map

    local function ensureFolder(name)
        local f = workspace:FindFirstChild(name)
        if not f then
            f = Instance.new("Folder")
            f.Name = name
            f.Parent = workspace
        end
        for _, c in ipairs(f:GetChildren()) do
            local gen = c:GetAttribute("Gen")
            if gen == "Village" or gen == "Village32" then c:Destroy() end
        end
        return f
    end

    plotsF = ensureFolder("Plots")
    stallsF = ensureFolder("Stalls")
    zonesF = ensureFolder("Zones")
    spawnsF = ensureFolder("Spawns")

    -- 2. Constrói todas as camadas da vila
    print("[VillageBuilder] Modelando terreno e ruas...")
    terrain()

    print("[VillageBuilder] Erguendo a muralha circular defensiva...")
    buildWall()

    print("[VillageBuilder] Construindo os portões da Trilha e do Porto...")
    buildGates()

    print("[VillageBuilder] Erguendo a Praça Central e o Monumento da Lanterna Mestra...")
    buildPlaza()

    print("[VillageBuilder] Construindo o Mercado Central...")
    buildMarket()

    print("[VillageBuilder] Construindo os Edifícios Oficiais (Dona Lúmen, Oficina, Taverna, Padaria, Armazém, Botânica)...")
    buildLumenManor(-62, -12, -90)
    buildWorkshop(62, -12, 90)
    buildTavern(-62, 38, -90)
    buildBakery(-48, -68, -90)
    buildWarehouse(48, -68, 90)
    buildApothecary(48, 38, 90)

    print("[VillageBuilder] Delimitando os Terrenos Residenciais...")
    buildPlots()

    print("[VillageBuilder] Espalhando a vegetação estilizada da vila...")
    scatterNature()

    -- 3. Spawn da Praça para Respawn
    local sp = Instance.new("SpawnLocation")
    sp.Name = "Spawn_Praca"
    sp.Anchored = true
    sp.Size = Vector3.new(6, 1, 6)
    sp.CFrame = L(0, 0.4, 18)
    sp.Transparency = 1
    sp.CanCollide = false
    sp.CanQuery = false
    sp.Neutral = true
    sp.Enabled = false -- O spawn inicial oficial de novato é o Spawn_ForestEdge
    sp.Duration = 0
    sp:SetAttribute("Gen", "Village")
    sp:SetAttribute("Kind", "Respawn")
    sp.Parent = spawnsF

    -- 4. Métricas e Resumo
    local partCount = 0
    for _, inst in ipairs({ root, plotsF, stallsF }) do
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("BasePart") then partCount += 1 end
        end
    end

    print(string.format("================================================================="))
    print(string.format("✅ [VillageBuilder] Vila Oficial Concluída com Sucesso!"))
    print(string.format("   • Total de Peças Arquitetônicas: %d peças", partCount))
    print(string.format("   • Edifícios Oficiais: Sede de Dona Lúmen, Oficina, Taverna, Padaria, Armazém, Botânica"))
    print(string.format("   • Mercado: 8 Bancas comerciais configuradas"))
    print(string.format("   • Bairro Residencial: 12 Terrenos com caixas de correio e cercados"))
    print(string.format("   • Muralha: Raio 150 com 6 Torres de vigia e 2 Portões monumentais"))
    print(string.format("   • Natureza importada: %s", nature and "SIM (usando Assets/Nature)" or "NÃO (usando peças low-poly procedurais)"))
    print(string.format("================================================================="))
end

return Builder
