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
		local data = DataService.GetData(player)
		if data then
			if not data.SeedInventory then data.SeedInventory = {} end
			data.SeedInventory[cfg.Seed] = (data.SeedInventory[cfg.Seed] or 0) + 1
		end
	end

	return { Success = true, Message = `Claimed {cfg.Label}! (+{cfg.Stardust} SD)` }
end

function PlaytimeService._buildAFKPool()
	local garden = Workspace:WaitForChild("StarweaveGarden", 15) :: Folder?
	if not garden then return end

	local poolCenter = Vector3.new(32, 0.1, 2)

	-- Circular Meditation Pool Dais
	local poolModel = Instance.new("Model")
	poolModel.Name = "CosmicAFKPool"
	poolModel.Parent = garden

	local border = Instance.new("Part")
	border.Name = "PoolRim"
	border.Shape = Enum.PartType.Cylinder
	border.Size = Vector3.new(0.6, 16, 16)
	border.CFrame = CFrame.new(poolCenter) * CFrame.Angles(0, 0, math.rad(90))
	border.Material = Enum.Material.Slate
	border.Color = Color3.fromRGB(36, 30, 56)
	border.Anchored = true
	border.CanCollide = true
	border.Parent = poolModel

	local water = Instance.new("Part")
	water.Name = "MeditationWater"
	water.Shape = Enum.PartType.Cylinder
	water.Size = Vector3.new(0.4, 14.5, 14.5)
	water.CFrame = CFrame.new(poolCenter + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	water.Material = Enum.Material.Neon
	water.Color = Color3.fromRGB(56, 189, 248)
	water.Transparency = 0.45
	water.Anchored = true
	water.CanCollide = false
	water.Parent = poolModel

	-- Rising Stardust Column
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(56, 189, 248)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 85, 247)),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Rate = 24
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.LightEmission = 0.9
	emitter.Parent = water

	-- Floating 3D Title
	local tag = Instance.new("BillboardGui")
	tag.Name = "PoolTitle"
	tag.Size = UDim2.new(0, 200, 0, 50)
	tag.StudsOffset = Vector3.new(0, 4.0, 0)
	tag.AlwaysOnTop = false
	tag.MaxDistance = 50
	tag.Parent = water

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 22)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "✦ COSMIC MEDITATION POOL ✦"
	titleLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
	titleLabel.TextSize = 13
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = tag

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0, 16)
	subLabel.Position = UDim2.new(0, 0, 0, 22)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "Stand here for +75 Stardust/30s & +15% Luck"
	subLabel.TextColor3 = Color3.fromRGB(240, 230, 255)
	subLabel.TextSize = 10
	subLabel.Font = Enum.Font.GothamMedium
	subLabel.Parent = tag

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
				if player.Character and (player.Character:GetPivot().Position - poolCenter).Magnitude > 8 then
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
