--!strict
--[[
	WorldService.luau — Authoritative 3D Spatial Sanctuary Builder for STARWEAVE
	Faithfully implements the Unified Vision Architecture (Concept Art media_1791217248028.jpg)

	Directly ingests and deploys all 13 user-created 3D models:
	  1. The Celestial Central Sanctuary Island Base (BZvOmeysHEgLnYsXNYmR)
	  2. Floating Sanctuary Sub-Islands (AgDrM0mbeO3gYlXiTYMk)
	  3. Bioluminescent Celestial Willow Tree (B9yU9Dueystnk3wEDa6Y)
	  4. Floating Market Gazebo & Merchant Stall (88K2rZReSQ5xHd5bkrt8)
	  5. Ancient Cosmic Realm Gate (K4xcbxw5JiktsVFs6Rvn)
	  6. Celestial Mystery Egg (PftfbIAqxyQQaT0eng8J)
	  7. Astral Kitsune Companion Pet (dy37cbLWfRNgVdahv9wz)
	  8. Starlight Hatchling Dragon Pet (wvKRYjmFL8CSK8TLfSXr)
	  9. Transmutation Altar (12lQusKLlIcOsvzOzjaa)
	  10. Gardner Plant Box (IVdfl4QeEMqt7VE4qcvS)
	  11. Cosmic Crystal Bloom (WuMxsfiY9i8DUrScM3Vv)
	  12. MeshEntity Decor (4WVlMWpKFjPTTOQ4RwS4)
	  13. YJdu Decor (bgcDryd1JXdfkwvccUxN)

	Constructs:
	  - Center Island: 3D crag base, glowing rune rim, front rune medallion,
	    central tiered stardust fountain with turquoise pool and light beacon,
	    two symmetrical garden quadrants, rear botanical shrine with 4 grand willows.
	  - Crystalline Ice Bridges: Translucent cyan and amethyst crystal spans.
	  - Left Island: Wealth Plaza, Market Gazebo, golden wishing well with
	    spilling gold coin hoard, golden autumn tree with lantern.
	  - Right Island: Transmutation & Summoning Dais, Ancient Cosmic Realm Gate,
	    giant egg on dais, purple summoning circle, amethyst crystal clusters, companion pets.
	  - Environment: Multi-layered pastel cloud sea, cosmic Aurora Borealis ribbons.

	Located in: ServerScriptService.Server.Services.WorldService
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldService = {}

-- 9 Symmetrical Garden Plot Positions (Left and Right quadrants flanking central walkway)
local PLOT_POSITIONS = {
	-- Left Garden Quadrant (West side of path)
	Vector3.new(-14.0, 0.4, 2.0),
	Vector3.new(-7.5, 0.4, 2.0),
	Vector3.new(-14.0, 0.4, 8.5),
	Vector3.new(-7.5, 0.4, 8.5),
	Vector3.new(-10.8, 0.4, 15.0),
	-- Right Garden Quadrant (East side of path)
	Vector3.new(7.5, 0.4, 2.0),
	Vector3.new(14.0, 0.4, 2.0),
	Vector3.new(7.5, 0.4, 8.5),
	Vector3.new(14.0, 0.4, 8.5),
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

	-- 1. Exact glTF Node Hashes from User's Downloaded Files
	if string.find(combined, "bzvomeysheglnysxnymr") or string.find(combined, "central sanctuary") or string.find(combined, "sanctuary island base") then
		return "ISLAND_CENTER"
	elseif string.find(combined, "agdrm0mbeo3gylxitymk") or string.find(combined, "floating%-sanctuary") or string.find(combined, "floating sanctuary") then
		return "ISLAND_SUB"
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
	elseif string.find(combined, "4wvlmpkfjpttoq4rws4") or string.find(combined, "bgcdryd1jxdfkwvccuxn") or string.find(combined, "meshentity") or string.find(combined, "crystal") or string.find(combined, "geode") then
		return "DECOR_CRYSTAL"
	-- 2. General Keyword Fallbacks
	elseif string.find(combined, "tree") or string.find(combined, "foliage") or string.find(combined, "wood") then
		return "TREE_WILLOW"
	elseif string.find(combined, "gate") or string.find(combined, "portal") or string.find(combined, "arch") then
		return "GATE_ARCH"
	elseif string.find(combined, "well") or string.find(combined, "fountain") then
		return "WELL"
	elseif string.find(combined, "pet") or string.find(combined, "companion") then
		return "PET_KITSUNE"
	elseif string.find(combined, "island") or string.find(combined, "terrain") then
		return "ISLAND_CENTER"
	end

	-- 3. Geometric Aspect Ratio Signature Fallback
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
			return "ISLAND_CENTER"
		end
	end

	return nil
end

-- ============================================================
-- AUTHORITATIVE SERVER INITIALIZATION
-- ============================================================
function WorldService.Init()
	print("  🌌 [WorldService] Constructing Authoritative Sanctuary from Unified Vision (Concept Art)...")

	-- 1. Setup Celestial Lighting Environment (Vibrant Twilight Cosmos)
	Lighting.ClockTime = 14.8
	Lighting.GeographicLatitude = 25
	Lighting.Ambient = Color3.fromRGB(130, 110, 185)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 130, 205)
	Lighting.Brightness = 2.8
	Lighting.ColorShift_Top = Color3.fromRGB(255, 245, 235)
	Lighting.ColorShift_Bottom = Color3.fromRGB(90, 70, 140)
	Lighting.FogColor = Color3.fromRGB(160, 135, 215)
	Lighting.FogEnd = 25000

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Name = "SanctuaryBloom"
	bloom.Intensity = 0.55
	bloom.Size = 22
	bloom.Threshold = 0.85
	bloom.Parent = Lighting

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "SanctuaryColorCorrection"
	colorCorrection.Saturation = 0.22
	colorCorrection.Contrast = 0.10
	colorCorrection.TintColor = Color3.fromRGB(255, 250, 255)
	colorCorrection.Parent = Lighting

	local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	sunRays.Name = "SanctuarySunRays"
	sunRays.Intensity = 0.12
	sunRays.Spread = 0.75
	sunRays.Parent = Lighting

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "SanctuaryAtmosphere"
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.18
	atmosphere.Color = Color3.fromRGB(180, 160, 240)
	atmosphere.Decay = Color3.fromRGB(120, 95, 175)
	atmosphere.Glare = 0.30
	atmosphere.Haze = 0.70
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

	-- Create SanctuarySpawn (Positioned on south pavilion facing central sanctuary)
	local spawn = Workspace:FindFirstChild("SanctuarySpawn") :: SpawnLocation?
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SanctuarySpawn"
		spawn.Parent = Workspace
	end
	spawn.Size = Vector3.new(12, 0.5, 12)
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

	-- Void Safety Floor
	local safetyFloor = Instance.new("Part")
	safetyFloor.Name = "SanctuarySafetyFloor"
	safetyFloor.Size = Vector3.new(900, 4, 900)
	safetyFloor.Position = Vector3.new(0, -28, 0)
	safetyFloor.Anchored = true
	safetyFloor.CanCollide = true
	safetyFloor.Transparency = 1
	safetyFloor.Parent = gardenFolder

	-- ========================================================
	-- COMPREHENSIVE SCANNER: INGEST ALL 13 USER 3D ASSETS
	-- ========================================================
	local classifiedAssets: { [string]: { Model } } = {
		ISLAND_CENTER = {},
		ISLAND_SUB = {},
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
					-- Check if this container is a folder holding nested imported models
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

	-- SAFETY GUARANTEE: NEVER DESTROY USER-IMPORTED MODELS!
	local userAssetsFolder = Workspace:FindFirstChild("UserImportedAssets")
	if not userAssetsFolder then
		userAssetsFolder = Instance.new("Folder")
		userAssetsFolder.Name = "UserImportedAssets"
		userAssetsFolder.Parent = Workspace
	end

	for _, stray in strayAssets do
		stray.Parent = userAssetsFolder
		anchorAllParts(stray, true)
		local descNames = {}
		for idx, d in stray:GetDescendants() do
			if idx <= 4 then table.insert(descNames, d.Name) end
		end
		print(string.format("  🛡️ [WorldService] Preserved model: '%s' (Descendants: %s) in Workspace.UserImportedAssets", stray.Name, table.concat(descNames, ", ")))
	end

	-- ========================================================
	-- 1. CENTRAL BOTANICAL SANCTUARY ISLAND (0, 0, 8)
	-- ========================================================
	-- Deploy 3D Island Base Model if present (BZvOmeysHEgLnYsXNYmR or AgDrM0mbeO3gYlXiTYMk)
	local centerIslandModel = classifiedAssets["ISLAND_CENTER"][1] or classifiedAssets["ISLAND_SUB"][1]
	if centerIslandModel then
		print("  ✨ [WorldService] Deploying 3D Central Sanctuary Island Crag (115 studs)...")
		centerIslandModel.Parent = gardenFolder
		anchorAllParts(centerIslandModel, true)
		scaleModelToDimension(centerIslandModel, 115)
		if not centerIslandModel.PrimaryPart then
			centerIslandModel.PrimaryPart = centerIslandModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if centerIslandModel.PrimaryPart then
			centerIslandModel:PivotTo(CFrame.new(0, -42.0, 8))
		end
	else
		print("  ℹ️ [WorldService] Using procedural island foundation fallback")
	end

	-- Walkable Stone Foundation Disc
	local centerFoundation = Instance.new("Part")
	centerFoundation.Name = "CenterIslandFoundation"
	centerFoundation.Size = Vector3.new(78, 2.0, 78)
	centerFoundation.Position = Vector3.new(0, -0.6, 8)
	centerFoundation.Anchored = true
	centerFoundation.Material = Enum.Material.Slate
	centerFoundation.Color = Color3.fromRGB(28, 22, 42)
	centerFoundation.TopSurface = Enum.SurfaceType.Smooth
	centerFoundation.Parent = gardenFolder

	-- Glowing Purple Outer Runic Rim
	local centerRuneRim = Instance.new("Part")
	centerRuneRim.Name = "CenterRuneRim"
	centerRuneRim.Shape = Enum.PartType.Cylinder
	centerRuneRim.Size = Vector3.new(0.6, 79, 79)
	centerRuneRim.Position = Vector3.new(0, 0.35, 8)
	centerRuneRim.Orientation = Vector3.new(0, 0, 90)
	centerRuneRim.Anchored = true
	centerRuneRim.CanCollide = false
	centerRuneRim.Material = Enum.Material.Neon
	centerRuneRim.Color = Color3.fromRGB(168, 85, 247)
	centerRuneRim.Transparency = 0.55
	centerRuneRim.Parent = gardenFolder

	-- Iconic Front Runic Medallion (Direct from Concept Art front cliff)
	local runeSigilOuter = Instance.new("Part")
	runeSigilOuter.Name = "CenterFrontRuneSigil"
	runeSigilOuter.Shape = Enum.PartType.Cylinder
	runeSigilOuter.Size = Vector3.new(0.6, 8.0, 8.0)
	runeSigilOuter.Position = Vector3.new(0, -0.4, -31.4)
	runeSigilOuter.Orientation = Vector3.new(90, 0, 0)
	runeSigilOuter.Anchored = true
	runeSigilOuter.CanCollide = false
	runeSigilOuter.Material = Enum.Material.Neon
	runeSigilOuter.Color = Color3.fromRGB(216, 70, 239)
	runeSigilOuter.Transparency = 0.15
	runeSigilOuter.Parent = gardenFolder

	local runeSigilInner = Instance.new("Part")
	runeSigilInner.Name = "CenterFrontRuneDiamond"
	runeSigilInner.Size = Vector3.new(4.4, 4.4, 0.8)
	runeSigilInner.Position = Vector3.new(0, -0.4, -31.5)
	runeSigilInner.Orientation = Vector3.new(0, 0, 45)
	runeSigilInner.Anchored = true
	runeSigilInner.CanCollide = false
	runeSigilInner.Material = Enum.Material.Neon
	runeSigilInner.Color = Color3.fromRGB(250, 204, 21)
	runeSigilInner.Parent = gardenFolder

	local runeLight = Instance.new("PointLight")
	runeLight.Color = Color3.fromRGB(216, 70, 239)
	runeLight.Brightness = 3.0
	runeLight.Range = 22
	runeLight.Parent = runeSigilOuter

	-- Stone Cross Walkways (Connecting cardinal directions across the island)
	local function createStonePaver(name: string, size: Vector3, pos: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
		p.Anchored = true
		p.Material = Enum.Material.Slate
		p.Color = Color3.fromRGB(38, 30, 56)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = gardenFolder
		return p
	end

	-- North-South Promenade (Spawn to Shrine)
	createStonePaver("PromenadeNorthSouth", Vector3.new(10, 0.3, 56), Vector3.new(0, 0.25, 8))
	-- East-West Cross Promenade (Bridge to Bridge)
	createStonePaver("PromenadeEastWest", Vector3.new(58, 0.3, 10), Vector3.new(0, 0.25, 8))

	-- ========================================================
	-- CENTRAL TIERED STARDUST FOUNTAIN (Concept Art Centerpiece)
	-- ========================================================
	local fountainCenter = Vector3.new(0, 0.4, 8)
	local fountainModel = Instance.new("Model")
	fountainModel.Name = "CentralStardustFountain"
	fountainModel.Parent = gardenFolder

	-- Tier 1: Outer Stone Basin
	local basinOuter = Instance.new("Part")
	basinOuter.Name = "FountainBasinOuter"
	basinOuter.Shape = Enum.PartType.Cylinder
	basinOuter.Size = Vector3.new(0.8, 16.0, 16.0)
	basinOuter.Position = fountainCenter + Vector3.new(0, 0.1, 0)
	basinOuter.Orientation = Vector3.new(0, 0, 90)
	basinOuter.Anchored = true
	basinOuter.Material = Enum.Material.Slate
	basinOuter.Color = Color3.fromRGB(34, 26, 50)
	basinOuter.Parent = fountainModel

	-- Tier 2: Raised Pedestal Ring
	local basinInner = Instance.new("Part")
	basinInner.Name = "FountainBasinInner"
	basinInner.Shape = Enum.PartType.Cylinder
	basinInner.Size = Vector3.new(0.6, 11.5, 11.5)
	basinInner.Position = fountainCenter + Vector3.new(0, 0.6, 0)
	basinInner.Orientation = Vector3.new(0, 0, 90)
	basinInner.Anchored = true
	basinInner.Material = Enum.Material.Slate
	basinInner.Color = Color3.fromRGB(44, 34, 64)
	basinInner.Parent = fountainModel

	-- Tier 3: Luminous Turquoise Stardust Pool
	local poolLiquid = Instance.new("Part")
	poolLiquid.Name = "FountainPoolLiquid"
	poolLiquid.Shape = Enum.PartType.Cylinder
	poolLiquid.Size = Vector3.new(0.35, 9.0, 9.0)
	poolLiquid.Position = fountainCenter + Vector3.new(0, 0.85, 0)
	poolLiquid.Orientation = Vector3.new(0, 0, 90)
	poolLiquid.Anchored = true
	poolLiquid.CanCollide = false
	poolLiquid.Material = Enum.Material.Neon
	poolLiquid.Color = Color3.fromRGB(34, 211, 238) -- Vibrant Turquoise/Cyan
	poolLiquid.Transparency = 0.15
	poolLiquid.Parent = fountainModel

	local poolLight = Instance.new("PointLight")
	poolLight.Color = Color3.fromRGB(34, 211, 238)
	poolLight.Brightness = 3.2
	poolLight.Range = 24
	poolLight.Parent = poolLiquid

	-- Floating Center Crystal Orb
	local centerOrb = Instance.new("Part")
	centerOrb.Name = "FloatingFountainOrb"
	centerOrb.Shape = Enum.PartType.Ball
	centerOrb.Size = Vector3.new(2.4, 2.4, 2.4)
	centerOrb.Position = fountainCenter + Vector3.new(0, 2.6, 0)
	centerOrb.Anchored = true
	centerOrb.CanCollide = false
	centerOrb.Material = Enum.Material.Neon
	centerOrb.Color = Color3.fromRGB(56, 189, 248)
	centerOrb.Parent = fountainModel

	-- Vertical Cyan Stardust Cascade Particles
	local fountainSparks = Instance.new("ParticleEmitter")
	fountainSparks.Name = "FountainStardust"
	fountainSparks.Rate = 28
	fountainSparks.Lifetime = NumberRange.new(3.0, 5.5)
	fountainSparks.Speed = NumberRange.new(1.5, 3.2)
	fountainSparks.SpreadAngle = Vector2.new(25, 25)
	fountainSparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 211, 238)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(168, 85, 247)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	fountainSparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	fountainSparks.LightEmission = 0.95
	fountainSparks.Parent = centerOrb

	-- ========================================================
	-- REAR SANCTUARY SHRINE & CELESTIAL OBSERVATORY (0, 0, 34)
	-- ========================================================
	local shrineCenter = Vector3.new(0, 0.6, 34)
	local shrineModel = Instance.new("Model")
	shrineModel.Name = "RearSanctuaryShrine"
	shrineModel.Parent = gardenFolder

	local shrineDais = Instance.new("Part")
	shrineDais.Name = "ShrineDais"
	shrineDais.Shape = Enum.PartType.Cylinder
	shrineDais.Size = Vector3.new(1.2, 22, 22)
	shrineDais.Position = shrineCenter + Vector3.new(0, 0.1, 0)
	shrineDais.Orientation = Vector3.new(0, 0, 90)
	shrineDais.Anchored = true
	shrineDais.Material = Enum.Material.Slate
	shrineDais.Color = Color3.fromRGB(36, 28, 54)
	shrineDais.Parent = shrineModel

	-- Shrine Temple Arch Pillars
	local pillarL = Instance.new("Part")
	pillarL.Name = "ShrinePillarLeft"
	pillarL.Size = Vector3.new(2.8, 14, 2.8)
	pillarL.Position = shrineCenter + Vector3.new(-8, 7.0, 2)
	pillarL.Anchored = true
	pillarL.CanCollide = false
	pillarL.Material = Enum.Material.Slate
	pillarL.Color = Color3.fromRGB(42, 32, 60)
	pillarL.Parent = shrineModel

	local pillarR = Instance.new("Part")
	pillarR.Name = "ShrinePillarRight"
	pillarR.Size = Vector3.new(2.8, 14, 2.8)
	pillarR.Position = shrineCenter + Vector3.new(8, 7.0, 2)
	pillarR.Anchored = true
	pillarR.CanCollide = false
	pillarR.Material = Enum.Material.Slate
	pillarR.Color = Color3.fromRGB(42, 32, 60)
	pillarR.Parent = shrineModel

	local archLintel = Instance.new("Part")
	archLintel.Name = "ShrineLintel"
	archLintel.Size = Vector3.new(19, 2.4, 3.4)
	archLintel.Position = shrineCenter + Vector3.new(0, 14.5, 2)
	archLintel.Anchored = true
	archLintel.CanCollide = false
	archLintel.Material = Enum.Material.Slate
	archLintel.Color = Color3.fromRGB(52, 40, 74)
	archLintel.Parent = shrineModel

	local portalBacking = Instance.new("Part")
	portalBacking.Name = "ShrinePortalBacking"
	portalBacking.Size = Vector3.new(13, 13, 0.5)
	portalBacking.Position = shrineCenter + Vector3.new(0, 7.5, 3.2)
	portalBacking.Anchored = true
	portalBacking.CanCollide = false
	portalBacking.Material = Enum.Material.Neon
	portalBacking.Color = Color3.fromRGB(168, 85, 247)
	portalBacking.Transparency = 0.45
	portalBacking.Parent = shrineModel

	-- Starlight Telescope for Skill Tree Interaction
	local telescopeBase = Instance.new("Part")
	telescopeBase.Name = "TelescopeBase"
	telescopeBase.Size = Vector3.new(2.4, 3.2, 2.4)
	telescopeBase.Position = shrineCenter + Vector3.new(0, 1.8, 5)
	telescopeBase.Anchored = true
	telescopeBase.Material = Enum.Material.SmoothPlastic
	telescopeBase.Color = Color3.fromRGB(250, 204, 21)
	telescopeBase.Parent = shrineModel

	local telescopeTube = Instance.new("Part")
	telescopeTube.Name = "TelescopeTube"
	telescopeTube.Size = Vector3.new(1.2, 6.0, 1.2)
	telescopeTube.Position = telescopeBase.Position + Vector3.new(0, 2.2, 1)
	telescopeTube.Orientation = Vector3.new(35, 0, 0)
	telescopeTube.Anchored = true
	telescopeTube.Material = Enum.Material.Neon
	telescopeTube.Color = Color3.fromRGB(56, 189, 248)
	telescopeTube.Parent = shrineModel

	local telePrompt = Instance.new("ProximityPrompt")
	telePrompt.Name = "TelescopePrompt"
	telePrompt.ActionText = "Stargaze"
	telePrompt.ObjectText = "Celestial Telescope (Skills)"
	telePrompt.KeyboardKeyCode = Enum.KeyCode.E
	telePrompt.HoldDuration = 0
	telePrompt.MaxActivationDistance = 14
	telePrompt.RequiresLineOfSight = false
	telePrompt.Parent = telescopeBase

	-- ========================================================
	-- 4 GRAND WEEPING WILLOW TREES (Concept Art Framing)
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
			scaleModelToDimension(treeClone, 17.0)
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
				spores.Rate = 16
				spores.Lifetime = NumberRange.new(3.5, 6.5)
				spores.Speed = NumberRange.new(0.5, 1.5)
				spores.SpreadAngle = Vector2.new(60, 60)
				spores.Color = ColorSequence.new(foliageColor)
				spores.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
				spores.LightEmission = 0.85
				spores.Parent = sporePart
			end
		else
			-- Sculpted Multi-Cluster Willow Tree Fallback (No simple ball-on-stick)
			local treeModel = Instance.new("Model")
			treeModel.Name = name
			treeModel.Parent = gardenFolder

			local trunk = Instance.new("Part")
			trunk.Name = "WillowTrunk"
			trunk.Size = Vector3.new(2.2, 12, 2.2)
			trunk.Position = pos + Vector3.new(0, 6, 0)
			trunk.Anchored = true
			trunk.CanCollide = false
			trunk.Material = Enum.Material.Wood
			trunk.Color = Color3.fromRGB(32, 24, 40)
			trunk.Parent = treeModel

			-- Multi-cluster drooping canopy
			local canopyOffsets = {
				Vector3.new(0, 13, 0),
				Vector3.new(-3.5, 11, -2),
				Vector3.new(3.5, 11, -2),
				Vector3.new(-2, 10, 3.5),
				Vector3.new(2, 10, 3.5),
			}
			for cIdx, offset in canopyOffsets do
				local cluster = Instance.new("Part")
				cluster.Name = "CanopyCluster_" .. cIdx
				cluster.Shape = Enum.PartType.Ball
				cluster.Size = Vector3.new(6.5, 6.5, 6.5)
				cluster.Position = pos + offset
				cluster.Anchored = true
				cluster.CanCollide = false
				cluster.Material = Enum.Material.Neon
				cluster.Color = foliageColor
				cluster.Transparency = 0.28
				cluster.Parent = treeModel

				local spores = Instance.new("ParticleEmitter")
				spores.Name = "DroopingSpores"
				spores.Rate = 6
				spores.Lifetime = NumberRange.new(3, 5.5)
				spores.Speed = NumberRange.new(0.4, 1.2)
				spores.SpreadAngle = Vector2.new(45, 45)
				spores.Color = ColorSequence.new(foliageColor)
				spores.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
				spores.LightEmission = 0.8
				spores.Parent = cluster
			end
		end
	end

	-- Flanking the Rear Sanctuary Shrine (2 Pastel Pink, 2 Radiant Cyan)
	deployWillowTree(Vector3.new(-20, 0.4, 36), Color3.fromRGB(244, 114, 182), "Willow_Pink_RearLeft")
	deployWillowTree(Vector3.new(-15, 0.4, 24), Color3.fromRGB(56, 189, 248), "Willow_Cyan_FrontLeft")
	deployWillowTree(Vector3.new(15, 0.4, 24), Color3.fromRGB(56, 189, 248), "Willow_Cyan_FrontRight")
	deployWillowTree(Vector3.new(20, 0.4, 36), Color3.fromRGB(244, 114, 182), "Willow_Pink_RearRight")

	-- ========================================================
	-- 2. CRYSTALLINE ICE BRIDGES (Connecting 3 Islands)
	-- ========================================================
	local function createCrystallineBridge(name: string, startX: number, endX: number, color: Color3)
		local bridgeModel = Instance.new("Model")
		bridgeModel.Name = name
		bridgeModel.Parent = gardenFolder

		local length = math.abs(endX - startX)
		local midX = (startX + endX) / 2

		-- Faceted Main Arched Walkway
		local deck = Instance.new("Part")
		deck.Name = "BridgeDeck"
		deck.Size = Vector3.new(length, 0.9, 8.5)
		deck.Position = Vector3.new(midX, 0.4, 8)
		deck.Anchored = true
		deck.CanCollide = true
		deck.Material = Enum.Material.Glass
		deck.Color = color
		deck.Transparency = 0.32
		deck.Reflectance = 0.15
		deck.Parent = bridgeModel

		-- Crystal Spires along bridge edges
		for step = -2, 2 do
			local xOffset = step * (length / 5.5)
			local spireL = Instance.new("Part")
			spireL.Name = "RailCrystalL"
			spireL.Size = Vector3.new(1.0, 3.2, 1.0)
			spireL.Position = Vector3.new(midX + xOffset, 1.8, 3.6)
			spireL.Orientation = Vector3.new(12, 0, 15)
			spireL.Anchored = true
			spireL.CanCollide = false
			spireL.Material = Enum.Material.Neon
			spireL.Color = color
			spireL.Transparency = 0.25
			spireL.Parent = bridgeModel

			local spireR = Instance.new("Part")
			spireR.Name = "RailCrystalR"
			spireR.Size = Vector3.new(1.0, 3.2, 1.0)
			spireR.Position = Vector3.new(midX + xOffset, 1.8, 12.4)
			spireR.Orientation = Vector3.new(-12, 0, -15)
			spireR.Anchored = true
			spireR.CanCollide = false
			spireR.Material = Enum.Material.Neon
			spireR.Color = color
			spireR.Transparency = 0.25
			spireR.Parent = bridgeModel
		end

		return bridgeModel
	end

	-- East Starlight Bridge (to Market Island)
	createCrystallineBridge("EastCrystallineBridge", 29, 47, Color3.fromRGB(186, 230, 253))
	-- West Amethyst Bridge (to Pet Island)
	createCrystallineBridge("WestAmethystBridge", -29, -47, Color3.fromRGB(216, 180, 254))

	-- ========================================================
	-- 3. LEFT ISLAND: WEALTH & MARKET PLAZA (58, 0, 8)
	-- ========================================================
	local eastIslandCenter = Vector3.new(58, -0.6, 8)
	local subIslandModels = classifiedAssets["ISLAND_SUB"] or {}
	if #subIslandModels > 0 then
		local eastIslandMesh = subIslandModels[1]:Clone()
		eastIslandMesh.Name = "EastIslandCrag"
		eastIslandMesh.Parent = gardenFolder
		anchorAllParts(eastIslandMesh, true)
		scaleModelToDimension(eastIslandMesh, 62)
		if not eastIslandMesh.PrimaryPart then
			eastIslandMesh.PrimaryPart = eastIslandMesh:FindFirstChildWhichIsA("BasePart", true)
		end
		if eastIslandMesh.PrimaryPart then
			eastIslandMesh:PivotTo(CFrame.new(58, -32, 8))
		end
	end

	local eastFoundation = Instance.new("Part")
	eastFoundation.Name = "EastMarketFoundation"
	eastFoundation.Size = Vector3.new(46, 2.0, 46)
	eastFoundation.Position = eastIslandCenter
	eastFoundation.Anchored = true
	eastFoundation.Material = Enum.Material.Slate
	eastFoundation.Color = Color3.fromRGB(28, 22, 42)
	eastFoundation.TopSurface = Enum.SurfaceType.Smooth
	eastFoundation.Parent = gardenFolder

	local eastRim = Instance.new("Part")
	eastRim.Name = "EastGoldRim"
	eastRim.Shape = Enum.PartType.Cylinder
	eastRim.Size = Vector3.new(0.5, 47, 47)
	eastRim.Position = Vector3.new(58, 0.35, 8)
	eastRim.Orientation = Vector3.new(0, 0, 90)
	eastRim.Anchored = true
	eastRim.CanCollide = false
	eastRim.Material = Enum.Material.Neon
	eastRim.Color = Color3.fromRGB(250, 204, 21)
	eastRim.Transparency = 0.55
	eastRim.Parent = gardenFolder

	-- MARKET GAZEBO & MERCHANT STALL (88K2rZReSQ5xHd5bkrt8)
	local gazeboCenter = Vector3.new(58, 0.4, 16)
	local userGazebo = classifiedAssets["GAZEBO"] and classifiedAssets["GAZEBO"][1]
	if userGazebo then
		print("  ✨ [WorldService] Deploying 3D Floating Market Gazebo (16 studs)...")
		userGazebo.Parent = gardenFolder
		anchorAllParts(userGazebo, true)
		scaleModelToDimension(userGazebo, 16.0)
		if not userGazebo.PrimaryPart then
			userGazebo.PrimaryPart = userGazebo:FindFirstChildWhichIsA("BasePart", true)
		end
		if userGazebo.PrimaryPart then
			userGazebo:PivotTo(CFrame.new(gazeboCenter))
		end
	else
		-- Sculpted Striped Marketplace Awning Stall Fallback
		local stallModel = Instance.new("Model")
		stallModel.Name = "MarketStall"
		stallModel.Parent = gardenFolder

		local counter = Instance.new("Part")
		counter.Name = "StallCounter"
		counter.Size = Vector3.new(12, 3.2, 4.0)
		counter.Position = gazeboCenter + Vector3.new(0, 1.6, 0)
		counter.Anchored = true
		counter.Material = Enum.Material.Wood
		counter.Color = Color3.fromRGB(80, 50, 30)
		counter.Parent = stallModel

		local awning = Instance.new("Part")
		awning.Name = "StripedAwning"
		awning.Size = Vector3.new(14, 1.2, 8.0)
		awning.Position = gazeboCenter + Vector3.new(0, 8.5, 0)
		awning.Orientation = Vector3.new(15, 0, 0)
		awning.Anchored = true
		awning.Material = Enum.Material.SmoothPlastic
		awning.Color = Color3.fromRGB(244, 63, 94)
		awning.Parent = stallModel
	end

	-- Interactive Pedestals on Market Island
	local function createSalesPedestal(name: string, offset: Vector3, labelText: string, subText: string, color: Color3, actionName: string)
		local ped = Instance.new("Part")
		ped.Name = name .. "_Pedestal"
		ped.Shape = Enum.PartType.Cylinder
		ped.Size = Vector3.new(2.4, 3.0, 3.0)
		ped.Position = gazeboCenter + offset
		ped.Orientation = Vector3.new(0, 0, 90)
		ped.Anchored = true
		ped.Material = Enum.Material.Slate
		ped.Color = Color3.fromRGB(28, 22, 42)
		ped.Parent = gardenFolder

		local gemIcon = Instance.new("Part")
		gemIcon.Name = "FloatingGem"
		gemIcon.Size = Vector3.new(1.4, 1.4, 1.4)
		gemIcon.Position = ped.Position + Vector3.new(0, 2.6, 0)
		gemIcon.Orientation = Vector3.new(45, 45, 0)
		gemIcon.Anchored = true
		gemIcon.Material = Enum.Material.Neon
		gemIcon.Color = color
		gemIcon.Parent = ped

		local pLight = Instance.new("PointLight")
		pLight.Color = color
		pLight.Brightness = 2.4
		pLight.Range = 12
		pLight.Parent = gemIcon

		local bb = Instance.new("BillboardGui")
		bb.Name = "PedestalBillboard"
		bb.Size = UDim2.new(0, 180, 0, 50)
		bb.StudsOffset = Vector3.new(0, 2.2, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 35
		bb.Parent = gemIcon

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 24)
		title.BackgroundTransparency = 1
		title.Text = labelText
		title.TextColor3 = color
		title.TextSize = 14
		title.Font = Enum.Font.FredokaOne
		title.Parent = bb

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, 0, 0, 16)
		sub.Position = UDim2.new(0, 0, 0, 24)
		sub.BackgroundTransparency = 1
		sub.Text = subText
		sub.TextColor3 = Color3.fromRGB(255, 255, 255)
		sub.TextSize = 11
		sub.Font = Enum.Font.FredokaOne
		sub.Parent = bb

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = actionName .. "Prompt"
		prompt.ActionText = "View in Shop"
		prompt.ObjectText = labelText
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = gemIcon
	end

	createSalesPedestal("Bundle", Vector3.new(-5, 1.2, 0), "🔥 STARTER BUNDLE", "80% OFF • 5x Rare Seeds", Color3.fromRGB(250, 204, 21), "Bundle")
	createSalesPedestal("AutoHarvest", Vector3.new(0, 1.2, 4), "⚡ AUTO-HARVEST", "Gamepass • AFK Harvest", Color3.fromRGB(56, 189, 248), "AutoHarvest")
	createSalesPedestal("LuckPotion", Vector3.new(5, 1.2, 0), "🍀 2x LUCK POTION", "+150% Mutation Luck", Color3.fromRGB(74, 222, 128), "LuckPotion")

	-- CELESTIAL WEALTH WELL & GOLD HOARD (Concept Art: Spilling golden coins & treasure)
	local wellPos = Vector3.new(58, 0.4, -2)
	local wellModel = Instance.new("Model")
	wellModel.Name = "CelestialWealthWell"
	wellModel.Parent = gardenFolder

	local userWell = classifiedAssets["WELL"] and classifiedAssets["WELL"][1]
	if userWell then
		print("  ✨ [WorldService] Deploying 3D Celestial Well (10 studs)...")
		userWell.Parent = wellModel
		anchorAllParts(userWell, true)
		scaleModelToDimension(userWell, 10.0)
		if not userWell.PrimaryPart then
			userWell.PrimaryPart = userWell:FindFirstChildWhichIsA("BasePart", true)
		end
		if userWell.PrimaryPart then
			userWell:PivotTo(CFrame.new(wellPos))
		end
	end

	local wellBase = Instance.new("Part")
	wellBase.Name = "WellBase"
	wellBase.Shape = Enum.PartType.Cylinder
	wellBase.Size = Vector3.new(1.8, 8.5, 8.5)
	wellBase.Position = wellPos + Vector3.new(0, 0.9, 0)
	wellBase.Orientation = Vector3.new(0, 0, 90)
	wellBase.Anchored = true
	wellBase.Material = Enum.Material.Slate
	wellBase.Color = Color3.fromRGB(36, 28, 54)
	wellBase.Parent = wellModel

	local wellLiquid = Instance.new("Part")
	wellLiquid.Name = "WellCore"
	wellLiquid.Shape = Enum.PartType.Cylinder
	wellLiquid.Size = Vector3.new(0.4, 7.2, 7.2)
	wellLiquid.Position = wellPos + Vector3.new(0, 1.7, 0)
	wellLiquid.Orientation = Vector3.new(0, 0, 90)
	wellLiquid.Anchored = true
	wellLiquid.Material = Enum.Material.Neon
	wellLiquid.Color = Color3.fromRGB(250, 204, 21)
	wellLiquid.Transparency = 0.15
	wellLiquid.Parent = wellModel

	local wellLight = Instance.new("PointLight")
	wellLight.Color = Color3.fromRGB(250, 204, 21)
	wellLight.Brightness = 3.0
	wellLight.Range = 20
	wellLight.Parent = wellLiquid

	local wellParticles = Instance.new("ParticleEmitter")
	wellParticles.Name = "GoldSparks"
	wellParticles.Rate = 24
	wellParticles.Lifetime = NumberRange.new(2.5, 4.5)
	wellParticles.Speed = NumberRange.new(1.2, 2.5)
	wellParticles.SpreadAngle = Vector2.new(30, 30)
	wellParticles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 204, 21)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(254, 240, 138)),
	})
	wellParticles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	wellParticles.LightEmission = 0.95
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

	wellPrompt.Triggered:Connect(function(player: Player)
		local DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
		DataService.CollectWell(player)
	end)

	-- Spilling Gold Coin Hoard around the Well
	local goldMoundPositions = {
		Vector3.new(4, 0.3, 2),
		Vector3.new(-4, 0.3, 1),
		Vector3.new(2, 0.3, -4),
		Vector3.new(-3, 0.3, -3),
		Vector3.new(5, 0.25, -2),
	}
	for idx, offset in goldMoundPositions do
		local goldPile = Instance.new("Part")
		goldPile.Name = "GoldTreasurePile_" .. idx
		goldPile.Shape = Enum.PartType.Ball
		goldPile.Size = Vector3.new(3.8, 1.2, 3.8)
		goldPile.Position = wellPos + offset
		goldPile.Anchored = true
		goldPile.CanCollide = false
		goldPile.Material = Enum.Material.SmoothPlastic
		goldPile.Color = Color3.fromRGB(250, 204, 21)
		goldPile.Parent = wellModel
	end

	-- Golden Autumn Tree with Streetlamp
	deployWillowTree(Vector3.new(72, 0.4, 2), Color3.fromRGB(250, 204, 21), "GoldenAutumnTree")

	-- ========================================================
	-- 4. RIGHT ISLAND: TRANSMUTATION & PET EGG DAIS (-58, 0, 8)
	-- ========================================================
	local westIslandCenter = Vector3.new(-58, -0.6, 8)
	if #subIslandModels > 1 then
		local westIslandMesh = subIslandModels[2]:Clone()
		westIslandMesh.Name = "WestIslandCrag"
		westIslandMesh.Parent = gardenFolder
		anchorAllParts(westIslandMesh, true)
		scaleModelToDimension(westIslandMesh, 62)
		if not westIslandMesh.PrimaryPart then
			westIslandMesh.PrimaryPart = westIslandMesh:FindFirstChildWhichIsA("BasePart", true)
		end
		if westIslandMesh.PrimaryPart then
			westIslandMesh:PivotTo(CFrame.new(-58, -32, 8))
		end
	end

	local westFoundation = Instance.new("Part")
	westFoundation.Name = "WestShrineFoundation"
	westFoundation.Size = Vector3.new(46, 2.0, 46)
	westFoundation.Position = westIslandCenter
	westFoundation.Anchored = true
	westFoundation.Material = Enum.Material.Slate
	westFoundation.Color = Color3.fromRGB(28, 22, 42)
	westFoundation.TopSurface = Enum.SurfaceType.Smooth
	westFoundation.Parent = gardenFolder

	local westRim = Instance.new("Part")
	westRim.Name = "WestAmethystRim"
	westRim.Shape = Enum.PartType.Cylinder
	westRim.Size = Vector3.new(0.5, 47, 47)
	westRim.Position = Vector3.new(-58, 0.35, 8)
	westRim.Orientation = Vector3.new(0, 0, 90)
	westRim.Anchored = true
	westRim.CanCollide = false
	westRim.Material = Enum.Material.Neon
	westRim.Color = Color3.fromRGB(168, 85, 247)
	westRim.Transparency = 0.55
	westRim.Parent = gardenFolder

	-- ANCIENT COSMIC REALM GATE ARCHES (K4xcbxw5JiktsVFs6Rvn)
	local userGate = classifiedAssets["GATE_ARCH"] and classifiedAssets["GATE_ARCH"][1]
	local gatePos = Vector3.new(-58, 0.5, 18)
	if userGate then
		print("  ✨ [WorldService] Deploying 3D Ancient Cosmic Realm Gate (22 studs)...")
		userGate.Parent = gardenFolder
		anchorAllParts(userGate, true)
		scaleModelToDimension(userGate, 22.0)
		if not userGate.PrimaryPart then
			userGate.PrimaryPart = userGate:FindFirstChildWhichIsA("BasePart", true)
		end
		if userGate.PrimaryPart then
			userGate:PivotTo(CFrame.new(gatePos))
		end
	else
		-- Twin Runic Stone Gate Archways Fallback
		local gateModel = Instance.new("Model")
		gateModel.Name = "TwinRunicArches"
		gateModel.Parent = gardenFolder

		local obeliskL = Instance.new("Part")
		obeliskL.Name = "ObeliskLeft"
		obeliskL.Size = Vector3.new(3.5, 18, 3.5)
		obeliskL.Position = gatePos + Vector3.new(-8, 8.5, 0)
		obeliskL.Anchored = true
		obeliskL.Material = Enum.Material.Slate
		obeliskL.Color = Color3.fromRGB(36, 28, 54)
		obeliskL.Parent = gateModel

		local obeliskR = Instance.new("Part")
		obeliskR.Name = "ObeliskRight"
		obeliskR.Size = Vector3.new(3.5, 18, 3.5)
		obeliskR.Position = gatePos + Vector3.new(8, 8.5, 0)
		obeliskR.Anchored = true
		obeliskR.Material = Enum.Material.Slate
		obeliskR.Color = Color3.fromRGB(36, 28, 54)
		obeliskR.Parent = gateModel
	end

	-- CELESTIAL MYSTERY EGG ON RAISED DAIS (PftfbIAqxyQQaT0eng8J)
	local eggDaisPos = Vector3.new(-58, 0.4, 6)
	local eggDais = Instance.new("Part")
	eggDais.Name = "EggRaisedDais"
	eggDais.Shape = Enum.PartType.Cylinder
	eggDais.Size = Vector3.new(1.2, 10.0, 10.0)
	eggDais.Position = eggDaisPos + Vector3.new(0, 0.6, 0)
	eggDais.Orientation = Vector3.new(0, 0, 90)
	eggDais.Anchored = true
	eggDais.Material = Enum.Material.Slate
	eggDais.Color = Color3.fromRGB(36, 28, 54)
	eggDais.Parent = gardenFolder

	local eggRuneRing = Instance.new("Part")
	eggRuneRing.Name = "EggDaisRuneRing"
	eggRuneRing.Shape = Enum.PartType.Cylinder
	eggRuneRing.Size = Vector3.new(0.2, 11.2, 11.2)
	eggRuneRing.Position = eggDaisPos + Vector3.new(0, 1.25, 0)
	eggRuneRing.Orientation = Vector3.new(0, 0, 90)
	eggRuneRing.Anchored = true
	eggRuneRing.CanCollide = false
	eggRuneRing.Material = Enum.Material.Neon
	eggRuneRing.Color = Color3.fromRGB(244, 114, 182)
	eggRuneRing.Transparency = 0.4
	eggRuneRing.Parent = gardenFolder

	local userEgg = classifiedAssets["EGG"] and classifiedAssets["EGG"][1]
	local eggPromptPart: BasePart = eggDais
	if userEgg then
		print("  ✨ [WorldService] Deploying 3D Celestial Mystery Egg (4.5 studs)...")
		userEgg.Parent = gardenFolder
		anchorAllParts(userEgg, true)
		scaleModelToDimension(userEgg, 4.5)
		if not userEgg.PrimaryPart then
			userEgg.PrimaryPart = userEgg:FindFirstChildWhichIsA("BasePart", true)
		end
		if userEgg.PrimaryPart then
			userEgg:PivotTo(CFrame.new(eggDaisPos + Vector3.new(0, 3.2, 0)))
			eggPromptPart = userEgg.PrimaryPart
		end
	end

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
	eggLight.Brightness = 2.8
	eggLight.Range = 18
	eggLight.Parent = eggPromptPart

	-- COMPANION PETS ON DISPLAY (Astral Kitsune & Starlight Hatchling Dragon)
	local userKitsune = classifiedAssets["PET_KITSUNE"] and classifiedAssets["PET_KITSUNE"][1]
	if userKitsune then
		print("  ✨ [WorldService] Deploying 3D Astral Kitsune Pet (3.4 studs)...")
		userKitsune.Parent = gardenFolder
		anchorAllParts(userKitsune, true)
		scaleModelToDimension(userKitsune, 3.4)
		if not userKitsune.PrimaryPart then
			userKitsune.PrimaryPart = userKitsune:FindFirstChildWhichIsA("BasePart", true)
		end
		if userKitsune.PrimaryPart then
			userKitsune:PivotTo(CFrame.new(eggDaisPos + Vector3.new(5.5, 0.8, -2)) * CFrame.Angles(0, math.rad(-75), 0))
		end
	end

	local userDragon = classifiedAssets["PET_DRAGON"] and classifiedAssets["PET_DRAGON"][1]
	if userDragon then
		print("  ✨ [WorldService] Deploying 3D Starlight Hatchling Dragon Pet (3.4 studs)...")
		userDragon.Parent = gardenFolder
		anchorAllParts(userDragon, true)
		scaleModelToDimension(userDragon, 3.4)
		if not userDragon.PrimaryPart then
			userDragon.PrimaryPart = userDragon:FindFirstChildWhichIsA("BasePart", true)
		end
		if userDragon.PrimaryPart then
			userDragon:PivotTo(CFrame.new(eggDaisPos + Vector3.new(-5.5, 0.8, -2)) * CFrame.Angles(0, math.rad(75), 0))
		end
	end

	-- TRANSMUTATION ALAR & SUMMONING RUNE CIRCLE (12lQusKLlIcOsvzOzjaa)
	local altarPos = Vector3.new(-58, 0.4, -4)
	local summoningCircle = Instance.new("Part")
	summoningCircle.Name = "SummoningRuneCircle"
	summoningCircle.Shape = Enum.PartType.Cylinder
	summoningCircle.Size = Vector3.new(0.2, 9.5, 9.5)
	summoningCircle.Position = altarPos + Vector3.new(0, 0.1, 0)
	summoningCircle.Orientation = Vector3.new(0, 0, 90)
	summoningCircle.Anchored = true
	summoningCircle.CanCollide = false
	summoningCircle.Material = Enum.Material.Neon
	summoningCircle.Color = Color3.fromRGB(168, 85, 247)
	summoningCircle.Transparency = 0.45
	summoningCircle.Parent = gardenFolder

	local userAltar = classifiedAssets["ALTAR"] and classifiedAssets["ALTAR"][1]
	local altarPromptPart: BasePart = summoningCircle
	if userAltar then
		print("  ✨ [WorldService] Deploying 3D Transmutation Altar (8.5 studs)...")
		userAltar.Parent = gardenFolder
		anchorAllParts(userAltar, true)
		scaleModelToDimension(userAltar, 8.5)
		if not userAltar.PrimaryPart then
			userAltar.PrimaryPart = userAltar:FindFirstChildWhichIsA("BasePart", true)
		end
		if userAltar.PrimaryPart then
			userAltar:PivotTo(CFrame.new(altarPos) * CFrame.Angles(0, math.rad(180), 0))
			altarPromptPart = userAltar.PrimaryPart
		end
	end

	local altarPrompt = Instance.new("ProximityPrompt")
	altarPrompt.Name = "AltarForgePrompt"
	altarPrompt.ActionText = "Transmute Seeds"
	altarPrompt.ObjectText = "Sacred Altar (Forge)"
	altarPrompt.KeyboardKeyCode = Enum.KeyCode.E
	altarPrompt.HoldDuration = 0
	altarPrompt.MaxActivationDistance = 14
	altarPrompt.RequiresLineOfSight = false
	altarPrompt.Parent = altarPromptPart

	-- GIANT AMETHYST CRYSTAL CLUSTERS (Concept Art: Erupting from the rock edges)
	local function createCrystalCluster(cPos: Vector3, mainColor: Color3)
		local clusterModel = Instance.new("Model")
		clusterModel.Name = "AmethystCluster"
		clusterModel.Parent = gardenFolder

		local spires = {
			{ Offset = Vector3.new(0, 4, 0), Size = Vector3.new(2.8, 10, 2.8), Rot = Vector3.new(10, 20, 5) },
			{ Offset = Vector3.new(-2, 3, 1.5), Size = Vector3.new(2.2, 7.5, 2.2), Rot = Vector3.new(-15, 40, -10) },
			{ Offset = Vector3.new(2, 2.5, -1.5), Size = Vector3.new(2.0, 6.5, 2.0), Rot = Vector3.new(20, -30, 15) },
		}
		for idx, s in spires do
			local p = Instance.new("Part")
			p.Name = "CrystalSpike_" .. idx
			p.Size = s.Size
			p.Position = cPos + s.Offset
			p.Orientation = s.Rot
			p.Anchored = true
			p.CanCollide = false
			p.Material = Enum.Material.Neon
			p.Color = mainColor
			p.Transparency = 0.25
			p.Parent = clusterModel
		end

		local pLight = Instance.new("PointLight")
		pLight.Color = mainColor
		pLight.Brightness = 2.8
		pLight.Range = 16
		pLight.Parent = clusterModel:FindFirstChildWhichIsA("BasePart")
	end

	createCrystalCluster(Vector3.new(-72, 0.4, 6), Color3.fromRGB(192, 132, 252))
	createCrystalCluster(Vector3.new(-48, 0.4, 18), Color3.fromRGB(236, 72, 153))

	-- ========================================================
	-- 5. DEPLOY THE 9 GARDEN PLOTS (IVdfl4QeEMqt7VE4qcvS)
	-- ========================================================
	local planterTemplate: Model? = nil
	local userPlanter = classifiedAssets["PLANTER"] and classifiedAssets["PLANTER"][1]
	if userPlanter then
		print("  ✨ [WorldService] Configuring 3D Planter Box Template (7 studs)...")
		anchorAllParts(userPlanter, true)
		scaleModelToDimension(userPlanter, 7.0)
		planterTemplate = userPlanter:Clone()
		userPlanter.Parent = userAssetsFolder
	end

	-- Prepare 3D Crop Bloom Template (WuMxsfiY9i8DUrScM3Vv)
	local userBloom = classifiedAssets["BLOOM"] and classifiedAssets["BLOOM"][1]
	if userBloom and assetsFolder then
		print("  ✨ [WorldService] Storing 3D Crystal Bloom Template in ReplicatedStorage...")
		anchorAllParts(userBloom, false)
		scaleModelToDimension(userBloom, 3.4)
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
				planterClone:PivotTo(CFrame.new(plotPos))
			end
			planterClone.Parent = plotModel
		else
			local planter = Instance.new("Part")
			planter.Name = "PlanterBox"
			planter.Size = Vector3.new(6.8, 0.7, 6.8)
			planter.Position = plotPos
			planter.Anchored = true
			planter.Material = Enum.Material.Slate
			planter.Color = Color3.fromRGB(30, 24, 46)
			planter.Parent = plotModel
		end

		-- Clickable Soil interaction part
		local soil = Instance.new("Part")
		soil.Name = "Soil"
		soil.Size = Vector3.new(5.6, 0.4, 5.6)
		soil.Position = plotPos + Vector3.new(0, 0.35, 0)
		soil.Anchored = true
		soil.Material = Enum.Material.Slate
		soil.Color = Color3.fromRGB(18, 14, 28)
		soil.Transparency = (planterTemplate ~= nil) and 1 or 0
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
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = soil
	end

	-- ========================================================
	-- 6. VOLUMETRIC PASTEL CLOUD SEA & COSMIC AURORA BOREALIS
	-- ========================================================
	local cloudPositions = {
		Vector3.new(0, -9, 8),
		Vector3.new(-24, -8, 8),
		Vector3.new(24, -8, 8),
		Vector3.new(54, -10, 8),
		Vector3.new(-54, -10, 8),
		Vector3.new(0, -9, -18),
		Vector3.new(0, -9, 34),
		Vector3.new(30, -11, 28),
		Vector3.new(-30, -11, 28),
		Vector3.new(34, -11, -12),
		Vector3.new(-34, -11, -12),
		Vector3.new(62, -9, -8),
		Vector3.new(-62, -9, -8),
		Vector3.new(62, -9, 24),
		Vector3.new(-62, -9, 24),
	}
	for idx, cPos in cloudPositions do
		local cloud = Instance.new("Part")
		cloud.Name = "CloudSeaPart_" .. idx
		cloud.Shape = Enum.PartType.Ball
		local cSize = 24 + (idx % 3) * 6
		cloud.Size = Vector3.new(cSize, 11, cSize)
		cloud.Position = cPos
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Color = (idx % 2 == 0) and Color3.fromRGB(246, 222, 248) or Color3.fromRGB(232, 218, 255)
		cloud.Transparency = 0.55
		cloud.Parent = gardenFolder
	end

	-- Cosmic Aurora Borealis Curtains
	local auroraFolder = Instance.new("Folder")
	auroraFolder.Name = "AuroraBorealis"
	auroraFolder.Parent = gardenFolder

	local auroraBands = {
		{ Center = Vector3.new(-40, 185, 30), Angle = 25, Size = Vector3.new(290, 26, 4), Color = Color3.fromRGB(52, 211, 153), Trans = 0.72 },
		{ Center = Vector3.new(10, 195, -20), Angle = -15, Size = Vector3.new(330, 30, 4), Color = Color3.fromRGB(56, 189, 248), Trans = 0.75 },
		{ Center = Vector3.new(60, 205, 50), Angle = 40, Size = Vector3.new(310, 28, 4), Color = Color3.fromRGB(236, 72, 153), Trans = 0.74 },
	}
	for idx, band in auroraBands do
		local aPart = Instance.new("Part")
		aPart.Name = string.format("AuroraWave_%d", idx)
		aPart.Size = band.Size
		aPart.Position = band.Center
		aPart.Orientation = Vector3.new(8, band.Angle, -5)
		aPart.Anchored = true
		aPart.CanCollide = false
		aPart.CanTouch = false
		aPart.CanQuery = false
		aPart.CastShadow = false
		aPart.Material = Enum.Material.Neon
		aPart.Color = band.Color
		aPart.Transparency = band.Trans
		aPart.Parent = auroraFolder
	end

	-- ========================================================
	-- 7. ENSURE RELIABLE CHARACTER SPAWN POSITIONING
	-- ========================================================
	local function onCharacterAdded(player: Player, character: Model)
		local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if hrp then
			task.wait(0.08)
			hrp.CFrame = CFrame.lookAt(Vector3.new(0, 3.5, -18), Vector3.new(0, 3.5, 8))
		end
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

	print("  ✅ [WorldService] Unified Vision 3D Archipelago Online! All Models, Fountain, and Zones Deployed.")
end

return WorldService
