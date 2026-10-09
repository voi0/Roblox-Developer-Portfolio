--!strict
--[[
	PlaytimeService.luau — Session Length Maximizer & AFK Rewards for VAULT WARS
	Tracks continuous player engagement time for Roblox Premium Payouts.
	Awards progressive time-gated Banked Cash at 5m, 15m, 30m, and 60m.
	Located in: ServerScriptService.Server.Services.PlaytimeService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaytimeService = {}
PlaytimeService._sessionTime = {} :: { [Player]: number }
PlaytimeService._claimedTiers = {} :: { [Player]: { [number]: boolean } }

local TIERS = {
	{ Minutes = 5,  Cash = 1000,   Label = "5 Min Reward" },
	{ Minutes = 15, Cash = 5000,   Label = "15 Min Reward" },
	{ Minutes = 30, Cash = 20000,  Label = "30 Min Reward" },
	{ Minutes = 60, Cash = 100000, Label = "60 Min Reward" },
}

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

function PlaytimeService.Init()
	print("  [PlaytimeService] Initializing Session Retention Engine...")

	local playtimeRF = ReplicatedStorage:FindFirstChild("PlaytimeRequest") :: RemoteFunction?
	if not playtimeRF then
		playtimeRF = Instance.new("RemoteFunction")
		playtimeRF.Name = "PlaytimeRequest"
		playtimeRF.Parent = ReplicatedStorage
	end

	playtimeRF.OnServerInvoke = function(player: Player, action: string, tierIndex: any)
		if action == "Claim" and type(tierIndex) == "number" then
			return PlaytimeService.ClaimReward(player, tierIndex)
		elseif action == "GetData" then
			local mins = math.floor((PlaytimeService._sessionTime[player] or 0) / 60)
			return {
				Minutes = mins,
				Claimed = PlaytimeService._claimedTiers[player] or {},
			}
		end
		return { Success = false }
	end

	for _, p in Players:GetPlayers() do
		PlaytimeService._sessionTime[p] = 0
		PlaytimeService._claimedTiers[p] = {}
	end

	Players.PlayerAdded:Connect(function(p)
		PlaytimeService._sessionTime[p] = 0
		PlaytimeService._claimedTiers[p] = {}
	end)

	Players.PlayerRemoving:Connect(function(p)
		PlaytimeService._sessionTime[p] = nil
		PlaytimeService._claimedTiers[p] = nil
	end)

	-- Ticker every second
	task.spawn(function()
		while true do
			task.wait(1)
			for p, curTime in PlaytimeService._sessionTime do
				PlaytimeService._sessionTime[p] = curTime + 1
			end
		end
	end)

	print("  [PlaytimeService] Session Retention Engine online ✓")
end

function PlaytimeService.ClaimReward(player: Player, tierIndex: number): { Success: boolean, Message: string? }
	local tier = TIERS[tierIndex]
	if not tier then return { Success = false, Message = "Invalid tier." } end

	local mins = math.floor((PlaytimeService._sessionTime[player] or 0) / 60)
	if mins < tier.Minutes then
		return { Success = false, Message = `Need {tier.Minutes - mins} more minutes.` }
	end

	if not PlaytimeService._claimedTiers[player] then
		PlaytimeService._claimedTiers[player] = {}
	end
	if PlaytimeService._claimedTiers[player][tierIndex] then
		return { Success = false, Message = "Already claimed this tier!" }
	end

	PlaytimeService._claimedTiers[player][tierIndex] = true

	local dataSvc = getDataService()
	if dataSvc then
		dataSvc.AddBanked(player, tier.Cash)
	end

	return { Success = true, Message = `Claimed ${tier.Cash} Banked Cash!` }
end

return PlaytimeService
