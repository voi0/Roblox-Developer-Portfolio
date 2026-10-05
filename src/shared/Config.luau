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
	-- Starting grid size (3x3 = 9 plots, 6 unlocked initially)
	StartingSize = 6,
	MaxSize = 64, -- 8x8 max grid

	-- Plot unlock costs (Stardust) by plot index
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
		StarterPack = {
			Id = 0,
			Price = 49,
			Flag = "HasStarterPack",
			Name = "Starter Pack",
			Description = "5x Solar Ferns, 5x Crystal Vines, +2,000 SD bonus",
			Icon = "SP",
		},
		AutoHarvester = {
			Id = 0,
			Price = 499,
			Flag = "HasAutoHarvester",
			Name = "Auto-Harvester",
			Description = "Automatically harvests crops the exact second they bloom!",
			Icon = "AH",
		},
		DoubleLuck = {
			Id = 0,
			Price = 899,
			Flag = "HasDoubleLuck",
			Name = "2x Cosmic Luck",
			Description = "Permanent 2x multiplier to all rare mutation rolls!",
			Icon = "2X",
		},
		InstantGrow = {
			Id = 0,
			Price = 299,
			Flag = "HasInstantGrow",
			Name = "Fast Metabolism",
			Description = "All plant growth durations reduced by 35% permanently!",
			Icon = "FG",
		},
		VIPGreenhouse = {
			Id = 0,
			Price = 699,
			Flag = "HasVIPGreenhouse",
			Name = "VIP Stargarden",
			Description = "+50% Stardust sell multiplier & exclusive gold chat title",
			Icon = "VIP",
		},
		CosmicPass = {
			Id = 0,
			Price = 1499,
			Flag = "HasCosmicPass",
			Name = "Cosmic All-Access",
			Description = "Unlocks Auto-Harvester, 2x Luck, Fast Grow & VIP Greenhouse all in one!",
			Icon = "ALL",
		},
	},

	DevProducts = {
		StardustPack = {
			Id = 0,
			Price = 25,
			Name = "5,000 Stardust",
			Description = "Instant infusion of cosmic currency",
			Reward = { Currency = "Stardust", Amount = 5000 },
			Icon = "SD",
		},
		MutationStorm = {
			Id = 0,
			Price = 49,
			Name = "Summon Superstorm",
			Description = "Summons a 5-minute 2x Luck Storm for the whole server!",
			Duration = 300,
			Icon = "ST",
		},
		SkipGrowth = {
			Id = 0,
			Price = 25,
			Name = "Instant Bloom",
			Description = "Instantly ripens your current growing crop",
			Icon = "IB",
		},
		MysterySeedBox = {
			Id = 0,
			Price = 99,
			Name = "Mystery Relic Box",
			Description = "Drops 3x guaranteed Rare, Epic, or Celestial seeds!",
			Icon = "MB",
		},
		NebulaGemPack = {
			Id = 0,
			Price = 149,
			Name = "500 Nebula Gems",
			Description = "Premium celestial crystals for rare pet summons & forging",
			Reward = { Currency = "NebulaGems", Amount = 500 },
			Icon = "NG",
		},
		InstantTranscend = {
			Id = 0,
			Price = 199,
			Name = "Instant Transcend",
			Description = "Instantly fulfill Stardust requirement for next Rebirth!",
			Icon = "IT",
		},
	},
}

-- ============================================================
-- DAILY QUESTS
-- ============================================================
Config.Quests = {
	DailyPool = {
		{
			Id = "plant_crops",
			Title = "Celestial Cultivator",
			Description = "Plant {Target} seeds in your sanctuary",
			Target = 15,
			RewardStardust = 2500,
			RewardGems = 25,
		},
		{
			Id = "harvest_mutations",
			Title = "Astral Botanist",
			Description = "Harvest {Target} mutated plants",
			Target = 5,
			RewardStardust = 5000,
			RewardGems = 50,
		},
		{
			Id = "forge_seeds",
			Title = "Transmutation Adept",
			Description = "Combine seeds in the Celestial Forge {Target} time",
			Target = 1,
			RewardStardust = 4000,
			RewardGems = 40,
		},
		{
			Id = "earn_stardust",
			Title = "Stardust Harvester",
			Description = "Earn {Target} Stardust from harvests",
			Target = 10000,
			RewardStardust = 3000,
			RewardGems = 35,
		},
	},
}

-- ============================================================
-- PROMO CODES (For TikTok, Launch & Organic UA)
-- ============================================================
Config.PromoCodes = {
	STARWEAVE = {
		RewardStardust = 2500,
		RewardGems = 50,
		RewardSeeds = { starseed_basic = 10, lunar_sprout = 3 },
	},
	COSMIC = {
		RewardStardust = 5000,
		RewardGems = 100,
		RewardSeeds = { solar_fern = 5 },
	},
	LAUNCH = {
		RewardStardust = 10000,
		RewardGems = 200,
		RewardSeeds = { crystal_vine = 3 },
	},
	VOI0 = {
		RewardStardust = 15000,
		RewardGems = 500,
		RewardSeeds = { nebula_moss = 2 },
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

