--!strict
--[[
	RoundController.luau — Client-side round listener & Hero/Chicken UI handler
	Located in: StarterPlayerScripts.Client.Controllers.RoundController
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local RoundController = {}
RoundController._heroGui = nil :: ScreenGui?

function RoundController.Init()
	print("  [RoundController] Initializing Round State Listener...")

	local roundEvt = ReplicatedStorage:WaitForChild("RoundStateChanged", 15) :: RemoteEvent?
	if roundEvt then
		roundEvt.OnClientEvent:Connect(function(data: any)
			RoundController.OnStateChanged(data)
		end)
	end

	local heroPromptEvt = ReplicatedStorage:WaitForChild("HeroPrompt", 15) :: RemoteEvent?
	if heroPromptEvt then
		heroPromptEvt.OnClientEvent:Connect(function()
			RoundController.ShowHeroPrompt()
		end)
	end

	local waveCrossedEvt = ReplicatedStorage:WaitForChild("WaveCrossed", 15) :: RemoteEvent?
	if waveCrossedEvt then
		waveCrossedEvt.OnClientEvent:Connect(function(waveIndex: number)
			RoundController.ShowCrossedBanner(waveIndex)
		end)
	end

	print("  [RoundController] Round listener ready ✓")
end

function RoundController.OnStateChanged(data: any)
	-- Update HUD if HUDController is present
	local pGui = player:FindFirstChildOfClass("PlayerGui")
	if not pGui then return end

	local hud = pGui:FindFirstChild("PackHUD")
	if hud then
		local stateLabel = hud:FindFirstChild("RoundStateLabel", true) :: TextLabel?
		local timerLabel = hud:FindFirstChild("TimerLabel", true) :: TextLabel?
		local countsLabel = hud:FindFirstChild("CountsLabel", true) :: TextLabel?

		if stateLabel and timerLabel and countsLabel then
			local sName = data.State
			if sName == "Intermission" then
				stateLabel.Text = "INTERMISSION"
				stateLabel.TextColor3 = Color3.fromRGB(168, 85, 247)
			elseif sName == "HeroSelection" then
				stateLabel.Text = "HERO SELECTION"
				stateLabel.TextColor3 = Color3.fromRGB(244, 114, 182)
			elseif sName == "RoundActive" then
				stateLabel.Text = `WAVE {data.WaveIndex}/3` .. (data.IsHeroMode and " (HERO SOLO RUN)" or "")
				stateLabel.TextColor3 = data.IsHeroMode and Color3.fromRGB(250, 204, 21) or Color3.fromRGB(56, 189, 248)
			elseif sName == "RoundIntermission" then
				stateLabel.Text = "INFECTION WAVE REST"
				stateLabel.TextColor3 = Color3.fromRGB(244, 63, 94)
			elseif sName == "MatchOver" then
				stateLabel.Text = "MATCH OVER"
				stateLabel.TextColor3 = Color3.fromRGB(34, 197, 94)
			end

			timerLabel.Text = `{data.TimeRemaining}s`
			countsLabel.Text = `🏃 {data.AliveRunners} Runners | 🔪 {data.Chasers} Chasers`

			local roleLabel = hud:FindFirstChild("RoleLabel", true) :: TextLabel?
			local roleBadge = hud:FindFirstChild("RoleBadge", true) :: Frame?
			if roleLabel and roleBadge and data.MyRole then
				if data.MyRole == "Runner" then
					roleBadge.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
					roleLabel.Text = "RUNNER"
					roleLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
				elseif data.MyRole == "Chaser" then
					roleBadge.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
					roleLabel.Text = "CHASER"
					roleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				else
					roleBadge.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
					roleLabel.Text = "SPECTATOR"
					roleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
			end
		end
	end
end

-- ============================================================
-- HERO OR CHICKEN SCREEN PROMPT (Streamer & TikTok Goldmine)
-- ============================================================
function RoundController.ShowHeroPrompt()
	local pGui = player:FindFirstChildOfClass("PlayerGui")
	if not pGui then return end

	local existing = pGui:FindFirstChild("HeroPromptGui")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HeroPromptGui"
	gui.ResetOnSpawn = false
	gui.Parent = pGui
	RoundController._heroGui = gui

	local card = Instance.new("Frame")
	card.Name = "HeroCard"
	card.Size = UDim2.new(0, 520, 0, 280)
	card.Position = UDim2.new(0.5, -260, 0.5, -140)
	card.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	card.BorderSizePixel = 0
	card.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(250, 204, 21)
	stroke.Thickness = 3
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Text = "👑 YOU HAVE BEEN CHOSEN! 👑"
	title.TextColor3 = Color3.fromRGB(250, 204, 21)
	title.TextSize = 22
	title.Font = Enum.Font.GothamBlack
	title.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -40, 0, 36)
	subtitle.Position = UDim2.new(0, 20, 0, 48)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Will you cross the arena SOLO for 5x Rewards, or run with the team?"
	subtitle.TextColor3 = Color3.fromRGB(244, 244, 245)
	subtitle.TextSize = 13
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextWrapped = true
	subtitle.Parent = card

	-- ── HERO BUTTON (SOLO) ──
	local heroBtn = Instance.new("TextButton")
	heroBtn.Name = "HeroButton"
	heroBtn.Size = UDim2.new(0, 220, 0, 90)
	heroBtn.Position = UDim2.new(0, 25, 0, 120)
	heroBtn.BackgroundColor3 = Color3.fromRGB(234, 179, 8)
	heroBtn.Text = "👑 BE THE HERO!\n(SOLO RUN)\n+5x Gems & Coins"
	heroBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
	heroBtn.TextSize = 15
	heroBtn.Font = Enum.Font.GothamBlack
	heroBtn.Parent = card
	Instance.new("UICorner", heroBtn).CornerRadius = UDim.new(0, 12)

	-- ── CHICKEN BUTTON (GROUP) ──
	local chickenBtn = Instance.new("TextButton")
	chickenBtn.Name = "ChickenButton"
	chickenBtn.Size = UDim2.new(0, 220, 0, 90)
	chickenBtn.Position = UDim2.new(1, -245, 0, 120)
	chickenBtn.BackgroundColor3 = Color3.fromRGB(75, 85, 99)
	chickenBtn.Text = "🐔 CHICKEN OUT\n(GROUP RUN)\nStandard Rewards"
	chickenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	chickenBtn.TextSize = 15
	chickenBtn.Font = Enum.Font.GothamBold
	chickenBtn.Parent = card
	Instance.new("UICorner", chickenBtn).CornerRadius = UDim.new(0, 12)

	local function onSelect(choice: string)
		local evt = ReplicatedStorage:FindFirstChild("HeroDecision") :: RemoteEvent?
		if evt then evt:FireServer(choice) end
		gui:Destroy()
	end

	heroBtn.MouseButton1Click:Connect(function() onSelect("Hero") end)
	chickenBtn.MouseButton1Click:Connect(function() onSelect("Chicken") end)

	-- Auto-destroy after 6 seconds
	task.delay(6, function()
		if gui and gui.Parent then gui:Destroy() end
	end)
end

function RoundController.ShowCrossedBanner(waveIndex: number)
	local pGui = player:FindFirstChildOfClass("PlayerGui")
	if not pGui then return end

	local banner = Instance.new("TextLabel")
	banner.Name = "SafeBanner"
	banner.Size = UDim2.new(0, 400, 0, 60)
	banner.Position = UDim2.new(0.5, -200, 0.25, 0)
	banner.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
	banner.Text = `✓ SAFE! WAVE {waveIndex} CROSSED!`
	banner.TextColor3 = Color3.fromRGB(255, 255, 255)
	banner.TextSize = 20
	banner.Font = Enum.Font.GothamBlack
	banner.Parent = pGui
	Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 12)

	task.delay(2.5, function()
		banner:Destroy()
	end)
end

return RoundController
