--!strict
--[[
	EconomyService.luau — Currency & Transaction Manager for STARWEAVE
	Handles all in-experience purchases (Gamepasses + DevProducts),
	currency validation, and the Rebirth system.
	Located in: ServerScriptService.Server.Services.EconomyService

	All monetary operations are server-authoritative.
	MarketplaceService receipts are processed server-side only.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SeedData = require(ReplicatedStorage.Shared.SeedData)

-- Resolved in Init()
local DataService: any = nil
local GardenService: any = nil

-- ============================================================
-- SERVICE
-- ============================================================
local EconomyService = {}
EconomyService._initialized = false

-- ============================================================
-- GAMEPASS PROCESSING
-- ============================================================

function EconomyService.ProcessGamepassPurchase(player: Player, gamepassId: number)
	-- Find which gamepass was purchased
	for passName, passData in Config.Monetization.Gamepasses do
		if passData.Id == gamepassId then
			DataService.SetGamepassFlag(player, passData.Flag, true)
			print(`[EconomyService] {player.Name} purchased Gamepass: {passName}`)

			-- Special handling for Starter Pack
			if passName == "StarterPack" then
				DataService.AddCurrency(player, "Stardust", 2000)
				DataService.AddSeeds(player, "solar_fern", 10)
				DataService.AddSeeds(player, "crystal_vine", 5)
			end

			-- Special handling for Cosmic Pass (grants all lower-tier benefits)
			if passName == "CosmicPass" then
				DataService.SetGamepassFlag(player, "HasAutoHarvester", true)
				DataService.SetGamepassFlag(player, "HasDoubleLuck", true)
				DataService.SetGamepassFlag(player, "HasInstantGrow", true)
				DataService.SetGamepassFlag(player, "HasVIPGreenhouse", true)
			end

			-- Notify client
			local shopEvent = ReplicatedStorage:FindFirstChild("ShopUpdate")
			if shopEvent and shopEvent:IsA("RemoteEvent") then
				shopEvent:FireClient(player, "GamepassPurchased", passName)
			end

			return
		end
	end
end

-- ============================================================
-- DEVELOPER PRODUCT PROCESSING
-- ============================================================

function EconomyService.ProcessDevProductPurchase(player: Player, productId: number): boolean
	for productName, productData in Config.Monetization.DevProducts do
		if productData.Id == productId then
			print(`[EconomyService] {player.Name} purchased DevProduct: {productName}`)

			if productName == "StardustPack" then
				DataService.AddCurrency(player, "Stardust", productData.Reward.Amount)

			elseif productName == "MutationStorm" then
				-- Personal mutation storm (handled by MutationService)
				-- For now, grant NebulaGems as bonus
				DataService.AddCurrency(player, "NebulaGems", 100)

			elseif productName == "SkipGrowth" then
				-- Skip the growth timer on the next plant
				-- Client will need to select which plot to skip
				-- Grant a "skip token" stored in data
				local data = DataService.GetData(player)
				if data then
					-- Find first growing plant and skip it
					for _, plot in data.Garden do
						if plot.Plant and plot.Plant.State == "Growing" then
							GardenService.SkipGrowth(player, plot.Index)
							break
						end
					end
				end

			elseif productName == "MysterySeedBox" then
				-- Roll a random seed from all unlocked seeds
				local data = DataService.GetData(player)
				if data then
					local rebirthLevel = data.Rebirth.Level
					local unlocked = SeedData.GetUnlockedSeeds(rebirthLevel)
					if #unlocked > 0 then
						-- Weight toward rarer seeds
						local weights: { number } = {}
						local totalWeight = 0
						for i, seed in unlocked do
							local tierOrder = SeedData.TierOrder[seed.Tier] or 1
							local weight = tierOrder * tierOrder -- Quadratic weight = rarer seeds more likely
							weights[i] = weight
							totalWeight = totalWeight + weight
						end

						local roll = math.random() * totalWeight
						local accumulated = 0
						for i, weight in weights do
							accumulated = accumulated + weight
							if roll <= accumulated then
								DataService.AddSeeds(player, unlocked[i].Id, 3)

								local shopEvent = ReplicatedStorage:FindFirstChild("ShopUpdate")
								if shopEvent and shopEvent:IsA("RemoteEvent") then
									shopEvent:FireClient(player, "MysterySeedResult", unlocked[i].Id, 3)
								end
								break
							end
						end
					end
				end

			elseif productName == "NebulaGemPack" then
				DataService.AddCurrency(player, "NebulaGems", productData.Reward.Amount)

			elseif productName == "InstantTranscend" then
				EconomyService.PerformRebirth(player, true) -- force rebirth
			end

			return true -- Receipt processed successfully
		end
	end

	return false
end

-- ============================================================
-- REBIRTH SYSTEM
-- ============================================================

--[[
	Perform a rebirth (Transcend).
	
	Requirements:
	- Player has earned enough Stardust this cycle
	
	Effects:
	- Resets: Stardust, Garden (plants cleared), Seed Inventory (keeps base seeds)
	- Keeps: NebulaGems, Starlight, Gamepasses, Pets, Collection Log
	- Gains: +1 Rebirth Level, Cosmic Multiplier increase, Constellation Points
	- Unlocks: New seeds, new realms
]]
function EconomyService.PerformRebirth(player: Player, forced: boolean?): (boolean, string)
	local data = DataService.GetData(player)
	if not data then return false, "Data not loaded." end

	-- Check requirement (unless forced via DevProduct)
	if not forced then
		local requiredStardust = math.floor(
			Config.Rebirth.RebirthCostBase
			* (Config.Rebirth.RebirthCostExponent ^ data.Rebirth.Level)
		)

		if data.TotalStardustEarned < requiredStardust then
			return false, `Need {requiredStardust} total Stardust earned this cycle.`
		end
	end

	-- ===== RESET =====
	-- Currency (keep premium currencies)
	data.Stardust = Config.Economy.StartingStardust

	-- Garden (clear all plants, keep unlocked plots)
	for _, plot in data.Garden do
		plot.Plant = nil
	end

	-- Cancel all growth timers
	if GardenService._growthTimers[player] then
		for plotIndex, thread in GardenService._growthTimers[player] do
			task.cancel(thread)
		end
		GardenService._growthTimers[player] = {}
	end

	-- Seed inventory (reset to starter + bonus based on rebirth level)
	data.SeedInventory = {
		starseed_basic = 5 + (data.Rebirth.Level * 2), -- More seeds each rebirth
	}

	-- Reset progression counters for this cycle
	data.TotalStardustEarned = 0
	data.Level = 1
	data.Experience = 0

	-- ===== GAINS =====
	data.Rebirth.Level = data.Rebirth.Level + 1
	data.Rebirth.TotalRebirths = data.Rebirth.TotalRebirths + 1

	-- Update Cosmic Multiplier
	data.Rebirth.CosmicMultiplier = Config.Rebirth.CosmicMultiplierBase
		+ (data.Rebirth.Level * Config.Rebirth.CosmicMultiplierPerLevel)

	-- Award Constellation Points
	data.Rebirth.ConstellationPoints = data.Rebirth.ConstellationPoints
		+ Config.Rebirth.ConstellationPointsPerRebirth

	-- Award Starlight (prestige currency)
	local starlightReward = 100 * data.Rebirth.Level
	DataService.AddCurrency(player, "Starlight", starlightReward)

	-- Check for new realm unlocks
	for _, realmUnlock in Config.Rebirth.RealmUnlocks do
		if data.Rebirth.Level >= realmUnlock.Level then
			local alreadyUnlocked = false
			for _, realm in data.Rebirth.UnlockedRealms do
				if realm == realmUnlock.Realm then
					alreadyUnlocked = true
					break
				end
			end
			if not alreadyUnlocked then
				table.insert(data.Rebirth.UnlockedRealms, realmUnlock.Realm)
			end
		end
	end

	-- Notify client
	local rebirthEvent = ReplicatedStorage:FindFirstChild("RebirthComplete")
	if rebirthEvent and rebirthEvent:IsA("RemoteEvent") then
		rebirthEvent:FireClient(player, {
			NewLevel = data.Rebirth.Level,
			CosmicMultiplier = data.Rebirth.CosmicMultiplier,
			ConstellationPoints = data.Rebirth.ConstellationPoints,
			StarlightReward = starlightReward,
		})
	end

	print(`[EconomyService] {player.Name} transcended to Rebirth Level {data.Rebirth.Level}!`)
	return true, `Transcended to Level {data.Rebirth.Level}!`
end

-- ============================================================
-- CONSTELLATION TREE (Prestige Upgrades)
-- ============================================================

local CONSTELLATION_UPGRADES = {
	sell_bonus = { MaxLevel = 20, PointCost = 1, Description = "+5% sell value per level" },
	mutation_luck = { MaxLevel = 15, PointCost = 2, Description = "+3% mutation luck per level" },
	growth_speed = { MaxLevel = 10, PointCost = 2, Description = "+5% growth speed per level" },
	plot_discount = { MaxLevel = 10, PointCost = 1, Description = "-5% plot unlock cost per level" },
	xp_bonus = { MaxLevel = 15, PointCost = 1, Description = "+10% XP per level" },
	seed_yield = { MaxLevel = 10, PointCost = 3, Description = "+1 bonus seed per harvest per level" },
	stardust_interest = { MaxLevel = 5, PointCost = 5, Description = "+1% Stardust interest per minute per level" },
}

function EconomyService.UpgradeConstellation(player: Player, upgradeId: string): (boolean, string)
	local data = DataService.GetData(player)
	if not data then return false, "Data not loaded." end

	local upgrade = CONSTELLATION_UPGRADES[upgradeId]
	if not upgrade then return false, "Unknown upgrade." end

	local currentLevel = data.Rebirth.ConstellationTree[upgradeId] or 0
	if currentLevel >= upgrade.MaxLevel then
		return false, "Already max level."
	end

	if data.Rebirth.ConstellationPoints < upgrade.PointCost then
		return false, `Need {upgrade.PointCost} Constellation Points.`
	end

	-- Deduct and upgrade
	data.Rebirth.ConstellationPoints = data.Rebirth.ConstellationPoints - upgrade.PointCost
	data.Rebirth.ConstellationTree[upgradeId] = currentLevel + 1

	return true, `{upgradeId} upgraded to level {currentLevel + 1}!`
end

-- ============================================================
-- LOGIN STREAK REWARDS
-- ============================================================

function EconomyService.ClaimLoginReward(player: Player): (boolean, number)
	local data = DataService.GetData(player)
	if not data then return false, 0 end

	local streak = data.LoginStreak
	local rewardDay = math.min(streak, 7) -- Cycles at 7
	local reward = Config.Engagement.LoginStreakRewards[rewardDay] or 50

	DataService.AddCurrency(player, "Stardust", reward)

	return true, reward
end

-- ============================================================
-- INITIALIZATION
-- ============================================================

function EconomyService.Init()
	if EconomyService._initialized then return end
	EconomyService._initialized = true

	-- Resolve dependencies
	local ServerScriptService = game:GetService("ServerScriptService")
	DataService = require(ServerScriptService.Server.Services.DataService)
	GardenService = require(ServerScriptService.Server.Services.GardenService)

	-- Create remote events
	local shopEvent = Instance.new("RemoteEvent")
	shopEvent.Name = "ShopUpdate"
	shopEvent.Parent = ReplicatedStorage

	local rebirthEvent = Instance.new("RemoteEvent")
	rebirthEvent.Name = "RebirthComplete"
	rebirthEvent.Parent = ReplicatedStorage

	-- Economy request handler
	local economyRequest = Instance.new("RemoteFunction")
	economyRequest.Name = "EconomyRequest"
	economyRequest.Parent = ReplicatedStorage

	economyRequest.OnServerInvoke = function(player: Player, action: string, ...: any): any
		if action == "Rebirth" then
			local success, message = EconomyService.PerformRebirth(player)
			return { Success = success, Message = message }

		elseif action == "UpgradeConstellation" then
			local upgradeId = ...
			local success, message = EconomyService.UpgradeConstellation(player, upgradeId :: string)
			return { Success = success, Message = message }

		elseif action == "ClaimLogin" then
			local success, reward = EconomyService.ClaimLoginReward(player)
			return { Success = success, Reward = reward }
		end

		return { Success = false, Message = "Unknown action." }
	end

	-- ============================================================
	-- MARKETPLACE SERVICE HANDLERS
	-- ============================================================

	-- Gamepass purchase handler
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, purchased)
		if purchased then
			EconomyService.ProcessGamepassPurchase(player, gamepassId)
		end
	end)

	-- DevProduct receipt handler (CRITICAL: Must return Enum.ProductPurchaseDecision)
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Wait for data to load
		local maxWait = 10
		local waited = 0
		while not DataService.IsDataLoaded(player) and waited < maxWait do
			task.wait(0.5)
			waited = waited + 0.5
		end

		if not DataService.IsDataLoaded(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local success = EconomyService.ProcessDevProductPurchase(player, receiptInfo.ProductId)

		if success then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	-- Check gamepasses on join (for returning players)
	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			while not DataService.IsDataLoaded(player) do
				task.wait(0.1)
			end

			for _, passData in Config.Monetization.Gamepasses do
				if passData.Id > 0 then
					local owns = false
					pcall(function()
						owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passData.Id)
					end)
					if owns then
						DataService.SetGamepassFlag(player, passData.Flag, true)
					end
				end
			end
		end)
	end)

	print("[EconomyService] Initialized ✓")
end

return EconomyService
