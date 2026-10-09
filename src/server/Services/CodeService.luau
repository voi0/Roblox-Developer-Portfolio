--!strict
--[[
	CodeService.luau — Promo Code Redemption Engine for VAULT WARS: STEAL & DEFEND TYCOON
	Allows players to redeem viral codes (TikTok / Discord) for Banked Cash.
	Located in: ServerScriptService.Server.Services.CodeService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PROMO_CODES: { [string]: { CashReward: number } } = {
	RELEASE = { CashReward = 2500 },
	VAULT10K = { CashReward = 15000 },
	HEIST = { CashReward = 5000 },
}

local CodeService = {}

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

function CodeService.Init()
	print("  [CodeService] Initializing Promo Code Engine...")

	local codeRF = ReplicatedStorage:FindFirstChild("RedeemCode") :: RemoteFunction?
	if not codeRF then
		codeRF = Instance.new("RemoteFunction")
		codeRF.Name = "RedeemCode"
		codeRF.Parent = ReplicatedStorage
	end

	codeRF.OnServerInvoke = function(player: Player, rawCode: string)
		return CodeService.RedeemCode(player, rawCode)
	end

	print("  [CodeService] Promo Code Engine online ✓")
end

function CodeService.RedeemCode(player: Player, rawCode: string): (boolean, string)
	if not rawCode or type(rawCode) ~= "string" then
		return false, "Invalid code."
	end

	local cleanCode = string.upper(string.match(rawCode, "^%s*(.-)%s*$") or "")
	local codeDef = PROMO_CODES[cleanCode]
	if not codeDef then
		return false, "Code does not exist!"
	end

	local dataSvc = getDataService()
	if not dataSvc then return false, "Data service unavailable." end

	local data = dataSvc.GetData(player)
	if not data then return false, "Profile not loaded." end

	if not data.RedeemedCodes then data.RedeemedCodes = {} end
	if data.RedeemedCodes[cleanCode] then
		return false, "Code already redeemed!"
	end

	data.RedeemedCodes[cleanCode] = true
	dataSvc.AddBanked(player, codeDef.CashReward)

	return true, `Redeemed ${codeDef.CashReward} Banked Cash!`
end

return CodeService
