--!strict
--[[
	MovementController.luau — Ankle-Breaking Juke Physics Engine
	Momentum acceleration, lateral diagonal dashes, and instant Alt-braking.
	Located in: StarterPlayerScripts.Client.Controllers.MovementController
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local MovementController = {}
MovementController._currentSpeed = Config.Movement.BaseSpeed
MovementController._isMoving = false
MovementController._lastDashTime = 0
MovementController._lastSlideTime = 0
MovementController._isDashing = false

local function getRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getHumanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

function MovementController.Init()
	print("  [MovementController] Initializing Ankle-Breaking Physics Controller...")

	-- ── 1. RENDERSTEPPED ACCELERATION LOOP ──
	RunService.RenderStepped:Connect(function(dt: number)
		local hum = getHumanoid()
		local root = getRoot()
		if not hum or not root or hum.Health <= 0 then return end
		if hum.PlatformStand then return end -- Downed

		local moveDir = hum.MoveDirection
		if moveDir.Magnitude > 0.05 then
			-- Accelerate toward MaxSprintSpeed
			MovementController._currentSpeed = math.min(
				Config.Movement.MaxSprintSpeed,
				MovementController._currentSpeed + (Config.Movement.AccelerationRate * dt)
			)
			hum.WalkSpeed = MovementController._currentSpeed
			MovementController._isMoving = true
		else
			-- Decelerate smoothly
			MovementController._currentSpeed = Config.Movement.BaseSpeed
			hum.WalkSpeed = Config.Movement.BaseSpeed
			MovementController._isMoving = false
		end
	end)

	-- ── 2. INPUT BINDINGS: ALT-BRAKE & LATERAL DASH ──
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- 🛑 INSTANT STOP (ALT KEY: The Ankle Breaker)
		if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
			MovementController.TriggerInstantStop()

		-- ⚡ LATERAL DASH (SPACEBAR WHILE STRAFING)
		elseif input.KeyCode == Enum.KeyCode.Space then
			local hum = getHumanoid()
			if hum and hum.MoveDirection.Magnitude > 0.1 then
				-- Check if moving sideways (holding A or D)
				local isStrafeLeft = UserInputService:IsKeyDown(Enum.KeyCode.A)
				local isStrafeRight = UserInputService:IsKeyDown(Enum.KeyCode.D)
				if isStrafeLeft or isStrafeRight then
					MovementController.TriggerLateralDash(isStrafeLeft, isStrafeRight)
				end
			end

		-- 🛹 CROUCH SLIDE (C KEY)
		elseif input.KeyCode == Enum.KeyCode.C then
			MovementController.TriggerSlide()
		end
	end)

	print("  [MovementController] Juke physics ready (Dash: Space+A/D, Brake: Alt) ✓")
end

-- ============================================================
-- INSTANT STOP (The "Alt-Brake")
-- ============================================================
function MovementController.TriggerInstantStop()
	local root = getRoot()
	local hum = getHumanoid()
	if not root or not hum or hum.Health <= 0 or hum.PlatformStand then return end

	-- Cut linear horizontal velocity dead
	root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	MovementController._currentSpeed = Config.Movement.BaseSpeed
	hum.WalkSpeed = Config.Movement.BaseSpeed

	-- Screech Dust Particle Burst
	local screech = Instance.new("ParticleEmitter")
	screech.Name = "BrakeScreech"
	screech.Rate = 0
	screech.Lifetime = NumberRange.new(0.2, 0.4)
	screech.Speed = NumberRange.new(4, 8)
	screech.SpreadAngle = Vector2.new(45, 45)
	screech.Color = ColorSequence.new(Color3.fromRGB(244, 244, 245))
	screech.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	screech.Parent = root
	screech:Emit(15)
	task.delay(0.5, function() screech:Destroy() end)
end

-- ============================================================
-- LATERAL DASH (Diagonal Evasive Jump)
-- ============================================================
function MovementController.TriggerLateralDash(isLeft: boolean, isRight: boolean)
	local now = os.clock()
	if now - MovementController._lastDashTime < Config.Movement.DashCooldown then return end

	local root = getRoot()
	local hum = getHumanoid()
	if not root or not hum or hum.Health <= 0 or hum.PlatformStand then return end

	MovementController._lastDashTime = now
	MovementController._isDashing = true

	if MovementController.OnDash then
		MovementController.OnDash(Config.Movement.DashCooldown)
	end

	-- Calculate Dash Vector
	local forward = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	local dashDir = (forward * 0.4 + (isLeft and -right or right) * 0.9).Unit

	-- Apply Impulse
	root.AssemblyLinearVelocity = dashDir * Config.Movement.DashImpulseSpeed + Vector3.new(0, 8, 0)

	-- Trail Effect
	local trail = Instance.new("Trail")
	trail.Name = "DashTrail"
	trail.Color = ColorSequence.new(Color3.fromRGB(56, 189, 248), Color3.fromRGB(244, 114, 182))
	trail.Lifetime = 0.25
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })

	local a0 = Instance.new("Attachment", root)
	a0.Position = Vector3.new(0, 1, 0)
	local a1 = Instance.new("Attachment", root)
	a1.Position = Vector3.new(0, -1, 0)
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Parent = root

	task.delay(Config.Movement.DashDuration, function()
		MovementController._isDashing = false
		trail:Destroy()
		a0:Destroy()
		a1:Destroy()
	end)
end

-- ============================================================
-- CROUCH SLIDE
-- ============================================================
function MovementController.TriggerSlide()
	local now = os.clock()
	if now - MovementController._lastSlideTime < Config.Movement.SlideCooldown then return end

	local root = getRoot()
	local hum = getHumanoid()
	if not root or not hum or hum.Health <= 0 or hum.PlatformStand then return end
	if hum.MoveDirection.Magnitude < 0.1 then return end

	MovementController._lastSlideTime = now
	local forwardDir = root.CFrame.LookVector

	-- Boost speed and slide
	root.AssemblyLinearVelocity = forwardDir * 32 + Vector3.new(0, 0, 0)
end

return MovementController
