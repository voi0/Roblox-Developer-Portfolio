--!strict
--[[
	ArenaService.luau — Procedural, high-visibility arena for ESCAPE THE PACK
	Constructs the rectangular crossing lane, safe zones, forcefields,
	and the elevated spectator terrace overlooking the pit.
	Located in: ServerScriptService.Server.Services.ArenaService
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ArenaService = {}
ArenaService._folder = nil :: Folder?
ArenaService._startGate = nil :: BasePart?
ArenaService._finishGate = nil :: BasePart?

local function createPart(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, parent: Instance, canCollide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CanCollide = (canCollide ~= false)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function ArenaService.Init()
	print("  [ArenaService] Constructing High-Visibility Tag Arena & Spectator Terrace...")

	local existing = Workspace:FindFirstChild("PackArena")
	if existing then existing:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name = "PackArena"
	folder.Parent = Workspace
	ArenaService._folder = folder

	local cfg = Config.Arena
	local len = cfg.Length      -- 240
	local wid = cfg.Width       -- 80
	local wallH = cfg.WallHeight -- 22

	-- ========================================================
	-- 1. MAIN ARENA FLOOR
	-- ========================================================
	local arenaFloor = createPart(
		"ArenaFloor",
		Vector3.new(wid, 2, len),
		CFrame.new(0, 0, 0),
		Color3.fromRGB(15, 17, 26),
		Enum.Material.Slate,
		folder
	)

	-- Center lane visual striping (High contrast for spatial awareness)
	for i = -3, 3 do
		createPart(
			"LaneStripe_" .. i,
			Vector3.new(2, 0.1, 16),
			CFrame.new(0, 1.05, i * 28),
			Color3.fromRGB(56, 189, 248),
			Enum.Material.Neon,
			folder,
			false
		)
	end

	-- ========================================================
	-- 2. PERIMETER BOUNDARY WALLS
	-- ========================================================
	-- West Wall
	createPart("WestWall", Vector3.new(2, wallH, len), CFrame.new(-wid / 2 - 1, wallH / 2, 0), Color3.fromRGB(30, 35, 50), Enum.Material.Concrete, folder)
	-- East Wall
	createPart("EastWall", Vector3.new(2, wallH, len), CFrame.new(wid / 2 + 1, wallH / 2, 0), Color3.fromRGB(30, 35, 50), Enum.Material.Concrete, folder)
	-- South End Wall (behind Start)
	createPart("SouthWall", Vector3.new(wid + 4, wallH, 2), CFrame.new(0, wallH / 2, -len / 2 - 1), Color3.fromRGB(30, 35, 50), Enum.Material.Concrete, folder)
	-- North End Wall (behind Finish)
	createPart("NorthWall", Vector3.new(wid + 4, wallH, 2), CFrame.new(0, wallH / 2, len / 2 + 1), Color3.fromRGB(30, 35, 50), Enum.Material.Concrete, folder)

	-- Neon Perimeter Crown Trims
	createPart("WestNeonTrim", Vector3.new(0.6, 1, len), CFrame.new(-wid / 2, wallH, 0), Color3.fromRGB(244, 63, 94), Enum.Material.Neon, folder, false)
	createPart("EastNeonTrim", Vector3.new(0.6, 1, len), CFrame.new(wid / 2, wallH, 0), Color3.fromRGB(244, 63, 94), Enum.Material.Neon, folder, false)

	-- ========================================================
	-- 3. START & FINISH SAFE ZONES
	-- ========================================================
	-- Start Zone (South, Z = -120 to -94)
	local startZone = createPart(
		"StartZonePad",
		Vector3.new(wid - 2, 0.2, cfg.SafeZoneLength),
		CFrame.new(0, 1.1, -len / 2 + cfg.SafeZoneLength / 2),
		Color3.fromRGB(16, 185, 129),
		Enum.Material.Neon,
		folder,
		false
	)
	startZone.Transparency = 0.55

	-- Finish Zone (North, Z = 94 to 120)
	local finishZone = createPart(
		"FinishZonePad",
		Vector3.new(wid - 2, 0.2, cfg.SafeZoneLength),
		CFrame.new(0, 1.1, len / 2 - cfg.SafeZoneLength / 2),
		Color3.fromRGB(14, 165, 233),
		Enum.Material.Neon,
		folder,
		false
	)
	finishZone.Transparency = 0.55

	-- ========================================================
	-- 4. FORCEFIELD GATES (Drop when wave starts)
	-- ========================================================
	-- Start Barrier Gate (at Z = -94)
	local startGate = createPart(
		"StartGate",
		Vector3.new(wid, wallH, 1.5),
		CFrame.new(0, wallH / 2, -len / 2 + cfg.SafeZoneLength),
		Color3.fromRGB(16, 185, 129),
		Enum.Material.ForceField,
		folder,
		true
	)
	startGate.Transparency = 0.5
	ArenaService._startGate = startGate

	-- Finish Barrier Gate (at Z = 94)
	local finishGate = createPart(
		"FinishGate",
		Vector3.new(wid, wallH, 1.5),
		CFrame.new(0, wallH / 2, len / 2 - cfg.SafeZoneLength),
		Color3.fromRGB(14, 165, 233),
		Enum.Material.ForceField,
		folder,
		false
	)
	finishGate.Transparency = 0.8
	ArenaService._finishGate = finishGate

	-- ========================================================
	-- 5. TACTICAL JUKING OBSTACLES (Clean stylized pillars & barricades)
	-- ========================================================
	local obstacleFolder = Instance.new("Folder")
	obstacleFolder.Name = "Obstacles"
	obstacleFolder.Parent = folder

	-- Symmetrical low pillars providing line-of-sight breaks and juke anchors
	local obstacleCoords = {
		Vector3.new(-22, 4, -60),
		Vector3.new(22, 4, -60),
		Vector3.new(0, 4, -30),
		Vector3.new(-26, 4, 0),
		Vector3.new(26, 4, 0),
		Vector3.new(0, 4, 30),
		Vector3.new(-22, 4, 60),
		Vector3.new(22, 4, 60),
	}

	for i, coord in obstacleCoords do
		local pillar = createPart(
			"JukePillar_" .. i,
			Vector3.new(6, 8, 6),
			CFrame.new(coord),
			Color3.fromRGB(39, 39, 42),
			Enum.Material.DiamondPlate,
			obstacleFolder
		)
		-- Glowing corner trim on pillars
		local trim = createPart(
			"PillarTrim_" .. i,
			Vector3.new(6.2, 0.4, 6.2),
			CFrame.new(coord.X, 7.8, coord.Z),
			Color3.fromRGB(244, 114, 182),
			Enum.Material.Neon,
			pillar,
			false
		)
	end

	-- Low vault barriers
	local barricadeCoords = {
		Vector3.new(-12, 2.5, -45),
		Vector3.new(12, 2.5, -45),
		Vector3.new(-12, 2.5, 45),
		Vector3.new(12, 2.5, 45),
	}
	for i, bCoord in barricadeCoords do
		createPart(
			"VaultBarricade_" .. i,
			Vector3.new(10, 3.5, 2),
			CFrame.new(bCoord),
			Color3.fromRGB(63, 63, 70),
			Enum.Material.Metal,
			obstacleFolder
		)
	end

	-- ========================================================
	-- 6. ELEVATED SPECTATOR LOBBY & VIEWING TERRACE
	-- ========================================================
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "SpectatorLobby"
	lobbyFolder.Parent = folder

	-- Main Lobby Platform
	local lobbyPos = cfg.LobbyPosition
	createPart(
		"LobbyDeck",
		Vector3.new(90, 2, 50),
		CFrame.new(lobbyPos),
		Color3.fromRGB(24, 24, 27),
		Enum.Material.SmoothPlastic,
		lobbyFolder
	)

	-- Glass Balcony overlooking the Arena Pit
	createPart(
		"ViewingBalconyRailing",
		Vector3.new(90, 4, 1),
		CFrame.new(lobbyPos.X, lobbyPos.Y + 3, lobbyPos.Z + 25),
		Color3.fromRGB(160, 210, 255),
		Enum.Material.Glass,
		lobbyFolder
	).Transparency = 0.65

	-- Lobby Spawn Point
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "LobbySpawn"
	spawnPad.Size = Vector3.new(12, 1, 12)
	spawnPad.CFrame = CFrame.new(lobbyPos.X, lobbyPos.Y + 1.2, lobbyPos.Z)
	spawnPad.Anchored = true
	spawnPad.CanCollide = true
	spawnPad.Material = Enum.Material.Neon
	spawnPad.Color = Color3.fromRGB(99, 102, 241)
	spawnPad.Duration = 0
	spawnPad.Parent = lobbyFolder

	print("  [ArenaService] Arena & Spectator Terrace initialized ✓")
end

function ArenaService.SetStartGate(closed: boolean)
	if ArenaService._startGate then
		ArenaService._startGate.CanCollide = closed
		ArenaService._startGate.Transparency = closed and 0.4 or 0.95
	end
end

function ArenaService.SetFinishGate(closed: boolean)
	if ArenaService._finishGate then
		ArenaService._finishGate.CanCollide = closed
		ArenaService._finishGate.Transparency = closed and 0.4 or 0.95
	end
end

function ArenaService.GetStartZoneCFrame(): CFrame
	return CFrame.new(Config.Arena.StartZoneCenter)
end

function ArenaService.GetFinishZoneCFrame(): CFrame
	return CFrame.new(Config.Arena.FinishZoneCenter)
end

function ArenaService.GetLobbyCFrame(): CFrame
	return CFrame.new(Config.Arena.LobbyPosition + Vector3.new(0, 3, 0))
end

function ArenaService.IsInFinishZone(pos: Vector3, waveIndex: number): boolean
	local cfg = Config.Arena
	-- On Wave 1 & 3: Goal is North Finish Zone (Z > 94)
	-- On Wave 2: Goal is South Start Zone (Z < -94)
	if waveIndex % 2 == 1 then
		return pos.Z >= (cfg.Length / 2 - cfg.SafeZoneLength)
	else
		return pos.Z <= (-cfg.Length / 2 + cfg.SafeZoneLength)
	end
end

function ArenaService.IsInSafeZone(pos: Vector3): boolean
	local cfg = Config.Arena
	local inSouth = pos.Z <= (-cfg.Length / 2 + cfg.SafeZoneLength)
	local inNorth = pos.Z >= (cfg.Length / 2 - cfg.SafeZoneLength)
	return inSouth or inNorth
end

return ArenaService
