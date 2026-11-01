-- PlayerData: carrega, guarda e salva o progresso de cada jogador.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local STORE = DataStoreService:GetDataStore("PlayerData_v1") -- "gaveta" no banco do Roblox
local AUTOSAVE_SECONDS = 120

-- Perfil padrão de quem entra pela primeira vez
local DEFAULT = {
    version = 1,      -- versão do formato (para migrar dados no futuro)
    coins = 0,
    visits = 0,
    firstJoin = 0,
    lastJoin = 0,
    stamps = 0,       -- Calendário de Carimbos
    findings = {},    -- Livro de Achados
}

local PlayerData = {}
local profiles = {} -- [Player] = tabela de dados em memória

local function deepCopy(t)
    local copy = {}
    for k, v in t do
        copy[k] = if type(v) == "table" then deepCopy(v) else v
    end
    return copy
end

-- Completa campos que não existiam quando o jogador salvou da última vez
local function reconcile(data)
    for k, v in DEFAULT do
        if data[k] == nil then
            data[k] = if type(v) == "table" then deepCopy(v) else v
        end
    end
    return data
end

-- Tenta até 3 vezes, esperando 2s, 4s e 8s entre as tentativas
local function withRetry(fn)
    for attempt = 1, 3 do
        local ok, result = pcall(fn)
        if ok then return true, result end
        warn(("[PlayerData] tentativa %d falhou: %s"):format(attempt, tostring(result)))
        task.wait(2 ^ attempt)
    end
    return false, nil
end

local function keyFor(player)
    return "u_" .. player.UserId
end

local function createLeaderstats(player, data)
    local stats = Instance.new("Folder")
    stats.Name = "leaderstats" -- nome especial: o Roblox mostra no placar
    local coins = Instance.new("IntValue")
    coins.Name = "Moedas"
    coins.Value = data.coins
    coins.Parent = stats
    local visits = Instance.new("IntValue")
    visits.Name = "Visitas"
    visits.Value = data.visits
    visits.Parent = stats
    stats.Parent = player
end

local function load(player)
    local ok, saved = withRetry(function()
        return STORE:GetAsync(keyFor(player))
    end)
    if not ok then
        -- Falhou o carregamento: tira o jogador do servidor em vez de jogar com perfil vazio.
        -- Se ele ficasse, o salvamento sobrescreveria o progresso real com zeros.
        player:Kick("Não conseguimos carregar seu progresso. Entre de novo. / Couldn't load your progress, please rejoin.")
        return
    end
    if not player.Parent then return end -- saiu enquanto carregava

    local data = reconcile(saved or deepCopy(DEFAULT))
    local now = os.time()
    if data.firstJoin == 0 then data.firstJoin = now end
    data.lastJoin = now
    data.visits += 1

    profiles[player] = data
    createLeaderstats(player, data)
end

local function save(player)
    local data = profiles[player]
    if not data then return end -- nunca salva quem não carregou direito
    withRetry(function()
        return STORE:UpdateAsync(keyFor(player), function()
            return data
        end)
    end)
end

function PlayerData.Get(player)
    return profiles[player]
end

function PlayerData.Start()
    Players.PlayerAdded:Connect(load)
    for _, p in Players:GetPlayers() do task.spawn(load, p) end -- quem já entrou antes do script

    Players.PlayerRemoving:Connect(function(player)
        save(player)
        profiles[player] = nil -- libera memória
    end)

    -- Servidor desligando: salva todos em paralelo (o Roblox dá até 30s)
    game:BindToClose(function()
        local pending = 0
        for player in profiles do
            pending += 1
            task.spawn(function()
                save(player)
                pending -= 1
            end)
        end
        while pending > 0 do task.wait() end
    end)

    -- Salvamento automático: se o servidor cair, perde-se no máximo 2 minutos
    task.spawn(function()
        while true do
            task.wait(AUTOSAVE_SECONDS)
            for player in profiles do task.spawn(save, player) end
        end
    end)
end

return PlayerData
