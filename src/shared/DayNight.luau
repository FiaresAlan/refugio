local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)

local PHASES = {
    { name = "Day",   len = Config.DAY,   from = 6,  to = 17 },
    { name = "Dusk",  len = Config.DUSK,  from = 17, to = 19 },
    { name = "Night", len = Config.NIGHT, from = 19, to = 30 }, -- 30 = 6h do dia seguinte
}
local TOTAL = Config.DAY + Config.DUSK + Config.NIGHT
local SPEED = if RunService:IsStudio() then Config.STUDIO_SPEED else 1

local DayNight = {}

-- Retorna a fase atual, a hora do relógio (0-24) e os segundos reais até a próxima fase
function DayNight.GetState(start)
    local t = ((workspace:GetServerTimeNow() - start) * SPEED) % TOTAL
    for i, p in PHASES do
        if t < p.len or i == #PHASES then
            local a = math.clamp(t / p.len, 0, 1)
            return {
                phase = p.name,
                clock = (p.from + (p.to - p.from) * a) % 24,
                secondsLeft = (p.len - t) / SPEED,
            }
        end
        t -= p.len
    end
end

return DayNight
