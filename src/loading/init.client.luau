--!strict
--[[
	Loading Screen — VAULT WARS: STEAL & DEFEND TYCOON
	Cinematic Cyber-Heist Terminal Boot Experience:
	- Tactical Obsidian theme with scanning matrix & telemetry stream
	- Biometric verification progress bar
	- Smooth graceful fade-out on asset readiness (eliminates popping & flickering)
	Located in: ReplicatedFirst.Loading
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Workspace = game:GetService("Workspace")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- DESIGN TOKENS
-- ============================================================
local C = {
	Obsidian   = Color3.fromRGB(7, 9, 14),
	Carbon     = Color3.fromRGB(15, 17, 26),
	SlatePanel = Color3.fromRGB(22, 25, 38),
	Gold       = Color3.fromRGB(245, 158, 11),
	GoldBright = Color3.fromRGB(254, 240, 138),
	Cyan       = Color3.fromRGB(56, 189, 248),
	Emerald    = Color3.fromRGB(16, 185, 129),
	Crimson    = Color3.fromRGB(239, 68, 68),
	White      = Color3.fromRGB(248, 250, 252),
	TextDim    = Color3.fromRGB(148, 163, 184),
}

-- ============================================================
-- ROOT GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
local isDestroyed = false
screenGui.Name = "VaultWarsLoadingScreen"
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 100
screenGui.Parent = playerGui

-- Background Frame
local bg = Instance.new("Frame")
local isBgDestroyed = false
bg.Name = "TerminalBackground"
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = C.Obsidian
bg.BorderSizePixel = 0
bg.Parent = screenGui

-- Center Cyber Console Container
local consoleBox = Instance.new("Frame")
consoleBox.Name = "ConsoleBox"
consoleBox.Size = UDim2.new(0, 520, 0, 340)
consoleBox.Position = UDim2.fromScale(0.5, 0.48)
consoleBox.AnchorPoint = Vector2.new(0.5, 0.5)
consoleBox.BackgroundColor3 = C.Carbon
consoleBox.BackgroundTransparency = 0.15
consoleBox.BorderSizePixel = 0
consoleBox.Parent = bg

local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 16)
cCorner.Parent = consoleBox

local cStroke = Instance.new("UIStroke")
cStroke.Color = Color3.fromRGB(30, 41, 59)
cStroke.Thickness = 2
cStroke.Parent = consoleBox

-- Top Status Bar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 42)
topBar.BackgroundColor3 = C.SlatePanel
topBar.BorderSizePixel = 0
topBar.Parent = consoleBox

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 16)
tbCorner.Parent = topBar

-- Status Indicator Dots
local dotCyan = Instance.new("Frame")
dotCyan.Size = UDim2.new(0, 10, 0, 10)
dotCyan.Position = UDim2.new(0, 16, 0.5, -5)
dotCyan.BackgroundColor3 = C.Cyan
dotCyan.BorderSizePixel = 0
dotCyan.Parent = topBar
Instance.new("UICorner", dotCyan).CornerRadius = UDim.new(1, 0)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -50, 1, 0)
statusLbl.Position = UDim2.new(0, 36, 0, 0)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "⚡ SECURE HEIST NETWORK // SYNDICATE TERMINAL"
statusLbl.TextColor3 = C.TextDim
statusLbl.TextSize = 11
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = topBar

-- Game Title
local titleLbl = Instance.new("TextLabel")
titleLbl.Name = "TitleLabel"
titleLbl.Size = UDim2.new(1, -40, 0, 44)
titleLbl.Position = UDim2.new(0, 20, 0, 60)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "VAULT WARS"
titleLbl.TextColor3 = C.Gold
titleLbl.TextSize = 38
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextXAlignment = Enum.TextXAlignment.Center
titleLbl.Parent = consoleBox

local subTitle = Instance.new("TextLabel")
subTitle.Size = UDim2.new(1, -40, 0, 20)
subTitle.Position = UDim2.new(0, 20, 0, 108)
subTitle.BackgroundTransparency = 1
subTitle.Text = "STEAL & DEFEND TYCOON"
subTitle.TextColor3 = C.Cyan
subTitle.TextSize = 14
subTitle.Font = Enum.Font.GothamBold
subTitle.TextXAlignment = Enum.TextXAlignment.Center
subTitle.Parent = consoleBox

-- Terminal Telemetry Log Box
local logBox = Instance.new("Frame")
logBox.Name = "LogBox"
logBox.Size = UDim2.new(1, -40, 0, 84)
logBox.Position = UDim2.new(0, 20, 0, 142)
logBox.BackgroundColor3 = C.Obsidian
logBox.BackgroundTransparency = 0.4
logBox.BorderSizePixel = 0
logBox.Parent = consoleBox
Instance.new("UICorner", logBox).CornerRadius = UDim.new(0, 8)

local logText = Instance.new("TextLabel")
logText.Name = "LogText"
logText.Size = UDim2.new(1, -16, 1, -10)
logText.Position = UDim2.new(0, 10, 0, 5)
logText.BackgroundTransparency = 1
logText.Text = "> INITIALIZING BIOMETRIC CIPHERS...\n> ESTABLISHING SECURE CONNECTION..."
logText.TextColor3 = C.Emerald
logText.TextSize = 11
logText.Font = Enum.Font.Code
logText.TextXAlignment = Enum.TextXAlignment.Left
logText.TextYAlignment = Enum.TextYAlignment.Top
logText.Parent = logBox

-- Progress Bar Outer Track
local barTrack = Instance.new("Frame")
barTrack.Name = "BarTrack"
barTrack.Size = UDim2.new(1, -40, 0, 14)
barTrack.Position = UDim2.new(0, 20, 0, 246)
barTrack.BackgroundColor3 = C.SlatePanel
barTrack.BorderSizePixel = 0
barTrack.Parent = consoleBox
Instance.new("UICorner", barTrack).CornerRadius = UDim.new(1, 0)

-- Progress Bar Fill
local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0.08, 0, 1, 0)
barFill.BackgroundColor3 = C.Cyan
barFill.BorderSizePixel = 0
barFill.Parent = barTrack
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

local pctLbl = Instance.new("TextLabel")
pctLbl.Name = "PercentLabel"
pctLbl.Size = UDim2.new(1, -40, 0, 22)
pctLbl.Position = UDim2.new(0, 20, 0, 270)
pctLbl.BackgroundTransparency = 1
pctLbl.Text = "AUTHENTICATING... 8%"
pctLbl.TextColor3 = C.TextDim
pctLbl.TextSize = 12
pctLbl.Font = Enum.Font.GothamMedium
pctLbl.TextXAlignment = Enum.TextXAlignment.Center
pctLbl.Parent = consoleBox

-- ============================================================
-- PROGRESSION & GRACEFUL EXIT
-- ============================================================
task.spawn(function()
	local isStudio = RunService:IsStudio()
	local logs = {
		"> ESTABLISHING ENCRYPTED TUNNEL... [OK]",
		"> LOADING SECTOR 07 CAVERN GEOMETRY... [OK]",
		"> SYNCHRONIZING SYNDICATE HEIST LEDGER... [OK]",
		"> SYSTEM ONLINE: WELCOME TO VAULT WARS.",
	}

	-- In Studio, execute instantly so developer Play Solo has 0 delay
	local waitStep = if isStudio then 0.05 else 0.25

	for i, log in logs do
		task.wait(waitStep)
		if isDestroyed then return end
		logText.Text = logText.Text .. "\n" .. log
		local targetPct = math.min(1.0, 0.25 * i)
		TweenService:Create(barFill, TweenInfo.new(waitStep, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(targetPct, 0, 1, 0),
		}):Play()
		pctLbl.Text = string.format("AUTHENTICATING... %d%%", math.floor(targetPct * 100))
	end

	-- Wait until VaultWarsArena is in Workspace or max 1.5s
	local startTime = os.clock()
	while not Workspace:FindFirstChild("VaultWarsArena") and (os.clock() - startTime < (if isStudio then 0.5 else 1.5)) do
		task.wait(0.1)
	end

	-- Complete progress
	barFill.BackgroundColor3 = C.Emerald
	TweenService:Create(barFill, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, 1, 0) }):Play()
	pctLbl.Text = "ACCESS GRANTED. INITIALIZING..."
	pctLbl.TextColor3 = C.Emerald
	task.wait(if isStudio then 0.1 else 0.25)

	-- Smooth Graceful Fade-Out (No pop-in or sudden flash!)
	if screenGui and screenGui.Parent then
		local fadeDuration = if isStudio then 0.2 else 0.4
		local fadeInfo = TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(bg, fadeInfo, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(consoleBox, fadeInfo, { BackgroundTransparency = 1 }):Play()
		for _, desc in consoleBox:GetDescendants() do
			if desc:IsA("TextLabel") then
				TweenService:Create(desc, fadeInfo, { TextTransparency = 1 }):Play()
			elseif desc:IsA("Frame") then
				TweenService:Create(desc, fadeInfo, { BackgroundTransparency = 1 }):Play()
			elseif desc:IsA("UIStroke") then
				TweenService:Create(desc, fadeInfo, { Transparency = 1 }):Play()
			end
		end

		task.wait(fadeDuration + 0.05)
		isDestroyed = true
		pcall(function()
			screenGui:Destroy()
		end)
	end
end)

-- Emergency safety cleanup (Guarantees loading screen never lingers under any condition)
task.delay(4, function()
	if screenGui and screenGui.Parent then
		pcall(function() screenGui:Destroy() end)
	end
end)
