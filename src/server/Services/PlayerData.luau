-- PlayerData: carrega, guarda e salva o progresso de cada jogador.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Strings = require(game:GetService("ReplicatedStorage").Shared.Strings)

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
local saved = setmetatable({}, { __mode = "k" }) -- [Player] = true (já salvo no encerramento)

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
        player:Kick(Strings.For(player.LocaleId).loadFailed)
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

-- Salva uma única vez por jogador no encerramento.
-- Evita double-save: PlayerRemoving e BindToClose podem disparar juntos.
local function saveOnce(player)
    if saved[player] then return end
    saved[player] = true
    save(player)
end

function PlayerData.Get(player)
    return profiles[player]
end

-- ===== API de moedas =====
-- Sempre atualiza a memória (profiles) e o placar (leaderstats) juntos.
-- Assim o save() grava o valor correto e o jogador vê o saldo atualizado.

local function syncLeaderstats(player, data)
    local stats = player:FindFirstChild("leaderstats")
    if stats then
        local coins = stats:FindFirstChild("Moedas")
        if coins and coins:IsA("IntValue") then
            coins.Value = data.coins
        end
    end
end

-- Adiciona (ou remove, se negativo) moedas. Retorna o novo saldo.
function PlayerData.AddCoins(player, amount)
    local data = profiles[player]
    if not data then return 0 end
    data.coins = math.max(0, data.coins + math.floor(amount))
    syncLeaderstats(player, data)
    return data.coins
end

-- Tenta gastar moedas. Retorna true se conseguiu, false se não tinha.
function PlayerData.SpendCoins(player, amount)
    local data = profiles[player]
    if not data or data.coins < amount then return false end
    data.coins -= math.floor(amount)
    syncLeaderstats(player, data)
    return true
end

function PlayerData.GetCoins(player)
    local data = profiles[player]
    return data and data.coins or 0
end

-- Define o saldo diretamente (ex: admin, correção).
function PlayerData.SetCoins(player, amount)
    local data = profiles[player]
    if not data then return 0 end
    data.coins = math.max(0, math.floor(amount))
    syncLeaderstats(player, data)
    return data.coins
end

function PlayerData.Start()
    Players.PlayerAdded:Connect(load)
    for _, p in Players:GetPlayers() do task.spawn(load, p) end -- quem já entrou antes do script

    Players.PlayerRemoving:Connect(function(player)
        saveOnce(player)
        profiles[player] = nil -- libera memória
        -- não limpa saved[player]: previne BindToClose de salvar de novo
    end)

    -- Servidor desligando: salva todos em paralelo (o Roblox dá até 30s)
    game:BindToClose(function()
        local pending = 0
        local snapshot = {}
        for player in profiles do table.insert(snapshot, player) end
        for _, player in snapshot do
            pending += 1
            task.spawn(function()
                saveOnce(player)
                pending -= 1
            end)
        end
        while pending > 0 do task.wait() end
    end)

    -- Salvamento automático: se o servidor cair, perde-se no máximo 2 minutos
    task.spawn(function()
        while true do
            task.wait(AUTOSAVE_SECONDS)
            local snapshot = {}
            for player in profiles do table.insert(snapshot, player) end
            for _, player in snapshot do task.spawn(save, player) end
        end
    end)
end

return PlayerData
