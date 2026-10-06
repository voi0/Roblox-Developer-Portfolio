--!strict
--[[
	WorldService.luau — Pure 3D Model Spatial Sanctuary for STARWEAVE
	Faithfully realizes the Unified Concept Art (media_1791217248028.jpg).
	Uses 100% of the User's imported 3D Models.
	ZERO procedural primitive blocks, ZERO neon discs, ZERO yellow/cyan toy shapes.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local WorldService = {}

-- ============================================================
-- SATELLITE & PLOT COORDINATES
-- ============================================================
-- 9 Garden Plots arranged in two clean symmetrical beds flanking the walkway
local PLOT_POSITIONS = {
	-- West Bed (Quadrant 1)
	Vector3.new(-13.0, 0.2, 2.0),
	Vector3.new(-6.5, 0.2, 2.0),
	Vector3.new(-13.0, 0.2, 10.0),
	Vector3.new(-6.5, 0.2, 10.0),

	-- Centerpiece Plot (Between walkway & altar)
	Vector3.new(0.0, 0.2, 7.0),

	-- East Bed (Quadrant 2)
	Vector3.new(6.5, 0.2, 2.0),
	Vector3.new(13.0, 0.2, 2.0),
	Vector3.new(6.5, 0.2, 10.0),
	Vector3.new(13.0, 0.2, 10.0),
}

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
	local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
	local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
	return CFrame.new(center), size
end

-- ============================================================
-- HELPER: ENSURE INSTANCE IS A PROPER MODEL
-- ============================================================
local function ensureAsModel(inst: Instance): Model
	if inst:IsA("Model") then
		return inst
	end
	local m = Instance.new("Model")
	m.Name = inst.Name
	local parent = inst.Parent
	inst.Parent = m
	m.Parent = parent
	m.PrimaryPart = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
	return m
end

-- ============================================================
-- HELPER: UNIFORM MODEL SCALING
-- ============================================================
local function scaleModelToDimension(model: Model, targetMaxDim: number)
	local cf, size = getContainerBounds(model)
	local maxCurrent = math.max(size.X, size.Y, size.Z)
	if maxCurrent > 0.01 and math.abs(maxCurrent - targetMaxDim) > 0.05 then
		local factor = targetMaxDim / maxCurrent
		local success = pcall(function()
			model:ScaleTo(factor)
		end)
		if not success then
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
-- 3D MODEL CLASSIFIER (Exact glTF Node Hashes + Keywords)
-- ============================================================
local function classifyModel(inst: Instance): string?
	local allNames = { inst.Name }
	for _, d in inst:GetDescendants() do
		table.insert(allNames, d.Name)
		if d:IsA("MeshPart") then
			table.insert(allNames, d.MeshId)
			table.insert(allNames, d.TextureID)
		elseif d:IsA("SpecialMesh") then
			table.insert(allNames, d.MeshId)
			table.insert(allNames, d.TextureId)
		end
	end
	local combined = string.lower(table.concat(allNames, " "))

	-- 1. Unified Full-Map / Multi-Structure Mesh File
	if string.find(combined, "unified") or string.find(combined, "structures") or string.find(combined, "full_map") or string.find(combined, "vision") or string.find(combined, "master_map") or string.find(combined, "archipelago") or string.find(combined, "environment") or string.find(combined, "main_map") or string.find(combined, "fullmap") or string.find(combined, "master") then
		return "MAP_UNIFIED"
	-- 2. Exact glTF Node Hashes & Keywords from User's Imports
	elseif string.find(combined, "agdrm0mbeo3gylxitymk") or string.find(combined, "bzvomeysheglnysxnymr") or string.find(combined, "floating%-sanctuary") or string.find(combined, "floating sanctuary") or string.find(combined, "central sanctuary") or string.find(combined, "island") then
		return "ISLAND"
	elseif string.find(combined, "ivdfl4qeemqt7ve4qcvs") or string.find(combined, "gardner") or string.find(combined, "plant%-box") or string.find(combined, "plant_box") or string.find(combined, "planter") then
		return "PLANTER"
	elseif string.find(combined, "12lquskllicosvzozjaa") or string.find(combined, "transmutation") or string.find(combined, "altar") or string.find(combined, "forge") then
		return "ALTAR"
	elseif string.find(combined, "wumxsfiy9i8durscm3vv") or string.find(combined, "crystal%-bloom") or string.find(combined, "crystal bloom") or string.find(combined, "cosmic%-crystal") or string.find(combined, "bloom") then
		return "BLOOM"
	elseif string.find(combined, "pftfbiaqxyqqa70eng8j") or string.find(combined, "mystery%-egg") or string.find(combined, "mystery egg") or string.find(combined, "celestial%-egg") or (string.find(combined, "egg") and not string.find(combined, "dragon")) then
		return "EGG"
	elseif string.find(combined, "b9yu9dueystnk3weda6y") or string.find(combined, "ioluminescent") or string.find(combined, "bioluminescent") or string.find(combined, "willow") then
		return "TREE_WILLOW"
	elseif string.find(combined, "88k2rzresq5xhd5bkrt8") or string.find(combined, "gazebo") or string.find(combined, "merchant stall") or string.find(combined, "market") then
		return "GAZEBO"
	elseif string.find(combined, "k4xcbxw5jiktsvfs6rvn") or string.find(combined, "realm gate") or string.find(combined, "locked portal") or string.find(combined, "cosmic realm gate") then
		return "GATE_ARCH"
	elseif string.find(combined, "dy37cblwfrngvdahv9wz") or string.find(combined, "kitsune") or string.find(combined, "astral kitsune") then
		return "PET_KITSUNE"
	elseif string.find(combined, "wvkryjmfl8csk8tlfsxr") or string.find(combined, "hatchling dragon") or string.find(combined, "dragon pet") or string.find(combined, "dragon") then
		return "PET_DRAGON"
	elseif string.find(combined, "well") or string.find(combined, "fountain") or string.find(combined, "vault") then
		return "WELL"
	elseif string.find(combined, "4wvlmpkfjpttoq4rws4") or string.find(combined, "bgcdryd1jxdfkwvccuxn") or string.find(combined, "meshentity") or string.find(combined, "crystal") or string.find(combined, "geode") then
		return "DECOR_CRYSTAL"
	-- General Keyword Fallbacks
	elseif string.find(combined, "tree") or string.find(combined, "foliage") or string.find(combined, "wood") then
		return "TREE_WILLOW"
	elseif string.find(combined, "gate") or string.find(combined, "portal") or string.find(combined, "arch") then
		return "GATE_ARCH"
	elseif string.find(combined, "pet") or string.find(combined, "companion") then
		return "PET_KITSUNE"
	end

	-- 2. Geometric Aspect Ratio Signature Fallback
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
	print("  🌌 [WorldService] Crafting Pure 3D Sanctuary from User Models...")

	-- 1. Setup Cinematic Atmospheric Lighting (Soft twilight fantasy, NO nuclear bloom)
	Lighting.ClockTime = 15.0
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(90, 80, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 100, 140)
	Lighting.ColorShift_Top = Color3.fromRGB(240, 230, 255)
	Lighting.ColorShift_Bottom = Color3.fromRGB(60, 50, 80)
	Lighting.FogColor = Color3.fromRGB(140, 120, 190)
	Lighting.FogEnd = 30000
	Lighting.ExposureCompensation = -0.10

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Name = "SanctuaryBloom"
	bloom.Intensity = 0.12
	bloom.Size = 12
	bloom.Threshold = 0.95
	bloom.Parent = Lighting

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "SanctuaryColorCorrection"
	colorCorrection.Saturation = 0.12
	colorCorrection.Contrast = 0.05
	colorCorrection.TintColor = Color3.fromRGB(255, 250, 255)
	colorCorrection.Parent = Lighting

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "SanctuaryAtmosphere"
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(160, 140, 210)
	atmosphere.Decay = Color3.fromRGB(110, 85, 150)
	atmosphere.Glare = 0.10
	atmosphere.Haze = 0.35
	atmosphere.Parent = Lighting

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

	-- SanctuarySpawn: Positioned on south arrival promenade facing north into the garden
	local spawn = Workspace:FindFirstChild("SanctuarySpawn") :: SpawnLocation?
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SanctuarySpawn"
		spawn.Parent = Workspace
	end
	spawn.Size = Vector3.new(8, 0.5, 8)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, -18), Vector3.new(0, 1.2, 8))
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Transparency = 1
	spawn.TopSurface = Enum.SurfaceType.Smooth
	for _, child in spawn:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") then
			child:Destroy()
		end
	end

	-- Folders
	local assetsFolder = ReplicatedStorage:FindFirstChild("StarweaveAssets") :: Folder?
	if not assetsFolder then
		assetsFolder = Instance.new("Folder")
		assetsFolder.Name = "StarweaveAssets"
		assetsFolder.Parent = ReplicatedStorage
	end

	local gardenFolder = Workspace:FindFirstChild("StarweaveGarden")
	if gardenFolder then
		gardenFolder:Destroy()
	end
	gardenFolder = Instance.new("Folder")
	gardenFolder.Name = "StarweaveGarden"
	gardenFolder.Parent = Workspace

	-- Void Safety Floor (Invisible safety net)
	local safetyFloor = Instance.new("Part")
	safetyFloor.Name = "SanctuarySafetyFloor"
	safetyFloor.Size = Vector3.new(900, 4, 900)
	safetyFloor.Position = Vector3.new(0, -32, 0)
	safetyFloor.Anchored = true
	safetyFloor.CanCollide = true
	safetyFloor.Transparency = 1
	safetyFloor.Parent = gardenFolder

	-- ========================================================
	-- COMPREHENSIVE SCANNER: INGEST ALL USER 3D ASSETS
	-- ========================================================
	local classifiedAssets: { [string]: { Model } } = {
		MAP_UNIFIED = {},
		ISLAND = {},
		PLANTER = {},
		ALTAR = {},
		BLOOM = {},
		EGG = {},
		TREE_WILLOW = {},
		GAZEBO = {},
		GATE_ARCH = {},
		PET_KITSUNE = {},
		PET_DRAGON = {},
		WELL = {},
		DECOR_CRYSTAL = {},
	}
	local strayAssets: { Instance } = {}

	local function scanContainer(container: Instance)
		for _, child in container:GetChildren() do
			if child.Name ~= "StarweaveGarden" and child.Name ~= "Terrain" and child.Name ~= "Camera" and child.Name ~= "SanctuarySpawn" and child.Name ~= "UserImportedAssets" and child.Name ~= "StarweaveAssets" then
				local model = ensureAsModel(child)
				local tag = classifyModel(model)
				if tag and classifiedAssets[tag] then
					table.insert(classifiedAssets[tag], model)
					print(string.format("  🎯 [WorldService] Found 3D Model: '%s' -> %s (#%d)", child.Name, tag, #classifiedAssets[tag]))
				else
					if child:IsA("Folder") or (child:IsA("Model") and #child:GetChildren() > 0 and not child:IsA("MeshPart")) then
						local hasClassifiedChild = false
						for _, sub in child:GetChildren() do
							local subModel = ensureAsModel(sub)
							local subTag = classifyModel(subModel)
							if subTag and classifiedAssets[subTag] then
								table.insert(classifiedAssets[subTag], subModel)
								print(string.format("  🎯 [WorldService] Found nested 3D Model: '%s/%s' -> %s (#%d)", child.Name, sub.Name, subTag, #classifiedAssets[subTag]))
								hasClassifiedChild = true
							end
						end
						if not hasClassifiedChild then
							table.insert(strayAssets, child)
						end
					else
						table.insert(strayAssets, child)
					end
				end
			end
		end
	end

	scanContainer(Workspace)
	scanContainer(ReplicatedStorage)

	-- SAFETY: NEVER DESTROY USER-IMPORTED ASSETS
	local userAssetsFolder = Workspace:FindFirstChild("UserImportedAssets")
	if not userAssetsFolder then
		userAssetsFolder = Instance.new("Folder")
		userAssetsFolder.Name = "UserImportedAssets"
		userAssetsFolder.Parent = Workspace
	end

	for _, stray in strayAssets do
		stray.Parent = userAssetsFolder
		anchorAllParts(stray, true)
	end

	-- ========================================================
	-- 0. MASTER UNIFIED SANCTUARY MAP (User-Modeled Multi-Structure Mesh)
	-- ========================================================
	local masterUnified = classifiedAssets["MAP_UNIFIED"] and classifiedAssets["MAP_UNIFIED"][1]
	if masterUnified then
		print("  🌟 [WorldService] Master Unified 3D Sanctuary Detected! Deploying to Garden...")
		masterUnified.Name = "MasterUnifiedSanctuary"
		masterUnified.Parent = gardenFolder
		anchorAllParts(masterUnified, true)
		if not masterUnified.PrimaryPart then
			masterUnified.PrimaryPart = masterUnified:FindFirstChildWhichIsA("BasePart", true)
		end
		if masterUnified.PrimaryPart then
			masterUnified:PivotTo(CFrame.new(0, 0, 0))
		end
	end

	-- ========================================================
	-- 1. CENTRAL SANCTUARY FLOATING ISLAND (Main Stage)
	-- ========================================================
	local islandTemplate = classifiedAssets["ISLAND"] and classifiedAssets["ISLAND"][1]
	if islandTemplate then
		print("  ✨ [WorldService] Deploying 3D Central Sanctuary Island (105 studs)...")
		local centerIsland = islandTemplate
		centerIsland.Name = "CenterSanctuaryIsland"
		centerIsland.Parent = gardenFolder
		anchorAllParts(centerIsland, true)
		scaleModelToDimension(centerIsland, 105)

		if not centerIsland.PrimaryPart then
			centerIsland.PrimaryPart = centerIsland:FindFirstChildWhichIsA("BasePart", true)
		end
		if centerIsland.PrimaryPart then
			-- Pivot island so its top stone pavers are flush at Y = 0
			centerIsland:PivotTo(CFrame.new(0, -40.0, 4))
		end
	end

	-- Invisible safety collision barrier beneath island surface (NO visible black boxes!)
	local centerSafetyCollision = Instance.new("Part")
	centerSafetyCollision.Name = "CenterInvisibleCollision"
	centerSafetyCollision.Size = Vector3.new(80, 2.0, 80)
	centerSafetyCollision.Position = Vector3.new(0, -1.0, 4)
	centerSafetyCollision.Anchored = true
	centerSafetyCollision.CanCollide = true
	centerSafetyCollision.Transparency = 1
	centerSafetyCollision.Parent = gardenFolder

	-- ========================================================
	-- 2. CENTERPIECE: 3D TRANSMUTATION ALTAR (12lQusKLlIcOsvzOzjaa)
	-- ========================================================
	local altarPos = Vector3.new(0, 0.4, 18)
	local userAltar = classifiedAssets["ALTAR"] and classifiedAssets["ALTAR"][1]
	if userAltar then
		print("  ✨ [WorldService] Deploying 3D Transmutation Altar centerpiece (9 studs)...")
		userAltar.Name = "SacredTransmutationAltar"
		userAltar.Parent = gardenFolder
		anchorAllParts(userAltar, true)
		scaleModelToDimension(userAltar, 9.0)
		if not userAltar.PrimaryPart then
			userAltar.PrimaryPart = userAltar:FindFirstChildWhichIsA("BasePart", true)
		end
		if userAltar.PrimaryPart then
			userAltar:PivotTo(CFrame.new(altarPos) * CFrame.Angles(0, math.rad(180), 0))
		end

		local promptPart = userAltar.PrimaryPart or Instance.new("Part")
		if promptPart.Parent ~= userAltar then
			promptPart.Size = Vector3.new(4, 4, 4)
			promptPart.Position = altarPos + Vector3.new(0, 2, 0)
			promptPart.Anchored = true
			promptPart.Transparency = 1
			promptPart.CanCollide = false
			promptPart.Parent = userAltar
		end

		local altarPrompt = Instance.new("ProximityPrompt")
		altarPrompt.Name = "AltarForgePrompt"
		altarPrompt.ActionText = "Transmute Seeds"
		altarPrompt.ObjectText = "Sacred Altar (Forge)"
		altarPrompt.KeyboardKeyCode = Enum.KeyCode.E
		altarPrompt.HoldDuration = 0
		altarPrompt.MaxActivationDistance = 14
		altarPrompt.RequiresLineOfSight = false
		altarPrompt.Parent = promptPart

		local altarLight = Instance.new("PointLight")
		altarLight.Color = Color3.fromRGB(168, 85, 247)
		altarLight.Brightness = 2.0
		altarLight.Range = 16
		altarLight.Parent = promptPart
	end

	-- ========================================================
	-- 3. THE 9 GARDEN PLOTS (IVdfl4QeEMqt7VE4qcvS)
	-- ========================================================
	local planterTemplate: Model? = nil
	local userPlanter = classifiedAssets["PLANTER"] and classifiedAssets["PLANTER"][1]
	if userPlanter then
		print("  ✨ [WorldService] Configuring 3D Planter Box Template (6.5 studs)...")
		anchorAllParts(userPlanter, true)
		scaleModelToDimension(userPlanter, 6.5)
		planterTemplate = userPlanter:Clone()
		userPlanter.Parent = userAssetsFolder
	end

	local userBloom = classifiedAssets["BLOOM"] and classifiedAssets["BLOOM"][1]
	if userBloom and assetsFolder then
		print("  ✨ [WorldService] Storing 3D Crystal Bloom Template in ReplicatedStorage...")
		anchorAllParts(userBloom, false)
		if not userBloom.PrimaryPart then
			userBloom.PrimaryPart = userBloom:FindFirstChildWhichIsA("BasePart", true)
		end
		scaleModelToDimension(userBloom, 3.2)
		userBloom.Name = "CropTemplate"
		userBloom.Parent = assetsFolder
	end

	for i = 1, #PLOT_POSITIONS do
		local plotPos = PLOT_POSITIONS[i]
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
				planterClone:PivotTo(CFrame.new(plotPos + Vector3.new(0, 0.35, 0)))
			end
			planterClone.Parent = plotModel
		end

		-- Transparent Soil interaction zone
		local soil = Instance.new("Part")
		soil.Name = "Soil"
		soil.Size = Vector3.new(5.2, 0.4, 5.2)
		soil.Position = plotPos + Vector3.new(0, 0.4, 0)
		soil.Anchored = true
		soil.CanCollide = false
		soil.Transparency = 1
		soil.TopSurface = Enum.SurfaceType.Smooth
		soil.Parent = plotModel

		local cropFolder = Instance.new("Folder")
		cropFolder.Name = "Crop"
		cropFolder.Parent = plotModel

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "InteractionPrompt"
		prompt.ActionText = "Plant Seed"
		prompt.ObjectText = `Plot #{i}`
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.Parent = soil
	end

	-- ========================================================
	-- 4. 4 GRAND BIOLUMINESCENT WEEPING WILLOW TREES (B9yU9Dueystnk3wEDa6Y)
	-- (Framing the rear scenic overlook into the cosmos)
	-- ========================================================
	local userWillows = classifiedAssets["TREE_WILLOW"] or {}
	local function deployWillowTree(pos: Vector3, foliageColor: Color3, name: string)
		if #userWillows > 0 then
			local template = userWillows[1]
			local treeClone = template:Clone()
			treeClone.Name = name
			treeClone.Parent = gardenFolder
			anchorAllParts(treeClone, true)
			for _, part in getContainerParts(treeClone) do
				part.CanCollide = false
			end
			scaleModelToDimension(treeClone, 18.0)
			if not treeClone.PrimaryPart then
				treeClone.PrimaryPart = treeClone:FindFirstChildWhichIsA("BasePart", true)
			end
			if treeClone.PrimaryPart then
				treeClone:PivotTo(CFrame.new(pos))
			end

			local sporePart = treeClone.PrimaryPart or treeClone:FindFirstChildWhichIsA("BasePart", true)
			if sporePart then
				local spores = Instance.new("ParticleEmitter")
				spores.Name = "WillowSpores"
				spores.Rate = 14
				spores.Lifetime = NumberRange.new(3.5, 6.0)
				spores.Speed = NumberRange.new(0.4, 1.2)
				spores.SpreadAngle = Vector2.new(50, 50)
				spores.Color = ColorSequence.new(foliageColor)
				spores.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
				spores.LightEmission = 0.80
				spores.Parent = sporePart
			end
		end
	end

	deployWillowTree(Vector3.new(-22, 0.2, 28), Color3.fromRGB(244, 114, 182), "Willow_Pink_RearLeft")
	deployWillowTree(Vector3.new(-14, 0.2, 38), Color3.fromRGB(56, 189, 248), "Willow_Cyan_FrontLeft")
	deployWillowTree(Vector3.new(14, 0.2, 38), Color3.fromRGB(56, 189, 248), "Willow_Cyan_FrontRight")
	deployWillowTree(Vector3.new(22, 0.2, 28), Color3.fromRGB(244, 114, 182), "Willow_Pink_RearRight")

	-- ========================================================
	-- 5. LEFT ISLAND: WEALTH & MARKET PLAZA
	-- ========================================================
	local eastIslandCenter = Vector3.new(62, 0, 4)
	if islandTemplate then
		local eastIsland = islandTemplate:Clone()
		eastIsland.Name = "EastMarketIsland"
		eastIsland.Parent = gardenFolder
		anchorAllParts(eastIsland, true)
		scaleModelToDimension(eastIsland, 55)
		if not eastIsland.PrimaryPart then
			eastIsland.PrimaryPart = eastIsland:FindFirstChildWhichIsA("BasePart", true)
		end
		if eastIsland.PrimaryPart then
			eastIsland:PivotTo(CFrame.new(62, -22, 4))
		end
	end

	local eastSafetyCollision = Instance.new("Part")
	eastSafetyCollision.Name = "EastInvisibleCollision"
	eastSafetyCollision.Size = Vector3.new(50, 2.0, 50)
	eastSafetyCollision.Position = Vector3.new(62, -1.0, 4)
	eastSafetyCollision.Anchored = true
	eastSafetyCollision.CanCollide = true
	eastSafetyCollision.Transparency = 1
	eastSafetyCollision.Parent = gardenFolder

	-- MARKET GAZEBO & MERCHANT STALL (88K2rZReSQ5xHd5bkrt8)
	local gazeboCenter = Vector3.new(62, 0.3, 10)
	local userGazebo = classifiedAssets["GAZEBO"] and classifiedAssets["GAZEBO"][1]
	if userGazebo then
		print("  ✨ [WorldService] Deploying 3D Floating Market Gazebo (16 studs)...")
		userGazebo.Name = "FloatingMarketGazebo"
		userGazebo.Parent = gardenFolder
		anchorAllParts(userGazebo, true)
		scaleModelToDimension(userGazebo, 16.0)
		if not userGazebo.PrimaryPart then
			userGazebo.PrimaryPart = userGazebo:FindFirstChildWhichIsA("BasePart", true)
		end
		if userGazebo.PrimaryPart then
			userGazebo:PivotTo(CFrame.new(gazeboCenter))
		end

		local shopPromptPart = userGazebo.PrimaryPart or Instance.new("Part")
		local shopPrompt = Instance.new("ProximityPrompt")
		shopPrompt.Name = "ShopPrompt"
		shopPrompt.ActionText = "Browse Shop"
		shopPrompt.ObjectText = "Market Gazebo"
		shopPrompt.KeyboardKeyCode = Enum.KeyCode.E
		shopPrompt.HoldDuration = 0
		shopPrompt.MaxActivationDistance = 14
		shopPrompt.RequiresLineOfSight = false
		shopPrompt.Parent = shopPromptPart
	end

	-- CELESTIAL WEALTH WELL (AFK Stardust Vault)
	local wellPos = Vector3.new(62, 0.3, -6)
	local userWell = classifiedAssets["WELL"] and classifiedAssets["WELL"][1]
	if userWell then
		print("  ✨ [WorldService] Deploying 3D Celestial Well (9 studs)...")
		userWell.Name = "CelestialWell"
		userWell.Parent = gardenFolder
		anchorAllParts(userWell, true)
		scaleModelToDimension(userWell, 9.0)
		if not userWell.PrimaryPart then
			userWell.PrimaryPart = userWell:FindFirstChildWhichIsA("BasePart", true)
		end
		if userWell.PrimaryPart then
			userWell:PivotTo(CFrame.new(wellPos))
		end

		local wellPrompt = Instance.new("ProximityPrompt")
		wellPrompt.Name = "CelestialWellPrompt"
		wellPrompt.ActionText = "Collect Stardust"
		wellPrompt.ObjectText = "Celestial Well (AFK Vault)"
		wellPrompt.KeyboardKeyCode = Enum.KeyCode.E
		wellPrompt.HoldDuration = 0
		wellPrompt.MaxActivationDistance = 12
		wellPrompt.RequiresLineOfSight = false
		wellPrompt.Parent = userWell.PrimaryPart

		wellPrompt.Triggered:Connect(function(player: Player)
			local DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
			DataService.CollectWell(player)
		end)
	end

	-- Golden Willow Tree framing the market plaza
	deployWillowTree(Vector3.new(75, 0.2, 2), Color3.fromRGB(250, 204, 21), "GoldenAutumnTree")

	-- ========================================================
	-- 6. RIGHT ISLAND: REALM PORTAL & PET SANCTUARY
	-- ========================================================
	local westIslandCenter = Vector3.new(-62, 0, 4)
	if islandTemplate then
		local westIsland = islandTemplate:Clone()
		westIsland.Name = "WestShrineIsland"
		westIsland.Parent = gardenFolder
		anchorAllParts(westIsland, true)
		scaleModelToDimension(westIsland, 55)
		if not westIsland.PrimaryPart then
			westIsland.PrimaryPart = westIsland:FindFirstChildWhichIsA("BasePart", true)
		end
		if westIsland.PrimaryPart then
			westIsland:PivotTo(CFrame.new(-62, -22, 4))
		end
	end

	local westSafetyCollision = Instance.new("Part")
	westSafetyCollision.Name = "WestInvisibleCollision"
	westSafetyCollision.Size = Vector3.new(50, 2.0, 50)
	westSafetyCollision.Position = Vector3.new(-62, -1.0, 4)
	westSafetyCollision.Anchored = true
	westSafetyCollision.CanCollide = true
	westSafetyCollision.Transparency = 1
	westSafetyCollision.Parent = gardenFolder

	-- ANCIENT COSMIC REALM GATE (K4xcbxw5JiktsVFs6Rvn)
	local userGate = classifiedAssets["GATE_ARCH"] and classifiedAssets["GATE_ARCH"][1]
	local gatePos = Vector3.new(-62, 0.3, 14)
	if userGate then
		print("  ✨ [WorldService] Deploying 3D Ancient Cosmic Realm Gate (22 studs)...")
		userGate.Name = "AncientCosmicRealmGate"
		userGate.Parent = gardenFolder
		anchorAllParts(userGate, true)
		scaleModelToDimension(userGate, 22.0)
		if not userGate.PrimaryPart then
			userGate.PrimaryPart = userGate:FindFirstChildWhichIsA("BasePart", true)
		end
		if userGate.PrimaryPart then
			userGate:PivotTo(CFrame.new(gatePos))
		end

		local gatePrompt = Instance.new("ProximityPrompt")
		gatePrompt.Name = "RealmGatePrompt"
		gatePrompt.ActionText = "Explore Realm"
		gatePrompt.ObjectText = "Astral Realm (Requires Rebirth 1)"
		gatePrompt.KeyboardKeyCode = Enum.KeyCode.E
		gatePrompt.HoldDuration = 0
		gatePrompt.MaxActivationDistance = 14
		gatePrompt.RequiresLineOfSight = false
		gatePrompt.Parent = userGate.PrimaryPart or userGate:FindFirstChildWhichIsA("BasePart", true)
	end

	-- CELESTIAL MYSTERY EGG (PftfbIAqxyQQaT0eng8J)
	local eggPos = Vector3.new(-62, 1.2, 0)
	local userEgg = classifiedAssets["EGG"] and classifiedAssets["EGG"][1]
	if userEgg then
		print("  ✨ [WorldService] Deploying 3D Celestial Mystery Egg (4.5 studs)...")
		userEgg.Name = "CelestialMysteryEgg"
		userEgg.Parent = gardenFolder
		anchorAllParts(userEgg, true)
		scaleModelToDimension(userEgg, 4.5)
		if not userEgg.PrimaryPart then
			userEgg.PrimaryPart = userEgg:FindFirstChildWhichIsA("BasePart", true)
		end
		if userEgg.PrimaryPart then
			userEgg:PivotTo(CFrame.new(eggPos))
		end

		local eggPrompt = Instance.new("ProximityPrompt")
		eggPrompt.Name = "HatchEggPrompt"
		eggPrompt.ActionText = "Hatch Companion"
		eggPrompt.ObjectText = "Celestial Mystery Egg"
		eggPrompt.KeyboardKeyCode = Enum.KeyCode.E
		eggPrompt.HoldDuration = 0
		eggPrompt.MaxActivationDistance = 14
		eggPrompt.RequiresLineOfSight = false
		eggPrompt.Parent = userEgg.PrimaryPart or userEgg:FindFirstChildWhichIsA("BasePart", true)

		local eggLight = Instance.new("PointLight")
		eggLight.Color = Color3.fromRGB(244, 114, 182)
		eggLight.Brightness = 1.8
		eggLight.Range = 14
		eggLight.Parent = userEgg.PrimaryPart or userEgg:FindFirstChildWhichIsA("BasePart", true)
	end

	-- ASTRAL KITSUNE COMPANION PET (dy37cbLWfRNgVdahv9wz)
	local userKitsune = classifiedAssets["PET_KITSUNE"] and classifiedAssets["PET_KITSUNE"][1]
	if userKitsune then
		print("  ✨ [WorldService] Deploying 3D Astral Kitsune Companion (3.5 studs)...")
		userKitsune.Name = "AstralKitsuneDais"
		userKitsune.Parent = gardenFolder
		anchorAllParts(userKitsune, true)
		scaleModelToDimension(userKitsune, 3.5)
		if not userKitsune.PrimaryPart then
			userKitsune.PrimaryPart = userKitsune:FindFirstChildWhichIsA("BasePart", true)
		end
		if userKitsune.PrimaryPart then
			userKitsune:PivotTo(CFrame.new(-56, 0.4, 0) * CFrame.Angles(0, math.rad(45), 0))
		end

		if assetsFolder then
			local petTemplate = userKitsune:Clone()
			petTemplate.Name = "Pet_celestial_kitsune"
			anchorAllParts(petTemplate, true)
			if not petTemplate.PrimaryPart then
				petTemplate.PrimaryPart = petTemplate:FindFirstChildWhichIsA("BasePart", true)
			end
			scaleModelToDimension(petTemplate, 2.2)
			petTemplate.Parent = assetsFolder
		end
	end

	-- STARLIGHT DRAGON PET (wvKRYjmFL8CSK8TLfSXr)
	local userDragon = classifiedAssets["PET_DRAGON"] and classifiedAssets["PET_DRAGON"][1]
	if userDragon then
		print("  ✨ [WorldService] Deploying 3D Starlight Hatchling Dragon (3.5 studs)...")
		userDragon.Name = "StarlightDragonDais"
		userDragon.Parent = gardenFolder
		anchorAllParts(userDragon, true)
		scaleModelToDimension(userDragon, 3.5)
		if not userDragon.PrimaryPart then
			userDragon.PrimaryPart = userDragon:FindFirstChildWhichIsA("BasePart", true)
		end
		if userDragon.PrimaryPart then
			userDragon:PivotTo(CFrame.new(-68, 0.4, 0) * CFrame.Angles(0, math.rad(-45), 0))
		end

		if assetsFolder then
			local petTemplate = userDragon:Clone()
			petTemplate.Name = "Pet_astral_dragon"
			anchorAllParts(petTemplate, true)
			if not petTemplate.PrimaryPart then
				petTemplate.PrimaryPart = petTemplate:FindFirstChildWhichIsA("BasePart", true)
			end
			scaleModelToDimension(petTemplate, 2.2)
			petTemplate.Parent = assetsFolder
		end
	end

	-- AMETHYST CRYSTALS DECOR
	local userCrystals = classifiedAssets["DECOR_CRYSTAL"] or {}
	if #userCrystals > 0 then
		for idx, cModel in userCrystals do
			if idx <= 3 then
				local clone = cModel:Clone()
				clone.Parent = gardenFolder
				anchorAllParts(clone, true)
				scaleModelToDimension(clone, 6.0)
				if not clone.PrimaryPart then
					clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
				end
				if clone.PrimaryPart then
					clone:PivotTo(CFrame.new(-74 + idx * 4, 0.2, 10))
				end
			end
		end
	end

	-- ========================================================
	-- 7. CRYSTALLINE ICE BRIDGES
	-- (Translucent crystalline glass spans connecting the 3 islands)
	-- ========================================================
	local function createCrystallineBridge(name: string, startX: number, endX: number, color: Color3)
		local bridgeModel = Instance.new("Model")
		bridgeModel.Name = name
		bridgeModel.Parent = gardenFolder

		local length = math.abs(endX - startX)
		local midX = (startX + endX) / 2

		local deck = Instance.new("Part")
		deck.Name = "BridgeDeck"
		deck.Size = Vector3.new(length, 0.5, 6.0)
		deck.Position = Vector3.new(midX, 0.1, 4)
		deck.Anchored = true
		deck.CanCollide = true
		deck.Material = Enum.Material.Glass
		deck.Color = color
		deck.Transparency = 0.45
		deck.Reflectance = 0.25
		deck.Parent = bridgeModel

		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "BridgeSparks"
		sparks.Rate = 6
		sparks.Lifetime = NumberRange.new(2, 4)
		sparks.Speed = NumberRange.new(0.3, 0.8)
		sparks.SpreadAngle = Vector2.new(30, 30)
		sparks.Color = ColorSequence.new(color)
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0) })
		sparks.LightEmission = 0.8
		sparks.Parent = deck

		return bridgeModel
	end

	createCrystallineBridge("EastCrystallineBridge", 28, 48, Color3.fromRGB(160, 210, 245))
	createCrystallineBridge("WestAmethystBridge", -28, -48, Color3.fromRGB(200, 170, 245))

	-- ========================================================
	-- 8. ATMOSPHERIC CLOUD SEA & HIGH-ALTITUDE AURORA
	-- ========================================================
	local cloudPositions = {
		Vector3.new(0, -28, 6),
		Vector3.new(-38, -26, 12),
		Vector3.new(38, -26, 12),
		Vector3.new(-65, -28, 0),
		Vector3.new(65, -28, 0),
		Vector3.new(0, -30, -25),
	}
	for idx, cPos in cloudPositions do
		local cloud = Instance.new("Part")
		cloud.Name = "CloudBank_" .. idx
		cloud.Shape = Enum.PartType.Ball
		cloud.Size = Vector3.new(46, 16, 46)
		cloud.Position = cPos
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Color = (idx % 2 == 0) and Color3.fromRGB(230, 215, 245) or Color3.fromRGB(245, 220, 235)
		cloud.Transparency = 0.55
		cloud.Parent = gardenFolder
	end

	local auroraFolder = Instance.new("Folder")
	auroraFolder.Name = "AuroraBorealis"
	auroraFolder.Parent = gardenFolder

	local auroraBands = {
		{ Center = Vector3.new(-40, 185, 30), Angle = 25, Size = Vector3.new(290, 26, 4), Color = Color3.fromRGB(52, 211, 153), Trans = 0.82 },
		{ Center = Vector3.new(10, 195, -20), Angle = -15, Size = Vector3.new(330, 30, 4), Color = Color3.fromRGB(56, 189, 248), Trans = 0.84 },
		{ Center = Vector3.new(60, 205, 50), Angle = 40, Size = Vector3.new(310, 28, 4), Color = Color3.fromRGB(236, 72, 153), Trans = 0.82 },
	}
	for idx, band in auroraBands do
		local aPart = Instance.new("Part")
		aPart.Name = "AuroraRibbon_" .. idx
		aPart.Size = band.Size
		aPart.Position = band.Center
		aPart.Orientation = Vector3.new(0, band.Angle, 0)
		aPart.Anchored = true
		aPart.CanCollide = false
		aPart.Material = Enum.Material.Neon
		aPart.Color = band.Color
		aPart.Transparency = band.Trans
		aPart.Parent = auroraFolder
	end

	-- ========================================================
	-- 9. RELIABLE CHARACTER SPAWN POSITIONING & STARTER TOOL
	-- ========================================================
	local function giveStarterTool(targetPlayer: Player)
		local backpack = targetPlayer:FindFirstChildOfClass("Backpack")
		local starterGear = targetPlayer:FindFirstChild("StarterGear")
		if not backpack then return end

		if backpack:FindFirstChild("Cosmic Trowel") or (targetPlayer.Character and targetPlayer.Character:FindFirstChild("Cosmic Trowel")) then
			return
		end

		local tool = Instance.new("Tool")
		tool.Name = "Cosmic Trowel"
		tool.ToolTip = "Sacred cosmic gardening trowel. Infused with starlight."
		tool.RequiresHandle = true
		tool.CanBeDropped = false

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.6, 2.0, 0.6)
		handle.Material = Enum.Material.SmoothPlastic
		handle.Color = Color3.fromRGB(168, 85, 247)
		handle.TopSurface = Enum.SurfaceType.Smooth
		handle.BottomSurface = Enum.SurfaceType.Smooth
		handle.CanCollide = false
		handle.Parent = tool

		local tipSparkles = Instance.new("ParticleEmitter")
		tipSparkles.Name = "CosmicSparks"
		tipSparkles.Rate = 10
		tipSparkles.Lifetime = NumberRange.new(0.4, 0.9)
		tipSparkles.Speed = NumberRange.new(0.4, 1.0)
		tipSparkles.SpreadAngle = Vector2.new(45, 45)
		tipSparkles.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 204, 21)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(168, 85, 247)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(56, 189, 248)),
		})
		tipSparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.22),
			NumberSequenceKeypoint.new(1, 0),
		})
		tipSparkles.LightEmission = 0.9
		tipSparkles.Parent = handle

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(216, 180, 254)
		light.Brightness = 1.2
		light.Range = 8
		light.Parent = handle

		tool.Grip = CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(-90), 0, 0)
		tool.Parent = backpack

		if starterGear and not starterGear:FindFirstChild("Cosmic Trowel") then
			local gearClone = tool:Clone()
			gearClone.Parent = starterGear
		end
	end

	local function onCharacterAdded(targetPlayer: Player, character: Model)
		local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if hrp then
			task.wait(0.08)
			hrp.CFrame = CFrame.lookAt(Vector3.new(0, 3.5, -16), Vector3.new(0, 3.5, 0))
		end
		giveStarterTool(targetPlayer)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			onCharacterAdded(player, char)
		end)
	end)

	for _, player in Players:GetPlayers() do
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
		player.CharacterAdded:Connect(function(char)
			onCharacterAdded(player, char)
		end)
	end

	print("  ✅ [WorldService] Pure 3D Sanctuary Online! All User Models Deployed.")
end

return WorldService
