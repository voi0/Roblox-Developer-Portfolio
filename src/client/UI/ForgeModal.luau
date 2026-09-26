--!strict
--[[
	ForgeModal.luau — Seed & Mutation Transmutation Altar for STARWEAVE
	Combines botanical specimens into guaranteed higher-tier cosmic seeds.
	Located in: StarterPlayerScripts.Client.UI.ForgeModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SeedData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeedData"))
local MutationData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MutationData"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local VFXController = require(script.Parent.Parent.Controllers.VFXController)

local player = Players.LocalPlayer

local ForgeModal = {}
ForgeModal._frame = nil :: Frame?
ForgeModal._data = nil :: any

function ForgeModal.Create(parentGui: ScreenGui)
	local modal = Instance.new("Frame")
	modal.Name = "ForgeModal"
	modal.Size = UDim2.new(0, 520, 0, 460)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.BackgroundColor3 = Color3.fromRGB(15, 11, 28)
	modal.BackgroundTransparency = 0.1
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = parentGui
	ForgeModal._frame = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(168, 85, 247)
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
	title.Text = "🔮 CELESTIAL SEED FORGE"
	title.TextColor3 = Color3.fromRGB(168, 85, 247)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(0.7, 0, 0, 16)
	subtitle.Position = UDim2.new(0, 20, 0, 38)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Transmute base strains into ascended anomalous seeds"
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
		ForgeModal.Close()
	end)

	-- Center Altar Visual
	local altar = Instance.new("Frame")
	altar.Name = "Altar"
	altar.Size = UDim2.new(1, -40, 0, 220)
	altar.Position = UDim2.new(0, 20, 0, 72)
	altar.BackgroundColor3 = Color3.fromRGB(24, 18, 42)
	altar.BorderSizePixel = 0
	altar.Parent = modal

	local altarCorner = Instance.new("UICorner")
	altarCorner.CornerRadius = UDim.new(0, 12)
	altarCorner.Parent = altar

	local altarStroke = Instance.new("UIStroke")
	altarStroke.Color = Color3.fromRGB(147, 51, 234)
	altarStroke.Thickness = 1.2
	altarStroke.Transparency = 0.4
	altarStroke.Parent = altar

	local altarIcon = Instance.new("TextLabel")
	altarIcon.Size = UDim2.new(1, 0, 0, 70)
	altarIcon.Position = UDim2.new(0, 0, 0, 20)
	altarIcon.BackgroundTransparency = 1
	altarIcon.Text = "⚡ ⚛ ⚡"
	altarIcon.TextColor3 = Color3.fromRGB(192, 132, 252)
	altarIcon.TextScaled = true
	altarIcon.Font = Enum.Font.GothamBold
	altarIcon.Parent = altar

	local altarDesc = Instance.new("TextLabel")
	altarDesc.Size = UDim2.new(0.9, 0, 0, 70)
	altarDesc.Position = UDim2.new(0.05, 0, 0, 110)
	altarDesc.BackgroundTransparency = 1
	altarDesc.Text = "Select 3 identical seeds from your harvest inventory to transmute them into a guaranteed ascended variant with higher base multiplier."
	altarDesc.TextColor3 = Color3.fromRGB(203, 213, 225)
	altarDesc.TextScaled = true
	altarDesc.Font = Enum.Font.Gotham
	altarDesc.TextWrapped = true
	altarDesc.Parent = altar

	-- Forge Action Button
	local forgeBtn = Instance.new("TextButton")
	forgeBtn.Name = "ForgeButton"
	forgeBtn.Size = UDim2.new(1, -40, 0, 52)
	forgeBtn.Position = UDim2.new(0, 20, 1, -72)
	forgeBtn.BackgroundColor3 = Color3.fromRGB(126, 34, 206)
	forgeBtn.BorderSizePixel = 0
	forgeBtn.Text = "TRANSMUTE SPECIMENS"
	forgeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	forgeBtn.TextScaled = true
	forgeBtn.Font = Enum.Font.GothamBold
	forgeBtn.Parent = modal

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = forgeBtn

	forgeBtn.MouseButton1Click:Connect(function()
		SoundController.Play("PlantReady")
		VFXController.AddCameraTrauma(0.3)
	end)
end

function ForgeModal.Open()
	if not ForgeModal._frame then return end
	ForgeModal._frame.Visible = true
	ForgeModal._frame.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(ForgeModal._frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
end

function ForgeModal.Close()
	if not ForgeModal._frame then return end
	local tween = TweenService:Create(ForgeModal._frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0.5, 0.55),
	})
	tween:Play()
	tween.Completed:Once(function()
		ForgeModal._frame.Visible = false
	end)
end

function ForgeModal.Update(data: any)
	ForgeModal._data = data
end

return ForgeModal
