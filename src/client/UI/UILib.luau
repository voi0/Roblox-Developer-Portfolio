--!strict
--[[
	UILib.luau — Shared Visual Design System for STARWEAVE
	Provides reusable factory functions for creating polished, game-quality
	UI components with consistent styling, animations, and visual depth.
	Located in: StarterPlayerScripts.Client.UI.UILib
]]

local TweenService = game:GetService("TweenService")

local UILib = {}

-- ============================================================
-- DESIGN TOKENS
-- ============================================================
UILib.Colors = {
	-- Core Palette
	Surface0    = Color3.fromRGB(7, 3, 18),      -- Deepest background
	Surface1    = Color3.fromRGB(12, 8, 28),      -- Modal/card base
	Surface2    = Color3.fromRGB(20, 14, 40),      -- Elevated card
	Surface3    = Color3.fromRGB(30, 22, 55),      -- Hover/active states
	Surface4    = Color3.fromRGB(42, 32, 72),      -- Pressed states

	-- Text
	TextPrimary   = Color3.fromRGB(248, 250, 252),
	TextSecondary = Color3.fromRGB(168, 162, 190),
	TextMuted     = Color3.fromRGB(105, 98, 130),

	-- Accent
	Purple       = Color3.fromRGB(147, 51, 234),
	PurpleLight  = Color3.fromRGB(192, 132, 252),
	PurpleDim    = Color3.fromRGB(88, 28, 152),

	-- Semantic
	Gold        = Color3.fromRGB(255, 204, 0),
	GoldDim     = Color3.fromRGB(180, 140, 20),
	Cyan        = Color3.fromRGB(56, 189, 248),
	Pink        = Color3.fromRGB(244, 114, 182),
	Green       = Color3.fromRGB(74, 222, 128),
	GreenDim    = Color3.fromRGB(22, 101, 52),
	Red         = Color3.fromRGB(248, 113, 113),
	Orange      = Color3.fromRGB(251, 146, 60),

	-- Tier Colors
	Common     = Color3.fromRGB(148, 163, 184),
	Uncommon   = Color3.fromRGB(74, 222, 128),
	Rare       = Color3.fromRGB(56, 189, 248),
	Epic       = Color3.fromRGB(192, 132, 252),
	Legendary  = Color3.fromRGB(251, 191, 36),
	Celestial  = Color3.fromRGB(244, 114, 182),
	Void       = Color3.fromRGB(147, 51, 234),
}

UILib.TierColor: { [string]: Color3 } = {
	Common     = UILib.Colors.Common,
	Uncommon   = UILib.Colors.Uncommon,
	Rare       = UILib.Colors.Rare,
	Epic       = UILib.Colors.Epic,
	Legendary  = UILib.Colors.Legendary,
	Celestial  = UILib.Colors.Celestial,
	Void       = UILib.Colors.Void,
}

UILib.Fonts = {
	Black  = Enum.Font.GothamBlack,
	Bold   = Enum.Font.GothamBold,
	Medium = Enum.Font.GothamMedium,
	Body   = Enum.Font.Gotham,
}

UILib.Timing = {
	Fast     = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal   = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Smooth   = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	ModalIn  = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	ModalOut = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	Spring   = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
}

-- ============================================================
-- CORNER / STROKE / GRADIENT FACTORIES
-- ============================================================

function UILib.ApplyCorner(parent: GuiObject, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function UILib.ApplyPill(parent: GuiObject): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = parent
	return corner
end

function UILib.ApplyStroke(parent: GuiObject, color: Color3, thickness: number, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function UILib.ApplyGradient(parent: GuiObject, topColor: Color3, bottomColor: Color3, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topColor),
		ColorSequenceKeypoint.new(1, bottomColor),
	})
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

function UILib.ApplyPadding(parent: GuiObject, top: number, right: number?, bottom: number?, left: number?): UIPadding
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, top)
	pad.PaddingRight = UDim.new(0, right or top)
	pad.PaddingBottom = UDim.new(0, bottom or top)
	pad.PaddingLeft = UDim.new(0, left or right or top)
	pad.Parent = parent
	return pad
end

-- ============================================================
-- DROP SHADOW (offset duplicate behind element)
-- ============================================================
function UILib.CreateShadow(parent: GuiObject, radius: number, spread: number?, opacity: number?): Frame
	local shadow = Instance.new("Frame")
	shadow.Name = "_Shadow"
	shadow.Size = UDim2.new(1, (spread or 8) * 2, 1, (spread or 8) * 2)
	shadow.Position = UDim2.new(0, -(spread or 8), 0, (spread or 4))
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 1 - (opacity or 0.35)
	shadow.BorderSizePixel = 0
	shadow.ZIndex = parent.ZIndex - 1
	shadow.Parent = parent
	UILib.ApplyCorner(shadow, radius + 4)
	return shadow
end

-- ============================================================
-- MODAL FRAME (consistent base for all modals)
-- ============================================================
function UILib.CreateModalFrame(
	parentGui: ScreenGui,
	name: string,
	width: number,
	height: number,
	accentColor: Color3
): Frame
	local modal = Instance.new("Frame")
	modal.Name = name
	modal.Size = UDim2.new(0, width, 0, height)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.BackgroundColor3 = UILib.Colors.Surface1
	modal.BackgroundTransparency = 0.04
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 10
	modal.Parent = parentGui

	UILib.ApplyCorner(modal, 14)

	-- Outer glow stroke
	local outerStroke = UILib.ApplyStroke(modal, accentColor, 1.5, 0.3)
	outerStroke.Name = "AccentStroke"

	-- Inner gradient for depth (lighter at top-left)
	local innerGrad = Instance.new("UIGradient")
	innerGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 28, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 8, 28)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 4, 20)),
	})
	innerGrad.Rotation = 135
	innerGrad.Parent = modal

	return modal
end

-- ============================================================
-- MODAL HEADER BAR
-- ============================================================
function UILib.CreateModalHeader(
	parent: Frame,
	title: string,
	subtitle: string,
	accentColor: Color3,
	onClose: () -> ()
): Frame
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 62)
	header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	header.BackgroundTransparency = 0.7
	header.BorderSizePixel = 0
	header.ZIndex = parent.ZIndex + 1
	header.Parent = parent

	-- Only round top corners using a clip frame
	UILib.ApplyCorner(header, 14)

	-- Bottom divider line
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, -32, 0, 1)
	divider.Position = UDim2.new(0, 16, 1, -1)
	divider.BackgroundColor3 = accentColor
	divider.BackgroundTransparency = 0.6
	divider.BorderSizePixel = 0
	divider.ZIndex = parent.ZIndex + 1
	divider.Parent = header

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(0.75, 0, 0, 24)
	titleLabel.Position = UDim2.new(0, 20, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.upper(title)
	titleLabel.TextColor3 = accentColor
	titleLabel.TextSize = 18
	titleLabel.Font = UILib.Fonts.Black
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = parent.ZIndex + 2
	titleLabel.Parent = header

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.new(0.75, 0, 0, 16)
	subtitleLabel.Position = UDim2.new(0, 20, 0, 36)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = UILib.Colors.TextSecondary
	subtitleLabel.TextSize = 13
	subtitleLabel.Font = UILib.Fonts.Body
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.ZIndex = parent.ZIndex + 2
	subtitleLabel.Parent = header

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 34, 0, 34)
	closeBtn.Position = UDim2.new(1, -48, 0, 14)
	closeBtn.BackgroundColor3 = UILib.Colors.Surface3
	closeBtn.BackgroundTransparency = 0.5
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = ""
	closeBtn.ZIndex = parent.ZIndex + 2
	closeBtn.Parent = header
	UILib.ApplyCorner(closeBtn, 8)

	-- X icon using two crossing lines
	local xLine1 = Instance.new("Frame")
	xLine1.Size = UDim2.new(0, 16, 0, 2)
	xLine1.Position = UDim2.new(0.5, -8, 0.5, -1)
	xLine1.BackgroundColor3 = UILib.Colors.TextSecondary
	xLine1.BorderSizePixel = 0
	xLine1.Rotation = 45
	xLine1.ZIndex = parent.ZIndex + 3
	xLine1.Parent = closeBtn

	local xLine2 = Instance.new("Frame")
	xLine2.Size = UDim2.new(0, 16, 0, 2)
	xLine2.Position = UDim2.new(0.5, -8, 0.5, -1)
	xLine2.BackgroundColor3 = UILib.Colors.TextSecondary
	xLine2.BorderSizePixel = 0
	xLine2.Rotation = -45
	xLine2.ZIndex = parent.ZIndex + 3
	xLine2.Parent = closeBtn

	-- Hover
	UILib.ApplyHover(closeBtn, UILib.Colors.Surface4, 0.3)

	closeBtn.MouseButton1Click:Connect(function()
		onClose()
	end)

	return header
end

-- ============================================================
-- ACTION BUTTON (Primary CTA)
-- ============================================================
function UILib.CreateActionButton(
	parent: GuiObject,
	text: string,
	color: Color3,
	size: UDim2,
	position: UDim2,
	onClick: () -> ()
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = "ActionButton"
	btn.Size = size
	btn.Position = position
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Text = string.upper(text)
	btn.TextColor3 = UILib.Colors.TextPrimary
	btn.TextSize = 16
	btn.Font = UILib.Fonts.Bold
	btn.ZIndex = parent.ZIndex + 1
	btn.Parent = parent

	UILib.ApplyCorner(btn, 10)

	-- Gradient overlay for depth
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
	})
	grad.Rotation = 90
	grad.Parent = btn

	-- Interaction
	UILib.ApplyHover(btn)
	btn.MouseButton1Click:Connect(onClick)

	return btn
end

-- ============================================================
-- HOVER + PRESS INTERACTIVITY
-- ============================================================
function UILib.ApplyHover(btn: GuiButton, hoverColor: Color3?, hoverTransparency: number?)
	local originalSize = btn.Size
	local originalColor = btn.BackgroundColor3
	local hColor = hoverColor or originalColor
	local hTrans = hoverTransparency

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, UILib.Timing.Fast, {
			Size = UDim2.new(
				originalSize.X.Scale, originalSize.X.Offset + 4,
				originalSize.Y.Scale, originalSize.Y.Offset + 2
			),
			BackgroundColor3 = hColor,
			BackgroundTransparency = hTrans or btn.BackgroundTransparency,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, UILib.Timing.Fast, {
			Size = originalSize,
			BackgroundColor3 = originalColor,
			BackgroundTransparency = btn.BackgroundTransparency,
		}):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, UILib.Timing.Fast, {
			Size = UDim2.new(
				originalSize.X.Scale, originalSize.X.Offset - 2,
				originalSize.Y.Scale, originalSize.Y.Offset - 1
			),
		}):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, UILib.Timing.Fast, {
			Size = originalSize,
		}):Play()
	end)
end

-- ============================================================
-- MODAL OPEN / CLOSE ANIMATIONS
-- ============================================================
function UILib.OpenModal(modal: Frame)
	modal.Visible = true
	modal.BackgroundTransparency = 0.3
	modal.Position = UDim2.fromScale(0.5, 0.54)

	local children = modal:GetDescendants()
	for _, child in children do
		if child:IsA("GuiObject") then
			child.Visible = true
		end
	end

	TweenService:Create(modal, UILib.Timing.ModalIn, {
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.04,
	}):Play()
end

function UILib.CloseModal(modal: Frame)
	local tween = TweenService:Create(modal, UILib.Timing.ModalOut, {
		Position = UDim2.fromScale(0.5, 0.54),
		BackgroundTransparency = 0.3,
	})
	tween:Play()
	tween.Completed:Once(function()
		modal.Visible = false
	end)
end

-- ============================================================
-- SCROLLING FRAME (styled)
-- ============================================================
function UILib.CreateScrollFrame(parent: GuiObject, name: string, size: UDim2, position: UDim2, accentColor: Color3?): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name
	scroll.Size = size
	scroll.Position = position
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = accentColor or UILib.Colors.Purple
	scroll.ScrollBarImageTransparency = 0.4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = parent.ZIndex + 1
	scroll.Parent = parent
	return scroll
end

-- ============================================================
-- CARD FRAME (for grids)
-- ============================================================
function UILib.CreateCard(parent: GuiObject, name: string, accentColor: Color3): Frame
	local card = Instance.new("Frame")
	card.Name = name
	card.BackgroundColor3 = UILib.Colors.Surface2
	card.BorderSizePixel = 0
	card.ZIndex = parent.ZIndex + 1
	card.Parent = parent

	UILib.ApplyCorner(card, 10)
	UILib.ApplyStroke(card, accentColor, 1, 0.55)

	-- Subtle gradient
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 22, 48)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 12, 32)),
	})
	grad.Rotation = 160
	grad.Parent = card

	return card
end

-- ============================================================
-- LABEL FACTORY
-- ============================================================
function UILib.CreateLabel(
	parent: GuiObject,
	name: string,
	text: string,
	color: Color3,
	fontSize: number,
	font: Enum.Font,
	position: UDim2,
	size: UDim2,
	align: Enum.TextXAlignment?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = fontSize
	label.Font = font
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = parent.ZIndex + 1
	label.Parent = parent
	return label
end

-- ============================================================
-- PROGRESS BAR
-- ============================================================
function UILib.CreateProgressBar(parent: GuiObject, name: string, position: UDim2, size: UDim2, fillColor: Color3): (Frame, Frame)
	local bg = Instance.new("Frame")
	bg.Name = name .. "Bg"
	bg.Size = size
	bg.Position = position
	bg.BackgroundColor3 = UILib.Colors.Surface0
	bg.BorderSizePixel = 0
	bg.ZIndex = parent.ZIndex + 1
	bg.Parent = parent
	UILib.ApplyPill(bg)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.ZIndex = parent.ZIndex + 2
	fill.Parent = bg
	UILib.ApplyPill(fill)

	-- Shimmer effect on fill
	local shimmer = Instance.new("UIGradient")
	shimmer.Name = "Shimmer"
	shimmer.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(200, 200, 200)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(200, 200, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	shimmer.Parent = fill

	return bg, fill
end

-- ============================================================
-- ANIMATED SHIMMER (for loading bars, cards)
-- ============================================================
function UILib.AnimateShimmer(gradient: UIGradient)
	task.spawn(function()
		while gradient.Parent do
			gradient.Offset = Vector2.new(-1, 0)
			local tween = TweenService:Create(gradient, TweenInfo.new(1.5, Enum.EasingStyle.Linear), {
				Offset = Vector2.new(1, 0),
			})
			tween:Play()
			tween.Completed:Wait()
		end
	end)
end

-- ============================================================
-- NUMBER FORMATTING
-- ============================================================
function UILib.FormatNumber(n: number): string
	if n >= 1e15 then return string.format("%.2fQ", n / 1e15)
	elseif n >= 1e12 then return string.format("%.2fT", n / 1e12)
	elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
	elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
	else return tostring(math.floor(n))
	end
end

-- ============================================================
-- PILL BADGE (small tier/status indicator)
-- ============================================================
function UILib.CreatePill(parent: GuiObject, text: string, color: Color3, position: UDim2, size: UDim2?): Frame
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Size = size or UDim2.new(0, 70, 0, 18)
	pill.Position = position
	pill.BackgroundColor3 = color
	pill.BackgroundTransparency = 0.75
	pill.BorderSizePixel = 0
	pill.ZIndex = parent.ZIndex + 2
	pill.Parent = parent
	UILib.ApplyPill(pill)
	UILib.ApplyStroke(pill, color, 1, 0.4)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = string.upper(text)
	label.TextColor3 = color
	label.TextSize = 10
	label.Font = UILib.Fonts.Bold
	label.ZIndex = parent.ZIndex + 3
	label.Parent = pill

	return pill
end

-- ============================================================
-- CURRENCY DISPLAY (icon + value, compact)
-- ============================================================
function UILib.CreateCurrencyDisplay(parent: GuiObject, name: string, iconText: string, color: Color3, position: UDim2): TextLabel
	local container = Instance.new("Frame")
	container.Name = name .. "Display"
	container.Size = UDim2.new(0, 120, 0, 36)
	container.Position = position
	container.BackgroundColor3 = UILib.Colors.Surface2
	container.BackgroundTransparency = 0.4
	container.BorderSizePixel = 0
	container.ZIndex = parent.ZIndex + 1
	container.Parent = parent
	UILib.ApplyPill(container)
	UILib.ApplyStroke(container, color, 1, 0.6)

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 28, 1, 0)
	icon.Position = UDim2.new(0, 6, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Text = iconText
	icon.TextColor3 = color
	icon.TextSize = 16
	icon.Font = UILib.Fonts.Bold
	icon.ZIndex = parent.ZIndex + 2
	icon.Parent = container

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(1, -38, 1, 0)
	valueLabel.Position = UDim2.new(0, 34, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = "0"
	valueLabel.TextColor3 = color
	valueLabel.TextSize = 14
	valueLabel.Font = UILib.Fonts.Bold
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.ZIndex = parent.ZIndex + 2
	valueLabel.Parent = container

	return valueLabel
end

return UILib
