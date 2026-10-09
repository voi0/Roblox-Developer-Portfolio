--!strict
--[[
	Types.luau — Central type definitions for VAULT WARS: STEAL & DEFEND TYCOON
	Cyber-Industrial Heist Simulator & Idle Mint Engine
	Located in: ReplicatedStorage.Shared.Types
]]

export type RelicTier = 
	| "Common" 
	| "Rare" 
	| "Epic" 
	| "Legendary" 
	| "Mythic" 
	| "Secret"

export type RelicDefinition = {
	Id: string,
	Name: string,
	Tier: RelicTier,
	BaseMultiplier: number,
	DropWeight: number,
	Color: Color3,
	Material: Enum.Material,
	Broadcast: boolean,
}

export type PlotUpgradeType = "Conveyor" | "Laser" | "Turret" | "VaultInterest"

export type SyndicateContract = {
	Id: string,
	Title: string,
	Description: string,
	TargetCount: number,
	CurrentCount: number,
	RewardCash: number,
	RewardXP: number,
	RewardTokens: number,
	IsCompleted: boolean,
	IsClaimed: boolean,
}

export type PerkBranch = "Infiltrator" | "Enforcer" | "Tycoon"

export type PerkDefinition = {
	Id: string,
	Name: string,
	Branch: PerkBranch,
	Tier: number,
	CostSP: number,
	Description: string,
	RequiredPerkId: string?,
}

export type PlayerData = {
	-- Currencies
	UnbankedCash: number,
	BankedCash: number,
	PrestigeTokens: number,
	PrestigeLevel: number,

	-- Progression & Mastery
	XP: number,
	Level: number,
	SkillPoints: number,
	UnlockedPerks: { [string]: boolean },
	TotalXPAccumulated: number,

	-- Base Upgrades
	PurchasedUpgrades: { [string]: boolean },
	ConveyorLevel: number,
	LaserTier: number,
	TurretTier: number,
	VaultInterestTier: number,
	EquippedVaultSkin: string,
	UnlockedVaultSkins: { [string]: boolean },

	-- Permanent Gamepass Flags
	HasAutoCollector: boolean,
	HasOfflineShield: boolean,
	HasDoubleCapacity: boolean,
	HasTitaniumLasers: boolean,

	-- Relic Stash & Synthesis
	RelicInventory: { [string]: number },

	-- Syndicate Black Market & Contracts
	SyndicateTokens: number,
	Contracts: { [string]: SyndicateContract },
	LastContractsRefresh: number,

	-- Lifetime Stats
	TotalHeistsWon: number,
	TotalHeistsLost: number,
	TotalCashStolen: number,
	HighestSingleHeist: number,
	PlayTimeSeconds: number,
	LastInterestTimestamp: number,
	DailyStreak: number,
	LastDailyClaimTimestamp: number,
	RedeemedCodes: { [string]: boolean },
}

export type StolenItemPayload = {
	Id: string,
	Name: string,
	Tier: RelicTier,
	Value: number,
	SourcePlotIndex: number,
	ThiefUserId: number,
}

export type PlotState = {
	Index: number,
	OwnerUserId: number?,
	IsBreached: boolean,
	BreachEndTime: number,
	UnbankedValue: number,
	ActiveRelicCount: number,
}

return {}
