--!strict
--[[
	UpgradesModal.luau — Tactical Cyber-Glass Upgrades Center for VAULT WARS
	Allows players to upgrade Conveyor Mint Levels, Laser Security Tiers,
	Vault Compound Interest, and execute Vault Liquidation (Prestige).
	Located in: StarterPlayerScripts.Client.UI.UpgradesModal
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local UILib = require(script.Parent:WaitForChild("UILib"))

local player = Players.LocalPlayer
local UpgradesModal = {}

UpgradesModal._frame = nil :: Frame?
UpgradesModal._isOpen = false
UpgradesModal._currentData = nil :: Types.PlayerData?
UpgradesModal._cards = {} :: { [string]: any }
UpgradesModal._passButtons = {} :: { [string]: TextButton }
UpgradesModal._prestigeBtn = nil :: TextButton?
UpgradesModal._prestigeLabel = nil :: TextLabel?

local function formatCurrency(n: number): string
	n = math.floor(n or 0)
	if n >= 1e12 then return string.format("$%.2fT", n / 1e12)
	elseif n >= 1e9 then return string.format("$%.2fB", n / 1e9)
	elseif n >= 1e6 then return string.format("$%.2fM", n / 1e6)
	elseif n >= 1e3 then return string.format("$%.1fK", n / 1e3)
	else return "$" .. tostring(n) end
end

function UpgradesModal.Create(parentGui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "UpgradesModal"
	frame.Size = UDim2.new(0, 560, 0, 460)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Visible = false
	frame.ZIndex = 50
	frame.Parent = parentGui
	UpgradesModal._frame = frame

	local stroke = UILib.ApplyLiquidGlassStyle(frame, Color3.fromRGB(56, 189, 248))

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 52)
	header.BackgroundTransparency = 1
	header.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 1, 0)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "VAULT BASE UPGRADES"
	title.TextColor3 = Color3.fromRGB(250, 204, 21)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = header
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
	UILib.ApplySpringHover(closeBtn, nil, nil)

	closeBtn.MouseButton1Click:Connect(function()
		UpgradesModal.Close()
	end)

	-- Upgrades List Container
	local listContainer = Instance.new("ScrollingFrame")
	listContainer.Name = "ListContainer"
	listContainer.Size = UDim2.new(1, -32, 0, 280)
	listContainer.Position = UDim2.new(0, 16, 0, 58)
	listContainer.BackgroundTransparency = 1
	listContainer.BorderSizePixel = 0
	listContainer.ScrollBarThickness = 4
	listContainer.ScrollBarImageColor3 = Color3.fromRGB(56, 189, 248)
	listContainer.CanvasSize = UDim2.new(0, 0, 0, 550)
	listContainer.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = listContainer

	-- Create 3 Upgrade Cards
	local upgradeDefs = {
		{ Type = "Conveyor", Title = "Mint Conveyor Engine", Icon = "ENG", Color = Color3.fromRGB(56, 189, 248) },
		{ Type = "Laser", Title = "Laser Security Grid", Icon = "SEC", Color = Color3.fromRGB(239, 68, 68) },
		{ Type = "VaultInterest", Title = "Vault Compound Interest", Icon = "ROI", Color = Color3.fromRGB(16, 185, 129) },
	}

	for _, uDef in upgradeDefs do
		local card = Instance.new("Frame")
		card.Name = "Card_" .. uDef.Type
		card.Size = UDim2.new(1, -8, 0, 78)
		card.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
		card.BorderSizePixel = 0
		card.Parent = listContainer
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
		local cStroke = Instance.new("UIStroke", card)
		cStroke.Color = Color3.fromRGB(39, 39, 42)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 260, 0, 22)
		nameLabel.Position = UDim2.new(0, 16, 0, 14)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = uDef.Title
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		local statLabel = Instance.new("TextLabel")
		statLabel.Size = UDim2.new(0, 260, 0, 20)
		statLabel.Position = UDim2.new(0, 16, 0, 42)
		statLabel.BackgroundTransparency = 1
		statLabel.Text = "Level 1"
		statLabel.TextColor3 = Color3.fromRGB(161, 161, 170)
		statLabel.TextSize = 12
		statLabel.Font = Enum.Font.GothamMedium
		statLabel.TextXAlignment = Enum.TextXAlignment.Left
		statLabel.Parent = card

		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyButton"
		buyBtn.Size = UDim2.new(0, 140, 0, 44)
		buyBtn.Position = UDim2.new(1, -154, 0.5, 0)
		buyBtn.AnchorPoint = Vector2.new(0, 0.5)
		buyBtn.BackgroundColor3 = uDef.Color
		buyBtn.Text = "UPGRADE\n$50"
		buyBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
		buyBtn.TextSize = 12
		buyBtn.Font = Enum.Font.GothamBlack
		buyBtn.Parent = card
		Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 10)

		buyBtn.MouseButton1Click:Connect(function()
			UpgradesModal.OnUpgradeClick(uDef.Type)
		end)

		UpgradesModal._cards[uDef.Type] = {
			StatLabel = statLabel,
			BuyButton = buyBtn,
			Def = uDef,
		}
	end

	-- ── VIP GAMEPASS PERKS SECTION ──
	local gamepassDefs = {
		{
			Key = "AutoDrone",
			Title = "Auto-Drone & Raid Shield",
			Desc = "Auto-deposits conveyor loot + 50% raid shield",
			Price = "799 R$",
			Id = Config.Monetization.Gamepasses.AutoDroneAndShield.Id,
			Color = Color3.fromRGB(245, 158, 11),
		},
		{
			Key = "Titanium",
			Title = "Titanium Laser Defense",
			Desc = "Max Tier 4 lasers (120 DMG + 45 knockback)",
			Price = "499 R$",
			Id = Config.Monetization.Gamepasses.TitaniumLasers.Id,
			Color = Color3.fromRGB(56, 189, 248),
		},
		{
			Key = "DoubleCapacity",
			Title = "Double Stash Capacity",
			Desc = "Expands conveyor belt capacity from 6 to 12",
			Price = "199 R$",
			Id = Config.Monetization.Gamepasses.DoubleCapacity.Id,
			Color = Color3.fromRGB(16, 185, 129),
		},
	}

	for _, gpDef in gamepassDefs do
		local card = Instance.new("Frame")
		card.Name = "Card_GP_" .. gpDef.Key
		card.Size = UDim2.new(1, -8, 0, 78)
		card.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
		card.BorderSizePixel = 0
		card.Parent = listContainer
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
		local cStroke = Instance.new("UIStroke", card)
		cStroke.Color = Color3.fromRGB(39, 39, 42)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 260, 0, 22)
		nameLabel.Position = UDim2.new(0, 16, 0, 14)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = gpDef.Title
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 13
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0, 260, 0, 20)
		descLabel.Position = UDim2.new(0, 16, 0, 42)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = gpDef.Desc
		descLabel.TextColor3 = Color3.fromRGB(161, 161, 170)
		descLabel.TextSize = 11
		descLabel.Font = Enum.Font.GothamMedium
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Parent = card

		local passBtn = Instance.new("TextButton")
		passBtn.Name = "BuyButton"
		passBtn.Size = UDim2.new(0, 140, 0, 44)
		passBtn.Position = UDim2.new(1, -154, 0.5, 0)
		passBtn.AnchorPoint = Vector2.new(0, 0.5)
		passBtn.BackgroundColor3 = gpDef.Color
		passBtn.Text = gpDef.Price
		passBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
		passBtn.TextSize = 13
		passBtn.Font = Enum.Font.GothamBlack
		passBtn.Parent = card
		Instance.new("UICorner", passBtn).CornerRadius = UDim.new(0, 10)

		passBtn.MouseButton1Click:Connect(function()
			if gpDef.Id and gpDef.Id > 0 then
				MarketplaceService:PromptGamePassPurchase(player, gpDef.Id)
			else
				passBtn.Text = "ACTIVE!"
				task.delay(1.5, function()
					if passBtn and passBtn.Parent then
						passBtn.Text = gpDef.Price
					end
				end)
			end
		end)

		UpgradesModal._passButtons[gpDef.Key] = passBtn
	end

	-- ── PRESTIGE / LIQUIDATION BOTTOM SECTION ──
	local prestigeCard = Instance.new("Frame")
	prestigeCard.Name = "PrestigeCard"
	prestigeCard.Size = UDim2.new(1, -32, 0, 90)
	prestigeCard.Position = UDim2.new(0, 16, 1, -104)
	prestigeCard.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	prestigeCard.BorderSizePixel = 0
	prestigeCard.Parent = frame
	Instance.new("UICorner", prestigeCard).CornerRadius = UDim.new(0, 12)
	local pStroke = Instance.new("UIStroke", prestigeCard)
	pStroke.Color = Color3.fromRGB(234, 179, 8)
	pStroke.Thickness = 1.5

	local pLabel = Instance.new("TextLabel")
	pLabel.Name = "PrestigeStatus"
	pLabel.Size = UDim2.new(0, 320, 1, 0)
	pLabel.Position = UDim2.new(0, 16, 0, 0)
	pLabel.BackgroundTransparency = 1
	pLabel.Text = "✦ VAULT LIQUIDATION (PRESTIGE)\nRequires $10,000,000 Banked Net Worth"
	pLabel.TextColor3 = Color3.fromRGB(244, 244, 245)
	pLabel.TextSize = 12
	pLabel.Font = Enum.Font.GothamMedium
	pLabel.TextXAlignment = Enum.TextXAlignment.Left
	pLabel.Parent = prestigeCard
	UpgradesModal._prestigeLabel = pLabel

	local pBtn = Instance.new("TextButton")
	pBtn.Name = "LiquidateButton"
	pBtn.Size = UDim2.new(0, 140, 0, 50)
	pBtn.Position = UDim2.new(1, -154, 0.5, 0)
	pBtn.AnchorPoint = Vector2.new(0, 0.5)
	pBtn.BackgroundColor3 = Color3.fromRGB(75, 85, 99)
	pBtn.Text = "LOCKED\n($10M Needed)"
	pBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	pBtn.TextSize = 11
	pBtn.Font = Enum.Font.GothamBold
	pBtn.Parent = prestigeCard
	Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 10)
	UpgradesModal._prestigeBtn = pBtn

	pBtn.MouseButton1Click:Connect(function()
		local rf = ReplicatedStorage:FindFirstChild("PrestigeRequest") :: RemoteFunction?
		if rf then
			local success, tokens = rf:InvokeServer()
			if success then
				UpgradesModal.Close()
			end
		end
	end)

	print("  [UpgradesModal] Tactical Upgrades Center created ✓")
end

function UpgradesModal.OnUpgradeClick(upgradeType: string)
	local rf = ReplicatedStorage:FindFirstChild("UpgradeRequest") :: RemoteFunction?
	if not rf then return end

	local success, msg = rf:InvokeServer(upgradeType)
	if not success and msg then
		warn(`[Upgrades] Upgrade failed: {msg}`)
	end
end

function UpgradesModal.Update(data: Types.PlayerData)
	if not data then return end
	UpgradesModal._currentData = data

	-- 1. Conveyor Card
	local cCard = UpgradesModal._cards["Conveyor"]
	if cCard then
		local curIncome = Config.Economy.GetConveyorIncome(data.ConveyorLevel, data.PrestigeTokens)
		local nextCost = Config.Economy.GetConveyorCost(data.ConveyorLevel + 1)
		cCard.StatLabel.Text = `Level {data.ConveyorLevel} • Generating +{formatCurrency(curIncome)}/sec`
		cCard.BuyButton.Text = `UPGRADE\n{formatCurrency(nextCost)}`
	end

	-- 2. Laser Card
	local lCard = UpgradesModal._cards["Laser"]
	if lCard then
		local tier = data.LaserTier
		local nextCost = Config.Economy.GetLaserCost(tier + 1)
		local dmg = Config.Heist.LaserDamageByTier[tier] or 25
		lCard.StatLabel.Text = `Tier {tier} • {dmg} Damage Tripwires`
		lCard.BuyButton.Text = (tier >= Config.Economy.MaxLaserTier) and "MAX TIER" or `UPGRADE\n{formatCurrency(nextCost)}`
	end

	-- 3. Interest Card
	local iCard = UpgradesModal._cards["VaultInterest"]
	if iCard then
		local tier = data.VaultInterestTier
		local nextCost = Config.Economy.GetInterestCost(tier + 1)
		local percent = tier * 2
		iCard.StatLabel.Text = `Tier {tier} • +{percent}% Hourly AFK Compound`
		iCard.BuyButton.Text = (tier >= Config.Economy.MaxInterestTier) and "MAX TIER" or `UPGRADE\n{formatCurrency(nextCost)}`
	end

	-- 4. Prestige Card
	local pBtn = UpgradesModal._prestigeBtn
	local pLabel = UpgradesModal._prestigeLabel
	if pBtn and pLabel then
		if data.BankedCash >= Config.Economy.PrestigeMinBanked then
			local tokens = math.floor(Config.Economy.PrestigeTokenBase * ((data.BankedCash / Config.Economy.PrestigeMinBanked) ^ Config.Economy.PrestigeExponent))
			pLabel.Text = `✦ LIQUIDATE VAULT (REBIRTH)\nGrants +{tokens} Prestige Tokens (+{tokens * 25}% Permanent Multiplier)`
			pBtn.BackgroundColor3 = Color3.fromRGB(234, 179, 8)
			pBtn.Text = `LIQUIDATE!\n(+{tokens} Tokens)`
			pBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
		else
			pLabel.Text = `✦ VAULT LIQUIDATION (PRESTIGE)\nRequires $10,000,000 Banked Net Worth ({formatCurrency(data.BankedCash)} / $10M)`
			pBtn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
			pBtn.Text = "LOCKED\n($10M Needed)"
			pBtn.TextColor3 = Color3.fromRGB(156, 163, 175)
		end
	end

	-- 5. Gamepass Cards
	if UpgradesModal._passButtons["AutoDrone"] and data.HasAutoCollector then
		UpgradesModal._passButtons["AutoDrone"].Text = "OWNED ✓"
		UpgradesModal._passButtons["AutoDrone"].BackgroundColor3 = Color3.fromRGB(16, 185, 129)
		UpgradesModal._passButtons["AutoDrone"].TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	if UpgradesModal._passButtons["Titanium"] and data.HasTitaniumLasers then
		UpgradesModal._passButtons["Titanium"].Text = "OWNED ✓"
		UpgradesModal._passButtons["Titanium"].BackgroundColor3 = Color3.fromRGB(16, 185, 129)
		UpgradesModal._passButtons["Titanium"].TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	if UpgradesModal._passButtons["DoubleCapacity"] and data.HasDoubleCapacity then
		UpgradesModal._passButtons["DoubleCapacity"].Text = "OWNED ✓"
		UpgradesModal._passButtons["DoubleCapacity"].BackgroundColor3 = Color3.fromRGB(16, 185, 129)
		UpgradesModal._passButtons["DoubleCapacity"].TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

function UpgradesModal.Open()
	if not UpgradesModal._frame then return end
	if UpgradesModal._isOpen then return end
	UpgradesModal._isOpen = true
	UILib.OpenModal(UpgradesModal._frame)
end

function UpgradesModal.Close()
	if not UpgradesModal._frame then return end
	if not UpgradesModal._isOpen then return end
	UpgradesModal._isOpen = false
	UILib.CloseModal(UpgradesModal._frame)
end

function UpgradesModal.Toggle()
	if UpgradesModal._isOpen then
		UpgradesModal.Close()
	else
		UpgradesModal.Open()
	end
end

function UpgradesModal.IsOpen(): boolean
	return UpgradesModal._isOpen
end

return UpgradesModal
