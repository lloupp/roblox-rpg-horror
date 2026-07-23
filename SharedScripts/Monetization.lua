-- ========== DARK SURVIVORS: Monetization Config =========
-- Shared ModuleScript: Game Pass IDs, Dev Product IDs, and purchase logic.
-- Phase 4: scaffolding for monetization. Replace placeholder IDs with real
-- ones from the Roblox Creator Dashboard after publishing the game.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Monetization = {}

-- ========== GAME PASS IDS =========
-- Replace 0 with real GamePass IDs from Roblox Creator Dashboard.
-- Game Passes are one-time purchases that grant permanent perks.
Monetization.GamePasses = {
    StarterPack = {
        id = 0,  -- TODO: replace with real GamePass ID
        name = "Starter Pack",
        description = "Comece com uma Machete, 2 Bandages e uma Water Bottle extra.",
        price = 50,  -- Robux
    },
    DoubleCarry = {
        id = 0,
        name = "Double Carry Weight",
        description = "Dobra a capacidade de peso do inventário permanentemente.",
        price = 100,
    },
    VIPRespawn = {
        id = 0,
        name = "VIP Respawn",
        description = "Respawn em 2 segundos (em vez de 5) + mantém itens ao morrer.",
        price = 200,
    },
    ExtraSlots = {
        id = 0,
        name = "Extra Inventory Slots",
        description = "+4 slots de inventário permanentemente.",
        price = 150,
    },
}

-- ========== DEVELOPER PRODUCT IDS =========
-- Dev Products are purchasable multiple times (consumables).
Monetization.DevProducts = {
    Revive = {
        id = 0,
        name = "Revive Potion",
        description = "Revive no local onde morreu, mantendo todos os itens.",
        price = 25,
    },
    SanityPotion = {
        id = 0,
        name = "Sanity Potion",
        description = "Restaura sanidade para 100 instantaneamente.",
        price = 15,
    },
    RandomLoot = {
        id = 0,
        name = "Random Loot Crate",
        description = "Receba 3 itens aleatórios (materiais ou consumíveis).",
        price = 30,
    },
}

-- ========== HELPER: Has Game Pass =========
function Monetization.HasGamePass(player, passKey)
    local config = Monetization.GamePasses[passKey]
    if not config or config.id == 0 then return false end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, config.id)
    end)
    return ok and owns
end

-- ========== HELPER: Prompt Purchase =========
function Monetization.PromptGamePass(player, passKey)
    local config = Monetization.GamePasses[passKey]
    if not config or config.id == 0 then
        warn("[Monetization] GamePass key '" .. tostring(passKey) .. "' has no ID set.")
        return
    end
    MarketplaceService:PromptGamePassPurchase(player, config.id)
end

function Monetization.PromptDevProduct(player, productKey)
    local config = Monetization.DevProducts[productKey]
    if not config or config.id == 0 then
        warn("[Monetization] DevProduct key '" .. tostring(productKey) .. "' has no ID set.")
        return
    end
    MarketplaceService:PromptProductPurchase(player, config.id)
end

-- ========== PROCESS PURCHASES =========
-- Called when a player buys a Dev Product. Return Grant or NotGranted.
function Monetization.ProcessReceipt(receiptInfo)
    -- This function would be assigned to MarketplaceService.ProcessReceipt
    -- in the server Script. Left as scaffolding — implement when real IDs exist.
    warn("[Monetization] ProcessReceipt called but no real Dev Product IDs set yet.")
    return Enum.ProductPurchaseDecision.NotGranted
end

return Monetization
