-- Escolhe o pacote de textos pelo idioma do jogador
local packs = {
    pt = require(script["pt-BR"]),
    en = require(script["en-US"]),
}

local Strings = {}

function Strings.For(localeId)
    local lang = string.sub(string.lower(localeId or ""), 1, 2)
    return packs[lang] or packs.en
end

return Strings