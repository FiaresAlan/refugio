-- HUD: relógio da fase + céu mudando suavemente
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayNight = require(Shared:WaitForChild("DayNight"))

-- LocaleId pode vir vazio no primeiro frame; espera sincronizar (máx 2s)
local player = Players.LocalPlayer
local locale = player.LocaleId
if locale == "" then
    for _ = 1, 20 do
        task.wait(0.1)
        locale = player.LocaleId
        if locale ~= "" then break end
    end
end
local Strings = require(Shared:WaitForChild("Strings")).For(locale)

-- espera o servidor marcar o início do ciclo (sem race: lê, se faltar espera uma vez)
local start = workspace:GetAttribute("CycleStart")
if not start then
    workspace:GetAttributeChangedSignal("CycleStart"):Wait()
    start = workspace:GetAttribute("CycleStart")
end

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 10)
label.Size = UDim2.fromOffset(220, 40)
label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
label.BackgroundTransparency = 0.3
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.Parent = gui
Instance.new("UICorner", label).CornerRadius = UDim.new(0, 10)

RunService.RenderStepped:Connect(function()
    local s = DayNight.GetState(start)
    Lighting.ClockTime = s.clock
    local left = math.max(1, math.floor(s.secondsLeft))
    label.Text = ("%s  %d:%02d"):format(Strings["phase" .. s.phase], left // 60, left % 60)
end)
