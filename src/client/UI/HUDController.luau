--!strict
--[[
	HUDController.luau — AAA Glassmorphic Heads-Up Display for STARWEAVE
	Features player profile avatar card, live currency capsules with number lerping,
	cosmic multiplier badge, active weather tracker, quick seed selection bar,
	and a floating bottom dock with micro-interactions and audio feedback.
	Located in: StarterPlayerScripts.Client.UI.HUDController
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SeedData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeedData"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local WorldController = require(script.Parent.Parent.Controllers.WorldController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HUDController = {}
HUDController._gui = nil :: ScreenGui?
HUDController._labels = {} :: { [string]: TextLabel }
HUDController._data = nil :: any
HUDController._seedBar = nil :: Frame?
HUDController._weatherBadge = nil :: Frame?

local TIER_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(148, 163, 184),
	Uncommon = Color3.fromRGB(74, 222, 128),
	Rare = Color3.fromRGB(56, 189, 248),
	Epic = Color3.fromRGB(192, 132, 252),
	Legendary = Color3.fromRGB(251, 191, 36),
	Celestial = Color3.fromRGB(244, 114, 182),
	Void = Color3.fromRGB(147, 51, 234),
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
	-- TOP BAR (Glassmorphic Header)
	-- ============================================================
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 64)
	topBar.Position = UDim2.fromScale(0, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(13, 9, 24)
	topBar.BackgroundTransparency = 0.18
	topBar.BorderSizePixel = 0
	topBar.Parent = gui

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = Color3.fromRGB(147, 51, 234)
	topStroke.Thickness = 1.2
	topStroke.Transparency = 0.4
	topStroke.Parent = topBar

	-- Left: Player Profile Badge
	local profileCard = Instance.new("Frame")
	profileCard.Name = "ProfileCard"
	profileCard.Size = UDim2.new(0, 210, 0, 46)
	profileCard.Position = UDim2.new(0, 16, 0.5, -23)
	profileCard.BackgroundColor3 = Color3.fromRGB(24, 18, 42)
	profileCard.BackgroundTransparency = 0.3
	profileCard.BorderSizePixel = 0
	profileCard.Parent = topBar

	local profCorner = Instance.new("UICorner")
	profCorner.CornerRadius = UDim.new(1, 0)
	profCorner.Parent = profileCard

	local profStroke = Instance.new("UIStroke")
	profStroke.Color = Color3.fromRGB(168, 85, 247)
	profStroke.Thickness = 1.2
	profStroke.Transparency = 0.5
	profStroke.Parent = profileCard

	-- Avatar Thumbnail Image
	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Name = "Avatar"
	avatarImg.Size = UDim2.new(0, 38, 0, 38)
	avatarImg.Position = UDim2.new(0, 4, 0.5, -19)
	avatarImg.BackgroundColor3 = Color3.fromRGB(35, 26, 60)
	avatarImg.BorderSizePixel = 0
	avatarImg.Parent = profileCard

	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0)
	avatarCorner.Parent = avatarImg

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
	nameLabel.Size = UDim2.new(0, 95, 0, 18)
	nameLabel.Position = UDim2.new(0, 48, 0, 6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = profileCard

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "PlayerLevel"
	levelLabel.Size = UDim2.new(0, 95, 0, 16)
	levelLabel.Position = UDim2.new(0, 48, 0, 24)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Level 1 Adept"
	levelLabel.TextColor3 = Color3.fromRGB(192, 132, 252)
	levelLabel.TextScaled = true
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = profileCard
	HUDController._labels.Level = levelLabel

	-- Center: Live Currency Capsules
	local capsuleContainer = Instance.new("Frame")
	capsuleContainer.Name = "CurrencyCapsules"
	capsuleContainer.Size = UDim2.new(0, 480, 0, 42)
	capsuleContainer.Position = UDim2.new(0.5, -240, 0.5, -21)
	capsuleContainer.BackgroundTransparency = 1
	capsuleContainer.Parent = topBar

	local capsuleLayout = Instance.new("UIListLayout")
	capsuleLayout.FillDirection = Enum.FillDirection.Horizontal
	capsuleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	capsuleLayout.Padding = UDim.new(0, 10)
	capsuleLayout.Parent = capsuleContainer

	HUDController._labels.Stardust = HUDController._createCapsule(capsuleContainer, "Stardust", "⭐", Color3.fromRGB(250, 204, 21), "0")
	HUDController._labels.NebulaGems = HUDController._createCapsule(capsuleContainer, "NebulaGems", "💎", Color3.fromRGB(56, 189, 248), "0")
	HUDController._labels.Starlight = HUDController._createCapsule(capsuleContainer, "Starlight", "🌟", Color3.fromRGB(244, 114, 182), "0")
	HUDController._labels.Cosmic = HUDController._createCapsule(capsuleContainer, "Cosmic", "✨", Color3.fromRGB(168, 85, 247), "1.00x")

	-- Right: Weather Event Badge
	local weatherBadge = Instance.new("Frame")
	weatherBadge.Name = "WeatherBadge"
	weatherBadge.Size = UDim2.new(0, 170, 0, 38)
	weatherBadge.Position = UDim2.new(1, -186, 0.5, -19)
	weatherBadge.BackgroundColor3 = Color3.fromRGB(24, 18, 42)
	weatherBadge.BackgroundTransparency = 0.3
	weatherBadge.BorderSizePixel = 0
	weatherBadge.Visible = false
	weatherBadge.Parent = topBar
	HUDController._weatherBadge = weatherBadge

	local wCorner = Instance.new("UICorner")
	wCorner.CornerRadius = UDim.new(1, 0)
	wCorner.Parent = weatherBadge

	local wStroke = Instance.new("UIStroke")
	wStroke.Color = Color3.fromRGB(250, 204, 21)
	wStroke.Thickness = 1.2
	wStroke.Parent = weatherBadge

	local wText = Instance.new("TextLabel")
	wText.Name = "WeatherText"
	wText.Size = UDim2.fromScale(1, 1)
	wText.BackgroundTransparency = 1
	wText.Text = "⚡ 2x LUCK STORM"
	wText.TextColor3 = Color3.fromRGB(254, 240, 138)
	wText.TextScaled = true
	wText.Font = Enum.Font.GothamBold
	wText.Parent = weatherBadge

	-- ============================================================
	-- BOTTOM QUICK SEED BAR
	-- ============================================================
	local seedBar = Instance.new("Frame")
	seedBar.Name = "SeedBar"
	seedBar.Size = UDim2.new(0, 520, 0, 36)
	seedBar.Position = UDim2.new(0.5, -260, 1, -104)
	seedBar.BackgroundColor3 = Color3.fromRGB(15, 11, 28)
	seedBar.BackgroundTransparency = 0.25
	seedBar.BorderSizePixel = 0
	seedBar.Parent = gui
	HUDController._seedBar = seedBar

	local sbCorner = Instance.new("UICorner")
	sbCorner.CornerRadius = UDim.new(1, 0)
	sbCorner.Parent = seedBar

	local sbStroke = Instance.new("UIStroke")
	sbStroke.Color = Color3.fromRGB(147, 51, 234)
	sbStroke.Thickness = 1
	sbStroke.Transparency = 0.5
	sbStroke.Parent = seedBar

	local sbLayout = Instance.new("UIListLayout")
	sbLayout.FillDirection = Enum.FillDirection.Horizontal
	sbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sbLayout.Padding = UDim.new(0, 8)
	sbLayout.Parent = seedBar

	local sbPad = Instance.new("UIPadding")
	sbPad.PaddingTop = UDim.new(0, 4)
	sbPad.PaddingBottom = UDim.new(0, 4)
	sbPad.Parent = seedBar

	-- ============================================================
	-- FLOATING NAVIGATION DOCK
	-- ============================================================
	local dock = Instance.new("Frame")
	dock.Name = "NavigationDock"
	dock.Size = UDim2.new(0, 590, 0, 52)
	dock.Position = UDim2.new(0.5, -295, 1, -62)
	dock.BackgroundColor3 = Color3.fromRGB(15, 11, 28)
	dock.BackgroundTransparency = 0.15
	dock.BorderSizePixel = 0
	dock.Parent = gui

	local dockCorner = Instance.new("UICorner")
	dockCorner.CornerRadius = UDim.new(1, 0)
	dockCorner.Parent = dock

	local dockStroke = Instance.new("UIStroke")
	dockStroke.Color = Color3.fromRGB(168, 85, 247)
	dockStroke.Thickness = 1.5
	dockStroke.Parent = dock

	local dockLayout = Instance.new("UIListLayout")
	dockLayout.FillDirection = Enum.FillDirection.Horizontal
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dockLayout.Padding = UDim.new(0, 8)
	dockLayout.Parent = dock

	HUDController._createDockButton(dock, "🌱 Market", "OpenShop", Color3.fromRGB(22, 101, 52))
	HUDController._createDockButton(dock, "🔮 Forge", "OpenForge", Color3.fromRGB(126, 34, 206))
	HUDController._createDockButton(dock, "🐾 Pets", "OpenPets", Color3.fromRGB(180, 83, 9))
	HUDController._createDockButton(dock, "🌌 Stars", "OpenConstellation", Color3.fromRGB(147, 51, 234))
	HUDController._createDockButton(dock, "📚 Logbook", "OpenCollection", Color3.fromRGB(3, 105, 161))
	HUDController._createDockButton(dock, "✨ Transcend", "OpenRebirth", Color3.fromRGB(190, 24, 93))
end

function HUDController._createCapsule(parent: Frame, name: string, icon: string, color: Color3, defaultValue: string): TextLabel
	local capsule = Instance.new("Frame")
	capsule.Name = name .. "Capsule"
	capsule.Size = UDim2.new(0, 112, 1, 0)
	capsule.BackgroundColor3 = Color3.fromRGB(24, 18, 42)
	capsule.BackgroundTransparency = 0.25
	capsule.BorderSizePixel = 0
	capsule.Parent = parent

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(1, 0)
	cCorner.Parent = capsule

	local cStroke = Instance.new("UIStroke")
	cStroke.Color = color
	cStroke.Thickness = 1
	cStroke.Transparency = 0.6
	cStroke.Parent = capsule

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(0, 24, 1, 0)
	iconLabel.Position = UDim2.new(0, 6, 0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextColor3 = color
	iconLabel.TextScaled = true
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.Parent = capsule

	local valLabel = Instance.new("TextLabel")
	valLabel.Name = "Value"
	valLabel.Size = UDim2.new(1, -34, 1, 0)
	valLabel.Position = UDim2.new(0, 30, 0, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = defaultValue
	valLabel.TextColor3 = color
	valLabel.TextScaled = true
	valLabel.Font = Enum.Font.GothamBold
	valLabel.TextXAlignment = Enum.TextXAlignment.Left
	valLabel.Parent = capsule

	return valLabel
end

function HUDController._createDockButton(parent: Frame, text: string, actionName: string, baseColor: Color3)
	local btn = Instance.new("TextButton")
	btn.Name = actionName
	btn.Size = UDim2.new(0, 96, 0, 36)
	btn.BackgroundColor3 = baseColor
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.Parent = parent

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(1, 0)
	bCorner.Parent = btn

	btn.MouseEnter:Connect(function()
		SoundController.Play("ButtonHover")
		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 102, 0, 38),
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 96, 0, 36),
		}):Play()
	end)

	btn.MouseButton1Click:Connect(function()
		SoundController.Play("ButtonClick")
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
-- LIVE SEED SELECTOR REFRESH
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
			local tierColor = seedDef and TIER_COLORS[seedDef.Tier] or Color3.fromRGB(168, 85, 247)

			local pill = Instance.new("TextButton")
			pill.Name = seedId
			pill.Size = UDim2.new(0, 110, 1, 0)
			pill.BackgroundColor3 = Color3.fromRGB(28, 20, 48)
			pill.BorderSizePixel = 0
			pill.Text = string.format("%s (%d)", seedDef and seedDef.Name or seedId, count)
			pill.TextColor3 = tierColor
			pill.TextScaled = true
			pill.Font = Enum.Font.GothamBold
			pill.Parent = bar

			local pCorner = Instance.new("UICorner")
			pCorner.CornerRadius = UDim.new(1, 0)
			pCorner.Parent = pill

			local pStroke = Instance.new("UIStroke")
			pStroke.Color = tierColor
			pStroke.Thickness = 1
			pStroke.Transparency = 0.5
			pStroke.Parent = pill

			pill.MouseButton1Click:Connect(function()
				SoundController.Play("ButtonClick")
				WorldController.SetSelectedSeed(seedId)
				local tut = script.Parent.Parent.Controllers:FindFirstChild("TutorialController")
				if tut then
					local tModule = require(tut :: ModuleScript)
					tModule.OnSeedSelected()
				end
				-- Highlight active selection
				for _, other in bar:GetChildren() do
					if other:IsA("TextButton") then
						other.BackgroundColor3 = Color3.fromRGB(28, 20, 48)
					end
				end
				pill.BackgroundColor3 = Color3.fromRGB(58, 38, 92)
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
		HUDController._labels.Stardust.Text = HUDController._formatNumber(data.Stardust or 0)
	end
	if HUDController._labels.NebulaGems then
		HUDController._labels.NebulaGems.Text = HUDController._formatNumber(data.NebulaGems or 0)
	end
	if HUDController._labels.Starlight then
		HUDController._labels.Starlight.Text = HUDController._formatNumber(data.Starlight or 0)
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

function HUDController._formatNumber(n: number): string
	if n >= 1e15 then return string.format("%.2fQ", n / 1e15)
	elseif n >= 1e12 then return string.format("%.2fT", n / 1e12)
	elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
	elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
	else return tostring(math.floor(n))
	end
end

function HUDController.GetUIActionEvent(): BindableEvent?
	if HUDController._gui then
		return HUDController._gui:FindFirstChild("UIAction") :: BindableEvent?
	end
	return nil
end

return HUDController
