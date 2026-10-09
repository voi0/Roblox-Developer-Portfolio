--!strict
--[[
	ToolService.luau — Tactical Physical Arsenal for VAULT WARS: STEAL & DEFEND TYCOON
	Provides players with:
	1. ⚡ Security Stun Baton: Close-quarters defense, 20 dmg, 38 knocback, forces thief to drop stolen loot.
	2. 📡 EMP Laser Jammer: Breaches enemy base security, disables laser grid for 6.0s.
	Located in: ServerScriptService.Server.Services.ToolService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local ToolService = {}
ToolService._batonCooldowns = {} :: { [Player]: number }
ToolService._jammerCooldowns = {} :: { [Player]: number }

local function getLaserService(): any?
	local svc = script.Parent:FindFirstChild("LaserService")
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

local function createWeld(p0: BasePart, p1: BasePart, c0: CFrame): Weld
	local weld = Instance.new("Weld")
	weld.Part0 = p0
	weld.Part1 = p1
	weld.C0 = c0
	weld.Parent = p0
	return weld
end

-- ============================================================
-- TOOL PROCEDURAL BUILDERS
-- ============================================================
function ToolService.CreateStunBatonTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "⚡ Stun Baton"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Defend your vault! Slaps thieves and forces them to drop loot."

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 3.2, 0.5)
	handle.Color = Color3.fromRGB(30, 41, 59)
	handle.Material = Enum.Material.Metal
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.Parent = tool

	local tip = Instance.new("Part")
	tip.Name = "BatonTip"
	tip.Size = Vector3.new(0.65, 0.9, 0.65)
	tip.Color = Color3.fromRGB(56, 189, 248) -- Electric Cyan
	tip.Material = Enum.Material.Neon
	tip.CanCollide = false
	tip.Parent = tool
	createWeld(handle, tip, CFrame.new(0, 1.4, 0))

	return tool
end

function ToolService.CreateEMPJammerTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "📡 EMP Jammer"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Infiltrate enemy vaults! Jams target laser grid for 6s."

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 1.8, 0.6)
	handle.Color = Color3.fromRGB(24, 24, 27)
	handle.Material = Enum.Material.Metal
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.Parent = tool

	local antenna = Instance.new("Part")
	antenna.Name = "ScannerHead"
	antenna.Size = Vector3.new(1.4, 0.4, 1.4)
	antenna.Color = Color3.fromRGB(245, 158, 11) -- Warning Amber
	antenna.Material = Enum.Material.Neon
	antenna.CanCollide = false
	antenna.Parent = tool
	createWeld(handle, antenna, CFrame.new(0, 1.1, 0))

	return tool
end

-- ============================================================
-- INITIALIZE & NETWORK REMOTES
-- ============================================================
function ToolService.Init()
	print("  [ToolService] Initializing Tactical Arsenal Engine...")

	local toolEvt = ReplicatedStorage:FindFirstChild("ToolFeedback") :: RemoteEvent?
	if not toolEvt then
		toolEvt = Instance.new("RemoteEvent")
		toolEvt.Name = "ToolFeedback"
		toolEvt.Parent = ReplicatedStorage
	end

	-- Connect Player Spawns
	for _, player in Players:GetPlayers() do
		ToolService.SetupPlayer(player)
	end
	Players.PlayerAdded:Connect(ToolService.SetupPlayer)

	print("  [ToolService] Arsenal online (Stun Baton + EMP Jammer) ✓")
end

function ToolService.SetupPlayer(player: Player)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		ToolService.GiveLoadout(player)
	end)
	if player.Character then
		ToolService.GiveLoadout(player)
	end
end

function ToolService.GiveLoadout(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	-- Check if tools already exist
	if not backpack:FindFirstChild("⚡ Stun Baton") and not (player.Character and player.Character:FindFirstChild("⚡ Stun Baton")) then
		local baton = ToolService.CreateStunBatonTool()
		baton.Activated:Connect(function()
			ToolService.UseStunBaton(player)
		end)
		baton.Parent = backpack
	end

	if not backpack:FindFirstChild("📡 EMP Jammer") and not (player.Character and player.Character:FindFirstChild("📡 EMP Jammer")) then
		local jammer = ToolService.CreateEMPJammerTool()
		jammer.Activated:Connect(function()
			ToolService.UseEMPJammer(player)
		end)
		jammer.Parent = backpack
	end
end

-- ============================================================
-- 1. USE STUN BATON (SERVER-AUTHORITATIVE)
-- ============================================================
function ToolService.UseStunBaton(defender: Player)
	local now = os.clock()
	local lastUse = ToolService._batonCooldowns[defender] or 0
	if now - lastUse < Config.Tools.StunBaton.CooldownSeconds then
		return
	end
	ToolService._batonCooldowns[defender] = now

	local char = defender.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then return end

	local toolEvt = ReplicatedStorage:FindFirstChild("ToolFeedback") :: RemoteEvent?
	local heistSvc = getHeistService()

	-- Find closest target within Range (9 studs)
	local bestTarget: Player? = nil
	local bestDist = Config.Tools.StunBaton.Range

	for _, other in Players:GetPlayers() do
		if other ~= defender and other.Character then
			local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local oHum = other.Character:FindFirstChildOfClass("Humanoid")
			if oRoot and oHum and oHum.Health > 0 then
				local dist = (oRoot.Position - root.Position).Magnitude
				if dist <= bestDist then
					bestDist = dist
					bestTarget = other
				end
			end
		end
	end

	if bestTarget and bestTarget.Character then
		local vChar = bestTarget.Character
		local vHum = vChar:FindFirstChildOfClass("Humanoid")
		local vRoot = vChar:FindFirstChild("HumanoidRootPart") :: BasePart?

		if vHum and vRoot then
			vHum:TakeDamage(Config.Tools.StunBaton.Damage)
			local knockDir = (vRoot.Position - root.Position).Unit
			vRoot.AssemblyLinearVelocity = knockDir * Config.Tools.StunBaton.KnockbackSpeed + Vector3.new(0, 16, 0)

			-- Force dropped loot if carrying
			if heistSvc and heistSvc.IsCarryingLoot(bestTarget) then
				heistSvc.DropLoot(bestTarget)
				if toolEvt then
					toolEvt:FireClient(defender, "BatonHitLoot", bestTarget.DisplayName)
					toolEvt:FireClient(bestTarget, "BatonDropVictim", defender.DisplayName)
				end
			else
				if toolEvt then
					toolEvt:FireClient(defender, "BatonHit", bestTarget.DisplayName)
				end
			end
		end
	else
		-- Swing whiff feedback
		if toolEvt then
			toolEvt:FireClient(defender, "BatonSwing")
		end
	end
end

-- ============================================================
-- 2. USE EMP JAMMER (SERVER-AUTHORITATIVE)
-- ============================================================
function ToolService.UseEMPJammer(infiltrator: Player)
	local now = os.clock()
	local lastUse = ToolService._jammerCooldowns[infiltrator] or 0
	if now - lastUse < Config.Tools.EMPJammer.CooldownSeconds then
		local rem = math.ceil(Config.Tools.EMPJammer.CooldownSeconds - (now - lastUse))
		local toolEvt = ReplicatedStorage:FindFirstChild("ToolFeedback") :: RemoteEvent?
		if toolEvt then
			toolEvt:FireClient(infiltrator, "Cooldown", rem)
		end
		return
	end

	local char = infiltrator.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then return end

	local plotSvc = getPlotService()
	local laserSvc = getLaserService()
	if not plotSvc or not laserSvc then return end

	-- Find closest enemy base laser entrance within Range (22 studs)
	local targetPlotIndex: number? = nil
	local closestDist = Config.Tools.EMPJammer.Range

	for i = 1, Config.Arena.PlotCount do
		local plot = plotSvc.GetPlotByIndex(i)
		if plot and plot.Owner ~= infiltrator and plot.LeftPost and plot.RightPost then
			local midLaser = (plot.LeftPost.Position + plot.RightPost.Position) / 2
			local dist = (midLaser - root.Position).Magnitude
			if dist <= closestDist then
				closestDist = dist
				targetPlotIndex = i
			end
		end
	end

	local toolEvt = ReplicatedStorage:FindFirstChild("ToolFeedback") :: RemoteEvent?

	if targetPlotIndex then
		ToolService._jammerCooldowns[infiltrator] = now
		local dur = Config.Tools.EMPJammer.DisableDurationSeconds
		laserSvc.DisableLasers(targetPlotIndex, dur)

		local targetPlot = plotSvc.GetPlotByIndex(targetPlotIndex)
		if toolEvt then
			toolEvt:FireClient(infiltrator, "JamSuccess", dur)
			if targetPlot and targetPlot.Owner then
				toolEvt:FireClient(targetPlot.Owner, "JamAlert", infiltrator.DisplayName)
			end
		end
		print(`  [ToolService] {infiltrator.Name} EMP-jammed Vault #{targetPlotIndex} for {dur}s!`)
	else
		if toolEvt then
			toolEvt:FireClient(infiltrator, "JamNoTarget")
		end
	end
end

return ToolService
