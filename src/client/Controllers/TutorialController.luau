--!strict
--[[
	TutorialController.luau — First-Time User Experience (FTUE) for STARWEAVE
	Guides new players through their first plant, growth, and harvest loop
	with non-intrusive floating banners, spatial 3D beacons, and audio fanfare.
	Located in: StarterPlayerScripts.Client.Controllers.TutorialController
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundController = require(script.Parent.SoundController)
local VFXController = require(script.Parent.VFXController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TutorialController = {}
TutorialController._active = false
TutorialController._currentStep = 0
TutorialController._gui = nil :: ScreenGui?
TutorialController._banner = nil :: Frame?
TutorialController._beacon = nil :: Part?

local TUTORIAL_STEPS = {
	[1] = {
		Title = "STEP 1: SELECT YOUR SEED",
		Description = "Click on your 'Basic Starseed' on the seed bar below.",
		Action = "SelectSeed",
	},
	[2] = {
		Title = "STEP 2: PLANT IN SANCTUARY",
		Description = "Walk up to Plot #1 and press [E] to plant your starseed.",
		Action = "PlantPlot1",
	},
	[3] = {
		Title = "STEP 3: HARVEST & ROLL MUTATION",
		Description = "Your seed has bloomed! Press [E] on Plot #1 to harvest.",
		Action = "HarvestPlot1",
	},
	[4] = {
		Title = "TUTORIAL COMPLETE!",
		Description = "Splendid work! Explore the Market & Compendium to ascend.",
		Action = "Complete",
	},
}

function TutorialController.Init()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Tutorial_HUD"
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 100
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	TutorialController._gui = screenGui

	-- Floating Guide Banner (Sleek Compact Pill under TopBar)
	local banner = Instance.new("Frame")
	banner.Name = "GuideBanner"
	banner.Size = UDim2.new(0, 360, 0, 36)
	banner.Position = UDim2.new(0.5, -180, 0, 114)
	banner.BackgroundColor3 = Color3.fromRGB(15, 11, 26)
	banner.BackgroundTransparency = 0.15
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.Parent = screenGui
	TutorialController._banner = banner

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(1, 0)
	bCorner.Parent = banner

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(250, 204, 21)
	bStroke.Thickness = 1.0
	bStroke.Transparency = 0.35
	bStroke.Parent = banner

	local stepTitle = Instance.new("TextLabel")
	stepTitle.Name = "StepTitle"
	stepTitle.Size = UDim2.new(1, -24, 0, 14)
	stepTitle.Position = UDim2.new(0, 12, 0, 4)
	stepTitle.BackgroundTransparency = 1
	stepTitle.Text = "STEP 1: SELECT YOUR SEED"
	stepTitle.TextColor3 = Color3.fromRGB(250, 204, 21)
	stepTitle.TextSize = 11
	stepTitle.Font = Enum.Font.GothamBold
	stepTitle.TextXAlignment = Enum.TextXAlignment.Center
	stepTitle.Parent = banner

	local stepDesc = Instance.new("TextLabel")
	stepDesc.Name = "StepDesc"
	stepDesc.Size = UDim2.new(1, -24, 0, 14)
	stepDesc.Position = UDim2.new(0, 12, 0, 18)
	stepDesc.BackgroundTransparency = 1
	stepDesc.Text = "Click on your 'Basic Starseed' on the seed bar below."
	stepDesc.TextColor3 = Color3.fromRGB(226, 232, 240)
	stepDesc.TextSize = 10
	stepDesc.Font = Enum.Font.GothamMedium
	stepDesc.TextXAlignment = Enum.TextXAlignment.Center
	stepDesc.Parent = banner
end

function TutorialController.CheckStart(playerData: any)
	if not playerData then return end
	if (playerData.TotalHarvests or 0) == 0 and not TutorialController._active then
		TutorialController.Start()
	end
end

function TutorialController.Start()
	TutorialController._active = true
	TutorialController.SetStep(1)
end

function TutorialController.SetStep(stepIndex: number)
	TutorialController._currentStep = stepIndex
	local stepData = TUTORIAL_STEPS[stepIndex]
	local banner = TutorialController._banner
	if not banner or not stepData then return end

	local titleLabel = banner:FindFirstChild("StepTitle") :: TextLabel?
	local descLabel = banner:FindFirstChild("StepDesc") :: TextLabel?

	if titleLabel then titleLabel.Text = stepData.Title end
	if descLabel then descLabel.Text = stepData.Description end

	banner.Position = UDim2.new(0.5, -180, 0, 106)
	TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -180, 0, 114),
	}):Play()

	SoundController.Play("PlantReady")

	if stepIndex == 2 or stepIndex == 3 then
		TutorialController._spawnGuideBeacon(Vector3.new(-9.5, 0.7, -7.5))
	else
		TutorialController._clearBeacon()
	end

	if stepIndex == 4 then
		task.delay(5, function()
			if banner then
				TweenService:Create(banner, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
				task.wait(0.5)
				banner.Visible = false
				TutorialController._active = false
			end
		end)
	end
end

function TutorialController.OnSeedSelected()
	if TutorialController._active and TutorialController._currentStep == 1 then
		TutorialController.SetStep(2)
	end
end

function TutorialController.OnPlantPlanted(plotIndex: number)
	if TutorialController._active and TutorialController._currentStep == 2 and plotIndex == 1 then
		TutorialController.SetStep(3)
	end
end

function TutorialController.OnPlantHarvested(plotIndex: number)
	if TutorialController._active and TutorialController._currentStep == 3 and plotIndex == 1 then
		TutorialController.SetStep(4)
		SoundController.Play("HarvestRare")
		VFXController.AddCameraTrauma(0.4)
		VFXController.FlashScreen(Color3.fromRGB(250, 204, 21), 0.5, 1.0)
	end
end

function TutorialController._spawnGuideBeacon(position: Vector3)
	TutorialController._clearBeacon()

	local beacon = Instance.new("Part")
	beacon.Name = "TutorialBeacon"
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(0.2, 5, 5)
	beacon.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Material = Enum.Material.Neon
	beacon.Color = Color3.fromRGB(250, 204, 21)
	beacon.Transparency = 0.3
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.Parent = Workspace
	TutorialController._beacon = beacon

	-- Pulsing effect
	task.spawn(function()
		while beacon.Parent do
			TweenService:Create(beacon, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.7,
				Size = Vector3.new(0.2, 6.5, 6.5),
			}):Play()
			task.wait(0.65)
			if not beacon.Parent then break end
			TweenService:Create(beacon, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.3,
				Size = Vector3.new(0.2, 5, 5),
			}):Play()
			task.wait(0.65)
		end
	end)
end

function TutorialController._clearBeacon()
	if TutorialController._beacon then
		TutorialController._beacon:Destroy()
		TutorialController._beacon = nil
	end
end

return TutorialController
