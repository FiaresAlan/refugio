-- Medidas oficiais do mapa REFÚGIO (usadas por todas as partes da Etapa 3). Norte = -Z
local MapConfig = {}

MapConfig.Seed = 7341
MapConfig.Voxel = 4
MapConfig.Bounds = { MinX = -320, MaxX = 360, MinZ = -1000, MaxZ = 320, MinY = -16, MaxY = 144 }
MapConfig.BaseHeight = 8

MapConfig.Village = { Center = Vector2.new(0, 0), Half = 110, Blend = 40 }
MapConfig.Mountain = { Center = Vector2.new(0, -920), Radius = 80, Height = 85 }
MapConfig.River = { X = 180, Amp = 18, Freq = 1 / 70, Width = 10, Bank = 10, Depth = 7, WaterLevel = 4 }
MapConfig.Edge = { Width = 55, Height = 48 }
MapConfig.ClearingCenter = Vector2.new(265, -290)

-- Maciços no meio do mapa
-- Picos e colinas internos: {X, Z, Raio, Altura}. Ficam longe do rio, do spawn e da vila.
MapConfig.Peaks = {
    { -150, -230, 45, 38 }, { 130, -380, 50, 45 }, { -190, -400, 55, 50 },
    { 85, -205, 38, 28 },   { -90, -335, 35, 30 }, { 70, -475, 40, 36 },
    { -200, 150, 50, 22 },  { 235, 175, 45, 20 },  { -60, 260, 55, 16 },
}
MapConfig.PeakTrailClear = 25 -- as trilhas passam por vales, então continuam livres


MapConfig.TrailWidth = 5
MapConfig.Trails = {
    Main = {
        Vector2.new(0, -110), Vector2.new(-14, -170), Vector2.new(18, -240), Vector2.new(-8, -320),
        Vector2.new(14, -400), Vector2.new(-10, -480), Vector2.new(20, -560), Vector2.new(-6, -640),
        Vector2.new(16, -720), Vector2.new(-4, -790), Vector2.new(0, -840),
    },
    Bridge = { Vector2.new(-8, -320), Vector2.new(60, -305), Vector2.new(125, -292), Vector2.new(165, -290) },
}

MapConfig.Spawn = Vector2.new(6, -138)
MapConfig.BridgeZ = -290

MapConfig.Zones = {
    { Name = "Zone_Village",     Center = Vector2.new(0, 0),      Size = Vector2.new(220, 220), Type = "Safe", Oruk = false, Risk = 0, Priority = 10 },
    { Name = "Zone_Meadow",      Center = Vector2.new(20, 215),   Size = Vector2.new(680, 210), Type = "Safe", Oruk = false, Risk = 0, Priority = 2 },
    { Name = "Zone_ForestEdge",  Center = Vector2.new(0, -140),   Size = Vector2.new(140, 60),  Type = "Wild", Oruk = true,  Risk = 1, Priority = 5 },
    { Name = "Zone_Forest",      Center = Vector2.new(20, -485),  Size = Vector2.new(680, 690), Type = "Wild", Oruk = true,  Risk = 2, Priority = 1 },
    { Name = "Zone_Clearing",    Center = Vector2.new(265, -290), Size = Vector2.new(80, 150),  Type = "Wild", Oruk = true,  Risk = 2, Priority = 7, Locked = true },
    { Name = "Zone_CaveReserve", Center = Vector2.new(0, -900),   Size = Vector2.new(260, 140), Type = "Wild", Oruk = true,  Risk = 3, Priority = 6 },
}

MapConfig.Colors = {
    Grass = Color3.fromRGB(108, 152, 70),
    LeafyGrass = Color3.fromRGB(84, 128, 60),
    Mud = Color3.fromRGB(122, 94, 66),
    Ground = Color3.fromRGB(104, 90, 70),
    Rock = Color3.fromRGB(122, 120, 114),
    Sand = Color3.fromRGB(200, 184, 142),
}

return MapConfig
