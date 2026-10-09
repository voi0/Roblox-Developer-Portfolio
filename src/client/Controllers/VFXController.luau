--!strict
--[[
	VFXController.luau — Visual Effects & Tactical Screen Dynamics for VAULT WARS
	Handles quadratic camera shake, 3D floating cash indicators,
	laser electric shock sparks, security tackle shockwave rings, and radiant synthesis pillars.
	Located in: StarterPlayerScripts.Client.Controllers.VFXController
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local VFXController = {}
VFXController._shakeTrauma = 0
VFXController._screenGui = nil :: ScreenGui?
VFXController._flashFrame = nil :: Frame?

function VFXController.Init()
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "VFX_Overlay"
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 999
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	VFXController._screenGui = screenGui

	local flashFrame = Instance.new("Frame")
	flashFrame.Name = "ScreenFlash"
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.Parent = screenGui
	VFXController._flashFrame = flashFrame

	-- Camera Shake Loop with Quadratic Decay
	local random = Random.new()
	RunService.RenderStepped:Connect(function(dt)
		if VFXController._shakeTrauma > 0 then
			local trauma = VFXController._shakeTrauma
			local shakeAmount = trauma * trauma
			local yaw = (random:NextNumber() - 0.5) * shakeAmount * 0.045
			local pitch = (random:NextNumber() - 0.5) * shakeAmount * 0.045
			local roll = (random:NextNumber() - 0.5) * shakeAmount * 0.035

			camera.CFrame = camera.CFrame * CFrame.Angles(pitch, yaw, roll)
			VFXController._shakeTrauma = math.max(0, VFXController._shakeTrauma - dt * 2.0)
		end
	end)

	print("  [VFXController] Tactical VFX & Dynamics Engine online ✓")
end

function VFXController.AddCameraTrauma(amount: number)
	VFXController._shakeTrauma = math.clamp(VFXController._shakeTrauma + amount, 0, 1)
end

function VFXController.FlashScreen(color: Color3, maxAlpha: number, duration: number)
	local flash = VFXController._flashFrame
	if not flash then return end

	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - maxAlpha

	local tween = TweenService:Create(flash, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	tween:Play()
end

-- ============================================================
-- 3D FLOATING CASH NOTIFIER
-- ============================================================
function VFXController.PlayCashDepositBurst(worldPos: Vector3, text: string)
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.Position = worldPos + Vector3.new(0, 1.5, 0)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = Workspace

	local bGui = Instance.new("BillboardGui")
	bGui.Size = UDim2.new(0, 140, 0, 36)
	bGui.AlwaysOnTop = true
	bGui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(16, 185, 129)
	label.TextSize = 18
	label.Font = Enum.Font.GothamBlack
	label.Parent = bGui

	local floatTween = TweenService:Create(anchor, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = worldPos + Vector3.new(0, 5.5, 0)
	})
	local fadeTween = TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1
	})

	floatTween:Play()
	fadeTween:Play()

	Debris:AddItem(anchor, 1.3)
end

-- ============================================================
-- LASER ELECTRIC SHOCK IMPACT
-- ============================================================
function VFXController.PlayLaserShock(worldPos: Vector3)
	VFXController.AddCameraTrauma(0.3)
	VFXController.FlashScreen(Color3.fromRGB(239, 68, 68), 0.4, 0.25)

	local sparkPart = Instance.new("Part")
	sparkPart.Size = Vector3.new(1, 1, 1)
	sparkPart.Position = worldPos
	sparkPart.Anchored = true
	sparkPart.CanCollide = false
	sparkPart.Color = Color3.fromRGB(239, 68, 68)
	sparkPart.Material = Enum.Material.Neon
	sparkPart.Parent = Workspace

	local tween = TweenService:Create(sparkPart, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(3.5, 3.5, 3.5),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(sparkPart, 0.4)
end

-- ============================================================
-- SECURITY TACKLE EXPANDING SHOCKWAVE RING
-- ============================================================
function VFXController.PlayTackleImpact(worldPos: Vector3)
	VFXController.AddCameraTrauma(0.5)
	VFXController.FlashScreen(Color3.fromRGB(56, 189, 248), 0.5, 0.3)

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(worldPos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Color = Color3.fromRGB(56, 189, 248)
	ring.Material = Enum.Material.Neon
	ring.Parent = Workspace

	local tween = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, 18, 18),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(ring, 0.45)
end

-- ============================================================
-- RADIANT SYNTHESIS ASCENSION LIGHT PILLAR
-- ============================================================
function VFXController.PlayRadiantAscent(worldPos: Vector3, relicName: string)
	VFXController.AddCameraTrauma(0.65)
	VFXController.FlashScreen(Color3.fromRGB(250, 204, 21), 0.6, 0.5)

	local pillar = Instance.new("Part")
	pillar.Name = "RadiantPillar"
	pillar.Size = Vector3.new(3.5, 120, 3.5)
	pillar.Position = worldPos + Vector3.new(0, 60, 0)
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.Color = Color3.fromRGB(250, 204, 21)
	pillar.Material = Enum.Material.Neon
	pillar.Transparency = 0.2
	pillar.Parent = Workspace

	local tween = TweenService:Create(pillar, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.5, 120, 0.5),
	})
	tween:Play()
	Debris:AddItem(pillar, 2.0)
end

return VFXController
