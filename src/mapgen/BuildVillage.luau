local C = require(script.Parent.MapConfig)
local BuildVillage = {}

local G, TAG = C.BaseHeight, "Village32"
local M = Enum.Material
local STONE, WOOD, DARK = Color3.fromRGB(150, 146, 138), Color3.fromRGB(150, 106, 66), Color3.fromRGB(84, 70, 58)
local ROOF, GOLD, PATH = Color3.fromRGB(176, 84, 66), Color3.fromRGB(255, 200, 90), Color3.fromRGB(150, 130, 104)
local AWN = { Color3.fromRGB(196, 84, 70), Color3.fromRGB(70, 150, 150), Color3.fromRGB(220, 170, 70), Color3.fromRGB(90, 120, 190) }

local function ensure(parent, name)
    local f = parent:FindFirstChild(name)
    if not f then f = Instance.new("Folder") f.Name = name f.Parent = parent end
    return f
end

local function clean(folder)
    for _, c in folder:GetChildren() do
        if c:GetAttribute("Gen") == TAG then c:Destroy() end
    end
end

local function group(parent, className, name)
    local g = Instance.new(className)
    g.Name = name
    g:SetAttribute("Gen", TAG)
    g.Parent = parent
    return g
end

local function part(parent, name, size, cf, color, material)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame, p.Anchored = name, size, cf, true
    p.Color, p.Material = color, material or M.SmoothPlastic
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function hidden(p)
    p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = 1, false, false, false, false
    return p
end

local function label(board, text)
    local gui = Instance.new("SurfaceGui")
    gui.Face, gui.SizingMode, gui.PixelsPerStud = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
    gui.Parent = board
    local t = Instance.new("TextLabel")
    t.Name, t.Size, t.BackgroundTransparency = "Text", UDim2.fromScale(1, 1), 1
    t.Text, t.TextScaled, t.Font, t.TextColor3 = text, true, Enum.Font.GothamBold, Color3.fromRGB(255, 244, 214)
    t.Parent = gui
end

-- placa com postes; "facing" = direção para onde a frente aponta
local function sign(parent, name, pos, facing, size, text)
    local cf = CFrame.lookAt(pos, pos + facing)
    local board = part(parent, name, size, cf, DARK, M.Wood)
    label(board, text)
    local drop = pos.Y - size.Y / 2 - G
    if drop > 0.5 then
        for _, s in { -1, 1 } do
            part(parent, name .. "_Post", Vector3.new(0.6, drop, 0.6), cf * CFrame.new(s * (size.X / 2 - 0.8), -size.Y / 2 - drop / 2, 0.2), DARK, M.Wood)
        end
    end
    return board
end

local function path(parent, name, cx, cz, sx, sz)
    part(parent, name, Vector3.new(sx, 0.4, sz), CFrame.new(cx, G + 0.1, cz), PATH, M.Cobblestone)
end

local function lamp(parent, x, z)
    part(parent, "LampPost", Vector3.new(0.6, 9, 0.6), CFrame.new(x, G + 4.5, z), DARK, M.Metal)
    local b = part(parent, "LampBulb", Vector3.new(1.6, 1.6, 1.6), CFrame.new(x, G + 9.4, z), Color3.fromRGB(255, 214, 140), M.Neon)
    b.Shape, b.CastShadow = Enum.PartType.Ball, false
    b:SetAttribute("NightLamp", true)
    local l = Instance.new("PointLight")
    l.Range, l.Brightness, l.Color, l.Shadows = 30, 1.2, Color3.fromRGB(255, 200, 120), false
    l.Parent = b
end

local function cylinder(parent, name, h, d, x, y, z, color, mat)
    local c = part(parent, name, Vector3.new(h, d, d), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), color, mat)
    c.Shape = Enum.PartType.Cylinder
    return c
end

local function buildPlaza(root)
    local f = group(root, "Folder", "Plaza")
    cylinder(f, "PlazaDisc", 0.5, 46, 0, G + 0.15, 0, STONE, M.Cobblestone)
    cylinder(f, "PlazaInner", 0.6, 30, 0, G + 0.17, 0, Color3.fromRGB(176, 170, 158), M.Cobblestone)

    local lm = group(f, "Model", "LanternaMestra")
    lm:SetAttribute("LampLevel", 0)
    cylinder(lm, "Base", 3, 10, 0, G + 1.9, 0, STONE, M.Slate)
    part(lm, "Column", Vector3.new(2, 8, 2), CFrame.new(0, G + 7.4, 0), DARK, M.Wood)
    local lantern = part(lm, "MasterLantern", Vector3.new(4, 4, 4), CFrame.new(0, G + 13.4, 0), Color3.fromRGB(90, 90, 96), M.Glass)
    lantern.Shape = Enum.PartType.Ball
    local light = Instance.new("PointLight")
    light.Range, light.Brightness, light.Enabled, light.Shadows = 40, 0, false, false
    light.Parent = lantern

    local feat = sign(f, "Board_Featured", Vector3.new(-12, G + 5, -15), Vector3.new(0, 0, 1), Vector3.new(10, 6, 0.6), "★ DESTAQUE DA SEMANA\n(em breve)")
    feat:SetAttribute("TextKey", "board_featured")
    local tre = sign(f, "Board_Treasure", Vector3.new(12, G + 5, -15), Vector3.new(0, 0, 1), Vector3.new(10, 6, 0.6), "TESOURO DA CAVERNA\n0 itens")
    tre:SetAttribute("TextKey", "board_treasure")
    tre:SetAttribute("Count", 0)

    for i, a in { 0, 90, 180, 270 } do
        local r = math.rad(a + 45)
        local pos = Vector3.new(math.sin(r) * 19, G + 1.2, math.cos(r) * 19)
        part(f, "Bench" .. i, Vector3.new(5, 0.6, 1.6), CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)), WOOD, M.WoodPlanks)
        if i % 2 == 1 then lamp(f, math.sin(r) * 25, math.cos(r) * 25) end
    end
end

local function buildPaths(root)
    local f = group(root, "Folder", "Paths")
    path(f, "Path_Gate", 0, -65, 8, 86)
    path(f, "Path_Plots", 0, 44, 8, 44)
    path(f, "Path_PlotStreet", 0, 66, 190, 10)
    path(f, "Path_MarketStreet", -55, -52, 12, 106)
    path(f, "Path_MarketLink", -38, 0, 34, 6)
    path(f, "Path_Workshop", 28, -62, 48, 6)
    for _, z in { -90, -60, -30 } do
        lamp(f, 6, z)
        lamp(f, -6, z)
    end
end

local function buildGate(root)
    local f = group(root, "Folder", "Gate")
    local z = -108
    for _, s in { -1, 1 } do
        part(f, "Pillar", Vector3.new(3, 14, 3), CFrame.new(s * 8, G + 7, z), STONE, M.Slate)
        part(f, "Wall", Vector3.new(30, 3, 1.5), CFrame.new(s * 25, G + 1.5, z), STONE, M.Cobblestone)
    end
    part(f, "Lintel", Vector3.new(19, 2.5, 3), CFrame.new(0, G + 15.25, z), DARK, M.Wood)
    local b = part(f, "GateLantern", Vector3.new(1.8, 1.8, 1.8), CFrame.new(0, G + 12.8, z), Color3.fromRGB(255, 214, 140), M.Neon)
    b.Shape, b.CastShadow = Enum.PartType.Ball, false
    b:SetAttribute("NightLamp", true)
    sign(f, "GateSign_North", Vector3.new(0, G + 15.25, z - 1.7), Vector3.new(0, 0, -1), Vector3.new(9, 1.8, 0.2), "TRILHA DA FLORESTA")
    sign(f, "GateSign_South", Vector3.new(0, G + 15.25, z + 1.7), Vector3.new(0, 0, 1), Vector3.new(9, 1.8, 0.2), "VILA REFÚGIO")
    local pad = cylinder(f, "GroupPad", 0.3, 12, 0, G + 0.35, z + 12, Color3.fromRGB(120, 200, 140), M.Neon)
    pad.Transparency, pad.CanCollide, pad.CastShadow = 0.6, false, false
    pad:SetAttribute("GroupSize", 4)
    pad:SetAttribute("WaitSeconds", 20)
end

local function buildStall(folder, id, x, z, facing)
    local m = group(folder, "Model", ("Stall_%02d"):format(id))
    local base = Vector3.new(x, G, z)
    local o = CFrame.lookAt(base, base + facing)
    local function p(n, size, lx, ly, lz, col, mat)
        return part(m, n, size, o * CFrame.new(lx, ly, lz), col, mat)
    end
    local counter = p("Counter", Vector3.new(8, 3, 2), 0, 1.5, -1.5, WOOD, M.WoodPlanks)
    p("Back", Vector3.new(8.4, 6, 0.4), 0, 3, 2.6, DARK, M.Wood)
    for _, s in { -1, 1 } do p("Post", Vector3.new(0.5, 6.5, 0.5), s * 4, 3.25, -2.6, DARK, M.Wood) end
    p("Awning", Vector3.new(9.2, 0.5, 6.8), 0, 6.5, 0, AWN[(id - 1) % #AWN + 1], M.Fabric).CanCollide = false
    hidden(p("ItemPoint", Vector3.new(1, 1, 1), 0, 3.6, -1.5, STONE, M.SmoothPlastic))
    hidden(p("CustomerPoint", Vector3.new(1, 1, 1), 0, 1, -6, STONE, M.SmoothPlastic))
    m.PrimaryPart = counter
    m:SetAttribute("StallId", id)
    m:SetAttribute("OwnerUserId", 0)
end

local function buildMarket(root, stalls)
    local f = group(root, "Folder", "Market")
    sign(f, "MarketArch", Vector3.new(-55, G + 9, -12), Vector3.new(0, 0, 1), Vector3.new(12, 3, 0.6), "MERCADO")
    for i, z in { -30, -52, -74, -96 } do
        buildStall(stalls, i * 2 - 1, -68, z, Vector3.new(1, 0, 0))
        buildStall(stalls, i * 2, -42, z, Vector3.new(-1, 0, 0))
    end
    for _, z in { -40, -85 } do lamp(f, -55, z) end
end

local function buildWorkshop(root)
    local m = group(root, "Model", "Workshop")
    local W, D, H = 26, 20, 10
    local o = CFrame.lookAt(Vector3.new(62, G, -62), Vector3.new(61, G, -62)) -- porta virada para o oeste
    local missing = 0
    local function p(n, sx, sy, sz, x, y, z, col, mat)
        return part(m, n, Vector3.new(sx, sy, sz), o * CFrame.new(x, y, z), col, mat or M.WoodPlanks)
    end
    local function ghost(n, sx, sy, sz, x, y, z)
        missing += 1
        local g = p(n, sx, sy, sz, x, y, z, GOLD, M.SmoothPlastic)
        g.Transparency, g.CanCollide, g.CanQuery, g.CastShadow = 0.65, false, false, false
        g:SetAttribute("Missing", true)
        g:SetAttribute("PieceId", missing)
    end
    p("Floor", W, 0.6, D, 0, 0.3, 0, DARK)
    p("WallBack", W, H, 1, 0, 0.6 + H / 2, D / 2 - 0.5, WOOD)
    p("WallLeft", 1, H, D, -W / 2 + 0.5, 0.6 + H / 2, 0, WOOD)
    p("WallRightLow", 1, 4, D, W / 2 - 0.5, 0.6 + 2, 0, WOOD)
    ghost("Missing_RightWall", 1, H - 4, D, W / 2 - 0.5, 0.6 + 4 + (H - 4) / 2, 0)
    p("WallFrontL", 10, H, 1, -8, 0.6 + H / 2, -D / 2 + 0.5, WOOD)
    p("WallFrontRLow", 10, 5, 1, 8, 0.6 + 2.5, -D / 2 + 0.5, WOOD)
    ghost("Missing_FrontRight", 10, H - 5, 1, 8, 0.6 + 5 + (H - 5) / 2, -D / 2 + 0.5)
    p("Lintel", 6, H - 7, 1, 0, 0.6 + 7 + (H - 7) / 2, -D / 2 + 0.5, WOOD)
    p("RoofLeft", 14, 0.8, D + 2, -7, 0.6 + H + 0.4, 0, ROOF, M.Slate)
    ghost("Missing_Roof", 14, 0.8, D + 2, 7, 0.6 + H + 0.4, 0)
    ghost("Missing_Sign", 5, 1.6, 0.3, 0, 0.6 + 8.8, -D / 2 - 0.15)
    p("Workbench", 8, 3, 3, -6, 0.6 + 1.5, 6, DARK, M.Wood)
    local bulb = p("Lamp", 1.2, 1.2, 1.2, 0, 0.6 + 7, 4, Color3.fromRGB(255, 214, 140), M.Neon)
    bulb.Shape, bulb.CastShadow = Enum.PartType.Ball, false
    bulb:SetAttribute("NightLamp", true)
    local l = Instance.new("PointLight")
    l.Range, l.Brightness, l.Shadows = 24, 1, false
    l.Parent = bulb
    for i, c in { Vector3.new(-10, 1.5, -13), Vector3.new(-10, 1.5, -16.2), Vector3.new(-10, 4.7, -14.6) } do
        p("Crate" .. i, 3, 3, 3, c.X, c.Y, c.Z, WOOD, M.Wood)
    end
    m:SetAttribute("TotalPieces", missing)
    m:SetAttribute("RestoredPieces", 0)
end

local function buildPlots(plots)
    local n = 0
    for r, z in { 50, 82 } do
        for _, x in { -75, -45, -15, 15, 45, 75 } do
            n += 1
            local slab = part(plots, ("Plot_%02d"):format(n), Vector3.new(22, 0.4, 22), CFrame.new(x, G + 0.1, z), Color3.fromRGB(128, 156, 90), M.SmoothPlastic)
            slab:SetAttribute("Gen", TAG)
            slab:SetAttribute("PlotId", n)
            slab:SetAttribute("OwnerUserId", 0)
            local north = r == 2
            local edge = if north then z - 11 else z + 11
            local tag = sign(plots, ("PlotSign_%02d"):format(n), Vector3.new(x - 8, G + 3.2, if north then edge + 1 else edge - 1), Vector3.new(0, 0, if north then -1 else 1), Vector3.new(5, 2, 0.4), ("Terreno %02d\nLivre"):format(n))
            tag:SetAttribute("Gen", TAG)
            tag:SetAttribute("PlotId", n)
        end
    end
end

local function buildMarkers(markers)
    for _, c in markers:GetChildren() do
        if c:GetAttribute("Gen") == TAG then c:Destroy() end
    end
    local function mark(name, x, z)
        local p = hidden(part(markers, name, Vector3.new(2, 2, 2), CFrame.new(x, G + 1, z), STONE))
        p:SetAttribute("Gen", TAG)
    end
    mark("Marker_DonaLumen", 24, -26)
    mark("Marker_Workshop", 50, -62)
    mark("Marker_MarketEntrance", -55, -6)
    mark("Marker_GroupPoint", 0, -96)
end

function BuildVillage.Run()
    local t0 = os.clock()
    local map = ensure(workspace, "Map")
    local root = ensure(map, "Village")
    local plots, stalls = ensure(workspace, "Plots"), ensure(workspace, "Stalls")
    clean(root); clean(plots); clean(stalls)
    buildPlaza(root)
    buildPaths(root)
    buildGate(root)
    buildMarket(root, stalls)
    buildWorkshop(root)
    buildPlots(plots)
    buildMarkers(ensure(map, "Markers"))
    pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("MapGen Village") end)
    print(("[MapGen] Vila pronta em %.1fs"):format(os.clock() - t0))
end

return BuildVillage
