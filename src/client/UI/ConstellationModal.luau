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

local ACCENT = Color3.fromRGB(200, 160, 255)

local UPGRADE_METADATA: { [string]: { Title: string, Glyph: string, Color: Color3 } } = {
	sell_bonus         = { Title = "Cosmic Commerce",    Glyph = "Cx", Color = Color3.fromRGB(250, 204, 21) },
	mutation_luck      = { Title = "Astral Fortune",     Glyph = "Af", Color = Color3.fromRGB(168, 85, 247) },
	growth_speed       = { Title = "Temporal Warp",      Glyph = "Tw", Color = Color3.fromRGB(56, 189, 248) },
	plot_discount      = { Title = "Spatial Architect",  Glyph = "Sa", Color = Color3.fromRGB(74, 222, 128) },
	xp_bonus           = { Title = "Adept Wisdom",       Glyph = "Aw", Color = Color3.fromRGB(192, 132, 252) },
	seed_yield         = { Title = "Bountiful Spores",   Glyph = "Bs", Color = Color3.fromRGB(251, 146, 60) },
	stardust_interest  = { Title = "Gravity Compound",   Glyph = "Gc", Color = Color3.fromRGB(244, 114, 182) },
}

local CONSTELLATION_CONFIG: { [string]: { MaxLevel: number, PointCost: number, Description: string } } = {
	sell_bonus         = { MaxLevel = 20, PointCost = 1, Description = "+5% sell value per level" },
	mutation_luck      = { MaxLevel = 15, PointCost = 2, Description = "+3% mutation luck per level" },
	growth_speed       = { MaxLevel = 10, PointCost = 2, Description = "+5% growth speed per level" },
	plot_discount      = { MaxLevel = 10, PointCost = 1, Description = "-5% plot unlock cost per level" },
	xp_bonus           = { MaxLevel = 15, PointCost = 1, Description = "+10% XP per level" },
	seed_yield         = { MaxLevel = 10, PointCost = 3, Description = "+1 bonus seed per harvest per level" },
	stardust_interest  = { MaxLevel = 5,  PointCost = 5, Description = "+1% Stardust interest/min per level" },
}

function ConstellationModal.Create(parentGui: ScreenGui)
	local modal = UILib.CreateModalFrame(parentGui, "ConstellationModal", 580, 540, ACCENT)
	ConstellationModal._frame = modal

	-- Header
	local header = UILib.CreateModalHeader(modal, "Constellation Star Chart", "Allocate points into permanent cosmic passives", ACCENT, function()
		SoundController.Play("ButtonClick")
		ConstellationModal.Close()
	end)

	-- Points display
	local pointsLabel = Instance.new("TextLabel")
	pointsLabel.Name = "PointsLabel"
	pointsLabel.Size = UDim2.new(1, -32, 0, 20)
	pointsLabel.Position = UDim2.new(0, 16, 0, 68)
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.Text = "Available Constellation Points: 0"
	pointsLabel.TextColor3 = UILib.Colors.Gold
	pointsLabel.TextSize = 14
	pointsLabel.Font = UILib.Fonts.Bold
	pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
	pointsLabel.ZIndex = modal.ZIndex + 2
	pointsLabel.Parent = modal

	-- Scrolling upgrade list
	local scroll = UILib.CreateScrollFrame(
		modal, "TreeScroll",
		UDim2.new(1, -32, 1, -108),
		UDim2.new(0, 16, 0, 96),
		ACCENT
	)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.FillDirection = Enum.FillDirection.Vertical
	scrollLayout.Padding = UDim.new(0, 8)
	scrollLayout.Parent = scroll

	-- Generate upgrade cards
	for upgradeId, cfg in CONSTELLATION_CONFIG do
		local meta = UPGRADE_METADATA[upgradeId] or { Title = upgradeId, Glyph = "?", Color = ACCENT }

		local card = Instance.new("Frame")
		card.Name = upgradeId
		card.Size = UDim2.new(1, 0, 0, 80)
		card.BackgroundColor3 = UILib.Colors.Surface2
		card.BorderSizePixel = 0
		card.ZIndex = modal.ZIndex + 2
		card.Parent = scroll
		UILib.ApplyCorner(card, 10)
		UILib.ApplyStroke(card, meta.Color, 1, 0.55)

		-- Gradient depth
		local cGrad = Instance.new("UIGradient")
		cGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 20, 46)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 10, 28)),
		})
		cGrad.Rotation = 150
		cGrad.Parent = card

		-- Icon circle
		local iconCircle = Instance.new("Frame")
		iconCircle.Size = UDim2.new(0, 38, 0, 38)
		iconCircle.Position = UDim2.new(0, 12, 0.5, -19)
		iconCircle.BackgroundColor3 = meta.Color
		iconCircle.BackgroundTransparency = 0.7
		iconCircle.BorderSizePixel = 0
		iconCircle.ZIndex = modal.ZIndex + 3
		iconCircle.Parent = card
		UILib.ApplyPill(iconCircle)

		local glyphLabel = Instance.new("TextLabel")
		glyphLabel.Size = UDim2.fromScale(1, 1)
		glyphLabel.BackgroundTransparency = 1
		glyphLabel.Text = meta.Glyph
		glyphLabel.TextColor3 = meta.Color
		glyphLabel.TextSize = 14
		glyphLabel.Font = UILib.Fonts.Black
		glyphLabel.ZIndex = modal.ZIndex + 4
		glyphLabel.Parent = iconCircle

		-- Title
		UILib.CreateLabel(card, "TitleLabel", meta.Title, meta.Color, 14, UILib.Fonts.Bold,
			UDim2.new(0, 60, 0, 8), UDim2.new(0.5, 0, 0, 18))

		-- Description
		UILib.CreateLabel(card, "DescLabel", cfg.Description, UILib.Colors.TextSecondary, 11, UILib.Fonts.Body,
			UDim2.new(0, 60, 0, 28), UDim2.new(0.5, 0, 0, 14))

		-- Level pill
		local levelPill = Instance.new("TextLabel")
		levelPill.Name = "LevelPill"
		levelPill.Size = UDim2.new(0.35, 0, 0, 14)
		levelPill.Position = UDim2.new(0, 60, 0, 48)
		levelPill.BackgroundTransparency = 1
		levelPill.Text = string.format("Level 0 / %d", cfg.MaxLevel)
		levelPill.TextColor3 = UILib.Colors.PurpleLight
		levelPill.TextSize = 11
		levelPill.Font = UILib.Fonts.Bold
		levelPill.TextXAlignment = Enum.TextXAlignment.Left
		levelPill.ZIndex = modal.ZIndex + 3
		levelPill.Parent = card

		-- Mini progress bar
		local miniBarBg = Instance.new("Frame")
		miniBarBg.Name = "MiniBarBg"
		miniBarBg.Size = UDim2.new(0.32, 0, 0, 4)
		miniBarBg.Position = UDim2.new(0, 60, 0, 66)
		miniBarBg.BackgroundColor3 = UILib.Colors.Surface0
		miniBarBg.BorderSizePixel = 0
		miniBarBg.ZIndex = modal.ZIndex + 3
		miniBarBg.Parent = card
		UILib.ApplyPill(miniBarBg)

		local miniFill = Instance.new("Frame")
		miniFill.Name = "MiniFill"
		miniFill.Size = UDim2.fromScale(0, 1)
		miniFill.BackgroundColor3 = meta.Color
		miniFill.BorderSizePixel = 0
		miniFill.ZIndex = modal.ZIndex + 4
		miniFill.Parent = miniBarBg
		UILib.ApplyPill(miniFill)

		-- Upgrade button
		local upBtn = Instance.new("TextButton")
		upBtn.Name = "UpgradeButton"
		upBtn.Size = UDim2.new(0, 120, 0, 36)
		upBtn.Position = UDim2.new(1, -132, 0.5, -18)
		upBtn.BackgroundColor3 = UILib.Colors.Surface3
		upBtn.BorderSizePixel = 0
		upBtn.Text = string.format("Upgrade (%d Pt)", cfg.PointCost)
		upBtn.TextColor3 = UILib.Colors.TextMuted
		upBtn.TextSize = 12
		upBtn.Font = UILib.Fonts.Bold
		upBtn.ZIndex = modal.ZIndex + 3
		upBtn.Parent = card
		UILib.ApplyCorner(upBtn, 8)

		upBtn.MouseEnter:Connect(function()
			TweenService:Create(upBtn, UILib.Timing.Fast, {
				Size = UDim2.new(0, 124, 0, 38),
			}):Play()
		end)
		upBtn.MouseLeave:Connect(function()
			TweenService:Create(upBtn, UILib.Timing.Fast, {
				Size = UDim2.new(0, 120, 0, 36),
			}):Play()
		end)

		upBtn.MouseButton1Click:Connect(function()
			local data = ConstellationModal._data
			if not data or not data.Rebirth then return end

			local curPts = data.Rebirth.ConstellationPoints or 0
			if curPts >= cfg.PointCost then
				SoundController.Play("HarvestRare")
				VFXController.AddCameraTrauma(0.2)
				-- Press animation
				TweenService:Create(upBtn, TweenInfo.new(0.06), { Size = UDim2.new(0, 116, 0, 34) }):Play()
				task.delay(0.08, function()
					TweenService:Create(upBtn, UILib.Timing.Fast, { Size = UDim2.new(0, 120, 0, 36) }):Play()
				end)
				local ecoReq = ReplicatedStorage:FindFirstChild("EconomyRequest") :: RemoteFunction?
				if ecoReq then
					ecoReq:InvokeServer("UpgradeConstellation", upgradeId)
				end
			else
				SoundController.Play("ButtonHover")
			end
		end)

		ConstellationModal._cards[upgradeId] = card
	end

	ConstellationModal.Refresh()
end

function ConstellationModal.Refresh()
	local modal = ConstellationModal._frame
	if not modal then return end

	local data = ConstellationModal._data
	local points = data and data.Rebirth and data.Rebirth.ConstellationPoints or 0
	local tree = data and data.Rebirth and data.Rebirth.ConstellationTree or {}

	local pLabel = modal:FindFirstChild("PointsLabel") :: TextLabel?
	if pLabel then
		pLabel.Text = string.format("Available Constellation Points: %d", points)
	end

	for upgradeId, card in ConstellationModal._cards do
		local cfg = CONSTELLATION_CONFIG[upgradeId]
		local meta = UPGRADE_METADATA[upgradeId]
		if not cfg or not meta then continue end

		local currentLvl = tree[upgradeId] or 0
		local isMax = currentLvl >= cfg.MaxLevel
		local canAfford = not isMax and points >= cfg.PointCost

		-- Level text
		local levelPill = card:FindFirstChild("LevelPill") :: TextLabel?
		if levelPill then
			levelPill.Text = isMax
				and string.format("Level %d / %d (MAX)", currentLvl, cfg.MaxLevel)
				or string.format("Level %d / %d", currentLvl, cfg.MaxLevel)
		end

		-- Mini progress bar
		local miniBarBg = card:FindFirstChild("MiniBarBg")
		local miniFill = miniBarBg and miniBarBg:FindFirstChild("MiniFill") :: Frame?
		if miniFill then
			local pct = cfg.MaxLevel > 0 and (currentLvl / cfg.MaxLevel) or 0
			TweenService:Create(miniFill, UILib.Timing.Normal, {
				Size = UDim2.fromScale(pct, 1),
			}):Play()
		end

		-- Upgrade button
		local upBtn = card:FindFirstChild("UpgradeButton") :: TextButton?
		if upBtn then
			if isMax then
				upBtn.BackgroundColor3 = UILib.Colors.Surface2
				upBtn.TextColor3 = UILib.Colors.TextMuted
				upBtn.Text = "MAXED"
			elseif canAfford then
				upBtn.BackgroundColor3 = meta.Color
				upBtn.TextColor3 = UILib.Colors.TextPrimary
				upBtn.Text = string.format("Upgrade (%d Pt)", cfg.PointCost)
			else
				upBtn.BackgroundColor3 = UILib.Colors.Surface3
				upBtn.TextColor3 = UILib.Colors.TextMuted
				upBtn.Text = string.format("Upgrade (%d Pt)", cfg.PointCost)
			end
		end
	end
end

function ConstellationModal.Open()
	if not ConstellationModal._frame then return end
	UILib.OpenModal(ConstellationModal._frame)
	ConstellationModal.Refresh()
end

function ConstellationModal.Close()
	if not ConstellationModal._frame then return end
	UILib.CloseModal(ConstellationModal._frame)
end

function ConstellationModal.Update(data: any)
	ConstellationModal._data = data
	if ConstellationModal._frame and ConstellationModal._frame.Visible then
		ConstellationModal.Refresh()
	end
end

return ConstellationModal
