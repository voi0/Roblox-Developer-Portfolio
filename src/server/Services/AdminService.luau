--!strict
--[[
	AdminService.luau — Creator Suite & Debug Engine for VAULT WARS: STEAL & DEFEND TYCOON
	Provides instant dev commands for creator Yassein ("intradient") and Studio testing:
	- /cash <amount>      : Grants banked cash
	- /relic <id>         : Grants relics into stash
	- /airdrop            : Spawns Central Plaza Golden Crate immediately
	- /laser <tier>       : Instantly sets base laser tier
	- /jam <plotIndex>    : EMP-jams target plot lasers
	- /max                : Instantly maxes upgrades and grants $100,000,000
	- /reset              : Resets player profile to default
	Located in: ServerScriptService.Server.Services.AdminService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RelicData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelicData"))

local AdminService = {}

local function isAuthorized(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return player.Name:lower() == Config.Admin.CreatorUsername:lower()
end

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

local function getAirdropService(): any?
	local svc = script.Parent:FindFirstChild("AirdropService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

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

local function notify(player: Player, title: string, message: string)
	local notifEvt = ReplicatedStorage:FindFirstChild("NotificationBroadcast") :: RemoteEvent?
	if notifEvt then
		notifEvt:FireClient(player, {
			Title = `🛠️ [DEV] {title}`,
			Message = message,
			Type = "System",
			Duration = 4,
		})
	end
	print(`  [AdminService] [{player.Name}] {title}: {message}`)
end

function AdminService.Init()
	print("  [AdminService] Initializing Creator Suite & Dev Commands Engine...")

	local function onPlayerAdded(player: Player)
		player.Chatted:Connect(function(message: string)
			if not isAuthorized(player) then return end
			AdminService.ProcessCommand(player, message)
		end)
	end

	for _, p in Players:GetPlayers() do
		onPlayerAdded(p)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	print("  [AdminService] Creator Suite online (Whitelist: " .. Config.Admin.CreatorUsername .. ") ✓")
end

function AdminService.ProcessCommand(player: Player, msg: string)
	local parts = string.split(msg, " ")
	local cmd = string.lower(parts[1] or "")

	local dataSvc = getDataService()

	-- 1. /cash <amount>
	if cmd == "/cash" or cmd == ":cash" then
		local amt = tonumber(parts[2]) or 1000000
		if dataSvc then
			dataSvc.AddBankedCash(player, amt)
			notify(player, "Cash Added", `Granted +${amt} Banked Cash!`)
		end

	-- 2. /relic <id> [count]
	elseif cmd == "/relic" or cmd == ":relic" then
		local relicInput = parts[2] or "CelestialCrown"
		local count = tonumber(parts[3]) or 3
		local targetId = "CelestialCrown"

		for id, _ in RelicData.Catalog do
			if string.lower(id) == string.lower(relicInput) then
				targetId = id
				break
			end
		end

		if dataSvc then
			dataSvc.AddRelic(player, targetId, count)
			notify(player, "Relics Granted", `Added {count}x {targetId} to inventory!`)
		end

	-- 3. /airdrop
	elseif cmd == "/airdrop" or cmd == ":airdrop" then
		local airdropSvc = getAirdropService()
		if airdropSvc then
			airdropSvc.SpawnAirdrop()
			notify(player, "Airdrop Triggered", "Central Plaza Golden Crate launched!")
		end

	-- 4. /laser <tier>
	elseif cmd == "/laser" or cmd == ":laser" then
		local tier = tonumber(parts[2]) or 4
		local plotSvc = getPlotService()
		local laserSvc = getLaserService()
		local plot = plotSvc and plotSvc.GetPlotForPlayer(player)
		if plot and laserSvc and dataSvc then
			local data = dataSvc.GetData(player)
			if data then data.LaserTier = tier end
			laserSvc.UpdateTier(plot.Index, tier)
			dataSvc.SyncClient(player)
			notify(player, "Laser Updated", `Base lasers set to Tier {tier}!`)
		end

	-- 5. /jam <plotIndex>
	elseif cmd == "/jam" or cmd == ":jam" then
		local pIdx = tonumber(parts[2]) or 1
		local laserSvc = getLaserService()
		if laserSvc then
			laserSvc.DisableLasers(pIdx, 15.0)
			notify(player, "Lasers Jammed", `Vault #{pIdx} lasers jammed for 15s!`)
		end

	-- 6. /max
	elseif cmd == "/max" or cmd == ":max" then
		if dataSvc then
			local data = dataSvc.GetData(player)
			if data then
				data.BankedCash += 100000000
				data.ConveyorLevel = 25
				data.LaserTier = 4
				data.TurretTier = 4
				data.VaultInterestTier = 10
				data.PrestigeTokens = (data.PrestigeTokens or 0) + 50
				data.SyndicateTokens = (data.SyndicateTokens or 0) + 50
				data.Level = 50
				data.SkillPoints = (data.SkillPoints or 0) + 30
				dataSvc.SyncClient(player)

				local plotSvc = getPlotService()
				local laserSvc = getLaserService()
				local plot = plotSvc and plotSvc.GetPlotForPlayer(player)
				if plot then
					if laserSvc then laserSvc.UpdateTier(plot.Index, 4) end
					plotSvc.UpdateConsolesForPlot(plot.Index)
				end

				notify(player, "Max Stats", "Conveyor Lv25, Laser T4, Turret T4, Interest T10, Level 50, +30 SP, +$100M, +50 Tokens!")
			end
		end

	-- 7. /xp <amount>
	elseif cmd == "/xp" or cmd == ":xp" then
		local amt = tonumber(parts[2]) or 1000
		if dataSvc then
			dataSvc.AddXP(player, amt, "Admin Grant")
			notify(player, "XP Granted", `Awarded +{amt} XP!`)
		end

	-- 8. /sp <amount>
	elseif cmd == "/sp" or cmd == ":sp" then
		local amt = tonumber(parts[2]) or 5
		if dataSvc then
			local data = dataSvc.GetData(player)
			if data then
				data.SkillPoints = (data.SkillPoints or 0) + amt
				dataSvc.SyncClient(player)
				notify(player, "SP Granted", `Awarded +{amt} Skill Points!`)
			end
		end

	-- 9. /unlockallperks
	elseif cmd == "/unlockallperks" or cmd == ":unlockallperks" then
		if dataSvc then
			local data = dataSvc.GetData(player)
			if data then
				if not data.UnlockedPerks then data.UnlockedPerks = {} end
				for perkId in Config.Progression.Perks do
					data.UnlockedPerks[perkId] = true
				end
				dataSvc.SyncClient(player)
				notify(player, "Perks Unlocked", "Unlocked all 12 Infiltrator, Enforcer & Tycoon perks!")
			end
		end

	-- 10. /tokens <amount>
	elseif cmd == "/tokens" or cmd == ":tokens" then
		local amt = tonumber(parts[2]) or 10
		if dataSvc then
			dataSvc.AddSyndicateTokens(player, amt)
			notify(player, "Tokens Granted", `Awarded +{amt} Syndicate Tokens!`)
		end

	-- 11. /turret <tier>
	elseif cmd == "/turret" or cmd == ":turret" then
		local tier = tonumber(parts[2]) or 4
		if dataSvc then
			local data = dataSvc.GetData(player)
			if data then
				data.TurretTier = math.clamp(tier, 1, Config.Turret.MaxTier)
				dataSvc.SyncClient(player)
				local plotSvc = getPlotService()
				local plot = plotSvc and plotSvc.GetPlotForPlayer(player)
				if plot then
					plotSvc.UpdateConsolesForPlot(plot.Index)
				end
				notify(player, "Turret Tier Set", `Base Turret set to Tier {data.TurretTier}!`)
			end
		end

	-- 12. /reset
	elseif cmd == "/reset" or cmd == ":reset" then
		if dataSvc then
			local data = dataSvc.GetData(player)
			if data then
				data.BankedCash = 0
				data.UnbankedCash = 0
				data.ConveyorLevel = 1
				data.LaserTier = 1
				data.TurretTier = 1
				data.VaultInterestTier = 1
				data.PrestigeTokens = 0
				data.PrestigeLevel = 0
				data.SyndicateTokens = 0
				data.Contracts = {}
				data.RelicInventory = {}
				data.XP = 0
				data.Level = 1
				data.SkillPoints = 0
				data.UnlockedPerks = {}
				dataSvc.SyncClient(player)
				local plotSvc = getPlotService()
				local plot = plotSvc and plotSvc.GetPlotForPlayer(player)
				if plot then
					plotSvc.UpdateConsolesForPlot(plot.Index)
				end
				notify(player, "Profile Reset", "Reset data back to baseline level 1.")
			end
		end
	end
end

return AdminService
