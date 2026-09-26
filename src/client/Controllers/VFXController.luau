--!strict
--[[
	VFXController.luau — Visual Effects & Screen Dynamics for STARWEAVE
	Handles camera shake impulses, cosmic light pillars, radial harvest bursts,
	screen flashes for ultra-rare mutations, and particle ambiance.
	Located in: StarterPlayerScripts.Client.Controllers.VFXController
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local VFXController = {}
VFXController._shakeTrauma = 0
VFXController._screenGui = nil :: ScreenGui?
VFXController._flashFrame = nil :: Frame?

local TIER_VFX_CONFIG = {
	Sprout = {
		Color = Color3.fromRGB(74, 222, 128),
		ParticleCount = 12,
		Trauma = 0.05,
		HasBeam = false,
	},
	Bloom = {
		Color = Color3.fromRGB(56, 189, 248),
		ParticleCount = 20,
		Trauma = 0.1,
		HasBeam = false,
	},
	Radiant = {
		Color = Color3.fromRGB(250, 204, 21),
		ParticleCount = 35,
		Trauma = 0.25,
		HasBeam = true,
		BeamHeight = 40,
	},
	Astral = {
		Color = Color3.fromRGB(168, 85, 247),
		ParticleCount = 60,
		Trauma = 0.45,
		HasBeam = true,
		BeamHeight = 80,
	},
	Celestial = {
		Color = Color3.fromRGB(244, 114, 182),
		ParticleCount = 100,
		Trauma = 0.7,
		HasBeam = true,
		BeamHeight = 150,
	},
	Primordial = {
		Color = Color3.fromRGB(255, 255, 255),
		ParticleCount = 200,
		Trauma = 1.0,
		HasBeam = true,
		BeamHeight = 300,
	},
}

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

	-- Camera Shake Render Loop
	local random = Random.new()
	RunService.RenderStepped:Connect(function(dt)
		if VFXController._shakeTrauma > 0 then
			local trauma = VFXController._shakeTrauma
			local shakeAmount = trauma * trauma -- Quadratic falloff for smooth feeling
			local yaw = (random:NextNumber() - 0.5) * shakeAmount * 0.04
			local pitch = (random:NextNumber() - 0.5) * shakeAmount * 0.04
			local roll = (random:NextNumber() - 0.5) * shakeAmount * 0.03

			camera.CFrame = camera.CFrame * CFrame.Angles(pitch, yaw, roll)

			-- Decay trauma smoothly
			VFXController._shakeTrauma = math.max(0, VFXController._shakeTrauma - dt * 1.5)
		end
	end)
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

function VFXController.SpawnHarvestBurst(worldPos: Vector3, tier: string)
	local config = TIER_VFX_CONFIG[tier] or TIER_VFX_CONFIG.Sprout
	VFXController.AddCameraTrauma(config.Trauma)

	if tier == "Celestial" or tier == "Primordial" or tier == "Astral" then
		VFXController.FlashScreen(config.Color, tier == "Primordial" and 0.85 or 0.45, 0.6)
	end

	-- Create burst part
	local burstAnchor = Instance.new("Part")
	burstAnchor.Name = "HarvestBurst"
	burstAnchor.Size = Vector3.new(0.5, 0.5, 0.5)
	burstAnchor.Position = worldPos + Vector3.new(0, 1, 0)
	burstAnchor.Anchored = true
	burstAnchor.CanCollide = false
	burstAnchor.Transparency = 1
	burstAnchor.Parent = Workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = burstAnchor

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, config.Color),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.6, 1.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(10, 26)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = attachment

	-- Fire particle burst
	emitter:Emit(config.ParticleCount)

	-- Radial expanding shockwave ring
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(worldPos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = config.Color
	ring.Transparency = 0.2
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = Workspace

	local ringTween = TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 18, 18),
		Transparency = 1,
	})
	ringTween:Play()
	ringTween.Completed:Once(function()
		ring:Destroy()
	end)

	task.delay(1.5, function()
		burstAnchor:Destroy()
	end)
end

function VFXController.CreatePlantingAura(worldPos: Vector3)
	local aura = Instance.new("Part")
	aura.Shape = Enum.PartType.Cylinder
	aura.Size = Vector3.new(0.1, 2, 2)
	aura.CFrame = CFrame.new(worldPos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	aura.Material = Enum.Material.Neon
	aura.Color = Color3.fromRGB(168, 85, 247)
	aura.Transparency = 0.5
	aura.Anchored = true
	aura.CanCollide = false
	aura.Parent = Workspace

	local tween = TweenService:Create(aura, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 7, 7),
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Once(function()
		aura:Destroy()
	end)
end

return VFXController
