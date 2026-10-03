--!strict
--[[
	ShopModal.luau — Cosmic Seed Market for STARWEAVE
	Polished market window for purchasing seeds with real-time
	affordability validation, tier filtering, and audio feedback.
	Located in: StarterPlayerScripts.Client.UI.ShopModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SeedData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeedData"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local UILib = require(script.Parent.UILib)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ShopModal = {}
ShopModal._gui = nil :: ScreenGui?
ShopModal._frame = nil :: Frame?
ShopModal._data = nil :: any
ShopModal._activeFilter = "All"
ShopModal._cardList = {} :: { Frame }
ShopModal._filterButtons = {} :: { [string]: TextButton }

local SEED_PRICE_MULTIPLIER: { [string]: number } = {
	Common = 2, Uncommon = 2.5, Rare = 3, Epic = 3.5,
	Legendary = 4, Celestial = 5, Void = 6,
}

local ACCENT = Color3.fromRGB(74, 222, 128) -- green market theme

function ShopModal.Create(parentGui: ScreenGui)
	ShopModal._gui = parentGui

	local modal = UILib.CreateModalFrame(parentGui, "ShopModal", 560, 500, ACCENT)
	ShopModal._frame = modal

	-- Header
	UILib.CreateModalHeader(modal, "Cosmic Seed Market", "Acquire celestial flora to cultivate stardust", ACCENT, function()
		SoundController.Play("ButtonClick")
		ShopModal.Close()
	end)

	-- Filter Tab Bar
	local filterBar = Instance.new("Frame")
	filterBar.Name = "FilterBar"
	filterBar.Size = UDim2.new(1, -32, 0, 30)
	filterBar.Position = UDim2.new(0, 16, 0, 68)
	filterBar.BackgroundTransparency = 1
	filterBar.ZIndex = modal.ZIndex + 1
	filterBar.Parent = modal

	local filterLayout = Instance.new("UIListLayout")
	filterLayout.FillDirection = Enum.FillDirection.Horizontal
	filterLayout.Padding = UDim.new(0, 4)
	filterLayout.Parent = filterBar

	local filters = { "All", "Common", "Uncommon", "Rare", "Epic", "Celestial" }
	for _, fName in filters do
		local tab = Instance.new("TextButton")
		tab.Name = fName
		tab.Size = UDim2.new(0, 80, 1, 0)
		tab.BackgroundColor3 = UILib.Colors.Surface2
		tab.BackgroundTransparency = 0.3
		tab.BorderSizePixel = 0
		tab.Text = fName
		tab.TextColor3 = UILib.Colors.TextSecondary
		tab.TextSize = 11
		tab.Font = UILib.Fonts.Bold
		tab.ZIndex = modal.ZIndex + 2
		tab.Parent = filterBar
		UILib.ApplyCorner(tab, 6)

		-- Active indicator (bottom line)
		local indicator = Instance.new("Frame")
		indicator.Name = "Indicator"
		indicator.Size = UDim2.new(0.6, 0, 0, 2)
		indicator.Position = UDim2.new(0.2, 0, 1, -3)
		indicator.BackgroundColor3 = ACCENT
		indicator.BorderSizePixel = 0
		indicator.Visible = (fName == "All")
		indicator.ZIndex = modal.ZIndex + 3
		indicator.Parent = tab
		UILib.ApplyPill(indicator)

		ShopModal._filterButtons[fName] = tab

		tab.MouseEnter:Connect(function()
			if ShopModal._activeFilter ~= fName then
				TweenService:Create(tab, UILib.Timing.Fast, {
					BackgroundColor3 = UILib.Colors.Surface3,
				}):Play()
			end
		end)

		tab.MouseLeave:Connect(function()
			if ShopModal._activeFilter ~= fName then
				TweenService:Create(tab, UILib.Timing.Fast, {
					BackgroundColor3 = UILib.Colors.Surface2,
				}):Play()
			end
		end)

		tab.MouseButton1Click:Connect(function()
			SoundController.Play("ButtonHover")
			ShopModal._activeFilter = fName
			-- Update visual states
			for fname, fbtn in ShopModal._filterButtons do
				local ind = fbtn:FindFirstChild("Indicator") :: Frame?
				if ind then ind.Visible = (fname == fName) end
				fbtn.BackgroundColor3 = (fname == fName) and UILib.Colors.Surface4 or UILib.Colors.Surface2
				fbtn.TextColor3 = (fname == fName) and UILib.Colors.TextPrimary or UILib.Colors.TextSecondary
			end
			ShopModal.RefreshGrid()
		end)
	end

	-- Scrolling Cards
	local scroll = UILib.CreateScrollFrame(
		modal, "CardScroll",
		UDim2.new(1, -32, 1, -118),
		UDim2.new(0, 16, 0, 108),
		ACCENT
	)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 156, 0, 180)
	gridLayout.CellPadding = UDim2.new(0, 12, 0, 12)
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
		local tierColor = UILib.TierColor[seed.Tier] or UILib.Colors.Common

		-- Card
		local card = UILib.CreateCard(scroll, seed.Id, tierColor)
		card.ZIndex = modal.ZIndex + 2

		-- Tier pill badge
		UILib.CreatePill(card, seed.Tier, tierColor, UDim2.new(0, 8, 0, 8))

		-- Seed name
		UILib.CreateLabel(
			card, "Name", seed.Name, UILib.Colors.TextPrimary,
			14, UILib.Fonts.Bold,
			UDim2.new(0, 10, 0, 32), UDim2.new(1, -20, 0, 18)
		)

		-- Growth time
		UILib.CreateLabel(
			card, "Growth", string.format("Growth: %ds", seed.GrowthTime), UILib.Colors.TextMuted,
			11, UILib.Fonts.Body,
			UDim2.new(0, 10, 0, 54), UDim2.new(1, -20, 0, 14)
		)

		-- Base value
		UILib.CreateLabel(
			card, "Value", string.format("Base: %s SD", UILib.FormatNumber(seed.BaseValue)), UILib.Colors.TextMuted,
			11, UILib.Fonts.Body,
			UDim2.new(0, 10, 0, 70), UDim2.new(1, -20, 0, 14)
		)

		-- Mutation chance indicator
		local mutLabel = UILib.CreateLabel(
			card, "MutChance",
			string.format("Mut. %%: %.1f%%", (seed.BaseMutationChance or 0) * 100),
			UILib.Colors.PurpleLight,
			10, UILib.Fonts.Medium,
			UDim2.new(0, 10, 0, 90), UDim2.new(1, -20, 0, 14)
		)
		mutLabel.ZIndex = modal.ZIndex + 3

		-- Separator line
		local sep = Instance.new("Frame")
		sep.Size = UDim2.new(1, -20, 0, 1)
		sep.Position = UDim2.new(0, 10, 0, 112)
		sep.BackgroundColor3 = tierColor
		sep.BackgroundTransparency = 0.7
		sep.BorderSizePixel = 0
		sep.ZIndex = modal.ZIndex + 3
		sep.Parent = card

		-- Buy Button
		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyButton"
		buyBtn.Size = UDim2.new(1, -20, 0, 34)
		buyBtn.Position = UDim2.new(0, 10, 1, -44)
		buyBtn.BackgroundColor3 = canAfford and UILib.Colors.GreenDim or UILib.Colors.Surface3
		buyBtn.BorderSizePixel = 0
		buyBtn.Text = string.format("%s SD", UILib.FormatNumber(price))
		buyBtn.TextColor3 = canAfford and UILib.Colors.Green or UILib.Colors.TextMuted
		buyBtn.TextSize = 13
		buyBtn.Font = UILib.Fonts.Bold
		buyBtn.ZIndex = modal.ZIndex + 3
		buyBtn.Parent = card
		UILib.ApplyCorner(buyBtn, 8)

		if canAfford then
			-- Gradient for depth on affordable buttons
			local buyGrad = Instance.new("UIGradient")
			buyGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 220, 200)),
			})
			buyGrad.Rotation = 90
			buyGrad.Parent = buyBtn

			buyBtn.MouseEnter:Connect(function()
				TweenService:Create(buyBtn, UILib.Timing.Fast, {
					Size = UDim2.new(1, -16, 0, 36),
				}):Play()
			end)
			buyBtn.MouseLeave:Connect(function()
				TweenService:Create(buyBtn, UILib.Timing.Fast, {
					Size = UDim2.new(1, -20, 0, 34),
				}):Play()
			end)
		end

		buyBtn.MouseButton1Click:Connect(function()
			if canAfford then
				SoundController.Play("HarvestCommon")
				-- Press feedback
				TweenService:Create(buyBtn, TweenInfo.new(0.06), {
					Size = UDim2.new(1, -22, 0, 32),
				}):Play()
				task.delay(0.08, function()
					TweenService:Create(buyBtn, UILib.Timing.Fast, {
						Size = UDim2.new(1, -20, 0, 34),
					}):Play()
				end)
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
	UILib.OpenModal(ShopModal._frame)
	ShopModal.RefreshGrid()
end

function ShopModal.Close()
	if not ShopModal._frame then return end
	UILib.CloseModal(ShopModal._frame)
end

function ShopModal.Update(data: any)
	ShopModal._data = data
	if ShopModal._frame and ShopModal._frame.Visible then
		ShopModal.RefreshGrid()
	end
end

return ShopModal
