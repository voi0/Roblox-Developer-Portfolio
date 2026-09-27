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

local player = Players.LocalPlayer

local ForgeModal = {}
ForgeModal._frame = nil :: Frame?
ForgeModal._data = nil :: any
ForgeModal._selectedSeedId = nil :: string?
ForgeModal._seedButtons = {} :: { TextButton }

local TIER_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(148, 163, 184),
	Uncommon = Color3.fromRGB(74, 222, 128),
	Rare = Color3.fromRGB(56, 189, 248),
	Epic = Color3.fromRGB(192, 132, 252),
	Legendary = Color3.fromRGB(251, 191, 36),
	Celestial = Color3.fromRGB(244, 114, 182),
	Void = Color3.fromRGB(147, 51, 234),
}

local TIER_UPGRADE_MAP: { [string]: string } = {
	Common = "Uncommon",
	Uncommon = "Rare",
	Rare = "Epic",
	Epic = "Legendary",
	Legendary = "Celestial",
	Celestial = "Void",
}

function ForgeModal.Create(parentGui: ScreenGui)
	local modal = Instance.new("Frame")
	modal.Name = "ForgeModal"
	modal.Size = UDim2.new(0, 520, 0, 480)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.BackgroundColor3 = Color3.fromRGB(15, 11, 28)
	modal.BackgroundTransparency = 0.1
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = parentGui
	ForgeModal._frame = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(168, 85, 247)
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
	title.Text = "🔮 CELESTIAL SEED FORGE"
	title.TextColor3 = Color3.fromRGB(168, 85, 247)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(0.7, 0, 0, 16)
	subtitle.Position = UDim2.new(0, 20, 0, 38)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Combine 3 identical seeds into an ascended tier"
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
		ForgeModal.Close()
	end)

	-- Center Altar Preview Box
	local altar = Instance.new("Frame")
	altar.Name = "Altar"
	altar.Size = UDim2.new(1, -40, 0, 150)
	altar.Position = UDim2.new(0, 20, 0, 68)
	altar.BackgroundColor3 = Color3.fromRGB(24, 18, 42)
	altar.BorderSizePixel = 0
	altar.Parent = modal

	local altarCorner = Instance.new("UICorner")
	altarCorner.CornerRadius = UDim.new(0, 12)
	altarCorner.Parent = altar

	local altarStroke = Instance.new("UIStroke")
	altarStroke.Name = "AltarStroke"
	altarStroke.Color = Color3.fromRGB(147, 51, 234)
	altarStroke.Thickness = 1.2
	altarStroke.Transparency = 0.4
	altarStroke.Parent = altar

	local formulaText = Instance.new("TextLabel")
	formulaText.Name = "FormulaText"
	formulaText.Size = UDim2.new(1, -20, 0, 50)
	formulaText.Position = UDim2.new(0, 10, 0, 18)
	formulaText.BackgroundTransparency = 1
	formulaText.Text = "Select 3 identical seeds from below to begin transmutation"
	formulaText.TextColor3 = Color3.fromRGB(216, 180, 254)
	formulaText.TextScaled = true
	formulaText.Font = Enum.Font.GothamBold
	formulaText.Parent = altar

	local targetTierBadge = Instance.new("TextLabel")
	targetTierBadge.Name = "TargetTier"
	targetTierBadge.Size = UDim2.new(0, 180, 0, 28)
	targetTierBadge.Position = UDim2.new(0.5, -90, 0, 85)
	targetTierBadge.BackgroundColor3 = Color3.fromRGB(35, 26, 60)
	targetTierBadge.BorderSizePixel = 0
	targetTierBadge.Text = "Ready"
	targetTierBadge.TextColor3 = Color3.fromRGB(148, 163, 184)
	targetTierBadge.TextScaled = true
	targetTierBadge.Font = Enum.Font.GothamBold
	targetTierBadge.Parent = altar

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(1, 0)
	badgeCorner.Parent = targetTierBadge

	-- Horizontal Scroll of Eligible Seeds
	local listTitle = Instance.new("TextLabel")
	listTitle.Name = "ListTitle"
	listTitle.Size = UDim2.new(1, -40, 0, 20)
	listTitle.Position = UDim2.new(0, 20, 0, 230)
	listTitle.BackgroundTransparency = 1
	listTitle.Text = "ELIGIBLE SEEDS IN INVENTORY (Need 3+):"
	listTitle.TextColor3 = Color3.fromRGB(148, 163, 184)
	listTitle.TextScaled = true
	listTitle.Font = Enum.Font.GothamBold
	listTitle.TextXAlignment = Enum.TextXAlignment.Left
	listTitle.Parent = modal

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "SeedScroll"
	scroll.Size = UDim2.new(1, -40, 0, 110)
	scroll.Position = UDim2.new(0, 20, 0, 256)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(168, 85, 247)
	scroll.Parent = modal

	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.FillDirection = Enum.FillDirection.Horizontal
	scrollLayout.Padding = UDim.new(0, 10)
	scrollLayout.Parent = scroll

	-- Action Button
	local forgeBtn = Instance.new("TextButton")
	forgeBtn.Name = "ForgeButton"
	forgeBtn.Size = UDim2.new(1, -40, 0, 52)
	forgeBtn.Position = UDim2.new(0, 20, 1, -68)
	forgeBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
	forgeBtn.BorderSizePixel = 0
	forgeBtn.Text = "SELECT SEEDS TO TRANSMUTE"
	forgeBtn.TextColor3 = Color3.fromRGB(113, 113, 122)
	forgeBtn.TextScaled = true
	forgeBtn.Font = Enum.Font.GothamBold
	forgeBtn.Parent = modal

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = forgeBtn

	forgeBtn.MouseButton1Click:Connect(function()
		local selectedId = ForgeModal._selectedSeedId
		if not selectedId then return end

		SoundController.Play("PlantReady")
		local req = ReplicatedStorage:FindFirstChild("GardenRequest") :: RemoteFunction?
		if req then
			local result = req:InvokeServer("Forge", selectedId)
			if result and result.Success then
				SoundController.Play("HarvestRare")
				VFXController.FlashScreen(Color3.fromRGB(168, 85, 247), 0.65, 0.9)
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

function ForgeModal.Refresh()
	local modal = ForgeModal._frame
	if not modal then return end

	local scroll = modal:FindFirstChild("SeedScroll") :: ScrollingFrame?
	local altar = modal:FindFirstChild("Altar")
	local formulaText = altar and altar:FindFirstChild("FormulaText") :: TextLabel?
	local targetTierBadge = altar and altar:FindFirstChild("TargetTier") :: TextLabel?
	local forgeBtn = modal:FindFirstChild("ForgeButton") :: TextButton?

	if not scroll then return end

	for _, btn in ForgeModal._seedButtons do
		btn:Destroy()
	end
	table.clear(ForgeModal._seedButtons)

	local inv = ForgeModal._data and ForgeModal._data.SeedInventory or {}
	local eligibleCount = 0

	for seedId, count in inv do
		if count >= 3 then
			eligibleCount = eligibleCount + 1
			local seedDef = SeedData.GetSeed(seedId)
			local tierColor = seedDef and TIER_COLORS[seedDef.Tier] or Color3.fromRGB(148, 163, 184)

			local btn = Instance.new("TextButton")
			btn.Name = seedId
			btn.Size = UDim2.new(0, 120, 0, 96)
			btn.BackgroundColor3 = (ForgeModal._selectedSeedId == seedId) and Color3.fromRGB(58, 38, 92) or Color3.fromRGB(24, 18, 42)
			btn.BorderSizePixel = 0
			btn.Text = ""
			btn.Parent = scroll

			local bCorner = Instance.new("UICorner")
			bCorner.CornerRadius = UDim.new(0, 10)
			bCorner.Parent = btn

			local bStroke = Instance.new("UIStroke")
			bStroke.Color = tierColor
			bStroke.Thickness = (ForgeModal._selectedSeedId == seedId) and 2 or 1
			bStroke.Transparency = (ForgeModal._selectedSeedId == seedId) and 0 or 0.5
			bStroke.Parent = btn

			local icon = Instance.new("TextLabel")
			icon.Size = UDim2.new(1, 0, 0, 30)
			icon.Position = UDim2.new(0, 0, 0, 8)
			icon.BackgroundTransparency = 1
			icon.Text = "🌱"
			icon.TextScaled = true
			icon.Parent = btn

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(1, -10, 0, 24)
			name.Position = UDim2.new(0, 5, 0, 38)
			name.BackgroundTransparency = 1
			name.Text = seedDef and seedDef.Name or seedId
			name.TextColor3 = Color3.fromRGB(241, 245, 249)
			name.TextScaled = true
			name.Font = Enum.Font.GothamBold
			name.Parent = btn

			local countLabel = Instance.new("TextLabel")
			countLabel.Size = UDim2.new(1, -10, 0, 18)
			countLabel.Position = UDim2.new(0, 5, 1, -26)
			countLabel.BackgroundTransparency = 1
			countLabel.Text = string.format("Owned: %d", count)
			countLabel.TextColor3 = tierColor
			countLabel.TextScaled = true
			countLabel.Font = Enum.Font.Gotham
			countLabel.Parent = btn

			btn.MouseButton1Click:Connect(function()
				SoundController.Play("ButtonClick")
				ForgeModal._selectedSeedId = seedId
				ForgeModal.Refresh()
			end)

			table.insert(ForgeModal._seedButtons, btn)
		end
	end

	scroll.CanvasSize = UDim2.new(0, eligibleCount * 130, 0, 0)

	-- Update Altar Preview
	if ForgeModal._selectedSeedId then
		local seedDef = SeedData.GetSeed(ForgeModal._selectedSeedId)
		local nextTier = seedDef and TIER_UPGRADE_MAP[seedDef.Tier]

		if seedDef and nextTier then
			local nextTierColor = TIER_COLORS[nextTier] or Color3.fromRGB(168, 85, 247)
			if formulaText then
				formulaText.Text = string.format("3x %s (%s) ➔ ASCEND", seedDef.Name, seedDef.Tier)
			end
			if targetTierBadge then
				targetTierBadge.Text = string.format("Guaranteed %s Seed!", nextTier)
				targetTierBadge.TextColor3 = nextTierColor
				targetTierBadge.BackgroundColor3 = Color3.fromRGB(48, 30, 78)
			end
			if forgeBtn then
				forgeBtn.BackgroundColor3 = Color3.fromRGB(147, 51, 234)
				forgeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				forgeBtn.Text = "TRANSMUTE SPECIMENS (Cost: 3 Seeds)"
			end
		end
	else
		if formulaText then
			if eligibleCount == 0 then
				formulaText.Text = "You need at least 3 of any seed type to use the Forge!"
			else
				formulaText.Text = "Select 3 identical seeds from below to begin transmutation"
			end
		end
		if targetTierBadge then
			targetTierBadge.Text = "Altar Idle"
			targetTierBadge.TextColor3 = Color3.fromRGB(148, 163, 184)
			targetTierBadge.BackgroundColor3 = Color3.fromRGB(30, 24, 48)
		end
		if forgeBtn then
			forgeBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
			forgeBtn.TextColor3 = Color3.fromRGB(113, 113, 122)
			forgeBtn.Text = "SELECT SEEDS TO TRANSMUTE"
		end
	end
end

function ForgeModal.Open()
	if not ForgeModal._frame then return end
	ForgeModal._frame.Visible = true
	ForgeModal._frame.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(ForgeModal._frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
	ForgeModal.Refresh()
end

function ForgeModal.Close()
	if not ForgeModal._frame then return end
	local tween = TweenService:Create(ForgeModal._frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0.5, 0.55),
	})
	tween:Play()
	tween.Completed:Once(function()
		ForgeModal._frame.Visible = false
	end)
end

function ForgeModal.Update(data: any)
	ForgeModal._data = data
	if ForgeModal._frame and ForgeModal._frame.Visible then
		ForgeModal.Refresh()
	end
end

return ForgeModal
