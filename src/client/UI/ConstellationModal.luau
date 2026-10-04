--!strict
--[[
	ConstellationModal.luau — Star Chart Prestige Skill Tree for STARWEAVE
	Allocate Constellation Points earned from Rebirth into permanent
	passive economic and mutation multipliers.
	Located in: StarterPlayerScripts.Client.UI.ConstellationModal
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local VFXController = require(script.Parent.Parent.Controllers.VFXController)
local UILib = require(script.Parent.UILib)

local ConstellationModal = {}
ConstellationModal._frame = nil :: Frame?
ConstellationModal._data = nil :: any
ConstellationModal._cards = {} :: { [string]: Frame }

local ACCENT = Color3.fromRGB(192, 132, 252)

local UPGRADE_METADATA: { [string]: { Title: string, Glyph: string, Color: Color3, Subtitle: string } } = {
	sell_bonus         = { Title = "COSMIC COMMERCE",      Glyph = "✦", Color = Color3.fromRGB(250, 204, 21),  Subtitle = "+5% crop sell value per level" },
	mutation_luck      = { Title = "ASTRAL FORTUNE",       Glyph = "✧", Color = Color3.fromRGB(168, 85, 247),  Subtitle = "+3% mutation luck per level" },
	growth_speed       = { Title = "TEMPORAL WARP",        Glyph = "✦", Color = Color3.fromRGB(56, 189, 248),   Subtitle = "+5% growth speed per level" },
	plot_discount      = { Title = "SPATIAL ARCHITECT",    Glyph = "✧", Color = Color3.fromRGB(52, 211, 153),  Subtitle = "-5% plot unlock cost per level" },
	xp_bonus           = { Title = "ADEPT WISDOM",         Glyph = "✦", Color = Color3.fromRGB(192, 132, 252), Subtitle = "+10% garden XP per level" },
	seed_yield         = { Title = "BOUNTIFUL SPORES",     Glyph = "✧", Color = Color3.fromRGB(251, 146, 60),  Subtitle = "+1 bonus seed per harvest" },
	stardust_interest  = { Title = "GRAVITATIONAL WEALTH", Glyph = "✦", Color = Color3.fromRGB(244, 114, 182), Subtitle = "+1% Stardust interest/min" },
}

local CONSTELLATION_CONFIG: { [string]: { MaxLevel: number, PointCost: number } } = {
	sell_bonus         = { MaxLevel = 20, PointCost = 1 },
	mutation_luck      = { MaxLevel = 15, PointCost = 2 },
	growth_speed       = { MaxLevel = 10, PointCost = 2 },
	plot_discount      = { MaxLevel = 10, PointCost = 1 },
	xp_bonus           = { MaxLevel = 15, PointCost = 1 },
	seed_yield         = { MaxLevel = 10, PointCost = 3 },
	stardust_interest  = { MaxLevel = 5,  PointCost = 5 },
}

function ConstellationModal.Create(parentGui: ScreenGui)
	local modal = UILib.CreateModalFrame(parentGui, "ConstellationModal", 540, 440, ACCENT)
	ConstellationModal._frame = modal

	-- Header
	local header = UILib.CreateModalHeader(modal, "Constellation Star Chart", "Allocate points into permanent cosmic multipliers", ACCENT, function()
		SoundController.Play("ButtonClick")
		ConstellationModal.Close()
	end)

	-- Points badge
	local pointsBadge = Instance.new("Frame")
	pointsBadge.Name = "PointsBadge"
	pointsBadge.Size = UDim2.new(1, -32, 0, 32)
	pointsBadge.Position = UDim2.new(0, 16, 0, 56)
	pointsBadge.BackgroundColor3 = Color3.fromRGB(20, 16, 32)
	pointsBadge.BorderSizePixel = 0
	pointsBadge.ZIndex = modal.ZIndex + 2
	pointsBadge.Parent = modal
	UILib.ApplyCorner(pointsBadge, 8)
	UILib.ApplyStroke(pointsBadge, Color3.fromRGB(250, 204, 21), 1, 0.5)

	local pointsLabel = Instance.new("TextLabel")
	pointsLabel.Name = "PointsLabel"
	pointsLabel.Size = UDim2.new(1, -16, 1, 0)
	pointsLabel.Position = UDim2.new(0, 12, 0, 0)
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.Text = "✦ AVAILABLE CONSTELLATION POINTS: 0"
	pointsLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	pointsLabel.TextSize = 12
	pointsLabel.Font = UILib.Fonts.Bold
	pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
	pointsLabel.ZIndex = modal.ZIndex + 3
	pointsLabel.Parent = pointsBadge

	-- Scrolling upgrade list
	local scroll = UILib.CreateScrollFrame(
		modal, "TreeScroll",
		UDim2.new(1, -32, 1, -100),
		UDim2.new(0, 16, 0, 94),
		ACCENT
	)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.FillDirection = Enum.FillDirection.Vertical
	scrollLayout.Padding = UDim.new(0, 8)
	scrollLayout.Parent = scroll

	-- Generate sleek upgrade cards
	for upgradeId, cfg in CONSTELLATION_CONFIG do
		local meta = UPGRADE_METADATA[upgradeId] or { Title = upgradeId, Glyph = "✦", Color = ACCENT, Subtitle = "" }

		local card = Instance.new("Frame")
		card.Name = upgradeId
		card.Size = UDim2.new(1, 0, 0, 68)
		card.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
		card.BorderSizePixel = 0
		card.ZIndex = modal.ZIndex + 2
		card.Parent = scroll
		UILib.ApplyCorner(card, 10)
		
		local stroke = Instance.new("UIStroke")
		stroke.Name = "CardStroke"
		stroke.Color = meta.Color
		stroke.Thickness = 1.2
		stroke.Transparency = 0.6
		stroke.Parent = card

		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 22, 46)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 12, 26)),
		})
		grad.Rotation = 90
		grad.Parent = card

		-- Left Icon Capsule
		local iconCapsule = Instance.new("Frame")
		iconCapsule.Size = UDim2.new(0, 38, 0, 38)
		iconCapsule.Position = UDim2.new(0, 12, 0.5, -19)
		iconCapsule.BackgroundColor3 = meta.Color
		iconCapsule.BackgroundTransparency = 0.85
		iconCapsule.BorderSizePixel = 0
		iconCapsule.ZIndex = modal.ZIndex + 3
		iconCapsule.Parent = card
		UILib.ApplyCorner(iconCapsule, 8)
		UILib.ApplyStroke(iconCapsule, meta.Color, 1, 0.5)

		local glyph = Instance.new("TextLabel")
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.BackgroundTransparency = 1
		glyph.Text = meta.Glyph
		glyph.TextColor3 = meta.Color
		glyph.TextSize = 18
		glyph.Font = UILib.Fonts.Bold
		glyph.ZIndex = modal.ZIndex + 4
		glyph.Parent = iconCapsule

		-- Title & Subtitle
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(0.55, 0, 0, 16)
		title.Position = UDim2.new(0, 58, 0, 10)
		title.BackgroundTransparency = 1
		title.Text = meta.Title
		title.TextColor3 = Color3.fromRGB(244, 235, 255)
		title.TextSize = 12
		title.Font = UILib.Fonts.Bold
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.ZIndex = modal.ZIndex + 3
		title.Parent = card

		local subtitle = Instance.new("TextLabel")
		subtitle.Name = "Subtitle"
		subtitle.Size = UDim2.new(0.55, 0, 0, 14)
		subtitle.Position = UDim2.new(0, 58, 0, 26)
		subtitle.BackgroundTransparency = 1
		subtitle.Text = meta.Subtitle
		subtitle.TextColor3 = Color3.fromRGB(180, 170, 200)
		subtitle.TextSize = 10
		subtitle.Font = UILib.Fonts.Medium
		subtitle.TextXAlignment = Enum.TextXAlignment.Left
		subtitle.ZIndex = modal.ZIndex + 3
		subtitle.Parent = card

		-- Level progress bar
		local barBg = Instance.new("Frame")
		barBg.Name = "LevelBarBg"
		barBg.Size = UDim2.new(0.48, 0, 0, 5)
		barBg.Position = UDim2.new(0, 58, 0, 48)
		barBg.BackgroundColor3 = Color3.fromRGB(30, 24, 48)
		barBg.BorderSizePixel = 0
		barBg.ZIndex = modal.ZIndex + 3
		barBg.Parent = card
		UILib.ApplyPill(barBg)

		local barFill = Instance.new("Frame")
		barFill.Name = "Fill"
		barFill.Size = UDim2.fromScale(0, 1)
		barFill.BackgroundColor3 = meta.Color
		barFill.BorderSizePixel = 0
		barFill.ZIndex = modal.ZIndex + 4
		barFill.Parent = barBg
		UILib.ApplyPill(barFill)

		local levelText = Instance.new("TextLabel")
		levelText.Name = "LevelText"
		levelText.Size = UDim2.new(0, 70, 0, 14)
		levelText.Position = UDim2.new(0.48, 64, 0, 43)
		levelText.BackgroundTransparency = 1
		levelText.Text = `0 / {cfg.MaxLevel}`
		levelText.TextColor3 = meta.Color
		levelText.TextSize = 9
		levelText.Font = UILib.Fonts.Bold
		levelText.TextXAlignment = Enum.TextXAlignment.Left
		levelText.ZIndex = modal.ZIndex + 3
		levelText.Parent = card

		-- Upgrade Button
		local btn = Instance.new("TextButton")
		btn.Name = "UpgradeBtn"
		btn.Size = UDim2.new(0, 110, 0, 32)
		btn.Position = UDim2.new(1, -122, 0.5, -16)
		btn.BackgroundColor3 = Color3.fromRGB(30, 24, 50)
		btn.BorderSizePixel = 0
		btn.Text = `UPGRADE ({cfg.PointCost} PT)`
		btn.TextColor3 = meta.Color
		btn.TextSize = 10
		btn.Font = UILib.Fonts.Bold
		btn.ZIndex = modal.ZIndex + 3
		btn.Parent = card
		UILib.ApplyCorner(btn, 8)
		UILib.ApplyStroke(btn, meta.Color, 1.2, 0.4)

		btn.MouseEnter:Connect(function()
			SoundController.Play("ButtonHover")
			TweenService:Create(btn, UILib.Timing.Fast, {
				BackgroundColor3 = Color3.fromRGB(48, 38, 75),
			}):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, UILib.Timing.Fast, {
				BackgroundColor3 = Color3.fromRGB(30, 24, 50),
			}):Play()
		end)

		btn.MouseButton1Click:Connect(function()
			local availPts = ConstellationModal._data and ConstellationModal._data.ConstellationPoints or 0
			if availPts < cfg.PointCost then
				SoundController.Play("ButtonHover")
				UILib.ShakeElement(btn, Color3.fromRGB(180, 50, 50))
				local notif = script.Parent:FindFirstChild("NotificationUI")
				if notif then
					local nMod = require(notif :: ModuleScript)
					nMod.ShowToast(`✦ Requires {cfg.PointCost} Constellation Points! (Earned via Rebirth/Ascension)`, Color3.fromRGB(250, 204, 21), 3.0)
				end
				return
			end

			SoundController.Play("ButtonClick")
			local gardenRequest = ReplicatedStorage:FindFirstChild("GardenRequest") :: RemoteFunction?
			if gardenRequest then
				gardenRequest:InvokeServer("UpgradeConstellation", upgradeId)
			end
		end)

		ConstellationModal._cards[upgradeId] = card
	end
end

function ConstellationModal.Open()
	if not ConstellationModal._frame then return end
	UILib.OpenModal(ConstellationModal._frame)
end

function ConstellationModal.Close()
	if not ConstellationModal._frame then return end
	UILib.CloseModal(ConstellationModal._frame)
end

function ConstellationModal.Update(data: any)
	if not data then return end
	ConstellationModal._data = data

	local modal = ConstellationModal._frame
	if not modal then return end

	local pointsBadge = modal:FindFirstChild("PointsBadge")
	local pointsLabel = pointsBadge and pointsBadge:FindFirstChild("PointsLabel") :: TextLabel?
	local availPts = data.ConstellationPoints or 0
	if pointsLabel then
		pointsLabel.Text = `✦ AVAILABLE CONSTELLATION POINTS: {availPts}`
	end

	local upgrades = data.Constellation or {}
	for upgradeId, card in ConstellationModal._cards do
		local curLevel = upgrades[upgradeId] or 0
		local cfg = CONSTELLATION_CONFIG[upgradeId]
		if not cfg then continue end

		local barBg = card:FindFirstChild("LevelBarBg")
		local fill = barBg and barBg:FindFirstChild("Fill") :: Frame?
		local levelText = card:FindFirstChild("LevelText") :: TextLabel?
		local btn = card:FindFirstChild("UpgradeBtn") :: TextButton?

		if fill then
			fill.Size = UDim2.fromScale(math.clamp(curLevel / cfg.MaxLevel, 0, 1), 1)
		end
		if levelText then
			levelText.Text = `{curLevel} / {cfg.MaxLevel}`
		end

		if btn then
			if curLevel >= cfg.MaxLevel then
				btn.Text = "★ MAXED ★"
				btn.BackgroundColor3 = Color3.fromRGB(24, 48, 36)
				btn.TextColor3 = Color3.fromRGB(52, 211, 153)
				btn.Active = false
			else
				btn.Text = `UPGRADE ({cfg.PointCost} PT)`
				btn.Active = true
				if availPts >= cfg.PointCost then
					btn.BackgroundColor3 = Color3.fromRGB(42, 32, 68)
					btn.TextColor3 = Color3.fromRGB(250, 204, 21)
				else
					btn.BackgroundColor3 = Color3.fromRGB(24, 20, 36)
					btn.TextColor3 = Color3.fromRGB(140, 130, 160)
				end
			end
		end
	end
end

return ConstellationModal
