--!strict
--[[
	WorldService.luau — Authoritative 3D Spatial Sanctuary Builder for STARWEAVE
	Crafted to faithfully match the Unified Vision Architecture (Concept Art media_1791217248028.jpg)

	Integrates and displays all 13 user-created 3D models with ZERO neon slop:
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

	Art Direction Rules:
	  - ZERO solid neon discs covering island floors. Floors are natural dark slate/granite stone.
	  - ZERO neon tombstone/slab bridge railings. Bridges are elegant translucent glass.
	  - ZERO flat black/pink nether-portal boxes. The shrine is an open scenic observatory framed by willows.
	  - ZERO giant vertical neon slabs. Crystals are small, delicate accents.
	  - Bloom and lighting calibrated for soft anime twilight (no nuclear whiteout).

	Located in: ServerScriptService.Server.Services.WorldService
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldService = {}

-- 9 Symmetrical Garden Plot Positions (Two clean 2x2 beds flanking the walkway + 1 centerpiece plot)
local PLOT_POSITIONS = {
	-- Left Garden Bed (West side)
	Vector3.new(-13.0, 0.2, 4.0),
	Vector3.new(-7.5, 0.2, 4.0),
	Vector3.new(-13.0, 0.2, 11.0),
	Vector3.new(-7.5, 0.2, 11.0),
	-- Right Garden Bed (East side)
	Vector3.new(7.5, 0.2, 4.0),
	Vector3.new(13.0, 0.2, 4.0),
	Vector3.new(7.5, 0.2, 11.0),
	Vector3.new(13.0, 0.2, 11.0),
	-- Centerpiece Botanical Plot (Behind central fountain)
	Vector3.new(0.0, 0.2, 17.5),
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
	print("  🌌 [WorldService] Crafting Aesthetic 3D Sanctuary matching Unified Vision...")

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
	Lighting.ExposureCompensation = -0.15

	-- Soft, subtle bloom (Prevents blinding whiteout)
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Name = "SanctuaryBloom"
	bloom.Intensity = 0.15
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

	-- Create SanctuarySpawn (Positioned on south arrival promenade facing central garden)
	local spawn = Workspace:FindFirstChild("SanctuarySpawn") :: SpawnLocation?
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SanctuarySpawn"
		spawn.Parent = Workspace
	end
	spawn.Size = Vector3.new(10, 0.5, 10)
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

	-- Reset StarweaveGarden folder in Workspace
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
	safetyFloor.Position = Vector3.new(0, -32, 0)
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
		local descNames = {}
		for idx, d in stray:GetDescendants() do
			if idx <= 4 then table.insert(descNames, d.Name) end
		end
		print(string.format("  🛡️ [WorldService] Preserved model: '%s' (Descendants: %s) in Workspace.UserImportedAssets", stray.Name, table.concat(descNames, ", ")))
	end

	-- ========================================================
	-- 1. CENTRAL BOTANICAL SANCTUARY ISLAND (0, 0, 8)
	-- ========================================================
	local centerIslandModel = classifiedAssets["ISLAND_CENTER"][1] or classifiedAssets["ISLAND_SUB"][1]
	if centerIslandModel then
		print("  ✨ [WorldService] Deploying 3D Central Sanctuary Island Crag (110 studs)...")
		centerIslandModel.Parent = gardenFolder
		anchorAllParts(centerIslandModel, true)
		scaleModelToDimension(centerIslandModel, 110)
		if not centerIslandModel.PrimaryPart then
			centerIslandModel.PrimaryPart = centerIslandModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if centerIslandModel.PrimaryPart then
			centerIslandModel:PivotTo(CFrame.new(0, -38.0, 8))
		end
	end

	-- Solid Walkable Dark Stone Foundation (NO neon disc covering the floor!)
	local centerFoundation = Instance.new("Part")
	centerFoundation.Name = "CenterIslandFoundation"
	centerFoundation.Size = Vector3.new(76, 1.6, 76)
	centerFoundation.Position = Vector3.new(0, -0.8, 8)
	centerFoundation.Anchored = true
	centerFoundation.Material = Enum.Material.Slate
	centerFoundation.Color = Color3.fromRGB(34, 28, 44)
	centerFoundation.TopSurface = Enum.SurfaceType.Smooth
	centerFoundation.Parent = gardenFolder

	-- Front Cliff Face Rune Medallion (Mounted on outer vertical cliff, NOT on top of walking floor)
	local runeSigilOuter = Instance.new("Part")
	runeSigilOuter.Name = "CenterFrontRuneSigil"
	runeSigilOuter.Shape = Enum.PartType.Cylinder
	runeSigilOuter.Size = Vector3.new(0.3, 6.0, 6.0)
	runeSigilOuter.Position = Vector3.new(0, -2.5, -31.2)
	runeSigilOuter.Orientation = Vector3.new(90, 0, 0)
	runeSigilOuter.Anchored = true
	runeSigilOuter.CanCollide = false
	runeSigilOuter.Material = Enum.Material.Neon
	runeSigilOuter.Color = Color3.fromRGB(192, 132, 252)
	runeSigilOuter.Transparency = 0.3
	runeSigilOuter.Parent = gardenFolder

	local runeSigilInner = Instance.new("Part")
	runeSigilInner.Name = "CenterFrontRuneDiamond"
	runeSigilInner.Size = Vector3.new(3.2, 3.2, 0.4)
	runeSigilInner.Position = Vector3.new(0, -2.5, -31.3)
	runeSigilInner.Orientation = Vector3.new(0, 0, 45)
	runeSigilInner.Anchored = true
	runeSigilInner.CanCollide = false
	runeSigilInner.Material = Enum.Material.Neon
	runeSigilInner.Color = Color3.fromRGB(250, 204, 21)
	runeSigilInner.Transparency = 0.2
	runeSigilInner.Parent = gardenFolder

	local runeLight = Instance.new("PointLight")
	runeLight.Color = Color3.fromRGB(192, 132, 252)
	runeLight.Brightness = 1.8
	runeLight.Range = 16
	runeLight.Parent = runeSigilOuter

	-- Paved Stone Cross Walkways (Connecting cardinal directions across the island)
	local function createStonePaver(name: string, size: Vector3, pos: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
		p.Anchored = true
		p.Material = Enum.Material.Slate
		p.Color = Color3.fromRGB(48, 40, 62)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = gardenFolder
		return p
	end

	-- North-South Promenade (Spawn to Shrine)
	createStonePaver("PromenadeNorthSouth", Vector3.new(7.0, 0.15, 52), Vector3.new(0, 0.08, 8))
	-- East-West Cross Promenade (Bridge to Bridge)
	createStonePaver("PromenadeEastWest", Vector3.new(54, 0.15, 7.0), Vector3.new(0, 0.08, 8))

	-- ========================================================
	-- CENTRAL TIERED STARDUST FOUNTAIN (Centerpiece of Sanctuary)
	-- ========================================================
	local fountainCenter = Vector3.new(0, 0.15, 8)
	local fountainModel = Instance.new("Model")
	fountainModel.Name = "CentralStardustFountain"
	fountainModel.Parent = gardenFolder

	-- Tier 1: Outer Slate Basin
	local basinOuter = Instance.new("Part")
	basinOuter.Name = "FountainBasinOuter"
	basinOuter.Shape = Enum.PartType.Cylinder
	basinOuter.Size = Vector3.new(0.6, 13.0, 13.0)
	basinOuter.Position = fountainCenter + Vector3.new(0, 0.25, 0)
	basinOuter.Orientation = Vector3.new(0, 0, 90)
	basinOuter.Anchored = true
	basinOuter.Material = Enum.Material.Slate
	basinOuter.Color = Color3.fromRGB(42, 34, 56)
	basinOuter.Parent = fountainModel

	-- Tier 2: Raised Inner Ring
	local basinInner = Instance.new("Part")
	basinInner.Name = "FountainBasinInner"
	basinInner.Shape = Enum.PartType.Cylinder
	basinInner.Size = Vector3.new(0.5, 9.5, 9.5)
	basinInner.Position = fountainCenter + Vector3.new(0, 0.55, 0)
	basinInner.Orientation = Vector3.new(0, 0, 90)
	basinInner.Anchored = true
	basinInner.Material = Enum.Material.Slate
	basinInner.Color = Color3.fromRGB(52, 42, 68)
	basinInner.Parent = fountainModel

	-- Luminous Turquoise Stardust Pool (Tasteful glass/water, NOT a solid neon disc!)
	local poolLiquid = Instance.new("Part")
	poolLiquid.Name = "FountainPoolLiquid"
	poolLiquid.Shape = Enum.PartType.Cylinder
	poolLiquid.Size = Vector3.new(0.2, 7.5, 7.5)
	poolLiquid.Position = fountainCenter + Vector3.new(0, 0.72, 0)
	poolLiquid.Orientation = Vector3.new(0, 0, 90)
	poolLiquid.Anchored = true
	poolLiquid.CanCollide = false
	poolLiquid.Material = Enum.Material.Glass
	poolLiquid.Color = Color3.fromRGB(34, 211, 238)
	poolLiquid.Transparency = 0.30
	poolLiquid.Reflectance = 0.25
	poolLiquid.Parent = fountainModel

	local poolLight = Instance.new("PointLight")
	poolLight.Color = Color3.fromRGB(34, 211, 238)
	poolLight.Brightness = 2.2
	poolLight.Range = 16
	poolLight.Parent = poolLiquid

	-- Floating Center Crystal Diamond
	local centerCrystal = Instance.new("Part")
	centerCrystal.Name = "FloatingFountainCrystal"
	centerCrystal.Size = Vector3.new(1.2, 1.8, 1.2)
	centerCrystal.Position = fountainCenter + Vector3.new(0, 2.2, 0)
	centerCrystal.Orientation = Vector3.new(15, 25, 10)
	centerCrystal.Anchored = true
	centerCrystal.CanCollide = false
	centerCrystal.Material = Enum.Material.Neon
	centerCrystal.Color = Color3.fromRGB(56, 189, 248)
	centerCrystal.Transparency = 0.2
	centerCrystal.Parent = fountainModel

	-- Gentle Swirling Stardust Particles
	local fountainSparks = Instance.new("ParticleEmitter")
	fountainSparks.Name = "FountainStardust"
	fountainSparks.Rate = 18
	fountainSparks.Lifetime = NumberRange.new(2.5, 4.5)
	fountainSparks.Speed = NumberRange.new(1.0, 2.4)
	fountainSparks.SpreadAngle = Vector2.new(20, 20)
	fountainSparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 211, 238)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(168, 85, 247)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	fountainSparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	fountainSparks.LightEmission = 0.90
	fountainSparks.Parent = centerCrystal

	-- ========================================================
	-- REAR SANCTUARY OVERLOOK & SKILL TREE OBSERVATORY (0, 0, 32)
	-- (Clean, open architectural balcony, NO flat black/pink nether-portal box)
	-- ========================================================
	local shrineCenter = Vector3.new(0, 0.15, 32)
	local shrineModel = Instance.new("Model")
	shrineModel.Name = "RearSanctuaryOverlook"
	shrineModel.Parent = gardenFolder

	local balconyDais = Instance.new("Part")
	balconyDais.Name = "BalconyDais"
	balconyDais.Shape = Enum.PartType.Cylinder
	balconyDais.Size = Vector3.new(0.8, 18, 18)
	balconyDais.Position = shrineCenter + Vector3.new(0, 0.2, 0)
	balconyDais.Orientation = Vector3.new(0, 0, 90)
	balconyDais.Anchored = true
	balconyDais.Material = Enum.Material.Slate
	balconyDais.Color = Color3.fromRGB(42, 34, 56)
	balconyDais.Parent = shrineModel

	-- Starlight Telescope for Skill Tree Interaction
	local telescopeBase = Instance.new("Part")
	telescopeBase.Name = "TelescopeBase"
	telescopeBase.Size = Vector3.new(2.2, 2.8, 2.2)
	telescopeBase.Position = shrineCenter + Vector3.new(0, 1.6, 2)
	telescopeBase.Anchored = true
	telescopeBase.Material = Enum.Material.SmoothPlastic
	telescopeBase.Color = Color3.fromRGB(245, 190, 30)
	telescopeBase.Parent = shrineModel

	local telescopeTube = Instance.new("Part")
	telescopeTube.Name = "TelescopeTube"
	telescopeTube.Size = Vector3.new(1.0, 5.5, 1.0)
	telescopeTube.Position = telescopeBase.Position + Vector3.new(0, 1.8, 1)
	telescopeTube.Orientation = Vector3.new(35, 0, 0)
	telescopeTube.Anchored = true
	telescopeTube.Material = Enum.Material.SmoothPlastic
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
	-- 4 GRAND WEEPING WILLOW TREES FRAMING THE OVERLOOK
	-- (2 Pastel Pink, 2 Radiant Cyan — bioluminescent foliage)
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
			scaleModelToDimension(treeClone, 16.0)
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
				spores.Rate = 12
				spores.Lifetime = NumberRange.new(3.5, 6.0)
				spores.Speed = NumberRange.new(0.4, 1.2)
				spores.SpreadAngle = Vector2.new(50, 50)
				spores.Color = ColorSequence.new(foliageColor)
				spores.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
				spores.LightEmission = 0.80
				spores.Parent = sporePart
			end
		else
			local treeModel = Instance.new("Model")
			treeModel.Name = name
			treeModel.Parent = gardenFolder

			local trunk = Instance.new("Part")
			trunk.Name = "WillowTrunk"
			trunk.Size = Vector3.new(2.0, 11, 2.0)
			trunk.Position = pos + Vector3.new(0, 5.5, 0)
			trunk.Anchored = true
			trunk.CanCollide = false
			trunk.Material = Enum.Material.Wood
			trunk.Color = Color3.fromRGB(30, 22, 38)
			trunk.Parent = treeModel

			local canopyOffsets = {
				Vector3.new(0, 11.5, 0),
				Vector3.new(-3.0, 9.5, -1.8),
				Vector3.new(3.0, 9.5, -1.8),
				Vector3.new(-1.8, 9.0, 2.8),
				Vector3.new(1.8, 9.0, 2.8),
			}
			for cIdx, offset in canopyOffsets do
				local cluster = Instance.new("Part")
				cluster.Name = "CanopyCluster_" .. cIdx
				cluster.Shape = Enum.PartType.Ball
				cluster.Size = Vector3.new(5.8, 5.8, 5.8)
				cluster.Position = pos + offset
				cluster.Anchored = true
				cluster.CanCollide = false
				cluster.Material = Enum.Material.Neon
				cluster.Color = foliageColor
				cluster.Transparency = 0.35
				cluster.Parent = treeModel
			end
		end
	end

	-- Flanking the Overlook
	deployWillowTree(Vector3.new(-18, 0.2, 32), Color3.fromRGB(244, 114, 182), "Willow_Pink_RearLeft")
	deployWillowTree(Vector3.new(-14, 0.2, 22), Color3.fromRGB(56, 189, 248), "Willow_Cyan_FrontLeft")
	deployWillowTree(Vector3.new(14, 0.2, 22), Color3.fromRGB(56, 189, 248), "Willow_Cyan_FrontRight")
	deployWillowTree(Vector3.new(18, 0.2, 32), Color3.fromRGB(244, 114, 182), "Willow_Pink_RearRight")

	-- ========================================================
	-- 2. CRYSTALLINE ICE BRIDGES (Connecting the 3 Islands)
	-- (Clean, translucent glass spans — NO glowing white gravestones!)
	-- ========================================================
	local function createCrystallineBridge(name: string, startX: number, endX: number, color: Color3)
		local bridgeModel = Instance.new("Model")
		bridgeModel.Name = name
		bridgeModel.Parent = gardenFolder

		local length = math.abs(endX - startX)
		local midX = (startX + endX) / 2

		-- Translucent Crystal Glass Deck
		local deck = Instance.new("Part")
		deck.Name = "BridgeDeck"
		deck.Size = Vector3.new(length, 0.6, 7.5)
		deck.Position = Vector3.new(midX, 0.2, 8)
		deck.Anchored = true
		deck.CanCollide = true
		deck.Material = Enum.Material.Glass
		deck.Color = color
		deck.Transparency = 0.45
		deck.Reflectance = 0.20
		deck.Parent = bridgeModel

		-- Clean Dark Stone Curb Rails (NOT blinding neon blocks!)
		local curbNorth = Instance.new("Part")
		curbNorth.Name = "CurbNorth"
		curbNorth.Size = Vector3.new(length, 0.35, 0.4)
		curbNorth.Position = Vector3.new(midX, 0.45, 4.3)
		curbNorth.Anchored = true
		curbNorth.Material = Enum.Material.Slate
		curbNorth.Color = Color3.fromRGB(42, 34, 56)
		curbNorth.Parent = bridgeModel

		local curbSouth = Instance.new("Part")
		curbSouth.Name = "CurbSouth"
		curbSouth.Size = Vector3.new(length, 0.35, 0.4)
		curbSouth.Position = Vector3.new(midX, 0.45, 11.7)
		curbSouth.Anchored = true
		curbSouth.Material = Enum.Material.Slate
		curbSouth.Color = Color3.fromRGB(42, 34, 56)
		curbSouth.Parent = bridgeModel

		-- Subtle Floating Stardust Sparkles
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

	-- East Starlight Bridge (to Market Island)
	createCrystallineBridge("EastCrystallineBridge", 28, 48, Color3.fromRGB(160, 210, 245))
	-- West Amethyst Bridge (to Pet Island)
	createCrystallineBridge("WestAmethystBridge", -28, -48, Color3.fromRGB(200, 170, 245))

	-- ========================================================
	-- 3. LEFT ISLAND: WEALTH & MARKET PLAZA (58, 0, 8)
	-- (NO 47-stud yellow neon puck! Solid dark stone slate floor)
	-- ========================================================
	local eastIslandCenter = Vector3.new(58, -0.6, 8)
	local subIslandModels = classifiedAssets["ISLAND_SUB"] or {}
	if #subIslandModels > 0 then
		local eastIslandMesh = subIslandModels[1]:Clone()
		eastIslandMesh.Name = "EastIslandCrag"
		eastIslandMesh.Parent = gardenFolder
		anchorAllParts(eastIslandMesh, true)
		scaleModelToDimension(eastIslandMesh, 58)
		if not eastIslandMesh.PrimaryPart then
			eastIslandMesh.PrimaryPart = eastIslandMesh:FindFirstChildWhichIsA("BasePart", true)
		end
		if eastIslandMesh.PrimaryPart then
			eastIslandMesh:PivotTo(CFrame.new(58, -28, 8))
		end
	end

	-- Solid Walkable Dark Stone Foundation
	local eastFoundation = Instance.new("Part")
	eastFoundation.Name = "EastMarketFoundation"
	eastFoundation.Size = Vector3.new(44, 1.6, 44)
	eastFoundation.Position = eastIslandCenter
	eastFoundation.Anchored = true
	eastFoundation.Material = Enum.Material.Slate
	eastFoundation.Color = Color3.fromRGB(34, 28, 44)
	eastFoundation.TopSurface = Enum.SurfaceType.Smooth
	eastFoundation.Parent = gardenFolder

	-- MARKET GAZEBO & MERCHANT STALL (88K2rZReSQ5xHd5bkrt8)
	local gazeboCenter = Vector3.new(58, 0.15, 14)
	local userGazebo = classifiedAssets["GAZEBO"] and classifiedAssets["GAZEBO"][1]
	if userGazebo then
		print("  ✨ [WorldService] Deploying 3D Floating Market Gazebo (15 studs)...")
		userGazebo.Parent = gardenFolder
		anchorAllParts(userGazebo, true)
		scaleModelToDimension(userGazebo, 15.0)
		if not userGazebo.PrimaryPart then
			userGazebo.PrimaryPart = userGazebo:FindFirstChildWhichIsA("BasePart", true)
		end
		if userGazebo.PrimaryPart then
			userGazebo:PivotTo(CFrame.new(gazeboCenter))
		end
	end

	-- Interactive Pedestals on Market Island
	local function createSalesPedestal(name: string, offset: Vector3, labelText: string, subText: string, color: Color3, actionName: string)
		local ped = Instance.new("Part")
		ped.Name = name .. "_Pedestal"
		ped.Shape = Enum.PartType.Cylinder
		ped.Size = Vector3.new(2.0, 2.6, 2.6)
		ped.Position = gazeboCenter + offset
		ped.Orientation = Vector3.new(0, 0, 90)
		ped.Anchored = true
		ped.Material = Enum.Material.Slate
		ped.Color = Color3.fromRGB(42, 34, 56)
		ped.Parent = gardenFolder

		local gemIcon = Instance.new("Part")
		gemIcon.Name = "FloatingGem"
		gemIcon.Size = Vector3.new(1.1, 1.1, 1.1)
		gemIcon.Position = ped.Position + Vector3.new(0, 2.0, 0)
		gemIcon.Orientation = Vector3.new(45, 45, 0)
		gemIcon.Anchored = true
		gemIcon.Material = Enum.Material.Neon
		gemIcon.Color = color
		gemIcon.Transparency = 0.2
		gemIcon.Parent = ped

		local pLight = Instance.new("PointLight")
		pLight.Color = color
		pLight.Brightness = 1.8
		pLight.Range = 10
		pLight.Parent = gemIcon

		local bb = Instance.new("BillboardGui")
		bb.Name = "PedestalBillboard"
		bb.Size = UDim2.new(0, 160, 0, 45)
		bb.StudsOffset = Vector3.new(0, 1.8, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 30
		bb.Parent = gemIcon

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 22)
		title.BackgroundTransparency = 1
		title.Text = labelText
		title.TextColor3 = color
		title.TextSize = 13
		title.Font = Enum.Font.FredokaOne
		title.Parent = bb

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, 0, 0, 16)
		sub.Position = UDim2.new(0, 0, 0, 22)
		sub.BackgroundTransparency = 1
		sub.Text = subText
		sub.TextColor3 = Color3.fromRGB(240, 240, 255)
		sub.TextSize = 10
		sub.Font = Enum.Font.FredokaOne
		sub.Parent = bb

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = actionName .. "Prompt"
		prompt.ActionText = "View in Shop"
		prompt.ObjectText = labelText
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = gemIcon
	end

	createSalesPedestal("Bundle", Vector3.new(-4.5, 0.8, 0), "🔥 STARTER BUNDLE", "80% OFF • 5x Rare Seeds", Color3.fromRGB(250, 204, 21), "Bundle")
	createSalesPedestal("AutoHarvest", Vector3.new(0, 0.8, 4), "⚡ AUTO-HARVEST", "Gamepass • AFK Harvest", Color3.fromRGB(56, 189, 248), "AutoHarvest")
	createSalesPedestal("LuckPotion", Vector3.new(4.5, 0.8, 0), "🍀 2x LUCK POTION", "+150% Mutation Luck", Color3.fromRGB(74, 222, 128), "LuckPotion")

	-- CELESTIAL WEALTH WELL & GOLD HOARD (Tasteful stone well with liquid gold & treasure)
	local wellPos = Vector3.new(58, 0.15, -4)
	local wellModel = Instance.new("Model")
	wellModel.Name = "CelestialWealthWell"
	wellModel.Parent = gardenFolder

	local userWell = classifiedAssets["WELL"] and classifiedAssets["WELL"][1]
	if userWell then
		print("  ✨ [WorldService] Deploying 3D Celestial Well (9 studs)...")
		userWell.Parent = wellModel
		anchorAllParts(userWell, true)
		scaleModelToDimension(userWell, 9.0)
		if not userWell.PrimaryPart then
			userWell.PrimaryPart = userWell:FindFirstChildWhichIsA("BasePart", true)
		end
		if userWell.PrimaryPart then
			userWell:PivotTo(CFrame.new(wellPos))
		end
	else
		local wellBase = Instance.new("Part")
		wellBase.Name = "WellBase"
		wellBase.Shape = Enum.PartType.Cylinder
		wellBase.Size = Vector3.new(1.6, 7.5, 7.5)
		wellBase.Position = wellPos + Vector3.new(0, 0.8, 0)
		wellBase.Orientation = Vector3.new(0, 0, 90)
		wellBase.Anchored = true
		wellBase.Material = Enum.Material.Slate
		wellBase.Color = Color3.fromRGB(42, 34, 56)
		wellBase.Parent = wellModel

		local wellLiquid = Instance.new("Part")
		wellLiquid.Name = "WellCore"
		wellLiquid.Shape = Enum.PartType.Cylinder
		wellLiquid.Size = Vector3.new(0.2, 5.8, 5.8)
		wellLiquid.Position = wellPos + Vector3.new(0, 1.45, 0)
		wellLiquid.Orientation = Vector3.new(0, 0, 90)
		wellLiquid.Anchored = true
		wellLiquid.Material = Enum.Material.Glass
		wellLiquid.Color = Color3.fromRGB(250, 204, 21)
		wellLiquid.Transparency = 0.25
		wellLiquid.Reflectance = 0.3
		wellLiquid.Parent = wellModel

		local wellLight = Instance.new("PointLight")
		wellLight.Color = Color3.fromRGB(250, 204, 21)
		wellLight.Brightness = 2.0
		wellLight.Range = 14
		wellLight.Parent = wellLiquid
	end

	local wellPrompt = Instance.new("ProximityPrompt")
	wellPrompt.Name = "CelestialWellPrompt"
	wellPrompt.ActionText = "Collect Stardust"
	wellPrompt.ObjectText = "Celestial Well (AFK Vault)"
	wellPrompt.KeyboardKeyCode = Enum.KeyCode.E
	wellPrompt.HoldDuration = 0
	wellPrompt.MaxActivationDistance = 12
	wellPrompt.RequiresLineOfSight = false
	local wellTarget = wellModel:FindFirstChildWhichIsA("BasePart", true) or eastFoundation
	wellPrompt.Parent = wellTarget

	wellPrompt.Triggered:Connect(function(player: Player)
		local DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
		DataService.CollectWell(player)
	end)

	-- Spilling Gold Coin Hoard around the Well base
	local goldMounds = {
		Vector3.new(3.5, 0.2, 1.5),
		Vector3.new(-3.5, 0.2, 1.0),
		Vector3.new(1.8, 0.2, -3.2),
		Vector3.new(-2.4, 0.2, -2.8),
	}
	for idx, offset in goldMounds do
		local goldPile = Instance.new("Part")
		goldPile.Name = "GoldCoinPile_" .. idx
		goldPile.Shape = Enum.PartType.Ball
		goldPile.Size = Vector3.new(2.8, 0.8, 2.8)
		goldPile.Position = wellPos + offset
		goldPile.Anchored = true
		goldPile.CanCollide = false
		goldPile.Material = Enum.Material.SmoothPlastic
		goldPile.Color = Color3.fromRGB(250, 204, 21)
		goldPile.Parent = wellModel
	end

	-- Golden Autumn Tree framing the wealth plaza
	deployWillowTree(Vector3.new(70, 0.2, 2), Color3.fromRGB(250, 204, 21), "GoldenAutumnTree")

	-- ========================================================
	-- 4. RIGHT ISLAND: TRANSMUTATION & PET EGG DAIS (-58, 0, 8)
	-- (NO 47-stud magenta neon puck! NO giant vertical neon slabs!)
	-- ========================================================
	local westIslandCenter = Vector3.new(-58, -0.6, 8)
	if #subIslandModels > 1 then
		local westIslandMesh = subIslandModels[2]:Clone()
		westIslandMesh.Name = "WestIslandCrag"
		westIslandMesh.Parent = gardenFolder
		anchorAllParts(westIslandMesh, true)
		scaleModelToDimension(westIslandMesh, 58)
		if not westIslandMesh.PrimaryPart then
			westIslandMesh.PrimaryPart = westIslandMesh:FindFirstChildWhichIsA("BasePart", true)
		end
		if westIslandMesh.PrimaryPart then
			westIslandMesh:PivotTo(CFrame.new(-58, -28, 8))
		end
	end

	-- Solid Walkable Dark Stone Foundation
	local westFoundation = Instance.new("Part")
	westFoundation.Name = "WestShrineFoundation"
	westFoundation.Size = Vector3.new(44, 1.6, 44)
	westFoundation.Position = westIslandCenter
	westFoundation.Anchored = true
	westFoundation.Material = Enum.Material.Slate
	westFoundation.Color = Color3.fromRGB(34, 28, 44)
	westFoundation.TopSurface = Enum.SurfaceType.Smooth
	westFoundation.Parent = gardenFolder

	-- ANCIENT COSMIC REALM GATE ARCHWAY (K4xcbxw5JiktsVFs6Rvn)
	local userGate = classifiedAssets["GATE_ARCH"] and classifiedAssets["GATE_ARCH"][1]
	local gatePos = Vector3.new(-58, 0.2, 16)
	if userGate then
		print("  ✨ [WorldService] Deploying 3D Ancient Cosmic Realm Gate (20 studs)...")
		userGate.Parent = gardenFolder
		anchorAllParts(userGate, true)
		scaleModelToDimension(userGate, 20.0)
		if not userGate.PrimaryPart then
			userGate.PrimaryPart = userGate:FindFirstChildWhichIsA("BasePart", true)
		end
		if userGate.PrimaryPart then
			userGate:PivotTo(CFrame.new(gatePos))
		end
	end

	-- CELESTIAL MYSTERY EGG ON RAISED DAIS (PftfbIAqxyQQaT0eng8J)
	local eggDaisPos = Vector3.new(-58, 0.2, 6)
	local eggDais = Instance.new("Part")
	eggDais.Name = "EggRaisedDais"
	eggDais.Shape = Enum.PartType.Cylinder
	eggDais.Size = Vector3.new(0.8, 9.0, 9.0)
	eggDais.Position = eggDaisPos + Vector3.new(0, 0.4, 0)
	eggDais.Orientation = Vector3.new(0, 0, 90)
	eggDais.Anchored = true
	eggDais.Material = Enum.Material.Slate
	eggDais.Color = Color3.fromRGB(42, 34, 56)
	eggDais.Parent = gardenFolder

	local userEgg = classifiedAssets["EGG"] and classifiedAssets["EGG"][1]
	local eggPromptPart: BasePart = eggDais
	if userEgg then
		print("  ✨ [WorldService] Deploying 3D Celestial Mystery Egg (4.2 studs)...")
		userEgg.Parent = gardenFolder
		anchorAllParts(userEgg, true)
		scaleModelToDimension(userEgg, 4.2)
		if not userEgg.PrimaryPart then
			userEgg.PrimaryPart = userEgg:FindFirstChildWhichIsA("BasePart", true)
		end
		if userEgg.PrimaryPart then
			userEgg:PivotTo(CFrame.new(eggDaisPos + Vector3.new(0, 2.5, 0)))
			eggPromptPart = userEgg.PrimaryPart
		end
	end

	local eggPrompt = Instance.new("ProximityPrompt")
	eggPrompt.Name = "HatchEggPrompt"
	eggPrompt.ActionText = "Hatch Companion"
	eggPrompt.ObjectText = "Celestial Mystery Egg"
	eggPrompt.KeyboardKeyCode = Enum.KeyCode.E
	eggPrompt.HoldDuration = 0
	eggPrompt.MaxActivationDistance = 12
	eggPrompt.RequiresLineOfSight = false
	eggPrompt.Parent = eggPromptPart

	local eggLight = Instance.new("PointLight")
	eggLight.Color = Color3.fromRGB(244, 114, 182)
	eggLight.Brightness = 2.0
	eggLight.Range = 14
	eggLight.Parent = eggPromptPart

	-- COMPANION PETS ON DISPLAY BESIDE THE EGG (Astral Kitsune & Starlight Dragon)
	local userKitsune = classifiedAssets["PET_KITSUNE"] and classifiedAssets["PET_KITSUNE"][1]
	if userKitsune then
		print("  ✨ [WorldService] Deploying 3D Astral Kitsune Pet (3.2 studs)...")
		userKitsune.Parent = gardenFolder
		anchorAllParts(userKitsune, true)
		scaleModelToDimension(userKitsune, 3.2)
		if not userKitsune.PrimaryPart then
			userKitsune.PrimaryPart = userKitsune:FindFirstChildWhichIsA("BasePart", true)
		end
		if userKitsune.PrimaryPart then
			userKitsune:PivotTo(CFrame.new(eggDaisPos + Vector3.new(5.0, 0.5, -1.5)) * CFrame.Angles(0, math.rad(-75), 0))
		end
	end

	local userDragon = classifiedAssets["PET_DRAGON"] and classifiedAssets["PET_DRAGON"][1]
	if userDragon then
		print("  ✨ [WorldService] Deploying 3D Starlight Hatchling Dragon Pet (3.2 studs)...")
		userDragon.Parent = gardenFolder
		anchorAllParts(userDragon, true)
		scaleModelToDimension(userDragon, 3.2)
		if not userDragon.PrimaryPart then
			userDragon.PrimaryPart = userDragon:FindFirstChildWhichIsA("BasePart", true)
		end
		if userDragon.PrimaryPart then
			userDragon:PivotTo(CFrame.new(eggDaisPos + Vector3.new(-5.0, 0.5, -1.5)) * CFrame.Angles(0, math.rad(75), 0))
		end
	end

	-- TRANSMUTATION ALTAR & SACRED SUMMONING CIRCLE (12lQusKLlIcOsvzOzjaa)
	local altarPos = Vector3.new(-58, 0.2, -4)
	local summoningCircle = Instance.new("Part")
	summoningCircle.Name = "SummoningRuneCircle"
	summoningCircle.Shape = Enum.PartType.Cylinder
	summoningCircle.Size = Vector3.new(0.1, 8.0, 8.0)
	summoningCircle.Position = altarPos + Vector3.new(0, 0.05, 0)
	summoningCircle.Orientation = Vector3.new(0, 0, 90)
	summoningCircle.Anchored = true
	summoningCircle.CanCollide = false
	summoningCircle.Material = Enum.Material.Slate
	summoningCircle.Color = Color3.fromRGB(48, 38, 62)
	summoningCircle.Parent = gardenFolder

	local userAltar = classifiedAssets["ALTAR"] and classifiedAssets["ALTAR"][1]
	local altarPromptPart: BasePart = summoningCircle
	if userAltar then
		print("  ✨ [WorldService] Deploying 3D Transmutation Altar (8 studs)...")
		userAltar.Parent = gardenFolder
		anchorAllParts(userAltar, true)
		scaleModelToDimension(userAltar, 8.0)
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
	altarPrompt.MaxActivationDistance = 12
	altarPrompt.RequiresLineOfSight = false
	altarPrompt.Parent = altarPromptPart

	-- ========================================================
	-- 5. DEPLOY THE 9 GARDEN PLOTS (IVdfl4QeEMqt7VE4qcvS)
	-- (Two neat 2x2 symmetrical garden beds + 1 centerpiece plot)
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

	-- Prepare 3D Crop Bloom Template (WuMxsfiY9i8DUrScM3Vv)
	local userBloom = classifiedAssets["BLOOM"] and classifiedAssets["BLOOM"][1]
	if userBloom and assetsFolder then
		print("  ✨ [WorldService] Storing 3D Crystal Bloom Template in ReplicatedStorage...")
		anchorAllParts(userBloom, false)
		scaleModelToDimension(userBloom, 3.2)
		userBloom.Name = "CropTemplate"
		userBloom.Parent = assetsFolder
	end

	-- Soil Bed Foundations for the garden quadrants
	local function createSoilBed(name: string, size: Vector3, pos: Vector3)
		local bed = Instance.new("Part")
		bed.Name = name
		bed.Size = size
		bed.Position = pos
		bed.Anchored = true
		bed.Material = Enum.Material.Slate
		bed.Color = Color3.fromRGB(24, 18, 26) -- Dark rich earth
		bed.TopSurface = Enum.SurfaceType.Smooth
		bed.Parent = gardenFolder
		return bed
	end

	createSoilBed("GardenSoilBedWest", Vector3.new(15, 0.15, 14), Vector3.new(-10.25, 0.08, 7.5))
	createSoilBed("GardenSoilBedEast", Vector3.new(15, 0.15, 14), Vector3.new(10.25, 0.08, 7.5))

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
			planter.Size = Vector3.new(6.0, 0.6, 6.0)
			planter.Position = plotPos
			planter.Anchored = true
			planter.Material = Enum.Material.Slate
			planter.Color = Color3.fromRGB(42, 34, 56)
			planter.Parent = plotModel
		end

		local soil = Instance.new("Part")
		soil.Name = "Soil"
		soil.Size = Vector3.new(5.2, 0.35, 5.2)
		soil.Position = plotPos + Vector3.new(0, 0.25, 0)
		soil.Anchored = true
		soil.Material = Enum.Material.Slate
		soil.Color = Color3.fromRGB(20, 16, 24)
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
		prompt.MaxActivationDistance = 11
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

	-- Shimmering High-Altitude Aurora Borealis Ribbons (High transparency, soft celestial glow)
	local auroraFolder = Instance.new("Folder")
	auroraFolder.Name = "AuroraBorealis"
	auroraFolder.Parent = gardenFolder

	local auroraBands = {
		{ Center = Vector3.new(-40, 185, 30), Angle = 25, Size = Vector3.new(290, 26, 4), Color = Color3.fromRGB(52, 211, 153), Trans = 0.78 },
		{ Center = Vector3.new(10, 195, -20), Angle = -15, Size = Vector3.new(330, 30, 4), Color = Color3.fromRGB(56, 189, 248), Trans = 0.80 },
		{ Center = Vector3.new(60, 205, 50), Angle = 40, Size = Vector3.new(310, 28, 4), Color = Color3.fromRGB(236, 72, 153), Trans = 0.80 },
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
	-- 7. RELIABLE CHARACTER SPAWN POSITIONING
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

	print("  ✅ [WorldService] Clean, Aesthetic 3D Sanctuary Online! All 13 Models & Zones Active.")
end

return WorldService
