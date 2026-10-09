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

-- ============================================================
-- HYDRAULIC PNEUMATIC STEAM BURST
-- ============================================================
function VFXController.PlaySteamBurst(worldPos: Vector3)
	local emitterPart = Instance.new("Part")
	emitterPart.Size = Vector3.new(0.5, 0.5, 0.5)
	emitterPart.CFrame = CFrame.new(worldPos)
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.Transparency = 1
	emitterPart.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(241, 245, 249))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 2.8),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.Rate = 0
	emitter.Parent = emitterPart

	emitter:Emit(25)
	Debris:AddItem(emitterPart, 1.2)
end

-- ============================================================
-- HIGH-VOLTAGE TESLA ELECTRIC ARC
-- ============================================================
function VFXController.PlayElectricArc(fromPos: Vector3, toPos: Vector3)
	local dist = (toPos - fromPos).Magnitude
	local beamPart = Instance.new("Part")
	beamPart.Size = Vector3.new(0.2, 0.2, dist)
	beamPart.CFrame = CFrame.lookAt((fromPos + toPos) / 2, toPos)
	beamPart.Color = Color3.fromRGB(56, 189, 248)
	beamPart.Material = Enum.Material.Neon
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.Parent = Workspace

	local tween = TweenService:Create(beamPart, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.05, 0.05, dist),
	})
	tween:Play()
	Debris:AddItem(beamPart, 0.25)
end

-- ============================================================
-- FLOATING 3D XP INDICATOR
-- ============================================================
function VFXController.PlayFloatingXP(worldPos: Vector3, xpAmount: number, reason: string)
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.Position = worldPos + Vector3.new(0, 3.2, 0)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = Workspace

	local bGui = Instance.new("BillboardGui")
	bGui.Size = UDim2.new(0, 180, 0, 36)
	bGui.AlwaysOnTop = true
	bGui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = `+{xpAmount} XP [{string.upper(reason)}]`
	label.TextColor3 = Color3.fromRGB(250, 204, 21)
	label.TextSize = 15
	label.Font = Enum.Font.GothamBlack
	label.Parent = bGui

	local targetPos = anchor.Position + Vector3.new(0, 4.0, 0)
	local moveTween = TweenService:Create(anchor, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = targetPos,
	})
	local fadeTween = TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	})

	moveTween:Play()
	fadeTween:Play()
	Debris:AddItem(anchor, 1.2)
end

-- ============================================================
-- CELEBRATORY LEVEL-UP SEQUENCE
-- ============================================================
function VFXController.PlayLevelUpCelebration(worldPos: Vector3, level: number, rankTitle: string)
	VFXController.AddCameraTrauma(0.55)
	VFXController.FlashScreen(Color3.fromRGB(254, 240, 138), 0.35, 0.45)

	-- Golden Vertical Light Pillar
	local pillar = Instance.new("Part")
	pillar.Name = "LevelUpPillar"
	pillar.Size = Vector3.new(8, 140, 8)
	pillar.CFrame = CFrame.new(worldPos + Vector3.new(0, 70, 0))
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.Color = Color3.fromRGB(250, 204, 21)
	pillar.Material = Enum.Material.Neon
	pillar.Transparency = 0.25
	pillar.Parent = Workspace

	local mesh = Instance.new("CylinderMesh")
	mesh.Parent = pillar

	TweenService:Create(pillar, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(1, 140, 1),
	}):Play()
	Debris:AddItem(pillar, 1.8)

	-- Expanding Radial Ground Shockwave Ring
	local ring = Instance.new("Part")
	ring.Name = "LevelUpShockwave"
	ring.Size = Vector3.new(4, 0.4, 4)
	ring.CFrame = CFrame.new(worldPos)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Color = Color3.fromRGB(250, 204, 21)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.Parent = Workspace

	local ringMesh = Instance.new("SpecialMesh")
	ringMesh.MeshType = Enum.MeshType.Sphere
	ringMesh.Parent = ring

	TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(38, 0.4, 38),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1.0)
end

-- ============================================================
-- PHANTOM DASH VFX
-- ============================================================
function VFXController.PlayPhantomDash(worldPos: Vector3, lookDir: Vector3)
	VFXController.AddCameraTrauma(0.25)
	local trailPart = Instance.new("Part")
	trailPart.Size = Vector3.new(1.2, 3.5, 12)
	trailPart.CFrame = CFrame.lookAt(worldPos, worldPos + lookDir)
	trailPart.Color = Color3.fromRGB(56, 189, 248)
	trailPart.Material = Enum.Material.Neon
	trailPart.Anchored = true
	trailPart.CanCollide = false
	trailPart.Transparency = 0.3
	trailPart.Parent = Workspace

	TweenService:Create(trailPart, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.1, 1, 16),
	}):Play()
	Debris:AddItem(trailPart, 0.45)
end

-- ============================================================
-- SHOCKWAVE SLAM VFX
-- ============================================================
function VFXController.PlayShockwaveSlam(worldPos: Vector3, hitCount: number)
	VFXController.AddCameraTrauma(0.45)
	local ring = Instance.new("Part")
	ring.Name = "SlamShockwave"
	ring.Size = Vector3.new(2, 0.4, 2)
	ring.CFrame = CFrame.new(worldPos)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Color = Color3.fromRGB(239, 68, 68)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.Parent = Workspace

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = ring

	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(36, 0.4, 36),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.8)
end

-- ============================================================
-- BASE TURRET SUPPRESSION TRACER FIRE VFX
-- ============================================================
function VFXController.PlayTurretFire(origin: Vector3, targetPos: Vector3)
	-- Muzzle Flash
	local flash = Instance.new("Part")
	flash.Name = "TurretMuzzleFlash"
	flash.Size = Vector3.new(0.8, 0.8, 0.8)
	flash.CFrame = CFrame.new(origin)
	flash.Anchored = true
	flash.CanCollide = false
	flash.Color = Color3.fromRGB(250, 204, 21)
	flash.Material = Enum.Material.Neon
	flash.Parent = Workspace

	local fMesh = Instance.new("SpecialMesh")
	fMesh.MeshType = Enum.MeshType.Sphere
	fMesh.Parent = flash

	TweenService:Create(flash, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(1.8, 1.8, 1.8),
		Transparency = 1,
	}):Play()
	Debris:AddItem(flash, 0.1)

	-- High-Speed Tracer Beam Part
	local dist = (targetPos - origin).Magnitude
	local tracer = Instance.new("Part")
	tracer.Name = "TurretTracer"
	tracer.Size = Vector3.new(0.2, 0.2, dist)
	tracer.CFrame = CFrame.lookAt(origin, targetPos) * CFrame.new(0, 0, -dist / 2)
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.Color = Color3.fromRGB(239, 68, 68)
	tracer.Material = Enum.Material.Neon
	tracer.Transparency = 0.15
	tracer.Parent = Workspace

	TweenService:Create(tracer, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.05, 0.05, dist),
	}):Play()
	Debris:AddItem(tracer, 0.15)
end

function VFXController.PlayTurretDisabled(worldPos: Vector3)
	local spark = Instance.new("Part")
	spark.Name = "TurretEMPStun"
	spark.Size = Vector3.new(2, 2, 2)
	spark.CFrame = CFrame.new(worldPos)
	spark.Anchored = true
	spark.CanCollide = false
	spark.Color = Color3.fromRGB(56, 189, 248)
	spark.Material = Enum.Material.Neon
	spark.Parent = Workspace

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = spark

	TweenService:Create(spark, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(8, 8, 8),
		Transparency = 1,
	}):Play()
	Debris:AddItem(spark, 0.55)
end

return VFXController
