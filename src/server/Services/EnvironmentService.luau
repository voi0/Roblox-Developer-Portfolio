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
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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

	Lighting.ClockTime = 16.2
	Lighting.TimeOfDay = "16:12:00"
	Lighting.Brightness = 1.5
	Lighting.Ambient = Color3.fromRGB(8, 8, 14)
	Lighting.OutdoorAmbient = Color3.fromRGB(36, 42, 54)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 244, 228)
	Lighting.ColorShift_Bottom = Color3.fromRGB(28, 32, 42)
	Lighting.GeographicLatitude = 38
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1.0
	Lighting.EnvironmentSpecularScale = 1.0
	Lighting.FogStart = 350
	Lighting.FogEnd = 1800
	Lighting.FogColor = Color3.fromRGB(28, 34, 46)

	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") then
			pcall(function() child:Destroy() end)
		end
	end

	local voidSky = Instance.new("Sky")
	voidSky.Name = "SubterraneanAtmosphereSky"
	voidSky.SkyboxBk = ""
	voidSky.SkyboxDn = ""
	voidSky.SkyboxFt = ""
	voidSky.SkyboxLf = ""
	voidSky.SkyboxRt = ""
	voidSky.SkyboxUp = ""
	voidSky.SunAngularSize = 0
	voidSky.MoonAngularSize = 0
	voidSky.StarCount = 0
	voidSky.Parent = Lighting

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.36
	atmosphere.Offset = 0.22
	atmosphere.Color = Color3.fromRGB(152, 168, 186)
	atmosphere.Decay = Color3.fromRGB(72, 85, 106)
	atmosphere.Glare = 0.0
	atmosphere.Haze = 2.0

	local bloom = Lighting:FindFirstChild("VaultWarsBloom") :: BloomEffect?
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "VaultWarsBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.25
	bloom.Size = 22
	bloom.Threshold = 1.25

	local cc = Lighting:FindFirstChild("VaultWarsCC") :: ColorCorrectionEffect?
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "VaultWarsCC"
		cc.Parent = Lighting
	end
	cc.TintColor = Color3.fromRGB(255, 250, 244)
	cc.Brightness = 0.02
	cc.Contrast = 0.16
	cc.Saturation = 0.12

	local sunRays = Lighting:FindFirstChild("VaultWarsSunRays") :: SunRaysEffect?
	if not sunRays then
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = "VaultWarsSunRays"
		sunRays.Parent = Lighting
	end
	sunRays.Intensity = 0.10
	sunRays.Spread = 0.8

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

	local gantryHeights = { 28, 32 }
	local zOffsets = { -35, 0, 35 }

	for idx, zOff in zOffsets do
		local beamHeight = gantryHeights[(idx % 2) + 1]
		local spanLen = 220

		local girder = createPart(
			`CraneGirder_{idx}`,
			Vector3.new(spanLen, 4.0, 5.0),
			CFrame.new(0, beamHeight, zOff),
			Color3.fromRGB(24, 28, 40),
			Enum.Material.DiamondPlate,
			gantryFolder,
			true
		)

		createPart(
			`CraneRailL_{idx}`,
			Vector3.new(spanLen, 0.8, 0.8),
			CFrame.new(0, beamHeight + 2.2, zOff - 1.8),
			Color3.fromRGB(245, 158, 11),
			Enum.Material.Metal,
			girder,
			false
		)

		for _, xPos in { -50, -18, 18, 50 } do
			createPart(
				`HighBayShroud_{idx}_{xPos}`,
				Vector3.new(3.8, 1.2, 3.8),
				CFrame.new(xPos, beamHeight - 2.0, zOff),
				Color3.fromRGB(15, 20, 28),
				Enum.Material.Metal,
				girder,
				false
			)

			local bayLightPart = createPart(
				`HighBayLight_{idx}_{xPos}`,
				Vector3.new(3.0, 0.4, 3.0),
				CFrame.new(xPos, beamHeight - 2.6, zOff),
				Color3.fromRGB(254, 240, 138),
				Enum.Material.Neon,
				girder,
				false
			)
			local point = Instance.new("PointLight")
			point.Name = "ArenaHighBayIllumination"
			point.Color = Color3.fromRGB(255, 248, 235)
			point.Range = 95
			point.Brightness = 3.6
			point.Shadows = true
			point.Parent = bayLightPart
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
end

-- ============================================================
-- MAIN INITIALIZATION
-- ============================================================
function EnvironmentService.Init()
	print("  [EnvironmentService] Constructing Continuous Subterranean Cyber-Facility...")

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

	-- 4. Full-World Architecture
	buildContinuousBedrockDeck(cavernFolder)
	buildCavernEnclosure(cavernFolder)
	buildCavernCeilingCanopy(cavernFolder)
	buildRotatingWallTurbines(cavernFolder)
	buildPerimeterIndustrialProps(cavernFolder)
	buildOverheadCraneGantries(cavernFolder)

	print("  [EnvironmentService] Bedrock deck, perimeter walls, ceiling canopy, cargo depots, and volumetric lighting initialized ✓")
end

return EnvironmentService
