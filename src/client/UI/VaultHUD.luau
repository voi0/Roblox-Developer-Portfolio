--!strict
--[[
	VaultHUD.luau — Tactical 2026 Liquid Glass & Bento-Grid HUD for VAULT WARS
	Inspired by top 2025-2026 trending Roblox games (Fisch, Sol's RNG):
	- Top Status Island: Live Banked Net Worth, Live Income Rate, Level/XP Bar, Syndicate Tokens
	- Left-Docked Bento Action Bar: [U] Upgrades, [B] Fusion, [C] Contracts, [P] Progress, [Y] Daily
	- Bottom Stash Pill: Unbanked Cash alert & Safe Deposit guidance
	- Audio & Micro-Animations on every interaction
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

local function applyTileSpring(btn: TextButton, stroke: UIStroke, accentColor: Color3)
	local scale = btn:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = btn
	end

	btn.MouseEnter:Connect(function()
		local snd = getSoundController()
		if snd and snd.Play then snd.Play("ButtonHover") end

		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
		TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
			BackgroundColor3 = Color3.fromRGB(26, 32, 48),
			BackgroundTransparency = 0.1,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
			Thickness = 2.0,
			Color = accentColor,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Scale = 1.0 }):Play()
		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			BackgroundColor3 = Color3.fromRGB(15, 17, 26),
			BackgroundTransparency = 0.22,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Thickness = 1.2,
			Color = Color3.fromRGB(39, 45, 66),
		}):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 0.94 }):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		local snd = getSoundController()
		if snd and snd.Play then snd.Play("ButtonClick") end

		TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
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

	-- ── 1. TOP CENTER: BENTO STATUS ISLAND ──
	local topIsland = Instance.new("Frame")
	topIsland.Name = "TopStatusIsland"
	topIsland.Size = UDim2.new(0, 560, 0, 56)
	topIsland.Position = UDim2.new(0.5, 0, 0, 16)
	topIsland.AnchorPoint = Vector2.new(0.5, 0)
	topIsland.BackgroundColor3 = Color3.fromRGB(13, 16, 25)
	topIsland.BackgroundTransparency = 0.15
	topIsland.BorderSizePixel = 0
	topIsland.Parent = gui

	Instance.new("UICorner", topIsland).CornerRadius = UDim.new(0, 16)

	local tiStroke = Instance.new("UIStroke")
	tiStroke.Color = Color3.fromRGB(56, 189, 248)
	tiStroke.Thickness = 1.4
	tiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tiStroke.Parent = topIsland

	local tiGrad = Instance.new("UIGradient")
	tiGrad.Rotation = 90
	tiGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(28, 34, 52)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(13, 16, 25)),
	})
	tiGrad.Parent = topIsland

	-- 1.1. Left Badge: Level & Mini XP Bar
	local levelBox = Instance.new("Frame")
	levelBox.Name = "LevelBox"
	levelBox.Size = UDim2.new(0, 125, 0, 40)
	levelBox.Position = UDim2.new(0, 10, 0.5, -20)
	levelBox.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
	levelBox.BorderSizePixel = 0
	levelBox.Parent = topIsland
	Instance.new("UICorner", levelBox).CornerRadius = UDim.new(0, 10)
	local lbStroke = Instance.new("UIStroke", levelBox)
	lbStroke.Color = Color3.fromRGB(56, 189, 248)
	lbStroke.Thickness = 1.0

	local rankLbl = Instance.new("TextLabel")
	rankLbl.Size = UDim2.new(1, 0, 0, 22)
	rankLbl.Position = UDim2.new(0, 0, 0, 2)
	rankLbl.BackgroundTransparency = 1
	rankLbl.Text = "⚔️ LV. 1 RECRUIT"
	rankLbl.TextColor3 = Color3.fromRGB(56, 189, 248)
	rankLbl.TextSize = 11
	rankLbl.Font = Enum.Font.GothamBlack
	rankLbl.TextXAlignment = Enum.TextXAlignment.Center
	rankLbl.Parent = levelBox
	VaultHUD._rankLabel = rankLbl

	-- Mini XP Bar
	local xpBg = Instance.new("Frame")
	xpBg.Name = "MiniXPBarBg"
	xpBg.Size = UDim2.new(1, -16, 0, 5)
	xpBg.Position = UDim2.new(0, 8, 0, 28)
	xpBg.BackgroundColor3 = Color3.fromRGB(11, 13, 20)
	xpBg.BorderSizePixel = 0
	xpBg.Parent = levelBox
	Instance.new("UICorner", xpBg).CornerRadius = UDim.new(1, 0)

	local xpFill = Instance.new("Frame")
	xpFill.Name = "MiniXPBarFill"
	xpFill.Size = UDim2.fromScale(0.15, 1)
	xpFill.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpBg
	Instance.new("UICorner", xpFill).CornerRadius = UDim.new(1, 0)
	VaultHUD._xpFill = xpFill

	-- 1.2. Center: Banked Net Worth
	local bankedBox = Instance.new("Frame")
	bankedBox.Name = "BankedNetWorthBox"
	bankedBox.Size = UDim2.new(0, 190, 1, 0)
	bankedBox.Position = UDim2.new(0.5, -95, 0, 0)
	bankedBox.BackgroundTransparency = 1
	bankedBox.Parent = topIsland

	local bankedLabel = Instance.new("TextLabel")
	bankedLabel.Name = "BankedNetWorth"
	bankedLabel.Size = UDim2.new(1, 0, 0, 30)
	bankedLabel.Position = UDim2.new(0, 0, 0, 6)
	bankedLabel.BackgroundTransparency = 1
	bankedLabel.Text = "$0"
	bankedLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	bankedLabel.TextSize = 25
	bankedLabel.Font = Enum.Font.GothamBlack
	bankedLabel.TextXAlignment = Enum.TextXAlignment.Center
	bankedLabel.Parent = bankedBox
	VaultHUD._bankedLabel = bankedLabel

	local netWorthSub = Instance.new("TextLabel")
	netWorthSub.Size = UDim2.new(1, 0, 0, 14)
	netWorthSub.Position = UDim2.new(0, 0, 0, 36)
	netWorthSub.BackgroundTransparency = 1
	netWorthSub.Text = "BANKED NET WORTH"
	netWorthSub.TextColor3 = Color3.fromRGB(148, 163, 184)
	netWorthSub.TextSize = 9
	netWorthSub.Font = Enum.Font.GothamBold
	netWorthSub.TextXAlignment = Enum.TextXAlignment.Center
	netWorthSub.Parent = bankedBox

	-- 1.3. Right: Live Income Ticker Pill
	local incomePill = Instance.new("Frame")
	incomePill.Name = "IncomePill"
	incomePill.Size = UDim2.new(0, 105, 0, 40)
	incomePill.Position = UDim2.new(1, -215, 0.5, -20)
	incomePill.BackgroundColor3 = Color3.fromRGB(16, 38, 30)
	incomePill.BorderSizePixel = 0
	incomePill.Parent = topIsland
	Instance.new("UICorner", incomePill).CornerRadius = UDim.new(0, 10)
	local ipStroke = Instance.new("UIStroke", incomePill)
	ipStroke.Color = Color3.fromRGB(16, 185, 129)
	ipStroke.Thickness = 1.0

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeRate"
	incomeLabel.Size = UDim2.new(1, 0, 1, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = "▲ +$5/s"
	incomeLabel.TextColor3 = Color3.fromRGB(110, 231, 183)
	incomeLabel.TextSize = 12
	incomeLabel.Font = Enum.Font.GothamBlack
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Center
	incomeLabel.Parent = incomePill
	VaultHUD._incomeLabel = incomeLabel

	-- 1.4. Far Right: Syndicate Tokens Pill
	local tokenPill = Instance.new("Frame")
	tokenPill.Name = "TokenPill"
	tokenPill.Size = UDim2.new(0, 95, 0, 40)
	tokenPill.Position = UDim2.new(1, -105, 0.5, -20)
	tokenPill.BackgroundColor3 = Color3.fromRGB(38, 28, 16)
	tokenPill.BorderSizePixel = 0
	tokenPill.Parent = topIsland
	Instance.new("UICorner", tokenPill).CornerRadius = UDim.new(0, 10)
	local tkStroke = Instance.new("UIStroke", tokenPill)
	tkStroke.Color = Color3.fromRGB(245, 158, 11)
	tkStroke.Thickness = 1.0

	local tokenLabel = Instance.new("TextLabel")
	tokenLabel.Name = "TokensLabel"
	tokenLabel.Size = UDim2.new(1, 0, 1, 0)
	tokenLabel.BackgroundTransparency = 1
	tokenLabel.Text = "⚡ 0 TK"
	tokenLabel.TextColor3 = Color3.fromRGB(254, 240, 138)
	tokenLabel.TextSize = 12
	tokenLabel.Font = Enum.Font.GothamBlack
	tokenLabel.TextXAlignment = Enum.TextXAlignment.Center
	tokenLabel.Parent = tokenPill
	VaultHUD._tokensLabel = tokenLabel

	-- ── 2. LEFT-DOCKED BENTO NAVIGATION BAR (Never overlaps top bar!) ──
	local leftDock = Instance.new("Frame")
	leftDock.Name = "LeftBentoActionDock"
	leftDock.Size = UDim2.new(0, 72, 0, 316)
	leftDock.Position = UDim2.new(0, 18, 0.5, 0)
	leftDock.AnchorPoint = Vector2.new(0, 0.5)
	leftDock.BackgroundColor3 = Color3.fromRGB(13, 16, 25)
	leftDock.BackgroundTransparency = 0.25
	leftDock.BorderSizePixel = 0
	leftDock.Parent = gui

	Instance.new("UICorner", leftDock).CornerRadius = UDim.new(0, 18)
	local ldStroke = Instance.new("UIStroke", leftDock)
	ldStroke.Color = Color3.fromRGB(39, 45, 66)
	ldStroke.Thickness = 1.4

	local dockLayout = Instance.new("UIListLayout")
	dockLayout.FillDirection = Enum.FillDirection.Vertical
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dockLayout.Padding = UDim.new(0, 8)
	dockLayout.Parent = leftDock

	local function createDockTile(name: string, iconText: string, labelText: string, keyText: string, accentColor: Color3, onClick: () -> ()): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, 60, 0, 52)
		btn.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
		btn.BackgroundTransparency = 0.22
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = leftDock

		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
		local stroke = Instance.new("UIStroke", btn)
		stroke.Color = Color3.fromRGB(39, 45, 66)
		stroke.Thickness = 1.2

		-- Icon
		local iconLbl = Instance.new("TextLabel")
		iconLbl.Size = UDim2.new(1, 0, 0, 22)
		iconLbl.Position = UDim2.new(0, 0, 0, 4)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Text = iconText
		iconLbl.TextSize = 16
		iconLbl.Font = Enum.Font.GothamBlack
		iconLbl.Parent = btn

		-- Title
		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, 0, 0, 12)
		titleLbl.Position = UDim2.new(0, 0, 0, 26)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = labelText
		titleLbl.TextColor3 = accentColor
		titleLbl.TextSize = 9
		titleLbl.Font = Enum.Font.GothamBlack
		titleLbl.Parent = btn

		-- Keybind pill badge
		local keyLbl = Instance.new("TextLabel")
		keyLbl.Size = UDim2.new(1, 0, 0, 10)
		keyLbl.Position = UDim2.new(0, 0, 0, 38)
		keyLbl.BackgroundTransparency = 1
		keyLbl.Text = keyText
		keyLbl.TextColor3 = Color3.fromRGB(148, 163, 184)
		keyLbl.TextSize = 8
		keyLbl.Font = Enum.Font.GothamBold
		keyLbl.Parent = btn

		applyTileSpring(btn, stroke, accentColor)
		btn.MouseButton1Click:Connect(onClick)
		return btn
	end

	createDockTile("UpgradesTile", "⚡", "UPGRADE", "[U]", Color3.fromRGB(56, 189, 248), function()
		if VaultHUD._onUpgradesToggle then VaultHUD._onUpgradesToggle() end
	end)

	createDockTile("FusionTile", "🔮", "FUSION", "[B]", Color3.fromRGB(168, 85, 247), function()
		if VaultHUD._onFusionToggle then VaultHUD._onFusionToggle() end
	end)

	createDockTile("ContractsTile", "📜", "BOUNTY", "[C]", Color3.fromRGB(245, 158, 11), function()
		if VaultHUD._onContractsToggle then VaultHUD._onContractsToggle() end
	end)

	createDockTile("ProgressTile", "🌟", "MASTERY", "[P]", Color3.fromRGB(250, 204, 21), function()
		if VaultHUD._onProgressToggle then VaultHUD._onProgressToggle() end
	end)

	createDockTile("DailyTile", "📅", "DAILY", "[Y]", Color3.fromRGB(16, 185, 129), function()
		if VaultHUD._onDailyToggle then VaultHUD._onDailyToggle() end
	end)

	-- ── 3. BOTTOM CENTER: UNBANKED STASH ALERT PILL ──
	local unbankedFrame = Instance.new("Frame")
	unbankedFrame.Name = "UnbankedFrame"
	unbankedFrame.Size = UDim2.new(0, 480, 0, 40)
	unbankedFrame.Position = UDim2.new(0.5, 0, 1, -26)
	unbankedFrame.AnchorPoint = Vector2.new(0.5, 1)
	unbankedFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	unbankedFrame.BackgroundTransparency = 0.12
	unbankedFrame.BorderSizePixel = 0
	unbankedFrame.Visible = false
	unbankedFrame.Parent = gui

	Instance.new("UICorner", unbankedFrame).CornerRadius = UDim.new(0, 12)
	local ubStroke = Instance.new("UIStroke", unbankedFrame)
	ubStroke.Color = Color3.fromRGB(245, 158, 11)
	ubStroke.Thickness = 2.0
	VaultHUD._unbankedFrame = unbankedFrame

	local ubLabel = Instance.new("TextLabel")
	ubLabel.Name = "UnbankedLabel"
	ubLabel.Size = UDim2.fromScale(1, 1)
	ubLabel.BackgroundTransparency = 1
	ubLabel.Text = "⚠️ UNBANKED: $0 — STEP ON GREEN SAFE PAD TO BANK!"
	ubLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	ubLabel.TextSize = 12
	ubLabel.Font = Enum.Font.GothamBlack
	ubLabel.Parent = unbankedFrame
	VaultHUD._unbankedLabel = ubLabel

	-- ── 3.5. ADRENALINE IMPULSE ESCAPE PILL (WHEN HEISTING) ──
	local adrenalineBtn = Instance.new("TextButton")
	adrenalineBtn.Name = "AdrenalineSurgeButton"
	adrenalineBtn.Size = UDim2.new(0, 420, 0, 44)
	adrenalineBtn.Position = UDim2.new(0.5, 0, 1, -114)
	adrenalineBtn.AnchorPoint = Vector2.new(0.5, 1)
	adrenalineBtn.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	adrenalineBtn.BorderSizePixel = 0
	adrenalineBtn.Text = "⚡ ADRENALINE SURGE (25 R$) — +65% ESCAPE SPEED!"
	adrenalineBtn.TextColor3 = Color3.fromRGB(250, 204, 21)
	adrenalineBtn.TextSize = 12
	adrenalineBtn.Font = Enum.Font.GothamBlack
	adrenalineBtn.Visible = false
	adrenalineBtn.Parent = gui
	Instance.new("UICorner", adrenalineBtn).CornerRadius = UDim.new(0, 12)

	local adStroke = Instance.new("UIStroke", adrenalineBtn)
	adStroke.Color = Color3.fromRGB(250, 204, 21)
	adStroke.Thickness = 2.5
	VaultHUD._adrenalineBtn = adrenalineBtn

	adrenalineBtn.MouseButton1Click:Connect(function()
		local pId = Config.Monetization.DevProducts.AdrenalineSurge.Id
		if pId and pId > 0 then
			MarketplaceService:PromptProductPurchase(player, pId)
		else
			adrenalineBtn.Text = "⚡ ADRENALINE BOOST ACTIVE!"
			task.delay(1.5, function()
				if adrenalineBtn and adrenalineBtn.Parent then
					adrenalineBtn.Text = "⚡ ADRENALINE SURGE (25 R$) — +65% ESCAPE SPEED!"
				end
			end)
		end
	end)

	-- ── 3.6. BOTTOM CONTROLS HINT BAR ──
	local tipsBar = Instance.new("Frame")
	tipsBar.Name = "ControlsTipsBar"
	tipsBar.Size = UDim2.new(0, 560, 0, 30)
	tipsBar.Position = UDim2.new(0.5, 0, 1, -72)
	tipsBar.AnchorPoint = Vector2.new(0.5, 1)
	tipsBar.BackgroundColor3 = Color3.fromRGB(11, 13, 20)
	tipsBar.BackgroundTransparency = 0.4
	tipsBar.BorderSizePixel = 0
	tipsBar.Parent = gui
	Instance.new("UICorner", tipsBar).CornerRadius = UDim.new(0, 10)
	local tbStroke = Instance.new("UIStroke", tipsBar)
	tbStroke.Color = Color3.fromRGB(39, 39, 42)

	local tbLabel = Instance.new("TextLabel")
	tbLabel.Size = UDim2.fromScale(1, 1)
	tbLabel.BackgroundTransparency = 1
	tbLabel.Text = "⚡ [U] Upgrades  •  🔮 [B] Fusion  •  📜 [C] Contracts  •  🌟 [P] Mastery  •  📅 [Y] Daily  •  🥊 [F] Tackle"
	tbLabel.TextColor3 = Color3.fromRGB(203, 213, 225)
	tbLabel.TextSize = 11
	tbLabel.Font = Enum.Font.GothamMedium
	tbLabel.Parent = tipsBar

	-- ── 4. FULLSCREEN SECURITY BREACH VIGNETTE ──
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
	breachMsg.Size = UDim2.new(0, 540, 0, 60)
	breachMsg.Position = UDim2.new(0.5, 0, 0.22, 0)
	breachMsg.AnchorPoint = Vector2.new(0.5, 0.5)
	breachMsg.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	breachMsg.BackgroundTransparency = 0.05
	breachMsg.Text = "🚨 SECURITY BREACH! INTRUDER INSIDE YOUR VAULT!"
	breachMsg.TextColor3 = Color3.fromRGB(248, 113, 113)
	breachMsg.TextSize = 16
	breachMsg.Font = Enum.Font.GothamBlack
	breachMsg.Parent = breachVignette
	Instance.new("UICorner", breachMsg).CornerRadius = UDim.new(0, 12)
	local bmStroke = Instance.new("UIStroke", breachMsg)
	bmStroke.Color = Color3.fromRGB(239, 68, 68)
	bmStroke.Thickness = 2.5
	VaultHUD._breachMsg = breachMsg

	print("  [VaultHUD] 2026 Bento-Grid Glass HUD mounted ✓")
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
		VaultHUD._incomeLabel.Text = `▲ +{formatCurrency(rate)}/s`
	end

	if VaultHUD._rankLabel then
		local level = data.Level or 1
		local rankTitle = "RECRUIT"
		if level >= 25 then rankTitle = "OVERLORD"
		elseif level >= 15 then rankTitle = "MASTERMIND"
		elseif level >= 8 then rankTitle = "ENFORCER"
		elseif level >= 4 then rankTitle = "OPERATIVE" end

		VaultHUD._rankLabel.Text = `⚔️ LV. {level} {rankTitle}`
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
		VaultHUD._tokensLabel.Text = `⚡ {tk} TK`
	end

	if VaultHUD._unbankedFrame and VaultHUD._unbankedLabel then
		local unbanked = data.UnbankedCash or 0
		if unbanked > 0 then
			VaultHUD._unbankedFrame.Visible = true
			VaultHUD._unbankedLabel.Text = `⚠️ UNBANKED: {formatCurrency(unbanked)} — STEP ON GREEN SAFE PAD TO BANK!`
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

	msg.Text = `🚨 SECURITY BREACH! {string.upper(intruderName)} IS IN YOUR VAULT!`
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
			VaultHUD._adrenalineBtn.Text = `⚡ ADRENALINE (25 R$) — ESCAPE WITH {string.upper(tostring(payload.Name))}!`
		else
			VaultHUD._adrenalineBtn.Text = "⚡ ADRENALINE SURGE (25 R$) — +65% ESCAPE SPEED!"
		end
	end
end

return VaultHUD
