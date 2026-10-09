--!strict
--[[
	HeistController.luau — Client Heist Event Listener & Camera Juice for VAULT WARS
	Handles Breach Alarms, Server Relic Notifications, and Heist Announcements.
	Located in: StarterPlayerScripts.Client.Controllers.HeistController
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local HeistController = {}

local function getVaultHUD(): any?
	local uiFolder = script.Parent.Parent:FindFirstChild("UI")
	local hud = uiFolder and uiFolder:FindFirstChild("VaultHUD")
	if hud then return require(hud :: ModuleScript) end
	return nil
end

function HeistController.Init()
	print("  [HeistController] Initializing Client Heist Listener...")

	-- 1. Breach Alert (Your vault is being raided!)
	local breachEvt = ReplicatedStorage:WaitForChild("BreachAlert", 15) :: RemoteEvent?
	if breachEvt then
		breachEvt.OnClientEvent:Connect(function(intruderName: string)
			local hud = getVaultHUD()
			if hud then
				hud.ShowBreachAlert(intruderName)
			end
		end)
	end

	-- 2. Rare Relic Minted Broadcast
	local relicEvt = ReplicatedStorage:WaitForChild("RelicMinted", 15) :: RemoteEvent?
	if relicEvt then
		relicEvt.OnClientEvent:Connect(function(ownerName: string, relicName: string, tier: string, value: number)
			HeistController.ShowRelicDropToast(ownerName, relicName, tier, value)
		end)
	end

	-- 3. Successful Heist Broadcast
	local heistEvt = ReplicatedStorage:WaitForChild("HeistBroadcast", 15) :: RemoteEvent?
	if heistEvt then
		heistEvt.OnClientEvent:Connect(function(thiefName: string, victimName: string, itemName: string, value: number)
			HeistController.ShowHeistSuccessToast(thiefName, victimName, itemName, value)
		end)
	end

	print("  [HeistController] Client Heist Listener online ✓")
end

function HeistController.ShowRelicDropToast(ownerName: string, relicName: string, tier: string, value: number)
	local pGui = player:FindFirstChildOfClass("PlayerGui")
	if not pGui then return end

	local hud = pGui:FindFirstChild("VaultWarsHUD")
	if not hud then return end

	local toast = Instance.new("Frame")
	toast.Name = "RelicToast"
	toast.Size = UDim2.new(0, 420, 0, 44)
	toast.Position = UDim2.new(0.5, 0, 0, 105)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	toast.BorderSizePixel = 0
	toast.Parent = hud
	Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)
	local tStroke = Instance.new("UIStroke", toast)
	tStroke.Color = (tier == "Secret") and Color3.fromRGB(250, 204, 21) or Color3.fromRGB(168, 85, 247)
	tStroke.Thickness = 2

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = `✨ [{tier}] {relicName} minted in {ownerName}'s Vault! (+$` .. tostring(value) .. `)`
	label.TextColor3 = tStroke.Color
	label.TextSize = 12
	label.Font = Enum.Font.GothamBold
	label.Parent = toast

	task.delay(4.5, function()
		if toast and toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, 70),
				BackgroundTransparency = 1,
			}):Play()
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

function HeistController.ShowHeistSuccessToast(thiefName: string, victimName: string, itemName: string, value: number)
	local pGui = player:FindFirstChildOfClass("PlayerGui")
	if not pGui then return end

	local hud = pGui:FindFirstChild("VaultWarsHUD")
	if not hud then return end

	local toast = Instance.new("Frame")
	toast.Name = "HeistToast"
	toast.Size = UDim2.new(0, 460, 0, 46)
	toast.Position = UDim2.new(0.5, 0, 0, 155)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.BackgroundColor3 = Color3.fromRGB(11, 13, 20)
	toast.BorderSizePixel = 0
	toast.Parent = hud
	Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)
	local tStroke = Instance.new("UIStroke", toast)
	tStroke.Color = Color3.fromRGB(239, 68, 68)
	tStroke.Thickness = 2

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = `💰 {thiefName} stole {victimName}'s {itemName} (+$` .. tostring(value) .. `)!`
	label.TextColor3 = Color3.fromRGB(254, 202, 202)
	label.TextSize = 12
	label.Font = Enum.Font.GothamBlack
	label.Parent = toast

	task.delay(5.0, function()
		if toast and toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, 120),
				BackgroundTransparency = 1,
			}):Play()
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

return HeistController
