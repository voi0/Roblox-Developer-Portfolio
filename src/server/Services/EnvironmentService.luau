--!strict
--[[
	EnvironmentService.luau — Subterranean Cyberpunk World & Atmosphere Engine
	Constructs the massive underground facility for VAULT WARS:
	- Destroys conflicting default Baseplates to eliminate Z-fighting
	- Builds continuous full-cavern Bedrock Deck (244x244 at Y=0, top Y=2.0) — zero void falls
	- Configures volumetric Lighting (Technology.Future, atmospheric haze, bloom, color correction)
	- Builds 16-sided perimeter armored blast cavern walls with heavy steel I-beam columns
	- Installs 6 radial recessed coolant plasma canals flowing between bunker plots
	- Embeds 4 rotating 3D ventilation turbines in perimeter blast walls
	- Stacks realistic 3D industrial cargo container depots and high-voltage substations
	- Spans overhead heavy crane gantries with suspended cargo and sodium floodlights
	Located in: ServerScriptService.Server.Services.EnvironmentService
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ModelEngine = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelEngine"))

local EnvironmentService = {}
EnvironmentService._folder = nil :: Folder?

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

local function createCylinder(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, parent: Instance, canCollide: boolean?): Part
	local p = createPart(name, size, cf, color, mat, parent, canCollide)
	local mesh = Instance.new("CylinderMesh")
	mesh.Parent = p
	return p
end

-- ============================================================
-- 1. BASEPLATE CLEANUP (Eliminates ground Z-fighting)
-- ============================================================
local function cleanupBaseplates()
	for _, child in Workspace:GetChildren() do
		if child:IsA("BasePart") then
			local lowerName = child.Name:lower()
			if lowerName == "baseplate" or lowerName:find("baseplate") then
				pcall(function()
					child:Destroy()
				end)
			end
		end
	end
end

-- ============================================================
-- 2. ATMOSPHERIC LIGHTING & POST-PROCESSING
-- ============================================================
local function setupAtmosphericLighting()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	Lighting.ClockTime = 0.0
	Lighting.TimeOfDay = "00:00:00"
	Lighting.Brightness = 0.0
	Lighting.Ambient = Color3.fromRGB(24, 28, 38)
	Lighting.OutdoorAmbient = Color3.fromRGB(16, 20, 30)
	Lighting.ColorShift_Top = Color3.fromRGB(180, 200, 230)
	Lighting.ColorShift_Bottom = Color3.fromRGB(15, 18, 25)
	Lighting.GeographicLatitude = 0
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.FogStart = 250
	Lighting.FogEnd = 1200
	Lighting.FogColor = Color3.fromRGB(12, 15, 22)

	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") then
			pcall(function() child:Destroy() end)
		end
	end

	local voidSky = Instance.new("Sky")
	voidSky.Name = "SubterraneanAtmosphereSky"
	-- Dark deep-space nebula asset IDs so no blue daytime sky can ever render
	voidSky.SkyboxBk = "rbxassetid://159454299"
	voidSky.SkyboxDn = "rbxassetid://159454299"
	voidSky.SkyboxFt = "rbxassetid://159454299"
	voidSky.SkyboxLf = "rbxassetid://159454299"
	voidSky.SkyboxRt = "rbxassetid://159454299"
	voidSky.SkyboxUp = "rbxassetid://159454299"
	voidSky.SunAngularSize = 0
	voidSky.MoonAngularSize = 0
	voidSky.StarCount = 0
	voidSky.Parent = Lighting

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.45
	atmosphere.Offset = 0.20
	atmosphere.Color = Color3.fromRGB(20, 24, 35)
	atmosphere.Decay = Color3.fromRGB(10, 12, 18)
	atmosphere.Glare = 0.0
	atmosphere.Haze = 2.0

	local bloom = Lighting:FindFirstChild("VaultWarsBloom") :: BloomEffect?
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "VaultWarsBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.12
	bloom.Size = 12
	bloom.Threshold = 1.95

	local cc = Lighting:FindFirstChild("VaultWarsCC") :: ColorCorrectionEffect?
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "VaultWarsCC"
		cc.Parent = Lighting
	end
	cc.TintColor = Color3.fromRGB(245, 248, 255)
	cc.Brightness = 0.01
	cc.Contrast = 0.20
	cc.Saturation = 0.08

	local sunRays = Lighting:FindFirstChild("VaultWarsSunRays") :: SunRaysEffect?
	if sunRays then
		sunRays:Destroy()
	end

	local dof = Lighting:FindFirstChild("VaultWarsDOF") :: DepthOfFieldEffect?
	if not dof then
		dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "VaultWarsDOF"
		dof.Parent = Lighting
	end
	dof.FarIntensity = 0.20
	dof.FocusDistance = 45
	dof.InFocusRadius = 35
	dof.NearIntensity = 0.0
end

-- ============================================================
-- 3. CONTINUOUS SUBTERRANEAN BEDROCK DECK (Full-Arena Ground)
-- ============================================================
local function buildContinuousBedrockDeck(parent: Folder)
	local floorFolder = Instance.new("Folder")
	floorFolder.Name = "BedrockFacilityFloor"
	floorFolder.Parent = parent

	-- 3.1. Main Contiguous Bedrock Deck (244x244, top at Y=2.0)
	createPart(
		"CavernBedrockFoundation",
		Vector3.new(244, 4.0, 244),
		CFrame.new(0, 0, 0),
		Color3.fromRGB(24, 28, 38),
		Enum.Material.Slate,
		floorFolder,
		true
	)

	-- 3.2. Perimeter DiamondPlate Security Apron (Ring near outer blast walls)
	local numApronSegs = 16
	local apronRadius = 108
	local halfAngle = math.pi / numApronSegs
	local segWidth = 2 * apronRadius * math.sin(halfAngle) + 4

	for i = 1, numApronSegs do
		local angle = (i - 0.5) * (math.pi * 2 / numApronSegs)
		local pos = Vector3.new(math.cos(angle) * apronRadius, 2.05, math.sin(angle) * apronRadius)
		local cf = CFrame.lookAt(pos, Vector3.new(0, 2.05, 0))

		-- Apron Walkway Plate
		createPart(
			`PerimeterApron_{i}`,
			Vector3.new(segWidth, 0.3, 14),
			cf * CFrame.new(0, 0, 0),
			Color3.fromRGB(38, 46, 60),
			Enum.Material.DiamondPlate,
			floorFolder,
			true
		)

		-- Hazard Yellow Caution Trim at Inner Apron Edge
		createPart(
			`ApronCautionTrim_{i}`,
			Vector3.new(segWidth, 0.35, 1.2),
			cf * CFrame.new(0, 0.05, 6.5),
			Color3.fromRGB(245, 158, 11),
			Enum.Material.SmoothPlastic,
			floorFolder,
			false
		)
	end

	-- 3.3. Major Sector Dividing Expansion Joints (Crosswise in Floor)
	createPart("ExpansionJointX", Vector3.new(220, 0.2, 2.4), CFrame.new(0, 2.04, 0), Color3.fromRGB(15, 23, 42), Enum.Material.DiamondPlate, floorFolder, false)
	createPart("ExpansionJointZ", Vector3.new(2.4, 0.2, 220), CFrame.new(0, 2.04, 0), Color3.fromRGB(15, 23, 42), Enum.Material.DiamondPlate, floorFolder, false)

	-- 3.4. 6 Radial Coolant Drainage Canals (Between Bunker Plots)
	local canalFolder = Instance.new("Folder")
	canalFolder.Name = "RadialCoolantCanals"
	canalFolder.Parent = floorFolder

	for plotIdx = 1, 6 do
		local angle = ((plotIdx - 0.5) / 6) * (math.pi * 2)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local canalCenter = dir * 75
		local canalCF = CFrame.lookAt(Vector3.new(canalCenter.X, 1.2, canalCenter.Z), Vector3.new(0, 1.2, 0))

		-- Recessed Canal Trench Bed (Below Floor Y=2.0)
		createPart(
			`CanalTrenchBed_{plotIdx}`,
			Vector3.new(6.0, 1.8, 54),
			canalCF * CFrame.new(0, -0.4, 0),
			Color3.fromRGB(15, 17, 26),
			Enum.Material.Concrete,
			canalFolder,
			true
		)

		-- Glowing Cyan Liquid Coolant (Flowing through trench)
		local coolant = createPart(
			`CanalCoolantPlasma_{plotIdx}`,
			Vector3.new(4.8, 0.4, 52),
			canalCF * CFrame.new(0, 0.2, 0),
			Color3.fromRGB(14, 165, 233),
			Enum.Material.Neon,
			canalFolder,
			false
		)
		coolant.Transparency = 0.25

		-- Safety Metal Grate (Flush with floor at Y=2.06)
		local grate = createPart(
			`CanalGrate_{plotIdx}`,
			Vector3.new(6.2, 0.2, 54),
			canalCF * CFrame.new(0, 0.85, 0),
			Color3.fromRGB(30, 41, 59),
			Enum.Material.DiamondPlate,
			canalFolder,
			true
		)
		grate.Transparency = 0.45

		-- Cyan Trench Accent Lights
		local cLight = Instance.new("PointLight")
		cLight.Color = Color3.fromRGB(56, 189, 248)
		cLight.Range = 16
		cLight.Brightness = 1.6
		cLight.Parent = coolant
	end
end

-- ============================================================
-- 4. PERIMETER CAVERN BLAST WALLS (16-Sided Enclosure)
-- ============================================================
local function buildCavernEnclosure(parent: Folder)
	local numSegments = 16
	local radius = 114
	local wallHeight = 36
	local wallThickness = 6
	local halfAngle = math.pi / numSegments
	local segmentWidth = 2 * radius * math.sin(halfAngle) + 6

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "PerimeterBlastWalls"
	wallsFolder.Parent = parent

	for i = 1, numSegments do
		local centerAngle = (i - 0.5) * (math.pi * 2 / numSegments)
		local vertAngle = i * (math.pi * 2 / numSegments)

		local wallPos = Vector3.new(
			math.cos(centerAngle) * radius,
			wallHeight / 2 + 2,
			math.sin(centerAngle) * radius
		)
		local lookCenterCF = CFrame.lookAt(wallPos, Vector3.new(0, wallHeight / 2 + 2, 0))

		-- 4.1. Lower Armored Blast Slab (DiamondPlate)
		createPart(
			`BlastWallLower_{i}`,
			Vector3.new(segmentWidth, 18, wallThickness),
			lookCenterCF * CFrame.new(0, -9, 0),
			Color3.fromRGB(48, 56, 72),
			Enum.Material.DiamondPlate,
			wallsFolder,
			true
		)

		-- Ground Baseboard Footer (Anchors wall firmly into bedrock, eliminates seams)
		createPart(
			`BlastWallBaseboard_{i}`,
			Vector3.new(segmentWidth + 1, 2.4, wallThickness + 1.4),
			lookCenterCF * CFrame.new(0, -17, -0.7),
			Color3.fromRGB(30, 36, 48),
			Enum.Material.Concrete,
			wallsFolder,
			true
		)

		-- 4.2. Upper Corrugated Blast Wall
		createPart(
			`BlastWallUpper_{i}`,
			Vector3.new(segmentWidth, 18, wallThickness - 1),
			lookCenterCF * CFrame.new(0, 9, 0.5),
			Color3.fromRGB(64, 74, 94),
			Enum.Material.CorrugatedMetal,
			wallsFolder,
			true
		)

		-- 4.3. Wall Trim & Horizontal Conduit Pipes
		createPart(
			`CoolantLine_{i}`,
			Vector3.new(segmentWidth + 2, 1.6, 1.6),
			lookCenterCF * CFrame.new(0, 0, -wallThickness / 2 - 0.8),
			Color3.fromRGB(14, 165, 233),
			Enum.Material.Metal,
			wallsFolder,
			false
		)
		createPart(
			`CoolantGlow_{i}`,
			Vector3.new(segmentWidth, 0.4, 0.4),
			lookCenterCF * CFrame.new(0, 0, -wallThickness / 2 - 1.7),
			Color3.fromRGB(56, 189, 248),
			Enum.Material.Neon,
			wallsFolder,
			false
		)

		-- Steam Exhaust Pressure Release Pipe (Puffs subtle atmospheric steam)
		if i % 4 == 2 then
			local steamVent = createPart(
				`SteamVent_{i}`,
				Vector3.new(1.8, 1.8, 2.4),
				lookCenterCF * CFrame.new(0, 4.0, -wallThickness / 2 - 1.6),
				Color3.fromRGB(38, 46, 60),
				Enum.Material.Metal,
				wallsFolder,
				false
			)
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "SteamEmitter"
			pe.Rate = 4
			pe.Speed = NumberRange.new(3, 6)
			pe.Lifetime = NumberRange.new(1.8, 3.0)
			pe.SpreadAngle = Vector2.new(15, 15)
			pe.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(0.5, 2.4),
				NumberSequenceKeypoint.new(1, 4.5),
			})
			pe.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(0.7, 0.75),
				NumberSequenceKeypoint.new(1, 1),
			})
			pe.Color = ColorSequence.new(Color3.fromRGB(200, 215, 230))
			pe.Acceleration = Vector3.new(0, 2.5, 0)
			pe.EmissionDirection = Enum.NormalId.Front
			pe.Parent = steamVent
		end

		-- Upper Amber High-Voltage Bus Conduit
		createPart(
			`VoltageBus_{i}`,
			Vector3.new(segmentWidth + 2, 1.4, 1.4),
			lookCenterCF * CFrame.new(0, 10, -wallThickness / 2 - 0.6),
			Color3.fromRGB(245, 158, 11),
			Enum.Material.Metal,
			wallsFolder,
			false
		)

		-- 4.4. Structural Heavy Vertical I-Beam Columns at Vertices
		local vertPos = Vector3.new(
			math.cos(vertAngle) * radius,
			wallHeight / 2 + 2,
			math.sin(vertAngle) * radius
		)
		local vertCF = CFrame.lookAt(vertPos, Vector3.new(0, wallHeight / 2 + 2, 0))

		local column = createPart(
			`StructuralIBeam_{i}`,
			Vector3.new(4.5, wallHeight + 2, 4.5),
			vertCF,
			Color3.fromRGB(36, 42, 56),
			Enum.Material.Metal,
			wallsFolder,
			true
		)

		-- Column Hazard Warning Chevron Panels
		createPart(
			`HazardPlate_{i}`,
			Vector3.new(4.6, 12, 0.4),
			vertCF * CFrame.new(0, -8, -2.4),
			(i % 2 == 0) and Color3.fromRGB(245, 158, 11) or Color3.fromRGB(24, 24, 27),
			Enum.Material.SmoothPlastic,
			column,
			false
		)

		-- 4.5. Wall-Mounted Volumetric Floodlights (Every 2nd segment)
		if i % 2 == 1 then
			local lightHousing = createPart(
				`WallFloodHousing_{i}`,
				Vector3.new(3.5, 2.0, 3.5),
				lookCenterCF * CFrame.new(0, 14, -wallThickness / 2 - 2) * CFrame.Angles(math.rad(-35), 0, 0),
				Color3.fromRGB(15, 23, 42),
				Enum.Material.Metal,
				wallsFolder,
				false
			)

			local lightLens = createPart(
				`WallFloodLens_{i}`,
				Vector3.new(3.2, 0.4, 3.2),
				lightHousing.CFrame * CFrame.new(0, -1.0, 0),
				(i % 4 == 1) and Color3.fromRGB(254, 240, 138) or Color3.fromRGB(186, 230, 253),
				Enum.Material.Neon,
				lightHousing,
				false
			)

			local spot = Instance.new("SpotLight")
			spot.Name = "VolumetricFlood"
			spot.Face = Enum.NormalId.Bottom
			spot.Range = 90
			spot.Angle = 65
			spot.Brightness = 2.4
			spot.Color = (i % 4 == 1) and Color3.fromRGB(251, 191, 36) or Color3.fromRGB(56, 189, 248)
			spot.Shadows = true
			spot.Parent = lightLens
		end
	end
end

-- ============================================================
-- 5. ROTATING 3D VENTILATION TURBINES (Embedded in Walls)
-- ============================================================
local function buildRotatingWallTurbines(parent: Folder)
	local turbineFolder = Instance.new("Folder")
	turbineFolder.Name = "WallVentilationTurbines"
	turbineFolder.Parent = parent

	local fanAssemblies: { Part } = {}
	local wallRadius = 114

	for tIdx, segIdx in { 4, 8, 12, 16 } do
		local angle = (segIdx - 0.5) * (math.pi * 2 / 16)
		local wallPos = Vector3.new(math.cos(angle) * wallRadius, 14, math.sin(angle) * wallRadius)
		local lookCenterCF = CFrame.lookAt(wallPos, Vector3.new(0, 14, 0))

		-- Outer Turbine Shroud Housing
		local shroud = createPart(
			`TurbineShroud_{tIdx}`,
			Vector3.new(14, 14, 4.5),
			lookCenterCF * CFrame.new(0, 0, -3.5),
			Color3.fromRGB(24, 28, 40),
			Enum.Material.Metal,
			turbineFolder,
			false
		)

		-- Shroud Circular Bezel
		createCylinder(
			`TurbineBezel_{tIdx}`,
			Vector3.new(4.8, 12.5, 12.5),
			shroud.CFrame * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(15, 23, 42),
			Enum.Material.DiamondPlate,
			shroud,
			false
		)

		-- Glowing Blue Intake Vortex Backing
		local glowBacking = createCylinder(
			`TurbineGlow_{tIdx}`,
			Vector3.new(0.5, 11, 11),
			shroud.CFrame * CFrame.new(0, 0, 1.8) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(14, 165, 233),
			Enum.Material.Neon,
			shroud,
			false
		)
		glowBacking.Transparency = 0.35

		-- Central Fan Rotor Hub (Rotates)
		local fanHub = createCylinder(
			`FanHub_{tIdx}`,
			Vector3.new(2.4, 3.2, 3.2),
			shroud.CFrame * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(71, 85, 105),
			Enum.Material.Metal,
			shroud,
			false
		)

		-- 4 Fan Blades attached to hub
		for b = 1, 4 do
			local blade = createPart(
				`FanBlade_{tIdx}_{b}`,
				Vector3.new(0.4, 4.2, 1.2),
				shroud.CFrame * CFrame.Angles(0, 0, math.rad(b * 90 + 20)) * CFrame.new(0, 2.5, 0),
				Color3.fromRGB(51, 65, 85),
				Enum.Material.Metal,
				shroud,
				false
			)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = fanHub
			weld.Part1 = blade
			weld.Parent = fanHub
			blade.Anchored = false
		end

		table.insert(fanAssemblies, fanHub)
	end

	-- Smooth rotation loop on Stepped
	if #fanAssemblies > 0 then
		local fanRot = 0
		RunService.Heartbeat:Connect(function(dt: number)
			fanRot += dt * 180 -- 180 deg/sec
			for _, hub in fanAssemblies do
				if hub and hub.Parent then
					local cf = hub.CFrame
					hub.CFrame = CFrame.new(cf.Position) * CFrame.Angles(0, 0, math.rad(fanRot))
				end
			end
		end)
	end
end

-- ============================================================
-- 6. PERIMETER CARGO CONTAINER DEPOTS & HIGH-VOLTAGE SUBSTATIONS
-- ============================================================
local function buildPerimeterIndustrialProps(parent: Folder)
	local propsFolder = Instance.new("Folder")
	propsFolder.Name = "PerimeterIndustrialProps"
	propsFolder.Parent = parent

	-- Helper: Build a realistic 3D Shipping Container
	local function createShippingContainer(name: string, cf: CFrame, color: Color3, parentInst: Instance): Model
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = parentInst

		-- Main Corrugated Body (16x8x7)
		local body = createPart("ContainerBody", Vector3.new(16, 8, 7.5), cf * CFrame.new(0, 4, 0), color, Enum.Material.CorrugatedMetal, m, true)
		m.PrimaryPart = body

		-- Reinforced Corner Castings (x8)
		for _, xRel in { -7.8, 7.8 } do
			for _, yRel in { 0.6, 7.4 } do
				for _, zRel in { -3.5, 3.5 } do
					createPart("CornerCast", Vector3.new(1.0, 1.2, 1.0), cf * CFrame.new(xRel, yRel, zRel), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, m, true)
				end
			end
		end

		-- Heavy Stamped End Door with Dual Locking Rods
		createPart("DoorFrame", Vector3.new(0.6, 7.6, 7.2), cf * CFrame.new(8, 4, 0), Color3.fromRGB(24, 28, 40), Enum.Material.Metal, m, true)
		createCylinder("LockingRodL", Vector3.new(7.4, 0.4, 0.4), cf * CFrame.new(8.2, 4, -1.4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(203, 213, 225), Enum.Material.Metal, m, false)
		createCylinder("LockingRodR", Vector3.new(7.4, 0.4, 0.4), cf * CFrame.new(8.2, 4, 1.4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(203, 213, 225), Enum.Material.Metal, m, false)

		-- Hazard Stencil Stripe
		createPart("HazardStripe", Vector3.new(14, 1.0, 0.2), cf * CFrame.new(0, 4, 3.85), Color3.fromRGB(245, 158, 11), Enum.Material.SmoothPlastic, m, false)

		return m
	end

	-- 4 Cargo Stacks at Perimeter Wall Angles
	local stackPositions = {
		{ Pos = Vector3.new(-82, 2.0, -68), Rot = 35, Color1 = Color3.fromRGB(30, 41, 59), Color2 = Color3.fromRGB(180, 83, 9) },
		{ Pos = Vector3.new(82, 2.0, -68), Rot = -35, Color1 = Color3.fromRGB(15, 23, 42), Color2 = Color3.fromRGB(56, 189, 248) },
		{ Pos = Vector3.new(-82, 2.0, 68), Rot = 145, Color1 = Color3.fromRGB(185, 28, 28), Color2 = Color3.fromRGB(30, 41, 59) },
		{ Pos = Vector3.new(82, 2.0, 68), Rot = -145, Color1 = Color3.fromRGB(16, 185, 129), Color2 = Color3.fromRGB(15, 23, 42) },
	}

	for idx, sData in stackPositions do
		local stackGroup = Instance.new("Folder")
		stackGroup.Name = `CargoDepotStack_{idx}`
		stackGroup.Parent = propsFolder

		local baseCF = CFrame.new(sData.Pos) * CFrame.Angles(0, math.rad(sData.Rot), 0)

		createShippingContainer(`CrateA_{idx}`, baseCF, sData.Color1, stackGroup)
		createShippingContainer(`CrateB_{idx}`, baseCF * CFrame.new(0, 0, 9), Color3.fromRGB(51, 65, 85), stackGroup)
		createShippingContainer(`CrateC_{idx}`, baseCF * CFrame.new(2, 8, 4.5) * CFrame.Angles(0, math.rad(5), 0), sData.Color2, stackGroup)
	end

	-- 2 High-Voltage Power Transformer Substations
	for _, xSign in { -1, 1 } do
		local subCF = CFrame.new(xSign * 98, 2.0, 0) * CFrame.Angles(0, math.rad(xSign * 90), 0)

		createPart("SubstationPad", Vector3.new(16, 1.2, 12), subCF * CFrame.new(0, 0.6, 0), Color3.fromRGB(47, 55, 70), Enum.Material.Concrete, propsFolder, true)
		local xfmr = createPart("TransformerHousing", Vector3.new(8, 7, 7), subCF * CFrame.new(0, 4.6, 0), Color3.fromRGB(24, 28, 40), Enum.Material.Metal, propsFolder, true)

		for bX = -2.4, 2.4, 2.4 do
			createCylinder("BushingInsulator", Vector3.new(2.4, 0.8, 0.8), xfmr.CFrame * CFrame.new(bX, 4.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(180, 83, 9), Enum.Material.SmoothPlastic, xfmr, false)
			createPart("BushingTerminal", Vector3.new(0.3, 0.8, 0.3), xfmr.CFrame * CFrame.new(bX, 5.6, 0), Color3.fromRGB(203, 213, 225), Enum.Material.Metal, xfmr, false)
		end

		local warnGlow = createPart("WarningIndicator", Vector3.new(1.0, 1.0, 0.2), subCF * CFrame.new(0, 5, 3.6), Color3.fromRGB(245, 158, 11), Enum.Material.Neon, xfmr, false)
		local wLight = Instance.new("PointLight")
		wLight.Color = Color3.fromRGB(245, 158, 11)
		wLight.Range = 14
		wLight.Brightness = 1.8
		wLight.Parent = warnGlow
	end
end

-- ============================================================
-- 7. OVERHEAD CRANE GANTRIES & CARGO SUSPENSION
-- ============================================================
local function buildOverheadCraneGantries(parent: Folder)
	local gantryFolder = Instance.new("Folder")
	gantryFolder.Name = "OverheadIndustrialGantries"
	gantryFolder.Parent = parent

	local gantryHeights = { 32, 36 }
	local zOffsets = { -45, 0, 45 }

	for idx, zOff in zOffsets do
		local beamHeight = gantryHeights[(idx % 2) + 1]
		local spanLen = 224

		-- Massive Industrial Yellow Crane Box Girder
		local girder = createPart(
			`CraneGirder_{idx}`,
			Vector3.new(spanLen, 3.8, 3.4),
			CFrame.new(0, beamHeight, zOff),
			Color3.fromRGB(245, 158, 11),
			Enum.Material.Metal,
			gantryFolder,
			true
		)

		-- Top & Bottom Heavy Steel Flange Plates
		createPart(
			`CraneFlangeTop_{idx}`,
			Vector3.new(spanLen, 0.4, 4.4),
			CFrame.new(0, beamHeight + 2.0, zOff),
			Color3.fromRGB(38, 44, 56),
			Enum.Material.Metal,
			girder,
			true
		)
		createPart(
			`CraneFlangeBottom_{idx}`,
			Vector3.new(spanLen, 0.4, 4.4),
			CFrame.new(0, beamHeight - 2.0, zOff),
			Color3.fromRGB(38, 44, 56),
			Enum.Material.Metal,
			girder,
			true
		)

		-- Yellow and Black Hazard Striping along Girder Sides
		for sX = -90, 90, 15 do
			createPart(
				`HazardChevron_{idx}_{sX}`,
				Vector3.new(6.0, 1.4, 0.15),
				CFrame.new(sX, beamHeight, zOff + 1.8),
				(math.abs(sX) % 30 == 0) and Color3.fromRGB(24, 24, 27) or Color3.fromRGB(245, 158, 11),
				Enum.Material.SmoothPlastic,
				girder,
				false
			)
		end

		-- Suspended Motorized Crane Trolley Carriage (Positioned at different points along the rail)
		local trolleyX = (idx == 1 and -30) or (idx == 2 and 40) or -10
		local trolleyCF = CFrame.new(trolleyX, beamHeight - 3.2, zOff)
		local trolley = createPart(
			`CraneTrolley_{idx}`,
			Vector3.new(8.0, 2.2, 5.5),
			trolleyCF,
			Color3.fromRGB(30, 36, 48),
			Enum.Material.Metal,
			girder,
			true
		)

		-- Dual Hanging Steel Hoist Cables
		createCylinder(`HoistCableL_{idx}`, Vector3.new(12.0, 0.2, 0.2), trolleyCF * CFrame.new(-1.8, -6.5, 0), Color3.fromRGB(180, 195, 210), Enum.Material.Metal, trolley, false)
		createCylinder(`HoistCableR_{idx}`, Vector3.new(12.0, 0.2, 0.2), trolleyCF * CFrame.new(1.8, -6.5, 0), Color3.fromRGB(180, 195, 210), Enum.Material.Metal, trolley, false)

		-- Heavy Industrial Cargo Hook Block
		local hookBlock = createPart(
			`HookBlock_{idx}`,
			Vector3.new(4.2, 2.8, 3.2),
			trolleyCF * CFrame.new(0, -13.0, 0),
			Color3.fromRGB(245, 158, 11),
			Enum.Material.Metal,
			trolley,
			true
		)
		createPart("HookSheave", Vector3.new(2.4, 1.8, 1.8), hookBlock.CFrame * CFrame.new(0, -1.8, 0), Color3.fromRGB(24, 24, 27), Enum.Material.Metal, hookBlock, false)

		-- High-Bay Halogen Floodlights on Girder
		for _, xPos in { -65, -20, 20, 65 } do
			local bayShroud = createPart(
				`HighBayShroud_{idx}_{xPos}`,
				Vector3.new(3.2, 1.0, 3.2),
				CFrame.new(xPos, beamHeight - 2.2, zOff),
				Color3.fromRGB(24, 28, 38),
				Enum.Material.Metal,
				girder,
				false
			)
			local bayLens = createPart(
				`HighBayLight_{idx}_{xPos}`,
				Vector3.new(2.6, 0.2, 2.6),
				CFrame.new(xPos, beamHeight - 2.7, zOff),
				Color3.fromRGB(254, 240, 138),
				Enum.Material.Neon,
				girder,
				false
			)
			local spot = Instance.new("SpotLight")
			spot.Name = "ArenaWorkFlood"
			spot.Face = Enum.NormalId.Bottom
			spot.Range = 90
			spot.Angle = 85
			spot.Brightness = 2.4
			spot.Color = Color3.fromRGB(255, 225, 160)
			spot.Shadows = true
			spot.Parent = bayLens
		end
	end
end

-- ============================================================
-- 8. CAVERN CEILING CANOPY (Zero Open Sky Visible)
-- ============================================================
local function buildCavernCeilingCanopy(parent: Folder)
	local ceilingFolder = Instance.new("Folder")
	ceilingFolder.Name = "CavernCeilingCanopy"
	ceilingFolder.Parent = parent

	local numSegs = 16
	local radius = 118
	local baseCeilingY = 36
	local apexCeilingY = 48
	local halfAngle = math.pi / numSegs
	local segWidth = 2 * radius * math.sin(halfAngle) + 6

	local centerHub = createPart(
		"CeilingCenterHub",
		Vector3.new(44, 4, 44),
		CFrame.new(0, apexCeilingY, 0),
		Color3.fromRGB(30, 41, 59),
		Enum.Material.DiamondPlate,
		ceilingFolder,
		true
	)

	createCylinder(
		"CeilingTurbineCore",
		Vector3.new(4, 32, 32),
		CFrame.new(0, apexCeilingY + 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(56, 189, 248),
		Enum.Material.Neon,
		centerHub,
		false
	)

	for i = 1, numSegs do
		local angle = (i - 0.5) * (math.pi * 2 / numSegs)
		local outerPos = Vector3.new(math.cos(angle) * radius, baseCeilingY, math.sin(angle) * radius)
		local innerPos = Vector3.new(math.cos(angle) * 22, apexCeilingY, math.sin(angle) * 22)
		local midPos = (outerPos + innerPos) / 2
		local spanLen = (outerPos - innerPos).Magnitude + 6

		local slabCF = CFrame.lookAt(midPos, Vector3.new(0, midPos.Y, 0)) * CFrame.Angles(math.atan2(apexCeilingY - baseCeilingY, radius - 22), 0, 0)

		createPart(
			`CeilingSlab_{i}`,
			Vector3.new(segWidth, 3.5, spanLen),
			slabCF,
			(i % 2 == 0) and Color3.fromRGB(34, 40, 54) or Color3.fromRGB(28, 34, 46),
			Enum.Material.Slate,
			ceilingFolder,
			true
		)
	end

	-- Full-Map Structural Cavern Cap (300x300 at Y=50, completely seals off open sky)
	createPart(
		"CavernFacilityCeilingCap",
		Vector3.new(300, 4.0, 300),
		CFrame.new(0, 50, 0),
		Color3.fromRGB(15, 18, 26),
		Enum.Material.Slate,
		ceilingFolder,
		true
	)
end

-- ============================================================
-- 9. ELEVATED PERIMETER INDUSTRIAL CATWALK SYSTEM (Y=22)
-- ============================================================
local function buildElevatedCatwalkSystem(parent: Folder)
	local catwalkFolder = Instance.new("Folder")
	catwalkFolder.Name = "ElevatedPerimeterCatwalks"
	catwalkFolder.Parent = parent

	local numCatwalkSegs = 16
	local catwalkRadius = 102
	local catwalkY = 22.0
	local halfAngle = math.pi / numCatwalkSegs
	local segWidth = 2 * catwalkRadius * math.sin(halfAngle) + 4

	for i = 1, numCatwalkSegs do
		local angle = (i - 0.5) * (math.pi * 2 / numCatwalkSegs)
		local pos = Vector3.new(math.cos(angle) * catwalkRadius, catwalkY, math.sin(angle) * catwalkRadius)
		local lookCenterCF = CFrame.lookAt(pos, Vector3.new(0, catwalkY, 0))

		-- Grated Metal Deck
		createPart(
			`CatwalkDeck_{i}`,
			Vector3.new(segWidth, 0.6, 6.0),
			lookCenterCF,
			Color3.fromRGB(38, 46, 60),
			Enum.Material.DiamondPlate,
			catwalkFolder,
			true
		)

		-- Heavy Under-Deck Steel Support Girder
		createPart(
			`CatwalkGirder_{i}`,
			Vector3.new(segWidth, 1.4, 1.2),
			lookCenterCF * CFrame.new(0, -1.0, 0),
			Color3.fromRGB(24, 28, 40),
			Enum.Material.Metal,
			catwalkFolder,
			true
		)

		-- Inner Safety Handrail
		createPart(
			`CatwalkInnerRail_{i}`,
			Vector3.new(segWidth, 3.2, 0.3),
			lookCenterCF * CFrame.new(0, 1.9, 2.85),
			Color3.fromRGB(51, 65, 85),
			Enum.Material.Metal,
			catwalkFolder,
			true
		)

		-- Outer Safety Handrail
		createPart(
			`CatwalkOuterRail_{i}`,
			Vector3.new(segWidth, 3.2, 0.3),
			lookCenterCF * CFrame.new(0, 1.9, -2.85),
			Color3.fromRGB(51, 65, 85),
			Enum.Material.Metal,
			catwalkFolder,
			true
		)

		-- Downward Catwalk Worklights (Every 2nd segment)
		if i % 2 == 0 then
			local lightPart = createPart(
				`CatwalkWorkLight_{i}`,
				Vector3.new(1.8, 0.6, 1.8),
				lookCenterCF * CFrame.new(0, -1.4, 0),
				Color3.fromRGB(254, 240, 138),
				Enum.Material.Neon,
				catwalkFolder,
				false
			)
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Bottom
			spot.Range = 45
			spot.Angle = 75
			spot.Brightness = 1.8
			spot.Color = Color3.fromRGB(255, 220, 150)
			spot.Parent = lightPart
		end
	end

	-- 2 Industrial Access Staircases Connecting Ground to Catwalk
	local stairAngles = { math.rad(55), math.rad(235) }
	for sIdx, sAngle in stairAngles do
		local stairStartDist = 92
		local sPos = Vector3.new(math.cos(sAngle) * stairStartDist, 2.0, math.sin(sAngle) * stairStartDist)
		local sLook = CFrame.lookAt(sPos, sPos + Vector3.new(-math.sin(sAngle), 0, math.cos(sAngle)))

		local numSteps = 20
		local stepHeight = (catwalkY - 2.0) / numSteps
		local stepDepth = 2.4

		for step = 1, numSteps do
			local stepCF = sLook * CFrame.new(0, step * stepHeight, -step * stepDepth)
			createPart(
				`StairTread_{sIdx}_{step}`,
				Vector3.new(5.5, 0.4, stepDepth),
				stepCF,
				Color3.fromRGB(38, 46, 60),
				Enum.Material.DiamondPlate,
				catwalkFolder,
				true
			)
			createPart(
				`StairNose_{sIdx}_{step}`,
				Vector3.new(5.6, 0.45, 0.3),
				stepCF * CFrame.new(0, 0.05, -stepDepth / 2),
				Color3.fromRGB(245, 158, 11),
				Enum.Material.SmoothPlastic,
				catwalkFolder,
				false
			)
		end
	end
end

-- ============================================================
-- 10. SYNDICATE BLACK MARKET & SMUGGLER ENCLAVE (black_market_vision.jpg)
-- ============================================================
local function buildSyndicateBlackMarketAlcove(parent: Folder)
	local marketFolder = Instance.new("Folder")
	marketFolder.Name = "SyndicateBlackMarketAlcove"
	marketFolder.Parent = parent

	local centerCF = CFrame.new(0, 2.0, -96)

	-- Arched Bedrock Tunnel Vaulting (5 Heavy Structural Arches)
	for a = -2, 2 do
		local archZ = a * 8
		local archCF = centerCF * CFrame.new(0, 0, archZ)

		createPart(`ArchColL_{a}`, Vector3.new(3.2, 22, 3.2), archCF * CFrame.new(-16, 11, 0), Color3.fromRGB(24, 28, 40), Enum.Material.Metal, marketFolder, true)
		createPart(`ArchColR_{a}`, Vector3.new(3.2, 22, 3.2), archCF * CFrame.new(16, 11, 0), Color3.fromRGB(24, 28, 40), Enum.Material.Metal, marketFolder, true)
		createPart(`ArchTop_{a}`, Vector3.new(32, 2.8, 3.4), archCF * CFrame.new(0, 22, 0), Color3.fromRGB(38, 46, 60), Enum.Material.Metal, marketFolder, true)

		local cableMid = archCF * CFrame.new(0, 18, 0)
		createCylinder(`HangingCable_{a}`, Vector3.new(28, 0.25, 0.25), cableMid * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(20, 24, 30), Enum.Material.Metal, marketFolder, false)
	end

	-- Smuggler Counter & Signboard
	local counterCF = centerCF * CFrame.new(0, 0, -12)
	createPart("SmugglerCounter", Vector3.new(20, 3.6, 4.0), counterCF * CFrame.new(0, 1.8, 0), Color3.fromRGB(24, 30, 42), Enum.Material.Metal, marketFolder, true)
	createPart("CounterTrim", Vector3.new(20.4, 0.4, 4.4), counterCF * CFrame.new(0, 3.7, 0), Color3.fromRGB(245, 158, 11), Enum.Material.DiamondPlate, marketFolder, true)

	local signBoard = createPart("MarketSign", Vector3.new(18, 2.8, 0.4), counterCF * CFrame.new(0, 9.5, 0), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, marketFolder, true)
	local sGui = Instance.new("SurfaceGui")
	sGui.Face = Enum.NormalId.Front
	sGui.CanvasSize = Vector2.new(600, 100)
	sGui.LightInfluence = 0.0
	sGui.Parent = signBoard

	local sLbl = Instance.new("TextLabel")
	sLbl.Size = UDim2.fromScale(1, 1)
	sLbl.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	sLbl.Text = "SYNDICATE BLACK MARKET // CYBER ARSENAL"
	sLbl.TextColor3 = Color3.fromRGB(251, 191, 36)
	sLbl.TextSize = 22
	sLbl.Font = Enum.Font.BuilderSansExtraBold
	sLbl.Parent = sGui

	-- 3 Holographic Weapon Display Pedestals
	local weaponOffers = {
		{ Name = "Security Stun Baton", Price = 250, ModelKey = "StunBaton", X = -6 },
		{ Name = "EMP Laser Jammer", Price = 1500, ModelKey = "EMPJammer", X = 0 },
		{ Name = "Laser Breach Cutter", Price = 5000, ModelKey = "LaserCutter", X = 6 },
	}

	for _, wData in weaponOffers do
		local pedCF = counterCF * CFrame.new(wData.X, 0, 7)

		createCylinder(`PedBase_{wData.ModelKey}`, Vector3.new(1.8, 3.6, 3.6), pedCF * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, marketFolder, true)
		createCylinder(`PedTrim_{wData.ModelKey}`, Vector3.new(0.25, 3.8, 3.8), pedCF * CFrame.new(0, 1.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, marketFolder, false)

		local holoBeam = createCylinder(`HoloBeam_{wData.ModelKey}`, Vector3.new(3.2, 2.4, 2.4), pedCF * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, marketFolder, false)
		holoBeam.Transparency = 0.85

		ModelEngine.GetOrBuild(wData.ModelKey, marketFolder, pedCF * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, math.rad(45), 0), function()
			local fallbackModel = Instance.new("Model")
			fallbackModel.Name = wData.ModelKey
			fallbackModel.Parent = marketFolder
			createPart("WeaponMock", Vector3.new(0.8, 3.2, 0.8), pedCF * CFrame.new(0, 3.4, 0), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, fallbackModel, false)
			return fallbackModel
		end)

		local promptPart = createPart(`PromptPart_{wData.ModelKey}`, Vector3.new(1, 1, 1), pedCF * CFrame.new(0, 2.5, 0), Color3.fromRGB(0, 0, 0), Enum.Material.SmoothPlastic, marketFolder, false)
		promptPart.Transparency = 1.0

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = `EQUIP // ${wData.Price}`
		prompt.ObjectText = wData.Name
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 8.0
		prompt.RequiresLineOfSight = false
		prompt.Parent = promptPart

		prompt.Triggered:Connect(function(triggerPlayer)
			local toolSvc = script.Parent:FindFirstChild("ToolService")
			if toolSvc then
				local svc = require(toolSvc :: ModuleScript)
				if svc and svc.GiveLoadout then
					svc.GiveLoadout(triggerPlayer)
				end
			end
		end)
	end

	-- Stacked Industrial Crates and Barrels
	ModelEngine.CreateIndustrialCrate(marketFolder, centerCF * CFrame.new(-12, 0, -6), 1.2)
	ModelEngine.CreateIndustrialCrate(marketFolder, centerCF * CFrame.new(-12, 0, -11), 1.0)
	ModelEngine.CreateIndustrialBarrel(marketFolder, centerCF * CFrame.new(12, 0, -6))
	ModelEngine.CreateIndustrialBarrel(marketFolder, centerCF * CFrame.new(13.5, 0, -8))

	-- Ground Fog / Ambient Mist Emitter
	local fogEmitterPart = createPart("MarketFogEmitter", Vector3.new(24, 0.2, 16), centerCF * CFrame.new(0, 0.2, 0), Color3.fromRGB(0, 0, 0), Enum.Material.SmoothPlastic, marketFolder, false)
	fogEmitterPart.Transparency = 1.0

	local mist = Instance.new("ParticleEmitter")
	mist.Rate = 5
	mist.Speed = NumberRange.new(0.8, 1.8)
	mist.Lifetime = NumberRange.new(3.0, 5.0)
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.0), NumberSequenceKeypoint.new(1, 8.0) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1.0) })
	mist.Color = ColorSequence.new(Color3.fromRGB(56, 189, 248))
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Parent = fogEmitterPart
end

-- ============================================================
-- 11. RELIC FUSION ALTAR ENCLAVE (transmutation-altar.glb)
-- ============================================================
local function buildRelicFusionAltarChamber(parent: Folder)
	local altarFolder = Instance.new("Folder")
	altarFolder.Name = "RelicFusionAltarChamber"
	altarFolder.Parent = parent

	local altarCF = CFrame.new(-75, 2.0, -75) * CFrame.Angles(0, math.rad(45), 0)

	createPart("AltarPlinthBase", Vector3.new(22, 1.4, 22), altarCF * CFrame.new(0, 0.7, 0), Color3.fromRGB(15, 20, 28), Enum.Material.Slate, altarFolder, true)
	createPart("AltarPlinthTier2", Vector3.new(18, 1.0, 18), altarCF * CFrame.new(0, 1.8, 0), Color3.fromRGB(30, 41, 59), Enum.Material.DiamondPlate, altarFolder, true)

	for i = 1, 8 do
		local ang = (i / 8) * (math.pi * 2)
		local pX = math.cos(ang) * 9.5
		local pZ = math.sin(ang) * 9.5
		createPart(`AltarRune_{i}`, Vector3.new(2.4, 0.2, 0.6), altarCF * CFrame.new(pX, 2.35, pZ) * CFrame.Angles(0, -ang, 0), Color3.fromRGB(168, 85, 247), Enum.Material.Neon, altarFolder, false)
	end

	ModelEngine.GetOrBuild("TransmutationAltar", altarFolder, altarCF * CFrame.new(0, 2.3, 0), function()
		local m = Instance.new("Model")
		m.Name = "TransmutationAltar"
		m.Parent = altarFolder

		local pedestal = createPart("CentralSpire", Vector3.new(5.0, 7.0, 5.0), altarCF * CFrame.new(0, 5.5, 0), Color3.fromRGB(24, 28, 40), Enum.Material.Slate, m, true)
		m.PrimaryPart = pedestal

		local vortexGlow = createCylinder("VortexCore", Vector3.new(1.2, 3.8, 3.8), altarCF * CFrame.new(0, 9.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(168, 85, 247), Enum.Material.Neon, m, false)
		vortexGlow.Transparency = 0.3

		local pLight = Instance.new("PointLight")
		pLight.Color = Color3.fromRGB(192, 132, 252)
		pLight.Range = 22
		pLight.Brightness = 2.2
		pLight.Parent = vortexGlow

		return m
	end)

	local promptPart = createPart("AltarPromptPart", Vector3.new(2, 2, 2), altarCF * CFrame.new(0, 4.5, 0), Color3.fromRGB(0, 0, 0), Enum.Material.SmoothPlastic, altarFolder, false)
	promptPart.Transparency = 1.0

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "ACCESS RELIC FUSION"
	prompt.ObjectText = "TRANSMUTATION ALTAR"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10.0
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart

	ModelEngine.CreateRockBoulder(altarFolder, altarCF * CFrame.new(-12, 0, 4), Vector3.new(8, 7, 8))
	ModelEngine.CreateRockBoulder(altarFolder, altarCF * CFrame.new(12, 0, 4), Vector3.new(9, 8, 9))
end

-- ============================================================
-- 12. NATURAL CAVERN ROCK FORMATIONS (reactor_cavern_vision.jpg)
-- ============================================================
local function buildNaturalRockCavernFormations(parent: Folder)
	local rocksFolder = Instance.new("Folder")
	rocksFolder.Name = "CavernRockFormations"
	rocksFolder.Parent = parent

	for i = 1, 16 do
		local angle = (i / 16) * (math.pi * 2)
		local rockDist = 110
		local rockPos = Vector3.new(math.cos(angle) * rockDist, 2.0, math.sin(angle) * rockDist)
		local rockCF = CFrame.new(rockPos) * CFrame.Angles(0, angle + math.rad(25), 0)

		local scale = 1.0 + (i % 3) * 0.4
		ModelEngine.CreateRockBoulder(rocksFolder, rockCF, Vector3.new(12 * scale, 14 * scale, 10 * scale))
	end
end

-- ============================================================
-- 13. STUDIO CUSTOM WORLD DECOR INTEGRATION
-- ============================================================
local function integrateCustomWorldDecor()
	local customFolder = Workspace:FindFirstChild("CustomWorldDecor")
	if not customFolder then
		customFolder = Instance.new("Folder")
		customFolder.Name = "CustomWorldDecor"
		customFolder.Parent = Workspace
	end

	for _, desc in customFolder:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
		end
	end
end

-- ============================================================
-- MAIN INITIALIZATION
-- ============================================================
function EnvironmentService.Init()
	print("  [EnvironmentService] Ingesting Studio 3D Models & Building Cyber-Cavern...")

	-- 0. Auto-ingest any 3D models imported into Workspace by user
	ModelEngine.IngestStudioModels()

	-- 1. Baseplate cleanup
	cleanupBaseplates()

	-- 2. Atmospheric Future Lighting
	setupAtmosphericLighting()

	-- 3. Root Cavern Model
	local existing = Workspace:FindFirstChild("VaultWarsCavern")
	if existing then existing:Destroy() end

	local cavernFolder = Instance.new("Folder")
	cavernFolder.Name = "VaultWarsCavern"
	cavernFolder.Parent = Workspace
	EnvironmentService._folder = cavernFolder

	-- 4. Full-World Architecture (Matching Vision Renders)
	buildContinuousBedrockDeck(cavernFolder)
	buildCavernEnclosure(cavernFolder)
	buildNaturalRockCavernFormations(cavernFolder)
	buildCavernCeilingCanopy(cavernFolder)
	buildElevatedCatwalkSystem(cavernFolder)
	buildRotatingWallTurbines(cavernFolder)
	buildPerimeterIndustrialProps(cavernFolder)
	buildOverheadCraneGantries(cavernFolder)
	buildSyndicateBlackMarketAlcove(cavernFolder)
	buildRelicFusionAltarChamber(cavernFolder)
	integrateCustomWorldDecor()

	print("  [EnvironmentService] Catwalks, Black Market, Altar, Rock formations, and Industrial assets online ✓")
end

return EnvironmentService
