--!strict
--[[
	CodeService.luau — Promo Code Redemption Engine for STARWEAVE
	Enables players to redeem viral codes (e.g. from TikTok, update logs, Twitter/X).
	Awards Stardust, Nebula Gems, and exclusive seeds while ensuring single-use per account.
	Located in: ServerScriptService.Server.Services.CodeService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService: any = nil

local CodeService = {}
CodeService._initialized = false

function CodeService.RedeemCode(player: Player, rawCode: string): (boolean, string, any?)
	if not rawCode or type(rawCode) ~= "string" then
		return false, "Please enter a valid code."
	end

	local cleanCode = string.upper(string.match(rawCode, "^%s*(.-)%s*$") or "")
	if #cleanCode == 0 then
		return false, "Please enter a code."
	end

	local codeDef = Config.PromoCodes[cleanCode]
	if not codeDef then
		return false, "Invalid code. Check for typos!"
	end

	if DataService.HasRedeemedCode(player, cleanCode) then
		return false, "You have already redeemed this code!"
	end

	-- Mark as redeemed
	DataService.MarkCodeRedeemed(player, cleanCode)

	-- Award currencies
	if codeDef.RewardStardust and codeDef.RewardStardust > 0 then
		DataService.AddCurrency(player, "Stardust", codeDef.RewardStardust)
	end
	if codeDef.RewardGems and codeDef.RewardGems > 0 then
		DataService.AddCurrency(player, "NebulaGems", codeDef.RewardGems)
	end

	-- Award seeds
	if codeDef.RewardSeeds then
		for seedId, count in codeDef.RewardSeeds do
			DataService.AddSeeds(player, seedId, count)
		end
	end

	print(`[CodeService] {player.Name} successfully redeemed code: {cleanCode}`)

	return true, `Code redeemed! Enjoy your celestial gifts.`, codeDef
end

function CodeService.Init()
	if CodeService._initialized then return end
	CodeService._initialized = true

	DataService = require(ServerScriptService.Server.Services.DataService)

	local codeRequest = Instance.new("RemoteFunction")
	codeRequest.Name = "CodeRequest"
	codeRequest.Parent = ReplicatedStorage

	codeRequest.OnServerInvoke = function(player: Player, codeStr: string): any
		local success, msg, reward = CodeService.RedeemCode(player, codeStr)
		return {
			Success = success,
			Message = msg,
			Reward = reward,
		}
	end

	print("[CodeService] Initialized ✓")
end

return CodeService
