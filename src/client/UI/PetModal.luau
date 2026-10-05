--!strict
--[[
	PetModal.luau — Companion Sanctuary & Cinematic Gacha Hatching for STARWEAVE
	Features:
	  - Sleek companion roster with glowing rarity borders and equipped status
	  - One-click companion equipping/unequipping with live multiplier updates
	  - AAA Cinematic Gacha Hatch Sequence: Wobble, crackle, explosion, and grand reveal!
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
PetModal._gui = nil :: ScreenGui?
PetModal._frame = nil :: Frame?
PetModal._data = nil :: any
PetModal._petCards = {} :: { Frame }

local ACCENT = Color3.fromRGB(251, 191, 36)

function PetModal.Create(parentGui: ScreenGui)
	PetModal._gui = parentGui

	local modal = UILib.CreateModalFrame(parentGui, "PetModal", 540, 440, ACCENT)
	PetModal._frame = modal

	-- Header
	UILib.CreateModalHeader(modal, "Celestial Companions", "Hatch cosmic eggs & equip mythical spirit companions", ACCENT, function()
		SoundController.Play("ButtonClick")
		PetModal.Close()
	end)

	-- Scroll Grid of Owned Pets
	local scroll = UILib.CreateScrollFrame(
		modal, "PetScroll",
		UDim2.new(1, -32, 1, -116),
		UDim2.new(0, 16, 0, 56),
		ACCENT
	)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 156, 0, 140)
	gridLayout.CellPadding = UDim2.new(0, 12, 0, 12)
	gridLayout.Parent = scroll

	-- Hatch Egg Action Button (Bottom)
	local hatchBtn = Instance.new("TextButton")
	hatchBtn.Name = "HatchButton"
	hatchBtn.Size = UDim2.new(1, -32, 0, 44)
	hatchBtn.Position = UDim2.new(0, 16, 1, -52)
	hatchBtn.BackgroundColor3 = Color3.fromRGB(217, 119, 6)
	hatchBtn.BorderSizePixel = 0
	hatchBtn.Text = "✦ HATCH CELESTIAL EGG (2,500 STARDUST) ✦"
	hatchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	hatchBtn.TextSize = 12
	hatchBtn.Font = UILib.Fonts.Bold
	hatchBtn.ZIndex = modal.ZIndex + 3
	hatchBtn.Parent = modal
	UILib.ApplyCorner(hatchBtn, 10)

	local hatchGrad = Instance.new("UIGradient")
	hatchGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 90, 10)),
	})
	hatchGrad.Rotation = 90
	hatchGrad.Parent = hatchBtn

	local hatchStroke = Instance.new("UIStroke")
	hatchStroke.Color = Color3.fromRGB(255, 220, 100)
	hatchStroke.Thickness = 1.2
	hatchStroke.Transparency = 0.3
	hatchStroke.Parent = hatchBtn

	hatchBtn.MouseEnter:Connect(function()
		SoundController.Play("ButtonHover")
		TweenService:Create(hatchBtn, UILib.Timing.Fast, {
			Size = UDim2.new(1, -28, 0, 46),
			Position = UDim2.new(0, 14, 1, -53),
		}):Play()
	end)
	hatchBtn.MouseLeave:Connect(function()
		TweenService:Create(hatchBtn, UILib.Timing.Fast, {
			Size = UDim2.new(1, -32, 0, 44),
			Position = UDim2.new(0, 16, 1, -52),
		}):Play()
	end)

	hatchBtn.MouseButton1Click:Connect(function()
		SoundController.Play("ButtonClick")
		local petReq = ReplicatedStorage:FindFirstChild("PetRequest") :: RemoteFunction?
		if petReq then
			local result = petReq:InvokeServer("Hatch")
			if result and result.Success and result.Pet then
				local newPet = result.Pet
				local pets = PetModal._data and PetModal._data.Pets or {}
				local petIndex = #pets

				-- Run Cinematic Gacha Sequence!
				PetModal.PlayCinematicHatch(parentGui, newPet, petIndex, function()
					PetModal.Refresh()
				end)
			else
				SoundController.Play("ButtonHover")
				UILib.ShakeElement(hatchBtn, Color3.fromRGB(180, 50, 50))
				local notif = script.Parent:FindFirstChild("NotificationUI")
				if notif then
					local nModule = require(notif :: ModuleScript)
					nModule.ShowToast(result and result.Message or "Need 2,500 Stardust to awaken a Celestial Egg!", Color3.fromRGB(248, 113, 113), 3.0)
				end
			end
		end
	end)

	PetModal.Refresh()
end

-- ============================================================
-- CINEMATIC GACHA HATCH OVERLAY
-- ============================================================
function PetModal.PlayCinematicHatch(parentGui: ScreenGui, pet: any, petIndex: number, onComplete: () -> ())
	PetModal.Close()

	local overlay = Instance.new("Frame")
	overlay.Name = "CinematicHatchOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(6, 4, 12)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 50
	overlay.Parent = parentGui

	TweenService:Create(overlay, TweenInfo.new(0.4), { BackgroundTransparency = 0.15 }):Play()

	-- Centered Wobbling Egg Frame
	local eggHolder = Instance.new("Frame")
	eggHolder.Name = "EggHolder"
	eggHolder.Size = UDim2.new(0, 160, 0, 210)
	eggHolder.Position = UDim2.fromScale(0.5, 0.5)
	eggHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	eggHolder.BackgroundColor3 = Color3.fromRGB(45, 20, 65)
	eggHolder.BorderSizePixel = 0
	eggHolder.ZIndex = 52
	eggHolder.Parent = overlay
	UILib.ApplyCorner(eggHolder, 80)

	local eggStroke = Instance.new("UIStroke")
	eggStroke.Color = Color3.fromRGB(250, 204, 21)
	eggStroke.Thickness = 2.0
	eggStroke.Transparency = 0.2
	eggStroke.Parent = eggHolder

	local eggGrad = Instance.new("UIGradient")
	eggGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(168, 85, 247)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 14, 48)),
	})
	eggGrad.Rotation = 90
	eggGrad.Parent = eggHolder

	local moonGlyph = Instance.new("TextLabel")
	moonGlyph.Size = UDim2.fromScale(1, 1)
	moonGlyph.BackgroundTransparency = 1
	moonGlyph.Text = "🌙"
	moonGlyph.TextSize = 56
	moonGlyph.ZIndex = 53
	moonGlyph.Parent = eggHolder

	-- Wobble Animation Loop
	task.spawn(function()
		for i = 1, 8 do
			local angle = (i % 2 == 0) and (4 + i * 2) or -(4 + i * 2)
			SoundController.Play("ButtonClick")
			local wobbleTween = TweenService:Create(eggHolder, TweenInfo.new(0.12, Enum.EasingStyle.Sine), {
				Rotation = angle,
				Size = UDim2.new(0, 160 + i * 4, 0, 210 + i * 4),
			})
			wobbleTween:Play()
			wobbleTween.Completed:Wait()
		end

		-- CRACK BURST!
		SoundController.Play("RebirthAscend")
		VFXController.AddCameraTrauma(0.8)
		VFXController.FlashScreen(Color3.fromRGB(255, 235, 170), 0.8, 1.2)

		eggHolder:Destroy()

		-- Grand Reveal Card
		local petDef = PetData.GetPet(pet.Id)
		local petColor = petDef and petDef.Color or ACCENT

		local card = Instance.new("Frame")
		card.Name = "RevealCard"
		card.Size = UDim2.new(0, 420, 0, 320)
		card.Position = UDim2.fromScale(0.5, 0.54)
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.BackgroundColor3 = Color3.fromRGB(16, 12, 28)
		card.BorderSizePixel = 0
		card.ZIndex = 54
		card.Parent = overlay
		UILib.ApplyCorner(card, 16)

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = petColor
		cardStroke.Thickness = 2.0
		cardStroke.Transparency = 0.1
		cardStroke.Parent = card

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -20, 0, 32)
		title.Position = UDim2.new(0, 10, 0, 24)
		title.BackgroundTransparency = 1
		title.Text = `★ {string.upper(pet.Name)} ★`
		title.TextColor3 = petColor
		title.TextSize = 20
		title.Font = UILib.Fonts.Bold
		title.ZIndex = 55
		title.Parent = card

		local tierPill = Instance.new("Frame")
		tierPill.Size = UDim2.new(0, 140, 0, 24)
		tierPill.Position = UDim2.new(0.5, -70, 0, 64)
		tierPill.BackgroundColor3 = petColor
		tierPill.BackgroundTransparency = 0.85
		tierPill.BorderSizePixel = 0
		tierPill.ZIndex = 55
		tierPill.Parent = card
		UILib.ApplyPill(tierPill)
		UILib.ApplyStroke(tierPill, petColor, 1.2, 0.4)

		local tierText = Instance.new("TextLabel")
		tierText.Size = UDim2.fromScale(1, 1)
		tierText.BackgroundTransparency = 1
		tierText.Text = `{string.upper(pet.Tier)} COMPANION`
		tierText.TextColor3 = petColor
		tierText.TextSize = 10
		tierText.Font = UILib.Fonts.Bold
		tierText.ZIndex = 56
		tierText.Parent = tierPill

		local bonus1 = Instance.new("TextLabel")
		bonus1.Size = UDim2.new(1, -40, 0, 20)
		bonus1.Position = UDim2.new(0, 20, 0, 110)
		bonus1.BackgroundTransparency = 1
		local luckPct = math.floor((pet.MutationLuckBonus or 0.05) * 100)
		bonus1.Text = `✦ +{luckPct}% Cosmic Mutation Luck`
		bonus1.TextColor3 = Color3.fromRGB(250, 204, 21)
		bonus1.TextSize = 13
		bonus1.Font = UILib.Fonts.Bold
		bonus1.ZIndex = 55
		bonus1.Parent = card

		local bonus2 = Instance.new("TextLabel")
		bonus2.Size = UDim2.new(1, -40, 0, 20)
		bonus2.Position = UDim2.new(0, 20, 0, 136)
		bonus2.BackgroundTransparency = 1
		local spdPct = math.floor(((pet.HarvestSpeedBonus or 1.1) - 1.0) * 100)
		bonus2.Text = `✦ +{spdPct}% Crop Growth Acceleration`
		bonus2.TextColor3 = Color3.fromRGB(56, 189, 248)
		bonus2.TextSize = 13
		bonus2.Font = UILib.Fonts.Bold
		bonus2.ZIndex = 55
		bonus2.Parent = card

		-- Equip Button
		local equipBtn = Instance.new("TextButton")
		equipBtn.Size = UDim2.new(1, -48, 0, 42)
		equipBtn.Position = UDim2.new(0, 24, 1, -64)
		equipBtn.BackgroundColor3 = petColor
		equipBtn.BorderSizePixel = 0
		equipBtn.Text = "EQUIP COMPANION"
		equipBtn.TextColor3 = Color3.fromRGB(16, 12, 28)
		equipBtn.TextSize = 13
		equipBtn.Font = UILib.Fonts.Bold
		equipBtn.ZIndex = 55
		equipBtn.Parent = card
		UILib.ApplyCorner(equipBtn, 10)

		equipBtn.MouseButton1Click:Connect(function()
			SoundController.Play("ButtonClick")
			local petReq = ReplicatedStorage:FindFirstChild("PetRequest") :: RemoteFunction?
			if petReq then
				petReq:InvokeServer("Equip", petIndex)
			end
			overlay:Destroy()
			PetModal.Open()
			onComplete()
		end)

		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
	end)
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
		local tierColor = petDef and petDef.Color or ACCENT

		local card = Instance.new("Frame")
		card.Name = `Pet_{idx}`
		card.BackgroundColor3 = Color3.fromRGB(20, 16, 32)
		card.BorderSizePixel = 0
		card.ZIndex = modal.ZIndex + 2
		card.Parent = scroll
		UILib.ApplyCorner(card, 10)

		local stroke = Instance.new("UIStroke")
		stroke.Color = isEquipped and Color3.fromRGB(74, 222, 128) or tierColor
		stroke.Thickness = isEquipped and 1.6 or 1.0
		stroke.Transparency = isEquipped and 0.1 or 0.5
		stroke.Parent = card

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -12, 0, 18)
		nameLabel.Position = UDim2.new(0, 6, 0, 10)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = pet.Name
		nameLabel.TextColor3 = tierColor
		nameLabel.TextSize = 11
		nameLabel.Font = UILib.Fonts.Bold
		nameLabel.ZIndex = modal.ZIndex + 3
		nameLabel.Parent = card

		local luckPct = math.floor((pet.MutationLuckBonus or 0.05) * 100)
		local spdPct = math.floor(((pet.HarvestSpeedBonus or 1.1) - 1.0) * 100)

		local stats = Instance.new("TextLabel")
		stats.Size = UDim2.new(1, -12, 0, 32)
		stats.Position = UDim2.new(0, 6, 0, 34)
		stats.BackgroundTransparency = 1
		stats.Text = `+{luckPct}% Luck\n+{spdPct}% Speed`
		stats.TextColor3 = Color3.fromRGB(220, 210, 240)
		stats.TextSize = 10
		stats.Font = UILib.Fonts.Medium
		stats.ZIndex = modal.ZIndex + 3
		stats.Parent = card

		local actionBtn = Instance.new("TextButton")
		actionBtn.Size = UDim2.new(1, -16, 0, 28)
		actionBtn.Position = UDim2.new(0, 8, 1, -36)
		actionBtn.BackgroundColor3 = isEquipped and Color3.fromRGB(28, 48, 36) or Color3.fromRGB(36, 28, 56)
		actionBtn.BorderSizePixel = 0
		actionBtn.Text = isEquipped and "EQUIPPED" or "EQUIP"
		actionBtn.TextColor3 = isEquipped and Color3.fromRGB(74, 222, 128) or tierColor
		actionBtn.TextSize = 10
		actionBtn.Font = UILib.Fonts.Bold
		actionBtn.ZIndex = modal.ZIndex + 3
		actionBtn.Parent = card
		UILib.ApplyCorner(actionBtn, 6)

		actionBtn.MouseButton1Click:Connect(function()
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
	PetModal.Refresh()
	UILib.OpenModal(PetModal._frame)
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
