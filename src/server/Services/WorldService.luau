--!strict
--[[
	WorldService.luau — Clean, Organized 3D Sanctuary for STARWEAVE
	Faithfully realizes the Unified Concept Art (media_1791217248028.jpg).
	Pure 3D architecture powered by the User's 14 imported models.
	ZERO random floating shapes, ZERO clipping models, ZERO void gaps.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local WorldService = {}

-- ============================================================
-- SATELLITE & PLOT COORDINATES (Clean, Symmetrical Garden Layout)
-- ============================================================
-- 9 Garden Plots arranged in two spacious flanking beds with a 28-stud central promenade
local PLOT_POSITIONS = {
	-- West Garden Bed (Quadrant 1)
	Vector3.new(-14.0, 0.45, -12.0),
	Vector3.new(-24.0, 0.45, -12.0),
	Vector3.new(-14.0, 0.45, -2.0),
	Vector3.new(-24.0, 0.45, -2.0),

	-- Centerpiece Plot (Framed right before the walkway leading to Altar)
	Vector3.new(0.0, 0.45, -5.0),

	-- East Garden Bed (Quadrant 2)
	Vector3.new(14.0, 0.45, -12.0),
	Vector3.new(24.0, 0.45, -12.0),
	Vector3.new(14.0, 0.45, -2.0),
	Vector3.new(24.0, 0.45, -2.0),
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
-- HELPER: MATHEMATICALLY PRECISE FLUSH PIVOTING
-- ============================================================
local function pivotModelBottomFlush(model: Model, targetXZ: Vector3, targetBottomY: number, rotYRad: number?)
	local cf, sz = getContainerBounds(model)
	local currentBottom = cf.Position.Y - sz.Y / 2
	local deltaY = targetBottomY - currentBottom
	local rot = rotYRad and CFrame.Angles(0, rotYRad, 0) or CFrame.identity
	local targetPos = Vector3.new(targetXZ.X, cf.Position.Y + deltaY, targetXZ.Z)

	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end

	local success = pcall(function()
		model:PivotTo(CFrame.new(targetPos) * rot)
	end)

	if not success then
		for _, part in getContainerParts(model) do
			local offset = part.Position - cf.Position
			local newPos = targetPos + offset
			part.CFrame = CFrame.new(newPos) * part.CFrame.Rotation
		end
	end
end

local function pivotIslandTopFlush(model: Model, targetXZ: Vector3, targetTopY: number)
	local cf, sz = getContainerBounds(model)
	local currentTop = cf.Position.Y + sz.Y / 2
	local deltaY = targetTopY - currentTop
	local targetPos = Vector3.new(targetXZ.X, cf.Position.Y + deltaY, targetXZ.Z)

	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end

	local success = pcall(function()
		model:PivotTo(CFrame.new(targetPos))
	end)

	if not success then
		for _, part in getContainerParts(model) do
			local offset = part.Position - cf.Position
			local newPos = targetPos + offset
			part.CFrame = CFrame.new(newPos) * part.CFrame.Rotation
		end
	end
end

-- ============================================================
-- 3D MODEL CLASSIFIER (Exact glTF Node Hashes for all 14 Models)
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

	-- 1. The 14th Model: Master Unified Vision Scene (Grand Celestial Temple)
	if string.find(combined, "ynrolxdcxfktt2p42y4l") or string.find(combined, "unified") or string.find(combined, "structures") or string.find(combined, "full_map") or string.find(combined, "vision") or string.find(combined, "master_map") or string.find(combined, "temple") or string.find(combined, "pavilion") then
		return "MAP_UNIFIED"
	-- 2. Floating Sanctuary Islands
	elseif string.find(combined, "bzvomeysheglnysxnymr") or string.find(combined, "floating%-sanctuary") or string.find(combined, "central sanctuary") or string.find(combined, "main_island") then
		return "ISLAND"
	elseif string.find(combined, "agdrm0mbeo3gylxitymk") or string.find(combined, "satellite_island") then
		return "ISLAND_SATELLITE"
	-- 3. Sacred Altar
	elseif string.find(combined, "12lquskllicosvzozjaa") or string.find(combined, "transmutation") or string.find(combined, "altar") or string.find(combined, "forge") or string.find(combined, "shrine") or string.find(combined, "monolith") or string.find(combined, "pedestal") then
		return "ALTAR"
	-- 4. Ornate Cosmic Planter Box
	elseif string.find(combined, "ivdfl4qeemqt7ve4qcvs") or string.find(combined, "gardner") or string.find(combined, "plant%-box") or string.find(combined, "plant_box") or string.find(combined, "planter") or string.find(combined, "plot") or string.find(combined, "pot") then
		return "PLANTER"
	-- 5. Bioluminescent Weeping Willow Tree
	elseif string.find(combined, "b9yu9dueystnk3weda6y") or string.find(combined, "ioluminescent") or string.find(combined, "bioluminescent") or string.find(combined, "willow") or string.find(combined, "tree") or string.find(combined, "foliage") or string.find(combined, "wood") then
		return "TREE_WILLOW"
	-- 6. Merchant Gazebo / Market Pavilion
	elseif string.find(combined, "88k2rzresq5xhd5bkrt8") or string.find(combined, "gazebo") or string.find(combined, "merchant stall") or string.find(combined, "market") or string.find(combined, "stall") or string.find(combined, "shop") or string.find(combined, "tent") then
		return "GAZEBO"
	-- 7. Ancient Cosmic Realm Gate
	elseif string.find(combined, "k4xcbxw5jiktsvfs6rvn") or string.find(combined, "realm gate") or string.find(combined, "locked portal") or string.find(combined, "cosmic realm gate") or string.find(combined, "gate") or string.find(combined, "portal") or string.find(combined, "arch") then
		return "GATE_ARCH"
	-- 8. Astral Kitsune Companion Fox
	elseif string.find(combined, "dy37cblwfrngvdahv9wz") or string.find(combined, "kitsune") or string.find(combined, "astral kitsune") or string.find(combined, "fox") then
		return "PET_KITSUNE"
	-- 9. Starlight Hatchling Dragon
	elseif string.find(combined, "wvkryjmfl8csk8tlfsxr") or string.find(combined, "hatchling dragon") or string.find(combined, "dragon pet") or string.find(combined, "dragon") or string.find(combined, "drake") then
		return "PET_DRAGON"
	-- 10. Celestial Mystery Egg
	elseif string.find(combined, "pftfbiaqxyqqa70eng8j") or string.find(combined, "mystery%-egg") or string.find(combined, "mystery egg") or string.find(combined, "celestial%-egg") or (string.find(combined, "egg") and not string.find(combined, "dragon")) then
		return "EGG"
	-- 11. Crystal Bloom Crop
	elseif string.find(combined, "wumxsfiy9i8durscm3vv") or string.find(combined, "crystal%-bloom") or string.find(combined, "crystal bloom") or string.find(combined, "cosmic%-crystal") or string.find(combined, "bloom") or string.find(combined, "flower") or string.find(combined, "crop") then
		return "BLOOM"
	-- 12. Amethyst Crystal Cluster / Geode
	elseif string.find(combined, "bgcdryd1jxdfkwvccuxn") or string.find(combined, "meshentity") or string.find(combined, "crystal") or string.find(combined, "geode") or string.find(combined, "ore") or string.find(combined, "gem") then
		return "DECOR_CRYSTAL"
	-- 13. Celestial Stardust Well (AFK Vault)
	elseif string.find(combined, "4wvlmwpkfjpttoq4rws4") or string.find(combined, "4wvlmpkfjpttoq4rws4") or string.find(combined, "well") or string.find(combined, "fountain") or string.find(combined, "vault") or string.find(combined, "pool") then
		return "WELL"
	-- Fallback Keyword Matches
	elseif string.find(combined, "island") or string.find(combined, "rock") or string.find(combined, "ground") then
		return "ISLAND"
	end

	return nil
end

-- ============================================================
-- AUTHORITATIVE SERVER INITIALIZATION
-- ============================================================
function WorldService.Init()
	print("========================================")
	print("  🌌 [WorldService] Constructing Clean, Organized 3D Sanctuary...")
	print("========================================")

	-- 1. Setup Cinematic Atmospheric Lighting (Matching the Midjourney Concept Art)
	Lighting.ClockTime = 19.5
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(35, 28, 52)
	Lighting.OutdoorAmbient = Color3.fromRGB(55, 45, 78)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 215, 165)
	Lighting.ColorShift_Bottom = Color3.fromRGB(85, 50, 125)
	Lighting.FogColor = Color3.fromRGB(75, 50, 110)
	Lighting.FogEnd = 40000
	Lighting.ExposureCompensation = -0.05

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Name = "SanctuaryBloom"
	bloom.Intensity = 0.20
	bloom.Size = 14
	bloom.Threshold = 0.90
	bloom.Parent = Lighting

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "SanctuaryColorCorrection"
	colorCorrection.Saturation = 0.15
	colorCorrection.Contrast = 0.08
	colorCorrection.TintColor = Color3.fromRGB(255, 248, 255)
	colorCorrection.Parent = Lighting

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "SanctuaryAtmosphere"
	atmosphere.Density = 0.30
	atmosphere.Offset = 0.20
	atmosphere.Color = Color3.fromRGB(110, 80, 160)
	atmosphere.Decay = Color3.fromRGB(50, 25, 85)
	atmosphere.Glare = 0.20
	atmosphere.Haze = 0.80
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

	-- ========================================================
	-- COMPREHENSIVE SCANNER ACROSS ALL 14 USER 3D MODELS
	-- ========================================================
	local classifiedAssets: { [string]: { Model } } = {
		MAP_UNIFIED = {},
		ISLAND = {},
		ISLAND_SATELLITE = {},
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
	local scannedInstances: { [Instance]: boolean } = {}

	local function processCandidate(inst: Instance)
		if scannedInstances[inst] then return end
		scannedInstances[inst] = true

		local model = ensureAsModel(inst)
		local _, sz = getContainerBounds(model)
		local tag = classifyModel(model)

		if tag and classifiedAssets[tag] then
			table.insert(classifiedAssets[tag], model)
			print(string.format("  🎯 [WorldService] Mapped Model: '%s' -> %s", model.Name, tag))
		end
	end

	local function scanContainer(container: Instance?)
		if not container then return end
		for _, child in container:GetChildren() do
			if child.Name == "StarweaveGarden" or child.Name == "Terrain" or child.Name == "Camera" or child.Name == "SanctuarySpawn" or child.Name == "StarweaveAssets" then
				continue
			end

			if child.Name == "UserImportedAssets" or child:IsA("Folder") or child:IsA("Configuration") then
				for _, sub in child:GetChildren() do
					if sub:IsA("Model") or sub:IsA("BasePart") then
						processCandidate(sub)
					end
				end
			elseif child:IsA("Model") or child:IsA("BasePart") then
				local hasSubModels = false
				for _, sub in child:GetChildren() do
					if sub:IsA("Model") then
						hasSubModels = true
						processCandidate(sub)
					end
				end
				if not hasSubModels then
					processCandidate(child)
				end
			end
		end
	end

	scanContainer(Workspace)
	scanContainer(ServerStorage)
	scanContainer(ReplicatedStorage)

	-- ========================================================
	-- 1. SOLID, BEAUTIFUL, CONTINUOUS MAIN ISLAND GROUND
	-- (Clean slate stone & cobblestone promenade at Y = 0.4)
	-- ========================================================
	local islandFolder = Instance.new("Folder")
	islandFolder.Name = "SanctuaryGround"
	islandFolder.Parent = gardenFolder

	-- Smooth circular stone island surface (Diameter 96 studs, top at Y = 0.4)
	local mainGround = Instance.new("Part")
	mainGround.Name = "IslandStoneDeck"
	mainGround.Shape = Enum.PartType.Cylinder
	mainGround.Size = Vector3.new(2.0, 96, 96)
	mainGround.CFrame = CFrame.new(0, -0.6, 2) * CFrame.Angles(0, 0, math.rad(90))
	mainGround.Anchored = true
	mainGround.CanCollide = true
	mainGround.Material = Enum.Material.Slate
	mainGround.Color = Color3.fromRGB(36, 30, 50)
	mainGround.TopSurface = Enum.SurfaceType.Smooth
	mainGround.Parent = islandFolder

	-- Central Cobblestone Promenade Walkway (Extends from spawn at Z = -34 to altar at Z = 16)
	local walkway = Instance.new("Part")
	walkway.Name = "CenterPromenade"
	walkway.Size = Vector3.new(12, 0.1, 52)
	walkway.Position = Vector3.new(0, 0.45, -9)
	walkway.Anchored = true
	walkway.CanCollide = true
	walkway.Material = Enum.Material.Cobblestone
	walkway.Color = Color3.fromRGB(50, 44, 66)
	walkway.TopSurface = Enum.SurfaceType.Smooth
	walkway.Parent = islandFolder

	-- Inset Starlight Rune Trim along the walkway edges
	local runeTrimLeft = Instance.new("Part")
	runeTrimLeft.Name = "RuneTrimLeft"
	runeTrimLeft.Size = Vector3.new(0.4, 0.12, 52)
	runeTrimLeft.Position = Vector3.new(-6.2, 0.46, -9)
	runeTrimLeft.Anchored = true
	runeTrimLeft.CanCollide = false
	runeTrimLeft.Material = Enum.Material.Neon
	runeTrimLeft.Color = Color3.fromRGB(168, 85, 247)
	runeTrimLeft.Transparency = 0.4
	runeTrimLeft.Parent = islandFolder

	local runeTrimRight = Instance.new("Part")
	runeTrimRight.Name = "RuneTrimRight"
	runeTrimRight.Size = Vector3.new(0.4, 0.12, 52)
	runeTrimRight.Position = Vector3.new(6.2, 0.46, -9)
	runeTrimRight.Anchored = true
	runeTrimRight.CanCollide = false
	runeTrimRight.Material = Enum.Material.Neon
	runeTrimRight.Color = Color3.fromRGB(168, 85, 247)
	runeTrimRight.Transparency = 0.4
	runeTrimRight.Parent = islandFolder

	-- 3D Island Rock Mesh (BZvOmeysHEgLnYsXNYmR) hanging underneath
	local mainIslandRock = classifiedAssets["ISLAND"] and classifiedAssets["ISLAND"][1]
	if mainIslandRock then
		print("  ✨ [WorldService] Mounting 3D Island Rock under main sanctuary...")
		mainIslandRock.Name = "CenterIslandCrags"
		mainIslandRock.Parent = islandFolder
		anchorAllParts(mainIslandRock, false)
		scaleModelToDimension(mainIslandRock, 105.0)
		pivotIslandTopFlush(mainIslandRock, Vector3.new(0, 0, 2), 0.3)
	end

	-- SanctuarySpawn: Situated at the south end of the walkway, looking North
	local spawn = Workspace:FindFirstChild("SanctuarySpawn") :: SpawnLocation?
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SanctuarySpawn"
		spawn.Parent = Workspace
	end
	spawn.Size = Vector3.new(10, 0.2, 10)
	spawn.Position = Vector3.new(0, 0.46, -30)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.46, -30), Vector3.new(0, 0.46, 0))
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Transparency = 1
	spawn.TopSurface = Enum.SurfaceType.Smooth

	-- ========================================================
	-- 2. THE 9 SPACIOUS GARDEN PLOTS (IVdfl4QeEMqt7VE4qcvS)
	-- ========================================================
	local userPlanter = classifiedAssets["PLANTER"] and classifiedAssets["PLANTER"][1]
	local planterTemplate: Model? = nil
	if userPlanter then
		print("  ✨ [WorldService] Deploying 9 Ornate 3D Planters with Cosmic Runes...")
		anchorAllParts(userPlanter, true)
		scaleModelToDimension(userPlanter, 6.2)
		planterTemplate = userPlanter:Clone()
		userPlanter.Parent = gardenFolder
	end

	local userBloom = classifiedAssets["BLOOM"] and classifiedAssets["BLOOM"][1]
	if userBloom and assetsFolder then
		anchorAllParts(userBloom, false)
		if not userBloom.PrimaryPart then
			userBloom.PrimaryPart = userBloom:FindFirstChildWhichIsA("BasePart", true)
		end
		scaleModelToDimension(userBloom, 3.5)
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
			pivotModelBottomFlush(planterClone, plotPos, 0.45)
			planterClone.Parent = plotModel

			local pLight = Instance.new("PointLight")
			pLight.Color = Color3.fromRGB(192, 132, 252)
			pLight.Brightness = 0.8
			pLight.Range = 8
			pLight.Parent = planterClone.PrimaryPart or planterClone:FindFirstChildWhichIsA("BasePart", true)
		end

		local soil = Instance.new("Part")
		soil.Name = "Soil"
		soil.Size = Vector3.new(5.0, 0.4, 5.0)
		soil.Position = plotPos + Vector3.new(0, 0.5, 0)
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
	-- 3. THE SACRED TRANSMUTATION ALTAR (12lQusKLlIcOsvzOzjaa)
	-- (Positioned at the head of the walkway at Z = 12)
	-- ========================================================
	local altarPos = Vector3.new(0, 0.45, 12)
	local userAltar = classifiedAssets["ALTAR"] and classifiedAssets["ALTAR"][1]
	if userAltar then
		print("  ✨ [WorldService] Deploying 3D Sacred Transmutation Altar...")
		userAltar.Name = "SacredTransmutationAltar"
		userAltar.Parent = gardenFolder
		anchorAllParts(userAltar, true)
		scaleModelToDimension(userAltar, 9.5)
		pivotModelBottomFlush(userAltar, altarPos, 0.45, math.rad(180))

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
		altarLight.Brightness = 3.0
		altarLight.Range = 20
		altarLight.Parent = promptPart
	end

	-- ========================================================
	-- 4. MASTER UNIFIED MODEL: GRAND CELESTIAL TEMPLE BACKDROP
	-- (YNrolxdcxfktT2p42Y4L — Elevated at rear overlook at Z = 28)
	-- ========================================================
	local masterUnified = classifiedAssets["MAP_UNIFIED"] and classifiedAssets["MAP_UNIFIED"][1]
	if masterUnified then
		print("  🌟 [WorldService] Deploying Grand Celestial Temple Pavilion at Rear Overlook...")
		masterUnified.Name = "GrandCelestialTemple"
		masterUnified.Parent = gardenFolder
		anchorAllParts(masterUnified, true)
		scaleModelToDimension(masterUnified, 45.0)
		pivotModelBottomFlush(masterUnified, Vector3.new(0, 0.45, 28), 0.45)
	end

	-- ========================================================
	-- 5. 4 WEEPING WILLOW TREES FRAMING ISLAND PERIMETER (B9yU9Dueystnk3wEDa6Y)
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
			scaleModelToDimension(treeClone, 20.0)
			pivotModelBottomFlush(treeClone, pos, 0.45)

			local sporePart = treeClone.PrimaryPart or treeClone:FindFirstChildWhichIsA("BasePart", true)
			if sporePart then
				local spores = Instance.new("ParticleEmitter")
				spores.Name = "WillowSpores"
				spores.Rate = 16
				spores.Lifetime = NumberRange.new(3.5, 6.0)
				spores.Speed = NumberRange.new(0.4, 1.2)
				spores.SpreadAngle = Vector2.new(50, 50)
				spores.Color = ColorSequence.new(foliageColor)
				spores.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
				spores.LightEmission = 0.85
				spores.Parent = sporePart

				local treeLight = Instance.new("PointLight")
				treeLight.Color = foliageColor
				treeLight.Brightness = 1.8
				treeLight.Range = 22
				treeLight.Parent = sporePart
			end
		end
	end

	deployWillowTree(Vector3.new(-34, 0.45, -16), Color3.fromRGB(244, 114, 182), "Willow_Pink_SouthWest")
	deployWillowTree(Vector3.new(34, 0.45, -16), Color3.fromRGB(250, 204, 21), "Willow_Gold_SouthEast")
	deployWillowTree(Vector3.new(-34, 0.45, 18), Color3.fromRGB(56, 189, 248), "Willow_Cyan_NorthWest")
	deployWillowTree(Vector3.new(34, 0.45, 18), Color3.fromRGB(56, 189, 248), "Willow_Cyan_NorthEast")

	-- ========================================================
	-- 6. EAST SATELLITE ISLAND: MARKET GAZEBO & CELESTIAL WELL
	-- ========================================================
	local satelliteTemplate = classifiedAssets["ISLAND_SATELLITE"] and classifiedAssets["ISLAND_SATELLITE"][1]
	local eastCenter = Vector3.new(68, 0.45, 0)

	local eastDeck = Instance.new("Part")
	eastDeck.Name = "EastIslandDeck"
	eastDeck.Shape = Enum.PartType.Cylinder
	eastDeck.Size = Vector3.new(2.0, 46, 46)
	eastDeck.CFrame = CFrame.new(68, -0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	eastDeck.Anchored = true
	eastDeck.CanCollide = true
	eastDeck.Material = Enum.Material.Slate
	eastDeck.Color = Color3.fromRGB(40, 34, 56)
	eastDeck.TopSurface = Enum.SurfaceType.Smooth
	eastDeck.Parent = islandFolder

	if satelliteTemplate then
		local eastRock = satelliteTemplate:Clone()
		eastRock.Name = "EastIslandCrags"
		eastRock.Parent = islandFolder
		anchorAllParts(eastRock, false)
		scaleModelToDimension(eastRock, 50.0)
		pivotIslandTopFlush(eastRock, eastCenter, 0.3)
	end

	-- Market Gazebo (88K2rZReSQ5xHd5bkrt8)
	local userGazebo = classifiedAssets["GAZEBO"] and classifiedAssets["GAZEBO"][1]
	if userGazebo then
		print("  ✨ [WorldService] Deploying Market Gazebo on East Island...")
		userGazebo.Name = "FloatingMarketGazebo"
		userGazebo.Parent = gardenFolder
		anchorAllParts(userGazebo, true)
		scaleModelToDimension(userGazebo, 16.0)
		pivotModelBottomFlush(userGazebo, Vector3.new(68, 0.45, 6), 0.45)

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

		local shopLight = Instance.new("PointLight")
		shopLight.Color = Color3.fromRGB(251, 191, 36)
		shopLight.Brightness = 2.5
		shopLight.Range = 20
		shopLight.Parent = shopPromptPart
	end

	-- Celestial Well (4WVlMWpKFjPTTOQ4RwS4)
	local userWell = classifiedAssets["WELL"] and classifiedAssets["WELL"][1]
	if userWell then
		print("  ✨ [WorldService] Deploying Celestial Well on East Island...")
		userWell.Name = "CelestialWell"
		userWell.Parent = gardenFolder
		anchorAllParts(userWell, true)
		scaleModelToDimension(userWell, 8.0)
		pivotModelBottomFlush(userWell, Vector3.new(68, 0.45, -10), 0.45)

		local wellPrompt = Instance.new("ProximityPrompt")
		wellPrompt.Name = "CelestialWellPrompt"
		wellPrompt.ActionText = "Collect Stardust"
		wellPrompt.ObjectText = "Celestial Well (AFK Vault)"
		wellPrompt.KeyboardKeyCode = Enum.KeyCode.E
		wellPrompt.HoldDuration = 0
		wellPrompt.MaxActivationDistance = 12
		wellPrompt.RequiresLineOfSight = false
		wellPrompt.Parent = userWell.PrimaryPart or userWell:FindFirstChildWhichIsA("BasePart", true)

		wellPrompt.Triggered:Connect(function(targetPlayer: Player)
			local DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
			DataService.CollectWell(targetPlayer)
		end)
	end

	-- ========================================================
	-- 7. WEST SATELLITE ISLAND: REALM GATE, MYSTERY EGG & PETS
	-- ========================================================
	local westCenter = Vector3.new(-68, 0.45, 0)

	local westDeck = Instance.new("Part")
	westDeck.Name = "WestIslandDeck"
	westDeck.Shape = Enum.PartType.Cylinder
	westDeck.Size = Vector3.new(2.0, 46, 46)
	westDeck.CFrame = CFrame.new(-68, -0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	westDeck.Anchored = true
	westDeck.CanCollide = true
	westDeck.Material = Enum.Material.Slate
	westDeck.Color = Color3.fromRGB(36, 32, 52)
	westDeck.TopSurface = Enum.SurfaceType.Smooth
	westDeck.Parent = islandFolder

	if satelliteTemplate then
		local westRock = satelliteTemplate:Clone()
		westRock.Name = "WestIslandCrags"
		westRock.Parent = islandFolder
		anchorAllParts(westRock, false)
		scaleModelToDimension(westRock, 50.0)
		pivotIslandTopFlush(westRock, westCenter, 0.3)
	end

	-- Realm Gate (K4xcbxw5JiktsVFs6Rvn)
	local userGate = classifiedAssets["GATE_ARCH"] and classifiedAssets["GATE_ARCH"][1]
	if userGate then
		print("  ✨ [WorldService] Deploying Cosmic Realm Gate on West Island...")
		userGate.Name = "AncientCosmicRealmGate"
		userGate.Parent = gardenFolder
		anchorAllParts(userGate, true)
		scaleModelToDimension(userGate, 20.0)
		pivotModelBottomFlush(userGate, Vector3.new(-68, 0.45, 8), 0.45)

		local gatePrompt = Instance.new("ProximityPrompt")
		gatePrompt.Name = "RealmGatePrompt"
		gatePrompt.ActionText = "Explore Realm"
		gatePrompt.ObjectText = "Astral Realm (Requires Rebirth 1)"
		gatePrompt.KeyboardKeyCode = Enum.KeyCode.E
		gatePrompt.HoldDuration = 0
		gatePrompt.MaxActivationDistance = 14
		gatePrompt.RequiresLineOfSight = false
		gatePrompt.Parent = userGate.PrimaryPart or userGate:FindFirstChildWhichIsA("BasePart", true)

		local gateLight = Instance.new("PointLight")
		gateLight.Color = Color3.fromRGB(56, 189, 248)
		gateLight.Brightness = 2.5
		gateLight.Range = 20
		gateLight.Parent = userGate.PrimaryPart or userGate:FindFirstChildWhichIsA("BasePart", true)
	end

	-- Celestial Mystery Egg (PftfbIAqxyQQaT0eng8J)
	local userEgg = classifiedAssets["EGG"] and classifiedAssets["EGG"][1]
	if userEgg then
		print("  ✨ [WorldService] Deploying Mystery Egg on West Island...")
		userEgg.Name = "CelestialMysteryEgg"
		userEgg.Parent = gardenFolder
		anchorAllParts(userEgg, true)
		scaleModelToDimension(userEgg, 4.5)
		pivotModelBottomFlush(userEgg, Vector3.new(-68, 0.45, -5), 0.45)

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
		eggLight.Brightness = 2.2
		eggLight.Range = 14
		eggLight.Parent = userEgg.PrimaryPart or userEgg:FindFirstChildWhichIsA("BasePart", true)
	end

	-- Astral Kitsune Companion Pet (dy37cbLWfRNgVdahv9wz)
	local userKitsune = classifiedAssets["PET_KITSUNE"] and classifiedAssets["PET_KITSUNE"][1]
	if userKitsune then
		userKitsune.Name = "AstralKitsuneDais"
		userKitsune.Parent = gardenFolder
		anchorAllParts(userKitsune, true)
		scaleModelToDimension(userKitsune, 3.5)
		pivotModelBottomFlush(userKitsune, Vector3.new(-60, 0.45, -5), 0.45, math.rad(45))

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

	-- Starlight Dragon Pet (wvKRYjmFL8CSK8TLfSXr)
	local userDragon = classifiedAssets["PET_DRAGON"] and classifiedAssets["PET_DRAGON"][1]
	if userDragon then
		userDragon.Name = "StarlightDragonDais"
		userDragon.Parent = gardenFolder
		anchorAllParts(userDragon, true)
		scaleModelToDimension(userDragon, 3.5)
		pivotModelBottomFlush(userDragon, Vector3.new(-76, 0.45, -5), 0.45, math.rad(-45))

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

	-- Amethyst Crystal Cluster Decor (bgcDryd1JXdfkwvccUxN)
	local userCrystals = classifiedAssets["DECOR_CRYSTAL"] or {}
	if #userCrystals > 0 then
		for idx, cModel in userCrystals do
			if idx <= 2 then
				local clone = cModel:Clone()
				clone.Parent = gardenFolder
				anchorAllParts(clone, true)
				scaleModelToDimension(clone, 5.0)
				pivotModelBottomFlush(clone, Vector3.new(-82 + idx * 4, 0.45, 4), 0.45)
			end
		end
	end

	-- ========================================================
	-- 8. CRYSTALLINE BRIDGES (Connecting Main Island to Satellites at ground level)
	-- ========================================================
	local function createCrystallineBridge(name: string, startX: number, endX: number, color: Color3)
		local bridgeModel = Instance.new("Model")
		bridgeModel.Name = name
		bridgeModel.Parent = gardenFolder

		local length = math.abs(endX - startX)
		local midX = (startX + endX) / 2

		local deck = Instance.new("Part")
		deck.Name = "BridgeDeck"
		deck.Size = Vector3.new(length, 0.4, 6.0)
		deck.Position = Vector3.new(midX, 0.42, 0)
		deck.Anchored = true
		deck.CanCollide = true
		deck.Material = Enum.Material.Glass
		deck.Color = color
		deck.Transparency = 0.35
		deck.Reflectance = 0.25
		deck.TopSurface = Enum.SurfaceType.Smooth
		deck.Parent = bridgeModel

		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "BridgeSparks"
		sparks.Rate = 6
		sparks.Lifetime = NumberRange.new(2, 4)
		sparks.Speed = NumberRange.new(0.3, 0.8)
		sparks.SpreadAngle = Vector2.new(30, 30)
		sparks.Color = ColorSequence.new(color)
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0) })
		sparks.LightEmission = 0.85
		sparks.Parent = deck

		return bridgeModel
	end

	createCrystallineBridge("EastCrystallineBridge", 40, 52, Color3.fromRGB(160, 210, 245))
	createCrystallineBridge("WestAmethystBridge", -40, -52, Color3.fromRGB(200, 170, 245))

	-- ========================================================
	-- 9. VOID SAFETY RESPAWN NET
	-- ========================================================
	local safetyFloor = Instance.new("Part")
	safetyFloor.Name = "SanctuarySafetyFloor"
	safetyFloor.Size = Vector3.new(1200, 4, 1200)
	safetyFloor.Position = Vector3.new(0, -38, 0)
	safetyFloor.Anchored = true
	safetyFloor.CanCollide = false
	safetyFloor.Transparency = 1
	safetyFloor.Parent = gardenFolder

	local spawnLocation = Vector3.new(0, 3.5, -30)
	local spawnLookAt = Vector3.new(0, 3.5, 0)

	local function teleportToPromenade(char: Model)
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.CFrame = CFrame.lookAt(spawnLocation, spawnLookAt)
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end

	safetyFloor.Touched:Connect(function(hit)
		local char = hit.Parent
		local p = char and Players:GetPlayerFromCharacter(char)
		if p and char:IsA("Model") then
			teleportToPromenade(char)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, p in Players:GetPlayers() do
				local char = p.Character
				if char then
					local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if hrp and hrp.Position.Y < -18 then
						teleportToPromenade(char)
					end
				end
			end
		end
	end)

	-- ========================================================
	-- 10. RELIABLE CHARACTER SPAWN POSITIONING & STARTER TOOL
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
			hrp.CFrame = CFrame.lookAt(spawnLocation, spawnLookAt)
		end
		giveStarterTool(targetPlayer)
	end

	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function(char)
			onCharacterAdded(p, char)
		end)
	end)

	for _, p in Players:GetPlayers() do
		if p.Character then
			onCharacterAdded(p, p.Character)
		end
		p.CharacterAdded:Connect(function(char)
			onCharacterAdded(p, char)
		end)
	end

	print("========================================")
	print("  ✅ [WorldService] Clean, Organized 3D Sanctuary Online!")
	print("========================================")
end

return WorldService
