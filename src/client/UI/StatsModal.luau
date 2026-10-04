--!strict
--[[
	StatsModal.luau — Player Profile & Live Cosmic Multipliers for STARWEAVE
	Displays active player stats, progression rank, live multipliers breakdown,
	and lifetime harvest milestones with clean visual cards.
	Located in: StarterPlayerScripts.Client.UI.StatsModal
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local UILib = require(script.Parent.UILib)

local player = Players.LocalPlayer

local StatsModal = {}
StatsModal._frame = nil :: Frame?
StatsModal._data = nil :: any
StatsModal._statLabels = {} :: { [string]: TextLabel }

local ACCENT = Color3.fromRGB(56, 189, 248)

function StatsModal.Create(parentGui: ScreenGui)
	local modal = UILib.CreateModalFrame(parentGui, "StatsModal", 540, 460, ACCENT)
	StatsModal._frame = modal

	-- Header
	UILib.CreateModalHeader(modal, "Cosmic Profile & Stats", "Live active multipliers, progression rank & garden milestones", ACCENT, function()
		SoundController.Play("ButtonClick")
		StatsModal.Close()
	end)

	-- Top Profile Summary Banner
	local banner = Instance.new("Frame")
	banner.Name = "ProfileBanner"
	banner.Size = UDim2.new(1, -32, 0, 72)
	banner.Position = UDim2.new(0, 16, 0, 56)
	banner.BackgroundColor3 = Color3.fromRGB(28, 36, 62)
	banner.BorderSizePixel = 0
	banner.ZIndex = modal.ZIndex + 2
	banner.Parent = modal
	UILib.ApplyCorner(banner, 12)
	UILib.ApplyStroke(banner, ACCENT, 1.2, 0.4)

	local bannerGrad = Instance.new("UIGradient")
	bannerGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 48, 82)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 30, 54)),
	})
	bannerGrad.Rotation = 90
	bannerGrad.Parent = banner

	-- Avatar Thumbnail
	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Name = "Avatar"
	avatarImg.Size = UDim2.new(0, 52, 0, 52)
	avatarImg.Position = UDim2.new(0, 10, 0.5, -26)
	avatarImg.BackgroundColor3 = Color3.fromRGB(18, 22, 38)
	avatarImg.BorderSizePixel = 0
	avatarImg.ZIndex = modal.ZIndex + 3
	avatarImg.Parent = banner
	UILib.ApplyCorner(avatarImg, 26)
	UILib.ApplyStroke(avatarImg, ACCENT, 1.2, 0.3)

	task.spawn(function()
		local thumb, isReady = Players:GetUserThumbnailAsync(
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
		if isReady then
			avatarImg.Image = thumb
		end
	end)

	-- Username & Rank
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Username"
	nameLabel.Size = UDim2.new(0.6, 0, 0, 20)
	nameLabel.Position = UDim2.new(0, 72, 0, 12)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName or player.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 15
	nameLabel.Font = UILib.Fonts.Bold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = modal.ZIndex + 3
	nameLabel.Parent = banner

	local rankPill = Instance.new("Frame")
	rankPill.Size = UDim2.new(0, 150, 0, 20)
	rankPill.Position = UDim2.new(0, 72, 0, 38)
	rankPill.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
	rankPill.BackgroundTransparency = 0.85
	rankPill.BorderSizePixel = 0
	rankPill.ZIndex = modal.ZIndex + 3
	rankPill.Parent = banner
	UILib.ApplyPill(rankPill)
	UILib.ApplyStroke(rankPill, Color3.fromRGB(168, 85, 247), 1, 0.5)

	local rankLabel = Instance.new("TextLabel")
	rankLabel.Name = "RankText"
	rankLabel.Size = UDim2.fromScale(1, 1)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = "TIER 0 • CELESTIAL ADEPT"
	rankLabel.TextColor3 = Color3.fromRGB(192, 132, 252)
	rankLabel.TextSize = 10
	rankLabel.Font = UILib.Fonts.Bold
	rankLabel.ZIndex = modal.ZIndex + 4
	rankLabel.Parent = rankPill
	StatsModal._statLabels["Rank"] = rankLabel

	-- 4 Core Multiplier Cards Grid
	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "MultipliersGrid"
	gridFrame.Size = UDim2.new(1, -32, 0, 170)
	gridFrame.Position = UDim2.new(0, 16, 0, 136)
	gridFrame.BackgroundTransparency = 1
	gridFrame.ZIndex = modal.ZIndex + 2
	gridFrame.Parent = modal

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.5, -6, 0, 80)
	gridLayout.CellPadding = UDim2.new(0, 12, 0, 10)
	gridLayout.Parent = gridFrame

	local multipliers = {
		{ Id = "MutationLuck", Title = "MUTATION LUCK", Icon = "🍀", Color = Color3.fromRGB(52, 211, 153), Sub = "Boosts rare flower mutations" },
		{ Id = "GrowthSpeed",  Title = "GROWTH ACCEL",  Icon = "⚡", Color = Color3.fromRGB(56, 189, 248),  Sub = "Reduces harvest countdowns" },
		{ Id = "SellMult",     Title = "SELL MULTIPLIER", Icon = "💰", Color = Color3.fromRGB(250, 204, 21),  Sub = "Multiplies Stardust per crop" },
		{ Id = "Constellation", Title = "COSMIC PASSIVES", Icon = "🌌", Color = Color3.fromRGB(244, 114, 182), Sub = "Active prestige perks" },
	}

	for _, mult in multipliers do
		local card = Instance.new("Frame")
		card.Name = mult.Id
		card.BackgroundColor3 = Color3.fromRGB(30, 38, 64)
		card.BorderSizePixel = 0
		card.ZIndex = modal.ZIndex + 3
		card.Parent = gridFrame
		UILib.ApplyCorner(card, 10)
		UILib.ApplyStroke(card, mult.Color, 1.2, 0.45)

		local cardGrad = Instance.new("UIGradient")
		cardGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 46, 76)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(26, 32, 54)),
		})
		cardGrad.Rotation = 90
		cardGrad.Parent = card

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -12, 0, 16)
		title.Position = UDim2.new(0, 10, 0, 8)
		title.BackgroundTransparency = 1
		title.Text = `{mult.Icon}  {mult.Title}`
		title.TextColor3 = mult.Color
		title.TextSize = 11
		title.Font = UILib.Fonts.Bold
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.ZIndex = modal.ZIndex + 4
		title.Parent = card

		local value = Instance.new("TextLabel")
		value.Name = "Value"
		value.Size = UDim2.new(1, -12, 0, 26)
		value.Position = UDim2.new(0, 10, 0, 26)
		value.BackgroundTransparency = 1
		value.Text = "+0.0%"
		value.TextColor3 = Color3.fromRGB(255, 255, 255)
		value.TextSize = 18
		value.Font = UILib.Fonts.Bold
		value.TextXAlignment = Enum.TextXAlignment.Left
		value.ZIndex = modal.ZIndex + 4
		value.Parent = card
		StatsModal._statLabels[mult.Id] = value

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, -12, 0, 14)
		sub.Position = UDim2.new(0, 10, 0, 54)
		sub.BackgroundTransparency = 1
		sub.Text = mult.Sub
		sub.TextColor3 = Color3.fromRGB(160, 175, 210)
		sub.TextSize = 9
		sub.Font = UILib.Fonts.Medium
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.ZIndex = modal.ZIndex + 4
		sub.Parent = card
	end

	-- Bottom Lifetime Milestones
	local milestones = Instance.new("Frame")
	milestones.Name = "MilestonesFrame"
	milestones.Size = UDim2.new(1, -32, 0, 120)
	milestones.Position = UDim2.new(0, 16, 0, 316)
	milestones.BackgroundColor3 = Color3.fromRGB(24, 30, 50)
	milestones.BorderSizePixel = 0
	milestones.ZIndex = modal.ZIndex + 2
	milestones.Parent = modal
	UILib.ApplyCorner(milestones, 10)
	UILib.ApplyStroke(milestones, Color3.fromRGB(60, 75, 120), 1, 0.6)

	local mLayout = Instance.new("UIListLayout")
	mLayout.FillDirection = Enum.FillDirection.Vertical
	mLayout.Padding = UDim.new(0, 8)
	mLayout.Parent = milestones
	UILib.ApplyPadding(milestones, 10, 14, 10, 14)

	local function addMilestoneRow(id: string, icon: string, labelText: string, defaultVal: string): TextLabel
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 18)
		row.BackgroundTransparency = 1
		row.ZIndex = modal.ZIndex + 3
		row.Parent = milestones

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.65, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = `{icon}  {labelText}`
		lbl.TextColor3 = Color3.fromRGB(200, 215, 245)
		lbl.TextSize = 11
		lbl.Font = UILib.Fonts.Medium
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.ZIndex = modal.ZIndex + 4
		lbl.Parent = row

		local val = Instance.new("TextLabel")
		val.Name = "Val"
		val.Size = UDim2.new(0.35, 0, 1, 0)
		val.Position = UDim2.new(0.65, 0, 0, 0)
		val.BackgroundTransparency = 1
		val.Text = defaultVal
		val.TextColor3 = Color3.fromRGB(250, 204, 21)
		val.TextSize = 11
		val.Font = UILib.Fonts.Bold
		val.TextXAlignment = Enum.TextXAlignment.Right
		val.ZIndex = modal.ZIndex + 4
		val.Parent = row

		StatsModal._statLabels[id] = val
		return val
	end

	addMilestoneRow("TotalStardust", "✦", "Total Stardust Harvested:", "0 SD")
	addMilestoneRow("TotalPlants", "🌾", "Total Crops Planted & Harvested:", "0")
	addMilestoneRow("DiscoveredFlora", "📖", "Compendium Flora Cataloged:", "0 / 96")
	addMilestoneRow("EquippedPet", "🐾", "Active Companion:", "None")
end

function StatsModal.Open()
	if not StatsModal._frame then return end
	StatsModal.Refresh()
	UILib.OpenModal(StatsModal._frame)
end

function StatsModal.Close()
	if not StatsModal._frame then return end
	UILib.CloseModal(StatsModal._frame)
end

function StatsModal.Refresh()
	local data = StatsModal._data
	if not data then return end

	local rebirthLvl = data.Rebirth and data.Rebirth.Level or 0
	local rankLabel = StatsModal._statLabels["Rank"]
	if rankLabel then
		rankLabel.Text = `REBIRTH TIER {rebirthLvl} • COSMIC ADEPT`
	end

	-- Calculate Multipliers
	local luckBonus = 0
	local spdBonus = 0

	-- Pet contribution
	local equippedIdx = data.EquippedPetIndex
	local equippedPet = (equippedIdx and data.Pets) and data.Pets[equippedIdx] or nil
	if equippedPet then
		luckBonus += (equippedPet.MutationLuckBonus or 0)
		spdBonus += ((equippedPet.HarvestSpeedBonus or 1.0) - 1.0)
		local petLbl = StatsModal._statLabels["EquippedPet"]
		if petLbl then
			petLbl.Text = equippedPet.Name
		end
	end

	-- Constellation contribution
	local const = data.Constellation or {}
	if const.mutation_luck then
		luckBonus += (const.mutation_luck * 0.03)
	end
	if const.growth_speed then
		spdBonus += (const.growth_speed * 0.05)
	end
	if const.sell_bonus then
		local sellMult = 1.0 + (const.sell_bonus * 0.05) + (data.Rebirth and (data.Rebirth.CosmicMultiplier - 1.0) or 0)
		local sellLbl = StatsModal._statLabels["SellMult"]
		if sellLbl then
			sellLbl.Text = string.format("%.2fx", sellMult)
		end
	end

	local luckLbl = StatsModal._statLabels["MutationLuck"]
	if luckLbl then
		luckLbl.Text = string.format("+%.1f%%", luckBonus * 100)
	end

	local spdLbl = StatsModal._statLabels["GrowthSpeed"]
	if spdLbl then
		spdLbl.Text = string.format("+%.1f%%", spdBonus * 100)
	end

	local constLbl = StatsModal._statLabels["Constellation"]
	if constLbl then
		local count = 0
		for _, lvl in const do count += lvl end
		constLbl.Text = `{count} Upgrades`
	end

	-- Milestones
	local sdLbl = StatsModal._statLabels["TotalStardust"]
	if sdLbl then
		sdLbl.Text = `{UILib.FormatNumber(data.Stardust or 0)} SD`
	end

	local plantLbl = StatsModal._statLabels["TotalPlants"]
	if plantLbl then
		plantLbl.Text = tostring(data.TotalHarvests or 0)
	end

	local collLbl = StatsModal._statLabels["DiscoveredFlora"]
	if collLbl then
		local count = 0
		local coll = data.PlantCollection or {}
		for _ in coll do count += 1 end
		collLbl.Text = `{count} / 96 Specimen`
	end
end

function StatsModal.Update(data: any)
	StatsModal._data = data
	if StatsModal._frame and StatsModal._frame.Visible then
		StatsModal.Refresh()
	end
end

return StatsModal
