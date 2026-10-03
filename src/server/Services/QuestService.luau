--!strict
--[[
	QuestService.luau — Daily Quest Engine for STARWEAVE
	Generates 3 daily goals every 24 hours (UTC midnight reset).
	Tracks real-time progress for planting, harvesting mutations, forging,
	and earning stardust. Awards Stardust, Nebula Gems, and discovery rewards.
	Located in: ServerScriptService.Server.Services.QuestService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService: any = nil

local QuestService = {}
QuestService._initialized = false

-- ============================================================
-- TIME UTILS
-- ============================================================
local function getUtcDayKey(): string
	local date = os.date("!*t")
	return string.format("%d-%02d-%02d", date.year, date.month, date.day)
end

local function getSecondsUntilMidnightUtc(): number
	local date = os.date("!*t")
	local currentSeconds = date.hour * 3600 + date.min * 60 + date.sec
	return 86400 - currentSeconds
end

-- ============================================================
-- QUEST GENERATION
-- ============================================================
function QuestService.EnsureQuests(player: Player)
	local data = DataService.GetData(player)
	if not data then return end

	local currentDay = getUtcDayKey()
	local active = data.ActiveQuests or {}

	-- If quests are for an older day or empty, generate new daily set
	if active.DayKey ~= currentDay or not active.List or #active.List == 0 then
		local pool = table.clone(Config.Quests.DailyPool)
		-- Shuffle pool
		for i = #pool, 2, -1 do
			local j = math.random(i)
			pool[i], pool[j] = pool[j], pool[i]
		end

		local newList = {}
		-- Pick 3 unique quests
		for i = 1, math.min(3, #pool) do
			local qDef = pool[i]
			table.insert(newList, {
				Id = qDef.Id,
				Title = qDef.Title,
				Description = string.gsub(qDef.Description, "{Target}", tostring(qDef.Target)),
				Current = 0,
				Target = qDef.Target,
				RewardStardust = qDef.RewardStardust,
				RewardGems = qDef.RewardGems,
				Completed = false,
				Claimed = false,
			})
		end

		data.ActiveQuests = {
			DayKey = currentDay,
			List = newList,
		}

		print(`[QuestService] Generated 3 new daily quests for {player.Name} (Day: {currentDay})`)
	end
end

-- ============================================================
-- PROGRESS TRACKING
-- ============================================================
function QuestService.TrackProgress(player: Player, questId: string, amount: number)
	local data = DataService.GetData(player)
	if not data or not data.ActiveQuests or not data.ActiveQuests.List then return end

	local updated = false
	for _, quest in data.ActiveQuests.List do
		if quest.Id == questId and not quest.Completed then
			quest.Current = math.min(quest.Target, quest.Current + (amount or 1))
			if quest.Current >= quest.Target then
				quest.Completed = true
				print(`[QuestService] {player.Name} COMPLETED daily quest: {quest.Title}!`)
			end
			updated = true
		end
	end

	if updated then
		local questEvent = ReplicatedStorage:FindFirstChild("QuestUpdate") :: RemoteEvent?
		if questEvent then
			questEvent:FireClient(player, data.ActiveQuests.List, getSecondsUntilMidnightUtc())
		end
	end
end

-- ============================================================
-- REWARD CLAIMING
-- ============================================================
function QuestService.ClaimReward(player: Player, questId: string): (boolean, string, number?, number?)
	local data = DataService.GetData(player)
	if not data or not data.ActiveQuests or not data.ActiveQuests.List then
		return false, "Data not loaded."
	end

	for _, quest in data.ActiveQuests.List do
		if quest.Id == questId then
			if not quest.Completed then
				return false, "Quest not completed yet."
			end
			if quest.Claimed then
				return false, "Reward already claimed."
			end

			quest.Claimed = true

			-- Grant rewards
			DataService.AddCurrency(player, "Stardust", quest.RewardStardust)
			DataService.AddCurrency(player, "NebulaGems", quest.RewardGems)

			print(`[QuestService] {player.Name} claimed rewards for {quest.Title}: +{quest.RewardStardust} SD, +{quest.RewardGems} Gems`)

			local questEvent = ReplicatedStorage:FindFirstChild("QuestUpdate") :: RemoteEvent?
			if questEvent then
				questEvent:FireClient(player, data.ActiveQuests.List, getSecondsUntilMidnightUtc())
			end

			return true, "Claimed successfully!", quest.RewardStardust, quest.RewardGems
		end
	end

	return false, "Quest not found."
end

-- ============================================================
-- INITIALIZATION
-- ============================================================
function QuestService.Init()
	if QuestService._initialized then return end
	QuestService._initialized = true

	DataService = require(ServerScriptService.Server.Services.DataService)

	-- Create remote objects
	local questEvent = Instance.new("RemoteEvent")
	questEvent.Name = "QuestUpdate"
	questEvent.Parent = ReplicatedStorage

	local questRequest = Instance.new("RemoteFunction")
	questRequest.Name = "QuestRequest"
	questRequest.Parent = ReplicatedStorage

	questRequest.OnServerInvoke = function(player: Player, action: string, ...: any): any
		QuestService.EnsureQuests(player)
		local data = DataService.GetData(player)

		if action == "GetQuests" then
			local list = data and data.ActiveQuests and data.ActiveQuests.List or {}
			return {
				Success = true,
				Quests = list,
				SecondsUntilReset = getSecondsUntilMidnightUtc(),
			}

		elseif action == "ClaimReward" then
			local qId = ...
			local success, msg, sd, gems = QuestService.ClaimReward(player, qId)
			return {
				Success = success,
				Message = msg,
				Stardust = sd,
				Gems = gems,
			}
		end

		return { Success = false, Message = "Unknown action." }
	end

	-- Connect player joined to initialize daily quests
	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			while not DataService.IsDataLoaded(player) do
				task.wait(0.2)
			end
			QuestService.EnsureQuests(player)
		end)
	end)

	for _, p in Players:GetPlayers() do
		task.spawn(function()
			while not DataService.IsDataLoaded(p) do
				task.wait(0.2)
			end
			QuestService.EnsureQuests(p)
		end)
	end

	print("[QuestService] Initialized ✓")
end

return QuestService
