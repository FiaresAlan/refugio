-- Definição dos itens coletáveis. Valores oficiais do plano:
-- Lumo Verde 40 · Dourada 150 · Prismática 600 · madeira 1 · cogumelo 5
local ItemConfig = {}

ItemConfig.BACKPACK_SLOTS = 8

ItemConfig.Lumos = {
    LumoGreen = {
        Id = "LumoGreen",
        NameKey = "lumoGreen",
        Value = 40,
        Color = Color3.fromRGB(95, 255, 115),
        GlowRange = 16,
        HumPitch = 1.0,
        HumVolume = 0.5,
        Rarity = "Common",
        Cooldown = 45,
        MaxStack = 10,
    },
    LumoGold = {
        Id = "LumoGold",
        NameKey = "lumoGold",
        Value = 150,
        Color = Color3.fromRGB(255, 215, 60),
        GlowRange = 22,
        HumPitch = 1.35,
        HumVolume = 0.75,
        Rarity = "Rare",
        Cooldown = 90,
        MaxStack = 5,
    },
    LumoPrismatic = {
        Id = "LumoPrismatic",
        NameKey = "lumoPrismatic",
        Value = 600,
        Color = Color3.fromRGB(115, 235, 255),
        GlowRange = 30,
        HumPitch = 1.7,
        HumVolume = 1.0,
        Rarity = "Legendary",
        Cooldown = 180,
        MaxStack = 2,
    },
}

ItemConfig.Resources = {
    Wood = {
        Id = "Wood",
        NameKey = "wood",
        Value = 1,
        Color = Color3.fromRGB(140, 95, 60),
        Rarity = "Common",
        MaxStack = 30,
    },
    Mushroom = {
        Id = "Mushroom",
        NameKey = "mushroom",
        Value = 5,
        Color = Color3.fromRGB(220, 80, 80),
        Rarity = "Uncommon",
        MaxStack = 15,
    },
}

function ItemConfig.Get(id)
    return ItemConfig.Lumos[id] or ItemConfig.Resources[id]
end

return ItemConfig
