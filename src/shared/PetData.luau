--!strict
--[[
	PetData.luau — Cosmic Companions Catalog for STARWEAVE
	Defines all celestial pets, their base stats, mutation luck bonuses,
	growth speed multipliers, and cosmetic aura colors.
	Located in: ReplicatedStorage.Shared.PetData
]]

export type PetDefinition = {
	Id: string,
	Name: string,
	Tier: "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Celestial",
	BaseMutationLuck: number, -- additive to mutation chance (e.g. 0.05 = +5%)
	BaseHarvestSpeed: number, -- speed divisor (e.g. 1.15 = 15% faster growth)
	Color: Color3,
	Description: string,
}

local Pets: { [string]: PetDefinition } = {
	["stardust_wisp"] = {
		Id = "stardust_wisp",
		Name = "Stardust Wisp",
		Tier = "Common",
		BaseMutationLuck = 0.03,
		BaseHarvestSpeed = 1.05,
		Color = Color3.fromRGB(250, 204, 21),
		Description = "A tiny floating orb of coalesced stardust. Attracts minor cosmic mutations.",
	},
	["nebula_sprite"] = {
		Id = "nebula_sprite",
		Name = "Nebula Sprite",
		Tier = "Uncommon",
		BaseMutationLuck = 0.06,
		BaseHarvestSpeed = 1.10,
		Color = Color3.fromRGB(56, 189, 248),
		Description = "Breathes ambient nebula mist across garden soil.",
	},
	["solar_phoenix"] = {
		Id = "solar_phoenix",
		Name = "Solar Phoenix",
		Tier = "Rare",
		BaseMutationLuck = 0.12,
		BaseHarvestSpeed = 1.20,
		Color = Color3.fromRGB(251, 146, 60),
		Description = "Reborn from stellar flares. Radiates intense solar warmth to speed growth.",
	},
	["astral_dragon"] = {
		Id = "astral_dragon",
		Name = "Astral Dragon",
		Tier = "Epic",
		BaseMutationLuck = 0.20,
		BaseHarvestSpeed = 1.35,
		Color = Color3.fromRGB(168, 85, 247),
		Description = "A miniature serpentine drake woven from dark matter and violet stars.",
	},
	["celestial_kitsune"] = {
		Id = "celestial_kitsune",
		Name = "Celestial Kitsune",
		Tier = "Legendary",
		BaseMutationLuck = 0.35,
		BaseHarvestSpeed = 1.50,
		Color = Color3.fromRGB(244, 114, 182),
		Description = "Nine tails of pure starlight. Bends spacetime and dramatically increases rare roll probability.",
	},
	["void_pup"] = {
		Id = "void_pup",
		Name = "Void Pup",
		Tier = "Celestial",
		BaseMutationLuck = 0.60,
		BaseHarvestSpeed = 2.00,
		Color = Color3.fromRGB(255, 255, 255),
		Description = "An impossible creature born beyond event horizons. Doubles harvest growth rate.",
	},
}

local PetDataModule = {
	Pets = Pets,
}

function PetDataModule.GetPet(id: string): PetDefinition?
	return Pets[id]
end

function PetDataModule.GetAllPets(): { PetDefinition }
	local list = {}
	for _, pet in Pets do
		table.insert(list, pet)
	end
	return list
end

return PetDataModule
