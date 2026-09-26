--!strict
--[[
	MutationData.luau — Mutation probability tables for STARWEAVE
	Defines all mutation tiers, their probabilities, multiplier ranges,
	and visual properties. The RNG engine rolls against these tables.
	Located in: ReplicatedStorage.Shared.MutationData
]]

local Types = require(script.Parent.Types)

export type MutationEntry = Types.MutationDefinition

-- ============================================================
-- MUTATION TIER DEFINITIONS
-- ============================================================
-- Probabilities are BASE chances (before luck bonuses, gamepasses, pets, weather)
-- Multipliers are the value multiplier applied to the harvested plant

local Mutations: { MutationEntry } = {
	{
		Tier = "None",
		MinMultiplier = 1.0,
		MaxMultiplier = 1.0,
		Chance = 0.0, -- "None" is the fallback, not rolled for
		ParticleColor = { R = 200, G = 200, B = 200 },
		DisplayName = "No Mutation",
	},
	{
		Tier = "Sprout",
		MinMultiplier = 2.0,
		MaxMultiplier = 5.0,
		Chance = 0.45, -- 45% of mutations are Sprout-tier
		ParticleColor = { R = 100, G = 255, B = 100 }, -- Green glow
		DisplayName = "🌱 Sprout Mutation",
	},
	{
		Tier = "Bloom",
		MinMultiplier = 5.0,
		MaxMultiplier = 15.0,
		Chance = 0.25, -- 25%
		ParticleColor = { R = 100, G = 200, B = 255 }, -- Blue glow
		DisplayName = "🌸 Bloom Mutation",
	},
	{
		Tier = "Radiant",
		MinMultiplier = 15.0,
		MaxMultiplier = 50.0,
		Chance = 0.15, -- 15%
		ParticleColor = { R = 255, G = 215, B = 0 }, -- Gold glow
		DisplayName = "✨ Radiant Mutation",
	},
	{
		Tier = "Astral",
		MinMultiplier = 50.0,
		MaxMultiplier = 200.0,
		Chance = 0.10, -- 10%
		ParticleColor = { R = 180, G = 100, B = 255 }, -- Purple glow
		DisplayName = "🔮 Astral Mutation",
	},
	{
		Tier = "Celestial",
		MinMultiplier = 200.0,
		MaxMultiplier = 1000.0,
		Chance = 0.04, -- 4%
		ParticleColor = { R = 255, G = 100, B = 200 }, -- Pink cosmic glow
		DisplayName = "🌌 Celestial Mutation",
	},
	{
		Tier = "Primordial",
		MinMultiplier = 1000.0,
		MaxMultiplier = 10000.0,
		Chance = 0.01, -- 1% — THE chase item
		ParticleColor = { R = 255, G = 255, B = 255 }, -- Blinding white
		DisplayName = "💫 PRIMORDIAL MUTATION",
	},
}

-- ============================================================
-- MUTATION TIER ORDER (for comparison operations)
-- ============================================================
local TierOrder: { [string]: number } = {
	None = 0,
	Sprout = 1,
	Bloom = 2,
	Radiant = 3,
	Astral = 4,
	Celestial = 5,
	Primordial = 6,
}

-- ============================================================
-- MODULE
-- ============================================================
local MutationDataModule = {
	Mutations = Mutations,
	TierOrder = TierOrder,
}

-- Get a specific mutation by tier name
function MutationDataModule.GetByTier(tier: string): MutationEntry?
	for _, mutation in Mutations do
		if mutation.Tier == tier then
			return mutation
		end
	end
	return nil
end

-- Get all mutations that can be rolled (excludes "None")
function MutationDataModule.GetRollableMutations(): { MutationEntry }
	local result: { MutationEntry } = {}
	for _, mutation in Mutations do
		if mutation.Tier ~= "None" then
			table.insert(result, mutation)
		end
	end
	return result
end

-- Check if tier A is rarer than tier B
function MutationDataModule.IsRarerThan(tierA: string, tierB: string): boolean
	return (TierOrder[tierA] or 0) > (TierOrder[tierB] or 0)
end

-- Check if a mutation tier qualifies as "rare" (for notifications/TikTok moments)
function MutationDataModule.IsRareTier(tier: string): boolean
	return (TierOrder[tier] or 0) >= TierOrder.Astral
end

-- Get the display color for a tier (for UI)
function MutationDataModule.GetTierColor(tier: string): Color3
	local mutation = MutationDataModule.GetByTier(tier)
	if mutation then
		return Color3.fromRGB(
			mutation.ParticleColor.R,
			mutation.ParticleColor.G,
			mutation.ParticleColor.B
		)
	end
	return Color3.fromRGB(200, 200, 200) -- default gray
end

return MutationDataModule
