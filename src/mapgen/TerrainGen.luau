local C = require(script.Parent.MapConfig)
local TerrainGen = {}
TerrainGen.Version = 3

local B, V, M = C.Bounds, C.Voxel, Enum.Material
local SEED = C.Seed * 0.001
local WL = C.River.WaterLevel

local function smooth(t)
    t = math.clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function villageDist(x, z)
    local v = C.Village
    return math.max(math.sqrt((x - v.Center.X) ^ 2 + (z - v.Center.Y) ^ 2) - v.Radius, 0)
end

function TerrainGen.RiverX(z, r)
    r = r or C.River
    return r.X + r.Amp * math.sin(z * r.Freq + (r.Phase or 0))
end

local function nearestRiver(x, z)
    local best, br = math.huge, C.River
    for _, r in ipairs(C.Rivers) do
        local d = math.abs(x - TerrainGen.RiverX(z, r))
        if d < best then best, br = d, r end
    end
    return best, br
end

-- trilhas pre-calculadas em numeros (sem criar Vector2 a cada ponto do mapa)
local SEGS, TMINX, TMAXX, TMINZ, TMAXZ = {}, math.huge, -math.huge, math.huge, -math.huge
for _, pts in pairs(C.Trails) do
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        local dx, dz = b.X - a.X, b.Y - a.Y
        table.insert(SEGS, { a.X, a.Y, dx, dz, dx * dx + dz * dz })
        TMINX = math.min(TMINX, a.X, b.X) TMAXX = math.max(TMAXX, a.X, b.X)
        TMINZ = math.min(TMINZ, a.Y, b.Y) TMAXZ = math.max(TMAXZ, a.Y, b.Y)
    end
end

function TerrainGen.TrailDistance(x, z)
    if x < TMINX - 80 or x > TMAXX + 80 or z < TMINZ - 80 or z > TMAXZ + 80 then return 999 end
    local best = math.huge
    for _, s in ipairs(SEGS) do
        local t = math.clamp(((x - s[1]) * s[3] + (z - s[2]) * s[4]) / s[5], 0, 1)
        local ex, ez = x - (s[1] + s[3] * t), z - (s[2] + s[4] * t)
        local d = math.sqrt(ex * ex + ez * ez)
        if d < best then best = d end
    end
    return best
end

-- Biomas: pesos 0..1 (tabela reutilizada: leia os valores logo apos chamar)
local W = { top = "", topw = 0 }
local lastX, lastZ = nil, nil
local function biome(x, z)
    if x == lastX and z == lastZ then return W end
    lastX, lastZ = x, z
    local warp = math.noise(x / 260, z / 260, SEED + 70) * 90
    W.top, W.topw = "", 0
    for _, b in ipairs(C.Biomes) do
        local dx, dz = x - b.X, z - b.Z
        local d = math.sqrt(dx * dx + dz * dz) + warp
        local w = smooth((1 - d / b.R) * 1.6)
        W[b.Name] = w
        if w > W.topw then W.top, W.topw = b.Name, w end
    end
    return W
end

function TerrainGen.BiomeAt(x, z)
    local w = biome(x, z)
    if w.topw > 0.5 then return w.top end
    return "Forest"
end

function TerrainGen.InAncient(x, z)
    for _, a in ipairs(C.AncientForest) do
        local dx, dz = x - a[1], z - a[2]
        if dx * dx + dz * dz < a[3] * a[3] then return true end
    end
    return false
end

-- picos: altura ajustada ao bioma (neve mais alto, deserto/pantano mais baixo)
local PEAKMULT = { Snow = 1.5, Volcanic = 1.15, Desert = 0.45, Swamp = 0.35 }
local PEAKS = {}
for _, pk in ipairs(C.Peaks) do
    local w = biome(pk[1], pk[2])
    local m = 1
    if w.topw > 0.4 then m = PEAKMULT[w.top] or 1 end
    table.insert(PEAKS, { pk[1], pk[2], pk[3], pk[4] * m })
end
lastX, lastZ = nil, nil

function TerrainGen.Height(x, z)
    local wild = smooth(villageDist(x, z) / C.Village.Blend)
    local w = biome(x, z)
    local wSw, wSn, wDe, wVo = w.Swamp or 0, w.Snow or 0, w.Desert or 0, w.Volcanic or 0

    local n = math.noise(x / 130, z / 130, SEED) * 22
        + math.noise(x / 45, z / 45, SEED + 10) * 6
        + math.noise(x / 14, z / 14, SEED + 20) * 1.2
    n = n * (1 - 0.8 * wSw) * (1 - 0.35 * wDe)
    local h = C.BaseHeight + wild * (4 + n)

    -- relevo extra: cordilheiras ao norte + relevo de cada bioma
    local extra = 0
    local north = smooth((-z - 130) / 140)
    local ridge = math.max(1 - math.abs(math.noise(x / 150, z / 150, SEED + 50)) * 2, 0)
    extra = extra + north * 34 * ridge * ridge
    if wSn > 0 then
        local r2 = math.max(1 - math.abs(math.noise(x / 170, z / 170, SEED + 80)) * 2, 0)
        extra = extra + wSn * (14 + 78 * r2 * r2 + math.noise(x / 40, z / 40, SEED + 81) * 6)
    end
    if wDe > 0 then -- mesas (plato com paredes) e dunas
        local t = math.noise(x / 150, z / 150, SEED + 90)
        extra = extra + wDe * (36 * smooth((t - 0.02) / 0.1) - 4 + math.noise(x / 38, z / 38, SEED + 91) * 3)
    end
    if wVo > 0 then
        extra = extra + wVo * (10 + math.abs(math.noise(x / 55, z / 55, SEED + 92)) * 40)
    end

    -- suaviza perto de trilha, rio e Clareira (para continuar andavel)
    local td = TerrainGen.TrailDistance(x, z)
    local dr = nearestRiver(x, z)
    local cdx, cdz = x - C.ClearingCenter.X, z - C.ClearingCenter.Y
    local f = 0.3 + 0.7 * smooth((td - 4) / 24)
    f = f * (0.4 + 0.6 * smooth((dr - 20) / 40))
    f = f * (0.2 + 0.8 * smooth((math.sqrt(cdx * cdx + cdz * cdz) - 70) / 40))
    h = h + extra * f * wild

    local e = math.min(x - B.MinX, B.MaxX - x, z - B.MinZ, B.MaxZ - z)
    h = h + C.Edge.Height * smooth(1 - e / C.Edge.Width) * (0.8 + 0.2 * math.noise(x / 30, z / 30, SEED + 30))

    local m = C.Mountain
    local dm = math.sqrt((x - m.Center.X) ^ 2 + (z - m.Center.Y) ^ 2)
    h = h + m.Height * math.exp(-(dm / m.Radius) ^ 2)

    -- picos (somados UMA vez; livres perto da trilha)
    local clear = smooth(td / C.PeakTrailClear)
    for _, pk in ipairs(PEAKS) do
        local dx = x - pk[1]
        if math.abs(dx) < pk[3] * 2.6 then
            local dz = z - pk[2]
            if math.abs(dz) < pk[3] * 2.6 then
                local d = math.sqrt(dx * dx + dz * dz)
                local shape = 0.8 + 0.4 * math.noise(x / 22, z / 22, SEED + 50)
                h = h + pk[4] * shape * math.exp(-(d / pk[3]) ^ 2) * wild * clear
            end
        end
    end

    local vo = C.Volcano
    if vo then
        local d = math.sqrt((x - vo.X) ^ 2 + (z - vo.Z) ^ 2)
        if d < vo.R then
            local cr = vo.Crater * vo.R
            local cone
            if d < cr then
                cone = vo.H * (1 - vo.Crater) ^ 1.5 - 30 * (1 - d / cr)
            else
                cone = vo.H * (1 - d / vo.R) ^ 1.5
            end
            h = h + cone * (0.92 + 0.08 * math.noise(x / 20, z / 20, SEED + 99))
        end
    end

    if td < C.TrailWidth then
        h = h - 0.8 * (1 - td / C.TrailWidth)
    end

    if wSw > 0 then h = lerp(h, WL + 2.4, 0.85 * wSw) end -- pantano: baixo e plano
    h = math.max(h, WL + 1.5)
    if wSw > 0.25 then -- pocas do pantano
        local pn = math.noise(x / 36, z / 36, SEED + 95)
        if pn > 0.22 then h = lerp(h, WL - 2.5, smooth((pn - 0.22) / 0.12) * wSw) end
    end

    for _, lk in ipairs(C.Lakes) do
        local lx = x - lk[1]
        if math.abs(lx) < lk[3] * 1.6 then
            local lz = z - lk[2]
            local d = math.sqrt(lx * lx + lz * lz)
            if d < lk[3] * 1.6 then
                h = lerp(WL - lk[4], h, smooth((d - lk[3] * 0.7) / (lk[3] * 0.9)))
            end
        end
    end

    for _, R in ipairs(C.Rivers) do
        local d = math.abs(x - TerrainGen.RiverX(z, R))
        if d < R.Width + R.Bank then
            h = lerp(R.WaterLevel - R.Depth, h, smooth((d - R.Width * 0.5) / (R.Width * 0.5 + R.Bank)))
        end
    end
    return math.min(h, B.MaxY - 8)
end

local function surfaceMaterial(x, z, h, slope)
    local dr, rv = nearestRiver(x, z)
    if dr < rv.Width + 3 and h < rv.WaterLevel + 2 then return M.Sand end
    if TerrainGen.TrailDistance(x, z) < C.TrailWidth then return M.Mud end
    local w = biome(x, z)
    local top, tw = w.top, w.topw
    if tw > 0.5 then
        if top == "Snow" then
            if slope > 1.1 then return M.Rock end
            return M.Snow
        elseif top == "Desert" then
            if slope > 0.9 then return M.Sandstone end
            return M.Sand
        elseif top == "Volcanic" then
            if slope > 1.4 then return M.Slate end
            if math.noise(x / 18, z / 18, SEED + 97) > 0.45 then return M.CrackedLava end
            return M.Basalt
        elseif top == "Swamp" then
            if math.noise(x / 30, z / 30, SEED + 96) > 0.3 then return M.Mud end
            return M.LeafyGrass
        end
    end
    if slope > 1 or h > C.BaseHeight + 55 then return M.Rock end
    if villageDist(x, z) <= 0 then return M.Grass end
    if math.noise(x / 25, z / 25, SEED + 40) > 0.15 then return M.LeafyGrass end
    return M.Grass
end

function TerrainGen.Build()
    local terrain = workspace.Terrain
    local nx, nz, ny = (B.MaxX - B.MinX) // V, (B.MaxZ - B.MinZ) // V, (B.MaxY - B.MinY) // V
    local H = {}
    for i = 0, nx + 1 do
        local row = {}
        for k = 0, nz + 1 do
            row[k] = TerrainGen.Height(B.MinX + (i - 0.5) * V, B.MinZ + (k - 0.5) * V)
        end
        H[i] = row
        if i % 10 == 0 then task.wait() end
    end
    print("[MapGen] Alturas calculadas (" .. nx .. "x" .. nz .. " colunas)")

    local CH, water = 32, WL
    local done, total = 0, math.ceil(nx / CH) * math.ceil(nz / CH)
    for i0 = 1, nx, CH do
        for k0 = 1, nz, CH do
            local cx, cz = math.min(CH, nx - i0 + 1), math.min(CH, nz - k0 + 1)
            local mats, occs = table.create(cx), table.create(cx)
            for a = 1, cx do
                local i = i0 + a - 1
                local mA, oA = table.create(ny), table.create(ny)
                for j = 1, ny do
                    mA[j], oA[j] = table.create(cz), table.create(cz)
                end
                for b = 1, cz do
                    local k = k0 + b - 1
                    local h = H[i][k]
                    local slope = (math.abs(H[i + 1][k] - H[i - 1][k]) + math.abs(H[i][k + 1] - H[i][k - 1])) / (2 * V)
                    local top = surfaceMaterial(B.MinX + (i - 0.5) * V, B.MinZ + (k - 0.5) * V, h, slope)
                    for j = 1, ny do
                        local y0 = B.MinY + (j - 1) * V
                        local depth = h - y0
                        local occ = math.clamp(depth / V, 0, 1)
                        local mat = M.Air
                        if occ > 0 then
                            if depth <= V * 2 then mat = top elseif depth > 16 then mat = M.Rock else mat = M.Ground end
                        elseif y0 < water then
                            mat, occ = M.Water, 1
                        end
                        mA[j][b], oA[j][b] = mat, occ
                    end
                end
                mats[a], occs[a] = mA, oA
            end
            local min = Vector3.new(B.MinX + (i0 - 1) * V, B.MinY, B.MinZ + (k0 - 1) * V)
            terrain:WriteVoxels(Region3.new(min, min + Vector3.new(cx * V, ny * V, cz * V)), V, mats, occs)
            done = done + 1
            if done % 40 == 0 then
                print(("[MapGen] Terreno %d/%d"):format(done, total))
                task.wait()
            end
        end
    end
end

return TerrainGen
