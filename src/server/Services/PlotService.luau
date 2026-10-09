--!strict
--[[
	PlotService.luau — Procedural Plot & Base Generator for VAULT WARS: STEAL & DEFEND TYCOON
	Constructs 6 circular base plots around a cyber-industrial central plaza,
	featuring the Central Leaderboard Monolith, Vault Doors, Conveyors, and Deposit Safes.
	Located in: ServerScriptService.Server.Services.PlotService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RelicData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelicData"))
local ModelEngine = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelEngine"))

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
	print("  [PlotService] Constructing Cyber-Industrial Plaza & 6 Fortified Bunker Bases...")

	-- ── 0. BASEPLATE CLEANUP (Eliminates ground flickering & Z-fighting) ──
	for _, child in Workspace:GetChildren() do
		if child:IsA("BasePart") then
			local lowerName = child.Name:lower()
			if lowerName == "baseplate" or lowerName:find("baseplate") then
				pcall(function() child:Destroy() end)
			end
		end
	end

	local existing = Workspace:FindFirstChild("VaultWarsArena")
	if existing then existing:Destroy() end

	local rootFolder = Instance.new("Folder")
	rootFolder.Name = "VaultWarsArena"
	rootFolder.Parent = Workspace
	PlotService._folder = rootFolder

	local ARENA_Y = 2.0 -- Center Y of foundation
	local FLOOR_Y = 4.0 -- Walkable deck surface

	-- ── 1. CENTRAL LOBBY PLAZA FLOOR (Elevated multi-tier foundation) ──
	local plaza = createPart(
		"CentralPlazaFloor",
		Vector3.new(160, 4, 160),
		CFrame.new(0, ARENA_Y, 0),
		Config.Arena.LobbyFloorColor,
		Enum.Material.Slate,
		rootFolder
	)

	-- Plaza Perimeter Diamond-Plate Trim Skirt
	createPart(
		"PlazaPerimeterSkirt",
		Vector3.new(164, 4.2, 164),
		CFrame.new(0, ARENA_Y, 0),
		Color3.fromRGB(15, 23, 42),
		Enum.Material.DiamondPlate,
		rootFolder,
		false
	)

	-- Center Octagonal Trim Ring
	local ring = createPart(
		"PlazaCenterRing",
		Vector3.new(34, 0.2, 34),
		CFrame.new(0, FLOOR_Y + 0.05, 0),
		Color3.fromRGB(30, 41, 59),
		Enum.Material.SmoothPlastic,
		rootFolder,
		false
	)

	-- Glowing Cyan Inlay Ring
	createPart(
		"PlazaCenterNeonTrim",
		Vector3.new(28, 0.1, 28),
		CFrame.new(0, FLOOR_Y + 0.08, 0),
		Color3.fromRGB(56, 189, 248),
		Enum.Material.Neon,
		rootFolder,
		false
	)

	-- ── 2. CENTRAL CYBER-INDUSTRIAL TERMINAL & LEADERBOARD ──
	-- 2.1 Stepped Plinth Base (Eliminates flat monolith look)
	createPart(
		"MonolithPlinthLower",
		Vector3.new(22, 1.8, 22),
		CFrame.new(0, FLOOR_Y + 0.9, 0),
		Color3.fromRGB(30, 41, 59),
		Enum.Material.DiamondPlate,
		rootFolder,
		true
	)
	createPart(
		"MonolithPlinthUpper",
		Vector3.new(17, 1.8, 17),
		CFrame.new(0, FLOOR_Y + 2.7, 0),
		Color3.fromRGB(47, 55, 70),
		Enum.Material.Concrete,
		rootFolder,
		true
	)

	-- 2.2 Main Terminal Core Body
	local monolith = createPart(
		"CenterMonolith",
		Vector3.new(12, 24, 12),
		CFrame.new(0, FLOOR_Y + 15.6, 0),
		Color3.fromRGB(38, 46, 60),
		Enum.Material.Metal,
		rootFolder,
		true
	)

	-- 4 Structural Steel Corner Flanges
	for _, xSide in { -6, 6 } do
		for _, zSide in { -6, 6 } do
			createPart(
				`MonolithCorner_{xSide}_{zSide}`,
				Vector3.new(1.8, 26, 1.8),
				CFrame.new(xSide, FLOOR_Y + 15.6, zSide),
				Color3.fromRGB(24, 28, 40),
				Enum.Material.DiamondPlate,
				monolith,
				false
			)
		end
	end

	-- Architectural Crown Cap & Holographic Projection Ring
	createPart(
		"MonolithCrownCap",
		Vector3.new(14.5, 2.4, 14.5),
		CFrame.new(0, FLOOR_Y + 28.5, 0),
		Color3.fromRGB(15, 23, 42),
		Enum.Material.Metal,
		monolith,
		true
	)
	createPart(
		"MonolithHoloRing",
		Vector3.new(16, 0.4, 16),
		CFrame.new(0, FLOOR_Y + 29.9, 0),
		Color3.fromRGB(56, 189, 248),
		Enum.Material.Neon,
		monolith,
		false
	)
	-- Communications Spire & Warning Beacon
	createPart(
		"MonolithSpire",
		Vector3.new(0.8, 8, 0.8),
		CFrame.new(0, FLOOR_Y + 34, 0),
		Color3.fromRGB(203, 213, 225),
		Enum.Material.Metal,
		monolith,
		false
	)
	local topBeacon = createPart(
		"MonolithBeacon",
		Vector3.new(1.2, 1.2, 1.2),
		CFrame.new(0, FLOOR_Y + 38.5, 0),
		Color3.fromRGB(245, 158, 11),
		Enum.Material.Neon,
		monolith,
		false
	)
	local mBeaconLight = Instance.new("PointLight")
	mBeaconLight.Color = Color3.fromRGB(245, 158, 11)
	mBeaconLight.Range = 35
	mBeaconLight.Brightness = 2.4
	mBeaconLight.Parent = topBeacon

	-- 4 Perimeter Monolith High-Bay Downlights (Illuminates central plaza, spawn, altar, and broker)
	for _, dir in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local mDownFixture = createPart(
			"MonolithFloodFixture",
			Vector3.new(2.4, 0.8, 2.4),
			CFrame.new(dir * 7.5 + Vector3.new(0, FLOOR_Y + 27.5, 0)),
			Color3.fromRGB(254, 240, 138),
			Enum.Material.Neon,
			monolith,
			false
		)
		local mDownSpot = Instance.new("SpotLight")
		mDownSpot.Name = "MonolithPlazaSpot"
		mDownSpot.Face = Enum.NormalId.Bottom
		mDownSpot.Angle = 125
		mDownSpot.Range = 75
		mDownSpot.Brightness = 4.2
		mDownSpot.Color = Color3.fromRGB(255, 248, 235)
		mDownSpot.Shadows = true
		mDownSpot.Parent = mDownFixture
	end

	-- Leaderboard Surface GUI (Front Face Recessed Screen)
	local sGui = Instance.new("SurfaceGui")
	sGui.Name = "LeaderboardGui"
	sGui.Face = Enum.NormalId.Front
	sGui.CanvasSize = Vector2.new(400, 600)
	sGui.LightInfluence = 0.4
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

	-- Spawn Location in Plaza (Framed Pad with DiamondPlate Border)
	local spawnBorder = createPart(
		"SpawnBorder",
		Vector3.new(14, 0.6, 14),
		CFrame.new(0, FLOOR_Y + 0.3, 26),
		Color3.fromRGB(30, 41, 59),
		Enum.Material.DiamondPlate,
		rootFolder,
		true
	)
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "PlazaSpawn"
	spawnPad.Size = Vector3.new(12, 0.4, 12)
	spawnPad.CFrame = CFrame.new(0, FLOOR_Y + 0.6, 26)
	spawnPad.Anchored = true
	spawnPad.CanCollide = true
	spawnPad.Material = Enum.Material.SmoothPlastic
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
		CFrame.new(0, FLOOR_Y + 0.6, -26),
		Color3.fromRGB(24, 24, 32),
		Enum.Material.Slate,
		rootFolder
	)
	createPart(
		"FusionAltarRing",
		Vector3.new(10, 0.3, 10),
		CFrame.new(0, FLOOR_Y + 1.35, -26),
		Color3.fromRGB(168, 85, 247),
		Enum.Material.Neon,
		rootFolder,
		false
	)
	local altarCore = createPart(
		"FusionAltarCore",
		Vector3.new(3.2, 3.2, 3.2),
		CFrame.new(0, FLOOR_Y + 4.2, -26),
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
			CFrame.new(Vector3.new(0, FLOOR_Y, -26) + offset),
			Color3.fromRGB(51, 65, 85),
			Enum.Material.Metal,
			rootFolder
		)
		createPart(
			`AltarPylonCap_{idx}`,
			Vector3.new(1.6, 0.6, 1.6),
			CFrame.new(Vector3.new(0, FLOOR_Y + 3.1, -26) + offset),
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

	-- ── 2.6. CENTRAL PLAZA SYNDICATE BLACK MARKET KIOSK ──
	ModelEngine.CreateSyndicateKiosk(rootFolder, CFrame.new(0, FLOOR_Y, -50))
	local brokerNpc = ModelEngine.CreateSyndicateBrokerNPC(rootFolder, CFrame.new(0, FLOOR_Y, -50) * CFrame.new(0, 0, 1.2))
	local brokerPrompt = brokerNpc:FindFirstChildWhichIsA("ProximityPrompt", true)
	if brokerPrompt then
		brokerPrompt.Triggered:Connect(function(player: Player)
			local openContractEvt = ReplicatedStorage:FindFirstChild("OpenContractModal") :: RemoteEvent?
			if openContractEvt then
				openContractEvt:FireClient(player)
			end
		end)
	end

	-- ── 3. BUILD 6 MODULAR FORTIFIED BUNKER PLOTS CIRCULARLY ──
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
		local plotPos = Vector3.new(plotDir.X * (radius + pLen / 2), ARENA_Y, plotDir.Z * (radius + pLen / 2))
		local faceCenterCF = CFrame.lookAt(plotPos, Vector3.new(0, ARENA_Y, 0))

		local pFolder = Instance.new("Folder")
		pFolder.Name = "Plot_" .. i
		pFolder.Parent = plotsFolder

		-- ── 3.1. INDUSTRIAL CATWALK BRIDGE (CONNECTS PLAZA TO BUNKER) ──
		local bridgePos = Vector3.new(plotDir.X * (radius - 4), FLOOR_Y - 0.2, plotDir.Z * (radius - 4))
		local bridgeCF = CFrame.lookAt(bridgePos, Vector3.new(0, FLOOR_Y - 0.2, 0))
		createPart(
			`CatwalkBridge_{i}`,
			Vector3.new(14, 0.4, 18),
			bridgeCF,
			Color3.fromRGB(51, 65, 85),
			Enum.Material.DiamondPlate,
			pFolder,
			true
		)
		local curbL = createPart(
			`BridgeCurbL_{i}`,
			Vector3.new(0.4, 0.6, 18),
			bridgeCF * CFrame.new(-6.8, 0.3, 0),
			Color3.fromRGB(56, 189, 248),
			Enum.Material.Neon,
			pFolder,
			false
		)
		local bLightL = Instance.new("PointLight")
		bLightL.Color = Color3.fromRGB(56, 189, 248)
		bLightL.Range = 22
		bLightL.Brightness = 2.2
		bLightL.Parent = curbL

		local curbR = createPart(
			`BridgeCurbR_{i}`,
			Vector3.new(0.4, 0.6, 18),
			bridgeCF * CFrame.new(6.8, 0.3, 0),
			Color3.fromRGB(56, 189, 248),
			Enum.Material.Neon,
			pFolder,
			false
		)
		local bLightR = Instance.new("PointLight")
		bLightR.Color = Color3.fromRGB(56, 189, 248)
		bLightR.Range = 22
		bLightR.Brightness = 2.2
		bLightR.Parent = curbR

		-- ── 3.2. ELEVATED BUNKER FOUNDATION FLOOR ──
		local floor = createPart(
			"PlotFloor",
			Vector3.new(pWidth, 4, pLen),
			faceCenterCF * CFrame.new(0, 0, 0),
			Color3.fromRGB(51, 65, 85),
			Enum.Material.Slate,
			pFolder
		)

		-- ── 3.3. FORTIFIED CYBER-VAULT BUNKER SHELL ──
		ModelEngine.CreateBunkerShell(pFolder, faceCenterCF * CFrame.new(0, 2, 0), pWidth, pLen, Config.Arena.WallHeight)

		-- ── 4. CHUNKY MULTI-TIER VAULT DOOR AT BACK ──
		local vaultDoorModel = ModelEngine.CreateVaultDoor(pFolder, faceCenterCF * CFrame.new(0, 2, pLen / 2 - 1.5))
		local vaultWheel = vaultDoorModel:FindFirstChild("CogWheelCenter") :: Part?

		-- ── 5. INDUSTRIAL MINT MACHINE & CONVEYOR ──
		local mintMachine = ModelEngine.CreateMintMachine(pFolder, faceCenterCF * CFrame.new(8, 2, 0))
		local conveyor = (mintMachine:FindFirstChild("BaseChassis") or mintMachine.PrimaryPart) :: Part
		local belt = (mintMachine:FindFirstChild("ConveyorBelt") or conveyor) :: Part
		local stampingHead = mintMachine:FindFirstChild("StampingHead") :: Part?

		-- ── 6. PHYSICAL HYDRAULIC DEPOSIT SWITCH ──
		local safeBtnModel, safePad = ModelEngine.CreateHydraulicFloorButton(
			pFolder,
			faceCenterCF * CFrame.new(0, 2, pLen / 2 - 9),
			Color3.fromRGB(16, 185, 129),
			"📥 STEP TO BANK"
		)

		-- ── 7. FRONT HIGH-VOLTAGE LASER PYLONS (SECURITY ENTRANCE) ──
		local leftLaserPost = createPart(
			"LaserPostLeft",
			Vector3.new(2.0, 10, 2.0),
			faceCenterCF * CFrame.new(-pWidth / 2 + 2.5, 7, -pLen / 2 + 1),
			Color3.fromRGB(51, 65, 85),
			Enum.Material.Metal,
			pFolder
		)
		local rightLaserPost = createPart(
			"LaserPostRight",
			Vector3.new(2.0, 10, 2.0),
			faceCenterCF * CFrame.new(pWidth / 2 - 2.5, 7, -pLen / 2 + 1),
			Color3.fromRGB(51, 65, 85),
			Enum.Material.Metal,
			pFolder
		)

		-- Glowing Magnetic Induction Rings on Pylons
		for _, yRing in { 4, 7, 10 } do
			createPart(
				`LaserRingL_{yRing}`,
				Vector3.new(2.4, 0.4, 2.4),
				leftLaserPost.CFrame * CFrame.new(0, yRing - 7, 0),
				Color3.fromRGB(245, 158, 11),
				Enum.Material.Neon,
				leftLaserPost,
				false
			)
			createPart(
				`LaserRingR_{yRing}`,
				Vector3.new(2.4, 0.4, 2.4),
				rightLaserPost.CFrame * CFrame.new(0, yRing - 7, 0),
				Color3.fromRGB(245, 158, 11),
				Enum.Material.Neon,
				rightLaserPost,
				false
			)
		end

		-- ── 7.5. BIOMETRIC SECURITY TERMINAL & AUTOMATED DEFENSE TURRET ──
		ModelEngine.CreateBiometricTerminal(pFolder, faceCenterCF * CFrame.new(-pWidth / 2 + 4.5, 2, -pLen / 2 + 4.5))
		-- Mounted directly onto the front elevated catwalk perch!
		ModelEngine.CreateSecurityTurret(pFolder, faceCenterCF * CFrame.new(0, Config.Arena.WallHeight + 2.2, -pLen / 2 + 2.6))

		-- ── 7.6. IN-WORLD PHYSICAL TYCOON UPGRADE CONSOLES ──
		local consoles = {}
		local cModel1, cBtn1, cGui1 = ModelEngine.CreateUpgradeConsole(
			pFolder,
			faceCenterCF * CFrame.new(-pWidth / 2 + 4.5, 2, 7),
			"Conveyor",
			"MINT PRESS OVERCLOCK",
			Color3.fromRGB(56, 189, 248)
		)
		local cModel2, cBtn2, cGui2 = ModelEngine.CreateUpgradeConsole(
			pFolder,
			faceCenterCF * CFrame.new(-pWidth / 2 + 4.5, 2, -2),
			"Laser",
			"LASER SECURITY MATRIX",
			Color3.fromRGB(245, 158, 11)
		)
		local cModel3, cBtn3, cGui3 = ModelEngine.CreateUpgradeConsole(
			pFolder,
			faceCenterCF * CFrame.new(pWidth / 2 - 4.5, 2, -2),
			"Turret",
			"AUTOMATED BASE TURRET",
			Color3.fromRGB(239, 68, 68)
		)
		consoles["Conveyor"] = { Model = cModel1, Button = cBtn1, Gui = cGui1 }
		consoles["Laser"] = { Model = cModel2, Button = cBtn2, Gui = cGui2 }
		consoles["Turret"] = { Model = cModel3, Button = cBtn3, Gui = cGui3 }

		local function handleConsolePress(player: Player, upType: string, btnPart: Part)
			local plot = PlotService._plots[i]
			if not plot or plot.Owner ~= player then return end

			-- Animate tactile button depression
			local downCF = btnPart:GetAttribute("DownCF") :: CFrame?
			local restCF = btnPart:GetAttribute("RestCF") :: CFrame?
			if downCF and restCF then
				TweenService:Create(btnPart, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { CFrame = downCF }):Play()
				task.delay(0.35, function()
					if btnPart and btnPart.Parent then
						TweenService:Create(btnPart, TweenInfo.new(0.25, Enum.EasingStyle.Back), { CFrame = restCF }):Play()
					end
				end)
			end

			local dataSvc = getDataService()
			if dataSvc then
				local success, msg = dataSvc.Upgrade(player, upType)
				if success then
					PlotService.UpdateConsolesForPlot(i)
				end
			end
		end

		for upType, info in consoles do
			info.Button.Touched:Connect(function(hit)
				local char = hit.Parent
				local p = char and Players:GetPlayerFromCharacter(char)
				if p then
					handleConsolePress(p, upType, info.Button)
				end
			end)
			local cd = info.Button:FindFirstChildOfClass("ClickDetector")
			if cd then
				cd.MouseClick:Connect(function(player)
					handleConsolePress(player, upType, info.Button)
				end)
			end
		end

		-- ── 8. SIREN BEACON ON BUNKER GATE LINTEL ──
		local siren = createPart(
			"SirenBeacon",
			Vector3.new(1.8, 2.4, 1.8),
			faceCenterCF * CFrame.new(0, Config.Arena.WallHeight + 3.4, -pLen / 2 + 1.2),
			Color3.fromRGB(239, 68, 68),
			Enum.Material.Neon,
			pFolder
		)

		-- Owner Billboard Mounted on Siren
		local ownerGui = Instance.new("BillboardGui")
		ownerGui.Name = "OwnerBillboard"
		ownerGui.Size = UDim2.new(0, 240, 0, 50)
		ownerGui.StudsOffset = Vector3.new(0, 2.4, 0)
		ownerGui.AlwaysOnTop = true
		ownerGui.Parent = siren

		local obText = Instance.new("TextLabel")
		obText.Name = "OwnerNameLabel"
		obText.Size = UDim2.new(1, 0, 1, 0)
		obText.BackgroundTransparency = 1
		obText.Text = `[VAULT #{i}: VACANT]`
		obText.TextColor3 = Color3.fromRGB(148, 163, 184)
		obText.TextSize = 16
		obText.Font = Enum.Font.GothamBold
		obText.Parent = ownerGui

		-- ── 8.5. BASE RELIC SHOWCASE PEDESTAL (FRONT ENTRANCE) ──
		local pedCF = faceCenterCF * CFrame.new(-9, 3.4, -pLen / 2 + 5.5)
		local pedBase = createPart(
			"ShowcasePedestal",
			Vector3.new(3.5, 2.8, 3.5),
			pedCF,
			Color3.fromRGB(24, 24, 32),
			Enum.Material.Metal,
			pFolder
		)
		local pedRing = createPart(
			"ShowcasePedestalRing",
			Vector3.new(3.8, 0.4, 3.8),
			pedCF * CFrame.new(0, 1.4, 0),
			Color3.fromRGB(56, 189, 248),
			Enum.Material.Neon,
			pFolder,
			false
		)
		local showcaseGem = createPart(
			"ShowcaseGem",
			Vector3.new(1.8, 1.8, 1.8),
			pedCF * CFrame.new(0, 3.2, 0),
			Color3.fromRGB(148, 163, 184),
			Enum.Material.Neon,
			pFolder,
			false
		)

		local showGui = Instance.new("BillboardGui")
		showGui.Name = "ShowcaseBillboard"
		showGui.Size = UDim2.new(0, 200, 0, 48)
		showGui.StudsOffset = Vector3.new(0, 2.2, 0)
		showGui.AlwaysOnTop = true
		showGui.Parent = showcaseGem

		local sLabel = Instance.new("TextLabel")
		sLabel.Size = UDim2.new(1, 0, 1, 0)
		sLabel.BackgroundTransparency = 1
		sLabel.Text = "👑 PRIZED RELIC\n[EMPTY]"
		sLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
		sLabel.TextSize = 11
		sLabel.Font = Enum.Font.GothamBlack
		sLabel.Parent = showGui

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
			ShowcaseGem = showcaseGem,
			ShowcaseRing = pedRing,
			ShowcaseLabel = sLabel,
			ShowcaseBaseCF = pedCF * CFrame.new(0, 3.2, 0),
			VaultDoorModel = vaultDoorModel,
			MintMachine = mintMachine,
			StampingHead = stampingHead,
			CurrentShowcaseModel = nil :: Model?,
			_isDoorOpening = false,
			Consoles = consoles,
		}

		-- Connect Touch on SafePad to automatically bank for owner or deposit stolen loot
		safePad.Touched:Connect(function(hit)
			local char = hit.Parent
			local p = char and Players:GetPlayerFromCharacter(char)
			if p and PlotService._plots[i].Owner == p then
				-- Animate physical plunger depression
				local restY = safePad:GetAttribute("RestY") :: number?
				if restY then
					TweenService:Create(safePad, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						CFrame = safePad.CFrame * CFrame.new(0, -0.35, 0)
					}):Play()
					task.delay(0.35, function()
						if safePad and safePad.Parent then
							TweenService:Create(safePad, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								CFrame = CFrame.new(safePad.Position.X, restY, safePad.Position.Z) * safePad.CFrame.Rotation
							}):Play()
						end
					end)
				end

				PlotService.AnimateVaultDoorOpen(i)
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

	-- Floating rotation animation for pedestal showcase 3D models & gems
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, plot in PlotService._plots do
			if plot.CurrentShowcaseModel and plot.ShowcaseBaseCF then
				local bob = math.sin(t * 3) * 0.35
				plot.CurrentShowcaseModel:PivotTo(plot.ShowcaseBaseCF * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * 1.5, 0))
			elseif plot.ShowcaseGem and plot.ShowcaseBaseCF then
				local bob = math.sin(t * 3) * 0.35
				plot.ShowcaseGem.CFrame = plot.ShowcaseBaseCF * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * 1.5, 0)
			end
		end
	end)

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

	PlotService.UpdateShowcase(assignedIndex)
	PlotService.UpdateConsolesForPlot(assignedIndex)
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
	PlotService.UpdateShowcase(plotIndex)
	PlotService.UpdateConsolesForPlot(plotIndex)
	print(`  [PlotService] Released Vault #{plotIndex} from {player.Name}`)
end

function PlotService.GetPlotForPlayer(player: Player): any?
	local idx = PlotService._playerPlots[player]
	return idx and PlotService._plots[idx] or nil
end

function PlotService.GetPlotByIndex(index: number): any?
	return PlotService._plots[index]
end

function PlotService.AnimateVaultDoorOpen(plotIndex: number)
	local plot = PlotService._plots[plotIndex]
	if not plot or not plot.VaultDoorModel then return end
	if plot._isDoorOpening then return end
	plot._isDoorOpening = true

	local doorModel = plot.VaultDoorModel
	local wheel = doorModel:FindFirstChild("CogWheelCenter") :: Part?
	local doorSlab = doorModel:FindFirstChild("DoorSlab") :: Part?
	local pinL = doorModel:FindFirstChild("LockingPinLeft") :: Part?
	local pinR = doorModel:FindFirstChild("LockingPinRight") :: Part?

	-- Spin cog wheel 360 degrees
	if wheel then
		local startCF = wheel.CFrame
		TweenService:Create(wheel, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = startCF * CFrame.Angles(0, 0, math.rad(360))
		}):Play()
	end

	-- Retract locking pins
	if pinL and pinR then
		local origL = pinL.CFrame
		local origR = pinR.CFrame
		TweenService:Create(pinL, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CFrame = origL * CFrame.new(1.2, 0, 0) }):Play()
		TweenService:Create(pinR, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CFrame = origR * CFrame.new(-1.2, 0, 0) }):Play()

		task.delay(2.2, function()
			TweenService:Create(pinL, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = origL }):Play()
			TweenService:Create(pinR, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = origR }):Play()
		end)
	end

	-- Swing open heavy door
	if doorSlab then
		local origDoorCF = doorSlab.CFrame
		task.delay(0.2, function()
			TweenService:Create(doorSlab, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = origDoorCF * CFrame.Angles(0, math.rad(-75), 0)
			}):Play()
		end)

		task.delay(2.5, function()
			TweenService:Create(doorSlab, TweenInfo.new(0.8, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
				CFrame = origDoorCF
			}):Play()
			task.wait(0.85)
			plot._isDoorOpening = false
		end)
	else
		plot._isDoorOpening = false
	end
end

function PlotService.UpdateShowcase(plotIndex: number)
	local plot = PlotService._plots[plotIndex]
	if not plot or not plot.ShowcaseGem or not plot.ShowcaseLabel then return end

	if plot.CurrentShowcaseModel then
		plot.CurrentShowcaseModel:Destroy()
		plot.CurrentShowcaseModel = nil
	end

	local owner = plot.Owner
	if not owner then
		plot.ShowcaseGem.Transparency = 0.8
		plot.ShowcaseGem.Color = Color3.fromRGB(100, 116, 139)
		plot.ShowcaseLabel.Text = "👑 PRIZED RELIC\n[VACANT]"
		plot.ShowcaseLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
		if plot.ShowcaseRing then plot.ShowcaseRing.Color = Color3.fromRGB(71, 85, 105) end
		return
	end

	local dataSvc = getDataService()
	local data = dataSvc and dataSvc.GetData(owner)
	local inventory = data and data.RelicInventory

	local priority = {
		"CelestialCrown",
		"VoidChronometer",
		"DiamondSkull",
		"RubyArtifact",
		"EmeraldMatrix",
		"GoldStack",
	}

	local bestId: string? = nil
	if inventory then
		for _, id in priority do
			if (inventory[id] or 0) > 0 then
				bestId = id
				break
			end
		end
	end

	if bestId and RelicData.Catalog[bestId] then
		local def = RelicData.Catalog[bestId]
		local relicModel = ModelEngine.CreateRelicModel(bestId, plot.ShowcaseBaseCF)
		relicModel.Parent = plot.Folder
		plot.CurrentShowcaseModel = relicModel

		plot.ShowcaseGem.Transparency = 1
		plot.ShowcaseLabel.Text = `👑 PRIZED RELIC\n{def.Name}`
		plot.ShowcaseLabel.TextColor3 = def.Color
		if plot.ShowcaseRing then plot.ShowcaseRing.Color = def.Color end
	else
		plot.ShowcaseGem.Transparency = 0.6
		plot.ShowcaseGem.Color = Color3.fromRGB(148, 163, 184)
		plot.ShowcaseLabel.Text = "👑 PRIZED RELIC\n[NO RELICS]"
		plot.ShowcaseLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
		if plot.ShowcaseRing then plot.ShowcaseRing.Color = Color3.fromRGB(56, 189, 248) end
	end
end

function PlotService.UpdateShowcaseForPlayer(player: Player)
	local idx = PlotService._playerPlots[player]
	if idx then
		PlotService.UpdateShowcase(idx)
	end
end

function PlotService.UpdateConsolesForPlot(plotIndex: number)
	local plot = PlotService._plots[plotIndex]
	if not plot or not plot.Consoles then return end

	local owner = plot.Owner
	local dataSvc = getDataService()
	local data = owner and dataSvc and dataSvc.GetData(owner)

	-- 1. Conveyor Console
	local convInfo = plot.Consoles["Conveyor"]
	if convInfo and convInfo.Gui then
		local card = convInfo.Gui:FindFirstChild("HoloCard")
		if card then
			local statLbl = card:FindFirstChild("StatLabel") :: TextLabel?
			local costLbl = card:FindFirstChild("CostLabel") :: TextLabel?
			if not owner or not data then
				if statLbl then statLbl.Text = "Level 1" end
				if costLbl then costLbl.Text = "Cost: $50" end
			else
				local lv = data.ConveyorLevel or 1
				local maxLv = Config.Economy.MaxConveyorLevel
				local income = Config.Economy.GetConveyorIncome(lv, data.PrestigeTokens or 0)
				local cost = Config.Economy.GetConveyorCost(lv + 1)
				if statLbl then statLbl.Text = `Lv {lv}/{maxLv} (${income}/sec)` end
				if costLbl then costLbl.Text = (lv >= maxLv) and "MAX LEVEL" or `Cost: ${cost}` end
			end
		end
	end

	-- 2. Laser Console
	local laserInfo = plot.Consoles["Laser"]
	if laserInfo and laserInfo.Gui then
		local card = laserInfo.Gui:FindFirstChild("HoloCard")
		if card then
			local statLbl = card:FindFirstChild("StatLabel") :: TextLabel?
			local costLbl = card:FindFirstChild("CostLabel") :: TextLabel?
			if not owner or not data then
				if statLbl then statLbl.Text = "Tier 1" end
				if costLbl then costLbl.Text = "Cost: $250" end
			else
				local tier = data.LaserTier or 1
				local maxTier = Config.Economy.MaxLaserTier
				local dmg = Config.Heist.LaserDamageByTier[tier] or 20
				local cost = Config.Economy.GetLaserCost(tier + 1)
				if statLbl then statLbl.Text = `Tier {tier}/{maxTier} ({dmg} DPS)` end
				if costLbl then costLbl.Text = (tier >= maxTier) and "MAX TIER" or `Cost: ${cost}` end
			end
		end
	end

	-- 3. Turret Console
	local turretInfo = plot.Consoles["Turret"]
	if turretInfo and turretInfo.Gui then
		local card = turretInfo.Gui:FindFirstChild("HoloCard")
		if card then
			local statLbl = card:FindFirstChild("StatLabel") :: TextLabel?
			local costLbl = card:FindFirstChild("CostLabel") :: TextLabel?
			if not owner or not data then
				if statLbl then statLbl.Text = "Tier 1: Sentry Minigun" end
				if costLbl then costLbl.Text = "Cost: $500" end
			else
				local tier = data.TurretTier or 1
				local maxTier = Config.Turret.MaxTier or 4
				local spec = Config.Turret.TierSpecs[tier] or Config.Turret.TierSpecs[1]
				local cost = Config.Economy.GetTurretCost(tier + 1)
				if statLbl then statLbl.Text = `Tier {tier}/{maxTier}: {spec.Name}` end
				if costLbl then costLbl.Text = (tier >= maxTier) and "MAX TIER" or `Cost: ${cost}` end
			end
		end
	end
end

return PlotService
