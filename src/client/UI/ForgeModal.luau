--!strict
--[[
	ForgeModal.luau — Seed & Mutation Transmutation Altar for STARWEAVE
	Interactive crafting interface where players select 3 identical seeds
	to transmute into a guaranteed higher-tier ascended seed.
	Located in: StarterPlayerScripts.Client.UI.ForgeModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SeedData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeedData"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local VFXController = require(script.Parent.Parent.Controllers.VFXController)
local UILib = require(script.Parent.UILib)

local player = Players.LocalPlayer

local ForgeModal = {}
ForgeModal._frame = nil :: Frame?
ForgeModal._data = nil :: any
ForgeModal._selectedSeedId = nil :: string?
ForgeModal._seedButtons = {} :: { TextButton }
ForgeModal._pulseConnection = nil :: RBXScriptConnection?

-- ============================================================
-- CONSTANTS
-- ============================================================

local MODAL_WIDTH: number = 540
local MODAL_HEIGHT: number = 520
local HEADER_HEIGHT: number = 62
local ALTAR_HEIGHT: number = 168
local ALTAR_TOP: number = 74
local SEED_LIST_TOP: number = 256
local SEED_LIST_LABEL_TOP: number = 250
local SEED_CARD_WIDTH: number = 126
local SEED_CARD_HEIGHT: number = 100
local FORGE_BTN_HEIGHT: number = 52

local ACCENT_COLOR: Color3 = UILib.Colors.Purple
local ACCENT_LIGHT: Color3 = UILib.Colors.PurpleLight
local ACCENT_DIM: Color3 = UILib.Colors.PurpleDim

local TIER_UPGRADE_MAP: { [string]: string } = {
	Common = "Uncommon",
	Uncommon = "Rare",
	Rare = "Epic",
	Epic = "Legendary",
	Legendary = "Celestial",
	Celestial = "Void",
}

-- ============================================================
-- INTERNAL HELPERS
-- ============================================================

local function _getTierColor(tier: string): Color3
	return UILib.TierColor[tier] or UILib.Colors.TextMuted
end

local function _stopPulse(): ()
	if ForgeModal._pulseConnection then
		ForgeModal._pulseConnection:Disconnect()
		ForgeModal._pulseConnection = nil
	end
end

local function _startForgePulse(btn: TextButton, strokeObj: UIStroke): ()
	_stopPulse()

	local pulseIn = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local pulseOut = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local running = true

	local conn: RBXScriptConnection
	conn = btn.AncestryChanged:Connect(function()
		running = false
		conn:Disconnect()
	end)
	ForgeModal._pulseConnection = conn

	task.spawn(function()
		while running and btn.Parent do
			local tw1 = TweenService:Create(strokeObj, pulseIn, {
				Transparency = 0.15,
			})
			tw1:Play()
			tw1.Completed:Wait()
			if not running then break end
			local tw2 = TweenService:Create(strokeObj, pulseOut, {
				Transparency = 0.7,
			})
			tw2:Play()
			tw2.Completed:Wait()
		end
	end)
end

-- ============================================================
-- CREATE
-- ============================================================

function ForgeModal.Create(parentGui: ScreenGui)
	-- Modal frame via UILib
	local modal = UILib.CreateModalFrame(parentGui, "ForgeModal", MODAL_WIDTH, MODAL_HEIGHT, ACCENT_COLOR)
	ForgeModal._frame = modal

	-- Header via UILib
	UILib.CreateModalHeader(modal, "Celestial Seed Forge", "Combine 3 identical seeds into an ascended tier", ACCENT_COLOR, function()
		SoundController.Play("ButtonClick")
		ForgeModal.Close()
	end)

	-- ==========================================================
	-- ALTAR PREVIEW AREA
	-- ==========================================================
	local altar = Instance.new("Frame")
	altar.Name = "Altar"
	altar.Size = UDim2.new(1, -40, 0, ALTAR_HEIGHT)
	altar.Position = UDim2.new(0, 20, 0, ALTAR_TOP)
	altar.BackgroundColor3 = UILib.Colors.Surface2
	altar.BackgroundTransparency = 0
	altar.BorderSizePixel = 0
	altar.ZIndex = modal.ZIndex + 1
	altar.Parent = modal
	UILib.ApplyCorner(altar, 12)
	UILib.ApplyStroke(altar, ACCENT_DIM, 1, 0.4)

	-- Altar gradient for depth
	local altarGrad = Instance.new("UIGradient")
	altarGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 20, 58)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 12, 38)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 8, 26)),
	})
	altarGrad.Rotation = 170
	altarGrad.Parent = altar

	-- Dramatic inner glow — circular radial gradient behind formula text
	local glowFrame = Instance.new("Frame")
	glowFrame.Name = "InnerGlow"
	glowFrame.Size = UDim2.new(0, 220, 0, 220)
	glowFrame.Position = UDim2.fromScale(0.5, 0.35)
	glowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	glowFrame.BackgroundColor3 = ACCENT_COLOR
	glowFrame.BackgroundTransparency = 0.82
	glowFrame.BorderSizePixel = 0
	glowFrame.ZIndex = modal.ZIndex + 1
	glowFrame.Parent = altar
	UILib.ApplyCorner(glowFrame, 110) -- fully circular

	local glowGrad = Instance.new("UIGradient")
	glowGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(168, 85, 247)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 40, 180)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 10, 40)),
	})
	glowGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.6, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGrad.Parent = glowFrame

	-- Formula text
	local formulaText = Instance.new("TextLabel")
	formulaText.Name = "FormulaText"
	formulaText.Size = UDim2.new(1, -24, 0, 42)
	formulaText.Position = UDim2.new(0, 12, 0, 14)
	formulaText.BackgroundTransparency = 1
	formulaText.Text = "Select 3 identical seeds from below to begin transmutation"
	formulaText.TextColor3 = ACCENT_LIGHT
	formulaText.TextSize = 15
	formulaText.Font = UILib.Fonts.Bold
	formulaText.TextWrapped = true
	formulaText.ZIndex = modal.ZIndex + 3
	formulaText.Parent = altar

	-- ==========================================================
	-- TRANSFORMATION ROW: 3x [Input Badge] --> arrow --> [Output Badge]
	-- ==========================================================
	local transformRow = Instance.new("Frame")
	transformRow.Name = "TransformRow"
	transformRow.Size = UDim2.new(1, -32, 0, 36)
	transformRow.Position = UDim2.new(0, 16, 0, 64)
	transformRow.BackgroundTransparency = 1
	transformRow.BorderSizePixel = 0
	transformRow.ZIndex = modal.ZIndex + 2
	transformRow.Parent = altar

	-- Input tier badge (left side)
	local inputBadge = Instance.new("Frame")
	inputBadge.Name = "InputBadge"
	inputBadge.Size = UDim2.new(0, 160, 0, 30)
	inputBadge.Position = UDim2.new(0, 0, 0.5, -15)
	inputBadge.BackgroundColor3 = UILib.Colors.Surface3
	inputBadge.BackgroundTransparency = 0.3
	inputBadge.BorderSizePixel = 0
	inputBadge.ZIndex = modal.ZIndex + 3
	inputBadge.Parent = transformRow
	UILib.ApplyPill(inputBadge)
	UILib.ApplyStroke(inputBadge, UILib.Colors.TextMuted, 1, 0.5)

	local inputLabel = Instance.new("TextLabel")
	inputLabel.Name = "InputLabel"
	inputLabel.Size = UDim2.fromScale(1, 1)
	inputLabel.BackgroundTransparency = 1
	inputLabel.Text = "3x ---"
	inputLabel.TextColor3 = UILib.Colors.TextMuted
	inputLabel.TextSize = 12
	inputLabel.Font = UILib.Fonts.Bold
	inputLabel.ZIndex = modal.ZIndex + 4
	inputLabel.Parent = inputBadge

	-- Arrow indicator (center)
	local arrowFrame = Instance.new("Frame")
	arrowFrame.Name = "Arrow"
	arrowFrame.Size = UDim2.new(0, 60, 0, 30)
	arrowFrame.Position = UDim2.new(0.5, -30, 0.5, -15)
	arrowFrame.BackgroundTransparency = 1
	arrowFrame.BorderSizePixel = 0
	arrowFrame.ZIndex = modal.ZIndex + 3
	arrowFrame.Parent = transformRow

	-- Arrow shaft (horizontal line)
	local arrowShaft = Instance.new("Frame")
	arrowShaft.Name = "Shaft"
	arrowShaft.Size = UDim2.new(0, 36, 0, 2)
	arrowShaft.Position = UDim2.new(0.5, -18, 0.5, -1)
	arrowShaft.BackgroundColor3 = ACCENT_LIGHT
	arrowShaft.BackgroundTransparency = 0.2
	arrowShaft.BorderSizePixel = 0
	arrowShaft.ZIndex = modal.ZIndex + 4
	arrowShaft.Parent = arrowFrame

	-- Arrow head — top chevron line
	local arrowTop = Instance.new("Frame")
	arrowTop.Name = "ChevronTop"
	arrowTop.Size = UDim2.new(0, 12, 0, 2)
	arrowTop.Position = UDim2.new(1, -14, 0.5, -6)
	arrowTop.AnchorPoint = Vector2.new(0, 0.5)
	arrowTop.BackgroundColor3 = ACCENT_LIGHT
	arrowTop.BackgroundTransparency = 0.2
	arrowTop.BorderSizePixel = 0
	arrowTop.Rotation = 40
	arrowTop.ZIndex = modal.ZIndex + 4
	arrowTop.Parent = arrowFrame

	-- Arrow head — bottom chevron line
	local arrowBot = Instance.new("Frame")
	arrowBot.Name = "ChevronBot"
	arrowBot.Size = UDim2.new(0, 12, 0, 2)
	arrowBot.Position = UDim2.new(1, -14, 0.5, 4)
	arrowBot.AnchorPoint = Vector2.new(0, 0.5)
	arrowBot.BackgroundColor3 = ACCENT_LIGHT
	arrowBot.BackgroundTransparency = 0.2
	arrowBot.BorderSizePixel = 0
	arrowBot.Rotation = -40
	arrowBot.ZIndex = modal.ZIndex + 4
	arrowBot.Parent = arrowFrame

	-- Output tier badge (right side)
	local outputBadge = Instance.new("Frame")
	outputBadge.Name = "OutputBadge"
	outputBadge.Size = UDim2.new(0, 160, 0, 30)
	outputBadge.Position = UDim2.new(1, -160, 0.5, -15)
	outputBadge.BackgroundColor3 = UILib.Colors.Surface3
	outputBadge.BackgroundTransparency = 0.3
	outputBadge.BorderSizePixel = 0
	outputBadge.ZIndex = modal.ZIndex + 3
	outputBadge.Parent = transformRow
	UILib.ApplyPill(outputBadge)
	UILib.ApplyStroke(outputBadge, UILib.Colors.TextMuted, 1, 0.5)

	local outputLabel = Instance.new("TextLabel")
	outputLabel.Name = "OutputLabel"
	outputLabel.Size = UDim2.fromScale(1, 1)
	outputLabel.BackgroundTransparency = 1
	outputLabel.Text = "Altar Idle"
	outputLabel.TextColor3 = UILib.Colors.TextMuted
	outputLabel.TextSize = 12
	outputLabel.Font = UILib.Fonts.Bold
	outputLabel.ZIndex = modal.ZIndex + 4
	outputLabel.Parent = outputBadge

	-- ==========================================================
	-- STATUS LINE under transform row
	-- ==========================================================
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -32, 0, 20)
	statusLabel.Position = UDim2.new(0, 16, 0, 106)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Ready"
	statusLabel.TextColor3 = UILib.Colors.TextMuted
	statusLabel.TextSize = 11
	statusLabel.Font = UILib.Fonts.Medium
	statusLabel.ZIndex = modal.ZIndex + 2
	statusLabel.Parent = altar

	-- Subtle divider line at altar bottom
	local altarDivider = Instance.new("Frame")
	altarDivider.Name = "AltarDivider"
	altarDivider.Size = UDim2.new(1, -24, 0, 1)
	altarDivider.Position = UDim2.new(0, 12, 0, 132)
	altarDivider.BackgroundColor3 = ACCENT_DIM
	altarDivider.BackgroundTransparency = 0.7
	altarDivider.BorderSizePixel = 0
	altarDivider.ZIndex = modal.ZIndex + 2
	altarDivider.Parent = altar

	-- Small "TRANSMUTATION ALTAR" label at bottom of altar area
	local altarLabel = Instance.new("TextLabel")
	altarLabel.Name = "AltarLabel"
	altarLabel.Size = UDim2.new(1, -24, 0, 18)
	altarLabel.Position = UDim2.new(0, 12, 0, 140)
	altarLabel.BackgroundTransparency = 1
	altarLabel.Text = "TRANSMUTATION ALTAR"
	altarLabel.TextColor3 = UILib.Colors.TextMuted
	altarLabel.TextSize = 9
	altarLabel.Font = UILib.Fonts.Bold
	altarLabel.TextTransparency = 0.4
	altarLabel.ZIndex = modal.ZIndex + 2
	altarLabel.Parent = altar

	-- ==========================================================
	-- SEED LIST SECTION
	-- ==========================================================
	local listTitle = Instance.new("TextLabel")
	listTitle.Name = "ListTitle"
	listTitle.Size = UDim2.new(1, -40, 0, 18)
	listTitle.Position = UDim2.new(0, 20, 0, SEED_LIST_LABEL_TOP)
	listTitle.BackgroundTransparency = 1
	listTitle.Text = "ELIGIBLE SEEDS (3+ OWNED)"
	listTitle.TextColor3 = UILib.Colors.TextSecondary
	listTitle.TextSize = 11
	listTitle.Font = UILib.Fonts.Bold
	listTitle.TextXAlignment = Enum.TextXAlignment.Left
	listTitle.ZIndex = modal.ZIndex + 1
	listTitle.Parent = modal

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "SeedScroll"
	scroll.Size = UDim2.new(1, -40, 0, 116)
	scroll.Position = UDim2.new(0, 20, 0, SEED_LIST_LABEL_TOP + 24)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = ACCENT_COLOR
	scroll.ScrollBarImageTransparency = 0.4
	scroll.ZIndex = modal.ZIndex + 1
	scroll.Parent = modal

	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.FillDirection = Enum.FillDirection.Horizontal
	scrollLayout.Padding = UDim.new(0, 10)
	scrollLayout.SortOrder = Enum.SortOrder.Name
	scrollLayout.Parent = scroll

	-- ==========================================================
	-- FORGE ACTION BUTTON
	-- ==========================================================
	local forgeBtn = Instance.new("TextButton")
	forgeBtn.Name = "ForgeButton"
	forgeBtn.Size = UDim2.new(1, -40, 0, FORGE_BTN_HEIGHT)
	forgeBtn.Position = UDim2.new(0, 20, 1, -FORGE_BTN_HEIGHT - 18)
	forgeBtn.BackgroundColor3 = UILib.Colors.Surface3
	forgeBtn.BorderSizePixel = 0
	forgeBtn.Text = "SELECT SEEDS TO TRANSMUTE"
	forgeBtn.TextColor3 = UILib.Colors.TextMuted
	forgeBtn.TextSize = 15
	forgeBtn.Font = UILib.Fonts.Bold
	forgeBtn.ZIndex = modal.ZIndex + 2
	forgeBtn.Parent = modal
	UILib.ApplyCorner(forgeBtn, 10)

	-- Gradient on forge button for depth
	local forgeBtnGrad = Instance.new("UIGradient")
	forgeBtnGrad.Name = "BtnGrad"
	forgeBtnGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190)),
	})
	forgeBtnGrad.Rotation = 90
	forgeBtnGrad.Parent = forgeBtn

	-- Pulse stroke (will animate when seed is selected)
	local forgeBtnStroke = Instance.new("UIStroke")
	forgeBtnStroke.Name = "PulseStroke"
	forgeBtnStroke.Color = ACCENT_LIGHT
	forgeBtnStroke.Thickness = 1.5
	forgeBtnStroke.Transparency = 1
	forgeBtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	forgeBtnStroke.Parent = forgeBtn

	-- Forge button click
	forgeBtn.MouseButton1Click:Connect(function()
		local selectedId = ForgeModal._selectedSeedId
		if not selectedId then return end

		SoundController.Play("PlantReady")
		local req = ReplicatedStorage:FindFirstChild("GardenRequest") :: RemoteFunction?
		if req then
			local result = req:InvokeServer("Forge", selectedId)
			if result and result.Success then
				SoundController.Play("HarvestRare")
				VFXController.FlashScreen(ACCENT_COLOR, 0.65, 0.9)
				VFXController.AddCameraTrauma(0.5)

				local notif = script.Parent:FindFirstChild("NotificationUI")
				if notif then
					local nModule = require(notif :: ModuleScript)
					nModule.ShowToast(result.Message, Color3.fromRGB(126, 34, 206), 4)
				end

				ForgeModal._selectedSeedId = nil
				ForgeModal.Refresh()
			end
		end
	end)
end

-- ============================================================
-- REFRESH
-- ============================================================

function ForgeModal.Refresh()
	local modal = ForgeModal._frame
	if not modal then return end

	local scroll = modal:FindFirstChild("SeedScroll") :: ScrollingFrame?
	local altar = modal:FindFirstChild("Altar") :: Frame?
	local formulaText = altar and altar:FindFirstChild("FormulaText") :: TextLabel?
	local forgeBtn = modal:FindFirstChild("ForgeButton") :: TextButton?
	local forgeBtnStroke = forgeBtn and forgeBtn:FindFirstChild("PulseStroke") :: UIStroke?

	-- Transform row elements
	local transformRow = altar and altar:FindFirstChild("TransformRow") :: Frame?
	local inputBadge = transformRow and transformRow:FindFirstChild("InputBadge") :: Frame?
	local outputBadge = transformRow and transformRow:FindFirstChild("OutputBadge") :: Frame?
	local inputLabel = inputBadge and inputBadge:FindFirstChild("InputLabel") :: TextLabel?
	local outputLabel = outputBadge and outputBadge:FindFirstChild("OutputLabel") :: TextLabel?
	local inputStroke = inputBadge and inputBadge:FindFirstChild("UIStroke") :: UIStroke?
	local outputStroke = outputBadge and outputBadge:FindFirstChild("UIStroke") :: UIStroke?
	local statusLabel = altar and altar:FindFirstChild("StatusLabel") :: TextLabel?

	if not scroll then return end

	-- Clear existing seed buttons
	for _, btn in ForgeModal._seedButtons do
		btn:Destroy()
	end
	table.clear(ForgeModal._seedButtons)

	local inv = ForgeModal._data and ForgeModal._data.SeedInventory or {}
	local eligibleCount: number = 0

	for seedId, count in inv do
		if count >= 3 then
			eligibleCount += 1
			local seedDef = SeedData.GetSeed(seedId)
			local tier: string = seedDef and seedDef.Tier or "Common"
			local tierColor: Color3 = _getTierColor(tier)
			local isSelected: boolean = ForgeModal._selectedSeedId == seedId

			-- Seed card button
			local btn = Instance.new("TextButton")
			btn.Name = seedId
			btn.Size = UDim2.new(0, SEED_CARD_WIDTH, 0, SEED_CARD_HEIGHT)
			btn.BackgroundColor3 = isSelected and UILib.Colors.Surface4 or UILib.Colors.Surface2
			btn.BorderSizePixel = 0
			btn.Text = ""
			btn.ZIndex = modal.ZIndex + 2
			btn.Parent = scroll
			UILib.ApplyCorner(btn, 10)

			-- Card gradient
			local cardGrad = Instance.new("UIGradient")
			cardGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 26, 56)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 14, 34)),
			})
			cardGrad.Rotation = 150
			cardGrad.Parent = btn

			-- Card stroke — thicker + brighter when selected
			local bStroke = Instance.new("UIStroke")
			bStroke.Color = tierColor
			bStroke.Thickness = isSelected and 2.5 or 1
			bStroke.Transparency = isSelected and 0 or 0.5
			bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			bStroke.Parent = btn

			-- Selected inner glow overlay
			if isSelected then
				local selGlow = Instance.new("Frame")
				selGlow.Name = "SelGlow"
				selGlow.Size = UDim2.fromScale(1, 1)
				selGlow.BackgroundColor3 = tierColor
				selGlow.BackgroundTransparency = 0.88
				selGlow.BorderSizePixel = 0
				selGlow.ZIndex = modal.ZIndex + 2
				selGlow.Parent = btn
				UILib.ApplyCorner(selGlow, 10)
			end

			-- Seed name
			local seedName: string = seedDef and seedDef.Name or seedId
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "SeedName"
			nameLabel.Size = UDim2.new(1, -12, 0, 18)
			nameLabel.Position = UDim2.new(0, 6, 0, 10)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = seedName
			nameLabel.TextColor3 = UILib.Colors.TextPrimary
			nameLabel.TextSize = 13
			nameLabel.Font = UILib.Fonts.Bold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			nameLabel.ZIndex = modal.ZIndex + 3
			nameLabel.Parent = btn

			-- Tier pill
			local tierPill = Instance.new("Frame")
			tierPill.Name = "TierPill"
			tierPill.Size = UDim2.new(0, 62, 0, 16)
			tierPill.Position = UDim2.new(0, 6, 0, 34)
			tierPill.BackgroundColor3 = tierColor
			tierPill.BackgroundTransparency = 0.78
			tierPill.BorderSizePixel = 0
			tierPill.ZIndex = modal.ZIndex + 3
			tierPill.Parent = btn
			UILib.ApplyPill(tierPill)

			local tierPillLabel = Instance.new("TextLabel")
			tierPillLabel.Size = UDim2.fromScale(1, 1)
			tierPillLabel.BackgroundTransparency = 1
			tierPillLabel.Text = string.upper(tier)
			tierPillLabel.TextColor3 = tierColor
			tierPillLabel.TextSize = 9
			tierPillLabel.Font = UILib.Fonts.Bold
			tierPillLabel.ZIndex = modal.ZIndex + 4
			tierPillLabel.Parent = tierPill

			-- Count label
			local countLabel = Instance.new("TextLabel")
			countLabel.Name = "Count"
			countLabel.Size = UDim2.new(1, -12, 0, 16)
			countLabel.Position = UDim2.new(0, 6, 1, -24)
			countLabel.BackgroundTransparency = 1
			countLabel.Text = string.format("Owned: %d", count)
			countLabel.TextColor3 = UILib.Colors.TextSecondary
			countLabel.TextSize = 11
			countLabel.Font = UILib.Fonts.Medium
			countLabel.TextXAlignment = Enum.TextXAlignment.Left
			countLabel.ZIndex = modal.ZIndex + 3
			countLabel.Parent = btn

			-- Hover / press via UILib (only for non-selected)
			if not isSelected then
				UILib.ApplyHover(btn, UILib.Colors.Surface3, nil)
			end

			-- Click to select
			btn.MouseButton1Click:Connect(function()
				SoundController.Play("ButtonClick")
				ForgeModal._selectedSeedId = seedId
				ForgeModal.Refresh()
			end)

			table.insert(ForgeModal._seedButtons, btn)
		end
	end

	-- Update scroll canvas
	scroll.CanvasSize = UDim2.new(0, eligibleCount * (SEED_CARD_WIDTH + 10), 0, 0)

	-- ==========================================================
	-- UPDATE ALTAR + FORGE BUTTON STATE
	-- ==========================================================
	if ForgeModal._selectedSeedId then
		local seedDef = SeedData.GetSeed(ForgeModal._selectedSeedId)
		local currentTier: string = seedDef and seedDef.Tier or "Common"
		local nextTier: string? = TIER_UPGRADE_MAP[currentTier]

		if seedDef and nextTier then
			local currentColor: Color3 = _getTierColor(currentTier)
			local nextColor: Color3 = _getTierColor(nextTier)

			-- Formula text
			if formulaText then
				formulaText.Text = string.format("3x %s (%s)  >>  Ascend", seedDef.Name, currentTier)
				formulaText.TextColor3 = UILib.Colors.TextPrimary
			end

			-- Input badge
			if inputLabel then
				inputLabel.Text = string.format("3x %s", seedDef.Name)
				inputLabel.TextColor3 = currentColor
			end
			if inputStroke then
				inputStroke.Color = currentColor
				inputStroke.Transparency = 0.3
			end

			-- Output badge
			if outputLabel then
				outputLabel.Text = string.format("Guaranteed %s", nextTier)
				outputLabel.TextColor3 = nextColor
			end
			if outputStroke then
				outputStroke.Color = nextColor
				outputStroke.Transparency = 0.2
			end
			if outputBadge then
				outputBadge.BackgroundColor3 = nextColor
				outputBadge.BackgroundTransparency = 0.82
			end

			-- Status label
			if statusLabel then
				statusLabel.Text = "Altar charged — ready to transmute"
				statusLabel.TextColor3 = UILib.Colors.Green
			end

			-- Forge button — active state
			if forgeBtn then
				forgeBtn.BackgroundColor3 = ACCENT_COLOR
				forgeBtn.TextColor3 = UILib.Colors.TextPrimary
				forgeBtn.Text = "TRANSMUTE SPECIMENS (COST: 3 SEEDS)"
			end

			-- Start pulse animation on forge button stroke
			if forgeBtnStroke then
				forgeBtnStroke.Transparency = 0.5
				_startForgePulse(forgeBtn :: TextButton, forgeBtnStroke)
			end
		end
	else
		_stopPulse()

		if formulaText then
			if eligibleCount == 0 then
				formulaText.Text = "You need at least 3 of any seed type to use the Forge"
			else
				formulaText.Text = "Select 3 identical seeds from below to begin transmutation"
			end
			formulaText.TextColor3 = ACCENT_LIGHT
		end

		-- Reset input badge
		if inputLabel then
			inputLabel.Text = "3x ---"
			inputLabel.TextColor3 = UILib.Colors.TextMuted
		end
		if inputStroke then
			inputStroke.Color = UILib.Colors.TextMuted
			inputStroke.Transparency = 0.5
		end

		-- Reset output badge
		if outputLabel then
			outputLabel.Text = "Altar Idle"
			outputLabel.TextColor3 = UILib.Colors.TextMuted
		end
		if outputStroke then
			outputStroke.Color = UILib.Colors.TextMuted
			outputStroke.Transparency = 0.5
		end
		if outputBadge then
			outputBadge.BackgroundColor3 = UILib.Colors.Surface3
			outputBadge.BackgroundTransparency = 0.3
		end

		-- Reset status
		if statusLabel then
			statusLabel.Text = "Ready"
			statusLabel.TextColor3 = UILib.Colors.TextMuted
		end

		-- Forge button — disabled state
		if forgeBtn then
			forgeBtn.BackgroundColor3 = UILib.Colors.Surface3
			forgeBtn.TextColor3 = UILib.Colors.TextMuted
			forgeBtn.Text = "SELECT SEEDS TO TRANSMUTE"
		end

		-- Hide pulse stroke
		if forgeBtnStroke then
			forgeBtnStroke.Transparency = 1
		end
	end
end

-- ============================================================
-- OPEN / CLOSE
-- ============================================================

function ForgeModal.Open()
	if not ForgeModal._frame then return end
	UILib.OpenModal(ForgeModal._frame)
	ForgeModal.Refresh()
end

function ForgeModal.Close()
	if not ForgeModal._frame then return end
	_stopPulse()
	UILib.CloseModal(ForgeModal._frame)
end

-- ============================================================
-- UPDATE
-- ============================================================

function ForgeModal.Update(data: any)
	ForgeModal._data = data
	if ForgeModal._frame and ForgeModal._frame.Visible then
		ForgeModal.Refresh()
	end
end

return ForgeModal
