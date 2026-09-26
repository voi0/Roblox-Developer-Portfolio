--!strict
--[[
	SeedData.luau — All seed definitions for STARWEAVE
	Each seed has a tier, base value, growth time, and mutation affinity.
	Located in: ReplicatedStorage.Shared.SeedData
]]

local Types = require(script.Parent.Types)

export type SeedEntry = Types.SeedDefinition

local SeedData: { [string]: SeedEntry } = {
	-- ============================================================
	-- COMMON SEEDS (Starter Meadow)
	-- ============================================================
	["starseed_basic"] = {
		Id = "starseed_basic",
		Name = "Basic Starseed",
		Tier = "Common",
		BaseValue = 10,
		GrowthTime = 15,
		BaseMutationChance = 0.30,
		UnlockRebirth = 0,
		Description = "A humble seed that glows faintly. Every cosmic garden starts here.",
	},
	["lunar_sprout"] = {
		Id = "lunar_sprout",
		Name = "Lunar Sprout",
		Tier = "Common",
		BaseValue = 18,
		GrowthTime = 20,
		BaseMutationChance = 0.32,
		UnlockRebirth = 0,
		Description = "Thrives under moonlight. Slightly higher mutation affinity.",
	},
	["dust_bloom"] = {
		Id = "dust_bloom",
		Name = "Dust Bloom",
		Tier = "Common",
		BaseValue = 25,
		GrowthTime = 25,
		BaseMutationChance = 0.28,
		UnlockRebirth = 0,
		Description = "Feeds on cosmic dust. Reliable, steady growth.",
	},

	-- ============================================================
	-- UNCOMMON SEEDS
	-- ============================================================
	["solar_fern"] = {
		Id = "solar_fern",
		Name = "Solar Fern",
		Tier = "Uncommon",
		BaseValue = 55,
		GrowthTime = 35,
		BaseMutationChance = 0.35,
		UnlockRebirth = 0,
		Description = "Absorbs starlight energy. Burns bright at harvest.",
	},
	["crystal_vine"] = {
		Id = "crystal_vine",
		Name = "Crystal Vine",
		Tier = "Uncommon",
		BaseValue = 80,
		GrowthTime = 45,
		BaseMutationChance = 0.33,
		UnlockRebirth = 0,
		Description = "Crystalline tendrils that refract light into rainbows.",
	},
	["nebula_moss"] = {
		Id = "nebula_moss",
		Name = "Nebula Moss",
		Tier = "Uncommon",
		BaseValue = 100,
		GrowthTime = 50,
		BaseMutationChance = 0.38,
		UnlockRebirth = 1,
		Description = "Soft, glowing moss that absorbs ambient cosmic energy.",
	},

	-- ============================================================
	-- RARE SEEDS
	-- ============================================================
	["aurora_blossom"] = {
		Id = "aurora_blossom",
		Name = "Aurora Blossom",
		Tier = "Rare",
		BaseValue = 250,
		GrowthTime = 75,
		BaseMutationChance = 0.40,
		UnlockRebirth = 2,
		Description = "Petals shift through the aurora spectrum. Mesmerizing.",
	},
	["gravity_root"] = {
		Id = "gravity_root",
		Name = "Gravity Root",
		Tier = "Rare",
		BaseValue = 400,
		GrowthTime = 90,
		BaseMutationChance = 0.36,
		UnlockRebirth = 3,
		Description = "Grows downward through spacetime. Defies physics.",
	},
	["comet_tulip"] = {
		Id = "comet_tulip",
		Name = "Comet Tulip",
		Tier = "Rare",
		BaseValue = 600,
		GrowthTime = 120,
		BaseMutationChance = 0.42,
		UnlockRebirth = 5,
		Description = "Leaves a trail of stardust when harvested.",
	},

	-- ============================================================
	-- EPIC SEEDS
	-- ============================================================
	["supernova_orchid"] = {
		Id = "supernova_orchid",
		Name = "Supernova Orchid",
		Tier = "Epic",
		BaseValue = 1_500,
		GrowthTime = 180,
		BaseMutationChance = 0.45,
		UnlockRebirth = 8,
		Description = "Erupts in a blinding flash at full bloom. Handle with care.",
	},
	["quasar_lily"] = {
		Id = "quasar_lily",
		Name = "Quasar Lily",
		Tier = "Epic",
		BaseValue = 3_000,
		GrowthTime = 240,
		BaseMutationChance = 0.42,
		UnlockRebirth = 12,
		Description = "Emits a focused beam of light visible from across the garden.",
	},

	-- ============================================================
	-- LEGENDARY SEEDS
	-- ============================================================
	["blackhole_rose"] = {
		Id = "blackhole_rose",
		Name = "Black Hole Rose",
		Tier = "Legendary",
		BaseValue = 10_000,
		GrowthTime = 360,
		BaseMutationChance = 0.50,
		UnlockRebirth = 20,
		Description = "Bends light around its petals. Nothing escapes its beauty.",
	},
	["dimension_tree"] = {
		Id = "dimension_tree",
		Name = "Dimension Tree",
		Tier = "Legendary",
		BaseValue = 25_000,
		GrowthTime = 600,
		BaseMutationChance = 0.48,
		UnlockRebirth = 30,
		Description = "Its branches stretch into parallel universes.",
	},

	-- ============================================================
	-- CELESTIAL SEEDS (Ultra-Rare)
	-- ============================================================
	["genesis_bloom"] = {
		Id = "genesis_bloom",
		Name = "Genesis Bloom",
		Tier = "Celestial",
		BaseValue = 100_000,
		GrowthTime = 900,
		BaseMutationChance = 0.60,
		UnlockRebirth = 40,
		Description = "The first flower that ever existed. Born from the Big Bang.",
	},

	-- ============================================================
	-- VOID SEEDS (Post-Endgame)
	-- ============================================================
	["void_singularity"] = {
		Id = "void_singularity",
		Name = "Void Singularity",
		Tier = "Void",
		BaseValue = 1_000_000,
		GrowthTime = 1800,
		BaseMutationChance = 0.70,
		UnlockRebirth = 50,
		Description = "It shouldn't exist. Yet here it blooms, consuming all light.",
	},
}

-- Utility: Get all seeds as a sorted array by tier
local TierOrder: { [string]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Celestial = 6,
	Void = 7,
}

local SeedDataModule = {
	Seeds = SeedData,
	TierOrder = TierOrder,
}

function SeedDataModule.GetSeed(seedId: string): SeedEntry?
	return SeedData[seedId]
end

function SeedDataModule.GetSeedsByTier(tier: string): { SeedEntry }
	local result: { SeedEntry } = {}
	for _, seed in SeedData do
		if seed.Tier == tier then
			table.insert(result, seed)
		end
	end
	return result
end

function SeedDataModule.GetUnlockedSeeds(rebirthLevel: number): { SeedEntry }
	local result: { SeedEntry } = {}
	for _, seed in SeedData do
		if seed.UnlockRebirth <= rebirthLevel then
			table.insert(result, seed)
		end
	end
	table.sort(result, function(a, b)
		return (TierOrder[a.Tier] or 0) < (TierOrder[b.Tier] or 0)
	end)
	return result
end

return SeedDataModule
