--!strict
--[[
	VaultHUD.luau — Modern Tactical Military-Grade HUD for VAULT WARS
	Inspired by high-tier tactical & weapon showcase interfaces (Kekuzav & Tactical Build references):
	- Top Island: Monospace Net Worth, live income ticker (+ $XX/s), level badge & precision XP track
	- Left Dock: Tactical vertical pill navigation dock (Upgrades, Synthesis, Contracts, Mastery, Daily)
	- Bottom Stash Pill: Tactical unbanked cargo warning & safe deposit prompts
	- 100% Zero emoji spam, BuilderSansExtraBold & BuilderMono typography, contextual strokes
	Located in: StarterPlayerScripts.Client.UI.VaultHUD
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local player = Players.LocalPlayer
local VaultHUD = {}

VaultHUD._gui = nil :: ScreenGui?
VaultHUD._bankedLabel = nil :: TextLabel?
VaultHUD._incomeLabel = nil :: TextLabel?
VaultHUD._rankLabel = nil :: TextLabel?
VaultHUD._xpFill = nil :: Frame?
VaultHUD._tokensLabel = nil :: TextLabel?
VaultHUD._unbankedLabel = nil :: TextLabel?
VaultHUD._unbankedFrame = nil :: Frame?
VaultHUD._adrenalineBtn = nil :: TextButton?
VaultHUD._breachVignette = nil :: Frame?
VaultHUD._breachMsg = nil :: TextLabel?

VaultHUD._onUpgradesToggle = nil :: (() -> ())?
VaultHUD._onFusionToggle = nil :: (() -> ())?
VaultHUD._onDailyToggle = nil :: (() -> ())?
VaultHUD._onProgressToggle = nil :: (() -> ())?
VaultHUD._onContractsToggle = nil :: (() -> ())?

local function getSoundController(): any?
	local controllers = script.Parent.Parent:FindFirstChild("Controllers")
	local mod = controllers and controllers:FindFirstChild("SoundController")
	if mod then return require(mod :: ModuleScript) end
	return nil
end

local function formatCurrency(n: number): string
	n = math.floor(n or 0)
	if n >= 1e15 then return string.format("$%.2fQa", n / 1e15)
	elseif n >= 1e12 then return string.format("$%.2fT", n / 1e12)
	elseif n >= 1e9 then return string.format("$%.2fB", n / 1e9)
	elseif n >= 1e6 then return string.format("$%.2fM", n / 1e6)
	elseif n >= 1e3 then return string.format("$%.1fK", n / 1e3)
	else return "$" .. tostring(n) end
end

local function applyTacticalPillHover(btn: TextButton, stroke: UIStroke, accentColor: Color3)
	local scale = btn:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = btn
	end

	btn.MouseEnter:Connect(function()
		local snd = getSoundController()
		if snd and snd.Play then snd.Play("ButtonHover") end

		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
		TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			BackgroundColor3 = Color3.fromRGB(26, 32, 48),
			BackgroundTransparency = 0.05,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			Thickness = 1.6,
			Color = accentColor,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Scale = 1.0 }):Play()
		TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
			BackgroundColor3 = Color3.fromRGB(15, 17, 26),
			BackgroundTransparency = 0.18,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
			Thickness = 1.0,
			Color = Color3.fromRGB(42, 52, 70),
		}):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06, Enum.EasingStyle.Quad), { Scale = 0.95 }):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		local snd = getSoundController()
		if snd and snd.Play then snd.Play("ButtonClick") end
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
	end)
end

function VaultHUD.Create()
	local pGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
	if not pGui then return end

	local existing = pGui:FindFirstChild("VaultWarsHUD")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "VaultWarsHUD"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = true
	gui.Parent = pGui
	VaultHUD._gui = gui

	-- ============================================================
	-- 1. TOP CENTER: TACTICAL COMMAND ISLAND
	-- ============================================================
	local topIsland = Instance.new("Frame")
	topIsland.Name = "TopTacticalIsland"
	topIsland.Size = UDim2.new(0, 580, 0, 52)
	topIsland.Position = UDim2.new(0.5, 0, 0, 16)
	topIsland.AnchorPoint = Vector2.new(0.5, 0)
	topIsland.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	topIsland.BackgroundTransparency = 0.12
	topIsland.BorderSizePixel = 0
	topIsland.Parent = gui

	local tiCorner = Instance.new("UICorner")
	tiCorner.CornerRadius = UDim.new(0, 12)
	tiCorner.Parent = topIsland

	local tiStroke = Instance.new("UIStroke")
	tiStroke.Color = Color3.fromRGB(42, 52, 70)
	tiStroke.Thickness = 1.2
	tiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tiStroke.Parent = topIsland

	-- 1.1. Left: Rank & XP Progress Block
	local rankBox = Instance.new("Frame")
	rankBox.Name = "RankBox"
	rankBox.Size = UDim2.new(0, 130, 0, 38)
	rankBox.Position = UDim2.new(0, 10, 0.5, -19)
	rankBox.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	rankBox.BorderSizePixel = 0
	rankBox.Parent = topIsland

	local rbCorner = Instance.new("UICorner")
	rbCorner.CornerRadius = UDim.new(0, 8)
	rbCorner.Parent = rankBox

	local rbStroke = Instance.new("UIStroke")
	rbStroke.Color = Color3.fromRGB(56, 189, 248)
	rbStroke.Thickness = 1.0
	rbStroke.Parent = rankBox

	local rankLbl = Instance.new("TextLabel")
	rankLbl.Name = "RankLabel"
	rankLbl.Size = UDim2.new(1, 0, 0, 20)
	rankLbl.Position = UDim2.new(0, 0, 0, 2)
	rankLbl.BackgroundTransparency = 1
	rankLbl.Text = "LV. 1 RECRUIT"
	rankLbl.TextColor3 = Color3.fromRGB(56, 189, 248)
	rankLbl.TextSize = 11
	rankLbl.Font = Enum.Font.BuilderSansExtraBold
	rankLbl.TextXAlignment = Enum.TextXAlignment.Center
	rankLbl.Parent = rankBox
	VaultHUD._rankLabel = rankLbl

	-- Precision XP Track
	local xpBg = Instance.new("Frame")
	xpBg.Name = "XPTrackBg"
	xpBg.Size = UDim2.new(1, -16, 0, 4)
	xpBg.Position = UDim2.new(0, 8, 0, 26)
	xpBg.BackgroundColor3 = Color3.fromRGB(11, 13, 20)
	xpBg.BorderSizePixel = 0
	xpBg.Parent = rankBox

	local xpBgCorner = Instance.new("UICorner")
	xpBgCorner.CornerRadius = UDim.new(1, 0)
	xpBgCorner.Parent = xpBg

	local xpFill = Instance.new("Frame")
	xpFill.Name = "XPTrackFill"
	xpFill.Size = UDim2.fromScale(0.15, 1)
	xpFill.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpBg

	local xpFillCorner = Instance.new("UICorner")
	xpFillCorner.CornerRadius = UDim.new(1, 0)
	xpFillCorner.Parent = xpFill
	VaultHUD._xpFill = xpFill

	-- 1.2. Center: Net Worth Monospace Block
	local netWorthBox = Instance.new("Frame")
	netWorthBox.Name = "NetWorthBox"
	netWorthBox.Size = UDim2.new(0, 190, 1, 0)
	netWorthBox.Position = UDim2.new(0.5, -95, 0, 0)
	netWorthBox.BackgroundTransparency = 1
	netWorthBox.Parent = topIsland

	local bankedLabel = Instance.new("TextLabel")
	bankedLabel.Name = "BankedNetWorth"
	bankedLabel.Size = UDim2.new(1, 0, 0, 26)
	bankedLabel.Position = UDim2.new(0, 0, 0, 6)
	bankedLabel.BackgroundTransparency = 1
	bankedLabel.Text = "$0"
	bankedLabel.TextColor3 = Color3.fromRGB(248, 250, 252)
	bankedLabel.TextSize = 22
	bankedLabel.Font = Enum.Font.RobotoMono
	bankedLabel.TextXAlignment = Enum.TextXAlignment.Center
	bankedLabel.Parent = netWorthBox
	VaultHUD._bankedLabel = bankedLabel

	local netWorthSub = Instance.new("TextLabel")
	netWorthSub.Size = UDim2.new(1, 0, 0, 12)
	netWorthSub.Position = UDim2.new(0, 0, 0, 32)
	netWorthSub.BackgroundTransparency = 1
	netWorthSub.Text = "NET WORTH"
	netWorthSub.TextColor3 = Color3.fromRGB(148, 163, 184)
	netWorthSub.TextSize = 9
	netWorthSub.Font = Enum.Font.BuilderSansBold
	netWorthSub.TextXAlignment = Enum.TextXAlignment.Center
	netWorthSub.Parent = netWorthBox

	-- 1.3. Right: Live Income Pill (Sage Green)
	local incomePill = Instance.new("Frame")
	incomePill.Name = "IncomePill"
	incomePill.Size = UDim2.new(0, 105, 0, 38)
	incomePill.Position = UDim2.new(1, -225, 0.5, -19)
	incomePill.BackgroundColor3 = Color3.fromRGB(18, 32, 24)
	incomePill.BorderSizePixel = 0
	incomePill.Parent = topIsland

	local ipCorner = Instance.new("UICorner")
	ipCorner.CornerRadius = UDim.new(0, 8)
	ipCorner.Parent = incomePill

	local ipStroke = Instance.new("UIStroke")
	ipStroke.Color = Color3.fromRGB(74, 124, 89)
	ipStroke.Thickness = 1.0
	ipStroke.Parent = incomePill

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeRate"
	incomeLabel.Size = UDim2.new(1, 0, 1, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = "+$5/s"
	incomeLabel.TextColor3 = Color3.fromRGB(110, 231, 183)
	incomeLabel.TextSize = 12
	incomeLabel.Font = Enum.Font.RobotoMono
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Center
	incomeLabel.Parent = incomePill
	VaultHUD._incomeLabel = incomeLabel

	-- 1.4. Far Right: Syndicate Tokens Pill (Amber)
	local tokenPill = Instance.new("Frame")
	tokenPill.Name = "TokenPill"
	tokenPill.Size = UDim2.new(0, 105, 0, 38)
	tokenPill.Position = UDim2.new(1, -115, 0.5, -19)
	tokenPill.BackgroundColor3 = Color3.fromRGB(36, 28, 18)
	tokenPill.BorderSizePixel = 0
	tokenPill.Parent = topIsland

	local tpCorner = Instance.new("UICorner")
	tpCorner.CornerRadius = UDim.new(0, 8)
	tpCorner.Parent = tokenPill

	local tpStroke = Instance.new("UIStroke")
	tpStroke.Color = Color3.fromRGB(245, 158, 11)
	tpStroke.Thickness = 1.0
	tpStroke.Parent = tokenPill

	local tokenLabel = Instance.new("TextLabel")
	tokenLabel.Name = "TokensLabel"
	tokenLabel.Size = UDim2.new(1, 0, 1, 0)
	tokenLabel.BackgroundTransparency = 1
	tokenLabel.Text = "0 TOKENS"
	tokenLabel.TextColor3 = Color3.fromRGB(254, 240, 138)
	tokenLabel.TextSize = 11
	tokenLabel.Font = Enum.Font.BuilderSansBold
	tokenLabel.TextXAlignment = Enum.TextXAlignment.Center
	tokenLabel.Parent = tokenPill
	VaultHUD._tokensLabel = tokenLabel

	-- ============================================================
	-- 2. LEFT DOCK: TACTICAL NAVIGATION BAR
	-- ============================================================
	local leftDock = Instance.new("Frame")
	leftDock.Name = "LeftTacticalDock"
	leftDock.Size = UDim2.new(0, 120, 0, 290)
	leftDock.Position = UDim2.new(0, 18, 0.5, 0)
	leftDock.AnchorPoint = Vector2.new(0, 0.5)
	leftDock.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	leftDock.BackgroundTransparency = 0.2
	leftDock.BorderSizePixel = 0
	leftDock.Parent = gui

	local ldCorner = Instance.new("UICorner")
	ldCorner.CornerRadius = UDim.new(0, 14)
	ldCorner.Parent = leftDock

	local ldStroke = Instance.new("UIStroke")
	ldStroke.Color = Color3.fromRGB(42, 52, 70)
	ldStroke.Thickness = 1.2
	ldStroke.Parent = leftDock

	local dockLayout = Instance.new("UIListLayout")
	dockLayout.FillDirection = Enum.FillDirection.Vertical
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dockLayout.Padding = UDim.new(0, 8)
	dockLayout.Parent = leftDock

	local function createDockPill(name: string, labelText: string, keyText: string, accentColor: Color3, onClick: () -> ()): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, 104, 0, 46)
		btn.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
		btn.BackgroundTransparency = 0.18
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = leftDock

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 8)
		bCorner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(42, 52, 70)
		stroke.Thickness = 1.0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn

		-- Accent Left Indicator Strip
		local indicator = Instance.new("Frame")
		indicator.Name = "ActiveIndicator"
		indicator.Size = UDim2.new(0, 3, 0.6, 0)
		indicator.Position = UDim2.new(0, 6, 0.2, 0)
		indicator.BackgroundColor3 = accentColor
		indicator.BorderSizePixel = 0
		indicator.Parent = btn

		local indCorner = Instance.new("UICorner")
		indCorner.CornerRadius = UDim.new(1, 0)
		indCorner.Parent = indicator

		-- Title
		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -20, 0, 16)
		titleLbl.Position = UDim2.new(0, 16, 0, 7)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = string.upper(labelText)
		titleLbl.TextColor3 = Color3.fromRGB(248, 250, 252)
		titleLbl.TextSize = 11
		titleLbl.Font = Enum.Font.BuilderSansExtraBold
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.Parent = btn

		-- Keybind Tag
		local keyLbl = Instance.new("TextLabel")
		keyLbl.Size = UDim2.new(1, -20, 0, 12)
		keyLbl.Position = UDim2.new(0, 16, 0, 25)
		keyLbl.BackgroundTransparency = 1
		keyLbl.Text = keyText
		keyLbl.TextColor3 = accentColor
		keyLbl.TextSize = 9
		keyLbl.Font = Enum.Font.RobotoMono
		keyLbl.TextXAlignment = Enum.TextXAlignment.Left
		keyLbl.Parent = btn

		applyTacticalPillHover(btn, stroke, accentColor)
		btn.MouseButton1Click:Connect(onClick)
		return btn
	end

	createDockPill("UpgradesTile", "UPGRADES", "[U]", Color3.fromRGB(56, 189, 248), function()
		if VaultHUD._onUpgradesToggle then VaultHUD._onUpgradesToggle() end
	end)

	createDockPill("FusionTile", "SYNTHESIS", "[B]", Color3.fromRGB(168, 85, 247), function()
		if VaultHUD._onFusionToggle then VaultHUD._onFusionToggle() end
	end)

	createDockPill("ContractsTile", "CONTRACTS", "[C]", Color3.fromRGB(245, 158, 11), function()
		if VaultHUD._onContractsToggle then VaultHUD._onContractsToggle() end
	end)

	createDockPill("ProgressTile", "MASTERY", "[P]", Color3.fromRGB(250, 204, 21), function()
		if VaultHUD._onProgressToggle then VaultHUD._onProgressToggle() end
	end)

	createDockPill("DailyTile", "DAILY", "[Y]", Color3.fromRGB(16, 185, 129), function()
		if VaultHUD._onDailyToggle then VaultHUD._onDailyToggle() end
	end)

	-- ============================================================
	-- 3. BOTTOM CENTER: UNBANKED STASH ALERT
	-- ============================================================
	local unbankedFrame = Instance.new("Frame")
	unbankedFrame.Name = "UnbankedFrame"
	unbankedFrame.Size = UDim2.new(0, 520, 0, 38)
	unbankedFrame.Position = UDim2.new(0.5, 0, 1, -24)
	unbankedFrame.AnchorPoint = Vector2.new(0.5, 1)
	unbankedFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	unbankedFrame.BackgroundTransparency = 0.1
	unbankedFrame.BorderSizePixel = 0
	unbankedFrame.Visible = false
	unbankedFrame.Parent = gui

	local ubCorner = Instance.new("UICorner")
	ubCorner.CornerRadius = UDim.new(0, 10)
	ubCorner.Parent = unbankedFrame

	local ubStroke = Instance.new("UIStroke")
	ubStroke.Color = Color3.fromRGB(245, 158, 11)
	ubStroke.Thickness = 1.5
	ubStroke.Parent = unbankedFrame
	VaultHUD._unbankedFrame = unbankedFrame

	local ubLabel = Instance.new("TextLabel")
	ubLabel.Name = "UnbankedLabel"
	ubLabel.Size = UDim2.fromScale(1, 1)
	ubLabel.BackgroundTransparency = 1
	ubLabel.Text = "UNBANKED STASH: $0 — RETURN TO GREEN SAFE PAD TO SECURE"
	ubLabel.TextColor3 = Color3.fromRGB(254, 240, 138)
	ubLabel.TextSize = 11
	ubLabel.Font = Enum.Font.BuilderSansExtraBold
	ubLabel.Parent = unbankedFrame
	VaultHUD._unbankedLabel = ubLabel

	-- ============================================================
	-- 3.5. ADRENALINE ESCAPE SURGE BUTTON (WHEN HEISTING)
	-- ============================================================
	local adrenalineBtn = Instance.new("TextButton")
	adrenalineBtn.Name = "AdrenalineSurgeButton"
	adrenalineBtn.Size = UDim2.new(0, 420, 0, 42)
	adrenalineBtn.Position = UDim2.new(0.5, 0, 1, -80)
	adrenalineBtn.AnchorPoint = Vector2.new(0.5, 1)
	adrenalineBtn.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	adrenalineBtn.BorderSizePixel = 0
	adrenalineBtn.Text = "ADRENALINE SURGE (25 R$) — +65% ESCAPE SPEED"
	adrenalineBtn.TextColor3 = Color3.fromRGB(250, 204, 21)
	adrenalineBtn.TextSize = 12
	adrenalineBtn.Font = Enum.Font.BuilderSansExtraBold
	adrenalineBtn.Visible = false
	adrenalineBtn.Parent = gui

	local adCorner = Instance.new("UICorner")
	adCorner.CornerRadius = UDim.new(0, 10)
	adCorner.Parent = adrenalineBtn

	local adStroke = Instance.new("UIStroke")
	adStroke.Color = Color3.fromRGB(250, 204, 21)
	adStroke.Thickness = 1.8
	adStroke.Parent = adrenalineBtn
	VaultHUD._adrenalineBtn = adrenalineBtn

	adrenalineBtn.MouseButton1Click:Connect(function()
		local pId = Config.Monetization.DevProducts.AdrenalineSurge.Id
		if pId and pId > 0 then
			MarketplaceService:PromptProductPurchase(player, pId)
		else
			adrenalineBtn.Text = "ADRENALINE BOOST ACTIVE"
			task.delay(1.5, function()
				if adrenalineBtn and adrenalineBtn.Parent then
					adrenalineBtn.Text = "ADRENALINE SURGE (25 R$) — +65% ESCAPE SPEED"
				end
			end)
		end
	end)

	-- ============================================================
	-- 4. SECURITY BREACH VIGNETTE
	-- ============================================================
	local breachVignette = Instance.new("Frame")
	breachVignette.Name = "BreachVignette"
	breachVignette.Size = UDim2.fromScale(1, 1)
	breachVignette.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
	breachVignette.BackgroundTransparency = 1
	breachVignette.BorderSizePixel = 0
	breachVignette.Visible = false
	breachVignette.Parent = gui
	VaultHUD._breachVignette = breachVignette

	local breachMsg = Instance.new("TextLabel")
	breachMsg.Name = "BreachMessage"
	breachMsg.Size = UDim2.new(0, 520, 0, 54)
	breachMsg.Position = UDim2.new(0.5, 0, 0.22, 0)
	breachMsg.AnchorPoint = Vector2.new(0.5, 0.5)
	breachMsg.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	breachMsg.BackgroundTransparency = 0.05
	breachMsg.Text = "SECURITY BREACH — INTRUDER INSIDE YOUR VAULT"
	breachMsg.TextColor3 = Color3.fromRGB(248, 113, 113)
	breachMsg.TextSize = 14
	breachMsg.Font = Enum.Font.BuilderSansExtraBold
	breachMsg.Parent = breachVignette

	local bmCorner = Instance.new("UICorner")
	bmCorner.CornerRadius = UDim.new(0, 10)
	bmCorner.Parent = breachMsg

	local bmStroke = Instance.new("UIStroke")
	bmStroke.Color = Color3.fromRGB(239, 68, 68)
	bmStroke.Thickness = 2.0
	bmStroke.Parent = breachMsg
	VaultHUD._breachMsg = breachMsg

	print("  [VaultHUD] Modern Tactical HUD mounted ✓")
end

-- ============================================================
-- UPDATE HUD FROM PLAYER DATA
-- ============================================================
function VaultHUD.Update(data: Types.PlayerData)
	if not data then return end

	if VaultHUD._bankedLabel then
		VaultHUD._bankedLabel.Text = formatCurrency(data.BankedCash)
	end

	if VaultHUD._incomeLabel then
		local rate = Config.Economy.GetConveyorIncome(data.ConveyorLevel, data.PrestigeTokens)
		VaultHUD._incomeLabel.Text = `+{formatCurrency(rate)}/s`
	end

	if VaultHUD._rankLabel then
		local level = data.Level or 1
		local rankTitle = "RECRUIT"
		if level >= 25 then rankTitle = "OVERLORD"
		elseif level >= 15 then rankTitle = "MASTERMIND"
		elseif level >= 8 then rankTitle = "ENFORCER"
		elseif level >= 4 then rankTitle = "OPERATIVE" end

		VaultHUD._rankLabel.Text = `LV. {level} {rankTitle}`
	end

	if VaultHUD._xpFill then
		local level = data.Level or 1
		local currentXP = data.XP or 0
		local reqXP = Config.Progression.GetRequiredXP(level)
		local frac = math.clamp(currentXP / math.max(1, reqXP), 0.05, 1.0)
		TweenService:Create(VaultHUD._xpFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(frac, 1) }):Play()
	end

	if VaultHUD._tokensLabel then
		local tk = data.SyndicateTokens or 0
		VaultHUD._tokensLabel.Text = `{tk} TOKENS`
	end

	if VaultHUD._unbankedFrame and VaultHUD._unbankedLabel then
		local unbanked = data.UnbankedCash or 0
		if unbanked > 0 then
			VaultHUD._unbankedFrame.Visible = true
			VaultHUD._unbankedLabel.Text = `UNBANKED STASH: {formatCurrency(unbanked)} — RETURN TO GREEN SAFE PAD TO SECURE`
		else
			VaultHUD._unbankedFrame.Visible = false
		end
	end
end

-- ============================================================
-- CALLBACK HOOKS & BREACH ALERT
-- ============================================================
function VaultHUD.SetUpgradesCallback(callback: () -> ())
	VaultHUD._onUpgradesToggle = callback
end

function VaultHUD.SetFusionCallback(callback: () -> ())
	VaultHUD._onFusionToggle = callback
end

function VaultHUD.SetDailyCallback(callback: () -> ())
	VaultHUD._onDailyToggle = callback
end

function VaultHUD.SetProgressCallback(callback: () -> ())
	VaultHUD._onProgressToggle = callback
end

function VaultHUD.SetContractsCallback(callback: () -> ())
	VaultHUD._onContractsToggle = callback
end

function VaultHUD.ShowBreachAlert(intruderName: string)
	local vignette = VaultHUD._breachVignette
	local msg = VaultHUD._breachMsg
	if not vignette or not msg then return end

	msg.Text = `SECURITY BREACH — {string.upper(intruderName)} IS IN YOUR VAULT`
	vignette.Visible = true

	task.spawn(function()
		for _ = 1, 6 do
			TweenService:Create(vignette, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {
				BackgroundTransparency = 0.65
			}):Play()
			task.wait(0.4)
			TweenService:Create(vignette, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {
				BackgroundTransparency = 0.95
			}):Play()
			task.wait(0.4)
		end
		vignette.Visible = false
	end)
end

function VaultHUD.SetCarryingState(isCarrying: boolean, payload: any?)
	if VaultHUD._adrenalineBtn then
		VaultHUD._adrenalineBtn.Visible = isCarrying
		if isCarrying and payload and payload.Name then
			VaultHUD._adrenalineBtn.Text = `ADRENALINE SURGE — ESCAPE WITH {string.upper(tostring(payload.Name))}`
		else
			VaultHUD._adrenalineBtn.Text = "ADRENALINE SURGE (25 R$) — +65% ESCAPE SPEED"
		end
	end
end

return VaultHUD
