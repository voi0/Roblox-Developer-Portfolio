--!strict
--[[
	Config.luau — Game constants and balance values for ESCAPE THE PACK
	Asymmetrical Survival / Ankle-Breaking Tag / Infection Arena
	Located in: ReplicatedStorage.Shared.Config
]]

local Config = {}

-- ============================================================
-- ARENA GEOMETRY & ZONES
-- ============================================================
Config.Arena = {
	Length = 240,       -- Z-axis length of the active crossing field
	Width = 80,         -- X-axis width of the arena
	SafeZoneLength = 26, -- Z-axis depth of safe zones on both ends
	WallHeight = 22,    -- Height of perimeter barrier walls
	LobbyHeight = 35,   -- Height of the elevated spectator terrace
	LobbyPosition = Vector3.new(0, 35, -160),
	StartZoneCenter = Vector3.new(0, 1.5, -105),
	FinishZoneCenter = Vector3.new(0, 1.5, 105),
}

-- ============================================================
-- ROUND TIMERS & STRUCTURE
-- ============================================================
Config.Round = {
	MinPlayersToStart = 1,       -- Supports solo testing in Studio!
	IntermissionDuration = 12,   -- Lobby waiting countdown (seconds)
	HeroSelectionDuration = 6,   -- "Hero or Chicken" prompt window (seconds)
	WaveDuration = 35,           -- Max time for runners to cross (seconds)
	InterWaveRest = 4,           -- Rest period between crossing waves (seconds)
	TotalWaves = 3,              -- 3 crossings to win match
	TagDistance = 7.5,           -- Studs within which knife swing tags runner
	ReviveDistance = 6.0,        -- Studs within which teammate can revive
	ReviveHoldTime = 1.8,        -- Seconds to hold [E] to revive
}

-- ============================================================
-- MOVEMENT & JUKING PHYSICS
-- ============================================================
Config.Movement = {
	BaseSpeed = 16,              -- Normal walk speed
	MaxSprintSpeed = 26.5,       -- Peak running speed
	AccelerationRate = 14,       -- Studs/sec^2 build-up speed
	SlideFriction = 0.88,        -- Inertia decay when releasing movement keys
	DashImpulseSpeed = 38,       -- Lateral dash velocity
	DashDuration = 0.22,         -- Seconds dash force is applied
	DashCooldown = 2.4,          -- Seconds before another dash
	AltStopEnabled = true,       -- Alt key instantly zeros linear velocity
	SlideDuration = 0.55,        -- Crouch slide duration
	SlideCooldown = 2.0,
}

-- ============================================================
-- ECONOMY & REWARDS
-- ============================================================
Config.Economy = {
	StartingCoins = 100,
	StartingGems = 10,
	WaveSurvivalCoins = 50,
	MatchWinCoins = 250,
	MatchWinGems = 20,
	HeroSurvivalCoins = 600,
	HeroSurvivalGems = 60,
	ChaserTagCoins = 40,
	TeammateReviveCoins = 50,
	AFKIntervalSeconds = 60,
	AFKCoinsReward = 15,
	AFKGemsReward = 1,
}

-- ============================================================
-- KNIFE SKINS (COSMETIC CRATES)
-- ============================================================
Config.Knives = {
	DefaultDagger = { Id = "DefaultDagger", Name = "Standard Combat Dagger", Rarity = "Common", Cost = 0 },
	RubyStiletto = { Id = "RubyStiletto", Name = "Crimson Stiletto", Rarity = "Rare", Cost = 500 },
	NeonPlasma = { Id = "NeonPlasma", Name = "Cyan Plasma Blade", Rarity = "Epic", Cost = 1200 },
	VoidScythe = { Id = "VoidScythe", Name = "Void Reaper Scythe", Rarity = "Legendary", Cost = 3000 },
	CelestialFang = { Id = "CelestialFang", Name = "Primordial Celestial Fang", Rarity = "Secret", Cost = 10000 },
}

return Config
