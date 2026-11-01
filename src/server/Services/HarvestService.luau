-- Coleta das frutas Lumo + cena dos primeiros 30 s (Etapa 4).
-- Validação 100% no servidor: distância, item ativo, mochila e rate-limit.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local Strings = require(ReplicatedStorage.Shared.Strings)
local BackpackService = require(script.Parent.BackpackService)

local HarvestService = {}

local RATE_LIMIT = 0.3
local MAX_DISTANCE = 18
local lastHarvest = setmetatable({}, { __mode = "k" })
local harvestFolder
local orukModel
local firstTaken = false

local function events()
    return ReplicatedStorage:FindFirstChild("Events")
end

local function notice(player, payload)
    local folder = events()
    local ev = folder and folder:FindFirstChild("HarvestNotice")
    if ev then
        ev:FireClient(player, payload)
    end
end

local function groundY(x, z)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { Workspace.Terrain }
    local hit = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
    return hit and hit.Position.Y or 10
end

local function itemName(id)
    local cfg = ItemConfig.Get(id)
    if not cfg then
        return id
    end
    return Strings.For("pt-BR")[cfg.NameKey] or id
end

local function createLumo(id, x, z)
    local cfg = ItemConfig.Get(id)
    assert(cfg, "Lumo desconhecida: " .. tostring(id))
    local pos = Vector3.new(x, groundY(x, z), z)

    local model = Instance.new("Model")
    model.Name = "Lumo_" .. id
    model:SetAttribute("Active", true)
    model:SetAttribute("ItemId", id)

    local stem = Instance.new("Part")
    stem.Name = "Stem"
    stem.Size = Vector3.new(0.55, 1.15, 0.55)
    stem.CFrame = CFrame.new(pos + Vector3.new(0, 0.58, 0))
    stem.Material = Enum.Material.Wood
    stem.Color = Color3.fromRGB(60, 45, 30)
    stem.Anchored = true
    stem.CanCollide = false
    stem.CastShadow = false
    stem.Parent = model

    local fruit = Instance.new("Part")
    fruit.Name = "Fruit"
    fruit.Shape = Enum.PartType.Ball
    fruit.Size = Vector3.new(2, 2, 2)
    fruit.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
    fruit.Material = Enum.Material.Neon
    fruit.Color = cfg.Color
    fruit.Anchored = true
    fruit.CanCollide = false
    fruit.Parent = model
    model.PrimaryPart = fruit
    CollectionService:AddTag(fruit, "LumoGlow")

    local light = Instance.new("PointLight")
    light.Name = "Glow"
    light.Color = cfg.Color
    light.Range = cfg.GlowRange
    light.Brightness = 2
    light.Shadows = false
    light.Parent = fruit

    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "Sparks"
    sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparks.Color = ColorSequence.new(cfg.Color)
    sparks.LightEmission = 1
    sparks.LightInfluence = 0
    sparks.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparks.Lifetime = NumberRange.new(2, 3.5)
    sparks.Rate = 5
    sparks.Speed = NumberRange.new(0.6, 1.4)
    sparks.SpreadAngle = Vector2.new(180, 180)
    sparks.Parent = fruit

    local hum = Instance.new("Sound")
    hum.Name = "HumSound"
    hum.SoundId = "rbxasset://sounds/electronicpingshort.wav"
    hum.PlaybackSpeed = cfg.HumPitch
    hum.Volume = cfg.HumVolume
    hum.Looped = true
    hum.RollOffMode = Enum.RollOffMode.LinearSquare
    hum.RollOffMinDistance = 6
    hum.RollOffMaxDistance = 32
    hum.Parent = fruit
    hum:Play()

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "HarvestPrompt"
    prompt.ActionText = Strings.For("pt-BR").takePrompt
    prompt.ObjectText = itemName(id)
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.12
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt:SetAttribute("ItemId", id)
    prompt.Parent = fruit

    local function setActive(on)
        model:SetAttribute("Active", on)
        prompt.Enabled = on
        fruit.Transparency = if on then 0 else 1
        light.Enabled = on
        sparks.Enabled = on
        if on then
            hum:Resume()
        else
            hum:Pause()
        end
    end

    prompt.Triggered:Connect(function(player)
        if not model:GetAttribute("Active") then
            return
        end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end
        if (root.Position - fruit.Position).Magnitude > MAX_DISTANCE then
            return
        end
        local now = os.clock()
        if lastHarvest[player] and (now - lastHarvest[player]) < RATE_LIMIT then
            return
        end
        lastHarvest[player] = now

        local ok, remaining = BackpackService.AddItem(player, id, 1)
        if not ok or remaining > 0 then
            notice(player, { type = "full" })
            return
        end

        setActive(false)
        notice(player, {
            type = "collected",
            id = id,
            nameKey = cfg.NameKey,
            value = cfg.Value,
            r = cfg.Color.R,
            g = cfg.Color.G,
            b = cfg.Color.B,
        })

        local ping = Instance.new("Sound")
        ping.SoundId = "rbxasset://sounds/action_get_up.mp3"
        ping.Volume = 0.7
        ping.Parent = fruit
        ping:Play()
        task.delay(2, function()
            ping:Destroy()
        end)

        if not firstTaken then
            firstTaken = true
            HarvestService._OnFirstHarvest()
        end

        task.delay(cfg.Cooldown or 45, function()
            if model.Parent then
                setActive(true)
            end
        end)
    end)

    model.Parent = harvestFolder
    return model
end

local function limb(parent, name, size, cf, color, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = false
    p.CastShadow = true
    p.Parent = parent
    return p
end

local function createOrukSilhouette()
    local x, z = 28, -305
    local y = groundY(x, z)
    local look = Vector3.new(4, y + 6, -190)
    local cf = CFrame.lookAt(Vector3.new(x, y + 5.2, z), look)

    local m = Instance.new("Model")
    m.Name = "OrukSilhouette"
    m:SetAttribute("Harmless", true)

    local body = Color3.fromRGB(18, 16, 22)
    local torso = limb(m, "Torso", Vector3.new(4.4, 6.2, 2.6), cf, body, Enum.Material.Slate)
    m.PrimaryPart = torso
    limb(m, "Head", Vector3.new(2.4, 2.2, 2.6), cf * CFrame.new(0, 4.4, -0.4), body, Enum.Material.Slate)
    limb(m, "ArmL", Vector3.new(1.3, 5.4, 1.3), cf * CFrame.new(-2.9, 0.2, -0.8) * CFrame.Angles(0.35, 0, 0.2), body)
    limb(m, "ArmR", Vector3.new(1.3, 5.4, 1.3), cf * CFrame.new(2.9, 0.2, -0.8) * CFrame.Angles(0.35, 0, -0.2), body)
    limb(m, "LegL", Vector3.new(1.5, 5.6, 1.7), cf * CFrame.new(-1.1, -5.4, 0.3), body, Enum.Material.Slate)
    limb(m, "LegR", Vector3.new(1.5, 5.6, 1.7), cf * CFrame.new(1.1, -5.4, 0.3), body, Enum.Material.Slate)

    local function eye(ox)
        local e = limb(m, "Eye", Vector3.new(0.35, 0.28, 0.3), cf * CFrame.new(ox, 4.55, -1.55), Color3.fromRGB(255, 170, 40), Enum.Material.Neon)
        local glow = Instance.new("PointLight")
        glow.Color = Color3.fromRGB(255, 160, 40)
        glow.Range = 10
        glow.Brightness = 1.4
        glow.Shadows = false
        glow.Parent = e
    end
    eye(-0.45)
    eye(0.45)

    local snore = Instance.new("Sound")
    snore.Name = "Snore"
    snore.SoundId = "rbxasset://sounds/electronicpingshort.wav"
    snore.PlaybackSpeed = 0.28
    snore.Volume = 1.1
    snore.Looped = true
    snore.RollOffMode = Enum.RollOffMode.LinearSquare
    snore.RollOffMinDistance = 20
    snore.RollOffMaxDistance = 160
    snore.Parent = torso
    snore:Play()

    m.Parent = harvestFolder
    orukModel = m
end

function HarvestService._OnFirstHarvest()
    local m = orukModel
    if not m or not m.Parent then
        return
    end
    task.spawn(function()
        local elapsed = 0
        while elapsed < 7 and m.Parent do
            local dt = task.wait()
            elapsed += dt
            m:PivotTo(m:GetPivot() * CFrame.new(0, 0.15 * dt, -11 * dt))
        end
        if m.Parent then
            m:Destroy()
        end
        orukModel = nil
    end)
end

function HarvestService.Start()
    harvestFolder = Workspace:FindFirstChild("HarvestNodes")
    if not harvestFolder then
        harvestFolder = Instance.new("Folder")
        harvestFolder.Name = "HarvestNodes"
        harvestFolder.Parent = Workspace
    else
        harvestFolder:ClearAllChildren()
    end
    firstTaken = false

    -- 1ª Lumo: ~18 studs à frente do Spawn_ForestEdge (4, -190), olhando para -Z
    createLumo("LumoGreen", 4, -208)
    createLumo("LumoGreen", 18, -240)
    createLumo("LumoGold", -8, -318)

    createOrukSilhouette()
    print("[HarvestService] cena dos 30 s: Lumo + silhueta do Oruk")
end

return HarvestService
