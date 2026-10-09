--!strict
--[[
	ModelEngine.luau — Procedural 3D Asset & Machinery Architecture for VAULT WARS
	Constructs high-fidelity, bespoke cyber-industrial models directly in code:
	- Industrial Conveyor Mint Press with working hydraulic pistons & steam vents.
	- Multi-tier Heavy Vault Door with spinning cog wheel & sliding pneumatic bolts.
	- 6 Sculpted 3D Relics (Ingot Pyramid, Gimbal Matrix, Crystal Skull, Astrolabe, Celestial Crown).
	- Detailed Tactical Weapons (Tesla Stun Baton, EMP Scanner).
	Located in: ReplicatedStorage.Shared.ModelEngine
]]

local Workspace = game:GetService("Workspace")

local ModelEngine = {}

local function createPart(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, parent: Instance, canCollide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CanCollide = (canCollide == true)
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

local function createWedge(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, parent: Instance): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = mat
	w.Anchored = true
	w.CanCollide = false
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

-- ============================================================
-- 1. INDUSTRIAL CONVEYOR MINT STAMPING PRESS
-- ============================================================
function ModelEngine.CreateMintMachine(parent: Instance, baseCF: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "IndustrialMintMachine"
	model.Parent = parent

	-- 1.1. Heavy Machine Base & Trusses
	local chassis = createPart("BaseChassis", Vector3.new(6.8, 1.2, 28), baseCF * CFrame.new(0, 0.6, 0), Color3.fromRGB(24, 24, 32), Enum.Material.Metal, model, true)
	model.PrimaryPart = chassis

	-- Footing Pads
	for _, zOffset in { -13, 0, 13 } do
		createPart("FootPadL", Vector3.new(1.2, 0.4, 2.4), baseCF * CFrame.new(-3.4, 0.2, zOffset), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, model)
		createPart("FootPadR", Vector3.new(1.2, 0.4, 2.4), baseCF * CFrame.new(3.4, 0.2, zOffset), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, model)
	end

	-- 1.2. Conveyor Belt Table & Rollers
	local belt = createPart("ConveyorBelt", Vector3.new(5.0, 0.4, 26.8), baseCF * CFrame.new(0, 1.4, 0), Color3.fromRGB(18, 18, 22), Enum.Material.Slate, model, true)
	
	-- End Rollers (Cylinders)
	createCylinder("RollerFront", Vector3.new(0.8, 5.2, 0.8), baseCF * CFrame.new(0, 1.4, -13.4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, model)
	createCylinder("RollerBack", Vector3.new(0.8, 5.2, 0.8), baseCF * CFrame.new(0, 1.4, 13.4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, model)

	-- Polished Steel Guide Rails
	createPart("GuideRailL", Vector3.new(0.4, 0.8, 27.2), baseCF * CFrame.new(-2.7, 1.8, 0), Color3.fromRGB(71, 85, 105), Enum.Material.Metal, model)
	createPart("GuideRailR", Vector3.new(0.4, 0.8, 27.2), baseCF * CFrame.new(2.7, 1.8, 0), Color3.fromRGB(71, 85, 105), Enum.Material.Metal, model)

	-- 1.3. Overhead Stamping Gantry & Hydraulic Press
	local gantryL = createPart("GantryPillarL", Vector3.new(1.4, 9.0, 2.2), baseCF * CFrame.new(-3.6, 5.2, 4), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, model)
	local gantryR = createPart("GantryPillarR", Vector3.new(1.4, 9.0, 2.2), baseCF * CFrame.new(3.6, 5.2, 4), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, model)
	local gantryTop = createPart("GantryCrossbar", Vector3.new(8.6, 2.0, 3.2), baseCF * CFrame.new(0, 10.2, 4), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, model)

	-- Hydraulic Cylinders (Static sleeves)
	local cylL = createCylinder("HydraulicSleeveL", Vector3.new(4.2, 1.0, 1.0), baseCF * CFrame.new(-1.8, 8.2, 4), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, model)
	local cylR = createCylinder("HydraulicSleeveR", Vector3.new(4.2, 1.0, 1.0), baseCF * CFrame.new(1.8, 8.2, 4), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, model)

	-- Moveable Hydraulic Stamping Head
	local stampHead = createPart("StampingHead", Vector3.new(4.8, 1.6, 3.2), baseCF * CFrame.new(0, 5.8, 4), Color3.fromRGB(234, 179, 8), Enum.Material.Metal, model, true)
	-- Chrome Piston Shafts attached to head
	local rodL = createCylinder("PistonRodL", Vector3.new(3.0, 0.6, 0.6), baseCF * CFrame.new(-1.8, 7.2, 4), Color3.fromRGB(203, 213, 225), Enum.Material.Metal, model)
	local rodR = createCylinder("PistonRodR", Vector3.new(3.0, 0.6, 0.6), baseCF * CFrame.new(1.8, 7.2, 4), Color3.fromRGB(203, 213, 225), Enum.Material.Metal, model)

	-- Cooling Pipes & Copper Coils
	createPart("CopperCoil1", Vector3.new(5.0, 0.3, 0.3), baseCF * CFrame.new(0, 9.4, 2.3), Color3.fromRGB(249, 115, 22), Enum.Material.Neon, model)
	createPart("CopperCoil2", Vector3.new(5.0, 0.3, 0.3), baseCF * CFrame.new(0, 9.4, 5.7), Color3.fromRGB(249, 115, 22), Enum.Material.Neon, model)

	-- Digital Yield Monitor
	local monitor = createPart("YieldMonitor", Vector3.new(2.4, 1.4, 0.6), baseCF * CFrame.new(0, 10.6, 2.2), Color3.fromRGB(15, 17, 26), Enum.Material.Metal, model)
	local screen = createPart("MonitorScreen", Vector3.new(2.1, 1.1, 0.1), baseCF * CFrame.new(0, 10.6, 1.85), Color3.fromRGB(16, 185, 129), Enum.Material.Neon, model)

	-- Steam Vent Attachments for VFX
	local ventL = Instance.new("Attachment")
	ventL.Name = "SteamVentL"
	ventL.Position = Vector3.new(-2.2, 0, 0)
	ventL.Parent = stampHead

	local ventR = Instance.new("Attachment")
	ventR.Name = "SteamVentR"
	ventR.Position = Vector3.new(2.2, 0, 0)
	ventR.Parent = stampHead

	return model
end

-- ============================================================
-- 2. HEAVY BANK VAULT DOOR & LOCKING MECHANISM
-- ============================================================
function ModelEngine.CreateVaultDoor(parent: Instance, baseCF: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "HeavyBankVaultDoor"
	model.Parent = parent

	-- 2.1. Reinforced Outer Frame Arch
	local archLeft = createPart("ArchLeft", Vector3.new(2.4, 15.0, 3.6), baseCF * CFrame.new(-7.2, 7.5, 0), Color3.fromRGB(24, 24, 32), Enum.Material.Concrete, model, true)
	local archRight = createPart("ArchRight", Vector3.new(2.4, 15.0, 3.6), baseCF * CFrame.new(7.2, 7.5, 0), Color3.fromRGB(24, 24, 32), Enum.Material.Concrete, model, true)
	local archTop = createPart("ArchTop", Vector3.new(16.8, 2.6, 3.6), baseCF * CFrame.new(0, 15.3, 0), Color3.fromRGB(24, 24, 32), Enum.Material.Concrete, model, true)
	local archThreshold = createPart("ArchThreshold", Vector3.new(16.8, 0.8, 3.6), baseCF * CFrame.new(0, 0.4, 0), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, model, true)
	model.PrimaryPart = archTop

	-- Interlocking Bolt Receptors (Recesses in frame)
	createPart("BoltHoleL", Vector3.new(0.8, 1.2, 1.2), baseCF * CFrame.new(-6.0, 7.5, 0), Color3.fromRGB(10, 10, 12), Enum.Material.Metal, model)
	createPart("BoltHoleR", Vector3.new(0.8, 1.2, 1.2), baseCF * CFrame.new(6.0, 7.5, 0), Color3.fromRGB(10, 10, 12), Enum.Material.Metal, model)

	-- 2.2. Heavy Vault Door Assembly (Circular Multi-Tiered)
	local doorPivot = createPart("DoorPivotHinge", Vector3.new(1.8, 13.0, 1.8), baseCF * CFrame.new(-5.4, 7.5, 0), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, model, true)
	
	-- Main Circular Door Slab
	local doorSlab = createCylinder("DoorSlab", Vector3.new(1.8, 11.4, 11.4), baseCF * CFrame.new(0, 7.5, -0.4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, model, true)

	-- Gold/Brass Flange Rim
	local rim = createCylinder("DoorRim", Vector3.new(2.0, 12.0, 12.0), baseCF * CFrame.new(0, 7.5, -0.4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(234, 179, 8), Enum.Material.Metal, model)

	-- Inner Armor Hub
	local hub = createCylinder("DoorHub", Vector3.new(2.4, 6.2, 6.2), baseCF * CFrame.new(0, 7.5, -0.6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, model)

	-- 2.3. Working 6-Spoke Brass Cog Wheel
	local wheel = createCylinder("CogWheelCenter", Vector3.new(1.4, 3.2, 3.2), baseCF * CFrame.new(0, 7.5, -1.8) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(245, 158, 11), Enum.Material.Metal, model)
	for i = 1, 6 do
		local angle = (i / 6) * (math.pi * 2)
		local spokeDir = Vector3.new(math.cos(angle), math.sin(angle), 0)
		createPart(`CogSpoke_{i}`, Vector3.new(0.4, 2.6, 0.4), baseCF * CFrame.new(Vector3.new(0, 7.5, -1.8) + spokeDir * 2.0) * CFrame.Angles(0, 0, angle + math.rad(90)), Color3.fromRGB(245, 158, 11), Enum.Material.Metal, model)
	end

	-- 2.4. Sliding Chrome Locking Bolts (4 Directions)
	local pinL = createCylinder("LockingPinLeft", Vector3.new(0.9, 2.4, 0.9), baseCF * CFrame.new(-5.4, 7.5, -0.4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(226, 232, 240), Enum.Material.Metal, model)
	local pinR = createCylinder("LockingPinRight", Vector3.new(0.9, 2.4, 0.9), baseCF * CFrame.new(5.4, 7.5, -0.4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(226, 232, 240), Enum.Material.Metal, model)
	local pinT = createCylinder("LockingPinTop", Vector3.new(2.4, 0.9, 0.9), baseCF * CFrame.new(0, 12.8, -0.4), Color3.fromRGB(226, 232, 240), Enum.Material.Metal, model)
	local pinB = createCylinder("LockingPinBottom", Vector3.new(2.4, 0.9, 0.9), baseCF * CFrame.new(0, 2.2, -0.4), Color3.fromRGB(226, 232, 240), Enum.Material.Metal, model)

	-- Pressure Gauge
	local gauge = createCylinder("PressureGauge", Vector3.new(0.6, 1.8, 1.8), baseCF * CFrame.new(3.2, 9.6, -1.6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(239, 68, 68), Enum.Material.Neon, model)

	return model
end

-- ============================================================
-- 3. SCULPTED 3D RELIC ARTIFACTS
-- ============================================================
function ModelEngine.CreateRelicModel(relicId: string, customCF: CFrame?): Model
	local cf = customCF or CFrame.new()
	local model = Instance.new("Model")
	model.Name = `Relic_{relicId}`

	-- 3.1. GOLD INGOT PYRAMID (Common)
	if relicId == "GoldStack" then
		local basePad = createPart("BasePad", Vector3.new(2.4, 0.2, 2.0), cf * CFrame.new(0, 0.1, 0), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, model)
		model.PrimaryPart = basePad

		-- Bottom row (3 ingots)
		for idx, xOff in { -0.7, 0, 0.7 } do
			local bar = createPart(`Ingot_B_{idx}`, Vector3.new(0.6, 0.45, 1.8), cf * CFrame.new(xOff, 0.4, 0), Color3.fromRGB(245, 158, 11), Enum.Material.SmoothPlastic, model)
			bar.Reflectance = 0.25
		end
		-- Middle row (2 ingots)
		for idx, xOff in { -0.35, 0.35 } do
			local bar = createPart(`Ingot_M_{idx}`, Vector3.new(0.6, 0.45, 1.7), cf * CFrame.new(xOff, 0.85, 0), Color3.fromRGB(250, 204, 21), Enum.Material.SmoothPlastic, model)
			bar.Reflectance = 0.3
		end
		-- Top ingot (1 ingot)
		local topBar = createPart("Ingot_Top", Vector3.new(0.6, 0.45, 1.6), cf * CFrame.new(0, 1.3, 0), Color3.fromRGB(253, 224, 71), Enum.Material.SmoothPlastic, model)
		topBar.Reflectance = 0.4

	-- 3.2. EMERALD GIMBAL MATRIX (Rare)
	elseif relicId == "EmeraldMatrix" then
		local core = createPart("EmeraldCore", Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0), Color3.fromRGB(16, 185, 129), Enum.Material.Neon, model)
		model.PrimaryPart = core

		-- Outer Gimbal Ring
		local outerRing = createCylinder("OuterGimbal", Vector3.new(0.2, 2.6, 2.6), cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, model)
		-- Inner Gimbal Ring
		local innerRing = createCylinder("InnerGimbal", Vector3.new(0.2, 2.0, 2.0), cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(110, 231, 183), Enum.Material.Neon, model)

	-- 3.3. RUBY SKULL ARTIFACT (Epic)
	elseif relicId == "RubyArtifact" then
		-- Cranium
		local cranium = createPart("RubyCranium", Vector3.new(1.8, 1.6, 1.8), cf * CFrame.new(0, 1.6, 0), Color3.fromRGB(225, 29, 72), Enum.Material.Neon, model)
		model.PrimaryPart = cranium
		-- Jaw
		createPart("RubyJaw", Vector3.new(1.2, 0.8, 1.2), cf * CFrame.new(0, 0.6, -0.2), Color3.fromRGB(190, 18, 60), Enum.Material.Neon, model)
		-- Glowing Crimson Eye Sockets
		createPart("EyeL", Vector3.new(0.4, 0.4, 0.2), cf * CFrame.new(-0.45, 1.4, -0.92), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, model)
		createPart("EyeR", Vector3.new(0.4, 0.4, 0.2), cf * CFrame.new(0.45, 1.4, -0.92), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, model)

	-- 3.4. DIAMOND CHRONO SKULL (Legendary)
	elseif relicId == "DiamondSkull" then
		local cranium = createPart("DiamondCranium", Vector3.new(1.9, 1.7, 1.9), cf * CFrame.new(0, 1.6, 0), Color3.fromRGB(56, 189, 248), Enum.Material.Glass, model)
		cranium.Transparency = 0.2
		model.PrimaryPart = cranium

		createPart("DiamondJaw", Vector3.new(1.3, 0.8, 1.3), cf * CFrame.new(0, 0.6, -0.2), Color3.fromRGB(56, 189, 248), Enum.Material.Glass, model)
		-- Interior Golden Clockwork Gears
		local gear = createCylinder("InternalGear", Vector3.new(0.3, 1.2, 1.2), cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(250, 204, 21), Enum.Material.Metal, model)

	-- 3.5. VOID EYE CHRONOMETER (Mythic)
	elseif relicId == "VoidChronometer" then
		-- Dark Matter Singularity Core
		local core = createPart("VoidCore", Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(0, 1.5, 0), Color3.fromRGB(15, 23, 42), Enum.Material.Neon, model)
		model.PrimaryPart = core

		-- 3 Intersecting Orbital Astrolabe Rings
		createCylinder("OrbitRing1", Vector3.new(0.18, 2.8, 2.8), cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0), Color3.fromRGB(168, 85, 247), Enum.Material.Neon, model)
		createCylinder("OrbitRing2", Vector3.new(0.18, 2.5, 2.5), cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(-math.rad(45), math.rad(45), 0), Color3.fromRGB(192, 132, 252), Enum.Material.Neon, model)
		createCylinder("OrbitRing3", Vector3.new(0.18, 2.2, 2.2), cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(216, 180, 254), Enum.Material.Neon, model)

	-- 3.6. CELESTIAL ARCHON CROWN (Secret Jackpot)
	else
		-- 8-Pointed Golden Circlet Base
		local circlet = createCylinder("CrownBase", Vector3.new(0.8, 2.4, 2.4), cf * CFrame.new(0, 0.6, 0), Color3.fromRGB(234, 179, 8), Enum.Material.Metal, model)
		model.PrimaryPart = circlet

		-- 8 Crown Spikes with Solar Shards
		for i = 1, 8 do
			local angle = (i / 8) * (math.pi * 2)
			local spikePos = Vector3.new(math.cos(angle) * 1.15, 1.3, math.sin(angle) * 1.15)
			createPart(`Spike_{i}`, Vector3.new(0.25, 1.1, 0.25), cf * CFrame.new(spikePos), Color3.fromRGB(250, 204, 21), Enum.Material.Metal, model)
			-- Levitating Solar Diamond Shards
			createPart(`SolarShard_{i}`, Vector3.new(0.35, 0.35, 0.35), cf * CFrame.new(spikePos + Vector3.new(0, 0.7, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color3.fromRGB(254, 240, 138), Enum.Material.Neon, model)
		end

		-- Levitating Golden Solar Halo
		createCylinder("SolarHalo", Vector3.new(0.15, 3.2, 3.2), cf * CFrame.new(0, 2.4, 0), Color3.fromRGB(253, 224, 71), Enum.Material.Neon, model)
	end

	return model
end

-- ============================================================
-- 4. TACTICAL PHYSICAL WEAPONS
-- ============================================================
function ModelEngine.CreateBatonModel(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "⚡ Stun Baton"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = createPart("Handle", Vector3.new(0.4, 3.4, 0.4), CFrame.new(0, 0, 0), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, tool, false)
	-- Grip Ribs
	for idx, yOff in { -1.0, -0.6, -0.2 } do
		createCylinder(`GripRib_{idx}`, Vector3.new(0.2, 0.52, 0.52), CFrame.new(0, yOff, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(15, 23, 42), Enum.Material.Slate, tool)
	end
	-- Tesla Coils at tip
	local coil1 = createCylinder("TeslaCoil1", Vector3.new(0.25, 0.75, 0.75), CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(249, 115, 22), Enum.Material.Neon, tool)
	local coil2 = createCylinder("TeslaCoil2", Vector3.new(0.25, 0.75, 0.75), CFrame.new(0, 1.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(249, 115, 22), Enum.Material.Neon, tool)
	-- Emitter Tip
	local tip = createPart("BatonTip", Vector3.new(0.65, 0.6, 0.65), CFrame.new(0, 1.8, 0), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, tool, false)

	return tool
end

function ModelEngine.CreateJammerModel(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "📡 EMP Jammer"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = createPart("Handle", Vector3.new(0.8, 1.8, 0.6), CFrame.new(0, 0, 0), Color3.fromRGB(24, 24, 27), Enum.Material.Metal, tool, false)
	-- Illuminated Scanner Screen
	createPart("JammerScreen", Vector3.new(0.65, 0.7, 0.1), CFrame.new(0, 0.2, -0.32), Color3.fromRGB(16, 185, 129), Enum.Material.Neon, tool, false)
	-- Folding Parabolic Dish
	createCylinder("JammerDish", Vector3.new(0.25, 1.8, 1.8), CFrame.new(0, 1.3, 0) * CFrame.Angles(math.rad(30), 0, 0), Color3.fromRGB(245, 158, 11), Enum.Material.Neon, tool, false)
	-- Antenna Needle
	createPart("AntennaNeedle", Vector3.new(0.12, 1.2, 0.12), CFrame.new(0, 1.8, -0.3), Color3.fromRGB(226, 232, 240), Enum.Material.Metal, tool, false)

	return tool
end

-- ============================================================
-- 5. DYNAMIC 3D TACTICAL LOOT SACK
-- ============================================================
function ModelEngine.CreateLootSack(parent: Instance, cf: CFrame, tier: string): Model
	local model = Instance.new("Model")
	model.Name = "DynamicLootSack"
	model.Parent = parent

	local tierColors: { [string]: Color3 } = {
		Common = Color3.fromRGB(245, 158, 11),
		Rare = Color3.fromRGB(16, 185, 129),
		Epic = Color3.fromRGB(239, 68, 68),
		Legendary = Color3.fromRGB(56, 189, 248),
		Mythic = Color3.fromRGB(168, 85, 247),
		Secret = Color3.fromRGB(250, 204, 21),
	}
	local accent = tierColors[tier] or Color3.fromRGB(245, 158, 11)

	-- Main Duffle Body
	local body = createPart("SackBody", Vector3.new(2.4, 2.8, 1.5), cf, Color3.fromRGB(24, 24, 27), Enum.Material.SmoothPlastic, model, false)
	body.Massless = true
	model.PrimaryPart = body

	-- Webbing Straps (Horizontal & Vertical)
	createPart("StrapHoriz", Vector3.new(2.45, 0.35, 1.55), cf, Color3.fromRGB(39, 39, 42), Enum.Material.Fabric, model, false)
	createPart("StrapVert", Vector3.new(0.35, 2.85, 1.55), cf, Color3.fromRGB(39, 39, 42), Enum.Material.Fabric, model, false)

	-- Glowing Cyber Trim Seams
	createPart("NeonTrimLeft", Vector3.new(0.12, 2.6, 0.12), cf * CFrame.new(-1.15, 0, 0.72), accent, Enum.Material.Neon, model, false)
	createPart("NeonTrimRight", Vector3.new(0.12, 2.6, 0.12), cf * CFrame.new(1.15, 0, 0.72), accent, Enum.Material.Neon, model, false)

	-- Cyber Padlock Buckle
	local lock = createPart("CyberLock", Vector3.new(0.65, 0.65, 0.35), cf * CFrame.new(0, 0.4, 0.8), Color3.fromRGB(203, 213, 225), Enum.Material.Metal, model, false)
	createPart("LockLed", Vector3.new(0.2, 0.2, 0.1), cf * CFrame.new(0, 0.4, 0.98), accent, Enum.Material.Neon, model, false)

	return model
end

-- ============================================================
-- 6. PHYSICAL HYDRAULIC FLOOR SWITCH (SPRING BUTTON)
-- ============================================================
function ModelEngine.CreateHydraulicFloorButton(parent: Instance, baseCF: CFrame, accentColor: Color3, labelText: string): (Model, Part)
	local model = Instance.new("Model")
	model.Name = "HydraulicFloorButton"
	model.Parent = parent

	-- Heavy Outer Cast-Iron Chassis
	local chassis = createPart("Chassis", Vector3.new(6.4, 0.6, 6.4), baseCF * CFrame.new(0, 0.3, 0), Color3.fromRGB(30, 41, 59), Enum.Material.DiamondPlate, model, true)
	model.PrimaryPart = chassis

	-- 4 Corner Industrial Bolt Rivets
	for _, xOff in { -2.7, 2.7 } do
		for _, zOff in { -2.7, 2.7 } do
			createCylinder(`Bolt_{xOff}_{zOff}`, Vector3.new(0.2, 0.4, 0.4), baseCF * CFrame.new(xOff, 0.65, zOff) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(100, 116, 139), Enum.Material.Metal, model)
		end
	end

	-- Recessed Inner Channel Rim
	createPart("InnerRim", Vector3.new(5.0, 0.3, 5.0), baseCF * CFrame.new(0, 0.45, 0), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, model, false)

	-- Spring-Loaded Mechanical Plunger Plate (Starts raised +0.35 studs)
	local plunger = createPart("PlungerPlate", Vector3.new(4.5, 0.5, 4.5), baseCF * CFrame.new(0, 0.75, 0), Color3.fromRGB(24, 24, 27), Enum.Material.Metal, model, true)
	plunger:SetAttribute("RestY", (baseCF * CFrame.new(0, 0.75, 0)).Position.Y)
	plunger:SetAttribute("DownY", (baseCF * CFrame.new(0, 0.35, 0)).Position.Y)

	-- Neon Glowing Pressure Ring on Plunger
	createPart("PlungerNeonRing", Vector3.new(4.2, 0.1, 4.2), baseCF * CFrame.new(0, 0.98, 0), accentColor, Enum.Material.Neon, model, false)

	-- SurfaceGui with Crisp Label
	local sGui = Instance.new("SurfaceGui")
	sGui.Name = "ButtonLabelGui"
	sGui.Face = Enum.NormalId.Top
	sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sGui.PixelsPerStud = 50
	sGui.Parent = plunger

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = accentColor
	lbl.TextSize = 22
	lbl.Font = Enum.Font.GothamBlack
	lbl.Parent = sGui

	return model, plunger
end

-- ============================================================
-- 7. TACTICAL BIOMETRIC SECURITY TERMINAL
-- ============================================================
function ModelEngine.CreateBiometricTerminal(parent: Instance, baseCF: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "BiometricSecurityTerminal"
	model.Parent = parent

	-- Base Steel Footing
	local foot = createPart("PedestalBase", Vector3.new(1.8, 0.3, 1.8), baseCF * CFrame.new(0, 0.15, 0), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, model, true)
	model.PrimaryPart = foot

	-- Vertical Conduit Pedestal
	createPart("Pillar", Vector3.new(0.6, 3.4, 0.6), baseCF * CFrame.new(0, 1.9, 0), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, model, true)

	-- Angled Console Head
	local consoleHead = createPart("ConsoleHead", Vector3.new(1.4, 0.4, 1.2), baseCF * CFrame.new(0, 3.6, -0.2) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(24, 24, 27), Enum.Material.Metal, model, true)

	-- Illuminated Handprint Glass Prism
	createPart("BiometricPad", Vector3.new(0.9, 0.1, 0.8), consoleHead.CFrame * CFrame.new(0, 0.22, 0), Color3.fromRGB(56, 189, 248), Enum.Material.Neon, model, false)

	-- Status Indicator LED
	createPart("StatusLED", Vector3.new(0.25, 0.15, 0.25), consoleHead.CFrame * CFrame.new(0, 0.22, -0.48), Color3.fromRGB(16, 185, 129), Enum.Material.Neon, model, false)

	return model
end

-- ============================================================
-- 8. AUTOMATED BASE DEFENSE TURRET
-- ============================================================
function ModelEngine.CreateSecurityTurret(parent: Instance, baseCF: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "AutomatedSecurityTurret"
	model.Parent = parent

	-- Ceiling/Wall Mount Base Plate
	local mount = createPart("MountPlate", Vector3.new(2.4, 0.4, 2.4), baseCF, Color3.fromRGB(30, 41, 59), Enum.Material.Metal, model, true)
	model.PrimaryPart = mount

	-- Swivel Gimbal Joint (Base Pivot)
	createCylinder("GimbalJoint", Vector3.new(0.8, 1.2, 1.2), baseCF * CFrame.new(0, -0.6, 0), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, model, true)

	-- Articulated Turret Head (Sub-model that swivels)
	local headModel = Instance.new("Model")
	headModel.Name = "TurretHead"
	headModel.Parent = model

	local podCF = baseCF * CFrame.new(0, -1.3, 0)
	local pod = createPart("WeaponPod", Vector3.new(1.6, 1.2, 2.4), podCF, Color3.fromRGB(15, 23, 42), Enum.Material.Metal, headModel, false)
	pod.Anchored = true
	headModel.PrimaryPart = pod
	headModel:SetAttribute("RestCF", podCF)

	-- Dual Motorized Barrels (Welded to Pod)
	local bLeft = createCylinder("BarrelLeft", Vector3.new(1.8, 0.35, 0.35), podCF * CFrame.new(-0.45, 0, -1.8) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(71, 85, 105), Enum.Material.Metal, headModel, false)
	bLeft.Anchored = false
	local wLeft = Instance.new("WeldConstraint")
	wLeft.Part0 = pod
	wLeft.Part1 = bLeft
	wLeft.Parent = pod

	local bRight = createCylinder("BarrelRight", Vector3.new(1.8, 0.35, 0.35), podCF * CFrame.new(0.45, 0, -1.8) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(71, 85, 105), Enum.Material.Metal, headModel, false)
	bRight.Anchored = false
	local wRight = Instance.new("WeldConstraint")
	wRight.Part0 = pod
	wRight.Part1 = bRight
	wRight.Parent = pod

	-- Ammo Drum Feed (Welded to Pod)
	local drum = createCylinder("AmmoDrum", Vector3.new(0.8, 1.4, 1.4), podCF * CFrame.new(0, 0.4, 0.6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(245, 158, 11), Enum.Material.Metal, headModel, false)
	drum.Anchored = false
	local wDrum = Instance.new("WeldConstraint")
	wDrum.Part0 = pod
	wDrum.Part1 = drum
	wDrum.Parent = pod

	-- Red Targeting Laser Beam emitter
	local laserSight = createPart("LaserSight", Vector3.new(0.25, 0.25, 0.35), podCF * CFrame.new(0, -0.4, -1.2), Color3.fromRGB(239, 68, 68), Enum.Material.Neon, headModel, false)
	laserSight.Anchored = false
	local wSight = Instance.new("WeldConstraint")
	wSight.Part0 = pod
	wSight.Part1 = laserSight
	wSight.Parent = pod

	-- Laser Sight Attachment
	local laserAtt = Instance.new("Attachment")
	laserAtt.Name = "LaserAttachment"
	laserAtt.Position = Vector3.new(0, 0, -0.2)
	laserAtt.Parent = laserSight

	-- Muzzle Flash Attachment
	local muzzleAtt = Instance.new("Attachment")
	muzzleAtt.Name = "MuzzleAttachment"
	muzzleAtt.Position = Vector3.new(0, 0, -1.0)
	muzzleAtt.Parent = bLeft

	return model
end

-- ============================================================
-- 9. SYNDICATE PLAZA KIOSK (BLACK MARKET BROKER)
-- ============================================================
function ModelEngine.CreateSyndicateKiosk(parent: Instance, baseCF: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "SyndicatePlazaKiosk"
	model.Parent = parent

	-- Heavy Floor Slab
	local floor = createPart("KioskFloor", Vector3.new(12, 0.6, 10), baseCF * CFrame.new(0, 0.3, 0), Color3.fromRGB(15, 17, 26), Enum.Material.DiamondPlate, model, true)
	model.PrimaryPart = floor

	-- Industrial Counter Desk
	createPart("FrontCounter", Vector3.new(9, 3.4, 1.6), baseCF * CFrame.new(0, 2.0, 3.2), Color3.fromRGB(24, 24, 32), Enum.Material.Metal, model, true)
	createPart("CounterTrim", Vector3.new(9.2, 0.25, 1.8), baseCF * CFrame.new(0, 3.75, 3.2), Color3.fromRGB(245, 158, 11), Enum.Material.Neon, model, false)

	-- 4 Steel Canopy Pillars
	for _, xOff in { -5.2, 5.2 } do
		for _, zOff in { -4.2, 4.2 } do
			createPart(`CanopyPillar_{xOff}_{zOff}`, Vector3.new(0.6, 9.0, 0.6), baseCF * CFrame.new(xOff, 4.8, zOff), Color3.fromRGB(30, 41, 59), Enum.Material.Metal, model, true)
		end
	end

	-- Angled Cyber Roof Canopy
	createPart("RoofSlab", Vector3.new(13.4, 0.5, 11.4), baseCF * CFrame.new(0, 9.4, 0) * CFrame.Angles(math.rad(-6), 0, 0), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, model, true)

	-- Neon Syndicate Overhead Sign
	local sign = createPart("SyndicateSign", Vector3.new(7.5, 1.4, 0.3), baseCF * CFrame.new(0, 8.6, 5.4), Color3.fromRGB(11, 13, 20), Enum.Material.Metal, model, true)
	local sGui = Instance.new("SurfaceGui")
	sGui.Face = Enum.NormalId.Front
	sGui.PixelsPerStud = 50
	sGui.Parent = sign
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "⚡ SYNDICATE BLACK MARKET ⚡"
	lbl.TextColor3 = Color3.fromRGB(250, 204, 21)
	lbl.TextSize = 22
	lbl.Font = Enum.Font.GothamBlack
	lbl.Parent = sGui

	return model
end

-- ============================================================
-- 10. IN-WORLD PHYSICAL TYCOON UPGRADE CONSOLE
-- ============================================================
function ModelEngine.CreateUpgradeConsole(
	parent: Instance,
	baseCF: CFrame,
	upgradeType: string,
	title: string,
	accentColor: Color3
): (Model, Part, BillboardGui)
	local model = Instance.new("Model")
	model.Name = `UpgradeConsole_{upgradeType}`
	model.Parent = parent

	-- 10.1. Heavy Diamond-Plate Base Plinth
	local basePlinth = createPart("ConsoleBase", Vector3.new(3.8, 0.4, 3.4), baseCF * CFrame.new(0, 0.2, 0), Color3.fromRGB(30, 41, 59), Enum.Material.DiamondPlate, model, true)
	model.PrimaryPart = basePlinth

	-- Corner Fasteners
	for _, xOff in { -1.6, 1.6 } do
		for _, zOff in { -1.4, 1.4 } do
			createCylinder(`Fastener_{xOff}_{zOff}`, Vector3.new(0.2, 0.3, 0.3), baseCF * CFrame.new(xOff, 0.45, zOff) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(100, 116, 139), Enum.Material.Metal, model)
		end
	end

	-- 10.2. Angled Steel Pedestal Column
	createPart("PedestalColumn", Vector3.new(1.4, 2.8, 1.4), baseCF * CFrame.new(0, 1.6, 0.2), Color3.fromRGB(15, 23, 42), Enum.Material.Metal, model, true)

	-- 10.3. Angled Control Dashboard Head
	local dashHead = createPart("ControlDash", Vector3.new(2.8, 0.4, 2.2), baseCF * CFrame.new(0, 3.1, -0.1) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(24, 24, 32), Enum.Material.Metal, model, true)

	-- Trim Accent Line
	createPart("DashTrim", Vector3.new(2.9, 0.1, 0.1), dashHead.CFrame * CFrame.new(0, 0.22, 1.0), accentColor, Enum.Material.Neon, model, false)

	-- 10.4. Clickable Mechanical Spring-Loaded Push Button
	local btnPlate = createPart("PlungerButton", Vector3.new(1.6, 0.35, 1.2), dashHead.CFrame * CFrame.new(0, 0.25, 0), Color3.fromRGB(15, 17, 26), Enum.Material.SmoothPlastic, model, true)
	btnPlate:SetAttribute("RestCF", btnPlate.CFrame)
	btnPlate:SetAttribute("DownCF", btnPlate.CFrame * CFrame.new(0, -0.22, 0))
	btnPlate:SetAttribute("UpgradeType", upgradeType)

	createPart("PlungerNeonCore", Vector3.new(1.3, 0.08, 0.9), btnPlate.CFrame * CFrame.new(0, 0.18, 0), accentColor, Enum.Material.Neon, model, false)

	-- ClickDetector for direct mouse/tap clicks from a distance
	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = 16
	cd.Parent = btnPlate

	-- 10.5. Floating 3D Holographic Stats Billboard
	local bGui = Instance.new("BillboardGui")
	bGui.Name = "ConsoleBillboard"
	bGui.Size = UDim2.new(0, 240, 0, 110)
	bGui.StudsOffset = Vector3.new(0, 2.8, 0)
	bGui.AlwaysOnTop = true
	bGui.Parent = dashHead

	local card = Instance.new("Frame")
	card.Name = "HoloCard"
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(11, 13, 20)
	card.BackgroundTransparency = 0.15
	card.Parent = bGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 1.5
	stroke.Parent = card

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "TitleLabel"
	titleLbl.Size = UDim2.new(1, -12, 0, 24)
	titleLbl.Position = UDim2.new(0, 6, 0, 6)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = title
	titleLbl.TextColor3 = accentColor
	titleLbl.TextSize = 13
	titleLbl.Font = Enum.Font.GothamBlack
	titleLbl.TextXAlignment = Enum.TextXAlignment.Center
	titleLbl.Parent = card

	local statLbl = Instance.new("TextLabel")
	statLbl.Name = "StatLabel"
	statLbl.Size = UDim2.new(1, -12, 0, 22)
	statLbl.Position = UDim2.new(0, 6, 0, 32)
	statLbl.BackgroundTransparency = 1
	statLbl.Text = "Level 1"
	statLbl.TextColor3 = Color3.fromRGB(226, 232, 240)
	statLbl.TextSize = 12
	statLbl.Font = Enum.Font.GothamBold
	statLbl.TextXAlignment = Enum.TextXAlignment.Center
	statLbl.Parent = card

	local costLbl = Instance.new("TextLabel")
	costLbl.Name = "CostLabel"
	costLbl.Size = UDim2.new(1, -12, 0, 22)
	costLbl.Position = UDim2.new(0, 6, 0, 56)
	costLbl.BackgroundTransparency = 1
	costLbl.Text = "Cost: $50"
	costLbl.TextColor3 = Color3.fromRGB(250, 204, 21)
	costLbl.TextSize = 13
	costLbl.Font = Enum.Font.GothamBlack
	costLbl.TextXAlignment = Enum.TextXAlignment.Center
	costLbl.Parent = card

	local promptLbl = Instance.new("TextLabel")
	promptLbl.Name = "PromptLabel"
	promptLbl.Size = UDim2.new(1, -12, 0, 20)
	promptLbl.Position = UDim2.new(0, 6, 0, 82)
	promptLbl.BackgroundTransparency = 1
	promptLbl.Text = "[CLICK / STEP TO UPGRADE]"
	promptLbl.TextColor3 = Color3.fromRGB(148, 163, 184)
	promptLbl.TextSize = 10
	promptLbl.Font = Enum.Font.Gotham
	promptLbl.TextXAlignment = Enum.TextXAlignment.Center
	promptLbl.Parent = card

	return model, btnPlate, bGui
end

-- ============================================================
-- 11. CYBERNETIC SYNDICATE BROKER NPC
-- ============================================================
function ModelEngine.CreateSyndicateBrokerNPC(parent: Instance, baseCF: CFrame): Model
	local npc = Instance.new("Model")
	npc.Name = "SyndicateBrokerNPC"
	npc.Parent = parent

	-- Torso (Armored Syndicate Vest)
	local torso = createPart("Torso", Vector3.new(2.0, 2.2, 1.0), baseCF * CFrame.new(0, 3.2, 0), Color3.fromRGB(24, 24, 32), Enum.Material.Metal, npc, true)
	npc.PrimaryPart = torso

	-- Cybernetic Spine Conduit
	createPart("SpineConduit", Vector3.new(0.4, 2.0, 0.3), torso.CFrame * CFrame.new(0, 0, 0.55), Color3.fromRGB(245, 158, 11), Enum.Material.Neon, npc, false)

	-- Head with Glowing Cyber Visor
	local head = createPart("Head", Vector3.new(1.2, 1.2, 1.2), torso.CFrame * CFrame.new(0, 1.7, 0), Color3.fromRGB(39, 39, 42), Enum.Material.SmoothPlastic, npc, true)
	-- Glowing Amber Visor Lens
	createPart("VisorLens", Vector3.new(1.0, 0.35, 0.3), head.CFrame * CFrame.new(0, 0.15, -0.55), Color3.fromRGB(245, 158, 11), Enum.Material.Neon, npc, false)

	-- Left Arm (Tactile cyber prosthetic)
	createPart("ArmL", Vector3.new(0.8, 2.0, 0.8), torso.CFrame * CFrame.new(-1.45, 0, 0), Color3.fromRGB(51, 65, 85), Enum.Material.Metal, npc, true)
	-- Right Arm (Black coat sleeve)
	createPart("ArmR", Vector3.new(0.8, 2.0, 0.8), torso.CFrame * CFrame.new(1.45, 0, 0), Color3.fromRGB(15, 23, 42), Enum.Material.Fabric, npc, true)

	-- Overhead Holographic Billboard
	local bGui = Instance.new("BillboardGui")
	bGui.Name = "BrokerBillboard"
	bGui.Size = UDim2.new(0, 220, 0, 52)
	bGui.StudsOffset = Vector3.new(0, 2.6, 0)
	bGui.AlwaysOnTop = true
	bGui.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "⚡ SYNDICATE BROKER ⚡\n[DAILY HEIST CONTRACTS]"
	lbl.TextColor3 = Color3.fromRGB(250, 204, 21)
	lbl.TextSize = 13
	lbl.Font = Enum.Font.GothamBlack
	lbl.Parent = bGui

	-- Proximity Prompt for interaction
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Syndicate Broker"
	prompt.ActionText = "View Daily Contracts"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso

	return npc
end

-- ============================================================
-- 12. FORTIFIED CYBER-VAULT BUNKER SHELL
-- ============================================================
function ModelEngine.CreateBunkerShell(
	parent: Instance,
	baseCF: CFrame,
	plotWidth: number,
	plotLength: number,
	wallHeight: number
): Model
	local model = Instance.new("Model")
	model.Name = "FortifiedBunkerShell"
	model.Parent = parent

	-- 12.1. Left Armored Wall Complex
	local leftCore = createPart(
		"LeftWallCore",
		Vector3.new(2.4, wallHeight, plotLength),
		baseCF * CFrame.new(-plotWidth / 2, wallHeight / 2, 0),
		Color3.fromRGB(71, 85, 105),
		Enum.Material.Slate,
		model,
		true
	)
	model.PrimaryPart = leftCore

	-- Beveled Base Skirt (DiamondPlate)
	createPart(
		"LeftWallSkirt",
		Vector3.new(3.2, 2.2, plotLength),
		baseCF * CFrame.new(-plotWidth / 2, 1.1, 0),
		Color3.fromRGB(47, 55, 70),
		Enum.Material.DiamondPlate,
		model,
		true
	)

	-- Exterior Pilasters / Vertical Armor Ribs (3 on left)
	for _, zRel in { -plotLength * 0.32, 0, plotLength * 0.32 } do
		createPart(
			"LeftRib",
			Vector3.new(1.4, wallHeight + 1.2, 4.5),
			baseCF * CFrame.new(-plotWidth / 2 - 1.2, (wallHeight + 1.2) / 2, zRel),
			Color3.fromRGB(38, 46, 60),
			Enum.Material.Metal,
			model,
			true
		)
		-- Glowing Status Conduit on Rib
		createPart(
			"LeftRibGlow",
			Vector3.new(0.3, wallHeight - 2, 0.6),
			baseCF * CFrame.new(-plotWidth / 2 - 1.9, wallHeight / 2, zRel),
			Color3.fromRGB(56, 189, 248),
			Enum.Material.Neon,
			model,
			false
		)
	end

	-- Horizontal Cyber Inlay Conduit
	createPart(
		"LeftConduit",
		Vector3.new(0.4, 0.6, plotLength - 4),
		baseCF * CFrame.new(-plotWidth / 2 - 1.3, 7.5, 0),
		Color3.fromRGB(56, 189, 248),
		Enum.Material.Neon,
		model,
		false
	)

	-- 12.2. Right Armored Wall Complex
	local rightCore = createPart(
		"RightWallCore",
		Vector3.new(2.4, wallHeight, plotLength),
		baseCF * CFrame.new(plotWidth / 2, wallHeight / 2, 0),
		Color3.fromRGB(71, 85, 105),
		Enum.Material.Slate,
		model,
		true
	)

	createPart(
		"RightWallSkirt",
		Vector3.new(3.2, 2.2, plotLength),
		baseCF * CFrame.new(plotWidth / 2, 1.1, 0),
		Color3.fromRGB(47, 55, 70),
		Enum.Material.DiamondPlate,
		model,
		true
	)

	for _, zRel in { -plotLength * 0.32, 0, plotLength * 0.32 } do
		createPart(
			"RightRib",
			Vector3.new(1.4, wallHeight + 1.2, 4.5),
			baseCF * CFrame.new(plotWidth / 2 + 1.2, (wallHeight + 1.2) / 2, zRel),
			Color3.fromRGB(38, 46, 60),
			Enum.Material.Metal,
			model,
			true
		)
		createPart(
			"RightRibGlow",
			Vector3.new(0.3, wallHeight - 2, 0.6),
			baseCF * CFrame.new(plotWidth / 2 + 1.9, wallHeight / 2, zRel),
			Color3.fromRGB(56, 189, 248),
			Enum.Material.Neon,
			model,
			false
		)
	end

	createPart(
		"RightConduit",
		Vector3.new(0.4, 0.6, plotLength - 4),
		baseCF * CFrame.new(plotWidth / 2 + 1.3, 7.5, 0),
		Color3.fromRGB(56, 189, 248),
		Enum.Material.Neon,
		model,
		false
	)

	-- 12.3. Rear Armored Bulkhead Wall & Recessed Alcove
	createPart(
		"BackWallCore",
		Vector3.new(plotWidth + 4, wallHeight, 3.2),
		baseCF * CFrame.new(0, wallHeight / 2, plotLength / 2),
		Color3.fromRGB(64, 75, 95),
		Enum.Material.Concrete,
		model,
		true
	)
	createPart(
		"BackWallUpperTrim",
		Vector3.new(plotWidth + 4.8, 2.2, 4.2),
		baseCF * CFrame.new(0, wallHeight + 0.6, plotLength / 2),
		Color3.fromRGB(38, 46, 60),
		Enum.Material.DiamondPlate,
		model,
		true
	)

	-- 12.4. Armored Blast Roof (Fully Encloses 100% of the bunker)
	local fullRoofLen = plotLength + 4
	createPart(
		"BlastRoofDeck",
		Vector3.new(plotWidth + 6, 2.2, fullRoofLen),
		baseCF * CFrame.new(0, wallHeight + 1.1, 0),
		Color3.fromRGB(42, 50, 66),
		Enum.Material.Metal,
		model,
		true
	)

	-- Front Airlock Entrance Cantilever Canopy (Extends forward over entrance)
	createPart(
		"EntranceCanopyOverhang",
		Vector3.new(plotWidth + 4, 1.6, 6.0),
		baseCF * CFrame.new(0, wallHeight + 0.8, -plotLength / 2 - 2),
		Color3.fromRGB(30, 36, 48),
		Enum.Material.DiamondPlate,
		model,
		true
	)

	-- Roof HVAC Industrial Fan & Duct
	local hvac = createPart(
		"RoofHVAC",
		Vector3.new(8.0, 3.2, 10.0),
		baseCF * CFrame.new(-6.0, wallHeight + 3.6, 0),
		Color3.fromRGB(15, 20, 30),
		Enum.Material.Corrugated,
		model,
		true
	)
	createCylinder(
		"HVACFanVent",
		Vector3.new(0.8, 4.8, 4.8),
		hvac.CFrame * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(56, 189, 248),
		Enum.Material.Neon,
		hvac,
		false
	)

	-- 12.5. Front Elevated Catwalk & Turret Observation Perch
	local catwalkY = wallHeight - 0.6
	local catwalkZ = -plotLength / 2 + 2.6
	-- Catwalk Base Girder
	createPart(
		"CatwalkGirder",
		Vector3.new(plotWidth + 2, 1.4, 5.6),
		baseCF * CFrame.new(0, catwalkY, catwalkZ),
		Color3.fromRGB(20, 24, 34),
		Enum.Material.DiamondPlate,
		model,
		true
	)
	-- Catwalk Safety Railing (Front)
	createPart(
		"CatwalkRailFront",
		Vector3.new(plotWidth - 2, 2.4, 0.3),
		baseCF * CFrame.new(0, catwalkY + 1.8, catwalkZ - 2.6),
		Color3.fromRGB(71, 85, 105),
		Enum.Material.Metal,
		model,
		false
	)

	-- Turret Observation Perch (Reinforced Pedestal Ring)
	createCylinder(
		"TurretPerchRing",
		Vector3.new(1.0, 6.4, 6.4),
		baseCF * CFrame.new(0, catwalkY + 0.8, catwalkZ) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(30, 41, 59),
		Enum.Material.Metal,
		model,
		true
	)

	-- Hazard Yellow Chevron Underside on Entryway
	local header = createPart(
		"GateHeaderLintel",
		Vector3.new(plotWidth - 3, 2.0, 3.2),
		baseCF * CFrame.new(0, wallHeight + 0.6, -plotLength / 2 + 1.2),
		Color3.fromRGB(245, 158, 11),
		Enum.Material.SmoothPlastic,
		model,
		true
	)

	-- LED Vault Designation Sign
	local sGui = Instance.new("SurfaceGui")
	sGui.Face = Enum.NormalId.Front
	sGui.PixelsPerStud = 50
	sGui.Parent = header
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "⚡ SECURE HEIST VAULT BASTION ⚡"
	lbl.TextColor3 = Color3.fromRGB(15, 23, 42)
	lbl.TextSize = 20
	lbl.Font = Enum.Font.GothamBlack
	lbl.Parent = sGui

	-- 12.6. FRONT AIRLOCK SECURITY PORTAL (FRAMED ENTRANCE)
	-- Left & Right Entrance Gate Concrete Pillars
	for _, xSide in { -plotWidth / 2 + 1.8, plotWidth / 2 - 1.8 } do
		createPart(
			"AirlockGatePillar",
			Vector3.new(3.6, wallHeight, 3.6),
			baseCF * CFrame.new(xSide, wallHeight / 2, -plotLength / 2 + 1.8),
			Color3.fromRGB(42, 48, 64),
			Enum.Material.Concrete,
			model,
			true
		)
		-- Vertical Status Neon on Pillar
		createPart(
			"AirlockPillarNeon",
			Vector3.new(0.3, wallHeight - 3, 0.4),
			baseCF * CFrame.new(xSide, wallHeight / 2, -plotLength / 2 - 0.1),
			Color3.fromRGB(56, 189, 248),
			Enum.Material.Neon,
			model,
			false
		)
	end

	-- Airlock Floor Threshold Warning Strip (+0.08 stud offset to eliminate Z-fighting)
	createPart(
		"AirlockThresholdPlate",
		Vector3.new(plotWidth - 8, 0.3, 3.8),
		baseCF * CFrame.new(0, 0.15, -plotLength / 2 + 1.8),
		Color3.fromRGB(245, 158, 11),
		Enum.Material.DiamondPlate,
		model,
		true
	)

	-- 12.7. 45° CHAMFERED BLAST CORNER BUTTRESSES (ELIMINATES NAKED 90° CORNERS)
	for _, xSign in { -1, 1 } do
		local cornerCF = baseCF * CFrame.new(xSign * (plotWidth / 2 - 2.5), wallHeight / 2, plotLength / 2 - 2.5) * CFrame.Angles(0, math.rad(xSign * 45), 0)
		createPart(
			"RearCornerButtress",
			Vector3.new(4.2, wallHeight, 2.2),
			cornerCF,
			Color3.fromRGB(42, 48, 64),
			Enum.Material.Concrete,
			model,
			true
		)
	end

	-- 12.8. INTERIOR ARCHITECTURAL FRAMING & DADO PLATES (+0.12 stud proud offset)
	-- Interior DiamondPlate Kickplate (Left and Right)
	createPart(
		"InteriorKickplateLeft",
		Vector3.new(0.4, 3.2, plotLength - 8),
		baseCF * CFrame.new(-plotWidth / 2 + 1.4, 1.6, 0),
		Color3.fromRGB(40, 48, 62),
		Enum.Material.DiamondPlate,
		model,
		true
	)
	createPart(
		"InteriorKickplateRight",
		Vector3.new(0.4, 3.2, plotLength - 8),
		baseCF * CFrame.new(plotWidth / 2 - 1.4, 1.6, 0),
		Color3.fromRGB(40, 48, 62),
		Enum.Material.DiamondPlate,
		model,
		true
	)

	-- Interior Structural Pilaster Columns (Every 14 studs inside)
	for _, zRel in { -plotLength * 0.22, plotLength * 0.15 } do
		for _, xSign in { -1, 1 } do
			createPart(
				"InteriorColumn",
				Vector3.new(1.2, wallHeight, 2.8),
				baseCF * CFrame.new(xSign * (plotWidth / 2 - 1.6), wallHeight / 2, zRel),
				Color3.fromRGB(30, 36, 48),
				Enum.Material.Metal,
				model,
				true
			)
			-- Micro Status LED on interior column
			createPart(
				"InteriorColLED",
				Vector3.new(0.3, 2.2, 0.4),
				baseCF * CFrame.new(xSign * (plotWidth / 2 - 2.25), wallHeight * 0.65, zRel),
				Color3.fromRGB(16, 185, 129),
				Enum.Material.Neon,
				model,
				false
			)
		end
	end

	-- 12.9. INTERIOR RECESSED SERVER BLADE ALCOVE (LEFT WALL)
	local serverAlcoveCF = baseCF * CFrame.new(-plotWidth / 2 + 1.6, 6.5, -4)
	createPart(
		"InteriorServerRack",
		Vector3.new(0.8, 8.5, 6.2),
		serverAlcoveCF,
		Color3.fromRGB(15, 17, 26),
		Enum.Material.Metal,
		model,
		true
	)
	for sIdx = -3, 3, 1.5 do
		createPart(
			`ServerBladeLED_{sIdx}`,
			Vector3.new(0.2, 0.3, 4.8),
			serverAlcoveCF * CFrame.new(0.42, sIdx, 0),
			(sIdx % 3 == 0) and Color3.fromRGB(245, 158, 11) or Color3.fromRGB(56, 189, 248),
			Enum.Material.Neon,
			model,
			false
		)
	end

	-- 12.10. INTERIOR HIGH-BAY HOODED FLOODLIGHTS
	for _, zLight in { -plotLength * 0.15, plotLength * 0.22 } do
		local interiorLightPart = createPart(
			"InteriorBunkerLamp",
			Vector3.new(2.4, 0.6, 2.4),
			baseCF * CFrame.new(0, wallHeight - 0.4, zLight),
			Color3.fromRGB(254, 240, 138),
			Enum.Material.Neon,
			model,
			false
		)
		local intPoint = Instance.new("PointLight")
		intPoint.Name = "BunkerInteriorIllumination"
		intPoint.Color = Color3.fromRGB(255, 245, 225)
		intPoint.Range = 36
		intPoint.Brightness = 2.0
		intPoint.Shadows = true
		intPoint.Parent = interiorLightPart
	end

	return model
end

return ModelEngine
