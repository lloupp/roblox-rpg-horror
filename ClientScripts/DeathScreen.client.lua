-- ========== DARK SURVIVORS: Death Screen (Client) =========
-- LocalScript: shows death overlay, respawn timer, and handles respawn.
-- Phase 3: replaces default Roblox respawn with a styled death screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateStats = Remotes:WaitForChild("UpdateStats")

-- ========== DEATH GUI =========
local gui = Instance.new("ScreenGui")
gui.Name = "DeathScreen"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player.PlayerGui

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(20, 0, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.ZIndex = 300
overlay.Parent = gui

local vignette = Instance.new("Frame")
vignette.Name = "Vignette"
vignette.Size = UDim2.new(1, 0, 1, 0)
vignette.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
vignette.BackgroundTransparency = 0.3
vignette.BorderSizePixel = 0
vignette.Parent = overlay

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 80)
title.Position = UDim2.new(0, 0, 0.3, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(200, 30, 30)
title.Font = Enum.Font.GothamBlack
title.TextSize = 48
title.Text = "VOCÊ MORREU"
title.ZIndex = 301
title.Parent = overlay

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(1, 0, 0, 30)
subtitle.Position = UDim2.new(0, 0, 0.45, 0)
subtitle.BackgroundTransparency = 1
subtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
subtitle.Font = Enum.Font.GothamBold
subtitle.TextSize = 16
subtitle.Text = "Respawnando em 5..."
subtitle.ZIndex = 301
subtitle.Parent = overlay

local respawnBar = Instance.new("Frame")
respawnBar.Name = "RespawnBar"
respawnBar.Size = UDim2.new(0, 200, 0, 6)
respawnBar.Position = UDim2.new(0.5, -100, 0.55, 0)
respawnBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
respawnBar.BorderSizePixel = 0
respawnBar.ZIndex = 301
respawnBar.Parent = overlay

local respawnFill = Instance.new("Frame")
respawnFill.Name = "Fill"
respawnFill.Size = UDim2.new(0, 0, 1, 0)
respawnFill.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
respawnFill.BorderSizePixel = 0
respawnFill.Parent = respawnBar

-- ========== STATE =========
local isDead = false
local deathTime = 0
local RESPAWN_DELAY = 5  -- seconds

-- ========== TRACK DEATH =========
UpdateStats.OnClientEvent:Connect(function(stats)
    if stats.Health and stats.Health <= 0 and not isDead then
        isDead = true
        deathTime = tick()
        overlay.Visible = true

        -- Fade in overlay
        TweenService:Create(overlay, TweenInfo.new(0.5),
            { BackgroundTransparency = 0.7 }):Play()
        TweenService:Create(vignette, TweenInfo.new(0.3),
            { BackgroundTransparency = 0.1 }):Play()
    end

    if stats.Health and stats.Health > 0 and isDead then
        -- Respawned
        isDead = false
        TweenService:Create(overlay, TweenInfo.new(1),
            { BackgroundTransparency = 1 }):Play()
        task.delay(1, function()
            overlay.Visible = false
        end)
    end
end)

-- ========== RESPAWN COUNTDOWN =========
RunService.RenderStepped:Connect(function()
    if not isDead then return end

    local elapsed = tick() - deathTime
    local remaining = math.max(0, RESPAWN_DELAY - elapsed)

    subtitle.Text = "Respawnando em " .. math.ceil(remaining) .. "..."

    -- Bar fill
    local pct = math.clamp(elapsed / RESPAWN_DELAY, 0, 1)
    respawnFill.Size = UDim2.new(pct, 0, 1, 0)

    -- Auto-respawn: tell server to reset
    if elapsed >= RESPAWN_DELAY then
        -- Request respawn from server via LoadCharacter
        player:LoadCharacter()
        isDead = false
        TweenService:Create(overlay, TweenInfo.new(1),
            { BackgroundTransparency = 1 }):Play()
        task.delay(1, function()
            overlay.Visible = false
        end)
    end
end)

print("[DeathScreen] Loaded ✓")
