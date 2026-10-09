--!strict
--[[
	HUDController.luau — Tactical Survival HUD for ESCAPE THE PACK
	Displays Live Wave Status, Countdown, Runner/Chaser Counters,
	Currency Capsules, Tactical Ability Cooldown [Q], Movement Tech Guide,
	and Downed State Vignette.
	Located in: StarterPlayerScripts.Client.UI.HUDController
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AbilityData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AbilityData"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local HUDController = {}

HUDController._gui = nil :: ScreenGui?
HUDController._stateLabel = nil :: TextLabel?
HUDController._timerLabel = nil :: TextLabel?
HUDController._countsLabel = nil :: TextLabel?
HUDController._coinsLabel = nil :: TextLabel?
HUDController._gemsLabel = nil :: TextLabel?
HUDController._roleLabel = nil :: TextLabel?
HUDController._roleBadge = nil :: Frame?
HUDController._abilityIcon = nil :: ImageLabel?
HUDController._abilityName = nil :: TextLabel?
HUDController._cooldownOverlay = nil :: Frame?
HUDController._cooldownLabel = nil :: TextLabel?
HUDController._downedVignette = nil :: Frame?
HUDController._dashBar = nil :: Frame?
HUDController._currentRole = "Runner"
HUDController._onLockerToggle = nil :: (() -> ())?

-- ============================================================
-- HELPER: FORMAT NUMBERS (K / M)
-- ============================================================
local function formatNumber(n: number): string
	n = math.floor(n or 0)
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	else
		return tostring(n)
	end
end

-- ============================================================
-- CREATE PACK HUD
-- ============================================================
function HUDController.Create()
	local pGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
	if not pGui then
		warn("[HUDController] PlayerGui not found!")
		return
	end

	local existing = pGui:FindFirstChild("PackHUD")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "PackHUD"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = pGui
	HUDController._gui = gui

	-- ── 1. TOP CENTER BANNER: WAVE, TIMER & PLAYERS ──
	local topBanner = Instance.new("Frame")
	topBanner.Name = "TopBanner"
	topBanner.Size = UDim2.new(0, 440, 0, 72)
	topBanner.Position = UDim2.new(0.5, 0, 0, 16)
	topBanner.AnchorPoint = Vector2.new(0.5, 0)
	topBanner.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	topBanner.BackgroundTransparency = 0.15
	topBanner.BorderSizePixel = 0
	topBanner.Parent = gui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 16)
	bCorner.Parent = topBanner

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(56, 189, 248)
	bStroke.Thickness = 2
	bStroke.Transparency = 0.3
	bStroke.Parent = topBanner

	-- Round State Label
	local stateLabel = Instance.new("TextLabel")
	stateLabel.Name = "RoundStateLabel"
	stateLabel.Size = UDim2.new(1, -20, 0, 22)
	stateLabel.Position = UDim2.new(0, 10, 0, 8)
	stateLabel.BackgroundTransparency = 1
	stateLabel.Text = "INTERMISSION"
	stateLabel.TextColor3 = Color3.fromRGB(168, 85, 247)
	stateLabel.TextSize = 15
	stateLabel.Font = Enum.Font.GothamBold
	stateLabel.TextXAlignment = Enum.TextXAlignment.Center
	stateLabel.Parent = topBanner
	HUDController._stateLabel = stateLabel

	-- Timer Label
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(1, -20, 0, 24)
	timerLabel.Position = UDim2.new(0, 10, 0, 28)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "30s"
	timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	timerLabel.TextSize = 22
	timerLabel.Font = Enum.Font.GothamBlack
	timerLabel.TextXAlignment = Enum.TextXAlignment.Center
	timerLabel.Parent = topBanner
	HUDController._timerLabel = timerLabel

	-- Counts Label
	local countsLabel = Instance.new("TextLabel")
	countsLabel.Name = "CountsLabel"
	countsLabel.Size = UDim2.new(1, -20, 0, 16)
	countsLabel.Position = UDim2.new(0, 10, 0, 52)
	countsLabel.BackgroundTransparency = 1
	countsLabel.Text = "🏃 0 Runners | 🔪 0 Chasers"
	countsLabel.TextColor3 = Color3.fromRGB(161, 161, 170)
	countsLabel.TextSize = 12
	countsLabel.Font = Enum.Font.GothamMedium
	countsLabel.TextXAlignment = Enum.TextXAlignment.Center
	countsLabel.Parent = topBanner
	HUDController._countsLabel = countsLabel

	-- ── 2. TOP RIGHT: COINS, GEMS, ROLE & LOCKER ──
	local topRight = Instance.new("Frame")
	topRight.Name = "TopRight"
	topRight.Size = UDim2.new(0, 320, 0, 48)
	topRight.Position = UDim2.new(1, -20, 0, 16)
	topRight.AnchorPoint = Vector2.new(1, 0)
	topRight.BackgroundTransparency = 1
	topRight.Parent = gui

	local trLayout = Instance.new("UIListLayout")
	trLayout.FillDirection = Enum.FillDirection.Horizontal
	trLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	trLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	trLayout.Padding = UDim.new(0, 8)
	trLayout.Parent = topRight

	-- Locker / Shop Button
	local lockerBtn = Instance.new("TextButton")
	lockerBtn.Name = "LockerButton"
	lockerBtn.Size = UDim2.new(0, 78, 0, 36)
	lockerBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
	lockerBtn.Text = "⚡ LOCKER"
	lockerBtn.TextColor3 = Color3.fromRGB(250, 204, 21)
	lockerBtn.TextSize = 11
	lockerBtn.Font = Enum.Font.GothamBold
	lockerBtn.Parent = topRight
	Instance.new("UICorner", lockerBtn).CornerRadius = UDim.new(0, 10)
	local lStroke = Instance.new("UIStroke", lockerBtn)
	lStroke.Color = Color3.fromRGB(234, 179, 8)
	lStroke.Thickness = 1.5

	lockerBtn.MouseButton1Click:Connect(function()
		if HUDController._onLockerToggle then
			HUDController._onLockerToggle()
		end
	end)

	-- Role Badge
	local roleBadge = Instance.new("Frame")
	roleBadge.Name = "RoleBadge"
	roleBadge.Size = UDim2.new(0, 82, 0, 36)
	roleBadge.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
	roleBadge.BorderSizePixel = 0
	roleBadge.Parent = topRight
	Instance.new("UICorner", roleBadge).CornerRadius = UDim.new(0, 10)
	HUDController._roleBadge = roleBadge

	local roleLabel = Instance.new("TextLabel")
	roleLabel.Name = "RoleLabel"
	roleLabel.Size = UDim2.new(1, 0, 1, 0)
	roleLabel.BackgroundTransparency = 1
	roleLabel.Text = "RUNNER"
	roleLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	roleLabel.TextSize = 12
	roleLabel.Font = Enum.Font.GothamBlack
	roleLabel.Parent = roleBadge
	HUDController._roleLabel = roleLabel

	-- Gems Capsule
	local gemsCap = Instance.new("Frame")
	gemsCap.Name = "GemsCapsule"
	gemsCap.Size = UDim2.new(0, 72, 0, 36)
	gemsCap.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
	gemsCap.Parent = topRight
	Instance.new("UICorner", gemsCap).CornerRadius = UDim.new(0, 10)
	Instance.new("UIStroke", gemsCap).Color = Color3.fromRGB(63, 63, 70)

	local gemsLabel = Instance.new("TextLabel")
	gemsLabel.Name = "GemsLabel"
	gemsLabel.Size = UDim2.new(1, 0, 1, 0)
	gemsLabel.BackgroundTransparency = 1
	gemsLabel.Text = "💎 0"
	gemsLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
	gemsLabel.TextSize = 12
	gemsLabel.Font = Enum.Font.GothamBold
	gemsLabel.Parent = gemsCap
	HUDController._gemsLabel = gemsLabel

	-- Coins Capsule
	local coinsCap = Instance.new("Frame")
	coinsCap.Name = "CoinsCapsule"
	coinsCap.Size = UDim2.new(0, 72, 0, 36)
	coinsCap.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
	coinsCap.Parent = topRight
	Instance.new("UICorner", coinsCap).CornerRadius = UDim.new(0, 10)
	Instance.new("UIStroke", coinsCap).Color = Color3.fromRGB(63, 63, 70)

	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "CoinsLabel"
	coinsLabel.Size = UDim2.new(1, 0, 1, 0)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Text = "🪙 0"
	coinsLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	coinsLabel.TextSize = 12
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.Parent = coinsCap
	HUDController._coinsLabel = coinsLabel

	-- ── 3. BOTTOM LEFT: TACTICAL ABILITY CARD [Q] ──
	local abilityContainer = Instance.new("Frame")
	abilityContainer.Name = "AbilityContainer"
	abilityContainer.Size = UDim2.new(0, 96, 0, 116)
	abilityContainer.Position = UDim2.new(0, 24, 1, -24)
	abilityContainer.AnchorPoint = Vector2.new(0, 1)
	abilityContainer.BackgroundTransparency = 1
	abilityContainer.Parent = gui

	local aCard = Instance.new("Frame")
	aCard.Name = "AbilityCard"
	aCard.Size = UDim2.new(0, 80, 0, 80)
	aCard.Position = UDim2.new(0, 0, 0, 0)
	aCard.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	aCard.BorderSizePixel = 0
	aCard.Parent = abilityContainer
	Instance.new("UICorner", aCard).CornerRadius = UDim.new(0, 14)

	local aStroke = Instance.new("UIStroke")
	aStroke.Color = Color3.fromRGB(56, 189, 248)
	aStroke.Thickness = 2.5
	aStroke.Parent = aCard

	-- Keybind Pill [Q]
	local keyPill = Instance.new("Frame")
	keyPill.Name = "KeyPill"
	keyPill.Size = UDim2.new(0, 24, 0, 20)
	keyPill.Position = UDim2.new(0, 6, 0, 6)
	keyPill.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
	keyPill.Parent = aCard
	Instance.new("UICorner", keyPill).CornerRadius = UDim.new(0, 6)

	local keyText = Instance.new("TextLabel")
	keyText.Size = UDim2.new(1, 0, 1, 0)
	keyText.BackgroundTransparency = 1
	keyText.Text = "Q"
	keyText.TextColor3 = Color3.fromRGB(0, 0, 0)
	keyText.TextSize = 11
	keyText.Font = Enum.Font.GothamBlack
	keyText.Parent = keyPill

	-- Ability Icon
	local aIcon = Instance.new("ImageLabel")
	aIcon.Name = "AbilityIcon"
	aIcon.Size = UDim2.new(0, 48, 0, 48)
	aIcon.Position = UDim2.new(0.5, 0, 0.5, 2)
	aIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	aIcon.BackgroundTransparency = 1
	aIcon.Image = "rbxassetid://10709790387" -- Default Cloak Icon
	aIcon.Parent = aCard
	HUDController._abilityIcon = aIcon

	-- Cooldown Overlay
	local cdOverlay = Instance.new("Frame")
	cdOverlay.Name = "CooldownOverlay"
	cdOverlay.Size = UDim2.new(1, 0, 0, 0)
	cdOverlay.Position = UDim2.new(0, 0, 1, 0)
	cdOverlay.AnchorPoint = Vector2.new(0, 1)
	cdOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cdOverlay.BackgroundTransparency = 0.45
	cdOverlay.BorderSizePixel = 0
	cdOverlay.Parent = aCard
	Instance.new("UICorner", cdOverlay).CornerRadius = UDim.new(0, 14)
	HUDController._cooldownOverlay = cdOverlay

	local cdLabel = Instance.new("TextLabel")
	cdLabel.Name = "CooldownLabel"
	cdLabel.Size = UDim2.new(1, 0, 1, 0)
	cdLabel.Position = UDim2.new(0, 0, 0, 0)
	cdLabel.BackgroundTransparency = 1
	cdLabel.Text = ""
	cdLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	cdLabel.TextSize = 18
	cdLabel.Font = Enum.Font.GothamBlack
	cdLabel.Parent = aCard
	HUDController._cooldownLabel = cdLabel

	-- Ability Name Label
	local aName = Instance.new("TextLabel")
	aName.Name = "AbilityName"
	aName.Size = UDim2.new(1, 20, 0, 18)
	aName.Position = UDim2.new(0, 0, 0, 84)
	aName.BackgroundTransparency = 1
	aName.Text = "CLOAK"
	aName.TextColor3 = Color3.fromRGB(228, 228, 231)
	aName.TextSize = 11
	aName.Font = Enum.Font.GothamBold
	aName.TextXAlignment = Enum.TextXAlignment.Left
	aName.Parent = abilityContainer
	HUDController._abilityName = aName

	-- ── 4. BOTTOM CENTER: JUKE TECH & MOVEMENT GUIDE ──
	local tipsFrame = Instance.new("Frame")
	tipsFrame.Name = "MovementTips"
	tipsFrame.Size = UDim2.new(0, 480, 0, 36)
	tipsFrame.Position = UDim2.new(0.5, 0, 1, -20)
	tipsFrame.AnchorPoint = Vector2.new(0.5, 1)
	tipsFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	tipsFrame.BackgroundTransparency = 0.25
	tipsFrame.BorderSizePixel = 0
	tipsFrame.Parent = gui
	Instance.new("UICorner", tipsFrame).CornerRadius = UDim.new(0, 10)
	local tStroke = Instance.new("UIStroke", tipsFrame)
	tStroke.Color = Color3.fromRGB(63, 63, 70)
	tStroke.Thickness = 1

	local tipsLabel = Instance.new("TextLabel")
	tipsLabel.Size = UDim2.new(1, -20, 1, 0)
	tipsLabel.Position = UDim2.new(0, 10, 0, 0)
	tipsLabel.BackgroundTransparency = 1
	tipsLabel.Text = "⚡ [SPACE + A/D] Lateral Dash   •   🛑 [ALT] Instant Brake   •   🛹 [C] Slide"
	tipsLabel.TextColor3 = Color3.fromRGB(212, 212, 216)
	tipsLabel.TextSize = 11
	tipsLabel.Font = Enum.Font.GothamMedium
	tipsLabel.Parent = tipsFrame

	-- Dash recharge indicator line
	local dashBarBg = Instance.new("Frame")
	dashBarBg.Name = "DashBarBg"
	dashBarBg.Size = UDim2.new(1, 0, 0, 3)
	dashBarBg.Position = UDim2.new(0, 0, 1, -3)
	dashBarBg.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
	dashBarBg.BorderSizePixel = 0
	dashBarBg.Parent = tipsFrame

	local dashBar = Instance.new("Frame")
	dashBar.Name = "DashBar"
	dashBar.Size = UDim2.new(1, 0, 1, 0)
	dashBar.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
	dashBar.BorderSizePixel = 0
	dashBar.Parent = dashBarBg
	HUDController._dashBar = dashBar

	-- ── 5. DOWNED VIGNETTE & ALERT OVERLAY ──
	local downedVignette = Instance.new("Frame")
	downedVignette.Name = "DownedVignette"
	downedVignette.Size = UDim2.new(1, 0, 1, 0)
	downedVignette.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
	downedVignette.BackgroundTransparency = 1
	downedVignette.BorderSizePixel = 0
	downedVignette.Visible = false
	downedVignette.Parent = gui
	HUDController._downedVignette = downedVignette

	local downedMsg = Instance.new("TextLabel")
	downedMsg.Name = "DownedMessage"
	downedMsg.Size = UDim2.new(0, 560, 0, 60)
	downedMsg.Position = UDim2.new(0.5, 0, 0.72, 0)
	downedMsg.AnchorPoint = Vector2.new(0.5, 0.5)
	downedMsg.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	downedMsg.BackgroundTransparency = 0.1
	downedMsg.Text = "⚠️ YOU ARE DOWNED!\nWAIT FOR A TEAMMATE TO REVIVE YOU [HOLD E]"
	downedMsg.TextColor3 = Color3.fromRGB(248, 113, 113)
	downedMsg.TextSize = 16
	downedMsg.Font = Enum.Font.GothamBlack
	downedMsg.Parent = downedVignette
	Instance.new("UICorner", downedMsg).CornerRadius = UDim.new(0, 12)
	local dmStroke = Instance.new("UIStroke", downedMsg)
	dmStroke.Color = Color3.fromRGB(239, 68, 68)
	dmStroke.Thickness = 2.5

	print("  [HUDController] Tactical Pack HUD created ✓")
end

-- ============================================================
-- DATA SYNC
-- ============================================================
function HUDController.UpdateData(data: any)
	if not data then return end

	if HUDController._coinsLabel and data.Coins ~= nil then
		HUDController._coinsLabel.Text = `🪙 {formatNumber(data.Coins)}`
	end

	if HUDController._gemsLabel and data.Gems ~= nil then
		HUDController._gemsLabel.Text = `💎 {formatNumber(data.Gems)}`
	end

	if data.EquippedAbility then
		local def = AbilityData[data.EquippedAbility]
		if def then
			if HUDController._abilityIcon then
				HUDController._abilityIcon.Image = def.Icon
			end
			if HUDController._abilityName then
				HUDController._abilityName.Text = string.upper(def.Name)
			end
		end
	end
end

-- ============================================================
-- ROLE BADGE UPDATE
-- ============================================================
function HUDController.SetRole(role: string)
	HUDController._currentRole = role
	if not HUDController._roleBadge or not HUDController._roleLabel then return end

	if role == "Runner" then
		HUDController._roleBadge.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
		HUDController._roleLabel.Text = "RUNNER"
		HUDController._roleLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	elseif role == "Chaser" then
		HUDController._roleBadge.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
		HUDController._roleLabel.Text = "CHASER"
		HUDController._roleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	elseif role == "Downed" then
		HUDController._roleBadge.BackgroundColor3 = Color3.fromRGB(245, 158, 11)
		HUDController._roleLabel.Text = "DOWNED"
		HUDController._roleLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	else
		HUDController._roleBadge.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
		HUDController._roleLabel.Text = "SPECTATOR"
		HUDController._roleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

-- ============================================================
-- COOLDOWN ANIMATION [Q]
-- ============================================================
function HUDController.TriggerAbilityCooldown(duration: number)
	local overlay = HUDController._cooldownOverlay
	local label = HUDController._cooldownLabel
	if not overlay or not label then return end

	overlay.Size = UDim2.new(1, 0, 1, 0)
	label.Visible = true

	local startTime = os.clock()
	task.spawn(function()
		while true do
			local elapsed = os.clock() - startTime
			local rem = math.max(0, duration - elapsed)
			if rem <= 0 then break end

			overlay.Size = UDim2.new(1, 0, rem / duration, 0)
			label.Text = string.format("%.1fs", rem)
			task.wait(0.05)
		end

		overlay.Size = UDim2.new(1, 0, 0, 0)
		label.Text = ""
		label.Visible = false
	end)
end

-- ============================================================
-- DASH RECHARGE INDICATOR
-- ============================================================
function HUDController.TriggerDashCooldown(duration: number)
	local bar = HUDController._dashBar
	if not bar then return end

	bar.Size = UDim2.new(0, 0, 1, 0)
	local tween = TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(1, 0, 1, 0)
	})
	tween:Play()
end

-- ============================================================
-- DOWNED STATE TOGGLE
-- ============================================================
function HUDController.SetDownedState(isDowned: boolean)
	local vignette = HUDController._downedVignette
	if not vignette then return end

	vignette.Visible = isDowned
	if isDowned then
		HUDController.SetRole("Downed")
		-- Pulse vignette
		task.spawn(function()
			while vignette.Visible do
				TweenService:Create(vignette, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					BackgroundTransparency = 0.65
				}):Play()
				task.wait(0.6)
				if not vignette.Visible then break end
				TweenService:Create(vignette, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					BackgroundTransparency = 0.85
				}):Play()
				task.wait(0.6)
			end
		end)
	else
		vignette.BackgroundTransparency = 1
	end
end

function HUDController.SetLockerCallback(callback: () -> ())
	HUDController._onLockerToggle = callback
end

return HUDController
