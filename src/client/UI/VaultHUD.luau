--!strict
--[[
	VaultHUD.luau — Tactical 2026 Liquid Glass & Bento-Grid HUD for VAULT WARS
	Displays Live Banked Net Worth, $/sec Income Rate, Unbanked Stash Alert,
	Security Breach Alarms, and Quick-Access Upgrades using modern Bento capsules.
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

function VaultHUD.SetContractsCallback(cb: () -> ())
	VaultHUD._onContractsToggle = cb
end

-- ============================================================
-- NUMBER FORMATTER (K / M / B / T / Qa)
-- ============================================================
local function formatCurrency(n: number): string
	n = math.floor(n or 0)
	if n >= 1e15 then
		return string.format("$%.2fQa", n / 1e15)
	elseif n >= 1e12 then
		return string.format("$%.2fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("$%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("$%.2fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("$%.1fK", n / 1e3)
	else
		return "$" .. tostring(n)
	end
end

-- ============================================================
-- HOVER / SPRING HELPER
-- ============================================================
local function applyBentoHover(btn: TextButton, stroke: UIStroke, accentColor: Color3)
	local scale = btn:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = btn
	end

	btn.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
		TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = Color3.fromRGB(30, 36, 54),
			BackgroundTransparency = 0.1,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 2.0,
			Color = accentColor,
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
		TweenService:Create(btn, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = Color3.fromRGB(15, 17, 26),
			BackgroundTransparency = 0.25,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 1.2,
			Color = Color3.fromRGB(39, 45, 66),
		}):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Scale = 0.94 }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
	end)
end

-- ============================================================
-- CREATE VAULT HUD
-- ============================================================
function VaultHUD.Create()
	local pGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
	if not pGui then
		warn("[VaultHUD] Error: PlayerGui not found after 10s!")
		return
	end

	local existing = pGui:FindFirstChild("VaultWarsHUD")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "VaultWarsHUD"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = pGui
	VaultHUD._gui = gui
	print("  [VaultHUD] Mounted Tactical Bento HUD into PlayerGui successfully!")

	-- ── 1. TOP CENTER: BENTO STATUS CAPSULE (2026 LIQUID GLASS) ──
	local topCapsule = Instance.new("Frame")
	topCapsule.Name = "TopStatusCapsule"
	topCapsule.Size = UDim2.new(0, 520, 0, 58)
	topCapsule.Position = UDim2.new(0.5, 0, 0, 18)
	topCapsule.AnchorPoint = Vector2.new(0.5, 0)
	topCapsule.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	topCapsule.BackgroundTransparency = 0.16
	topCapsule.BorderSizePixel = 0
	topCapsule.Parent = gui

	local tcCorner = Instance.new("UICorner")
	tcCorner.CornerRadius = UDim.new(0, 18)
	tcCorner.Parent = topCapsule

	-- 45° Specular Rim Light
	local tcStroke = Instance.new("UIStroke")
	tcStroke.Color = Color3.fromRGB(30, 41, 59)
	tcStroke.Thickness = 1.4
	tcStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tcStroke.Parent = topCapsule

	local tcStrokeGrad = Instance.new("UIGradient")
	tcStrokeGrad.Rotation = 45
	tcStrokeGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(148, 163, 184)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(30, 41, 59)),
	})
	tcStrokeGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.12),
		NumberSequenceKeypoint.new(0.6, 0.65),
		NumberSequenceKeypoint.new(1.0, 0.85),
	})
	tcStrokeGrad.Parent = tcStroke

	-- Diffuse Glass Gradient
	local tcBgGrad = Instance.new("UIGradient")
	tcBgGrad.Rotation = 90
	tcBgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(30, 36, 54)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(15, 17, 26)),
	})
	tcBgGrad.Parent = topCapsule

	-- Left Sub-Pill: Syndicate Rank Badge
	local rankPill = Instance.new("Frame")
	rankPill.Name = "RankBadge"
	rankPill.Size = UDim2.new(0, 130, 0, 36)
	rankPill.Position = UDim2.new(0, 12, 0.5, -18)
	rankPill.BackgroundColor3 = Color3.fromRGB(22, 26, 40)
	rankPill.BorderSizePixel = 0
	rankPill.Parent = topCapsule
	Instance.new("UICorner", rankPill).CornerRadius = UDim.new(0, 10)
	local rStroke = Instance.new("UIStroke", rankPill)
	rStroke.Color = Color3.fromRGB(56, 189, 248)
	rStroke.Thickness = 1.2

	local rankLbl = Instance.new("TextLabel")
	rankLbl.Size = UDim2.new(1, 0, 1, 0)
	rankLbl.BackgroundTransparency = 1
	rankLbl.Text = "⚔️ RANK 1"
	rankLbl.TextColor3 = Color3.fromRGB(56, 189, 248)
	rankLbl.TextSize = 12
	rankLbl.Font = Enum.Font.GothamBlack
	rankLbl.Parent = rankPill
	VaultHUD._rankLabel = rankLbl

	-- Center: Banked Net Worth
	local bankedLabel = Instance.new("TextLabel")
	bankedLabel.Name = "BankedNetWorth"
	bankedLabel.Size = UDim2.new(0, 200, 1, 0)
	bankedLabel.Position = UDim2.new(0.5, -100, 0, 0)
	bankedLabel.BackgroundTransparency = 1
	bankedLabel.Text = "$0"
	bankedLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	bankedLabel.TextSize = 26
	bankedLabel.Font = Enum.Font.GothamBlack
	bankedLabel.TextXAlignment = Enum.TextXAlignment.Center
	bankedLabel.Parent = topCapsule
	VaultHUD._bankedLabel = bankedLabel

	-- Right Sub-Pill: Live Income Rate Ticker
	local incomePill = Instance.new("Frame")
	incomePill.Name = "IncomePill"
	incomePill.Size = UDim2.new(0, 140, 0, 36)
	incomePill.Position = UDim2.new(1, -152, 0.5, -18)
	incomePill.BackgroundColor3 = Color3.fromRGB(16, 42, 34)
	incomePill.BorderSizePixel = 0
	incomePill.Parent = topCapsule
	Instance.new("UICorner", incomePill).CornerRadius = UDim.new(0, 10)
	local iStroke = Instance.new("UIStroke", incomePill)
	iStroke.Color = Color3.fromRGB(16, 185, 129)
	iStroke.Thickness = 1.2

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeRate"
	incomeLabel.Size = UDim2.new(1, 0, 1, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = "▲ +$5/s"
	incomeLabel.TextColor3 = Color3.fromRGB(110, 231, 183)
	incomeLabel.TextSize = 13
	incomeLabel.Font = Enum.Font.GothamBlack
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Center
	incomeLabel.Parent = incomePill
	VaultHUD._incomeLabel = incomeLabel

	-- ── 2. TOP RIGHT: BENTO ACTION TRAY ──
	local topRight = Instance.new("Frame")
	topRight.Name = "TopRightActionTray"
	topRight.Size = UDim2.new(0, 600, 0, 42)
	topRight.Position = UDim2.new(1, -20, 0, 26)
	topRight.AnchorPoint = Vector2.new(1, 0)
	topRight.BackgroundTransparency = 1
	topRight.Parent = gui

	local trLayout = Instance.new("UIListLayout")
	trLayout.FillDirection = Enum.FillDirection.Horizontal
	trLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	trLayout.Padding = UDim.new(0, 8)
	trLayout.Parent = topRight

	local function createBentoBtn(name: string, text: string, accentColor: Color3, onClick: () -> ()): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, 112, 0, 38)
		btn.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
		btn.BackgroundTransparency = 0.25
		btn.Text = text
		btn.TextColor3 = accentColor
		btn.TextSize = 12
		btn.Font = Enum.Font.GothamBlack
		btn.Parent = topRight

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(39, 45, 66)
		stroke.Thickness = 1.2
		stroke.Parent = btn

		applyBentoHover(btn, stroke, accentColor)
		btn.MouseButton1Click:Connect(onClick)
		return btn
	end

	createBentoBtn("ProgressButton", "🌟 PROGRESS", Color3.fromRGB(250, 204, 21), function()
		if VaultHUD._onProgressToggle then VaultHUD._onProgressToggle() end
	end)

	createBentoBtn("ContractsButton", "📜 CONTRACTS", Color3.fromRGB(245, 158, 11), function()
		if VaultHUD._onContractsToggle then VaultHUD._onContractsToggle() end
	end)

	createBentoBtn("DailyButton", "📅 DAILY", Color3.fromRGB(249, 115, 22), function()
		if VaultHUD._onDailyToggle then VaultHUD._onDailyToggle() end
	end)

	createBentoBtn("FusionButton", "🔮 FUSION", Color3.fromRGB(168, 85, 247), function()
		if VaultHUD._onFusionToggle then VaultHUD._onFusionToggle() end
	end)

	createBentoBtn("UpgradesButton", "⚡ UPGRADES", Color3.fromRGB(56, 189, 248), function()
		if VaultHUD._onUpgradesToggle then VaultHUD._onUpgradesToggle() end
	end)

	-- ── 3. BOTTOM CENTER: UNBANKED STASH ALERT ──
	local unbankedFrame = Instance.new("Frame")
	unbankedFrame.Name = "UnbankedFrame"
	unbankedFrame.Size = UDim2.new(0, 440, 0, 42)
	unbankedFrame.Position = UDim2.new(0.5, 0, 1, -24)
	unbankedFrame.AnchorPoint = Vector2.new(0.5, 1)
	unbankedFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	unbankedFrame.BackgroundTransparency = 0.12
	unbankedFrame.BorderSizePixel = 0
	unbankedFrame.Visible = false
	unbankedFrame.Parent = gui

	local ubCorner = Instance.new("UICorner")
	ubCorner.CornerRadius = UDim.new(0, 12)
	ubCorner.Parent = unbankedFrame

	local ubStroke = Instance.new("UIStroke")
	ubStroke.Color = Color3.fromRGB(245, 158, 11)
	ubStroke.Thickness = 2
	ubStroke.Parent = unbankedFrame
	VaultHUD._unbankedFrame = unbankedFrame

	local ubLabel = Instance.new("TextLabel")
	ubLabel.Name = "UnbankedLabel"
	ubLabel.Size = UDim2.new(1, 0, 1, 0)
	ubLabel.BackgroundTransparency = 1
	ubLabel.Text = "⚠️ UNBANKED: $0 — STEP ON GREEN SAFE PAD TO SECURE!"
	ubLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	ubLabel.TextSize = 12
	ubLabel.Font = Enum.Font.GothamBlack
	ubLabel.Parent = unbankedFrame
	VaultHUD._unbankedLabel = ubLabel

	-- ── 3.3. FLOATING 25 R$ ADRENALINE IMPULSE ESCAPE PILL ──
	local adrenalineBtn = Instance.new("TextButton")
	adrenalineBtn.Name = "AdrenalineSurgeButton"
	adrenalineBtn.Size = UDim2.new(0, 400, 0, 44)
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

	-- Pulsing effect for Adrenaline button
	task.spawn(function()
		while true do
			if adrenalineBtn.Visible then
				TweenService:Create(adStroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Color = Color3.fromRGB(239, 68, 68)
				}):Play()
				task.wait(0.5)
				TweenService:Create(adStroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Color = Color3.fromRGB(250, 204, 21)
				}):Play()
				task.wait(0.5)
			else
				task.wait(1.0)
			end
		end
	end)

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

	-- ── 3.5. BOTTOM CONTROLS TIPS BAR ──
	local tipsBar = Instance.new("Frame")
	tipsBar.Name = "ControlsTipsBar"
	tipsBar.Size = UDim2.new(0, 560, 0, 32)
	tipsBar.Position = UDim2.new(0.5, 0, 1, -72)
	tipsBar.AnchorPoint = Vector2.new(0.5, 1)
	tipsBar.BackgroundColor3 = Color3.fromRGB(11, 13, 20)
	tipsBar.BackgroundTransparency = 0.35
	tipsBar.BorderSizePixel = 0
	tipsBar.Parent = gui
	Instance.new("UICorner", tipsBar).CornerRadius = UDim.new(0, 10)
	local tbStroke = Instance.new("UIStroke", tipsBar)
	tbStroke.Color = Color3.fromRGB(39, 39, 42)

	local tbLabel = Instance.new("TextLabel")
	tbLabel.Size = UDim2.new(1, 0, 1, 0)
	tbLabel.BackgroundTransparency = 1
	tbLabel.Text = "⚡ [U] Upgrades  •  🔮 [B] Fusion  •  📜 [C] Contracts  •  📅 [Y] Daily  •  🥊 [F] Tackle  •  📥 [Step Safe] Bank"
	tbLabel.TextColor3 = Color3.fromRGB(203, 213, 225)
	tbLabel.TextSize = 11
	tbLabel.Font = Enum.Font.GothamMedium
	tbLabel.Parent = tipsBar

	-- ── 4. FULLSCREEN SECURITY BREACH VIGNETTE ──
	local breachVignette = Instance.new("Frame")
	breachVignette.Name = "BreachVignette"
	breachVignette.Size = UDim2.new(1, 0, 1, 0)
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
		local rank = data.Level or 1
		VaultHUD._rankLabel.Text = `⚔️ RANK {rank}`
	end

	if VaultHUD._unbankedFrame and VaultHUD._unbankedLabel then
		local unbanked = data.UnbankedCash or 0
		if unbanked > 0 then
			VaultHUD._unbankedFrame.Visible = true
			VaultHUD._unbankedLabel.Text = `⚠️ UNBANKED: {formatCurrency(unbanked)} — STEP ON GREEN SAFE PAD TO SECURE!`
		else
			VaultHUD._unbankedFrame.Visible = false
		end
	end
end

-- ============================================================
-- TRIGGER BREACH ALARM VIGNETTE
-- ============================================================
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
