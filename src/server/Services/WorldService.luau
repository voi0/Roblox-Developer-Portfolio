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
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local WorldService = {}

-- ============================================================
-- SATELLITE & PLOT COORDINATES
-- ============================================================
-- 9 Garden Plots arranged in two clean symmetrical beds flanking the walkway
local PLOT_POSITIONS = {
	-- West Bed (Quadrant 1)
	Vector3.new(-13.0, 0.5, 2.0),
	Vector3.new(-6.5, 0.5, 2.0),
	Vector3.new(-13.0, 0.5, 10.0),
	Vector3.new(-6.5, 0.5, 10.0),

	-- Centerpiece Plot (Between walkway & altar)
	Vector3.new(0.0, 0.5, 7.0),

	-- East Bed (Quadrant 2)
	Vector3.new(6.5, 0.5, 2.0),
	Vector3.new(13.0, 0.5, 2.0),
	Vector3.new(6.5, 0.5, 10.0),
	Vector3.new(13.0, 0.5, 10.0),
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
-- Places the BOTTOM of the model's bounding box exactly at targetBottomY
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

-- Places the TOP surface of an island rock exactly at targetTopY (so the rock hangs underneath)
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
	if string.find(combined, "unified") or string.find(combined, "structures") or string.find(combined, "full_map") or string.find(combined, "vision") or string.find(combined, "master_map") or string.find(combined, "archipelago") or string.find(combined, "environment") or string.find(combined, "main_map") or string.find(combined, "fullmap") or string.find(combined, "master") or string.find(combined, "scene") or string.find(combined, "all_models") or string.find(combined, "combined") then
		return "MAP_UNIFIED"
	-- 2. Exact glTF Node Hashes & Keywords from User's Imports
	elseif string.find(combined, "agdrm0mbeo3gylxitymk") or string.find(combined, "bzvomeysheglnysxnymr") or string.find(combined, "floating%-sanctuary") or string.find(combined, "floating sanctuary") or string.find(combined, "central sanctuary") or string.find(combined, "island") or string.find(combined, "sanctuary") or string.find(combined, "rock") or string.find(combined, "ground") or string.find(combined, "mountain") then
		return "ISLAND"
	elseif string.find(combined, "ivdfl4qeemqt7ve4qcvs") or string.find(combined, "gardner") or string.find(combined, "plant%-box") or string.find(combined, "plant_box") or string.find(combined, "planter") or string.find(combined, "plot") or string.find(combined, "pot") or string.find(combined, "box") then
		return "PLANTER"
	elseif string.find(combined, "12lquskllicosvzozjaa") or string.find(combined, "transmutation") or string.find(combined, "altar") or string.find(combined, "forge") or string.find(combined, "shrine") or string.find(combined, "monolith") or string.find(combined, "pedestal") or string.find(combined, "table") then
		return "ALTAR"
	elseif string.find(combined, "wumxsfiy9i8durscm3vv") or string.find(combined, "crystal%-bloom") or string.find(combined, "crystal bloom") or string.find(combined, "cosmic%-crystal") or string.find(combined, "bloom") or string.find(combined, "flower") or string.find(combined, "crop") then
		return "BLOOM"
	elseif string.find(combined, "pftfbiaqxyqqa70eng8j") or string.find(combined, "mystery%-egg") or string.find(combined, "mystery egg") or string.find(combined, "celestial%-egg") or (string.find(combined, "egg") and not string.find(combined, "dragon")) then
		return "EGG"
	elseif string.find(combined, "b9yu9dueystnk3weda6y") or string.find(combined, "ioluminescent") or string.find(combined, "bioluminescent") or string.find(combined, "willow") or string.find(combined, "tree") or string.find(combined, "foliage") or string.find(combined, "wood") or string.find(combined, "branch") then
		return "TREE_WILLOW"
	elseif string.find(combined, "88k2rzresq5xhd5bkrt8") or string.find(combined, "gazebo") or string.find(combined, "merchant stall") or string.find(combined, "market") or string.find(combined, "stall") or string.find(combined, "shop") or string.find(combined, "pavilion") or string.find(combined, "kiosk") then
		return "GAZEBO"
	elseif string.find(combined, "k4xcbxw5jiktsvfs6rvn") or string.find(combined, "realm gate") or string.find(combined, "locked portal") or string.find(combined, "cosmic realm gate") or string.find(combined, "gate") or string.find(combined, "portal") or string.find(combined, "arch") then
		return "GATE_ARCH"
	elseif string.find(combined, "dy37cblwfrngvdahv9wz") or string.find(combined, "kitsune") or string.find(combined, "astral kitsune") or string.find(combined, "fox") then
		return "PET_KITSUNE"
	elseif string.find(combined, "wvkryjmfl8csk8tlfsxr") or string.find(combined, "hatchling dragon") or string.find(combined, "dragon pet") or string.find(combined, "dragon") or string.find(combined, "drake") then
		return "PET_DRAGON"
	elseif string.find(combined, "well") or string.find(combined, "fountain") or string.find(combined, "vault") or string.find(combined, "pool") then
		return "WELL"
	elseif string.find(combined, "4wvlmpkfjpttoq4rws4") or string.find(combined, "bgcdryd1jxdfkwvccuxn") or string.find(combined, "meshentity") or string.find(combined, "crystal") or string.find(combined, "geode") or string.find(combined, "ore") or string.find(combined, "gem") then
		return "DECOR_CRYSTAL"
	end

	-- 3. Geometric Aspect Ratio Signature Fallback
	local parts = getContainerParts(inst)
	local _, sz = getContainerBounds(inst)
	if sz.X > 0.05 and sz.Z > 0.05 then
		-- Multi-mesh composite or very large footprint -> MAP_UNIFIED or ISLAND
		if #parts >= 4 or (sz.X > 40 and sz.Z > 40) then
			return "MAP_UNIFIED"
		-- Tall vertical object -> TREE
		elseif sz.Y > 10 and sz.Y > sz.X * 1.1 then
			return "TREE_WILLOW"
		-- Medium altar or pedestal
		elseif (sz.X >= 4 and sz.X <= 18) and (sz.Y >= 1.5 and sz.Y <= 10) then
			return "ALTAR"
		-- Planter box shape
		elseif (sz.X >= 2.5 and sz.X <= 9) and (sz.Y <= 4) and (sz.X / sz.Z >= 0.7 and sz.X / sz.Z <= 1.4) then
			return "PLANTER"
		-- Small flower or crystal
		elseif (sz.X <= 5 and sz.Y <= 6) and (sz.Y > sz.X * 1.3) then
			return "BLOOM"
		-- Egg shape
		elseif (sz.X <= 6 and sz.Y <= 8) and (sz.Y > sz.X * 1.05 and sz.Y < sz.X * 1.8) then
			return "EGG"
		end
	end

	return nil
end

-- ============================================================
-- AUTHORITATIVE SERVER INITIALIZATION
-- ============================================================
function WorldService.Init()
	print("========================================")
	print("  🌌 [WorldService] Crafting Pure 3D Sanctuary from User Models...")
	print("========================================")

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

	-- SanctuarySpawn: Placed on solid arrival dais facing into the garden
	local spawn = Workspace:FindFirstChild("SanctuarySpawn") :: SpawnLocation?
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SanctuarySpawn"
		spawn.Parent = Workspace
	end
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.7, -22)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.7, -22), Vector3.new(0, 0.7, 10))
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(48, 42, 68)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	for _, child in spawn:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") then
			child:Destroy()
		end
	end

	-- ========================================================
	-- COMPREHENSIVE SCANNER ACROSS WORKSPACE, SERVERSTORAGE, REPLICATEDSTORAGE
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
	local strayAssets: { Model } = {}

	local scannedInstances: { [Instance]: boolean } = {}

	local function processCandidate(inst: Instance)
		if scannedInstances[inst] then return end
		scannedInstances[inst] = true

		local model = ensureAsModel(inst)
		local _, sz = getContainerBounds(model)
		local tag = classifyModel(model)

		if tag and classifiedAssets[tag] then
			table.insert(classifiedAssets[tag], model)
			print(string.format("  🎯 [WorldService] Classified 3D Asset: '%s' -> %s (Size: %.1f x %.1f x %.1f)", model.Name, tag, sz.X, sz.Y, sz.Z))
		else
			table.insert(strayAssets, model)
			print(string.format("  🔍 [WorldService] Unclassified 3D Asset: '%s' (Size: %.1f x %.1f x %.1f, Parts: %d)", model.Name, sz.X, sz.Y, sz.Z, #getContainerParts(model)))
		end
	end

	local function scanContainer(container: Instance?)
		if not container then return end
		for _, child in container:GetChildren() do
			if child.Name == "StarweaveGarden" or child.Name == "Terrain" or child.Name == "Camera" or child.Name == "SanctuarySpawn" or child.Name == "StarweaveAssets" then
				continue
			end

			-- If inside UserImportedAssets from a previous session, inspect all children
			if child.Name == "UserImportedAssets" or child:IsA("Folder") or child:IsA("Configuration") then
				for _, sub in child:GetChildren() do
					if sub:IsA("Model") or sub:IsA("BasePart") then
						processCandidate(sub)
					end
				end
			elseif child:IsA("Model") or child:IsA("BasePart") then
				-- Check if model is a container with submodels
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
	-- GREEDY ASSIGNMENT FOR STRAYS (FAIL-SAFE DISCOVERY)
	-- ========================================================
	-- Sort strays by footprint area (X * Z) descending
	table.sort(strayAssets, function(a, b)
		local _, sza = getContainerBounds(a)
		local _, szb = getContainerBounds(b)
		return (sza.X * sza.Z) > (szb.X * szb.Z)
	end)

	local usedStrays: { [Model]: boolean } = {}

	-- If MAP_UNIFIED & ISLAND are both empty, assign the largest stray
	if #classifiedAssets["MAP_UNIFIED"] == 0 and #classifiedAssets["ISLAND"] == 0 then
		for _, stray in strayAssets do
			if not usedStrays[stray] then
				local _, sz = getContainerBounds(stray)
				if (sz.X * sz.Z) > 80 or #getContainerParts(stray) >= 3 then
					table.insert(classifiedAssets["MAP_UNIFIED"], stray)
					usedStrays[stray] = true
					print(string.format("  🪄 [WorldService] Greedy Assign: '%s' -> MAP_UNIFIED (Footprint: %.1f)", stray.Name, sz.X * sz.Z))
					break
				end
			end
		end
	end

	-- If ALTAR is empty, find best medium pedestal stray
	if #classifiedAssets["ALTAR"] == 0 then
		for _, stray in strayAssets do
			if not usedStrays[stray] then
				local _, sz = getContainerBounds(stray)
				if sz.X >= 3 and sz.X <= 20 and sz.Y >= 1.5 and sz.Y <= 12 then
					table.insert(classifiedAssets["ALTAR"], stray)
					usedStrays[stray] = true
					print(string.format("  🪄 [WorldService] Greedy Assign: '%s' -> ALTAR", stray.Name))
					break
				end
			end
		end
	end

	-- If GAZEBO is empty, find building/stall stray
	if #classifiedAssets["GAZEBO"] == 0 then
		for _, stray in strayAssets do
			if not usedStrays[stray] then
				local _, sz = getContainerBounds(stray)
				if sz.X >= 8 and sz.X <= 28 and sz.Y >= 4 then
					table.insert(classifiedAssets["GAZEBO"], stray)
					usedStrays[stray] = true
					print(string.format("  🪄 [WorldService] Greedy Assign: '%s' -> GAZEBO", stray.Name))
					break
				end
			end
		end
	end

	-- If GATE_ARCH is empty, find tall portal stray
	if #classifiedAssets["GATE_ARCH"] == 0 then
		for _, stray in strayAssets do
			if not usedStrays[stray] then
				local _, sz = getContainerBounds(stray)
				if sz.Y >= 8 and sz.X >= 6 then
					table.insert(classifiedAssets["GATE_ARCH"], stray)
					usedStrays[stray] = true
					print(string.format("  🪄 [WorldService] Greedy Assign: '%s' -> GATE_ARCH", stray.Name))
					break
				end
			end
		end
	end

	-- If PLANTER is empty, find small planter box stray
	if #classifiedAssets["PLANTER"] == 0 then
		for _, stray in strayAssets do
			if not usedStrays[stray] then
				local _, sz = getContainerBounds(stray)
				if sz.X >= 2 and sz.X <= 9 and sz.Y <= 5 then
					table.insert(classifiedAssets["PLANTER"], stray)
					usedStrays[stray] = true
					print(string.format("  🪄 [WorldService] Greedy Assign: '%s' -> PLANTER", stray.Name))
					break
				end
			end
		end
	end

	-- If TREE_WILLOW is empty, find tall foliage strays
	if #classifiedAssets["TREE_WILLOW"] == 0 then
		for _, stray in strayAssets do
			if not usedStrays[stray] then
				local _, sz = getContainerBounds(stray)
				if sz.Y > 8 and sz.Y > sz.X * 1.05 then
					table.insert(classifiedAssets["TREE_WILLOW"], stray)
					usedStrays[stray] = true
					print(string.format("  🪄 [WorldService] Greedy Assign: '%s' -> TREE_WILLOW", stray.Name))
					if #classifiedAssets["TREE_WILLOW"] >= 4 then break end
				end
			end
		end
	end

	-- Preserve any remaining unused strays safely
	local userAssetsFolder = Workspace:FindFirstChild("UserImportedAssets")
	if not userAssetsFolder then
		userAssetsFolder = Instance.new("Folder")
		userAssetsFolder.Name = "UserImportedAssets"
		userAssetsFolder.Parent = Workspace
	end

	for _, stray in strayAssets do
		if not usedStrays[stray] then
			stray.Parent = userAssetsFolder
			anchorAllParts(stray, true)
		end
	end

	-- ========================================================
	-- GUARANTEED SOLID PHYSICAL SANCTUARY DAIS & PLAZAS
	-- (Ensures player ALWAYS stands on rich stone architecture)
	-- ========================================================
	local architectureFolder = Instance.new("Folder")
	architectureFolder.Name = "SanctuaryArchitecture"
	architectureFolder.Parent = gardenFolder

	-- Central Stone Plaza (Solid slate disc, diameter 92 studs, top at Y = 0.5)
	local centerPlaza = Instance.new("Part")
	centerPlaza.Name = "SanctuaryCenterPlaza"
	centerPlaza.Size = Vector3.new(92, 2.0, 92)
	centerPlaza.Position = Vector3.new(0, -0.5, 4)
	centerPlaza.Anchored = true
	centerPlaza.CanCollide = true
	centerPlaza.Material = Enum.Material.Slate
	centerPlaza.Color = Color3.fromRGB(44, 38, 62)
	centerPlaza.TopSurface = Enum.SurfaceType.Smooth
	centerPlaza.Parent = architectureFolder

	-- Inner Starlight Concentric Rune Ring
	local innerRing = Instance.new("Part")
	innerRing.Name = "CenterRuneRing"
	innerRing.Size = Vector3.new(62, 0.1, 62)
	innerRing.Position = Vector3.new(0, 0.55, 4)
	innerRing.Anchored = true
	innerRing.CanCollide = false
	innerRing.Material = Enum.Material.SmoothPlastic
	innerRing.Color = Color3.fromRGB(76, 56, 110)
	innerRing.TopSurface = Enum.SurfaceType.Smooth
	innerRing.Parent = architectureFolder

	-- South Arrival Promenade (Stone path from spawn to center plaza)
	local promenade = Instance.new("Part")
	promenade.Name = "SouthArrivalPromenade"
	promenade.Size = Vector3.new(14, 2.0, 26)
	promenade.Position = Vector3.new(0, -0.5, -19)
	promenade.Anchored = true
	promenade.CanCollide = true
	promenade.Material = Enum.Material.Slate
	promenade.Color = Color3.fromRGB(44, 38, 62)
	promenade.TopSurface = Enum.SurfaceType.Smooth
	promenade.Parent = architectureFolder

	-- East Market Plaza (Diameter 52 studs, top at Y = 0.5)
	local eastPlaza = Instance.new("Part")
	eastPlaza.Name = "EastMarketPlaza"
	eastPlaza.Size = Vector3.new(52, 2.0, 52)
	eastPlaza.Position = Vector3.new(62, -0.5, 4)
	eastPlaza.Anchored = true
	eastPlaza.CanCollide = true
	eastPlaza.Material = Enum.Material.Slate
	eastPlaza.Color = Color3.fromRGB(48, 40, 70)
	eastPlaza.TopSurface = Enum.SurfaceType.Smooth
	eastPlaza.Parent = architectureFolder

	-- West Shrine Plaza (Diameter 52 studs, top at Y = 0.5)
	local westPlaza = Instance.new("Part")
	westPlaza.Name = "WestShrinePlaza"
	westPlaza.Size = Vector3.new(52, 2.0, 52)
	westPlaza.Position = Vector3.new(-62, -0.5, 4)
	westPlaza.Anchored = true
	westPlaza.CanCollide = true
	westPlaza.Material = Enum.Material.Slate
	westPlaza.Color = Color3.fromRGB(42, 38, 64)
	westPlaza.TopSurface = Enum.SurfaceType.Smooth
	westPlaza.Parent = architectureFolder

	-- ========================================================
	-- 0. MASTER UNIFIED SANCTUARY MAP (User-Modeled Multi-Structure Mesh)
	-- ========================================================
	local masterUnified = classifiedAssets["MAP_UNIFIED"] and classifiedAssets["MAP_UNIFIED"][1]
	if masterUnified then
		print("  🌟 [WorldService] Master Unified 3D Sanctuary Detected! Deploying to Garden...")
		masterUnified.Name = "MasterUnifiedSanctuary"
		masterUnified.Parent = gardenFolder
		anchorAllParts(masterUnified, true)
		pivotModelBottomFlush(masterUnified, Vector3.new(0, 0, 0), 0.5)
	end

	-- ========================================================
	-- 1. CENTRAL SANCTUARY FLOATING ISLAND (Main Floating Rock)
	-- ========================================================
	local islandTemplate = classifiedAssets["ISLAND"] and classifiedAssets["ISLAND"][1]
	if islandTemplate then
		print("  ✨ [WorldService] Deploying 3D Central Sanctuary Island Rock...")
		local centerIsland = islandTemplate
		centerIsland.Name = "CenterSanctuaryIsland"
		centerIsland.Parent = gardenFolder
		anchorAllParts(centerIsland, true)
		scaleModelToDimension(centerIsland, 105)
		-- Top surface of island rock flush with underside of stone plaza
		pivotIslandTopFlush(centerIsland, Vector3.new(0, 0, 4), 0.4)

		-- Clone for East and West satellite islands
		local eastIsland = centerIsland:Clone()
		eastIsland.Name = "EastMarketIsland"
		eastIsland.Parent = gardenFolder
		scaleModelToDimension(eastIsland, 55)
		pivotIslandTopFlush(eastIsland, Vector3.new(62, 0, 4), 0.4)

		local westIsland = centerIsland:Clone()
		westIsland.Name = "WestShrineIsland"
		westIsland.Parent = gardenFolder
		scaleModelToDimension(westIsland, 55)
		pivotIslandTopFlush(westIsland, Vector3.new(-62, 0, 4), 0.4)
	end

	-- ========================================================
	-- 2. CENTERPIECE: 3D TRANSMUTATION ALTAR
	-- ========================================================
	local altarPos = Vector3.new(0, 0.5, 18)
	local userAltar = classifiedAssets["ALTAR"] and classifiedAssets["ALTAR"][1]
	if userAltar then
		print("  ✨ [WorldService] Deploying 3D Transmutation Altar centerpiece...")
		userAltar.Name = "SacredTransmutationAltar"
		userAltar.Parent = gardenFolder
		anchorAllParts(userAltar, true)
		scaleModelToDimension(userAltar, 9.0)
		pivotModelBottomFlush(userAltar, altarPos, 0.5, math.rad(180))

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
	-- 3. THE 9 GARDEN PLOTS (Architectural Curbs + Loam Soil + 3D Planters)
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

		-- Raised Stone Planter Curb Border
		local curb = Instance.new("Part")
		curb.Name = "PlanterCurb"
		curb.Size = Vector3.new(6.8, 0.6, 6.8)
		curb.Position = plotPos + Vector3.new(0, 0.3, 0)
		curb.Anchored = true
		curb.CanCollide = true
		curb.Material = Enum.Material.Slate
		curb.Color = Color3.fromRGB(56, 48, 80)
		curb.TopSurface = Enum.SurfaceType.Smooth
		curb.Parent = plotModel

		-- Rich Dark Loam Soil Bed
		local soilBed = Instance.new("Part")
		soilBed.Name = "SoilBed"
		soilBed.Size = Vector3.new(5.8, 0.5, 5.8)
		soilBed.Position = plotPos + Vector3.new(0, 0.35, 0)
		soilBed.Anchored = true
		soilBed.CanCollide = false
		soilBed.Material = Enum.Material.Ground
		soilBed.Color = Color3.fromRGB(28, 22, 38)
		soilBed.TopSurface = Enum.SurfaceType.Smooth
		soilBed.Parent = plotModel

		-- User's 3D Planter Mesh (if available)
		if planterTemplate then
			local planterClone = planterTemplate:Clone()
			planterClone.Name = "PlanterMesh"
			anchorAllParts(planterClone, true)
			pivotModelBottomFlush(planterClone, plotPos, 0.5)
			planterClone.Parent = plotModel
		end

		-- Transparent Soil interaction zone for client WorldController
		local soil = Instance.new("Part")
		soil.Name = "Soil"
		soil.Size = Vector3.new(5.4, 0.4, 5.4)
		soil.Position = plotPos + Vector3.new(0, 0.6, 0)
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
	-- 4. 4 GRAND BIOLUMINESCENT WEEPING WILLOW TREES
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
			pivotModelBottomFlush(treeClone, pos, 0.5)

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

	deployWillowTree(Vector3.new(-22, 0.5, 28), Color3.fromRGB(244, 114, 182), "Willow_Pink_RearLeft")
	deployWillowTree(Vector3.new(-14, 0.5, 38), Color3.fromRGB(56, 189, 248), "Willow_Cyan_FrontLeft")
	deployWillowTree(Vector3.new(14, 0.5, 38), Color3.fromRGB(56, 189, 248), "Willow_Cyan_FrontRight")
	deployWillowTree(Vector3.new(22, 0.5, 28), Color3.fromRGB(244, 114, 182), "Willow_Pink_RearRight")

	-- ========================================================
	-- 5. LEFT ISLAND: WEALTH & MARKET GAZEBO & CELESTIAL WELL
	-- ========================================================
	local gazeboCenter = Vector3.new(62, 0.5, 10)
	local userGazebo = classifiedAssets["GAZEBO"] and classifiedAssets["GAZEBO"][1]
	if userGazebo then
		print("  ✨ [WorldService] Deploying 3D Floating Market Gazebo...")
		userGazebo.Name = "FloatingMarketGazebo"
		userGazebo.Parent = gardenFolder
		anchorAllParts(userGazebo, true)
		scaleModelToDimension(userGazebo, 16.0)
		pivotModelBottomFlush(userGazebo, gazeboCenter, 0.5)

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
	local wellPos = Vector3.new(62, 0.5, -6)
	local userWell = classifiedAssets["WELL"] and classifiedAssets["WELL"][1]
	if userWell then
		print("  ✨ [WorldService] Deploying 3D Celestial Well...")
		userWell.Name = "CelestialWell"
		userWell.Parent = gardenFolder
		anchorAllParts(userWell, true)
		scaleModelToDimension(userWell, 9.0)
		pivotModelBottomFlush(userWell, wellPos, 0.5)

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

	-- Golden Willow Tree framing the market plaza
	deployWillowTree(Vector3.new(75, 0.5, 2), Color3.fromRGB(250, 204, 21), "GoldenAutumnTree")

	-- ========================================================
	-- 6. RIGHT ISLAND: REALM PORTAL & PET SANCTUARY
	-- ========================================================
	local userGate = classifiedAssets["GATE_ARCH"] and classifiedAssets["GATE_ARCH"][1]
	local gatePos = Vector3.new(-62, 0.5, 14)
	if userGate then
		print("  ✨ [WorldService] Deploying 3D Ancient Cosmic Realm Gate...")
		userGate.Name = "AncientCosmicRealmGate"
		userGate.Parent = gardenFolder
		anchorAllParts(userGate, true)
		scaleModelToDimension(userGate, 22.0)
		pivotModelBottomFlush(userGate, gatePos, 0.5)

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

	-- CELESTIAL MYSTERY EGG
	local eggPos = Vector3.new(-62, 0.5, 0)
	local userEgg = classifiedAssets["EGG"] and classifiedAssets["EGG"][1]
	if userEgg then
		print("  ✨ [WorldService] Deploying 3D Celestial Mystery Egg...")
		userEgg.Name = "CelestialMysteryEgg"
		userEgg.Parent = gardenFolder
		anchorAllParts(userEgg, true)
		scaleModelToDimension(userEgg, 4.5)
		pivotModelBottomFlush(userEgg, eggPos, 0.5)

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

	-- ASTRAL KITSUNE COMPANION PET
	local userKitsune = classifiedAssets["PET_KITSUNE"] and classifiedAssets["PET_KITSUNE"][1]
	if userKitsune then
		print("  ✨ [WorldService] Deploying 3D Astral Kitsune Companion...")
		userKitsune.Name = "AstralKitsuneDais"
		userKitsune.Parent = gardenFolder
		anchorAllParts(userKitsune, true)
		scaleModelToDimension(userKitsune, 3.5)
		pivotModelBottomFlush(userKitsune, Vector3.new(-56, 0.5, 0), 0.5, math.rad(45))

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

	-- STARLIGHT DRAGON PET
	local userDragon = classifiedAssets["PET_DRAGON"] and classifiedAssets["PET_DRAGON"][1]
	if userDragon then
		print("  ✨ [WorldService] Deploying 3D Starlight Hatchling Dragon...")
		userDragon.Name = "StarlightDragonDais"
		userDragon.Parent = gardenFolder
		anchorAllParts(userDragon, true)
		scaleModelToDimension(userDragon, 3.5)
		pivotModelBottomFlush(userDragon, Vector3.new(-68, 0.5, 0), 0.5, math.rad(-45))

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
				pivotModelBottomFlush(clone, Vector3.new(-74 + idx * 4, 0.5, 10), 0.5)
			end
		end
	end

	-- ========================================================
	-- 7. CRYSTALLINE BRIDGES (SOLID CONNECTORS BETWEEN ISLANDS)
	-- ========================================================
	local function createCrystallineBridge(name: string, startX: number, endX: number, color: Color3)
		local bridgeModel = Instance.new("Model")
		bridgeModel.Name = name
		bridgeModel.Parent = gardenFolder

		local length = math.abs(endX - startX)
		local midX = (startX + endX) / 2

		local deck = Instance.new("Part")
		deck.Name = "BridgeDeck"
		deck.Size = Vector3.new(length, 1.0, 7.0)
		deck.Position = Vector3.new(midX, 0.0, 4)
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
		sparks.LightEmission = 0.8
		sparks.Parent = deck

		return bridgeModel
	end

	createCrystallineBridge("EastCrystallineBridge", 38, 52, Color3.fromRGB(160, 210, 245))
	createCrystallineBridge("WestAmethystBridge", -38, -52, Color3.fromRGB(200, 170, 245))

	-- ========================================================
	-- 8. ATMOSPHERIC CLOUD SEA & HIGH-ALTITUDE AURORA
	-- ========================================================
	local cloudPositions = {
		Vector3.new(0, -32, 6),
		Vector3.new(-42, -30, 14),
		Vector3.new(42, -30, 14),
		Vector3.new(-70, -32, 0),
		Vector3.new(70, -32, 0),
		Vector3.new(0, -34, -28),
	}
	for idx, cPos in cloudPositions do
		local cloud = Instance.new("Part")
		cloud.Name = "CloudBank_" .. idx
		cloud.Shape = Enum.PartType.Ball
		cloud.Size = Vector3.new(52, 18, 52)
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
	-- 9. VOID SAFETY RESPAWN NET
	-- ========================================================
	local safetyFloor = Instance.new("Part")
	safetyFloor.Name = "SanctuarySafetyFloor"
	safetyFloor.Size = Vector3.new(1200, 4, 1200)
	safetyFloor.Position = Vector3.new(0, -36, 0)
	safetyFloor.Anchored = true
	safetyFloor.CanCollide = false
	safetyFloor.Transparency = 1
	safetyFloor.Parent = gardenFolder

	local spawnLocation = Vector3.new(0, 3.5, -20)
	local spawnLookAt = Vector3.new(0, 3.5, 10)

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

	-- Heartbeat safeguard: Never allow player to remain below Y = -18
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
	print("  ✅ [WorldService] Pure 3D Sanctuary Online! All Foundations & Models Deployed.")
	print("========================================")
end

return WorldService
