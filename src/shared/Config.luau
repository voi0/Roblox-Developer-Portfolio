--!strict
--[[
	Config.luau — Mathematical Balance Constants for VAULT WARS: STEAL & DEFEND TYCOON
	Controls Conveyor Minting, Upgrade Cost Curves, Heist Drag Physics, and DevEx Monetization.
	Located in: ReplicatedStorage.Shared.Config
]]

local Config = {}

-- ============================================================
-- 1. ECONOMY CONSTANTS & CURVES
-- ============================================================
Config.Economy = {
	StartingBankedCash = 100,
	StartingUnbankedCash = 0,
	BaseMintRate = 5, -- Base $/sec generated at level 1

	-- Upgrades
	MaxConveyorLevel = 50,
	ConveyorBaseCost = 50,
	ConveyorCostExponent = 1.22,
	ConveyorRateExponent = 1.24,

	MaxLaserTier = 4,
	LaserBaseCost = 250,
	LaserCostExponent = 2.40,

	MaxInterestTier = 10,
	InterestBaseCost = 1000,
	InterestCostExponent = 2.20,

	MaxTurretTier = 4,
	TurretBaseCost = 500,
	TurretCostExponent = 2.50,

	-- Prestige (Vault Liquidation)
	PrestigeMinBanked = 10_000_000, -- $10 Million to unlock first liquidation
	PrestigeTokenBase = 10,
	PrestigeExponent = 0.38,
	PrestigeMultiplierPerToken = 0.25, -- +25% permanent income per token
}

-- Calculate upgrade costs with precision
function Config.Economy.GetConveyorCost(level: number): number
	return math.floor(Config.Economy.ConveyorBaseCost * (Config.Economy.ConveyorCostExponent ^ (level - 1)))
end

function Config.Economy.GetConveyorIncome(level: number, prestigeTokens: number): number
	local base = Config.Economy.BaseMintRate * (Config.Economy.ConveyorRateExponent ^ (level - 1))
	local prestigeMult = 1 + (prestigeTokens * Config.Economy.PrestigeMultiplierPerToken)
	return math.floor(base * prestigeMult)
end

function Config.Economy.GetLaserCost(tier: number): number
	return math.floor(Config.Economy.LaserBaseCost * (Config.Economy.LaserCostExponent ^ (tier - 1)))
end

function Config.Economy.GetInterestCost(tier: number): number
	return math.floor(Config.Economy.InterestBaseCost * (Config.Economy.InterestCostExponent ^ (tier - 1)))
end

function Config.Economy.GetTurretCost(tier: number): number
	return math.floor(Config.Economy.TurretBaseCost * (Config.Economy.TurretCostExponent ^ (tier - 1)))
end

-- ============================================================
-- 2. PLOT GEOMETRY & ARENA CONFIG
-- ============================================================
Config.Arena = {
	PlotCount = 6,             -- 6 modular base plots in circular plaza
	PlazaRadius = 60,          -- Studs from center origin to plot entrance
	PlotWidth = 32,            -- Plot X dimension
	PlotLength = 46,           -- Plot Z dimension
	WallHeight = 18,           -- Increased ceiling clearance for smooth camera navigation
	MonolithPosition = Vector3.new(0, 0, 0),
	LobbyFloorColor = Color3.fromRGB(51, 65, 85),
}

-- ============================================================
-- 3. MINT CONVEYOR & RELIC CYCLE
-- ============================================================
Config.Mint = {
	DropIntervalSeconds = 3.5,  -- Time between conveyor spawns
	ConveyorLength = 18,
	ConveyorSpeed = 3.5,        -- Studs per second item travels down conveyor
	MaxUnbankedItemsPerPlot = 6, -- Capacity cap before conveyor stalls
	RelicRNGChance = 0.35,      -- 35% chance to drop a Relic instead of Cash Stack
}

-- ============================================================
-- 4. HEIST & SECURITY MECHANICS
-- ============================================================
Config.Heist = {
	NormalWalkSpeed = 16.0,
	CarryDebuffSpeed = 11.5,     -- Speed penalty when carrying stolen loot
	AdrenalineBoostSpeed = 26.5, -- Speed with Adrenaline DevProduct active
	AdrenalineDuration = 60.0,   -- Seconds adrenaline boost lasts
	BreachAlarmDuration = 14.0,  -- Seconds sirens blare when base is infiltrated
	DepositInteractionDistance = 8.0,

	-- Laser Tripwire damage per second
	LaserDamageByTier = {
		[1] = 20, -- Static beam
		[2] = 40, -- Moving sweep
		[3] = 65, -- Shock pulse
		[4] = 95, -- Titanium incinerator
	},
	LaserKnockbackSpeed = 32.0,
}

-- ============================================================
-- 5. MONETIZATION IDENTIFIERS (ROBUX LADDER)
-- ============================================================
Config.Monetization = {
	DevProducts = {
		AdrenalineSurge = { Id = 0, Robux = 25, Name = "Adrenaline Heist Surge" },
		InstantRelicMagnet = { Id = 0, Robux = 75, Name = "Instant Relic Surge" },
	},
	Gamepasses = {
		DoubleCapacity = { Id = 0, Robux = 199, Name = "Double Stash Capacity" },
		PlatinumVault = { Id = 0, Robux = 349, Name = "Platinum Vault Door" },
		TitaniumLasers = { Id = 0, Robux = 499, Name = "Titanium Laser Defense" },
		AutoDroneAndShield = { Id = 0, Robux = 799, Name = "Auto-Collector Drone & Shield" },
	},
}

-- ============================================================
-- 6. CENTRAL PLAZA GOLDEN AIRDROP EVENT
-- ============================================================
Config.Airdrop = {
	IntervalSeconds = 480,       -- Event triggers every 8 minutes
	DropAltitude = 90,           -- Studs above center monolith
	DescentDuration = 12.0,      -- Seconds crate glides down
	ChannelDurationSeconds = 3.5, -- Hold duration required to crack crate
	JackpotCash = 250000,        -- Cash prize
}

-- ============================================================
-- 7. TACTICAL TOOLS & ARSENAL
-- ============================================================
Config.Tools = {
	StunBaton = {
		Range = 9.0,
		Damage = 20,
		KnockbackSpeed = 38.0,
		CooldownSeconds = 2.5,
	},
	EMPJammer = {
		Range = 22.0,
		DisableDurationSeconds = 6.0,
		CooldownSeconds = 25.0,
	},
}

-- ============================================================
-- 8. 7-DAY DAILY RETENTION LADDER
-- ============================================================
Config.DailyRewards = {
	[1] = { Cash = 10000,   RelicId = nil,               Tokens = 0,  Label = "Day 1: $10,000 Cash" },
	[2] = { Cash = 25000,   RelicId = "EmeraldMatrix",   Tokens = 0,  Label = "Day 2: 1x Rare Emerald Matrix" },
	[3] = { Cash = 50000,   RelicId = "RubyArtifact",    Tokens = 2,  Label = "Day 3: $50K + 1x Epic Ruby Skull" },
	[4] = { Cash = 100000,  RelicId = nil,               Tokens = 5,  Label = "Day 4: $100K + 5 Prestige Tokens" },
	[5] = { Cash = 250000,  RelicId = "DiamondSkull",    Tokens = 8,  Label = "Day 5: 1x Legendary Diamond Skull" },
	[6] = { Cash = 500000,  RelicId = nil,               Tokens = 15, Label = "Day 6: $500K + 15 Prestige Tokens" },
	[7] = { Cash = 1000000, RelicId = "VoidChronometer", Tokens = 25, Label = "Day 7: $1M + 1x Mythic Void Eye!" },
}

-- ============================================================
-- 8.5. BASE DEFENSE TURRETS & AI TARGETING
-- ============================================================
Config.Turret = {
	ScanRadius = 38.0,
	FireInterval = 0.25, -- Seconds between burst shots
	DamagePerHit = 3.0,  -- 12 damage/sec base
	LockOnDuration = 1.0, -- Seconds required to lock on before opening fire
	MaxTier = 4,
	TierSpecs = {
		[1] = { Damage = 2.5, FireInterval = 0.35, Range = 32.0, Name = "Sentry Minigun" },
		[2] = { Damage = 3.5, FireInterval = 0.25, Range = 38.0, Name = "Twin Vulcan" },
		[3] = { Damage = 5.0, FireInterval = 0.20, Range = 44.0, Name = "Laser Gatling" },
		[4] = { Damage = 7.5, FireInterval = 0.15, Range = 50.0, Name = "Plasma Rail-Turret" },
	},
	EMPDisableDuration = 8.0, -- Seconds deactivated when hit by EMP Jammer
}

-- ============================================================
-- 8.6. SYNDICATE BLACK MARKET DAILY CONTRACTS
-- ============================================================
Config.Contracts = {
	RefreshIntervalSeconds = 86400, -- 24 hours
	Templates = {
		{
			Id = "StealRelics",
			Title = "Operation Ghost Infiltration",
			Description = "Infiltrate rival vaults and snatch 3 relics or bullion.",
			TargetCount = 3,
			RewardCash = 15000,
			RewardXP = 200,
			RewardTokens = 3,
		},
		{
			Id = "TackleThieves",
			Title = "Operation Grid Enforcer",
			Description = "Neutralize 2 intruder thieves using the Stun Baton.",
			TargetCount = 2,
			RewardCash = 20000,
			RewardXP = 250,
			RewardTokens = 4,
		},
		{
			Id = "BankBullion",
			Title = "Operation Bullion Rush",
			Description = "Deposit $25,000 worth of minted or stolen loot.",
			TargetCount = 25000,
			RewardCash = 25000,
			RewardXP = 300,
			RewardTokens = 5,
		},
		{
			Id = "SynthesizeRelic",
			Title = "Operation Alchemical Matrix",
			Description = "Synthesize 1 relic at the Central Plaza Fusion Altar.",
			TargetCount = 1,
			RewardCash = 30000,
			RewardXP = 350,
			RewardTokens = 5,
		},
	},
}

-- ============================================================
-- 9. ADMIN & DEV CREATOR WHITELIST
-- ============================================================
Config.Admin = {
	CreatorUsername = "intradient",
}

-- ============================================================
-- 10. PROGRESSION ENGINE, HEIST RANKS & 3-BRANCH SKILL TREE
-- ============================================================
Config.Progression = {
	MaxLevel = 100,
	BaseXP = 100,
	XPExponent = 1.45,
	SkillPointsPerLevel = 1,

	-- XP Award Values for active gameplay actions
	XPAwards = {
		MintItem = 10,
		SnatchLoot = 75,
		DepositStolenLoot = 150,
		TackleThief = 125,
		FuseRelic = 200,
		AirdropCracked = 500,
		DailyClaim = 250,
	},

	-- Heist Prestige Ranks
	Ranks = {
		{ MinLevel = 1,   Title = "Rookie Burglar",      Color = Color3.fromRGB(148, 163, 184) },
		{ MinLevel = 5,   Title = "Street Infiltrator",  Color = Color3.fromRGB(56, 189, 248) },
		{ MinLevel = 15,  Title = "Shadow Operative",    Color = Color3.fromRGB(168, 85, 247) },
		{ MinLevel = 30,  Title = "Vault Phantom",       Color = Color3.fromRGB(236, 72, 153) },
		{ MinLevel = 50,  Title = "Syndicate Underboss", Color = Color3.fromRGB(245, 158, 11) },
		{ MinLevel = 75,  Title = "Apex Kingpin",        Color = Color3.fromRGB(239, 68, 68) },
		{ MinLevel = 100, Title = "Vault Sovereign",     Color = Color3.fromRGB(250, 204, 21) },
	},

	-- 3-Branch Specialization Skill Tree
	Perks = {
		-- INFILTRATOR BRANCH (Stealth, Mobility & Evasion)
		LightfootProtocol = {
			Id = "LightfootProtocol",
			Name = "Lightfoot Protocol",
			Branch = "Infiltrator",
			Tier = 1,
			CostSP = 1,
			RequiredPerkId = nil,
			Description = "+20% Base Sprint Speed & -50% Loot Carrying Weight Debuff.",
		},
		SilentProwler = {
			Id = "SilentProwler",
			Name = "Silent Prowler",
			Branch = "Infiltrator",
			Tier = 2,
			CostSP = 2,
			RequiredPerkId = "LightfootProtocol",
			Description = "Laser Tripwire Detection Range reduced by 35% & Silent Footsteps.",
		},
		OverclockedEMP = {
			Id = "OverclockedEMP",
			Name = "Overclocked EMP",
			Branch = "Infiltrator",
			Tier = 3,
			CostSP = 3,
			RequiredPerkId = "SilentProwler",
			Description = "EMP Jammer Cooldown reduced by 6s & Jam Duration extended by +2.5s.",
		},
		PhantomDash = {
			Id = "PhantomDash",
			Name = "Phantom Dash (CAPSTONE)",
			Branch = "Infiltrator",
			Tier = 4,
			CostSP = 5,
			RequiredPerkId = "OverclockedEMP",
			Description = "Double-Tap Shift / [Q] to dash forward 24 studs with 1.2s laser immunity [12s CD].",
		},

		-- ENFORCER BRANCH (Combat, Base Defense & Bounty)
		HeavySwing = {
			Id = "HeavySwing",
			Name = "Heavy Swing",
			Branch = "Enforcer",
			Tier = 1,
			CostSP = 1,
			RequiredPerkId = nil,
			Description = "+50% Stun Baton Knockback Force & Stun Duration increased to 4.0s.",
		},
		HardenedCarapace = {
			Id = "HardenedCarapace",
			Name = "Hardened Carapace",
			Branch = "Enforcer",
			Tier = 2,
			CostSP = 2,
			RequiredPerkId = "HeavySwing",
			Description = "-40% Damage taken from Enemy Lasers & Batons; Immune to Tackle knockdown.",
		},
		BountyHunter = {
			Id = "BountyHunter",
			Name = "Bounty Hunter",
			Branch = "Enforcer",
			Tier = 3,
			CostSP = 3,
			RequiredPerkId = "HardenedCarapace",
			Description = "Earn 2x Cash Bounty ($1,000) and +150 bonus XP when neutralizing intruders in your plot.",
		},
		ShockwaveSlam = {
			Id = "ShockwaveSlam",
			Name = "Shockwave Slam (CAPSTONE)",
			Branch = "Enforcer",
			Tier = 4,
			CostSP = 5,
			RequiredPerkId = "BountyHunter",
			Description = "Press [R] with Baton to slam ground, emitting EMP shockwave knocking back all intruders in 18 studs.",
		},

		-- TYCOON BRANCH (Economy, Automation & Relic Mastery)
		OverchargedPress = {
			Id = "OverchargedPress",
			Name = "Overcharged Press",
			Branch = "Tycoon",
			Tier = 1,
			CostSP = 1,
			RequiredPerkId = nil,
			Description = "Conveyor Mint Stamping Speed increased by +35%; faster bullion generation cycle.",
		},
		MidasTouch = {
			Id = "MidasTouch",
			Name = "Midas Touch",
			Branch = "Tycoon",
			Tier = 2,
			CostSP = 2,
			RequiredPerkId = "OverchargedPress",
			Description = "+20% Chance for Mint to drop Pure Gold Bullion (Value Multiplier 1.5x).",
		},
		CompoundingTreasury = {
			Id = "CompoundingTreasury",
			Name = "Compounding Treasury",
			Branch = "Tycoon",
			Tier = 3,
			CostSP = 3,
			RequiredPerkId = "MidasTouch",
			Description = "Vault Interest Rate increased from 2.5% to 4.5% every 60s; Stash Capacity +50%.",
		},
		AlchemicalResonance = {
			Id = "AlchemicalResonance",
			Name = "Alchemical Resonance (CAPSTONE)",
			Branch = "Tycoon",
			Tier = 4,
			CostSP = 5,
			RequiredPerkId = "CompoundingTreasury",
			Description = "Relic Fusion Altar success rate +15% & Supercharged Mutation chance doubled to 40%.",
		},
	},
}

function Config.Progression.GetXPRequiredForLevel(level: number): number
	if level >= Config.Progression.MaxLevel then return 999_999_999 end
	return math.floor(Config.Progression.BaseXP * (level ^ Config.Progression.XPExponent))
end

function Config.Progression.GetRankForLevel(level: number): { Title: string, Color: Color3 }
	local currentRank = Config.Progression.Ranks[1]
	for _, rank in Config.Progression.Ranks do
		if level >= rank.MinLevel then
			currentRank = rank
		end
	end
	return currentRank
end

return Config
