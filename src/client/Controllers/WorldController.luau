--!strict
--[[
	WorldController.luau — 3D Spatial Garden & Cosmic Environment for STARWEAVE
	Detects, auto-classifies, scales, and wires all Nilo-generated 3D assets:
	  1. Floating Sanctuary Island (Celestial foundation, scaled to 72 studs)
	  2. Gardner Plant Box (3D stone planter, scaled to 7 studs, across all 9 plots)
	  3. Transmutation Altar (Interactive Forge Shrine, scaled to 8.5 studs with [E] prompt)
	  4. Cosmic Crystal Bloom (Dynamic 3D crop blooming from 1.8 to 3.4 studs)
	  5. Celestial Mystery Egg (Hovering Companion Gacha, scaled to 4 studs with [E] prompt)
	Features geometric ratio classification + node ID matching + luminous celestial lighting.
	Located in: StarterPlayerScripts.Client.Controllers.WorldController
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SeedData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeedData"))
local MutationData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MutationData"))

local SoundController: any = nil
local VFXController: any = nil

local player = Players.LocalPlayer

local WorldController = {}
WorldController._plotModels = {} :: { [number]: Model }
WorldController._plotData = {} :: { [number]: any }
WorldController._data = nil :: any
WorldController._gardenFolder = nil :: Folder?
WorldController._selectedSeedId = "starseed_basic"
WorldController._rotatingCores = {} :: { BasePart }

-- 3D Mesh Asset References
WorldController._planterTemplate = nil :: Model?
WorldController._cropTemplate = nil :: Model?
WorldController._altarModel = nil :: Model?
WorldController._eggModel = nil :: Model?
WorldController._islandModel = nil :: Model?
WorldController._eggBaseCFrame = nil :: CFrame?

local GRID_COLUMNS = 3
local PLOT_SPACING = 9.5

local SEED_COLORS: { [string]: Color3 } = {
	starseed_basic    = Color3.fromRGB(250, 204, 21),
	lunar_sprout      = Color3.fromRGB(224, 231, 255),
	solar_fern        = Color3.fromRGB(249, 115, 22),
	crystal_vine      = Color3.fromRGB(56, 189, 248),
	nebula_moss       = Color3.fromRGB(168, 85, 247),
	stellar_lotus     = Color3.fromRGB(244, 114, 182),
	aurora_dahlia     = Color3.fromRGB(52, 211, 153),
	supernova_orchid  = Color3.fromRGB(239, 68, 68),
	comet_tail_reed   = Color3.fromRGB(96, 165, 250),
	plasma_cactus     = Color3.fromRGB(251, 146, 60),
	eclipse_lily      = Color3.fromRGB(192, 132, 252),
	astral_bamboo     = Color3.fromRGB(74, 222, 128),
	quasar_bloom      = Color3.fromRGB(253, 224, 71),
	black_hole_iris   = Color3.fromRGB(99, 102, 241),
	cosmic_willow     = Color3.fromRGB(236, 72, 153),
	void_singularity  = Color3.fromRGB(248, 250, 252),
}

-- ============================================================
-- HELPER: LAZY REQUIRE UI CONTROLLER SAFELY
-- ============================================================
local function getUIController(): any?
	local controllersFolder = script.Parent
	if controllersFolder then
		local uiMod = controllersFolder:FindFirstChild("UIController")
		if uiMod and uiMod:IsA("ModuleScript") then
			local ok, res = pcall(function()
				return require(uiMod)
			end)
			if ok then return res end
		end
	end
	return nil
end

-- ============================================================
-- HELPER: GET ALL BASEPARTS IN ANY CONTAINER
-- ============================================================
local function getContainerParts(inst: Instance): { BasePart }
	local parts: { BasePart } = {}
	if inst:IsA("BasePart") then
		table.insert(parts, inst)
	end
	for _, desc in inst:GetDescendants() do
		if desc:IsA("BasePart") then
			table.insert(parts, desc)
		end
	end
	return parts
end

-- ============================================================
-- HELPER: GET ACCURATE BOUNDING BOX FROM PARTS
-- ============================================================
local function getContainerBounds(inst: Instance): (CFrame, Vector3)
	local parts = getContainerParts(inst)
	if #parts == 0 then
		return CFrame.new(), Vector3.zero
	end
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, part in parts do
		local p = part.Position
		local s = part.Size
		minX = math.min(minX, p.X - s.X / 2)
		maxX = math.max(maxX, p.X + s.X / 2)
		minY = math.min(minY, p.Y - s.Y / 2)
		maxY = math.max(maxY, p.Y + s.Y / 2)
		minZ = math.min(minZ, p.Z - s.Z / 2)
		maxZ = math.max(maxZ, p.Z + s.Z / 2)
	end
	local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
	local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
	return CFrame.new(center), size
end

-- ============================================================
-- HELPER: WRAP RAW MESHPARTS OR MODELS INTO A STANDARD MODEL
-- ============================================================
local function ensureAsModel(inst: Instance): Model
	if inst:IsA("Model") then
		if not inst.PrimaryPart then
			inst.PrimaryPart = inst:FindFirstChildWhichIsA("BasePart", true)
		end
		return inst
	elseif inst:IsA("BasePart") then
		local model = Instance.new("Model")
		model.Name = inst.Name
		model.Parent = inst.Parent
		inst.Parent = model
		model.PrimaryPart = inst
		return model
	end
	return inst:FindFirstChildWhichIsA("Model", true) or Instance.new("Model")
end

-- ============================================================
-- HELPER: ROBUST SCALE FOR MODEL
-- ============================================================
local function scaleModelToDimension(model: Model, targetMaxDim: number)
	local cf, size = getContainerBounds(model)
	local maxDim = math.max(size.X, size.Y, size.Z)
	if maxDim > 0.001 then
		local factor = targetMaxDim / maxDim
		local s = pcall(function()
			model:ScaleTo(factor)
		end)
		if not s then
			-- Fallback: scale each BasePart individually
			for _, part in getContainerParts(model) do
				pcall(function()
					part.Size = part.Size * factor
					local offset = (part.Position - cf.Position) * factor
					part.CFrame = CFrame.new(cf.Position + offset) * part.CFrame.Rotation
				end)
			end
		end
	end
end

local function anchorAllParts(inst: Instance, canCollide: boolean?)
	for _, part in getContainerParts(inst) do
		part.Anchored = true
		if canCollide ~= nil then
			part.CanCollide = canCollide
		end
	end
end

-- ============================================================
-- 3D MODEL CLASSIFIER (Node IDs + Geometric Aspect Ratios)
-- ============================================================
local function classifyModel(inst: Instance): string?
	local allNames = { inst.Name }
	for _, d in inst:GetDescendants() do
		table.insert(allNames, d.Name)
	end
	local combined = string.lower(table.concat(allNames, " "))

	-- 1. Exact Nilo glTF node ID & Keyword Match
	if string.find(combined, "agdrm0mbeo3gylxitymk") or string.find(combined, "island") or string.find(combined, "floating") then
		return "ISLAND"
	elseif string.find(combined, "ivdfl4qeemqt7ve4qcvs") or string.find(combined, "planter") or string.find(combined, "plant%-box") or string.find(combined, "plant_box") or string.find(combined, "gardner") then
		return "PLANTER"
	elseif string.find(combined, "12lquskllicosvzozjaa") or string.find(combined, "altar") or string.find(combined, "transmutation") or string.find(combined, "forge") then
		return "ALTAR"
	elseif string.find(combined, "wumxsfiy9i8durscm3vv") or string.find(combined, "bloom") or string.find(combined, "crystal%-bloom") or string.find(combined, "flower") then
		return "BLOOM"
	elseif string.find(combined, "pftfbiaqxyqqa70eng8j") or string.find(combined, "egg") or string.find(combined, "mystery") or string.find(combined, "pet") then
		return "EGG"
	end

	-- 2. Geometric Aspect Ratio Signature Match
	local _, sz = getContainerBounds(inst)
	if sz.X > 0.05 and sz.Z > 0.05 then
		local yx = sz.Y / sz.X
		local xz = sz.X / sz.Z
		if yx > 2.0 then
			return "BLOOM"
		elseif yx < 0.55 and (xz > 0.8 and xz < 1.25) then
			return "PLANTER"
		elseif (yx >= 0.55 and yx < 0.80) and (xz > 0.8 and xz < 1.25) then
			return "ALTAR"
		elseif (yx >= 1.1 and yx < 1.8) then
			return "EGG"
		elseif (yx >= 0.80 and yx <= 1.05) and (xz > 0.8 and xz < 1.25) then
			return "ISLAND"
		end
	end

	return nil
end

-- ============================================================
-- COSMIC ENVIRONMENT & LUMINOUS LIGHTING SETUP
-- ============================================================
function WorldController.SetupEnvironment()
	-- Daytime Celestial Lighting: Bright, clear, readable, beautiful!
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 20
	Lighting.Ambient = Color3.fromRGB(120, 110, 160)
	Lighting.OutdoorAmbient = Color3.fromRGB(145, 135, 185)
	Lighting.Brightness = 2.2
	Lighting.ColorShift_Top = Color3.fromRGB(245, 230, 255)
	Lighting.ColorShift_Bottom = Color3.fromRGB(80, 65, 120)
	Lighting.FogColor = Color3.fromRGB(45, 30, 75)
	Lighting.FogEnd = 10000 -- No suffocating dark fog!
	Lighting.FogStart = 500

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "CosmicBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.3
	bloom.Size = 18
	bloom.Threshold = 0.9

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "CosmicGrade"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Saturation = 0.25
	colorCorrection.Contrast = 0.12
	colorCorrection.TintColor = Color3.fromRGB(255, 250, 255)

	local existingSky = Lighting:FindFirstChildOfClass("Sky")
	if not existingSky then
		local sky = Instance.new("Sky")
		sky.Name = "NebulaSky"
		sky.SkyboxBk = "rbxassetid://159454299"
		sky.SkyboxDn = "rbxassetid://159454296"
		sky.SkyboxFt = "rbxassetid://159454293"
		sky.SkyboxLf = "rbxassetid://159454286"
		sky.SkyboxRt = "rbxassetid://159454300"
		sky.SkyboxUp = "rbxassetid://159454288"
		sky.StarCount = 5000
		sky.CelestialBodiesShown = true
		sky.Parent = Lighting
	end

	-- Remove default baseplate
	for _, child in Workspace:GetDescendants() do
		if child:IsA("BasePart") and string.find(string.lower(child.Name), "baseplate") then
			child:Destroy()
		end
	end

	-- Clean up legacy spawn locations
	for _, desc in Workspace:GetDescendants() do
		if desc:IsA("SpawnLocation") and desc.Name ~= "SanctuarySpawn" then
			desc.Transparency = 1
			desc.CanCollide = false
			for _, d in desc:GetDescendants() do
				if d:IsA("Decal") or d:IsA("Texture") then
					d:Destroy()
				end
			end
		end
	end

	local spawn = Workspace:FindFirstChild("SanctuarySpawn") :: SpawnLocation?
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SanctuarySpawn"
		spawn.Parent = Workspace
	end
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.Position = Vector3.new(0, 0.2, -14)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(38, 30, 60)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	for _, child in spawn:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") then
			child:Destroy()
		end
	end
end

-- ============================================================
-- 3D ASSET DISCOVERY & SANCTUARY BUILDER
-- ============================================================
function WorldController.Init()
	WorldController.SetupEnvironment()

	local gardenFolder = Workspace:FindFirstChild("StarweaveGarden")
	if gardenFolder then
		gardenFolder:Destroy()
	end

	gardenFolder = Instance.new("Folder")
	gardenFolder.Name = "StarweaveGarden"
	gardenFolder.Parent = Workspace
	WorldController._gardenFolder = gardenFolder

	local startOrigin = Vector3.new(0, 0, 2)

	-- Teleport player onto sanctuary entrance
	task.spawn(function()
		local char = player.Character or player.CharacterAdded:Wait()
		local root = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if root then
			root.CFrame = CFrame.new(0, 3.5, -14) * CFrame.Angles(0, 0, 0)
		end
	end)

	-- Void Safety Floor
	local safetyFloor = Instance.new("Part")
	safetyFloor.Name = "SanctuarySafetyFloor"
	safetyFloor.Size = Vector3.new(800, 4, 800)
	safetyFloor.Position = Vector3.new(0, -22, 0)
	safetyFloor.Anchored = true
	safetyFloor.CanCollide = true
	safetyFloor.Transparency = 1
	safetyFloor.Parent = gardenFolder

	safetyFloor.Touched:Connect(function(hit)
		local hitChar = hit.Parent
		if hitChar and hitChar == player.Character then
			local root = hitChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.CFrame = CFrame.new(0, 3.5, -14)
			end
		end
	end)

	-- ========================================================
	-- SCAN & CLASSIFY ALL IMPORTED 3D ASSETS IN WORKSPACE
	-- ========================================================
	local classifiedAssets: { [string]: Model } = {}
	local strayAssets: { Instance } = {}

	for _, child in Workspace:GetChildren() do
		if child.Name ~= "StarweaveGarden" and child.Name ~= "Terrain" and child.Name ~= "Camera" and child.Name ~= "SanctuarySpawn" then
			if child ~= player.Character and not (player.Character and child:IsDescendantOf(player.Character)) then
				local model = ensureAsModel(child)
				local tag = classifyModel(model)
				if tag and not classifiedAssets[tag] then
					classifiedAssets[tag] = model
					print(string.format("  🎯 [WorldController] 3D Asset Classified: %s -> %s", child.Name, tag))
				else
					table.insert(strayAssets, child)
				end
			end
		end
	end

	-- Also check ReplicatedStorage if any model was stored there
	for _, child in ReplicatedStorage:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			local model = ensureAsModel(child)
			local tag = classifyModel(model)
			if tag and not classifiedAssets[tag] then
				classifiedAssets[tag] = model
				print(string.format("  🎯 [WorldController] 3D Asset in ReplicatedStorage: %s -> %s", child.Name, tag))
			end
		end
	end

	-- ========================================================
	-- 1. WIRE 3D FLOATING SANCTUARY ISLAND
	-- ========================================================
	local islandModel = classifiedAssets["ISLAND"]
	local proceduralIslandTransparency = 0

	if islandModel then
		print("  ✨ [WorldController] Deploying 3D Floating Sanctuary Island (72 studs)...")
		islandModel.Parent = gardenFolder
		anchorAllParts(islandModel, true)
		scaleModelToDimension(islandModel, 72)

		if not islandModel.PrimaryPart then
			islandModel.PrimaryPart = islandModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if islandModel.PrimaryPart then
			islandModel:PivotTo(CFrame.new(0, -1.0, 2))
		end
		WorldController._islandModel = islandModel
		proceduralIslandTransparency = 1
	else
		print("  ℹ️ [WorldController] Using procedural island foundation fallback")
	end

	-- Solid Walkable Foundation Parts
	local island = Instance.new("Part")
	island.Name = "SanctuaryIslandFoundation"
	island.Size = Vector3.new(64, 2.0, 64)
	island.Position = Vector3.new(0, -1.0, 0)
	island.Anchored = true
	island.Material = Enum.Material.Slate
	island.Color = Color3.fromRGB(24, 20, 36)
	island.Transparency = proceduralIslandTransparency
	island.TopSurface = Enum.SurfaceType.Smooth
	island.Parent = gardenFolder

	local terrace = Instance.new("Part")
	terrace.Name = "GardenTerraceFoundation"
	terrace.Size = Vector3.new(42, 0.4, 42)
	terrace.Position = Vector3.new(0, 0.2, 2)
	terrace.Anchored = true
	terrace.Material = Enum.Material.Slate
	terrace.Color = Color3.fromRGB(30, 24, 46)
	terrace.Transparency = proceduralIslandTransparency
	terrace.TopSurface = Enum.SurfaceType.Smooth
	terrace.Parent = gardenFolder

	-- Stardust Ambient Particles
	local stardustEmitter = Instance.new("ParticleEmitter")
	stardustEmitter.Name = "AmbientStardust"
	stardustEmitter.Rate = 26
	stardustEmitter.Lifetime = NumberRange.new(4, 7)
	stardustEmitter.Speed = NumberRange.new(0.5, 1.8)
	stardustEmitter.SpreadAngle = Vector2.new(45, 45)
	stardustEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	stardustEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.2),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	stardustEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 180, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(250, 204, 21)),
	})
	stardustEmitter.LightEmission = 0.8
	stardustEmitter.Parent = terrace

	-- ========================================================
	-- 2. WIRE 3D TRANSMUTATION FORGE ALTAR
	-- ========================================================
	local altarModel = classifiedAssets["ALTAR"]
	local altarPos = Vector3.new(0, 0.4, 20)

	if altarModel then
		print("  ✨ [WorldController] Deploying 3D Transmutation Altar (8.5 studs)...")
		altarModel.Parent = gardenFolder
		anchorAllParts(altarModel, true)
		scaleModelToDimension(altarModel, 8.5)

		if not altarModel.PrimaryPart then
			altarModel.PrimaryPart = altarModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if altarModel.PrimaryPart then
			altarModel:PivotTo(CFrame.new(altarPos) * CFrame.Angles(0, math.rad(180), 0))
		end

		local promptPart = altarModel.PrimaryPart or Instance.new("Part")
		if promptPart.Parent ~= altarModel then
			promptPart.Size = Vector3.new(4, 4, 4)
			promptPart.Position = altarPos + Vector3.new(0, 2, 0)
			promptPart.Anchored = true
			promptPart.Transparency = 1
			promptPart.CanCollide = false
			promptPart.Parent = altarModel
		end

		local altarPrompt = Instance.new("ProximityPrompt")
		altarPrompt.Name = "AltarForgePrompt"
		altarPrompt.ActionText = "Transmute Seeds"
		altarPrompt.ObjectText = "Sacred Altar"
		altarPrompt.KeyboardKeyCode = Enum.KeyCode.E
		altarPrompt.HoldDuration = 0
		altarPrompt.MaxActivationDistance = 14
		altarPrompt.RequiresLineOfSight = false
		altarPrompt.Parent = promptPart

		altarPrompt.Triggered:Connect(function()
			local ui = getUIController()
			if ui and ui.ToggleModal then
				ui.ToggleModal("Forge")
			end
		end)

		local altarLight = Instance.new("PointLight")
		altarLight.Color = Color3.fromRGB(168, 85, 247)
		altarLight.Brightness = 2.5
		altarLight.Range = 18
		altarLight.Parent = promptPart
		WorldController._altarModel = altarModel
	end

	-- ========================================================
	-- 3. WIRE 3D CELESTIAL MYSTERY PET EGG
	-- ========================================================
	local eggModel = classifiedAssets["EGG"]
	local eggPos = Vector3.new(-18, 1.4, 2)

	if eggModel then
		print("  ✨ [WorldController] Deploying 3D Celestial Pet Egg (4 studs)...")
		eggModel.Parent = gardenFolder
		anchorAllParts(eggModel, false)
		scaleModelToDimension(eggModel, 4.0)

		if not eggModel.PrimaryPart then
			eggModel.PrimaryPart = eggModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if eggModel.PrimaryPart then
			eggModel:PivotTo(CFrame.new(eggPos))
		end

		WorldController._eggBaseCFrame = CFrame.new(eggPos)
		WorldController._eggModel = eggModel

		local pedestal = Instance.new("Part")
		pedestal.Name = "EggPedestal"
		pedestal.Shape = Enum.PartType.Cylinder
		pedestal.Size = Vector3.new(0.6, 4.0, 4.0)
		pedestal.Position = eggPos + Vector3.new(0, -1.2, 0)
		pedestal.Orientation = Vector3.new(0, 0, 90)
		pedestal.Anchored = true
		pedestal.Material = Enum.Material.Slate
		pedestal.Color = Color3.fromRGB(30, 24, 46)
		pedestal.Parent = gardenFolder

		local eggPromptPart = eggModel.PrimaryPart or pedestal
		local eggPrompt = Instance.new("ProximityPrompt")
		eggPrompt.Name = "HatchEggPrompt"
		eggPrompt.ActionText = "Hatch Companion"
		eggPrompt.ObjectText = "Celestial Mystery Egg"
		eggPrompt.KeyboardKeyCode = Enum.KeyCode.E
		eggPrompt.HoldDuration = 0
		eggPrompt.MaxActivationDistance = 14
		eggPrompt.RequiresLineOfSight = false
		eggPrompt.Parent = eggPromptPart

		eggPrompt.Triggered:Connect(function()
			local ui = getUIController()
			if ui and ui.ToggleModal then
				ui.ToggleModal("Pets")
			end
		end)

		local eggLight = Instance.new("PointLight")
		eggLight.Color = Color3.fromRGB(244, 114, 182)
		eggLight.Brightness = 2.0
		eggLight.Range = 14
		eggLight.Parent = eggPromptPart
	end

	-- ========================================================
	-- 4. WIRE 3D PLANTER & CROP TEMPLATES
	-- ========================================================
	local planterModel = classifiedAssets["PLANTER"]
	if planterModel then
		print("  ✨ [WorldController] Configuring 3D Planter Box Template (7 studs)...")
		anchorAllParts(planterModel, true)
		scaleModelToDimension(planterModel, 7.0)
		WorldController._planterTemplate = planterModel:Clone()
		planterModel:Destroy()
	end

	local cropModel = classifiedAssets["BLOOM"]
	if cropModel then
		print("  ✨ [WorldController] Configuring 3D Crystal Bloom Template (3.4 studs)...")
		anchorAllParts(cropModel, false)
		scaleModelToDimension(cropModel, 3.4)
		WorldController._cropTemplate = cropModel:Clone()
		cropModel:Destroy()
	end

	-- Clean up any stray imported meshes so nothing is left tiny on the side
	for _, stray in strayAssets do
		pcall(function()
			stray:Destroy()
		end)
	end

	-- Generate the 9 Starting Plots (3x3 grid)
	for i = 1, 9 do
		local row = math.floor((i - 1) / GRID_COLUMNS)
		local col = (i - 1) % GRID_COLUMNS

		local xPos = (col - 1) * PLOT_SPACING
		local zPos = (row - 1) * PLOT_SPACING
		local plotPos = startOrigin + Vector3.new(xPos, 0, zPos)

		WorldController._create3DPlot(i, plotPos, gardenFolder)
	end
end

function WorldController._create3DPlot(index: number, position: Vector3, parent: Folder)
	local plotModel = Instance.new("Model")
	plotModel.Name = `Plot_{index}`
	plotModel.Parent = parent

	-- Check if we have the 3D Planter Box Mesh
	local planterTemplate = WorldController._planterTemplate
	if planterTemplate then
		local planterClone = planterTemplate:Clone()
		planterClone.Name = "PlanterMesh"
		anchorAllParts(planterClone, true)

		if not planterClone.PrimaryPart then
			planterClone.PrimaryPart = planterClone:FindFirstChildWhichIsA("BasePart", true)
		end
		if planterClone.PrimaryPart then
			planterClone:PivotTo(CFrame.new(position + Vector3.new(0, 0.4, 0)))
		end
		planterClone.Parent = plotModel
	else
		-- Procedural Planter Fallback
		local planter = Instance.new("Part")
		planter.Name = "PlanterBox"
		planter.Size = Vector3.new(6.8, 0.7, 6.8)
		planter.Position = position + Vector3.new(0, 0.35, 0)
		planter.Anchored = true
		planter.Material = Enum.Material.Slate
		planter.Color = Color3.fromRGB(30, 24, 46)
		planter.Parent = plotModel
	end

	-- Soil Clickable / Interaction Zone
	local soil = Instance.new("Part")
	soil.Name = "Soil"
	soil.Size = Vector3.new(5.8, 0.4, 5.8)
	soil.Position = position + Vector3.new(0, 0.65, 0)
	soil.Anchored = true
	soil.Material = Enum.Material.Slate
	soil.Color = Color3.fromRGB(18, 14, 28)
	soil.Transparency = (planterTemplate ~= nil) and 1 or 0
	soil.TopSurface = Enum.SurfaceType.Smooth
	soil.Parent = plotModel

	-- Crop Holder Folder
	local cropFolder = Instance.new("Folder")
	cropFolder.Name = "Crop"
	cropFolder.Parent = plotModel

	-- Interactive Proximity Prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "InteractionPrompt"
	prompt.ActionText = "Plant Seed"
	prompt.ObjectText = `Plot #{index}`
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = soil

	prompt.Triggered:Connect(function()
		WorldController._handlePlotInteraction(index)
	end)

	-- Modern Floating Status Badge
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlotBillboard"
	billboard.Size = UDim2.new(0, 140, 0, 48)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 28
	billboard.Enabled = false
	billboard.Parent = soil

	local badgeFrame = Instance.new("Frame")
	badgeFrame.Name = "Badge"
	badgeFrame.Size = UDim2.fromScale(1, 1)
	badgeFrame.BackgroundColor3 = Color3.fromRGB(15, 11, 26)
	badgeFrame.BackgroundTransparency = 0.15
	badgeFrame.BorderSizePixel = 0
	badgeFrame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = badgeFrame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "BadgeStroke"
	stroke.Color = Color3.fromRGB(168, 85, 247)
	stroke.Thickness = 1.2
	stroke.Transparency = 0.3
	stroke.Parent = badgeFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "StatusTitle"
	titleLabel.Size = UDim2.new(1, -12, 0, 18)
	titleLabel.Position = UDim2.new(0, 6, 0, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = ""
	titleLabel.TextColor3 = Color3.fromRGB(244, 235, 255)
	titleLabel.TextSize = 12
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = badgeFrame

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "SubInfo"
	subLabel.Size = UDim2.new(1, -12, 0, 14)
	subLabel.Position = UDim2.new(0, 6, 0, 24)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = ""
	subLabel.TextColor3 = Color3.fromRGB(192, 132, 252)
	subLabel.TextSize = 10
	subLabel.Font = Enum.Font.GothamMedium
	subLabel.Parent = badgeFrame

	local progressBarBg = Instance.new("Frame")
	progressBarBg.Name = "ProgressBarBg"
	progressBarBg.Size = UDim2.new(1, -16, 0, 4)
	progressBarBg.Position = UDim2.new(0, 8, 1, -8)
	progressBarBg.BackgroundColor3 = Color3.fromRGB(28, 20, 44)
	progressBarBg.BorderSizePixel = 0
	progressBarBg.Visible = false
	progressBarBg.Parent = badgeFrame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = progressBarBg

	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBarBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = progressFill

	WorldController._plotModels[index] = plotModel
end

-- ============================================================
-- INTERACTION ROUTER
-- ============================================================
function WorldController._handlePlotInteraction(plotIndex: number)
	local data = WorldController._data
	if not data then return end

	local plot = data.Garden and data.Garden[plotIndex]
	if not plot then return end

	local gardenRequest = ReplicatedStorage:FindFirstChild("GardenRequest") :: RemoteFunction?
	if not gardenRequest then return end

	if not plot.Unlocked then
		gardenRequest:InvokeServer("UnlockPlot", plotIndex)
		return
	end

	if plot.Plant == nil then
		local plotModel = WorldController._plotModels[plotIndex]
		if plotModel then
			local soil = plotModel:FindFirstChild("Soil") :: BasePart?
			if soil and VFXController then
				VFXController.CreatePlantingAura(soil.Position)
			end
		end
		gardenRequest:InvokeServer("Plant", plotIndex, WorldController._selectedSeedId)
	elseif plot.Plant.State == "Ready" then
		gardenRequest:InvokeServer("Harvest", plotIndex)
	end
end

-- ============================================================
-- 3D CROP VISUAL BUILDER (3D MESH OR CLEAN FALLBACK)
-- ============================================================
function WorldController.UpdatePlantVisual(plotIndex: number, plant: any?)
	local plotModel = WorldController._plotModels[plotIndex]
	if not plotModel then return end

	local soil = plotModel:FindFirstChild("Soil") :: BasePart?
	local cropFolder = plotModel:FindFirstChild("Crop") :: Folder?
	local prompt = soil and soil:FindFirstChildOfClass("ProximityPrompt")
	local billboard = soil and soil:FindFirstChild("PlotBillboard") :: BillboardGui?

	if not (soil and cropFolder and prompt and billboard) then return end

	local badge = billboard:FindFirstChild("Badge") :: Frame?
	local titleLabel = badge and badge:FindFirstChild("StatusTitle") :: TextLabel?
	local subLabel = badge and badge:FindFirstChild("SubInfo") :: TextLabel?
	local progressBg = badge and badge:FindFirstChild("ProgressBarBg") :: Frame?
	local stroke = badge and badge:FindFirstChild("BadgeStroke") :: UIStroke?

	cropFolder:ClearAllChildren()

	-- 1. EMPTY PLOT: Completely clean
	if not plant then
		prompt.Enabled = true
		prompt.ActionText = "Plant Seed"
		prompt.ObjectText = `Plot #{plotIndex}`
		billboard.Enabled = false
		return
	end

	local seedDef = SeedData.GetSeed(plant.SeedId)
	local seedColor = SEED_COLORS[plant.SeedId] or Color3.fromRGB(168, 85, 247)
	local cropTemplate = WorldController._cropTemplate

	-- 2. GROWING PLOT
	if plant.State == "Growing" then
		prompt.Enabled = false
		billboard.Enabled = true

		if titleLabel and subLabel and progressBg and stroke then
			titleLabel.Text = seedDef and seedDef.Name or plant.SeedId
			titleLabel.TextColor3 = Color3.fromRGB(244, 235, 255)
			subLabel.Text = "Growing..."
			subLabel.TextColor3 = seedColor
			progressBg.Visible = true
			stroke.Color = seedColor
		end

		if cropTemplate then
			local cropClone = cropTemplate:Clone()
			cropClone.Name = "GrowingCrop"
			anchorAllParts(cropClone, false)
			scaleModelToDimension(cropClone, 1.8)

			if not cropClone.PrimaryPart then
				cropClone.PrimaryPart = cropClone:FindFirstChildWhichIsA("BasePart", true)
			end
			if cropClone.PrimaryPart then
				cropClone:PivotTo(CFrame.new(soil.Position + Vector3.new(0, 0.4, 0)))
			end
			cropClone.Parent = cropFolder
		else
			local stem = Instance.new("Part")
			stem.Name = "SproutStem"
			stem.Size = Vector3.new(0.3, 1.4, 0.3)
			stem.Position = soil.Position + Vector3.new(0, 1.0, 0)
			stem.Anchored = true
			stem.Material = Enum.Material.SmoothPlastic
			stem.Color = Color3.fromRGB(52, 211, 153)
			stem.Parent = cropFolder

			local bulb = Instance.new("Part")
			bulb.Name = "SproutBulb"
			bulb.Shape = Enum.PartType.Ball
			bulb.Size = Vector3.new(0.9, 0.9, 0.9)
			bulb.Position = stem.Position + Vector3.new(0, 0.9, 0)
			bulb.Anchored = true
			bulb.Material = Enum.Material.Neon
			bulb.Color = seedColor
			bulb.Transparency = 0.2
			bulb.Parent = cropFolder
		end

	-- 3. READY TO HARVEST
	elseif plant.State == "Ready" then
		prompt.Enabled = true
		prompt.ActionText = "Harvest!"
		prompt.ObjectText = seedDef and seedDef.Name or "Cosmic Bloom"
		billboard.Enabled = true

		if titleLabel and subLabel and progressBg and stroke then
			titleLabel.Text = "READY TO HARVEST"
			titleLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
			subLabel.Text = "[E] Harvest"
			subLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			progressBg.Visible = false
			stroke.Color = Color3.fromRGB(250, 204, 21)
		end

		if cropTemplate then
			local cropClone = cropTemplate:Clone()
			cropClone.Name = "MatureBloom"
			anchorAllParts(cropClone, false)
			scaleModelToDimension(cropClone, 3.4)

			if not cropClone.PrimaryPart then
				cropClone.PrimaryPart = cropClone:FindFirstChildWhichIsA("BasePart", true)
			end
			if cropClone.PrimaryPart then
				cropClone:PivotTo(CFrame.new(soil.Position + Vector3.new(0, 0.8, 0)))
			end
			cropClone.Parent = cropFolder

			local corePart = cropClone.PrimaryPart
			if corePart then
				table.insert(WorldController._rotatingCores, corePart)
				local bloomLight = Instance.new("PointLight")
				bloomLight.Color = seedColor
				bloomLight.Brightness = 2.0
				bloomLight.Range = 14
				bloomLight.Parent = corePart
			end
		else
			local stalk = Instance.new("Part")
			stalk.Name = "Stalk"
			stalk.Size = Vector3.new(0.35, 2.2, 0.35)
			stalk.Position = soil.Position + Vector3.new(0, 1.4, 0)
			stalk.Anchored = true
			stalk.Material = Enum.Material.SmoothPlastic
			stalk.Color = Color3.fromRGB(46, 160, 115)
			stalk.Parent = cropFolder

			local core = Instance.new("Part")
			core.Name = "BloomCore"
			core.Shape = Enum.PartType.Ball
			core.Size = Vector3.new(1.6, 1.6, 1.6)
			core.Position = stalk.Position + Vector3.new(0, 1.3, 0)
			core.Anchored = true
			core.Material = Enum.Material.Neon
			core.Color = seedColor
			core.Transparency = 0.15
			core.Parent = cropFolder
			table.insert(WorldController._rotatingCores, core)

			local bloomLight = Instance.new("PointLight")
			bloomLight.Color = seedColor
			bloomLight.Brightness = 1.4
			bloomLight.Range = 10
			bloomLight.Parent = core
		end
	end
end

-- ============================================================
-- CONTINUOUS RENDER LOOP (Timers, rotations, floating animations)
-- ============================================================
function WorldController.StartRenderLoop()
	task.spawn(function()
		while true do
			local now = os.time()
			local data = WorldController._data

			if data and data.Garden then
				for plotIndex, plot in data.Garden do
					if plot.Plant and plot.Plant.State == "Growing" then
						local endAt = plot.Plant.GrowthEndAt or (now + 10)
						local totalDur = (plot.Plant.GrowthEndAt - plot.Plant.PlantedAt)
						if totalDur <= 0 then totalDur = 10 end
						local remaining = math.max(0, endAt - now)
						local progressPct = math.clamp(1 - (remaining / totalDur), 0, 1)

						local plotModel = WorldController._plotModels[plotIndex]
						if plotModel then
							local soil = plotModel:FindFirstChild("Soil")
							local billboard = soil and soil:FindFirstChild("PlotBillboard") :: BillboardGui?
							local badge = billboard and billboard:FindFirstChild("Badge")
							local subLabel = badge and badge:FindFirstChild("SubInfo") :: TextLabel?
							local progressBg = badge and badge:FindFirstChild("ProgressBarBg")
							local fill = progressBg and progressBg:FindFirstChild("Fill") :: Frame?

							if subLabel then
								subLabel.Text = string.format("%02ds remaining", remaining)
							end
							if fill then
								fill.Size = UDim2.fromScale(progressPct, 1)
							end
						end
					end
				end
			end

			-- Smooth Core & Crop Rotation
			for i = #WorldController._rotatingCores, 1, -1 do
				local core = WorldController._rotatingCores[i]
				if core and core.Parent then
					core.CFrame = core.CFrame * CFrame.Angles(0, math.rad(1.2), 0)
				else
					table.remove(WorldController._rotatingCores, i)
				end
			end

			-- Magical Floating Bob for Pet Egg
			local eggModel = WorldController._eggModel
			local eggBaseCF = WorldController._eggBaseCFrame
			if eggModel and eggBaseCF and eggModel.PrimaryPart then
				local bobOffset = math.sin(os.clock() * 2.2) * 0.3
				local rotAngle = os.clock() * 0.4
				eggModel:PivotTo(eggBaseCF * CFrame.new(0, bobOffset, 0) * CFrame.Angles(0, rotAngle, 0))
			end

			task.wait(0.1)
		end
	end)
end

function WorldController.Update(data: any)
	if not data then return end
	WorldController._data = data

	if data.Garden then
		for index, plot in data.Garden do
			WorldController.UpdatePlantVisual(index, plot.Plant)
		end
	end
end

function WorldController.SetSelectedSeed(seedId: string)
	WorldController._selectedSeedId = seedId
end

return WorldController
