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

-- ============================================================
-- DOCK BUTTON ICON GLYPHS (geometric, no emoji)
-- ============================================================
local DOCK_BUTTONS: { { Label: string, Action: string, Accent: Color3, Glyph: string } } = {
	{ Label = "Market",    Action = "OpenShop",          Accent = Color3.fromRGB(74, 222, 128),  Glyph = "M" },
	{ Label = "Forge",     Action = "OpenForge",         Accent = Color3.fromRGB(168, 85, 247),  Glyph = "F" },
	{ Label = "Quests",    Action = "OpenQuests",        Accent = Color3.fromRGB(250, 204, 21),  Glyph = "Q" },
	{ Label = "Pets",      Action = "OpenPets",          Accent = Color3.fromRGB(251, 191, 36),  Glyph = "P" },
	{ Label = "Stars",     Action = "OpenConstellation", Accent = Color3.fromRGB(192, 132, 252), Glyph = "S" },
	{ Label = "Logbook",   Action = "OpenCollection",    Accent = Color3.fromRGB(56, 189, 248),  Glyph = "L" },
	{ Label = "Transcend", Action = "OpenRebirth",       Accent = Color3.fromRGB(244, 114, 182), Glyph = "T" },
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
	-- TOP BAR (Clean floating translucent pill, not full screen stretch!)
	-- ============================================================
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, -32, 0, 48)
	topBar.Position = UDim2.new(0, 16, 0, 10)
	topBar.BackgroundColor3 = UILib.Colors.Surface0
	topBar.BackgroundTransparency = 0.18
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 5
	topBar.Parent = gui
	UILib.ApplyPill(topBar)
	UILib.ApplyStroke(topBar, UILib.Colors.PurpleDim, 1, 0.45)

	-- ── Left: Player Profile Badge ──
	local profileCard = Instance.new("Frame")
	profileCard.Name = "ProfileCard"
	profileCard.Size = UDim2.new(0, 180, 0, 36)
	profileCard.Position = UDim2.new(0, 6, 0.5, -18)
	profileCard.BackgroundColor3 = UILib.Colors.Surface2
	profileCard.BackgroundTransparency = 0.3
	profileCard.BorderSizePixel = 0
	profileCard.ZIndex = 6
	profileCard.Parent = topBar
	UILib.ApplyPill(profileCard)

	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Name = "Avatar"
	avatarImg.Size = UDim2.new(0, 28, 0, 28)
	avatarImg.Position = UDim2.new(0, 4, 0.5, -14)
	avatarImg.BackgroundColor3 = UILib.Colors.Surface3
	avatarImg.BorderSizePixel = 0
	avatarImg.ZIndex = 7
	avatarImg.Parent = profileCard
	UILib.ApplyPill(avatarImg)

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
	nameLabel.Size = UDim2.new(1, -40, 0, 14)
	nameLabel.Position = UDim2.new(0, 36, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = UILib.Colors.TextPrimary
	nameLabel.TextSize = 12
	nameLabel.Font = UILib.Fonts.Bold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 7
	nameLabel.Parent = profileCard

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "PlayerLevel"
	levelLabel.Size = UDim2.new(1, -40, 0, 12)
	levelLabel.Position = UDim2.new(0, 36, 0, 18)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Level 1 Adept"
	levelLabel.TextColor3 = UILib.Colors.PurpleLight
	levelLabel.TextSize = 10
	levelLabel.Font = UILib.Fonts.Medium
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.ZIndex = 7
	levelLabel.Parent = profileCard
	HUDController._labels.Level = levelLabel

	-- ── Center: Currency Capsules ──
	local capsuleContainer = Instance.new("Frame")
	capsuleContainer.Name = "CurrencyCapsules"
	capsuleContainer.Size = UDim2.new(0, 460, 0, 32)
	capsuleContainer.Position = UDim2.new(0.5, -230, 0.5, -16)
	capsuleContainer.BackgroundTransparency = 1
	capsuleContainer.ZIndex = 6
	capsuleContainer.Parent = topBar

	local capsuleLayout = Instance.new("UIListLayout")
	capsuleLayout.FillDirection = Enum.FillDirection.Horizontal
	capsuleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	capsuleLayout.Padding = UDim.new(0, 6)
	capsuleLayout.Parent = capsuleContainer

	HUDController._labels.Stardust = HUDController._createCapsule(capsuleContainer, "Stardust", "SD", UILib.Colors.Gold, "0")
	HUDController._labels.NebulaGems = HUDController._createCapsule(capsuleContainer, "Gems", "NG", UILib.Colors.Cyan, "0")
	HUDController._labels.Starlight = HUDController._createCapsule(capsuleContainer, "Light", "SL", UILib.Colors.Pink, "0")
	HUDController._labels.Cosmic = HUDController._createCapsule(capsuleContainer, "Mult", "Cx", UILib.Colors.PurpleLight, "1.00x")

	-- ── Right: Weather Badge ──
	local weatherBadge = Instance.new("Frame")
	weatherBadge.Name = "WeatherBadge"
	weatherBadge.Size = UDim2.new(0, 140, 0, 28)
	weatherBadge.Position = UDim2.new(1, -150, 0.5, -14)
	weatherBadge.BackgroundColor3 = UILib.Colors.Surface2
	weatherBadge.BackgroundTransparency = 0.2
	weatherBadge.BorderSizePixel = 0
	weatherBadge.Visible = false
	weatherBadge.ZIndex = 6
	weatherBadge.Parent = topBar
	HUDController._weatherBadge = weatherBadge
	UILib.ApplyPill(weatherBadge)
	UILib.ApplyStroke(weatherBadge, UILib.Colors.Gold, 1.2, 0.2)

	local wText = Instance.new("TextLabel")
	wText.Name = "WeatherText"
	wText.Size = UDim2.fromScale(1, 1)
	wText.BackgroundTransparency = 1
	wText.Text = "2x LUCK STORM"
	wText.TextColor3 = UILib.Colors.Gold
	wText.TextSize = 11
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
	-- FLOATING NAVIGATION DOCK
	-- ============================================================
	local dock = Instance.new("Frame")
	dock.Name = "NavigationDock"
	dock.Size = UDim2.new(0, 646, 0, 48)
	dock.Position = UDim2.new(0.5, -323, 1, -54)
	dock.BackgroundColor3 = UILib.Colors.Surface0
	dock.BackgroundTransparency = 0.12
	dock.BorderSizePixel = 0
	dock.ZIndex = 5
	dock.Parent = gui
	UILib.ApplyCorner(dock, 14)
	UILib.ApplyStroke(dock, UILib.Colors.PurpleDim, 1.2, 0.4)

	local dockLayout = Instance.new("UIListLayout")
	dockLayout.FillDirection = Enum.FillDirection.Horizontal
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dockLayout.Padding = UDim.new(0, 6)
	dockLayout.Parent = dock

	for _, btnDef in DOCK_BUTTONS do
		HUDController._createDockButton(dock, btnDef.Label, btnDef.Action, btnDef.Accent, btnDef.Glyph)
	end
end

-- ============================================================
-- CURRENCY CAPSULE FACTORY
-- ============================================================
function HUDController._createCapsule(parent: Frame, name: string, icon: string, color: Color3, defaultValue: string): TextLabel
	local capsule = Instance.new("Frame")
	capsule.Name = name .. "Capsule"
	capsule.Size = UDim2.new(0, 105, 1, 0)
	capsule.BackgroundColor3 = UILib.Colors.Surface2
	capsule.BackgroundTransparency = 0.35
	capsule.BorderSizePixel = 0
	capsule.ZIndex = 7
	capsule.Parent = parent
	UILib.ApplyPill(capsule)
	UILib.ApplyStroke(capsule, color, 1, 0.5)

	local iconBg = Instance.new("Frame")
	iconBg.Size = UDim2.new(0, 20, 0, 20)
	iconBg.Position = UDim2.new(0, 4, 0.5, -10)
	iconBg.BackgroundColor3 = color
	iconBg.BackgroundTransparency = 0.8
	iconBg.BorderSizePixel = 0
	iconBg.ZIndex = 8
	iconBg.Parent = capsule
	UILib.ApplyPill(iconBg)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextColor3 = color
	iconLabel.TextSize = 9
	iconLabel.Font = UILib.Fonts.Black
	iconLabel.ZIndex = 9
	iconLabel.Parent = iconBg

	local valLabel = Instance.new("TextLabel")
	valLabel.Name = "Value"
	valLabel.Size = UDim2.new(1, -30, 1, 0)
	valLabel.Position = UDim2.new(0, 28, 0, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = defaultValue
	valLabel.TextColor3 = color
	valLabel.TextSize = 12
	valLabel.Font = UILib.Fonts.Bold
	valLabel.TextXAlignment = Enum.TextXAlignment.Left
	valLabel.ZIndex = 8
	valLabel.Parent = capsule

	return valLabel
end

-- ============================================================
-- DOCK BUTTON FACTORY
-- ============================================================
function HUDController._createDockButton(parent: Frame, label: string, actionName: string, accentColor: Color3, glyph: string)
	local btn = Instance.new("TextButton")
	btn.Name = actionName
	btn.Size = UDim2.new(0, 84, 0, 36)
	btn.BackgroundColor3 = UILib.Colors.Surface2
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.ZIndex = 6
	btn.Parent = parent
	UILib.ApplyCorner(btn, 10)

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 3, 0, 16)
	indicator.Position = UDim2.new(0, 4, 0.5, -8)
	indicator.BackgroundColor3 = accentColor
	indicator.BorderSizePixel = 0
	indicator.ZIndex = 7
	indicator.Parent = btn
	UILib.ApplyPill(indicator)

	local glyphLabel = Instance.new("TextLabel")
	glyphLabel.Size = UDim2.new(0, 16, 0, 14)
	glyphLabel.Position = UDim2.new(0, 10, 0, 3)
	glyphLabel.BackgroundTransparency = 1
	glyphLabel.Text = glyph
	glyphLabel.TextColor3 = accentColor
	glyphLabel.TextSize = 11
	glyphLabel.Font = UILib.Fonts.Black
	glyphLabel.ZIndex = 7
	glyphLabel.Parent = btn

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -12, 0, 12)
	textLabel.Position = UDim2.new(0, 6, 1, -15)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = label
	textLabel.TextColor3 = UILib.Colors.TextSecondary
	textLabel.TextSize = 9
	textLabel.Font = UILib.Fonts.Medium
	textLabel.ZIndex = 7
	textLabel.Parent = btn

	btn.MouseEnter:Connect(function()
		local sc = getSoundController()
		if sc then sc.Play("ButtonHover") end
		TweenService:Create(btn, UILib.Timing.Fast, {
			BackgroundColor3 = UILib.Colors.Surface3,
			Size = UDim2.new(0, 86, 0, 38),
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, UILib.Timing.Fast, {
			BackgroundColor3 = UILib.Colors.Surface2,
			Size = UDim2.new(0, 84, 0, 36),
		}):Play()
	end)

	btn.MouseButton1Click:Connect(function()
		local sc = getSoundController()
		if sc then sc.Play("ButtonClick") end

		TweenService:Create(btn, TweenInfo.new(0.06), {
			Size = UDim2.new(0, 80, 0, 34),
		}):Play()
		task.delay(0.07, function()
			TweenService:Create(btn, UILib.Timing.Fast, {
				Size = UDim2.new(0, 84, 0, 36),
			}):Play()
		end)

		local actionEvent = HUDController._gui and HUDController._gui:FindFirstChild("UIAction") :: BindableEvent?
		if actionEvent then
			actionEvent:Fire(actionName)
		end
	end)
end

-- ============================================================
-- SEED BAR REFRESH
-- ============================================================
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

	-- If player has 0 seeds in inventory, give them a prompt to visit market
	if not hasAnySeeds then
		local emptyMsg = Instance.new("TextLabel")
		emptyMsg.Size = UDim2.fromScale(1, 1)
		emptyMsg.BackgroundTransparency = 1
		emptyMsg.Text = "No seeds equipped — Open Market [M] to buy seeds"
		emptyMsg.TextColor3 = UILib.Colors.TextMuted
		emptyMsg.TextSize = 11
		emptyMsg.Font = UILib.Fonts.Medium
		emptyMsg.ZIndex = 6
		emptyMsg.Parent = bar
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

	HUDController.RefreshSeedBar(data)
end

function HUDController.SetWeatherVisible(isVisible: boolean)
	if HUDController._weatherBadge then
		HUDController._weatherBadge.Visible = isVisible
		if isVisible then
			local sc = getSoundController()
			if sc then sc.Play("StormAlert") end
		end
	end
end

function HUDController.GetUIActionEvent(): BindableEvent?
	if HUDController._gui then
		return HUDController._gui:FindFirstChild("UIAction") :: BindableEvent?
	end
	return nil
end

return HUDController
