-- HUD: relógio da fase + céu mudando suavemente
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayNight = require(Shared:WaitForChild("DayNight"))
local Strings = require(Shared:WaitForChild("Strings")).For(Players.LocalPlayer.LocaleId)

-- espera o servidor marcar o início do ciclo
while workspace:GetAttribute("CycleStart") == nil do
    workspace:GetAttributeChangedSignal("CycleStart"):Wait()
end
local start = workspace:GetAttribute("CycleStart")

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
    local left = math.max(0, math.floor(s.secondsLeft))
    label.Text = ("%s  %d:%02d"):format(Strings["phase" .. s.phase], left // 60, left % 60)
end)
