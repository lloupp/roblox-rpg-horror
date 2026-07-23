-- ========== DARK SURVIVORS: Sound System =========
-- Server-side: plays ambient, combat, crafting, and UI sounds via Sound
-- instances parented to Workspace. No external asset IDs required — uses
-- built-in Roblox sound assets where possible, falls back to silent.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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

local PlaySoundRemote = ensureRemote("PlaySound", "RemoteEvent")
local StopSoundRemote = ensureRemote("StopSound", "RemoteEvent")

-- ========== SOUND CATALOG =========
-- Roblox builtin sound asset IDs (free, noupload needed).
-- These are the standard library sounds available to all games.
local SOUNDS = {
    -- Combat
    meleeHit    = "rbxassetid://138088902",
    meleeMiss   = "rbxassetid://0",
    rangedShot  = "rbxassetid://138088902",
    critHit     = "rbxassetid://138088902",
    blockSound  = "rbxassetid://0",
    enemyHit    = "rbxassetid://138088902",
    enemyDeath  = "rbxassetid://0",

    -- Horror
    whisper     = "rbxassetid://0",
    ambientDrone= "rbxassetid://9046863143",
    jumpscare   = "rbxassetid://0",
    heartbeat   = "rbxassetid://0",

    -- World
    rain        = "rbxassetid://3723754198",
    thunder     = "rbxassetid://1760730353",
    pickup       = "rbxassetid://0",

    -- UI
    inventoryOpen   = "rbxassetid://0",
    craftSuccess   = "rbxassetid://0",
    craftFail      = "rbxassetid://0",
    levelUp         = "rbxassetid://0",
}

-- ========== AMBIENT SOUND MANAGER =========
-- Plays looping ambient sounds based on time/weather/sanity
local ambientSounds = {}   -- soundName -> Sound instance

local function playAmbient(soundName, looped, volume)
    if ambientSounds[soundName] then return end
    local soundId = SOUNDS[soundName]
    if not soundId or soundId == "rbxassetid://0" then return end

    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Looped = looped or false
    sound.Volume = volume or 0.5
    sound.Name = "Ambient_" .. soundName
    sound.Parent = Workspace
    sound:Play()
    ambientSounds[soundName] = sound
end

local function stopAmbient(soundName)
    local sound = ambientSounds[soundName]
    if sound then
        sound:Stop()
        sound:Destroy()
        ambientSounds[soundName] = nil
    end
end

-- ========== AMBIENT LOOP =========
-- Adjust ambient sounds based on weather, night/day, biome
local ambientCheckAccum = 0

RunService.Heartbeat:Connect(function(dt)
    ambientCheckAccum = ambientCheckAccum + dt
    if ambientCheckAccum < 5 then return end
    ambientCheckAccum = 0

    local isNight = _G.IsNight and _G.IsNight() or false
    local weather = _G.GetCurrentWeather and _G.GetCurrentWeather() or "Clear"

    -- Night drone
    if isNight then
        playAmbient("ambientDrone", true, 0.3)
    else
        stopAmbient("ambientDrone")
    end

    -- Rain/storm sounds
    if weather == "Rain" or weather == "BloodRain" then
        playAmbient("rain", true, 0.4)
    else
        stopAmbient("rain")
    end

    if weather == "Storm" then
        playAmbient("thunder", false, 0.6)
    end
end)

-- ========== CLIENT-REQUESTED SOUNDS =========
-- Client can request a sound to be played (e.g., jump scare, UI click)
PlaySoundRemote.OnServerEvent:Connect(function(player, soundName, position)
    local soundId = SOUNDS[soundName]
    if not soundId or soundId == "rbxassetid://0" then return end

    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 0.5

    if position then
        -- 3D positioned sound
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 1
        part.Position = position
        part.Parent = Workspace
        sound.Parent = part
        sound:Play()
        game:GetService("Debris"):AddItem(part, 10)
    else
        -- Global sound
        sound.Parent = Workspace
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 10)
    end
end)

StopSoundRemote.OnServerEvent:Connect(function(player, soundName)
    stopAmbient(soundName)
end)

-- ========== DELETE ALL ON SHUTDOWN =========
game:BindToClose(function()
    for name, _ in pairs(ambientSounds) do
        stopAmbient(name)
    end
end)

print("[SoundSystem] Loaded ✓")
