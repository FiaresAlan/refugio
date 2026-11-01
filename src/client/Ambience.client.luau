-- Ambience.client.luau  (StarterPlayerScripts)
-- Vagalumes ao entardecer/noite, polen de dia. Segue o jogador (leve, so no cliente).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local function phase()
	local p = Workspace:GetAttribute("Phase") or ReplicatedStorage:GetAttribute("Phase") or Lighting:GetAttribute("Phase")
	if p ~= nil then
		local s = string.lower(tostring(p))
		if s:find("dusk") or s:find("entard") then return "dusk" end
		if s:find("night") or s:find("noit") then return "night" end
		return "day"
	end
	local h = Lighting.ClockTime
	if h >= 19.5 or h < 5 then return "night" elseif h >= 17 then return "dusk" end
	return "day"
end

local anchor = Instance.new("Part")
anchor.Name = "AmbienceAnchor"
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.Transparency = 1
anchor.Size = Vector3.new(140, 24, 140)
anchor.Parent = Workspace

local function emitter(color, size, life, speed)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, size), NumberSequenceKeypoint.new(0.5, size * 0.4), NumberSequenceKeypoint.new(0.8, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(life * 0.6, life)
	e.Speed = NumberRange.new(speed * 0.3, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.EmissionDirection = Enum.NormalId.Top
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 0
	e.Parent = anchor
	return e
end

local fireflies = emitter(Color3.fromRGB(190, 255, 90), 0.55, 8, 1.6)
local pollen = emitter(Color3.fromRGB(255, 240, 170), 0.25, 9, 1)

local rateF = { day = 0, dusk = 20, night = 42 }
local rateP = { day = 10, dusk = 3, night = 0 }

RunService.Heartbeat:Connect(function()
	local cam = Workspace.CurrentCamera
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local pos = root and root.Position or (cam and cam.CFrame.Position)
	if pos then anchor.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) end
end)

task.spawn(function()
	while true do
		local p = phase()
		fireflies.Rate = rateF[p]
		pollen.Rate = rateP[p]
		task.wait(2)
	end
end)
