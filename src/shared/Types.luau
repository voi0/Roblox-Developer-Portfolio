--!strict
--[[
	Types.luau — Central type definitions for STARWEAVE
	All game objects are strictly typed for safety and autocompletion.
	Located in: ReplicatedStorage.Shared.Types
]]

export type SeedTier = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Celestial" | "Void"

export type MutationTier = "None" | "Sprout" | "Bloom" | "Radiant" | "Astral" | "Celestial" | "Primordial"

export type CurrencyType = "Stardust" | "NebulaGems" | "Starlight"

export type PlotState = "Empty" | "Planted" | "Growing" | "Ready" | "Mutating"

export type SeedDefinition = {
	Id: string,
	Name: string,
	Tier: SeedTier,
	BaseValue: number,
	GrowthTime: number, -- seconds
	BaseMutationChance: number, -- 0.0 to 1.0
	UnlockRebirth: number, -- minimum rebirth level to unlock
	Description: string,
}

export type MutationDefinition = {
	Tier: MutationTier,
	MinMultiplier: number,
	MaxMultiplier: number,
	Chance: number, -- base probability 0.0 to 1.0
	ParticleColor: { R: number, G: number, B: number },
	DisplayName: string,
}

export type PlantInstance = {
	PlotIndex: number,
	SeedId: string,
	State: PlotState,
	PlantedAt: number, -- os.time() timestamp
	GrowthEndAt: number, -- os.time() timestamp
	MutationTier: MutationTier,
	MutationMultiplier: number,
	IsAutoHarvested: boolean,
}

export type GardenPlot = {
	Index: number,
	Unlocked: boolean,
	Plant: PlantInstance?,
}

export type PetInstance = {
	Id: string,
	Name: string,
	Tier: SeedTier,
	MutationLuckBonus: number, -- additive bonus to mutation chance
	HarvestSpeedBonus: number, -- multiplier on growth speed (1.0 = no bonus)
	Level: number,
	Experience: number,
}

export type RebirthData = {
	Level: number,
	TotalRebirths: number,
	CosmicMultiplier: number, -- permanent multiplier to all earnings
	ConstellationPoints: number, -- spendable prestige currency
	ConstellationTree: { [string]: number }, -- upgrade_id -> level
	UnlockedRealms: { string },
}

export type PlayerData = {
	-- Currency
	Stardust: number,
	NebulaGems: number,
	Starlight: number,

	-- Garden
	Garden: { GardenPlot },
	GardenSize: number, -- total unlocked plots (starts at 9 = 3x3)

	-- Inventory
	SeedInventory: { [string]: number }, -- seed_id -> count
	PlantCollection: { [string]: boolean }, -- mutation_id -> collected (for collection log)

	-- Pets
	Pets: { PetInstance },
	EquippedPetIndex: number?, -- index into Pets array

	-- Progression
	Rebirth: RebirthData,
	Level: number,
	Experience: number,
	TotalHarvests: number,
	TotalStardustEarned: number,

	-- Engagement
	LoginStreak: number,
	LastLoginDate: string, -- YYYY-MM-DD
	DailyQuestsCompleted: { [string]: boolean },
	PlayTimeSeconds: number,

	-- Monetization
	HasAutoHarvester: boolean,
	HasDoubleLuck: boolean,
	HasInstantGrow: boolean,
	HasVIPGreenhouse: boolean,
	HasCosmicPass: boolean,
	HasStarterPack: boolean,
	SubscriptionActive: boolean,
	SubscriptionExpiry: number?, -- os.time() timestamp

	-- Meta
	DataVersion: number,
	FirstJoinTimestamp: number,
}

export type TransactionResult = {
	Success: boolean,
	Message: string,
	NewBalance: number?,
}

export type HarvestResult = {
	Success: boolean,
	SeedId: string,
	MutationTier: MutationTier,
	MutationMultiplier: number,
	BaseValue: number,
	FinalValue: number,
	IsNewCollection: boolean,
}

export type MutationRollResult = {
	Tier: MutationTier,
	Multiplier: number,
	IsRare: boolean, -- Astral or above
}

return nil
