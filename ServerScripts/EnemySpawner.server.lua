-- ========== DARK SURVIVORS: Enemy Spawner ==========
-- Server-side: lê Workspace/EnemySpawns, cria NPCs e dirige o módulo EnemyAI.
-- Liga o módulo órfão (Modules/EnemyAI.lua) ao jogo — pathfinding, estados,
-- ataque por contato, loot (via tag EnemyType usada pelo CombatSystem).
-- Sem assets: rig de NPC montado em código (Part + Humanoid + WeldConstraint).

local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyAI = require(ServerScriptService.Modules.EnemyAI)

-- ========== CONFIG ==========
local TYPE_COLORS = {
	Zombie = "Dark green",
	Shadow = "Really black",
	Mutant = "Royal purple",
}

local activeEnemies = {}   -- { ai, npc, marker, enemyType }

-- ========== CRIA RIG DE NPC (sem asset) ==========
local function createNPC(spawnPos, enemyType)
	local model = Instance.new("Model")
	model.Name = enemyType .. "_NPC"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 1, 1)
	root.Position = spawnPos + Vector3.new(0, 1, 0)
	root.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Position = root.Position + Vector3.new(0, 1.5, 0)
	torso.BrickColor = BrickColor.new(TYPE_COLORS[enemyType] or "Dark green")
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.Position = torso.Position + Vector3.new(0, 1.5, 0)
	head.Parent = model

	-- Prende torso/cabeça ao root pra não voar ao mover
	for _, p in ipairs({ torso, head }) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end

	local hum = Instance.new("Humanoid")
	hum.Parent = model

	model.PrimaryPart = root
	model.Parent = Workspace

	return model
end

-- ========== SPAWN A PARTIR DE MARKER ==========
local function spawnFromMarker(marker)
	local name = marker.Name
	local enemyType
	for t, _ in pairs(TYPE_COLORS) do
		if name:sub(1, #t) == t then enemyType = t; break end
	end
	if not enemyType then
		warn("[EnemySpawner] Marker ignorado (prefixo desconhecido): " .. name)
		return
	end

	local spawnPos = marker.Position
	local npc = createNPC(spawnPos, enemyType)
	local ai = EnemyAI.new(npc, enemyType, spawnPos)
	if not ai then
		npc:Destroy()
		return
	end

	local record = { ai = ai, npc = npc, marker = marker, enemyType = enemyType }
	table.insert(activeEnemies, record)

	-- Respawn ao morrer (usa respawnTime do tipo)
	npc:FindFirstChild("Humanoid").Died:Connect(function()
		local idx = table.find(activeEnemies, record)
		if idx then table.remove(activeEnemies, idx) end
		local cfg = ai.config.respawnTime or 30
		task.delay(cfg, function()
			if marker.Parent then spawnFromMarker(marker) end
		end)
	end)
end

-- ========== DRIVE LOOP ==========
RunService.Heartbeat:Connect(function(dt)
	for _, rec in ipairs(activeEnemies) do
		local ok, err = pcall(rec.ai.update, rec.ai, dt)
		if not ok then
			warn("[EnemySpawner] AI error (" .. rec.enemyType .. "): " .. err)
		end
	end
end)

-- ========== INIT ==========
local enemyFolder = Workspace:FindFirstChild("EnemySpawns")
if not enemyFolder then
	enemyFolder = Instance.new("Folder")
	enemyFolder.Name = "EnemySpawns"
	enemyFolder.Parent = Workspace
	warn("[EnemySpawner] Pasta EnemySpawns criada — adicione Parts marcadores no Studio.")
end

for _, marker in ipairs(enemyFolder:GetChildren()) do
	if marker:IsA("BasePart") then spawnFromMarker(marker) end
end

print("[EnemySpawner] Loaded ✓ — inimigos ativos: " .. #activeEnemies)
