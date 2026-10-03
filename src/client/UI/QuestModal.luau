--!strict
--[[
	QuestModal.luau — Daily Quests & Secret Codes Sanctuary for STARWEAVE
	Displays the 3 active daily quests with live progress bars, reward claiming,
	countdown to UTC midnight reset, and a secret code redemption bar.
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
QuestModal._questCards = {} :: { Frame }

local ACCENT = Color3.fromRGB(250, 204, 21) -- Celestial Gold

function QuestModal.Create(parentGui: ScreenGui)
	local modal = UILib.CreateModalFrame(parentGui, "QuestModal", 580, 520, ACCENT)
	QuestModal._frame = modal

	-- Header
	UILib.CreateModalHeader(modal, "Daily Quests & Codes", "Complete astral challenges & redeem promotional codes", ACCENT, function()
		SoundController.Play("ButtonClick")
		QuestModal.Close()
	end)

	-- Timer Bar (Reset countdown)
	local timerBar = Instance.new("Frame")
	timerBar.Name = "TimerBar"
	timerBar.Size = UDim2.new(1, -32, 0, 28)
	timerBar.Position = UDim2.new(0, 16, 0, 68)
	timerBar.BackgroundColor3 = UILib.Colors.Surface2
	timerBar.BorderSizePixel = 0
	timerBar.ZIndex = modal.ZIndex + 1
	timerBar.Parent = modal
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
	timerIcon.ZIndex = modal.ZIndex + 2
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
	timerLabel.ZIndex = modal.ZIndex + 2
	timerLabel.Parent = timerBar

	-- Scrolling Cards Area for 3 Quests
	local scroll = UILib.CreateScrollFrame(
		modal, "QuestScroll",
		UDim2.new(1, -32, 0, 290),
		UDim2.new(0, 16, 0, 104),
		ACCENT
	)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.FillDirection = Enum.FillDirection.Vertical
	scrollLayout.Padding = UDim.new(0, 10)
	scrollLayout.Parent = scroll

	-- ============================================================
	-- PROMO CODE REDEMPTION SECTION (Bottom)
	-- ============================================================
	local codeFrame = Instance.new("Frame")
	codeFrame.Name = "CodeFrame"
	codeFrame.Size = UDim2.new(1, -32, 0, 80)
	codeFrame.Position = UDim2.new(0, 16, 1, -94)
	codeFrame.BackgroundColor3 = UILib.Colors.Surface2
	codeFrame.BorderSizePixel = 0
	codeFrame.ZIndex = modal.ZIndex + 2
	codeFrame.Parent = modal
	UILib.ApplyCorner(codeFrame, 12)
	UILib.ApplyStroke(codeFrame, UILib.Colors.PurpleLight, 1, 0.4)

	local codeTitle = Instance.new("TextLabel")
	codeTitle.Size = UDim2.new(1, -20, 0, 18)
	codeTitle.Position = UDim2.new(0, 12, 0, 8)
	codeTitle.BackgroundTransparency = 1
	codeTitle.Text = "PROMO CODE REDEMPTION (Check TikTok/Twitter)"
	codeTitle.TextColor3 = ACCENT
	codeTitle.TextSize = 11
	codeTitle.Font = UILib.Fonts.Bold
	codeTitle.TextXAlignment = Enum.TextXAlignment.Left
	codeTitle.ZIndex = modal.ZIndex + 3
	codeTitle.Parent = codeFrame

	-- Input Box
	local input = Instance.new("TextBox")
	input.Name = "CodeInput"
	input.Size = UDim2.new(1, -140, 0, 36)
	input.Position = UDim2.new(0, 12, 0, 32)
	input.BackgroundColor3 = UILib.Colors.Surface0
	input.BorderSizePixel = 0
	input.PlaceholderText = "Enter code (e.g. STARWEAVE)..."
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

	-- Redeem Button
	local redeemBtn = Instance.new("TextButton")
	redeemBtn.Name = "RedeemButton"
	redeemBtn.Size = UDim2.new(0, 110, 0, 36)
	redeemBtn.Position = UDim2.new(1, -122, 0, 32)
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
					nModule.ShowToast(result.Message, Color3.fromRGB(120, 30, 30), 4)
				end
			end
		end
	end)

	-- Start local clock timer for daily reset
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
	local scroll = modal:FindFirstChild("QuestScroll") :: ScrollingFrame?
	if not scroll then return end

	for _, card in QuestModal._questCards do
		card:Destroy()
	end
	table.clear(QuestModal._questCards)

	for _, quest in QuestModal._activeQuests do
		local card = Instance.new("Frame")
		card.Name = quest.Id
		card.Size = UDim2.new(1, 0, 0, 82)
		card.BackgroundColor3 = quest.Claimed and Color3.fromRGB(16, 12, 26) or UILib.Colors.Surface2
		card.BorderSizePixel = 0
		card.ZIndex = modal.ZIndex + 2
		card.Parent = scroll
		UILib.ApplyCorner(card, 10)

		local strokeColor = quest.Completed and ACCENT or UILib.Colors.PurpleDim
		UILib.ApplyStroke(card, strokeColor, 1, quest.Claimed and 0.8 or 0.4)

		-- Title
		UILib.CreateLabel(
			card, "Title", quest.Title,
			quest.Completed and ACCENT or UILib.Colors.TextPrimary,
			13, UILib.Fonts.Bold,
			UDim2.new(0, 12, 0, 8), UDim2.new(0.65, 0, 0, 18)
		)

		-- Description
		UILib.CreateLabel(
			card, "Desc", quest.Description,
			UILib.Colors.TextSecondary,
			11, UILib.Fonts.Body,
			UDim2.new(0, 12, 0, 26), UDim2.new(0.65, 0, 0, 14)
		)

		-- Reward preview
		local rewText = string.format("+%s SD  •  +%d Gems", UILib.FormatNumber(quest.RewardStardust), quest.RewardGems)
		UILib.CreateLabel(
			card, "Rewards", rewText,
			UILib.Colors.PurpleLight,
			10, UILib.Fonts.Medium,
			UDim2.new(0, 12, 0, 42), UDim2.new(0.65, 0, 0, 14)
		)

		-- Progress Bar
		local progBg, progFill = UILib.CreateProgressBar(
			card, "QuestProg",
			UDim2.new(0, 12, 0, 62),
			UDim2.new(0.62, 0, 0, 8),
			ACCENT
		)
		local pct = math.clamp(quest.Current / math.max(quest.Target, 1), 0, 1)
		progFill.Size = UDim2.fromScale(pct, 1)

		local countText = string.format("%d / %d", quest.Current, quest.Target)
		local countLabel = UILib.CreateLabel(
			card, "Count", countText,
			UILib.Colors.TextMuted,
			10, UILib.Fonts.Bold,
			UDim2.new(0.62, 20, 0, 60), UDim2.new(0, 50, 0, 12),
			Enum.TextXAlignment.Left
		)

		-- Action Button (Claim / In Progress / Claimed)
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
							nModule.ShowToast(`⭐ Claimed: +{UILib.FormatNumber(res.Stardust)} SD, +{res.Gems} Gems!`, Color3.fromRGB(22, 101, 52), 4)
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

function QuestModal.Open()
	if not QuestModal._frame then return end
	UILib.OpenModal(QuestModal._frame)

	-- Request latest quests
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
