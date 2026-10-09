--!strict
--[[
	VaultHUD.luau — Tactical Glassmorphic Survival & Economy HUD for VAULT WARS
	Displays Live Banked Net Worth, $/sec Income Rate, Unbanked Stash Alert,
	Security Breach Alarms, and Quick-Access Upgrades.
	Located in: StarterPlayerScripts.Client.UI.VaultHUD
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local player = Players.LocalPlayer
local VaultHUD = {}

VaultHUD._gui = nil :: ScreenGui?
VaultHUD._bankedLabel = nil :: TextLabel?
VaultHUD._incomeLabel = nil :: TextLabel?
VaultHUD._unbankedLabel = nil :: TextLabel?
VaultHUD._unbankedFrame = nil :: Frame?
VaultHUD._breachVignette = nil :: Frame?
VaultHUD._breachMsg = nil :: TextLabel?
VaultHUD._onUpgradesToggle = nil :: (() -> ())?

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
-- CREATE VAULT HUD
-- ============================================================
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
	gui.Parent = pGui
	VaultHUD._gui = gui

	-- ── 1. TOP CENTER: NET WORTH & INCOME TICKER ──
	local topBanner = Instance.new("Frame")
	topBanner.Name = "TopBanner"
	topBanner.Size = UDim2.new(0, 480, 0, 78)
	topBanner.Position = UDim2.new(0.5, 0, 0, 16)
	topBanner.AnchorPoint = Vector2.new(0.5, 0)
	topBanner.BackgroundColor3 = Color3.fromRGB(11, 13, 20)
	topBanner.BackgroundTransparency = 0.15
	topBanner.BorderSizePixel = 0
	topBanner.Parent = gui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 16)
	bCorner.Parent = topBanner

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(30, 41, 59)
	bStroke.Thickness = 2
	bStroke.Parent = topBanner

	-- Banked Net Worth
	local bankedLabel = Instance.new("TextLabel")
	bankedLabel.Name = "BankedNetWorth"
	bankedLabel.Size = UDim2.new(1, -20, 0, 32)
	bankedLabel.Position = UDim2.new(0, 10, 0, 10)
	bankedLabel.BackgroundTransparency = 1
	bankedLabel.Text = "$0"
	bankedLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	bankedLabel.TextSize = 28
	bankedLabel.Font = Enum.Font.GothamBlack
	bankedLabel.TextXAlignment = Enum.TextXAlignment.Center
	bankedLabel.Parent = topBanner
	VaultHUD._bankedLabel = bankedLabel

	-- Income Rate ($/sec)
	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeRate"
	incomeLabel.Size = UDim2.new(1, -20, 0, 20)
	incomeLabel.Position = UDim2.new(0, 10, 0, 46)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = "+$5/sec (Level 1 Conveyor)"
	incomeLabel.TextColor3 = Color3.fromRGB(16, 185, 129)
	incomeLabel.TextSize = 13
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Center
	incomeLabel.Parent = topBanner
	VaultHUD._incomeLabel = incomeLabel

	-- ── 2. TOP RIGHT: UPGRADES BUTTON ──
	local topRight = Instance.new("Frame")
	topRight.Name = "TopRight"
	topRight.Size = UDim2.new(0, 240, 0, 48)
	topRight.Position = UDim2.new(1, -20, 0, 16)
	topRight.AnchorPoint = Vector2.new(1, 0)
	topRight.BackgroundTransparency = 1
	topRight.Parent = gui

	local trLayout = Instance.new("UIListLayout")
	trLayout.FillDirection = Enum.FillDirection.Horizontal
	trLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	trLayout.Padding = UDim.new(0, 10)
	trLayout.Parent = topRight

	local upBtn = Instance.new("TextButton")
	upBtn.Name = "UpgradesButton"
	upBtn.Size = UDim2.new(0, 130, 0, 42)
	upBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
	upBtn.Text = "⚡ UPGRADES"
	upBtn.TextColor3 = Color3.fromRGB(56, 189, 248)
	upBtn.TextSize = 13
	upBtn.Font = Enum.Font.GothamBlack
	upBtn.Parent = topRight
	Instance.new("UICorner", upBtn).CornerRadius = UDim.new(0, 12)
	local uStroke = Instance.new("UIStroke", upBtn)
	uStroke.Color = Color3.fromRGB(56, 189, 248)
	uStroke.Thickness = 2

	upBtn.MouseButton1Click:Connect(function()
		if VaultHUD._onUpgradesToggle then
			VaultHUD._onUpgradesToggle()
		end
	end)

	-- ── 3. BOTTOM CENTER: UNBANKED STASH ALERT ──
	local unbankedFrame = Instance.new("Frame")
	unbankedFrame.Name = "UnbankedFrame"
	unbankedFrame.Size = UDim2.new(0, 420, 0, 44)
	unbankedFrame.Position = UDim2.new(0.5, 0, 1, -24)
	unbankedFrame.AnchorPoint = Vector2.new(0.5, 1)
	unbankedFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	unbankedFrame.BackgroundTransparency = 0.1
	unbankedFrame.BorderSizePixel = 0
	unbankedFrame.Visible = false
	unbankedFrame.Parent = gui
	Instance.new("UICorner", unbankedFrame).CornerRadius = UDim.new(0, 12)
	local ubStroke = Instance.new("UIStroke", unbankedFrame)
	ubStroke.Color = Color3.fromRGB(245, 158, 11)
	ubStroke.Thickness = 2
	VaultHUD._unbankedFrame = unbankedFrame

	local ubLabel = Instance.new("TextLabel")
	ubLabel.Name = "UnbankedLabel"
	ubLabel.Size = UDim2.new(1, 0, 1, 0)
	ubLabel.BackgroundTransparency = 1
	ubLabel.Text = "⚠️ UNBANKED: $0 — STEP ON SAFE TO SECURE!"
	ubLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	ubLabel.TextSize = 12
	ubLabel.Font = Enum.Font.GothamBlack
	ubLabel.Parent = unbankedFrame
	VaultHUD._unbankedLabel = ubLabel

	-- ── 3.5. BOTTOM CONTROLS TIPS BAR ──
	local tipsBar = Instance.new("Frame")
	tipsBar.Name = "ControlsTipsBar"
	tipsBar.Size = UDim2.new(0, 480, 0, 32)
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
	tbLabel.Text = "⚡ [U] Upgrades   •   🥊 [F] Tackle Thief   •   📥 [Step Safe] Bank Cash"
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
	breachMsg.Size = UDim2.new(0, 520, 0, 60)
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

	print("  [VaultHUD] Tactical Cyber-Glass HUD mounted ✓")
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
		VaultHUD._incomeLabel.Text = `+{formatCurrency(rate)}/sec (Level {data.ConveyorLevel})`
	end

	if VaultHUD._unbankedFrame and VaultHUD._unbankedLabel then
		local unbanked = data.UnbankedCash or 0
		if unbanked > 0 then
			VaultHUD._unbankedFrame.Visible = true
			VaultHUD._unbankedLabel.Text = `⚠️ UNBANKED: {formatCurrency(unbanked)} — STEP ON SAFE TO SECURE!`
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

return VaultHUD
