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

return ModelEngine
