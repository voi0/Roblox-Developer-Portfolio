--!strict
--[[
	WorldService.luau — Authoritative 3D Spatial Sanctuary Builder for STARWEAVE
	Runs on the SERVER at boot with full authoritative control over Workspace.
	Auto-detects and deploys all 5 Nilo-generated 3D assets:
	  1. Floating Sanctuary Island (Celestial foundation, scaled to 72 studs)
	  2. Gardner Plant Box (3D stone planter, scaled to 7 studs, cloned across 9 plots)
	  3. Transmutation Altar (Interactive Forge Shrine, scaled to 8.5 studs with [E] prompt)
	  4. Cosmic Crystal Bloom (Stored in ReplicatedStorage for dynamic crop growth)
	  5. Celestial Mystery Egg (Dais companion gacha, scaled to 4 studs with [E] prompt)
	Authoritatively removes the baseplate, sets luminous celestial lighting, and anchors all parts.
	Located in: ServerScriptService.Server.Services.WorldService
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldService = {}

local GRID_COLUMNS = 3
local PLOT_SPACING = 13.0
local START_ORIGIN = Vector3.new(0, 0, 2)

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
-- 3D MODEL CLASSIFIER (Exact Node IDs + Geometric Aspect Ratios)
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
-- AUTHORITATIVE SERVER INITIALIZATION
-- ============================================================
function WorldService.Init()
	print("  🏗️ [WorldService] Building Authoritative 3D Sanctuary on Server...")

	-- 1. Setup Environment Authoritatively
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 20
	Lighting.Ambient = Color3.fromRGB(120, 110, 160)
	Lighting.OutdoorAmbient = Color3.fromRGB(145, 135, 185)
	Lighting.Brightness = 2.2
	Lighting.ColorShift_Top = Color3.fromRGB(245, 230, 255)
	Lighting.ColorShift_Bottom = Color3.fromRGB(80, 65, 120)
	Lighting.FogColor = Color3.fromRGB(45, 30, 75)
	Lighting.FogEnd = 10000

	-- Destroy Baseplate
	for _, child in Workspace:GetChildren() do
		if child:IsA("BasePart") and string.find(string.lower(child.Name), "baseplate") then
			child:Destroy()
			print("  [WorldService] Baseplate destroyed ✓")
		end
	end

	-- Clean up legacy spawn locations
	for _, desc in Workspace:GetChildren() do
		if desc:IsA("SpawnLocation") and desc.Name ~= "SanctuarySpawn" then
			desc:Destroy()
		end
	end

	-- Create SanctuarySpawn
	local spawn = Workspace:FindFirstChild("SanctuarySpawn") :: SpawnLocation?
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SanctuarySpawn"
		spawn.Parent = Workspace
	end
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.Position = Vector3.new(0, 0.2, -20)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1 -- Invisible so player walks directly on the 3D island pavers!
	spawn.TopSurface = Enum.SurfaceType.Smooth
	for _, child in spawn:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") then
			child:Destroy()
		end
	end

	-- Create StarweaveAssets folder in ReplicatedStorage for shared assets
	local assetsFolder = ReplicatedStorage:FindFirstChild("StarweaveAssets") :: Folder?
	if not assetsFolder then
		assetsFolder = Instance.new("Folder")
		assetsFolder.Name = "StarweaveAssets"
		assetsFolder.Parent = ReplicatedStorage
	end

	-- Create or Reset StarweaveGarden in Workspace
	local gardenFolder = Workspace:FindFirstChild("StarweaveGarden")
	if gardenFolder then
		gardenFolder:Destroy()
	end
	gardenFolder = Instance.new("Folder")
	gardenFolder.Name = "StarweaveGarden"
	gardenFolder.Parent = Workspace

	-- Create Void Safety Floor
	local safetyFloor = Instance.new("Part")
	safetyFloor.Name = "SanctuarySafetyFloor"
	safetyFloor.Size = Vector3.new(800, 4, 800)
	safetyFloor.Position = Vector3.new(0, -22, 0)
	safetyFloor.Anchored = true
	safetyFloor.CanCollide = true
	safetyFloor.Transparency = 1
	safetyFloor.Parent = gardenFolder

	-- ========================================================
	-- SCAN & CLASSIFY ALL IMPORTED 3D ASSETS IN WORKSPACE
	-- ========================================================
	local classifiedAssets: { [string]: Model } = {}
	local strayAssets: { Instance } = {}

	for _, child in Workspace:GetChildren() do
		if child.Name ~= "StarweaveGarden" and child.Name ~= "Terrain" and child.Name ~= "Camera" and child.Name ~= "SanctuarySpawn" then
			local model = ensureAsModel(child)
			local tag = classifyModel(model)
			if tag and not classifiedAssets[tag] then
				classifiedAssets[tag] = model
				print(string.format("  🎯 [WorldService] Found 3D Model: '%s' -> %s", child.Name, tag))
			else
				table.insert(strayAssets, child)
			end
		end
	end

	-- 1. DEPLOY 3D FLOATING SANCTUARY ISLAND
	local islandModel = classifiedAssets["ISLAND"]
	local proceduralIslandTransparency = 0

	if islandModel then
		print("  ✨ [WorldService] Deploying 3D Floating Sanctuary Island (110 studs)...")
		islandModel.Parent = gardenFolder
		anchorAllParts(islandModel, true)
		scaleModelToDimension(islandModel, 110)

		if not islandModel.PrimaryPart then
			islandModel.PrimaryPart = islandModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if islandModel.PrimaryPart then
			-- Place island center down at Y = -42 so its top surface sits flush at Y = -0.5 beneath the plots!
			islandModel:PivotTo(CFrame.new(0, -42.0, 2))
		end
		proceduralIslandTransparency = 1
	else
		print("  ℹ️ [WorldService] Using procedural island foundation fallback")
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

	-- Ambient Floating Stardust
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

	-- 2. DEPLOY 3D TRANSMUTATION FORGE ALTAR
	local altarModel = classifiedAssets["ALTAR"]
	local altarPos = Vector3.new(0, 0.4, 26)

	if altarModel then
		print("  ✨ [WorldService] Deploying 3D Transmutation Altar (8.5 studs)...")
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

		local altarLight = Instance.new("PointLight")
		altarLight.Color = Color3.fromRGB(168, 85, 247)
		altarLight.Brightness = 2.5
		altarLight.Range = 18
		altarLight.Parent = promptPart
	end

	-- 3. DEPLOY 3D CELESTIAL MYSTERY PET EGG
	local eggModel = classifiedAssets["EGG"]
	local eggPos = Vector3.new(-24, 1.4, 2)

	if eggModel then
		print("  ✨ [WorldService] Deploying 3D Celestial Pet Egg (4 studs)...")
		eggModel.Parent = gardenFolder
		anchorAllParts(eggModel, false)
		scaleModelToDimension(eggModel, 4.0)

		if not eggModel.PrimaryPart then
			eggModel.PrimaryPart = eggModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if eggModel.PrimaryPart then
			eggModel:PivotTo(CFrame.new(eggPos))
		end

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

		local eggLight = Instance.new("PointLight")
		eggLight.Color = Color3.fromRGB(244, 114, 182)
		eggLight.Brightness = 2.0
		eggLight.Range = 14
		eggLight.Parent = eggPromptPart
	end

	-- 3.5 DEPLOY CELESTIAL STARDUST WELL (AFK VAULT)
	local wellPos = Vector3.new(0, 0.4, -22)
	local wellModel = Instance.new("Model")
	wellModel.Name = "CelestialWell"
	wellModel.Parent = gardenFolder

	local wellBase = Instance.new("Part")
	wellBase.Name = "WellBase"
	wellBase.Shape = Enum.PartType.Cylinder
	wellBase.Size = Vector3.new(1.8, 8.0, 8.0)
	wellBase.Position = wellPos + Vector3.new(0, 0.9, 0)
	wellBase.Orientation = Vector3.new(0, 0, 90)
	wellBase.Anchored = true
	wellBase.Material = Enum.Material.Slate
	wellBase.Color = Color3.fromRGB(24, 20, 38)
	wellBase.Parent = wellModel

	local wellRim = Instance.new("Part")
	wellRim.Name = "WellRim"
	wellRim.Shape = Enum.PartType.Cylinder
	wellRim.Size = Vector3.new(0.6, 9.2, 9.2)
	wellRim.Position = wellPos + Vector3.new(0, 1.8, 0)
	wellRim.Orientation = Vector3.new(0, 0, 90)
	wellRim.Anchored = true
	wellRim.Material = Enum.Material.Slate
	wellRim.Color = Color3.fromRGB(36, 28, 54)
	wellRim.Parent = wellModel

	local wellLiquid = Instance.new("Part")
	wellLiquid.Name = "WellCore"
	wellLiquid.Shape = Enum.PartType.Cylinder
	wellLiquid.Size = Vector3.new(0.4, 7.2, 7.2)
	wellLiquid.Position = wellPos + Vector3.new(0, 1.7, 0)
	wellLiquid.Orientation = Vector3.new(0, 0, 90)
	wellLiquid.Anchored = true
	wellLiquid.Material = Enum.Material.Neon
	wellLiquid.Color = Color3.fromRGB(250, 204, 21)
	wellLiquid.Transparency = 0.2
	wellLiquid.Parent = wellModel

	local wellLight = Instance.new("PointLight")
	wellLight.Color = Color3.fromRGB(250, 204, 21)
	wellLight.Brightness = 2.2
	wellLight.Range = 16
	wellLight.Parent = wellLiquid

	local wellParticles = Instance.new("ParticleEmitter")
	wellParticles.Name = "WellParticles"
	wellParticles.Rate = 18
	wellParticles.Lifetime = NumberRange.new(2.5, 4.5)
	wellParticles.Speed = NumberRange.new(1.2, 2.5)
	wellParticles.SpreadAngle = Vector2.new(30, 30)
	wellParticles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 204, 21)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(244, 114, 182)),
	})
	wellParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	wellParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.8, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	wellParticles.LightEmission = 0.9
	wellParticles.Parent = wellLiquid

	local wellPrompt = Instance.new("ProximityPrompt")
	wellPrompt.Name = "CelestialWellPrompt"
	wellPrompt.ActionText = "Collect Stardust"
	wellPrompt.ObjectText = "Celestial Well (AFK Vault)"
	wellPrompt.KeyboardKeyCode = Enum.KeyCode.E
	wellPrompt.HoldDuration = 0
	wellPrompt.MaxActivationDistance = 14
	wellPrompt.RequiresLineOfSight = false
	wellPrompt.Parent = wellLiquid

	-- 4. PREPARE 3D PLANTER TEMPLATE & CROP TEMPLATE
	local planterTemplate: Model? = nil
	local planterModel = classifiedAssets["PLANTER"]
	if planterModel then
		print("  ✨ [WorldService] Configuring 3D Planter Box Template (7 studs)...")
		anchorAllParts(planterModel, true)
		scaleModelToDimension(planterModel, 7.0)
		planterTemplate = planterModel:Clone()
		planterModel:Destroy()
	end

	local cropModel = classifiedAssets["BLOOM"]
	if cropModel and assetsFolder then
		print("  ✨ [WorldService] Storing 3D Crystal Bloom Template in ReplicatedStorage...")
		anchorAllParts(cropModel, false)
		scaleModelToDimension(cropModel, 3.4)
		cropModel.Name = "CropTemplate"
		cropModel.Parent = assetsFolder
	end

	-- Clean up stray orphan models so nothing is left tiny on the side
	for _, stray in strayAssets do
		pcall(function()
			stray:Destroy()
		end)
	end

	-- 5. DEPLOY THE 9 GARDEN PLOTS AUTHORITATIVELY ON THE SERVER
	for i = 1, 9 do
		local row = math.floor((i - 1) / GRID_COLUMNS)
		local col = (i - 1) % GRID_COLUMNS

		local xPos = (col - 1) * PLOT_SPACING
		local zPos = (row - 1) * PLOT_SPACING
		local plotPos = START_ORIGIN + Vector3.new(xPos, 0, zPos)

		local plotModel = Instance.new("Model")
		plotModel.Name = `Plot_{i}`
		plotModel.Parent = gardenFolder

		if planterTemplate then
			local planterClone = planterTemplate:Clone()
			planterClone.Name = "PlanterMesh"
			anchorAllParts(planterClone, true)
			if not planterClone.PrimaryPart then
				planterClone.PrimaryPart = planterClone:FindFirstChildWhichIsA("BasePart", true)
			end
			if planterClone.PrimaryPart then
				planterClone:PivotTo(CFrame.new(plotPos + Vector3.new(0, 0.4, 0)))
			end
			planterClone.Parent = plotModel
		else
			local planter = Instance.new("Part")
			planter.Name = "PlanterBox"
			planter.Size = Vector3.new(6.8, 0.7, 6.8)
			planter.Position = plotPos + Vector3.new(0, 0.35, 0)
			planter.Anchored = true
			planter.Material = Enum.Material.Slate
			planter.Color = Color3.fromRGB(30, 24, 46)
			planter.Parent = plotModel
		end

		-- Soil Clickable / Interaction Zone
		local soil = Instance.new("Part")
		soil.Name = "Soil"
		soil.Size = Vector3.new(5.8, 0.4, 5.8)
		soil.Position = plotPos + Vector3.new(0, 0.65, 0)
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

		-- Server-Authoritative Interaction Prompt
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "InteractionPrompt"
		prompt.ActionText = "Plant Seed"
		prompt.ObjectText = `Plot #{i}`
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = soil
	end

	print("  ✅ [WorldService] Authoritative 3D Sanctuary Online! All 9 Plots & Meshes Deployed.")
end

return WorldService
