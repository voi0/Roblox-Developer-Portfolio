--!strict
--[[
	AbilityData.luau — Tactical ability catalog for ESCAPE THE PACK
	Located in: ReplicatedStorage.Shared.AbilityData
]]

local Types = require(script.Parent:WaitForChild("Types"))

local AbilityData: { [Types.AbilityId]: Types.AbilityDefinition } = {
	Cloak = {
		Id = "Cloak",
		Name = "Invisibility Cloak",
		Role = "Runner",
		GemCost = 1000,
		Cooldown = 18.0,
		Duration = 3.0,
		Description = "Become completely invisible for 3 seconds to break the Chaser's line of sight.",
		Icon = "rbxassetid://10709790387",
	},
	PocketDoor = {
		Id = "PocketDoor",
		Name = "Pocket Barricade",
		Role = "Runner",
		GemCost = 400,
		Cooldown = 22.0,
		Duration = 6.0,
		Description = "Slam a solid wooden barricade door behind you that blocks Chasers for 6 seconds.",
		Icon = "rbxassetid://10709790537",
	},
	Decoy = {
		Id = "Decoy",
		Name = "Holographic Decoy",
		Role = "Runner",
		GemCost = 600,
		Cooldown = 15.0,
		Duration = 4.0,
		Description = "Project a sprint clone of yourself forward to bait the Chaser's attack.",
		Icon = "rbxassetid://10709790226",
	},
	RufusLeash = {
		Id = "RufusLeash",
		Name = "Rufus's Spectral Leash",
		Role = "Chaser",
		GemCost = 1200,
		Cooldown = 16.0,
		Duration = 0.5,
		Description = "Throw a spectral hook forward up to 25 studs that yanks the nearest Runner 8 studs closer.",
		Icon = "rbxassetid://10709790158",
	},
	Adrenaline = {
		Id = "Adrenaline",
		Name = "Adrenaline Surge",
		Role = "Universal",
		GemCost = 250,
		Cooldown = 20.0,
		Duration = 4.0,
		Description = "Inject high-octane speed (+35% WalkSpeed) with instant max acceleration.",
		Icon = "rbxassetid://10709790453",
	},
}

return AbilityData
