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
local START_ORIGIN = Vector3.new(0, 0, 8)

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

	-- 1. Setup Environment Authoritatively (Vibrant Fairy-Tale Sanctuary)
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 25
	Lighting.Ambient = Color3.fromRGB(165, 150, 215)
	Lighting.OutdoorAmbient = Color3.fromRGB(185, 170, 235)
	Lighting.Brightness = 3.2
	Lighting.ColorShift_Top = Color3.fromRGB(255, 248, 235)
	Lighting.ColorShift_Bottom = Color3.fromRGB(120, 100, 160)
	Lighting.FogColor = Color3.fromRGB(180, 160, 230)
	Lighting.FogEnd = 30000

	-- Cinematic Atmospheric Post-Processing
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Name = "SanctuaryBloom"
	bloom.Intensity = 0.65
	bloom.Size = 24
	bloom.Threshold = 0.82
	bloom.Parent = Lighting

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "SanctuaryColorCorrection"
	colorCorrection.Saturation = 0.18
	colorCorrection.Contrast = 0.08
	colorCorrection.TintColor = Color3.fromRGB(255, 250, 255)
	colorCorrection.Parent = Lighting

	local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	sunRays.Name = "SanctuarySunRays"
	sunRays.Intensity = 0.15
	sunRays.Spread = 0.8
	sunRays.Parent = Lighting

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "SanctuaryAtmosphere"
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(200, 185, 245)
	atmosphere.Decay = Color3.fromRGB(130, 105, 180)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 0.75
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

	-- Create SanctuarySpawn (Solid, raised, elevated above pavers, facing garden)
	local spawn = Workspace:FindFirstChild("SanctuarySpawn") :: SpawnLocation?
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SanctuarySpawn"
		spawn.Parent = Workspace
	end
	spawn.Size = Vector3.new(10, 0.5, 10)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, -14), Vector3.new(0, 1.2, 0))
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

	-- ========================================================
	-- 1. CENTRAL BOTANICAL SANCTUARY ISLAND
	-- ========================================================
	local islandModel = classifiedAssets["ISLAND"]
	if islandModel then
		print("  ✨ [WorldService] Deploying 3D Floating Sanctuary Island (110 studs)...")
		islandModel.Parent = gardenFolder
		anchorAllParts(islandModel, true)
		scaleModelToDimension(islandModel, 110)
		if not islandModel.PrimaryPart then
			islandModel.PrimaryPart = islandModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if islandModel.PrimaryPart then
			islandModel:PivotTo(CFrame.new(0, -42.0, 8))
		end
	end

	-- Center Island Foundation (Solid Walkable Base)
	local centerIsland = Instance.new("Part")
	centerIsland.Name = "CenterIslandFoundation"
	centerIsland.Size = Vector3.new(78, 2.5, 78)
	centerIsland.Position = Vector3.new(0, -1.0, 8)
	centerIsland.Anchored = true
	centerIsland.Material = Enum.Material.Slate
	centerIsland.Color = Color3.fromRGB(32, 26, 48)
	centerIsland.TopSurface = Enum.SurfaceType.Smooth
	centerIsland.Parent = gardenFolder

	local centerRuneRim = Instance.new("Part")
	centerRuneRim.Name = "CenterRuneRim"
	centerRuneRim.Shape = Enum.PartType.Cylinder
	centerRuneRim.Size = Vector3.new(0.5, 79, 79)
	centerRuneRim.Position = Vector3.new(0, 0.25, 8)
	centerRuneRim.Orientation = Vector3.new(0, 0, 90)
	centerRuneRim.Anchored = true
	centerRuneRim.CanCollide = false
	centerRuneRim.Material = Enum.Material.Neon
	centerRuneRim.Color = Color3.fromRGB(168, 85, 247)
	centerRuneRim.Transparency = 0.6
	centerRuneRim.Parent = gardenFolder

	local terrace = Instance.new("Part")
	terrace.Name = "GardenTerraceFoundation"
	terrace.Size = Vector3.new(48, 0.4, 48)
	terrace.Position = Vector3.new(0, 0.2, 8)
	terrace.Anchored = true
	terrace.Material = Enum.Material.Slate
	terrace.Color = Color3.fromRGB(42, 34, 62)
	terrace.TopSurface = Enum.SurfaceType.Smooth
	terrace.Parent = gardenFolder

	-- Ambient Floating Stardust on Terrace
	local stardustEmitter = Instance.new("ParticleEmitter")
	stardustEmitter.Name = "AmbientStardust"
	stardustEmitter.Rate = 32
	stardustEmitter.Lifetime = NumberRange.new(4, 7)
	stardustEmitter.Speed = NumberRange.new(0.5, 1.8)
	stardustEmitter.SpreadAngle = Vector2.new(45, 45)
	stardustEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	stardustEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.15),
		NumberSequenceKeypoint.new(0.8, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	stardustEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 210, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(250, 204, 21)),
	})
	stardustEmitter.LightEmission = 0.85
	stardustEmitter.Parent = terrace

	-- Spawn Pavilion (Elevated Cylinder facing garden)
	local spawnPavilion = Instance.new("Part")
	spawnPavilion.Name = "SpawnPavilion"
	spawnPavilion.Shape = Enum.PartType.Cylinder
	spawnPavilion.Size = Vector3.new(1.2, 16, 16)
	spawnPavilion.Position = Vector3.new(0, 0.6, -14)
	spawnPavilion.Orientation = Vector3.new(0, 0, 90)
	spawnPavilion.Anchored = true
	spawnPavilion.CanCollide = true
	spawnPavilion.Material = Enum.Material.Slate
	spawnPavilion.Color = Color3.fromRGB(38, 30, 56)
	spawnPavilion.Parent = gardenFolder

	local spawnRune = Instance.new("Part")
	spawnRune.Name = "SpawnRune"
	spawnRune.Shape = Enum.PartType.Cylinder
	spawnRune.Size = Vector3.new(0.05, 12, 12)
	spawnRune.Position = Vector3.new(0, 1.15, -14)
	spawnRune.Orientation = Vector3.new(0, 0, 90)
	spawnRune.Anchored = true
	spawnRune.CanCollide = false
	spawnRune.Material = Enum.Material.Neon
	spawnRune.Color = Color3.fromRGB(192, 132, 252)
	spawnRune.Transparency = 0.45
	spawnRune.Parent = gardenFolder

	-- Decorative Celestial Archway (Non-colliding so PopperCam NEVER occludes player)
	local archModel = Instance.new("Model")
	archModel.Name = "CelestialArchway"
	archModel.Parent = gardenFolder

	local function makeDecorPart(name: string, size: Vector3, pos: Vector3, mat: Enum.Material, col: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Material = mat
		p.Color = col
		p.Parent = archModel
		return p
	end

	makeDecorPart("PillarLeft", Vector3.new(2.2, 12, 2.2), Vector3.new(-8, 6.0, -20), Enum.Material.Slate, Color3.fromRGB(38, 30, 56))
	makeDecorPart("CapLeft", Vector3.new(3, 1, 3), Vector3.new(-8, 12.2, -20), Enum.Material.Neon, Color3.fromRGB(192, 132, 252))
	makeDecorPart("PillarRight", Vector3.new(2.2, 12, 2.2), Vector3.new(8, 6.0, -20), Enum.Material.Slate, Color3.fromRGB(38, 30, 56))
	makeDecorPart("CapRight", Vector3.new(3, 1, 3), Vector3.new(8, 12.2, -20), Enum.Material.Neon, Color3.fromRGB(192, 132, 252))
	makeDecorPart("ArchBeam", Vector3.new(18.4, 1.8, 2.4), Vector3.new(0, 12.5, -20), Enum.Material.Slate, Color3.fromRGB(48, 38, 72))
	local sigil = makeDecorPart("StarSigil", Vector3.new(2.4, 2.4, 0.4), Vector3.new(0, 12.5, -18.6), Enum.Material.Neon, Color3.fromRGB(250, 204, 21))
	sigil.Orientation = Vector3.new(0, 0, 45)

	-- ========================================================
	-- 2. SOUTH ASTRAL REALM GATEWAY (LOCKED PROGRESSION ZONE)
	-- ========================================================
	local gateModel = Instance.new("Model")
	gateModel.Name = "AstralRealmGate"
	gateModel.Parent = gardenFolder

	local obeliskL = Instance.new("Part")
	obeliskL.Name = "ObeliskLeft"
	obeliskL.Size = Vector3.new(3.5, 18, 3.5)
	obeliskL.Position = Vector3.new(-11, 8.5, -28)
	obeliskL.Anchored = true
	obeliskL.Material = Enum.Material.Slate
	obeliskL.Color = Color3.fromRGB(26, 20, 42)
	obeliskL.Parent = gateModel

	local obeliskR = Instance.new("Part")
	obeliskR.Name = "ObeliskRight"
	obeliskR.Size = Vector3.new(3.5, 18, 3.5)
	obeliskR.Position = Vector3.new(11, 8.5, -28)
	obeliskR.Anchored = true
	obeliskR.Material = Enum.Material.Slate
	obeliskR.Color = Color3.fromRGB(26, 20, 42)
	obeliskR.Parent = gateModel

	local barrier = Instance.new("Part")
	barrier.Name = "BarrierForcefield"
	barrier.Size = Vector3.new(18.5, 15, 1.5)
	barrier.Position = Vector3.new(0, 8.0, -28)
	barrier.Anchored = true
	barrier.CanCollide = true
	barrier.Material = Enum.Material.ForceField
	barrier.Color = Color3.fromRGB(168, 85, 247)
	barrier.Transparency = 0.35
	barrier.Parent = gateModel

	local barrierLight = Instance.new("PointLight")
	barrierLight.Color = Color3.fromRGB(168, 85, 247)
	barrierLight.Brightness = 3.0
	barrierLight.Range = 22
	barrierLight.Parent = barrier

	local gatePrompt = Instance.new("ProximityPrompt")
	gatePrompt.Name = "RealmGatePrompt"
	gatePrompt.ActionText = "Inspect Realm Barrier"
	gatePrompt.ObjectText = "Astral Realm (Locked)"
	gatePrompt.KeyboardKeyCode = Enum.KeyCode.E
	gatePrompt.HoldDuration = 0
	gatePrompt.MaxActivationDistance = 14
	gatePrompt.RequiresLineOfSight = false
	gatePrompt.Parent = barrier

	-- Overhead Locked Realm Billboard
	local gateBillboard = Instance.new("BillboardGui")
	gateBillboard.Name = "GateBillboard"
	gateBillboard.Size = UDim2.new(0, 320, 0, 70)
	gateBillboard.StudsOffset = Vector3.new(0, 9.5, 0)
	gateBillboard.AlwaysOnTop = true
	gateBillboard.MaxDistance = 60
	gateBillboard.Parent = barrier

	local gateTitle = Instance.new("TextLabel")
	gateTitle.Size = UDim2.new(1, 0, 0, 32)
	gateTitle.BackgroundTransparency = 1
	gateTitle.Text = "🔒 ASTRAL REALM"
	gateTitle.TextColor3 = Color3.fromRGB(244, 114, 182)
	gateTitle.TextSize = 22
	gateTitle.Font = Enum.Font.FredokaOne
	gateTitle.Parent = gateBillboard

	local gateSub = Instance.new("TextLabel")
	gateSub.Size = UDim2.new(1, 0, 0, 24)
	gateSub.Position = UDim2.new(0, 0, 0, 32)
	gateSub.BackgroundTransparency = 1
	gateSub.Text = "Unlocks at Rebirth 1 (Level 5)"
	gateSub.TextColor3 = Color3.fromRGB(254, 240, 138)
	gateSub.TextSize = 14
	gateSub.Font = Enum.Font.FredokaOne
	gateSub.Parent = gateBillboard

	-- ========================================================
	-- 3. NORTH STARLIGHT OBSERVATORY (PANORAMIC OVERLOOK)
	-- ========================================================
	local balcony = Instance.new("Part")
	balcony.Name = "ObservatoryBalcony"
	balcony.Shape = Enum.PartType.Cylinder
	balcony.Size = Vector3.new(1.2, 22, 22)
	balcony.Position = Vector3.new(0, 0.6, 36)
	balcony.Orientation = Vector3.new(0, 0, 90)
	balcony.Anchored = true
	balcony.Material = Enum.Material.Slate
	balcony.Color = Color3.fromRGB(36, 28, 54)
	balcony.Parent = gardenFolder

	local telescopeBase = Instance.new("Part")
	telescopeBase.Name = "TelescopeBase"
	telescopeBase.Size = Vector3.new(2.4, 3.2, 2.4)
	telescopeBase.Position = Vector3.new(0, 2.4, 39)
	telescopeBase.Anchored = true
	telescopeBase.Material = Enum.Material.SmoothPlastic
	telescopeBase.Color = Color3.fromRGB(250, 204, 21)
	telescopeBase.Parent = gardenFolder

	local telescopeTube = Instance.new("Part")
	telescopeTube.Name = "TelescopeTube"
	telescopeTube.Size = Vector3.new(1.2, 6.0, 1.2)
	telescopeTube.Position = Vector3.new(0, 4.4, 40)
	telescopeTube.Orientation = Vector3.new(35, 0, 0)
	telescopeTube.Anchored = true
	telescopeTube.Material = Enum.Material.Neon
	telescopeTube.Color = Color3.fromRGB(56, 189, 248)
	telescopeTube.Parent = gardenFolder

	local telePrompt = Instance.new("ProximityPrompt")
	telePrompt.Name = "TelescopePrompt"
	telePrompt.ActionText = "Stargaze"
	telePrompt.ObjectText = "Celestial Telescope (Skill Tree)"
	telePrompt.KeyboardKeyCode = Enum.KeyCode.E
	telePrompt.HoldDuration = 0
	telePrompt.MaxActivationDistance = 14
	telePrompt.RequiresLineOfSight = false
	telePrompt.Parent = telescopeBase

	-- ========================================================
	-- 4. EAST ISLAND & BRIDGE (WEALTH & MARKET PLAZA)
	-- ========================================================
	-- Arched Crystalline Bridge to East
	local eastBridge = Instance.new("Part")
	eastBridge.Name = "EastStarlightBridge"
	eastBridge.Size = Vector3.new(18, 0.8, 8)
	eastBridge.Position = Vector3.new(32, 0.4, 8)
	eastBridge.Anchored = true
	eastBridge.CanCollide = true
	eastBridge.Material = Enum.Material.Glass
	eastBridge.Color = Color3.fromRGB(56, 189, 248)
	eastBridge.Transparency = 0.3
	eastBridge.Parent = gardenFolder

	-- East Island Foundation
	local eastIsland = Instance.new("Part")
	eastIsland.Name = "EastMarketIsland"
	eastIsland.Size = Vector3.new(46, 2.0, 46)
	eastIsland.Position = Vector3.new(58, -1.0, 8)
	eastIsland.Anchored = true
	eastIsland.Material = Enum.Material.Slate
	eastIsland.Color = Color3.fromRGB(32, 26, 48)
	eastIsland.Parent = gardenFolder

	local eastRim = Instance.new("Part")
	eastRim.Name = "EastGoldRim"
	eastRim.Shape = Enum.PartType.Cylinder
	eastRim.Size = Vector3.new(0.4, 47, 47)
	eastRim.Position = Vector3.new(58, 0.2, 8)
	eastRim.Orientation = Vector3.new(0, 0, 90)
	eastRim.Anchored = true
	eastRim.CanCollide = false
	eastRim.Material = Enum.Material.Neon
	eastRim.Color = Color3.fromRGB(250, 204, 21)
	eastRim.Transparency = 0.6
	eastRim.Parent = gardenFolder

	-- Celestial Well on East Island
	local wellPos = Vector3.new(58, 0.4, 0)
	local wellModel = Instance.new("Model")
	wellModel.Name = "CelestialWell"
	wellModel.Parent = gardenFolder

	local wellPatio = Instance.new("Part")
	wellPatio.Name = "WellPatio"
	wellPatio.Shape = Enum.PartType.Cylinder
	wellPatio.Size = Vector3.new(0.6, 13, 13)
	wellPatio.Position = wellPos + Vector3.new(0, 0.1, 0)
	wellPatio.Orientation = Vector3.new(0, 0, 90)
	wellPatio.Anchored = true
	wellPatio.Material = Enum.Material.Slate
	wellPatio.Color = Color3.fromRGB(34, 28, 50)
	wellPatio.Parent = wellModel

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
	wellLight.Brightness = 2.4
	wellLight.Range = 18
	wellLight.Parent = wellLiquid

	local wellParticles = Instance.new("ParticleEmitter")
	wellParticles.Name = "WellParticles"
	wellParticles.Rate = 22
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

	-- Connect server-side well collection
	wellPrompt.Triggered:Connect(function(player: Player)
		local DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
		DataService.CollectWell(player)
	end)

	-- In-World Merchant Gazebo & 3D Interactive Sales Pedestals
	local gazeboCenter = Vector3.new(58, 0.4, 16)
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
		pLight.Brightness = 2.0
		pLight.Range = 10
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

	-- ========================================================
	-- 5. WEST ISLAND & BRIDGE (ALTAR & PET COMPANION HAVEN)
	-- ========================================================
	-- Arched Amethyst Bridge to West
	local westBridge = Instance.new("Part")
	westBridge.Name = "WestAmethystBridge"
	westBridge.Size = Vector3.new(18, 0.8, 8)
	westBridge.Position = Vector3.new(-32, 0.4, 8)
	westBridge.Anchored = true
	westBridge.CanCollide = true
	westBridge.Material = Enum.Material.Glass
	westBridge.Color = Color3.fromRGB(168, 85, 247)
	westBridge.Transparency = 0.3
	westBridge.Parent = gardenFolder

	-- West Island Foundation
	local westIsland = Instance.new("Part")
	westIsland.Name = "WestShrineIsland"
	westIsland.Size = Vector3.new(46, 2.0, 46)
	westIsland.Position = Vector3.new(-58, -1.0, 8)
	westIsland.Anchored = true
	westIsland.Material = Enum.Material.Slate
	westIsland.Color = Color3.fromRGB(32, 26, 48)
	westIsland.Parent = gardenFolder

	local westRim = Instance.new("Part")
	westRim.Name = "WestAmethystRim"
	westRim.Shape = Enum.PartType.Cylinder
	westRim.Size = Vector3.new(0.4, 47, 47)
	westRim.Position = Vector3.new(-58, 0.2, 8)
	westRim.Orientation = Vector3.new(0, 0, 90)
	westRim.Anchored = true
	westRim.CanCollide = false
	westRim.Material = Enum.Material.Neon
	westRim.Color = Color3.fromRGB(168, 85, 247)
	westRim.Transparency = 0.6
	westRim.Parent = gardenFolder

	-- Transmutation Altar on West Island
	local altarModel = classifiedAssets["ALTAR"]
	local altarPos = Vector3.new(-58, 0.4, 14)

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
		altarPrompt.ObjectText = "Sacred Altar (Forge)"
		altarPrompt.KeyboardKeyCode = Enum.KeyCode.E
		altarPrompt.HoldDuration = 0
		altarPrompt.MaxActivationDistance = 14
		altarPrompt.RequiresLineOfSight = false
		altarPrompt.Parent = promptPart

		local altarLight = Instance.new("PointLight")
		altarLight.Color = Color3.fromRGB(168, 85, 247)
		altarLight.Brightness = 2.8
		altarLight.Range = 18
		altarLight.Parent = promptPart
	else
		-- Procedural Altar Dais Fallback
		local altarDais = Instance.new("Part")
		altarDais.Name = "AltarDais"
		altarDais.Size = Vector3.new(8, 1.8, 8)
		altarDais.Position = altarPos + Vector3.new(0, 0.9, 0)
		altarDais.Anchored = true
		altarDais.Material = Enum.Material.Slate
		altarDais.Color = Color3.fromRGB(48, 36, 74)
		altarDais.Parent = gardenFolder

		local altarRune = Instance.new("Part")
		altarRune.Name = "AltarRune"
		altarRune.Size = Vector3.new(6, 0.2, 6)
		altarRune.Position = altarPos + Vector3.new(0, 1.9, 0)
		altarRune.Anchored = true
		altarRune.Material = Enum.Material.Neon
		altarRune.Color = Color3.fromRGB(168, 85, 247)
		altarRune.Parent = gardenFolder

		local altarPrompt = Instance.new("ProximityPrompt")
		altarPrompt.Name = "AltarForgePrompt"
		altarPrompt.ActionText = "Transmute Seeds"
		altarPrompt.ObjectText = "Sacred Altar (Forge)"
		altarPrompt.KeyboardKeyCode = Enum.KeyCode.E
		altarPrompt.HoldDuration = 0
		altarPrompt.MaxActivationDistance = 14
		altarPrompt.RequiresLineOfSight = false
		altarPrompt.Parent = altarRune
	end

	-- Celestial Pet Egg Shrine on West Island
	local eggModel = classifiedAssets["EGG"]
	local eggPos = Vector3.new(-58, 1.4, 0)

	local eggPedestal = Instance.new("Part")
	eggPedestal.Name = "EggPedestal"
	eggPedestal.Shape = Enum.PartType.Cylinder
	eggPedestal.Size = Vector3.new(1.0, 7.0, 7.0)
	eggPedestal.Position = eggPos + Vector3.new(0, -0.6, 0)
	eggPedestal.Orientation = Vector3.new(0, 0, 90)
	eggPedestal.Anchored = true
	eggPedestal.Material = Enum.Material.Slate
	eggPedestal.Color = Color3.fromRGB(30, 24, 46)
	eggPedestal.Parent = gardenFolder

	local eggRune = Instance.new("Part")
	eggRune.Name = "EggRuneRing"
	eggRune.Shape = Enum.PartType.Cylinder
	eggRune.Size = Vector3.new(0.2, 8.2, 8.2)
	eggRune.Position = eggPos + Vector3.new(0, -0.1, 0)
	eggRune.Orientation = Vector3.new(0, 0, 90)
	eggRune.Anchored = true
	eggRune.CanCollide = false
	eggRune.Material = Enum.Material.Neon
	eggRune.Color = Color3.fromRGB(244, 114, 182)
	eggRune.Transparency = 0.5
	eggRune.Parent = gardenFolder

	local eggPromptPart = eggPedestal
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
			eggPromptPart = eggModel.PrimaryPart
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
	eggLight.Brightness = 2.4
	eggLight.Range = 16
	eggLight.Parent = eggPromptPart

	-- 2 Sculpted Bioluminescent Willow Trees on West Island
	local function createWillowTree(tPos: Vector3, leafColor: Color3)
		local trunk = Instance.new("Part")
		trunk.Name = "WillowTrunk"
		trunk.Size = Vector3.new(1.8, 10, 1.8)
		trunk.Position = tPos + Vector3.new(0, 5, 0)
		trunk.Anchored = true
		trunk.CanCollide = false
		trunk.Material = Enum.Material.Wood
		trunk.Color = Color3.fromRGB(34, 26, 44)
		trunk.Parent = gardenFolder

		local canopy = Instance.new("Part")
		canopy.Name = "WillowCanopy"
		canopy.Shape = Enum.PartType.Ball
		canopy.Size = Vector3.new(9, 7, 9)
		canopy.Position = tPos + Vector3.new(0, 11, 0)
		canopy.Anchored = true
		canopy.CanCollide = false
		canopy.Material = Enum.Material.Neon
		canopy.Color = leafColor
		canopy.Transparency = 0.3
		canopy.Parent = gardenFolder

		local spores = Instance.new("ParticleEmitter")
		spores.Name = "FallingSpores"
		spores.Rate = 14
		spores.Lifetime = NumberRange.new(3, 6)
		spores.Speed = NumberRange.new(0.4, 1.2)
		spores.SpreadAngle = Vector2.new(60, 60)
		spores.Color = ColorSequence.new(leafColor)
		spores.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		spores.LightEmission = 0.8
		spores.Parent = canopy
	end

	createWillowTree(Vector3.new(-70, 0.4, 2), Color3.fromRGB(244, 114, 182))
	createWillowTree(Vector3.new(-70, 0.4, 14), Color3.fromRGB(168, 85, 247))

	-- ========================================================
	-- 6. VOLUMETRIC CLOUD SEA (UNDERNEATH ARCHIPELAGO)
	-- ========================================================
	local cloudPositions = {
		Vector3.new(0, -9, 8),
		Vector3.new(-22, -8, 8),
		Vector3.new(22, -8, 8),
		Vector3.new(48, -10, 8),
		Vector3.new(-48, -10, 8),
		Vector3.new(0, -9, -16),
		Vector3.new(0, -9, 30),
		Vector3.new(28, -11, 26),
		Vector3.new(-28, -11, 26),
		Vector3.new(32, -11, -12),
		Vector3.new(-32, -11, -12),
		Vector3.new(60, -9, -8),
		Vector3.new(-60, -9, -8),
		Vector3.new(60, -9, 22),
		Vector3.new(-60, -9, 22),
	}
	for idx, cPos in cloudPositions do
		local cloud = Instance.new("Part")
		cloud.Name = "CloudSeaPart_" .. idx
		cloud.Shape = Enum.PartType.Ball
		local cSize = 22 + (idx % 3) * 6
		cloud.Size = Vector3.new(cSize, 10, cSize)
		cloud.Position = cPos
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Color = Color3.fromRGB(240, 235, 255)
		cloud.Transparency = 0.58
		cloud.Parent = gardenFolder
	end

	-- ========================================================
	-- 7. DISTANT FLOATING SKY ISLANDS
	-- ========================================================
	local skyIslandConfigs = {
		{ Pos = Vector3.new(110, 35, 80), Size = 32, CrystalColor = Color3.fromRGB(56, 189, 248) },
		{ Pos = Vector3.new(-110, 42, 75), Size = 28, CrystalColor = Color3.fromRGB(168, 85, 247) },
		{ Pos = Vector3.new(120, 30, -70), Size = 30, CrystalColor = Color3.fromRGB(250, 204, 21) },
		{ Pos = Vector3.new(-115, 48, -65), Size = 26, CrystalColor = Color3.fromRGB(244, 114, 182) },
	}
	for idx, sCfg in skyIslandConfigs do
		local sIsland = Instance.new("Part")
		sIsland.Name = "SkyIsland_" .. idx
		sIsland.Shape = Enum.PartType.Cylinder
		sIsland.Size = Vector3.new(6, sCfg.Size, sCfg.Size)
		sIsland.Position = sCfg.Pos
		sIsland.Orientation = Vector3.new(0, 0, 90)
		sIsland.Anchored = true
		sIsland.Material = Enum.Material.Slate
		sIsland.Color = Color3.fromRGB(36, 28, 52)
		sIsland.Parent = gardenFolder

		local spire = Instance.new("Part")
		spire.Name = "CrystalSpire"
		spire.Size = Vector3.new(4.2, 18, 4.2)
		spire.Position = sCfg.Pos + Vector3.new(0, 11, 0)
		spire.Anchored = true
		spire.Material = Enum.Material.Neon
		spire.Color = sCfg.CrystalColor
		spire.Orientation = Vector3.new(10, 15, -8)
		spire.Parent = gardenFolder

		local sLight = Instance.new("PointLight")
		sLight.Color = sCfg.CrystalColor
		sLight.Brightness = 3.5
		sLight.Range = 45
		sLight.Parent = spire
	end

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

	-- 5. ENSURE RELIABLE CHARACTER SPAWN POSITIONING (PAVILION LOOKING AT GARDEN)
	local function onCharacterAdded(player: Player, character: Model)
		local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if hrp then
			task.wait(0.08)
			hrp.CFrame = CFrame.lookAt(Vector3.new(0, 3.5, -14), Vector3.new(0, 3.5, 0))
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

	print("  ✅ [WorldService] Authoritative 3D Sanctuary Online! All 9 Plots & Meshes Deployed.")
end

return WorldService
