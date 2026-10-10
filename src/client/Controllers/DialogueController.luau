--!strict
--[[
	DialogueController.luau — Cinematic NPC Letterbox & Branching Dialogue Engine
	Inspired by high-production cinematic games (Jazzfunk reference):
	- Letterbox cinematic black framing with smooth slide transitions
	- Character faction badge and styled dialogue card
	- UTF-8 safe RichText typewriter effect driven by MaxVisibleGraphemes
	- Punctuation cadence pauses and pitch-randomized retro audio feedback
	- Click-to-skip typing acceleration
	- Tactile branching choice pills with spring hover effects
	- Automatic Over-The-Shoulder (OTS) camera handoff via CameraController
	Located in: StarterPlayerScripts.Client.Controllers.DialogueController
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local DialogueController = {}
DialogueController._isOpen = false

local dialogueGui: ScreenGui? = nil
local topBar: Frame? = nil
local bottomBar: Frame? = nil
local dialogueCard: Frame? = nil
local nameBadge: TextLabel? = nil
local bodyText: TextLabel? = nil
local choicesHolder: Frame? = nil
local clickCatcher: TextButton? = nil

local isTyping = false
local skipRequested = false
local typingThread: thread? = nil

local function getCameraController(): any?
	local controllers = script.Parent
	local mod = controllers:FindFirstChild("CameraController")
	if mod then
		return require(mod :: ModuleScript)
	end
	return nil
end

local function getSoundController(): any?
	local controllers = script.Parent
	local mod = controllers:FindFirstChild("SoundController")
	if mod then
		return require(mod :: ModuleScript)
	end
	return nil
end

-- ============================================================
-- AUDIO BLIP GENERATOR
-- ============================================================
local blipSound: Sound? = nil

local function playTypingBlip()
	if not blipSound then
		blipSound = Instance.new("Sound")
		blipSound.Name = "DialogueBlip"
		blipSound.SoundId = "rbxassetid://9114223170"
		blipSound.Volume = 0.22
		blipSound.Parent = Workspace
	end
	blipSound.PlaybackSpeed = 0.95 + (math.random() * 0.35)
	blipSound:Play()
end

-- ============================================================
-- GUI INITIALIZATION
-- ============================================================
local function initGui()
	if dialogueGui and dialogueGui.Parent then return end

	local sg = Instance.new("ScreenGui")
	sg.Name = "VaultWarsCinematicDialogue"
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 50
	sg.IgnoreGuiInset = true
	sg.Enabled = false
	sg.Parent = playerGui
	dialogueGui = sg

	-- Top Letterbox Bar
	local top = Instance.new("Frame")
	top.Name = "TopLetterbox"
	top.Size = UDim2.new(1, 0, 0, 56)
	top.Position = UDim2.new(0, 0, 0, -60)
	top.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
	top.BorderSizePixel = 0
	top.Parent = sg
	topBar = top

	-- Bottom Letterbox Bar
	local btm = Instance.new("Frame")
	btm.Name = "BottomLetterbox"
	btm.Size = UDim2.new(1, 0, 0, 210)
	btm.Position = UDim2.new(0, 0, 1, 210)
	btm.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
	btm.BorderSizePixel = 0
	btm.Parent = sg
	bottomBar = btm

	-- Click-to-skip Catcher
	local catcher = Instance.new("TextButton")
	catcher.Name = "ClickToSkipCatcher"
	catcher.Size = UDim2.new(1, 0, 1, 0)
	catcher.BackgroundTransparency = 1
	catcher.Text = ""
	catcher.Parent = btm
	clickCatcher = catcher

	-- Main Centered Dialogue Card
	local card = Instance.new("Frame")
	card.Name = "DialogueCard"
	card.Size = UDim2.new(0, 720, 0, 175)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Parent = btm
	dialogueCard = card

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 12)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardStroke.Color = Color3.fromRGB(51, 65, 85)
	cardStroke.Thickness = 1.2
	cardStroke.Parent = card

	-- Character Name & Tag Badge
	local badgeContainer = Instance.new("Frame")
	badgeContainer.Name = "BadgeContainer"
	badgeContainer.Size = UDim2.new(1, -36, 0, 26)
	badgeContainer.Position = UDim2.new(0, 18, 0, 14)
	badgeContainer.BackgroundTransparency = 1
	badgeContainer.Parent = card

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "SpeakerBadge"
	nameLbl.Size = UDim2.new(1, 0, 1, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = "SYNDICATE BROKER • BLACK MARKET"
	nameLbl.TextColor3 = Color3.fromRGB(245, 158, 11)
	nameLbl.TextSize = 13
	nameLbl.Font = Enum.Font.BuilderSansExtraBold
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Parent = badgeContainer
	nameBadge = nameLbl

	-- Subtitle Text Body
	local text = Instance.new("TextLabel")
	text.Name = "DialogueBody"
	text.Size = UDim2.new(1, -36, 0, 58)
	text.Position = UDim2.new(0, 18, 0, 44)
	text.BackgroundTransparency = 1
	text.RichText = true
	text.Text = ""
	text.TextColor3 = Color3.fromRGB(248, 250, 252)
	text.TextSize = 16
	text.Font = Enum.Font.BuilderSansMedium
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.MaxVisibleGraphemes = 0
	text.Parent = card
	bodyText = text

	-- Interactive Choices Holder (Horizontal Row of Pills)
	local choices = Instance.new("Frame")
	choices.Name = "ChoicesHolder"
	choices.Size = UDim2.new(1, -36, 0, 38)
	choices.Position = UDim2.new(0, 18, 1, -50)
	choices.BackgroundTransparency = 1
	choices.Parent = card
	choicesHolder = choices

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 10)
	listLayout.Parent = choices

	-- Connect Skip
	catcher.MouseButton1Click:Connect(function()
		if isTyping then
			skipRequested = true
		end
	end)
end

-- ============================================================
-- TYPEWRITER ENGINE
-- ============================================================
local function playTypewriter(text: string, onFinished: () -> ())
	if not bodyText then return end

	isTyping = true
	skipRequested = false
	bodyText.Text = text
	bodyText.MaxVisibleGraphemes = 0

	local totalLength = utf8.len(bodyText.ContentText) or string.len(bodyText.ContentText)

	if typingThread then
		task.cancel(typingThread)
		typingThread = nil
	end

	typingThread = task.spawn(function()
		for i = 1, totalLength do
			if skipRequested then
				bodyText.MaxVisibleGraphemes = -1
				break
			end

			bodyText.MaxVisibleGraphemes = i

			-- Check current character for punctuation cadence pauses
			local char = string.sub(bodyText.ContentText, i, i)
			if char == "." or char == "!" or char == "?" then
				playTypingBlip()
				task.wait(0.24)
			elseif char == "," or char == ";" or char == "—" then
				playTypingBlip()
				task.wait(0.12)
			else
				if i % 2 == 1 and char ~= " " then
					playTypingBlip()
				end
				task.wait(0.024)
			end
		end

		bodyText.MaxVisibleGraphemes = -1
		isTyping = false
		skipRequested = false
		onFinished()
	end)
end

-- ============================================================
-- CHOICE PILL FACTORY
-- ============================================================
local function renderChoices(choices: { { Label: string, Style: string?, Callback: () -> () } })
	if not choicesHolder then return end

	for _, child in choicesHolder:GetChildren() do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	for idx, cData in choices do
		local btn = Instance.new("TextButton")
		btn.Name = `Choice_{idx}`
		btn.Size = UDim2.new(0, 0, 1, 0)
		btn.AutomaticSize = Enum.AutomaticSize.X
		btn.BackgroundColor3 = (cData.Style == "Primary") and Color3.fromRGB(245, 158, 11) or Color3.fromRGB(30, 41, 59)
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = choicesHolder

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 16)
		pad.PaddingRight = UDim.new(0, 16)
		pad.Parent = btn

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = (cData.Style == "Primary") and Color3.fromRGB(251, 191, 36) or Color3.fromRGB(51, 65, 85)
		stroke.Thickness = 1.2
		stroke.Parent = btn

		local label = Instance.new("TextLabel")
		label.Name = "ChoiceLabel"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = string.upper(cData.Label)
		label.TextColor3 = (cData.Style == "Primary") and Color3.fromRGB(15, 23, 42) or Color3.fromRGB(248, 250, 252)
		label.TextSize = 12
		label.Font = Enum.Font.BuilderSansExtraBold
		label.Parent = btn

		-- Tactile Hover Springs
		local soundSvc = getSoundController()
		btn.MouseEnter:Connect(function()
			if soundSvc then soundSvc.Play("Hover") end
			TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = (cData.Style == "Primary") and Color3.fromRGB(251, 191, 36) or Color3.fromRGB(51, 65, 85),
			}):Play()
		end)

		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = (cData.Style == "Primary") and Color3.fromRGB(245, 158, 11) or Color3.fromRGB(30, 41, 59),
			}):Play()
		end)

		btn.MouseButton1Click:Connect(function()
			if soundSvc then soundSvc.Play("Click") end
			cData.Callback()
		end)
	end
end

-- ============================================================
-- PUBLIC API
-- ============================================================
export type DialogueChoice = {
	Label: string,
	Style: string?,
	Callback: () -> (),
}

export type DialogueConfig = {
	Speaker: string,
	FactionTag: string?,
	Text: string,
	Choices: { DialogueChoice },
	TargetModel: Model?,
	TargetCFrame: CFrame?,
}

function DialogueController.Open(config: DialogueConfig)
	initGui()
	if not dialogueGui or not topBar or not bottomBar then return end

	DialogueController._isOpen = true
	dialogueGui.Enabled = true

	if nameBadge then
		local tag = config.FactionTag and ` • {string.upper(config.FactionTag)}` or ""
		nameBadge.Text = `{string.upper(config.Speaker)}{tag}`
	end

	-- Camera Cinematic Framing
	local camSvc = getCameraController()
	if camSvc and (config.TargetModel or config.TargetCFrame) then
		local char = player.Character
		local charPos = (char and char:FindFirstChild("HumanoidRootPart")) and (char:FindFirstChild("HumanoidRootPart") :: BasePart).Position or Vector3.new(0, 4, 0)
		local targetPos = config.TargetCFrame and config.TargetCFrame.Position or (config.TargetModel and config.TargetModel:GetPivot().Position) or Vector3.new(0, 4, -40)

		local toTarget = (targetPos - charPos).Unit
		local rightVec = Vector3.new(-toTarget.Z, 0, toTarget.X).Unit
		local eyePos = charPos + (rightVec * 2.4) + Vector3.new(0, 2.0, 0) - (toTarget * 2.8)
		local lookAt = targetPos + Vector3.new(0, 0.8, 0)
		local otsCF = CFrame.lookAt(eyePos, lookAt)

		local dist = (eyePos - targetPos).Magnitude
		camSvc.FocusCinematic(otsCF, dist, 56)
	end

	-- Animate In Letterbox
	TweenService:Create(topBar, TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()

	local btmTween = TweenService:Create(bottomBar, TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 1, -210),
	})
	btmTween:Play()

	-- Start Typewriter
	btmTween.Completed:Once(function()
		playTypewriter(config.Text, function()
			renderChoices(config.Choices)
		end)
	end)
end

function DialogueController.Close(onClosed: (() -> ())?)
	if not DialogueController._isOpen then return end
	DialogueController._isOpen = false

	if typingThread then
		task.cancel(typingThread)
		typingThread = nil
	end

	local camSvc = getCameraController()
	if camSvc then
		camSvc.RestoreDefault()
	end

	if topBar and bottomBar then
		TweenService:Create(topBar, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0, 0, 0, -60),
		}):Play()

		local btmTween = TweenService:Create(bottomBar, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0, 0, 1, 210),
		})
		btmTween:Play()
		btmTween.Completed:Once(function()
			if dialogueGui then
				dialogueGui.Enabled = false
			end
			if onClosed then onClosed() end
		end)
	else
		if dialogueGui then dialogueGui.Enabled = false end
		if onClosed then onClosed() end
	end
end

-- ============================================================
-- SYNDICATE BROKER INTERACTION PRESET
-- ============================================================
function DialogueController.OpenSyndicateBroker(brokerModel: Model?)
	DialogueController.Open({
		Speaker = "Syndicate Broker",
		FactionTag = "Underworld Network",
		Text = "Word on the radio is you've got an eye for rare tech. The underground pays top dollar for stolen relics—bring them here and you'll walk away with more than just pocket change.",
		TargetModel = brokerModel,
		Choices = {
			{
				Label = "View Contracts",
				Style = "Primary",
				Callback = function()
					DialogueController.Close(function()
						local contractModal = script.Parent.Parent:FindFirstChild("UI") and script.Parent.Parent.UI:FindFirstChild("ContractModal")
						if contractModal then
							local cMod = require(contractModal :: ModuleScript)
							if cMod and cMod.Open then cMod.Open() end
						end
					end)
				end,
			},
			{
				Label = "Heist Briefing",
				Style = "Secondary",
				Callback = function()
					DialogueController.Open({
						Speaker = "Syndicate Broker",
						FactionTag = "Intel Briefing",
						Text = "Every bunker has security lasers and heavy vault doors. Use your Stun Baton [1] to breach and crack the cogwheel. Once inside, grab their bullion and dash back to your safe before their alarms trigger!",
						TargetModel = brokerModel,
						Choices = {
							{
								Label = "Understood",
								Style = "Primary",
								Callback = function()
									DialogueController.Close()
								end,
							},
						},
					})
				end,
			},
			{
				Label = "Exit",
				Style = "Secondary",
				Callback = function()
					DialogueController.Close()
				end,
			},
		},
	})
end

function DialogueController.Init()
	print("  [DialogueController] Initializing Cinematic Dialogue Engine...")
	initGui()

	-- Listen for remote trigger from server (e.g. Broker NPC interaction)
	local brokerEvt = ReplicatedStorage:FindFirstChild("OpenBrokerDialogue") :: RemoteEvent?
	if not brokerEvt then
		brokerEvt = Instance.new("RemoteEvent")
		brokerEvt.Name = "OpenBrokerDialogue"
		brokerEvt.Parent = ReplicatedStorage
	end

	brokerEvt.OnClientEvent:Connect(function(brokerModel: Model?)
		DialogueController.OpenSyndicateBroker(brokerModel)
	end)

	print("  [DialogueController] Cinematic Dialogue Engine online ✓")
end

return DialogueController
