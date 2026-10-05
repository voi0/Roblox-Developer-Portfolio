--!strict
--[[
	ObjectiveData.luau — Guided Progression & Milestone Objectives for STARWEAVE
	Ensures players always have a clear, dopamine-rich immediate target on screen.
	Located in: ReplicatedStorage.Shared.ObjectiveData
]]

export type Objective = {
	Id: number,
	Title: string,
	ActionType: "Plant" | "Harvest" | "UnlockPlot" | "BuySeed" | "CollectWell" | "Forge" | "HatchPet" | "ReachLevel" | "ReachStardust" | "HarvestMutation",
	Target: number,
	RewardStardust: number,
	RewardGems: number,
	RewardXP: number,
	Description: string,
}

local ObjectiveData = {}

ObjectiveData.List = {
	{
		Id = 1,
		Title = "Plant 3 Cosmic Seeds",
		ActionType = "Plant",
		Target = 3,
		RewardStardust = 250,
		RewardGems = 5,
		RewardXP = 60,
		Description = "Select a seed and click an empty plot to plant.",
	},
	{
		Id = 2,
		Title = "Harvest 2 Mature Blooms",
		ActionType = "Harvest",
		Target = 2,
		RewardStardust = 350,
		RewardGems = 5,
		RewardXP = 100,
		Description = "Wait for your crops to mature and harvest them.",
	},
	{
		Id = 3,
		Title = "Stock Up: Buy 5 Seeds",
		ActionType = "BuySeed",
		Target = 5,
		RewardStardust = 500,
		RewardGems = 10,
		RewardXP = 120,
		Description = "Open the Shop [B] and purchase 5 seeds.",
	},
	{
		Id = 4,
		Title = "Expand Sanctuary: Unlock Plot #7",
		ActionType = "UnlockPlot",
		Target = 7,
		RewardStardust = 600,
		RewardGems = 15,
		RewardXP = 150,
		Description = "Unlock Plot #7 in your garden.",
	},
	{
		Id = 5,
		Title = "Harvest the Celestial Well",
		ActionType = "CollectWell",
		Target = 1,
		RewardStardust = 400,
		RewardGems = 10,
		RewardXP = 100,
		Description = "Collect accumulated AFK Stardust from the Sanctuary Well.",
	},
	{
		Id = 6,
		Title = "Altar Alchemy: Forge 1 Seed",
		ActionType = "Forge",
		Target = 1,
		RewardStardust = 1000,
		RewardGems = 20,
		RewardXP = 250,
		Description = "Combine 3 matching seeds at the Altar [F] into a higher tier.",
	},
	{
		Id = 7,
		Title = "Hatch a Cosmic Companion",
		ActionType = "HatchPet",
		Target = 1,
		RewardStardust = 1500,
		RewardGems = 30,
		RewardXP = 300,
		Description = "Hatch your first cosmic pet at the Pet Pod [P].",
	},
	{
		Id = 8,
		Title = "Ascend to Level 5",
		ActionType = "ReachLevel",
		Target = 5,
		RewardStardust = 2500,
		RewardGems = 50,
		RewardXP = 400,
		Description = "Earn XP by harvesting crops to reach Level 5.",
	},
	{
		Id = 9,
		Title = "Discover a Rare Mutation",
		ActionType = "HarvestMutation",
		Target = 1,
		RewardStardust = 4000,
		RewardGems = 75,
		RewardXP = 600,
		Description = "Harvest any crop with Sprout, Bloom, Radiant or higher mutation.",
	},
	{
		Id = 10,
		Title = "Amass 15,000 Stardust",
		ActionType = "ReachStardust",
		Target = 15000,
		RewardStardust = 5000,
		RewardGems = 100,
		RewardXP = 1000,
		Description = "Reach 15,000 total Stardust in your cosmic vault.",
	},
} :: { Objective }

function ObjectiveData.GetObjective(id: number): Objective?
	return ObjectiveData.List[id]
end

return ObjectiveData
