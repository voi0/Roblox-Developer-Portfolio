--!strict
--[[
	PetModal.luau — Companion Sanctuary & Egg Hatching for STARWEAVE
	Allows players to hatch cosmic eggs, equip companions, and inspect bonuses.
	Located in: StarterPlayerScripts.Client.UI.PetModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PetData = require(ReplicatedStorage.Shared.PetData)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local VFXController = require(script.Parent.Parent.Controllers.VFXController)

local player = Players.LocalPlayer

local PetModal = {}
PetModal._frame = nil :: Frame?
PetModal._data = nil :: any
PetModal._petCards = {} :: { Frame }

local TIER_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(148, 163, 184),
	Uncommon = Color3.fromRGB(74, 222, 128),
	Rare = Color3.fromRGB(56, 189, 248),
	Epic = Color3.fromRGB(192, 132, 252),
	Legendary = Color3.fromRGB(251, 191, 36),
	Celestial = Color3.fromRGB(244, 114, 182),
}

function PetModal.Create(parentGui: ScreenGui)
	local modal = Instance.new("Frame")
	modal.Name = "PetModal"
	modal.Size = UDim2.new(0, 540, 0, 480)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.BackgroundColor3 = Color3.fromRGB(15, 11, 28)
	modal.BackgroundTransparency = 0.1
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = parentGui
	PetModal._frame = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(251, 191, 36)
	stroke.Thickness = 2
	stroke.Parent = modal

	-- Header
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
	title.Text = "🐾 CELESTIAL COMPANIONS"
	title.TextColor3 = Color3.fromRGB(251, 191, 36)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(0.7, 0, 0, 16)
	subtitle.Position = UDim2.new(0, 20, 0, 38)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Equip mythical wisps to amplify mutation luck & speed"
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
		PetModal.Close()
	end)

	-- Scroll Grid of Owned Pets
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "PetScroll"
	scroll.Size = UDim2.new(1, -40, 1, -140)
	scroll.Position = UDim2.new(0, 20, 0, 68)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(251, 191, 36)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 300)
	scroll.Parent = modal

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 150, 0, 160)
	gridLayout.CellPadding = UDim2.new(0, 12, 0, 12)
	gridLayout.Parent = scroll

	-- Hatch Egg Action Button
	local hatchBtn = Instance.new("TextButton")
	hatchBtn.Name = "HatchButton"
	hatchBtn.Size = UDim2.new(1, -40, 0, 52)
	hatchBtn.Position = UDim2.new(0, 20, 1, -64)
	hatchBtn.BackgroundColor3 = Color3.fromRGB(217, 119, 6)
	hatchBtn.BorderSizePixel = 0
	hatchBtn.Text = "HATCH CELESTIAL EGG (⭐ 2,500)"
	hatchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	hatchBtn.TextScaled = true
	hatchBtn.Font = Enum.Font.GothamBold
	hatchBtn.Parent = modal

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = hatchBtn

	hatchBtn.MouseButton1Click:Connect(function()
		SoundController.Play("HarvestCommon")
		local petReq = ReplicatedStorage:FindFirstChild("PetRequest") :: RemoteFunction?
		if petReq then
			local result = petReq:InvokeServer("Hatch")
			if result and result.Success then
				SoundController.Play("HarvestRare")
				VFXController.AddCameraTrauma(0.5)
				VFXController.FlashScreen(Color3.fromRGB(251, 191, 36), 0.6, 1.0)
				PetModal.Refresh()
			else
				SoundController.Play("ButtonHover")
			end
		end
	end)

	PetModal.Refresh()
end

function PetModal.Refresh()
	local modal = PetModal._frame
	if not modal then return end
	local scroll = modal:FindFirstChild("PetScroll") :: ScrollingFrame?
	if not scroll then return end

	for _, card in PetModal._petCards do
		card:Destroy()
	end
	table.clear(PetModal._petCards)

	local pets = PetModal._data and PetModal._data.Pets or {}
	local equippedIdx = PetModal._data and PetModal._data.EquippedPetIndex

	for idx, pet in pets do
		local isEquipped = (equippedIdx == idx)
		local petDef = PetData.GetPet(pet.Id)
		local tierColor = TIER_COLORS[pet.Tier] or Color3.fromRGB(250, 204, 21)

		local card = Instance.new("Frame")
		card.Name = `Pet_{idx}`
		card.BackgroundColor3 = isEquipped and Color3.fromRGB(48, 36, 24) or Color3.fromRGB(24, 18, 42)
		card.BorderSizePixel = 0
		card.Parent = scroll

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 10)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = isEquipped and Color3.fromRGB(251, 191, 36) or tierColor
		cStroke.Thickness = isEquipped and 2 or 1
		cStroke.Parent = card

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.new(1, 0, 0, 36)
		icon.Position = UDim2.new(0, 0, 0, 10)
		icon.BackgroundTransparency = 1
		icon.Text = "🐾"
		icon.TextScaled = true
		icon.Parent = card

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -12, 0, 22)
		nameLabel.Position = UDim2.new(0, 6, 0, 48)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = pet.Name
		nameLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Parent = card

		local bonusLabel = Instance.new("TextLabel")
		bonusLabel.Size = UDim2.new(1, -12, 0, 32)
		bonusLabel.Position = UDim2.new(0, 6, 0, 72)
		bonusLabel.BackgroundTransparency = 1
		bonusLabel.Text = string.format("+%.0f%% Luck\n%.0f%% Speed", (pet.MutationLuckBonus or 0) * 100, ((pet.HarvestSpeedBonus or 1) - 1) * 100)
		bonusLabel.TextColor3 = tierColor
		bonusLabel.TextScaled = true
		bonusLabel.Font = Enum.Font.Gotham
		bonusLabel.Parent = card

		local eqBtn = Instance.new("TextButton")
		eqBtn.Name = "EquipButton"
		eqBtn.Size = UDim2.new(1, -16, 0, 28)
		eqBtn.Position = UDim2.new(0, 8, 1, -36)
		eqBtn.BackgroundColor3 = isEquipped and Color3.fromRGB(180, 83, 9) or Color3.fromRGB(39, 39, 42)
		eqBtn.BorderSizePixel = 0
		eqBtn.Text = isEquipped and "EQUIPPED" or "EQUIP"
		eqBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		eqBtn.TextScaled = true
		eqBtn.Font = Enum.Font.GothamBold
		eqBtn.Parent = card

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 6)
		bCorner.Parent = eqBtn

		eqBtn.MouseButton1Click:Connect(function()
			SoundController.Play("ButtonClick")
			local petReq = ReplicatedStorage:FindFirstChild("PetRequest") :: RemoteFunction?
			if petReq then
				if isEquipped then
					petReq:InvokeServer("Unequip")
				else
					petReq:InvokeServer("Equip", idx)
				end
			end
		end)

		table.insert(PetModal._petCards, card)
	end
end

function PetModal.Open()
	if not PetModal._frame then return end
	PetModal._frame.Visible = true
	PetModal._frame.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(PetModal._frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
	PetModal.Refresh()
end

function PetModal.Close()
	if not PetModal._frame then return end
	local tween = TweenService:Create(PetModal._frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0.5, 0.55),
	})
	tween:Play()
	tween.Completed:Once(function()
		PetModal._frame.Visible = false
	end)
end

function PetModal.Update(data: any)
	PetModal._data = data
	if PetModal._frame and PetModal._frame.Visible then
		PetModal.Refresh()
	end
end

return PetModal
