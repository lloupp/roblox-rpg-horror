-- ========== DARK SURVIVORS: Enemy AI Module ==========
-- ModuleScript: state machine for Zombie, Shadow, Mutant NPCs

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EnemyAI = {}

-- ========== PLAYER DAMAGE (gap #2) ==========
-- Aplica dano de inimigo respeitando defesa de armadura equipada no alvo.
local function damagePlayer(targetPlayer, rawDamage)
    local char = targetPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return end

    local dmg = rawDamage
    local def = _G.GetDefenseForPlayer and _G.GetDefenseForPlayer(targetPlayer)
    if def and def.defense and def.defense > 0 then
        dmg = dmg * (1 - def.defense / (def.defense + 50))
    end
    hum:TakeDamage(math.floor(dmg))
end

-- ========== ENEMY CONFIGS ==========
local ENEMY_CONFIGS = {
    Zombie = {
        hp = 100,
        walkSpeed = 8,
        attackDamage = 15,
        attackRange = 4,
        attackSpeed = 1.2,
        aggroRange = 20,
        patrolRadius = 30,
        respawnTime = 30,
    },
    Shadow = {
        hp = 40,
        walkSpeed = 22,
        attackDamage = 25,
        attackRange = 4,
        attackSpeed = 0.6,
        aggroRange = 25,
        patrolRadius = 40,
        respawnTime = 30,
        canTeleport = true,
    },
    Mutant = {
        hp = 60,
        walkSpeed = 10,
        attackDamage = 20,
        attackRange = 15, -- ranged
        attackSpeed = 1.5,
        aggroRange = 25,
        patrolRadius = 25,
        respawnTime = 30,
        isRanged = true,
        fleeHealthPct = 0.2,
    },
}

-- ========== STATES ==========
local STATE = {
    IDLE = "Idle",
    PATROL = "Patrol",
    CHASE = "Chase",
    ATTACK = "Attack",
    FLEE = "Flee",
    SEARCH = "Search",
}

-- ========== CREATE ENEMY AI ==========
function EnemyAI.new(npc, enemyType, spawnPosition)
    local config = ENEMY_CONFIGS[enemyType]
    if not config then
        warn("[EnemyAI] Unknown enemy type: " .. tostring(enemyType))
        return nil
    end

    local self = {
        npc = npc,
        config = config,
        enemyType = enemyType,
        spawnPosition = spawnPosition,
        state = STATE.IDLE,
        target = nil,
        lastKnownPosition = nil,
        lastAttackTime = 0,
        patrolTarget = nil,
        stateTimer = 0,
    }

    -- Set NPC properties
    local humanoid = npc:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.MaxHealth = config.hp
        humanoid.Health = config.hp
        humanoid.WalkSpeed = config.walkSpeed
    end

    -- Mark enemy type
    local typeTag = Instance.new("StringValue")
    typeTag.Name = "EnemyType"
    typeTag.Value = enemyType
    typeTag.Parent = npc

    setmetatable(self, { __index = EnemyAI })
    return self
end

-- ========== FIND NEAREST PLAYER ==========
function EnemyAI:findNearestPlayer()
    local nearest = nil
    local nearestDist = self.config.aggroRange

    local rootPart = self.npc:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local playerRoot = player.Character.HumanoidRootPart
            local dist = (rootPart.Position - playerRoot.Position).Magnitude
            if dist < nearestDist then
                nearest = player
                nearestDist = dist
            end
        end
    end

    return nearest, nearestDist
end

-- ========== CHECK LINE OF SIGHT ==========
function EnemyAI:hasLineOfSight(targetPlayer)
    local rootPart = self.npc:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local targetRoot = targetPlayer.Character and
        targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end

    local direction = targetRoot.Position - rootPart.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {self.npc}

    local result = workspace:Raycast(rootPart.Position, direction, rayParams)
    if result then
        return result.Instance:IsDescendantOf(targetPlayer.Character)
    end
    return true
end

-- ========== CHASE / PATHFIND ==========
function EnemyAI:chaseTarget()
    if not self.target then return end
    local targetRoot = self.target.Character and
        self.target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local humanoid = self.npc:FindFirstChild("Humanoid")
    if not humanoid then return end

    -- Simple follow for close range, pathfinding for far
    local rootPart = self.npc:FindFirstChild("HumanoidRootPart")
    local dist = (rootPart.Position - targetRoot.Position).Magnitude

    if dist < 10 then
        humanoid:MoveTo(targetRoot.Position)
    else
        local path = PathfindingService:CreatePath({
            Costs = { Water = 20 },
            AgentCanJump = true,
        })
        path:ComputeAsync(rootPart.Position, targetRoot.Position)
        if path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            for _, wp in ipairs(waypoints) do
                humanoid:MoveTo(wp.Position)
                local reached = humanoid.MoveToFinished:Wait()
                if not reached then break end  -- travou/timeout: evita travamento infinito
            end
        end
    end
end

-- ========== ATTACK ==========
function EnemyAI:attackTarget()
    local humanoid = self.npc:FindFirstChild("Humanoid")
    if not humanoid then return end

    local now = tick()
    if now - self.lastAttackTime < self.config.attackSpeed then return end
    self.lastAttackTime = now

    if not self.target then return end
    local targetHumanoid = self.target.Character and
        self.target.Character:FindFirstChild("Humanoid")
    if not targetHumanoid then return end

    if self.config.isRanged then
        -- Ranged attack (Mutant spit)
        self:spawnProjectile()
    else
        -- Melee attack
        damagePlayer(self.target, self.config.attackDamage)
    end
end

-- ========== RANGED PROJECTILE ==========
function EnemyAI:spawnProjectile()
    local rootPart = self.npc:FindFirstChild("HumanoidRootPart")
    local targetRoot = self.target.Character and
        self.target.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart or not targetRoot then return end

    local projectile = Instance.new("Part")
    projectile.Name = "AcidSpit"
    projectile.Size = Vector3.new(0.3, 0.3, 0.3)
    projectile.Shape = Enum.PartType.Ball
    projectile.Color = Color3.fromRGB(0, 255, 0)
    projectile.Position = rootPart.Position + rootPart.CFrame.LookVector * 2
    projectile.Anchored = false
    projectile.CanCollide = true
    projectile.Parent = workspace

    local direction = (targetRoot.Position - rootPart.Position).Unit
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = direction * 50
    bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bodyVelocity.Parent = projectile

    -- Hit detection
    projectile.Touched:Connect(function(hit)
        local targetChar = hit.Parent
        local player = Players:GetPlayerFromCharacter(targetChar)
        if player then
            local targetHum = targetChar:FindFirstChild("Humanoid")
            if targetHum then
                damagePlayer(player, self.config.attackDamage)
            end
        end
        projectile:Destroy()
    end)

    game:GetService("Debris"):AddItem(projectile, 5)
end

-- ========== PATROL ==========
function EnemyAI:patrol()
    local humanoid = self.npc:FindFirstChild("Humanoid")
    local rootPart = self.npc:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    if not self.patrolTarget or
        (rootPart.Position - self.patrolTarget).Magnitude < 3 then
        -- Pick new patrol point
        local angle = math.random() * math.pi * 2
        local radius = math.random() * self.config.patrolRadius
        self.patrolTarget = self.spawnPosition + Vector3.new(
            math.cos(angle) * radius,
            0,
            math.sin(angle) * radius
        )
    end

    humanoid:MoveTo(self.patrolTarget)
end

-- ========== FLEE ==========
function EnemyAI:flee()
    local humanoid = self.npc:FindFirstChild("Humanoid")
    local rootPart = self.npc:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart or not self.target then return end

    local targetRoot = self.target.Character and
        self.target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    -- Move away from target
    local fleeDir = (rootPart.Position - targetRoot.Position).Unit * 30
    humanoid:MoveTo(rootPart.Position + fleeDir)
end

-- ========== SHADOW TELEPORT ==========
function EnemyAI:tryTeleport()
    if not self.config.canTeleport then return false end

    if not self:hasLineOfSight(self.target) then
        -- Teleport behind target
        local targetRoot = self.target.Character and
            self.target.Character:FindFirstChild("HumanoidRootPart")
        local rootPart = self.npc:FindFirstChild("HumanoidRootPart")
        if targetRoot and rootPart then
            local behindPos = targetRoot.Position -
                targetRoot.CFrame.LookVector * 8
            rootPart.CFrame = CFrame.new(behindPos)
            return true
        end
    end
    return false
end

-- ========== MAIN UPDATE ==========
function EnemyAI:update(dt)
    local humanoid = self.npc:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local rootPart = self.npc:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    -- Find target
    local nearest, dist = self:findNearestPlayer()

    -- Check flee condition
    local healthPct = humanoid.Health / humanoid.MaxHealth
    local fleeThreshold = self.config.fleeHealthPct or 0

    if healthPct <= fleeThreshold and self.target then
        self.state = STATE.FLEE
        self:flee()
        return
    end

    -- State machine
    if nearest then
        self.target = nearest
        self.lastKnownPosition = nearest.Character and
            nearest.Character:FindFirstChild("HumanoidRootPart") and
            nearest.Character.HumanoidRootPart.Position or nil

        if dist <= self.config.attackRange then
            self.state = STATE.ATTACK
            self:attackTarget()
        elseif self:hasLineOfSight(nearest) then
            self.state = STATE.CHASE
            self:chaseTarget()
        else
            self.state = STATE.SEARCH
            if self:tryTeleport() then
                self.state = STATE.CHASE
                self:chaseTarget()
            elseif self.lastKnownPosition then
                humanoid:MoveTo(self.lastKnownPosition)
            end
        end
    else
        self.target = nil
        self.state = STATE.PATROL
        self:patrol()
    end
end

-- ========== RESPAWN ==========
function EnemyAI:respawn()
    wait(self.config.respawnTime)

    local humanoid = self.npc:FindFirstChild("Humanoid")
    local rootPart = self.npc:FindFirstChild("HumanoidRootPart")
    if humanoid and rootPart then
        humanoid.Health = self.config.hp
        rootPart.CFrame = CFrame.new(self.spawnPosition)
        self.state = STATE.IDLE
        self.target = nil
    end
end

return EnemyAI
