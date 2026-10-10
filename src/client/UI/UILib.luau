--!strict
--[[
	UILib.luau — Shared Visual Design System for STARWEAVE
	Provides reusable factory functions for creating polished, game-quality
	UI components with consistent styling, animations, and visual depth.
	Located in: StarterPlayerScripts.Client.UI.UILib
]]

local TweenService = game:GetService("TweenService")

local UILib = {}

local function getCameraController(): any?
	local controllers = script.Parent.Parent:FindFirstChild("Controllers")
	local mod = controllers and controllers:FindFirstChild("CameraController")
	if mod then
		return require(mod :: ModuleScript)
	end
	return nil
end

local function getSoundController(): any?
	local controllers = script.Parent.Parent:FindFirstChild("Controllers")
	local mod = controllers and controllers:FindFirstChild("SoundController")
	if mod then
		return require(mod :: ModuleScript)
	end
	return nil
end

-- ============================================================
-- DESIGN TOKENS (Vibrant, Kid-Friendly Roblox Simulator Style)
-- ============================================================
UILib.Colors = {
	-- 2026 Bento-Grid Carbon & Obsidian Palette
	Surface0    = Color3.fromRGB(7, 9, 14),       -- Deep obsidian background
	Surface1    = Color3.fromRGB(15, 17, 26),     -- Dark carbon modal surface
	Surface2    = Color3.fromRGB(22, 25, 38),     -- Elevated bento card face
	Surface3    = Color3.fromRGB(30, 36, 54),     -- Hover state
	Surface4    = Color3.fromRGB(42, 50, 76),     -- Active pressed state

	-- Text (Crisp White and Cool Slate)
	TextPrimary   = Color3.fromRGB(248, 250, 252),
	TextSecondary = Color3.fromRGB(203, 213, 225),
	TextMuted     = Color3.fromRGB(148, 163, 184),

	-- Sleek Metallic & Cyber Borders
	StrokeDark    = Color3.fromRGB(30, 41, 59),     -- Refined dark slate outline
	StrokeGold    = Color3.fromRGB(245, 158, 11),
	StrokeCyan    = Color3.fromRGB(56, 189, 248),

	-- Neon Cyber-Heist Accents
	Gold        = Color3.fromRGB(245, 158, 11),     -- Bullion Amber Gold
	GoldBright  = Color3.fromRGB(254, 240, 138),
	GoldDark    = Color3.fromRGB(217, 119, 6),
	Cyan        = Color3.fromRGB(56, 189, 248),     -- Electric Cyan
	CyanBright  = Color3.fromRGB(186, 230, 253),
	CyanDark    = Color3.fromRGB(3, 105, 161),
	Pink        = Color3.fromRGB(244, 114, 182),
	PinkBright  = Color3.fromRGB(249, 168, 212),
	PinkDark    = Color3.fromRGB(190, 24, 93),
	Green       = Color3.fromRGB(16, 185, 129),     -- Emerald Vault Green
	GreenBright = Color3.fromRGB(110, 231, 183),
	GreenDark   = Color3.fromRGB(5, 150, 105),
	Purple      = Color3.fromRGB(168, 85, 247),     -- Arcane Singularity Purple
	PurpleLight = Color3.fromRGB(216, 180, 254),
	PurpleDark  = Color3.fromRGB(126, 34, 206),
	PurpleDim   = Color3.fromRGB(109, 40, 217),
	GreenDim    = Color3.fromRGB(6, 78, 59),
	Red         = Color3.fromRGB(239, 68, 68),      -- Breach Crimson
	Orange      = Color3.fromRGB(249, 115, 22),

	-- Tier Colors
	Common     = Color3.fromRGB(148, 163, 184),
	Uncommon   = Color3.fromRGB(74, 222, 128),
	Rare       = Color3.fromRGB(56, 189, 248),
	Epic       = Color3.fromRGB(239, 68, 68),
	Legendary  = Color3.fromRGB(245, 158, 11),
	Celestial  = Color3.fromRGB(250, 204, 21),
	Void       = Color3.fromRGB(168, 85, 247),
}

UILib.TierColor = {
	Common     = UILib.Colors.Common,
	Uncommon   = UILib.Colors.Uncommon,
	Rare       = UILib.Colors.Rare,
	Epic       = UILib.Colors.Epic,
	Legendary  = UILib.Colors.Legendary,
	Celestial  = UILib.Colors.Celestial,
	Void       = UILib.Colors.Void,
}

-- 2026 Modern Professional Typography
UILib.Fonts = {
	Black  = Enum.Font.BuilderSansExtraBold,
	Bold   = Enum.Font.BuilderSansBold,
	Medium = Enum.Font.BuilderSansMedium,
	Body   = Enum.Font.BuilderSans,
	Alt    = Enum.Font.BuilderSansExtraBold,
	Mono   = Enum.Font.BuilderMono,
}

UILib.Icons = {
	Stardust     = "rbxassetid://6031075931",
	NebulaGems   = "rbxassetid://6031075929",
	Starlight    = "rbxassetid://6031075933",
	CosmicMult   = "rbxassetid://6031075938",
	Shop         = "rbxassetid://6031075927",
	Forge        = "rbxassetid://6031075935",
	Quests       = "rbxassetid://6031075936",
	Pets         = "rbxassetid://6031075937",
	Stars        = "rbxassetid://6031075930",
	Codex        = "rbxassetid://6031075928",
	Transcend    = "rbxassetid://6031075934",
	Checkmark    = "rbxassetid://6031075932",
	Lock         = "rbxassetid://6031075926",
}

UILib.Timing = {
	Fast     = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Standard = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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

function UILib.ApplyStroke(parent: GuiObject, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(16, 12, 28)
	stroke.Thickness = thickness or 2
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

function UILib.ApplyTextStroke(parent: TextLabel | TextButton, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UILib.Colors.StrokeDark
	stroke.Thickness = thickness or 2.5
	stroke.Transparency = 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = parent
	return stroke
end

function UILib.CreateGlassCard(parent: GuiObject, size: UDim2, pos: UDim2, anchor: Vector2?): Frame
	local card = Instance.new("Frame")
	card.Size = size
	card.Position = pos
	card.AnchorPoint = anchor or Vector2.zero
	card.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	card.BackgroundTransparency = 0.18
	card.BorderSizePixel = 0
	card.Parent = parent

	-- 16px Bento Corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card

	-- Specular Rim Stroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.4
	stroke.Color = Color3.fromRGB(56, 189, 248)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card

	-- Diffuse Glass Gradient
	local bgGrad = Instance.new("UIGradient")
	bgGrad.Rotation = 90
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(30, 36, 54)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(15, 17, 26)),
	})
	bgGrad.Parent = card

	return card
end

function UILib.ApplyLiquidGlassStyle(frame: Frame, accentColor: Color3?): UIStroke
	frame.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0

	local corner = frame:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 16)
		corner.Parent = frame
	end

	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = frame
	end
	stroke.Thickness = 1.6
	stroke.Color = accentColor or Color3.fromRGB(56, 189, 248)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local bgGrad = frame:FindFirstChild("GlassBgGradient") :: UIGradient?
	if not bgGrad then
		bgGrad = Instance.new("UIGradient")
		bgGrad.Name = "GlassBgGradient"
		bgGrad.Rotation = 90
		bgGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(28, 34, 52)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(13, 15, 22)),
		})
		bgGrad.Parent = frame
	end

	return stroke
end


function UILib.ApplySpringHover(btn: GuiButton, stroke: UIStroke?, accentColor: Color3?)
	local scale = btn:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = btn
	end

	btn.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
		if stroke and accentColor then
			TweenService:Create(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Color = accentColor, Thickness = 2.0 }):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Color = Color3.fromRGB(39, 45, 66), Thickness = 1.2 }):Play()
		end
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Scale = 0.94 }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
	end)
end

function UILib.CreateChunkyButton(
	parent: GuiObject,
	name: string,
	text: string,
	topColor: Color3,
	bottomColor: Color3,
	size: UDim2,
	pos: UDim2,
	iconId: string?
): TextButton
	local container = Instance.new("TextButton")
	container.Name = name
	container.Size = size
	container.Position = pos
	container.BackgroundTransparency = 1
	container.Text = ""
	container.Active = true
	container.AutoButtonColor = false
	container.Selectable = true
	container.Parent = parent

	-- Shadow Base (3D Bevel depth)
	local shadow = Instance.new("Frame")
	shadow.Name = "ShadowBase"
	shadow.Size = UDim2.new(1, 0, 1, -4)
	shadow.Position = UDim2.new(0, 0, 0, 4)
	shadow.BackgroundColor3 = bottomColor:Lerp(Color3.new(0, 0, 0), 0.45)
	shadow.BorderSizePixel = 0
	shadow.Active = false
	shadow.ZIndex = container.ZIndex
	shadow.Parent = container
	UILib.ApplyCorner(shadow, 12)
	UILib.ApplyStroke(shadow, UILib.Colors.StrokeDark, 2.5)

	-- Button Face
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -4)
	face.Position = UDim2.new(0, 0, 0, 0)
	face.BackgroundColor3 = topColor
	face.BorderSizePixel = 0
	face.Active = false
	face.ZIndex = container.ZIndex + 1
	face.Parent = container
	UILib.ApplyCorner(face, 12)
	UILib.ApplyGradient(face, topColor, bottomColor, 90)
	UILib.ApplyStroke(face, UILib.Colors.StrokeDark, 2.5)

	-- Top Glossy Sheen
	local sheen = Instance.new("Frame")
	sheen.Name = "Sheen"
	sheen.Size = UDim2.new(1, -12, 0, 6)
	sheen.Position = UDim2.new(0, 6, 0, 3)
	sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sheen.BackgroundTransparency = 0.65
	sheen.BorderSizePixel = 0
	sheen.ZIndex = container.ZIndex + 2
	sheen.Parent = face
	UILib.ApplyPill(sheen)

	-- Icon & Label
	if iconId and iconId ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(0, 22, 0, 22)
		icon.Position = UDim2.new(0.5, -11, 0, 4)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ZIndex = container.ZIndex + 2
		icon.Parent = face

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, 0, 0, 14)
		label.Position = UDim2.new(0, 0, 1, -18)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 10
		label.Font = UILib.Fonts.Black
		label.ZIndex = container.ZIndex + 2
		label.Parent = face
		UILib.ApplyTextStroke(label, UILib.Colors.StrokeDark, 2.5)
	else
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 12
		label.Font = UILib.Fonts.Black
		label.ZIndex = container.ZIndex + 2
		label.Parent = face
		UILib.ApplyTextStroke(label, UILib.Colors.StrokeDark, 2.5)
	end

	-- Micro-Interactions (Squish down on click, bounce on hover)
	container.MouseEnter:Connect(function()
		TweenService:Create(face, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, -2),
		}):Play()
		TweenService:Create(shadow, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 6),
		}):Play()
	end)

	container.MouseLeave:Connect(function()
		TweenService:Create(face, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0),
		}):Play()
		TweenService:Create(shadow, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 4),
		}):Play()
	end)

	container.MouseButton1Down:Connect(function()
		TweenService:Create(face, TweenInfo.new(0.06), {
			Position = UDim2.new(0, 0, 0, 4),
		}):Play()
	end)

	container.MouseButton1Up:Connect(function()
		TweenService:Create(face, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, -2),
		}):Play()
	end)

	return container
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

	UILib.ApplyCorner(modal, 16)

	-- Dark cartoon outline
	local outerStroke = UILib.ApplyStroke(modal, UILib.Colors.StrokeDark, 3.5, 0)
	outerStroke.Name = "CartoonStroke"

	-- Inner gradient for depth (vibrant deep space navy)
	local innerGrad = Instance.new("UIGradient")
	innerGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 42, 72)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(24, 28, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 18, 36)),
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
	UILib.ApplyCorner(header, 16)

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
	titleLabel.Size = UDim2.new(0.75, 0, 0, 26)
	titleLabel.Position = UDim2.new(0, 20, 0, 9)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.upper(title)
	titleLabel.TextColor3 = accentColor
	titleLabel.TextSize = 20
	titleLabel.Font = UILib.Fonts.Black
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = parent.ZIndex + 2
	titleLabel.Parent = header
	UILib.ApplyTextStroke(titleLabel, UILib.Colors.StrokeDark, 2.5)

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
	UILib.ApplyStroke(btn, UILib.Colors.StrokeDark, 2.5)
	UILib.ApplyTextStroke(btn, UILib.Colors.StrokeDark, 2)

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
	local currentCloseId = (modal:GetAttribute("ModalSeqId") or 0) + 1
	modal:SetAttribute("ModalSeqId", currentCloseId)

	local camCtrl = getCameraController()
	if camCtrl and camCtrl.SetUIFocus then
		camCtrl.SetUIFocus(true)
	end

	local sndCtrl = getSoundController()
	if sndCtrl and sndCtrl.Play then
		sndCtrl.Play("ButtonClick")
	end

	modal.Visible = true
	modal.Position = UDim2.fromScale(0.5, 0.54)
	modal.BackgroundTransparency = 0.3

	local scale = modal:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = modal
	end
	scale.Scale = 0.92

	TweenService:Create(scale, UILib.Timing.ModalIn, { Scale = 1.0 }):Play()
	TweenService:Create(modal, UILib.Timing.ModalIn, {
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.04,
	}):Play()
end

function UILib.CloseModal(modal: Frame)
	local currentCloseId = (modal:GetAttribute("ModalSeqId") or 0) + 1
	modal:SetAttribute("ModalSeqId", currentCloseId)

	local camCtrl = getCameraController()
	if camCtrl and camCtrl.SetUIFocus then
		camCtrl.SetUIFocus(false)
	end

	local sndCtrl = getSoundController()
	if sndCtrl and sndCtrl.Play then
		sndCtrl.Play("ButtonClick")
	end

	local scale = modal:FindFirstChildOfClass("UIScale")
	if scale then
		TweenService:Create(scale, UILib.Timing.ModalOut, { Scale = 0.92 }):Play()
	end

	local tween = TweenService:Create(modal, UILib.Timing.ModalOut, {
		Position = UDim2.fromScale(0.5, 0.54),
		BackgroundTransparency = 0.3,
	})
	tween:Play()
	tween.Completed:Once(function()
		if modal:GetAttribute("ModalSeqId") == currentCloseId then
			modal.Visible = false
			if scale then scale.Scale = 1.0 end
		end
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


-- ============================================================
-- SHAKE ELEMENT (Tactile error feedback)
-- ============================================================
function UILib.ShakeElement(guiObj: GuiObject, errorColor: Color3?)
	local origPos = guiObj.Position
	local origBg = guiObj.BackgroundColor3
	if errorColor then
		guiObj.BackgroundColor3 = errorColor
	end
	task.spawn(function()
		for i = 1, 6 do
			local offset = (i % 2 == 0) and 5 or -5
			guiObj.Position = origPos + UDim2.new(0, offset, 0, 0)
			task.wait(0.03)
		end
		guiObj.Position = origPos
		if errorColor then
			guiObj.BackgroundColor3 = origBg
		end
	end)
end

return UILib
