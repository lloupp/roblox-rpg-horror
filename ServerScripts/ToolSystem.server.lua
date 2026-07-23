-- ========== DARK SURVIVORS: Tool System =========
-- Server-side: light tools (Flashlight, Torch, Lighter), equip effects.
-- When a player equips a light tool, attaches a Light to their character.
-- Unequipping removes it.

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

local Shared = ReplicatedStorage:FindFirstChild("Shared")
local ItemData = require(Shared:WaitForChild("ItemData"))

-- ========== LIGHT CONFIGS =========
-- Each light tool gets a specific light type + properties.
local LIGHT_CONFIGS = {
    Flashlight = {
        lightType = "SpotLight",
        brightness = 2,
        range = 40,
        angle = 45,
        color = Color3.fromRGB(255, 255, 200),
        face = Enum.NormalId.Front,
    },
    Torch = {
        lightType = "PointLight",
        brightness = 1.5,
        range = 15,
        color = Color3.fromRGB(255, 160, 60),
    },
    Lighter = {
        lightType = "PointLight",
        brightness = 1,
        range = 6,
        color = Color3.fromRGB(255, 180, 80),
    },
}

-- ========== ACTIVE LIGHTS =========
local activeLights = {}  -- userId -> Instance (the light)

local function attachLight(player, itemId)
    local config = LIGHT_CONFIGS[itemId]
    if not config then return end

    -- Remove previous light
    detachLight(player)

    local character = player.Character
    if not character then return end
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if not torso then return end

    local light
    if config.lightType == "SpotLight" then
        light = Instance.new("SpotLight")
        light.Angle = config.angle
        light.Face = config.face
    else
        light = Instance.new("PointLight")
    end

    light.Name = "ToolLight"
    light.Brightness = config.brightness
    light.Range = config.range
    light.Color = config.color
    light.Parent = torso

    activeLights[player.UserId] = light
end

function detachLight(player)
    local light = activeLights[player.UserId]
    if light then
        light:Destroy()
        activeLights[player.UserId] = nil
    end
end

-- ========== EQUIP / UNEQUIP HANDLER =========
-- Listen to InventorySystem equip/unequip via the shared equip remote.
local EquipRemote = ensureRemote("EquipWeapon", "RemoteEvent")

EquipRemote.OnServerEvent:Connect(function(player, itemId)
    local item = ItemData.GetItem(itemId)
    if not item then return end

    if item.providesLight then
        attachLight(player, itemId)
    end
end)

-- ========== UNEQUIP via InventoryAction =========
local InventoryAction = ensureRemote("InventoryAction", "RemoteEvent")
InventoryAction.OnServerEvent:Connect(function(player, action, data)
    if action == "unequip" then
        -- Check if they're unequipping a light tool
        local inv = _G.GetInventory and _G.GetInventory(player)
        if not inv then return end

        local equippedWeapon = inv.equipped and inv.equipped.weapon
        local item = equippedWeapon and ItemData.GetItem(equippedWeapon)
        if data.equipSlot == "weapon" and (not item or not item.providesLight) then
            detachLight(player)
        end
    end
end)

-- ========== POWER FAILURE (from HorrorSystem client) =========
local ToolAction = ensureRemote("ToolAction", "RemoteEvent")
ToolAction.OnServerEvent:Connect(function(player, action, duration)
    if action == "powerFailure" then
        detachLight(player)
        task.delay(duration or 5, function()
            -- Re-attach if player still has a light tool equipped
            local inv = _G.GetInventory and _G.GetInventory(player)
            if inv and inv.equipped and inv.equipped.weapon then
                local item = ItemData.GetItem(inv.equipped.weapon)
                if item and item.providesLight then
                    attachLight(player, inv.equipped.weapon)
                end
            end
        end)
    end
end)

-- ========== CLEANUP ON DEATH / LEAVE =========
Players.PlayerRemoving:Connect(function(player)
    detachLight(player)
end)

-- Expose so other systems can force-detach (e.g., HorrorSystem PowerFailure)
_G.DetachLight = detachLight
_G.AttachLight = attachLight

print("[ToolSystem] Loaded ✓")
