--!strict
--[[
	CustomPromptController.luau — Tactical 3D Keycap ProximityPrompt Engine
	Constructs high-fidelity tactile 3D billboards for in-world interactions:
	- Stylized [ E ] tactile keycap box with beveled depth
	- Animated radial / linear hold progress fill for channeled interactions
	- Bold typography with Contextual stroke outlines
	- Mobile touch interaction support
	Located in: StarterPlayerScripts.Client.Controllers.CustomPromptController
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local CustomPromptController = {}
local activePrompts: { [ProximityPrompt]: { Gui: BillboardGui, Cleanup: () -> () } } = {}

local SCREEN_GUI_NAME = "VaultWarsCustomPrompts"
local promptContainerGui: ScreenGui? = nil

local function getContainerGui(): ScreenGui
	if promptContainerGui and promptContainerGui.Parent then
		return promptContainerGui
	end

	local existing = playerGui:FindFirstChild(SCREEN_GUI_NAME) :: ScreenGui?
	if existing then
		promptContainerGui = existing
		return existing
	end

	local sg = Instance.new("ScreenGui")
	sg.Name = SCREEN_GUI_NAME
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 15
	sg.Parent = playerGui
	promptContainerGui = sg
	return sg
end

local function getKeyName(prompt: ProximityPrompt): string
	local key = prompt.KeyboardKeyCode
	if key == Enum.KeyCode.E then
		return "E"
	elseif key == Enum.KeyCode.F then
		return "F"
	elseif key == Enum.KeyCode.Q then
		return "Q"
	elseif key == Enum.KeyCode.R then
		return "R"
	elseif key == Enum.KeyCode.X then
		return "X"
	end
	return key.Name
end

-- ============================================================
-- BUILD CUSTOM PROMPT BILLBOARD
-- ============================================================
local function createPromptGui(prompt: ProximityPrompt): (BillboardGui, () -> ())
	local adorneePart: BasePart? = nil
	if prompt.Parent:IsA("BasePart") then
		adorneePart = prompt.Parent :: BasePart
	elseif prompt.Parent:IsA("Attachment") then
		adorneePart = (prompt.Parent :: Attachment).Parent :: BasePart?
	elseif prompt.Parent:IsA("Model") then
		adorneePart = (prompt.Parent :: Model).PrimaryPart
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = `Prompt_{prompt.Name}`
	billboard.Adornee = adorneePart or prompt.Parent
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.new(0, 240, 0, 64)
	billboard.StudsOffset = Vector3.new(0, 2.0, 0)
	billboard.MaxDistance = prompt.MaxActivationDistance + 6
	billboard.ResetOnSpawn = false
	billboard.Parent = getContainerGui()

	-- Master Card Container
	local card = Instance.new("Frame")
	card.Name = "PromptCard"
	card.Size = UDim2.new(1, 0, 1, 0)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	card.BackgroundTransparency = 0.15
	card.BorderSizePixel = 0
	card.Parent = billboard

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardStroke.Color = Color3.fromRGB(51, 65, 85)
	cardStroke.Thickness = 1.2
	cardStroke.Parent = card

	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 0.82
	cardScale.Parent = card

	-- Tactile Keycap Frame (Left Side)
	local keycapHolder = Instance.new("Frame")
	keycapHolder.Name = "KeycapHolder"
	keycapHolder.Size = UDim2.new(0, 44, 0, 44)
	keycapHolder.Position = UDim2.new(0, 10, 0.5, -22)
	keycapHolder.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
	keycapHolder.BorderSizePixel = 0
	keycapHolder.Parent = card

	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 8)
	keyCorner.Parent = keycapHolder

	local keyStroke = Instance.new("UIStroke")
	keyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	keyStroke.Color = Color3.fromRGB(71, 85, 105)
	keyStroke.Thickness = 1.5
	keyStroke.Parent = keycapHolder

	local keyGrad = Instance.new("UIGradient")
	keyGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(51, 65, 85)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 32, 47)),
	})
	keyGrad.Rotation = 90
	keyGrad.Parent = keycapHolder

	-- Hold Progress Bar (Surrounds keycap / bottom underline)
	local holdTrack = Instance.new("Frame")
	holdTrack.Name = "HoldTrack"
	holdTrack.Size = UDim2.new(1, 0, 0, 3)
	holdTrack.Position = UDim2.new(0, 0, 1, -3)
	holdTrack.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	holdTrack.BorderSizePixel = 0
	holdTrack.Parent = keycapHolder

	local holdFill = Instance.new("Frame")
	holdFill.Name = "HoldFill"
	holdFill.Size = UDim2.new(0, 0, 1, 0)
	holdFill.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
	holdFill.BorderSizePixel = 0
	holdFill.Parent = holdTrack

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyText"
	keyLabel.Size = UDim2.new(1, 0, 1, -3)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text = getKeyName(prompt)
	keyLabel.TextColor3 = Color3.fromRGB(248, 250, 252)
	keyLabel.TextSize = 18
	keyLabel.Font = Enum.Font.BuilderSansExtraBold
	keyLabel.Parent = keycapHolder

	-- Text Container (Right Side)
	local textHolder = Instance.new("Frame")
	textHolder.Name = "TextHolder"
	textHolder.Size = UDim2.new(1, -66, 1, -12)
	textHolder.Position = UDim2.new(0, 60, 0, 6)
	textHolder.BackgroundTransparency = 1
	textHolder.Parent = card

	local objectLabel = Instance.new("TextLabel")
	objectLabel.Name = "ObjectLabel"
	objectLabel.Size = UDim2.new(1, 0, 0, 16)
	objectLabel.Position = UDim2.new(0, 0, 0, 6)
	objectLabel.BackgroundTransparency = 1
	objectLabel.Text = string.upper(prompt.ObjectText ~= "" and prompt.ObjectText or "INTERACTION")
	objectLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
	objectLabel.TextSize = 10
	objectLabel.Font = Enum.Font.BuilderSansBold
	objectLabel.TextXAlignment = Enum.TextXAlignment.Left
	objectLabel.Parent = textHolder

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "ActionLabel"
	actionLabel.Size = UDim2.new(1, 0, 0, 22)
	actionLabel.Position = UDim2.new(0, 0, 0, 22)
	actionLabel.BackgroundTransparency = 1
	actionLabel.Text = string.upper(prompt.ActionText ~= "" and prompt.ActionText or "INTERACT")
	actionLabel.TextColor3 = Color3.fromRGB(248, 250, 252)
	actionLabel.TextSize = 14
	actionLabel.Font = Enum.Font.BuilderSansExtraBold
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.Parent = textHolder

	-- Mobile Touch Button Overlay
	local touchBtn = Instance.new("TextButton")
	touchBtn.Name = "TouchTrigger"
	touchBtn.Size = UDim2.new(1, 0, 1, 0)
	touchBtn.BackgroundTransparency = 1
	touchBtn.Text = ""
	touchBtn.Parent = card

	touchBtn.MouseButton1Down:Connect(function()
		prompt:InputHoldBegin()
	end)
	touchBtn.MouseButton1Up:Connect(function()
		prompt:InputHoldEnd()
	end)

	-- Entrance Animation
	TweenService:Create(cardScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1.0,
	}):Play()

	-- Hold Animations
	local activeHoldTween: Tween? = nil

	local holdBeganConn = prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			holdFill.Size = UDim2.new(0, 0, 1, 0)
			if activeHoldTween then activeHoldTween:Cancel() end
			activeHoldTween = TweenService:Create(holdFill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
				Size = UDim2.new(1, 0, 1, 0),
			})
			activeHoldTween:Play()

			TweenService:Create(keyStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
				Color = Color3.fromRGB(56, 189, 248),
			}):Play()
		end
	end)

	local holdEndedConn = prompt.PromptButtonHoldEnded:Connect(function()
		if activeHoldTween then
			activeHoldTween:Cancel()
			activeHoldTween = nil
		end
		TweenService:Create(holdFill, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
			Size = UDim2.new(0, 0, 1, 0),
		}):Play()
		TweenService:Create(keyStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			Color = Color3.fromRGB(71, 85, 105),
		}):Play()
	end)

	local triggeredConn = prompt.Triggered:Connect(function()
		-- Tactile trigger pulse
		TweenService:Create(cardScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.08,
		}):Play()
		task.delay(0.08, function()
			if cardScale and cardScale.Parent then
				TweenService:Create(cardScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = 1.0,
				}):Play()
			end
		end)
	end)

	local function cleanup()
		holdBeganConn:Disconnect()
		holdEndedConn:Disconnect()
		triggeredConn:Disconnect()
		if activeHoldTween then activeHoldTween:Cancel() end

		if card and card.Parent then
			local exitTween = TweenService:Create(cardScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 0.7,
			})
			exitTween:Play()
			exitTween.Completed:Once(function()
				billboard:Destroy()
			end)
		else
			billboard:Destroy()
		end
	end

	return billboard, cleanup
end

-- ============================================================
-- PROXIMITY PROMPT SERVICE HOOKS
-- ============================================================
local function onPromptShown(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end

	if activePrompts[prompt] then
		activePrompts[prompt].Cleanup()
		activePrompts[prompt] = nil
	end

	local gui, cleanup = createPromptGui(prompt)
	activePrompts[prompt] = {
		Gui = gui,
		Cleanup = cleanup,
	}
end

local function onPromptHidden(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local record = activePrompts[prompt]
	if record then
		record.Cleanup()
		activePrompts[prompt] = nil
	end
end

function CustomPromptController.Init()
	print("  [CustomPromptController] Initializing Tactile 3D ProximityPrompt Engine...")

	ProximityPromptService.PromptShown:Connect(onPromptShown)
	ProximityPromptService.PromptHidden:Connect(onPromptHidden)

	print("  [CustomPromptController] Custom ProximityPrompt hooks registered ✓")
end

return CustomPromptController
