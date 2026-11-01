--!nocheck
-- BuildNature.luau (ModuleScript em ServerStorage/MapGen)  -- v3
-- Command Bar (modo Edit):  require(game.ServerStorage.MapGen.BuildNature:Clone()).Run()
-- Por partes: .Forest() / .Bridges() / .Clear()
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local MapConfig = require(script.Parent.MapConfig)
local TG = require(script.Parent.TerrainGen)

local M = {}
M.Version = 3

local CFG = {
    Seed = 7421,
    GateAngles = { 270 },   -- 270 = lado -Z (portao da trilha, igual a VillageBuilder)
    ForestGrid = 28,
    DetailGrid = 20,
    MaxTrees = 4500,
    MaxDetails = 3500,
    MaxBridges = 8,
    GiantChance = 0.03,       -- floresta comum
    AncientGiantChance = 0.32, -- Floresta Antiga
    TallChance = 0.20,
}

local BLOCK = {}
for _, m in ipairs({
    Enum.Material.Water, Enum.Material.Mud, Enum.Material.Ground, Enum.Material.Rock,
    Enum.Material.Cobblestone, Enum.Material.Pavement, Enum.Material.Asphalt, Enum.Material.Concrete,
    Enum.Material.Salt, Enum.Material.Limestone, Enum.Material.CrackedLava,
}) do BLOCK[m] = true end
-- materiais que so bloqueiam na floresta comum (nos biomas sao o chao normal)
local DRY = { [Enum.Material.Sand] = true, [Enum.Material.Basalt] = true, [Enum.Material.Slate] = true, [Enum.Material.Sandstone] = true }

local S = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function ground(x, z)
    local r = Workspace:Raycast(Vector3.new(x, S.topY, z), Vector3.new(0, -(S.topY + 100), 0), params)
    if r then return r.Position, r.Material, r.Normal, r.Instance end
    return nil
end

local function okGround(x, z, maxSlope, dryOk)
    local pos, mat, nrm, inst = ground(x, z)
    if not pos then return nil, "vazio" end
    if inst ~= Workspace.Terrain then return nil, "nao-terreno" end
    if BLOCK[mat] then return nil, mat.Name end
    if DRY[mat] and not dryOk then return nil, mat.Name end
    if nrm.Y < (maxSlope or 0.8) then return nil, "inclinado" end
    return pos
end

local function wetNear(x, z)
    local offs = { { 6, 0 }, { -6, 0 }, { 0, 6 }, { 0, -6 } }
    for _, o in ipairs(offs) do
        local _, m = ground(x + o[1], z + o[2])
        if m == Enum.Material.Water or m == Enum.Material.Mud then return true end
    end
    return false
end

local function freshFolder(name)
    local old = S.root:FindFirstChild(name)
    if old then old:Destroy() end
    local f = Instance.new("Folder")
    f.Name = name
    f.Parent = S.root
    return f
end

local function setup(opts)
    if opts then for k, v in pairs(opts) do CFG[k] = v end end
    S.b = MapConfig.Bounds
    S.topY = S.b.MaxY + 200
    S.R = MapConfig.Village.Radius - 20 -- 150 = muralha
    S.center = Vector3.new(MapConfig.Village.Center.X, 0, MapConfig.Village.Center.Y)
    local vc = Workspace:FindFirstChild("VillageCenter")
    if vc then
        local p = vc:IsA("BasePart") and vc.Position or vc:GetPivot().Position
        S.center = Vector3.new(p.X, 0, p.Z)
        local r = vc:GetAttribute("Radius")
        if type(r) == "number" then S.R = r end
    end
    S.rng = Random.new(CFG.Seed)
    local root = Workspace:FindFirstChild("Nature")
    if not root then
        root = Instance.new("Folder")
        root.Name = "Nature"
        root.Parent = Workspace
    end
    S.root = root
    params.FilterDescendantsInstances = { root }
    local assets = ServerStorage:FindFirstChild("Assets")
    S.assets = assets and assets:FindFirstChild("Nature")
    print(string.format("[Nature] v%d mapa X %d..%d  Z %d..%d  vila r=%d", M.Version, S.b.MinX, S.b.MaxX, S.b.MinZ, S.b.MaxZ, S.R))
end

local function pool(prefixes, mustHave, exclude)
    local list = {}
    if not S.assets then return list end
    for _, a in ipairs(S.assets:GetChildren()) do
        for _, p in ipairs(prefixes) do
            if a.Name:sub(1, #p) == p
                and (not mustHave or a.Name:find(mustHave))
                and not (exclude and a.Name:find(exclude)) then
                table.insert(list, a)
                break
            end
        end
    end
    return list
end

local function pick(list) return list[S.rng:NextInteger(1, #list)] end

local function sizeOf(i)
    if i:IsA("Model") then return i:GetExtentsSize() end
    return i.Size
end

local function prep(inst, shadow)
    local parts = inst:IsA("BasePart") and { inst } or inst:GetDescendants()
    for _, d in ipairs(parts) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanTouch = false
            d.CanQuery = false
            d.CastShadow = shadow
        end
    end
end

-- coloca um asset no chao, escalando para uma altura (ou maior dimensao) alvo
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

local function nearGate(x, z, dist)
    local off = Vector3.new(x - S.center.X, 0, z - S.center.Z)
    if off.Magnitude < 1 then return false end
    for _, deg in ipairs(CFG.GateAngles) do
        local g = Vector3.new(math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
        if off.Unit:Dot(g) > 0.96 and off.Magnitude < S.R + dist then return true end
    end
    return false
end

local function naVila(x, z, margem)
    return Vector3.new(x - S.center.X, 0, z - S.center.Z).Magnitude < S.R + margem
end

----------------------------------------------------------------- FLORESTA
function M.Forest()
    if not S.root then setup() end
    if not S.assets then warn("[Nature] ServerStorage/Assets/Nature nao encontrado") return end
    local trees = freshFolder("Trees")
    local details = freshFolder("Details")
    local c, R = S.center, S.R

    local pines = pool({ "tree_pine" }, nil, "dark")
    local pinesDark = pool({ "tree_pine" }, "dark")
    local tallPines = pool({ "tree_pineTall" })
    local broad = pool({ "tree_oak", "tree_default", "tree_fat", "tree_detailed", "tree_blocks", "tree_cone" }, nil, "fall")
    local broadDark = pool({ "tree_oak", "tree_default", "tree_fat", "tree_detailed", "tree_blocks", "tree_cone" }, "dark")
    local fallOnly = pool({ "tree_oak", "tree_default", "tree_fat", "tree_detailed", "tree_blocks" }, "fall")
    local all = pool({ "tree_" })
    if #all == 0 then warn("[Nature] nenhuma arvore (tree_*) em Assets/Nature") return end
    if #pines == 0 then pines = all end
    if #pinesDark == 0 then pinesDark = pines end
    if #broad == 0 then broad = all end
    if #broadDark == 0 then broadDark = broad end
    if #tallPines == 0 then tallPines = pines end
    if #fallOnly == 0 then fallOnly = broad end

    local rej, placed, giants, talls, byBiome = {}, 0, 0, 0, {}
    local n = 0
    local g = CFG.ForestGrid
    local gx = S.b.MinX + 40
    while gx <= S.b.MaxX - 40 do
        local gz = S.b.MinZ + 40
        while gz <= S.b.MaxZ - 40 do
            n = n + 1
            if n % 120 == 0 then task.wait() end
            if placed < CFG.MaxTrees then
                local x = gx + S.rng:NextNumber(-12, 12)
                local z = gz + S.rng:NextNumber(-12, 12)
                local d = Vector3.new(x - c.X, 0, z - c.Z).Magnitude
                local biome = TG.BiomeAt(x, z)
                local ancient = TG.InAncient(x, z)
                local td = TG.TrailDistance(x, z)
                local skip = naVila(x, z, 10) or nearGate(x, z, 60) or td < 9
                local density = 0
                if not skip then
                    if biome == "Forest" then
                        density = 0.5 + math.noise(x / 280, z / 280, 3.3) * 1.2
                        if ancient then density = 0.92 end
                        if z > 150 and not ancient then density = density * 0.35 end -- campo aberto ao sul
                    elseif biome == "Snow" then density = 0.35
                    elseif biome == "Swamp" then density = 0.30
                    elseif biome == "Desert" then density = 0.03
                    else density = 0 end
                    if nearGate(x, z, 160) then density = 0 end
                    density = math.clamp(density, 0, 0.95)
                end
                if density > 0 and S.rng:NextNumber() < density then
                    local pos, why = okGround(x, z, 0.8, biome ~= "Forest")
                    if pos and wetNear(x, z) then pos = nil why = "agua/trilha" end
                    if not pos then
                        rej[why or "?"] = (rej[why or "?"] or 0) + 1
                    else
                        local roll = S.rng:NextNumber()
                        local conifer = math.noise(x / 400, z / 400, 9.1) > -0.05
                        local h, asset
                        local giantP = ancient and CFG.AncientGiantChance or CFG.GiantChance
                        if biome == "Snow" then
                            h = S.rng:NextNumber(24, 50)
                            asset = pick(roll < 0.5 and pinesDark or pines)
                            if roll < 0.06 then h = S.rng:NextNumber(70, 120) asset = pick(tallPines) end
                        elseif biome == "Swamp" then
                            h = S.rng:NextNumber(16, 34)
                            asset = pick(broadDark)
                        elseif biome == "Desert" then
                            h = S.rng:NextNumber(12, 22)
                            asset = pick(fallOnly)
                        elseif d > R + 120 and roll < giantP then
                            h = S.rng:NextNumber(110, ancient and 190 or 160)
                            if S.rng:NextNumber() < 0.5 then asset = pick(tallPines) else asset = pick(broad) end
                            giants = giants + 1
                        elseif roll < giantP + CFG.TallChance then
                            h = S.rng:NextNumber(50, 85)
                            asset = pick(conifer and pines or broad)
                            talls = talls + 1
                        else
                            h = S.rng:NextNumber(22, 42)
                            if math.noise(x / 160, z / 160, 5.5) > 0.3 then asset = pick(fallOnly)
                            else asset = pick(conifer and pines or broad) end
                        end
                        if h >= 45 and td < 20 then h = 30 end -- perto da trilha: nada gigante cobrindo o caminho
                        local t = put(asset, pos, h, trees, false, h > 30)
                        placed = placed + 1
                        byBiome[biome] = (byBiome[biome] or 0) + 1
                        if h >= 45 then
                            local col = Instance.new("Part")
                            col.Name = "Trunk"
                            col.Anchored = true
                            col.CanCollide = true
                            col.Transparency = 1
                            col.CanQuery = false
                            col.CanTouch = false
                            col.Size = Vector3.new(h * 0.07, h * 0.4, h * 0.07)
                            col.CFrame = CFrame.new(pos + Vector3.new(0, h * 0.2, 0))
                            col.Parent = t
                        end
                    end
                end
            end
            gz = gz + g
        end
        gx = gx + g
    end
    print(string.format("[Nature] arvores=%d (gigantes=%d, altas=%d)", placed, giants, talls))
    for k, v in pairs(byBiome) do print("   bioma " .. k .. ": " .. v) end
    for k, v in pairs(rej) do print("   rejeitado por " .. k .. ": " .. v) end

    -- detalhes por bioma
    local flowers, bushes = pool({ "flower" }), pool({ "plant_bush", "bush" })
    local rocksS, rocksL = pool({ "rock_small" }), pool({ "rock_large" })
    local logs, stumps, mush = pool({ "log" }), pool({ "stump" }), pool({ "mushroom" })
    local function spot(list, pos, a, b, useMax, shadow)
        if #list == 0 then return 0 end
        put(pick(list), pos, S.rng:NextNumber(a, b), details, useMax, shadow)
        return 1
    end
    local count, m = 0, 0
    local dg = CFG.DetailGrid
    local dx = S.b.MinX + 40
    while dx <= S.b.MaxX - 40 do
        local dz = S.b.MinZ + 40
        while dz <= S.b.MaxZ - 40 do
            m = m + 1
            if m % 250 == 0 then task.wait() end
            if count < CFG.MaxDetails then
                local x = dx + S.rng:NextNumber(-8, 8)
                local z = dz + S.rng:NextNumber(-8, 8)
                local d = Vector3.new(x - c.X, 0, z - c.Z).Magnitude
                local inVillage = d < R - 8
                local blocked = (inVillage and d < R * 0.7) or (d >= R - 8 and d <= R + 8) or nearGate(x, z, 60)
                if not blocked and S.rng:NextNumber() <= 0.6 then
                    local biome = TG.BiomeAt(x, z)
                    local pos = okGround(x, z, 0.7, biome ~= "Forest")
                    if pos then
                        local r = S.rng:NextNumber()
                        if inVillage then
                            if r < 0.30 and #flowers > 0 then
                                for _ = 1, S.rng:NextInteger(5, 9) do
                                    local fx, fz = x + S.rng:NextNumber(-5, 5), z + S.rng:NextNumber(-5, 5)
                                    local fp = okGround(fx, fz, 0.7)
                                    if fp then count = count + spot(flowers, fp, 1.6, 3, false, false) end
                                end
                            elseif r < 0.55 then count = count + spot(bushes, pos, 4, 8, true, false) end
                        elseif biome == "Forest" then
                            if r < 0.30 and #flowers > 0 then
                                for _ = 1, S.rng:NextInteger(5, 9) do
                                    local fx, fz = x + S.rng:NextNumber(-5, 5), z + S.rng:NextNumber(-5, 5)
                                    local fp = okGround(fx, fz, 0.7)
                                    if fp then count = count + spot(flowers, fp, 1.6, 3, false, false) end
                                end
                            elseif r < 0.55 then count = count + spot(bushes, pos, 4, 8, true, false)
                            elseif r < 0.72 then count = count + spot(rocksS, pos, 2.5, 6, true, false)
                            elseif r < 0.80 and d > R + 80 then count = count + spot(rocksL, pos, 8, 22, true, true)
                            elseif r < 0.88 then count = count + spot(logs, pos, 9, 16, true, false)
                            elseif r < 0.94 then count = count + spot(stumps, pos, 3, 5, true, false)
                            else count = count + spot(mush, pos, 1.5, 4, true, false) end
                        elseif biome == "Swamp" then
                            if r < 0.35 then count = count + spot(mush, pos, 2, 5, true, false)
                            elseif r < 0.55 then count = count + spot(logs, pos, 9, 16, true, false)
                            elseif r < 0.75 then count = count + spot(bushes, pos, 4, 8, true, false)
                            else count = count + spot(stumps, pos, 3, 6, true, false) end
                        elseif biome == "Snow" then
                            if r < 0.6 then count = count + spot(rocksS, pos, 3, 7, true, false)
                            elseif r < 0.8 then count = count + spot(rocksL, pos, 10, 26, true, true)
                            else count = count + spot(stumps, pos, 3, 5, true, false) end
                        elseif biome == "Desert" then
                            if r < 0.5 then count = count + spot(rocksS, pos, 3, 8, true, false)
                            elseif r < 0.8 then count = count + spot(rocksL, pos, 10, 30, true, true)
                            else count = count + spot(logs, pos, 8, 14, true, false) end
                        else -- Volcanic
                            if r < 0.45 then count = count + spot(rocksL, pos, 12, 34, true, true)
                            else count = count + spot(rocksS, pos, 3, 9, true, false) end
                        end
                    end
                end
            end
            dz = dz + dg
        end
        dx = dx + dg
    end
    print("[Nature] detalhes=" .. count)
end

----------------------------------------------------------------- PONTES
local function lantern(parent, pos, range)
    local l = Instance.new("Part")
    l.Shape = Enum.PartType.Ball
    l.Size = Vector3.new(1.6, 1.6, 1.6)
    l.Position = pos
    l.Anchored = true
    l.CanCollide = false
    l.CanQuery = false
    l.Material = Enum.Material.Neon
    l.Color = Color3.fromRGB(255, 200, 110)
    local pl = Instance.new("PointLight")
    pl.Range = range or 26
    pl.Brightness = 1.6
    pl.Color = Color3.fromRGB(255, 185, 95)
    pl.Shadows = false
    pl.Parent = l
    l.Parent = parent
end

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
    A = A - dir * 5
    B = B + dir * 5
    len = len + 10
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
        local nd = nodes[i]
        for k = -1, 1, 2 do
            local post = Instance.new("Part")
            post.Anchored = true
            post.Material = Enum.Material.Wood
            post.Color = dark
            post.Size = Vector3.new(0.8, 3.4, 0.8)
            post.Position = nd + side * k * (W / 2) + Vector3.new(0, 1.5, 0)
            post.Parent = parent
        end
        if i % 2 == 0 then
            local gp = ground(nd.X, nd.Z)
            local bottom = (gp and gp.Y or nd.Y - 10) - 6
            local h = nd.Y - bottom
            local pil = Instance.new("Part")
            pil.Anchored = true
            pil.Material = Enum.Material.Wood
            pil.Color = dark
            pil.Size = Vector3.new(1.6, h, 1.6)
            pil.Position = Vector3.new(nd.X, bottom + h / 2, nd.Z) + side * (W / 2 - 1)
            pil.Parent = parent
            local pil2 = pil:Clone()
            pil2.Position = Vector3.new(nd.X, bottom + h / 2, nd.Z) - side * (W / 2 - 1)
            pil2.Parent = parent
        end
    end
    for _, e in ipairs({ 0, steps }) do
        local nd = nodes[e]
        for k = -1, 1, 2 do
            lantern(parent, nd + side * k * (W / 2) + Vector3.new(0, 4.6, 0), 28)
        end
    end
end

local function riverDist(x, z)
    local best = math.huge
    for _, r in ipairs(MapConfig.Rivers) do
        best = math.min(best, math.abs(x - TG.RiverX(z, r)))
    end
    return best
end

function M.Bridges()
    if not S.root then setup() end
    local f = freshFolder("Bridges")
    local waters, n = {}, 0
    local x = S.b.MinX + 40
    while x <= S.b.MaxX - 40 do
        local z = S.b.MinZ + 40
        while z <= S.b.MaxZ - 40 do
            n = n + 1
            if n % 300 == 0 then task.wait() end
            if riverDist(x, z) < 14 then -- so rios (lagos nao recebem ponte)
                local _, mat = ground(x, z)
                if mat == Enum.Material.Water then table.insert(waters, Vector3.new(x, 0, z)) end
            end
            z = z + 24
        end
        x = x + 24
    end
    print("[Nature] pontos de agua (rios): " .. #waters)
    for i = #waters, 2, -1 do
        local j = S.rng:NextInteger(1, i)
        waters[i], waters[j] = waters[j], waters[i]
    end
    local built, tries = {}, 0
    for _, w in ipairs(waters) do
        if #built < CFG.MaxBridges then
            tries = tries + 1
            if tries % 20 == 0 then task.wait() end
            local tooClose = (Vector3.new(w.X, 0, w.Z) - S.center).Magnitude < S.R + 40
            for _, b in ipairs(built) do if (b - w).Magnitude < 170 then tooClose = true end end
            if not tooClose then
                local best
                for deg = 0, 165, 15 do
                    local dir = Vector3.new(math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
                    local samples = {}
                    for k = -12, 12 do
                        local p, mt, nrm = ground(w.X + dir.X * k * 4, w.Z + dir.Z * k * 4)
                        samples[k] = { p = p, water = (mt == Enum.Material.Water), up = nrm and nrm.Y or 0 }
                    end
                    if samples[0].water then
                        local lo, hi = 0, 0
                        while samples[lo - 1] and samples[lo - 1].water do lo = lo - 1 end
                        while samples[hi + 1] and samples[hi + 1].water do hi = hi + 1 end
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
                    print(string.format("[Nature] ponte em %d, %d (vao %.0f studs)", best.A.X, best.A.Z, best.L))
                end
            end
        end
    end
    if #built == 0 then warn("[Nature] nenhuma ponte possivel; ajuste L (12-70) no codigo") end
end

----------------------------------------------------------------- GERAL
function M.Clear()
    local r = Workspace:FindFirstChild("Nature")
    if r then r:Destroy() end
end

function M.Run(opts)
    if RunService:IsRunning() then warn("[Nature] so roda no Studio em modo Edit.") return end
    setup(opts)
    M.Bridges()
    M.Forest()
    print("[Nature] pronto. Pecas em Workspace/Nature.")
end

return M
