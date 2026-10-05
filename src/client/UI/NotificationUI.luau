--!strict
--[[
	NotificationUI.luau — Toast & Popup Notification System for STARWEAVE
	Handles harvest results, rare mutation announcements, weather alerts,
	and general game notifications with smooth slide-in animations.
	Located in: StarterPlayerScripts.Client.UI.NotificationUI
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UILib = require(script.Parent.UILib)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local NotificationUI = {}
NotificationUI._gui = nil :: ScreenGui?
NotificationUI._container = nil :: Frame?

local MUTATION_COLORS: { [string]: Color3 } = {
	None       = Color3.fromRGB(120, 120, 130),
	Sprout     = Color3.fromRGB(74, 222, 128),
	Bloom      = Color3.fromRGB(56, 189, 248),
	Radiant    = Color3.fromRGB(255, 204, 0),
	Astral     = Color3.fromRGB(168, 85, 247),
	Celestial  = Color3.fromRGB(244, 114, 182),
	Primordial = Color3.fromRGB(248, 250, 252),
}

function NotificationUI.Create()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notifications"
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = playerGui
	NotificationUI._gui = gui

	-- Toast container (right side, vertical stack)
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 300, 0.55, 0)
	container.Position = UDim2.new(1, -310, 0, 66)
	container.BackgroundTransparency = 1
	container.ZIndex = 20
	container.Parent = gui
	NotificationUI._container = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	-- Center rare popup
	local centerPopup = Instance.new("Frame")
	centerPopup.Name = "CenterPopup"
	centerPopup.Size = UDim2.new(0, 420, 0, 200)
	centerPopup.Position = UDim2.fromScale(0.5, 0.5)
	centerPopup.AnchorPoint = Vector2.new(0.5, 0.5)
	centerPopup.BackgroundColor3 = UILib.Colors.Surface1
	centerPopup.BackgroundTransparency = 0.04
	centerPopup.BorderSizePixel = 0
	centerPopup.Visible = false
	centerPopup.ZIndex = 30
	centerPopup.Parent = gui
	UILib.ApplyCorner(centerPopup, 16)

	-- Gradient depth
	local popGrad = Instance.new("UIGradient")
	popGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 22, 55)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 6, 22)),
	})
	popGrad.Rotation = 135
	popGrad.Parent = centerPopup

	local popStroke = Instance.new("UIStroke")
	popStroke.Name = "PopStroke"
	popStroke.Color = UILib.Colors.PurpleLight
	popStroke.Thickness = 2
	popStroke.Transparency = 0.2
	popStroke.Parent = centerPopup

	-- Glow circle behind title
	local glowCircle = Instance.new("Frame")
	glowCircle.Name = "Glow"
	glowCircle.Size = UDim2.new(0, 120, 0, 120)
	glowCircle.Position = UDim2.new(0.5, -60, 0, -30)
	glowCircle.BackgroundColor3 = UILib.Colors.Purple
	glowCircle.BackgroundTransparency = 0.85
	glowCircle.BorderSizePixel = 0
	glowCircle.ZIndex = 31
	glowCircle.Parent = centerPopup
	UILib.ApplyPill(glowCircle)

	local popTitle = Instance.new("TextLabel")
	popTitle.Name = "Title"
	popTitle.Size = UDim2.new(1, -40, 0, 30)
	popTitle.Position = UDim2.new(0, 20, 0, 24)
	popTitle.BackgroundTransparency = 1
	popTitle.Text = "RARE MUTATION"
	popTitle.TextColor3 = UILib.Colors.Gold
	popTitle.TextSize = 24
	popTitle.Font = UILib.Fonts.Black
	popTitle.ZIndex = 32
	popTitle.Parent = centerPopup

	local popDetails = Instance.new("TextLabel")
	popDetails.Name = "Details"
	popDetails.Size = UDim2.new(1, -40, 0, 60)
	popDetails.Position = UDim2.new(0, 20, 0, 64)
	popDetails.BackgroundTransparency = 1
	popDetails.Text = ""
	popDetails.TextColor3 = UILib.Colors.TextPrimary
	popDetails.TextSize = 14
	popDetails.Font = UILib.Fonts.Medium
	popDetails.TextWrapped = true
	popDetails.TextYAlignment = Enum.TextYAlignment.Top
	popDetails.ZIndex = 32
	popDetails.Parent = centerPopup

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "Close"
	closeBtn.Size = UDim2.new(0, 140, 0, 36)
	closeBtn.Position = UDim2.new(0.5, -70, 1, -50)
	closeBtn.BackgroundColor3 = UILib.Colors.Purple
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "AWESOME"
	closeBtn.TextColor3 = UILib.Colors.TextPrimary
	closeBtn.TextSize = 14
	closeBtn.Font = UILib.Fonts.Bold
	closeBtn.ZIndex = 32
	closeBtn.Parent = centerPopup
	UILib.ApplyCorner(closeBtn, 8)

	local closeGrad = Instance.new("UIGradient")
	closeGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 220)),
	})
	closeGrad.Rotation = 90
	closeGrad.Parent = closeBtn

	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, UILib.Timing.Fast, {
			Size = UDim2.new(0, 146, 0, 38),
		}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, UILib.Timing.Fast, {
			Size = UDim2.new(0, 140, 0, 36),
		}):Play()
	end)
	closeBtn.MouseButton1Click:Connect(function()
		TweenService:Create(centerPopup, UILib.Timing.ModalOut, {
			Position = UDim2.fromScale(0.5, 0.53),
			BackgroundTransparency = 0.5,
		}):Play()
		task.delay(0.25, function()
			centerPopup.Visible = false
		end)
	end)
end

-- ============================================================
-- TOAST (right side, auto-dismiss)
-- ============================================================
function NotificationUI.ShowToast(message: string, color: Color3?, duration: number?)
	if not NotificationUI._container then return end

	local toastColor = color or UILib.Colors.Surface3
	local toastDuration = duration or 3

	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.new(1, 0, 0, 44)
	toast.BackgroundColor3 = toastColor
	toast.BackgroundTransparency = 0.12
	toast.BorderSizePixel = 0
	toast.LayoutOrder = math.floor(os.clock() * 100)
	toast.ZIndex = 21
	toast.Parent = NotificationUI._container
	UILib.ApplyCorner(toast, 8)

	-- Subtle left accent bar
	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(0, 3, 1, -8)
	accentBar.Position = UDim2.new(0, 4, 0, 4)
	accentBar.BackgroundColor3 = Color3.new(
		math.min(toastColor.R * 1.5, 1),
		math.min(toastColor.G * 1.5, 1),
		math.min(toastColor.B * 1.5, 1)
	)
	accentBar.BorderSizePixel = 0
	accentBar.ZIndex = 22
	accentBar.Parent = toast
	UILib.ApplyPill(accentBar)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -24, 1, 0)
	label.Position = UDim2.new(0, 14, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = UILib.Colors.TextPrimary
	label.TextSize = 12
	label.Font = UILib.Fonts.Bold
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 22
	label.Parent = toast

	-- Slide in from right
	toast.Position = UDim2.new(1, 20, 0, 0)
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0, 0),
	}):Play()

	-- Auto-dismiss
	task.delay(toastDuration, function()
		if not toast.Parent then return end
		TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 20, 0, 0),
			BackgroundTransparency = 0.6,
		}):Play()
		TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
		task.delay(0.3, function()
			if toast.Parent then toast:Destroy() end
		end)
	end)
end

-- ============================================================
-- HARVEST NOTIFICATION
-- ============================================================
function NotificationUI.ShowHarvest(harvestData: any)
	if not harvestData then return end

	local tier = harvestData.MutationTier or "None"
	local color = MUTATION_COLORS[tier] or MUTATION_COLORS.None
	local value = harvestData.FinalValue or 0
	local multiplier = harvestData.MutationMultiplier or 1

	if harvestData.IsRare then
		NotificationUI._showRarePopup(harvestData)
	end

	local tierSymbol = {
		None = "-", Sprout = "+", Bloom = "++",
		Radiant = "*", Astral = "**", Celestial = "***", Primordial = "!",
	}
	local sym = tierSymbol[tier] or "-"
	local msg = string.format("[%s] %s (%dx) > %s SD", sym, tier, multiplier, UILib.FormatNumber(value))
	NotificationUI.ShowToast(msg, Color3.new(color.R * 0.35, color.G * 0.35, color.B * 0.35), 4)

	if harvestData.IsNewCollection then
		task.delay(0.5, function()
			NotificationUI.ShowToast("NEW COLLECTION ENTRY", Color3.fromRGB(20, 50, 80), 3)
		end)
	end
end

function NotificationUI._showRarePopup(data: any)
	if not NotificationUI._gui then return end
	local popup = NotificationUI._gui:FindFirstChild("CenterPopup") :: Frame?
	if not popup then return end

	local tier = data.MutationTier or "Astral"
	local color = MUTATION_COLORS[tier] or MUTATION_COLORS.Astral

	local stroke = popup:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = color end

	local glow = popup:FindFirstChild("Glow") :: Frame?
	if glow then glow.BackgroundColor3 = color end

	local titleLabel = popup:FindFirstChild("Title") :: TextLabel?
	if titleLabel then
		if tier == "Primordial" then
			titleLabel.Text = "PRIMORDIAL MUTATION"
		elseif tier == "Celestial" then
			titleLabel.Text = "CELESTIAL MUTATION"
		else
			titleLabel.Text = "RARE MUTATION"
		end
		titleLabel.TextColor3 = color
	end

	local detailsLabel = popup:FindFirstChild("Details") :: TextLabel?
	if detailsLabel then
		detailsLabel.Text = string.format(
			"Mutation Tier: %s\nMultiplier: %dx\nStardust Earned: %s",
			tier, data.MutationMultiplier or 1, UILib.FormatNumber(data.FinalValue or 0)
		)
	end

	popup.Visible = true
	popup.BackgroundTransparency = 0.3
	popup.Position = UDim2.fromScale(0.5, 0.54)

	TweenService:Create(popup, UILib.Timing.ModalIn, {
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.04,
	}):Play()
end

-- ============================================================
-- WEATHER NOTIFICATION
-- ============================================================
function NotificationUI.ShowWeather(weatherData: any)
	if type(weatherData) == "boolean" then
		if weatherData then
			NotificationUI.ShowToast("⚡ MUTATION STORM ACTIVE — All luck x2", Color3.fromRGB(88, 28, 152), 5)
		else
			NotificationUI.ShowToast("✨ The celestial storm has subsided", Color3.fromRGB(32, 40, 68), 3)
		end
		return
	end

	if not weatherData or not weatherData.IsActive then
		NotificationUI.ShowToast("✨ The cosmic storm has passed — Sanctuary is calm", Color3.fromRGB(32, 40, 68), 3)
		return
	end

	local title = string.format("%s %s [%s]", weatherData.Icon or "⚡", weatherData.Name or "COSMIC EVENT", weatherData.MultiplierText or "")
	NotificationUI.ShowToast(title, weatherData.BadgeColor or Color3.fromRGB(88, 28, 152), 5)
end

-- ============================================================
-- SERVER ANNOUNCEMENT
-- ============================================================
function NotificationUI.ShowAnnouncement(message: string, tier: string?)
	local color = UILib.Colors.Surface3
	if tier then
		local c = MUTATION_COLORS[tier]
		if c then
			color = Color3.new(c.R * 0.25, c.G * 0.25, c.B * 0.25)
		end
	end
	NotificationUI.ShowToast(message, color, 5)
end

return NotificationUI
