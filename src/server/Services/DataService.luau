--!strict
--[[
	DataService.luau — ProfileService wrapper for VAULT WARS: STEAL & DEFEND TYCOON
	Provides crash-safe session-locked persistence for Banked Net Worth,
	Unbanked Stash, Conveyor/Laser Tiers, and Prestige Multipliers.
	Located in: ServerScriptService.Server.Services.DataService
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

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local DATA_TEMPLATE: Types.PlayerData = {
	UnbankedCash = Config.Economy.StartingUnbankedCash,
	BankedCash = Config.Economy.StartingBankedCash,
	PrestigeTokens = 0,
	PrestigeLevel = 0,

	ConveyorLevel = 1,
	LaserTier = 1,
	VaultInterestTier = 1,
	EquippedVaultSkin = "DefaultIron",
	UnlockedVaultSkins = { DefaultIron = true },

	HasAutoCollector = false,
	HasOfflineShield = false,
	HasDoubleCapacity = false,
	HasTitaniumLasers = false,

	TotalHeistsWon = 0,
	TotalHeistsLost = 0,
	TotalCashStolen = 0,
	HighestSingleHeist = 0,
	PlayTimeSeconds = 0,
	LastInterestTimestamp = os.time(),
	RedeemedCodes = {},
	RelicInventory = {},
}

local BaseProfileStore = ProfileService.GetProfileStore(
	"VaultWars_v1",
	DATA_TEMPLATE
)

local ProfileStore = (RunService:IsStudio() and BaseProfileStore.Mock) or BaseProfileStore

local DataService = {}
DataService._profiles = {} :: { [Player]: any }

-- Reconcile template keys
local function reconcileData(data: any)
	for key, defaultValue in DATA_TEMPLATE do
		if data[key] == nil then
			if type(defaultValue) == "table" then
				data[key] = table.clone(defaultValue)
			else
				data[key] = defaultValue
			end
		end
	end
end

-- ============================================================
-- LIFECYCLE HOOKS
-- ============================================================
function DataService.OnPlayerAdded(player: Player)
	local profile: any = nil
	local success, err = pcall(function()
		profile = ProfileStore:LoadProfileAsync(
			"Player_" .. player.UserId,
			"ForceLoad"
		)
	end)

	if not success or profile == nil then
		warn(`[DataService] Using mock store for {player.Name}: {tostring(err)}`)
		pcall(function()
			profile = BaseProfileStore.Mock:LoadProfileAsync("Player_" .. player.UserId, "ForceLoad")
		end)
	end

	if profile == nil then
		warn(`[DataService] Emergency memory fallback for {player.Name}`)
		local memData = table.clone(DATA_TEMPLATE)
		DataService._profiles[player] = { Data = memData, Release = function() end }
		local readyEvt = ReplicatedStorage:FindFirstChild("DataReady") :: RemoteEvent?
		if readyEvt then readyEvt:FireClient(player, memData) end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	if not player:IsDescendantOf(Players) then
		profile:Release()
		return
	end

	reconcileData(profile.Data)

	profile:ListenToRelease(function()
		DataService._profiles[player] = nil
		player:Kick("Your Vault Wars profile was loaded in another server. Please rejoin.")
	end)

	-- Calculate Offline Compound Interest
	local now = os.time()
	local lastTime = profile.Data.LastInterestTimestamp or now
	local timeElapsed = math.max(0, now - lastTime)
	profile.Data.LastInterestTimestamp = now

	if timeElapsed > 60 and profile.Data.BankedCash > 0 then
		local tier = profile.Data.VaultInterestTier or 1
		local ratePerHour = tier * 0.02 -- 2% to 20% per hour
		local hours = math.min(24, timeElapsed / 3600)
		local interestEarned = math.floor(profile.Data.BankedCash * (ratePerHour * hours))
		if interestEarned > 0 then
			profile.Data.BankedCash += interestEarned
			print(`  [DataService] {player.Name} earned +${interestEarned} in offline compound interest!`)
		end
	end

	DataService._profiles[player] = profile

	local readyEvt = ReplicatedStorage:FindFirstChild("DataReady") :: RemoteEvent?
	if readyEvt then
		readyEvt:FireClient(player, profile.Data)
	end

	print(`  [DataService] Profile active for {player.Name} (Banked: ${profile.Data.BankedCash}, Unbanked: ${profile.Data.UnbankedCash})`)
end

function DataService.OnPlayerRemoving(player: Player)
	local profile = DataService._profiles[player]
	if profile then
		profile:Release()
		DataService._profiles[player] = nil
		print(`  [DataService] Saved & released profile for {player.Name}`)
	end
end

-- ============================================================
-- GETTERS & SYNC
-- ============================================================
function DataService.GetData(player: Player): Types.PlayerData?
	local profile = DataService._profiles[player]
	return profile and profile.Data or nil
end

function DataService.SyncClient(player: Player)
	local data = DataService.GetData(player)
	if not data then return end

	local updateEvt = ReplicatedStorage:FindFirstChild("DataUpdate") :: RemoteEvent?
	if updateEvt then
		updateEvt:FireClient(player, data)
	end
end

-- ============================================================
-- VAULT & HEIST ECONOMY TRANSACTIONS
-- ============================================================
function DataService.AddUnbanked(player: Player, amount: number): number
	if amount <= 0 then return 0 end
	local data = DataService.GetData(player)
	if not data then return 0 end

	data.UnbankedCash = (data.UnbankedCash or 0) + math.floor(amount)
	DataService.SyncClient(player)
	return data.UnbankedCash
end

function DataService.DeductUnbanked(player: Player, amount: number): number
	if amount <= 0 then return 0 end
	local data = DataService.GetData(player)
	if not data then return 0 end

	local deduction = amount
	if data.HasOfflineShield then
		deduction = math.floor(amount * 0.5)
	end

	local actual = math.min(data.UnbankedCash, math.floor(deduction))
	data.UnbankedCash -= actual
	data.TotalHeistsLost += 1
	DataService.SyncClient(player)
	return actual
end

function DataService.BankAll(player: Player): number
	local data = DataService.GetData(player)
	if not data then return 0 end

	local amount = data.UnbankedCash
	if amount <= 0 then return 0 end

	data.BankedCash = (data.BankedCash or 0) + amount
	data.UnbankedCash = 0
	DataService.SyncClient(player)
	return amount
end

function DataService.AddBanked(player: Player, amount: number): number
	if amount <= 0 then return 0 end
	local data = DataService.GetData(player)
	if not data then return 0 end

	data.BankedCash = (data.BankedCash or 0) + math.floor(amount)
	DataService.SyncClient(player)
	return data.BankedCash
end

function DataService.SpendBanked(player: Player, amount: number): boolean
	if amount <= 0 then return true end
	local data = DataService.GetData(player)
	if not data then return false end
	if (data.BankedCash or 0) < amount then return false end

	data.BankedCash -= math.floor(amount)
	DataService.SyncClient(player)
	return true
end

function DataService.RecordSuccessfulHeist(thief: Player, amount: number)
	local data = DataService.GetData(thief)
	if not data then return end

	data.BankedCash = (data.BankedCash or 0) + math.floor(amount)
	data.TotalHeistsWon += 1
	data.TotalCashStolen = (data.TotalCashStolen or 0) + math.floor(amount)
	if amount > (data.HighestSingleHeist or 0) then
		data.HighestSingleHeist = math.floor(amount)
	end
	DataService.SyncClient(thief)
end

-- ============================================================
-- RELIC INVENTORY STASH
-- ============================================================
function DataService.AddRelic(player: Player, relicId: string, count: number?): number
	local data = DataService.GetData(player)
	if not data then return 0 end

	if not data.RelicInventory then
		data.RelicInventory = {}
	end

	local addCount = count or 1
	data.RelicInventory[relicId] = (data.RelicInventory[relicId] or 0) + addCount
	DataService.SyncClient(player)
	return data.RelicInventory[relicId]
end

function DataService.RemoveRelic(player: Player, relicId: string, count: number?): boolean
	local data = DataService.GetData(player)
	if not data or not data.RelicInventory then return false end

	local toRemove = count or 1
	local current = data.RelicInventory[relicId] or 0
	if current < toRemove then return false end

	data.RelicInventory[relicId] = current - toRemove
	DataService.SyncClient(player)
	return true
end

-- ============================================================
-- BASE UPGRADES
-- ============================================================
function DataService.Upgrade(player: Player, upgradeType: string): (boolean, string?)
	local data = DataService.GetData(player)
	if not data then return false, "No player data" end

	if upgradeType == "Conveyor" then
		if data.ConveyorLevel >= Config.Economy.MaxConveyorLevel then
			return false, "Max Conveyor Level reached"
		end
		local cost = Config.Economy.GetConveyorCost(data.ConveyorLevel + 1)
		if not DataService.SpendBanked(player, cost) then
			return false, `Need ${cost} Banked Cash`
		end
		data.ConveyorLevel += 1
		DataService.SyncClient(player)
		return true, `Conveyor upgraded to Level {data.ConveyorLevel}!`

	elseif upgradeType == "Laser" then
		if data.LaserTier >= Config.Economy.MaxLaserTier then
			return false, "Max Laser Tier reached"
		end
		local cost = Config.Economy.GetLaserCost(data.LaserTier + 1)
		if not DataService.SpendBanked(player, cost) then
			return false, `Need ${cost} Banked Cash`
		end
		data.LaserTier += 1
		DataService.SyncClient(player)
		return true, `Laser Security upgraded to Tier {data.LaserTier}!`

	elseif upgradeType == "VaultInterest" then
		if data.VaultInterestTier >= Config.Economy.MaxInterestTier then
			return false, "Max Interest Tier reached"
		end
		local cost = Config.Economy.GetInterestCost(data.VaultInterestTier + 1)
		if not DataService.SpendBanked(player, cost) then
			return false, `Need ${cost} Banked Cash`
		end
		data.VaultInterestTier += 1
		DataService.SyncClient(player)
		return true, `Vault Interest upgraded to Tier {data.VaultInterestTier}!`
	end

	return false, "Unknown upgrade type"
end

-- ============================================================
-- PRESTIGE (VAULT LIQUIDATION)
-- ============================================================
function DataService.LiquidateVault(player: Player): (boolean, number)
	local data = DataService.GetData(player)
	if not data then return false, 0 end

	if data.BankedCash < Config.Economy.PrestigeMinBanked then
		return false, 0
	end

	local tokensEarned = math.floor(Config.Economy.PrestigeTokenBase * ((data.BankedCash / Config.Economy.PrestigeMinBanked) ^ Config.Economy.PrestigeExponent))
	if tokensEarned < 1 then tokensEarned = 1 end

	data.PrestigeTokens = (data.PrestigeTokens or 0) + tokensEarned
	data.PrestigeLevel = (data.PrestigeLevel or 0) + 1

	-- Reset base
	data.BankedCash = 0
	data.UnbankedCash = 0
	data.ConveyorLevel = 1
	data.LaserTier = 1
	data.VaultInterestTier = 1

	DataService.SyncClient(player)
	return true, tokensEarned
end

-- ============================================================
-- INITIALIZE REMOTES & HOOKS
-- ============================================================
function DataService.Init()
	print("  [DataService] Initializing ProfileService for VAULT WARS...")

	local events = { "DataReady", "DataUpdate", "BreachAlert", "RelicMinted", "HeistBroadcast" }
	for _, name in events do
		if not ReplicatedStorage:FindFirstChild(name) then
			local evt = Instance.new("RemoteEvent")
			evt.Name = name
			evt.Parent = ReplicatedStorage
		end
	end

	local functions = { "GetData", "UpgradeRequest", "BankCashRequest", "PrestigeRequest" }
	for _, name in functions do
		if not ReplicatedStorage:FindFirstChild(name) then
			local rf = Instance.new("RemoteFunction")
			rf.Name = name
			rf.Parent = ReplicatedStorage
		end
	end

	-- Connect RemoteFunctions
	local getDataRF = ReplicatedStorage:FindFirstChild("GetData") :: RemoteFunction?
	if getDataRF then
		getDataRF.OnServerInvoke = function(p: Player)
			return DataService.GetData(p)
		end
	end

	local upgradeRF = ReplicatedStorage:FindFirstChild("UpgradeRequest") :: RemoteFunction?
	if upgradeRF then
		upgradeRF.OnServerInvoke = function(p: Player, upType: string)
			return DataService.Upgrade(p, upType)
		end
	end

	local bankRF = ReplicatedStorage:FindFirstChild("BankCashRequest") :: RemoteFunction?
	if bankRF then
		bankRF.OnServerInvoke = function(p: Player)
			return DataService.BankAll(p)
		end
	end

	local prestigeRF = ReplicatedStorage:FindFirstChild("PrestigeRequest") :: RemoteFunction?
	if prestigeRF then
		prestigeRF.OnServerInvoke = function(p: Player)
			return DataService.LiquidateVault(p)
		end
	end

	-- Real-time 60-second compound interest ticker for active & AFK tycoons
	task.spawn(function()
		while true do
			task.wait(60)
			local now = os.time()
			for player, profile in DataService._profiles do
				if player:IsDescendantOf(Players) and profile.Data then
					profile.Data.LastInterestTimestamp = now
					local banked = profile.Data.BankedCash or 0
					if banked > 0 then
						local tier = profile.Data.VaultInterestTier or 1
						-- Tier 1 = 2%/hr -> (tier * 0.02) / 60 per minute
						local ratePerMinute = (tier * 0.02) / 60
						local interestEarned = math.floor(banked * ratePerMinute)
						if interestEarned > 0 then
							profile.Data.BankedCash += interestEarned
							DataService.SyncClient(player)
						end
					end
				end
			end
		end
	end)

	for _, p in Players:GetPlayers() do
		task.spawn(DataService.OnPlayerAdded, p)
	end
	Players.PlayerAdded:Connect(DataService.OnPlayerAdded)
	Players.PlayerRemoving:Connect(DataService.OnPlayerRemoving)

	print("  [DataService] Vault Wars Session Store online ✓")
end

return DataService
