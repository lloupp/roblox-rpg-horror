-- ========== DARK SURVIVORS: Game Loop System =========
-- Server-side: survival timer, wave progression, leaderboard stats.
-- Phase 4: game loop + progression + global stats.

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

local GameUpdate = ensureRemote("GameUpdate", "RemoteEvent")

-- ========== SESSION DATA =========
-- Per-session survival time + kill count. Persisted to DataStore on leave.
local sessions = {}   -- userId -> { survivalTime = 0, kills = 0, bestTime = 0 }

-- ========== LEADERBOARD =========
-- Uses Roblox leaderboard system (leaderstats)
local function setupLeaderstats(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local survivalTime = Instance.new("IntValue")
    survivalTime.Name = "Sobreviveu"
    survivalTime.Value = 0
    survivalTime.Parent = leaderstats

    local kills = Instance.new("IntValue")
    kills.Name = "Abates"
    kills.Value = 0
    kills.Parent = leaderstats

    -- Load best time from DataStore
    local pd = _G.GetPlayerData and _G.GetPlayerData(player)
    if pd and pd.bestSurvival then
        survivalTime.Value = 0 -- Current session starts at 0; best is separate
    end
end

-- ========== SESSION TRACKING =========
Players.PlayerAdded:Connect(function(player)
    local pd = _G.GetPlayerData and _G.GetPlayerData(player)
    sessions[player.UserId] = {
        survivalTime = 0,
        kills = pd and pd.kills or 0,
        bestTime = pd and pd.bestSurvival or 0,
    }
    setupLeaderstats(player)
end)

Players.PlayerRemoving:Connect(function(player)
    local session = sessions[player.UserId]
    if session then
        -- Persist to DataStore
        local pd = _G.GetPlayerData and _G.GetPlayerData(player)
        if pd then
            pd.kills = session.kills
            -- Update best survival time
            if session.survivalTime > session.bestTime then
                pd.bestSurvival = session.survivalTime
            end
            if _G.MarkDataDirty then _G.MarkDataDirty(player) end
        end
    end
    sessions[player.UserId] = nil
end)

-- ========== MAIN LOOP: survival timer + wave check =========
local survivalAccum = 0
local lastWaveWarning = 0

RunService.Heartbeat:Connect(function(dt)
    survivalAccum = survivalAccum + dt

    for _, player in ipairs(Players:GetPlayers()) do
        local session = sessions[player.UserId]
        if not session then continue end

        local s = _G.GetStats and _G.GetStats(player)
        -- Only count survival time if player is alive
        if s and not s.IsDead then
            session.survivalTime = session.survivalTime + dt

            -- Update leaderstats every second
            if survivalAccum >= 1 then
                local leaderstats = player:FindFirstChild("leaderstats")
                if leaderstats then
                    local surv = leaderstats:FindFirstChild("Sobreviveu")
                    if surv then
                        surv.Value = math.floor(session.survivalTime)
                    end
                end
            end

            -- Sync to client for UI
            if survivalAccum >= 1 then
                GameUpdate:FireClient(player, {
                    survivalTime = math.floor(session.survivalTime),
                    kills = session.kills,
                    bestTime = session.bestTime,
                })
            end
        end
    end

    if survivalAccum >= 1 then survivalAccum = 0 end
end)

-- ========== KILL TRACKING =========
-- Called by CombatSystem when an enemy dies
_G.OnEnemyKill = function(player)
    local session = sessions[player.UserId]
    if session then
        session.kills = session.kills + 1
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local kills = leaderstats:FindFirstChild("Abates")
            if kills then kills.Value = session.kills end
        end
    end
end

print("[GameLoopSystem] Loaded ✓")
