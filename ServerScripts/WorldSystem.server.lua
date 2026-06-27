-- ========== DARK SURVIVORS: World System ==========
-- Server-side: day/night cycle, weather, biomes, loot spawns

local Lighting = game:GetService("Lighting")
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

local WeatherUpdate = ensureRemote("WeatherUpdate", "RemoteEvent")
local TimeUpdate = ensureRemote("TimeUpdate", "RemoteEvent")

-- ========== DAY/NIGHT CONFIG ==========
local CYCLE_DURATION = 600       -- 10 min total
local DAY_DURATION = 360         -- 6 min day
local NIGHT_DURATION = 240       -- 4 min night

-- ========== WEATHER CONFIG ==========
local WEATHER_TYPES = {"Clear", "Rain", "Storm", "Fog", "BloodRain"}
local WEATHER_WEIGHTS = {Clear = 40, Rain = 25, Storm = 10, Fog = 15, BloodRain = 10}
local weatherChangeMin = 120  -- 2 min
local weatherChangeMax = 300 -- 5 min

local currentWeather = "Clear"
local nextWeatherChange = tick() + math.random(weatherChangeMin, weatherChangeMax)
local isNight = false
local nightEnemyBonus = 1.0

-- ========== DAY/NIGHT CYCLE ==========
local cycleTime = 0

local function updateDayNight(dt)
    cycleTime = (cycleTime + dt) % CYCLE_DURATION

    local clockTime
    local nightProgress = 0
    if cycleTime < DAY_DURATION then
        -- Day phase: 6am → 6pm (12 hours in Lighting.ClockTime)
        local dayProgress = cycleTime / DAY_DURATION
        clockTime = 6 + dayProgress * 12
        isNight = false
        nightEnemyBonus = 1.0
    else
        -- Night phase: 6pm → 6am
        nightProgress = (cycleTime - DAY_DURATION) / NIGHT_DURATION
        clockTime = 18 + nightProgress * 12
        if clockTime >= 24 then clockTime = clockTime - 24 end
        isNight = true
        nightEnemyBonus = 1.5  -- 50% more enemy spawns at night
    end

    Lighting.ClockTime = clockTime

    -- Adjust lighting based on time
    if isNight then
        Lighting.Brightness = math.max(0.2, 2 - nightProgress * 1.8)
        Lighting.Ambient = Color3.fromRGB(
            math.max(30, 128 - 98),
            math.max(30, 128 - 98),
            math.max(40, 128 - 88)
        )
        -- Increase fog at night
        Lighting.FogEnd = math.max(200, 10000 - nightProgress * 8000)
    else
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
        Lighting.FogEnd = 10000
    end

    -- Update atmosphere
    local atmo = Lighting:FindFirstChild("Atmosphere")
    if atmo then
        atmo.Density = isNight and 0.5 or 0.3
    end

    TimeUpdate:FireAllClients({
        clockTime = clockTime,
        isNight = isNight,
        cycleProgress = cycleTime / CYCLE_DURATION,
    })
end

-- ========== WEATHER SYSTEM ==========
local function pickWeather()
    -- Ajusta pesos antes de calcular o total
    if isNight then
        WEATHER_WEIGHTS.BloodRain = 20
        WEATHER_WEIGHTS.Fog = 25
        WEATHER_WEIGHTS.Clear = 15
    else
        WEATHER_WEIGHTS.BloodRain = 10
        WEATHER_WEIGHTS.Fog = 15
        WEATHER_WEIGHTS.Clear = 40
    end

    local totalWeight = 0
    for _, w in pairs(WEATHER_WEIGHTS) do
        totalWeight = totalWeight + w
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for weather, weight in pairs(WEATHER_WEIGHTS) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            return weather
        end
    end
    return "Clear"
end

local function applyWeather(weather)
    currentWeather = weather

    -- Reset all weather effects first
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)

    if weather == "Rain" then
        Lighting.FogEnd = math.min(Lighting.FogEnd, 5000)
        -- Speed debuff handled per-player in Heartbeat
    elseif weather == "Storm" then
        Lighting.FogEnd = math.min(Lighting.FogEnd, 3000)
        Lighting.Brightness = math.max(Lighting.Brightness * 0.5, 0.3)
        -- Lightning flashes handled by StormFlash coroutine
    elseif weather == "Fog" then
        Lighting.FogEnd = 500
        Lighting.FogStart = 0
    elseif weather == "BloodRain" then
        Lighting.FogEnd = math.min(Lighting.FogEnd, 4000)
        Lighting.OutdoorAmbient = Color3.fromRGB(100, 60, 60)
    end

    WeatherUpdate:FireAllClients({
        weather = weather,
        isNight = isNight,
    })
end

-- ========== STORM LIGHTNING ==========
task.spawn(function()
    while true do
        wait(math.random(3, 10))
        if currentWeather == "Storm" then
            -- Flash
            local origBrightness = Lighting.Brightness
            Lighting.Brightness = 5
            wait(0.1)
            Lighting.Brightness = origBrightness

            -- 30% chance to damage outdoor players
            if math.random() < 0.3 then
                for _, player in ipairs(Players:GetPlayers()) do
                    local char = player.Character
                    if char then
                        local root = char:FindFirstChild("HumanoidRootPart")
                        local hum = char:FindFirstChild("Humanoid")
                        if root and hum then
                            -- Check if outdoors (no roof above)
                            local ray = Workspace:Raycast(
                                root.Position, Vector3.new(0, 100, 0))
                            if not ray then
                                hum:TakeDamage(15)
                            end
                        end
                    end
                end
            end

            -- Double flash sometimes
            if math.random() < 0.3 then
                wait(0.15)
                Lighting.Brightness = 4
                wait(0.05)
                Lighting.Brightness = origBrightness
            end
        end
    end
end)

-- ========== LOOT SPAWNS ==========
local LOOT_ZONES = {"Ruins", "Hospital"}
local LOOT_INTERVAL_MIN = 60
local LOOT_INTERVAL_MAX = 120
local MAX_WORLD_LOOT = 50

local SPAWNABLE_LOOT = {
    "CannedBeans", "Bandage", "Cloth", "Wood", "DuctTape",
    "WaterBottle", "Metal", "Wire", "Chemical", "Jerky",
    "RawMeat", "Glass", "Rope", "Mushrooms",
}

task.spawn(function()
    while true do
        wait(math.random(LOOT_INTERVAL_MIN, LOOT_INTERVAL_MAX))

        -- Count current world loot
        local lootCount = 0
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:FindFirstChild("ItemName") then
                lootCount = lootCount + 1
            end
        end

        if lootCount >= MAX_WORLD_LOOT then continue end

        -- Pick a zone and spawn loot
        local zoneName = LOOT_ZONES[math.random(1, #LOOT_ZONES)]
        local zone = Workspace:FindFirstChild("Biomes") and
            Workspace.Biomes:FindFirstChild(zoneName)
        if not zone then continue end

        local itemName = SPAWNABLE_LOOT[math.random(1, #SPAWNABLE_LOOT)]
        local spawnParts = zone:GetChildren()
        if #spawnParts == 0 then continue end

        local spawnPart = spawnParts[math.random(1, #spawnParts)]
        local pos = spawnPart:IsA("BasePart") and spawnPart.Position or
            Vector3.new(math.random(-100, 100), 5, math.random(-100, 100))

        local part = Instance.new("Part")
        part.Name = "WorldLoot_" .. itemName
        part.Size = Vector3.new(0.5, 0.5, 0.5)
        part.Position = pos + Vector3.new(0, 2, 0)
        part.Anchored = false
        part.CanCollide = true
        part.BrickColor = BrickColor.new("Bright yellow")
        part.Parent = Workspace

        local itemVal = Instance.new("StringValue")
        itemVal.Name = "ItemName"
        itemVal.Value = itemName
        itemVal.Parent = part

        -- Highlight
        local highlight = Instance.new("Highlight")
        highlight.FillColor = Color3.fromRGB(255, 255, 0)
        highlight.OutlineColor = Color3.fromRGB(255, 200, 0)
        highlight.Parent = part

        game:GetService("Debris"):AddItem(part, 180) -- despawn 3min
    end
end)

-- ========== WEATHER SPEED DEBUFF ==========
-- Applied in Heartbeat for Rain weather
RunService.Heartbeat:Connect(function(dt)
    -- Day/night
    updateDayNight(dt)

    -- Weather change
    if tick() >= nextWeatherChange then
        local newWeather = pickWeather()
        applyWeather(newWeather)
        nextWeatherChange = tick() + math.random(weatherChangeMin, weatherChangeMax)
    end

    -- Player speed debuff for weather
    if currentWeather == "Rain" or currentWeather == "BloodRain" then
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    hum.WalkSpeed = math.min(hum.WalkSpeed, 10.8) -- -10%
                end
            end
        end
    end
end)

-- ========== BIOME CHECK (utility for other scripts) ==========
local function getPlayerBiome(player)
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local biomes = Workspace:FindFirstChild("Biomes")
    if not biomes then return nil end

    for _, zone in ipairs(biomes:GetChildren()) do
        if zone:IsA("Configuration") then continue end
        -- Check if player is within zone bounds
        local part = zone:FindFirstChild("Part") or zone
        if part:IsA("BasePart") then
            local dist = (root.Position - part.Position).Magnitude
            local size = part.Size.Magnitude / 2
            if dist <= size then
                return zone.Name
            end
        end
    end
    return "Forest"
end

-- Export for other scripts
_G.GetPlayerBiome = getPlayerBiome
_G.IsNight = function() return isNight end
_G.GetCurrentWeather = function() return currentWeather end
_G.NightEnemyBonus = function() return nightEnemyBonus end

print("[WorldSystem] Loaded ✓")
