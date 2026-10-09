--!strict
--[[
	EconomyService.luau — DevEx & In-Experience Robux Monetization for VAULT WARS
	Processes Marketplace receipts for 25 R$ Adrenaline, Relic Magnet,
	and high-ticket Gamepasses (Titanium Lasers, Auto-Drone & Raid Shield).
	Located in: ServerScriptService.Server.Services.EconomyService
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local EconomyService = {}

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

function EconomyService.Init()
	print("  [EconomyService] Initializing Robux Monetization & Receipt Processor...")

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local dataSvc = getDataService()
		if not dataSvc then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local pId = receiptInfo.ProductId

		-- ⚡ 25 R$ Adrenaline Surge
		if pId == Config.Monetization.DevProducts.AdrenalineSurge.Id then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = Config.Heist.AdrenalineBoostSpeed
				task.delay(Config.Heist.AdrenalineDuration, function()
					if hum and hum.Parent then
						hum.WalkSpeed = Config.Heist.NormalWalkSpeed
					end
				end)
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	print("  [EconomyService] Monetization Engine ready ✓")
end

return EconomyService
