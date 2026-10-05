--!strict
--[[
	GardenService.luau — Garden Grid System for STARWEAVE
	Manages planting, growth timers, harvesting, and plot management.
	Located in: ServerScriptService.Server.Services.GardenService

	All garden operations are server-authoritative.
	Client sends requests via RemoteEvents, server validates and executes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local SeedData = require(ReplicatedStorage.Shared.SeedData)
local MutationData = require(ReplicatedStorage.Shared.MutationData)

-- These will be required after Init to avoid circular deps
local DataService: any = nil
local MutationService: any = nil
local QuestService: any = nil

-- ============================================================
-- SERVICE
-- ============================================================
local GardenService = {}
GardenService._initialized = false
GardenService._growthTimers = {} :: { [Player]: { [number]: thread } } -- player -> plotIndex -> timer thread
GardenService._rateLimits = {} :: { [Player]: { LastPlant: number, LastHarvest: number, PlantCount: number, HarvestCount: number } }

-- ============================================================
-- RATE LIMITING
-- ============================================================

local function _checkRateLimit(player: Player, action: "Plant" | "Harvest"): boolean
	local limits = GardenService._rateLimits[player]
	if not limits then
		GardenService._rateLimits[player] = {
			LastPlant = 0,
			LastHarvest = 0,
			PlantCount = 0,
			HarvestCount = 0,
		}
		limits = GardenService._rateLimits[player]
	end

	local now = os.clock()

	if action == "Plant" then
		-- Reset counter every second
		if now - limits.LastPlant > 1.0 then
			limits.PlantCount = 0
			limits.LastPlant = now
		end
		limits.PlantCount = limits.PlantCount + 1
		return limits.PlantCount <= Config.Security.MaxPlantsPerSecond
	else
		if now - limits.LastHarvest > 1.0 then
			limits.HarvestCount = 0
			limits.LastHarvest = now
		end
		limits.HarvestCount = limits.HarvestCount + 1
		return limits.HarvestCount <= Config.Security.MaxHarvestsPerSecond
	end
end

-- ============================================================
-- PLANTING
-- ============================================================

--[[
	Plant a seed in a specific plot.
	Validates:
	- Player has data loaded
	- Plot exists and is unlocked
	- Plot is empty
	- Player has the seed in inventory
	- Seed is unlocked at player's rebirth level
]]
function GardenService.PlantSeed(player: Player, plotIndex: number, seedId: string): (boolean, string)
	-- Rate limit
	if not _checkRateLimit(player, "Plant") then
		return false, "Too many actions. Slow down!"
	end

	-- Get player data
	local data = DataService.GetData(player)
	if not data then return false, "Data not loaded." end

	-- Validate seed exists
	local seedDef = SeedData.GetSeed(seedId)
	if not seedDef then return false, "Invalid seed." end

	-- Check rebirth unlock
	if data.Rebirth.Level < seedDef.UnlockRebirth then
		return false, `Requires Rebirth Level {seedDef.UnlockRebirth}.`
	end

	-- Validate plot
	local plot = data.Garden[plotIndex]
	if not plot then return false, "Invalid plot." end
	if not plot.Unlocked then return false, "Plot is locked." end
	if plot.Plant ~= nil then return false, "Plot is occupied." end

	-- Check seed inventory
	if not DataService.RemoveSeed(player, seedId, 1) then
		return false, "No seeds available."
	end

	-- Calculate growth time (with bonuses)
	local growthTime = seedDef.GrowthTime

	-- Instant grow gamepass
	if data.HasInstantGrow then
		growthTime = math.max(growthTime * 0.5, 1) -- 50% faster, min 1 second
	end

	-- Cosmic Pass bonus
	if data.HasCosmicPass then
		growthTime = growthTime * 0.85 -- 15% faster
	end

	-- Pet harvest speed bonus
	if data.EquippedPetIndex and data.Pets[data.EquippedPetIndex] then
		local pet = data.Pets[data.EquippedPetIndex]
		growthTime = growthTime / (pet.HarvestSpeedBonus or 1.0)
	end

	-- Subscription bonus
	if data.SubscriptionActive then
		growthTime = growthTime * 0.9 -- 10% faster
	end

	-- Cosmic Weather bonus (e.g. Solar Flare 3.0x speed)
	pcall(function()
		local ws = require(script.Parent.WeatherService)
		local growthMult = ws.GetGrowthMultiplier()
		if growthMult > 1.0 then
			growthTime = growthTime / growthMult
		end
	end)

	-- Create plant instance
	local now = os.time()
	local plant = {
		PlotIndex = plotIndex,
		SeedId = seedId,
		State = "Growing" :: string,
		PlantedAt = now,
		GrowthEndAt = now + math.floor(growthTime),
		MutationTier = "None" :: string,
		MutationMultiplier = 1.0,
		IsAutoHarvested = false,
	}

	-- Place in plot
	DataService.SetPlotPlant(player, plotIndex, plant)

	-- Start growth timer
	GardenService._startGrowthTimer(player, plotIndex, growthTime)

	-- Notify client
	local gardenEvent = ReplicatedStorage:FindFirstChild("GardenUpdate")
	if gardenEvent and gardenEvent:IsA("RemoteEvent") then
		gardenEvent:FireClient(player, "Planted", plotIndex, plant)
	end

	-- Track daily quest
	if QuestService then
		QuestService.TrackProgress(player, "plant_crops", 1)
	end

	-- Track active objective
	DataService.ProgressObjective(player, "Plant", 1, nil)

	return true, "Planted!"
end

-- ============================================================
-- GROWTH TIMER
-- ============================================================

function GardenService._startGrowthTimer(player: Player, plotIndex: number, duration: number)
	-- Cancel existing timer for this plot
	GardenService._cancelGrowthTimer(player, plotIndex)

	-- Initialize player timer table if needed
	if not GardenService._growthTimers[player] then
		GardenService._growthTimers[player] = {}
	end

	-- Create timer thread
	GardenService._growthTimers[player][plotIndex] = task.spawn(function()
		task.wait(duration)

		-- Growth complete
		local data = DataService.GetData(player)
		if not data then return end

		local plot = data.Garden[plotIndex]
		if not plot or not plot.Plant then return end

		-- Mark as ready
		plot.Plant.State = "Ready"

		-- Notify client
		local gardenEvent = ReplicatedStorage:FindFirstChild("GardenUpdate")
		if gardenEvent and gardenEvent:IsA("RemoteEvent") then
			gardenEvent:FireClient(player, "Ready", plotIndex, plot.Plant)
		end

		-- Auto-harvest if player has the gamepass
		if data.HasAutoHarvester then
			task.wait(Config.Garden.AutoHarvesterInterval)
			if plot.Plant and plot.Plant.State == "Ready" then
				GardenService.HarvestPlant(player, plotIndex)
			end
		end
	end)
end

function GardenService._cancelGrowthTimer(player: Player, plotIndex: number)
	if GardenService._growthTimers[player] and GardenService._growthTimers[player][plotIndex] then
		task.cancel(GardenService._growthTimers[player][plotIndex])
		GardenService._growthTimers[player][plotIndex] = nil
	end
end

-- ============================================================
-- HARVESTING
-- ============================================================

--[[
	Harvest a fully-grown plant from a plot.
	This triggers the mutation RNG roll and calculates final value.

	Returns harvest result or nil on failure.
]]
function GardenService.HarvestPlant(player: Player, plotIndex: number): (boolean, any?)
	-- Rate limit
	if not _checkRateLimit(player, "Harvest") then
		return false, nil
	end

	local data = DataService.GetData(player)
	if not data then return false, nil end

	local plot = data.Garden[plotIndex]
	if not plot then return false, nil end
	if not plot.Plant then return false, nil end
	if plot.Plant.State ~= "Ready" then return false, nil end

	local seedId = plot.Plant.SeedId

	-- Roll mutation
	local mutationResult = MutationService.RollMutation(data, seedId)

	-- Calculate harvest value
	local finalValue = MutationService.CalculateHarvestValue(
		data,
		seedId,
		mutationResult.Multiplier
	)

	-- Add currency
	DataService.AddCurrency(player, "Stardust", finalValue)

	-- Add experience
	local seed = SeedData.GetSeed(seedId)
	local xpGain = Config.Leveling.BaseXPPerHarvest
	if seed then
		local tierMult = SeedData.TierOrder[seed.Tier] or 1
		xpGain = xpGain * tierMult
	end
	DataService.AddExperience(player, xpGain)

	-- Increment harvest counter
	DataService.IncrementHarvests(player)

	-- Check collection
	local collectionKey = MutationService.GetCollectionKey(seedId, mutationResult.Tier)
	local isNewCollection = DataService.AddToCollection(player, collectionKey)

	-- Clear the plot
	DataService.SetPlotPlant(player, plotIndex, nil)

	-- Build result
	local harvestResult = {
		Success = true,
		SeedId = seedId,
		MutationTier = mutationResult.Tier,
		MutationMultiplier = mutationResult.Multiplier,
		BaseValue = seed and seed.BaseValue or 0,
		FinalValue = finalValue,
		IsNewCollection = isNewCollection,
		IsRare = mutationResult.IsRare,
	}

	-- Notify client
	local gardenEvent = ReplicatedStorage:FindFirstChild("GardenUpdate")
	if gardenEvent and gardenEvent:IsA("RemoteEvent") then
		gardenEvent:FireClient(player, "Harvested", plotIndex, harvestResult)
	end

	-- Server-wide announcement for rare mutations
	if mutationResult.IsRare then
		local announcement = `🌟 {player.Name} harvested a {mutationResult.Tier} {seed and seed.Name or "plant"} ({mutationResult.Multiplier}x)!`
		local announceEvent = ReplicatedStorage:FindFirstChild("ServerAnnouncement")
		if announceEvent and announceEvent:IsA("RemoteEvent") then
			announceEvent:FireAllClients(announcement, mutationResult.Tier)
		end
	end

	-- Track daily quests
	if QuestService then
		if harvestResult.MutationTier and harvestResult.MutationTier ~= "None" then
			QuestService.TrackProgress(player, "harvest_mutations", 1)
		end
		if harvestResult.FinalValue and harvestResult.FinalValue > 0 then
			QuestService.TrackProgress(player, "earn_stardust", harvestResult.FinalValue)
		end
	end

	-- Track active objectives
	DataService.ProgressObjective(player, "Harvest", 1, nil)
	if harvestResult.MutationTier and harvestResult.MutationTier ~= "None" then
		DataService.ProgressObjective(player, "HarvestMutation", 1, nil)
	end

	return true, harvestResult
end

-- ============================================================
-- PLOT UNLOCKING
-- ============================================================

function GardenService.UnlockPlot(player: Player, plotIndex: number): (boolean, string)
	local data = DataService.GetData(player)
	if not data then return false, "Data not loaded." end

	local plot = data.Garden[plotIndex]
	if not plot then return false, "Invalid plot." end
	if plot.Unlocked then return false, "Already unlocked." end

	-- Calculate cost (exponential scaling)
	local currentGardenSize = data.GardenSize or Config.Garden.StartingSize
	local unlockedCount = math.max(0, currentGardenSize - Config.Garden.StartingSize)
	local cost = math.floor(
		Config.Garden.PlotUnlockBaseCost
		* (Config.Garden.PlotUnlockCostMultiplier ^ unlockedCount)
	)

	-- Deduct currency
	if not DataService.RemoveCurrency(player, "Stardust", cost) then
		return false, `Need {cost} Stardust.`
	end

	-- Unlock
	DataService.UnlockPlot(player, plotIndex)
	DataService.ProgressObjective(player, "UnlockPlot", 1, plotIndex)

	-- Notify client
	local gardenEvent = ReplicatedStorage:FindFirstChild("GardenUpdate")
	if gardenEvent and gardenEvent:IsA("RemoteEvent") then
		gardenEvent:FireClient(player, "PlotUnlocked", plotIndex, nil)
	end

	return true, "Plot unlocked!"
end

-- ============================================================
-- SEED SHOP
-- ============================================================

--[[
	Buy seeds from the shop using Stardust.
	Seed prices scale by tier.
]]
local SEED_PRICE_MULTIPLIER: { [string]: number } = {
	Common = 2,      -- 2x base value to buy
	Uncommon = 2.5,
	Rare = 3,
	Epic = 3.5,
	Legendary = 4,
	Celestial = 5,
	Void = 6,
}

function GardenService.BuySeed(player: Player, seedId: string, count: number): (boolean, string)
	if count <= 0 or count > 100 then return false, "Invalid quantity." end

	local data = DataService.GetData(player)
	if not data then return false, "Data not loaded." end

	local seed = SeedData.GetSeed(seedId)
	if not seed then return false, "Invalid seed." end

	-- Check rebirth unlock
	if data.Rebirth.Level < seed.UnlockRebirth then
		return false, `Requires Rebirth Level {seed.UnlockRebirth}.`
	end

	-- Calculate price
	local priceMultiplier = SEED_PRICE_MULTIPLIER[seed.Tier] or 3
	local pricePerSeed = math.floor(seed.BaseValue * priceMultiplier)
	local totalPrice = pricePerSeed * count

	-- Deduct
	if not DataService.RemoveCurrency(player, "Stardust", totalPrice) then
		return false, `Need {totalPrice} Stardust.`
	end

	-- Add seeds
	DataService.AddSeeds(player, seedId, count)
	DataService.ProgressObjective(player, "BuySeed", count, nil)

	return true, `Bought {count}x {seed.Name}!`
end

-- ============================================================
-- SEED FORGE (Combine 3 identical seeds into higher tier)
-- ============================================================

local TIER_UPGRADE_MAP: { [string]: string } = {
	Common = "Uncommon",
	Uncommon = "Rare",
	Rare = "Epic",
	Epic = "Legendary",
	Legendary = "Celestial",
	Celestial = "Void",
}

function GardenService.ForgeSeed(player: Player, seedId: string): (boolean, string, string?)
	local data = DataService.GetData(player)
	if not data then return false, "Data not loaded.", nil end

	local seed = SeedData.GetSeed(seedId)
	if not seed then return false, "Invalid seed.", nil end

	local currentCount = DataService.GetSeedCount(player, seedId)
	if currentCount < 3 then
		return false, "You need at least 3 identical seeds to forge!", nil
	end

	local nextTier = TIER_UPGRADE_MAP[seed.Tier]
	if not nextTier then
		return false, "This seed tier has reached maximum ascension!", nil
	end

	local possibleNextSeeds = SeedData.GetSeedsByTier(nextTier)
	if #possibleNextSeeds == 0 then
		return false, "No next-tier seeds available.", nil
	end

	local nextSeed = possibleNextSeeds[math.random(#possibleNextSeeds)]

	-- Consume 3 input seeds
	if not DataService.RemoveSeed(player, seedId, 3) then
		return false, "Failed to consume seeds.", nil
	end

	-- Grant upgraded seed
	DataService.AddSeeds(player, nextSeed.Id, 1)

	-- Track active objective
	DataService.ProgressObjective(player, "Forge", 1, nil)

	-- Track daily quest
	if QuestService then
		QuestService.TrackProgress(player, "forge_seeds", 1)
	end

	return true, `Successfully forged 3x {seed.Name} into 1x {nextSeed.Name}!`, nextSeed.Id
end

-- ============================================================
-- SKIP GROWTH (DevProduct)
-- ============================================================

function GardenService.SkipGrowth(player: Player, plotIndex: number): (boolean, string)
	local data = DataService.GetData(player)
	if not data then return false, "Data not loaded." end

	local plot = data.Garden[plotIndex]
	if not plot or not plot.Plant then return false, "No plant here." end
	if plot.Plant.State == "Ready" then return false, "Already grown." end

	-- Cancel growth timer and mark as ready
	GardenService._cancelGrowthTimer(player, plotIndex)
	plot.Plant.State = "Ready"
	plot.Plant.GrowthEndAt = os.time()

	-- Notify client
	local gardenEvent = ReplicatedStorage:FindFirstChild("GardenUpdate")
	if gardenEvent and gardenEvent:IsA("RemoteEvent") then
		gardenEvent:FireClient(player, "Ready", plotIndex, plot.Plant)
	end

	return true, "Growth skipped!"
end

-- ============================================================
-- CLEANUP
-- ============================================================

function GardenService.OnPlayerRemoving(player: Player)
	-- Cancel all growth timers
	if GardenService._growthTimers[player] then
		for plotIndex, thread in GardenService._growthTimers[player] do
			task.cancel(thread)
		end
		GardenService._growthTimers[player] = nil
	end

	-- Remove rate limits
	GardenService._rateLimits[player] = nil
end

-- ============================================================
-- RESUME GROWTH ON JOIN
-- ============================================================

function GardenService.ResumeGrowthTimers(player: Player)
	local data = DataService.GetData(player)
	if not data then return end

	local now = os.time()

	for _, plot in data.Garden do
		if plot.Plant and plot.Plant.State == "Growing" then
			local remainingTime = plot.Plant.GrowthEndAt - now
			if remainingTime <= 0 then
				-- Already grown while offline
				plot.Plant.State = "Ready"

				-- Auto-harvest if gamepass
				if data.HasAutoHarvester then
					task.defer(function()
						GardenService.HarvestPlant(player, plot.Index)
					end)
				end
			else
				-- Resume timer
				GardenService._startGrowthTimer(player, plot.Index, remainingTime)
			end
		end
	end
end

-- ============================================================
-- INITIALIZATION
-- ============================================================

function GardenService.Init()
	if GardenService._initialized then return end
	GardenService._initialized = true

	-- Resolve service dependencies
	local ServerScriptService = game:GetService("ServerScriptService")
	DataService = require(ServerScriptService.Server.Services.DataService)
	MutationService = require(ServerScriptService.Server.Services.MutationService)
	QuestService = require(ServerScriptService.Server.Services.QuestService)

	-- Create remote events
	local gardenEvent = Instance.new("RemoteEvent")
	gardenEvent.Name = "GardenUpdate"
	gardenEvent.Parent = ReplicatedStorage

	local announceEvent = Instance.new("RemoteEvent")
	announceEvent.Name = "ServerAnnouncement"
	announceEvent.Parent = ReplicatedStorage

	-- Create remote functions for client requests
	local gardenRequest = Instance.new("RemoteFunction")
	gardenRequest.Name = "GardenRequest"
	gardenRequest.Parent = ReplicatedStorage

	gardenRequest.OnServerInvoke = function(player: Player, action: string, ...: any): any
		if action == "Plant" then
			local plotIndex, seedId = ...
			local success, message = GardenService.PlantSeed(player, plotIndex :: number, seedId :: string)
			return { Success = success, Message = message }

		elseif action == "Harvest" then
			local plotIndex = ...
			local success, result = GardenService.HarvestPlant(player, plotIndex :: number)
			return { Success = success, Result = result }

		elseif action == "UnlockPlot" then
			local plotIndex = ...
			local success, message = GardenService.UnlockPlot(player, plotIndex :: number)
			return { Success = success, Message = message }

		elseif action == "BuySeed" then
			local seedId, count = ...
			local success, message = GardenService.BuySeed(player, seedId :: string, count :: number)
			return { Success = success, Message = message }

		elseif action == "SkipGrowth" then
			local plotIndex = ...
			local success, message = GardenService.SkipGrowth(player, plotIndex :: number)
			return { Success = success, Message = message }

		elseif action == "Forge" then
			local seedId = ...
			local success, message, newSeedId = GardenService.ForgeSeed(player, seedId :: string)
			return { Success = success, Message = message, NewSeedId = newSeedId }

		elseif action == "CollectWell" then
			local success, amount = DataService.CollectWell(player)
			return { Success = success, Amount = amount }
		end

		return { Success = false, Message = "Unknown action." }
	end

	-- Resume timers when data loads
	Players.PlayerAdded:Connect(function(player)
		-- Wait for data to load
		while not DataService.IsDataLoaded(player) do
			task.wait(0.1)
		end
		GardenService.ResumeGrowthTimers(player)
	end)

	-- Cleanup on leave
	Players.PlayerRemoving:Connect(GardenService.OnPlayerRemoving)

	-- Active Auto-Harvester Background Loop
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				local data = DataService and DataService.GetData(player)
				if data and data.HasAutoHarvester and data.Garden then
					for plotIdx, plot in data.Garden do
						if plot.Plant and plot.Plant.State == "Ready" then
							GardenService.HarvestPlant(player, plotIdx)
						end
					end
				end
			end
		end
	end)

	print("[GardenService] Initialized ✓")
end

return GardenService
