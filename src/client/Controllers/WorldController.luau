--!strict
--[[
	WorldController.luau — 3D Spatial Garden & Cosmic Environment for STARWEAVE
	Spawns a mystical celestial floating island, textured slate planters,
	atmospheric lighting, dynamic crystal crops, and clean growth indicators.
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

local GRID_COLUMNS = 3
local PLOT_SPACING = 9.5 -- slightly more breathing room

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
-- COSMIC ENVIRONMENT & SKYBOX SETUP
-- ============================================================
function WorldController.SetupEnvironment()
	Lighting.ClockTime = 0 -- midnight
	Lighting.GeographicLatitude = 35
	Lighting.Ambient = Color3.fromRGB(48, 38, 68)
	Lighting.OutdoorAmbient = Color3.fromRGB(32, 25, 52)
	Lighting.Brightness = 1.0
	Lighting.ColorShift_Top = Color3.fromRGB(216, 180, 254)
	Lighting.ColorShift_Bottom = Color3.fromRGB(35, 25, 55)
	Lighting.FogColor = Color3.fromRGB(15, 10, 26)
	Lighting.FogEnd = 400
	Lighting.FogStart = 80

	-- Soft balanced Bloom (no blinding glare!)
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "CosmicBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.35
	bloom.Size = 16
	bloom.Threshold = 0.95

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "CosmicGrade"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Saturation = 0.18
	colorCorrection.Contrast = 0.08
	colorCorrection.TintColor = Color3.fromRGB(250, 242, 255)

	-- Cosmic Nebula Skybox
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

	-- Completely destroy default Baseplate and its textures
	for _, child in Workspace:GetDescendants() do
		if child:IsA("BasePart") and string.find(string.lower(child.Name), "baseplate") then
			child:Destroy()
		end
	end

	-- Clean up all existing default SpawnLocations
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

	-- Position clean celestial spawn location directly at the sanctuary entrance
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
	spawn.Color = Color3.fromRGB(24, 18, 38)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	for _, child in spawn:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") then
			child:Destroy()
		end
	end
end

-- ============================================================
-- 3D GARDEN BUILDER
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

	-- Teleport player onto sanctuary terrace
	task.spawn(function()
		local char = player.Character or player.CharacterAdded:Wait()
		local root = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if root then
			root.CFrame = CFrame.new(0, 2.5, -14) * CFrame.Angles(0, 0, 0)
		end
	end)

	-- Void Safety Floor (Massive solid invisible boundary below island)
	local safetyFloor = Instance.new("Part")
	safetyFloor.Name = "SanctuarySafetyFloor"
	safetyFloor.Size = Vector3.new(800, 4, 800)
	safetyFloor.Position = Vector3.new(0, -18, 0)
	safetyFloor.Anchored = true
	safetyFloor.CanCollide = true -- Solid floor so player can NEVER fall into the abyss
	safetyFloor.Transparency = 1
	safetyFloor.Parent = gardenFolder

	safetyFloor.Touched:Connect(function(hit)
		local hitChar = hit.Parent
		if hitChar and hitChar == player.Character then
			local root = hitChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.CFrame = CFrame.new(0, 2.5, -14)
			end
		end
	end)

	-- Spawn Portal Ring Graphic
	local spawnPortal = Instance.new("Part")
	spawnPortal.Name = "SpawnPortalRing"
	spawnPortal.Shape = Enum.PartType.Cylinder
	spawnPortal.Size = Vector3.new(0.08, 6, 6)
	spawnPortal.Position = Vector3.new(0, 0.42, -14)
	spawnPortal.Orientation = Vector3.new(0, 0, 90)
	spawnPortal.Anchored = true
	spawnPortal.Material = Enum.Material.Neon
	spawnPortal.Color = Color3.fromRGB(168, 85, 247)
	spawnPortal.Transparency = 0.75
	spawnPortal.CanCollide = false
	spawnPortal.Parent = gardenFolder

	-- 1. Main Island Body (Large Dark Obsidian Stone Foundation)
	local island = Instance.new("Part")
	island.Name = "SanctuaryIsland"
	island.Size = Vector3.new(64, 2.0, 64)
	island.Position = Vector3.new(0, -1.0, 0)
	island.Anchored = true
	island.Material = Enum.Material.Slate
	island.Color = Color3.fromRGB(16, 12, 26)
	island.TopSurface = Enum.SurfaceType.Smooth
	island.Parent = gardenFolder

	-- Raised Garden Terrace (Inner courtyard)
	local terrace = Instance.new("Part")
	terrace.Name = "GardenTerrace"
	terrace.Size = Vector3.new(42, 0.4, 42)
	terrace.Position = Vector3.new(0, 0.2, 2)
	terrace.Anchored = true
	terrace.Material = Enum.Material.Slate
	terrace.Color = Color3.fromRGB(22, 16, 36)
	terrace.TopSurface = Enum.SurfaceType.Smooth
	terrace.Parent = gardenFolder

	-- Beveled Island Rim (Dark metallic stone)
	local rim = Instance.new("Part")
	rim.Name = "IslandRim"
	rim.Size = Vector3.new(65.6, 0.8, 65.6)
	rim.Position = Vector3.new(0, -1.6, 0)
	rim.Anchored = true
	rim.Material = Enum.Material.SmoothPlastic
	rim.Color = Color3.fromRGB(28, 20, 44)
	rim.CanCollide = false
	rim.Parent = gardenFolder

	-- Subtle floating stardust emitter
	local stardustEmitter = Instance.new("ParticleEmitter")
	stardustEmitter.Name = "AmbientStardust"
	stardustEmitter.Rate = 22
	stardustEmitter.Lifetime = NumberRange.new(4, 7)
	stardustEmitter.Speed = NumberRange.new(0.5, 1.8)
	stardustEmitter.SpreadAngle = Vector2.new(35, 35)
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
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(250, 204, 21)),
	})
	stardustEmitter.LightEmission = 0.8
	stardustEmitter.Parent = terrace

	-- 4 Corner Celestial Lanterns with gentle illumination
	local cornerOffsets = {
		Vector3.new(24, 0, 24),
		Vector3.new(-24, 0, 24),
		Vector3.new(24, 0, -24),
		Vector3.new(-24, 0, -24),
	}

	for idx, offset in cornerOffsets do
		local pillar = Instance.new("Part")
		pillar.Name = `CornerLantern_{idx}`
		pillar.Size = Vector3.new(1.2, 2.8, 1.2)
		pillar.Position = startOrigin + offset + Vector3.new(0, 1.4, 0)
		pillar.Anchored = true
		pillar.Material = Enum.Material.Slate
		pillar.Color = Color3.fromRGB(26, 20, 42)
		pillar.Parent = gardenFolder

		local gem = Instance.new("Part")
		gem.Name = "LanternCrystal"
		gem.Shape = Enum.PartType.Ball
		gem.Size = Vector3.new(1.0, 1.0, 1.0)
		gem.Position = pillar.Position + Vector3.new(0, 1.8, 0)
		gem.Anchored = true
		gem.Material = Enum.Material.Neon
		gem.Color = Color3.fromRGB(192, 132, 252)
		gem.Transparency = 0.2
		gem.CanCollide = false
		gem.Parent = gardenFolder

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(216, 180, 254)
		light.Brightness = 1.2
		light.Range = 18
		light.Shadows = false
		light.Parent = gem
	end

	-- Center Sacred Altar Runes
	local centerRune = Instance.new("Part")
	centerRune.Name = "CenterRune"
	centerRune.Shape = Enum.PartType.Cylinder
	centerRune.Size = Vector3.new(0.1, 4.5, 4.5)
	centerRune.Position = startOrigin + Vector3.new(0, 0.05, 0)
	centerRune.Orientation = Vector3.new(0, 0, 90)
	centerRune.Anchored = true
	centerRune.Material = Enum.Material.Neon
	centerRune.Color = Color3.fromRGB(168, 85, 247)
	centerRune.Transparency = 0.8
	centerRune.CanCollide = false
	centerRune.Parent = gardenFolder

	-- Generate 9 Starting Plots (3x3)
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

	-- Raised Stone Planter Box (Clean dark frame)
	local planter = Instance.new("Part")
	planter.Name = "PlanterBox"
	planter.Size = Vector3.new(6.8, 0.7, 6.8)
	planter.Position = position + Vector3.new(0, 0.35, 0)
	planter.Anchored = true
	planter.Material = Enum.Material.Slate
	planter.Color = Color3.fromRGB(24, 18, 38)
	planter.Parent = plotModel

	-- Rich Celestial Loam Soil
	local soil = Instance.new("Part")
	soil.Name = "Soil"
	soil.Size = Vector3.new(5.8, 0.4, 5.8)
	soil.Position = position + Vector3.new(0, 0.65, 0)
	soil.Anchored = true
	soil.Material = Enum.Material.Slate
	soil.Color = Color3.fromRGB(14, 10, 22)
	soil.TopSurface = Enum.SurfaceType.Smooth
	soil.Parent = plotModel

	-- Faint Runic Inset Ring (Non-blinding, soft accent)
	local runeBorder = Instance.new("Part")
	runeBorder.Name = "RuneTrim"
	runeBorder.Size = Vector3.new(6.0, 0.05, 6.0)
	runeBorder.Position = position + Vector3.new(0, 0.72, 0)
	runeBorder.Anchored = true
	runeBorder.Material = Enum.Material.SmoothPlastic
	runeBorder.Color = Color3.fromRGB(88, 28, 135)
	runeBorder.Transparency = 0.5
	runeBorder.CanCollide = false
	runeBorder.Parent = plotModel

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

	-- Modern Minimal Floating Badge (ONLY SHOWN WHEN CROP IS ACTIVE!)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlotBillboard"
	billboard.Size = UDim2.new(0, 140, 0, 48)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = false -- Respects 3D depth!
	billboard.MaxDistance = 28 -- Only visible when reasonably close!
	billboard.Enabled = false -- HIDDEN BY DEFAULT on empty plots!
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
-- 3D CROP VISUAL BUILDER
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

	-- 1. EMPTY PLOT: Completely clean, NO cluttering billboard!
	if not plant then
		prompt.Enabled = true
		prompt.ActionText = "Plant Seed"
		prompt.ObjectText = `Plot #{plotIndex}`
		billboard.Enabled = false -- Clean!
		return
	end

	local seedDef = SeedData.GetSeed(plant.SeedId)
	local seedColor = SEED_COLORS[plant.SeedId] or Color3.fromRGB(168, 85, 247)

	-- 2. GROWING PLOT: Shows neat progress countdown
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

		-- Elegant Sprout Stem
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

	-- 3. READY TO HARVEST: Golden bloom
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

		-- Full Blooming Crystal Flower
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

		-- Soft Harvest Glow
		local bloomLight = Instance.new("PointLight")
		bloomLight.Color = seedColor
		bloomLight.Brightness = 1.4
		bloomLight.Range = 10
		bloomLight.Parent = core
	end
end

-- ============================================================
-- CONTINUOUS RENDER LOOP (Crop timers & rotation)
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

			-- Smooth Core Rotation
			for i = #WorldController._rotatingCores, 1, -1 do
				local core = WorldController._rotatingCores[i]
				if core and core.Parent then
					core.CFrame = core.CFrame * CFrame.Angles(0, math.rad(1.2), 0)
				else
					table.remove(WorldController._rotatingCores, i)
				end
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
