--!strict
--[[
	RelicData.luau — RNG Mint Catalog for VAULT WARS: STEAL & DEFEND TYCOON
	Defines the 6 discrete Relic tiers dropped onto conveyors.
	Located in: ReplicatedStorage.Shared.RelicData
]]

local Types = require(script.Parent:WaitForChild("Types"))

local RelicData: { [string]: Types.RelicDefinition } = {
	GoldStack = {
		Id = "GoldStack",
		Name = "Gold Ingot Stack",
		Tier = "Common",
		BaseMultiplier = 1.5,
		DropWeight = 7200, -- 72.0%
		Color = Color3.fromRGB(234, 179, 8),
		Material = Enum.Material.SmoothPlastic,
		Broadcast = false,
	},
	EmeraldMatrix = {
		Id = "EmeraldMatrix",
		Name = "Emerald Matrix Core",
		Tier = "Rare",
		BaseMultiplier = 6.0,
		DropWeight = 1950, -- 19.5%
		Color = Color3.fromRGB(16, 185, 129),
		Material = Enum.Material.Neon,
		Broadcast = false,
	},
	RubyArtifact = {
		Id = "RubyArtifact",
		Name = "Ruby Skull Artifact",
		Tier = "Epic",
		BaseMultiplier = 30.0,
		DropWeight = 650, -- 6.5%
		Color = Color3.fromRGB(239, 68, 68),
		Material = Enum.Material.Neon,
		Broadcast = false,
	},
	DiamondSkull = {
		Id = "DiamondSkull",
		Name = "Diamond Chrono Skull",
		Tier = "Legendary",
		BaseMultiplier = 180.0,
		DropWeight = 170, -- 1.7%
		Color = Color3.fromRGB(56, 189, 248),
		Material = Enum.Material.Glass,
		Broadcast = true,
	},
	VoidChronometer = {
		Id = "VoidChronometer",
		Name = "Void Eye Chronometer",
		Tier = "Mythic",
		BaseMultiplier = 1500.0,
		DropWeight = 28, -- 0.28%
		Color = Color3.fromRGB(168, 85, 247),
		Material = Enum.Material.Neon,
		Broadcast = true,
	},
	CelestialCrown = {
		Id = "CelestialCrown",
		Name = "Celestial Archon Crown",
		Tier = "Secret",
		BaseMultiplier = 15000.0,
		DropWeight = 2, -- 0.02% (1 in 5,000)
		Color = Color3.fromRGB(253, 224, 71),
		Material = Enum.Material.Neon,
		Broadcast = true,
	},
}

-- Ordered table for fast RNG cumulative weight selection
local RelicOrder: { Types.RelicDefinition } = {
	RelicData.GoldStack,
	RelicData.EmeraldMatrix,
	RelicData.RubyArtifact,
	RelicData.DiamondSkull,
	RelicData.VoidChronometer,
	RelicData.CelestialCrown,
}

local TotalWeight = 0
for _, def in RelicOrder do
	TotalWeight += def.DropWeight
end

local Module = {
	Catalog = RelicData,
	Order = RelicOrder,
	TotalWeight = TotalWeight,
}

function Module.RollRandomRelic(luckMultiplier: number?): Types.RelicDefinition
	local mult = math.max(1, luckMultiplier or 1)
	-- Weighted random with luck scaling on higher tiers
	local roll = math.random(1, TotalWeight)
	local cumulative = 0

	-- Luck boost slightly shifts weight away from common toward rare+
	if mult > 1 and roll <= (RelicData.GoldStack.DropWeight * 0.4) then
		roll = math.random(RelicData.GoldStack.DropWeight, TotalWeight)
	end

	for _, def in RelicOrder do
		cumulative += def.DropWeight
		if roll <= cumulative then
			return def
		end
	end

	return RelicData.GoldStack
end

return Module
