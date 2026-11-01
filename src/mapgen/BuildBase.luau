local Lighting = game:GetService("Lighting")
local C = require(script.Parent.MapConfig)
local TerrainGen = require(script.Parent.TerrainGen)

local BuildBase = {}

local function ensure(parent, className, name)
    local obj = parent:FindFirstChild(name)
    if obj and obj:IsA(className) then return obj end
    obj = Instance.new(className)
    obj.Name = name
    obj.Parent = parent
    return obj
end

local function effect(className)
    return Lighting:FindFirstChildOfClass(className) or Instance.new(className, Lighting)
end

local function invisiblePart(parent, name, size, cf)
    local old = parent:FindFirstChild(name)
    if old then old:Destroy() end
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
    p.Transparency = 1
    p.Parent = parent
    return p
end

local function setupLighting()
    pcall(function() Lighting.Technology = Enum.Technology.Future end)
    Lighting.GlobalShadows = true
    Lighting.Brightness = 2.2
    Lighting.EnvironmentDiffuseScale = 1
    Lighting.EnvironmentSpecularScale = 0.6
    Lighting.OutdoorAmbient = Color3.fromRGB(118, 116, 128)

    local atm = effect("Atmosphere")
    atm.Density, atm.Offset, atm.Glare, atm.Haze = 0.32, 0.25, 0.3, 1.6
    atm.Color, atm.Decay = Color3.fromRGB(199, 178, 166), Color3.fromRGB(106, 112, 125)

    local bloom = effect("BloomEffect")
    bloom.Intensity, bloom.Size, bloom.Threshold = 0.6, 28, 1.6

    local cc = effect("ColorCorrectionEffect")
    cc.Saturation, cc.Contrast, cc.Brightness = 0.12, 0.08, 0

    effect("SunRaysEffect").Intensity = 0.06
end

local function setupTerrainLook()
    local t = workspace.Terrain
    for name, color in C.Colors do
        t:SetMaterialColor(Enum.Material[name], color)
    end
    t.WaterColor = Color3.fromRGB(54, 120, 110)
    t.WaterTransparency, t.WaterReflectance = 0.55, 0.35
    t.WaterWaveSize, t.WaterWaveSpeed = 0.08, 6
    pcall(function() t.Decoration = true end)
end

local function buildZones(folder)
    for _, z in C.Zones do
        local p = invisiblePart(folder, z.Name, Vector3.new(z.Size.X, 240, z.Size.Y), CFrame.new(z.Center.X, 100, z.Center.Y))
        p:SetAttribute("ZoneType", z.Type)
        p:SetAttribute("OrukAllowed", z.Oruk)
        p:SetAttribute("Risk", z.Risk)
        p:SetAttribute("Priority", z.Priority)
        p:SetAttribute("Locked", z.Locked == true)
    end
end

local function buildMarkers(folder)
    local function mark(name, x, z, y)
        invisiblePart(folder, name, Vector3.new(2, 2, 2), CFrame.new(x, y or TerrainGen.Height(x, z) + 1, z))
    end
    mark("Marker_Plaza", 0, 0)
    mark("Marker_VillageGate", 0, -150)
    mark("Marker_CaveEntrance", 0, -840)
    mark("Marker_BridgeSite", TerrainGen.RiverX(C.BridgeZ), C.BridgeZ, C.River.WaterLevel + 3)
end

local function buildSpawns(folder)
    local function spawn(name, x, z, enabled)
        local old = folder:FindFirstChild(name)
        if old then old:Destroy() end
        local s = Instance.new("SpawnLocation")
        s.Name, s.Size = name, Vector3.new(6, 1, 6)
        s.CFrame = CFrame.new(x, TerrainGen.Height(x, z) + 0.5, z)
        s.Anchored, s.CanCollide, s.CanQuery, s.CastShadow = true, false, false, false
        s.Transparency, s.Neutral, s.Duration, s.Enabled = 1, true, 0, enabled
        s.Parent = folder
    end
    spawn("Spawn_ForestEdge", C.Spawn.X, C.Spawn.Y, true)
    spawn("Spawn_Plaza", 0, 14, false)
end

function BuildBase.Run(opts)
    opts = opts or {}
    local t0 = os.clock()
    local map = ensure(workspace, "Folder", "Map")
    for _, n in { "Village", "Forest", "Cave", "Decor", "Markers" } do
        ensure(map, "Folder", n)
    end
    local zones, spawns = ensure(workspace, "Folder", "Zones"), ensure(workspace, "Folder", "Spawns")
    ensure(workspace, "Folder", "Plots")
    ensure(workspace, "Folder", "Stalls")

    setupLighting()
    setupTerrainLook()
    if opts.terrain ~= false then
        TerrainGen.Build()
    end
    buildZones(zones)
    buildMarkers(map.Markers)
    buildSpawns(spawns)

    pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("MapGen Base") end)
    print(("[MapGen] Base pronta em %.1fs"):format(os.clock() - t0))
end

return BuildBase
