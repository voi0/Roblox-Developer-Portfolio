--!strict
--[[
	AbilityService.luau — Tactical Ability Execution Engine
	Handles Cloak, PocketDoor, RufusLeash, Decoy, and Adrenaline.
	Located in: ServerScriptService.Server.Services.AbilityService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local AbilityData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AbilityData"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AbilityService = {}
AbilityService._cooldowns = {} :: { [Player]: { [string]: number } }

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

function AbilityService.Init()
	print("  [AbilityService] Initializing Tactical Ability Engine...")

	local remotes = { "UseAbility", "AbilityActivated" }
	for _, name in remotes do
		if not ReplicatedStorage:FindFirstChild(name) then
			local inst = (name == "UseAbility") and Instance.new("RemoteFunction") or Instance.new("RemoteEvent")
			inst.Name = name
			inst.Parent = ReplicatedStorage
		end
	end

	local useAbilityRF = ReplicatedStorage:FindFirstChild("UseAbility") :: RemoteFunction?
	if useAbilityRF then
		useAbilityRF.OnServerInvoke = function(player: Player, abilityId: string)
			return AbilityService.ActivateAbility(player, abilityId)
		end
	end

	Players.PlayerRemoving:Connect(function(p: Player)
		AbilityService._cooldowns[p] = nil
	end)

	print("  [AbilityService] Tactical Ability Engine ready ✓")
end

function AbilityService.ActivateAbility(player: Player, abilityId: string): (boolean, string?)
	local roundSvc = getRoundService()
	if not roundSvc or not roundSvc.IsRoundActive() then
		return false, "No active round"
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return false, "Character unavailable"
	end

	local def = AbilityData[abilityId]
	if not def then
		return false, "Unknown ability"
	end

	-- Check cooldown
	local now = os.clock()
	if not AbilityService._cooldowns[player] then
		AbilityService._cooldowns[player] = {}
	end
	local lastUsed = AbilityService._cooldowns[player][abilityId] or 0
	if now - lastUsed < def.Cooldown then
		return false, `Cooldown remaining: {math.ceil(def.Cooldown - (now - lastUsed))}s`
	end

	-- Set Cooldown
	AbilityService._cooldowns[player][abilityId] = now

	-- ── EXECUTE SPECIFIC ABILITY ──
	if abilityId == "Cloak" then
		-- Invisibility for 3 seconds
		task.spawn(function()
			local parts = {}
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") then
					table.insert(parts, { Part = part, OrigTrans = part.Transparency })
					part.Transparency = 1
				end
			end
			task.wait(def.Duration)
			for _, item in parts do
				if item.Part and item.Part.Parent then
					item.Part.Transparency = item.OrigTrans
				end
			end
		end)

	elseif abilityId == "PocketDoor" then
		-- Slam down a temporary obstacle barricade door behind player
		local door = Instance.new("Part")
		door.Name = "PocketBarricade"
		door.Size = Vector3.new(12, 10, 1.5)
		door.CFrame = root.CFrame * CFrame.new(0, 4, 6) -- 6 studs behind player
		door.Anchored = true
		door.CanCollide = true
		door.Material = Enum.Material.WoodPlanks
		door.Color = Color3.fromRGB(120, 53, 15)
		door.Parent = Workspace

		local trim = Instance.new("Part")
		trim.Name = "DoorTrim"
		trim.Size = Vector3.new(12.2, 0.4, 1.7)
		trim.CFrame = door.CFrame * CFrame.new(0, 5, 0)
		trim.Anchored = true
		trim.CanCollide = false
		trim.Material = Enum.Material.Neon
		trim.Color = Color3.fromRGB(244, 63, 94)
		trim.Parent = door

		Debris:AddItem(door, def.Duration)

	elseif abilityId == "RufusLeash" then
		-- Chaser pulls nearest runner 8 studs closer
		local closestRunner: Player? = nil
		local closestDist = 25.0
		for _, p in Players:GetPlayers() do
			if p ~= player and roundSvc.GetPlayerRole(p) == "Runner" then
				local pChar = p.Character
				local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart") :: BasePart?
				if pRoot then
					local dist = (root.Position - pRoot.Position).Magnitude
					if dist <= closestDist then
						closestDist = dist
						closestRunner = p
					end
				end
			end
		end

		if closestRunner then
			local rChar = closestRunner.Character
			local rRoot = rChar and rChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rRoot then
				local pullDir = (root.Position - rRoot.Position).Unit
				rRoot.AssemblyLinearVelocity = pullDir * 60 + Vector3.new(0, 15, 0)
			end
		end

	elseif abilityId == "Adrenaline" then
		-- Speed surge
		task.spawn(function()
			local origSpeed = hum.WalkSpeed
			hum.WalkSpeed = origSpeed * 1.35
			task.wait(def.Duration)
			if hum and hum.Parent then
				hum.WalkSpeed = origSpeed
			end
		end)
	end

	-- Notify Clients for VFX
	local evt = ReplicatedStorage:FindFirstChild("AbilityActivated") :: RemoteEvent?
	if evt then
		evt:FireAllClients(player, abilityId)
	end

	return true, nil
end

return AbilityService
