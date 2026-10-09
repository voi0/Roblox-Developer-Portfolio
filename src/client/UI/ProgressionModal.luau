--!strict
--[[
	ProgressionModal.luau — Tactical Bento-Grid Mastery & Skill Tree for VAULT WARS
	Displays Player Level, Heist Ranks, XP Progress Bar, Available Skill Points,
	and interactive 3-Branch Specialization Tree (Infiltrator, Enforcer, Tycoon).
	Located in: StarterPlayerScripts.Client.UI.ProgressionModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Spring = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Spring"))

local player = Players.LocalPlayer
local ProgressionModal = {}

ProgressionModal._frame = nil :: Frame?
ProgressionModal._isOpen = false
ProgressionModal._currentData = nil :: any
ProgressionModal._selectedPerkId = "LightfootProtocol" :: string

-- UI References
ProgressionModal._rankLabel = nil :: TextLabel?
ProgressionModal._levelLabel = nil :: TextLabel?
ProgressionModal._spLabel = nil :: TextLabel?
ProgressionModal._xpBarFill = nil :: Frame?
ProgressionModal._xpValueLabel = nil :: TextLabel?
ProgressionModal._nodeButtons = {} :: { [string]: TextButton }
ProgressionModal._inspectTitle = nil :: TextLabel?
ProgressionModal._inspectDesc = nil :: TextLabel?
ProgressionModal._inspectReq = nil :: TextLabel?
ProgressionModal._buyBtn = nil :: TextButton?

local BRANCH_COLORS: { [string]: Color3 } = {
	Infiltrator = Color3.fromRGB(56, 189, 248), -- Sky Cyan
	Enforcer = Color3.fromRGB(239, 68, 68),    -- Crimson
	Tycoon = Color3.fromRGB(16, 185, 129),     -- Emerald Gold
}

-- ============================================================
-- HELPER: 3D EXTRUDED BUTTON CREATION
-- ============================================================
local function makeTactileButton(btn: TextButton, baseColor: Color3, strokeColor: Color3)
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor
	stroke.Thickness = 2
	stroke.Parent = btn

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = baseColor:Lerp(Color3.new(1, 1, 1), 0.15)
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = baseColor
		}):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.06), {
			Position = btn.Position + UDim2.new(0, 0, 0, 2)
		}):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = btn.Position - UDim2.new(0, 0, 0, 2)
		}):Play()
	end)
end

-- ============================================================
-- CREATE PROGRESSION MODAL
-- ============================================================
function ProgressionModal.Create(parentGui: ScreenGui)
	local modal = Instance.new("Frame")
	modal.Name = "ProgressionModal"
	modal.Size = UDim2.new(0, 780, 0, 540)
	modal.Position = UDim2.new(0.5, 0, 0.5, 0)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.BackgroundColor3 = Color3.fromRGB(11, 13, 20)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 60
	modal.Parent = parentGui
	ProgressionModal._frame = modal

	Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 16)
	local mStroke = Instance.new("UIStroke", modal)
	mStroke.Color = Color3.fromRGB(245, 158, 11)
	mStroke.Thickness = 2.5

	-- Header Bar
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundTransparency = 1
	header.Parent = modal

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 1, 0)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "🌟 SYNDICATE MASTERY & SKILL TREE"
	title.TextColor3 = Color3.fromRGB(250, 204, 21)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 6)
	closeBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(161, 161, 170)
	closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = header
	makeTactileButton(closeBtn, Color3.fromRGB(24, 24, 27), Color3.fromRGB(63, 63, 70))
	closeBtn.MouseButton1Click:Connect(function()
		ProgressionModal.Close()
	end)

	-- ── 1. TOP BENTO ROW: PLAYER PROFILE & XP BAR ──
	local topCard = Instance.new("Frame")
	topCard.Name = "TopCard"
	topCard.Size = UDim2.new(1, -32, 0, 78)
	topCard.Position = UDim2.new(0, 16, 0, 52)
	topCard.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
	topCard.BorderSizePixel = 0
	topCard.Parent = modal
	Instance.new("UICorner", topCard).CornerRadius = UDim.new(0, 12)
	local tcStroke = Instance.new("UIStroke", topCard)
	tcStroke.Color = Color3.fromRGB(39, 39, 42)
	tcStroke.Thickness = 1.5

	-- Rank Badge & Level
	local rankLabel = Instance.new("TextLabel")
	rankLabel.Name = "RankLabel"
	rankLabel.Size = UDim2.new(0, 240, 0, 26)
	rankLabel.Position = UDim2.new(0, 16, 0, 10)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = "RANK: ROOKIE BURGLAR"
	rankLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
	rankLabel.TextSize = 15
	rankLabel.Font = Enum.Font.GothamBlack
	rankLabel.TextXAlignment = Enum.TextXAlignment.Left
	rankLabel.Parent = topCard
	ProgressionModal._rankLabel = rankLabel

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(0, 120, 0, 26)
	levelLabel.Position = UDim2.new(0, 260, 0, 10)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "LEVEL 1"
	levelLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	levelLabel.TextSize = 15
	levelLabel.Font = Enum.Font.GothamBlack
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = topCard
	ProgressionModal._levelLabel = levelLabel

	-- Available Skill Points Pill
	local spLabel = Instance.new("TextLabel")
	spLabel.Name = "SPLabel"
	spLabel.Size = UDim2.new(0, 180, 0, 26)
	spLabel.Position = UDim2.new(1, -196, 0, 10)
	spLabel.BackgroundTransparency = 1
	spLabel.Text = "🌟 AVAILABLE SP: 0"
	spLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	spLabel.TextSize = 14
	spLabel.Font = Enum.Font.GothamBlack
	spLabel.TextXAlignment = Enum.TextXAlignment.Right
	spLabel.Parent = topCard
	ProgressionModal._spLabel = spLabel

	-- XP Progress Bar Track
	local xpTrack = Instance.new("Frame")
	xpTrack.Name = "XPTrack"
	xpTrack.Size = UDim2.new(1, -32, 0, 18)
	xpTrack.Position = UDim2.new(0, 16, 0, 44)
	xpTrack.BackgroundColor3 = Color3.fromRGB(9, 9, 11)
	xpTrack.BorderSizePixel = 0
	xpTrack.Parent = topCard
	Instance.new("UICorner", xpTrack).CornerRadius = UDim.new(0, 9)

	local xpFill = Instance.new("Frame")
	xpFill.Name = "XPFill"
	xpFill.Size = UDim2.new(0.3, 0, 1, 0)
	xpFill.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpTrack
	Instance.new("UICorner", xpFill).CornerRadius = UDim.new(0, 9)
	ProgressionModal._xpBarFill = xpFill

	local xpGrad = Instance.new("UIGradient")
	xpGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 185, 129)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(56, 189, 248)),
	})
	xpGrad.Parent = xpFill

	local xpVal = Instance.new("TextLabel")
	xpVal.Name = "XPVal"
	xpVal.Size = UDim2.new(1, 0, 1, 0)
	xpVal.BackgroundTransparency = 1
	xpVal.Text = "XP: 0 / 100"
	xpVal.TextColor3 = Color3.fromRGB(255, 255, 255)
	xpVal.TextSize = 11
	xpVal.Font = Enum.Font.GothamBold
	xpVal.Parent = xpTrack
	ProgressionModal._xpValueLabel = xpVal

	-- ── 2. 3-COLUMN BENTO GRID: PERK BRANCHES ──
	local columnsFrame = Instance.new("Frame")
	columnsFrame.Name = "Columns"
	columnsFrame.Size = UDim2.new(1, -32, 0, 250)
	columnsFrame.Position = UDim2.new(0, 16, 0, 138)
	columnsFrame.BackgroundTransparency = 1
	columnsFrame.Parent = modal

	local colLayout = Instance.new("UIListLayout")
	colLayout.FillDirection = Enum.FillDirection.Horizontal
	colLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	colLayout.Padding = UDim.new(0, 12)
	colLayout.Parent = columnsFrame

	local branchData = {
		{
			Branch = "Infiltrator",
			Title = "⚡ INFILTRATOR",
			Subtitle = "Stealth, Speed & Evasion",
			Accent = BRANCH_COLORS.Infiltrator,
			PerkIds = { "LightfootProtocol", "SilentProwler", "OverclockedEMP", "PhantomDash" }
		},
		{
			Branch = "Enforcer",
			Title = "🛡️ ENFORCER",
			Subtitle = "Baton Combat & Bounties",
			Accent = BRANCH_COLORS.Enforcer,
			PerkIds = { "HeavySwing", "HardenedCarapace", "BountyHunter", "ShockwaveSlam" }
		},
		{
			Branch = "Tycoon",
			Title = "💰 TYCOON",
			Subtitle = "Economy, Mints & Relics",
			Accent = BRANCH_COLORS.Tycoon,
			PerkIds = { "OverchargedPress", "MidasTouch", "CompoundingTreasury", "AlchemicalResonance" }
		},
	}

	for _, bInfo in branchData do
		local col = Instance.new("Frame")
		col.Name = `Col_{bInfo.Branch}`
		col.Size = UDim2.new(0, 240, 1, 0)
		col.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
		col.BorderSizePixel = 0
		col.Parent = columnsFrame
		Instance.new("UICorner", col).CornerRadius = UDim.new(0, 12)
		local cStroke = Instance.new("UIStroke", col)
		cStroke.Color = bInfo.Accent
		cStroke.Thickness = 1.5

		-- Branch Header
		local bh = Instance.new("TextLabel")
		bh.Size = UDim2.new(1, -16, 0, 24)
		bh.Position = UDim2.new(0, 8, 0, 8)
		bh.BackgroundTransparency = 1
		bh.Text = bInfo.Title
		bh.TextColor3 = bInfo.Accent
		bh.TextSize = 13
		bh.Font = Enum.Font.GothamBlack
		bh.Parent = col

		-- 4 Node Buttons per Branch
		local nodesContainer = Instance.new("Frame")
		nodesContainer.Size = UDim2.new(1, -16, 1, -40)
		nodesContainer.Position = UDim2.new(0, 8, 0, 34)
		nodesContainer.BackgroundTransparency = 1
		nodesContainer.Parent = col

		local nLayout = Instance.new("UIListLayout")
		nLayout.FillDirection = Enum.FillDirection.Vertical
		nLayout.Padding = UDim.new(0, 6)
		nLayout.Parent = nodesContainer

		for _, perkId in bInfo.PerkIds do
			local pDef = Config.Progression.Perks[perkId]
			if not pDef then continue end

			local nodeBtn = Instance.new("TextButton")
			nodeBtn.Name = `Node_{perkId}`
			nodeBtn.Size = UDim2.new(1, 0, 0, 42)
			nodeBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
			nodeBtn.Text = ""
			nodeBtn.AutoButtonColor = false
			nodeBtn.Parent = nodesContainer
			Instance.new("UICorner", nodeBtn).CornerRadius = UDim.new(0, 8)

			local nStroke = Instance.new("UIStroke")
			nStroke.Name = "NodeStroke"
			nStroke.Color = Color3.fromRGB(39, 39, 42)
			nStroke.Thickness = 1.5
			nStroke.Parent = nodeBtn

			local nTitle = Instance.new("TextLabel")
			nTitle.Name = "TitleLabel"
			nTitle.Size = UDim2.new(1, -64, 0, 20)
			nTitle.Position = UDim2.new(0, 8, 0, 4)
			nTitle.BackgroundTransparency = 1
			nTitle.Text = pDef.Name
			nTitle.TextColor3 = Color3.fromRGB(228, 228, 231)
			nTitle.TextSize = 11
			nTitle.Font = Enum.Font.GothamBold
			nTitle.TextXAlignment = Enum.TextXAlignment.Left
			nTitle.Parent = nodeBtn

			local nBadge = Instance.new("TextLabel")
			nBadge.Name = "StatusBadge"
			nBadge.Size = UDim2.new(0, 56, 0, 18)
			nBadge.Position = UDim2.new(1, -60, 0, 5)
			nBadge.BackgroundColor3 = Color3.fromRGB(9, 9, 11)
			nBadge.Text = `{pDef.CostSP} SP`
			nBadge.TextColor3 = Color3.fromRGB(250, 204, 21)
			nBadge.TextSize = 10
			nBadge.Font = Enum.Font.GothamBlack
			nBadge.Parent = nodeBtn
			Instance.new("UICorner", nBadge).CornerRadius = UDim.new(0, 6)

			local nTier = Instance.new("TextLabel")
			nTier.Name = "TierLabel"
			nTier.Size = UDim2.new(1, -16, 0, 14)
			nTier.Position = UDim2.new(0, 8, 0, 22)
			nTier.BackgroundTransparency = 1
			nTier.Text = (pDef.Tier == 4) and "⭐ CAPSTONE ABILITY" or `Tier {pDef.Tier}`
			nTier.TextColor3 = (pDef.Tier == 4) and Color3.fromRGB(250, 204, 21) or Color3.fromRGB(113, 113, 122)
			nTier.TextSize = 9
			nTier.Font = Enum.Font.GothamMedium
			nTier.TextXAlignment = Enum.TextXAlignment.Left
			nTier.Parent = nodeBtn

			ProgressionModal._nodeButtons[perkId] = nodeBtn

			nodeBtn.MouseButton1Click:Connect(function()
				ProgressionModal.SelectPerk(perkId)
			end)
		end
	end

	-- ── 3. BOTTOM BENTO INSPECTOR CARD ──
	local inspectCard = Instance.new("Frame")
	inspectCard.Name = "InspectCard"
	inspectCard.Size = UDim2.new(1, -32, 0, 126)
	inspectCard.Position = UDim2.new(0, 16, 0, 396)
	inspectCard.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
	inspectCard.BorderSizePixel = 0
	inspectCard.Parent = modal
	Instance.new("UICorner", inspectCard).CornerRadius = UDim.new(0, 12)
	local icStroke = Instance.new("UIStroke", inspectCard)
	icStroke.Color = Color3.fromRGB(39, 39, 42)
	icStroke.Thickness = 1.5

	local inTitle = Instance.new("TextLabel")
	inTitle.Name = "InspectTitle"
	inTitle.Size = UDim2.new(1, -220, 0, 24)
	inTitle.Position = UDim2.new(0, 16, 0, 12)
	inTitle.BackgroundTransparency = 1
	inTitle.Text = "Lightfoot Protocol"
	inTitle.TextColor3 = Color3.fromRGB(250, 204, 21)
	inTitle.TextSize = 15
	inTitle.Font = Enum.Font.GothamBlack
	inTitle.TextXAlignment = Enum.TextXAlignment.Left
	inTitle.Parent = inspectCard
	ProgressionModal._inspectTitle = inTitle

	local inDesc = Instance.new("TextLabel")
	inDesc.Name = "InspectDesc"
	inDesc.Size = UDim2.new(1, -220, 0, 44)
	inDesc.Position = UDim2.new(0, 16, 0, 38)
	inDesc.BackgroundTransparency = 1
	inDesc.Text = "+20% Base Sprint Speed & -50% Loot Carrying Weight Debuff."
	inDesc.TextColor3 = Color3.fromRGB(212, 212, 216)
	inDesc.TextSize = 12
	inDesc.Font = Enum.Font.GothamMedium
	inDesc.TextXAlignment = Enum.TextXAlignment.Left
	inDesc.TextWrapped = true
	inDesc.Parent = inspectCard
	ProgressionModal._inspectDesc = inDesc

	local inReq = Instance.new("TextLabel")
	inReq.Name = "InspectReq"
	inReq.Size = UDim2.new(1, -220, 0, 20)
	inReq.Position = UDim2.new(0, 16, 0, 90)
	inReq.BackgroundTransparency = 1
	inReq.Text = "Prerequisite: None"
	inReq.TextColor3 = Color3.fromRGB(113, 113, 122)
	inReq.TextSize = 11
	inReq.Font = Enum.Font.GothamBold
	inReq.TextXAlignment = Enum.TextXAlignment.Left
	inReq.Parent = inspectCard
	ProgressionModal._inspectReq = inReq

	-- Buy Button
	local buyBtn = Instance.new("TextButton")
	buyBtn.Name = "BuyPerkButton"
	buyBtn.Size = UDim2.new(0, 180, 0, 48)
	buyBtn.Position = UDim2.new(1, -196, 0.5, -24)
	buyBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
	buyBtn.Text = "UNLOCK PERK (1 SP)"
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.TextSize = 12
	buyBtn.Font = Enum.Font.GothamBlack
	buyBtn.Parent = inspectCard
	makeTactileButton(buyBtn, Color3.fromRGB(16, 185, 129), Color3.fromRGB(5, 150, 105))
	ProgressionModal._buyBtn = buyBtn

	buyBtn.MouseButton1Click:Connect(function()
		ProgressionModal.AttemptPurchaseCurrent()
	end)

	ProgressionModal.SelectPerk(ProgressionModal._selectedPerkId)
end

-- ============================================================
-- SELECT & INSPECT PERK
-- ============================================================
function ProgressionModal.SelectPerk(perkId: string)
	ProgressionModal._selectedPerkId = perkId
	local pDef = Config.Progression.Perks[perkId]
	if not pDef then return end

	if ProgressionModal._inspectTitle then
		ProgressionModal._inspectTitle.Text = pDef.Name
		ProgressionModal._inspectTitle.TextColor3 = BRANCH_COLORS[pDef.Branch] or Color3.fromRGB(250, 204, 21)
	end

	if ProgressionModal._inspectDesc then
		ProgressionModal._inspectDesc.Text = pDef.Description
	end

	if ProgressionModal._inspectReq then
		if pDef.RequiredPerkId and pDef.RequiredPerkId ~= "" then
			local reqDef = Config.Progression.Perks[pDef.RequiredPerkId]
			local reqName = reqDef and reqDef.Name or pDef.RequiredPerkId
			ProgressionModal._inspectReq.Text = `Prerequisite: {reqName}`
		else
			ProgressionModal._inspectReq.Text = "Prerequisite: None (Tier 1 Entry)"
		end
	end

	ProgressionModal.RefreshInspectButton()
end

function ProgressionModal.RefreshInspectButton()
	local buyBtn = ProgressionModal._buyBtn
	if not buyBtn then return end

	local pDef = Config.Progression.Perks[ProgressionModal._selectedPerkId]
	if not pDef then return end

	local data = ProgressionModal._currentData
	local isUnlocked = data and data.UnlockedPerks and data.UnlockedPerks[pDef.Id] == true
	local sp = data and data.SkillPoints or 0

	local reqMet = true
	if pDef.RequiredPerkId and pDef.RequiredPerkId ~= "" then
		reqMet = (data and data.UnlockedPerks and data.UnlockedPerks[pDef.RequiredPerkId] == true)
	end

	if isUnlocked then
		buyBtn.Text = "✓ ALREADY ACTIVE"
		buyBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
		buyBtn.TextColor3 = Color3.fromRGB(161, 161, 170)
	elseif not reqMet then
		buyBtn.Text = "🔒 PREREQ REQUIRED"
		buyBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
		buyBtn.TextColor3 = Color3.fromRGB(113, 113, 122)
	elseif sp < pDef.CostSP then
		buyBtn.Text = `NEED {pDef.CostSP} SP (HAVE {sp})`
		buyBtn.BackgroundColor3 = Color3.fromRGB(63, 63, 70)
		buyBtn.TextColor3 = Color3.fromRGB(244, 63, 94)
	else
		buyBtn.Text = `UNLOCK PERK ({pDef.CostSP} SP)`
		buyBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
		buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

-- ============================================================
-- PURCHASE PERK
-- ============================================================
function ProgressionModal.AttemptPurchaseCurrent()
	local perkId = ProgressionModal._selectedPerkId
	local perkRF = ReplicatedStorage:FindFirstChild("PurchasePerk") :: RemoteFunction?
	if not perkRF then return end

	local success, msg = perkRF:InvokeServer(perkId)
	if success then
		print(`[Progression] Perk {perkId} unlocked!`)
	else
		warn(`[Progression] Purchase failed: {tostring(msg)}`)
	end
end

-- ============================================================
-- UPDATE DATA REPLICATION
-- ============================================================
function ProgressionModal.Update(data: any)
	if not data then return end
	ProgressionModal._currentData = data

	local level = data.Level or 1
	local xp = data.XP or 0
	local sp = data.SkillPoints or 0
	local reqXP = Config.Progression.GetXPRequiredForLevel(level)
	local rankInfo = Config.Progression.GetRankForLevel(level)

	if ProgressionModal._rankLabel then
		ProgressionModal._rankLabel.Text = `RANK: {string.upper(rankInfo.Title)}`
		ProgressionModal._rankLabel.TextColor3 = rankInfo.Color
	end

	if ProgressionModal._levelLabel then
		ProgressionModal._levelLabel.Text = `LEVEL {level}`
	end

	if ProgressionModal._spLabel then
		ProgressionModal._spLabel.Text = `🌟 AVAILABLE SP: {sp}`
	end

	if ProgressionModal._xpBarFill then
		local frac = math.clamp(xp / reqXP, 0, 1)
		TweenService:Create(ProgressionModal._xpBarFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(frac, 0, 1, 0)
		}):Play()
	end

	if ProgressionModal._xpValueLabel then
		local pct = math.floor((xp / reqXP) * 100)
		ProgressionModal._xpValueLabel.Text = `XP: {xp} / {reqXP} ({pct}%)`
	end

	-- Update Node Buttons
	for perkId, btn in ProgressionModal._nodeButtons do
		local pDef = Config.Progression.Perks[perkId]
		if not pDef then continue end

		local isUnlocked = data.UnlockedPerks and data.UnlockedPerks[perkId] == true
		local statusBadge = btn:FindFirstChild("StatusBadge") :: TextLabel?
		local stroke = btn:FindFirstChild("NodeStroke") :: UIStroke?
		local branchColor = BRANCH_COLORS[pDef.Branch] or Color3.fromRGB(56, 189, 248)

		local reqMet = true
		if pDef.RequiredPerkId and pDef.RequiredPerkId ~= "" then
			reqMet = (data.UnlockedPerks and data.UnlockedPerks[pDef.RequiredPerkId] == true)
		end

		if isUnlocked then
			btn.BackgroundColor3 = branchColor:Lerp(Color3.fromRGB(15, 23, 42), 0.7)
			if stroke then
				stroke.Color = branchColor
				stroke.Thickness = 2
			end
			if statusBadge then
				statusBadge.Text = "ACTIVE"
				statusBadge.TextColor3 = Color3.fromRGB(34, 197, 94)
			end
		elseif not reqMet then
			btn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
			if stroke then
				stroke.Color = Color3.fromRGB(39, 39, 42)
				stroke.Thickness = 1
			end
			if statusBadge then
				statusBadge.Text = "LOCKED"
				statusBadge.TextColor3 = Color3.fromRGB(113, 113, 122)
			end
		else
			btn.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
			if stroke then
				stroke.Color = (sp >= pDef.CostSP) and Color3.fromRGB(250, 204, 21) or Color3.fromRGB(63, 63, 70)
				stroke.Thickness = (sp >= pDef.CostSP) and 2 or 1
			end
			if statusBadge then
				statusBadge.Text = `{pDef.CostSP} SP`
				statusBadge.TextColor3 = (sp >= pDef.CostSP) and Color3.fromRGB(250, 204, 21) or Color3.fromRGB(161, 161, 170)
			end
		end
	end

	ProgressionModal.RefreshInspectButton()
end

-- ============================================================
-- MODAL OPEN / CLOSE / TOGGLE
-- ============================================================
function ProgressionModal.Open()
	if not ProgressionModal._frame then return end
	ProgressionModal._isOpen = true
	ProgressionModal._frame.Visible = true

	ProgressionModal._frame.Size = UDim2.new(0, 700, 0, 480)
	TweenService:Create(ProgressionModal._frame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 780, 0, 540)
	}):Play()
end

function ProgressionModal.Close()
	if not ProgressionModal._frame then return end
	ProgressionModal._isOpen = false

	local tw = TweenService:Create(ProgressionModal._frame, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 680, 0, 460)
	})
	tw:Play()
	tw.Completed:Connect(function()
		if not ProgressionModal._isOpen and ProgressionModal._frame then
			ProgressionModal._frame.Visible = false
		end
	end)
end

function ProgressionModal.Toggle()
	if ProgressionModal._isOpen then
		ProgressionModal.Close()
	else
		ProgressionModal.Open()
	end
end

return ProgressionModal
