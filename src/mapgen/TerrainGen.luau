local C = require(script.Parent.MapConfig)
local TerrainGen = {}

local B, V, M = C.Bounds, C.Voxel, Enum.Material
local SEED = C.Seed * 0.001

local function smooth(t)
    t = math.clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function segDist(p, a, b)
    local ab = b - a
    local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
    return (p - (a + ab * t)).Magnitude
end

local function villageDist(x, z)
    local v = C.Village
    local dx = math.max(math.abs(x - v.Center.X) - v.Half, 0)
    local dz = math.max(math.abs(z - v.Center.Y) - v.Half, 0)
    return math.sqrt(dx * dx + dz * dz)
end

function TerrainGen.RiverX(z)
    return C.River.X + C.River.Amp * math.sin(z * C.River.Freq)
end

function TerrainGen.TrailDistance(x, z)
    local p, best = Vector2.new(x, z), math.huge
    for _, pts in C.Trails do
        for i = 1, #pts - 1 do
            best = math.min(best, segDist(p, pts[i], pts[i + 1]))
        end
    end
    return best
end

function TerrainGen.Height(x, z)
    local p = Vector2.new(x, z)
    local wild = smooth(villageDist(x, z) / C.Village.Blend)
    local n = math.noise(x / 130, z / 130, SEED) * 22
        + math.noise(x / 45, z / 45, SEED + 10) * 6
        + math.noise(x / 14, z / 14, SEED + 20) * 1.2
    local h = C.BaseHeight + wild * (4 + n)

    -- relevo extra: maciços no meio + cordilheiras que crescem para o norte
    local extra = 0
    for _, pk in C.Peaks do
        local d = math.sqrt((x - pk[1]) ^ 2 + (z - pk[2]) ^ 2)
        extra += pk[4] * math.exp(-(d / pk[3]) ^ 2)
            * (0.85 + 0.3 * math.noise(x / 22, z / 22, SEED + 60))
    end
    local north = smooth((-z - 130) / 140)
    local ridge = math.max(1 - math.abs(math.noise(x / 120, z / 120, SEED + 50)) * 2, 0)
    extra += north * 26 * ridge * ridge

    -- suaviza perto de trilha, rio e Clareira (para continuar andável)
    local R = C.River
    local td = TerrainGen.TrailDistance(x, z)
    local f = 0.3 + 0.7 * smooth((td - 4) / 24)
    f *= 0.4 + 0.6 * smooth((math.abs(x - TerrainGen.RiverX(z)) - 20) / 40)
    f *= 0.2 + 0.8 * smooth(((p - C.ClearingCenter).Magnitude - 70) / 40)
    h += extra * f * wild

    local e = math.min(x - B.MinX, B.MaxX - x, z - B.MinZ, B.MaxZ - z)
    h += C.Edge.Height * smooth(1 - e / C.Edge.Width) * (0.8 + 0.2 * math.noise(x / 30, z / 30, SEED + 30))

    local m = C.Mountain
    local dm = (p - m.Center).Magnitude
    h += m.Height * math.exp(-(dm / m.Radius) ^ 2)

    local clear = smooth(td / C.PeakTrailClear)
    for _, p in C.Peaks do
        local d = math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2)
        local shape = 0.8 + 0.4 * math.noise(x / 22, z / 22, SEED + 50)
        h += p[4] * shape * math.exp(-(d / p[3]) ^ 2) * wild * clear
    end
    if td < C.TrailWidth then
        h -= 0.8 * (1 - td / C.TrailWidth)
    end

    h = math.max(h, R.WaterLevel + 1.5)
    local dr = math.abs(x - TerrainGen.RiverX(z))
    if dr < R.Width + R.Bank then
        h = lerp(R.WaterLevel - R.Depth, h, smooth((dr - R.Width * 0.5) / (R.Width * 0.5 + R.Bank)))
    end
    return h
end

local function surfaceMaterial(x, z, h, slope)
    if math.abs(x - TerrainGen.RiverX(z)) < C.River.Width + 3 and h < C.River.WaterLevel + 2 then
        return M.Sand
    end
    if TerrainGen.TrailDistance(x, z) < C.TrailWidth then return M.Mud end
    if slope > 1 or h > C.BaseHeight + 55 then return M.Rock end
    if villageDist(x, z) <= 0 then return M.Grass end
    return if math.noise(x / 25, z / 25, SEED + 40) > 0.15 then M.LeafyGrass else M.Grass
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
    end

    local CH, water = 32, C.River.WaterLevel
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
                            mat = if depth <= V * 2 then top elseif depth > 16 then M.Rock else M.Ground
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
            done += 1
            if done % 6 == 0 then
                print(("[MapGen] Terreno %d/%d"):format(done, total))
                task.wait()
            end
        end
    end
end

return TerrainGen
