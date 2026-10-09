--!strict
--[[
	EnvironmentService.luau — Subterranean Cyberpunk World & Atmosphere Engine
	Constructs the massive underground cavern facility for VAULT WARS:
	- Destroys conflicting default Baseplates to eliminate Z-fighting
	- Configures volumetric Lighting (Technology.Future, deep industrial atmosphere, bloom)
	- Builds 16-sided perimeter blast cavern walls with heavy I-beams, conduit pipes & exhaust vents
	- Spans overhead industrial crane gantries with suspended shipping crates & sodium floodlights
	- Installs perimeter coolant plasma trenches and monolithic background server racks
	Located in: ServerScriptService.Server.Services.EnvironmentService
]]

local Lighting = game:GetService("Lighting")
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

	Lighting.ClockTime = 14.0
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(72, 85, 108)
	Lighting.OutdoorAmbient = Color3.fromRGB(58, 70, 90)
	Lighting.GeographicLatitude = 25
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1.0
	Lighting.EnvironmentSpecularScale = 1.0
	Lighting.FogStart = 450
	Lighting.FogEnd = 2400
	Lighting.FogColor = Color3.fromRGB(24, 32, 46)

	-- Subterranean Deep Industrial Atmosphere
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.22
	atmosphere.Color = Color3.fromRGB(120, 145, 175)
	atmosphere.Decay = Color3.fromRGB(36, 46, 64)
	atmosphere.Glare = 0.16
	atmosphere.Haze = 0.60

	-- High-Threshold Bloom (Neon glows brightly, normal materials never blow out)
	local bloom = Lighting:FindFirstChild("VaultWarsBloom") :: BloomEffect?
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "VaultWarsBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.55
	bloom.Size = 24
	bloom.Threshold = 2.05

	-- Filmic ColorCorrection (Rich contrast & depth)
	local cc = Lighting:FindFirstChild("VaultWarsCC") :: ColorCorrectionEffect?
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "VaultWarsCC"
		cc.Parent = Lighting
	end
	cc.TintColor = Color3.fromRGB(245, 250, 255)
	cc.Brightness = 0.01
	cc.Contrast = 0.16
	cc.Saturation = 0.16

	-- Depth of Field (Cinematic camera bokeh on distant cavern geometry)
	local dof = Lighting:FindFirstChild("VaultWarsDOF") :: DepthOfFieldEffect?
	if not dof then
		dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "VaultWarsDOF"
		dof.Parent = Lighting
	end
	dof.FarIntensity = 0.16
	dof.FocusDistance = 45
	dof.InFocusRadius = 65
	dof.NearIntensity = 0.0
end

-- ============================================================
-- 3. PERIMETER CAVERN BLAST WALLS (16-Sided Enclosure)
-- ============================================================
local function buildCavernEnclosure(parent: Folder)
	local numSegments = 16
	local radius = 175
	local wallHeight = 92
	local wallThickness = 6
	local halfAngle = math.pi / numSegments
	local segmentWidth = 2 * radius * math.sin(halfAngle) + 4

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "PerimeterBlastWalls"
	wallsFolder.Parent = parent

	for i = 1, numSegments do
		local centerAngle = (i - 0.5) * (math.pi * 2 / numSegments)
		local vertAngle = i * (math.pi * 2 / numSegments)

		local wallPos = Vector3.new(
			math.cos(centerAngle) * radius,
			wallHeight / 2,
			math.sin(centerAngle) * radius
		)
		local lookCenterCF = CFrame.lookAt(wallPos, Vector3.new(0, wallHeight / 2, 0))

		-- 3.1. Lower Armored Blast Slab (DiamondPlate)
		createPart(
			`BlastWallLower_{i}`,
			Vector3.new(segmentWidth, 42, wallThickness),
			lookCenterCF * CFrame.new(0, -25, 0),
			Color3.fromRGB(58, 66, 84),
			Enum.Material.DiamondPlate,
			wallsFolder,
			true
		)

		-- 3.2. Upper Corrugated Blast Wall
		createPart(
			`BlastWallUpper_{i}`,
			Vector3.new(segmentWidth, 50, wallThickness - 1),
			lookCenterCF * CFrame.new(0, 21, 0.5),
			Color3.fromRGB(75, 86, 108),
			Enum.Material.Corrugated,
			wallsFolder,
			true
		)

		-- 3.3. Wall Trim & Horizontal Conduit Pipes
		-- Lower Cyan Coolant Pipeline
		createPart(
			`CoolantLine_{i}`,
			Vector3.new(segmentWidth + 2, 1.8, 1.8),
			lookCenterCF * CFrame.new(0, -5, -wallThickness / 2 - 0.8),
			Color3.fromRGB(14, 165, 233),
			Enum.Material.Metal,
			wallsFolder,
			false
		)
		-- Glowing Neon Indicator Band on Coolant Line
		createPart(
			`CoolantGlow_{i}`,
			Vector3.new(segmentWidth, 0.4, 0.4),
			lookCenterCF * CFrame.new(0, -5, -wallThickness / 2 - 1.8),
			Color3.fromRGB(56, 189, 248),
			Enum.Material.Neon,
			wallsFolder,
			false
		)

		-- Upper Amber High-Voltage Bus Conduit
		createPart(
			`VoltageBus_{i}`,
			Vector3.new(segmentWidth + 2, 1.4, 1.4),
			lookCenterCF * CFrame.new(0, 25, -wallThickness / 2 - 0.6),
			Color3.fromRGB(245, 158, 11),
			Enum.Material.Metal,
			wallsFolder,
			false
		)

		-- 3.4. Structural Heavy Vertical I-Beam Columns at Vertices
		local vertPos = Vector3.new(
			math.cos(vertAngle) * radius,
			wallHeight / 2,
			math.sin(vertAngle) * radius
		)
		local vertCF = CFrame.lookAt(vertPos, Vector3.new(0, wallHeight / 2, 0))

		local column = createPart(
			`StructuralIBeam_{i}`,
			Vector3.new(4.5, wallHeight + 4, 4.5),
			vertCF,
			Color3.fromRGB(42, 48, 64),
			Enum.Material.Metal,
			wallsFolder,
			true
		)

		-- Column Hazard Warning Chevron Panels (Alternating Yellow/Black)
		local hazardPlate = createPart(
			`HazardPlate_{i}`,
			Vector3.new(4.6, 12, 0.4),
			vertCF * CFrame.new(0, -28, -2.4),
			(i % 2 == 0) and Color3.fromRGB(245, 158, 11) or Color3.fromRGB(24, 24, 27),
			Enum.Material.SmoothPlastic,
			column,
			false
		)

		-- 3.5. Wall-Mounted Volumetric Floodlights (Every 2nd segment)
		if i % 2 == 1 then
			local lightHousing = createPart(
				`WallFloodHousing_{i}`,
				Vector3.new(3.5, 2.0, 3.5),
				lookCenterCF * CFrame.new(0, 34, -wallThickness / 2 - 2) * CFrame.Angles(math.rad(-35), 0, 0),
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
			spot.Range = 110
			spot.Angle = 65
			spot.Brightness = 2.4
			spot.Color = (i % 4 == 1) and Color3.fromRGB(251, 191, 36) or Color3.fromRGB(56, 189, 248)
			spot.Shadows = true
			spot.Parent = lightLens
		end

		-- 3.6. Industrial Ventilation Turbines (Every 4th segment)
		if i % 4 == 0 then
			local ventChamber = createPart(
				`VentChamber_{i}`,
				Vector3.new(14, 14, 4),
				lookCenterCF * CFrame.new(0, 10, -wallThickness / 2 - 1),
				Color3.fromRGB(11, 13, 20),
				Enum.Material.Metal,
				wallsFolder,
				false
			)

			local ventCore = createCylinder(
				`VentCore_{i}`,
				Vector3.new(3.8, 11, 11),
				ventChamber.CFrame * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(14, 165, 233),
				Enum.Material.Neon,
				ventChamber,
				false
			)
			ventCore.Transparency = 0.4
		end
	end
end

-- ============================================================
-- 4. OVERHEAD INDUSTRIAL CRANE GANTRIES & CARGO SUSPENSION
-- ============================================================
local function buildOverheadCraneGantries(parent: Folder)
	local gantryFolder = Instance.new("Folder")
	gantryFolder.Name = "OverheadIndustrialGantries"
	gantryFolder.Parent = parent

	local gantryHeights = { 76, 84 }
	local zOffsets = { -65, 0, 65 }

	for idx, zOff in zOffsets do
		local beamHeight = gantryHeights[(idx % 2) + 1]
		local spanLen = 330

		-- 4.1. Heavy Main Overhead Box Girder
		local girder = createPart(
			`CraneGirder_{idx}`,
			Vector3.new(spanLen, 5.0, 6.0),
			CFrame.new(0, beamHeight, zOff),
			Color3.fromRGB(24, 28, 40),
			Enum.Material.DiamondPlate,
			gantryFolder,
			true
		)

		-- Yellow Crane Rails along top
		createPart(
			`CraneRailL_{idx}`,
			Vector3.new(spanLen, 0.8, 0.8),
			CFrame.new(0, beamHeight + 2.8, zOff - 2.2),
			Color3.fromRGB(245, 158, 11),
			Enum.Material.Metal,
			girder,
			false
		)
		-- 4.15 High-Bay Industrial Sodium Floodlights with Volumetric Cones
		for _, xPos in { -80, -25, 25, 80 } do
			-- Cast-Iron Fixture Shroud
			createPart(
				`HighBayShroud_{idx}_{xPos}`,
				Vector3.new(4.2, 1.2, 4.2),
				CFrame.new(xPos, beamHeight - 2.4, zOff),
				Color3.fromRGB(15, 20, 28),
				Enum.Material.Metal,
				girder,
				false
			)

			local bayLightPart = createPart(
				`HighBayLight_{idx}_{xPos}`,
				Vector3.new(3.5, 0.4, 3.5),
				CFrame.new(xPos, beamHeight - 3.1, zOff),
				Color3.fromRGB(254, 240, 138),
				Enum.Material.Neon,
				girder,
				false
			)
			local point = Instance.new("PointLight")
			point.Name = "ArenaHighBayIllumination"
			point.Color = Color3.fromRGB(255, 244, 224)
			point.Range = 130
			point.Brightness = 2.2
			point.Shadows = true
			point.Parent = bayLightPart

			-- Semi-Transparent Volumetric Beam Cone
			local beamCone = Instance.new("Part")
			beamCone.Name = `VolumetricBeam_{idx}_{xPos}`
			beamCone.Size = Vector3.new(32, 46, 32)
			beamCone.CFrame = CFrame.new(xPos, beamHeight - 26, zOff)
			beamCone.Color = Color3.fromRGB(254, 240, 138)
			beamCone.Material = Enum.Material.Neon
			beamCone.Transparency = 0.94
			beamCone.CanCollide = false
			beamCone.CastShadow = false
			beamCone.Anchored = true
			beamCone.Parent = girder

			local coneMesh = Instance.new("SpecialMesh")
			coneMesh.MeshType = Enum.MeshType.Cylinder
			coneMesh.Parent = beamCone
		end

		-- 4.2. Motorized Crane Hoist Trolley
		local trolleyX = (idx == 1 and -45) or (idx == 2 and 35) or -10
		local trolley = createPart(
			`CraneTrolley_{idx}`,
			Vector3.new(12, 4.0, 9),
			CFrame.new(trolleyX, beamHeight - 3.5, zOff),
			Color3.fromRGB(234, 179, 8),
			Enum.Material.Metal,
			gantryFolder,
			true
		)

		-- Flashing Warning Beacon on Trolley
		local beacon = createPart(
			`TrolleyBeacon_{idx}`,
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(trolleyX, beamHeight - 1.0, zOff),
			Color3.fromRGB(239, 68, 68),
			Enum.Material.Neon,
			trolley,
			false
		)
		local pLight = Instance.new("PointLight")
		pLight.Color = Color3.fromRGB(239, 68, 68)
		pLight.Range = 25
		pLight.Brightness = 2.0
		pLight.Parent = beacon

		-- 4.3. Suspension Cables Hanging Down
		local dropLen = 32
		local cableY = beamHeight - 3.5 - (dropLen / 2)
		for _, xDelta in { -4, 4 } do
			createPart(
				`HoistCable_{idx}_{xDelta}`,
				Vector3.new(0.3, dropLen, 0.3),
				CFrame.new(trolleyX + xDelta, cableY, zOff),
				Color3.fromRGB(100, 116, 139),
				Enum.Material.Metal,
				gantryFolder,
				false
			)
		end

		-- 4.4. Suspended Industrial Tech Cargo Container
		local containerCF = CFrame.new(trolleyX, beamHeight - 3.5 - dropLen - 4.5, zOff)
		local container = createPart(
			`SuspendedTechContainer_{idx}`,
			Vector3.new(18, 9, 8.5),
			containerCF,
			(idx == 2) and Color3.fromRGB(15, 23, 42) or Color3.fromRGB(30, 41, 59),
			Enum.Material.Corrugated,
			gantryFolder,
			true
		)

		-- Container Hazard Frame
		createPart(
			`ContainerFrame_{idx}`,
			Vector3.new(18.4, 0.6, 8.9),
			containerCF * CFrame.new(0, 4.6, 0),
			Color3.fromRGB(245, 158, 11),
			Enum.Material.Metal,
			container,
			false
		)
		-- Container Status Hologram / Neon Stencil
		createPart(
			`ContainerHolo_{idx}`,
			Vector3.new(12, 2.2, 0.2),
			containerCF * CFrame.new(0, 0, -4.35),
			Color3.fromRGB(56, 189, 248),
			Enum.Material.Neon,
			container,
			false
		)
	end
end

-- ============================================================
-- 5. PERIMETER COOLANT TRENCH & PLASMA CONDUITS
-- ============================================================
local function buildCoolantDrainageTrenches(parent: Folder)
	local moatFolder = Instance.new("Folder")
	moatFolder.Name = "PerimeterCoolantTrench"
	moatFolder.Parent = parent

	local numMoatSegs = 16
	local moatRadius = 142
	local moatWidth = 10
	local halfAngle = math.pi / numMoatSegs
	local segLen = 2 * moatRadius * math.sin(halfAngle) + 2

	for i = 1, numMoatSegs do
		local angle = (i - 0.5) * (math.pi * 2 / numMoatSegs)
		local pos = Vector3.new(
			math.cos(angle) * moatRadius,
			0.5,
			math.sin(angle) * moatRadius
		)
		local cf = CFrame.lookAt(pos, Vector3.new(0, 0.5, 0))

		-- Trench Base Channel (Dark Obsidian)
		createPart(
			`TrenchBed_{i}`,
			Vector3.new(segLen, 1.4, moatWidth),
			cf * CFrame.new(0, -0.6, 0),
			Color3.fromRGB(11, 13, 20),
			Enum.Material.Concrete,
			moatFolder,
			true
		)

		-- Glowing Liquid Coolant (Neon Teal)
		local coolant = createPart(
			`CoolantLiquid_{i}`,
			Vector3.new(segLen, 0.4, moatWidth - 1.5),
			cf * CFrame.new(0, 0.1, 0),
			Color3.fromRGB(14, 165, 233),
			Enum.Material.Neon,
			moatFolder,
			false
		)
		coolant.Transparency = 0.25

		-- Heavy Safety Grating (Semi-transparent DiamondPlate)
		local grate = createPart(
			`TrenchGrate_{i}`,
			Vector3.new(segLen, 0.2, moatWidth),
			cf * CFrame.new(0, 0.4, 0),
			Color3.fromRGB(30, 41, 59),
			Enum.Material.DiamondPlate,
			moatFolder,
			true
		)
		grate.Transparency = 0.5
	end
end

-- ============================================================
-- 6. MONOLITHIC SERVER TOWERS & HOLOGRAPHIC TELEMETRY
-- ============================================================
local function buildBackgroundServerMonoliths(parent: Folder)
	local serverFolder = Instance.new("Folder")
	serverFolder.Name = "BackgroundServerMonoliths"
	serverFolder.Parent = parent

	local angles = { math.pi * 0.25, math.pi * 0.75, math.pi * 1.25, math.pi * 1.75 }
	local dist = 162

	for idx, angle in angles do
		local pos = Vector3.new(math.cos(angle) * dist, 24, math.sin(angle) * dist)
		local cf = CFrame.lookAt(pos, Vector3.new(0, 24, 0))

		-- 6.1. Massive Tower Body
		local tower = createPart(
			`ServerTower_{idx}`,
			Vector3.new(16, 48, 10),
			cf,
			Color3.fromRGB(15, 17, 26),
			Enum.Material.Metal,
			serverFolder,
			true
		)

		-- 6.2. Staggered Blinking LED Server Blade Racks
		for bladeY = -18, 18, 5 do
			local blade = createPart(
				`ServerBlade_{idx}_{bladeY}`,
				Vector3.new(13.5, 3.2, 0.4),
				cf * CFrame.new(0, bladeY, -5.2),
				Color3.fromRGB(24, 24, 32),
				Enum.Material.Metal,
				tower,
				false
			)

			-- Neon Activity Strips
			local ledColor = (bladeY % 10 == 0) and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(56, 189, 248)
			createPart(
				`BladeLED_{idx}_{bladeY}`,
				Vector3.new(11.5, 0.35, 0.2),
				blade.CFrame * CFrame.new(0, 0, -0.25),
				ledColor,
				Enum.Material.Neon,
				blade,
				false
			)
		end

		-- 6.3. Tower Cap & Antenna Transmitter
		createPart(
			`TowerCap_{idx}`,
			Vector3.new(17.2, 2.0, 11.2),
			cf * CFrame.new(0, 25, 0),
			Color3.fromRGB(30, 41, 59),
			Enum.Material.Metal,
			tower,
			false
		)
		createPart(
			`Antenna_{idx}`,
			Vector3.new(0.6, 16, 0.6),
			cf * CFrame.new(0, 33, 0),
			Color3.fromRGB(203, 213, 225),
			Enum.Material.Metal,
			tower,
			false
		)
		local antLight = createPart(
			`AntennaBeacon_{idx}`,
			Vector3.new(1.0, 1.0, 1.0),
			cf * CFrame.new(0, 41, 0),
			Color3.fromRGB(239, 68, 68),
			Enum.Material.Neon,
			tower,
			false
		)
		local bLight = Instance.new("PointLight")
		bLight.Color = Color3.fromRGB(239, 68, 68)
		bLight.Range = 20
		bLight.Brightness = 1.8
		bLight.Parent = antLight
	end
end

-- ============================================================
-- 7. CAVERN CEILING CANOPY & STRUCTURAL TRUSS DOME
-- ============================================================
local function buildCavernCeilingCanopy(parent: Folder)
	local ceilingFolder = Instance.new("Folder")
	ceilingFolder.Name = "CavernCeilingCanopy"
	ceilingFolder.Parent = parent

	local numSegs = 16
	local radius = 180
	local baseCeilingY = 92
	local apexCeilingY = 114
	local halfAngle = math.pi / numSegs
	local segWidth = 2 * radius * math.sin(halfAngle) + 6

	-- 7.1. Central Compression Hub Ring
	local centerHub = createPart(
		"CeilingCenterHub",
		Vector3.new(52, 6, 52),
		CFrame.new(0, apexCeilingY, 0),
		Color3.fromRGB(30, 41, 59),
		Enum.Material.DiamondPlate,
		ceilingFolder,
		true
	)

	-- Glowing Cyan Central Ventilation Turbine
	local turbineCore = createCylinder(
		"CeilingTurbineCore",
		Vector3.new(5, 42, 42),
		CFrame.new(0, apexCeilingY + 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(56, 189, 248),
		Enum.Material.Neon,
		centerHub,
		false
	)
	turbineCore.Transparency = 0.35

	-- 7.2. 16 Arched Bedrock & Armor Canopy Slabs (Zero open sky visible)
	for i = 1, numSegs do
		local angle = (i - 0.5) * (math.pi * 2 / numSegs)
		local outerPos = Vector3.new(math.cos(angle) * radius, baseCeilingY, math.sin(angle) * radius)
		local innerPos = Vector3.new(math.cos(angle) * 26, apexCeilingY, math.sin(angle) * 26)
		local midPos = (outerPos + innerPos) / 2
		local spanLen = (outerPos - innerPos).Magnitude + 8

		local slabCF = CFrame.lookAt(midPos, Vector3.new(0, midPos.Y, 0)) * CFrame.Angles(math.atan2(apexCeilingY - baseCeilingY, radius - 26), 0, 0)

		-- Main Bedrock / Slate Canopy Slab (Encloses entire sky)
		createPart(
			`CeilingSlab_{i}`,
			Vector3.new(segWidth, 4.0, spanLen),
			slabCF,
			(i % 2 == 0) and Color3.fromRGB(34, 40, 54) or Color3.fromRGB(28, 34, 46),
			Enum.Material.Slate,
			ceilingFolder,
			true
		)

		-- Internal Reinforced I-Beam Rafter
		createPart(
			`CeilingRafter_{i}`,
			Vector3.new(3.5, 3.5, spanLen),
			slabCF * CFrame.new(0, -2.5, 0),
			Color3.fromRGB(20, 24, 34),
			Enum.Material.Metal,
			ceilingFolder,
			false
		)
	end

	-- 7.3. Massive Steel Cross-Trusses (Spanning across cavern ceiling)
	for _, rotDeg in { 0, 45, 90, 135 } do
		createPart(
			`CeilingCrossTruss_{rotDeg}`,
			Vector3.new(350, 4.5, 5.0),
			CFrame.new(0, baseCeilingY + 2, 0) * CFrame.Angles(0, math.rad(rotDeg), 0),
			Color3.fromRGB(24, 28, 40),
			Enum.Material.DiamondPlate,
			ceilingFolder,
			false
		)
	end
end

-- ============================================================
-- MAIN INITIALIZATION
-- ============================================================
function EnvironmentService.Init()
	print("  [EnvironmentService] Constructing Subterranean Cyberpunk Cavern Complex...")

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

	-- 4. Cavern Architecture
	buildCavernEnclosure(cavernFolder)
	buildCavernCeilingCanopy(cavernFolder)
	buildOverheadCraneGantries(cavernFolder)
	buildCoolantDrainageTrenches(cavernFolder)
	buildBackgroundServerMonoliths(cavernFolder)

	print("  [EnvironmentService] Cavern walls, ceiling dome, overhead gantries, and volumetric lighting initialized ✓")
end

return EnvironmentService
