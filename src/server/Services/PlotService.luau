--!strict
--[[
	PlotService.luau — Procedural Plot & In-World Tycoon Engine for VAULT WARS: STEAL & DEFEND TYCOON
	Constructs 6 circular base plots around a cyber-industrial central plaza, featuring:
	- Elevated Central Command Arrival Platform with panoramic view & wide stairs
	- Towering Leaderboard Monolith, Syndicate Container Outpost & Relic Fusion Chamber
	- Physical [ STEP TO CLAIM BASE ] pads at each vault entrance
	- 9 Sequential Physical Step-On Tycoon Buttons with tactile depression, audio & particle bursts
	- Real-time persistent building restoration from DataService
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

local function getTurretService(): any?
	local svc = script.Parent:FindFirstChild("TurretService")
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
-- ORDERED TYCOON UPGRADE SPECIFICATIONS
-- ============================================================
local ORDERED_UPGRADES = {
	"MintPress",
	"BankSafe",
	"BlastWalls",
	"LaserGrid",
	"VaultDoor",
	"ConveyorOverclock",
	"DefenseTurret",
	"RelicPedestal",
	"SecurityAlarm",
}

local UPGRADE_DEFS: { [string]: any } = {
	MintPress = {
		Order = 1,
		Title = "Hydraulic Mint Press",
		Cost = 0,
		AccentColor = Color3.fromRGB(16, 185, 129),
		ButtonOffset = Vector3.new(0, 2.0, -12),
		Build = function(plot: any)
			if plot.BuiltObjects["MintPress"] then return end
			local mintCF = plot.CF * CFrame.new(8, 2, 0)
			local mintMachine = ModelEngine.GetOrBuild("MintMachine", plot.Folder, mintCF, function()
				return ModelEngine.CreateMintMachine(plot.Folder, mintCF)
			end)
			plot.MintMachine = mintMachine
			plot.Conveyor = mintMachine:FindFirstChild("BaseChassis") or mintMachine.PrimaryPart
			plot.Belt = mintMachine:FindFirstChild("ConveyorBelt") or plot.Conveyor
			plot.StampingHead = mintMachine:FindFirstChild("StampingHead")
			plot.BuiltObjects["MintPress"] = mintMachine
		end,
	},
	BankSafe = {
		Order = 2,
		Title = "Bank Safe & Deposit Pad",
		Cost = 50,
		AccentColor = Color3.fromRGB(245, 158, 11),
		ButtonOffset = Vector3.new(-5, 2.0, -6),
		Build = function(plot: any)
			if plot.BuiltObjects["BankSafe"] then return end

			-- Collector safe at conveyor terminus
			local safeModel = Instance.new("Model")
			safeModel.Name = "BankSafeCollector"
			safeModel.Parent = plot.Folder

			local hopper = createPart("SafeHopper", Vector3.new(5.0, 5.0, 5.0), plot.CF * CFrame.new(8, 4.5, 10), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, safeModel, true)
			safeModel.PrimaryPart = hopper
			createPart("HopperTrim", Vector3.new(5.4, 0.4, 5.4), plot.CF * CFrame.new(8, 7.2, 10), Color3.fromRGB(16, 185, 129), Enum.Material.Neon, safeModel, false)

			-- Deposit plunger floor pad
			local pLen = Config.Arena.PlotLength
			local safeBtnModel, safePad = ModelEngine.CreateHydraulicFloorButton(
				plot.Folder,
				plot.CF * CFrame.new(0, 2, pLen / 2 - 9),
				Color3.fromRGB(16, 185, 129),
				"📥 STEP TO BANK $"
			)
			plot.SafePad = safePad
			plot.BuiltObjects["BankSafe"] = safeModel
			plot.BuiltObjects["SafeButtonModel"] = safeBtnModel

			-- Connect touch to bank unbanked cash into permanent net worth
			safePad.Touched:Connect(function(hit)
				local char = hit.Parent
				local p = char and Players:GetPlayerFromCharacter(char)
				if p and plot.Owner == p then
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

					PlotService.AnimateVaultDoorOpen(plot.Index)
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
		end,
	},
	BlastWalls = {
		Order = 3,
		Title = "Bunker Blast Walls",
		Cost = 150,
		AccentColor = Color3.fromRGB(56, 189, 248),
		ButtonOffset = Vector3.new(-5, 2.0, 0),
		Build = function(plot: any)
			if plot.BuiltObjects["BlastWalls"] then return end
			local shellCF = plot.CF * CFrame.new(0, 2, 0)
			local shell = ModelEngine.GetOrBuild("BunkerShell", plot.Folder, shellCF, function()
				return ModelEngine.CreateBunkerShell(plot.Folder, shellCF, Config.Arena.PlotWidth, Config.Arena.PlotLength, Config.Arena.WallHeight)
			end)
			plot.BuiltObjects["BlastWalls"] = shell
		end,
	},
	LaserGrid = {
		Order = 4,
		Title = "Security Laser Grid",
		Cost = 300,
		AccentColor = Color3.fromRGB(239, 68, 68),
		ButtonOffset = Vector3.new(0, 2.0, -16),
		Build = function(plot: any)
			if plot.BuiltObjects["LaserGrid"] then return end
			local pWidth = Config.Arena.PlotWidth
			local pLen = Config.Arena.PlotLength
			local faceCenterCF = plot.CF

			local leftLaserPost = createPart(
				"LaserPostLeft",
				Vector3.new(2.0, 10, 2.0),
				faceCenterCF * CFrame.new(-pWidth / 2 + 2.5, 7, -pLen / 2 + 1),
				Color3.fromRGB(51, 65, 85),
				Enum.Material.Metal,
				plot.Folder
			)
			local rightLaserPost = createPart(
				"LaserPostRight",
				Vector3.new(2.0, 10, 2.0),
				faceCenterCF * CFrame.new(pWidth / 2 - 2.5, 7, -pLen / 2 + 1),
				Color3.fromRGB(51, 65, 85),
				Enum.Material.Metal,
				plot.Folder
			)

			for _, yRing in { 4, 7, 10 } do
				createPart(`LaserRingL_{yRing}`, Vector3.new(2.4, 0.4, 2.4), leftLaserPost.CFrame * CFrame.new(0, yRing - 7, 0), Color3.fromRGB(245, 158, 11), Enum.Material.Neon, leftLaserPost, false)
				createPart(`LaserRingR_{yRing}`, Vector3.new(2.4, 0.4, 2.4), rightLaserPost.CFrame * CFrame.new(0, yRing - 7, 0), Color3.fromRGB(245, 158, 11), Enum.Material.Neon, rightLaserPost, false)
			end

			plot.LeftPost = leftLaserPost
			plot.RightPost = rightLaserPost

			local laserSvc = getLaserService()
			if laserSvc then
				laserSvc.BuildLaserBeam(plot)
			end

			plot.BuiltObjects["LaserGrid"] = leftLaserPost
			plot.BuiltObjects["LaserRightPost"] = rightLaserPost
		end,
	},
	VaultDoor = {
		Order = 5,
		Title = "Cogwheel Vault Door",
		Cost = 600,
		AccentColor = Color3.fromRGB(168, 85, 247),
		ButtonOffset = Vector3.new(0, 2.0, 6),
		Build = function(plot: any)
			if plot.BuiltObjects["VaultDoor"] then return end
			local pLen = Config.Arena.PlotLength
			local doorCF = plot.CF * CFrame.new(0, 2, pLen / 2 - 1.5)
			local door = ModelEngine.GetOrBuild("VaultDoor", plot.Folder, doorCF, function()
				return ModelEngine.CreateVaultDoor(plot.Folder, doorCF)
			end)
			plot.VaultDoorModel = door
			plot.BuiltObjects["VaultDoor"] = door
		end,
	},
	ConveyorOverclock = {
		Order = 6,
		Title = "Overclock Coils (2x Speed)",
		Cost = 1200,
		AccentColor = Color3.fromRGB(234, 179, 8),
		ButtonOffset = Vector3.new(0, 2.0, 0),
		Build = function(plot: any)
			if plot.BuiltObjects["ConveyorOverclock"] then return end
			local coils = Instance.new("Model")
			coils.Name = "OverclockCoils"
			coils.Parent = plot.Folder
			for cZ = -4, 4, 2.5 do
				createPart("InductionRing", Vector3.new(6.8, 0.6, 1.2), plot.CF * CFrame.new(8, 5.5, cZ), Color3.fromRGB(250, 204, 21), Enum.Material.Neon, coils, false)
			end
			plot.BuiltObjects["ConveyorOverclock"] = coils
		end,
	},
	DefenseTurret = {
		Order = 7,
		Title = "Automated Sentry Turret",
		Cost = 2500,
		AccentColor = Color3.fromRGB(239, 68, 68),
		ButtonOffset = Vector3.new(-6, 2.0, -10),
		Build = function(plot: any)
			if plot.BuiltObjects["DefenseTurret"] then return end
			local pLen = Config.Arena.PlotLength
			local turretCF = plot.CF * CFrame.new(0, Config.Arena.WallHeight + 2.2, -pLen / 2 + 2.6)
			local turret = ModelEngine.GetOrBuild("SecurityTurret", plot.Folder, turretCF, function()
				return ModelEngine.CreateSecurityTurret(plot.Folder, turretCF)
			end)
			local turretSvc = getTurretService()
			if turretSvc and turretSvc.RegisterTurret then
				turretSvc.RegisterTurret(plot.Index, turret)
			end
			plot.BuiltObjects["DefenseTurret"] = turret
		end,
	},
	RelicPedestal = {
		Order = 8,
		Title = "Prized Relic Showcase",
		Cost = 5000,
		AccentColor = Color3.fromRGB(216, 180, 254),
		ButtonOffset = Vector3.new(-5, 2.0, 6),
		Build = function(plot: any)
			if plot.BuiltObjects["RelicPedestal"] then return end
			local pLen = Config.Arena.PlotLength
			local pedCF = plot.CF * CFrame.new(-9, 3.4, -pLen / 2 + 5.5)

			local pedBase = createPart("ShowcasePedestal", Vector3.new(3.5, 2.8, 3.5), pedCF, Color3.fromRGB(24, 24, 32), Enum.Material.Metal, plot.Folder)
			local pedRing = createPart("ShowcasePedestalRing", Vector3.new(3.8, 0.4, 3.8), pedCF * CFrame.new(0, 1.4, 0), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, plot.Folder, false)
			local showcaseGem = createPart("ShowcaseGem", Vector3.new(1.8, 1.8, 1.8), pedCF * CFrame.new(0, 3.2, 0), Color3.fromRGB(148, 163, 184), Enum.Material.Neon, plot.Folder, false)

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

			plot.ShowcaseGem = showcaseGem
			plot.ShowcaseRing = pedRing
			plot.ShowcaseLabel = sLabel
			plot.ShowcaseBaseCF = pedCF * CFrame.new(0, 3.2, 0)

			plot.BuiltObjects["RelicPedestal"] = pedBase
			plot.BuiltObjects["PedRing"] = pedRing
			plot.BuiltObjects["ShowcaseGem"] = showcaseGem

			PlotService.UpdateShowcase(plot.Index)
		end,
	},
	SecurityAlarm = {
		Order = 9,
		Title = "Emergency Alarm & Siren",
		Cost = 10000,
		AccentColor = Color3.fromRGB(239, 68, 68),
		ButtonOffset = Vector3.new(-6, 2.0, 12),
		Build = function(plot: any)
			if plot.BuiltObjects["SecurityAlarm"] then return end
			local pLen = Config.Arena.PlotLength
			local pWidth = Config.Arena.PlotWidth

			local siren = createPart(
				"SirenBeacon",
				Vector3.new(1.8, 2.4, 1.8),
				plot.CF * CFrame.new(0, Config.Arena.WallHeight + 3.4, -pLen / 2 + 1.2),
				Color3.fromRGB(239, 68, 68),
				Enum.Material.Neon,
				plot.Folder
			)
			plot.Siren = siren

			local terminal = ModelEngine.CreateBiometricTerminal(plot.Folder, plot.CF * CFrame.new(-pWidth / 2 + 4.5, 2, -pLen / 2 + 4.5))
			plot.BuiltObjects["SecurityAlarm"] = siren
			plot.BuiltObjects["Terminal"] = terminal
		end,
	},
}

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

	-- ── 1. CENTRAL LOBBY PLAZA CORE & MULTI-TIER DECKS ──
	-- 1.1. Central Command Hub Deck (Radius ~29, 58x58 square core, zero overlap with plots)
	local plazaCore = createPart(
		"CentralPlazaCore",
		Vector3.new(58, 2.0, 58),
		CFrame.new(0, 3.0, 0),
		Color3.fromRGB(30, 36, 52),
		Enum.Material.Slate,
		rootFolder,
		true
	)

	-- 1.2. North Syndicate Black Market Trading Pier (Extends from Z=-29 to Z=-57)
	local northPier = createPart(
		"NorthSyndicatePier",
		Vector3.new(22, 2.0, 28),
		CFrame.new(0, 3.0, -43),
		Color3.fromRGB(26, 32, 46),
		Enum.Material.DiamondPlate,
		rootFolder,
		true
	)
	-- Amber Hazard Curb & Rails on North Pier
	createPart("NorthPierCurbL", Vector3.new(0.6, 1.0, 28), CFrame.new(-10.7, 4.2, -43), Color3.fromRGB(24, 28, 40), Enum.Material.Metal, rootFolder, true)
	createPart("NorthPierTrimL", Vector3.new(0.3, 0.3, 28), CFrame.new(-10.7, 4.85, -43), Color3.fromRGB(245, 158, 11), Enum.Material.Neon, rootFolder, false)
	createPart("NorthPierRailL", Vector3.new(0.4, 3.2, 28), CFrame.new(-10.7, 6.0, -43), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, rootFolder, true)

	createPart("NorthPierCurbR", Vector3.new(0.6, 1.0, 28), CFrame.new(10.7, 4.2, -43), Color3.fromRGB(24, 28, 40), Enum.Material.Metal, rootFolder, true)
	createPart("NorthPierTrimR", Vector3.new(0.3, 0.3, 28), CFrame.new(10.7, 4.85, -43), Color3.fromRGB(245, 158, 11), Enum.Material.Neon, rootFolder, false)
	createPart("NorthPierRailR", Vector3.new(0.4, 3.2, 28), CFrame.new(10.7, 6.0, -43), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, rootFolder, true)

	createPart("NorthPierEndCurb", Vector3.new(22, 1.0, 0.6), CFrame.new(0, 4.2, -56.7), Color3.fromRGB(24, 28, 40), Enum.Material.Metal, rootFolder, true)
	createPart("NorthPierEndRail", Vector3.new(22, 3.2, 0.4), CFrame.new(0, 6.0, -56.7), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, rootFolder, true)

	-- 1.3. Central Raised Command Dais (Stepped up +0.6 studs to Y=4.6)
	createPart(
		"PlazaCenterDais",
		Vector3.new(34, 0.6, 34),
		CFrame.new(0, 4.3, 0),
		Color3.fromRGB(20, 24, 34),
		Enum.Material.DiamondPlate,
		rootFolder,
		true
	)

	-- Dais Outer Trim & Recessed Cyan Circuit Conduits (Thin 0.2-stud channels, zero solid neon slabs!)
	for a = 0, 7 do
		local radAngle = a * (math.pi / 4)
		local dCF = CFrame.new(0, 4.65, 0) * CFrame.Angles(0, radAngle, 0) * CFrame.new(0, 0, 13)
		createPart(`DaisTrim_{a}`, Vector3.new(9.8, 0.2, 0.8), dCF, Color3.fromRGB(30, 41, 59), Enum.Material.Metal, rootFolder, true)
		createPart(`DaisConduit_{a}`, Vector3.new(9.4, 0.05, 0.15), dCF * CFrame.new(0, 0.1, 0), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, rootFolder, false)
	end

	-- ── 2. CENTRAL SUBTERRANEAN CYBER-REACTOR & COMMAND VAULT ──
	local reactorFolder = Instance.new("Folder")
	reactorFolder.Name = "CentralCyberReactor"
	reactorFolder.Parent = rootFolder

	-- Heavy Octagonal Cast-Concrete Plinth
	createPart("ReactorBaseTier1", Vector3.new(24, 1.8, 24), CFrame.new(0, 5.0, 0), Color3.fromRGB(24, 28, 40), Enum.Material.Concrete, reactorFolder, true)
	createPart("ReactorBaseTier2", Vector3.new(20, 1.4, 20), CFrame.new(0, 6.4, 0), Color3.fromRGB(30, 41, 59), Enum.Material.DiamondPlate, reactorFolder, true)
	createPart("ReactorCautionBorder", Vector3.new(20.4, 0.3, 20.4), CFrame.new(0, 7.15, 0), Color3.fromRGB(245, 158, 11), Enum.Material.SmoothPlastic, reactorFolder, false)

	-- Central Plasma Energy Chamber: Tempered Glass Shell with Internal Glowing Plasma Rod
	local innerPlasmaRod = createPart("ReactorPlasmaRod", Vector3.new(3.4, 18, 3.4), CFrame.new(0, 17.5, 0), Color3.fromRGB(14, 165, 233), Enum.Material.Neon, reactorFolder, false)
	Instance.new("CylinderMesh", innerPlasmaRod)

	local glassChamber = createPart("ReactorGlassChamber", Vector3.new(7.6, 19, 7.6), CFrame.new(0, 17.5, 0), Color3.fromRGB(15, 23, 42), Enum.Material.Glass, reactorFolder, false)
	glassChamber.Transparency = 0.55
	Instance.new("CylinderMesh", glassChamber)

	local coreLight = Instance.new("PointLight")
	coreLight.Color = Color3.fromRGB(56, 189, 248)
	coreLight.Range = 36
	coreLight.Brightness = 2.0
	coreLight.Parent = innerPlasmaRod

	-- Slotted Dark Steel Reactor Containment Cage around Core (8 Structural Pillars)
	for a = 0, 7 do
		local radAngle = a * (math.pi / 4)
		local pX = math.cos(radAngle) * 5.6
		local pZ = math.sin(radAngle) * 5.6
		createPart(`ReactorCagePillar_{a}`, Vector3.new(1.4, 20, 1.4), CFrame.new(pX, 17.5, pZ), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, reactorFolder, true)
	end

	-- 4 Heavy Steel Structural Pylon Buttresses (North, South, East, West)
	for _, dir in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local buttress = createPart("ReactorButtressPylon", Vector3.new(3.2, 24, 3.2), CFrame.new(dir * 11 + Vector3.new(0, 17.5, 0)), Color3.fromRGB(38, 46, 60), Enum.Material.Metal, reactorFolder, true)
		createPart("ButtressHazardTrim", Vector3.new(3.4, 6.0, 0.3), buttress.CFrame * CFrame.new(0, -6.0, 1.7), Color3.fromRGB(245, 158, 11), Enum.Material.SmoothPlastic, buttress, false)

		-- Downward Sodium Floodlights on Pylons
		local fFixture = createPart("ReactorFloodFixture", Vector3.new(2.4, 0.8, 2.4), CFrame.new(dir * 11 + Vector3.new(0, 28, 0)), Color3.fromRGB(254, 240, 138), Enum.Material.Neon, buttress, false)
		local fSpot = Instance.new("SpotLight")
		fSpot.Face = Enum.NormalId.Bottom
		fSpot.Angle = 110
		fSpot.Range = 55
		fSpot.Brightness = 2.8
		fSpot.Color = Color3.fromRGB(255, 248, 235)
		fSpot.Shadows = true
		fSpot.Parent = fFixture
	end

	-- Overhead Segmented Magnetic Containment Collars (Mechanical rings with thin recessed LED strips)
	for a = 0, 7 do
		local radAngle = a * (math.pi / 4)
		-- Top cyan collar at Y=26, radius 7.5
		local topCF = CFrame.new(0, 26, 0) * CFrame.Angles(0, radAngle, 0) * CFrame.new(0, 0, 7.5)
		createPart(`CollarTopSeg_{a}`, Vector3.new(5.8, 1.2, 1.0), topCF, Color3.fromRGB(30, 41, 59), Enum.Material.Metal, reactorFolder, true)
		createPart(`CollarTopTrim_{a}`, Vector3.new(5.6, 0.15, 0.2), topCF * CFrame.new(0, 0, 0.55), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, reactorFolder, false)

		-- Mid amber collar at Y=20, radius 8.5
		local midCF = CFrame.new(0, 20, 0) * CFrame.Angles(0, radAngle, 0) * CFrame.new(0, 0, 8.5)
		createPart(`CollarMidSeg_{a}`, Vector3.new(6.6, 1.0, 1.0), midCF, Color3.fromRGB(30, 41, 59), Enum.Material.Metal, reactorFolder, true)
		createPart(`CollarMidTrim_{a}`, Vector3.new(6.4, 0.15, 0.2), midCF * CFrame.new(0, 0, 0.55), Color3.fromRGB(245, 158, 11), Enum.Material.Neon, reactorFolder, false)
	end

	-- Leaderboard Array (Embedded smoothly into South face of reactor towards arrivals)
	local lbBacking = createPart("LeaderboardBacking", Vector3.new(11, 14, 1.2), CFrame.new(0, 16.5, 6.2), Color3.fromRGB(15, 17, 26), Enum.Material.Metal, reactorFolder, true)
	local sGui = Instance.new("SurfaceGui")
	sGui.Name = "LeaderboardGui"
	sGui.Face = Enum.NormalId.Front
	sGui.CanvasSize = Vector2.new(450, 600)
	sGui.LightInfluence = 0.2
	sGui.Parent = lbBacking

	local lbTitle = Instance.new("TextLabel")
	lbTitle.Size = UDim2.new(1, 0, 0, 65)
	lbTitle.BackgroundColor3 = Color3.fromRGB(11, 13, 20)
	lbTitle.Text = "TOP VAULT NET WORTH"
	lbTitle.TextColor3 = Color3.fromRGB(56, 189, 248)
	lbTitle.TextSize = 22
	lbTitle.Font = Enum.Font.BuilderSansExtraBold
	lbTitle.Parent = sGui

	local lbFrame = Instance.new("Frame")
	lbFrame.Name = "LeaderboardList"
	lbFrame.Size = UDim2.new(1, 0, 1, -65)
	lbFrame.Position = UDim2.new(0, 0, 0, 65)
	lbFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	lbFrame.BorderSizePixel = 0
	lbFrame.Parent = sGui

	-- ── 2.4. SECTOR-7 TRANSIT DOCK (Authentic Subterranean Station Terminal) ──
	local deckH = FLOOR_Y + 4.5 -- 8.5
	local stationFolder = Instance.new("Folder")
	stationFolder.Name = "Sector7TransitTerminal"
	stationFolder.Parent = rootFolder

	createPart(
		"ArrivalDeck",
		Vector3.new(34, 2.0, 20),
		CFrame.new(0, deckH, 36),
		Color3.fromRGB(24, 28, 40),
		Enum.Material.DiamondPlate,
		stationFolder,
		true
	)

	-- Station Back Security Wall (Encloses the South boundary behind spawns)
	local stationBackWall = createPart(
		"StationBackWall",
		Vector3.new(36, 16, 3.6),
		CFrame.new(0, deckH + 8, 46.5),
		Color3.fromRGB(30, 36, 48),
		Enum.Material.Concrete,
		stationFolder,
		true
	)
	for _, pX in { -16, -8, 0, 8, 16 } do
		createPart(`StationPilaster_{pX}`, Vector3.new(1.8, 16.5, 2.0), CFrame.new(pX, deckH + 8, 45.2), Color3.fromRGB(18, 22, 32), Enum.Material.Metal, stationBackWall, true)
	end
	createPart("StationHazardStripe", Vector3.new(34, 1.2, 0.4), CFrame.new(0, deckH + 3.0, 44.5), Color3.fromRGB(245, 158, 11), Enum.Material.SmoothPlastic, stationBackWall, false)

	-- Overhead High-Bay Station Floodlights
	for _, lX in { -10, 0, 10 } do
		local stFlood = createPart(`StationFlood_{lX}`, Vector3.new(3.0, 0.6, 2.0), CFrame.new(lX, deckH + 14.5, 43.5), Color3.fromRGB(254, 240, 138), Enum.Material.Neon, stationBackWall, false)
		local sLight = Instance.new("SpotLight")
		sLight.Face = Enum.NormalId.Bottom
		sLight.Range = 40
		sLight.Angle = 90
		sLight.Brightness = 3.5
		sLight.Color = Color3.fromRGB(255, 248, 230)
		sLight.Shadows = true
		sLight.Parent = stFlood
	end

	-- Left and Right Security Railings
	createPart("DeckRailL", Vector3.new(0.6, 3.6, 20), CFrame.new(-16.7, deckH + 2.5, 36), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, stationFolder, true)
	createPart("DeckRailR", Vector3.new(0.6, 3.6, 20), CFrame.new(16.7, deckH + 2.5, 36), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, stationFolder, true)

	-- Twin Wide Concrete Staircases Leading Down to Plaza
	for _, xStair in { -8.5, 8.5 } do
		for step = 1, 6 do
			local sY = deckH - (step * (4.5 / 6))
			local sZ = 26 - (step * 2.0)
			local stepPart = createPart(`ArrivalStep_{xStair}_{step}`, Vector3.new(11, 0.8, 2.2), CFrame.new(xStair, sY, sZ), Color3.fromRGB(38, 46, 60), Enum.Material.Concrete, stationFolder, true)
			createPart(`StepTread_{xStair}_{step}`, Vector3.new(10.8, 0.1, 0.4), CFrame.new(xStair, sY + 0.45, sZ - 0.9), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, stepPart, false)
		end
	end

	-- Overhead Gantry Arch with Professional Signage (No Emojis!)
	local signArch = createPart("ArrivalSignArch", Vector3.new(24, 1.4, 1.4), CFrame.new(0, deckH + 11, 26), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, stationFolder, true)
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "ArrivalSignGui"
	signGui.Size = UDim2.new(0, 360, 0, 50)
	signGui.StudsOffset = Vector3.new(0, 2.2, 0)
	signGui.AlwaysOnTop = true
	signGui.Parent = signArch

	local sFrame = Instance.new("Frame")
	sFrame.Size = UDim2.fromScale(1, 1)
	sFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	sFrame.BackgroundTransparency = 0.12
	sFrame.Parent = signGui
	Instance.new("UICorner", sFrame).CornerRadius = UDim.new(0, 8)
	local sStroke = Instance.new("UIStroke", sFrame)
	sStroke.Color = Color3.fromRGB(56, 189, 248)
	sStroke.Thickness = 1.4

	local sLbl = Instance.new("TextLabel")
	sLbl.Size = UDim2.fromScale(1, 1)
	sLbl.BackgroundTransparency = 1
	sLbl.Text = "SECTOR-7 TRANSIT TERMINAL\nSELECT YOUR FORTIFIED VAULT"
	sLbl.TextColor3 = Color3.fromRGB(248, 250, 252)
	sLbl.TextSize = 13
	sLbl.Font = Enum.Font.BuilderSansExtraBold
	sLbl.Parent = sFrame

	-- SpawnLocation centered on Arrival Deck facing North towards Plaza
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "PlazaSpawn"
	spawnPad.Size = Vector3.new(16, 0.4, 12)
	spawnPad.CFrame = CFrame.new(0, deckH + 1.2, 36) * CFrame.Angles(0, math.rad(180), 0)
	spawnPad.Anchored = true
	spawnPad.CanCollide = true
	spawnPad.Material = Enum.Material.SmoothPlastic
	spawnPad.Color = Color3.fromRGB(30, 41, 59)
	spawnPad.Duration = 0
	spawnPad.Parent = stationFolder

	-- ── 2.55. PLAZA SECURITY TRAINING DRONES (Immediate Combat Gameplay!) ──
	local function createCombatTrainingDrone(name: string, spawnCF: CFrame)
		local botModel = Instance.new("Model")
		botModel.Name = name
		botModel.Parent = rootFolder

		local torso = createPart("Torso", Vector3.new(2.4, 2.6, 1.4), spawnCF * CFrame.new(0, 3.4, 0), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, botModel, true)
		botModel.PrimaryPart = torso

		-- Side Thruster Turbines
		createPart("ThrusterL", Vector3.new(0.6, 1.6, 0.8), torso.CFrame * CFrame.new(-1.5, 0, 0), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, botModel, true)
		createPart("ThrusterR", Vector3.new(0.6, 1.6, 0.8), torso.CFrame * CFrame.new(1.5, 0, 0), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, botModel, true)
		createPart("NozzleL", Vector3.new(0.5, 0.1, 0.6), torso.CFrame * CFrame.new(-1.5, -0.85, 0), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, botModel, false)
		createPart("NozzleR", Vector3.new(0.5, 0.1, 0.6), torso.CFrame * CFrame.new(1.5, -0.85, 0), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, botModel, false)

		local head = createPart("Head", Vector3.new(1.4, 1.2, 1.4), torso.CFrame * CFrame.new(0, 1.9, 0), Color3.fromRGB(15, 23, 42), Enum.Material.SmoothPlastic, botModel, true)
		createPart("Visor", Vector3.new(1.1, 0.3, 0.2), head.CFrame * CFrame.new(0, 0.15, -0.7), Color3.fromRGB(239, 68, 68), Enum.Material.Neon, botModel, false)

		-- Diamond Plate Combat Ring Pedestal with Thin 0.15-stud Hazard Border (No solid neon blocks!)
		local ped = createPart("TargetPedestal", Vector3.new(4.8, 0.4, 4.8), spawnCF * CFrame.new(0, 0.2, 0), Color3.fromRGB(24, 28, 40), Enum.Material.DiamondPlate, botModel, true)
		for _, edgeOffset in {
			CFrame.new(0, 0.22, -2.35),
			CFrame.new(0, 0.22, 2.35),
			CFrame.new(-2.35, 0.22, 0) * CFrame.Angles(0, math.rad(90), 0),
			CFrame.new(2.35, 0.22, 0) * CFrame.Angles(0, math.rad(90), 0),
		} do
			createPart("TargetEdgeTrim", Vector3.new(4.6, 0.05, 0.15), ped.CFrame * edgeOffset, Color3.fromRGB(239, 68, 68), Enum.Material.Neon, botModel, false)
		end

		local hum = Instance.new("Humanoid")
		hum.MaxHealth = 100
		hum.Health = 100
		hum.NameDisplayDistance = 0
		hum.HealthDisplayDistance = 0
		hum.Parent = botModel

		local bGui = Instance.new("BillboardGui")
		bGui.Name = "DroneBillboard"
		bGui.Size = UDim2.new(0, 180, 0, 42)
		bGui.StudsOffset = Vector3.new(0, 2.6, 0)
		bGui.AlwaysOnTop = true
		bGui.Parent = head

		local dCard = Instance.new("Frame")
		dCard.Size = UDim2.fromScale(1, 1)
		dCard.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
		dCard.BackgroundTransparency = 0.15
		dCard.Parent = bGui
		Instance.new("UICorner", dCard).CornerRadius = UDim.new(0, 8)
		local dStroke = Instance.new("UIStroke", dCard)
		dStroke.Color = Color3.fromRGB(239, 68, 68)
		dStroke.Thickness = 1.2

		local dTitle = Instance.new("TextLabel")
		dTitle.Size = UDim2.new(1, 0, 0, 18)
		dTitle.Position = UDim2.new(0, 0, 0, 3)
		dTitle.BackgroundTransparency = 1
		dTitle.Text = "TRAINING DRONE"
		dTitle.TextColor3 = Color3.fromRGB(248, 250, 252)
		dTitle.TextSize = 11
		dTitle.Font = Enum.Font.BuilderSansExtraBold
		dTitle.Parent = dCard

		local hpBg = Instance.new("Frame")
		hpBg.Size = UDim2.new(1, -16, 0, 6)
		hpBg.Position = UDim2.new(0, 8, 0, 25)
		hpBg.BackgroundColor3 = Color3.fromRGB(11, 13, 20)
		hpBg.BorderSizePixel = 0
		hpBg.Parent = dCard
		Instance.new("UICorner", hpBg).CornerRadius = UDim.new(1, 0)

		local hpFill = Instance.new("Frame")
		hpFill.Size = UDim2.fromScale(1, 1)
		hpFill.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
		hpFill.BorderSizePixel = 0
		hpFill.Parent = hpBg
		Instance.new("UICorner", hpFill).CornerRadius = UDim.new(1, 0)

		hum.HealthChanged:Connect(function(newHP)
			local frac = math.clamp(newHP / 100, 0, 1)
			hpFill.Size = UDim2.fromScale(frac, 1)
			if newHP <= 0 then
				task.wait(3.0)
				hum.Health = 100
				hpFill.Size = UDim2.fromScale(1, 1)
			end
		end)

		torso.Touched:Connect(function(hit)
			local tool = hit:FindFirstAncestorOfClass("Tool")
			if tool and string.find(tool.Name, "Baton") then
				local p = tool.Parent and Players:GetPlayerFromCharacter(tool.Parent)
				if p and hum.Health > 0 then
					hum:TakeDamage(35)
					local dataSvc = getDataService()
					if dataSvc then
						dataSvc.AddCash(p, 25)
					end
				end
			end
		end)
	end

	createCombatTrainingDrone("TrainingDrone_1", CFrame.new(-18, FLOOR_Y, 8))
	createCombatTrainingDrone("TrainingDrone_2", CFrame.new(18, FLOOR_Y, 8))

	-- ── 2.5. CENTRAL PLAZA RELIC FUSION CHAMBER (North side of Central Core) ──
	local openFusionEvt = ReplicatedStorage:FindFirstChild("OpenFusionModal") :: RemoteEvent?
	if not openFusionEvt then
		openFusionEvt = Instance.new("RemoteEvent")
		openFusionEvt.Name = "OpenFusionModal"
		openFusionEvt.Parent = ReplicatedStorage
	end

	local _, _, fusionPrompt = ModelEngine.CreateRelicFusionChamber(rootFolder, CFrame.new(0, FLOOR_Y, -18))
	fusionPrompt.Triggered:Connect(function(player: Player)
		if openFusionEvt then
			openFusionEvt:FireClient(player)
		end
	end)

	-- ── 2.6. CENTRAL PLAZA SYNDICATE BLACK MARKET OUTPOST (North Pier) ──
	ModelEngine.CreateSyndicateKiosk(rootFolder, CFrame.new(0, FLOOR_Y, -50))
	local brokerNpc = ModelEngine.CreateSyndicateBrokerNPC(rootFolder, CFrame.new(0, FLOOR_Y, -42))
	local brokerPrompt = brokerNpc:FindFirstChildWhichIsA("ProximityPrompt", true)
	if brokerPrompt then
		local brokerDialogueEvt = ReplicatedStorage:FindFirstChild("OpenBrokerDialogue") :: RemoteEvent?
		if not brokerDialogueEvt then
			brokerDialogueEvt = Instance.new("RemoteEvent")
			brokerDialogueEvt.Name = "OpenBrokerDialogue"
			brokerDialogueEvt.Parent = ReplicatedStorage
		end

		brokerPrompt.Triggered:Connect(function(player: Player)
			if brokerDialogueEvt then
				brokerDialogueEvt:FireClient(player, brokerNpc)
			end
		end)
	end

	-- ── 3. BUILD 6 MODULAR FORTIFIED BUNKER PLOTS & CONNECTING CATWALKS ──
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

		-- 3.1. INDUSTRIAL CATWALK ARTERY (CONNECTS CENTRAL PLAZA AT R=28 TO PLOT AT R=60)
		-- Center is at radius 44, length 32 studs, width 12 studs, top at Y=4.0
		local bridgePos = Vector3.new(plotDir.X * 44, 3.0, plotDir.Z * 44)
		local bridgeCF = CFrame.lookAt(bridgePos, Vector3.new(0, 3.0, 0))
		createPart(`CatwalkBridge_{i}`, Vector3.new(12, 2.0, 32), bridgeCF, Color3.fromRGB(38, 46, 60), Enum.Material.DiamondPlate, pFolder, true)

		-- Left & Right Heavy Industrial Steel Safety Railings with Cyan Neon Top Rail
		createPart(`BridgeRailL_{i}`, Vector3.new(0.6, 3.2, 32), bridgeCF * CFrame.new(-5.7, 2.2, 0), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, pFolder, true)
		createPart(`BridgeTrimL_{i}`, Vector3.new(0.3, 0.3, 32), bridgeCF * CFrame.new(-5.7, 3.75, 0), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, pFolder, false)

		createPart(`BridgeRailR_{i}`, Vector3.new(0.6, 3.2, 32), bridgeCF * CFrame.new(5.7, 2.2, 0), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, pFolder, true)
		createPart(`BridgeTrimR_{i}`, Vector3.new(0.3, 0.3, 32), bridgeCF * CFrame.new(5.7, 3.75, 0), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, pFolder, false)

		-- Catwalk Luminaire Posts & Soft Cyan Downward Illumination
		for _, zL in { -10, 10 } do
			local postL = createPart(`CatwalkPostL_{i}_{zL}`, Vector3.new(0.4, 5.0, 0.4), bridgeCF * CFrame.new(-5.7, 3.5, zL), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, pFolder, true)
			local lampL = createPart(`CatwalkLampL_{i}_{zL}`, Vector3.new(1.0, 0.4, 1.0), bridgeCF * CFrame.new(-4.8, 5.8, zL), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, pFolder, false)
			local spotL = Instance.new("PointLight")
			spotL.Color = Color3.fromRGB(56, 189, 248)
			spotL.Range = 18
			spotL.Brightness = 2.0
			spotL.Parent = lampL

			local postR = createPart(`CatwalkPostR_{i}_{zL}`, Vector3.new(0.4, 5.0, 0.4), bridgeCF * CFrame.new(5.7, 3.5, zL), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, pFolder, true)
			local lampR = createPart(`CatwalkLampR_{i}_{zL}`, Vector3.new(1.0, 0.4, 1.0), bridgeCF * CFrame.new(4.8, 5.8, zL), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, pFolder, false)
			local spotR = Instance.new("PointLight")
			spotR.Color = Color3.fromRGB(56, 189, 248)
			spotR.Range = 18
			spotR.Brightness = 2.0
			spotR.Parent = lampR
		end

		-- Structural Steel Support Trestles beneath Catwalk (Anchored in Bedrock)
		createPart(`BridgeTrestleL_{i}`, Vector3.new(1.2, 2.0, 1.2), bridgeCF * CFrame.new(-4.5, -2.0, 0), Color3.fromRGB(24, 28, 40), Enum.Material.Metal, pFolder, true)
		createPart(`BridgeTrestleR_{i}`, Vector3.new(1.2, 2.0, 1.2), bridgeCF * CFrame.new(4.5, -2.0, 0), Color3.fromRGB(24, 28, 40), Enum.Material.Metal, pFolder, true)

		-- 3.2. ELEVATED BUNKER FOUNDATION FLOOR (Top at Y=4.0, zero clipping)
		local floor = createPart("PlotFloor", Vector3.new(pWidth, 2.0, pLen), faceCenterCF * CFrame.new(0, 1.0, 0), Color3.fromRGB(45, 52, 70), Enum.Material.Slate, pFolder)

		-- Permanent Armored Compound Perimeter Walls & Corner Buttresses
		createPart(`CompoundWallL_{i}`, Vector3.new(1.8, 12, pLen), faceCenterCF * CFrame.new(-pWidth / 2 + 0.9, 6.0, 0), Color3.fromRGB(42, 48, 64), Enum.Material.Concrete, pFolder, true)
		createPart(`CompoundWallR_{i}`, Vector3.new(1.8, 12, pLen), faceCenterCF * CFrame.new(pWidth / 2 - 0.9, 6.0, 0), Color3.fromRGB(42, 48, 64), Enum.Material.Concrete, pFolder, true)
		createPart(`CompoundWallBack_{i}`, Vector3.new(pWidth, 12, 1.8), faceCenterCF * CFrame.new(0, 6.0, pLen / 2 - 0.9), Color3.fromRGB(42, 48, 64), Enum.Material.Concrete, pFolder, true)

		for _, xSide in { -pWidth / 2 + 0.9, pWidth / 2 - 0.9 } do
			createPart(`CornerPilaster_{i}_{xSide}`, Vector3.new(2.6, 13, 2.6), faceCenterCF * CFrame.new(xSide, 6.5, pLen / 2 - 0.9), Color3.fromRGB(24, 28, 40), Enum.Material.Metal, pFolder, true)
		end

		-- 3.3. PERIMETER SAFETY CURBS WITH OPEN ENTRANCE PORTAL
		-- Front Entrance Curbs (Left & Right segments leaving an open 14-stud walk-in portal)
		local curbFrontWidth = (pWidth - 14) / 2
		createPart("PlotCurbFrontL", Vector3.new(curbFrontWidth, 1.0, 1.4), faceCenterCF * CFrame.new(-pWidth / 2 + curbFrontWidth / 2, 2.5, -pLen / 2 + 0.7), Color3.fromRGB(30, 41, 59), Enum.Material.DiamondPlate, pFolder, true)
		createPart("PlotCurbFrontR", Vector3.new(curbFrontWidth, 1.0, 1.4), faceCenterCF * CFrame.new(pWidth / 2 - curbFrontWidth / 2, 2.5, -pLen / 2 + 0.7), Color3.fromRGB(30, 41, 59), Enum.Material.DiamondPlate, pFolder, true)

		-- 3.4. ENTRANCE ARCH SIGN / BEACON
		local archLintel = createPart(`EntranceArch_{i}`, Vector3.new(18, 2.0, 2.0), faceCenterCF * CFrame.new(0, 11, -pLen / 2 + 1), Color3.fromRGB(24, 28, 40), Enum.Material.Metal, pFolder, true)
		createPart(`ArchColL_{i}`, Vector3.new(1.8, 11, 1.8), faceCenterCF * CFrame.new(-8.2, 5.5, -pLen / 2 + 1), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, pFolder, true)
		createPart(`ArchColR_{i}`, Vector3.new(1.8, 11, 1.8), faceCenterCF * CFrame.new(8.2, 5.5, -pLen / 2 + 1), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, pFolder, true)

		-- Entrance Arch Floodlights
		local archLight = Instance.new("PointLight")
		archLight.Color = Color3.fromRGB(56, 189, 248)
		archLight.Range = 24
		archLight.Brightness = 2.4
		archLight.Parent = archLintel

		local ownerGui = Instance.new("BillboardGui")
		ownerGui.Name = "OwnerBillboard"
		ownerGui.Size = UDim2.new(0, 260, 0, 52)
		ownerGui.StudsOffset = Vector3.new(0, 2.8, 0)
		ownerGui.AlwaysOnTop = true
		ownerGui.Parent = archLintel

		local obCard = Instance.new("Frame")
		obCard.Size = UDim2.fromScale(1, 1)
		obCard.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
		obCard.BackgroundTransparency = 0.15
		obCard.Parent = ownerGui
		Instance.new("UICorner", obCard).CornerRadius = UDim.new(0, 10)
		local obStroke = Instance.new("UIStroke", obCard)
		obStroke.Color = Color3.fromRGB(16, 185, 129)
		obStroke.Thickness = 1.6

		local obText = Instance.new("TextLabel")
		obText.Name = "OwnerNameLabel"
		obText.Size = UDim2.fromScale(1, 1)
		obText.BackgroundTransparency = 1
		obText.Text = `VAULT #{i} • AVAILABLE`
		obText.TextColor3 = Color3.fromRGB(110, 231, 183)
		obText.TextSize = 13
		obText.Font = Enum.Font.BuilderSansExtraBold
		obText.Parent = obCard

		-- 3.5. IN-WORLD PHYSICAL BASE CLAIM PAD
		local claimPadModel, claimStepPad = ModelEngine.CreateVaultClaimPad(pFolder, faceCenterCF * CFrame.new(0, 2, -pLen / 2 + 6.0), i)

		-- State container for Plot i
		PlotService._plots[i] = {
			Index = i,
			Folder = pFolder,
			Floor = floor,
			CF = faceCenterCF,
			ArchLintel = archLintel,
			Owner = nil :: Player?,
			OwnerLabel = obText,
			OwnerStroke = obStroke,
			ClaimModel = claimPadModel,
			ClaimPad = claimStepPad,
			BuiltObjects = {} :: { [string]: Instance },
			CurrentButton = nil :: Model?,
			SafePad = nil :: Part?,
			Conveyor = nil :: Part?,
			Belt = nil :: Part?,
			StampingHead = nil :: Part?,
			VaultDoorModel = nil :: Model?,
			LeftPost = nil :: Part?,
			RightPost = nil :: Part?,
			Siren = nil :: Part?,
			ShowcaseGem = nil :: Part?,
			ShowcaseRing = nil :: Part?,
			ShowcaseLabel = nil :: TextLabel?,
			ShowcaseBaseCF = nil :: CFrame?,
			CurrentShowcaseModel = nil :: Model?,
			_isDoorOpening = false,
		}

		-- Connect ClaimPad Touch
		claimStepPad.Touched:Connect(function(hit)
			local char = hit.Parent
			local player = char and Players:GetPlayerFromCharacter(char)
			if not player then return end

			-- Only unassigned players can claim
			if PlotService._playerPlots[player] then return end

			PlotService.ClaimPlot(player, i)
		end)
	end

	-- Connect Player Join / Leave
	for _, p in Players:GetPlayers() do
		task.spawn(PlotService.AssignPlot, p)
	end
	Players.PlayerAdded:Connect(PlotService.AssignPlot)
	Players.PlayerRemoving:Connect(PlotService.ReleasePlot)

	-- Heartbeat: showcase relic floating animation
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

	print("  [PlotService] 6 Fortified Tycoon Vault Bases ready ✓")
end

-- ============================================================
-- CLAIM & ASSIGN PLOT
-- ============================================================
function PlotService.ClaimPlot(player: Player, plotIndex: number)
	if PlotService._playerPlots[player] then return end
	local plot = PlotService._plots[plotIndex]
	if not plot or plot.Owner ~= nil then return end

	plot.Owner = player
	PlotService._playerPlots[player] = plotIndex

	-- Update entrance banner (Clean Builder typography, zero emoji spam)
	plot.OwnerLabel.Text = `{string.upper(player.DisplayName)}'S FORTIFIED VAULT`
	plot.OwnerLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
	plot.OwnerLabel.Font = Enum.Font.BuilderSansExtraBold
	if plot.OwnerStroke then
		plot.OwnerStroke.Color = Color3.fromRGB(56, 189, 248)
	end

	-- Hide/destroy claim pad
	if plot.ClaimModel and plot.ClaimModel.Parent then
		plot.ClaimModel:Destroy()
		plot.ClaimModel = nil
	end

	-- Auto-unlock starter Mint Press & Bank Safe in playerData so income flows immediately!
	local dataSvc = getDataService()
	if dataSvc then
		local data = dataSvc.GetData(player)
		if data then
			if not data.PurchasedUpgrades then
				data.PurchasedUpgrades = {}
			end
			data.PurchasedUpgrades["MintPress"] = true
			data.PurchasedUpgrades["BankSafe"] = true
		end
	end

	-- Visual wayfinding guide: Glowing cyan beacon line leading player to their vault!
	task.spawn(function()
		local char = player.Character or player.CharacterAdded:Wait()
		local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if root and plot.ArchLintel then
			-- Celebration burst on claim
			local emitter = Instance.new("ParticleEmitter")
			emitter.Rate = 0
			emitter.Speed = NumberRange.new(10, 20)
			emitter.Lifetime = NumberRange.new(0.5, 1.0)
			emitter.Color = ColorSequence.new(Color3.fromRGB(56, 189, 248))
			emitter.Parent = root
			emitter:Emit(40)

			-- Wayfinding attachment & beam
			local pAtt = Instance.new("Attachment")
			pAtt.Name = "VaultWaypointAtt"
			pAtt.Position = Vector3.new(0, -2, 0)
			pAtt.Parent = root

			local vAtt = Instance.new("Attachment")
			vAtt.Name = "VaultTargetAtt"
			vAtt.Position = Vector3.new(0, -4, 0)
			vAtt.Parent = plot.ArchLintel

			local beam = Instance.new("Beam")
			beam.Name = "VaultGuideBeam"
			beam.Attachment0 = pAtt
			beam.Attachment1 = vAtt
			beam.Color = ColorSequence.new(Color3.fromRGB(56, 189, 248))
			beam.Width0 = 0.6
			beam.Width1 = 1.6
			beam.FaceCamera = true
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(1, 0.45),
			})
			beam.Parent = root

			-- Remove beam after 45 seconds or when player enters their vault
			task.delay(45, function()
				if beam and beam.Parent then beam:Destroy() end
				if pAtt and pAtt.Parent then pAtt:Destroy() end
				if vAtt and vAtt.Parent then vAtt:Destroy() end
			end)
		end
	end)

	-- Toast notification
	local notifEvt = ReplicatedStorage:FindFirstChild("NotificationBroadcast") :: RemoteEvent?
	if notifEvt then
		notifEvt:FireClient(player, {
			Type = "Success",
			Title = "VAULT ASSIGNED",
			Message = `Follow the cyan waypoint beacon to Vault #{plotIndex}!`,
			Duration = 5,
		})
	end

	-- Load saved upgrades & spawn next button
	PlotService.LoadPlotForPlayer(plotIndex, player)
	print(`  [PlotService] {player.Name} claimed Vault #{plotIndex}!`)
end

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

	-- Auto-claim the plot for smooth singleplayer / studio onboarding
	PlotService.ClaimPlot(player, assignedIndex)
end

function PlotService.ReleasePlot(player: Player)
	local plotIndex = PlotService._playerPlots[player]
	if not plotIndex then return end

	local plot = PlotService._plots[plotIndex]
	if plot then
		plot.Owner = nil
		plot.OwnerLabel.Text = `VAULT #{plotIndex} • AVAILABLE`
		plot.OwnerLabel.TextColor3 = Color3.fromRGB(110, 231, 183)
		plot.OwnerLabel.Font = Enum.Font.BuilderSansExtraBold
		if plot.OwnerStroke then
			plot.OwnerStroke.Color = Color3.fromRGB(16, 185, 129)
		end

		-- Clean up current button
		if plot.CurrentButton and plot.CurrentButton.Parent then
			plot.CurrentButton:Destroy()
			plot.CurrentButton = nil
		end

		-- Clean up built objects
		for _, inst in plot.BuiltObjects do
			if inst and inst.Parent then
				inst:Destroy()
			end
		end
		plot.BuiltObjects = {}

		-- Respawn Claim Pad
		local pLen = Config.Arena.PlotLength
		local claimModel, claimPad = ModelEngine.CreateVaultClaimPad(plot.Folder, plot.CF * CFrame.new(0, 2, -pLen / 2 + 4.5), plotIndex)
		plot.ClaimModel = claimModel
		plot.ClaimPad = claimPad

		claimPad.Touched:Connect(function(hit)
			local char = hit.Parent
			local p = char and Players:GetPlayerFromCharacter(char)
			if p and not PlotService._playerPlots[p] then
				PlotService.ClaimPlot(p, plotIndex)
			end
		end)
	end

	PlotService._playerPlots[player] = nil
	print(`  [PlotService] Released Vault #{plotIndex} from {player.Name}`)
end

-- ============================================================
-- TYCOON UPGRADE RESTORATION & NEXT BUTTON SPAWNING
-- ============================================================
function PlotService.LoadPlotForPlayer(plotIndex: number, player: Player)
	local plot = PlotService._plots[plotIndex]
	if not plot then return end

	local dataSvc = getDataService()
	local data = dataSvc and dataSvc.GetData(player)
	local purchased = (data and data.PurchasedUpgrades) or {}

	-- Ensure starter mint machine & safe exist for instant gameplay!
	if not plot.BuiltObjects["MintPress"] then
		UPGRADE_DEFS["MintPress"].Build(plot)
	end
	if not plot.BuiltObjects["BankSafe"] then
		UPGRADE_DEFS["BankSafe"].Build(plot)
	end

	-- 1. Build all previously purchased upgrades
	for _, upId in ORDERED_UPGRADES do
		if purchased[upId] and not plot.BuiltObjects[upId] then
			local def = UPGRADE_DEFS[upId]
			if def then
				def.Build(plot)
			end
		end
	end

	-- 2. Spawn the next unpurchased button
	PlotService.SpawnNextButton(plotIndex)
end

function PlotService.SpawnNextButton(plotIndex: number)
	local plot = PlotService._plots[plotIndex]
	if not plot then return end

	-- Clean up existing button
	if plot.CurrentButton and plot.CurrentButton.Parent then
		plot.CurrentButton:Destroy()
		plot.CurrentButton = nil
	end

	local owner = plot.Owner
	if not owner then return end

	local dataSvc = getDataService()
	local data = dataSvc and dataSvc.GetData(owner)
	local purchased = (data and data.PurchasedUpgrades) or {}

	-- Find the first unpurchased upgrade
	local nextUpgradeId: string? = nil
	for _, upId in ORDERED_UPGRADES do
		if not purchased[upId] then
			nextUpgradeId = upId
			break
		end
	end

	if not nextUpgradeId then
		-- Vault is fully maxed! Spawn prestigious completion monument
		local maxModel = Instance.new("Model")
		maxModel.Name = "VaultMaxedBadge"
		maxModel.Parent = plot.Folder
		local flange = createPart("MaxFlange", Vector3.new(8, 0.4, 8), plot.CF * CFrame.new(0, 2.0, 0), Color3.fromRGB(245, 158, 11), Enum.Material.Neon, maxModel, false)
		local bGui = Instance.new("BillboardGui")
		bGui.Size = UDim2.new(0, 240, 0, 50)
		bGui.StudsOffset = Vector3.new(0, 3.5, 0)
		bGui.AlwaysOnTop = true
		bGui.Parent = flange
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Text = "👑 VAULT FULLY MAXED OUT 👑"
		lbl.TextColor3 = Color3.fromRGB(254, 240, 138)
		lbl.TextSize = 14
		lbl.Font = Enum.Font.GothamBlack
		lbl.Parent = bGui
		plot.CurrentButton = maxModel
		return
	end

	local def = UPGRADE_DEFS[nextUpgradeId]
	if not def then return end

	local btnModel, stepPad, bGui, costLbl = ModelEngine.CreateTycoonButton(
		plot.Folder,
		plot.CF * CFrame.new(def.ButtonOffset.X, 2.0, def.ButtonOffset.Z),
		nextUpgradeId,
		def.Title,
		def.Cost,
		def.AccentColor
	)
	plot.CurrentButton = btnModel

	-- Handle Button Step
	local debounce = false
	stepPad.Touched:Connect(function(hit)
		if debounce then return end
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player or player ~= plot.Owner then return end
		debounce = true

		local dSvc = getDataService()
		if not dSvc then
			debounce = false
			return
		end

		-- Verify funds
		if not dSvc.SpendForUpgrade(player, def.Cost) then
			-- Flash cost label red
			costLbl.TextColor3 = Color3.fromRGB(239, 68, 68)
			task.delay(0.45, function()
				if costLbl and costLbl.Parent then
					costLbl.TextColor3 = (def.Cost == 0) and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(250, 204, 21)
				end
				debounce = false
			end)
			return
		end

		-- Animate pad depression
		local origCF = stepPad.CFrame
		TweenService:Create(stepPad, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { CFrame = origCF * CFrame.new(0, -0.35, 0) }):Play()

		-- Sparkle burst
		local p = Instance.new("ParticleEmitter")
		p.Rate = 0
		p.Speed = NumberRange.new(8, 16)
		p.Lifetime = NumberRange.new(0.3, 0.6)
		p.Color = ColorSequence.new(def.AccentColor)
		p.Parent = stepPad
		p:Emit(25)

		-- Chime sound
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://9069609200"
		s.Volume = 0.85
		s.Parent = stepPad
		s:Play()

		-- Save upgrade
		dSvc.AddUpgrade(player, nextUpgradeId)

		task.wait(0.12)
		-- Build purchased structure
		def.Build(plot)

		task.wait(0.2)
		if btnModel and btnModel.Parent then
			btnModel:Destroy()
		end

		-- Spawn the next button in sequence!
		PlotService.SpawnNextButton(plotIndex)
	end)
end

-- ============================================================
-- HELPERS & QUERIES
-- ============================================================
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
	local wheel = (doorModel:FindFirstChild("CogWheelCenter")
		or doorModel:FindFirstChild("Wheel")
		or doorModel:FindFirstChild("Handle")) :: BasePart?

	local doorSlab = (doorModel:FindFirstChild("DoorSlab")
		or doorModel:FindFirstChild("Door")
		or doorModel:FindFirstChild("Slab")
		or doorModel.PrimaryPart) :: BasePart?

	local pinL = (doorModel:FindFirstChild("LockingPinLeft") or doorModel:FindFirstChild("PinLeft")) :: BasePart?
	local pinR = (doorModel:FindFirstChild("LockingPinRight") or doorModel:FindFirstChild("PinRight")) :: BasePart?

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
	-- Compatibility hook for legacy console updates
end

return PlotService
