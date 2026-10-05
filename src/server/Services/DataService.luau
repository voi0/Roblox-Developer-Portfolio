--!strict
--[[
	DataService.luau — ProfileService wrapper for STARWEAVE
	Handles all player data persistence with crash-safe locking.
	Located in: ServerScriptService.Server.Services.DataService

	CRITICAL: All data mutations go through this service.
	Never modify player data directly — always use DataService methods.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerPackages = ServerScriptService:WaitForChild("ServerPackages", 15)
local ProfileService: any = nil
if ServerPackages then
	ProfileService = require(ServerPackages:WaitForChild("ProfileService", 10) :: ModuleScript)
else
	ProfileService = require(ServerScriptService.ServerPackages.ProfileService)
end

local Config = require(ReplicatedStorage.Shared.Config)

-- ============================================================
-- DATA TEMPLATE (Default values for new players)
-- ============================================================
local DATA_TEMPLATE = {
	-- Currency
	Stardust = Config.Economy.StartingStardust,
	NebulaGems = Config.Economy.StartingNebulaGems,
	Starlight = Config.Economy.StartingStarlight,

	-- Garden (initialized as 3x3 grid of unlocked empty plots)
	Garden = {}, -- populated in _initializeGarden
	GardenSize = Config.Garden.StartingSize,

	-- Inventory
	SeedInventory = {
		starseed_basic = 5, -- Start with 5 basic seeds
	},
	PlantCollection = {},

	-- Pets
	Pets = {},
	EquippedPetIndex = nil :: number?,

	-- Progression
	Rebirth = {
		Level = 0,
		TotalRebirths = 0,
		CosmicMultiplier = 1.0,
		ConstellationPoints = 0,
		ConstellationTree = {},
		UnlockedRealms = { "StarterMeadow" },
	},
	Level = 1,
	Experience = 0,
	TotalHarvests = 0,
	TotalStardustEarned = 0,

	-- Engagement
	LoginStreak = 0,
	LastLoginDate = "",
	DailyQuestsCompleted = {},
	ActiveQuests = {}, -- { [string]: { Id: string, Current: number, Target: number, Completed: boolean, Claimed: boolean } }
	RedeemedCodes = {}, -- { [string]: boolean }
	PlayTimeSeconds = 0,

	-- Monetization flags
	HasAutoHarvester = false,
	HasDoubleLuck = false,
	HasInstantGrow = false,
	HasVIPGreenhouse = false,
	HasCosmicPass = false,
	HasStarterPack = false,
	SubscriptionActive = false,
	SubscriptionExpiry = nil :: number?,

	-- Meta
	DataVersion = 1,
	FirstJoinTimestamp = 0,
}

-- ============================================================
-- PROFILE STORE
-- ============================================================
local PROFILE_STORE_NAME = "StarweavePlayerData_v1"
local BaseProfileStore = ProfileService.GetProfileStore(PROFILE_STORE_NAME, DATA_TEMPLATE)
local ProfileStore = if RunService:IsStudio() then BaseProfileStore.Mock else BaseProfileStore

-- ============================================================
-- SERVICE
-- ============================================================
local DataService = {}
DataService._profiles = {} :: { [Player]: any } -- Player -> Profile mapping
DataService._initialized = false

-- ============================================================
-- PRIVATE HELPERS
-- ============================================================

local function _initializeGarden(data: any)
	-- Create the starting grid if empty
	if #data.Garden == 0 then
		for i = 1, Config.Garden.StartingSize do
			table.insert(data.Garden, {
				Index = i,
				Unlocked = true,
				Plant = nil,
			})
		end
		-- Fill remaining slots up to max as locked
		for i = Config.Garden.StartingSize + 1, Config.Garden.MaxSize do
			table.insert(data.Garden, {
				Index = i,
				Unlocked = false,
				Plant = nil,
			})
		end
	end
end

local function _reconcileData(data: any)
	-- Ensure all template keys exist (handles data migration)
	for key, defaultValue in DATA_TEMPLATE do
		if data[key] == nil then
			data[key] = defaultValue
		end
	end

	-- Reconcile nested tables
	if data.Rebirth then
		for key, defaultValue in DATA_TEMPLATE.Rebirth do
			if data.Rebirth[key] == nil then
				data.Rebirth[key] = defaultValue
			end
		end
	end

	-- Set first join timestamp if not set
	if data.FirstJoinTimestamp == 0 then
		data.FirstJoinTimestamp = os.time()
	end

	-- Reconcile GardenSize based on unlocked plots
	if data.Garden and #data.Garden > 0 then
		local count = 0
		for _, plot in data.Garden do
			if plot.Unlocked then
				count = count + 1
			end
		end
		data.GardenSize = math.max(count, Config.Garden.StartingSize)
	end
end

local function _handleLoginStreak(data: any)
	local today = os.date("%Y-%m-%d") :: string
	local lastLogin = data.LastLoginDate

	if lastLogin == today then
		-- Already logged in today, no change
		return
	end

	-- Check if yesterday
	local yesterday = os.date("%Y-%m-%d", os.time() - 86400) :: string
	if lastLogin == yesterday then
		-- Consecutive login
		data.LoginStreak = math.min(data.LoginStreak + 1, 7)
	else
		-- Streak broken
		data.LoginStreak = 1
	end

	data.LastLoginDate = today
	data.DailyQuestsCompleted = {} -- Reset daily quests
end

-- ============================================================
-- PLAYER LIFECYCLE
-- ============================================================

function DataService.OnPlayerAdded(player: Player)
	local profile: any = nil
	local success, err = pcall(function()
		profile = ProfileStore:LoadProfileAsync(
			"Player_" .. player.UserId,
			"ForceLoad" -- Safe: kicks old sessions if they exist
		)
	end)

	if not success or profile == nil then
		warn(`[DataService] Could not load cloud ProfileStore for {player.Name}: {tostring(err)}. Falling back to Mock store.`)
		pcall(function()
			profile = BaseProfileStore.Mock:LoadProfileAsync("Player_" .. player.UserId, "ForceLoad")
		end)
	end

	if profile == nil then
		warn(`[DataService] Using emergency session data for {player.Name}`)
		local memData = table.clone(DATA_TEMPLATE)
		_initializeGarden(memData)
		DataService._profiles[player] = { Data = memData, Release = function() end }
		local dataReadyEvent = ReplicatedStorage:FindFirstChild("DataReady")
		if dataReadyEvent and dataReadyEvent:IsA("RemoteEvent") then
			dataReadyEvent:FireClient(player, memData)
		end
		return
	end

	-- Profile loaded successfully
	profile:AddUserId(player.UserId) -- GDPR compliance
	profile:Reconcile() -- Fill missing keys from template

	-- Safety: If player left during async load
	if not player:IsDescendantOf(Players) then
		profile:Release()
		return
	end

	-- Additional data initialization
	_reconcileData(profile.Data)
	_initializeGarden(profile.Data)
	_handleLoginStreak(profile.Data)

	-- Listen for profile release (session lock stolen by another server)
	profile:ListenToRelease(function()
		DataService._profiles[player] = nil
		player:Kick("Your data was loaded on another server. Please rejoin.")
	end)

	-- Store profile
	DataService._profiles[player] = profile

	-- Fire client-ready signal
	local dataReadyEvent = ReplicatedStorage:FindFirstChild("DataReady")
	if dataReadyEvent and dataReadyEvent:IsA("RemoteEvent") then
		dataReadyEvent:FireClient(player, profile.Data)
	end
end

function DataService.OnPlayerRemoving(player: Player)
	local profile = DataService._profiles[player]
	if profile then
		profile:Release() -- Safely release session lock
		DataService._profiles[player] = nil
	end
end

-- ============================================================
-- DATA ACCESS API
-- ============================================================

function DataService.GetData(player: Player): any?
	local profile = DataService._profiles[player]
	if profile then
		return profile.Data
	end
	return nil
end

function DataService.IsDataLoaded(player: Player): boolean
	return DataService._profiles[player] ~= nil
end

-- ============================================================
-- DATA REPLICATION & CLIENT SYNC
-- ============================================================

function DataService.SyncClient(player: Player)
	local data = DataService.GetData(player)
	if not data then return end
	local dataReady = ReplicatedStorage:FindFirstChild("DataReady")
	if dataReady and dataReady:IsA("RemoteEvent") then
		dataReady:FireClient(player, data)
	end
end

-- ============================================================
-- CURRENCY OPERATIONS (Server-Authoritative)
-- ============================================================

function DataService.AddCurrency(player: Player, currencyType: string, amount: number): boolean
	local data = DataService.GetData(player)
	if not data then return false end
	if amount <= 0 then return false end

	-- Anti-exploit: sanity check
	if amount > Config.Security.MaxCurrencyGainPerAction then
		warn(`[DataService] Suspicious currency gain for {player.Name}: {amount} {currencyType}`)
		return false
	end

	local maxCap = Config.Economy["Max" .. currencyType]
	if maxCap then
		data[currencyType] = math.min(data[currencyType] + amount, maxCap)
	else
		data[currencyType] = data[currencyType] + amount
	end

	if currencyType == "Stardust" then
		data.TotalStardustEarned = data.TotalStardustEarned + amount
	end

	DataService.SyncClient(player)
	return true
end

function DataService.RemoveCurrency(player: Player, currencyType: string, amount: number): boolean
	local data = DataService.GetData(player)
	if not data then return false end
	if amount <= 0 then return false end

	if data[currencyType] < amount then
		return false -- Insufficient funds
	end

	data[currencyType] = data[currencyType] - amount
	DataService.SyncClient(player)
	return true
end

function DataService.GetCurrency(player: Player, currencyType: string): number
	local data = DataService.GetData(player)
	if not data then return 0 end
	return data[currencyType] or 0
end

-- ============================================================
-- SEED INVENTORY OPERATIONS
-- ============================================================

function DataService.AddSeeds(player: Player, seedId: string, count: number): boolean
	local data = DataService.GetData(player)
	if not data then return false end
	if count <= 0 then return false end

	data.SeedInventory[seedId] = (data.SeedInventory[seedId] or 0) + count
	DataService.SyncClient(player)
	return true
end

function DataService.RemoveSeed(player: Player, seedId: string, count: number): boolean
	local data = DataService.GetData(player)
	if not data then return false end

	local current = data.SeedInventory[seedId] or 0
	if current < count then return false end

	data.SeedInventory[seedId] = current - count
	if data.SeedInventory[seedId] <= 0 then
		data.SeedInventory[seedId] = nil
	end
	DataService.SyncClient(player)
	return true
end

function DataService.GetSeedCount(player: Player, seedId: string): number
	local data = DataService.GetData(player)
	if not data then return 0 end
	return data.SeedInventory[seedId] or 0
end

-- ============================================================
-- GARDEN PLOT OPERATIONS
-- ============================================================

function DataService.GetPlot(player: Player, plotIndex: number): any?
	local data = DataService.GetData(player)
	if not data then return nil end
	return data.Garden[plotIndex]
end

function DataService.SetPlotPlant(player: Player, plotIndex: number, plant: any?)
	local data = DataService.GetData(player)
	if not data then return end

	local plot = data.Garden[plotIndex]
	if plot then
		plot.Plant = plant
		DataService.SyncClient(player)
	end
end

function DataService.UnlockPlot(player: Player, plotIndex: number): boolean
	local data = DataService.GetData(player)
	if not data then return false end

	local plot = data.Garden[plotIndex]
	if not plot then return false end
	if plot.Unlocked then return false end -- Already unlocked

	plot.Unlocked = true
	data.GardenSize = data.GardenSize + 1
	DataService.SyncClient(player)
	return true
end

-- ============================================================
-- PROGRESSION OPERATIONS
-- ============================================================

function DataService.AddExperience(player: Player, amount: number)
	local data = DataService.GetData(player)
	if not data then return end

	data.Experience = data.Experience + amount

	-- Check for level up
	local requiredXP = Config.Leveling.LevelUpBase * (data.Level ^ Config.Leveling.LevelUpExponent)
	while data.Experience >= requiredXP and data.Level < Config.Leveling.MaxLevel do
		data.Experience = data.Experience - requiredXP
		data.Level = data.Level + 1
		requiredXP = Config.Leveling.LevelUpBase * (data.Level ^ Config.Leveling.LevelUpExponent)
	end
	DataService.SyncClient(player)
end

function DataService.IncrementHarvests(player: Player)
	local data = DataService.GetData(player)
	if not data then return end
	data.TotalHarvests = data.TotalHarvests + 1
	DataService.SyncClient(player)
end

function DataService.AddToCollection(player: Player, collectionKey: string): boolean
	local data = DataService.GetData(player)
	if not data then return false end

	if data.PlantCollection[collectionKey] then
		return false -- Already collected
	end

	data.PlantCollection[collectionKey] = true
	DataService.SyncClient(player)
	return true
end

-- ============================================================
-- GAMEPASS FLAG OPERATIONS
-- ============================================================

function DataService.SetGamepassFlag(player: Player, flag: string, value: boolean)
	local data = DataService.GetData(player)
	if not data then return end
	data[flag] = value
	DataService.SyncClient(player)
end

function DataService.HasGamepass(player: Player, flag: string): boolean
	local data = DataService.GetData(player)
	if not data then return false end
	return data[flag] == true
end

-- ============================================================
-- QUEST & PROMO CODE OPERATIONS
-- ============================================================

function DataService.GetActiveQuests(player: Player): any?
	local data = DataService.GetData(player)
	if not data then return nil end
	if not data.ActiveQuests then data.ActiveQuests = {} end
	return data.ActiveQuests
end

function DataService.SetActiveQuests(player: Player, quests: any)
	local data = DataService.GetData(player)
	if not data then return end
	data.ActiveQuests = quests
	DataService.SyncClient(player)
end

function DataService.HasRedeemedCode(player: Player, code: string): boolean
	local data = DataService.GetData(player)
	if not data or not data.RedeemedCodes then return false end
	return data.RedeemedCodes[string.upper(code)] == true
end

function DataService.MarkCodeRedeemed(player: Player, code: string)
	local data = DataService.GetData(player)
	if not data then return end
	if not data.RedeemedCodes then data.RedeemedCodes = {} end
	data.RedeemedCodes[string.upper(code)] = true
	DataService.SyncClient(player)
end

-- ============================================================
-- INITIALIZATION
-- ============================================================

function DataService.Init()
	if DataService._initialized then return end
	DataService._initialized = true

	-- Create DataReady remote event
	local dataReady = Instance.new("RemoteEvent")
	dataReady.Name = "DataReady"
	dataReady.Parent = ReplicatedStorage

	-- Create GetData remote function for reliable client-side bootstrap
	local getData = Instance.new("RemoteFunction")
	getData.Name = "GetData"
	getData.Parent = ReplicatedStorage

	getData.OnServerInvoke = function(clientPlayer: Player)
		local start = os.clock()
		while not DataService.IsDataLoaded(clientPlayer) and (os.clock() - start) < 10 do
			task.wait(0.1)
		end
		return DataService.GetData(clientPlayer)
	end

	-- Connect player lifecycle
	Players.PlayerAdded:Connect(DataService.OnPlayerAdded)
	Players.PlayerRemoving:Connect(DataService.OnPlayerRemoving)

	-- Handle players already in server (Studio edge case)
	for _, player in Players:GetPlayers() do
		task.spawn(DataService.OnPlayerAdded, player)
	end

	-- Graceful shutdown: release all profiles on server close
	game:BindToClose(function()
		for player, profile in DataService._profiles do
			profile:Release()
		end
	end)

	print("[DataService] Initialized ✓")
end

return DataService
