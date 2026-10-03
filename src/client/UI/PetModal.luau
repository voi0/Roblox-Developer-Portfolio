--!strict
--[[
	PetModal.luau — Companion Sanctuary & Egg Hatching for STARWEAVE
	Allows players to hatch cosmic eggs, equip companions, and inspect bonuses.
	Located in: StarterPlayerScripts.Client.UI.PetModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PetData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetData"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local VFXController = require(script.Parent.Parent.Controllers.VFXController)
local UILib = require(script.Parent.UILib)

local player = Players.LocalPlayer

local PetModal = {}
PetModal._frame = nil :: Frame?
PetModal._data = nil :: any
PetModal._petCards = {} :: { Frame }

local ACCENT = Color3.fromRGB(251, 191, 36) -- Warm Gold

function PetModal.Create(parentGui: ScreenGui)
	local modal = UILib.CreateModalFrame(parentGui, "PetModal", 560, 500, ACCENT)
	PetModal._frame = modal

	-- Header
	UILib.CreateModalHeader(modal, "Celestial Companions", "Equip mythical wisps to amplify mutation luck & harvest speed", ACCENT, function()
		SoundController.Play("ButtonClick")
		PetModal.Close()
	end)

	-- Scroll Grid of Owned Pets
	local scroll = UILib.CreateScrollFrame(
		modal, "PetScroll",
		UDim2.new(1, -32, 1, -140),
		UDim2.new(0, 16, 0, 72),
		ACCENT
	)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 160, 0, 175)
	gridLayout.CellPadding = UDim2.new(0, 12, 0, 12)
	gridLayout.Parent = scroll

	-- Hatch Egg Action Button
	local hatchBtn = Instance.new("TextButton")
	hatchBtn.Name = "HatchButton"
	hatchBtn.Size = UDim2.new(1, -32, 0, 48)
	hatchBtn.Position = UDim2.new(0, 16, 1, -60)
	hatchBtn.BackgroundColor3 = Color3.fromRGB(217, 119, 6)
	hatchBtn.BorderSizePixel = 0
	hatchBtn.Text = "HATCH CELESTIAL EGG (2,500 SD)"
	hatchBtn.TextColor3 = UILib.Colors.TextPrimary
	hatchBtn.TextSize = 15
	hatchBtn.Font = UILib.Fonts.Black
	hatchBtn.ZIndex = modal.ZIndex + 3
	hatchBtn.Parent = modal
	UILib.ApplyCorner(hatchBtn, 12)

	local hatchGrad = Instance.new("UIGradient")
	hatchGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 160)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 130, 10)),
	})
	hatchGrad.Rotation = 90
	hatchGrad.Parent = hatchBtn

	hatchBtn.MouseEnter:Connect(function()
		TweenService:Create(hatchBtn, UILib.Timing.Fast, {
			Size = UDim2.new(1, -28, 0, 50),
		}):Play()
	end)
	hatchBtn.MouseLeave:Connect(function()
		TweenService:Create(hatchBtn, UILib.Timing.Fast, {
			Size = UDim2.new(1, -32, 0, 48),
		}):Play()
	end)

	hatchBtn.MouseButton1Click:Connect(function()
		SoundController.Play("HarvestCommon")
		local petReq = ReplicatedStorage:FindFirstChild("PetRequest") :: RemoteFunction?
		if petReq then
			local result = petReq:InvokeServer("Hatch")
			if result and result.Success then
				SoundController.Play("HarvestRare")
				VFXController.AddCameraTrauma(0.5)
				VFXController.FlashScreen(ACCENT, 0.6, 1.0)
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
		local tierColor = UILib.TierColor[pet.Tier] or ACCENT

		local card = UILib.CreateCard(scroll, `Pet_{idx}`, isEquipped and ACCENT or tierColor)
		card.BackgroundColor3 = isEquipped and Color3.fromRGB(36, 26, 18) or UILib.Colors.Surface2
		card.ZIndex = modal.ZIndex + 2

		if isEquipped then
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = ACCENT
				stroke.Thickness = 2
				stroke.Transparency = 0.1
			end
		end

		-- Tier Pill
		UILib.CreatePill(card, pet.Tier, tierColor, UDim2.new(0, 8, 0, 8), UDim2.new(0, 65, 0, 18))

		-- Equipped status badge if active
		if isEquipped then
			local eqBadge = UILib.CreatePill(card, "ACTIVE", ACCENT, UDim2.new(1, -65, 0, 8), UDim2.new(0, 55, 0, 18))
			eqBadge.BackgroundColor3 = Color3.fromRGB(180, 83, 9)
		end

		-- Name
		UILib.CreateLabel(
			card, "Name", pet.Name, UILib.Colors.TextPrimary,
			13, UILib.Fonts.Bold,
			UDim2.new(0, 10, 0, 36), UDim2.new(1, -20, 0, 18)
		)

		-- Bonuses Section
		local luckText = string.format("+%.0f%% Mut. Luck", (pet.MutationLuckBonus or 0) * 100)
		local speedText = string.format("+%.0f%% Speed", ((pet.HarvestSpeedBonus or 1) - 1) * 100)

		UILib.CreateLabel(
			card, "LuckStat", luckText, UILib.Colors.PurpleLight,
			11, UILib.Fonts.Medium,
			UDim2.new(0, 10, 0, 60), UDim2.new(1, -20, 0, 14)
		)

		UILib.CreateLabel(
			card, "SpeedStat", speedText, UILib.Colors.Cyan,
			11, UILib.Fonts.Medium,
			UDim2.new(0, 10, 0, 78), UDim2.new(1, -20, 0, 14)
		)

		-- Equip/Unequip Button
		local eqBtn = Instance.new("TextButton")
		eqBtn.Name = "EquipButton"
		eqBtn.Size = UDim2.new(1, -20, 0, 30)
		eqBtn.Position = UDim2.new(0, 10, 1, -40)
		eqBtn.BackgroundColor3 = isEquipped and Color3.fromRGB(180, 83, 9) or UILib.Colors.Surface3
		eqBtn.BorderSizePixel = 0
		eqBtn.Text = isEquipped and "EQUIPPED" or "EQUIP"
		eqBtn.TextColor3 = isEquipped and Color3.fromRGB(254, 240, 138) or UILib.Colors.TextPrimary
		eqBtn.TextSize = 12
		eqBtn.Font = UILib.Fonts.Bold
		eqBtn.ZIndex = modal.ZIndex + 3
		eqBtn.Parent = card
		UILib.ApplyCorner(eqBtn, 8)

		eqBtn.MouseEnter:Connect(function()
			TweenService:Create(eqBtn, UILib.Timing.Fast, {
				Size = UDim2.new(1, -16, 0, 32),
			}):Play()
		end)
		eqBtn.MouseLeave:Connect(function()
			TweenService:Create(eqBtn, UILib.Timing.Fast, {
				Size = UDim2.new(1, -20, 0, 30),
			}):Play()
		end)

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
	UILib.OpenModal(PetModal._frame)
	PetModal.Refresh()
end

function PetModal.Close()
	if not PetModal._frame then return end
	UILib.CloseModal(PetModal._frame)
end

function PetModal.Update(data: any)
	PetModal._data = data
	if PetModal._frame and PetModal._frame.Visible then
		PetModal.Refresh()
	end
end

return PetModal
