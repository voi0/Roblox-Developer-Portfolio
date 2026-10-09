--!strict
--[[
	LockerModal.luau — Tactical Ability & Loadout Locker for ESCAPE THE PACK
	Allows players to purchase, unlock, and equip abilities using Gems.
	Located in: StarterPlayerScripts.Client.UI.LockerModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AbilityData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AbilityData"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local player = Players.LocalPlayer
local LockerModal = {}

LockerModal._frame = nil :: Frame?
LockerModal._cardList = nil :: ScrollingFrame?
LockerModal._isOpen = false
LockerModal._currentData = nil :: any
LockerModal._cards = {} :: { [string]: { Button: TextButton, StatusLabel: TextLabel } }

function LockerModal.Create(parentGui: ScreenGui)
	local modalFrame = Instance.new("Frame")
	modalFrame.Name = "LockerModal"
	modalFrame.Size = UDim2.new(0, 560, 0, 420)
	modalFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	modalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	modalFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	modalFrame.BorderSizePixel = 0
	modalFrame.Visible = false
	modalFrame.ZIndex = 50
	modalFrame.Parent = parentGui
	LockerModal._frame = modalFrame

	Instance.new("UICorner", modalFrame).CornerRadius = UDim.new(0, 16)
	local stroke = Instance.new("UIStroke", modalFrame)
	stroke.Color = Color3.fromRGB(56, 189, 248)
	stroke.Thickness = 2

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 52)
	header.BackgroundTransparency = 1
	header.Parent = modalFrame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 1, 0)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "⚡ TACTICAL LOADOUT & ABILITIES"
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

	closeBtn.MouseButton1Click:Connect(function()
		LockerModal.Close()
	end)

	-- Abilities Scroll List
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "AbilitiesScroll"
	scroll.Size = UDim2.new(1, -32, 1, -72)
	scroll.Position = UDim2.new(0, 16, 0, 56)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(56, 189, 248)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 480)
	scroll.Parent = modalFrame
	LockerModal._cardList = scroll

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroll

	-- Populate Cards
	local abilityOrder = { "Cloak", "PocketDoor", "Decoy", "Adrenaline", "RufusLeash" }
	for _, id in abilityOrder do
		local def = AbilityData[id]
		if def then
			local card = Instance.new("Frame")
			card.Name = "Card_" .. id
			card.Size = UDim2.new(1, -8, 0, 84)
			card.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
			card.BorderSizePixel = 0
			card.Parent = scroll
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
			local cStroke = Instance.new("UIStroke", card)
			cStroke.Color = Color3.fromRGB(39, 39, 42)
			cStroke.Thickness = 1

			-- Icon
			local icon = Instance.new("ImageLabel")
			icon.Size = UDim2.new(0, 54, 0, 54)
			icon.Position = UDim2.new(0, 14, 0.5, 0)
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.BackgroundTransparency = 1
			icon.Image = def.Icon
			icon.Parent = card

			-- Info
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0, 260, 0, 20)
			nameLabel.Position = UDim2.new(0, 80, 0, 12)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = def.Name
			nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			nameLabel.TextSize = 14
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = card

			local roleTag = Instance.new("TextLabel")
			roleTag.Size = UDim2.new(0, 80, 0, 16)
			roleTag.Position = UDim2.new(0, 80 + nameLabel.TextBounds.X + 8, 0, 14)
			roleTag.BackgroundTransparency = 1
			roleTag.Text = `[{string.upper(def.Role)}]`
			roleTag.TextColor3 = (def.Role == "Chaser") and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(56, 189, 248)
			roleTag.TextSize = 10
			roleTag.Font = Enum.Font.GothamBold
			roleTag.TextXAlignment = Enum.TextXAlignment.Left
			roleTag.Parent = card

			local descLabel = Instance.new("TextLabel")
			descLabel.Size = UDim2.new(0, 280, 0, 32)
			descLabel.Position = UDim2.new(0, 80, 0, 36)
			descLabel.BackgroundTransparency = 1
			descLabel.Text = def.Description
			descLabel.TextColor3 = Color3.fromRGB(161, 161, 170)
			descLabel.TextSize = 11
			descLabel.Font = Enum.Font.GothamMedium
			descLabel.TextWrapped = true
			descLabel.TextXAlignment = Enum.TextXAlignment.Left
			descLabel.Parent = card

			-- Action Button (Buy / Equip / Equipped)
			local actionBtn = Instance.new("TextButton")
			actionBtn.Name = "ActionBtn"
			actionBtn.Size = UDim2.new(0, 110, 0, 42)
			actionBtn.Position = UDim2.new(1, -122, 0.5, 0)
			actionBtn.AnchorPoint = Vector2.new(0, 0.5)
			actionBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
			actionBtn.Text = `💎 {def.GemCost}`
			actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			actionBtn.TextSize = 12
			actionBtn.Font = Enum.Font.GothamBold
			actionBtn.Parent = card
			Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 10)

			actionBtn.MouseButton1Click:Connect(function()
				LockerModal.OnAction(id)
			end)

			LockerModal._cards[id] = { Button = actionBtn, StatusLabel = nameLabel }
		end
	end

	print("  [LockerModal] Tactical Locker Modal created ✓")
end

function LockerModal.OnAction(abilityId: string)
	local shopRF = ReplicatedStorage:FindFirstChild("ShopRequest") :: RemoteFunction?
	if not shopRF then return end

	local data = LockerModal._currentData
	local isUnlocked = data and data.UnlockedAbilities and data.UnlockedAbilities[abilityId]

	if isUnlocked then
		-- Equip
		local success, msg = shopRF:InvokeServer("EquipAbility", abilityId)
		if success and data then
			data.EquippedAbility = abilityId
			LockerModal.Update(data)
		end
	else
		-- Buy
		local success, msg = shopRF:InvokeServer("BuyAbility", abilityId)
		if success and data then
			if not data.UnlockedAbilities then data.UnlockedAbilities = {} end
			data.UnlockedAbilities[abilityId] = true
			data.EquippedAbility = abilityId
			LockerModal.Update(data)
		end
	end
end

function LockerModal.Update(data: any)
	if not data then return end
	LockerModal._currentData = data

	for id, cardInfo in LockerModal._cards do
		local isUnlocked = data.UnlockedAbilities and data.UnlockedAbilities[id]
		local isEquipped = data.EquippedAbility == id
		local def = AbilityData[id]

		if isEquipped then
			cardInfo.Button.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
			cardInfo.Button.Text = "✓ EQUIPPED"
			cardInfo.Button.TextColor3 = Color3.fromRGB(0, 0, 0)
		elseif isUnlocked then
			cardInfo.Button.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
			cardInfo.Button.Text = "EQUIP"
			cardInfo.Button.TextColor3 = Color3.fromRGB(0, 0, 0)
		else
			cardInfo.Button.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
			cardInfo.Button.Text = `💎 {def and def.GemCost or 0}`
			cardInfo.Button.TextColor3 = Color3.fromRGB(250, 204, 21)
		end
	end
end

function LockerModal.Open()
	if not LockerModal._frame then return end
	LockerModal._isOpen = true
	LockerModal._frame.Visible = true
	LockerModal._frame.Size = UDim2.new(0, 500, 0, 380)

	TweenService:Create(LockerModal._frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 560, 0, 420)
	}):Play()
end

function LockerModal.Close()
	if not LockerModal._frame then return end
	LockerModal._isOpen = false

	local tween = TweenService:Create(LockerModal._frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 480, 0, 360)
	})
	tween:Play()
	tween.Completed:Connect(function()
		if not LockerModal._isOpen and LockerModal._frame then
			LockerModal._frame.Visible = false
		end
	end)
end

function LockerModal.Toggle()
	if LockerModal._isOpen then
		LockerModal.Close()
	else
		LockerModal.Open()
	end
end

return LockerModal
