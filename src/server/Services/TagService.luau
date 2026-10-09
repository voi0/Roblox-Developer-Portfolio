--!strict
--[[
	TagService.luau — Server-Authoritative Tag & Revive Engine
	Validates knife swings, downs runners, and manages teammate revives.
	Located in: ServerScriptService.Server.Services.TagService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local TagService = {}
TagService._downedPlayers = {} :: { [Player]: boolean }

local function getArenaService(): any?
	local svc = script.Parent:FindFirstChild("ArenaService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

local function getRoundService(): any?
	local svc = script.Parent:FindFirstChild("RoundService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

function TagService.Init()
	print("  [TagService] Initializing Server-Authoritative Tag & Revive Engine...")

	local remotes = { "TagHit", "PlayerDowned", "PlayerRevived", "KnifeSwing" }
	for _, name in remotes do
		if not ReplicatedStorage:FindFirstChild(name) then
			local evt = Instance.new("RemoteEvent")
			evt.Name = name
			evt.Parent = ReplicatedStorage
		end
	end

	-- Knife Swing from Chaser
	local knifeSwingEvt = ReplicatedStorage:FindFirstChild("KnifeSwing") :: RemoteEvent?
	if knifeSwingEvt then
		knifeSwingEvt.OnServerEvent:Connect(function(attacker: Player, targetUserId: number?)
			TagService.AttemptTag(attacker, targetUserId)
		end)
	end

	print("  [TagService] Tag & Revive engine ready ✓")
end

function TagService.AttemptTag(chaser: Player, targetUserId: number?)
	local roundSvc = getRoundService()
	if not roundSvc or not roundSvc.IsRoundActive() then return end
	if roundSvc.GetPlayerRole(chaser) ~= "Chaser" then return end

	local chaserChar = chaser.Character
	if not chaserChar then return end
	local chaserRoot = chaserChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not chaserRoot then return end

	-- Find candidate target
	local targetPlayer: Player? = nil
	if targetUserId then
		targetPlayer = Players:GetPlayerByUserId(targetUserId)
	else
		-- Find nearest runner
		local closestDist = Config.Round.TagDistance
		for _, p in Players:GetPlayers() do
			if p ~= chaser and roundSvc.GetPlayerRole(p) == "Runner" and not TagService.IsDowned(p) then
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local dist = (chaserRoot.Position - root.Position).Magnitude
					if dist <= closestDist then
						closestDist = dist
						targetPlayer = p
					end
				end
			end
		end
	end

	if not targetPlayer then return end
	if roundSvc.GetPlayerRole(targetPlayer) ~= "Runner" then return end
	if TagService.IsDowned(targetPlayer) then return end

	local targetChar = targetPlayer.Character
	local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then return end

	-- Check distance
	local dist = (chaserRoot.Position - targetRoot.Position).Magnitude
	if dist > Config.Round.TagDistance then return end

	-- Check safe zone
	local arenaSvc = getArenaService()
	if arenaSvc and arenaSvc.IsInSafeZone(targetRoot.Position) then
		return -- Target is inside safe zone!
	end

	-- Tag successful!
	TagService.DownPlayer(targetPlayer, chaser)
end

function TagService.DownPlayer(runner: Player, chaser: Player?)
	TagService._downedPlayers[runner] = true

	local char = runner.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.PlatformStand = true
	end

	-- Record kill for chaser
	if chaser then
		local dataSvc = getDataService()
		if dataSvc then dataSvc.RecordTag(chaser) end
	end

	-- Create Revive ProximityPrompt on downed player
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ActionText = "Revive"
		prompt.ObjectText = runner.DisplayName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = Config.Round.ReviveHoldTime
		prompt.MaxActivationDistance = Config.Round.ReviveDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = root

		prompt.Triggered:Connect(function(reviver: Player)
			if reviver ~= runner then
				local roundSvc = getRoundService()
				if roundSvc and roundSvc.GetPlayerRole(reviver) == "Runner" and not TagService.IsDowned(reviver) then
					prompt:Destroy()
					TagService.RevivePlayer(runner, reviver)
				end
			end
		end)
	end

	local playerDownedEvt = ReplicatedStorage:FindFirstChild("PlayerDowned") :: RemoteEvent?
	if playerDownedEvt then
		playerDownedEvt:FireAllClients(runner, chaser)
	end
end

function TagService.RevivePlayer(runner: Player, reviver: Player)
	TagService._downedPlayers[runner] = nil

	local char = runner.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
		hum.WalkSpeed = Config.Movement.BaseSpeed
		hum.JumpPower = 50
	end

	local dataSvc = getDataService()
	if dataSvc then
		dataSvc.RecordRevive(reviver)
	end

	local playerRevivedEvt = ReplicatedStorage:FindFirstChild("PlayerRevived") :: RemoteEvent?
	if playerRevivedEvt then
		playerRevivedEvt:FireAllClients(runner, reviver)
	end
end

function TagService.IsDowned(player: Player): boolean
	return TagService._downedPlayers[player] == true
end

function TagService.ClearDowned(player: Player)
	TagService._downedPlayers[player] = nil
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local prompt = root:FindFirstChild("RevivePrompt")
		if prompt then prompt:Destroy() end
	end
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
		hum.WalkSpeed = Config.Movement.BaseSpeed
		hum.JumpPower = 50
	end
end

function TagService.ResetAll()
	for p, _ in TagService._downedPlayers do
		TagService.ClearDowned(p)
	end
	TagService._downedPlayers = {}
end

return TagService
