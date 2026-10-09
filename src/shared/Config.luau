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
	StartingBankedCash = 0,
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

-- ============================================================
-- 2. PLOT GEOMETRY & ARENA CONFIG
-- ============================================================
Config.Arena = {
	PlotCount = 6,             -- 6 modular base plots in circular plaza
	PlazaRadius = 60,          -- Studs from center origin to plot entrance
	PlotWidth = 32,            -- Plot X dimension
	PlotLength = 46,           -- Plot Z dimension
	WallHeight = 16,
	MonolithPosition = Vector3.new(0, 0, 0),
	LobbyFloorColor = Color3.fromRGB(15, 17, 26),
}

-- ============================================================
-- 3. MINT CONVEYOR & RELIC CYCLE
-- ============================================================
Config.Mint = {
	DropIntervalSeconds = 5.0,  -- Time between conveyor spawns
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

return Config
