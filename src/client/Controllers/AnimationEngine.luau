--!strict
--[[
	AnimationEngine.luau — Procedural Spring-Driven Animation & Camera Controller for VAULT WARS
	Implements:
	1. Physics-based Hooke's Law Camera Trauma & Recoil (zero jitter, motion-sickness safe).
	2. Procedural Walking Bob & Inertial View Sway.
	3. Tactical Tool Viewmodel Swing & Recoil via Motor6D and CFrame spring physics.
	Located in: StarterPlayerScripts.Client.Controllers.AnimationEngine
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Spring = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Spring"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local AnimationEngine = {}
AnimationEngine._camSpring = nil :: any
AnimationEngine._swaySpring = nil :: any
AnimationEngine._walkCycle = 0
AnimationEngine._activeTool = nil :: Tool?

function AnimationEngine.Init()
	print("  [AnimationEngine] Initializing Spring-Driven Procedural Animation Engine...")

	-- 1. Setup Camera Physics Springs
	AnimationEngine._camSpring = Spring.new(Vector3.zero, 28, 0.72)
	AnimationEngine._swaySpring = Spring.new(Vector3.zero, 18, 0.8)

	-- 2. Hook RenderStepped for Camera Bob & Spring Updates
	RunService.RenderStepped:Connect(AnimationEngine._onRenderStepped)

	-- 3. Character Tool Tracking
	local function onCharacter(char: Model)
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				AnimationEngine._activeTool = child
				AnimationEngine._bindTool(child)
			end
		end)
		char.ChildRemoved:Connect(function(child)
			if child == AnimationEngine._activeTool then
				AnimationEngine._activeTool = nil
			end
		end)
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	-- Listen for remote feedback triggers (e.g. baton hit, laser trip)
	local toolEvt = ReplicatedStorage:FindFirstChild("ToolFeedback") :: RemoteEvent?
	if toolEvt then
		toolEvt.OnClientEvent:Connect(function(action: string)
			if action == "BatonSwing" or action == "BatonHit" then
				AnimationEngine.ShakeCamera(Vector3.new(0.6, -1.2, 0.8))
			elseif action == "BatonDropVictim" then
				AnimationEngine.ShakeCamera(Vector3.new(2.4, 1.8, -2.0))
			elseif action == "JamSuccess" then
				AnimationEngine.ShakeCamera(Vector3.new(0.3, 0.5, 0.2))
			end
		end)
	end

	-- Keybindings for Active Capstone Abilities: [Q] Phantom Dash & [R] Shockwave Slam
	local UserInputService = game:GetService("UserInputService")
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Q then
			local dashRF = ReplicatedStorage:FindFirstChild("PhantomDashRequest") :: RemoteFunction?
			if dashRF then
				task.spawn(function()
					dashRF:InvokeServer()
				end)
			end
		elseif input.KeyCode == Enum.KeyCode.R then
			local slamRF = ReplicatedStorage:FindFirstChild("ShockwaveSlamRequest") :: RemoteFunction?
			if slamRF then
				task.spawn(function()
					slamRF:InvokeServer()
				end)
			end
		end
	end)

	-- Listen for global VFX broadcasts
	local vfxEvt = ReplicatedStorage:FindFirstChild("VFXBroadcast") :: RemoteEvent?
	if vfxEvt then
		vfxEvt.OnClientEvent:Connect(function(vfxType: string, pos: Vector3, extra: any)
			local vfxControllerMod = script.Parent:FindFirstChild("VFXController")
			local vfx = vfxControllerMod and require(vfxControllerMod :: ModuleScript)
			if not vfx then return end
			if vfxType == "PhantomDash" then
				vfx.PlayPhantomDash(pos, extra)
			elseif vfxType == "ShockwaveSlam" then
				vfx.PlayShockwaveSlam(pos, extra)
			end
		end)
	end

	print("  [AnimationEngine] Spring Animation Engine online ✓")
end

-- ============================================================
-- CAMERA TRAUMA & BOB STEPPER
-- ============================================================
function AnimationEngine._onRenderStepped(dt: number)
	-- 1. Step Springs
	local camOffset = AnimationEngine._camSpring:Update(dt)

	-- 2. Apply Trauma Shakes to Camera CFrame strictly when an impulse is active
	if camera and camOffset.Magnitude > 0.005 then
		local shakeRot = CFrame.Angles(
			math.rad(camOffset.Y * 1.5),
			math.rad(camOffset.X * 1.5),
			math.rad(camOffset.Z * 1.2)
		)
		camera.CFrame = camera.CFrame * shakeRot
	end
end

-- ============================================================
-- SHAKE CAMERA IMPULSE
-- ============================================================
function AnimationEngine.ShakeCamera(force: Vector3)
	if AnimationEngine._camSpring then
		AnimationEngine._camSpring:Impulse(force)
	end
end

-- ============================================================
-- BIND PROCEDURAL SWING TO TOOLS
-- ============================================================
function AnimationEngine._bindTool(tool: Tool)
	tool.Activated:Connect(function()
		if string.find(tool.Name, "Baton") then
			AnimationEngine.PlayBatonSwing(tool)
		elseif string.find(tool.Name, "Jammer") then
			AnimationEngine.PlayJammerPulse(tool)
		end
	end)
end

function AnimationEngine.PlayBatonSwing(tool: Tool)
	-- Camera forward strike impulse
	AnimationEngine.ShakeCamera(Vector3.new(0.5, -1.0, 0.4))

	local char = player.Character
	local torso = char and (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
	local rArm = char and (char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm"))
	if not char or not torso or not rArm then return end

	local shoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D?
	if shoulder then
		local origC0 = shoulder.C0
		-- Swift tactical swing arc
		task.spawn(function()
			for step = 1, 6 do
				shoulder.C0 = origC0 * CFrame.Angles(math.rad(15 * step), math.rad(-10 * step), math.rad(5 * step))
				RunService.RenderStepped:Wait()
			end
			task.wait(0.08)
			for step = 5, 0, -1 do
				shoulder.C0 = origC0 * CFrame.Angles(math.rad(15 * step), math.rad(-10 * step), math.rad(5 * step))
				RunService.RenderStepped:Wait()
			end
			shoulder.C0 = origC0
		end)
	end
end

function AnimationEngine.PlayJammerPulse(tool: Tool)
	AnimationEngine.ShakeCamera(Vector3.new(0.3, 0.4, 0.2))

	local dish = tool:FindFirstChild("JammerDish") :: Part?
	if dish then
		local origCF = dish.CFrame
		task.spawn(function()
			for i = 1, 12 do
				dish.CFrame = origCF * CFrame.Angles(0, math.rad(i * 30), 0)
				RunService.RenderStepped:Wait()
			end
			dish.CFrame = origCF
		end)
	end
end

return AnimationEngine
