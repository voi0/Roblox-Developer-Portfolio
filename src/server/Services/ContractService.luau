--!strict
--[[
	ContractService.luau — Server-Authoritative Syndicate Contracts & Wanted Bounty Engine
	Generates persistent daily operations for players, tracks live gameplay progress,
	manages Syndicate Token payouts, and maintains the server Wanted Burglar Board.
	Located in: ServerScriptService.Server.Services.ContractService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local ContractService = {}

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

-- ============================================================
-- GENERATE / REFRESH DAILY CONTRACTS
-- ============================================================
function ContractService.EnsureDailyContracts(player: Player): { [string]: Types.SyndicateContract }
	local dataSvc = getDataService()
	if not dataSvc then return {} end

	local data = dataSvc.GetData(player)
	if not data then return {} end

	local now = os.time()
	local lastRefresh = data.LastContractsRefresh or 0
	local needsRefresh = (now - lastRefresh) >= Config.Contracts.RefreshIntervalSeconds or not data.Contracts or next(data.Contracts) == nil

	if needsRefresh then
		local newContracts: { [string]: Types.SyndicateContract } = {}
		local templates = Config.Contracts.Templates
		local indices = { 1, 2, 3 }

		for _, idx in indices do
			local template = templates[idx]
			if template then
				newContracts[template.Id] = {
					Id = template.Id,
					Title = template.Title,
					Description = template.Description,
					TargetCount = template.TargetCount,
					CurrentCount = 0,
					RewardCash = template.RewardCash,
					RewardXP = template.RewardXP,
					RewardTokens = template.RewardTokens,
					IsCompleted = false,
					IsClaimed = false,
				}
			end
		end

		dataSvc.SetContracts(player, newContracts)
		return newContracts
	end

	return data.Contracts
end

-- ============================================================
-- PROGRESS DISPATCHER
-- ============================================================
function ContractService.ReportAction(player: Player, actionTemplateId: string, amount: number)
	local dataSvc = getDataService()
	if not dataSvc then return end

	local contracts = dataSvc.GetContracts(player)
	if not contracts or not contracts[actionTemplateId] then return end

	local contract = contracts[actionTemplateId]
	if contract.IsCompleted or contract.IsClaimed then return end

	contract.CurrentCount = math.clamp(contract.CurrentCount + amount, 0, contract.TargetCount)
	if contract.CurrentCount >= contract.TargetCount then
		contract.IsCompleted = true
		print(`  [ContractService] {player.Name} completed Syndicate Operation: {contract.Title}!`)
	end

	dataSvc.SetContracts(player, contracts)

	local updateEvt = ReplicatedStorage:FindFirstChild("ContractProgressUpdated") :: RemoteEvent?
	if updateEvt then
		updateEvt:FireClient(player, contracts)
	end
end

-- ============================================================
-- CLAIM CONTRACT REWARDS
-- ============================================================
function ContractService.ClaimReward(player: Player, contractId: string): (boolean, string?)
	local dataSvc = getDataService()
	if not dataSvc then return false, "No DataService" end

	local contracts = dataSvc.GetContracts(player)
	if not contracts or not contracts[contractId] then
		return false, "Contract not found"
	end

	local contract = contracts[contractId]
	if not contract.IsCompleted then
		return false, "Contract objective not yet completed"
	end
	if contract.IsClaimed then
		return false, "Contract reward already claimed"
	end

	contract.IsClaimed = true
	dataSvc.SetContracts(player, contracts)

	-- Award Banked Cash
	dataSvc.AddBanked(player, contract.RewardCash)

	-- Award XP
	dataSvc.AddXP(player, contract.RewardXP, "Syndicate Contract: " .. contract.Title)

	-- Award Syndicate Tokens
	dataSvc.AddSyndicateTokens(player, contract.RewardTokens)

	print(`  [ContractService] {player.Name} claimed reward for {contract.Title} (+${contract.RewardCash}, +{contract.RewardXP} XP, +{contract.RewardTokens} Tokens)`)
	return true, `Claimed: +${contract.RewardCash} Cash, +{contract.RewardXP} XP, +{contract.RewardTokens} Tokens!`
end

-- ============================================================
-- WANTED BURGLARY BOUNTY BOARD
-- ============================================================
function ContractService.GetWantedBounties(): { any }
	local dataSvc = getDataService()
	local list = {}

	for _, player in Players:GetPlayers() do
		local data = dataSvc and dataSvc.GetData(player)
		local unbanked = data and data.UnbankedCash or 0
		local won = data and data.TotalHeistsWon or 0
		local bountyVal = math.max(1000, math.floor(unbanked * 0.5 + won * 500))

		table.insert(list, {
			UserId = player.UserId,
			DisplayName = player.DisplayName,
			Name = player.Name,
			UnbankedCash = unbanked,
			BountyCash = bountyVal,
			HeistsWon = won,
		})
	end

	table.sort(list, function(a, b)
		return a.BountyCash > b.BountyCash
	end)

	local top3 = {}
	for i = 1, math.min(3, #list) do
		table.insert(top3, list[i])
	end

	return top3
end

-- ============================================================
-- INITIALIZE REMOTES & HOOKS
-- ============================================================
function ContractService.Init()
	print("  [ContractService] Initializing Syndicate Contracts & Wanted Board...")

	-- Setup RemoteEvent & RemoteFunction
	local openEvt = ReplicatedStorage:FindFirstChild("OpenContractModal") :: RemoteEvent?
	if not openEvt then
		openEvt = Instance.new("RemoteEvent")
		openEvt.Name = "OpenContractModal"
		openEvt.Parent = ReplicatedStorage
	end

	local updateEvt = ReplicatedStorage:FindFirstChild("ContractProgressUpdated") :: RemoteEvent?
	if not updateEvt then
		updateEvt = Instance.new("RemoteEvent")
		updateEvt.Name = "ContractProgressUpdated"
		updateEvt.Parent = ReplicatedStorage
	end

	local claimRF = ReplicatedStorage:FindFirstChild("ClaimContractReward") :: RemoteFunction?
	if not claimRF then
		claimRF = Instance.new("RemoteFunction")
		claimRF.Name = "ClaimContractReward"
		claimRF.Parent = ReplicatedStorage
	end
	claimRF.OnServerInvoke = function(p: Player, contractId: string)
		return ContractService.ClaimReward(p, contractId)
	end

	local getContractsRF = ReplicatedStorage:FindFirstChild("GetContracts") :: RemoteFunction?
	if not getContractsRF then
		getContractsRF = Instance.new("RemoteFunction")
		getContractsRF.Name = "GetContracts"
		getContractsRF.Parent = ReplicatedStorage
	end
	getContractsRF.OnServerInvoke = function(p: Player)
		return ContractService.EnsureDailyContracts(p)
	end

	local getBountiesRF = ReplicatedStorage:FindFirstChild("GetWantedBounties") :: RemoteFunction?
	if not getBountiesRF then
		getBountiesRF = Instance.new("RemoteFunction")
		getBountiesRF.Name = "GetWantedBounties"
		getBountiesRF.Parent = ReplicatedStorage
	end
	getBountiesRF.OnServerInvoke = function(_: Player)
		return ContractService.GetWantedBounties()
	end

	-- Connect player joined
	Players.PlayerAdded:Connect(function(player: Player)
		task.delay(1.5, function()
			if player:IsDescendantOf(Players) then
				ContractService.EnsureDailyContracts(player)
			end
		end)
	end)

	print("  [ContractService] Syndicate Black Market Contracts ready ✓")
end

return ContractService
