-- Cycle: marca o início do ciclo e avisa o servidor quando a fase muda
local DayNight = require(game:GetService("ReplicatedStorage").Shared.DayNight)

local Cycle = {}
Cycle.Changed = Instance.new("BindableEvent") -- o monstro vai "escutar" isto depois
local current = nil

function Cycle.Get()
    return current
end

function Cycle.Start()
    local start = workspace:GetServerTimeNow()
    workspace:SetAttribute("CycleStart", start)

    task.spawn(function()
        while true do
            local state = DayNight.GetState(start)
            if state.phase ~= current then
                current = state.phase
                workspace:SetAttribute("Phase", current)
                Cycle.Changed:Fire(current)
                print("[Cycle] fase:", current)
            end
            task.wait(0.5)
        end
    end)
end

return Cycle
