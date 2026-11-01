--!nocheck
-- BuildNature.luau v2 — natureza da floresta (fora da vila)
-- Compatível com MapConfig v2. NÃO constrói muralhas (VillageBuilder faz isso).
-- Command Bar (modo Edit):
--   require(game.ServerStorage.MapGen.BuildNature:Clone()).Run()
-- Ou por partes: .Forest() / .Bridges() / .Clear()

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local MapConfig = require(script.Parent.MapConfig)
local TerrainGen = require(script.Parent.TerrainGen)

local M = {}

-- ===== configuração =====
local CFG = {
    Seed = 7421,
    TreeGrid = 26,        -- espaçamento da grade de árvores (studs)
    TreeJitter = 12,      -- variação aleatória em torno do grid
    DetailGrid = 15,      -- espaçamento da grade de detalhes
    MaxTrees = 1400,
    MaxDetails = 2000,
    MaxBridges = 4,
    VillageMargin = 5,    -- margem extra além do raio da vila
    TrailClear = 8,       -- não colocar a menos de X studs de trilha
    RiverClear = 14,      -- não colocar a menos de X studs do rio
    SpawnClear = 30,      -- área livre ao redor do spawn
    GateClear = 50,       -- área livre ao redor dos portões
    MaxSlope = 0.75,      -- não colocar em encostas íngremes (normal.Y)
    GiantChance = 0.02,   -- chance de árvore gigante (110-170 studs)
    TallChance = 0.15,     -- chance de árvore alta (50-80 studs)
}

-- materiais que bloqueiam colocação (não é chão de floresta)
local BLOCK = {}
for _, m in ipairs({
    Enum.Material.Water, Enum.Material.Mud, Enum.Material.Ground,
    Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Basalt,
    Enum.Material.Sand, Enum.Material.Cobblestone, Enum.Material.Pavement,
    Enum.Material.Asphalt, Enum.Material.Concrete, Enum.Material.Salt,
    Enum.Material.Limestone,
}) do BLOCK[m] = true end

-- ===== estado interno =====
local S = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

-- ===== utilidades de terreno =====

-- raycast de cima para baixo: acha a superfície do terreno
local function ground(x, z)
    local r = Workspace:Raycast(Vector3.new(x, 1500, z), Vector3.new(0, -3000, 0), params)
    if r then return r.Position, r.Material, r.Normal, r.Instance end
    return nil
end

-- chão válido para natureza? (terreno, material aceitável, pouca inclinação)
local function okGround(x, z, maxSlope)
    local pos, mat, nrm, inst = ground(x, z)
    if not pos then return nil end
    if inst ~= Workspace.Terrain then return nil end
    if BLOCK[mat] then return nil end
    if nrm.Y < (maxSlope or CFG.MaxSlope) then return nil end
    return pos
end

-- distância até a borda da vila (negativo = dentro, positivo = fora)
local function villageDist(x, z)
    local v = MapConfig.Village
    return math.sqrt((x - v.Center.X) ^ 2 + (z - v.Center.Y) ^ 2) - v.Radius
end

local function nearTrail(x, z)
    return TerrainGen.TrailDistance(x, z) < CFG.TrailClear
end

local function nearRiver(x, z)
    return math.abs(x - TerrainGen.RiverX(z)) < CFG.RiverClear
end

local function nearSpawn(x, z)
    local sp = MapConfig.Spawn
    return math.sqrt((x - sp.X) ^ 2 + (z - sp.Y) ^ 2) < CFG.SpawnClear
end

local function nearGate(x, z)
    local R = MapConfig.Village.Radius
    -- portão da trilha (norte, -Z) e portão do porto (sul, +Z)
    return math.sqrt(x ^ 2 + (z + R) ^ 2) < CFG.GateClear
        or math.sqrt(x ^ 2 + (z - R) ^ 2) < CFG.GateClear
end

-- pode colocar natureza aqui? retorna pos ou nil
local function canPlace(x, z, maxSlope)
    if villageDist(x, z) < CFG.VillageMargin then return nil end
    if nearTrail(x, z) then return nil end
    if nearRiver(x, z) then return nil end
    if nearSpawn(x, z) then return nil end
    if nearGate(x, z) then return nil end
    return okGround(x, z, maxSlope)
end

-- ===== assets =====

local function pool(prefixes, exclude)
    local list = {}
    if not S.assets then return list end
    for _, a in S.assets:GetChildren() do
        local name = string.lower(a.Name)
        for _, p in prefixes do
            if string.sub(name, 1, #p) == p and not (exclude and string.find(name, exclude)) then
                table.insert(list, a)
                break
            end
        end
    end
    return list
end

local function pick(list)
    return list[S.rng:NextInteger(1, #list)]
end

local function sizeOf(i)
    if i:IsA("Model") then return i:GetExtentsSize() end
    return i.Size
end

local function prep(inst, shadow)
    local parts = inst:IsA("BasePart") and { inst } or inst:GetDescendants()
    for _, d in parts do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanTouch = false
            d.CanQuery = false
            d.CastShadow = shadow
        end
    end
end

-- coloca um asset no chão, escalando para uma altura (ou maior dimensão) alvo
local function put(asset, pos, target, parent, useMax, shadow)
    local c = asset:Clone()
    local s = sizeOf(c)
    local ref = useMax and math.max(s.X, s.Y, s.Z) or s.Y
    local k = target / math.max(ref, 0.01)
    local yaw = S.rng:NextNumber(0, math.pi * 2)
    if c:IsA("Model") then
        c:ScaleTo(c:GetScale() * k)
        prep(c, shadow)
        c:PivotTo(CFrame.Angles(0, yaw, 0))
        local cf, size = c:GetBoundingBox()
        local delta = Vector3.new(pos.X - cf.X, (pos.Y - 0.3) - (cf.Y - size.Y / 2), pos.Z - cf.Z)
        c:PivotTo(c:GetPivot() + delta)
    else
        c.Size = c.Size * k
        prep(c, shadow)
        c.CFrame = CFrame.new(pos.X, pos.Y - 0.3 + c.Size.Y / 2, pos.Z) * CFrame.Angles(0, yaw, 0)
    end
    c.Parent = parent
    return c
end

-- ===== floresta =====
function M.Forest()
    local trees = Instance.new("Folder")
    trees.Name = "Trees"
    trees.Parent = S.root
    local details = Instance.new("Folder")
    details.Name = "Details"
    details.Parent = S.root

    -- pools de assets
    local conifers = pool({ "tree_pine" })
    local tallPines = pool({ "tree_pinetall" })
    local broad = pool({ "tree_oak", "tree_default", "tree_fat", "tree_detailed", "tree_blocks", "tree_cone" }, "fall")
    local fall = pool({ "tree_oak", "tree_default", "tree_fat", "tree_detailed", "tree_blocks" })
    if #conifers == 0 then conifers = broad end
    if #broad == 0 then broad = conifers end
    if #tallPines == 0 then tallPines = conifers end
    if #conifers == 0 then
        warn("[Nature] nenhuma árvore (tree_*) em Assets/Nature — floresta vazia")
        return
    end

    local B = MapConfig.Bounds
    local placed, giants, talls = 0, 0, 0
    local n = 0

    for gx = B.MinX, B.MaxX, CFG.TreeGrid do
        for gz = B.MinZ, B.MaxZ, CFG.TreeGrid do
            if placed >= CFG.MaxTrees then break end
            n += 1
            if n % 150 == 0 then task.wait() end

            local x = gx + S.rng:NextNumber(-CFG.TreeJitter, CFG.TreeJitter)
            local z = gz + S.rng:NextNumber(-CFG.TreeJitter, CFG.TreeJitter)

            local vd = villageDist(x, z)
            if vd < CFG.VillageMargin then continue end

            -- densidade em manchas (noise): dá clareiras naturais
            local density = 0.5 + math.noise(x / 280, z / 280, 3.3) * 1.2
            density = math.clamp(density, 0, 0.95)
            -- ralo na borda da vila (transição suave)
            if vd < 30 then density *= vd / 30 end

            if S.rng:NextNumber() >= density then continue end

            local pos = canPlace(x, z)
            if not pos then continue end

            -- checa vizinhos: se um lado é água/trilha, aborta (evita árvore na beira)
            for _, o in { { 6, 0 }, { -6, 0 }, { 0, 6 }, { 0, -6 } } do
                local _, m = ground(x + o[1], z + o[2])
                if m and BLOCK[m] then pos = nil break end
            end
            if not pos then continue end

            local roll = S.rng:NextNumber()
            local h, asset
            local conifer = math.noise(x / 400, z / 400, 9.1) > -0.05

            if vd > 120 and roll < CFG.GiantChance then
                h = S.rng:NextNumber(110, 170); asset = pick(tallPines); giants += 1
            elseif roll < CFG.TallChance then
                h = S.rng:NextNumber(50, 80); asset = pick(conifer and conifers or broad); talls += 1
            else
                h = S.rng:NextNumber(22, 42)
                if #fall > 0 and math.noise(x / 160, z / 160, 5.5) > 0.3 then
                    asset = pick(fall)
                else
                    asset = pick(conifer and conifers or broad)
                end
            end

            local t = put(asset, pos, h, trees, false, h > 30)
            placed += 1

            -- tronco de colisão invisível para árvores altas
            if h >= 45 then
                local col = Instance.new("Part")
                col.Name = "Trunk"
                col.Anchored = true
                col.Transparency = 1
                col.CanQuery = false
                col.CanTouch = false
                col.Size = Vector3.new(h * 0.07, h * 0.4, h * 0.07)
                col.CFrame = CFrame.new(pos + Vector3.new(0, h * 0.2, 0))
                col.Parent = t
            end
        end
    end

    print(("[Nature] árvores=%d (gigantes=%d, altas=%d)"):format(placed, giants, talls))

    -- detalhes: flores, arbustos, pedras, troncos, tocos, cogumelos
    local flowers = pool({ "flower" })
    local bushes = pool({ "plant_bush", "bush" })
    local rocksS = pool({ "rock_small" })
    local rocksL = pool({ "rock_large" })
    local logs = pool({ "log" })
    local stumps = pool({ "stump" })
    local mush = pool({ "mushroom" })

    local count = 0
    local m = 0
    for gx = B.MinX, B.MaxX, CFG.DetailGrid do
        for gz = B.MinZ, B.MaxZ, CFG.DetailGrid do
            if count >= CFG.MaxDetails then break end
            m += 1
            if m % 250 == 0 then task.wait() end

            local x = gx + S.rng:NextNumber(-6, 6)
            local z = gz + S.rng:NextNumber(-6, 6)

            local vd = villageDist(x, z)
            -- dentro da vila: só flores e arbustos; na borda: pula
            local inVillage = vd < -8
            local onEdge = vd >= -8 and vd < 8
            if onEdge or nearGate(x, z) or nearSpawn(x, z) then continue end
            if S.rng:NextNumber() > 0.55 then continue end

            local pos = okGround(x, z, 0.7)
            if not pos then continue end

            local r = S.rng:NextNumber()
            if r < 0.30 and #flowers > 0 then
                for _ = 1, S.rng:NextInteger(5, 9) do
                    local fx, fz = x + S.rng:NextNumber(-5, 5), z + S.rng:NextNumber(-5, 5)
                    local fp = okGround(fx, fz, 0.7)
                    if fp then put(pick(flowers), fp, S.rng:NextNumber(1.6, 3), details, false, false) count += 1 end
                end
            elseif r < 0.55 and #bushes > 0 then
                put(pick(bushes), pos, S.rng:NextNumber(4, 8), details, true, false) count += 1
            elseif inVillage then
                continue -- dentro da vila: só flores e arbustos
            elseif r < 0.72 and #rocksS > 0 then
                put(pick(rocksS), pos, S.rng:NextNumber(2.5, 6), details, true, false) count += 1
            elseif r < 0.80 and #rocksL > 0 and vd > 80 then
                put(pick(rocksL), pos, S.rng:NextNumber(8, 22), details, true, true) count += 1
            elseif r < 0.88 and #logs > 0 then
                put(pick(logs), pos, S.rng:NextNumber(9, 16), details, true, false) count += 1
            elseif r < 0.94 and #stumps > 0 then
                put(pick(stumps), pos, S.rng:NextNumber(3, 5), details, true, false) count += 1
            elseif #mush > 0 then
                put(pick(mush), pos, S.rng:NextNumber(1.5, 4), details, true, false) count += 1
            end
        end
    end
    print("[Nature] detalhes=" .. count)
end

-- ===== pontes =====
local function beam(parent, a, b, w, t, color, mat)
    local p = Instance.new("Part")
    p.Anchored = true
    p.Material = mat
    p.Color = color
    p.Size = Vector3.new(w, t, (b - a).Magnitude + 0.15)
    p.CFrame = CFrame.lookAt((a + b) / 2, b)
    p.Parent = parent
    return p
end

local function buildBridge(parent, A, B)
    local dirH = Vector3.new(B.X - A.X, 0, B.Z - A.Z)
    local len = dirH.Magnitude
    local dir = dirH.Unit
    A -= dir * 5
    B += dir * 5
    len += 10
    local side = dir:Cross(Vector3.yAxis).Unit
    local baseY = math.max(A.Y, B.Y) + 1.6
    local arch = math.clamp(len * 0.06, 1.5, 4)
    local steps = math.max(8, math.floor(len / 5))
    local W = 9
    local wood = Color3.fromRGB(139, 94, 60)
    local dark = Color3.fromRGB(92, 58, 38)

    local nodes = {}
    for i = 0, steps do
        local t = i / steps
        local flat = A:Lerp(B, t)
        nodes[i] = Vector3.new(flat.X, baseY + arch * math.sin(math.pi * t), flat.Z)
    end
    for i = 0, steps - 1 do
        local a, b = nodes[i], nodes[i + 1]
        beam(parent, a, b, W, 1, wood, Enum.Material.WoodPlanks)
        for k = -1, 1, 2 do
            beam(parent, a + side * k * (W / 2) + Vector3.new(0, 2.4, 0), b + side * k * (W / 2) + Vector3.new(0, 2.4, 0), 0.5, 0.5, dark, Enum.Material.Wood)
            beam(parent, a + side * k * (W / 2) + Vector3.new(0, 1.3, 0), b + side * k * (W / 2) + Vector3.new(0, 1.3, 0), 0.4, 0.4, dark, Enum.Material.Wood)
        end
    end
    for i = 0, steps do
        local n = nodes[i]
        for k = -1, 1, 2 do
            local post = Instance.new("Part")
            post.Anchored = true
            post.Material = Enum.Material.Wood
            post.Color = dark
            post.Size = Vector3.new(0.8, 3.4, 0.8)
            post.Position = n + side * k * (W / 2) + Vector3.new(0, 1.5, 0)
            post.Parent = parent
        end
        if i % 2 == 0 then
            local g = ground(n.X, n.Z)
            local bottom = (g and g.Y or n.Y - 10) - 6
            local h = n.Y - bottom
            local pil = Instance.new("Part")
            pil.Anchored = true
            pil.Material = Enum.Material.Wood
            pil.Color = dark
            pil.Size = Vector3.new(1.6, h, 1.6)
            pil.Position = Vector3.new(n.X, bottom + h / 2, n.Z) + side * (W / 2 - 1)
            pil.Parent = parent
            local pil2 = pil:Clone()
            pil2.Position = Vector3.new(n.X, bottom + h / 2, n.Z) - side * (W / 2 - 1)
            pil2.Parent = parent
        end
    end
    for _, e in { { 0, 1 }, { steps, -1 } } do
        local n = nodes[e[1]]
        for k = -1, 1, 2 do
            local l = Instance.new("Part")
            l.Shape = Enum.PartType.Ball
            l.Size = Vector3.new(1.6, 1.6, 1.6)
            l.Position = n + side * k * (W / 2) + Vector3.new(0, 4.6, 0)
            l.Anchored = true
            l.CanCollide = false
            l.CanQuery = false
            l.Material = Enum.Material.Neon
            l.Color = Color3.fromRGB(255, 200, 110)
            local pl = Instance.new("PointLight")
            pl.Range = 28
            pl.Brightness = 1.6
            pl.Color = Color3.fromRGB(255, 185, 95)
            pl.Shadows = false
            pl.Parent = l
            l.Parent = parent
        end
    end
end

function M.Bridges()
    local f = Instance.new("Folder")
    f.Name = "Bridges"
    f.Parent = S.root

    local B = MapConfig.Bounds
    local waters = {}
    local n = 0
    for x = B.MinX, B.MaxX, 24 do
        for z = B.MinZ, B.MaxZ, 24 do
            n += 1
            if n % 300 == 0 then task.wait() end
            local _, m = ground(x, z)
            if m == Enum.Material.Water then table.insert(waters, Vector3.new(x, 0, z)) end
        end
    end
    print("[Nature] pontos de água encontrados: " .. #waters)

    -- embaralha (Fisher-Yates)
    for i = #waters, 2, -1 do
        local j = S.rng:NextInteger(1, i)
        waters[i], waters[j] = waters[j], waters[i]
    end

    local built = {}
    local tries = 0
    for _, w in waters do
        if #built >= CFG.MaxBridges then break end
        tries += 1
        if tries % 20 == 0 then task.wait() end

        -- muito perto de outra ponte ou da vila? pula
        local tooClose = false
        for _, b in built do
            if (b - w).Magnitude < 170 then tooClose = true break end
        end
        local vd = villageDist(w.X, w.Z)
        if vd < 40 then tooClose = true end
        if tooClose then continue end

        -- procura a melhor direção de travessia (menor vão)
        local best
        for deg = 0, 165, 15 do
            local dir = Vector3.new(math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
            local samples = {}
            for k = -12, 12 do
                local p, m, nrm = ground(w.X + dir.X * k * 4, w.Z + dir.Z * k * 4)
                samples[k] = { p = p, water = (m == Enum.Material.Water), up = nrm and nrm.Y or 0 }
            end
            if samples[0].water then
                local lo, hi = 0, 0
                while samples[lo - 1] and samples[lo - 1].water do lo -= 1 end
                while samples[hi + 1] and samples[hi + 1].water do hi += 1 end
                local a, b = samples[lo - 1], samples[hi + 1]
                if a and b and a.p and b.p and a.up > 0.7 and b.up > 0.7 and math.abs(a.p.Y - b.p.Y) < 8 then
                    local L = (b.p - a.p).Magnitude
                    if L > 12 and L < 70 and (not best or L < best.L) then
                        best = { L = L, A = a.p, B = b.p }
                    end
                end
            end
        end
        if best then
            buildBridge(f, best.A, best.B)
            table.insert(built, w)
            print(("[Nature] ponte em %s (vão %.0f studs)"):format(tostring(best.A), best.L))
        end
    end
    if #built == 0 then
        warn("[Nature] nenhuma ponte possível; rio largo/estreito demais?")
    end
end

-- ===== principal =====
function M.Clear()
    local r = Workspace:FindFirstChild("Nature")
    if r then r:Destroy() end
end

function M.Run(opts)
    if opts then for k, v in opts do CFG[k] = v end end
    S.rng = Random.new(CFG.Seed)

    -- limpa a natureza antiga
    M.Clear()
    S.root = Instance.new("Folder")
    S.root.Name = "Nature"
    S.root.Parent = Workspace

    -- assets externos (opcional: ServerStorage/Assets/Nature)
    local assets = ServerStorage:FindFirstChild("Assets")
    S.assets = assets and assets:FindFirstChild("Nature")
    params.FilterDescendantsInstances = { S.root }

    local B = MapConfig.Bounds
    print(("[Nature] mapa %d×%d | vila raio=%d | assets=%s"):format(
        B.MaxX - B.MinX, B.MaxZ - B.MinZ, MapConfig.Village.Radius,
        S.assets and "SIM" or "não"))

    M.Bridges()
    M.Forest()

    print("[Nature] pronto. Peças em Workspace/Nature.")
end

return M
