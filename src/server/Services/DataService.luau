--!strict
--[[
	DataService.luau — ProfileService wrapper for ESCAPE THE PACK
	Handles all player data persistence with crash-safe locking.
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

-- ============================================================
-- DATA TEMPLATE (Default values for new players)
-- ============================================================
local DATA_TEMPLATE = {
	Coins = Config.Economy.StartingCoins,
	Gems = Config.Economy.StartingGems,
	Wins = 0,
	Kills = 0,
	HeroClutches = 0,
	TotalCrossings = 0,
	TotalRevives = 0,

	-- Loadout
	EquippedAbility = "Cloak",
	UnlockedAbilities = { Cloak = true },
	EquippedKnife = "DefaultDagger",
	UnlockedKnives = { DefaultDagger = true },
	EquippedTrail = "Default",
	UnlockedTrails = { Default = true },

	-- Meta
	RedeemedCodes = {},
	PlayTimeSeconds = 0,
	LoginStreak = 0,
	LastLoginDate = "",
}

local BaseProfileStore = ProfileService.GetProfileStore(
	"EscapeThePack_v1",
	DATA_TEMPLATE
)

local ProfileStore = (RunService:IsStudio() and BaseProfileStore.Mock) or BaseProfileStore

local DataService = {}
DataService._profiles = {} :: { [Player]: any }

-- ============================================================
-- INTERNAL HELPERS
-- ============================================================
local function _reconcileData(data: any)
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

local function _handleLoginStreak(data: any)
	local today = os.date("!*t")
	local dateStr = string.format("%d-%02d-%02d", today.year, today.month, today.day)

	if data.LastLoginDate == "" then
		data.LoginStreak = 1
		data.LastLoginDate = dateStr
		return
	end

	if data.LastLoginDate == dateStr then
		return
	end

	local lastYear, lastMonth, lastDay = data.LastLoginDate:match("(%d+)-(%d+)-(%d+)")
	if lastYear then
		local lastTime = os.time({ year = tonumber(lastYear), month = tonumber(lastMonth), day = tonumber(lastDay), hour = 0, min = 0, sec = 0 })
		local todayTime = os.time({ year = today.year, month = today.month, day = today.day, hour = 0, min = 0, sec = 0 })
		local diffDays = math.floor((todayTime - lastTime) / 86400)

		if diffDays == 1 then
			data.LoginStreak = (data.LoginStreak or 0) + 1
		else
			data.LoginStreak = 1
		end
	else
		data.LoginStreak = 1
	end

	data.LastLoginDate = dateStr
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
		warn(`[DataService] Could not load cloud ProfileStore for {player.Name}: {tostring(err)}. Falling back to Mock store.`)
		pcall(function()
			profile = BaseProfileStore.Mock:LoadProfileAsync("Player_" .. player.UserId, "ForceLoad")
		end)
	end

	if profile == nil then
		warn(`[DataService] Using emergency session data for {player.Name}`)
		local memData = table.clone(DATA_TEMPLATE)
		DataService._profiles[player] = { Data = memData, Release = function() end }
		local dataReadyEvent = ReplicatedStorage:FindFirstChild("DataReady")
		if dataReadyEvent and dataReadyEvent:IsA("RemoteEvent") then
			dataReadyEvent:FireClient(player, memData)
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	if not player:IsDescendantOf(Players) then
		profile:Release()
		return
	end

	_reconcileData(profile.Data)
	_handleLoginStreak(profile.Data)

	profile:ListenToRelease(function()
		DataService._profiles[player] = nil
		player:Kick("Your session was loaded on another server. Please rejoin.")
	end)

	DataService._profiles[player] = profile

	local dataReadyEvent = ReplicatedStorage:FindFirstChild("DataReady")
	if dataReadyEvent and dataReadyEvent:IsA("RemoteEvent") then
		dataReadyEvent:FireClient(player, profile.Data)
	end

	print(`  [DataService] Loaded profile for {player.Name} (Coins: {profile.Data.Coins}, Gems: {profile.Data.Gems})`)
end

function DataService.OnPlayerRemoving(player: Player)
	local profile = DataService._profiles[player]
	if profile then
		profile:Release()
		DataService._profiles[player] = nil
		print(`  [DataService] Released session profile for {player.Name}`)
	end
end

-- ============================================================
-- GETTERS & CLIENT SYNC
-- ============================================================
function DataService.GetData(player: Player): any?
	local profile = DataService._profiles[player]
	if not profile then return nil end
	return profile.Data
end

function DataService.SyncClient(player: Player)
	local data = DataService.GetData(player)
	if not data then return end

	local dataUpdate = ReplicatedStorage:FindFirstChild("DataUpdate")
	if dataUpdate and dataUpdate:IsA("RemoteEvent") then
		dataUpdate:FireClient(player, data)
	end
end

-- ============================================================
-- ECONOMY OPERATIONS
-- ============================================================
function DataService.AddCoins(player: Player, amount: number, reason: string?): number
	if amount <= 0 then return 0 end
	local data = DataService.GetData(player)
	if not data then return 0 end

	data.Coins = (data.Coins or 0) + math.floor(amount)
	DataService.SyncClient(player)
	return data.Coins
end

function DataService.SpendCoins(player: Player, amount: number): boolean
	if amount <= 0 then return true end
	local data = DataService.GetData(player)
	if not data then return false end
	if (data.Coins or 0) < amount then return false end

	data.Coins = data.Coins - math.floor(amount)
	DataService.SyncClient(player)
	return true
end

function DataService.AddGems(player: Player, amount: number, reason: string?): number
	if amount <= 0 then return 0 end
	local data = DataService.GetData(player)
	if not data then return 0 end

	data.Gems = (data.Gems or 0) + math.floor(amount)
	DataService.SyncClient(player)
	return data.Gems
end

function DataService.SpendGems(player: Player, amount: number): boolean
	if amount <= 0 then return true end
	local data = DataService.GetData(player)
	if not data then return false end
	if (data.Gems or 0) < amount then return false end

	data.Gems = data.Gems - math.floor(amount)
	DataService.SyncClient(player)
	return true
end

-- ============================================================
-- STATS & ROUND MILESTONES
-- ============================================================
function DataService.RecordWaveCrossing(player: Player)
	local data = DataService.GetData(player)
	if not data then return end

	data.TotalCrossings = (data.TotalCrossings or 0) + 1
	DataService.AddCoins(player, Config.Economy.WaveSurvivalCoins, "WaveCrossing")
end

function DataService.RecordMatchWin(player: Player, isHero: boolean)
	local data = DataService.GetData(player)
	if not data then return end

	data.Wins = (data.Wins or 0) + 1
	if isHero then
		data.HeroClutches = (data.HeroClutches or 0) + 1
		DataService.AddCoins(player, Config.Economy.HeroSurvivalCoins, "HeroWin")
		DataService.AddGems(player, Config.Economy.HeroSurvivalGems, "HeroWinGems")
	else
		DataService.AddCoins(player, Config.Economy.MatchWinCoins, "MatchWin")
		DataService.AddGems(player, Config.Economy.MatchWinGems, "MatchWinGems")
	end
end

function DataService.RecordTag(player: Player)
	local data = DataService.GetData(player)
	if not data then return end

	data.Kills = (data.Kills or 0) + 1
	DataService.AddCoins(player, Config.Economy.ChaserTagCoins, "ChaserTag")
end

function DataService.RecordRevive(player: Player)
	local data = DataService.GetData(player)
	if not data then return end

	data.TotalRevives = (data.TotalRevives or 0) + 1
	DataService.AddCoins(player, Config.Economy.TeammateReviveCoins, "TeammateRevive")
end

-- ============================================================
-- LOADOUT & ABILITIES
-- ============================================================
function DataService.UnlockAbility(player: Player, abilityId: string): boolean
	local data = DataService.GetData(player)
	if not data then return false end

	if not data.UnlockedAbilities then data.UnlockedAbilities = {} end
	data.UnlockedAbilities[abilityId] = true
	data.EquippedAbility = abilityId
	DataService.SyncClient(player)
	return true
end

function DataService.EquipAbility(player: Player, abilityId: string): boolean
	local data = DataService.GetData(player)
	if not data then return false end
	if not data.UnlockedAbilities or not data.UnlockedAbilities[abilityId] then return false end

	data.EquippedAbility = abilityId
	DataService.SyncClient(player)
	return true
end

function DataService.UnlockKnife(player: Player, knifeId: string): boolean
	local data = DataService.GetData(player)
	if not data then return false end

	if not data.UnlockedKnives then data.UnlockedKnives = {} end
	data.UnlockedKnives[knifeId] = true
	data.EquippedKnife = knifeId
	DataService.SyncClient(player)
	return true
end

function DataService.EquipKnife(player: Player, knifeId: string): boolean
	local data = DataService.GetData(player)
	if not data then return false end
	if not data.UnlockedKnives or not data.UnlockedKnives[knifeId] then return false end

	data.EquippedKnife = knifeId
	DataService.SyncClient(player)
	return true
end

-- ============================================================
-- SERVICE INITIALIZATION
-- ============================================================
function DataService.Init()
	print("  [DataService] Initializing ProfileService for ESCAPE THE PACK...")

	local remotes = { "DataReady", "DataUpdate", "GetData", "ShopRequest" }
	for _, name in remotes do
		if not ReplicatedStorage:FindFirstChild(name) then
			local inst = (name == "GetData" or name == "ShopRequest") and Instance.new("RemoteFunction") or Instance.new("RemoteEvent")
			inst.Name = name
			inst.Parent = ReplicatedStorage
		end
	end

	local getDataRF = ReplicatedStorage:FindFirstChild("GetData") :: RemoteFunction?
	if getDataRF then
		getDataRF.OnServerInvoke = function(player: Player)
			return DataService.GetData(player)
		end
	end

	local shopRequestRF = ReplicatedStorage:FindFirstChild("ShopRequest") :: RemoteFunction?
	if shopRequestRF then
		local AbilityData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AbilityData"))
		shopRequestRF.OnServerInvoke = function(player: Player, action: string, itemId: string)
			if action == "BuyAbility" then
				local def = AbilityData[itemId]
				if not def then return false, "Unknown ability" end
				local data = DataService.GetData(player)
				if data and data.UnlockedAbilities and data.UnlockedAbilities[itemId] then
					return false, "Already unlocked"
				end
				if DataService.SpendGems(player, def.GemCost) then
					DataService.UnlockAbility(player, itemId)
					return true, `Unlocked {def.Name}!`
				else
					return false, "Not enough Gems!"
				end
			elseif action == "EquipAbility" then
				if DataService.EquipAbility(player, itemId) then
					return true, "Equipped!"
				else
					return false, "Ability is locked"
				end
			end
			return false, "Invalid action"
		end
	end

	for _, p in Players:GetPlayers() do
		task.spawn(DataService.OnPlayerAdded, p)
	end
	Players.PlayerAdded:Connect(DataService.OnPlayerAdded)
	Players.PlayerRemoving:Connect(DataService.OnPlayerRemoving)

	print("  [DataService] ProfileService session store ready ✓")
end

return DataService
