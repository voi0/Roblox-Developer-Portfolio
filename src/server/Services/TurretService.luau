--!strict
--[[
	TurretService.luau — Server-Authoritative Base Defense AI for VAULT WARS
	Controls Automated Security Turrets with Raycast Line-of-Sight targeting,
	smooth CFrame gimbal rotation, red laser tracking, and suppression tracer fire.
	Counters intruders unless disabled by EMP Jammers.
	Located in: ServerScriptService.Server.Services.TurretService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local TurretService = {}
TurretService._turrets = {} :: { [number]: any }

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

local function getPlotService(): any?
	local svc = script.Parent:FindFirstChild("PlotService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

-- ============================================================
-- INITIALIZE TURRETS & TARGETING LOOP
-- ============================================================
function TurretService.Init()
	print("  [TurretService] Initializing Base Defense AI & Targeting Loops...")

	-- Setup Network Remotes
	local fireEvt = ReplicatedStorage:FindFirstChild("TurretFire") :: RemoteEvent?
	if not fireEvt then
		fireEvt = Instance.new("RemoteEvent")
		fireEvt.Name = "TurretFire"
		fireEvt.Parent = ReplicatedStorage
	end

	local stunEvt = ReplicatedStorage:FindFirstChild("TurretDisabled") :: RemoteEvent?
	if not stunEvt then
		stunEvt = Instance.new("RemoteEvent")
		stunEvt.Name = "TurretDisabled"
		stunEvt.Parent = ReplicatedStorage
	end

	-- Wait briefly for arena geometry
	task.spawn(function()
		local arena = Workspace:WaitForChild("VaultWarsArena", 10)
		if not arena then return end
		local plotsFolder = arena:WaitForChild("Plots", 10)
		if not plotsFolder then return end

		for i = 1, Config.Arena.PlotCount do
			local pFolder = plotsFolder:WaitForChild("Plot_" .. i, 5)
			if pFolder then
				local turretModel = pFolder:FindFirstChild("AutomatedSecurityTurret") :: Model?
				if turretModel then
					local head = turretModel:FindFirstChild("TurretHead") :: Model?
					local pod = head and (head:FindFirstChild("WeaponPod") :: Part?)
					if pod then
						local restCF = head:GetAttribute("RestCF") :: CFrame? or pod.CFrame
						TurretService._turrets[i] = {
							PlotIndex = i,
							Model = turretModel,
							Head = head,
							Pod = pod,
							RestCF = restCF,
							CurrentTarget = nil :: Player?,
							LockOnStartTime = 0,
							LastFireTime = 0,
							DisabledUntil = 0,
						}
					end
				end
			end
		end

		print(`  [TurretService] Initialized automated defense turrets scanner ✓`)
	end)

function TurretService.RegisterTurret(plotIndex: number, turretModel: Model)
	local head = turretModel:FindFirstChild("TurretHead") :: Model?
	local pod = head and (head:FindFirstChild("WeaponPod") :: Part?)
	if pod then
		local restCF = head:GetAttribute("RestCF") :: CFrame? or pod.CFrame
		TurretService._turrets[plotIndex] = {
			PlotIndex = plotIndex,
			Model = turretModel,
			Head = head,
			Pod = pod,
			RestCF = restCF,
			CurrentTarget = nil :: Player?,
			LockOnStartTime = 0,
			LastFireTime = 0,
			DisabledUntil = 0,
		}
		print(`  [TurretService] Registered dynamic turret for Plot #{plotIndex} ✓`)
	end
end

function TurretService.UnregisterTurret(plotIndex: number)
	TurretService._turrets[plotIndex] = nil
end

	-- Heartbeat Target Acquisition & Suppression Fire Loop
	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		local plotSvc = getPlotService()
		local dataSvc = getDataService()

		for plotIndex, turret in TurretService._turrets do
			local pod = turret.Pod :: Part?
			if not pod or not pod.Parent then continue end

			-- Check EMP Jammer Disable Status
			if now < turret.DisabledUntil then
				turret.CurrentTarget = nil
				turret.LockOnStartTime = 0
				continue
			end

			local plot = plotSvc and plotSvc.GetPlotByIndex(plotIndex)
			local owner = plot and plot.Owner :: Player?

			-- Determine Turret Tier Specs
			local turretTier = 1
			if owner and dataSvc then
				local pData = dataSvc.GetData(owner)
				turretTier = pData and (pData.TurretTier or 1) or 1
			end
			local spec = Config.Turret.TierSpecs[turretTier] or Config.Turret.TierSpecs[1]
			local scanRadius = spec.Range or Config.Turret.ScanRadius

			-- ── 1. SCAN FOR CANDIDATE INTRUDER TARGET ──
			local bestTarget: Player? = nil
			local bestDist = scanRadius
			local podPos = pod.Position

			for _, player in Players:GetPlayers() do
				if player == owner then continue end
				local char = player.Character
				if not char then continue end

				local hum = char:FindFirstChildOfClass("Humanoid")
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not hum or hum.Health <= 0 or not root then continue end

				local dist = (root.Position - podPos).Magnitude
				if dist <= scanRadius and dist < bestDist then
					-- Check Line of Sight via Raycast
					local rayParams = RaycastParams.new()
					rayParams.FilterType = Enum.RaycastFilterType.Exclude
					rayParams.FilterDescendantsInstances = { turret.Model, char }

					local rayResult = Workspace:Raycast(podPos, (root.Position - podPos), rayParams)
					if not rayResult then
						bestTarget = player
						bestDist = dist
					end
				end
			end

			-- ── 2. TRACK TARGET & ROTATE GIMBAL ──
			if bestTarget and bestTarget.Character then
				local root = bestTarget.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local targetPos = root.Position
					local targetCF = CFrame.lookAt(podPos, targetPos)
					pod.CFrame = pod.CFrame:Lerp(targetCF, math.clamp(dt * 12, 0.05, 0.35))

					if turret.CurrentTarget == bestTarget then
						-- Target has been tracked
						local lockDuration = now - turret.LockOnStartTime
						if lockDuration >= Config.Turret.LockOnDuration then
							-- ── 3. ENGAGE WITH SUPPRESSION FIRE ──
							if now - turret.LastFireTime >= spec.FireInterval then
								turret.LastFireTime = now

								local hum = bestTarget.Character:FindFirstChildOfClass("Humanoid")
								if hum and hum.Health > 0 then
									hum:TakeDamage(spec.Damage)

									-- Apply gentle deterrence knockback
									local pushDir = (root.Position - podPos).Unit
									root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + pushDir * 8

									-- Broadcast Fire Remote for client VFX & audio
									if fireEvt then
										fireEvt:FireAllClients(podPos, targetPos, plotIndex)
									end
								end
							end
						end
					else
						-- New target acquired: start lock-on clock
						turret.CurrentTarget = bestTarget
						turret.LockOnStartTime = now
					end
				end
			else
				-- No intruder: smoothly return to rest orientation
				turret.CurrentTarget = nil
				turret.LockOnStartTime = 0
				if turret.RestCF then
					pod.CFrame = pod.CFrame:Lerp(turret.RestCF, math.clamp(dt * 4, 0.02, 0.15))
				end
			end
		end
	end)
end

-- ============================================================
-- EMP JAMMER COUNTERMEASURE
-- ============================================================
function TurretService.DisableTurret(plotIndex: number, duration: number)
	local turret = TurretService._turrets[plotIndex]
	if not turret then return end

	turret.DisabledUntil = os.clock() + duration
	turret.CurrentTarget = nil
	turret.LockOnStartTime = 0

	local stunEvt = ReplicatedStorage:FindFirstChild("TurretDisabled") :: RemoteEvent?
	if stunEvt then
		stunEvt:FireAllClients(plotIndex, duration)
	end

	print(`  [TurretService] Base Turret #{plotIndex} EMP-disabled for {duration}s!`)
end

return TurretService
