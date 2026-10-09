--!strict
--[[
	CameraController.luau — Dynamic Camera & UI Focus Engine for VAULT WARS
	Provides:
	- First-frame spawn alignment (frames character smoothly from behind)
	- UI Focus Mode: Smoothly activates Lighting.BlurEffect and shifts camera focus when modals open
	- Dynamic FOV engine (Base 70, Sprint 78, Modal focus 62)
	- Subtle head & walk sway on RenderStepped
	- Camera Shake: Procedural exponential decay shake for impacts & alarms
	- Tuned occlusion & zoom limits (no ceiling/wall popping)
	Located in: StarterPlayerScripts.Client.Controllers.CameraController
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local function getCamera(): Camera
	return Workspace.CurrentCamera or (Workspace:FindFirstChild("Camera") :: Camera?) or (Workspace:WaitForChild("Camera", 5) :: Camera)
end

local CameraController = {}
CameraController._blurEffect = nil :: BlurEffect?
CameraController._isUIFocused = false
CameraController._baseFOV = 70
CameraController._currentFOV = 70
CameraController._targetFOV = 70
CameraController._shakeIntensity = 0
CameraController._shakeDecay = 8
CameraController._openModalsCount = 0

-- ============================================================
-- INITIALIZATION
-- ============================================================
function CameraController.Init()
	print("  [CameraController] Initializing Dynamic Camera & UI Focus Engine...")

	-- 1. Ensure BlurEffect exists in Lighting for Cinematic UI Focus
	local blur = Lighting:FindFirstChild("VaultWarsUIBlur") :: BlurEffect?
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "VaultWarsUIBlur"
		blur.Size = 0
		blur.Enabled = false
		blur.Parent = Lighting
	end
	CameraController._blurEffect = blur

	-- 2. Configure camera parameters
	local cam = getCamera()
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = CameraController._baseFOV
	end

	player.CameraMinZoomDistance = 3.0
	player.CameraMaxZoomDistance = 45.0
	player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom

	-- 3. Character framing on spawn / respawn
	if player.Character then
		task.spawn(CameraController._alignCameraOnCharacter, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		task.spawn(CameraController._alignCameraOnCharacter, char)
	end)

	-- 4. RenderStepped Camera Loop (Dynamic FOV, subtle sway, shake)
	local swayTime = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local currentCam = getCamera()
		if not currentCam then return end

		-- Smooth FOV lerp
		if math.abs(currentCam.FieldOfView - CameraController._targetFOV) > 0.05 then
			currentCam.FieldOfView = currentCam.FieldOfView + (CameraController._targetFOV - currentCam.FieldOfView) * math.clamp(dt * 8, 0, 1)
		end

		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?

		-- Subtle walk sway when moving and not focused in UI
		if hum and root and not CameraController._isUIFocused then
			local speed = root.AssemblyLinearVelocity.Magnitude
			if speed > 2 and hum.FloorMaterial ~= Enum.Material.Air then
				swayTime = swayTime + dt * 10
				local swayOffset = Vector3.new(
					math.sin(swayTime * 0.5) * 0.02,
					math.abs(math.sin(swayTime)) * 0.035,
					0
				)
				currentCam.CFrame = currentCam.CFrame * CFrame.new(swayOffset)
			end
		end

		-- Procedural Camera Shake
		if CameraController._shakeIntensity > 0.001 then
			local sX = (math.random() - 0.5) * 2 * CameraController._shakeIntensity
			local sY = (math.random() - 0.5) * 2 * CameraController._shakeIntensity
			local sZ = (math.random() - 0.5) * 0.5 * CameraController._shakeIntensity
			currentCam.CFrame = currentCam.CFrame * CFrame.Angles(math.rad(sX * 1.5), math.rad(sY * 1.5), math.rad(sZ))
			CameraController._shakeIntensity = math.max(0, CameraController._shakeIntensity - (CameraController._shakeIntensity * CameraController._shakeDecay * dt))
		else
			CameraController._shakeIntensity = 0
		end
	end)

	print("  [CameraController] Dynamic Camera Engine online ✓")
end

-- ============================================================
-- ALIGN CAMERA BEHIND CHARACTER ON SPAWN
-- ============================================================
function CameraController._alignCameraOnCharacter(char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not root or not hum then return end

	local cam = getCamera()
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = hum

		task.wait(0.08)
		if root and root.Parent then
			local look = root.CFrame.LookVector
			local targetPos = root.Position + Vector3.new(0, 2.0, 0)
			local eyePos = targetPos - (look * 14) + Vector3.new(0, 3.8, 0)
			cam.CFrame = CFrame.lookAt(eyePos, targetPos)
		end
	end
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
	if not blur or not blur.Parent then
		blur = Lighting:FindFirstChild("VaultWarsUIBlur") :: BlurEffect?
		if not blur then
			blur = Instance.new("BlurEffect")
			blur.Name = "VaultWarsUIBlur"
			blur.Size = 0
			blur.Enabled = false
			blur.Parent = Lighting
		end
		CameraController._blurEffect = blur
	end

	if shouldFocus then
		-- Entering UI: Smoothly fade in background blur and focus FOV
		if blur then
			blur.Enabled = true
			TweenService:Create(blur, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = 18
			}):Play()
		end
		CameraController._targetFOV = 63
	else
		-- Exiting UI: Smoothly restore crisp world view
		if blur then
			local tw = TweenService:Create(blur, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = 0
			})
			tw:Play()
			tw.Completed:Once(function()
				if not CameraController._isUIFocused and blur then
					blur.Enabled = false
				end
			end)
		end
		CameraController._targetFOV = CameraController._baseFOV
	end
end

-- ============================================================
-- DYNAMIC FOV ZOOM (Sprint / Heist Alarm / Adrenaline)
-- ============================================================
function CameraController.SetTargetFOV(fov: number)
	if CameraController._isUIFocused then return end
	CameraController._targetFOV = math.clamp(fov, 55, 95)
end

function CameraController.ResetFOV()
	if CameraController._isUIFocused then
		CameraController._targetFOV = 63
	else
		CameraController._targetFOV = CameraController._baseFOV
	end
end

-- ============================================================
-- PROCEDURAL CAMERA SHAKE
-- ============================================================
function CameraController.Shake(intensity: number?, duration: number?)
	local strength = intensity or 0.6
	CameraController._shakeIntensity = math.clamp(CameraController._shakeIntensity + strength, 0, 3.5)
	if duration and duration > 0 then
		CameraController._shakeDecay = math.max(1, 1 / duration)
	else
		CameraController._shakeDecay = 7
	end
end

return CameraController
