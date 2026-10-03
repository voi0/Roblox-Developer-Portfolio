--!strict
--[[
	RebirthModal.luau — Cosmic Transcendence & Prestige for STARWEAVE
	Presents the Rebirth ascension loop: permanent Cosmic Multipliers,
	Constellation Points, Starlight prestige currency, and Realm unlocks.
	Located in: StarterPlayerScripts.Client.UI.RebirthModal
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local VFXController = require(script.Parent.Parent.Controllers.VFXController)
local UILib = require(script.Parent.UILib)

local RebirthModal = {}
RebirthModal._frame = nil :: Frame?
RebirthModal._data = nil :: any

local ACCENT = Color3.fromRGB(244, 114, 182) -- pink

function RebirthModal.Create(parentGui: ScreenGui)
	local modal = UILib.CreateModalFrame(parentGui, "RebirthModal", 540, 480, ACCENT)
	RebirthModal._frame = modal

	UILib.CreateModalHeader(modal, "Cosmic Transcendence", "Sacrifice mortal harvest to awaken celestial multipliers", ACCENT, function()
		SoundController.Play("ButtonClick")
		RebirthModal.Close()
	end)

	-- Comparison Section: Current vs Next (side by side)
	local compFrame = Instance.new("Frame")
	compFrame.Name = "Comparison"
	compFrame.Size = UDim2.new(1, -32, 0, 120)
	compFrame.Position = UDim2.new(0, 16, 0, 72)
	compFrame.BackgroundTransparency = 1
	compFrame.ZIndex = modal.ZIndex + 1
	compFrame.Parent = modal

	-- Current Level Card
	local currentCard = Instance.new("Frame")
	currentCard.Name = "CurrentCard"
	currentCard.Size = UDim2.new(0.45, 0, 1, 0)
	currentCard.BackgroundColor3 = UILib.Colors.Surface2
	currentCard.BorderSizePixel = 0
	currentCard.ZIndex = modal.ZIndex + 2
	currentCard.Parent = compFrame
	UILib.ApplyCorner(currentCard, 10)
	UILib.ApplyStroke(currentCard, UILib.Colors.TextMuted, 1, 0.6)

	UILib.CreateLabel(currentCard, "CardTitle", "CURRENT", UILib.Colors.TextMuted, 10, UILib.Fonts.Bold,
		UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 0, 14))

	local curLevelLabel = UILib.CreateLabel(currentCard, "CurLevel", "Level 0", UILib.Colors.TextPrimary, 22, UILib.Fonts.Black,
		UDim2.new(0, 12, 0, 28), UDim2.new(1, -24, 0, 26))
	curLevelLabel.ZIndex = modal.ZIndex + 3

	local curMultLabel = UILib.CreateLabel(currentCard, "CurMult", "1.00x Multiplier", UILib.Colors.TextSecondary, 12, UILib.Fonts.Medium,
		UDim2.new(0, 12, 0, 58), UDim2.new(1, -24, 0, 16))
	curMultLabel.ZIndex = modal.ZIndex + 3

	-- Arrow indicator
	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Name = "Arrow"
	arrowLabel.Size = UDim2.new(0.1, 0, 0, 30)
	arrowLabel.Position = UDim2.new(0.45, 0, 0.5, -15)
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Text = ">"
	arrowLabel.TextColor3 = ACCENT
	arrowLabel.TextSize = 24
	arrowLabel.Font = UILib.Fonts.Black
	arrowLabel.ZIndex = modal.ZIndex + 2
	arrowLabel.Parent = compFrame

	-- Next Level Card
	local nextCard = Instance.new("Frame")
	nextCard.Name = "NextCard"
	nextCard.Size = UDim2.new(0.45, 0, 1, 0)
	nextCard.Position = UDim2.new(0.55, 0, 0, 0)
	nextCard.BackgroundColor3 = UILib.Colors.Surface2
	nextCard.BorderSizePixel = 0
	nextCard.ZIndex = modal.ZIndex + 2
	nextCard.Parent = compFrame
	UILib.ApplyCorner(nextCard, 10)
	UILib.ApplyStroke(nextCard, ACCENT, 1, 0.4)

	UILib.CreateLabel(nextCard, "CardTitle", "AFTER TRANSCENDENCE", ACCENT, 10, UILib.Fonts.Bold,
		UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 0, 14))

	local nxtLevelLabel = UILib.CreateLabel(nextCard, "NxtLevel", "Level 1", ACCENT, 22, UILib.Fonts.Black,
		UDim2.new(0, 12, 0, 28), UDim2.new(1, -24, 0, 26))
	nxtLevelLabel.ZIndex = modal.ZIndex + 3

	local nxtMultLabel = UILib.CreateLabel(nextCard, "NxtMult", "1.25x Multiplier", UILib.Colors.TextPrimary, 12, UILib.Fonts.Bold,
		UDim2.new(0, 12, 0, 58), UDim2.new(1, -24, 0, 16))
	nxtMultLabel.ZIndex = modal.ZIndex + 3

	-- Rewards Pills
	local rewardsFrame = Instance.new("Frame")
	rewardsFrame.Name = "Rewards"
	rewardsFrame.Size = UDim2.new(1, -24, 0, 22)
	rewardsFrame.Position = UDim2.new(0, 12, 0, 84)
	rewardsFrame.BackgroundTransparency = 1
	rewardsFrame.ZIndex = modal.ZIndex + 3
	rewardsFrame.Parent = nextCard

	local rLayout = Instance.new("UIListLayout")
	rLayout.FillDirection = Enum.FillDirection.Horizontal
	rLayout.Padding = UDim.new(0, 4)
	rLayout.Parent = rewardsFrame

	UILib.CreatePill(rewardsFrame, "+3 CP", UILib.Colors.PurpleLight, UDim2.new(), UDim2.new(0, 52, 0, 18))
	UILib.CreatePill(rewardsFrame, "+100 SL", UILib.Colors.Pink, UDim2.new(), UDim2.new(0, 58, 0, 18))
	UILib.CreatePill(rewardsFrame, "+25%", UILib.Colors.Gold, UDim2.new(), UDim2.new(0, 44, 0, 18))

	-- Retains info
	local retainsLabel = UILib.CreateLabel(modal, "Retains", "Retains: Gems, Pets, Gamepasses, Compendium", UILib.Colors.TextMuted, 10, UILib.Fonts.Body,
		UDim2.new(0, 16, 0, 198), UDim2.new(1, -32, 0, 14), Enum.TextXAlignment.Center)
	retainsLabel.ZIndex = modal.ZIndex + 2

	-- Progress Bar
	local progSection = Instance.new("Frame")
	progSection.Name = "ProgressSection"
	progSection.Size = UDim2.new(1, -32, 0, 50)
	progSection.Position = UDim2.new(0, 16, 0, 224)
	progSection.BackgroundTransparency = 1
	progSection.ZIndex = modal.ZIndex + 1
	progSection.Parent = modal

	local progressText = Instance.new("TextLabel")
	progressText.Name = "ProgressText"
	progressText.Size = UDim2.new(1, 0, 0, 16)
	progressText.BackgroundTransparency = 1
	progressText.Text = "Cycle Stardust: 0 / 50,000"
	progressText.TextColor3 = UILib.Colors.TextSecondary
	progressText.TextSize = 12
	progressText.Font = UILib.Fonts.Bold
	progressText.TextXAlignment = Enum.TextXAlignment.Left
	progressText.ZIndex = modal.ZIndex + 2
	progressText.Parent = progSection

	local progBg, progFill = UILib.CreateProgressBar(
		progSection, "RebirthProg",
		UDim2.new(0, 0, 0, 24),
		UDim2.new(1, 0, 0, 10),
		ACCENT
	)

	-- Transcend Button
	local transcendBtn = Instance.new("TextButton")
	transcendBtn.Name = "TranscendButton"
	transcendBtn.Size = UDim2.new(1, -32, 0, 52)
	transcendBtn.Position = UDim2.new(0, 16, 1, -70)
	transcendBtn.BackgroundColor3 = UILib.Colors.Surface3
	transcendBtn.BorderSizePixel = 0
	transcendBtn.Text = "MORE STARDUST NEEDED"
	transcendBtn.TextColor3 = UILib.Colors.TextMuted
	transcendBtn.TextSize = 16
	transcendBtn.Font = UILib.Fonts.Bold
	transcendBtn.ZIndex = modal.ZIndex + 2
	transcendBtn.Parent = modal
	UILib.ApplyCorner(transcendBtn, 12)

	transcendBtn.MouseButton1Click:Connect(function()
		local data = RebirthModal._data
		if not data then return end

		local reqCost = math.floor(Config.Rebirth.RebirthCostBase * (Config.Rebirth.RebirthCostExponent ^ (data.Rebirth.Level or 0)))
		local totalEarned = data.TotalStardustEarned or 0

		if totalEarned >= reqCost then
			SoundController.Play("RebirthAscend")
			VFXController.FlashScreen(ACCENT, 0.75, 1.2)
			VFXController.AddCameraTrauma(0.8)

			local ecoReq = ReplicatedStorage:FindFirstChild("EconomyRequest") :: RemoteFunction?
			if ecoReq then
				ecoReq:InvokeServer("Rebirth")
			end
			RebirthModal.Close()
		else
			SoundController.Play("ButtonHover")
		end
	end)
end

function RebirthModal.Refresh()
	local modal = RebirthModal._frame
	if not modal then return end
	local data = RebirthModal._data
	if not data then return end

	local currentLvl = data.Rebirth and data.Rebirth.Level or 0
	local currentMult = data.Rebirth and data.Rebirth.CosmicMultiplier or 1.0
	local nextLvl = currentLvl + 1
	local nextMult = Config.Rebirth.CosmicMultiplierBase + (nextLvl * Config.Rebirth.CosmicMultiplierPerLevel)

	-- Update comparison cards
	local comp = modal:FindFirstChild("Comparison")
	if comp then
		local curCard = comp:FindFirstChild("CurrentCard")
		local nxtCard = comp:FindFirstChild("NextCard")
		if curCard then
			local cl = curCard:FindFirstChild("CurLevel") :: TextLabel?
			local cm = curCard:FindFirstChild("CurMult") :: TextLabel?
			if cl then cl.Text = string.format("Level %d", currentLvl) end
			if cm then cm.Text = string.format("%.2fx Multiplier", currentMult) end
		end
		if nxtCard then
			local nl = nxtCard:FindFirstChild("NxtLevel") :: TextLabel?
			local nm = nxtCard:FindFirstChild("NxtMult") :: TextLabel?
			if nl then nl.Text = string.format("Level %d", nextLvl) end
			if nm then nm.Text = string.format("%.2fx Multiplier", nextMult) end
		end
	end

	-- Update progress
	local reqCost = math.floor(Config.Rebirth.RebirthCostBase * (Config.Rebirth.RebirthCostExponent ^ currentLvl))
	local totalEarned = data.TotalStardustEarned or 0
	local canRebirth = totalEarned >= reqCost
	local pct = math.clamp(totalEarned / reqCost, 0, 1)

	local progSection = modal:FindFirstChild("ProgressSection")
	if progSection then
		local pText = progSection:FindFirstChild("ProgressText") :: TextLabel?
		local fillFrame = progSection:FindFirstChild("RebirthProgBg")
		local fill = fillFrame and fillFrame:FindFirstChild("Fill") :: Frame?
		if pText then
			pText.Text = string.format("Cycle Stardust: %s / %s (%d%%)",
				UILib.FormatNumber(totalEarned), UILib.FormatNumber(reqCost), math.floor(pct * 100))
		end
		if fill then
			TweenService:Create(fill, UILib.Timing.Normal, {
				Size = UDim2.fromScale(pct, 1),
			}):Play()
		end
	end

	-- Update transcend button
	local btn = modal:FindFirstChild("TranscendButton") :: TextButton?
	if btn then
		if canRebirth then
			btn.BackgroundColor3 = Color3.fromRGB(190, 24, 93)
			btn.TextColor3 = UILib.Colors.TextPrimary
			btn.Text = "TRANSCEND NOW"

			-- Add gradient when available
			local existing = btn:FindFirstChildOfClass("UIGradient")
			if not existing then
				local grad = Instance.new("UIGradient")
				grad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 200)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 180, 200)),
				})
				grad.Rotation = 90
				grad.Parent = btn
			end
		else
			btn.BackgroundColor3 = UILib.Colors.Surface3
			btn.TextColor3 = UILib.Colors.TextMuted
			btn.Text = "MORE STARDUST NEEDED"
			local existing = btn:FindFirstChildOfClass("UIGradient")
			if existing then existing:Destroy() end
		end
	end
end

function RebirthModal.Open()
	if not RebirthModal._frame then return end
	UILib.OpenModal(RebirthModal._frame)
	RebirthModal.Refresh()
end

function RebirthModal.Close()
	if not RebirthModal._frame then return end
	UILib.CloseModal(RebirthModal._frame)
end

function RebirthModal.Update(data: any)
	RebirthModal._data = data
	if RebirthModal._frame and RebirthModal._frame.Visible then
		RebirthModal.Refresh()
	end
end

return RebirthModal
