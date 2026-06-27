-- ========== DARK SURVIVORS: Horror System ==========
-- Server-side: sanity events, random horror, jump scares, ambient horror

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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

local HorrorEvent = ensureRemote("HorrorEvent", "RemoteEvent")
local SanityEffect = ensureRemote("SanityEffect", "RemoteEvent")
local JumpScare = ensureRemote("JumpScare", "RemoteEvent")
local UpdateStats = ensureRemote("UpdateStats", "RemoteEvent")

-- ========== SANITY THRESHOLDS ==========
local SANITY_TIERS = {
    { threshold = 70, events = { "Whispers", "DistantShadow" } },
    { threshold = 50, events = { "ScreenFlicker", "FakeEnemy", "DoorOpen" } },
    { threshold = 30, events = { "HeavyDistortion", "FakeJumpscare", "TextOnWalls" } },
    { threshold = 15, events = { "UI_Lies", "EnemyLooksLikeNPC", "CompleteDistortion" } },
}

-- ========== RANDOM HORROR EVENTS ==========
local RANDOM_EVENTS = {
    { name = "FootstepsBehind", minSanity = 50, weight = 20, nightBonus = 15 },
    { name = "ShadowFigure", minSanity = 40, weight = 15, nightBonus = 20 },
    { name = "RadioStatic", minSanity = 60, weight = 15, nightBonus = 10 },
    { name = "PowerFailure", minSanity = 30, weight = 10, nightBonus = 15 },
    { name = "BleedingWalls", minSanity = 30, weight = 10, nightBonus = 20 },
    { name = "MusicBox", minSanity = 50, weight = 8, nightBonus = 12 },
    { name = "DoorSlam", minSanity = 40, weight = 12, nightBonus = 10 },
    { name = "DropBehind", minSanity = 60, weight = 10, nightBonus = 8 },
}

local JUMPSCARE_CHANCE = 0.05  -- 5% per eligible trigger
local horrorIntervalMin = 30
local horrorIntervalMax = 120

-- ========== PLAYER SANITY TRACKING ==========
local playerSanity = {}

local function getPlayerSanity(player)
    return playerSanity[player.UserId] or 100
end

-- Listen for stat updates from SurvivalSystem
local UpdateStatsRemote = Remotes:FindFirstChild("UpdateStats")
if UpdateStatsRemote then
    -- Server tracks sanity internally
end

-- ========== SANITY-BASED EVENTS ==========
local function checkSanityEvents(player)
    local sanity = getPlayerSanity(player)
    if sanity >= 100 then return end

    for _, tier in ipairs(SANITY_TIERS) do
        if sanity <= tier.threshold then
            -- Pick a random event from this tier
            local evt = tier.events[math.random(1, #tier.events)]
            HorrorEvent:FireClient(player, {
                type = "sanity",
                event = evt,
                sanity = sanity,
                intensity = (100 - sanity) / 100,
            })
        end
    end
end

-- ========== RANDOM HORROR EVENTS ==========
local function triggerRandomEvent(player)
    local sanity = getPlayerSanity(player)
    local isNight = _G.IsNight and _G.IsNight() or false

    -- Build eligible events
    local eligible = {}
    local totalWeight = 0

    for _, evt in ipairs(RANDOM_EVENTS) do
        if sanity <= evt.minSanity then
            local w = evt.weight + (isNight and evt.nightBonus or 0)
            table.insert(eligible, { event = evt, weight = w })
            totalWeight = totalWeight + w
        end
    end

    if #eligible == 0 then return end

    -- Weighted random pick
    local roll = math.random() * totalWeight
    local cumulative = 0
    local chosen = eligible[1].event

    for _, e in ipairs(eligible) do
        cumulative = cumulative + e.weight
        if roll <= cumulative then
            chosen = e.event
            break
        end
    end

    HorrorEvent:FireClient(player, {
        type = "random",
        event = chosen.name,
        sanity = sanity,
        isNight = isNight,
    })

    -- Jump scare chance
    if sanity < 30 and math.random() < JUMPSCARE_CHANCE then
        JumpScare:FireClient(player, {
            type = math.random(1, 3),  -- different jump scare variants
            duration = 0.3,
        })
        -- Jump scare further reduces sanity
        playerSanity[player.UserId] = math.max(0, sanity - 5)
    end

    -- Sanity drain from horror events
    playerSanity[player.UserId] = math.max(0, sanity - math.random(1, 3))
end

-- ========== AMBIENT HORROR (always running) ==========
local function ambientHorror(player)
    local sanity = getPlayerSanity(player)

    -- Subtle sanity drain in dangerous areas
    local biome = _G.GetPlayerBiome and _G.GetPlayerBiome(player) or "Forest"
    local drainRate = 0

    if biome == "Hospital" then drainRate = 0.5
    elseif biome == "Caves" then drainRate = 0.3
    elseif biome == "Swamp" then drainRate = 0.2
    elseif biome == "Ruins" then drainRate = 0.15
    end

    if _G.IsNight and _G.IsNight() then
        drainRate = drainRate + 0.1
    end

    if drainRate > 0 then
        playerSanity[player.UserId] = math.max(0, sanity - drainRate * 0.1)
    end
end

-- ========== ZONE-TRIGGERED HORROR ==========
local ZONE_TRIGGERS = {
    Hospital = { event = "HospitalEntry", sanityDrain = 10 },
    Caves = { event = "CaveEntry", sanityDrain = 5 },
}

local playerZones = {}

local function checkZoneTriggers(player)
    local biome = _G.GetPlayerBiome and _G.GetPlayerBiome(player) or "Forest"
    local userId = player.UserId
    local prevZone = playerZones[userId]

    if biome ~= prevZone then
        playerZones[userId] = biome

        local trigger = ZONE_TRIGGERS[biome]
        if trigger then
            HorrorEvent:FireClient(player, {
                type = "zone",
                event = trigger.event,
                zone = biome,
            })
            -- Drain sanity on first entry
            playerSanity[userId] = math.max(0,
                (playerSanity[userId] or 100) - trigger.sanityDrain)
        end
    end
end

-- ========== MAIN LOOP ==========
local horrorTimers = {}
local sanityCheckAccum = 0

RunService.Heartbeat:Connect(function(dt)
    sanityCheckAccum = sanityCheckAccum + dt
    local doSanityCheck = sanityCheckAccum >= 5
    if doSanityCheck then sanityCheckAccum = 0 end

    for _, player in ipairs(Players:GetPlayers()) do
        local userId = player.UserId

        -- Initialize if needed
        if not playerSanity[userId] then
            playerSanity[userId] = 100
        end

        if not horrorTimers[userId] then
            horrorTimers[userId] = tick() + math.random(horrorIntervalMin, horrorIntervalMax)
        end

        -- Ambient horror every frame
        ambientHorror(player)

        -- Zone triggers
        checkZoneTriggers(player)

        -- Sanity-based events every 5 sec
        if doSanityCheck then
            checkSanityEvents(player)
        end

        -- Random horror events on timer
        if tick() >= horrorTimers[userId] then
            triggerRandomEvent(player)
            horrorTimers[userId] = tick() + math.random(horrorIntervalMin, horrorIntervalMax)
        end
    end
end)

-- ========== PLAYER LIFECYCLE ==========
Players.PlayerAdded:Connect(function(player)
    playerSanity[player.UserId] = 100
end)

Players.PlayerRemoving:Connect(function(player)
    playerSanity[player.UserId] = nil
    horrorTimers[player.UserId] = nil
    playerZones[player.UserId] = nil
end)

-- ========== EXTERNAL: Modify Sanity (called by other scripts) ==========
function HorrorEvent_ModifySanity(player, amount)
    if playerSanity[player.UserId] then
        playerSanity[player.UserId] = math.clamp(
            playerSanity[player.UserId] + amount, 0, 100)
    end
end

-- Expose for other server scripts
_G.ModifySanity = HorrorEvent_ModifySanity

print("[HorrorSystem] Loaded ✓")
