--!strict
--[[
	WorldController.luau — 3D Spatial Garden & Cosmic Environment for STARWEAVE
	Spawns physical 3D garden beds, glowing plots, animated crystal crop models,
	floating 3D Billboard tags, and configures cinematic cosmic Lighting.
	Located in: StarterPlayerScripts.Client.Controllers.WorldController
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SeedData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeedData"))
local MutationData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MutationData"))

local SoundController = require(script.Parent.SoundController)
local VFXController = require(script.Parent.VFXController)

local player = Players.LocalPlayer

local WorldController = {}
WorldController._plotModels = {} :: { [number]: Model }
WorldController._plotData = {} :: { [number]: any }
WorldController._gardenFolder = nil :: Folder?
WorldController._selectedSeedId = "starseed_basic"
WorldController._data = nil :: any

local PLOT_SPACING = 9
local GRID_COLUMNS = 3

local SEED_COLORS: { [string]: Color3 } = {
	starseed_basic = Color3.fromRGB(192, 132, 252),
	lunar_sprout = Color3.fromRGB(96, 165, 250),
	dust_bloom = Color3.fromRGB(244, 114, 182),
	solar_fern = Color3.fromRGB(251, 191, 36),
	crystal_vine = Color3.fromRGB(45, 212, 191),
	nebula_moss = Color3.fromRGB(167, 139, 250),
	aurora_blossom = Color3.fromRGB(56, 189, 248),
	gravity_root = Color3.fromRGB(129, 140, 248),
	comet_tulip = Color3.fromRGB(251, 146, 60),
	supernova_orchid = Color3.fromRGB(244, 63, 94),
	quasar_lily = Color3.fromRGB(168, 85, 247),
	blackhole_rose = Color3.fromRGB(30, 27, 75),
	dimension_tree = Color3.fromRGB(13, 148, 136),
	genesis_bloom = Color3.fromRGB(250, 204, 21),
	void_singularity = Color3.fromRGB(15, 23, 42),
}

-- ============================================================
-- COSMIC ENVIRONMENT SETUP
-- ============================================================
function WorldController.SetupEnvironment()
	Lighting.ClockTime = 22.5
	Lighting.GeographicLatitude = 45
	Lighting.Ambient = Color3.fromRGB(35, 25, 55)
	Lighting.OutdoorAmbient = Color3.fromRGB(22, 16, 42)
	Lighting.Brightness = 1.2
	Lighting.ColorShift_Top = Color3.fromRGB(192, 132, 252)
	Lighting.ColorShift_Bottom = Color3.fromRGB(30, 20, 50)
	Lighting.FogColor = Color3.fromRGB(18, 12, 34)
	Lighting.FogEnd = 350
	Lighting.FogStart = 50

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "CosmicBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.75
	bloom.Size = 24
	bloom.Threshold = 0.82

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "CosmicGrade"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Saturation = 0.25
	colorCorrection.Contrast = 0.12
	colorCorrection.TintColor = Color3.fromRGB(245, 235, 255)
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

	local startOrigin = Vector3.new(0, 0, 25)

	-- Sanctuary Base Platform
	local platform = Instance.new("Part")
	platform.Name = "SanctuaryPlatform"
	platform.Size = Vector3.new(36, 1.2, 36)
	platform.Position = startOrigin - Vector3.new(0, 0.6, 0)
	platform.Anchored = true
	platform.Material = Enum.Material.SmoothPlastic
	platform.Color = Color3.fromRGB(18, 14, 32)
	platform.Parent = gardenFolder

	local platformBorder = Instance.new("Part")
	platformBorder.Name = "PlatformNeonBorder"
	platformBorder.Size = Vector3.new(36.8, 0.4, 36.8)
	platformBorder.Position = startOrigin - Vector3.new(0, 0.1, 0)
	platformBorder.Anchored = true
	platformBorder.Material = Enum.Material.Neon
	platformBorder.Color = Color3.fromRGB(147, 51, 234)
	platformBorder.Transparency = 0.3
	platformBorder.CanCollide = false
	platformBorder.Parent = gardenFolder

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

	-- Soil Base
	local soil = Instance.new("Part")
	soil.Name = "Soil"
	soil.Size = Vector3.new(6.5, 0.6, 6.5)
	soil.Position = position + Vector3.new(0, 0.3, 0)
	soil.Anchored = true
	soil.Material = Enum.Material.Slate
	soil.Color = Color3.fromRGB(24, 18, 36)
	soil.TopSurface = Enum.SurfaceType.Smooth
	soil.Parent = plotModel

	-- Neon Runic Frame
	local border = Instance.new("Part")
	border.Name = "NeonTrim"
	border.Size = Vector3.new(6.8, 0.2, 6.8)
	border.Position = position + Vector3.new(0, 0.55, 0)
	border.Anchored = true
	border.CanCollide = false
	border.Material = Enum.Material.Neon
	border.Color = Color3.fromRGB(126, 34, 206)
	border.Transparency = 0.4
	border.Parent = plotModel

	-- Crop Holder
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
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = soil

	prompt.Triggered:Connect(function()
		WorldController._handlePlotInteraction(index)
	end)

	-- Floating 3D Billboard Badge
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlotBillboard"
	billboard.Size = UDim2.new(0, 160, 0, 70)
	billboard.StudsOffset = Vector3.new(0, 3.8, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 50
	billboard.Parent = soil

	local badgeFrame = Instance.new("Frame")
	badgeFrame.Name = "Badge"
	badgeFrame.Size = UDim2.fromScale(1, 1)
	badgeFrame.BackgroundColor3 = Color3.fromRGB(15, 11, 28)
	badgeFrame.BackgroundTransparency = 0.2
	badgeFrame.BorderSizePixel = 0
	badgeFrame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = badgeFrame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "BadgeStroke"
	stroke.Color = Color3.fromRGB(147, 51, 234)
	stroke.Thickness = 1.5
	stroke.Parent = badgeFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "StatusTitle"
	titleLabel.Size = UDim2.new(1, -12, 0, 22)
	titleLabel.Position = UDim2.new(0, 6, 0, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "READY TO PLANT"
	titleLabel.TextColor3 = Color3.fromRGB(216, 180, 254)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = badgeFrame

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "SubInfo"
	subLabel.Size = UDim2.new(1, -12, 0, 18)
	subLabel.Position = UDim2.new(0, 6, 0, 30)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "Press [E]"
	subLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
	subLabel.TextScaled = true
	subLabel.Font = Enum.Font.Gotham
	subLabel.Parent = badgeFrame

	local progressBarBg = Instance.new("Frame")
	progressBarBg.Name = "ProgressBarBg"
	progressBarBg.Size = UDim2.new(1, -16, 0, 6)
	progressBarBg.Position = UDim2.new(0, 8, 1, -12)
	progressBarBg.BackgroundColor3 = Color3.fromRGB(30, 24, 48)
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

	local plot = data.Garden[plotIndex]
	if not plot then return end

	local gardenRequest = ReplicatedStorage:FindFirstChild("GardenRequest") :: RemoteFunction?
	if not gardenRequest then return end

	if not plot.Unlocked then
		SoundController.Play("ButtonClick")
		gardenRequest:InvokeServer("UnlockPlot", plotIndex)
		return
	end

	if plot.Plant == nil then
		SoundController.Play("PlantSeed")
		local plotModel = WorldController._plotModels[plotIndex]
		if plotModel then
			local soil = plotModel:FindFirstChild("Soil") :: BasePart?
			if soil then
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
	local border = plotModel:FindFirstChild("NeonTrim") :: BasePart?
	local cropFolder = plotModel:FindFirstChild("Crop") :: Folder?
	local prompt = soil and soil:FindFirstChildOfClass("ProximityPrompt")
	local billboard = soil and soil:FindFirstChild("PlotBillboard") :: BillboardGui?

	if not (soil and border and cropFolder and prompt and billboard) then return end

	local badge = billboard:FindFirstChild("Badge") :: Frame?
	local titleLabel = badge and badge:FindFirstChild("StatusTitle") :: TextLabel?
	local subLabel = badge and badge:FindFirstChild("SubInfo") :: TextLabel?
	local progressBg = badge and badge:FindFirstChild("ProgressBarBg") :: Frame?
	local progressFill = progressBg and progressBg:FindFirstChild("Fill") :: Frame?
	local stroke = badge and badge:FindFirstChild("BadgeStroke") :: UIStroke?

	cropFolder:ClearAllChildren()

	if not plant then
		-- Plot is empty
		prompt.Enabled = true
		prompt.ActionText = "Plant Seed"
		prompt.ObjectText = `Plot #{plotIndex}`
		border.Color = Color3.fromRGB(126, 34, 206)
		border.Transparency = 0.6

		if titleLabel and subLabel and progressBg and stroke then
			titleLabel.Text = "READY TO PLANT"
			titleLabel.TextColor3 = Color3.fromRGB(216, 180, 254)
			subLabel.Text = "Press [E]"
			subLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
			progressBg.Visible = false
			stroke.Color = Color3.fromRGB(126, 34, 206)
		end
		return
	end

	local seedDef = SeedData.GetSeed(plant.SeedId)
	local seedColor = SEED_COLORS[plant.SeedId] or Color3.fromRGB(168, 85, 247)

	if plant.State == "Growing" then
		prompt.Enabled = false
		border.Color = seedColor
		border.Transparency = 0.3

		if titleLabel and subLabel and progressBg and progressFill and stroke then
			titleLabel.Text = string.upper(seedDef and seedDef.Name or plant.SeedId)
			titleLabel.TextColor3 = seedColor
			progressBg.Visible = true
			stroke.Color = seedColor
		end

		-- Spawn Crystal Sprout Mesh/Part
		local stem = Instance.new("Part")
		stem.Name = "SproutStem"
		stem.Size = Vector3.new(0.4, 1.8, 0.4)
		stem.Position = soil.Position + Vector3.new(0, 1.2, 0)
		stem.Anchored = true
		stem.CanCollide = false
		stem.Material = Enum.Material.Neon
		stem.Color = seedColor
		stem.Parent = cropFolder

		local crystalBulb = Instance.new("Part")
		crystalBulb.Name = "CrystalBulb"
		crystalBulb.Shape = Enum.PartType.Ball
		crystalBulb.Size = Vector3.new(1.2, 1.2, 1.2)
		crystalBulb.Position = stem.Position + Vector3.new(0, 1.1, 0)
		crystalBulb.Anchored = true
		crystalBulb.CanCollide = false
		crystalBulb.Material = Enum.Material.Neon
		crystalBulb.Color = Color3.fromRGB(255, 255, 255)
		crystalBulb.Parent = cropFolder

	elseif plant.State == "Ready" then
		prompt.Enabled = true
		prompt.ActionText = "Harvest!"
		prompt.ObjectText = seedDef and seedDef.Name or "Cosmic Bloom"

		local mutDef = MutationData.GetByTier(plant.MutationTier)
		local mutColor = mutDef and Color3.fromRGB(mutDef.ParticleColor.R, mutDef.ParticleColor.G, mutDef.ParticleColor.B) or Color3.fromRGB(250, 204, 21)

		border.Color = mutColor
		border.Transparency = 0.1

		if titleLabel and subLabel and progressBg and stroke then
			titleLabel.Text = "✨ READY TO HARVEST!"
			titleLabel.TextColor3 = mutColor
			subLabel.Text = `Tier: {plant.MutationTier} ({plant.MutationMultiplier}x)`
			subLabel.TextColor3 = Color3.fromRGB(254, 240, 138)
			progressBg.Visible = false
			stroke.Color = mutColor
		end

		-- Spawn Bloom Crystal Model with Orbital Ring
		local bloomCore = Instance.new("Part")
		bloomCore.Name = "BloomCore"
		bloomCore.Size = Vector3.new(1.6, 2.8, 1.6)
		bloomCore.Position = soil.Position + Vector3.new(0, 1.9, 0)
		bloomCore.Anchored = true
		bloomCore.CanCollide = false
		bloomCore.Material = Enum.Material.Neon
		bloomCore.Color = mutColor
		bloomCore.Parent = cropFolder

		local orbitRing = Instance.new("Part")
		orbitRing.Shape = Enum.PartType.Cylinder
		orbitRing.Size = Vector3.new(0.15, 3.2, 3.2)
		orbitRing.CFrame = CFrame.new(bloomCore.Position) * CFrame.Angles(0, 0, math.rad(90))
		orbitRing.Anchored = true
		orbitRing.CanCollide = false
		orbitRing.Material = Enum.Material.Neon
		orbitRing.Color = Color3.fromRGB(255, 255, 255)
		orbitRing.Transparency = 0.3
		orbitRing.Parent = cropFolder

		-- Subtle spinning tween for the orbital ring
		task.spawn(function()
			while orbitRing.Parent do
				orbitRing.CFrame = orbitRing.CFrame * CFrame.Angles(0.04, 0.03, 0)
				task.wait(0.03)
			end
		end)
	end
end

-- ============================================================
-- REALTIME GROWTH TIMER SYNC
-- ============================================================
function WorldController.StartRenderLoop()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local data = WorldController._data
			if not data then continue end

			local now = os.time()
			for i = 1, 9 do
				local plot = data.Garden[i]
				if plot and plot.Plant and plot.Plant.State == "Growing" then
					local plant = plot.Plant
					local seed = SeedData.GetSeed(plant.SeedId)
					local totalDuration = seed and seed.GrowthTime or 15
					local remaining = plant.GrowthEndAt - now

					local plotModel = WorldController._plotModels[i]
					if plotModel then
						local soil = plotModel:FindFirstChild("Soil") :: BasePart?
						local billboard = soil and soil:FindFirstChild("PlotBillboard") :: BillboardGui?
						local badge = billboard and billboard:FindFirstChild("Badge")
						local subLabel = badge and badge:FindFirstChild("SubInfo") :: TextLabel?
						local progressBg = badge and badge:FindFirstChild("ProgressBarBg")
						local progressFill = progressBg and progressBg:FindFirstChild("Fill") :: Frame?

						if remaining <= 0 then
							if subLabel then subLabel.Text = "Blooming..." end
							if progressFill then progressFill.Size = UDim2.fromScale(1, 1) end
						else
							local progress = math.clamp(1 - (remaining / totalDuration), 0, 1)
							if progressFill then
								progressFill.Size = UDim2.fromScale(progress, 1)
							end
							if subLabel then
								local m = math.floor(remaining / 60)
								local s = remaining % 60
								subLabel.Text = string.format("Growing: %02d:%02d", m, s)
							end
						end
					end
				end
			end
		end
	end)
end

function WorldController.SetSelectedSeed(seedId: string)
	WorldController._selectedSeedId = seedId
end

function WorldController.Update(playerData: any)
	WorldController._data = playerData
	if not playerData or not playerData.Garden then return end

	for i = 1, 9 do
		local plot = playerData.Garden[i]
		if plot then
			WorldController.UpdatePlantVisual(i, plot.Plant)
		end
	end
end

return WorldController
