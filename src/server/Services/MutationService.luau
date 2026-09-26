--!strict
--[[
	MutationService.luau — The RNG Engine for STARWEAVE
	Handles all mutation probability rolls, luck calculations,
	and multiplier generation. This is the mathematical heart of the game.
	Located in: ServerScriptService.Server.Services.MutationService

	DESIGN PHILOSOPHY:
	- The mutation system uses a weighted lottery model
	- Luck bonuses from gamepasses, pets, and weather INCREASE
	  the chance of triggering a mutation, AND shift the distribution
	  toward higher tiers
	- Multipliers within each tier are uniformly random (fair)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MutationData = require(ReplicatedStorage.Shared.MutationData)
local SeedData = require(ReplicatedStorage.Shared.SeedData)

-- ============================================================
-- SERVICE
-- ============================================================
local MutationService = {}
MutationService._initialized = false
MutationService._weatherActive = false
MutationService._random = Random.new()

-- ============================================================
-- LUCK CALCULATION
-- ============================================================

--[[
	Calculates the total luck multiplier for a player.
	Luck affects BOTH:
	1. Whether a mutation occurs at all (base chance * luck)
	2. The tier distribution (higher luck = higher tier weights)

	Sources of luck:
	- Base seed mutation chance (varies per seed)
	- Gamepass: 2x Luck (+1.0)
	- Gamepass: Cosmic Pass (+0.5)
	- Pet: Mutation luck bonus (variable)
	- Weather: Storm bonus (2.0x during events)
	- Rebirth: +2% per rebirth level
]]
function MutationService.CalculateLuckMultiplier(playerData: any, seedId: string): number
	local seed = SeedData.GetSeed(seedId)
	if not seed then return 0 end

	local baseLuck = seed.BaseMutationChance
	local luckMultiplier = 1.0

	-- Gamepass bonuses
	if playerData.HasDoubleLuck then
		luckMultiplier = luckMultiplier + 1.0 -- +100%
	end
	if playerData.HasCosmicPass then
		luckMultiplier = luckMultiplier + 0.5 -- +50%
	end

	-- Subscription bonus
	if playerData.SubscriptionActive then
		luckMultiplier = luckMultiplier + 0.1 -- +10%
	end

	-- Pet bonus
	if playerData.EquippedPetIndex and playerData.Pets[playerData.EquippedPetIndex] then
		local pet = playerData.Pets[playerData.EquippedPetIndex]
		luckMultiplier = luckMultiplier + (pet.MutationLuckBonus or 0)
	end

	-- Rebirth bonus (+2% per rebirth level)
	local rebirthBonus = (playerData.Rebirth.Level or 0) * 0.02
	luckMultiplier = luckMultiplier + rebirthBonus

	-- Weather bonus
	if MutationService._weatherActive then
		luckMultiplier = luckMultiplier * Config.Engagement.WeatherMutationBonus
	end

	-- Final mutation chance (capped at 95% to always have some risk)
	local finalChance = math.min(baseLuck * luckMultiplier, 0.95)

	return finalChance
end

-- ============================================================
-- THE CORE RNG ROLL
-- ============================================================

--[[
	Rolls for a mutation on a harvested plant.
	
	Step 1: Roll whether a mutation occurs at all (based on luck-modified chance)
	Step 2: If yes, determine the mutation tier using weighted lottery
	Step 3: Roll the multiplier within that tier's range

	Returns: { Tier, Multiplier, IsRare }
]]
function MutationService.RollMutation(playerData: any, seedId: string): {
	Tier: string,
	Multiplier: number,
	IsRare: boolean,
}
	-- Step 1: Does a mutation occur?
	local mutationChance = MutationService.CalculateLuckMultiplier(playerData, seedId)
	local roll = MutationService._random:NextNumber()

	if roll > mutationChance then
		-- No mutation
		return {
			Tier = "None",
			Multiplier = 1.0,
			IsRare = false,
		}
	end

	-- Step 2: Determine mutation tier via weighted lottery
	local rollableMutations = MutationData.GetRollableMutations()
	local luckFactor = mutationChance -- Higher luck shifts weights toward rarer tiers

	-- Build weighted table with luck-adjusted probabilities
	local weightedTable: { { Tier: string, Weight: number } } = {}
	local totalWeight = 0

	for _, mutation in rollableMutations do
		-- Luck shifts the weight: rarer tiers get relatively more weight with higher luck
		local tierIndex = MutationData.TierOrder[mutation.Tier] or 1
		local luckBoost = 1.0 + (luckFactor * tierIndex * 0.15) -- Higher tiers benefit more from luck
		local adjustedWeight = mutation.Chance * luckBoost

		table.insert(weightedTable, {
			Tier = mutation.Tier,
			Weight = adjustedWeight,
		})
		totalWeight = totalWeight + adjustedWeight
	end

	-- Roll against weighted table
	local tierRoll = MutationService._random:NextNumber() * totalWeight
	local accumulated = 0
	local selectedTier = "Sprout" -- fallback

	for _, entry in weightedTable do
		accumulated = accumulated + entry.Weight
		if tierRoll <= accumulated then
			selectedTier = entry.Tier
			break
		end
	end

	-- Step 3: Roll multiplier within tier range
	local mutationDef = MutationData.GetByTier(selectedTier)
	if not mutationDef then
		return { Tier = "None", Multiplier = 1.0, IsRare = false }
	end

	local multiplier = MutationService._random:NextNumber()
		* (mutationDef.MaxMultiplier - mutationDef.MinMultiplier)
		+ mutationDef.MinMultiplier

	-- Round to 2 decimal places for clean display
	multiplier = math.floor(multiplier * 100 + 0.5) / 100

	return {
		Tier = selectedTier,
		Multiplier = multiplier,
		IsRare = MutationData.IsRareTier(selectedTier),
	}
end

-- ============================================================
-- HARVEST VALUE CALCULATION
-- ============================================================

--[[
	Calculates the final Stardust value of a harvested plant.

	Formula:
	FinalValue = BaseValue * MutationMultiplier * CosmicMultiplier * SellMultiplier

	Where:
	- BaseValue = seed's inherent value
	- MutationMultiplier = from the RNG roll
	- CosmicMultiplier = permanent rebirth bonus (1.0 + 0.25 * rebirthLevel)
	- SellMultiplier = base * constellation tree bonuses
]]
function MutationService.CalculateHarvestValue(
	playerData: any,
	seedId: string,
	mutationMultiplier: number
): number
	local seed = SeedData.GetSeed(seedId)
	if not seed then return 0 end

	local baseValue = seed.BaseValue
	local cosmicMult = playerData.Rebirth.CosmicMultiplier or 1.0
	local sellMult = Config.Economy.BaseSellMultiplier

	-- Constellation tree bonuses (example: "sell_bonus" node)
	local constellationSellBonus = 0
	if playerData.Rebirth.ConstellationTree then
		local sellNode = playerData.Rebirth.ConstellationTree["sell_bonus"]
		if sellNode then
			constellationSellBonus = sellNode * 0.05 -- +5% per level
		end
	end

	local finalValue = baseValue
		* mutationMultiplier
		* cosmicMult
		* (sellMult + constellationSellBonus)

	-- Round to whole number
	return math.floor(finalValue + 0.5)
end

-- ============================================================
-- SEED FORGE (Combine duplicates into higher tier)
-- ============================================================

--[[
	Forge 3 plants of the same mutation tier into a guaranteed
	seed of the next tier up. This is the "crafting" loop.

	Returns the forged seed's tier, or nil if invalid.
]]
function MutationService.CalculateForgeResult(inputTier: string): string?
	local tierOrder = MutationData.TierOrder
	local currentOrder = tierOrder[inputTier]
	if not currentOrder then return nil end

	-- Find next tier
	for tier, order in tierOrder do
		if order == currentOrder + 1 then
			return tier
		end
	end

	return nil -- Already max tier
end

-- ============================================================
-- WEATHER SYSTEM
-- ============================================================

function MutationService.SetWeatherActive(active: boolean)
	MutationService._weatherActive = active

	-- Fire event to all clients for visual effects
	local weatherEvent = ReplicatedStorage:FindFirstChild("WeatherChanged")
	if weatherEvent and weatherEvent:IsA("RemoteEvent") then
		weatherEvent:FireAllClients(active)
	end
end

function MutationService.IsWeatherActive(): boolean
	return MutationService._weatherActive
end

-- ============================================================
-- STATISTICS (for collection log)
-- ============================================================

function MutationService.GetCollectionKey(seedId: string, mutationTier: string): string
	return seedId .. "_" .. mutationTier
end

-- ============================================================
-- INITIALIZATION
-- ============================================================

function MutationService.Init()
	if MutationService._initialized then return end
	MutationService._initialized = true

	-- Create weather remote event
	local weatherEvent = Instance.new("RemoteEvent")
	weatherEvent.Name = "WeatherChanged"
	weatherEvent.Parent = ReplicatedStorage

	-- Start weather cycle
	task.spawn(function()
		while true do
			-- Wait random interval
			local waitTime = MutationService._random:NextInteger(
				Config.Engagement.WeatherEventMinInterval,
				Config.Engagement.WeatherEventMaxInterval
			)
			task.wait(waitTime)

			-- Activate weather event
			MutationService.SetWeatherActive(true)
			print("[MutationService] ⚡ Mutation Storm active!")

			-- Duration
			task.wait(Config.Engagement.WeatherEventDuration)

			-- Deactivate
			MutationService.SetWeatherActive(false)
			print("[MutationService] Mutation Storm ended.")
		end
	end)

	print("[MutationService] Initialized ✓")
end

return MutationService
