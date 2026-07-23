-- ========== DARK SURVIVORS: Survival System ==========
-- Server-side: manages HP, Hunger, Thirst, Sanity, Stamina

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ensure Remotes folder
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

local UpdateStats = ensureRemote("UpdateStats", "RemoteEvent")
local SanityEffect = ensureRemote("SanityEffect", "RemoteEvent")

-- ========== STAT DEFAULTS ==========
local DEFAULTS = {
    Health = 100,
    MaxHealth = 100,
    Hunger = 100,
    Thirst = 100,
    Sanity = 100,
    Stamina = 100,
}

-- ========== DECAY RATES ==========
local HUNGER_DECAY = 1        -- per 5 sec
local THIRST_DECAY = 1        -- per 3 sec
local STAMINA_REGEN = 2       -- per sec
local STAMINA_DRAIN = 1       -- per sec (running)
local HUNGER_DAMAGE = 2       -- per sec at 0 hunger
local THIRST_DAMAGE = 3       -- per sec at 0 thirst

local WALK_SPEED = 12
local RUN_SPEED = 20

-- ========== PLAYER DATA ==========
local playerStats = {}

local function clamp(val, min, max)
    return math.clamp(val, min, max)
end

local function initPlayer(player)
    -- Bug #3: restaura stats do DataStore em vez de sempre usar DEFAULTS.
    local pd = _G.GetPlayerData and _G.GetPlayerData(player)
    local saved = pd and pd.stats or {}

    playerStats[player.UserId] = {
        Health = saved.Health or DEFAULTS.Health,
        MaxHealth = saved.MaxHealth or DEFAULTS.MaxHealth,
        Hunger = saved.Hunger or DEFAULTS.Hunger,
        Thirst = saved.Thirst or DEFAULTS.Thirst,
        Sanity = saved.Sanity or DEFAULTS.Sanity,
        Stamina = saved.Stamina or DEFAULTS.Stamina,
        IsRunning = false,
        IsDead = false,
        -- Phase 2: temporary status effects
        PoisonStacks = 0,        -- ticks de veneno restantes
        PoisonDPS = 0,           -- dano por tick de veneno
        SpeedBoostEnds = 0,      -- os.time() quando o boost expira
        SpeedBoostMult = 1,      -- multiplicador de speed (1 = sem boost)
    }
end

local function getStats(player)
    return playerStats[player.UserId]
end

local function syncStats(player)
    local s = getStats(player)
    if s then
        UpdateStats:FireClient(player, {
            Health = s.Health,
            MaxHealth = s.MaxHealth,
            Hunger = s.Hunger,
            Thirst = s.Thirst,
            Sanity = s.Sanity,
            Stamina = s.Stamina,
        })
    end
end

-- ========== FOOD / DRINK EFFECTS ==========
local FOOD_EFFECTS = {
    CannedBeans = { Hunger = 25 },
    Jerky = { Hunger = 15 },
    Bread = { Hunger = 20 },
    Mushrooms = { Hunger = 10, Sanity = -5 },
    RawMeat = { Hunger = 5 },
    CookedMeat = { Hunger = 30 },
}

local DRINK_EFFECTS = {
    WaterBottle = { Thirst = 30 },
    EnergyDrink = { Thirst = 20, Stamina = 50 },
    DirtyWater = { Thirst = 10, Health = -5 },
}

-- ========== ON PLAYER ADDED ==========
local function onPlayerAdded(player)
    initPlayer(player)

    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        local s = getStats(player)
        if s then
            s.Health = DEFAULTS.Health
            s.IsDead = false
            humanoid.MaxHealth = s.MaxHealth
            humanoid.Health = s.Health
        end

        -- Bug #1: ouve dano externo (TakeDamage de inimigos, etc.) e
        -- sincroniza o Health real do Humanoid de volta para s.Health.
        -- Sem isso, o loop sobrescrevia humanoid.Health com s.Health velho,
        -- cancelando qualquer dano recebido.
        humanoid.HealthChanged:Connect(function(newHealth)
            local st = getStats(player)
            if not st then return end
            st.Health = math.clamp(newHealth, 0, st.MaxHealth)
            if newHealth <= 0 and not st.IsDead then
                st.IsDead = true
            end
        end)

        -- Track running state
        humanoid.Running:Connect(function(speed)
            if s then
                s.IsRunning = speed > WALK_SPEED + 1
            end
        end)

        -- On death
        humanoid.Died:Connect(function()
            if s then
                s.Health = 0
                s.IsDead = true
            end
        end)

        humanoid.WalkSpeed = WALK_SPEED
    end)
end

-- ========== MAIN UPDATE LOOP ==========
local hungerAccum = 0
local thirstAccum = 0

RunService.Heartbeat:Connect(function(dt)
    hungerAccum = hungerAccum + dt
    thirstAccum = thirstAccum + dt

    local doHungerDecay = hungerAccum >= 5
    local doThirstDecay = thirstAccum >= 3

    if doHungerDecay then hungerAccum = 0 end
    if doThirstDecay then thirstAccum = 0 end

    for _, player in ipairs(Players:GetPlayers()) do
        local s = getStats(player)
        if not s or s.IsDead then continue end

        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        -- Hunger decay
        if doHungerDecay then
            s.Hunger = clamp(s.Hunger - HUNGER_DECAY, 0, 100)
        end

        -- Thirst decay
        if doThirstDecay then
            s.Thirst = clamp(s.Thirst - THIRST_DECAY, 0, 100)
        end

        -- Starvation damage
        if s.Hunger <= 0 then
            s.Health = clamp(s.Health - HUNGER_DAMAGE * dt, 0, s.MaxHealth)
        end

        -- Dehydration damage
        if s.Thirst <= 0 then
            s.Health = clamp(s.Health - THIRST_DAMAGE * dt, 0, s.MaxHealth)
        end

        -- Stamina management
        if s.IsRunning then
            s.Stamina = clamp(s.Stamina - STAMINA_DRAIN * dt, 0, 100)
            if s.Stamina <= 0 then
                s.IsRunning = false
                humanoid.WalkSpeed = WALK_SPEED
            end
        else
            s.Stamina = clamp(s.Stamina + STAMINA_REGEN * dt, 0, 100)
        end

        -- Speed based on stamina + speed boost (Adrenaline)
        local baseSpeed = WALK_SPEED
        if s.IsRunning and s.Stamina > 0 then
            baseSpeed = RUN_SPEED
        end
        -- Phase 2: speed boost ativo?
        if os.time() < s.SpeedBoostEnds and s.SpeedBoostMult > 1 then
            humanoid.WalkSpeed = baseSpeed * s.SpeedBoostMult
        else
            s.SpeedBoostMult = 1
            s.SpeedBoostEnds = 0
            humanoid.WalkSpeed = baseSpeed
        end

        -- Phase 2: poison tick (1 dano por segundo por stack)
        if s.PoisonStacks > 0 then
            s.PoisonStacks = s.PoisonStacks - dt
            s.Health = clamp(s.Health - s.PoisonDPS * dt, 0, s.MaxHealth)
            if s.PoisonStacks <= 0 then
                s.PoisonStacks = 0
                s.PoisonDPS = 0
            end
        end

        -- Bug #1: só aplicamos dano (s.Health < humanoid.Health).
        -- Nunca sobrescrevemos dano externo; o listener HealthChanged
        -- já mantém s.Health sincronizado com o humanoid.
        if s.Health < humanoid.Health then
            humanoid.Health = s.Health
        end

        -- Sanity low trigger
        if s.Sanity < 30 then
            SanityEffect:FireClient(player, s.Sanity)
        end

        -- Sync all stats to client
        syncStats(player)
    end
end)

-- ========== REMOTE HANDLERS ==========
local EatRemote = ensureRemote("EatFood", "RemoteEvent")
local DrinkRemote = ensureRemote("DrinkItem", "RemoteEvent")
local RestRemote = ensureRemote("Rest", "RemoteEvent")
local RunToggle = ensureRemote("ToggleRun", "RemoteEvent")

EatRemote.OnServerEvent:Connect(function(player, foodName)
    local s = getStats(player)
    if not s then return end
    local effect = FOOD_EFFECTS[foodName]
    if not effect then return end
    if effect.Hunger then s.Hunger = clamp(s.Hunger + effect.Hunger, 0, 100) end
    if effect.Sanity then s.Sanity = clamp(s.Sanity + effect.Sanity, 0, 100) end
    if effect.Health then s.Health = clamp(s.Health + effect.Health, 0, s.MaxHealth) end
end)

DrinkRemote.OnServerEvent:Connect(function(player, drinkName)
    local s = getStats(player)
    if not s then return end
    local effect = DRINK_EFFECTS[drinkName]
    if not effect then return end
    if effect.Thirst then s.Thirst = clamp(s.Thirst + effect.Thirst, 0, 100) end
    if effect.Stamina then s.Stamina = clamp(s.Stamina + effect.Stamina, 0, 100) end
    if effect.Health then s.Health = clamp(s.Health + effect.Health, 0, s.MaxHealth) end
end)

RestRemote.OnServerEvent:Connect(function(player)
    local s = getStats(player)
    if not s then return end
    s.Stamina = clamp(s.Stamina + 5, 0, 100)
end)

RunToggle.OnServerEvent:Connect(function(player, isRunning)
    local s = getStats(player)
    if not s then return end
    s.IsRunning = isRunning and s.Stamina > 0
end)

-- ========== SANITY MODIFY (called by other server scripts) ==========
-- Bug #2: expõe GetStats para HorrorSystem ler a sanidade daqui
-- em vez de manter uma tabela paralela dessincronizada.
_G.GetStats = getStats

local ModifySanityRemote = ensureRemote("ModifySanity", "RemoteEvent")

ModifySanityRemote.OnServerEvent:Connect(function(player, amount)
    local s = getStats(player)
    if not s then return end
    s.Sanity = clamp(s.Sanity + amount, 0, 100)
end)

-- ========== PLAYER LIFECYCLE ==========
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    playerStats[player.UserId] = nil
end)

-- Expõe para outros scripts do servidor aplicarem efeitos de consumíveis
_G.ApplyConsumable = function(player, itemId)
    local s = getStats(player)
    if not s then return end
    local foodEffect = FOOD_EFFECTS[itemId]
    if foodEffect then
        if foodEffect.Hunger then s.Hunger = clamp(s.Hunger + foodEffect.Hunger, 0, 100) end
        if foodEffect.Sanity then s.Sanity = clamp(s.Sanity + foodEffect.Sanity, 0, 100) end
        if foodEffect.Health then s.Health = clamp(s.Health + foodEffect.Health, 0, s.MaxHealth) end
        return
    end
    local drinkEffect = DRINK_EFFECTS[itemId]
    if drinkEffect then
        if drinkEffect.Thirst then s.Thirst = clamp(s.Thirst + drinkEffect.Thirst, 0, 100) end
        if drinkEffect.Stamina then s.Stamina = clamp(s.Stamina + drinkEffect.Stamina, 0, 100) end
        if drinkEffect.Health then s.Health = clamp(s.Health + drinkEffect.Health, 0, s.MaxHealth) end
        return
    end

    -- Phase 2: itens médicos especiais
    if itemId == "Antidote" then
        s.PoisonStacks = 0
        s.PoisonDPS = 0
        return
    end

    if itemId == "Adrenaline" then
        s.Stamina = clamp(s.Stamina + 50, 0, 100)
        s.SpeedBoostMult = 1.5
        s.SpeedBoostEnds = os.time() + 10
        return
    end
end

-- Phase 2: permite que EnemyAI/throwables apliquem veneno no jogador
_G.ApplyPoison = function(player, dps, duration)
    local s = getStats(player)
    if not s then return end
    -- Não remove imunidade de GasMask aqui; EnemyAI já checa poisonImmunity
    s.PoisonStacks = math.max(s.PoisonStacks, duration)
    s.PoisonDPS = math.max(s.PoisonDPS, dps)
end

print("[SurvivalSystem] Loaded ✓")
