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

	-- ── 2.6. CENTRAL PLAZA SYNDICATE BLACK MARKET KIOSK ──
	ModelEngine.CreateSyndicateKiosk(rootFolder, CFrame.new(0, 0, -50))

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

		-- ── 4. CHUNKY MULTI-TIER VAULT DOOR AT BACK ──
		local vaultDoorModel = ModelEngine.CreateVaultDoor(pFolder, faceCenterCF * CFrame.new(0, 0, pLen / 2 - 1.5))
		local vaultWheel = vaultDoorModel:FindFirstChild("CogWheelCenter") :: Part?

		-- ── 5. INDUSTRIAL MINT MACHINE & CONVEYOR ──
		local mintMachine = ModelEngine.CreateMintMachine(pFolder, faceCenterCF * CFrame.new(8, 0, 0))
		local conveyor = (mintMachine:FindFirstChild("BaseChassis") or mintMachine.PrimaryPart) :: Part
		local belt = (mintMachine:FindFirstChild("ConveyorBelt") or conveyor) :: Part
		local stampingHead = mintMachine:FindFirstChild("StampingHead") :: Part?

		-- ── 6. PHYSICAL HYDRAULIC DEPOSIT SWITCH ──
		local safeBtnModel, safePad = ModelEngine.CreateHydraulicFloorButton(
			pFolder,
			faceCenterCF * CFrame.new(0, 0, pLen / 2 - 9),
			Color3.fromRGB(16, 185, 129),
			"📥 STEP TO BANK"
		)

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

		-- ── 7.5. BIOMETRIC SECURITY TERMINAL & AUTOMATED DEFENSE TURRET ──
		ModelEngine.CreateBiometricTerminal(pFolder, faceCenterCF * CFrame.new(-pWidth / 2 + 4.5, 0, -pLen / 2 + 3.5))
		ModelEngine.CreateSecurityTurret(pFolder, faceCenterCF * CFrame.new(0, 10.4, -pLen / 2 + 1))

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

		-- ── 8.5. BASE RELIC SHOWCASE PEDESTAL (FRONT PLAZA ENTRANCE) ──
		local pedCF = faceCenterCF * CFrame.new(-9, 1.4, -pLen / 2 + 5)
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

return PlotService
