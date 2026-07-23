-- ========== DARK SURVIVORS: Horror Effects (Client) ==========
-- LocalScript: visual distortion, sanity effects, jump scares, hallucinations

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HorrorEvent = Remotes:WaitForChild("HorrorEvent")
local SanityEffect = Remotes:WaitForChild("SanityEffect")
local JumpScare = Remotes:WaitForChild("JumpScare")
local UpdateStats = Remotes:WaitForChild("UpdateStats")

-- ========== CURRENT SANITY ==========
local currentSanity = 100
local currentStats = {}

-- ========== GUI FRAMEWORK ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HorrorFX"
screenGui.ResetOnSpawn = false
screenGui.Parent = player.PlayerGui

-- Vignette overlay (red/blood at low HP/sanity)
local vignette = Instance.new("Frame")
vignette.Name = "Vignette"
vignette.Size = UDim2.new(1, 0, 1, 0)
vignette.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
vignette.BackgroundTransparency = 1
vignette.BorderSizePixel = 0
vignette.ZIndex = 100
vignette.Parent = screenGui

-- Use UICorner for circular vignette effect
local vignetteCorner = Instance.new("UICorner")
vignetteCorner.CornerRadius = UDim.new(0, 0)
vignetteCorner.Parent = vignette

-- Distortion overlay
local distortion = Instance.new("Frame")
distortion.Name = "DistortionFrame"
distortion.Size = UDim2.new(1, 0, 1, 0)
distortion.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
distortion.BackgroundTransparency = 1
distortion.BorderSizePixel = 0
distortion.ZIndex = 99
distortion.Parent = screenGui

-- Film grain frame
local grain = Instance.new("Frame")
grain.Name = "FilmGrain"
grain.Size = UDim2.new(1, 0, 1, 0)
grain.BackgroundColor3 = Color3.fromRGB(128, 128, 128)
grain.BackgroundTransparency = 1
grain.BorderSizePixel = 0
grain.ZIndex = 98
grain.Parent = screenGui

-- Jump scare full screen
local jumpScareFrame = Instance.new("Frame")
jumpScareFrame.Name = "JumpScare"
jumpScareFrame.Size = UDim2.new(1, 0, 1, 0)
jumpScareFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
jumpScareFrame.BackgroundTransparency = 1
jumpScareFrame.BorderSizePixel = 0
jumpScareFrame.ZIndex = 200
jumpScareFrame.Visible = false
jumpScareFrame.Parent = screenGui

local jumpScareText = Instance.new("TextLabel")
jumpScareText.Size = UDim2.new(1, 0, 1, 0)
jumpScareText.BackgroundTransparency = 1
jumpScareText.TextColor3 = Color3.fromRGB(255, 0, 0)
jumpScareText.TextSize = 100
jumpScareText.Font = Enum.Font.GothamBold
jumpScareText.Text = "💀"
jumpScareText.ZIndex = 201
jumpScareText.Parent = jumpScareFrame

-- ========== STAT SYNC ==========
UpdateStats.OnClientEvent:Connect(function(stats)
    currentStats = stats
    if stats.Sanity then currentSanity = stats.Sanity end
end)

-- ========== VIGNETTE / LOW-HEALTH EFFECT ==========
RunService.RenderStepped:Connect(function()
    local healthPct = (currentStats.Health or 100) / (currentStats.MaxHealth or 100)

    -- Red vignette at low health
    if healthPct < 0.3 then
        local intensity = (0.3 - healthPct) / 0.3
        vignette.BackgroundTransparency = 1 - (intensity * 0.5)
    else
        vignette.BackgroundTransparency = 1
    end

    -- Sanity-based distortion
    local sanityPct = currentSanity / 100
    local distortionIntensity = (1 - sanityPct) -- 0 at 100 sanity, 1 at 0

    -- Chromatic aberration / color shift (approximated via color tint)
    if distortionIntensity > 0.3 then
        distortion.BackgroundColor3 = Color3.fromRGB(
            math.floor(distortionIntensity * 60),
            0,
            0
        )
        distortion.BackgroundTransparency = 1 - (distortionIntensity * 0.3)
    else
        distortion.BackgroundTransparency = 1
    end

    -- Film grain (subtle noise overlay)
    if distortionIntensity > 0.2 then
        grain.BackgroundTransparency = 1 - (distortionIntensity * 0.15)
        -- Randomize color for grain effect
        if math.random() < 0.3 then
            local v = math.random(100, 180)
            grain.BackgroundColor3 = Color3.fromRGB(v, v, v)
        end
    else
        grain.BackgroundTransparency = 1
    end

    -- Camera FOV shift at very low sanity (breathing effect)
    if currentSanity < 30 then
        local breath = math.sin(tick() * 2) * distortionIntensity * 5
        camera.FieldOfView = 70 + breath
    else
        camera.FieldOfView = 70
    end
end)

-- ========== SANITY EFFECT (from server) ==========
SanityEffect.OnClientEvent:Connect(function(sanity)
    currentSanity = sanity
    -- Additional visual burst when crossing sanity threshold
    if sanity < 30 then
        -- Heavy pulse
        local tween = TweenService:Create(vignette,
            TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
            { BackgroundTransparency = 0.3 })
        tween:Play()
        tween.Completed:Connect(function()
            TweenService:Create(vignette, TweenInfo.new(1),
                { BackgroundTransparency = 0.7 }):Play()
        end)
    end
end)

-- ========== HORROR EVENTS (from server) ==========
HorrorEvent.OnClientEvent:Connect(function(data)
    local eventType = data.type
    local eventName = data.event
    local intensity = data.intensity or 0.5

    if eventType == "sanity" then
        if eventName == "Whispers" then
            -- Subtle audio/visual cue (would need Sound objects)
            playScreenFlicker(0.1)
        elseif eventName == "ScreenFlicker" then
            playScreenFlicker(0.3)
        elseif eventName == "FakeEnemy" then
            spawnFakeEntity()
        elseif eventName == "HeavyDistortion" then
            playScreenFlicker(0.5)
            shakeCamera(0.5)
        elseif eventName == "FakeJumpscare" then
            playFakeJumpscare()
        elseif eventName == "UI_Lies" then
            -- UI lies handled in HUD script
        end

    elseif eventType == "random" then
        if eventName == "FootstepsBehind" then
            playScreenFlicker(0.05)
        elseif eventName == "ShadowFigure" then
            spawnFakeEntity()
        elseif eventName == "PowerFailure" then
            triggerPowerFailure()
        elseif eventName == "BleedingWalls" then
            tintWorld(Color3.fromRGB(80, 0, 0), 3)
        elseif eventName == "MusicBox" then
            playScreenFlicker(0.02)
        elseif eventName == "DoorSlam" then
            shakeCamera(0.3)
        end

    elseif eventType == "zone" then
        if eventName == "HospitalEntry" then
            tintWorld(Color3.fromRGB(50, 20, 20), 5)
            shakeCamera(0.2)
        elseif eventName == "CaveEntry" then
            tintWorld(Color3.fromRGB(0, 0, 30), 3)
        end
    end
end)

-- ========== JUMP SCARES ==========
JumpScare.OnClientEvent:Connect(function(data)
    jumpScareFrame.Visible = true
    jumpScareFrame.BackgroundTransparency = 0

    -- Different scare types
    local scareTexts = {"💀", "👁️", "☠️"}
    jumpScareText.Text = scareTexts[data.type] or "💀"

    shakeCamera(1)

    -- Flash white then fade
    jumpScareFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    wait(0.05)
    jumpScareFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

    task.spawn(function()
        wait(data.duration or 0.3)
        TweenService:Create(jumpScareFrame, TweenInfo.new(0.5),
            { BackgroundTransparency = 1 }):Play()
        wait(0.5)
        jumpScareFrame.Visible = false
    end)
end)

-- ========== HELPER FUNCTIONS ==========

function playScreenFlicker(intensity)
    task.spawn(function()
        for i = 1, math.floor(intensity * 10) do
            distortion.BackgroundTransparency = 0.5 - intensity
            wait(0.05)
            distortion.BackgroundTransparency = 1
            wait(math.random() * 0.1)
        end
    end)
end

function shakeCamera(intensity)
    task.spawn(function()
        local origCFrame = camera.CFrame
        for i = 1, 10 do
            local offset = Vector3.new(
                (math.random() - 0.5) * intensity,
                (math.random() - 0.5) * intensity,
                0
            )
            camera.CFrame = camera.CFrame * CFrame.new(offset)
            wait(0.03)
        end
    end)
end

function spawnFakeEntity()
    task.spawn(function()
        -- Create a brief shadow figure
        local figure = Instance.new("Part")
        figure.Name = "Hallucination"
        figure.Size = Vector3.new(2, 5, 1)
        figure.Anchored = true
        figure.CanCollide = false
        figure.Transparency = 0.3
        figure.Color = Color3.fromRGB(20, 20, 20)
        figure.Material = Enum.Material.SmoothPlastic

        -- Place in front of player, 20 studs away
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local pos = root.Position + root.CFrame.LookVector * 20
                figure.CFrame = CFrame.new(pos)
                figure.Parent = Workspace

                -- Dissolve when player gets close
                task.spawn(function()
                    while figure and figure.Parent do
                        if root and (root.Position - figure.Position).Magnitude < 8 then
                            -- Dissolve
                            for t = 0.3, 1, 0.05 do
                                figure.Transparency = t
                                wait()
                            end
                            figure:Destroy()
                            break
                        end
                        wait(0.1)
                    end
                end)

                -- Despawn after 10 sec anyway
                game:GetService("Debris"):AddItem(figure, 10)
            end
        end
    end)
end

function triggerPowerFailure()
    task.spawn(function()
        -- Notify server to kill lights for 5 seconds
        local toolAction = Remotes:FindFirstChild("ToolAction")
        if toolAction then
            toolAction:FireServer("powerFailure", 5)
        end
        -- Brief blackout effect
        distortion.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        distortion.BackgroundTransparency = 0.3
        wait(0.5)
        distortion.BackgroundTransparency = 1
    end)
end

function tintWorld(color, duration)
    task.spawn(function()
        local origAmbient = Lighting.Ambient
        Lighting.Ambient = color
        wait(duration)
        Lighting.Ambient = origAmbient
    end)
end

function playFakeJumpscare()
    task.spawn(function()
        distortion.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        distortion.BackgroundTransparency = 0.5
        shakeCamera(0.5)
        wait(0.2)
        distortion.BackgroundTransparency = 1
    end)
end

print("[HorrorEffects] Loaded ✓")
