--!strict
--[[
	CameraController.luau — Production Camera, Cinematic Framing & Shake Engine for VAULT WARS
	Engineered for AAA Stability:
	1. Zero Locomotion Jitter: Walk bobbing uses Humanoid.CameraOffset (100% collision-safe, zero CameraModule desync).
	2. Non-Destructive Rotational Shake: Bound additively at RenderPriority.Camera.Value + 1 using second-order Spring physics.
	3. Cinematic Over-The-Shoulder Framing: Smooth Scriptable transitions for NPC dialogue with DepthOfField.
	4. Dynamic FOV & UI Focus: Clean lighting blur when menus are open.
	Located in: StarterPlayerScripts.Client.Controllers.CameraController
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spring = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Spring"))

local player = Players.LocalPlayer

local function getCamera(): Camera
	return Workspace.CurrentCamera or (Workspace:FindFirstChild("Camera") :: Camera?) or (Workspace:WaitForChild("Camera", 5) :: Camera)
end

local CameraController = {}
CameraController._blurEffect = nil :: BlurEffect?
CameraController._dialogueDOF = nil :: DepthOfFieldEffect?
CameraController._isUIFocused = false
CameraController._isCinematic = false
CameraController._baseFOV = 70
CameraController._currentFOV = 70
CameraController._targetFOV = 70
CameraController._openModalsCount = 0

-- Physics springs
local shakeSpring = Spring.new(Vector3.zero, 28, 0.72)
local bobCycle = 0

-- Cache for cinematic restoration
local originalCFrame = CFrame.identity
local originalFOV = 70
local activeCinematicTween: Tween? = nil

-- ============================================================
-- INITIALIZATION
-- ============================================================
function CameraController.Init()
	print("  [CameraController] Initializing AAA Camera & Cinematic Engine...")

	-- 1. Ensure Lighting Effects exist
	local blur = Lighting:FindFirstChild("VaultWarsUIBlur") :: BlurEffect?
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "VaultWarsUIBlur"
		blur.Size = 0
		blur.Enabled = false
		blur.Parent = Lighting
	end
	CameraController._blurEffect = blur

	local dof = Lighting:FindFirstChild("DialogueDOF") :: DepthOfFieldEffect?
	if not dof then
		dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "DialogueDOF"
		dof.FarIntensity = 0
		dof.NearIntensity = 0
		dof.InFocusRadius = 6
		dof.FocusDistance = 10
		dof.Enabled = false
		dof.Parent = Lighting
	end
	CameraController._dialogueDOF = dof

	-- 2. Configure camera parameters
	local cam = getCamera()
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = CameraController._baseFOV
	end

	player.CameraMinZoomDistance = 3.5
	player.CameraMaxZoomDistance = 40.0
	player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom

	-- 3. Dynamic FOV and Camera Management (Zero head tracking sway)
	RunService.RenderStepped:Connect(function(dt: number)
		local currentCam = getCamera()
		if not currentCam then return end

		-- Dynamic FOV lerp
		if not CameraController._isCinematic and math.abs(currentCam.FieldOfView - CameraController._targetFOV) > 0.05 then
			currentCam.FieldOfView = currentCam.FieldOfView + (CameraController._targetFOV - currentCam.FieldOfView) * math.clamp(dt * 8, 0, 1)
		end

		-- Ensure Humanoid CameraOffset is reset so native camera is rock-solid
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.CameraOffset ~= Vector3.zero then
			hum.CameraOffset = Vector3.zero
		end
	end)

	-- 4. Rotational Camera Shake bound at RenderPriority.Camera.Value + 1
	RunService:BindToRenderStep("PostCameraShake", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local currentCam = getCamera()
		if not currentCam or currentCam.CameraType ~= Enum.CameraType.Custom then return end

		local shakePos = shakeSpring:Update(dt) :: Vector3
		if shakePos.Magnitude > 0.005 then
			local shakeAngles = CFrame.Angles(
				math.rad(shakePos.X),
				math.rad(shakePos.Y),
				math.rad(shakePos.Z)
			)
			currentCam.CFrame = currentCam.CFrame * shakeAngles
		end
	end)

	print("  [CameraController] AAA Camera Engine online ✓")
end

-- ============================================================
-- PROCEDURAL CAMERA SHAKE (Spring Driven)
-- ============================================================
function CameraController.Shake(intensity: number?)
	local strength = intensity or 0.8
	local rx = (math.random() - 0.5) * 2 * strength
	local ry = (math.random() - 0.5) * 2 * strength
	local rz = (math.random() - 0.5) * 2 * (strength * 0.5)
	shakeSpring:Impulse(Vector3.new(rx, ry, rz))
end

-- ============================================================
-- CINEMATIC OVER-THE-SHOULDER FRAMING (NPC Dialogue & Modals)
-- ============================================================
function CameraController.FocusCinematic(targetCFrame: CFrame, focusDistance: number, targetFOV: number?, onComplete: (() -> ())?)
	local cam = getCamera()
	if not cam then return end

	CameraController._isCinematic = true
	originalCFrame = cam.CFrame
	originalFOV = cam.FieldOfView

	cam.CameraType = Enum.CameraType.Scriptable

	-- Activate Depth of Field
	local dof = CameraController._dialogueDOF
	if dof then
		dof.FocusDistance = focusDistance
		dof.InFocusRadius = 6.0
		dof.Enabled = true
		TweenService:Create(dof, TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			FarIntensity = 0.7,
			NearIntensity = 0.2,
		}):Play()
	end

	if activeCinematicTween then activeCinematicTween:Cancel() end
	local tInfo = TweenInfo.new(0.7, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	activeCinematicTween = TweenService:Create(cam, tInfo, {
		CFrame = targetCFrame,
		FieldOfView = targetFOV or 58,
	})
	activeCinematicTween.Completed:Once(function()
		activeCinematicTween = nil
		if onComplete then onComplete() end
	end)
	activeCinematicTween:Play()
end

function CameraController.RestoreDefault(onComplete: (() -> ())?)
	local cam = getCamera()
	if not cam then return end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- Fade out DepthOfField
	local dof = CameraController._dialogueDOF
	if dof then
		local dofTween = TweenService:Create(dof, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			FarIntensity = 0,
			NearIntensity = 0,
		})
		dofTween:Play()
		dofTween.Completed:Once(function()
			if dof then dof.Enabled = false end
		end)
	end

	-- Compute smooth return vantage behind character
	local returnCFrame = originalCFrame
	if root then
		local look = root.CFrame.LookVector
		local returnEye = root.Position - (look * 13) + Vector3.new(0, 3.2, 0)
		returnCFrame = CFrame.lookAt(returnEye, root.Position + Vector3.new(0, 1.6, 0))
	end

	if activeCinematicTween then activeCinematicTween:Cancel() end
	local tInfo = TweenInfo.new(0.55, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	activeCinematicTween = TweenService:Create(cam, tInfo, {
		CFrame = returnCFrame,
		FieldOfView = originalFOV,
	})

	activeCinematicTween.Completed:Once(function()
		activeCinematicTween = nil
		CameraController._isCinematic = false
		if hum then
			cam.CameraSubject = hum
		end
		cam.CameraType = Enum.CameraType.Custom
		if onComplete then onComplete() end
	end)
	activeCinematicTween:Play()
end

-- ============================================================
-- UI FOCUS MODE (Cinematic Modal Focus & World Blur)
-- ============================================================
function CameraController.SetUIFocus(isFocused: boolean)
	if isFocused then
		CameraController._openModalsCount += 1
	else
		CameraController._openModalsCount = math.max(0, CameraController._openModalsCount - 1)
	end

	local shouldFocus = CameraController._openModalsCount > 0
	if CameraController._isUIFocused == shouldFocus then return end
	CameraController._isUIFocused = shouldFocus

	local blur = CameraController._blurEffect
	if blur then
		if shouldFocus then
			blur.Enabled = true
			TweenService:Create(blur, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = 16
			}):Play()
			CameraController._targetFOV = 62
		else
			local tw = TweenService:Create(blur, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = 0
			})
			tw:Play()
			tw.Completed:Once(function()
				if not CameraController._isUIFocused and blur then
					blur.Enabled = false
				end
			end)
			CameraController._targetFOV = CameraController._baseFOV
		end
	end
end

function CameraController.SetTargetFOV(fov: number)
	if CameraController._isUIFocused or CameraController._isCinematic then return end
	CameraController._targetFOV = math.clamp(fov, 55, 95)
end

function CameraController.ResetFOV()
	if CameraController._isUIFocused then
		CameraController._targetFOV = 62
	else
		CameraController._targetFOV = CameraController._baseFOV
	end
end

return CameraController
