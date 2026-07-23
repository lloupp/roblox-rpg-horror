-- ========== DARK SURVIVORS: HUD (Client) =========
-- LocalScript: status bars, hotbar, inventory/crafting panels, input handling.
-- Phase 2: InventoryUpdate listener, hotbar use, attack (click), block (F),
--          sprint (Shift), place trap (G), throw (T).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Mouse = Players.LocalPlayer:GetMouse()

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateStats = Remotes:WaitForChild("UpdateStats")
local DamageNumber = Remotes:WaitForChild("DamageNumber")
local InventoryUpdate = Remotes:WaitForChild("InventoryUpdate")
local InventoryAction = Remotes:WaitForChild("InventoryAction")
local AttackRequest = Remotes:WaitForChild("AttackRequest")
local CraftingResult = Remotes:WaitForChild("CraftingResult")

-- Local references for remotes created by other systems
local function getRemote(name)
    return Remotes:FindFirstChild(name)
end

-- ========== STATE ==========
local currentStats = {
    Health = 100, MaxHealth = 100,
    Hunger = 100, Thirst = 100, Sanity = 100, Stamina = 100,
}
local inventoryOpen = false
local craftingOpen = false
local hotbarSelection = 1
local isBlocking = false
local isRunning = false

-- Inventory data from server
local inventoryData = {
    slots = {},
    maxSlots = 8,
    equipped = {},
    hotbar = {},
    totalWeight = 0,
    maxWeight = 50,
}

-- ========== GUI ==========
local gui = Instance.new("ScreenGui")
gui.Name = "DarkSurvivorsHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player.PlayerGui

-- ========== HELPER: Create Bar ==========
local function createBar(name, color, yPos, icon)
    local container = Instance.new("Frame")
    container.Name = name .. "Bar"
    container.Size = UDim2.new(0, 200, 0, 20)
    container.Position = UDim2.new(0, 10, 0, yPos)
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    container.BorderSizePixel = 1
    container.BorderColor3 = Color3.fromRGB(60, 60, 60)
    container.Parent = gui

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.Parent = container

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Right
    label.Text = icon .. " 100"
    label.ZIndex = 2
    label.Parent = container

    return container, fill, label
end

-- ========== STATUS BARS ==========
local barData = {}
barData.Health = { createBar("Health", Color3.fromRGB(200, 30, 30), 10, "❤️") }
barData.Hunger = { createBar("Hunger", Color3.fromRGB(200, 120, 20), 35, "🍖") }
barData.Thirst = { createBar("Thirst", Color3.fromRGB(30, 100, 200), 60, "💧") }
barData.Stamina = { createBar("Stamina", Color3.fromRGB(200, 200, 30), 85, "⚡") }
barData.Sanity = { createBar("Sanity", Color3.fromRGB(140, 30, 200), 110, "🧠") }

-- ========== UPDATE BARS ==========
local function updateBars()
    for stat, data in pairs(barData) do
        local container, fill, label = unpack(data)
        local value = currentStats[stat] or 100
        local maxVal = stat == "Health" and (currentStats.MaxHealth or 100) or 100
        local pct = math.clamp(value / maxVal, 0, 1)

        TweenService:Create(fill, TweenInfo.new(0.3),
            { Size = UDim2.new(pct, 0, 1, 0) }):Play()

        local icons = { Health = "❤️", Hunger = "🍖", Thirst = "💧",
                        Stamina = "⚡", Sanity = "🧠" }
        label.Text = (icons[stat] or "") .. " " .. math.floor(value)

        if stat == "Sanity" and value < 30 then
            local pulse = (math.sin(tick() * 4) + 1) / 2
            fill.BackgroundColor3 = Color3.fromRGB(
                140 + pulse * 115, 30, 200)
        end
    end
end

-- ========== HOTBAR ==========
local hotbarFrame = Instance.new("Frame")
hotbarFrame.Name = "Hotbar"
hotbarFrame.Size = UDim2.new(0, 240, 0, 60)
hotbarFrame.Position = UDim2.new(0.5, -120, 1, -70)
hotbarFrame.BackgroundTransparency = 0.5
hotbarFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
hotbarFrame.BorderSizePixel = 0
hotbarFrame.Parent = gui

local hotbarSlots = {}
local hotbarLabels = {}
for i = 1, 4 do
    local slot = Instance.new("Frame")
    slot.Name = "Slot" .. i
    slot.Size = UDim2.new(0, 55, 0, 55)
    slot.Position = UDim2.new(0, (i-1) * 60 + 2, 0, 2)
    slot.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    slot.BorderSizePixel = 1
    slot.BorderColor3 = Color3.fromRGB(80, 80, 80)
    slot.Parent = hotbarFrame

    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size = UDim2.new(0, 15, 0, 15)
    keyLabel.Position = UDim2.new(0, 2, 0, 0)
    keyLabel.BackgroundTransparency = 1
    keyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    keyLabel.Font = Enum.Font.GothamBold
    keyLabel.TextSize = 10
    keyLabel.Text = tostring(i)
    keyLabel.Parent = slot

    local itemLabel = Instance.new("TextLabel")
    itemLabel.Size = UDim2.new(1, 0, 1, 0)
    itemLabel.BackgroundTransparency = 1
    itemLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    itemLabel.Font = Enum.Font.GothamBold
    itemLabel.TextSize = 9
    itemLabel.Text = ""
    itemLabel.Parent = slot

    hotbarSlots[i] = slot
    hotbarLabels[i] = itemLabel
end

local function updateHotbarHighlight()
    for i, slot in ipairs(hotbarSlots) do
        if i == hotbarSelection then
            slot.BorderColor3 = Color3.fromRGB(255, 50, 50)
        else
            slot.BorderColor3 = Color3.fromRGB(80, 80, 80)
        end
    end
end
updateHotbarHighlight()

-- ========== UPDATE HOTBAR CONTENT ==========
local function updateHotbarContent()
    for i = 1, 4 do
        local slotIdx = inventoryData.hotbar[i]
        local label = hotbarLabels[i]
        if slotIdx and inventoryData.slots[slotIdx] then
            local item = inventoryData.slots[slotIdx]
            label.Text = item.itemId:sub(1, 8) .. "\n" .. (item.count or 1)
        else
            label.Text = ""
        end
    end
end

-- ========== CROSSHAIR ==========
local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.Size = UDim2.new(0, 4, 0, 4)
crosshair.Position = UDim2.new(0.5, -2, 0.5, -2)
crosshair.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
crosshair.BackgroundTransparency = 0.3
crosshair.BorderSizePixel = 0
crosshair.Parent = gui

local crossCorner = Instance.new("UICorner")
crossCorner.CornerRadius = UDim.new(1, 0)
crossCorner.Parent = crosshair

-- ========== CLOCK / DAY-NIGHT ==========
local clockFrame = Instance.new("Frame")
clockFrame.Name = "Clock"
clockFrame.Size = UDim2.new(0, 100, 0, 30)
clockFrame.Position = UDim2.new(1, -110, 0, 10)
clockFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
clockFrame.BackgroundTransparency = 0.3
clockFrame.BorderSizePixel = 0
clockFrame.Parent = gui

local clockLabel = Instance.new("TextLabel")
clockLabel.Size = UDim2.new(1, 0, 1, 0)
clockLabel.BackgroundTransparency = 1
clockLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
clockLabel.Font = Enum.Font.GothamBold
clockLabel.TextSize = 12
clockLabel.Text = "☀️ 12:00"
clockLabel.Parent = clockFrame

-- ========== INTERACTION PROMPT ==========
local promptFrame = Instance.new("Frame")
promptFrame.Name = "InteractPrompt"
promptFrame.Size = UDim2.new(0, 200, 0, 30)
promptFrame.Position = UDim2.new(0.5, -100, 0.7, 0)
promptFrame.BackgroundTransparency = 1
promptFrame.Visible = false
promptFrame.Parent = gui

local promptLabel = Instance.new("TextLabel")
promptLabel.Size = UDim2.new(1, 0, 1, 0)
promptLabel.BackgroundTransparency = 1
promptLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
promptLabel.TextStrokeTransparency = 0
promptLabel.Font = Enum.Font.GothamBold
promptLabel.TextSize = 14
promptLabel.Text = "[E] Pick Up"
promptLabel.Parent = promptFrame

-- ========== INVENTORY PANEL ==========
local invFrame = Instance.new("Frame")
invFrame.Name = "Inventory"
invFrame.Size = UDim2.new(0, 350, 0, 300)
invFrame.Position = UDim2.new(0.5, -175, 0.5, -150)
invFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
invFrame.BackgroundTransparency = 0.1
invFrame.BorderSizePixel = 1
invFrame.BorderColor3 = Color3.fromRGB(100, 30, 30)
invFrame.Visible = false
invFrame.Parent = gui

local invTitle = Instance.new("TextLabel")
invTitle.Size = UDim2.new(1, 0, 0, 30)
invTitle.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
invTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
invTitle.Font = Enum.Font.GothamBold
invTitle.TextSize = 16
invTitle.Text = "INVENTORY"
invTitle.BorderSizePixel = 0
invTitle.Parent = invFrame

-- Grid slots (4 columns)
local invSlots = {}
for row = 0, 3 do
    for col = 0, 3 do
        local slot = Instance.new("Frame")
        slot.Size = UDim2.new(0, 75, 0, 60)
        slot.Position = UDim2.new(0, col * 80 + 10, 0, row * 65 + 40)
        slot.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        slot.BorderSizePixel = 1
        slot.BorderColor3 = Color3.fromRGB(60, 60, 60)
        slot.Parent = invFrame
        table.insert(invSlots, slot)
    end
end

-- ========== CRAFTING PANEL ==========
local craftFrame = Instance.new("Frame")
craftFrame.Name = "Crafting"
craftFrame.Size = UDim2.new(0, 300, 0, 350)
craftFrame.Position = UDim2.new(0.5, 150, 0.5, -175)
craftFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
craftFrame.BackgroundTransparency = 0.1
craftFrame.BorderSizePixel = 1
craftFrame.BorderColor3 = Color3.fromRGB(100, 30, 30)
craftFrame.Visible = false
craftFrame.Parent = gui

local craftTitle = Instance.new("TextLabel")
craftTitle.Size = UDim2.new(1, 0, 0, 30)
craftTitle.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
craftTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
craftTitle.Font = Enum.Font.GothamBold
craftTitle.TextSize = 16
craftTitle.Text = "CRAFTING"
craftTitle.BorderSizePixel = 0
craftTitle.Parent = craftFrame

-- ========== EQUIPPED INDICATOR ==========
local equipFrame = Instance.new("Frame")
equipFrame.Name = "EquipInfo"
equipFrame.Size = UDim2.new(0, 200, 0, 25)
equipFrame.Position = UDim2.new(0, 10, 0, 135)
equipFrame.BackgroundTransparency = 1
equipFrame.Parent = gui

local equipLabel = Instance.new("TextLabel")
equipLabel.Size = UDim2.new(1, 0, 1, 0)
equipLabel.BackgroundTransparency = 1
equipLabel.TextColor3 = Color3.fromRGB(200, 160, 100)
equipLabel.Font = Enum.Font.GothamBold
equipLabel.TextSize = 12
equipLabel.TextXAlignment = Enum.TextXAlignment.Left
equipLabel.Text = ""
equipLabel.Parent = equipFrame

-- ========== STAT SYNC ==========
UpdateStats.OnClientEvent:Connect(function(stats)
    currentStats = stats
end)

-- ========== INVENTORY SYNC ==========
InventoryUpdate.OnClientEvent:Connect(function(data)
    inventoryData = data
    updateHotbarContent()
    -- Update equip label
    local equipped = data.equipped or {}
    local equipTexts = {}
    if equipped.weapon then table.insert(equipTexts, "⚔️ " .. equipped.weapon) end
    if equipped.armor then table.insert(equipTexts, "🛡️ " .. equipped.armor) end
    if equipped.tool then table.insert(equipTexts, "🔧 " .. equipped.tool) end
    equipLabel.Text = table.concat(equipTexts, "  ")
end)

-- ========== TIME UPDATE ==========
local TimeUpdate = Remotes:WaitForChild("TimeUpdate")
TimeUpdate.OnClientEvent:Connect(function(data)
    local h = math.floor(data.clockTime)
    local m = math.floor((data.clockTime % 1) * 60)
    local icon = data.isNight and "🌙" or "☀️"
    clockLabel.Text = icon .. " " .. string.format("%02d:%02d", h, m)
end)

-- ========== CRAFTING RESULT ==========
local function showCraftResult(msg)
    task.spawn(function()
        local resultLabel = Instance.new("TextLabel")
        resultLabel.Size = UDim2.new(0, 250, 0, 30)
        resultLabel.Position = UDim2.new(0.5, -125, 0, 200)
        resultLabel.BackgroundTransparency = 0.3
        resultLabel.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
        resultLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        resultLabel.Font = Enum.Font.GothamBold
        resultLabel.TextSize = 14
        resultLabel.Text = msg
        resultLabel.Parent = gui
        wait(2)
        for i = 0, 1, 0.1 do
            resultLabel.TextTransparency = i
            resultLabel.BackgroundTransparency = 0.3 + i * 0.7
            wait(0.05)
        end
        resultLabel:Destroy()
    end)
end

if CraftingResult then
    CraftingResult.OnClientEvent:Connect(function(data)
        local msg = data.message or (data.success and "Crafted!" or "Failed")
        showCraftResult(msg)
    end)
end

-- ========== DAMAGE NUMBERS ==========
DamageNumber.OnClientEvent:Connect(function(data)
    local dmgLabel = Instance.new("TextLabel")
    dmgLabel.Size = UDim2.new(0, 100, 0, 30)
    dmgLabel.BackgroundTransparency = 1
    dmgLabel.TextColor3 = data.isCrit and Color3.fromRGB(255, 255, 0) or
        Color3.fromRGB(255, 50, 50)
    dmgLabel.Font = Enum.Font.GothamBold
    dmgLabel.TextSize = data.isCrit and 24 or 18
    dmgLabel.Text = (data.isCrit and "CRIT " or "") .. tostring(data.damage)
    dmgLabel.Parent = gui

    dmgLabel.Position = UDim2.new(0.5, math.random(-50, 50), 0.5, -20)

    task.spawn(function()
        for i = 1, 20 do
            dmgLabel.Position = dmgLabel.Position + UDim2.new(0, 0, 0, -2)
            dmgLabel.TextTransparency = i / 20
            wait(0.05)
        end
        dmgLabel:Destroy()
    end)
end)

-- ========== INPUT ==========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    -- Hotbar keys 1-4
    if input.KeyCode == Enum.KeyCode.One then
        hotbarSelection = 1
        updateHotbarHighlight()
    elseif input.KeyCode == Enum.KeyCode.Two then
        hotbarSelection = 2
        updateHotbarHighlight()
    elseif input.KeyCode == Enum.KeyCode.Three then
        hotbarSelection = 3
        updateHotbarHighlight()
    elseif input.KeyCode == Enum.KeyCode.Four then
        hotbarSelection = 4
        updateHotbarHighlight()

    -- Use hotbar item (R = use equipped hotbar slot)
    elseif input.KeyCode == Enum.KeyCode.R then
        local slotIdx = inventoryData.hotbar[hotbarSelection]
        if slotIdx then
            InventoryAction:FireServer("use", { slotIndex = slotIdx })
        end

    -- Toggle inventory (I)
    elseif input.KeyCode == Enum.KeyCode.I then
        inventoryOpen = not inventoryOpen
        invFrame.Visible = inventoryOpen

    -- Toggle crafting (C)
    elseif input.KeyCode == Enum.KeyCode.C then
        craftingOpen = not craftingOpen
        craftFrame.Visible = craftingOpen

    -- Sprint (Left Shift) - Phase 2
    elseif input.KeyCode == Enum.KeyCode.LeftShift then
        isRunning = true
        local runToggle = getRemote("ToggleRun")
        if runToggle then runToggle:FireServer(true) end

    -- Block toggle (F) - Phase 2
    elseif input.KeyCode == Enum.KeyCode.F then
        isBlocking = not isBlocking
        local blockRemote = getRemote("ToggleBlock")
        if blockRemote then blockRemote:FireServer(isBlocking) end
    end
end)

-- ========== SPRINT RELEASE ==========
UserInputService.InputEnded:Connect(function(input, processed)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        isRunning = false
        local runToggle = getRemote("ToggleRun")
        if runToggle then runToggle:FireServer(false) end
    end
end)

-- ========== MOUSE INPUT (Attack) - Phase 2 ==========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    -- Left click = attack with equipped weapon
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local equipped = inventoryData.equipped and inventoryData.equipped.weapon
        if equipped then
            AttackRequest:FireServer(equipped)
        end
    end
end)

-- ========== RENDER LOOP ==========
RunService.RenderStepped:Connect(function()
    updateBars()
end)

print("[HUD] Loaded ✓")
