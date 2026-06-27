-- ========== DARK SURVIVORS: Inventory System ==========
-- Server-side: inventory management, equipping, picking up, crafting

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = ReplicatedStorage
end

local function ensureRemote(n, c)
    local r = Remotes:FindFirstChild(n)
    if not r then r = Instance.new(c); r.Name = n; r.Parent = Remotes end
    return r
end

local InventoryUpdate = ensureRemote("InventoryUpdate", "RemoteEvent")
local InventoryAction = ensureRemote("InventoryAction", "RemoteEvent")
local CraftingResult = ensureRemote("CraftingResult", "RemoteEvent")

-- Load ItemData
local Shared = ReplicatedStorage:FindFirstChild("Shared")
if not Shared then
    Shared = Instance.new("Folder")
    Shared.Name = "Shared"
    Shared.Parent = ReplicatedStorage
end

local ItemData = require(Shared:WaitForChild("ItemData"))

-- ========== CONFIG ==========
local BASE_SLOTS = 8
local BACKPACK_SLOTS = 8  -- +8 from Backpack item
local BASE_CARRY_WEIGHT = 50
local BACKPACK_WEIGHT_BONUS = 20

-- ========== PLAYER INVENTORY ==========
local inventories = {}

local function initInventory(player)
    inventories[player.UserId] = {
        slots = {},        -- array of { itemId, count } or nil
        maxSlots = BASE_SLOTS,
        maxWeight = BASE_CARRY_WEIGHT,
        equipped = { weapon = nil, armor = nil, tool = nil },
        hotbar = { nil, nil, nil, nil },
    }

    -- Grant starter items if new player
    local pd = _G.GetPlayerData and _G.GetPlayerData(player)
    if pd and pd.isNew then
        local inv = inventories[player.UserId]
        local starters = {
            { itemId = "Flashlight", count = 1 },
            { itemId = "Bandage", count = 2 },
            { itemId = "CannedBeans", count = 1 },
            { itemId = "WaterBottle", count = 1 },
        }
        for _, item in ipairs(starters) do
            addItem(player, item.itemId, item.count)
        end
        pd.isNew = false
    end
end

-- ========== CALCULATE WEIGHT ==========
local function getTotalWeight(player)
    local inv = inventories[player.UserId]
    if not inv then return 0 end

    local total = 0
    for _, slot in ipairs(inv.slots) do
        if slot then
            local item = ItemData.GetItem(slot.itemId)
            if item then
                total = total + item.weight * slot.count
            end
        end
    end
    return total
end

-- ========== ADD ITEM ==========
function addItem(player, itemId, count)
    local inv = inventories[player.UserId]
    if not inv then return false end

    count = count or 1
    local item = ItemData.GetItem(itemId)
    if not item then return false end

    -- Try to stack existing slot
    for _, slot in ipairs(inv.slots) do
        if slot and slot.itemId == itemId and slot.count < item.maxStack then
            local canAdd = math.min(count, item.maxStack - slot.count)
            local weightCheck = item.weight * canAdd
            if getTotalWeight(player) + weightCheck <= inv.maxWeight then
                slot.count = slot.count + canAdd
                count = count - canAdd
                if count <= 0 then
                    syncInventory(player)
                    if _G.MarkDataDirty then _G.MarkDataDirty(player) end
                    return true
                end
            end
        end
    end

    -- Add to new slot(s)
    while count > 0 do
        if #inv.slots >= inv.maxSlots then return false end

        local canAdd = math.min(count, item.maxStack)
        if getTotalWeight(player) + item.weight * canAdd > inv.maxWeight then
            return false
        end

        table.insert(inv.slots, { itemId = itemId, count = canAdd })
        count = count - canAdd
    end

    syncInventory(player)
    if _G.MarkDataDirty then _G.MarkDataDirty(player) end
    return true
end

-- ========== REMOVE ITEM ==========
local function removeItem(player, itemId, count)
    local inv = inventories[player.UserId]
    if not inv then return false end

    count = count or 1
    local removed = 0

    -- Iterate backwards to remove from end first
    for i = #inv.slots, 1, -1 do
        local slot = inv.slots[i]
        if slot and slot.itemId == itemId then
            local canRemove = math.min(count - removed, slot.count)
            slot.count = slot.count - canRemove
            removed = removed + canRemove

            if slot.count <= 0 then
                table.remove(inv.slots, i)
            end

            if removed >= count then break end
        end
    end

    if removed > 0 then
        syncInventory(player)
        if _G.MarkDataDirty then _G.MarkDataDirty(player) end
        return true
    end
    return false
end

-- ========== SYNC TO CLIENT ==========
function syncInventory(player)
    local inv = inventories[player.UserId]
    if not inv then return end

    InventoryUpdate:FireClient(player, {
        slots = inv.slots,
        maxSlots = inv.maxSlots,
        equipped = inv.equipped,
        hotbar = inv.hotbar,
        totalWeight = getTotalWeight(player),
        maxWeight = inv.maxWeight,
    })
end

-- ========== CRAFTING ==========
local function craft(player, recipeIndex)
    local inv = inventories[player.UserId]
    if not inv then return false end

    local recipe = ItemData.Recipes[recipeIndex]
    if not recipe then return false end

    -- Check if player has ingredients
    if not ItemData.CanCraft(recipe, inv.slots) then
        CraftingResult:FireClient(player, {
            success = false,
            message = "Missing ingredients!",
        })
        return false
    end

    -- Check if requires tool (e.g., Lighter for CookedMeat)
    if recipe.requiresTool then
        local hasTool = false
        for _, slot in ipairs(inv.slots) do
            if slot and slot.itemId == recipe.requiresTool then
                hasTool = true
                break
            end
        end
        if not hasTool then
            CraftingResult:FireClient(player, {
                success = false,
                message = "Requires " .. recipe.requiresTool .. "!",
            })
            return false
        end
    end

    -- Consume ingredients
    for itemId, count in pairs(recipe.ingredients) do
        if count > 0 then
            removeItem(player, itemId, count)
        end
    end

    -- Add result
    local success = addItem(player, recipe.result, recipe.resultCount or 1)

    CraftingResult:FireClient(player, {
        success = success,
        message = success and ("Crafted " .. recipe.name .. "!") or "Inventory full!",
        recipe = recipe.name,
    })

    return success
end

-- ========== PICK UP ITEM (Touch) ==========
Workspace.ChildAdded:Connect(function(child)
    if not child:FindFirstChild("ItemName") then return end

    child.Touched:Connect(function(hit)
        local character = hit.Parent
        local player = Players:GetPlayerFromCharacter(character)
        if not player then return end

        local itemName = child.ItemName.Value
        if addItem(player, itemName, 1) then
            child:Destroy()
        end
    end)
end)

-- ========== REMOTE HANDLERS ==========
InventoryAction.OnServerEvent:Connect(function(player, action, data)
    if action == "swap" then
        -- Swap two inventory slots
        local inv = inventories[player.UserId]
        if inv and data.from and data.to then
            local temp = inv.slots[data.from]
            inv.slots[data.from] = inv.slots[data.to]
            inv.slots[data.to] = temp
            syncInventory(player)
        end

    elseif action == "equip" then
        local inv = inventories[player.UserId]
        if inv and data.slotIndex and data.equipSlot then
            local slot = inv.slots[data.slotIndex]
            if slot then
                local item = ItemData.GetItem(slot.itemId)
                if item then
                    inv.equipped[data.equipSlot] = slot.itemId
                    syncInventory(player)
                end
            end
        end

    elseif action == "unequip" then
        local inv = inventories[player.UserId]
        if inv and data.equipSlot then
            inv.equipped[data.equipSlot] = nil
            syncInventory(player)
        end

    elseif action == "drop" then
        local inv = inventories[player.UserId]
        if inv and data.slotIndex then
            local slot = inv.slots[data.slotIndex]
            if slot then
                -- Spawn part in world
                local char = player.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local part = Instance.new("Part")
                        part.Name = slot.itemId
                        part.Size = Vector3.new(0.5, 0.5, 0.5)
                        part.Position = root.Position + root.CFrame.LookVector * 3
                        part.Anchored = false
                        part.CanCollide = true
                        part.BrickColor = BrickColor.new("Bright yellow")
                        part.Parent = Workspace

                        local itemVal = Instance.new("StringValue")
                        itemVal.Name = "ItemName"
                        itemVal.Value = slot.itemId
                        itemVal.Parent = part

                        game:GetService("Debris"):AddItem(part, 300)
                    end
                end

                table.remove(inv.slots, data.slotIndex)
                syncInventory(player)
            end
        end

    elseif action == "use" then
        local inv = inventories[player.UserId]
        if inv and data.slotIndex then
            local slot = inv.slots[data.slotIndex]
            if slot then
                local item = ItemData.GetItem(slot.itemId)
                if not item then return end

                -- Use item based on category
                if item.category == "Food" or item.category == "Drinks" then
                    if _G.ApplyConsumable then
                        _G.ApplyConsumable(player, slot.itemId)
                    end
                    removeItem(player, slot.itemId, 1)
                elseif item.category == "Medical" then
                    if item.healthRestore then
                        -- Apply heal
                        local hum = player.Character and
                            player.Character:FindFirstChild("Humanoid")
                        if hum then
                            hum.Health = math.min(hum.Health + item.healthRestore, hum.MaxHealth)
                        end
                    end
                    removeItem(player, slot.itemId, 1)
                end
            end
        end

    elseif action == "craft" then
        craft(player, data.recipeIndex)

    elseif action == "hotbar" then
        local inv = inventories[player.UserId]
        if inv and data.slotIndex and data.hotbarIndex then
            inv.hotbar[data.hotbarIndex] = data.slotIndex
            syncInventory(player)
        end
    end
end)

-- ========== BACKPACK CHECK ==========
-- If player equips Backpack, expand slots
local EquipRemote = Remotes:FindFirstChild("EquipWeapon")
if EquipRemote then
    EquipRemote.OnServerEvent:Connect(function(player, weaponName)
        local inv = inventories[player.UserId]
        if not inv then return end

        -- Check for backpack in inventory
        local hasBackpack = false
        for _, slot in ipairs(inv.slots) do
            if slot and slot.itemId == "Backpack" then
                hasBackpack = true
                break
            end
        end

        if hasBackpack then
            inv.maxSlots = BASE_SLOTS + BACKPACK_SLOTS
            inv.maxWeight = BASE_CARRY_WEIGHT + BACKPACK_WEIGHT_BONUS
        else
            inv.maxSlots = BASE_SLOTS
            inv.maxWeight = BASE_CARRY_WEIGHT
        end
    end)
end

-- ========== PLAYER LIFECYCLE ==========
Players.PlayerAdded:Connect(function(player)
    initInventory(player)
    -- Delay sync until after DataStore load
    player.CharacterAdded:Connect(function()
        task.wait(1)
        syncInventory(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    inventories[player.UserId] = nil
end)

print("[InventorySystem] Loaded ✓")
