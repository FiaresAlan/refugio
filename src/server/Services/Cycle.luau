-- Cycle: marca o início do ciclo e avisa o servidor quando a fase muda
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local DayNight = require(game:GetService("ReplicatedStorage").Shared.DayNight)

local Cycle = {}
Cycle.Changed = Instance.new("BindableEvent") -- o monstro vai "escutar" isto depois
local current = nil

function Cycle.Get()
    return current
end

-- Liga/desliga luzes e emissores da vila conforme a fase
-- VillageLight: PointLight das lâmpadas | VillageNight: emissores fixos das canteiras
-- (o Ambience.client tem seus próprios emissores móveis, independentes)
local function updateAmbience(phase)
    local on = phase == "Dusk" or phase == "Night"
    for _, part in CollectionService:GetTagged("VillageLight") do
        local light = part:FindFirstChildWhichIsA("PointLight")
        if light then light.Enabled = on end
    end
    for _, part in CollectionService:GetTagged("VillageNight") do
        local emitter = part:FindFirstChildWhichIsA("ParticleEmitter")
        if emitter then emitter.Enabled = on end
    end
end

function Cycle.Start()
    local start = workspace:GetServerTimeNow()
    workspace:SetAttribute("CycleStart", start)

    task.spawn(function()
        while true do
            local state = DayNight.GetState(start)
            Lighting.ClockTime = state.clock
            if state.phase ~= current then
                current = state.phase
                workspace:SetAttribute("Phase", current)
                Cycle.Changed:Fire(current)
                updateAmbience(current)
                print("[Cycle] fase:", current)
            end
            task.wait(0.5)
        end
    end)
end

return Cycle
