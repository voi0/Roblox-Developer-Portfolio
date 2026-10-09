--!strict
--[[
	LaserService.luau — Server-Authoritative Laser Security Tripwires for VAULT WARS
	Generates glowing entry tripwires across base entrances that damage,
	knock back, and detect non-owner trespassers based on Laser Tiers.
	Located in: ServerScriptService.Server.Services.LaserService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local LaserService = {}
LaserService._lasers = {} :: { [number]: { Beam: Part, LeftPost: Part, RightPost: Part, Tier: number } }
LaserService._lastDamage = {} :: { [Player]: number }

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

local function getHeistService(): any?
	local svc = script.Parent:FindFirstChild("HeistService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

function LaserService.Init()
	print("  [LaserService] Initializing Laser Security Engine...")

	local plotSvc = getPlotService()
	if not plotSvc then return end

	for i = 1, Config.Arena.PlotCount do
		local plot = plotSvc.GetPlotByIndex(i)
		if plot and plot.LeftPost and plot.RightPost then
			LaserService.BuildLaserBeam(plot)
		end
	end

	-- Run continuous beam touch / collision validation
	RunService.Heartbeat:Connect(LaserService._onHeartbeat)

	print("  [LaserService] Laser Security Tripwires active ✓")
end

function LaserService.BuildLaserBeam(plot: any)
	local left = plot.LeftPost :: Part
	local right = plot.RightPost :: Part

	local dist = (left.Position - right.Position).Magnitude
	local center = (left.Position + right.Position) / 2

	local beam = Instance.new("Part")
	beam.Name = "LaserTripwire"
	beam.Size = Vector3.new(0.6, 0.6, dist)
	beam.CFrame = CFrame.lookAt(center, left.Position) * CFrame.Angles(0, math.rad(90), 0)
	beam.Anchored = true
	beam.CanCollide = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(239, 68, 68) -- Neon Crimson
	beam.Parent = plot.Folder

	LaserService._lasers[plot.Index] = {
		Beam = beam,
		LeftPost = left,
		RightPost = right,
		Tier = 1,
	}

	-- Touch trigger
	beam.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player then return end

		local plotOwner = plot.Owner
		if player ~= plotOwner then
			LaserService.HandleTrespasserHit(player, plot)
		end
	end)
end

function LaserService.HandleTrespasserHit(intruder: Player, plot: any)
	local now = os.clock()
	local lastHit = LaserService._lastDamage[intruder] or 0
	if now - lastHit < 0.65 then return end -- Damage cooldown
	LaserService._lastDamage[intruder] = now

	local char = intruder.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or hum.Health <= 0 then return end

	-- Get laser tier of the plot
	local dataSvc = getDataService()
	local ownerData = plot.Owner and dataSvc and dataSvc.GetData(plot.Owner)
	local tier = ownerData and ownerData.LaserTier or 1
	local isTitanium = ownerData and (ownerData.HasTitaniumLasers or ownerData.LaserTier >= 4)
	local dmg = isTitanium and 120 or (Config.Heist.LaserDamageByTier[tier] or 25)

	-- Apply damage
	hum:TakeDamage(dmg)

	-- Apply knockback away from plot
	local awayDir = (root.Position - plot.CF.Position).Unit
	root.AssemblyLinearVelocity = awayDir * Config.Heist.LaserKnockbackSpeed + Vector3.new(0, 14, 0)

	-- Trigger base breach alarm
	local heistSvc = getHeistService()
	if heistSvc then
		heistSvc.TriggerBreachAlarm(plot, intruder)
	end
end

function LaserService._onHeartbeat(dt: number)
	-- Animate laser color/pulsing for higher tiers
	local pulse = (math.sin(os.clock() * 6) + 1) / 2
	for _, lInfo in LaserService._lasers do
		if lInfo.Beam and lInfo.Beam.Parent then
			lInfo.Beam.Transparency = 0.15 + (pulse * 0.15)
		end
	end
end

function LaserService.UpdateTier(plotIndex: number, newTier: number)
	local lInfo = LaserService._lasers[plotIndex]
	if not lInfo then return end

	lInfo.Tier = newTier
	if newTier == 1 then
		lInfo.Beam.Color = Color3.fromRGB(239, 68, 68)
		lInfo.Beam.Size = Vector3.new(0.6, 0.6, lInfo.Beam.Size.Z)
	elseif newTier == 2 then
		lInfo.Beam.Color = Color3.fromRGB(249, 115, 22) -- Orange
		lInfo.Beam.Size = Vector3.new(0.9, 0.9, lInfo.Beam.Size.Z)
	elseif newTier == 3 then
		lInfo.Beam.Color = Color3.fromRGB(168, 85, 247) -- Purple shock
		lInfo.Beam.Size = Vector3.new(1.2, 1.2, lInfo.Beam.Size.Z)
	elseif newTier == 4 then
		lInfo.Beam.Color = Color3.fromRGB(56, 189, 248) -- Cyan Titanium Incinerator
		lInfo.Beam.Size = Vector3.new(1.6, 1.6, lInfo.Beam.Size.Z)
	end
end

return LaserService
