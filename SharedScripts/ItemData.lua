-- ========== DARK SURVIVORS: Item Data Module ==========
-- Shared ModuleScript: all items, categories, and crafting recipes

local ItemData = {}

-- ========== ITEMS DATABASE ==========
ItemData.Items = {
    -- WEAPONS
    KitchenKnife = {
        name = "Kitchen Knife",
        category = "Weapons",
        weight = 1,
        maxStack = 1,
        description = "Rusty but sharp. Better than nothing.",
        damage = 15, range = 3, attackSpeed = 0.4, weaponType = "melee",
    },
    FireAxe = {
        name = "Fire Axe",
        category = "Weapons",
        weight = 3,
        maxStack = 1,
        description = "Heavy axe. Slow but devastating.",
        damage = 25, range = 4, attackSpeed = 0.8, weaponType = "melee",
    },
    Machete = {
        name = "Machete",
        category = "Weapons",
        weight = 2,
        maxStack = 1,
        description = "Jungle blade. Good all-rounder.",
        damage = 20, range = 3.5, attackSpeed = 0.5, weaponType = "melee",
    },
    Crowbar = {
        name = "Crowbar",
        category = "Weapons",
        weight = 2.5,
        maxStack = 1,
        description = "Pry things open. Also cracks skulls.",
        damage = 12, range = 3, attackSpeed = 0.5, weaponType = "melee",
        isTool = true,
    },
    Shotgun = {
        name = "Shotgun",
        category = "Weapons",
        weight = 4,
        maxStack = 1,
        description = "Spread damage. Powerful but loud.",
        damage = 50, range = 30, attackSpeed = 1.5, weaponType = "ranged",
        ammo = 8, maxAmmo = 8,
    },

    -- FOOD
    CannedBeans = {
        name = "Canned Beans",
        category = "Food",
        weight = 0.5,
        maxStack = 10,
        description = "Not great, but filling.",
        hungerRestore = 25,
    },
    Jerky = {
        name = "Jerky",
        category = "Food",
        weight = 0.3,
        maxStack = 15,
        description = "Dried meat. Light and lasts forever.",
        hungerRestore = 15,
    },
    Bread = {
        name = "Bread",
        category = "Food",
        weight = 0.4,
        maxStack = 10,
        description = "Stale but edible.",
        hungerRestore = 20,
    },
    Mushrooms = {
        name = "Mushrooms",
        category = "Food",
        weight = 0.1,
        maxStack = 20,
        description = "Something feels off about these...",
        hungerRestore = 10, sanityChange = -5,
    },
    RawMeat = {
        name = "Raw Meat",
        category = "Food",
        weight = 0.5,
        maxStack = 5,
        description = "Needs cooking. Risky to eat raw.",
        hungerRestore = 5, needsCooking = true,
    },
    CookedMeat = {
        name = "Cooked Meat",
        category = "Food",
        weight = 0.5,
        maxStack = 10,
        description = "Properly cooked. Safe and nourishing.",
        hungerRestore = 30,
    },

    -- DRINKS
    WaterBottle = {
        name = "Water Bottle",
        category = "Drinks",
        weight = 0.5,
        maxStack = 5,
        description = "Clean water. Precious commodity.",
        thirstRestore = 30,
    },
    EnergyDrink = {
        name = "Energy Drink",
        category = "Drinks",
        weight = 0.3,
        maxStack = 5,
        description = "Buzz of energy. Stamina boost.",
        thirstRestore = 20, staminaBonus = 50,
    },
    DirtyWater = {
        name = "Dirty Water",
        category = "Drinks",
        weight = 0.5,
        maxStack = 5,
        description = "Looks contaminated. Drink at your own risk.",
        thirstRestore = 10, healthChange = -5,
    },

    -- MEDICAL
    Bandage = {
        name = "Bandage",
        category = "Medical",
        weight = 0.2,
        maxStack = 10,
        description = "Stops bleeding. Minor heal.",
        healthRestore = 15,
    },
    MedKit = {
        name = "Med Kit",
        category = "Medical",
        weight = 1,
        maxStack = 3,
        description = "Full medical kit. Major heal.",
        healthRestore = 40,
    },
    Antidote = {
        name = "Antidote",
        category = "Medical",
        weight = 0.3,
        maxStack = 5,
        description = "Cures poison and venom.",
        curesPoison = true,
    },
    Adrenaline = {
        name = "Adrenaline",
        category = "Medical",
        weight = 0.2,
        maxStack = 5,
        description = "Emergency boost. Stamina + speed for 10 sec.",
        staminaBonus = 50, speedBoost = true, boostDuration = 10,
    },

    -- MATERIALS
    Wood = {
        name = "Wood",
        category = "Materials",
        weight = 1,
        maxStack = 20,
        description = "Basic building material.",
    },
    Metal = {
        name = "Metal",
        category = "Materials",
        weight = 2,
        maxStack = 15,
        description = "Scrap metal. Strong but heavy.",
    },
    Cloth = {
        name = "Cloth",
        category = "Materials",
        weight = 0.3,
        maxStack = 20,
        description = "Fabric scraps. Versatile.",
    },
    Wire = {
        name = "Wire",
        category = "Materials",
        weight = 0.2,
        maxStack = 15,
        description = "Copper wire. Conductive.",
    },
    Chemical = {
        name = "Chemical",
        category = "Materials",
        weight = 0.5,
        maxStack = 10,
        description = "Dangerous substance. Handle with care.",
    },
    DuctTape = {
        name = "Duct Tape",
        category = "Materials",
        weight = 0.1,
        maxStack = 20,
        description = "Fixes everything.",
    },
    Glass = {
        name = "Glass",
        category = "Materials",
        weight = 0.5,
        maxStack = 10,
        description = "Glass shards. Sharp.",
    },
    Rope = {
        name = "Rope",
        category = "Materials",
        weight = 0.5,
        maxStack = 10,
        description = "Strong rope. Binding and climbing.",
    },

    -- TOOLS
    Flashlight = {
        name = "Flashlight",
        category = "Tools",
        weight = 0.5,
        maxStack = 1,
        description = "Light in the darkness. Essential.",
        providesLight = true,
    },
    Lockpick = {
        name = "Lockpick",
        category = "Tools",
        weight = 0.1,
        maxStack = 3,
        description = "Opens locked doors and containers.",
        opensLocks = true,
    },
    Compass = {
        name = "Compass",
        category = "Tools",
        weight = 0.1,
        maxStack = 1,
        description = "Always points north. Never get lost.",
        showsDirection = true,
    },
    Map = {
        name = "Map",
        category = "Tools",
        weight = 0.1,
        maxStack = 1,
        description = "Area map. Reveals locations.",
        revealsMap = true,
    },
    Radio = {
        name = "Radio",
        category = "Tools",
        weight = 0.8,
        maxStack = 1,
        description = "Static... wait, was that a voice?",
        canCallRescue = true,
    },
    Lighter = {
        name = "Lighter",
        category = "Tools",
        weight = 0.1,
        maxStack = 1,
        description = "Small flame. Cooking and light.",
        providesFire = true,
    },

    -- ARMOR
    LeatherVest = {
        name = "Leather Vest",
        category = "Armor",
        weight = 3,
        maxStack = 1,
        description = "Basic protection. Def +10.",
        defense = 10,
    },
    RiotHelmet = {
        name = "Riot Helmet",
        category = "Armor",
        weight = 2,
        maxStack = 1,
        description = "Head protection. Def +5.",
        defense = 5,
    },
    GasMask = {
        name = "Gas Mask",
        category = "Armor",
        weight = 1,
        maxStack = 1,
        description = "Filters toxic air. Poison immunity.",
        defense = 2, poisonImmunity = true,
    },

    -- SPECIAL
    Journal = {
        name = "Journal",
        category = "Special",
        weight = 0.2,
        maxStack = 1,
        description = "Someone's diary. Contains lore clues.",
        containsLore = true,
    },
    MysteryBox = {
        name = "Mystery Box",
        category = "Special",
        weight = 1,
        maxStack = 1,
        description = "???. Open at your own risk.",
        randomLoot = true,
    },

    -- CRAFTED ITEMS
    Torch = {
        name = "Torch",
        category = "Tools",
        weight = 0.8,
        maxStack = 3,
        description = "Burning torch. Wider light than flashlight.",
        providesLight = true, lightRadius = 15,
    },
    SpikeTrap = {
        name = "Spike Trap",
        category = "Weapons",
        weight = 5,
        maxStack = 3,
        description = "Place on ground. Damages enemies who walk over it.",
        trapDamage = 30, isTrap = true,
    },
    Molotov = {
        name = "Molotov",
        category = "Weapons",
        weight = 1,
        maxStack = 5,
        description = "Fire bomb. Area damage over time.",
        areaDamage = 20, duration = 5, isThrowable = true,
    },
    Shield = {
        name = "Shield",
        category = "Armor",
        weight = 5,
        maxStack = 1,
        description = "Improvised shield. Great for blocking.",
        defense = 20, blockBonus = 0.2,
    },
    PoisonBomb = {
        name = "Poison Bomb",
        category = "Weapons",
        weight = 1.5,
        maxStack = 3,
        description = "Toxic explosion. Area poison.",
        areaDamage = 10, poisons = true, isThrowable = true,
    },
    ElectricTrap = {
        name = "Electric Trap",
        category = "Weapons",
        weight = 3,
        maxStack = 3,
        description = "Stuns enemies who trigger it.",
        stunDuration = 5, isTrap = true,
    },
    Backpack = {
        name = "Backpack",
        category = "Armor",
        weight = 1,
        maxStack = 1,
        description = "Extra carrying capacity. +8 slots.",
        extraSlots = 8, weightBonus = 20,
    },
    FlashBomb = {
        name = "Flash Bomb",
        category = "Weapons",
        weight = 0.5,
        maxStack = 5,
        description = "Blinds and stuns enemies temporarily.",
        stunDuration = 3, blinding = true, isThrowable = true,
    },
}

-- ========== CRAFTING RECIPES ==========
ItemData.Recipes = {
    {
        name = "Torch",
        ingredients = { Wood = 1, Cloth = 1, DuctTape = 1 },
        result = "Torch",
        resultCount = 1,
        category = "Tools",
    },
    {
        name = "Spike Trap",
        ingredients = { Wood = 1, Metal = 1, Rope = 1 },
        result = "SpikeTrap",
        resultCount = 1,
        category = "Weapons",
    },
    {
        name = "Molotov",
        ingredients = { Cloth = 1, Chemical = 1 },
        result = "Molotov",
        resultCount = 1,
        category = "Weapons",
    },
    {
        name = "Shield",
        ingredients = { Metal = 2, DuctTape = 1 },
        result = "Shield",
        resultCount = 1,
        category = "Armor",
    },
    {
        name = "Poison Bomb",
        ingredients = { Chemical = 2, Glass = 1 },
        result = "PoisonBomb",
        resultCount = 1,
        category = "Weapons",
    },
    {
        name = "Electric Trap",
        ingredients = { Wood = 1, Wire = 1, DuctTape = 1 },
        result = "ElectricTrap",
        resultCount = 1,
        category = "Weapons",
    },
    {
        name = "Backpack",
        ingredients = { Cloth = 2, Rope = 1 },
        result = "Backpack",
        resultCount = 1,
        category = "Armor",
    },
    {
        name = "Lockpick",
        ingredients = { Metal = 1, DuctTape = 1, Wire = 1 },
        result = "Lockpick",
        resultCount = 1,
        category = "Tools",
    },
    {
        name = "Cooked Meat",
        ingredients = { RawMeat = 1, Lighter = 0 }, -- Lighter is tool, not consumed
        result = "CookedMeat",
        resultCount = 1,
        category = "Food",
        requiresTool = "Lighter",
    },
    {
        name = "Flash Bomb",
        ingredients = { Glass = 1, Chemical = 1, DuctTape = 1 },
        result = "FlashBomb",
        resultCount = 1,
        category = "Weapons",
    },
}

-- ========== HELPER: Get item by ID ==========
function ItemData.GetItem(itemId)
    return ItemData.Items[itemId]
end

-- ========== HELPER: Can player craft recipe? ==========
function ItemData.CanCraft(recipe, inventory)
    for itemId, count in pairs(recipe.ingredients) do
        if count == 0 then continue end -- tools not consumed
        local hasCount = 0
        for _, slot in ipairs(inventory) do
            if slot and slot.itemId == itemId then
                hasCount = hasCount + slot.count
            end
        end
        if hasCount < count then return false end
    end
    return true
end

return ItemData
