-- Pulso da Lumo, toasts de coleta e textos do prompt no idioma do jogador.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemConfig = require(Shared:WaitForChild("ItemConfig"))
local Strings = require(Shared:WaitForChild("Strings"))

local locale = player.LocaleId
if locale == "" then
    for _ = 1, 20 do
        task.wait(0.1)
        locale = player.LocaleId
        if locale ~= "" then
            break
        end
    end
end
local S = Strings.For(locale)

local gui = Instance.new("ScreenGui")
gui.Name = "HarvestFx"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local pulse = Instance.new("Frame")
pulse.Name = "LumoPulse"
pulse.BackgroundColor3 = Color3.fromRGB(95, 255, 115)
pulse.BackgroundTransparency = 1
pulse.BorderSizePixel = 0
pulse.Size = UDim2.fromScale(1, 1)
pulse.Parent = gui

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -96)
toast.Size = UDim2.fromOffset(280, 36)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
toast.BackgroundTransparency = 0.25
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.Visible = false
toast.Parent = gui
Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)

local toastUntil = 0

local function showToast(text, color)
    toast.Text = text
    toast.TextColor3 = color or Color3.new(1, 1, 1)
    toast.Visible = true
    toastUntil = os.clock() + 2.2
end

ProximityPromptService.PromptShown:Connect(function(prompt)
    if prompt.Name ~= "HarvestPrompt" then
        return
    end
    local id = prompt:GetAttribute("ItemId")
    local cfg = id and ItemConfig.Get(id)
    prompt.ActionText = S.takePrompt
    if cfg then
        prompt.ObjectText = S[cfg.NameKey] or prompt.ObjectText
    end
end)

task.spawn(function()
    local events = ReplicatedStorage:WaitForChild("Events")
    local notice = events:WaitForChild("HarvestNotice")
    notice.OnClientEvent:Connect(function(payload)
        if type(payload) ~= "table" then
            return
        end
        if payload.type == "full" then
            showToast(S.backpackFull, Color3.fromRGB(255, 180, 90))
            return
        end
        if payload.type == "collected" then
            local name = S[payload.nameKey] or payload.id
            showToast(S.collected .. " · " .. name, Color3.new(payload.r or 1, payload.g or 1, payload.b or 1))
        end
    end)
end)

RunService.RenderStepped:Connect(function()
    if toast.Visible and os.clock() > toastUntil then
        toast.Visible = false
    end

    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        pulse.BackgroundTransparency = 1
        return
    end

    local best, bestRange, bestColor = math.huge, 16, Color3.fromRGB(95, 255, 115)
    for _, fruit in CollectionService:GetTagged("LumoGlow") do
        if fruit:IsA("BasePart") and fruit.Transparency < 0.5 then
            local dist = (fruit.Position - root.Position).Magnitude
            local light = fruit:FindFirstChild("Glow")
            local range = (light and light:IsA("PointLight") and light.Range) or 16
            if dist < range and dist < best then
                best = dist
                bestRange = range
                bestColor = fruit.Color
            end
        end
    end

    if best == math.huge then
        pulse.BackgroundTransparency = 1
        return
    end

    local near = 1 - math.clamp(best / bestRange, 0, 1)
    local wave = 0.5 + 0.5 * math.sin(os.clock() * 6)
    pulse.BackgroundColor3 = bestColor
    pulse.BackgroundTransparency = 1 - near * 0.12 * wave
end)
