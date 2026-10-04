--!strict
--[[
	ShopModal.luau — Cosmic Market & Robux Store for STARWEAVE
	Full market suite featuring Flora Seeds, Gamepasses (Auto-Harvest, 2x Luck, VIP),
	and Developer Products (Superstorm, Instant Bloom, Gem Packs).
	Located in: StarterPlayerScripts.Client.UI.ShopModal
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SeedData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeedData"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local UILib = require(script.Parent.UILib)

local player = Players.LocalPlayer

local ShopModal = {}
ShopModal._gui = nil :: ScreenGui?
ShopModal._frame = nil :: Frame?
ShopModal._data = nil :: any
ShopModal._currentCategory = "Seeds" :: "Seeds" | "Gamepasses" | "Boosts"
ShopModal._activeFilter = "All"
ShopModal._cardList = {} :: { Frame }
ShopModal._filterButtons = {} :: { [string]: TextButton }
ShopModal._categoryButtons = {} :: { [string]: TextButton }

local SEED_PRICE_MULTIPLIER: { [string]: number } = {
	Common = 2, Uncommon = 2.5, Rare = 3, Epic = 3.5,
	Legendary = 4, Celestial = 5, Void = 6,
}

local ACCENT = Color3.fromRGB(74, 222, 128)

function ShopModal.Create(parentGui: ScreenGui)
	ShopModal._gui = parentGui

	local modal = UILib.CreateModalFrame(parentGui, "ShopModal", 580, 520, ACCENT)
	ShopModal._frame = modal

	-- Header
	UILib.CreateModalHeader(modal, "Cosmic Market", "Acquire celestial flora, permanent gamepasses & astral boosts", ACCENT, function()
		SoundController.Play("ButtonClick")
		ShopModal.Close()
	end)

	-- Top Category Tabs (Seeds / Gamepasses / Boosts)
	local catBar = Instance.new("Frame")
	catBar.Name = "CategoryBar"
	catBar.Size = UDim2.new(1, -32, 0, 32)
	catBar.Position = UDim2.new(0, 16, 0, 68)
	catBar.BackgroundColor3 = UILib.Colors.Surface0
	catBar.BorderSizePixel = 0
	catBar.ZIndex = modal.ZIndex + 1
	catBar.Parent = modal
	UILib.ApplyPill(catBar)
	UILib.ApplyStroke(catBar, UILib.Colors.PurpleDim, 1, 0.5)

	local catLayout = Instance.new("UIListLayout")
	catLayout.FillDirection = Enum.FillDirection.Horizontal
	catLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	catLayout.Padding = UDim.new(0, 6)
	catLayout.Parent = catBar

	local categories = {
		{ Id = "Seeds", Name = "Flora Seeds", Color = Color3.fromRGB(74, 222, 128) },
		{ Id = "Gamepasses", Name = "Gamepasses", Color = Color3.fromRGB(250, 204, 21) },
		{ Id = "Boosts", Name = "Boosts & Gems", Color = Color3.fromRGB(192, 132, 252) },
	}

	for _, cat in categories do
		local cBtn = Instance.new("TextButton")
		cBtn.Name = cat.Id
		cBtn.Size = UDim2.new(0, 160, 1, -6)
		cBtn.Position = UDim2.new(0, 0, 0, 3)
		cBtn.BackgroundColor3 = (cat.Id == "Seeds") and UILib.Colors.Surface3 or Color3.fromRGB(0, 0, 0)
		cBtn.BackgroundTransparency = (cat.Id == "Seeds") and 0 or 0.8
		cBtn.BorderSizePixel = 0
		cBtn.Text = cat.Name
		cBtn.TextColor3 = (cat.Id == "Seeds") and cat.Color or UILib.Colors.TextSecondary
		cBtn.TextSize = 12
		cBtn.Font = UILib.Fonts.Bold
		cBtn.ZIndex = modal.ZIndex + 2
		cBtn.Parent = catBar
		UILib.ApplyPill(cBtn)

		ShopModal._categoryButtons[cat.Id] = cBtn

		cBtn.MouseButton1Click:Connect(function()
			SoundController.Play("ButtonHover")
			ShopModal._currentCategory = cat.Id :: any
			for cid, btn in ShopModal._categoryButtons do
				local isActive = (cid == cat.Id)
				btn.BackgroundColor3 = isActive and UILib.Colors.Surface3 or Color3.fromRGB(0, 0, 0)
				btn.BackgroundTransparency = isActive and 0 or 0.8
				btn.TextColor3 = isActive and cat.Color or UILib.Colors.TextSecondary
			end
			ShopModal.RefreshGrid()
		end)
	end

	-- Sub-Filter Tab Bar (Only visible when Seeds category is active)
	local filterBar = Instance.new("Frame")
	filterBar.Name = "FilterBar"
	filterBar.Size = UDim2.new(1, -32, 0, 24)
	filterBar.Position = UDim2.new(0, 16, 0, 106)
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

		local indicator = Instance.new("Frame")
		indicator.Name = "Indicator"
		indicator.Size = UDim2.new(0.6, 0, 0, 2)
		indicator.Position = UDim2.new(0.2, 0, 1, -2)
		indicator.BackgroundColor3 = ACCENT
		indicator.BorderSizePixel = 0
		indicator.Visible = (fName == "All")
		indicator.ZIndex = modal.ZIndex + 3
		indicator.Parent = tab
		UILib.ApplyPill(indicator)

		ShopModal._filterButtons[fName] = tab

		tab.MouseButton1Click:Connect(function()
			SoundController.Play("ButtonHover")
			ShopModal._activeFilter = fName
			for fname, fbtn in ShopModal._filterButtons do
				local ind = fbtn:FindFirstChild("Indicator") :: Frame?
				if ind then ind.Visible = (fname == fName) end
				fbtn.BackgroundColor3 = (fname == fName) and UILib.Colors.Surface4 or UILib.Colors.Surface2
				fbtn.TextColor3 = (fname == fName) and UILib.Colors.TextPrimary or UILib.Colors.TextSecondary
			end
			ShopModal.RefreshGrid()
		end)
	end

	-- Scrolling Cards Area
	local scroll = UILib.CreateScrollFrame(
		modal, "CardScroll",
		UDim2.new(1, -32, 1, -144),
		UDim2.new(0, 16, 0, 136),
		ACCENT
	)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.Name = "GridLayout"
	gridLayout.CellSize = UDim2.new(0, 162, 0, 180)
	gridLayout.CellPadding = UDim2.new(0, 12, 0, 12)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scroll

	ShopModal.RefreshGrid()
end

function ShopModal.RefreshGrid()
	local modal = ShopModal._frame
	if not modal then return end
	local scroll = modal:FindFirstChild("CardScroll") :: ScrollingFrame?
	local filterBar = modal:FindFirstChild("FilterBar") :: Frame?
	if not scroll then return end

	for _, card in ShopModal._cardList do
		card:Destroy()
	end
	table.clear(ShopModal._cardList)

	-- Show/hide subfilters based on category
	if filterBar then
		filterBar.Visible = (ShopModal._currentCategory == "Seeds")
	end

	-- Adjust scroll position based on category
	if ShopModal._currentCategory == "Seeds" then
		scroll.Position = UDim2.new(0, 16, 0, 136)
		scroll.Size = UDim2.new(1, -32, 1, -144)
	else
		scroll.Position = UDim2.new(0, 16, 0, 110)
		scroll.Size = UDim2.new(1, -32, 1, -118)
	end

	local data = ShopModal._data
	local playerStardust = data and data.Stardust or 0

	-- ============================================================
	-- CATEGORY 1: FLORA SEEDS
	-- ============================================================
	if ShopModal._currentCategory == "Seeds" then
		local rebirthLvl = data and data.Rebirth and data.Rebirth.Level or 0
		local unlockedSeeds = SeedData.GetUnlockedSeeds(rebirthLvl)

		for _, seed in unlockedSeeds do
			if ShopModal._activeFilter ~= "All" and seed.Tier ~= ShopModal._activeFilter then
				continue
			end

			local mult = SEED_PRICE_MULTIPLIER[seed.Tier] or 3
			local price = math.floor(seed.BaseValue * mult)
			local canAfford = playerStardust >= price
			local tierColor = UILib.TierColor[seed.Tier] or UILib.Colors.Common

			local card = UILib.CreateCard(scroll, seed.Id, tierColor)
			card.ZIndex = modal.ZIndex + 2

			UILib.CreatePill(card, seed.Tier, tierColor, UDim2.new(0, 8, 0, 8))

			UILib.CreateLabel(
				card, "Name", seed.Name, UILib.Colors.TextPrimary,
				14, UILib.Fonts.Bold,
				UDim2.new(0, 10, 0, 32), UDim2.new(1, -20, 0, 18)
			)

			UILib.CreateLabel(
				card, "Growth", string.format("Growth: %ds", seed.GrowthTime), UILib.Colors.TextMuted,
				11, UILib.Fonts.Body,
				UDim2.new(0, 10, 0, 54), UDim2.new(1, -20, 0, 14)
			)

			UILib.CreateLabel(
				card, "Value", string.format("Base: %s SD", UILib.FormatNumber(seed.BaseValue)), UILib.Colors.TextMuted,
				11, UILib.Fonts.Body,
				UDim2.new(0, 10, 0, 70), UDim2.new(1, -20, 0, 14)
			)

			local mutLabel = UILib.CreateLabel(
				card, "MutChance",
				string.format("Mut. Rate: %.1f%%", (seed.BaseMutationChance or 0) * 100),
				UILib.Colors.PurpleLight,
				10, UILib.Fonts.Medium,
				UDim2.new(0, 10, 0, 90), UDim2.new(1, -20, 0, 14)
			)
			mutLabel.ZIndex = modal.ZIndex + 3

			local sep = Instance.new("Frame")
			sep.Size = UDim2.new(1, -20, 0, 1)
			sep.Position = UDim2.new(0, 10, 0, 112)
			sep.BackgroundColor3 = tierColor
			sep.BackgroundTransparency = 0.7
			sep.BorderSizePixel = 0
			sep.ZIndex = modal.ZIndex + 3
			sep.Parent = card

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

			buyBtn.MouseButton1Click:Connect(function()
				if canAfford then
					SoundController.Play("HarvestCommon")
					local req = ReplicatedStorage:FindFirstChild("GardenRequest") :: RemoteFunction?
					if req then
						req:InvokeServer("BuySeed", seed.Id, 1)
					end
				else
					SoundController.Play("ButtonHover")
					UILib.ShakeElement(buyBtn, Color3.fromRGB(180, 50, 50))
					local notif = script.Parent:FindFirstChild("NotificationUI")
					if notif then
						local nMod = require(notif :: ModuleScript)
						nMod.ShowToast(`❌ Need {price} Stardust to buy {seed.Name}!`, Color3.fromRGB(248, 113, 113), 2.5)
					end
				end
			end)

			table.insert(ShopModal._cardList, card)
		end

	-- ============================================================
	-- CATEGORY 2: GAMEPASSES
	-- ============================================================
	elseif ShopModal._currentCategory == "Gamepasses" then
		for passKey, passData in Config.Monetization.Gamepasses do
			local isOwned = data and data[passData.Flag] == true
			local card = UILib.CreateCard(scroll, passKey, Color3.fromRGB(250, 204, 21))
			card.Size = UDim2.new(0, 162, 0, 180)
			card.ZIndex = modal.ZIndex + 2

			-- Icon / Badge
			UILib.CreatePill(card, passData.Icon or "PASS", Color3.fromRGB(250, 204, 21), UDim2.new(0, 8, 0, 8), UDim2.new(0, 48, 0, 18))

			if isOwned then
				local ownedBadge = UILib.CreatePill(card, "OWNED", Color3.fromRGB(74, 222, 128), UDim2.new(1, -62, 0, 8), UDim2.new(0, 54, 0, 18))
				ownedBadge.BackgroundColor3 = Color3.fromRGB(20, 80, 40)
			end

			-- Title
			UILib.CreateLabel(
				card, "Name", passData.Name or passKey, UILib.Colors.TextPrimary,
				13, UILib.Fonts.Bold,
				UDim2.new(0, 10, 0, 32), UDim2.new(1, -20, 0, 18)
			)

			-- Description
			local desc = UILib.CreateLabel(
				card, "Desc", passData.Description or "", UILib.Colors.TextSecondary,
				10, UILib.Fonts.Body,
				UDim2.new(0, 10, 0, 52), UDim2.new(1, -20, 0, 48)
			)
			desc.TextWrapped = true

			-- Purchase Button
			local buyBtn = Instance.new("TextButton")
			buyBtn.Name = "BuyButton"
			buyBtn.Size = UDim2.new(1, -20, 0, 34)
			buyBtn.Position = UDim2.new(0, 10, 1, -44)
			buyBtn.BackgroundColor3 = isOwned and Color3.fromRGB(28, 22, 38) or Color3.fromRGB(180, 83, 9)
			buyBtn.BorderSizePixel = 0
			buyBtn.Text = isOwned and "OWNED" or string.format("R$ %d", passData.Price)
			buyBtn.TextColor3 = isOwned and Color3.fromRGB(74, 222, 128) or Color3.fromRGB(255, 255, 255)
			buyBtn.TextSize = 13
			buyBtn.Font = UILib.Fonts.Black
			buyBtn.ZIndex = modal.ZIndex + 3
			buyBtn.Parent = card
			UILib.ApplyCorner(buyBtn, 8)

			if not isOwned then
				buyBtn.MouseButton1Click:Connect(function()
					SoundController.Play("ButtonClick")
					if passData.Id and passData.Id > 0 then
						MarketplaceService:PromptGamePassPurchase(player, passData.Id)
					else
						local notif = script.Parent:FindFirstChild("NotificationUI")
						if notif then
							local nModule = require(notif :: ModuleScript)
							nModule.ShowToast("Roblox Gamepass ID pending Studio publication!", Color3.fromRGB(180, 120, 20), 4)
						end
					end
				end)
			end

			table.insert(ShopModal._cardList, card)
		end

	-- ============================================================
	-- CATEGORY 3: BOOSTS & DEVPRODUCTS
	-- ============================================================
	elseif ShopModal._currentCategory == "Boosts" then
		for prodKey, prodData in Config.Monetization.DevProducts do
			local card = UILib.CreateCard(scroll, prodKey, Color3.fromRGB(192, 132, 252))
			card.Size = UDim2.new(0, 162, 0, 180)
			card.ZIndex = modal.ZIndex + 2

			-- Icon / Badge
			UILib.CreatePill(card, prodData.Icon or "BOOST", Color3.fromRGB(192, 132, 252), UDim2.new(0, 8, 0, 8), UDim2.new(0, 54, 0, 18))

			-- Title
			UILib.CreateLabel(
				card, "Name", prodData.Name or prodKey, UILib.Colors.TextPrimary,
				13, UILib.Fonts.Bold,
				UDim2.new(0, 10, 0, 32), UDim2.new(1, -20, 0, 18)
			)

			-- Description
			local desc = UILib.CreateLabel(
				card, "Desc", prodData.Description or "", UILib.Colors.TextSecondary,
				10, UILib.Fonts.Body,
				UDim2.new(0, 10, 0, 52), UDim2.new(1, -20, 0, 48)
			)
			desc.TextWrapped = true

			-- Purchase Button
			local buyBtn = Instance.new("TextButton")
			buyBtn.Name = "BuyButton"
			buyBtn.Size = UDim2.new(1, -20, 0, 34)
			buyBtn.Position = UDim2.new(0, 10, 1, -44)
			buyBtn.BackgroundColor3 = Color3.fromRGB(126, 34, 206)
			buyBtn.BorderSizePixel = 0
			buyBtn.Text = string.format("R$ %d", prodData.Price)
			buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			buyBtn.TextSize = 13
			buyBtn.Font = UILib.Fonts.Black
			buyBtn.ZIndex = modal.ZIndex + 3
			buyBtn.Parent = card
			UILib.ApplyCorner(buyBtn, 8)

			buyBtn.MouseButton1Click:Connect(function()
				SoundController.Play("ButtonClick")
				if prodData.Id and prodData.Id > 0 then
					MarketplaceService:PromptProductPurchase(player, prodData.Id)
				else
					local notif = script.Parent:FindFirstChild("NotificationUI")
					if notif then
						local nModule = require(notif :: ModuleScript)
						nModule.ShowToast("DevProduct ID pending Studio publication!", Color3.fromRGB(180, 120, 20), 4)
					end
				end
			end)

			table.insert(ShopModal._cardList, card)
		end
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
