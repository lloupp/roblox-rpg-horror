-- ========== DARK SURVIVORS: Trap & Throwable System =========
-- Server-side: SpikeTrap, ElectricTrap (placeables); Molotov, PoisonBomb,
-- FlashBomb (throwables). Consumes items from inventory, spawns world objects
-- with Touched/region effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

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

-- ========== TRAP CONFIGS =========
local TRAP_CONFIGS = {
    SpikeTrap = {
        damage = 30,
        radius = 3,
        color = Color3.fromRGB(80, 80, 80),
        duration = 120,       -- despawn after 2 min
        triggerCooldown = 1, -- can't hit same target twice in 1 sec
    },
    ElectricTrap = {
        stunDuration = 5,
        damage = 10,
        radius = 3,
        color = Color3.fromRGB(0, 150, 255),
        duration = 90,
        triggerCooldown = 2,
    },
}

-- ========== THROWABLE CONFIGS =========
local THROWABLE_CONFIGS = {
    Molotov = {
        areaDamage = 20,
        radius = 8,
        duration = 5,       -- fire burns for 5 sec
        color = Color3.fromRGB(255, 100, 0),
        fire = true,
    },
    PoisonBomb = {
        areaDamage = 10,
        radius = 6,
        duration = 8,       -- poison cloud lasts 8 sec
        color = Color3.fromRGB(100, 255, 0),
        poison = true,
        poisonDPS = 3,
    },
    FlashBomb = {
        areaDamage = 0,
        radius = 12,
        duration = 3,       -- stun duration on hit
        color = Color3.fromRGB(255, 255, 255),
        stun = true,
        stunDuration = 3,
    },
}

-- ========== PLACE TRAP IN WORLD =========
local function placeTrap(player, itemId, position)
    local config = TRAP_CONFIGS[itemId]
    if not config then return false end

    local trapPart = Instance.new("Part")
    trapPart.Name = "Trap_" .. itemId
    trapPart.Size = Vector3.new(config.radius * 2, 0.5, config.radius * 2)
    trapPart.Position = position
    trapPart.Anchored = true
    trapPart.CanCollide = false
    trapPart.Transparency = 0.3
    trapPart.Color = config.color
    trapPart.Material = Enum.Material.Neon
    trapPart.Parent = Workspace

    local idVal = Instance.new("StringValue")
    idVal.Name = "ItemId"
    idVal.Value = itemId
    idVal.Parent = trapPart

    -- Hit tracking: which characters have been hit recently
    local hitCooldowns = {}

    trapPart.Touched:Connect(function(hit)
        local character = hit.Parent
        local hum = character and character:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then return end

        -- Don't hit the placer
        local hitPlayer = Players:GetPlayerFromCharacter(character)
        if hitPlayer == player then return end

        local charKey = character
        local now = os.time()
        if hitCooldowns[charKey] and now - hitCooldowns[charKey] < config.triggerCooldown then
            return
        end
        hitCooldowns[charKey] = now

        if itemId == "SpikeTrap" then
            -- Check defense of target player
            local dmg = config.damage
            if hitPlayer then
                local def = _G.GetDefenseForPlayer and _G.GetDefenseForPlayer(hitPlayer)
                if def and def.defense and def.defense > 0 then
                    dmg = dmg * (1 - def.defense / (def.defense + 50))
                end
            end
            hum:TakeDamage(math.floor(dmg))
            -- Damage number
            local DamageNumber = ensureRemote("DamageNumber", "RemoteEvent")
            local root = character:FindFirstChild("HumanoidRootPart")
            DamageNumber:FireAllClients({
                damage = math.floor(dmg),
                position = root and root.Position or trapPart.Position,
                isCrit = false,
            })

        elseif itemId == "ElectricTrap" then
            -- Stun: freeze WalkSpeed temporarily
            local origSpeed = hum.WalkSpeed
            local origJump = hum.JumpPower
            hum.WalkSpeed = 0
            if hum.JumpPower then hum.JumpPower = 0 end
            if config.damage > 0 then
                hum:TakeDamage(config.damage)
            end
            -- Visual: blue flash
            trapPart.Color = Color3.fromRGB(255, 255, 255)
            task.delay(0.1, function()
                if trapPart.Parent then trapPart.Color = config.color end
            end)
            task.delay(config.stunDuration, function()
                if hum and hum.Parent then
                    hum.WalkSpeed = origSpeed
                    if hum.JumpPower then hum.JumpPower = origJump end
                end
            end)
        end
    end)

    Debris:AddItem(trapPart, config.duration)
    return true
end

-- ========== THROW PROJECTILE =========
local function throwThrowable(player, itemId, targetPosition)
    local config = THROWABLE_CONFIGS[itemId]
    if not config then return false end

    local char = player.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    -- Create projectile part
    local projectile = Instance.new("Part")
    projectile.Name = "Throwable_" .. itemId
    projectile.Size = Vector3.new(0.5, 0.5, 0.5)
    projectile.Shape = Enum.PartType.Ball
    projectile.Color = config.color
    projectile.Position = root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1.5, 0)
    projectile.Anchored = false
    projectile.CanCollide = true
    projectile.Parent = Workspace

    -- Launch towards target
    local direction = (targetPosition - projectile.Position).Unit
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = direction * 60 + Vector3.new(0, 20, 0)  -- arc
    bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bodyVelocity.Parent = projectile

    local exploded = false
    local function explode()
        if exploded then return end
        exploded = true

        local explodePos = projectile.Position
        projectile:Destroy()

        -- Visual explosion part
        local fx = Instance.new("Part")
        fx.Name = "Explosion_" .. itemId
        fx.Shape = Enum.PartType.Ball
        fx.Size = Vector3.new(1, 1, 1)
        fx.Position = explodePos
        fx.Anchored = true
        fx.CanCollide = false
        fx.Transparency = 0.5
        fx.Color = config.color
        fx.Material = Enum.Material.Neon
        fx.Parent = Workspace

        -- Grow + fade
        if config.fire or config.poison then
            -- Lingering effect (fire/poison cloud)
            for i = 1, config.duration do
                task.wait(1)
                if not fx.Parent then break end
                fx.Size = fx.Size + Vector3.new(0.5, 0.5, 0.5)
                fx.Transparency = fx.Transparency + 0.05

                -- Damage players in radius
                for _, p in ipairs(Players:GetPlayers()) do
                    local pChar = p.Character
                    local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
                    local pHum = pChar and pChar:FindFirstChild("Humanoid")
                    if pRoot and pHum and pHum.Health > 0 then
                        if (pRoot.Position - explodePos).Magnitude <= config.radius then
                            -- Don't apply defense to fire/poison (DoT ignores armor)
                            pHum:TakeDamage(config.areaDamage)
                            if config.poison and _G.ApplyPoison then
                                _G.ApplyPoison(p, config.poisonDPS, config.duration - i + 1)
                            end
                        end
                    end
                end
            end
        else
            -- Instant explosion (FlashBomb)
            fx.Size = Vector3.new(config.radius * 2, config.radius * 2, config.radius * 2)
            task.wait(0.1)
            for i = 1, 10 do
                fx.Transparency = fx.Transparency + 0.08
                task.wait(0.05)
            end

            -- Apply effects instantly in radius
            for _, p in ipairs(Players:GetPlayers()) do
                local pChar = p.Character
                local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
                local pHum = pChar and pChar:FindFirstChild("Humanoid")
                if pRoot and pHum and pHum.Health > 0 then
                    if (pRoot.Position - explodePos).Magnitude <= config.radius then
                        if config.stun then
                            local origSpeed = pHum.WalkSpeed
                            pHum.WalkSpeed = 0
                            task.delay(config.stunDuration, function()
                                if pHum and pHum.Parent then
                                    pHum.WalkSpeed = origSpeed
                                end
                            end)
                        end
                        if config.areaDamage > 0 then
                            pHum:TakeDamage(config.areaDamage)
                        end
                    end
                end
            end
        end

        fx:Destroy()
    end

    -- Explode on impact
    projectile.Touched:Connect(function(hit)
        -- Don't explode on the thrower
        if hit:IsDescendantOf(char) then return end
        explode()
    end)

    -- Fallback: explode after 5 seconds
    Debris:AddItem(projectile, 5)
    task.delay(5, explode)

    return true
end

-- ========== REMOTE: PLACE TRAP / THROW =========
local PlaceAction = ensureRemote("PlaceAction", "RemoteEvent")
PlaceAction.OnServerEvent:Connect(function(player, action, data)
    if action == "placeTrap" then
        -- data = { itemId, position }
        local itemId = data.itemId
        if not TRAP_CONFIGS[itemId] then return end

        -- Validate player has the item
        local inv = _G.GetInventory and _G.GetInventory(player)
        if not inv then return end
        local hasItem = false
        for _, slot in ipairs(inv.slots) do
            if slot and slot.itemId == itemId then
                hasItem = true
                break
            end
        end
        if not hasItem then return end

        -- Consume item from inventory
        if _G.RemoveItem then
            _G.RemoveItem(player, itemId, 1)
        end

        placeTrap(player, itemId, data.position)

    elseif action == "throw" then
        -- data = { itemId, targetPosition }
        local itemId = data.itemId
        if not THROWABLE_CONFIGS[itemId] then return end

        -- Validate + consume
        local inv = _G.GetInventory and _G.GetInventory(player)
        if not inv then return end
        local hasItem = false
        for _, slot in ipairs(inv.slots) do
            if slot and slot.itemId == itemId then
                hasItem = true
                break
            end
        end
        if not hasItem then return end

        if _G.RemoveItem then
            _G.RemoveItem(player, itemId, 1)
        end

        throwThrowable(player, itemId, data.targetPosition)
    end
end)

print("[TrapThrowableSystem] Loaded ✓")
