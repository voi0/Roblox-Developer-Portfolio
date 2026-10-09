--!strict
--[[
	ProgressionService.luau — Server-Authoritative Progression & Mastery Engine
	VAULT WARS: STEAL & DEFEND TYCOON
	Orchestrates XP distribution, Level Up calculations, Heist Rank promotions,
	and Perk tree querying for all server services.
	Located in: ServerScriptService.Server.Services.ProgressionService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local ProgressionService = {}

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

function ProgressionService.Init()
	print("  [ProgressionService] Initializing Mastery Engine & Skill Tree...")

	-- Ensure remotes exist
	local dashRF = ReplicatedStorage:FindFirstChild("PhantomDashRequest") :: RemoteFunction?
	if not dashRF then
		dashRF = Instance.new("RemoteFunction")
		dashRF.Name = "PhantomDashRequest"
		dashRF.Parent = ReplicatedStorage
	end
	dashRF.OnServerInvoke = function(player: Player)
		return ProgressionService.ExecutePhantomDash(player)
	end

	local slamRF = ReplicatedStorage:FindFirstChild("ShockwaveSlamRequest") :: RemoteFunction?
	if not slamRF then
		slamRF = Instance.new("RemoteFunction")
		slamRF.Name = "ShockwaveSlamRequest"
		slamRF.Parent = ReplicatedStorage
	end
	slamRF.OnServerInvoke = function(player: Player)
		return ProgressionService.ExecuteShockwaveSlam(player)
	end

	print("  [ProgressionService] Progression & Mastery Engine online ✓")
end

-- ============================================================
-- XP DISTRIBUTION API
-- ============================================================
function ProgressionService.AwardXP(player: Player, amount: number, reason: string?)
	local dataSvc = getDataService()
	if not dataSvc then return end
	dataSvc.AddXP(player, amount, reason)
end

function ProgressionService.HasPerk(player: Player, perkId: string): boolean
	local dataSvc = getDataService()
	if not dataSvc then return false end
	return dataSvc.HasPerk(player, perkId)
end

-- ============================================================
-- ACTIVE CAPSTONE ABILITY 1: PHANTOM DASH [Q]
-- ============================================================
local dashCooldowns: { [Player]: number } = {}
local dashInvulnerable: { [Player]: number } = {}

function ProgressionService.IsInvulnerable(player: Player): boolean
	local expiry = dashInvulnerable[player]
	return expiry ~= nil and os.clock() < expiry
end

function ProgressionService.ExecutePhantomDash(player: Player): (boolean, string?)
	if not ProgressionService.HasPerk(player, "PhantomDash") then
		return false, "Phantom Dash perk required"
	end

	local now = os.clock()
	local lastDash = dashCooldowns[player] or 0
	if now - lastDash < 12.0 then
		local remaining = math.ceil(12.0 - (now - lastDash))
		return false, `Dash on cooldown ({remaining}s)`
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not root or not hum or hum.Health <= 0 then
		return false, "Invalid character"
	end

	dashCooldowns[player] = now
	dashInvulnerable[player] = now + 1.2

	-- Forward impulse
	local lookDir = root.CFrame.LookVector
	root.AssemblyLinearVelocity = lookDir * 75 + Vector3.new(0, 8, 0)

	-- Broadcast dash VFX to all clients
	local vfxEvt = ReplicatedStorage:FindFirstChild("VFXBroadcast") :: RemoteEvent?
	if vfxEvt then
		vfxEvt:FireAllClients("PhantomDash", root.Position, lookDir)
	end

	print(`  [Progression] {player.Name} executed Phantom Dash!`)
	return true, "Dash activated!"
end

-- ============================================================
-- ACTIVE CAPSTONE ABILITY 2: SHOCKWAVE SLAM [R]
-- ============================================================
local slamCooldowns: { [Player]: number } = {}

function ProgressionService.ExecuteShockwaveSlam(player: Player): (boolean, string?)
	if not ProgressionService.HasPerk(player, "ShockwaveSlam") then
		return false, "Shockwave Slam perk required"
	end

	local now = os.clock()
	local lastSlam = slamCooldowns[player] or 0
	if now - lastSlam < 15.0 then
		local remaining = math.ceil(15.0 - (now - lastSlam))
		return false, `Slam on cooldown ({remaining}s)`
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not root or not hum or hum.Health <= 0 then
		return false, "Invalid character"
	end

	slamCooldowns[player] = now

	-- Knock back all other players within 18 studs
	local slamPos = root.Position
	local hitCount = 0

	for _, other in Players:GetPlayers() do
		if other ~= player then
			local oChar = other.Character
			local oRoot = oChar and oChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			local oHum = oChar and oChar:FindFirstChildOfClass("Humanoid")
			if oRoot and oHum and oHum.Health > 0 then
				local dist = (oRoot.Position - slamPos).Magnitude
				if dist <= 18.0 then
					hitCount += 1
					local away = (oRoot.Position - slamPos).Unit
					oRoot.AssemblyLinearVelocity = away * 55 + Vector3.new(0, 22, 0)
					oHum:TakeDamage(25)

					-- Force drop carried loot if carrying
					local heistSvc = script.Parent:FindFirstChild("HeistService")
					if heistSvc then
						local hs = require(heistSvc :: ModuleScript)
						if type(hs.DropLoot) == "function" then
							hs.DropLoot(other)
						end
					end
				end
			end
		end
	end

	-- Broadcast Shockwave VFX
	local vfxEvt = ReplicatedStorage:FindFirstChild("VFXBroadcast") :: RemoteEvent?
	if vfxEvt then
		vfxEvt:FireAllClients("ShockwaveSlam", slamPos, hitCount)
	end

	ProgressionService.AwardXP(player, 50 + (hitCount * 30), "Shockwave Slam")
	print(`  [Progression] {player.Name} executed Shockwave Slam (Hit {hitCount} targets)!`)
	return true, `Shockwave hit {hitCount} targets!`
end

return ProgressionService
