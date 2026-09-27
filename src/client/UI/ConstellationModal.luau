--!strict
--[[
	ConstellationModal.luau — Star Chart Prestige Skill Tree for STARWEAVE
	Allows players to allocate Constellation Points earned from Rebirth
	into permanent passive economic & mutation multipliers.
	Located in: StarterPlayerScripts.Client.UI.ConstellationModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local VFXController = require(script.Parent.Parent.Controllers.VFXController)

local player = Players.LocalPlayer

local ConstellationModal = {}
ConstellationModal._frame = nil :: Frame?
ConstellationModal._data = nil :: any
ConstellationModal._cards = {} :: { [string]: Frame }

local UPGRADE_METADATA: { [string]: { Title: string, Icon: string, Color: Color3 } } = {
	sell_bonus = { Title = "Cosmic Commerce", Icon = "⭐", Color = Color3.fromRGB(250, 204, 21) },
	mutation_luck = { Title = "Astral Fortune", Icon = "🔮", Color = Color3.fromRGB(168, 85, 247) },
	growth_speed = { Title = "Temporal Warp", Icon = "⚡", Color = Color3.fromRGB(56, 189, 248) },
	plot_discount = { Title = "Spatial Architect", Icon = "📐", Color = Color3.fromRGB(74, 222, 128) },
	xp_bonus = { Title = "Adept Wisdom", Icon = "📜", Color = Color3.fromRGB(192, 132, 252) },
	seed_yield = { Title = "Bountiful Spores", Icon = "🌱", Color = Color3.fromRGB(251, 146, 60) },
	stardust_interest = { Title = "Gravity Compound", Icon = "🌌", Color = Color3.fromRGB(244, 114, 182) },
}

local CONSTELLATION_CONFIG: { [string]: { MaxLevel: number, PointCost: number, Description: string } } = {
	sell_bonus = { MaxLevel = 20, PointCost = 1, Description = "+5% sell value per level" },
	mutation_luck = { MaxLevel = 15, PointCost = 2, Description = "+3% mutation luck per level" },
	growth_speed = { MaxLevel = 10, PointCost = 2, Description = "+5% growth speed per level" },
	plot_discount = { MaxLevel = 10, PointCost = 1, Description = "-5% plot unlock cost per level" },
	xp_bonus = { MaxLevel = 15, PointCost = 1, Description = "+10% XP per level" },
	seed_yield = { MaxLevel = 10, PointCost = 3, Description = "+1 bonus seed per harvest per level" },
	stardust_interest = { MaxLevel = 5, PointCost = 5, Description = "+1% Stardust interest per min per level" },
}

function ConstellationModal.Create(parentGui: ScreenGui)
	local modal = Instance.new("Frame")
	modal.Name = "ConstellationModal"
	modal.Size = UDim2.new(0, 560, 0, 520)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.BackgroundColor3 = Color3.fromRGB(15, 11, 28)
	modal.BackgroundTransparency = 0.1
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = parentGui
	ConstellationModal._frame = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(200, 160, 255)
	stroke.Thickness = 2
	stroke.Parent = modal

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundTransparency = 1
	header.Parent = modal

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.7, 0, 0, 26)
	title.Position = UDim2.new(0, 20, 0, 12)
	title.BackgroundTransparency = 1
	title.Text = "🌌 CONSTELLATION STAR CHART"
	title.TextColor3 = Color3.fromRGB(200, 160, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local pointsLabel = Instance.new("TextLabel")
	pointsLabel.Name = "PointsLabel"
	pointsLabel.Size = UDim2.new(0.7, 0, 0, 18)
	pointsLabel.Position = UDim2.new(0, 20, 0, 38)
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.Text = "Available Constellation Points: 0 ✨"
	pointsLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	pointsLabel.TextScaled = true
	pointsLabel.Font = Enum.Font.GothamBold
	pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
	pointsLabel.Parent = header

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -44, 0, 12)
	closeBtn.BackgroundColor3 = Color3.fromRGB(30, 22, 50)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(216, 180, 254)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = header

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		SoundController.Play("ButtonClick")
		ConstellationModal.Close()
	end)

	-- Scroll Grid
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "TreeScroll"
	scroll.Size = UDim2.new(1, -40, 1, -80)
	scroll.Position = UDim2.new(0, 20, 0, 68)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(200, 160, 255)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 640)
	scroll.Parent = modal

	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.FillDirection = Enum.FillDirection.Vertical
	scrollLayout.Padding = UDim.new(0, 10)
	scrollLayout.Parent = scroll

	-- Generate upgrade cards
	for upgradeId, cfg in CONSTELLATION_CONFIG do
		local meta = UPGRADE_METADATA[upgradeId] or { Title = upgradeId, Icon = "✨", Color = Color3.fromRGB(200, 160, 255) }

		local card = Instance.new("Frame")
		card.Name = upgradeId
		card.Size = UDim2.new(1, 0, 0, 78)
		card.BackgroundColor3 = Color3.fromRGB(24, 18, 42)
		card.BorderSizePixel = 0
		card.Parent = scroll

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 10)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = meta.Color
		cStroke.Thickness = 1.2
		cStroke.Transparency = 0.5
		cStroke.Parent = card

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(0, 36, 0, 36)
		iconLabel.Position = UDim2.new(0, 12, 0, 12)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = meta.Icon
		iconLabel.TextScaled = true
		iconLabel.Parent = card

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "TitleLabel"
		titleLabel.Size = UDim2.new(0.5, 0, 0, 20)
		titleLabel.Position = UDim2.new(0, 56, 0, 10)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = meta.Title
		titleLabel.TextColor3 = meta.Color
		titleLabel.TextScaled = true
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.Name = "DescLabel"
		descLabel.Size = UDim2.new(0.5, 0, 0, 16)
		descLabel.Position = UDim2.new(0, 56, 0, 32)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = cfg.Description
		descLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
		descLabel.TextScaled = true
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Parent = card

		local levelPill = Instance.new("TextLabel")
		levelPill.Name = "LevelPill"
		levelPill.Size = UDim2.new(0.5, 0, 0, 16)
		levelPill.Position = UDim2.new(0, 56, 0, 50)
		levelPill.BackgroundTransparency = 1
		levelPill.Text = string.format("Level 0 / %d", cfg.MaxLevel)
		levelPill.TextColor3 = Color3.fromRGB(216, 180, 254)
		levelPill.TextScaled = true
		levelPill.Font = Enum.Font.GothamBold
		levelPill.TextXAlignment = Enum.TextXAlignment.Left
		levelPill.Parent = card

		local upBtn = Instance.new("TextButton")
		upBtn.Name = "UpgradeButton"
		upBtn.Size = UDim2.new(0, 130, 0, 38)
		upBtn.Position = UDim2.new(1, -142, 0.5, -19)
		upBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
		upBtn.BorderSizePixel = 0
		upBtn.Text = string.format("Upgrade (%d Pt)", cfg.PointCost)
		upBtn.TextColor3 = Color3.fromRGB(113, 113, 122)
		upBtn.TextScaled = true
		upBtn.Font = Enum.Font.GothamBold
		upBtn.Parent = card

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = upBtn

		upBtn.MouseButton1Click:Connect(function()
			local data = ConstellationModal._data
			if not data or not data.Rebirth then return end

			local curPts = data.Rebirth.ConstellationPoints or 0
			if curPts >= cfg.PointCost then
				SoundController.Play("HarvestRare")
				VFXController.AddCameraTrauma(0.2)
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

	local pLabel = modal:FindFirstChild("Header") and modal.Header:FindFirstChild("PointsLabel") :: TextLabel?
	if pLabel then
		pLabel.Text = string.format("Available Constellation Points: %d ✨", points)
	end

	for upgradeId, card in ConstellationModal._cards do
		local cfg = CONSTELLATION_CONFIG[upgradeId]
		if not cfg then continue end

		local currentLvl = tree[upgradeId] or 0
		local isMax = currentLvl >= cfg.MaxLevel
		local canAfford = not isMax and points >= cfg.PointCost

		local levelPill = card:FindFirstChild("LevelPill") :: TextLabel?
		if levelPill then
			levelPill.Text = isMax and string.format("Level %d / %d (MAX)", currentLvl, cfg.MaxLevel) or string.format("Level %d / %d", currentLvl, cfg.MaxLevel)
		end

		local upBtn = card:FindFirstChild("UpgradeButton") :: TextButton?
		if upBtn then
			if isMax then
				upBtn.BackgroundColor3 = Color3.fromRGB(30, 24, 48)
				upBtn.TextColor3 = Color3.fromRGB(148, 163, 184)
				upBtn.Text = "MAX LEVEL"
			elseif canAfford then
				upBtn.BackgroundColor3 = Color3.fromRGB(147, 51, 234)
				upBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				upBtn.Text = string.format("Upgrade (%d Pt)", cfg.PointCost)
			else
				upBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
				upBtn.TextColor3 = Color3.fromRGB(113, 113, 122)
				upBtn.Text = string.format("Upgrade (%d Pt)", cfg.PointCost)
			end
		end
	end
end

function ConstellationModal.Open()
	if not ConstellationModal._frame then return end
	ConstellationModal._frame.Visible = true
	ConstellationModal._frame.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(ConstellationModal._frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
	ConstellationModal.Refresh()
end

function ConstellationModal.Close()
	if not ConstellationModal._frame then return end
	local tween = TweenService:Create(ConstellationModal._frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0.5, 0.55),
	})
	tween:Play()
	tween.Completed:Once(function()
		ConstellationModal._frame.Visible = false
	end)
end

function ConstellationModal.Update(data: any)
	ConstellationModal._data = data
	if ConstellationModal._frame and ConstellationModal._frame.Visible then
		ConstellationModal.Refresh()
	end
end

return ConstellationModal
