--!strict
--[[
	NotificationUI.luau — Tactical Cyber-Glass Toast & Popup System for VAULT WARS
	Displays high-impact notifications for Heists, Rare Relic Drops,
	Security Tackles, Altar Syntheses, and Server Announcements.
	Located in: StarterPlayerScripts.Client.UI.NotificationUI
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local NotificationUI = {}
NotificationUI._gui = nil :: ScreenGui?
NotificationUI._container = nil :: Frame?

local TYPE_COLORS: { [string]: Color3 } = {
	Heist    = Color3.fromRGB(239, 68, 68),
	Relic    = Color3.fromRGB(250, 204, 21),
	Fusion   = Color3.fromRGB(168, 85, 247),
	Defense  = Color3.fromRGB(56, 189, 248),
	Success  = Color3.fromRGB(16, 185, 129),
	Info     = Color3.fromRGB(148, 163, 184),
	Airdrop  = Color3.fromRGB(250, 204, 21),
	Jackpot  = Color3.fromRGB(244, 114, 182),
	Daily    = Color3.fromRGB(34, 197, 94),
	System   = Color3.fromRGB(99, 102, 241),
}

function NotificationUI.Create()
	local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
	if not playerGui then return end

	local existing = playerGui:FindFirstChild("VaultWarsNotifications")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "VaultWarsNotifications"
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = playerGui
	NotificationUI._gui = gui

	-- Right-side toast stack container
	local container = Instance.new("Frame")
	container.Name = "ToastStack"
	container.Size = UDim2.new(0, 320, 0.6, 0)
	container.Position = UDim2.new(1, -336, 0, 80)
	container.BackgroundTransparency = 1
	container.Parent = gui
	NotificationUI._container = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	-- Listen for Server Broadcasts
	task.spawn(function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local notifEvt = ReplicatedStorage:WaitForChild("NotificationBroadcast", 15) :: RemoteEvent?
		if notifEvt then
			notifEvt.OnClientEvent:Connect(function(payload: any)
				if payload and type(payload) == "table" then
					NotificationUI.ShowToast(payload.Type or "Info", payload.Title or "ALERT", payload.Message or "", payload.Duration or 4)
				end
			end)
		end

		local toolEvt = ReplicatedStorage:WaitForChild("ToolFeedback", 15) :: RemoteEvent?
		if toolEvt then
			toolEvt.OnClientEvent:Connect(function(action: string, arg1: any)
				if action == "BatonHitLoot" then
					NotificationUI.ShowToast("Defense", "⚡ BATON SMASH!", `Hit {arg1} and forced loot drop!`, 3.5)
				elseif action == "BatonDropVictim" then
					NotificationUI.ShowToast("Heist", "⚡ STUNNED!", `{arg1} struck you with a Baton! Loot dropped!`, 4)
				elseif action == "BatonHit" then
					NotificationUI.ShowToast("Defense", "⚡ BATON HIT", `Stunned {arg1}!`, 2.5)
				elseif action == "JamSuccess" then
					NotificationUI.ShowToast("Success", "📡 EMP ACTIVE", `Enemy lasers disabled for {arg1}s! Breach now!`, 4)
				elseif action == "JamAlert" then
					NotificationUI.ShowToast("Heist", "🚨 LASERS JAMMED!", `{arg1} disabled your lasers with an EMP!`, 4)
				elseif action == "Cooldown" then
					NotificationUI.ShowToast("Info", "⏳ COOLDOWN", `Device recharging ({arg1}s remaining)`, 2)
				elseif action == "JamNoTarget" then
					NotificationUI.ShowToast("Info", "📡 NO TARGET", "No enemy lasers within 22 studs", 2.5)
				end
			end)
		end
	end)

	print("  [NotificationUI] Tactical Toast Notifications mounted ✓")
end

function NotificationUI.ShowToast(category: string, titleText: string, messageText: string, duration: number?)
	if not NotificationUI._container then return end

	local color = TYPE_COLORS[category] or TYPE_COLORS.Info
	local lifeTime = duration or 3.5

	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.new(1, 0, 0, 56)
	toast.Position = UDim2.new(1, 40, 0, 0) -- starts off-screen
	toast.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	toast.BackgroundTransparency = 0.1
	toast.BorderSizePixel = 0
	toast.Parent = NotificationUI._container

	Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", toast)
	stroke.Color = color
	stroke.Thickness = 1.5

	-- Accent bar on left
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 4, 1, -12)
	bar.Position = UDim2.new(0, 6, 0, 6)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.Parent = toast
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 20)
	title.Position = UDim2.new(0, 18, 0, 6)
	title.BackgroundTransparency = 1
	title.Text = string.upper(titleText)
	title.TextColor3 = color
	title.TextSize = 12
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = toast

	-- Message
	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -24, 0, 22)
	desc.Position = UDim2.new(0, 18, 0, 26)
	desc.BackgroundTransparency = 1
	desc.Text = messageText
	desc.TextColor3 = Color3.fromRGB(226, 232, 240)
	desc.TextSize = 11
	desc.Font = Enum.Font.GothamMedium
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextTruncate = Enum.TextTruncate.AtEnd
	desc.Parent = toast

	-- Entrance Animation
	toast.Position = UDim2.new(1, 40, 0, 0)
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	}):Play()

	-- Dismissal after lifeTime
	task.delay(lifeTime, function()
		if toast and toast.Parent then
			local exitTween = TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(1, 40, 0, 0),
				BackgroundTransparency = 1
			})
			exitTween:Play()
			exitTween.Completed:Once(function()
				toast:Destroy()
			end)
		end
	end)
end

return NotificationUI
