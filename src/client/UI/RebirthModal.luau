--!strict
--[[
	RebirthModal.luau — Transcendence & Prestige Sanctuary for STARWEAVE
	Presents the Rebirth ascension loop: permanent Cosmic Multipliers,
	Constellation Points, Starlight prestige currency, and Realm unlocks.
	Located in: StarterPlayerScripts.Client.UI.RebirthModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local VFXController = require(script.Parent.Parent.Controllers.VFXController)

local player = Players.LocalPlayer

local RebirthModal = {}
RebirthModal._frame = nil :: Frame?
RebirthModal._data = nil :: any

function RebirthModal.Create(parentGui: ScreenGui)
	local modal = Instance.new("Frame")
	modal.Name = "RebirthModal"
	modal.Size = UDim2.new(0, 520, 0, 460)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.BackgroundColor3 = Color3.fromRGB(15, 11, 28)
	modal.BackgroundTransparency = 0.1
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = parentGui
	RebirthModal._frame = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(244, 114, 182)
	stroke.Thickness = 2
	stroke.Parent = modal

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundTransparency = 1
	header.Parent = modal

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.7, 0, 0, 26)
	title.Position = UDim2.new(0, 20, 0, 12)
	title.BackgroundTransparency = 1
	title.Text = "✨ COSMIC TRANSCENDENCE"
	title.TextColor3 = Color3.fromRGB(244, 114, 182)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(0.7, 0, 0, 16)
	subtitle.Position = UDim2.new(0, 20, 0, 38)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Sacrifice mortal harvest to awaken celestial multipliers"
	subtitle.TextColor3 = Color3.fromRGB(148, 163, 184)
	subtitle.TextScaled = true
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = header

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -44, 0, 12)
	closeBtn.BackgroundColor3 = Color3.fromRGB(30, 22, 50)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(216, 180, 254)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = header

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		SoundController.Play("ButtonClick")
		RebirthModal.Close()
	end)

	-- Center Comparison Frame
	local compFrame = Instance.new("Frame")
	compFrame.Name = "Comparison"
	compFrame.Size = UDim2.new(1, -40, 0, 140)
	compFrame.Position = UDim2.new(0, 20, 0, 72)
	compFrame.BackgroundColor3 = Color3.fromRGB(24, 18, 42)
	compFrame.BorderSizePixel = 0
	compFrame.Parent = modal

	local compCorner = Instance.new("UICorner")
	compCorner.CornerRadius = UDim.new(0, 12)
	compCorner.Parent = compFrame

	local compLayout = Instance.new("UIListLayout")
	compLayout.FillDirection = Enum.FillDirection.Vertical
	compLayout.Padding = UDim.new(0, 8)
	compLayout.Parent = compFrame

	local compPad = Instance.new("UIPadding")
	compPad.PaddingLeft = UDim.new(0, 16)
	compPad.PaddingRight = UDim.new(0, 16)
	compPad.PaddingTop = UDim.new(0, 12)
	compPad.Parent = compFrame

	local currentLabel = Instance.new("TextLabel")
	currentLabel.Name = "CurrentStats"
	currentLabel.Size = UDim2.new(1, 0, 0, 22)
	currentLabel.BackgroundTransparency = 1
	currentLabel.Text = "Current: Level 0 (1.00x Multiplier)"
	currentLabel.TextColor3 = Color3.fromRGB(203, 213, 225)
	currentLabel.TextScaled = true
	currentLabel.Font = Enum.Font.Gotham
	currentLabel.TextXAlignment = Enum.TextXAlignment.Left
	currentLabel.Parent = compFrame

	local nextLabel = Instance.new("TextLabel")
	nextLabel.Name = "NextStats"
	nextLabel.Size = UDim2.new(1, 0, 0, 24)
	nextLabel.BackgroundTransparency = 1
	nextLabel.Text = "Ascension: Level 1 (1.25x Multiplier)"
	nextLabel.TextColor3 = Color3.fromRGB(244, 114, 182)
	nextLabel.TextScaled = true
	nextLabel.Font = Enum.Font.GothamBold
	nextLabel.TextXAlignment = Enum.TextXAlignment.Left
	nextLabel.Parent = compFrame

	local rewardsLabel = Instance.new("TextLabel")
	rewardsLabel.Name = "RewardsStats"
	rewardsLabel.Size = UDim2.new(1, 0, 0, 48)
	rewardsLabel.BackgroundTransparency = 1
	rewardsLabel.Text = "Gains: +3 Constellation Points • +100 Starlight • +25% Earnings Forever\nRetains: Gems, Pets, Gamepasses, & Compendium"
	rewardsLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
	rewardsLabel.TextScaled = true
	rewardsLabel.Font = Enum.Font.Gotham
	rewardsLabel.TextXAlignment = Enum.TextXAlignment.Left
	rewardsLabel.Parent = compFrame

	-- Progress Bar Toward Rebirth
	local progressBox = Instance.new("Frame")
	progressBox.Name = "ProgressBox"
	progressBox.Size = UDim2.new(1, -40, 0, 48)
	progressBox.Position = UDim2.new(0, 20, 0, 226)
	progressBox.BackgroundTransparency = 1
	progressBox.Parent = modal

	local progressText = Instance.new("TextLabel")
	progressText.Name = "ProgressText"
	progressText.Size = UDim2.new(1, 0, 0, 18)
	progressText.BackgroundTransparency = 1
	progressText.Text = "Stardust Required: 0 / 50,000"
	progressText.TextColor3 = Color3.fromRGB(203, 213, 225)
	progressText.TextScaled = true
	progressText.Font = Enum.Font.GothamBold
	progressText.TextXAlignment = Enum.TextXAlignment.Left
	progressText.Parent = progressBox

	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(1, 0, 0, 14)
	barBg.Position = UDim2.new(0, 0, 0, 24)
	barBg.BackgroundColor3 = Color3.fromRGB(30, 24, 48)
	barBg.BorderSizePixel = 0
	barBg.Parent = progressBox

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(244, 114, 182)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = barFill

	-- Big Transcend Button
	local transcendBtn = Instance.new("TextButton")
	transcendBtn.Name = "TranscendButton"
	transcendBtn.Size = UDim2.new(1, -40, 0, 52)
	transcendBtn.Position = UDim2.new(0, 20, 1, -72)
	transcendBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
	transcendBtn.BorderSizePixel = 0
	transcendBtn.Text = "LOCKED"
	transcendBtn.TextColor3 = Color3.fromRGB(113, 113, 122)
	transcendBtn.TextScaled = true
	transcendBtn.Font = Enum.Font.GothamBold
	transcendBtn.Parent = modal

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = transcendBtn

	transcendBtn.MouseButton1Click:Connect(function()
		local data = RebirthModal._data
		if not data then return end

		local reqCost = math.floor(Config.Rebirth.RebirthCostBase * (Config.Rebirth.RebirthCostExponent ^ (data.Rebirth.Level or 0)))
		local totalEarned = data.TotalStardustEarned or 0

		if totalEarned >= reqCost then
			SoundController.Play("RebirthAscend")
			VFXController.FlashScreen(Color3.fromRGB(244, 114, 182), 0.75, 1.2)
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

	local comp = modal:FindFirstChild("Comparison")
	if comp then
		local cur = comp:FindFirstChild("CurrentStats") :: TextLabel?
		local nxt = comp:FindFirstChild("NextStats") :: TextLabel?
		if cur then cur.Text = string.format("Current: Level %d (%.2fx Cosmic Multiplier)", currentLvl, currentMult) end
		if nxt then nxt.Text = string.format("Ascension: Level %d (%.2fx Cosmic Multiplier)", nextLvl, nextMult) end
	end

	local reqCost = math.floor(Config.Rebirth.RebirthCostBase * (Config.Rebirth.RebirthCostExponent ^ currentLvl))
	local totalEarned = data.TotalStardustEarned or 0
	local canRebirth = totalEarned >= reqCost

	local progBox = modal:FindFirstChild("ProgressBox")
	if progBox then
		local pText = progBox:FindFirstChild("ProgressText") :: TextLabel?
		local fill = progBox:FindFirstChild("BarBg") and progBox.BarBg:FindFirstChild("Fill") :: Frame?
		local pct = math.clamp(totalEarned / reqCost, 0, 1)

		if pText then
			pText.Text = string.format("Cycle Stardust: %s / %s (%d%%)", RebirthModal._formatNumber(totalEarned), RebirthModal._formatNumber(reqCost), math.floor(pct * 100))
		end
		if fill then
			fill.Size = UDim2.fromScale(pct, 1)
		end
	end

	local btn = modal:FindFirstChild("TranscendButton") :: TextButton?
	if btn then
		if canRebirth then
			btn.BackgroundColor3 = Color3.fromRGB(219, 39, 119)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.Text = "TRANSCEND NOW ✨"
		else
			btn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
			btn.TextColor3 = Color3.fromRGB(113, 113, 122)
			btn.Text = "MORE STARDUST NEEDED"
		end
	end
end

function RebirthModal._formatNumber(n: number): string
	if n >= 1e12 then return string.format("%.1fT", n / 1e12)
	elseif n >= 1e9 then return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
	else return tostring(math.floor(n))
	end
end

function RebirthModal.Open()
	if not RebirthModal._frame then return end
	RebirthModal._frame.Visible = true
	RebirthModal._frame.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(RebirthModal._frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
	RebirthModal.Refresh()
end

function RebirthModal.Close()
	if not RebirthModal._frame then return end
	local tween = TweenService:Create(RebirthModal._frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0.5, 0.55),
	})
	tween:Play()
	tween.Completed:Once(function()
		RebirthModal._frame.Visible = false
	end)
end

function RebirthModal.Update(data: any)
	RebirthModal._data = data
	if RebirthModal._frame and RebirthModal._frame.Visible then
		RebirthModal.Refresh()
	end
end

return RebirthModal
