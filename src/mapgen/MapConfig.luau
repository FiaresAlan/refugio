-- Medidas oficiais do mapa REFUGIO (usadas por todas as partes da Etapa 3). Norte = -Z
-- v3: mapa 2400x2400 studs, biomas (Neve, Deserto, Vulcao, Pantano), 3 rios, 5 lagos, ~80 picos, 3 trilhas.
local MapConfig = {}
MapConfig.Version = 3

MapConfig.Seed = 7341
MapConfig.Voxel = 4
MapConfig.Bounds = { MinX = -1200, MaxX = 1200, MinZ = -1800, MaxZ = 600, MinY = -16, MaxY = 220 }
MapConfig.BaseHeight = 8

MapConfig.Village = { Center = Vector2.new(0, 0), Radius = 170, Blend = 60 } -- chao plano ate 170 (muralha em 150)
MapConfig.Mountain = { Center = Vector2.new(0, -1500), Radius = 170, Height = 120 } -- montanha da Caverna do Oruk
MapConfig.Cave = { Entrance = Vector2.new(0, -1330) }

MapConfig.River = { X = 180, Amp = 18, Freq = 1 / 70, Width = 10, Bank = 10, Depth = 7, WaterLevel = 4 }
MapConfig.Rivers = {
    MapConfig.River,
    { X = -430, Amp = 34, Freq = 1 / 95, Phase = 2.1, Width = 9, Bank = 12, Depth = 6, WaterLevel = 4 },
    { X = 620, Amp = 28, Freq = 1 / 110, Phase = 4.0, Width = 8, Bank = 12, Depth = 6, WaterLevel = 4 },
}
-- Lagos: { X, Z, Raio, Profundidade }
MapConfig.Lakes = {
    { -330, -520, 95, 7 }, { 440, -820, 80, 6 }, { -620, 330, 120, 5 }, { 40, 420, 70, 5 }, { 880, 130, 90, 6 },
}
MapConfig.Edge = { Width = 110, Height = 85 }
MapConfig.ClearingCenter = Vector2.new(265, -290)
MapConfig.Volcano = { X = 820, Z = -1320, R = 210, H = 140, Crater = 0.2 }

-- Biomas distantes (a vila e a trilha principal ficam sempre na floresta/campo)
MapConfig.Biomes = {
    { Name = "Snow",     X = -760, Z = -1250, R = 560 },
    { Name = "Desert",   X = 860,  Z = -330,  R = 520 },
    { Name = "Volcanic", X = 820,  Z = -1320, R = 420 },
    { Name = "Swamp",    X = -760, Z = 230,   R = 470 },
}
-- Floresta Antiga (arvores gigantes): { X, Z, Raio }
MapConfig.AncientForest = { { -200, -760, 360 }, { 300, -1050, 300 } }

MapConfig.PeakTrailClear = 25 -- as trilhas passam por vales, entao continuam livres
MapConfig.TrailWidth = 5
MapConfig.Trails = {
    Main = {
        Vector2.new(0, -152), Vector2.new(-14, -195), Vector2.new(18, -240), Vector2.new(-8, -320),
        Vector2.new(14, -400), Vector2.new(-10, -480), Vector2.new(20, -560), Vector2.new(-6, -640),
        Vector2.new(16, -720), Vector2.new(-4, -790), Vector2.new(12, -870), Vector2.new(-8, -960),
        Vector2.new(18, -1050), Vector2.new(-10, -1140), Vector2.new(14, -1230), Vector2.new(0, -1330),
    },
    Bridge = { Vector2.new(-8, -320), Vector2.new(60, -305), Vector2.new(125, -292), Vector2.new(165, -290) },
    Lake = { Vector2.new(14, -400), Vector2.new(-60, -430), Vector2.new(-150, -480), Vector2.new(-235, -520) },
    Ruins = { Vector2.new(-6, -640), Vector2.new(-90, -690), Vector2.new(-180, -760), Vector2.new(-270, -850) },
}

MapConfig.Spawn = Vector2.new(4, -190)
MapConfig.BridgeZ = -290

-- Macicos: { X, Z, Raio, Altura }. Os 9 primeiros sao manuais; o resto e gerado (mesma seed = mesmo mapa).
MapConfig.Peaks = {
    { -150, -230, 45, 38 }, { 130, -380, 50, 45 }, { -190, -400, 55, 50 },
    { 85, -205, 38, 28 },   { -90, -335, 35, 30 }, { 70, -475, 40, 36 },
    { -200, 150, 50, 22 },  { 235, 175, 45, 20 },  { -60, 260, 55, 16 },
}

local function segd(px, pz, a, b)
    local abx, abz = b.X - a.X, b.Y - a.Y
    local t = ((px - a.X) * abx + (pz - a.Y) * abz) / (abx * abx + abz * abz)
    t = math.clamp(t, 0, 1)
    local dx, dz = px - (a.X + abx * t), pz - (a.Y + abz * t)
    return math.sqrt(dx * dx + dz * dz)
end

do
    local rng = Random.new(MapConfig.Seed + 5)
    local B, list = MapConfig.Bounds, MapConfig.Peaks
    local vc, sp, mt, cl, vo = MapConfig.Village.Center, MapConfig.Spawn, MapConfig.Mountain.Center, MapConfig.ClearingCenter, MapConfig.Volcano
    local target, tries = #list + 70, 0
    while #list < target and tries < 3000 do
        tries = tries + 1
        local x = rng:NextNumber(B.MinX + 140, B.MaxX - 140)
        local z = rng:NextNumber(B.MinZ + 140, B.MaxZ - 140)
        local roll = rng:NextNumber()
        local r, h
        if roll < 0.55 then
            r, h = rng:NextNumber(30, 55), rng:NextNumber(14, 32)
        elseif roll < 0.88 then
            r, h = rng:NextNumber(60, 95), rng:NextNumber(35, 65)
        else
            r, h = rng:NextNumber(110, 160), rng:NextNumber(70, 110)
        end
        local ok = true
        local function dist(ax, az) return math.sqrt((x - ax) ^ 2 + (z - az) ^ 2) end
        if dist(vc.X, vc.Y) < 380 + r * 0.5 then ok = false end
        if ok and dist(sp.X, sp.Y) < 230 + r * 0.5 then ok = false end
        if ok and dist(mt.X, mt.Y) < 270 + r * 0.5 then ok = false end
        if ok and dist(cl.X, cl.Y) < 160 + r then ok = false end
        if ok and dist(vo.X, vo.Z) < vo.R + r then ok = false end
        if ok then
            for _, lk in ipairs(MapConfig.Lakes) do
                if dist(lk[1], lk[2]) < lk[3] * 1.6 + r * 0.6 then ok = false break end
            end
        end
        if ok then
            for _, rv in ipairs(MapConfig.Rivers) do
                local rx = rv.X + rv.Amp * math.sin(z * rv.Freq + (rv.Phase or 0))
                if math.abs(x - rx) < r * 0.9 + 30 then ok = false break end
            end
        end
        if ok then
            for _, pts in pairs(MapConfig.Trails) do
                for i = 1, #pts - 1 do
                    if segd(x, z, pts[i], pts[i + 1]) < r * 0.8 + 25 then ok = false break end
                end
                if not ok then break end
            end
        end
        if ok then
            for _, pk in ipairs(list) do
                if dist(pk[1], pk[2]) < (r + pk[3]) * 0.55 then ok = false break end
            end
        end
        if ok then table.insert(list, { math.floor(x), math.floor(z), math.floor(r), math.floor(h) }) end
    end
end

MapConfig.Zones = {
    { Name = "Zone_Village",     Center = Vector2.new(0, 0),      Size = Vector2.new(340, 340),   Type = "Safe", Oruk = false, Risk = 0, Priority = 10 },
    { Name = "Zone_Meadow",      Center = Vector2.new(0, 230),    Size = Vector2.new(2400, 740),  Type = "Safe", Oruk = false, Risk = 0, Priority = 2 },
    { Name = "Zone_ForestEdge",  Center = Vector2.new(0, -200),   Size = Vector2.new(140, 80),    Type = "Wild", Oruk = true,  Risk = 1, Priority = 5 },
    { Name = "Zone_Forest",      Center = Vector2.new(0, -970),   Size = Vector2.new(2400, 1660), Type = "Wild", Oruk = true,  Risk = 2, Priority = 1 },
    { Name = "Zone_Clearing",    Center = Vector2.new(265, -290), Size = Vector2.new(80, 150),    Type = "Wild", Oruk = true,  Risk = 2, Priority = 7, Locked = true },
    { Name = "Zone_CaveReserve", Center = Vector2.new(0, -1480),  Size = Vector2.new(400, 300),   Type = "Wild", Oruk = true,  Risk = 3, Priority = 6 },
    -- biomas distantes: reservados para futuros monstros/ilhas (Oruk = false)
    { Name = "Zone_Snow",        Center = Vector2.new(-760, -1250), Size = Vector2.new(1000, 1000), Type = "Wild", Oruk = false, Risk = 3, Priority = 3 },
    { Name = "Zone_Desert",      Center = Vector2.new(860, -330),   Size = Vector2.new(940, 940),   Type = "Wild", Oruk = false, Risk = 3, Priority = 3 },
    { Name = "Zone_Volcanic",    Center = Vector2.new(820, -1320),  Size = Vector2.new(760, 760),   Type = "Wild", Oruk = false, Risk = 4, Priority = 3 },
    { Name = "Zone_Swamp",       Center = Vector2.new(-760, 230),   Size = Vector2.new(860, 860),   Type = "Wild", Oruk = false, Risk = 2, Priority = 3 },
}

MapConfig.Colors = {
    Grass = Color3.fromRGB(108, 152, 70),
    LeafyGrass = Color3.fromRGB(84, 128, 60),
    Mud = Color3.fromRGB(122, 94, 66),
    Ground = Color3.fromRGB(104, 90, 70),
    Rock = Color3.fromRGB(122, 120, 114),
    Sand = Color3.fromRGB(200, 184, 142),
    Snow = Color3.fromRGB(238, 244, 252),
    Sandstone = Color3.fromRGB(190, 140, 92),
    Basalt = Color3.fromRGB(58, 52, 56),
    Slate = Color3.fromRGB(92, 98, 110),
    CrackedLava = Color3.fromRGB(230, 96, 38),
}

return MapConfig
