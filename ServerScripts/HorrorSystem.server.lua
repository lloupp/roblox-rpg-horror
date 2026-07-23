-- ========== DARK SURVIVORS: Horror System =========
-- Server-side: sanity events, random horror, jump scares, ambient horror
--
-- Bug #2: sanidade agora é lida de SurvivalSystem via _G.GetStats(player).
-- Não há mais tabela paralela deste lado — a fonte da verdade é única.
-- Drenos de sanidade aplicam-se via _G.GetStats e ModifySanity (SurvivalSystem).

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

-- ========== SANITY HELPER (fonte única = SurvivalSystem) =========
local function getPlayerSanity(player)
    local s = _G.GetStats and _G.GetStats(player)
    return s and s.Sanity or 100
end

-- Aplica delta de sanidade na fonte da verdade (SurvivalSystem).
-- Se o delta for grande (ex: entrada de zona), usa SetAsync direto no stats.
local function modifySanity(player, delta)
    local s = _G.GetStats and _G.GetStats(player)
    if not s then return end
    s.Sanity = math.clamp(s.Sanity + delta, 0, 100)
end

-- ========== SANITY THRESHOLDS =========
local SANITY_TIERS = {
    { threshold = 70, events = { "Whispers", "DistantShadow" } },
    { threshold = 50, events = { "ScreenFlicker", "FakeEnemy", "DoorOpen" } },
    { threshold = 30, events = { "HeavyDistortion", "FakeJumpscare", "TextOnWalls" } },
    { threshold = 15, events = { "UI_Lies", "EnemyLooksLikeNPC", "CompleteDistortion" } },
}

-- ========== RANDOM HORROR EVENTS =========
local RANDOM_EVENTS = {
    { name = "FootstepsBehind", minSanity = 50, weight = 20, nightBonus = 15 },
    { name = "ShadowFigure",    minSanity = 40, weight = 15, nightBonus = 20 },
    { name = "RadioStatic",     minSanity = 60, weight = 15, nightBonus = 10 },
    { name = "PowerFailure",    minSanity = 30, weight = 10, nightBonus = 15 },
    { name = "BleedingWalls",   minSanity = 30, weight = 10, nightBonus = 20 },
    { name = "MusicBox",        minSanity = 50, weight = 8,  nightBonus = 12 },
    { name = "DoorSlam",        minSanity = 40, weight = 12, nightBonus = 10 },
    { name = "DropBehind",      minSanity = 60, weight = 10, nightBonus = 8 },
}

local JUMPSCARE_CHANCE = 0.05  -- 5% per eligible trigger
local horrorIntervalMin = 30
local horrorIntervalMax = 120

-- ========== SANITY-BASED EVENTS =========
local lastTierEvent = {}   -- userId -> last tier index that fired (evita spam)

local function checkSanityEvents(player)
    local sanity = getPlayerSanity(player)
    if sanity >= 100 then return end

    for i, tier in ipairs(SANITY_TIERS) do
        if sanity <= tier.threshold then
            local last = lastTierEvent[player.UserId]
            if last ~= i then
                lastTierEvent[player.UserId] = i
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
end

-- ========== RANDOM HORROR EVENTS =========
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
        -- Jump scare further reduces sanity (fonte única)
        modifySanity(player, -5)
    end

    -- Sanity drain from horror events
    modifySanity(player, -math.random(1, 3))
end

-- ========== AMBIENT HORROR (always running) =========
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
        modifySanity(player, -drainRate * 0.1)
    end
end

-- ========== ZONE-TRIGGERED HORROR =========
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
            -- Drain sanity on first entry (fonte única)
            modifySanity(player, -trigger.sanityDrain)
        end
    end
end

-- ========== MAIN LOOP =========
local horrorTimers = {}
local sanityCheckAccum = 0

RunService.Heartbeat:Connect(function(dt)
    sanityCheckAccum = sanityCheckAccum + dt
    local doSanityCheck = sanityCheckAccum >= 5
    if doSanityCheck then sanityCheckAccum = 0 end

    for _, player in ipairs(Players:GetPlayers()) do
        local userId = player.UserId

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

-- ========== PLAYER LIFECYCLE =========
Players.PlayerRemoving:Connect(function(player)
    horrorTimers[player.UserId] = nil
    playerZones[player.UserId] = nil
    lastTierEvent[player.UserId] = nil
end)

-- ========== EXTERNAL: Modify Sanity (called by other scripts) =========
-- Mantido para compat: repassa para a fonte única.
_HorrorSystem_ModifySanity = function(player, amount)
    modifySanity(player, amount)
end
_G.ModifySanity = _HorrorSystem_ModifySanity

print("[HorrorSystem] Loaded ✓")
