--!strict
--[[
	HUDController.luau — Polished Heads-Up Display for STARWEAVE
	Player profile badge, live currency capsules with number formatting,
	cosmic multiplier badge, active weather tracker, seed selection bar,
	and a floating bottom navigation dock with micro-interactions.
	Located in: StarterPlayerScripts.Client.UI.HUDController
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SeedData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeedData"))
local UILib = require(script.Parent.UILib)
local ObjectiveTracker = require(script.Parent:WaitForChild("ObjectiveTracker"))

local player = Players.LocalPlayer

local function getSoundController(): any?
	local ctrl = script.Parent.Parent:FindFirstChild("Controllers")
	local sc = ctrl and ctrl:FindFirstChild("SoundController")
	if sc then return require(sc :: ModuleScript) end
	return nil
end

local function getWorldController(): any?
	local ctrl = script.Parent.Parent:FindFirstChild("Controllers")
	local wc = ctrl and ctrl:FindFirstChild("WorldController")
	if wc then return require(wc :: ModuleScript) end
	return nil
end

local HUDController = {}
HUDController._gui = nil :: ScreenGui?
HUDController._labels = {} :: { [string]: TextLabel }
HUDController._data = nil :: any
HUDController._seedBar = nil :: Frame?
HUDController._weatherBadge = nil :: Frame?
HUDController._xpFill = nil :: Frame?

-- ============================================================
-- DOCK BUTTON CONFIGURATION (Vibrant Candy 3D Toy Palettes)
-- ============================================================
local DOCK_BUTTONS: { { Label: string, Action: string, Icon: string, Top: Color3, Bottom: Color3 } } = {
	{ Label = "SHOP",      Action = "OpenShop",          Icon = UILib.Icons.Shop,      Top = Color3.fromRGB(52, 211, 153), Bottom = Color3.fromRGB(16, 149, 106) },
	{ Label = "FORGE",     Action = "OpenForge",         Icon = UILib.Icons.Forge,     Top = Color3.fromRGB(168, 85, 247), Bottom = Color3.fromRGB(109, 40, 217) },
	{ Label = "QUESTS",    Action = "OpenQuests",        Icon = UILib.Icons.Quests,    Top = Color3.fromRGB(251, 191, 36), Bottom = Color3.fromRGB(194, 98, 4) },
	{ Label = "PETS",      Action = "OpenPets",          Icon = UILib.Icons.Pets,      Top = Color3.fromRGB(56, 189, 248), Bottom = Color3.fromRGB(2, 132, 199) },
	{ Label = "STARS",     Action = "OpenConstellation", Icon = UILib.Icons.Stars,     Top = Color3.fromRGB(216, 180, 254), Bottom = Color3.fromRGB(147, 51, 234) },
	{ Label = "CODEX",     Action = "OpenCollection",    Icon = UILib.Icons.Codex,     Top = Color3.fromRGB(96, 165, 250), Bottom = Color3.fromRGB(29, 78, 216) },
	{ Label = "TRANSCEND", Action = "OpenRebirth",       Icon = UILib.Icons.Transcend, Top = Color3.fromRGB(244, 114, 182), Bottom = Color3.fromRGB(190, 24, 93) },
}

function HUDController.Create()
	local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
	if not playerGui then
		warn("[HUDController] Could not find PlayerGui!")
		return
	end

	local existing = playerGui:FindFirstChild("STARWEAVE_HUD")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "STARWEAVE_HUD"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.Enabled = true
	gui.Parent = playerGui
	HUDController._gui = gui

	-- Pre-create UIAction bindable event
	local actionEvent = Instance.new("BindableEvent")
	actionEvent.Name = "UIAction"
	actionEvent.Parent = gui

	-- ============================================================
	-- TOP BAR (Chunky floating banner anchored top-right clear of Chat & CoreGui)
	-- ============================================================
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(0, 840, 0, 52)
	topBar.Position = UDim2.new(1, -20, 0, 52)
	topBar.AnchorPoint = Vector2.new(1, 0)
	topBar.BackgroundColor3 = UILib.Colors.Surface0
	topBar.BackgroundTransparency = 0.05
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 5
	topBar.Parent = gui
	UILib.ApplyCorner(topBar, 16)
	UILib.ApplyStroke(topBar, UILib.Colors.StrokeDark, 3)

	-- Top Gloss Sheen
	local topSheen = Instance.new("Frame")
	topSheen.Name = "TopSheen"
	topSheen.Size = UDim2.new(1, -24, 0, 6)
	topSheen.Position = UDim2.new(0, 12, 0, 3)
	topSheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	topSheen.BackgroundTransparency = 0.75
	topSheen.BorderSizePixel = 0
	topSheen.ZIndex = 6
	topSheen.Parent = topBar
	UILib.ApplyPill(topSheen)

	-- ── Left: Player Profile Badge with Live XP Bar ──
	local profileCard = Instance.new("TextButton")
	profileCard.Name = "ProfileCard"
	profileCard.Size = UDim2.new(0, 175, 0, 40)
	profileCard.Position = UDim2.new(0, 8, 0.5, -20)
	profileCard.BackgroundColor3 = UILib.Colors.Surface1
	profileCard.BorderSizePixel = 0
	profileCard.Text = ""
	profileCard.ZIndex = 6
	profileCard.Parent = topBar
	UILib.ApplyCorner(profileCard, 12)
	UILib.ApplyStroke(profileCard, UILib.Colors.StrokeDark, 2.5)

	profileCard.MouseButton1Click:Connect(function()
		local sc = getSoundController()
		if sc then sc.Play("ButtonClick") end
		local actionEvent = HUDController._gui and HUDController._gui:FindFirstChild("UIAction") :: BindableEvent?
		if actionEvent then actionEvent:Fire("OpenStats") end
	end)

	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Name = "Avatar"
	avatarImg.Size = UDim2.new(0, 34, 0, 34)
	avatarImg.Position = UDim2.new(0, 4, 0.5, -17)
	avatarImg.BackgroundColor3 = UILib.Colors.Surface2
	avatarImg.BorderSizePixel = 0
	avatarImg.ZIndex = 7
	avatarImg.Parent = profileCard
	UILib.ApplyPill(avatarImg)
	UILib.ApplyStroke(avatarImg, UILib.Colors.Gold, 2)

	if player.UserId > 0 then
		task.spawn(function()
			pcall(function()
				local content, isReady = Players:GetUserThumbnailAsync(
					player.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size100x100
				)
				if isReady then
					avatarImg.Image = content
				end
			end)
		end)
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Size = UDim2.new(1, -44, 0, 14)
	nameLabel.Position = UDim2.new(0, 42, 0, 3)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 13
	nameLabel.Font = UILib.Fonts.Black
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 7
	nameLabel.Parent = profileCard
	UILib.ApplyTextStroke(nameLabel, UILib.Colors.StrokeDark, 2.5)

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "PlayerLevel"
	levelLabel.Size = UDim2.new(1, -44, 0, 13)
	levelLabel.Position = UDim2.new(0, 42, 0, 17)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "LVL 1 ADEPT"
	levelLabel.TextColor3 = UILib.Colors.GoldBright
	levelLabel.TextSize = 10
	levelLabel.Font = UILib.Fonts.Black
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.ZIndex = 7
	levelLabel.Parent = profileCard
	UILib.ApplyTextStroke(levelLabel, UILib.Colors.StrokeDark, 2.5)
	HUDController._labels.Level = levelLabel

	local xpBarBg = Instance.new("Frame")
	xpBarBg.Name = "XPBarBg"
	xpBarBg.Size = UDim2.new(1, -48, 0, 5)
	xpBarBg.Position = UDim2.new(0, 42, 1, -7)
	xpBarBg.BackgroundColor3 = Color3.fromRGB(16, 12, 28)
	xpBarBg.BorderSizePixel = 0
	xpBarBg.ZIndex = 7
	xpBarBg.Parent = profileCard
	UILib.ApplyPill(xpBarBg)

	local xpFill = Instance.new("Frame")
	xpFill.Name = "XPFill"
	xpFill.Size = UDim2.fromScale(0.1, 1)
	xpFill.BackgroundColor3 = Color3.fromRGB(14, 165, 233)
	xpFill.BorderSizePixel = 0
	xpFill.ZIndex = 8
	xpFill.Parent = xpBarBg
	UILib.ApplyPill(xpFill)
	HUDController._xpFill = xpFill

	-- ── Center: Currency Capsules with Real High-Res Asset Icons ──
	local capsuleContainer = Instance.new("Frame")
	capsuleContainer.Name = "CurrencyCapsules"
	capsuleContainer.Size = UDim2.new(0, 500, 0, 38)
	capsuleContainer.Position = UDim2.new(0.5, -250, 0.5, -19)
	capsuleContainer.BackgroundTransparency = 1
	capsuleContainer.ZIndex = 6
	capsuleContainer.Parent = topBar

	local capsuleLayout = Instance.new("UIListLayout")
	capsuleLayout.FillDirection = Enum.FillDirection.Horizontal
	capsuleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	capsuleLayout.Padding = UDim.new(0, 6)
	capsuleLayout.Parent = capsuleContainer

	HUDController._labels.Stardust = HUDController._createCapsule(capsuleContainer, "Stardust", UILib.Icons.Stardust, UILib.Colors.Gold, "0")
	HUDController._labels.NebulaGems = HUDController._createCapsule(capsuleContainer, "Gems", UILib.Icons.NebulaGems, UILib.Colors.Cyan, "0")
	HUDController._labels.Starlight = HUDController._createCapsule(capsuleContainer, "Light", UILib.Icons.Starlight, UILib.Colors.Pink, "0")
	HUDController._labels.Cosmic = HUDController._createCapsule(capsuleContainer, "Mult", UILib.Icons.CosmicMult, UILib.Colors.PurpleLight, "1.00x")

	-- ── Right: Weather Badge ──
	local weatherBadge = Instance.new("Frame")
	weatherBadge.Name = "WeatherBadge"
	weatherBadge.Size = UDim2.new(0, 140, 0, 28)
	weatherBadge.Position = UDim2.new(1, -148, 0.5, -14)
	weatherBadge.BackgroundColor3 = UILib.Colors.Surface2
	weatherBadge.BackgroundTransparency = 0.2
	weatherBadge.BorderSizePixel = 0
	weatherBadge.Visible = false
	weatherBadge.ZIndex = 6
	weatherBadge.Parent = topBar
	HUDController._weatherBadge = weatherBadge
	UILib.ApplyPill(weatherBadge)
	UILib.ApplyStroke(weatherBadge, UILib.Colors.Gold, 1.2, 0.2)
	UILib.ApplyPill(weatherBadge)
	UILib.ApplyStroke(weatherBadge, UILib.Colors.Gold, 1.2, 0.2)

	local wText = Instance.new("TextLabel")
	wText.Name = "WeatherText"
	wText.Size = UDim2.fromScale(1, 1)
	wText.BackgroundTransparency = 1
	wText.Text = "2x LUCK STORM"
	wText.TextColor3 = UILib.Colors.Gold
	wText.TextSize = 10
	wText.Font = UILib.Fonts.Bold
	wText.ZIndex = 7
	wText.Parent = weatherBadge

	-- ============================================================
	-- BOTTOM QUICK SEED BAR
	-- ============================================================
	local seedBar = Instance.new("Frame")
	seedBar.Name = "SeedBar"
	seedBar.Size = UDim2.new(0, 480, 0, 32)
	seedBar.Position = UDim2.new(0.5, -240, 1, -94)
	seedBar.BackgroundColor3 = UILib.Colors.Surface0
	seedBar.BackgroundTransparency = 0.18
	seedBar.BorderSizePixel = 0
	seedBar.ZIndex = 5
	seedBar.Parent = gui
	HUDController._seedBar = seedBar
	UILib.ApplyPill(seedBar)
	UILib.ApplyStroke(seedBar, UILib.Colors.PurpleDim, 1, 0.5)

	local sbLayout = Instance.new("UIListLayout")
	sbLayout.FillDirection = Enum.FillDirection.Horizontal
	sbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sbLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	sbLayout.Padding = UDim.new(0, 6)
	sbLayout.Parent = seedBar

	UILib.ApplyPadding(seedBar, 2, 6, 2, 6)

	-- ============================================================
	-- FLOATING NAVIGATION DOCK (Chunky 3D Toy Bar)
	-- ============================================================
	local dock = Instance.new("Frame")
	dock.Name = "NavigationDock"
	dock.Size = UDim2.new(0, 715, 0, 56)
	dock.Position = UDim2.new(0.5, -357, 1, -66)
	dock.BackgroundColor3 = UILib.Colors.Surface0
	dock.BackgroundTransparency = 0.05
	dock.BorderSizePixel = 0
	dock.ZIndex = 5
	dock.Parent = gui
	UILib.ApplyCorner(dock, 16)
	UILib.ApplyStroke(dock, UILib.Colors.StrokeDark, 3)

	local dockLayout = Instance.new("UIListLayout")
	dockLayout.FillDirection = Enum.FillDirection.Horizontal
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dockLayout.Padding = UDim.new(0, 6)
	dockLayout.Parent = dock

	for _, btnDef in DOCK_BUTTONS do
		HUDController._createDockButton(dock, btnDef.Label, btnDef.Action, btnDef.Icon, btnDef.Top, btnDef.Bottom)
	end

	-- Guided Objective Tracker (pinned on left)
	ObjectiveTracker.Create(gui)
end

-- ============================================================
-- CURRENCY CAPSULE FACTORY (Chunky Cartoon Pill)
-- ============================================================
function HUDController._createCapsule(parent: Frame, name: string, icon: string, color: Color3, defaultValue: string): TextLabel
	local capsule = Instance.new("Frame")
	capsule.Name = name .. "Capsule"
	capsule.Size = UDim2.new(0, 118, 0, 36)
	capsule.BackgroundColor3 = UILib.Colors.Surface1
	capsule.BorderSizePixel = 0
	capsule.ZIndex = 7
	capsule.Parent = parent
	UILib.ApplyCorner(capsule, 12)
	UILib.ApplyStroke(capsule, UILib.Colors.StrokeDark, 2.5)

	-- Icon Emblem Badge (Circular with dark stroke)
	local iconBg = Instance.new("Frame")
	iconBg.Name = "Emblem"
	iconBg.Size = UDim2.new(0, 26, 0, 26)
	iconBg.Position = UDim2.new(0, 5, 0.5, -13)
	iconBg.BackgroundColor3 = color
	iconBg.BackgroundTransparency = 0.2
	iconBg.BorderSizePixel = 0
	iconBg.ZIndex = 8
	iconBg.Parent = capsule
	UILib.ApplyPill(iconBg)
	UILib.ApplyStroke(iconBg, UILib.Colors.StrokeDark, 2)

	local iconImg = Instance.new("ImageLabel")
	iconImg.Name = "CapsuleIcon"
	iconImg.Size = UDim2.new(0, 18, 0, 18)
	iconImg.Position = UDim2.new(0.5, -9, 0.5, -9)
	iconImg.BackgroundTransparency = 1
	iconImg.Image = icon
	iconImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
	iconImg.ZIndex = 9
	iconImg.Parent = iconBg

	local valLabel = Instance.new("TextLabel")
	valLabel.Name = "Value"
	valLabel.Size = UDim2.new(1, -38, 1, 0)
	valLabel.Position = UDim2.new(0, 35, 0, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = defaultValue
	valLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	valLabel.TextSize = 13
	valLabel.Font = UILib.Fonts.Black
	valLabel.TextXAlignment = Enum.TextXAlignment.Left
	valLabel.ZIndex = 8
	valLabel.Parent = capsule
	UILib.ApplyTextStroke(valLabel, UILib.Colors.StrokeDark, 2.5)

	-- Optional Plus Button for Stardust & Gems
	if name == "Stardust" or name == "Gems" then
		local plusBtn = Instance.new("TextButton")
		plusBtn.Name = "PlusBtn"
		plusBtn.Size = UDim2.new(0, 18, 0, 18)
		plusBtn.Position = UDim2.new(1, -22, 0.5, -9)
		plusBtn.BackgroundColor3 = UILib.Colors.Green
		plusBtn.Text = "+"
		plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		plusBtn.TextSize = 14
		plusBtn.Font = UILib.Fonts.Black
		plusBtn.ZIndex = 9
		plusBtn.Parent = capsule
		UILib.ApplyPill(plusBtn)
		UILib.ApplyStroke(plusBtn, UILib.Colors.StrokeDark, 1.5)

		plusBtn.MouseButton1Click:Connect(function()
			local sc = getSoundController()
			if sc then sc.Play("ButtonClick") end
			local actionEvent = HUDController._gui and HUDController._gui:FindFirstChild("UIAction") :: BindableEvent?
			if actionEvent then actionEvent:Fire("OpenShop") end
		end)
	end

	return valLabel
end

HUDController._onActionCallback = nil :: ((string) -> ())?

function HUDController.SetActionCallback(callback: (string) -> ())
	HUDController._onActionCallback = callback
end

-- ============================================================
-- DOCK BUTTON FACTORY (Chunky 3D Toy Button)
-- ============================================================
function HUDController._createDockButton(
	parent: Frame,
	label: string,
	actionName: string,
	iconAssetId: string,
	topColor: Color3,
	bottomColor: Color3
)
	local btn = UILib.CreateChunkyButton(
		parent,
		actionName,
		label,
		topColor,
		bottomColor,
		UDim2.new(0, 96, 0, 46),
		UDim2.new(0, 0, 0, 0),
		iconAssetId
	)

	local lastClickTime = 0
	local function triggerAction()
		local now = os.clock()
		if now - lastClickTime < 0.25 then return end
		lastClickTime = now

		local sc = getSoundController()
		if sc then sc.Play("ButtonClick") end

		if HUDController._onActionCallback then
			pcall(function()
				HUDController._onActionCallback(actionName)
			end)
		else
			local actionEvent = HUDController._gui and HUDController._gui:FindFirstChild("UIAction") :: BindableEvent?
			if actionEvent then
				actionEvent:Fire(actionName)
			end
		end
	end

	btn.Activated:Connect(triggerAction)
end

function HUDController.RefreshSeedBar(data: any)
	local bar = HUDController._seedBar
	if not bar then return end

	for _, child in bar:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local inv = data and data.SeedInventory or {}
	local hasAnySeeds = false

	for seedId, count in inv do
		if count > 0 then
			hasAnySeeds = true
			local seedDef = SeedData.GetSeed(seedId)
			local tierColor = seedDef and UILib.TierColor[seedDef.Tier] or UILib.Colors.Purple

			local pill = Instance.new("TextButton")
			pill.Name = seedId
			pill.Size = UDim2.new(0, 115, 0, 24)
			pill.BackgroundColor3 = UILib.Colors.Surface2
			pill.BorderSizePixel = 0
			pill.Text = ""
			pill.ZIndex = 6
			pill.Parent = bar
			UILib.ApplyPill(pill)
			UILib.ApplyStroke(pill, tierColor, 1, 0.5)

			local pillText = Instance.new("TextLabel")
			pillText.Size = UDim2.new(1, -8, 1, 0)
			pillText.Position = UDim2.new(0, 4, 0, 0)
			pillText.BackgroundTransparency = 1
			pillText.Text = string.format("%s (%d)", seedDef and seedDef.Name or seedId, count)
			pillText.TextColor3 = tierColor
			pillText.TextSize = 10
			pillText.Font = UILib.Fonts.Bold
			pillText.TextTruncate = Enum.TextTruncate.AtEnd
			pillText.ZIndex = 7
			pillText.Parent = pill

			pill.MouseButton1Click:Connect(function()
				local sc = getSoundController()
				if sc then sc.Play("ButtonClick") end

				local wc = getWorldController()
				if wc then wc.SetSelectedSeed(seedId) end

				local tut = script.Parent.Parent.Controllers:FindFirstChild("TutorialController")
				if tut then
					pcall(function()
						require(tut :: ModuleScript).OnSeedSelected()
					end)
				end

				for _, other in bar:GetChildren() do
					if other:IsA("TextButton") then
						other.BackgroundColor3 = UILib.Colors.Surface2
					end
				end
				pill.BackgroundColor3 = UILib.Colors.Surface4
			end)
		end
	end

	-- If player has 0 seeds in inventory, give them a clickable button to visit Shop
	if not hasAnySeeds then
		local emptyBtn = Instance.new("TextButton")
		emptyBtn.Name = "EmptySeedButton"
		emptyBtn.Size = UDim2.fromScale(1, 1)
		emptyBtn.BackgroundTransparency = 1
		emptyBtn.Text = "✦ No seeds equipped — Click to Open Shop ✦"
		emptyBtn.TextColor3 = UILib.Colors.Green
		emptyBtn.TextSize = 11
		emptyBtn.Font = UILib.Fonts.Bold
		emptyBtn.ZIndex = 6
		emptyBtn.Parent = bar

		emptyBtn.MouseButton1Click:Connect(function()
			local sc = getSoundController()
			if sc then sc.Play("ButtonClick") end
			local actionEvent = HUDController._gui and HUDController._gui:FindFirstChild("UIAction") :: BindableEvent?
			if actionEvent then
				actionEvent:Fire("OpenShop")
			end
		end)
	end
end

-- ============================================================
-- DATA SYNC
-- ============================================================
function HUDController.Update(data: any)
	if not data then return end
	HUDController._data = data

	if HUDController._labels.Stardust then
		HUDController._labels.Stardust.Text = UILib.FormatNumber(data.Stardust or 0)
	end
	if HUDController._labels.NebulaGems then
		HUDController._labels.NebulaGems.Text = UILib.FormatNumber(data.NebulaGems or 0)
	end
	if HUDController._labels.Starlight then
		HUDController._labels.Starlight.Text = UILib.FormatNumber(data.Starlight or 0)
	end
	if HUDController._labels.Cosmic then
		local mult = data.Rebirth and data.Rebirth.CosmicMultiplier or 1.0
		HUDController._labels.Cosmic.Text = string.format("%.2fx", mult)
	end
	if HUDController._labels.Level then
		HUDController._labels.Level.Text = string.format("Level %d Adept", data.Level or 1)
	end

	-- Live XP Progress Fill
	if HUDController._xpFill and data.Level and data.Experience then
		local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
		local reqExp = (Config.Progression and Config.Progression.BaseLevelExp or 100) * (data.Level or 1)
		local ratio = math.clamp(data.Experience / reqExp, 0.05, 1)
		TweenService:Create(HUDController._xpFill, UILib.Timing.Standard, {
			Size = UDim2.fromScale(ratio, 1),
		}):Play()
	end

	-- Guided Objective Tracker
	ObjectiveTracker.Update(data)

	HUDController.RefreshSeedBar(data)
end

HUDController._weatherThread = nil :: thread?

function HUDController.SetWeather(weatherData: any)
	local badge = HUDController._weatherBadge
	if not badge then return end

	if HUDController._weatherThread then
		task.cancel(HUDController._weatherThread)
		HUDController._weatherThread = nil
	end

	if type(weatherData) == "boolean" then
		badge.Visible = weatherData
		return
	end

	if not weatherData or not weatherData.IsActive then
		badge.Visible = false
		return
	end

	badge.Visible = true
	local stroke = badge:FindFirstChildOfClass("UIStroke")
	if stroke and weatherData.BadgeColor then
		stroke.Color = weatherData.BadgeColor
	end

	local wText = badge:FindFirstChild("WeatherText") :: TextLabel?
	if wText and weatherData.BadgeColor then
		wText.TextColor3 = weatherData.BadgeColor
	end

	local sc = getSoundController()
	if sc then sc.Play("StormAlert") end

	local duration = weatherData.Duration or 45
	HUDController._weatherThread = task.spawn(function()
		for rem = duration, 0, -1 do
			if wText and badge.Visible then
				wText.Text = string.format("%s %s (%ds)", weatherData.Icon or "⚡", weatherData.MultiplierText or "BOOST", rem)
			end
			task.wait(1)
		end
		badge.Visible = false
	end)
end

function HUDController.SetWeatherVisible(isVisible: boolean)
	HUDController.SetWeather({ IsActive = isVisible, MultiplierText = "2x LUCK", Duration = 60, Icon = "⚡" })
end

function HUDController.GetUIActionEvent(): BindableEvent?
	if HUDController._gui then
		return HUDController._gui:FindFirstChild("UIAction") :: BindableEvent?
	end
	return nil
end

return HUDController
