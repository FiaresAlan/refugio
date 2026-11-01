-- Mochila de expedição: temporária, separada do inventário guardado (Etapa 4).
-- Se o Oruk pegar o jogador (Etapa 7), só esta mochila cai.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)

local BackpackService = {}

local backpacks = {} -- [Player] = { maxSlots = number, slots = { [index] = { id, count } } }

local function getEvent(name, className)
    local folder = ReplicatedStorage:FindFirstChild("Events")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "Events"
        folder.Parent = ReplicatedStorage
    end
    local ev = folder:FindFirstChild(name)
    if not ev then
        ev = Instance.new(className)
        ev.Name = name
        ev.Parent = folder
    end
    return ev
end

local syncEvent = getEvent("BackpackSync", "RemoteEvent")
getEvent("HarvestNotice", "RemoteEvent")

local function snapshot(bp)
    local slots = {}
    for i = 1, bp.maxSlots do
        local slot = bp.slots[i]
        if slot then
            slots[i] = { id = slot.id, count = slot.count }
        end
    end
    return { maxSlots = bp.maxSlots, slots = slots }
end

local function syncToClient(player)
    local bp = backpacks[player]
    if bp then
        syncEvent:FireClient(player, snapshot(bp))
    end
end

function BackpackService.Get(player)
    return backpacks[player]
end

-- Coloca itens. Retorna (colocouAlgumaCoisa, quantidadeQueSobrou).
function BackpackService.AddItem(player, itemId, count)
    count = math.floor(count or 1)
    if count <= 0 then
        return false, 0
    end
    local bp = backpacks[player]
    if not bp then
        return false, count
    end
    local item = ItemConfig.Get(itemId)
    if not item then
        return false, count
    end

    local remaining = count
    local maxStack = item.MaxStack or 10

    for idx = 1, bp.maxSlots do
        local slot = bp.slots[idx]
        if slot and slot.id == itemId and slot.count < maxStack then
            local add = math.min(maxStack - slot.count, remaining)
            slot.count += add
            remaining -= add
            if remaining <= 0 then
                break
            end
        end
    end

    if remaining > 0 then
        for idx = 1, bp.maxSlots do
            if not bp.slots[idx] then
                local add = math.min(maxStack, remaining)
                bp.slots[idx] = { id = itemId, count = add }
                remaining -= add
                if remaining <= 0 then
                    break
                end
            end
        end
    end

    local added = count - remaining
    if added > 0 then
        syncToClient(player)
    end
    return added > 0, remaining
end

function BackpackService.RemoveItem(player, slotIndex, count)
    local bp = backpacks[player]
    if not bp then
        return false
    end
    local slot = bp.slots[slotIndex]
    if not slot then
        return false
    end
    count = count or slot.count
    if count >= slot.count then
        bp.slots[slotIndex] = nil
    else
        slot.count -= count
    end
    syncToClient(player)
    return true
end

function BackpackService.Clear(player)
    local bp = backpacks[player]
    if not bp then
        return {}
    end
    local dropped = bp.slots
    bp.slots = {}
    syncToClient(player)
    return dropped
end

function BackpackService.GetTotalValue(player)
    local bp = backpacks[player]
    if not bp then
        return 0
    end
    local total = 0
    for _, slot in bp.slots do
        local item = ItemConfig.Get(slot.id)
        if item then
            total += item.Value * slot.count
        end
    end
    return total
end

function BackpackService.Start()
    local function initPlayer(player)
        backpacks[player] = {
            maxSlots = ItemConfig.BACKPACK_SLOTS,
            slots = {},
        }
        syncToClient(player)
    end

    Players.PlayerAdded:Connect(initPlayer)
    for _, p in Players:GetPlayers() do
        initPlayer(p)
    end

    Players.PlayerRemoving:Connect(function(player)
        backpacks[player] = nil
    end)

    print("[BackpackService] mochila de expedição pronta")
end

return BackpackService
