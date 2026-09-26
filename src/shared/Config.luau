--!strict
--[[
	Config.luau — Game constants and balance values for STARWEAVE
	All tunable values live here. Change one number, change the game.
	Located in: ReplicatedStorage.Shared.Config
]]

local Config = {}

-- ============================================================
-- GARDEN
-- ============================================================
Config.Garden = {
	-- Starting grid size (3x3 = 9 plots)
	StartingSize = 9,
	MaxSize = 64, -- 8x8 max grid

	-- Plot unlock costs (Stardust) by plot index
	-- First 9 are free, then escalating cost
	PlotUnlockBaseCost = 500,
	PlotUnlockCostMultiplier = 1.85, -- exponential scaling

	-- Growth speed
	BaseGrowthSpeedMultiplier = 1.0,
	AutoHarvesterInterval = 5.0, -- seconds between auto-harvest checks

	-- Grid layout
	GridColumns = 8,
	PlotSize = 6, -- studs
	PlotSpacing = 1, -- studs between plots
}

-- ============================================================
-- ECONOMY
-- ============================================================
Config.Economy = {
	-- Starting currency
	StartingStardust = 100,
	StartingNebulaGems = 0,
	StartingStarlight = 0,

	-- Currency caps (anti-exploit)
	MaxStardust = 1e18, -- 1 quintillion (supports late-game scaling)
	MaxNebulaGems = 1e12,
	MaxStarlight = 1e9,

	-- Sell multiplier (base, before rebirth/pet bonuses)
	BaseSellMultiplier = 1.0,
}

-- ============================================================
-- REBIRTH / PRESTIGE
-- ============================================================
Config.Rebirth = {
	-- Minimum Stardust earned to rebirth
	MinStardustForFirstRebirth = 50_000,

	-- Each rebirth requires exponentially more
	RebirthCostBase = 50_000,
	RebirthCostExponent = 1.65,

	-- Cosmic Multiplier formula: base * (1 + rebirthLevel * scaling)
	CosmicMultiplierBase = 1.0,
	CosmicMultiplierPerLevel = 0.25, -- +25% per rebirth

	-- Constellation points per rebirth
	ConstellationPointsPerRebirth = 3,

	-- Realms unlock at these rebirth levels
	RealmUnlocks = {
		{ Level = 0, Realm = "StarterMeadow" },
		{ Level = 5, Realm = "VoidGarden" },
		{ Level = 15, Realm = "NebulaFields" },
		{ Level = 30, Realm = "QuantumGreenhouse" },
		{ Level = 50, Realm = "CelestialSanctum" },
	},
}

-- ============================================================
-- EXPERIENCE / LEVELING
-- ============================================================
Config.Leveling = {
	-- XP per harvest (base, scales with seed tier)
	BaseXPPerHarvest = 10,

	-- Level-up formula: requiredXP = base * level^exponent
	LevelUpBase = 100,
	LevelUpExponent = 1.45,

	MaxLevel = 500,
}

-- ============================================================
-- ENGAGEMENT
-- ============================================================
Config.Engagement = {
	-- Login streak rewards (Stardust)
	LoginStreakRewards = {
		[1] = 50,
		[2] = 100,
		[3] = 200,
		[4] = 300,
		[5] = 500,
		[6] = 750,
		[7] = 2000, -- Big Day 7 reward
	},

	-- Daily quest reward (NebulaGems)
	DailyQuestGemReward = 25,

	-- Weather event interval (seconds)
	WeatherEventMinInterval = 300, -- 5 minutes
	WeatherEventMaxInterval = 900, -- 15 minutes
	WeatherEventDuration = 60, -- 1 minute of boosted mutation chance

	-- Mutation storm bonus
	WeatherMutationBonus = 2.0, -- 2x mutation chance during storms
}

-- ============================================================
-- PETS
-- ============================================================
Config.Pets = {
	MaxEquipped = 1,
	MaxOwned = 50,

	-- XP to level up: base * level^exponent
	LevelUpBase = 50,
	LevelUpExponent = 1.3,
	MaxLevel = 100,

	-- Pet luck bonus per level
	LuckBonusPerLevel = 0.002, -- +0.2% per level
}

-- ============================================================
-- MONETIZATION (Roblox Product IDs — fill after creating in Studio)
-- ============================================================
Config.Monetization = {
	Gamepasses = {
		StarterPack = { Id = 0, Price = 49, Flag = "HasStarterPack" },
		AutoHarvester = { Id = 0, Price = 499, Flag = "HasAutoHarvester" },
		DoubleLuck = { Id = 0, Price = 899, Flag = "HasDoubleLuck" },
		InstantGrow = { Id = 0, Price = 299, Flag = "HasInstantGrow" },
		VIPGreenhouse = { Id = 0, Price = 699, Flag = "HasVIPGreenhouse" },
		CosmicPass = { Id = 0, Price = 1499, Flag = "HasCosmicPass" },
	},

	DevProducts = {
		StardustPack = { Id = 0, Price = 25, Reward = { Currency = "Stardust", Amount = 5000 } },
		MutationStorm = { Id = 0, Price = 49, Duration = 300 }, -- 5 min storm
		SkipGrowth = { Id = 0, Price = 25 },
		MysterySeedBox = { Id = 0, Price = 99 },
		NebulaGemPack = { Id = 0, Price = 149, Reward = { Currency = "NebulaGems", Amount = 500 } },
		InstantTranscend = { Id = 0, Price = 199 },
	},
}

-- ============================================================
-- ANTI-EXPLOIT
-- ============================================================
Config.Security = {
	-- Maximum operations per second per player (rate limiting)
	MaxHarvestsPerSecond = 5,
	MaxPlantsPerSecond = 3,
	MaxTradesPerMinute = 10,

	-- Sanity check thresholds
	MaxCurrencyGainPerAction = 1e15, -- flag if exceeded
}

return Config
