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
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local WorldController = require(script.Parent.Parent.Controllers.WorldController)
local UILib = require(script.Parent.UILib)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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
	{ Label = "Pets",      Action = "OpenPets",          Accent = Color3.fromRGB(251, 191, 36),  Glyph = "P" },
	{ Label = "Stars",     Action = "OpenConstellation", Accent = Color3.fromRGB(192, 132, 252), Glyph = "S" },
	{ Label = "Logbook",   Action = "OpenCollection",    Accent = Color3.fromRGB(56, 189, 248),  Glyph = "L" },
	{ Label = "Transcend", Action = "OpenRebirth",       Accent = Color3.fromRGB(244, 114, 182), Glyph = "T" },
}

function HUDController.Create()
	local gui = Instance.new("ScreenGui")
	gui.Name = "STARWEAVE_HUD"
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	HUDController._gui = gui

	-- ============================================================
	-- TOP BAR
	-- ============================================================
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 58)
	topBar.Position = UDim2.fromScale(0, 0)
	topBar.BackgroundColor3 = UILib.Colors.Surface0
	topBar.BackgroundTransparency = 0.12
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 5
	topBar.Parent = gui

	-- Gradient depth on top bar
	local topGrad = Instance.new("UIGradient")
	topGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 10, 28)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 5, 18)),
	})
	topGrad.Rotation = 90
	topGrad.Parent = topBar

	-- Bottom accent line
	local topDivider = Instance.new("Frame")
	topDivider.Name = "Divider"
	topDivider.Size = UDim2.new(1, 0, 0, 1)
	topDivider.Position = UDim2.new(0, 0, 1, -1)
	topDivider.BackgroundColor3 = UILib.Colors.Purple
	topDivider.BackgroundTransparency = 0.55
	topDivider.BorderSizePixel = 0
	topDivider.ZIndex = 6
	topDivider.Parent = topBar

	-- ── Left: Player Profile Badge ──
	local profileCard = Instance.new("Frame")
	profileCard.Name = "ProfileCard"
	profileCard.Size = UDim2.new(0, 200, 0, 42)
	profileCard.Position = UDim2.new(0, 14, 0.5, -21)
	profileCard.BackgroundColor3 = UILib.Colors.Surface2
	profileCard.BackgroundTransparency = 0.25
	profileCard.BorderSizePixel = 0
	profileCard.ZIndex = 6
	profileCard.Parent = topBar

	UILib.ApplyPill(profileCard)
	UILib.ApplyStroke(profileCard, UILib.Colors.PurpleDim, 1, 0.5)

	-- Avatar
	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Name = "Avatar"
	avatarImg.Size = UDim2.new(0, 34, 0, 34)
	avatarImg.Position = UDim2.new(0, 4, 0.5, -17)
	avatarImg.BackgroundColor3 = UILib.Colors.Surface3
	avatarImg.BorderSizePixel = 0
	avatarImg.ZIndex = 7
	avatarImg.Parent = profileCard
	UILib.ApplyPill(avatarImg)

	task.spawn(function()
		local content, isReady = Players:GetUserThumbnailAsync(
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size100x100
		)
		if isReady then
			avatarImg.Image = content
		end
	end)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Size = UDim2.new(0, 100, 0, 16)
	nameLabel.Position = UDim2.new(0, 44, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = UILib.Colors.TextPrimary
	nameLabel.TextSize = 13
	nameLabel.Font = UILib.Fonts.Bold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 7
	nameLabel.Parent = profileCard

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "PlayerLevel"
	levelLabel.Size = UDim2.new(0, 100, 0, 14)
	levelLabel.Position = UDim2.new(0, 44, 0, 22)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Level 1 Adept"
	levelLabel.TextColor3 = UILib.Colors.PurpleLight
	levelLabel.TextSize = 11
	levelLabel.Font = UILib.Fonts.Medium
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.ZIndex = 7
	levelLabel.Parent = profileCard
	HUDController._labels.Level = levelLabel

	-- ── Center: Currency Capsules ──
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
	capsuleLayout.Padding = UDim.new(0, 8)
	capsuleLayout.Parent = capsuleContainer

	HUDController._labels.Stardust = HUDController._createCapsule(capsuleContainer, "Stardust", "SD", UILib.Colors.Gold, "0")
	HUDController._labels.NebulaGems = HUDController._createCapsule(capsuleContainer, "Gems", "NG", UILib.Colors.Cyan, "0")
	HUDController._labels.Starlight = HUDController._createCapsule(capsuleContainer, "Light", "SL", UILib.Colors.Pink, "0")
	HUDController._labels.Cosmic = HUDController._createCapsule(capsuleContainer, "Mult", "Cx", UILib.Colors.PurpleLight, "1.00x")

	-- ── Right: Weather Badge ──
	local weatherBadge = Instance.new("Frame")
	weatherBadge.Name = "WeatherBadge"
	weatherBadge.Size = UDim2.new(0, 160, 0, 34)
	weatherBadge.Position = UDim2.new(1, -174, 0.5, -17)
	weatherBadge.BackgroundColor3 = UILib.Colors.Surface2
	weatherBadge.BackgroundTransparency = 0.2
	weatherBadge.BorderSizePixel = 0
	weatherBadge.Visible = false
	weatherBadge.ZIndex = 6
	weatherBadge.Parent = topBar
	HUDController._weatherBadge = weatherBadge
	UILib.ApplyPill(weatherBadge)
	UILib.ApplyStroke(weatherBadge, UILib.Colors.Gold, 1.5, 0.2)

	local wText = Instance.new("TextLabel")
	wText.Name = "WeatherText"
	wText.Size = UDim2.new(1, -16, 1, 0)
	wText.Position = UDim2.new(0, 8, 0, 0)
	wText.BackgroundTransparency = 1
	wText.Text = "2x LUCK STORM"
	wText.TextColor3 = UILib.Colors.Gold
	wText.TextSize = 13
	wText.Font = UILib.Fonts.Bold
	wText.ZIndex = 7
	wText.Parent = weatherBadge

	-- Pulse animation for weather badge
	task.spawn(function()
		while weatherBadge.Parent do
			if weatherBadge.Visible then
				TweenService:Create(weatherBadge, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					BackgroundTransparency = 0.35,
				}):Play()
				task.wait(0.8)
				TweenService:Create(weatherBadge, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					BackgroundTransparency = 0.15,
				}):Play()
				task.wait(0.8)
			else
				task.wait(1)
			end
		end
	end)

	-- ============================================================
	-- BOTTOM QUICK SEED BAR
	-- ============================================================
	local seedBar = Instance.new("Frame")
	seedBar.Name = "SeedBar"
	seedBar.Size = UDim2.new(0, 520, 0, 34)
	seedBar.Position = UDim2.new(0.5, -260, 1, -100)
	seedBar.BackgroundColor3 = UILib.Colors.Surface0
	seedBar.BackgroundTransparency = 0.18
	seedBar.BorderSizePixel = 0
	seedBar.ZIndex = 5
	seedBar.Parent = gui
	HUDController._seedBar = seedBar
	UILib.ApplyPill(seedBar)
	UILib.ApplyStroke(seedBar, UILib.Colors.PurpleDim, 1, 0.55)

	local sbLayout = Instance.new("UIListLayout")
	sbLayout.FillDirection = Enum.FillDirection.Horizontal
	sbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sbLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	sbLayout.Padding = UDim.new(0, 6)
	sbLayout.Parent = seedBar

	UILib.ApplyPadding(seedBar, 3, 6, 3, 6)

	-- ============================================================
	-- FLOATING NAVIGATION DOCK
	-- ============================================================
	local dock = Instance.new("Frame")
	dock.Name = "NavigationDock"
	dock.Size = UDim2.new(0, 560, 0, 52)
	dock.Position = UDim2.new(0.5, -280, 1, -58)
	dock.BackgroundColor3 = UILib.Colors.Surface0
	dock.BackgroundTransparency = 0.08
	dock.BorderSizePixel = 0
	dock.ZIndex = 5
	dock.Parent = gui
	UILib.ApplyCorner(dock, 14)
	UILib.ApplyStroke(dock, UILib.Colors.PurpleDim, 1.5, 0.35)

	-- Gradient for depth
	local dockGrad = Instance.new("UIGradient")
	dockGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 12, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 7, 22)),
	})
	dockGrad.Rotation = 90
	dockGrad.Parent = dock

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
	capsule.Size = UDim2.new(0, 118, 1, 0)
	capsule.BackgroundColor3 = UILib.Colors.Surface2
	capsule.BackgroundTransparency = 0.3
	capsule.BorderSizePixel = 0
	capsule.ZIndex = 7
	capsule.Parent = parent
	UILib.ApplyPill(capsule)
	UILib.ApplyStroke(capsule, color, 1, 0.6)

	-- Icon circle
	local iconBg = Instance.new("Frame")
	iconBg.Size = UDim2.new(0, 24, 0, 24)
	iconBg.Position = UDim2.new(0, 6, 0.5, -12)
	iconBg.BackgroundColor3 = color
	iconBg.BackgroundTransparency = 0.75
	iconBg.BorderSizePixel = 0
	iconBg.ZIndex = 8
	iconBg.Parent = capsule
	UILib.ApplyPill(iconBg)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextColor3 = color
	iconLabel.TextSize = 10
	iconLabel.Font = UILib.Fonts.Black
	iconLabel.ZIndex = 9
	iconLabel.Parent = iconBg

	local valLabel = Instance.new("TextLabel")
	valLabel.Name = "Value"
	valLabel.Size = UDim2.new(1, -38, 1, 0)
	valLabel.Position = UDim2.new(0, 34, 0, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = defaultValue
	valLabel.TextColor3 = color
	valLabel.TextSize = 14
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
	btn.Size = UDim2.new(0, 84, 0, 38)
	btn.BackgroundColor3 = UILib.Colors.Surface3
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.ZIndex = 6
	btn.Parent = parent
	UILib.ApplyCorner(btn, 10)

	-- Colored left indicator bar
	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 3, 0, 18)
	indicator.Position = UDim2.new(0, 4, 0.5, -9)
	indicator.BackgroundColor3 = accentColor
	indicator.BorderSizePixel = 0
	indicator.ZIndex = 7
	indicator.Parent = btn
	UILib.ApplyPill(indicator)

	-- Glyph icon
	local glyphLabel = Instance.new("TextLabel")
	glyphLabel.Size = UDim2.new(0, 16, 0, 16)
	glyphLabel.Position = UDim2.new(0, 12, 0, 4)
	glyphLabel.BackgroundTransparency = 1
	glyphLabel.Text = glyph
	glyphLabel.TextColor3 = accentColor
	glyphLabel.TextSize = 12
	glyphLabel.Font = UILib.Fonts.Black
	glyphLabel.ZIndex = 7
	glyphLabel.Parent = btn

	-- Text label
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -14, 0, 12)
	textLabel.Position = UDim2.new(0, 7, 1, -16)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = label
	textLabel.TextColor3 = UILib.Colors.TextSecondary
	textLabel.TextSize = 9
	textLabel.Font = UILib.Fonts.Medium
	textLabel.ZIndex = 7
	textLabel.Parent = btn

	-- Hover / Press
	local originalBg = btn.BackgroundColor3
	btn.MouseEnter:Connect(function()
		SoundController.Play("ButtonHover")
		TweenService:Create(btn, UILib.Timing.Fast, {
			BackgroundColor3 = UILib.Colors.Surface4,
			Size = UDim2.new(0, 88, 0, 40),
		}):Play()
		TweenService:Create(indicator, UILib.Timing.Fast, {
			Size = UDim2.new(0, 3, 0, 24),
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, UILib.Timing.Fast, {
			BackgroundColor3 = originalBg,
			Size = UDim2.new(0, 84, 0, 38),
		}):Play()
		TweenService:Create(indicator, UILib.Timing.Fast, {
			Size = UDim2.new(0, 3, 0, 18),
		}):Play()
	end)

	btn.MouseButton1Click:Connect(function()
		SoundController.Play("ButtonClick")
		-- Press feedback
		TweenService:Create(btn, TweenInfo.new(0.08), {
			Size = UDim2.new(0, 82, 0, 36),
		}):Play()
		task.delay(0.08, function()
			TweenService:Create(btn, UILib.Timing.Fast, {
				Size = UDim2.new(0, 84, 0, 38),
			}):Play()
		end)

		local actionEvent = HUDController._gui and HUDController._gui:FindFirstChild("UIAction")
		if not actionEvent then
			actionEvent = Instance.new("BindableEvent")
			actionEvent.Name = "UIAction"
			actionEvent.Parent = HUDController._gui
		end
		(actionEvent :: BindableEvent):Fire(actionName)
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
	for seedId, count in inv do
		if count > 0 then
			local seedDef = SeedData.GetSeed(seedId)
			local tierColor = seedDef and UILib.TierColor[seedDef.Tier] or UILib.Colors.Purple

			local pill = Instance.new("TextButton")
			pill.Name = seedId
			pill.Size = UDim2.new(0, 105, 0, 26)
			pill.BackgroundColor3 = UILib.Colors.Surface2
			pill.BorderSizePixel = 0
			pill.Text = ""
			pill.ZIndex = 6
			pill.Parent = bar
			UILib.ApplyPill(pill)
			UILib.ApplyStroke(pill, tierColor, 1, 0.5)

			local pillText = Instance.new("TextLabel")
			pillText.Size = UDim2.new(1, -10, 1, 0)
			pillText.Position = UDim2.new(0, 5, 0, 0)
			pillText.BackgroundTransparency = 1
			pillText.Text = string.format("%s (%d)", seedDef and seedDef.Name or seedId, count)
			pillText.TextColor3 = tierColor
			pillText.TextSize = 11
			pillText.Font = UILib.Fonts.Bold
			pillText.TextTruncate = Enum.TextTruncate.AtEnd
			pillText.ZIndex = 7
			pillText.Parent = pill

			-- Hover state
			pill.MouseEnter:Connect(function()
				TweenService:Create(pill, UILib.Timing.Fast, {
					BackgroundColor3 = UILib.Colors.Surface3,
				}):Play()
			end)
			pill.MouseLeave:Connect(function()
				TweenService:Create(pill, UILib.Timing.Fast, {
					BackgroundColor3 = UILib.Colors.Surface2,
				}):Play()
			end)

			pill.MouseButton1Click:Connect(function()
				SoundController.Play("ButtonClick")
				WorldController.SetSelectedSeed(seedId)
				local tut = script.Parent.Parent.Controllers:FindFirstChild("TutorialController")
				if tut then
					local tModule = require(tut :: ModuleScript)
					tModule.OnSeedSelected()
				end
				-- Highlight active
				for _, other in bar:GetChildren() do
					if other:IsA("TextButton") then
						other.BackgroundColor3 = UILib.Colors.Surface2
					end
				end
				pill.BackgroundColor3 = UILib.Colors.Surface4
			end)
		end
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
			SoundController.Play("StormAlert")
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
