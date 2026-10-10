--!strict
--[[
	DailyRewardService.luau — 7-Day Retention Streak Engine for VAULT WARS: STEAL & DEFEND TYCOON
	Provides cumulative 7-day retention rewards escalations:
	Day 1: $10,000 -> Day 7: $1,000,000 + 25 Tokens + 1x Mythic Void Eye!
	Located in: ServerScriptService.Server.Services.DailyRewardService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RelicData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelicData"))

local DailyRewardService = {}

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

function DailyRewardService.Init()
	print("  [DailyRewardService] Initializing 7-Day Retention Streak Engine...")

	local claimRF = ReplicatedStorage:FindFirstChild("ClaimDailyReward") :: RemoteFunction?
	if not claimRF then
		claimRF = Instance.new("RemoteFunction")
		claimRF.Name = "ClaimDailyReward"
		claimRF.Parent = ReplicatedStorage
	end
	claimRF.OnServerInvoke = function(player: Player)
		return DailyRewardService.Claim(player)
	end

	local statusRF = ReplicatedStorage:FindFirstChild("GetDailyStatus") :: RemoteFunction?
	if not statusRF then
		statusRF = Instance.new("RemoteFunction")
		statusRF.Name = "GetDailyStatus"
		statusRF.Parent = ReplicatedStorage
	end
	statusRF.OnServerInvoke = function(player: Player)
		return DailyRewardService.GetStatus(player)
	end

	print("  [DailyRewardService] 7-Day Retention Streak online ✓")
end

function DailyRewardService.GetStatus(player: Player): any
	local dataSvc = getDataService()
	local data = dataSvc and dataSvc.GetData(player)
	if not data then
		return { Streak = 0, CanClaim = false, TimeUntilNext = 0, Config = Config.DailyRewards }
	end

	local now = os.time()
	local lastClaim = data.LastDailyClaimTimestamp or 0
	local elapsed = now - lastClaim

	local canClaim = (lastClaim == 0) or (elapsed >= 72000) -- 20 hours cooldown
	local timeUntilNext = canClaim and 0 or math.max(0, 72000 - elapsed)
	local streak = data.DailyStreak or 0

	-- If streak expired (>48 hours), next claim will start at day 1
	if lastClaim > 0 and elapsed > 172800 then
		streak = 0
	end

	return {
		Streak = streak,
		CanClaim = canClaim,
		TimeUntilNext = timeUntilNext,
		Config = Config.DailyRewards,
	}
end

function DailyRewardService.Claim(player: Player): any
	local dataSvc = getDataService()
	local data = dataSvc and dataSvc.GetData(player)
	if not data then
		return { Success = false, Message = "Player data not loaded." }
	end

	local now = os.time()
	local lastClaim = data.LastDailyClaimTimestamp or 0
	local elapsed = now - lastClaim

	if lastClaim > 0 and elapsed < 72000 then
		local rem = 72000 - elapsed
		local hrs = math.floor(rem / 3600)
		local mins = math.floor((rem % 3600) / 60)
		return {
			Success = false,
			Message = `Next daily reward available in {hrs}h {mins}m!`,
		}
	end

	-- Determine next streak day
	local currentStreak = data.DailyStreak or 0
	local newStreak: number
	if lastClaim > 0 and elapsed > 172800 then
		newStreak = 1 -- Reset after 48h missed
	else
		newStreak = (currentStreak % 7) + 1
	end

	local reward = Config.DailyRewards[newStreak]
	if not reward then
		return { Success = false, Message = "Invalid reward configuration." }
	end

	-- Grant rewards
	if reward.Cash and reward.Cash > 0 then
		dataSvc.AddBankedCash(player, reward.Cash)
	end

	if reward.Tokens and reward.Tokens > 0 then
		dataSvc.AddPrestigeTokens(player, reward.Tokens)
	end

	local relicName: string? = nil
	if reward.RelicId then
		dataSvc.AddRelic(player, reward.RelicId, 1)
		local def = RelicData.Catalog[reward.RelicId]
		relicName = def and def.Name or reward.RelicId
	end

	data.DailyStreak = newStreak
	data.LastDailyClaimTimestamp = now

	-- Award active XP for daily login (+250 XP)
	local progMod = script.Parent:FindFirstChild("ProgressionService")
	if progMod then
		local ps = require(progMod :: ModuleScript)
		ps.AwardXP(player, Config.Progression.XPAwards.DailyClaim, "Daily Streak Claimed")
	end

	dataSvc.SyncClient(player)

	-- Broadcast / Notify player
	local notifEvt = ReplicatedStorage:FindFirstChild("NotificationBroadcast") :: RemoteEvent?
	if notifEvt then
		local desc = `Claimed: ${reward.Cash}`
		if relicName then desc ..= ` + {relicName}` end
		if reward.Tokens and reward.Tokens > 0 then desc ..= ` + {reward.Tokens} Tokens` end

		notifEvt:FireClient(player, {
			Title = `DAY {newStreak} STREAK CLAIMED!`,
			Message = desc,
			Type = "Daily",
			Duration = 5,
		})
	end

	print(`  [DailyRewardService] {player.Name} claimed Day {newStreak} reward!`)

	return {
		Success = true,
		Streak = newStreak,
		Reward = reward,
		RelicName = relicName,
	}
end

return DailyRewardService
