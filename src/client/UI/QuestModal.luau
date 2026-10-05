--!strict
--[[
	QuestModal.luau — Daily Quests, Playtime Rewards & Secret Codes for STARWEAVE
	Presents:
	  1. Daily Astral Quests with UTC midnight reset countdown
	  2. Playtime Rewards (5m, 15m, 30m, 60m tiers) with live progress and claiming
	  3. Secret Promo Code Redemption with listed active community codes
	Located in: StarterPlayerScripts.Client.UI.QuestModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local VFXController = require(script.Parent.Parent.Controllers.VFXController)
local UILib = require(script.Parent.UILib)

local player = Players.LocalPlayer

local QuestModal = {}
QuestModal._frame = nil :: Frame?
QuestModal._data = nil :: any
QuestModal._activeQuests = {} :: { any }
QuestModal._secondsUntilReset = 0
QuestModal._activeTab = "Quests" :: "Quests" | "Playtime" | "Codes"
QuestModal._questCards = {} :: { Frame }
QuestModal._playtimeCards = {} :: { Frame }

local ACCENT = Color3.fromRGB(250, 204, 21) -- Celestial Gold

local PLAYTIME_TIERS = {
	{ Index = 1, Minutes = 5,  Stardust = 500,   Gems = 5,   Seed = "lunar_sprout",     Label = "5 Min Reward" },
	{ Index = 2, Minutes = 15, Stardust = 1500,  Gems = 20,  Seed = "solar_fern",       Label = "15 Min Reward" },
	{ Index = 3, Minutes = 30, Stardust = 5000,  Gems = 50,  Seed = "crystal_vine",     Label = "30 Min Reward" },
	{ Index = 4, Minutes = 60, Stardust = 15000, Gems = 150, Seed = "supernova_orchid", Label = "60 Min Reward" },
}

function QuestModal.Create(parentGui: ScreenGui)
	local modal = UILib.CreateModalFrame(parentGui, "QuestModal", 580, 520, ACCENT)
	QuestModal._frame = modal

	-- Header
	UILib.CreateModalHeader(modal, "Rewards & Challenges", "Daily quests, session playtime milestones & secret promo codes", ACCENT, function()
		SoundController.Play("ButtonClick")
		QuestModal.Close()
	end)

	-- Navigation Tabs Bar
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -32, 0, 32)
	tabBar.Position = UDim2.new(0, 16, 0, 68)
	tabBar.BackgroundColor3 = UILib.Colors.Surface0
	tabBar.BorderSizePixel = 0
	tabBar.ZIndex = modal.ZIndex + 1
	tabBar.Parent = modal
	UILib.ApplyPill(tabBar)
	UILib.ApplyStroke(tabBar, UILib.Colors.PurpleDim, 1, 0.5)

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabBar

	local tabs = {
		{ Id = "Quests", Name = "Daily Quests", Color = Color3.fromRGB(250, 204, 21) },
		{ Id = "Playtime", Name = "Playtime Rewards", Color = Color3.fromRGB(56, 189, 248) },
		{ Id = "Codes", Name = "Secret Codes", Color = Color3.fromRGB(192, 132, 252) },
	}

	local tabButtons: { [string]: TextButton } = {}

	-- Containers for each section
	local questsContainer = Instance.new("Frame")
	questsContainer.Name = "QuestsContainer"
	questsContainer.Size = UDim2.new(1, -32, 1, -116)
	questsContainer.Position = UDim2.new(0, 16, 0, 106)
	questsContainer.BackgroundTransparency = 1
	questsContainer.ZIndex = modal.ZIndex + 1
	questsContainer.Parent = modal

	local playtimeContainer = Instance.new("Frame")
	playtimeContainer.Name = "PlaytimeContainer"
	playtimeContainer.Size = UDim2.new(1, -32, 1, -116)
	playtimeContainer.Position = UDim2.new(0, 16, 0, 106)
	playtimeContainer.BackgroundTransparency = 1
	playtimeContainer.Visible = false
	playtimeContainer.ZIndex = modal.ZIndex + 1
	playtimeContainer.Parent = modal

	local codesContainer = Instance.new("Frame")
	codesContainer.Name = "CodesContainer"
	codesContainer.Size = UDim2.new(1, -32, 1, -116)
	codesContainer.Position = UDim2.new(0, 16, 0, 106)
	codesContainer.BackgroundTransparency = 1
	codesContainer.Visible = false
	codesContainer.ZIndex = modal.ZIndex + 1
	codesContainer.Parent = modal

	for _, tabDef in tabs do
		local tBtn = Instance.new("TextButton")
		tBtn.Name = tabDef.Id
		tBtn.Size = UDim2.new(0, 165, 1, -6)
		tBtn.Position = UDim2.new(0, 0, 0, 3)
		tBtn.BackgroundColor3 = (tabDef.Id == "Quests") and UILib.Colors.Surface3 or Color3.fromRGB(0, 0, 0)
		tBtn.BackgroundTransparency = (tabDef.Id == "Quests") and 0 or 0.8
		tBtn.BorderSizePixel = 0
		tBtn.Text = tabDef.Name
		tBtn.TextColor3 = (tabDef.Id == "Quests") and tabDef.Color or UILib.Colors.TextSecondary
		tBtn.TextSize = 11
		tBtn.Font = UILib.Fonts.Bold
		tBtn.ZIndex = modal.ZIndex + 2
		tBtn.Parent = tabBar
		UILib.ApplyPill(tBtn)

		tabButtons[tabDef.Id] = tBtn

		tBtn.MouseButton1Click:Connect(function()
			SoundController.Play("ButtonHover")
			QuestModal._activeTab = tabDef.Id :: any
			for tid, btn in tabButtons do
				local isActive = (tid == tabDef.Id)
				btn.BackgroundColor3 = isActive and UILib.Colors.Surface3 or Color3.fromRGB(0, 0, 0)
				btn.BackgroundTransparency = isActive and 0 or 0.8
				btn.TextColor3 = isActive and tabDef.Color or UILib.Colors.TextSecondary
			end
			questsContainer.Visible = (tabDef.Id == "Quests")
			playtimeContainer.Visible = (tabDef.Id == "Playtime")
			codesContainer.Visible = (tabDef.Id == "Codes")
			QuestModal.Refresh()
		end)
	end

	-- ============================================================
	-- TAB 1: DAILY QUESTS
	-- ============================================================
	local timerBar = Instance.new("Frame")
	timerBar.Name = "TimerBar"
	timerBar.Size = UDim2.new(1, 0, 0, 28)
	timerBar.Position = UDim2.new(0, 0, 0, 0)
	timerBar.BackgroundColor3 = UILib.Colors.Surface2
	timerBar.BorderSizePixel = 0
	timerBar.ZIndex = modal.ZIndex + 2
	timerBar.Parent = questsContainer
	UILib.ApplyPill(timerBar)
	UILib.ApplyStroke(timerBar, UILib.Colors.PurpleDim, 1, 0.5)

	local timerIcon = Instance.new("TextLabel")
	timerIcon.Size = UDim2.new(0, 24, 1, 0)
	timerIcon.Position = UDim2.new(0, 8, 0, 0)
	timerIcon.BackgroundTransparency = 1
	timerIcon.Text = "24h"
	timerIcon.TextColor3 = ACCENT
	timerIcon.TextSize = 11
	timerIcon.Font = UILib.Fonts.Black
	timerIcon.ZIndex = modal.ZIndex + 3
	timerIcon.Parent = timerBar

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "ResetTimer"
	timerLabel.Size = UDim2.new(1, -40, 1, 0)
	timerLabel.Position = UDim2.new(0, 36, 0, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "New Quests In: Calculating..."
	timerLabel.TextColor3 = UILib.Colors.TextSecondary
	timerLabel.TextSize = 12
	timerLabel.Font = UILib.Fonts.Bold
	timerLabel.TextXAlignment = Enum.TextXAlignment.Left
	timerLabel.ZIndex = modal.ZIndex + 3
	timerLabel.Parent = timerBar

	local questScroll = UILib.CreateScrollFrame(
		questsContainer, "QuestScroll",
		UDim2.new(1, 0, 1, -36),
		UDim2.new(0, 0, 0, 36),
		ACCENT
	)
	questScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local qScrollLayout = Instance.new("UIListLayout")
	qScrollLayout.FillDirection = Enum.FillDirection.Vertical
	qScrollLayout.Padding = UDim.new(0, 8)
	qScrollLayout.Parent = questScroll

	-- ============================================================
	-- TAB 2: PLAYTIME REWARDS
	-- ============================================================
	local playScroll = UILib.CreateScrollFrame(
		playtimeContainer, "PlaytimeScroll",
		UDim2.fromScale(1, 1),
		UDim2.new(0, 0, 0, 0),
		Color3.fromRGB(56, 189, 248)
	)
	playScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local pScrollLayout = Instance.new("UIListLayout")
	pScrollLayout.FillDirection = Enum.FillDirection.Vertical
	pScrollLayout.Padding = UDim.new(0, 8)
	pScrollLayout.Parent = playScroll

	-- ============================================================
	-- TAB 3: SECRET CODES
	-- ============================================================
	local codeFrame = Instance.new("Frame")
	codeFrame.Name = "CodeFrame"
	codeFrame.Size = UDim2.new(1, 0, 0, 140)
	codeFrame.Position = UDim2.new(0, 0, 0, 10)
	codeFrame.BackgroundColor3 = UILib.Colors.Surface2
	codeFrame.BorderSizePixel = 0
	codeFrame.ZIndex = modal.ZIndex + 2
	codeFrame.Parent = codesContainer
	UILib.ApplyCorner(codeFrame, 12)
	UILib.ApplyStroke(codeFrame, UILib.Colors.PurpleLight, 1, 0.4)

	local codeTitle = Instance.new("TextLabel")
	codeTitle.Size = UDim2.new(1, -20, 0, 22)
	codeTitle.Position = UDim2.new(0, 14, 0, 12)
	codeTitle.BackgroundTransparency = 1
	codeTitle.Text = "✦ REDEEM PROMOTIONAL CODE"
	codeTitle.TextColor3 = ACCENT
	codeTitle.TextSize = 13
	codeTitle.Font = UILib.Fonts.Bold
	codeTitle.TextXAlignment = Enum.TextXAlignment.Left
	codeTitle.ZIndex = modal.ZIndex + 3
	codeTitle.Parent = codeFrame

	local input = Instance.new("TextBox")
	input.Name = "CodeInput"
	input.Size = UDim2.new(1, -140, 0, 38)
	input.Position = UDim2.new(0, 14, 0, 42)
	input.BackgroundColor3 = UILib.Colors.Surface0
	input.BorderSizePixel = 0
	input.PlaceholderText = "Enter promo code here..."
	input.PlaceholderColor3 = UILib.Colors.TextMuted
	input.Text = ""
	input.TextColor3 = UILib.Colors.TextPrimary
	input.TextSize = 13
	input.Font = UILib.Fonts.Bold
	input.ClearTextOnFocus = false
	input.ZIndex = modal.ZIndex + 3
	input.Parent = codeFrame
	UILib.ApplyCorner(input, 8)
	UILib.ApplyPadding(input, 0, 10, 0, 10)

	local redeemBtn = Instance.new("TextButton")
	redeemBtn.Name = "RedeemButton"
	redeemBtn.Size = UDim2.new(0, 110, 0, 38)
	redeemBtn.Position = UDim2.new(1, -124, 0, 42)
	redeemBtn.BackgroundColor3 = ACCENT
	redeemBtn.BorderSizePixel = 0
	redeemBtn.Text = "REDEEM"
	redeemBtn.TextColor3 = Color3.fromRGB(15, 10, 28)
	redeemBtn.TextSize = 13
	redeemBtn.Font = UILib.Fonts.Black
	redeemBtn.ZIndex = modal.ZIndex + 3
	redeemBtn.Parent = codeFrame
	UILib.ApplyCorner(redeemBtn, 8)

	redeemBtn.MouseButton1Click:Connect(function()
		local codeStr = input.Text
		if #codeStr == 0 then return end

		SoundController.Play("ButtonClick")
		local codeReq = ReplicatedStorage:FindFirstChild("CodeRequest") :: RemoteFunction?
		if codeReq then
			local result = codeReq:InvokeServer(codeStr)
			local notif = script.Parent:FindFirstChild("NotificationUI")
			if notif then
				local nModule = require(notif :: ModuleScript)
				if result.Success then
					SoundController.Play("HarvestRare")
					VFXController.FlashScreen(ACCENT, 0.5, 0.8)
					nModule.ShowToast(result.Message, Color3.fromRGB(22, 101, 52), 4)
					input.Text = ""
				else
					SoundController.Play("ButtonHover")
					UILib.ShakeElement(redeemBtn, Color3.fromRGB(180, 50, 50))
					nModule.ShowToast(result.Message, Color3.fromRGB(248, 113, 113), 3.5)
				end
			end
		end
	end)

	-- Active Promo Codes hint banner
	local hintCard = Instance.new("Frame")
	hintCard.Size = UDim2.new(1, 0, 0, 140)
	hintCard.Position = UDim2.new(0, 0, 0, 160)
	hintCard.BackgroundColor3 = UILib.Colors.Surface1
	hintCard.BorderSizePixel = 0
	hintCard.ZIndex = modal.ZIndex + 2
	hintCard.Parent = codesContainer
	UILib.ApplyCorner(hintCard, 10)
	UILib.ApplyStroke(hintCard, UILib.Colors.PurpleDim, 1, 0.5)

	local hintTitle = Instance.new("TextLabel")
	hintTitle.Size = UDim2.new(1, -20, 0, 20)
	hintTitle.Position = UDim2.new(0, 14, 0, 12)
	hintTitle.BackgroundTransparency = 1
	hintTitle.Text = "★ ACTIVE COMMUNITY PROMO CODES:"
	hintTitle.TextColor3 = UILib.Colors.PurpleLight
	hintTitle.TextSize = 11
	hintTitle.Font = UILib.Fonts.Bold
	hintTitle.TextXAlignment = Enum.TextXAlignment.Left
	hintTitle.ZIndex = modal.ZIndex + 3
	hintTitle.Parent = hintCard

	local codesList = {
		"• STARWEAVE — +500 Stardust & 5 Gems",
		"• COSMIC — +250 Stardust & 3x Seeds",
		"• LAUNCH — +1,000 Stardust celebration bonus",
		"• VOI0 — +10 Nebula Gems & Rare seed",
	}

	for i, cText in codesList do
		local cLabel = Instance.new("TextLabel")
		cLabel.Size = UDim2.new(1, -20, 0, 16)
		cLabel.Position = UDim2.new(0, 14, 0, 36 + (i - 1) * 22)
		cLabel.BackgroundTransparency = 1
		cLabel.Text = cText
		cLabel.TextColor3 = UILib.Colors.TextSecondary
		cLabel.TextSize = 11
		cLabel.Font = UILib.Fonts.Body
		cLabel.TextXAlignment = Enum.TextXAlignment.Left
		cLabel.ZIndex = modal.ZIndex + 3
		cLabel.Parent = hintCard
	end

	-- Daily countdown timer
	task.spawn(function()
		while modal.Parent do
			if QuestModal._secondsUntilReset > 0 then
				QuestModal._secondsUntilReset -= 1
				local h = math.floor(QuestModal._secondsUntilReset / 3600)
				local m = math.floor((QuestModal._secondsUntilReset % 3600) / 60)
				local s = QuestModal._secondsUntilReset % 60
				timerLabel.Text = string.format("New Quests In: %02dh %02dm %02ds", h, m, s)
			end
			task.wait(1)
		end
	end)

	-- Listen for quest updates from server
	local questEvent = ReplicatedStorage:WaitForChild("QuestUpdate") :: RemoteEvent
	questEvent.OnClientEvent:Connect(function(questList: any, secondsUntilReset: number)
		QuestModal._activeQuests = questList or {}
		if secondsUntilReset then
			QuestModal._secondsUntilReset = secondsUntilReset
		end
		if QuestModal._frame and QuestModal._frame.Visible then
			QuestModal.Refresh()
		end
	end)

	QuestModal.Refresh()
end

function QuestModal.Refresh()
	local modal = QuestModal._frame
	if not modal then return end

	-- Refresh Tab 1: Quests
	local qContainer = modal:FindFirstChild("QuestsContainer")
	local qScroll = qContainer and qContainer:FindFirstChild("QuestScroll") :: ScrollingFrame?

	if qScroll then
		for _, card in QuestModal._questCards do
			card:Destroy()
		end
		table.clear(QuestModal._questCards)

		for _, quest in QuestModal._activeQuests do
			local card = Instance.new("Frame")
			card.Name = quest.Id
			card.Size = UDim2.new(1, 0, 0, 84)
			card.BackgroundColor3 = quest.Claimed and Color3.fromRGB(18, 22, 38) or UILib.Colors.Surface2
			card.BorderSizePixel = 0
			card.ZIndex = modal.ZIndex + 2
			card.Parent = qScroll
			UILib.ApplyCorner(card, 10)

			local strokeColor = quest.Completed and ACCENT or UILib.Colors.PurpleDim
			UILib.ApplyStroke(card, strokeColor, 1, quest.Claimed and 0.8 or 0.4)

			UILib.CreateLabel(
				card, "Title", quest.Title,
				quest.Completed and ACCENT or UILib.Colors.TextPrimary,
				13, UILib.Fonts.Bold,
				UDim2.new(0, 12, 0, 8), UDim2.new(0.65, 0, 0, 18)
			)

			UILib.CreateLabel(
				card, "Desc", quest.Description,
				UILib.Colors.TextSecondary,
				11, UILib.Fonts.Body,
				UDim2.new(0, 12, 0, 26), UDim2.new(0.65, 0, 0, 14)
			)

			local rewText = string.format("+%s SD  •  +%d Gems", UILib.FormatNumber(quest.RewardStardust), quest.RewardGems)
			UILib.CreateLabel(
				card, "Rewards", rewText,
				UILib.Colors.PurpleLight,
				10, UILib.Fonts.Medium,
				UDim2.new(0, 12, 0, 42), UDim2.new(0.65, 0, 0, 14)
			)

			local progBg, progFill = UILib.CreateProgressBar(
				card, "QuestProg",
				UDim2.new(0, 12, 0, 62),
				UDim2.new(0.62, 0, 0, 8),
				ACCENT
			)
			local pct = math.clamp(quest.Current / math.max(quest.Target, 1), 0, 1)
			progFill.Size = UDim2.fromScale(pct, 1)

			local countText = string.format("%d / %d", quest.Current, quest.Target)
			UILib.CreateLabel(
				card, "Count", countText,
				UILib.Colors.TextMuted,
				10, UILib.Fonts.Bold,
				UDim2.new(0.62, 20, 0, 60), UDim2.new(0, 50, 0, 12),
				Enum.TextXAlignment.Left
			)

			local claimBtn = Instance.new("TextButton")
			claimBtn.Name = "ClaimButton"
			claimBtn.Size = UDim2.new(0, 100, 0, 36)
			claimBtn.Position = UDim2.new(1, -112, 0.5, -18)
			claimBtn.BorderSizePixel = 0
			claimBtn.ZIndex = modal.ZIndex + 3
			claimBtn.Parent = card
			UILib.ApplyCorner(claimBtn, 8)

			if quest.Claimed then
				claimBtn.BackgroundColor3 = Color3.fromRGB(24, 20, 36)
				claimBtn.Text = "CLAIMED"
				claimBtn.TextColor3 = UILib.Colors.TextMuted
				claimBtn.TextSize = 11
				claimBtn.Font = UILib.Fonts.Bold
			elseif quest.Completed then
				claimBtn.BackgroundColor3 = ACCENT
				claimBtn.Text = "CLAIM!"
				claimBtn.TextColor3 = Color3.fromRGB(15, 10, 28)
				claimBtn.TextSize = 13
				claimBtn.Font = UILib.Fonts.Black

				claimBtn.MouseButton1Click:Connect(function()
					SoundController.Play("HarvestRare")
					VFXController.FlashScreen(ACCENT, 0.4, 0.7)
					local req = ReplicatedStorage:FindFirstChild("QuestRequest") :: RemoteFunction?
					if req then
						local res = req:InvokeServer("ClaimReward", quest.Id)
						if res and res.Success then
							local notif = script.Parent:FindFirstChild("NotificationUI")
							if notif then
								local nModule = require(notif :: ModuleScript)
								nModule.ShowToast(string.format("⭐ Claimed: +%s SD, +%d Gems!", UILib.FormatNumber(res.Stardust), res.Gems), Color3.fromRGB(22, 101, 52), 4)
							end
						end
					end
				end)
			else
				claimBtn.BackgroundColor3 = UILib.Colors.Surface3
				claimBtn.Text = "IN PROGRESS"
				claimBtn.TextColor3 = UILib.Colors.TextMuted
				claimBtn.TextSize = 10
				claimBtn.Font = UILib.Fonts.Bold
			end

			table.insert(QuestModal._questCards, card)
		end
	end

	-- Refresh Tab 2: Playtime Rewards
	local pContainer = modal:FindFirstChild("PlaytimeContainer")
	local pScroll = pContainer and pContainer:FindFirstChild("PlaytimeScroll") :: ScrollingFrame?

	if pScroll then
		for _, card in QuestModal._playtimeCards do
			card:Destroy()
		end
		table.clear(QuestModal._playtimeCards)

		-- Query server playtime stats
		local playReq = ReplicatedStorage:FindFirstChild("PlaytimeRequest") :: RemoteFunction?
		local playData = { Minutes = 0, Claimed = {} }
		if playReq then
			local success, res = pcall(function()
				return playReq:InvokeServer("GetData")
			end)
			if success and res then
				playData = res
			end
		end

		local currentMins = playData.Minutes or 0
		local claimedMap = playData.Claimed or {}

		for _, tier in PLAYTIME_TIERS do
			local isClaimed = claimedMap[tier.Index] == true
			local isReady = (currentMins >= tier.Minutes) and not isClaimed
			local tierColor = isReady and Color3.fromRGB(56, 189, 248) or UILib.Colors.PurpleLight

			local card = Instance.new("Frame")
			card.Name = `Tier_{tier.Index}`
			card.Size = UDim2.new(1, 0, 0, 84)
			card.BackgroundColor3 = isClaimed and Color3.fromRGB(18, 22, 38) or UILib.Colors.Surface2
			card.BorderSizePixel = 0
			card.ZIndex = modal.ZIndex + 2
			card.Parent = pScroll
			UILib.ApplyCorner(card, 10)
			UILib.ApplyStroke(card, isReady and Color3.fromRGB(56, 189, 248) or UILib.Colors.PurpleDim, 1, isClaimed and 0.8 or 0.4)

			UILib.CreateLabel(
				card, "Title", tier.Label,
				isReady and Color3.fromRGB(56, 189, 248) or UILib.Colors.TextPrimary,
				13, UILib.Fonts.Bold,
				UDim2.new(0, 12, 0, 8), UDim2.new(0.65, 0, 0, 18)
			)

			local rewText = string.format("+%s SD • +%d Gems • 1x %s", UILib.FormatNumber(tier.Stardust), tier.Gems, tier.Seed)
			UILib.CreateLabel(
				card, "Rewards", rewText,
				tierColor,
				11, UILib.Fonts.Medium,
				UDim2.new(0, 12, 0, 26), UDim2.new(0.65, 0, 0, 14)
			)

			local progBg, progFill = UILib.CreateProgressBar(
				card, "PlayProg",
				UDim2.new(0, 12, 0, 62),
				UDim2.new(0.62, 0, 0, 8),
				Color3.fromRGB(56, 189, 248)
			)
			local pct = math.clamp(currentMins / tier.Minutes, 0, 1)
			progFill.Size = UDim2.fromScale(pct, 1)

			local countText = string.format("%d / %d mins", math.min(currentMins, tier.Minutes), tier.Minutes)
			UILib.CreateLabel(
				card, "Count", countText,
				UILib.Colors.TextMuted,
				10, UILib.Fonts.Bold,
				UDim2.new(0.62, 20, 0, 60), UDim2.new(0, 70, 0, 12),
				Enum.TextXAlignment.Left
			)

			local claimBtn = Instance.new("TextButton")
			claimBtn.Name = "ClaimButton"
			claimBtn.Size = UDim2.new(0, 105, 0, 36)
			claimBtn.Position = UDim2.new(1, -118, 0.5, -18)
			claimBtn.BorderSizePixel = 0
			claimBtn.ZIndex = modal.ZIndex + 3
			claimBtn.Parent = card
			UILib.ApplyCorner(claimBtn, 8)

			if isClaimed then
				claimBtn.BackgroundColor3 = Color3.fromRGB(24, 20, 36)
				claimBtn.Text = "CLAIMED"
				claimBtn.TextColor3 = UILib.Colors.TextMuted
				claimBtn.TextSize = 11
				claimBtn.Font = UILib.Fonts.Bold
			elseif isReady then
				claimBtn.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
				claimBtn.Text = "CLAIM REWARD"
				claimBtn.TextColor3 = Color3.fromRGB(15, 10, 28)
				claimBtn.TextSize = 11
				claimBtn.Font = UILib.Fonts.Black

				claimBtn.MouseButton1Click:Connect(function()
					SoundController.Play("HarvestRare")
					VFXController.FlashScreen(Color3.fromRGB(56, 189, 248), 0.4, 0.7)
					if playReq then
						local res = playReq:InvokeServer("Claim", tier.Index)
						if res and res.Success then
							local notif = script.Parent:FindFirstChild("NotificationUI")
							if notif then
								local nModule = require(notif :: ModuleScript)
								nModule.ShowToast(res.Message or "Playtime reward claimed!", Color3.fromRGB(22, 101, 52), 4)
							end
							QuestModal.Refresh()
						end
					end
				end)
			else
				claimBtn.BackgroundColor3 = UILib.Colors.Surface3
				local remMins = tier.Minutes - currentMins
				claimBtn.Text = string.format("%dm left", remMins)
				claimBtn.TextColor3 = UILib.Colors.TextMuted
				claimBtn.TextSize = 11
				claimBtn.Font = UILib.Fonts.Bold
			end

			table.insert(QuestModal._playtimeCards, card)
		end
	end
end

function QuestModal.Open()
	if not QuestModal._frame then return end
	UILib.OpenModal(QuestModal._frame)

	local req = ReplicatedStorage:FindFirstChild("QuestRequest") :: RemoteFunction?
	if req then
		local res = req:InvokeServer("GetQuests")
		if res and res.Success then
			QuestModal._activeQuests = res.Quests or {}
			QuestModal._secondsUntilReset = res.SecondsUntilReset or 86400
			QuestModal.Refresh()
		end
	end
end

function QuestModal.Close()
	if not QuestModal._frame then return end
	UILib.CloseModal(QuestModal._frame)
end

function QuestModal.Update(data: any)
	QuestModal._data = data
	if QuestModal._frame and QuestModal._frame.Visible then
		QuestModal.Refresh()
	end
end

return QuestModal
