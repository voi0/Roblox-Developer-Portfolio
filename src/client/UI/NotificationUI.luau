--!strict
--[[
	NotificationUI.luau — Popup notification system for STARWEAVE
	Handles harvest results, rare mutation announcements, weather alerts,
	and general game notifications.
	Located in: StarterPlayerScripts.Client.UI.NotificationUI
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local NotificationUI = {}
NotificationUI._gui = nil :: ScreenGui?
NotificationUI._container = nil :: Frame?

-- Tier colors for mutation notifications
local TIER_COLORS: { [string]: Color3 } = {
	None = Color3.fromRGB(150, 150, 150),
	Sprout = Color3.fromRGB(100, 255, 100),
	Bloom = Color3.fromRGB(100, 200, 255),
	Radiant = Color3.fromRGB(255, 215, 0),
	Astral = Color3.fromRGB(180, 100, 255),
	Celestial = Color3.fromRGB(255, 100, 200),
	Primordial = Color3.fromRGB(255, 255, 255),
}

function NotificationUI.Create()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notifications"
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	NotificationUI._gui = gui

	-- Notification container (right side, stacks vertically)
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 320, 0.6, 0)
	container.Position = UDim2.new(1, -330, 0, 60)
	container.BackgroundTransparency = 1
	container.Parent = gui
	NotificationUI._container = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	-- Center popup for rare mutations
	local centerPopup = Instance.new("Frame")
	centerPopup.Name = "CenterPopup"
	centerPopup.Size = UDim2.fromScale(0.5, 0.3)
	centerPopup.Position = UDim2.fromScale(0.25, 0.35)
	centerPopup.BackgroundColor3 = Color3.fromRGB(15, 10, 35)
	centerPopup.BackgroundTransparency = 0.1
	centerPopup.BorderSizePixel = 0
	centerPopup.Visible = false
	centerPopup.Parent = gui

	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, 16)
	popupCorner.Parent = centerPopup

	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color = Color3.fromRGB(180, 100, 255)
	popupStroke.Thickness = 3
	popupStroke.Parent = centerPopup

	-- Popup title
	local popupTitle = Instance.new("TextLabel")
	popupTitle.Name = "Title"
	popupTitle.Size = UDim2.new(1, 0, 0.3, 0)
	popupTitle.BackgroundTransparency = 1
	popupTitle.Text = "🌟 RARE MUTATION!"
	popupTitle.TextColor3 = Color3.fromRGB(255, 215, 80)
	popupTitle.TextScaled = true
	popupTitle.Font = Enum.Font.GothamBold
	popupTitle.Parent = centerPopup

	-- Popup details
	local popupDetails = Instance.new("TextLabel")
	popupDetails.Name = "Details"
	popupDetails.Size = UDim2.new(0.9, 0, 0.5, 0)
	popupDetails.Position = UDim2.new(0.05, 0, 0.3, 0)
	popupDetails.BackgroundTransparency = 1
	popupDetails.Text = ""
	popupDetails.TextColor3 = Color3.fromRGB(220, 220, 255)
	popupDetails.TextScaled = true
	popupDetails.Font = Enum.Font.Gotham
	popupDetails.TextWrapped = true
	popupDetails.Parent = centerPopup

	-- Popup close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "Close"
	closeBtn.Size = UDim2.new(0.4, 0, 0, 35)
	closeBtn.Position = UDim2.new(0.3, 0, 1, -45)
	closeBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 160)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "Awesome! ✨"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = centerPopup

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		centerPopup.Visible = false
	end)
end

-- ============================================================
-- TOAST NOTIFICATIONS (right side, auto-dismiss)
-- ============================================================

function NotificationUI.ShowToast(message: string, color: Color3?, duration: number?)
	if not NotificationUI._container then return end

	local toastColor = color or Color3.fromRGB(60, 50, 100)
	local toastDuration = duration or 3

	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.new(1, 0, 0, 50)
	toast.BackgroundColor3 = toastColor
	toast.BackgroundTransparency = 0.15
	toast.BorderSizePixel = 0
	toast.LayoutOrder = os.clock() :: number
	toast.Parent = NotificationUI._container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = toast

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextWrapped = true
	label.Parent = toast

	local labelPadding = Instance.new("UIPadding")
	labelPadding.PaddingLeft = UDim.new(0, 12)
	labelPadding.PaddingRight = UDim.new(0, 12)
	labelPadding.PaddingTop = UDim.new(0, 6)
	labelPadding.PaddingBottom = UDim.new(0, 6)
	labelPadding.Parent = label

	-- Slide in
	toast.Position = UDim2.new(1, 50, 0, 0)
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.fromScale(0, 0),
	}):Play()

	-- Auto-dismiss
	task.delay(toastDuration, function()
		local fadeOut = TweenService:Create(toast, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
		})
		if label then
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
		fadeOut:Play()
		fadeOut.Completed:Wait()
		toast:Destroy()
	end)
end

-- ============================================================
-- HARVEST NOTIFICATION
-- ============================================================

function NotificationUI.ShowHarvest(harvestData: any)
	if not harvestData then return end

	local tier = harvestData.MutationTier or "None"
	local color = TIER_COLORS[tier] or TIER_COLORS.None
	local value = harvestData.FinalValue or 0
	local multiplier = harvestData.MutationMultiplier or 1

	if harvestData.IsRare then
		-- BIG center popup for rare mutations
		NotificationUI._showRarePopup(harvestData)
	end

	-- Always show toast
	local tierEmoji = {
		None = "🌿", Sprout = "🌱", Bloom = "🌸",
		Radiant = "✨", Astral = "🔮", Celestial = "🌌", Primordial = "💫",
	}
	local emoji = tierEmoji[tier] or "🌿"

	local msg = `{emoji} {tier} ({multiplier}x) → ⭐{NotificationUI._formatNumber(value)}`
	NotificationUI.ShowToast(msg, Color3.new(color.R * 0.4, color.G * 0.4, color.B * 0.4), 4)

	if harvestData.IsNewCollection then
		task.delay(0.5, function()
			NotificationUI.ShowToast("📚 NEW COLLECTION ENTRY!", Color3.fromRGB(50, 80, 140), 3)
		end)
	end
end

function NotificationUI._showRarePopup(data: any)
	if not NotificationUI._gui then return end
	local popup = NotificationUI._gui:FindFirstChild("CenterPopup") :: Frame?
	if not popup then return end

	local tier = data.MutationTier or "Astral"
	local color = TIER_COLORS[tier] or TIER_COLORS.Astral

	local stroke = popup:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = color end

	local titleLabel = popup:FindFirstChild("Title") :: TextLabel?
	if titleLabel then
		if tier == "Primordial" then
			titleLabel.Text = "💫 PRIMORDIAL MUTATION! 💫"
		elseif tier == "Celestial" then
			titleLabel.Text = "🌌 CELESTIAL MUTATION!"
		else
			titleLabel.Text = "🔮 RARE MUTATION!"
		end
		titleLabel.TextColor3 = color
	end

	local detailsLabel = popup:FindFirstChild("Details") :: TextLabel?
	if detailsLabel then
		detailsLabel.Text = `Mutation: {tier}\nMultiplier: {data.MutationMultiplier}x\nValue: ⭐{NotificationUI._formatNumber(data.FinalValue or 0)}`
	end

	popup.Visible = true
	popup.Size = UDim2.fromScale(0.05, 0.05)
	popup.Position = UDim2.fromScale(0.475, 0.475)

	TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
		Size = UDim2.fromScale(0.5, 0.3),
		Position = UDim2.fromScale(0.25, 0.35),
	}):Play()
end

-- ============================================================
-- WEATHER NOTIFICATION
-- ============================================================

function NotificationUI.ShowWeather(isActive: boolean)
	if isActive then
		NotificationUI.ShowToast("⚡ MUTATION STORM! All mutation chances 2x!", Color3.fromRGB(80, 40, 120), 5)
	else
		NotificationUI.ShowToast("🌤️ Mutation Storm has passed.", Color3.fromRGB(40, 40, 60), 3)
	end
end

-- ============================================================
-- SERVER ANNOUNCEMENT
-- ============================================================

function NotificationUI.ShowAnnouncement(message: string, tier: string?)
	local color = Color3.fromRGB(60, 40, 100)
	if tier then
		color = TIER_COLORS[tier] or color
		color = Color3.new(color.R * 0.3, color.G * 0.3, color.B * 0.3)
	end
	NotificationUI.ShowToast(message, color, 5)
end

function NotificationUI._formatNumber(n: number): string
	if n >= 1e15 then return string.format("%.2fQ", n / 1e15)
	elseif n >= 1e12 then return string.format("%.2fT", n / 1e12)
	elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
	elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
	else return tostring(math.floor(n))
	end
end

return NotificationUI
