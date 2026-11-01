-- HUD da mochila de expedição (8 slots). Não é o inventário da casa.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
gui.Name = "BackpackHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -16)
bar.Size = UDim2.fromOffset(8 * 52 + 16, 70)
bar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
bar.BackgroundTransparency = 0.25
bar.Parent = gui
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 12)

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.Parent = bar

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = bar

local slots = {}
for i = 1, ItemConfig.BACKPACK_SLOTS do
    local cell = Instance.new("Frame")
    cell.Name = "Slot" .. i
    cell.Size = UDim2.fromOffset(46, 54)
    cell.BackgroundColor3 = Color3.fromRGB(12, 16, 18)
    cell.BackgroundTransparency = 0.15
    cell.Parent = bar
    Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 8)

    local swatch = Instance.new("Frame")
    swatch.Name = "Swatch"
    swatch.AnchorPoint = Vector2.new(0.5, 0)
    swatch.Position = UDim2.new(0.5, 0, 0, 6)
    swatch.Size = UDim2.fromOffset(22, 22)
    swatch.BackgroundColor3 = Color3.fromRGB(40, 48, 44)
    swatch.Parent = cell
    Instance.new("UICorner", swatch).CornerRadius = UDim.new(1, 0)

    local count = Instance.new("TextLabel")
    count.Name = "Count"
    count.BackgroundTransparency = 1
    count.Position = UDim2.new(0, 0, 1, -18)
    count.Size = UDim2.new(1, 0, 0, 16)
    count.Font = Enum.Font.GothamBold
    count.TextSize = 12
    count.TextColor3 = Color3.new(1, 1, 1)
    count.Text = ""
    count.Parent = cell

    slots[i] = { cell = cell, swatch = swatch, count = count }
end

local function paint(payload)
    local data = payload or { maxSlots = ItemConfig.BACKPACK_SLOTS, slots = {} }
    for i = 1, ItemConfig.BACKPACK_SLOTS do
        local ui = slots[i]
        local slot = data.slots and data.slots[i]
        if slot and slot.id then
            local item = ItemConfig.Get(slot.id)
            ui.swatch.BackgroundColor3 = item and item.Color or Color3.new(1, 1, 1)
            ui.count.Text = tostring(slot.count or 1)
            ui.cell.BackgroundTransparency = 0.05
        else
            ui.swatch.BackgroundColor3 = Color3.fromRGB(40, 48, 44)
            ui.count.Text = ""
            ui.cell.BackgroundTransparency = 0.15
        end
    end
end

paint(nil)

task.spawn(function()
    local events = ReplicatedStorage:WaitForChild("Events")
    local sync = events:WaitForChild("BackpackSync")
    sync.OnClientEvent:Connect(paint)
end)

-- Título discreto acima da barra
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 1)
title.Position = UDim2.new(0.5, 0, 1, -88)
title.Size = UDim2.fromOffset(160, 18)
title.Font = Enum.Font.Gotham
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(220, 230, 222)
title.TextTransparency = 0.25
title.Text = S.backpackTitle
title.Parent = gui
