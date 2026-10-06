--!strict
--[[
	PlaytimeService.luau — AFK Meditation Pool & Session Length Maximizer for STARWEAVE
	Implements Masterplan Revenue Engine A:
	  - Tracks continuous player engagement time for Premium Payouts
	  - 4 Progressive Time-Gated Reward Tiers (5m, 15m, 30m, 60m)
	  - Cosmic Meditation Pool: Passive +50 Stardust/30s & +15% AFK Mutation Luck
	Located in: ServerScriptService.Server.Services.PlaytimeService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlaytimeService = {}
PlaytimeService._playerSessionTime = {} :: { [Player]: number }
PlaytimeService._claimedTiers = {} :: { [Player]: { [number]: boolean } }
PlaytimeService._inAFKPool = {} :: { [Player]: boolean }

local DataService: any = nil

local TIERS = {
	{ Minutes = 5,  Stardust = 500,   Gems = 5,   Seed = "lunar_sprout", Label = "5 Min Reward" },
	{ Minutes = 15, Stardust = 1500,  Gems = 20,  Seed = "solar_fern",   Label = "15 Min Reward" },
	{ Minutes = 30, Stardust = 5000,  Gems = 50,  Seed = "crystal_vine", Label = "30 Min Reward" },
	{ Minutes = 60, Stardust = 15000, Gems = 150, Seed = "supernova_orchid", Label = "60 Min Reward" },
}

function PlaytimeService.Init()
	local ServerScriptService = game:GetService("ServerScriptService")
	DataService = require(ServerScriptService.Server.Services.DataService)

	-- Build Cosmic AFK Pool in Workspace
	PlaytimeService._buildAFKPool()

	-- Remotes
	local playtimeReq = Instance.new("RemoteFunction")
	playtimeReq.Name = "PlaytimeRequest"
	playtimeReq.Parent = ReplicatedStorage

	local afkAlert = Instance.new("RemoteEvent")
	afkAlert.Name = "AFKAlert"
	afkAlert.Parent = ReplicatedStorage

	playtimeReq.OnServerInvoke = function(player: Player, action: string, tierIndex: any): any
		if action == "Claim" and type(tierIndex) == "number" then
			return PlaytimeService.ClaimReward(player, tierIndex)
		elseif action == "GetData" then
			local sessionMins = math.floor((PlaytimeService._playerSessionTime[player] or 0) / 60)
			return {
				Minutes = sessionMins,
				Claimed = PlaytimeService._claimedTiers[player] or {},
				InPool = PlaytimeService._inAFKPool[player] == true,
			}
		end
		return { Success = false }
	end

	-- Player Session Tracker
	Players.PlayerAdded:Connect(function(player)
		PlaytimeService._playerSessionTime[player] = 0
		PlaytimeService._claimedTiers[player] = {}
		PlaytimeService._inAFKPool[player] = false
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlaytimeService._playerSessionTime[player] = nil
		PlaytimeService._claimedTiers[player] = nil
		PlaytimeService._inAFKPool[player] = nil
	end)

	-- 1-Second Master Loop
	task.spawn(function()
		local afkCounter = 0
		while true do
			task.wait(1)
			afkCounter += 1

			for player, elapsed in PlaytimeService._playerSessionTime do
				PlaytimeService._playerSessionTime[player] = elapsed + 1
			end

			-- Every 30 seconds: Grant AFK Pool Rewards
			if afkCounter >= 30 then
				afkCounter = 0
				for player, inPool in PlaytimeService._inAFKPool do
					if inPool and player.Parent then
						DataService.AddCurrency(player, "Stardust", 75)
						afkAlert:FireClient(player, "AFK_TICK", 75)
					end
				end
			end
		end
	end)

	print("[PlaytimeService] Initialized ✓")
end

function PlaytimeService.ClaimReward(player: Player, tierIdx: number): { Success: boolean, Message: string }
	local cfg = TIERS[tierIdx]
	if not cfg then return { Success = false, Message = "Invalid tier." } end

	local elapsed = PlaytimeService._playerSessionTime[player] or 0
	local mins = math.floor(elapsed / 60)
	if mins < cfg.Minutes then
		return { Success = false, Message = `Requires {cfg.Minutes} minutes of playtime!` }
	end

	local claimed = PlaytimeService._claimedTiers[player]
	if not claimed then
		claimed = {}
		PlaytimeService._claimedTiers[player] = claimed
	end

	if claimed[tierIdx] then
		return { Success = false, Message = "Already claimed!" }
	end

	claimed[tierIdx] = true
	DataService.AddCurrency(player, "Stardust", cfg.Stardust)
	if cfg.Gems > 0 then
		DataService.AddCurrency(player, "NebulaGems", cfg.Gems)
	end
	if cfg.Seed then
		DataService.AddSeeds(player, cfg.Seed, 1)
	end

	DataService.SyncClient(player)
	return { Success = true, Message = `Claimed {cfg.Label}! (+{cfg.Stardust} SD)` }
end

function PlaytimeService._buildAFKPool()
	local garden = Workspace:WaitForChild("StarweaveGarden", 15) :: Folder?
	if not garden then return end

	local poolCenter = Vector3.new(0, 1.0, 24)

	-- Completely invisible AFK trigger volume - zero procedural neon shapes, zero 2D billboards
	local water = Instance.new("Part")
	water.Name = "MeditationTrigger"
	water.Size = Vector3.new(24, 8, 24)
	water.CFrame = CFrame.new(poolCenter)
	water.Transparency = 1
	water.CanCollide = false
	water.Anchored = true
	water.Parent = garden

	-- Zone Detection
	water.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if player then
			PlaytimeService._inAFKPool[player] = true
		end
	end)

	water.TouchEnded:Connect(function(hit)
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if player then
			task.delay(1, function()
				if player.Character and (player.Character:GetPivot().Position - poolCenter).Magnitude > 14 then
					PlaytimeService._inAFKPool[player] = false
				end
			end)
		end
	end)
end

function PlaytimeService.IsPlayerInAFKPool(player: Player): boolean
	return PlaytimeService._inAFKPool[player] == true
end

return PlaytimeService
