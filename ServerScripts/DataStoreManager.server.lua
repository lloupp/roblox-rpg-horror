-- ========== DARK SURVIVORS: DataStore Manager ==========
-- Server-side: save/load player data with DataStoreService

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DATA_VERSION = 1
local SAVE_INTERVAL = 60     -- auto-save every 60 sec
local MAX_RETRIES = 3
local RETRY_DELAY = 1

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

-- ========== DATA STORE ==========
local dataStore
pcall(function()
    dataStore = DataStoreService:GetDataStore("DarkSurvivors_v" .. DATA_VERSION)
end)

-- ========== PLAYER DATA ==========
local playerData = {}
local dirtyFlags = {}

local DEFAULT_DATA = {
    version = DATA_VERSION,
    stats = {
        Health = 100,
        Hunger = 100,
        Thirst = 100,
        Sanity = 100,
        Stamina = 100,
    },
    inventory = {},
    equipped = {},
    position = { x = 0, y = 5, z = 0 },
    playtime = 0,
    isNew = true,
}

-- Starter items for new players
local STARTER_ITEMS = {
    { itemId = "Flashlight", count = 1 },
    { itemId = "Bandage", count = 2 },
    { itemId = "CannedBeans", count = 1 },
    { itemId = "WaterBottle", count = 1 },
}

-- ========== SAFE DATA OPERATIONS ==========
local function safeGet(key)
    for attempt = 1, MAX_RETRIES do
        local success, result = pcall(function()
            return dataStore:GetAsync(key)
        end)
        if success then return result end
        if attempt < MAX_RETRIES then task.wait(RETRY_DELAY) end
    end
    warn("[DataStore] Failed to get: " .. key)
    return nil
end

local function safeSet(key, value)
    for attempt = 1, MAX_RETRIES do
        local success, result = pcall(function()
            dataStore:SetAsync(key, value)
        end)
        if success then return true end
        if attempt < MAX_RETRIES then task.wait(RETRY_DELAY) end
    end
    warn("[DataStore] Failed to set: " .. key)
    return false
end

-- ========== LOAD DATA ==========
local function loadPlayerData(player)
    local key = "Player_" .. player.UserId
    local data = safeGet(key)

    if data then
        -- Version check / migration
        if data.version ~= DATA_VERSION then
            -- Future migration logic here
            data.version = DATA_VERSION
        end
        playerData[player.UserId] = data
    else
        -- New player
        data = table.clone(DEFAULT_DATA)
        data.inventory = {}

        -- Grant starter items
        for _, item in ipairs(STARTER_ITEMS) do
            table.insert(data.inventory, {
                itemId = item.itemId,
                count = item.count,
            })
        end

        playerData[player.UserId] = data
    end

    dirtyFlags[player.UserId] = false

    -- Notify client of loaded data
    local LoadData = ensureRemote("DataLoaded", "RemoteEvent")
    LoadData:FireClient(player, playerData[player.UserId])

    return data
end

-- ========== SAVE DATA ==========
local function savePlayerData(player)
    local userId = player.UserId
    if not playerData[userId] then return end
    if not dirtyFlags[userId] then return end  -- Skip if unchanged

    -- Update position
    local char = player.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            playerData[userId].position = {
                x = root.Position.X,
                y = root.Position.Y,
                z = root.Position.Z,
            }
        end
    end

    -- Pull authoritative inventory straight from InventorySystem (never from client input)
    local snapshot = _G.GetInventorySnapshot and _G.GetInventorySnapshot(player)
    if snapshot then
        playerData[userId].inventory = snapshot.slots
        playerData[userId].equipped = snapshot.equipped
        playerData[userId].hotbar = snapshot.hotbar
    end

    -- Update playtime
    playerData[userId].playtime = playerData[userId].playtime + SAVE_INTERVAL

    local key = "Player_" .. userId
    local success = safeSet(key, playerData[userId])

    if success then
        dirtyFlags[userId] = false
    end
end

-- ========== MARK DIRTY ==========
-- Called by other systems when they modify player data
local function markDirty(player)
    dirtyFlags[player.UserId] = true
end

-- Expose for other server scripts
_G.MarkDataDirty = markDirty
_G.GetPlayerData = function(player)
    return playerData[player.UserId]
end

-- ========== PLAYER LIFECYCLE ==========
Players.PlayerAdded:Connect(function(player)
    loadPlayerData(player)

    -- Restore position on spawn
    player.CharacterAdded:Connect(function(character)
        local pd = playerData[player.UserId]
        if pd and pd.position then
            local root = character:WaitForChild("HumanoidRootPart")
            root.CFrame = CFrame.new(
                pd.position.x,
                pd.position.y,
                pd.position.z
            )
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    savePlayerData(player)
    playerData[player.UserId] = nil
    dirtyFlags[player.UserId] = nil
end)

-- ========== AUTO-SAVE LOOP ==========
task.spawn(function()
    while true do
        task.wait(SAVE_INTERVAL)
        for _, player in ipairs(Players:GetPlayers()) do
            savePlayerData(player)
        end
    end
end)

-- ========== ON SHUTDOWN (graceful save) ==========
game:BindOnClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        savePlayerData(player)
    end
end)

print("[DataStoreManager] Loaded ✓")
