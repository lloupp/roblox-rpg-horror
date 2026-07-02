-- ========== DARK SURVIVORS: World Bootstrap ==========
-- Server-side: auto-generates a minimal playable placeholder world
-- (ground, biome zones, spawn location, lighting) so the game is playable
-- immediately after a Rojo sync, with no manual Studio setup required.
-- Every step only fills in pieces that are still missing, so replacing any
-- of this with real level art later on won't get overwritten on next run.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

-- ========== BIOME ZONES ==========
local BIOME_ZONES = {
    Forest   = { center = Vector3.new(0, 0, 0),     color = Color3.fromRGB(40, 90, 40) },
    Swamp    = { center = Vector3.new(350, 0, 0),   color = Color3.fromRGB(60, 80, 50) },
    Ruins    = { center = Vector3.new(-350, 0, 0),  color = Color3.fromRGB(110, 100, 90) },
    Bunker   = { center = Vector3.new(0, 0, 350),   color = Color3.fromRGB(70, 70, 75) },
    Hospital = { center = Vector3.new(0, 0, -350),  color = Color3.fromRGB(150, 150, 140) },
    Caves    = { center = Vector3.new(350, 0, 350), color = Color3.fromRGB(35, 35, 40) },
}
local ZONE_SIZE = 250

-- ========== GROUND ==========
if not Workspace:FindFirstChild("Ground") then
    local ground = Instance.new("Part")
    ground.Name = "Ground"
    ground.Size = Vector3.new(1400, 4, 1400)
    ground.Position = Vector3.new(0, -2, 0)
    ground.Anchored = true
    ground.CanCollide = true
    ground.Color = Color3.fromRGB(55, 60, 50)
    ground.Material = Enum.Material.Ground
    ground.Parent = Workspace
end

-- ========== BIOME ZONE MARKERS ==========
local Biomes = Workspace:FindFirstChild("Biomes")
if not Biomes then
    Biomes = Instance.new("Folder")
    Biomes.Name = "Biomes"
    Biomes.Parent = Workspace
end

for name, def in pairs(BIOME_ZONES) do
    local zoneFolder = Biomes:FindFirstChild(name)
    if not zoneFolder then
        zoneFolder = Instance.new("Folder")
        zoneFolder.Name = name
        zoneFolder.Parent = Biomes
    end

    if #zoneFolder:GetChildren() == 0 then
        local plate = Instance.new("Part")
        plate.Name = "Zone"
        plate.Size = Vector3.new(ZONE_SIZE, 1, ZONE_SIZE)
        plate.Position = def.center + Vector3.new(0, 0.55, 0)
        plate.Anchored = true
        plate.CanCollide = false
        plate.Transparency = 0.5
        plate.Color = def.color
        plate.Material = Enum.Material.SmoothPlastic
        plate.Parent = zoneFolder
    end
end

-- ========== SPAWN LOCATION ==========
if not Workspace:FindFirstChildOfClass("SpawnLocation") then
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "PlayerSpawn"
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = BIOME_ZONES.Forest.center + Vector3.new(0, 1, 0)
    spawn.Anchored = true
    spawn.CanCollide = true
    spawn.Neutral = true
    spawn.Color = Color3.fromRGB(90, 60, 30)
    spawn.Parent = Workspace
end

-- ========== LIGHTING / ATMOSPHERE ==========
Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(128, 128, 128)
Lighting.FogEnd = 10000

if not Lighting:FindFirstChild("Atmosphere") then
    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Density = 0.3
    atmosphere.Parent = Lighting
end

print("[WorldBootstrap] Loaded ✓")
