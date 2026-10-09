--!strict
--[[
	DailyModal.luau — 7-Day Retention Rewards Modal for VAULT WARS: STEAL & DEFEND TYCOON
	Displays 7-day calendar with claimed checkmarks, unlock timers, and instant claim button.
	Located in: StarterPlayerScripts.Client.UI.DailyModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local ModelEngine = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelEngine"))
local UILib = require(script.Parent:WaitForChild("UILib"))

local player = Players.LocalPlayer
local DailyModal = {}

DailyModal._frame = nil :: Frame?
DailyModal._isOpen = false
DailyModal._dayCards = {} :: { [number]: Frame }
DailyModal._claimBtn = nil :: TextButton?
DailyModal._timerLabel = nil :: TextLabel?

function DailyModal.Create(parentGui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "DailyRewardModal"
	frame.Size = UDim2.new(0, 680, 0, 480)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Visible = false
	frame.ZIndex = 50
	frame.Parent = parentGui
	DailyModal._frame = frame

	local stroke = UILib.ApplyLiquidGlassStyle(frame, Color3.fromRGB(245, 158, 11))

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundTransparency = 1
	header.Parent = frame

	local title = Instance.new("TextLabel")
	title.Text = "📅 7-DAY RETENTION STREAK CALENDAR"
	title.TextColor3 = Color3.fromRGB(250, 204, 21)
	title.TextSize = 18
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.new(0, 24, 0, 10)
	title.Size = UDim2.new(1, -80, 0, 22)
	title.BackgroundTransparency = 1
	title.Parent = header

	local sub = Instance.new("TextLabel")
	sub.Text = "Log in daily to escalate your payout up to $1,000,000 + Mythic Void Eye!"
	sub.TextColor3 = Color3.fromRGB(148, 163, 184)
	sub.TextSize = 12
	sub.Font = Enum.Font.GothamMedium
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Position = UDim2.new(0, 24, 0, 32)
	sub.Size = UDim2.new(1, -80, 0, 18)
	sub.BackgroundTransparency = 1
	sub.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(148, 163, 184)
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Position = UDim2.new(1, -44, 0, 12)
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	closeBtn.Parent = header
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
	UILib.ApplySpringHover(closeBtn, nil, nil)

	closeBtn.MouseButton1Click:Connect(function()
		DailyModal.Close()
	end)

	-- Grid Container for 7 Days
	local gridContainer = Instance.new("Frame")
	gridContainer.Name = "GridContainer"
	gridContainer.Size = UDim2.new(1, -48, 0, 320)
	gridContainer.Position = UDim2.new(0, 24, 0, 68)
	gridContainer.BackgroundTransparency = 1
	gridContainer.Parent = frame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 150, 0, 150)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = gridContainer

	-- Build 7 Day Cards
	for dayNum = 1, 7 do
		local reward = Config.DailyRewards[dayNum]
		local isJackpotDay = (dayNum == 7)

		local card = Instance.new("Frame")
		card.Name = `DayCard_{dayNum}`
		card.LayoutOrder = dayNum
		card.BackgroundColor3 = isJackpotDay and Color3.fromRGB(30, 27, 46) or Color3.fromRGB(18, 22, 34)
		card.BorderSizePixel = 0
		card.Parent = gridContainer
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

		local cardStroke = Instance.new("UIStroke", card)
		cardStroke.Color = isJackpotDay and Color3.fromRGB(250, 204, 21) or Color3.fromRGB(39, 39, 42)
		cardStroke.Thickness = isJackpotDay and 2.5 or 1.5

		-- Day Header
		local dLabel = Instance.new("TextLabel")
		dLabel.Text = isJackpotDay and `👑 DAY {dayNum} (JACKPOT)` or `DAY {dayNum}`
		dLabel.TextColor3 = isJackpotDay and Color3.fromRGB(250, 204, 21) or Color3.fromRGB(56, 189, 248)
		dLabel.TextSize = 11
		dLabel.Font = Enum.Font.GothamBlack
		dLabel.Size = UDim2.new(1, -12, 0, 20)
		dLabel.Position = UDim2.new(0, 6, 0, 8)
		dLabel.BackgroundTransparency = 1
		dLabel.Parent = card

		-- Live 3D ViewportFrame
		local relicId = reward and (reward.RelicId or "GoldStack") or "GoldStack"
		local vp = Instance.new("ViewportFrame")
		vp.Name = "RelicVP"
		vp.Size = UDim2.new(0, 50, 0, 50)
		vp.Position = UDim2.new(0.5, 0, 0, 30)
		vp.AnchorPoint = Vector2.new(0.5, 0)
		vp.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
		vp.BorderSizePixel = 0
		vp.Parent = card
		Instance.new("UICorner", vp).CornerRadius = UDim.new(0, 8)

		local relic3D = ModelEngine.CreateRelicModel(relicId, CFrame.new(0, 0, 0))
		relic3D.Parent = vp

		local vpCam = Instance.new("Camera")
		vpCam.CFrame = CFrame.lookAt(Vector3.new(0, 1.4, 3.8), Vector3.new(0, 1.4, 0))
		vpCam.Parent = vp
		vp.CurrentCamera = vpCam

		task.spawn(function()
			local rot = math.random() * math.pi
			while vp and vp.Parent do
				rot += 0.025
				if relic3D and relic3D.PrimaryPart then
					relic3D:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, rot, 0))
				end
				task.wait(0.03)
			end
		end)

		-- Reward Label positioned below Viewport
		local rLabel = Instance.new("TextLabel")
		rLabel.Name = "RewardText"
		rLabel.Text = reward and reward.Label or "Bonus"
		rLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
		rLabel.TextSize = 10
		rLabel.Font = Enum.Font.GothamBold
		rLabel.TextWrapped = true
		rLabel.Size = UDim2.new(1, -12, 0, 32)
		rLabel.Position = UDim2.new(0, 6, 0, 84)
		rLabel.BackgroundTransparency = 1
		rLabel.Parent = card

		-- Status Pill (Claimed / Ready / Locked)
		local statusPill = Instance.new("TextLabel")
		statusPill.Name = "StatusPill"
		statusPill.Text = "🔒 LOCKED"
		statusPill.TextColor3 = Color3.fromRGB(148, 163, 184)
		statusPill.TextSize = 10
		statusPill.Font = Enum.Font.GothamBlack
		statusPill.Size = UDim2.new(1, -16, 0, 24)
		statusPill.Position = UDim2.new(0, 8, 1, -30)
		statusPill.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
		statusPill.Parent = card
		Instance.new("UICorner", statusPill).CornerRadius = UDim.new(0, 8)

		DailyModal._dayCards[dayNum] = card
	end

	-- Bottom Action Bar: Claim Button & Timer
	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.Size = UDim2.new(1, -48, 0, 52)
	bottomBar.Position = UDim2.new(0, 24, 1, -64)
	bottomBar.BackgroundTransparency = 1
	bottomBar.Parent = frame

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(0, 360, 1, 0)
	timerLabel.Position = UDim2.new(0, 0, 0, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "⏳ Next reward ready in: --:--"
	timerLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
	timerLabel.TextSize = 12
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.TextXAlignment = Enum.TextXAlignment.Left
	timerLabel.Parent = bottomBar
	DailyModal._timerLabel = timerLabel

	local claimBtn = Instance.new("TextButton")
	claimBtn.Name = "ClaimButton"
	claimBtn.Size = UDim2.new(0, 210, 0, 44)
	claimBtn.Position = UDim2.new(1, -210, 0, 4)
	claimBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
	claimBtn.Text = "🎁 CLAIM TODAY'S REWARD"
	claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	claimBtn.TextSize = 12
	claimBtn.Font = Enum.Font.GothamBlack
	claimBtn.Parent = bottomBar
	Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 10)

	local cStroke = Instance.new("UIStroke", claimBtn)
	cStroke.Color = Color3.fromRGB(5, 150, 105)
	cStroke.Thickness = 2.5

	claimBtn.MouseEnter:Connect(function()
		if claimBtn.AutoButtonColor then
			TweenService:Create(claimBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 216, 0, 46)
			}):Play()
		end
	end)
	claimBtn.MouseLeave:Connect(function()
		TweenService:Create(claimBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 210, 0, 44)
		}):Play()
	end)

	DailyModal._claimBtn = claimBtn

	claimBtn.MouseButton1Click:Connect(function()
		local claimRF = ReplicatedStorage:FindFirstChild("ClaimDailyReward") :: RemoteFunction?
		if claimRF then
			claimBtn.Text = "CLAIMING..."
			task.spawn(function()
				local result = claimRF:InvokeServer()
				if result and result.Success then
					claimBtn.Text = "✓ CLAIMED!"
					DailyModal.Refresh()
				else
					claimBtn.Text = "UNAVAILABLE"
					task.wait(1.5)
					DailyModal.Refresh()
				end
			end)
		end
	end)

	print("  [DailyModal] 7-Day Retention Modal constructed ✓")
end

function DailyModal.Refresh()
	local statusRF = ReplicatedStorage:FindFirstChild("GetDailyStatus") :: RemoteFunction?
	if not statusRF then return end

	task.spawn(function()
		local status = statusRF:InvokeServer()
		if not status then return end

		local streak = status.Streak or 0
		local canClaim = status.CanClaim or false
		local timeRem = status.TimeUntilNext or 0

		-- Update cards
		for dayNum = 1, 7 do
			local card = DailyModal._dayCards[dayNum]
			if not card then continue end

			local pill = card:FindFirstChild("StatusPill") :: TextLabel?
			local cardStroke = card:FindFirstChildOfClass("UIStroke")
			if not pill then continue end

			if dayNum <= streak then
				-- Already claimed
				pill.Text = "✓ CLAIMED"
				pill.TextColor3 = Color3.fromRGB(16, 185, 129)
				pill.BackgroundColor3 = Color3.fromRGB(6, 78, 59)
				card.BackgroundTransparency = 0.35
				if cardStroke then cardStroke.Color = Color3.fromRGB(16, 185, 129) end

			elseif dayNum == streak + 1 and canClaim then
				-- Ready to claim now
				pill.Text = "⚡ CLAIM NOW!"
				pill.TextColor3 = Color3.fromRGB(250, 204, 21)
				pill.BackgroundColor3 = Color3.fromRGB(120, 53, 15)
				card.BackgroundTransparency = 0
				if cardStroke then cardStroke.Color = Color3.fromRGB(250, 204, 21) end

			else
				-- Locked
				pill.Text = "🔒 LOCKED"
				pill.TextColor3 = Color3.fromRGB(148, 163, 184)
				pill.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
				card.BackgroundTransparency = 0.1
				if cardStroke then cardStroke.Color = Color3.fromRGB(39, 39, 42) end
			end
		end

		-- Update button & bottom label
		if DailyModal._claimBtn then
			if canClaim then
				DailyModal._claimBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
				DailyModal._claimBtn.Text = `🎁 CLAIM DAY {streak + 1} REWARD`
				DailyModal._claimBtn.AutoButtonColor = true
			else
				DailyModal._claimBtn.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
				DailyModal._claimBtn.Text = "ALREADY CLAIMED TODAY"
				DailyModal._claimBtn.AutoButtonColor = false
			end
		end

		if DailyModal._timerLabel then
			if canClaim then
				DailyModal._timerLabel.Text = "✅ Daily streak reward is ready to claim!"
				DailyModal._timerLabel.TextColor3 = Color3.fromRGB(16, 185, 129)
			else
				local hrs = math.floor(timeRem / 3600)
				local mins = math.floor((timeRem % 3600) / 60)
				DailyModal._timerLabel.Text = `⏳ Next reward available in: {hrs}h {mins}m`
				DailyModal._timerLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
			end
		end
	end)
end

function DailyModal.Open()
	if not DailyModal._frame then return end
	DailyModal._frame.Visible = true
	DailyModal._isOpen = true
	DailyModal.Refresh()
end

function DailyModal.Close()
	if not DailyModal._frame then return end
	DailyModal._frame.Visible = false
	DailyModal._isOpen = false
end

function DailyModal.Toggle()
	if DailyModal._isOpen then
		DailyModal.Close()
	else
		DailyModal.Open()
	end
end

return DailyModal
