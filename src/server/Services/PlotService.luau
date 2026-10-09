--!strict
--[[
	PlotService.luau — Procedural Plot & Base Generator for VAULT WARS: STEAL & DEFEND TYCOON
	Constructs 6 circular base plots around a cyber-industrial central plaza,
	featuring the Central Leaderboard Monolith, Vault Doors, Conveyors, and Deposit Safes.
	Located in: ServerScriptService.Server.Services.PlotService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local PlotService = {}
PlotService._folder = nil :: Folder?
PlotService._plots = {} :: { [number]: any }
PlotService._playerPlots = {} :: { [Player]: number }

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

local function getLaserService(): any?
	local svc = script.Parent:FindFirstChild("LaserService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

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

-- ============================================================
-- INITIALIZE ARENA & 6 MODULAR PLOTS
-- ============================================================
function PlotService.Init()
	print("  [PlotService] Constructing Cyber-Industrial Plaza & 6 Modular Vault Bases...")

	local existing = Workspace:FindFirstChild("VaultWarsArena")
	if existing then existing:Destroy() end

	local rootFolder = Instance.new("Folder")
	rootFolder.Name = "VaultWarsArena"
	rootFolder.Parent = Workspace
	PlotService._folder = rootFolder

	-- ── 1. CENTRAL LOBBY PLAZA FLOOR ──
	local plaza = createPart(
		"CentralPlazaFloor",
		Vector3.new(160, 2, 160),
		CFrame.new(0, -1, 0),
		Config.Arena.LobbyFloorColor,
		Enum.Material.Slate,
		rootFolder
	)

	-- Center Octagonal Trim Ring
	local ring = createPart(
		"PlazaCenterRing",
		Vector3.new(28, 0.2, 28),
		CFrame.new(0, 0.1, 0),
		Color3.fromRGB(30, 41, 59),
		Enum.Material.SmoothPlastic,
		rootFolder,
		false
	)

	-- ── 2. CENTRAL MONOLITH & LEADERBOARD ──
	local monolith = createPart(
		"CenterMonolith",
		Vector3.new(10, 22, 10),
		CFrame.new(0, 11, 0),
		Color3.fromRGB(15, 23, 42),
		Enum.Material.Metal,
		rootFolder
	)

	-- Glowing Cyan Trims on Monolith
	createPart(
		"MonolithTrim1",
		Vector3.new(10.4, 0.8, 10.4),
		CFrame.new(0, 20, 0),
		Color3.fromRGB(56, 189, 248),
		Enum.Material.Neon,
		monolith,
		false
	)

	-- Leaderboard Surface GUI
	local sGui = Instance.new("SurfaceGui")
	sGui.Name = "LeaderboardGui"
	sGui.Face = Enum.NormalId.Front
	sGui.CanvasSize = Vector2.new(400, 600)
	sGui.Parent = monolith

	local lbTitle = Instance.new("TextLabel")
	lbTitle.Size = UDim2.new(1, 0, 0, 70)
	lbTitle.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	lbTitle.Text = "🏆 VAULT WARS: TOP NET WORTH"
	lbTitle.TextColor3 = Color3.fromRGB(250, 204, 21)
	lbTitle.TextSize = 20
	lbTitle.Font = Enum.Font.GothamBlack
	lbTitle.Parent = sGui

	local lbFrame = Instance.new("Frame")
	lbFrame.Name = "LeaderboardList"
	lbFrame.Size = UDim2.new(1, 0, 1, -70)
	lbFrame.Position = UDim2.new(0, 0, 0, 70)
	lbFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
	lbFrame.Parent = sGui

	-- Spawn Location in Plaza
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "PlazaSpawn"
	spawnPad.Size = Vector3.new(10, 1, 10)
	spawnPad.CFrame = CFrame.new(0, 0.5, 25)
	spawnPad.Anchored = true
	spawnPad.CanCollide = true
	spawnPad.Material = Enum.Material.Neon
	spawnPad.Color = Color3.fromRGB(56, 189, 248)
	spawnPad.Duration = 0
	spawnPad.Parent = rootFolder

	-- ── 2.5. CENTRAL PLAZA RELIC FUSION ALTAR ──
	local openFusionEvt = ReplicatedStorage:FindFirstChild("OpenFusionModal") :: RemoteEvent?
	if not openFusionEvt then
		openFusionEvt = Instance.new("RemoteEvent")
		openFusionEvt.Name = "OpenFusionModal"
		openFusionEvt.Parent = ReplicatedStorage
	end

	local altarBase = createPart(
		"FusionAltarBase",
		Vector3.new(14, 1.2, 14),
		CFrame.new(0, 0.6, -26),
		Color3.fromRGB(24, 24, 32),
		Enum.Material.Slate,
		rootFolder
	)
	createPart(
		"FusionAltarRing",
		Vector3.new(10, 0.3, 10),
		CFrame.new(0, 1.35, -26),
		Color3.fromRGB(168, 85, 247),
		Enum.Material.Neon,
		rootFolder,
		false
	)
	local altarCore = createPart(
		"FusionAltarCore",
		Vector3.new(3.2, 3.2, 3.2),
		CFrame.new(0, 4.2, -26),
		Color3.fromRGB(192, 132, 252),
		Enum.Material.Glass,
		rootFolder,
		false
	)

	-- 4 Corner Resonator Pylons
	local pylonOffsets = {
		Vector3.new(5.5, 3.5, 5.5),
		Vector3.new(-5.5, 3.5, 5.5),
		Vector3.new(5.5, 3.5, -5.5),
		Vector3.new(-5.5, 3.5, -5.5),
	}
	for idx, offset in pylonOffsets do
		createPart(
			`AltarPylon_{idx}`,
			Vector3.new(1.4, 6.0, 1.4),
			CFrame.new(Vector3.new(0, 0, -26) + offset),
			Color3.fromRGB(51, 65, 85),
			Enum.Material.Metal,
			rootFolder
		)
		createPart(
			`AltarPylonCap_{idx}`,
			Vector3.new(1.6, 0.6, 1.6),
			CFrame.new(Vector3.new(0, 6.6, -26) + offset),
			Color3.fromRGB(168, 85, 247),
			Enum.Material.Neon,
			rootFolder,
			false
		)
	end

	-- Altar Overhead Billboard
	local aGui = Instance.new("BillboardGui")
	aGui.Name = "AltarBillboard"
	aGui.Size = UDim2.new(0, 260, 0, 54)
	aGui.StudsOffset = Vector3.new(0, 3.2, 0)
	aGui.AlwaysOnTop = true
	aGui.Parent = altarCore

	local aLabel = Instance.new("TextLabel")
	aLabel.Size = UDim2.new(1, 0, 1, 0)
	aLabel.BackgroundTransparency = 1
	aLabel.Text = "🔮 RELIC FUSION ALTAR\n[E] COMBINE 3x FOR HIGHER TIERS"
	aLabel.TextColor3 = Color3.fromRGB(216, 180, 254)
	aLabel.TextSize = 13
	aLabel.Font = Enum.Font.GothamBlack
	aLabel.Parent = aGui

	-- Proximity Prompt for interaction
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Relic Fusion Altar"
	prompt.ActionText = "Open Fusion Matrix"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = altarCore

	prompt.Triggered:Connect(function(player: Player)
		if openFusionEvt then
			openFusionEvt:FireClient(player)
		end
	end)

	-- ── 3. BUILD 6 MODULAR PLOTS CIRCULARLY ──
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = rootFolder

	local numPlots = Config.Arena.PlotCount -- 6
	local radius = Config.Arena.PlazaRadius -- 60
	local pWidth = Config.Arena.PlotWidth   -- 32
	local pLen = Config.Arena.PlotLength    -- 46

	for i = 1, numPlots do
		local angle = ((i - 1) / numPlots) * (math.pi * 2)
		local plotDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local plotPos = plotDir * (radius + pLen / 2)
		local faceCenterCF = CFrame.lookAt(plotPos, Vector3.new(0, plotPos.Y, 0))

		local pFolder = Instance.new("Folder")
		pFolder.Name = "Plot_" .. i
		pFolder.Parent = plotsFolder

		-- Plot Floor
		local floor = createPart(
			"PlotFloor",
			Vector3.new(pWidth, 2, pLen),
			faceCenterCF * CFrame.new(0, 0, 0),
			Color3.fromRGB(24, 24, 27),
			Enum.Material.SmoothPlastic,
			pFolder
		)

		-- Plot Perimeter Walls (Left, Right, Back)
		local leftWall = createPart(
			"LeftWall",
			Vector3.new(1.5, Config.Arena.WallHeight, pLen),
			faceCenterCF * CFrame.new(-pWidth / 2, Config.Arena.WallHeight / 2, 0),
			Color3.fromRGB(39, 39, 42),
			Enum.Material.Concrete,
			pFolder
		)
		local rightWall = createPart(
			"RightWall",
			Vector3.new(1.5, Config.Arena.WallHeight, pLen),
			faceCenterCF * CFrame.new(pWidth / 2, Config.Arena.WallHeight / 2, 0),
			Color3.fromRGB(39, 39, 42),
			Enum.Material.Concrete,
			pFolder
		)
		local backWall = createPart(
			"BackWall",
			Vector3.new(pWidth + 1.5, Config.Arena.WallHeight, 1.5),
			faceCenterCF * CFrame.new(0, Config.Arena.WallHeight / 2, pLen / 2),
			Color3.fromRGB(39, 39, 42),
			Enum.Material.Concrete,
			pFolder
		)

		-- ── 4. CHUNKY CIRCULAR VAULT DOOR AT BACK ──
		local vaultFrame = createPart(
			"VaultDoorFrame",
			Vector3.new(10, 12, 2),
			faceCenterCF * CFrame.new(0, 6, pLen / 2 - 1.5),
			Color3.fromRGB(15, 23, 42),
			Enum.Material.Metal,
			pFolder
		)
		local vaultWheel = createPart(
			"VaultCogWheel",
			Vector3.new(6, 6, 1),
			faceCenterCF * CFrame.new(0, 6, pLen / 2 - 2.8),
			Color3.fromRGB(234, 179, 8),
			Enum.Material.Metal,
			pFolder,
			false
		)
		Instance.new("CylinderMesh", vaultWheel)

		-- ── 5. MINT CONVEYOR TABLE ──
		local conveyor = createPart(
			"MintConveyor",
			Vector3.new(6, 3, Config.Mint.ConveyorLength),
			faceCenterCF * CFrame.new(8, 1.5, 0),
			Color3.fromRGB(30, 41, 59),
			Enum.Material.Metal,
			pFolder
		)
		-- Rubber belt top
		local belt = createPart(
			"ConveyorBelt",
			Vector3.new(5.2, 0.2, Config.Mint.ConveyorLength - 0.4),
			faceCenterCF * CFrame.new(8, 3.1, 0),
			Color3.fromRGB(15, 17, 26),
			Enum.Material.Slate,
			conveyor,
			false
		)

		-- ── 6. DEPOSIT SAFE PAD ──
		local safePad = createPart(
			"DepositSafe",
			Vector3.new(7, 1.2, 7),
			faceCenterCF * CFrame.new(0, 0.7, pLen / 2 - 9),
			Color3.fromRGB(16, 185, 129),
			Enum.Material.Neon,
			pFolder
		)

		local safeLabel = Instance.new("BillboardGui")
		safeLabel.Name = "SafeBillboard"
		safeLabel.Size = UDim2.new(0, 160, 0, 40)
		safeLabel.StudsOffset = Vector3.new(0, 2.8, 0)
		safeLabel.AlwaysOnTop = true
		safeLabel.Parent = safePad

		local slText = Instance.new("TextLabel")
		slText.Size = UDim2.new(1, 0, 1, 0)
		slText.BackgroundTransparency = 1
		slText.Text = "📥 STEP TO BANK"
		slText.TextColor3 = Color3.fromRGB(16, 185, 129)
		slText.TextSize = 14
		slText.Font = Enum.Font.GothamBlack
		slText.Parent = safeLabel

		-- ── 7. FRONT LASER PILLARS (SECURITY ENTRANCE) ──
		local leftLaserPost = createPart(
			"LaserPostLeft",
			Vector3.new(1.5, 10, 1.5),
			faceCenterCF * CFrame.new(-pWidth / 2 + 3, 5, -pLen / 2 + 1),
			Color3.fromRGB(51, 65, 85),
			Enum.Material.Metal,
			pFolder
		)
		local rightLaserPost = createPart(
			"LaserPostRight",
			Vector3.new(1.5, 10, 1.5),
			faceCenterCF * CFrame.new(pWidth / 2 - 3, 5, -pLen / 2 + 1),
			Color3.fromRGB(51, 65, 85),
			Enum.Material.Metal,
			pFolder
		)

		-- ── 8. SIREN BEACON ON FRONT ARCHWAY ──
		local frontArch = createPart(
			"FrontArch",
			Vector3.new(pWidth, 2, 2),
			faceCenterCF * CFrame.new(0, 11, -pLen / 2 + 1),
			Color3.fromRGB(30, 41, 59),
			Enum.Material.Metal,
			pFolder
		)
		local siren = createPart(
			"SirenBeacon",
			Vector3.new(1.8, 2.5, 1.8),
			faceCenterCF * CFrame.new(0, 13.2, -pLen / 2 + 1),
			Color3.fromRGB(239, 68, 68),
			Enum.Material.Neon,
			pFolder
		)

		-- Owner Billboard on Front Arch
		local ownerGui = Instance.new("BillboardGui")
		ownerGui.Name = "OwnerBillboard"
		ownerGui.Size = UDim2.new(0, 220, 0, 48)
		ownerGui.StudsOffset = Vector3.new(0, 2, 0)
		ownerGui.AlwaysOnTop = true
		ownerGui.Parent = frontArch

		local obText = Instance.new("TextLabel")
		obText.Name = "OwnerNameLabel"
		obText.Size = UDim2.new(1, 0, 1, 0)
		obText.BackgroundTransparency = 1
		obText.Text = `[VAULT #{i}: VACANT]`
		obText.TextColor3 = Color3.fromRGB(148, 163, 184)
		obText.TextSize = 16
		obText.Font = Enum.Font.GothamBold
		obText.Parent = ownerGui

		PlotService._plots[i] = {
			Index = i,
			Folder = pFolder,
			Floor = floor,
			SafePad = safePad,
			Conveyor = conveyor,
			Belt = belt,
			Siren = siren,
			LeftPost = leftLaserPost,
			RightPost = rightLaserPost,
			OwnerLabel = obText,
			Owner = nil :: Player?,
			CF = faceCenterCF,
			IsBreached = false,
			BreachExpiry = 0,
		}

		-- Connect Touch on SafePad to automatically bank for owner or deposit stolen loot
		safePad.Touched:Connect(function(hit)
			local char = hit.Parent
			local p = char and Players:GetPlayerFromCharacter(char)
			if p and PlotService._plots[i].Owner == p then
				local heistMod = script.Parent:FindFirstChild("HeistService") :: ModuleScript?
				local heistSvc = heistMod and require(heistMod)
				if heistSvc and heistSvc.IsCarryingLoot(p) then
					heistSvc.DepositStolenLoot(p)
				else
					local dataSvc = getDataService()
					if dataSvc then
						dataSvc.BankAll(p)
					end
				end
			end
		end)
	end

	-- Connect Player Join/Leave Plot Assignment
	for _, p in Players:GetPlayers() do
		task.spawn(PlotService.AssignPlot, p)
	end
	Players.PlayerAdded:Connect(PlotService.AssignPlot)
	Players.PlayerRemoving:Connect(PlotService.ReleasePlot)

	print("  [PlotService] 6 Modular Vault Bases ready ✓")
end

-- ============================================================
-- PLOT ASSIGNMENT
-- ============================================================
function PlotService.AssignPlot(player: Player)
	if PlotService._playerPlots[player] then return end

	-- Find first vacant plot
	local assignedIndex: number? = nil
	for i = 1, Config.Arena.PlotCount do
		if PlotService._plots[i] and PlotService._plots[i].Owner == nil then
			assignedIndex = i
			break
		end
	end

	if not assignedIndex then
		warn(`[PlotService] Server full! No free plot for {player.Name}`)
		return
	end

	local plot = PlotService._plots[assignedIndex]
	plot.Owner = player
	PlotService._playerPlots[player] = assignedIndex

	plot.OwnerLabel.Text = `👑 {string.upper(player.DisplayName)}'S VAULT`
	plot.OwnerLabel.TextColor3 = Color3.fromRGB(56, 189, 248)

	-- Teleport player to their base
	task.spawn(function()
		local char = player.Character or player.CharacterAdded:Wait()
		local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if root then
			root.CFrame = plot.CF * CFrame.new(0, 3, 0)
		end
	end)

	print(`  [PlotService] Assigned Vault #{assignedIndex} to {player.Name}`)
end

function PlotService.ReleasePlot(player: Player)
	local plotIndex = PlotService._playerPlots[player]
	if not plotIndex then return end

	local plot = PlotService._plots[plotIndex]
	if plot then
		plot.Owner = nil
		plot.OwnerLabel.Text = `[VAULT #{plotIndex}: VACANT]`
		plot.OwnerLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
		plot.IsBreached = false
	end

	PlotService._playerPlots[player] = nil
	print(`  [PlotService] Released Vault #{plotIndex} from {player.Name}`)
end

function PlotService.GetPlotForPlayer(player: Player): any?
	local idx = PlotService._playerPlots[player]
	return idx and PlotService._plots[idx] or nil
end

function PlotService.GetPlotByIndex(index: number): any?
	return PlotService._plots[index]
end

return PlotService
