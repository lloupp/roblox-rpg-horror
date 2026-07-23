-- ========== DARK SURVIVORS: Combat System ==========
-- Server-side: melee/ranged combat, damage, blocking, criticals, loot

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = ReplicatedStorage
end

local function ensureRemote(name, className)
    local r = Remotes:FindFirstChild(name)
    if not r then
        r = Instance.new(className)
        r.Name = name
        r.Parent = Remotes
    end
    return r
end

local AttackRequest = ensureRemote("AttackRequest", "RemoteEvent")
local AttackResult = ensureRemote("AttackResult", "RemoteEvent")
local DamageNumber = ensureRemote("DamageNumber", "RemoteEvent")
local BlockToggle = ensureRemote("ToggleBlock", "RemoteEvent")
local EquipRemote = ensureRemote("EquipWeapon", "RemoteEvent")

-- ========== WEAPON DATA ==========
local WEAPONS = {
    KitchenKnife = { damage = 15, range = 3, speed = 0.4, type = "melee" },
    FireAxe = { damage = 25, range = 4, speed = 0.8, type = "melee" },
    Machete = { damage = 20, range = 3.5, speed = 0.5, type = "melee" },
    Crowbar = { damage = 12, range = 3, speed = 0.5, type = "melee" },
    Shotgun = { damage = 50, range = 30, speed = 1.5, type = "ranged", ammo = 8, maxAmmo = 8 },
}

local CRIT_CHANCE = 0.15
local CRIT_MULTIPLIER = 2
local BLOCK_REDUCTION = 0.6

-- ========== PLAYER COMBAT STATE ==========
local combatState = {}

local function initCombatState(player)
    combatState[player.UserId] = {
        equippedWeapon = nil,
        isBlocking = false,
        lastAttackTime = 0,
        ammo = {},
    }
end

-- ========== DAMAGE CALC ==========
local function calculateDamage(weapon, isCrit, isBlocked)
    local dmg = weapon.damage
    if isCrit then dmg = dmg * CRIT_MULTIPLIER end
    if isBlocked then dmg = dmg * (1 - BLOCK_REDUCTION) end
    return math.floor(dmg)
end

-- ========== RAYCAST ==========
local function raycastAttack(player, weapon)
    local character = player.Character
    if not character then return nil end
    local head = character:FindFirstChild("Head")
    if not head then return nil end

    local origin = head.Position
    local direction = head.CFrame.LookVector * weapon.range

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {character}

    return Workspace:Raycast(origin, direction, rayParams)
end

-- ========== LOOT TABLES ==========
local ENEMY_LOOT = {
    Zombie = { "Cloth", "Cloth", "DuctTape", "RawMeat" },
    Shadow = { "Chemical", "Wire", "Glass" },
    Mutant = { "Chemical", "Chemical", "Metal", "Glass" },
}

local function dropLoot(enemyType, position)
    local lootTable = ENEMY_LOOT[enemyType]
    if not lootTable then return end

    for i = 1, math.random(1, 2) do
        local itemName = lootTable[math.random(1, #lootTable)]
        local part = Instance.new("Part")
        part.Name = itemName
        part.Size = Vector3.new(0.5, 0.5, 0.5)
        part.Position = position + Vector3.new(
            math.random(-2, 2), 2, math.random(-2, 2)
        )
        part.Anchored = false
        part.CanCollide = true
        part.BrickColor = BrickColor.new("Bright yellow")
        part.Parent = Workspace

        local itemValue = Instance.new("StringValue")
        itemValue.Name = "ItemName"
        itemValue.Value = itemName
        itemValue.Parent = part

        game:GetService("Debris"):AddItem(part, 60)
    end
end

-- ========== ATTACK HANDLER =========
AttackRequest.OnServerEvent:Connect(function(player, weaponName)
    local cs = combatState[player.UserId]
    if not cs then return end

    -- Bug #5: valida que o jogador realmente tem a arma equipada.
    -- Antes o cliente podia atacar com qualquer arma sem a possuir.
    local equipped = _G.GetEquippedWeapon and _G.GetEquippedWeapon(player)
    if not equipped or equipped ~= weaponName then
        return
    end

    local weapon = WEAPONS[weaponName]
    if not weapon then return end

    local now = tick()
    if now - cs.lastAttackTime < weapon.speed then return end
    cs.lastAttackTime = now

    if weapon.type == "ranged" then
        local ammo = cs.ammo[weaponName] or weapon.ammo
        if ammo <= 0 then return end
        cs.ammo[weaponName] = ammo - 1
    end

    local result = raycastAttack(player, weapon)
    if not result then
        AttackResult:FireClient(player, { hit = false, weapon = weaponName })
        return
    end

    local hitInstance = result.Instance
    local hitPosition = result.Position

    local targetHumanoid = nil
    local targetCharacter = hitInstance.Parent

    if targetCharacter then
        targetHumanoid = targetCharacter:FindFirstChild("Humanoid")
    end
    if not targetHumanoid and hitInstance.Parent.Parent then
        targetHumanoid = hitInstance.Parent.Parent:FindFirstChild("Humanoid")
    end

    if not targetHumanoid or targetHumanoid.Health <= 0 then
        AttackResult:FireClient(player, { hit = false, weapon = weaponName })
        return
    end

    local isCrit = math.random() < CRIT_CHANCE
    local isBlocked = false

    local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
    if targetPlayer then
        local targetCS = combatState[targetPlayer.UserId]
        if targetCS and targetCS.isBlocking then
            isBlocked = true
        end
    end

    local damage = calculateDamage(weapon, isCrit, isBlocked)

    -- Apply equipped armor defense (gap #2): def/(def+50), + blockBonus se bloqueando
    local def = _G.GetDefenseForPlayer and _G.GetDefenseForPlayer(targetPlayer)
    if def and def.defense and def.defense > 0 then
        damage = damage * (1 - def.defense / (def.defense + 50))
        if isBlocked and def.blockBonus then
            damage = damage * (1 - def.blockBonus)
        end
    end
    damage = math.floor(damage)

    targetHumanoid:TakeDamage(damage)

    AttackResult:FireClient(player, {
        hit = true,
        weapon = weaponName,
        damage = damage,
        isCrit = isCrit,
        isBlocked = isBlocked,
        position = hitPosition,
    })

    -- Damage numbers to nearby players
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("Head") then
            if (p.Character.Head.Position - hitPosition).Magnitude < 50 then
                DamageNumber:FireClient(p, {
                    damage = damage,
                    position = hitPosition,
                    isCrit = isCrit,
                })
            end
        end
    end

    -- Enemy death → loot
    if targetHumanoid.Health <= 0 then
        local enemyType = targetCharacter:FindFirstChild("EnemyType")
        if enemyType then
            local rootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
            local pos = rootPart and rootPart.Position or hitPosition
            dropLoot(enemyType.Value, pos)
        end
    end
end)

-- ========== BLOCK / EQUIP ==========
BlockToggle.OnServerEvent:Connect(function(player, isBlocking)
    local cs = combatState[player.UserId]
    if cs then cs.isBlocking = isBlocking end
end)

EquipRemote.OnServerEvent:Connect(function(player, weaponName)
    local cs = combatState[player.UserId]
    if cs and WEAPONS[weaponName] then
        cs.equippedWeapon = weaponName
        if WEAPONS[weaponName].type == "ranged" and not cs.ammo[weaponName] then
            cs.ammo[weaponName] = WEAPONS[weaponName].ammo
        end
    end
    -- Bug #5: sincroniza inv.equipped.weapon e persiste via DataStore
    local inv = _G.GetInventory and _G.GetInventory(player)
    if inv and WEAPONS[weaponName] then
        inv.equipped = inv.equipped or {}
        inv.equipped.weapon = weaponName
        if _G.MarkDataDirty then _G.MarkDataDirty(player) end
    end
end)

-- ========== PLAYER LIFECYCLE ==========
Players.PlayerAdded:Connect(function(player)
    initCombatState(player)
end)
Players.PlayerRemoving:Connect(function(player)
    combatState[player.UserId] = nil
end)

print("[CombatSystem] Loaded ✓")
