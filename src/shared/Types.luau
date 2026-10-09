--!strict
--[[
	Types.luau — Central type definitions for ESCAPE THE PACK
	Asymmetrical Survival / Ankle-Breaking Tag / Infection Arena
	Located in: ReplicatedStorage.Shared.Types
]]

export type PlayerRole = "Runner" | "Chaser" | "Spectator"

export type RoundState = 
	| "WaitingForPlayers"
	| "Intermission" 
	| "HeroSelection" 
	| "RoundActive" 
	| "RoundIntermission" 
	| "MatchOver"

export type AbilityId = "Cloak" | "PocketDoor" | "RufusLeash" | "Decoy" | "Adrenaline"

export type AbilityDefinition = {
	Id: AbilityId,
	Name: string,
	Role: "Runner" | "Chaser" | "Universal",
	GemCost: number,
	Cooldown: number,
	Duration: number,
	Description: string,
	Icon: string,
}

export type KnifeDefinition = {
	Id: string,
	Name: string,
	Rarity: "Common" | "Rare" | "Epic" | "Legendary" | "Secret",
	BladeColor: Color3,
	GlowColor: Color3,
}

export type TrailDefinition = {
	Id: string,
	Name: string,
	Rarity: "Common" | "Rare" | "Epic" | "Legendary",
	ColorSequence: ColorSequence,
}

export type PlayerData = {
	Coins: number,
	Gems: number,
	Wins: number,
	Kills: number,
	HeroClutches: number,
	TotalCrossings: number,
	TotalRevives: number,
	EquippedAbility: AbilityId?,
	UnlockedAbilities: { [string]: boolean },
	EquippedKnife: string,
	UnlockedKnives: { [string]: boolean },
	EquippedTrail: string,
	UnlockedTrails: { [string]: boolean },
	RedeemedCodes: { [string]: boolean },
	PlaytimeSeconds: number,
}

local Types = {}
return Types
