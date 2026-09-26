--!strict
--[[
	ShopModal.luau — Cosmic Seed Market Modal for STARWEAVE
	A modern, responsive glassmorphic market window for purchasing
	seeds and boosts with real-time affordability validation and audio feedback.
	Located in: StarterPlayerScripts.Client.UI.ShopModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SeedData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeedData"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ShopModal = {}
ShopModal._gui = nil :: ScreenGui?
ShopModal._frame = nil :: Frame?
ShopModal._data = nil :: any
ShopModal._activeFilter = "All"
ShopModal._cardList = {} :: { Frame }

local TIER_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(148, 163, 184),
	Uncommon = Color3.fromRGB(74, 222, 128),
	Rare = Color3.fromRGB(56, 189, 248),
	Epic = Color3.fromRGB(192, 132, 252),
	Legendary = Color3.fromRGB(251, 191, 36),
	Celestial = Color3.fromRGB(244, 114, 182),
	Void = Color3.fromRGB(147, 51, 234),
}

local SEED_PRICE_MULTIPLIER: { [string]: number } = {
	Common = 2,
	Uncommon = 2.5,
	Rare = 3,
	Epic = 3.5,
	Legendary = 4,
	Celestial = 5,
	Void = 6,
}

function ShopModal.Create(parentGui: ScreenGui)
	ShopModal._gui = parentGui

	-- Modal Backdrop Frame
	local modal = Instance.new("Frame")
	modal.Name = "ShopModal"
	modal.Size = UDim2.new(0, 540, 0, 480)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.BackgroundColor3 = Color3.fromRGB(15, 11, 28)
	modal.BackgroundTransparency = 0.12
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = parentGui
	ShopModal._frame = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(147, 51, 234)
	stroke.Thickness = 2
	stroke.Parent = modal

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 16, 44)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 9, 24)),
	})
	gradient.Rotation = 45
	gradient.Parent = modal

	-- Header Bar
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundTransparency = 1
	header.Parent = modal

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.7, 0, 0, 26)
	title.Position = UDim2.new(0, 20, 0, 12)
	title.BackgroundTransparency = 1
	title.Text = "🌱 COSMIC SEED MARKET"
	title.TextColor3 = Color3.fromRGB(250, 204, 21)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(0.7, 0, 0, 16)
	subtitle.Position = UDim2.new(0, 20, 0, 38)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Acquire celestial flora to cultivate stardust"
	subtitle.TextColor3 = Color3.fromRGB(148, 163, 184)
	subtitle.TextScaled = true
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = header

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
		ShopModal.Close()
	end)

	-- Filter Tabs
	local filterBar = Instance.new("Frame")
	filterBar.Name = "FilterBar"
	filterBar.Size = UDim2.new(1, -40, 0, 32)
	filterBar.Position = UDim2.new(0, 20, 0, 64)
	filterBar.BackgroundTransparency = 1
	filterBar.Parent = modal

	local filterLayout = Instance.new("UIListLayout")
	filterLayout.FillDirection = Enum.FillDirection.Horizontal
	filterLayout.Padding = UDim.new(0, 8)
	filterLayout.Parent = filterBar

	local filters = { "All", "Common", "Uncommon", "Rare", "Epic", "Celestial" }
	for _, fName in filters do
		local tab = Instance.new("TextButton")
		tab.Name = fName
		tab.Size = UDim2.new(0, 75, 1, 0)
		tab.BackgroundColor3 = Color3.fromRGB(28, 20, 48)
		tab.BorderSizePixel = 0
		tab.Text = fName
		tab.TextColor3 = Color3.fromRGB(203, 213, 225)
		tab.TextScaled = true
		tab.Font = Enum.Font.GothamBold
		tab.Parent = filterBar

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 6)
		tabCorner.Parent = tab

		tab.MouseButton1Click:Connect(function()
			SoundController.Play("ButtonHover")
			ShopModal._activeFilter = fName
			ShopModal.RefreshGrid()
		end)
	end

	-- Scrolling Cards Frame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "CardScroll"
	scroll.Size = UDim2.new(1, -40, 1, -120)
	scroll.Position = UDim2.new(0, 20, 0, 106)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(147, 51, 234)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 600)
	scroll.Parent = modal

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 154, 0, 172)
	gridLayout.CellPadding = UDim2.new(0, 14, 0, 14)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scroll

	ShopModal.RefreshGrid()
end

function ShopModal.RefreshGrid()
	local modal = ShopModal._frame
	if not modal then return end
	local scroll = modal:FindFirstChild("CardScroll") :: ScrollingFrame?
	if not scroll then return end

	for _, card in ShopModal._cardList do
		card:Destroy()
	end
	table.clear(ShopModal._cardList)

	local rebirthLvl = ShopModal._data and ShopModal._data.Rebirth and ShopModal._data.Rebirth.Level or 0
	local playerStardust = ShopModal._data and ShopModal._data.Stardust or 0
	local unlockedSeeds = SeedData.GetUnlockedSeeds(rebirthLvl)

	for _, seed in unlockedSeeds do
		if ShopModal._activeFilter ~= "All" and seed.Tier ~= ShopModal._activeFilter then
			continue
		end

		local mult = SEED_PRICE_MULTIPLIER[seed.Tier] or 3
		local price = math.floor(seed.BaseValue * mult)
		local canAfford = playerStardust >= price

		local card = Instance.new("Frame")
		card.Name = seed.Id
		card.BackgroundColor3 = Color3.fromRGB(24, 18, 42)
		card.BorderSizePixel = 0
		card.Parent = scroll

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 10)
		cardCorner.Parent = card

		local tierColor = TIER_COLORS[seed.Tier] or Color3.fromRGB(148, 163, 184)
		local stroke = Instance.new("UIStroke")
		stroke.Color = tierColor
		stroke.Thickness = 1.2
		stroke.Transparency = 0.3
		stroke.Parent = card

		-- Tier Pill
		local pill = Instance.new("Frame")
		pill.Name = "TierPill"
		pill.Size = UDim2.new(0, 64, 0, 16)
		pill.Position = UDim2.new(0, 8, 0, 8)
		pill.BackgroundColor3 = tierColor
		pill.BackgroundTransparency = 0.2
		pill.BorderSizePixel = 0
		pill.Parent = card

		local pillCorner = Instance.new("UICorner")
		pillCorner.CornerRadius = UDim.new(1, 0)
		pillCorner.Parent = pill

		local pillText = Instance.new("TextLabel")
		pillText.Size = UDim2.fromScale(1, 1)
		pillText.BackgroundTransparency = 1
		pillText.Text = string.upper(seed.Tier)
		pillText.TextColor3 = Color3.fromRGB(255, 255, 255)
		pillText.TextScaled = true
		pillText.Font = Enum.Font.GothamBold
		pillText.Parent = pill

		-- Name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -16, 0, 20)
		nameLabel.Position = UDim2.new(0, 8, 0, 30)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = seed.Name
		nameLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		-- Stats
		local statsLabel = Instance.new("TextLabel")
		statsLabel.Size = UDim2.new(1, -16, 0, 36)
		statsLabel.Position = UDim2.new(0, 8, 0, 56)
		statsLabel.BackgroundTransparency = 1
		statsLabel.Text = string.format("Growth: %ds\nBase: ⭐%d", seed.GrowthTime, seed.BaseValue)
		statsLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
		statsLabel.TextScaled = true
		statsLabel.Font = Enum.Font.Gotham
		statsLabel.TextXAlignment = Enum.TextXAlignment.Left
		statsLabel.Parent = card

		-- Buy Button
		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyButton"
		buyBtn.Size = UDim2.new(1, -16, 0, 32)
		buyBtn.Position = UDim2.new(0, 8, 1, -40)
		buyBtn.BackgroundColor3 = canAfford and Color3.fromRGB(22, 101, 52) or Color3.fromRGB(39, 39, 42)
		buyBtn.BorderSizePixel = 0
		buyBtn.Text = string.format("⭐ %d", price)
		buyBtn.TextColor3 = canAfford and Color3.fromRGB(187, 247, 208) or Color3.fromRGB(113, 113, 122)
		buyBtn.TextScaled = true
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.Parent = card

		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 8)
		buyCorner.Parent = buyBtn

		buyBtn.MouseButton1Click:Connect(function()
			if canAfford then
				SoundController.Play("HarvestCommon")
				local req = ReplicatedStorage:FindFirstChild("GardenRequest") :: RemoteFunction?
				if req then
					req:InvokeServer("BuySeed", seed.Id, 1)
				end
			else
				SoundController.Play("ButtonHover")
			end
		end)

		table.insert(ShopModal._cardList, card)
	end
end

function ShopModal.Open()
	if not ShopModal._frame then return end
	ShopModal._frame.Visible = true
	ShopModal._frame.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(ShopModal._frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
	ShopModal.RefreshGrid()
end

function ShopModal.Close()
	if not ShopModal._frame then return end
	local tween = TweenService:Create(ShopModal._frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0.5, 0.55),
	})
	tween:Play()
	tween.Completed:Once(function()
		ShopModal._frame.Visible = false
	end)
end

function ShopModal.Update(data: any)
	ShopModal._data = data
	if ShopModal._frame and ShopModal._frame.Visible then
		ShopModal.RefreshGrid()
	end
end

return ShopModal
