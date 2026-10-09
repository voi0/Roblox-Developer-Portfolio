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

export type PlotUpgradeType = "Conveyor" | "Laser" | "VaultInterest"

export type PlayerData = {
	-- Currencies
	UnbankedCash: number,
	BankedCash: number,
	PrestigeTokens: number,
	PrestigeLevel: number,

	-- Base Upgrades
	ConveyorLevel: number,
	LaserTier: number,
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

	-- Lifetime Stats
	TotalHeistsWon: number,
	TotalHeistsLost: number,
	TotalCashStolen: number,
	HighestSingleHeist: number,
	PlayTimeSeconds: number,
	LastInterestTimestamp: number,
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
