--!strict
--[[
	WorldController.luau — Client Spatial Garden Controller for STARWEAVE
	Connects to the server-authoritative 3D Sanctuary built by WorldService:
	  - Wires interactive ProximityPrompts on Plots, Altar, and Pet Egg
	  - Attaches 3D floating status badges & growth countdowns
	  - Clones 3D Crystal Bloom meshes from ReplicatedStorage when crops grow
	  - Runs 60 FPS floating bob animations and stardust particles
	Located in: StarterPlayerScripts.Client.Controllers.WorldController
]]

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
WorldController._selectedSeedId = "starseed_basic"
WorldController._rotatingCores = {} :: { BasePart }
WorldController._eggModel = nil :: Model?
WorldController._eggBaseCFrame = nil :: CFrame?

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

local function getUIController(): any?
	local controllersFolder = script.Parent
	if controllersFolder then
		local uiMod = controllersFolder:FindFirstChild("UIController")
		if uiMod and uiMod:IsA("ModuleScript") then
			local ok, res = pcall(function() return require(uiMod) end)
			if ok then return res end
		end
	end
	return nil
end

function WorldController.Init()
	print("  🌱 [WorldController] Initializing Client Spatial Garden...")

	-- Wait for server-built sanctuary
	local gardenFolder = Workspace:WaitForChild("StarweaveGarden", 15) :: Folder?
	if not gardenFolder then
		warn("[WorldController] Waiting for server-built StarweaveGarden...")
		return
	end

	-- Connect Plots
	for i = 1, 9 do
		local plotModel = gardenFolder:WaitForChild(`Plot_{i}`, 5) :: Model?
		if plotModel then
			WorldController._setupPlotClient(i, plotModel)
		end
	end

	-- Connect Altar Prompt
	task.spawn(function()
		local altarPrompt = gardenFolder:FindFirstChild("AltarForgePrompt", true) :: ProximityPrompt?
		if altarPrompt then
			altarPrompt.Triggered:Connect(function()
				local ui = getUIController()
				if ui and ui.ToggleModal then ui.ToggleModal("Forge") end
			end)
		end
	end)

	-- Connect Pet Egg Prompt & Setup Hover Bob
	task.spawn(function()
		local eggPrompt = gardenFolder:FindFirstChild("HatchEggPrompt", true) :: ProximityPrompt?
		if eggPrompt then
			eggPrompt.Triggered:Connect(function()
				local ui = getUIController()
				if ui and ui.ToggleModal then ui.ToggleModal("Pets") end
			end)
		end

		for _, child in gardenFolder:GetChildren() do
			if child:IsA("Model") and (string.find(string.lower(child.Name), "egg") or string.find(string.lower(child.Name), "auxscene")) then
				if child ~= gardenFolder:FindFirstChild("SanctuaryIslandFoundation") and child.Name ~= "Plot" then
					local cf, _ = child:GetBoundingBox()
					if math.abs(cf.Position.X - (-18)) < 4 then
						WorldController._eggModel = child
						WorldController._eggBaseCFrame = cf
						break
					end
				end
			end
		end
	end)

	WorldController.StartRenderLoop()
	print("  ✅ [WorldController] Client Spatial Garden Online!")
end

function WorldController._setupPlotClient(index: number, plotModel: Model)
	local soil = plotModel:WaitForChild("Soil", 5) :: BasePart?
	if not soil then return end

	local prompt = soil:WaitForChild("InteractionPrompt", 5) :: ProximityPrompt?
	if prompt then
		prompt.Triggered:Connect(function()
			WorldController._handlePlotInteraction(index)
		end)
	end

	-- Create Client-Side Status Billboard
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

	-- 1. EMPTY PLOT
	if not plant then
		prompt.Enabled = true
		prompt.ActionText = "Plant Seed"
		prompt.ObjectText = `Plot #{plotIndex}`
		billboard.Enabled = false
		return
	end

	local seedDef = SeedData.GetSeed(plant.SeedId)
	local seedColor = SEED_COLORS[plant.SeedId] or Color3.fromRGB(168, 85, 247)

	-- Check for 3D Crop Template from ReplicatedStorage
	local assets = ReplicatedStorage:FindFirstChild("StarweaveAssets")
	local cropTemplate = assets and assets:FindFirstChild("CropTemplate") :: Model?

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
			pcall(function() cropClone:ScaleTo(0.5) end)
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

			-- Pet Egg Hover Animation
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
