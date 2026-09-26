--!strict
--[[
	Loading Screen — STARWEAVE
	Shows while player data loads. Provides immediate visual feedback
	to prevent first-60-second bounce (critical for algorithm).
	Located in: ReplicatedFirst.Loading
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

-- Remove default Roblox loading screen
ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create loading screen GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Background
local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(10, 5, 25) -- Deep cosmic purple
background.BorderSizePixel = 0
background.Parent = screenGui

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.fromScale(0.8, 0.15)
title.Position = UDim2.fromScale(0.1, 0.3)
title.BackgroundTransparency = 1
title.Text = "✨ STARWEAVE ✨"
title.TextColor3 = Color3.fromRGB(255, 230, 180)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = background

-- Subtitle
local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.fromScale(0.6, 0.05)
subtitle.Position = UDim2.fromScale(0.2, 0.45)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Cultivate the Cosmos"
subtitle.TextColor3 = Color3.fromRGB(180, 160, 255)
subtitle.TextScaled = true
subtitle.Font = Enum.Font.Gotham
subtitle.Parent = background

-- Loading bar frame
local barFrame = Instance.new("Frame")
barFrame.Name = "BarFrame"
barFrame.Size = UDim2.fromScale(0.5, 0.02)
barFrame.Position = UDim2.fromScale(0.25, 0.55)
barFrame.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
barFrame.BorderSizePixel = 0
barFrame.Parent = background

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = barFrame

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(180, 130, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barFrame

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = barFill

-- Status text
local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.fromScale(0.6, 0.04)
status.Position = UDim2.fromScale(0.2, 0.58)
status.BackgroundTransparency = 1
status.Text = "Loading assets..."
status.TextColor3 = Color3.fromRGB(150, 140, 180)
status.TextScaled = true
status.Font = Enum.Font.Gotham
status.Parent = background

-- Tip text
local tips = {
	"💡 Tip: Higher-tier seeds have better mutation chances!",
	"💡 Tip: Mutation Storms double your luck temporarily!",
	"💡 Tip: Trade rare mutated plants with other players!",
	"💡 Tip: Each Rebirth permanently boosts ALL your earnings!",
	"💡 Tip: Equip a pet to boost your mutation luck!",
	"💡 Tip: Visit the Seed Forge to combine plants into rarer seeds!",
	"💡 Tip: Complete daily quests for free Nebula Gems!",
}

local tipText = Instance.new("TextLabel")
tipText.Name = "Tip"
tipText.Size = UDim2.fromScale(0.8, 0.04)
tipText.Position = UDim2.fromScale(0.1, 0.75)
tipText.BackgroundTransparency = 1
tipText.Text = tips[math.random(#tips)]
tipText.TextColor3 = Color3.fromRGB(120, 110, 160)
tipText.TextScaled = true
tipText.Font = Enum.Font.Gotham
tipText.Parent = background

-- Animate loading bar
local function setProgress(progress: number, statusText: string)
	local tween = TweenService:Create(barFill, TweenInfo.new(0.3), {
		Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1),
	})
	tween:Play()
	status.Text = statusText
end

-- Loading sequence
task.spawn(function()
	setProgress(0.2, "Connecting to the cosmos...")
	task.wait(0.5)

	setProgress(0.5, "Loading your garden...")
	task.wait(0.5)

	setProgress(0.7, "Preparing seeds...")
	task.wait(0.3)

	-- Wait for data
	setProgress(0.85, "Loading your data...")

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local dataReady = ReplicatedStorage:WaitForChild("DataReady", 30)

	if dataReady then
		-- Wait for the actual data event
		local received = false
		dataReady.OnClientEvent:Once(function()
			received = true
		end)

		-- Timeout: don't hang forever
		local waitStart = os.clock()
		while not received and (os.clock() - waitStart) < 15 do
			task.wait(0.1)
		end
	end

	setProgress(1.0, "Welcome to Starweave! ✨")
	task.wait(0.8)

	-- Fade out
	local fadeOut = TweenService:Create(background, TweenInfo.new(0.5), {
		BackgroundTransparency = 1,
	})

	-- Fade all children too
	for _, child in background:GetDescendants() do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.5), {
				TextTransparency = 1,
			}):Play()
		elseif child:IsA("Frame") then
			TweenService:Create(child, TweenInfo.new(0.5), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end

	fadeOut:Play()
	fadeOut.Completed:Wait()

	screenGui:Destroy()
end)
