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

		-- 25 R$ Adrenaline Surge
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

	-- Check gamepass ownership on join
	local function onPlayerJoined(player: Player)
		task.delay(1.5, function()
			EconomyService.CheckGamepasses(player)
		end)
	end

	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerJoined, p)
	end
	Players.PlayerAdded:Connect(onPlayerJoined)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, wasPurchased: boolean)
		if wasPurchased then
			EconomyService.CheckGamepasses(player)
		end
	end)

	print("  [EconomyService] Monetization Engine ready ✓")
end

function EconomyService.CheckGamepasses(player: Player)
	local dataSvc = getDataService()
	if not dataSvc then return end
	local data = dataSvc.GetData(player)
	if not data then return end

	local gp = Config.Monetization.Gamepasses
	if gp.AutoDroneAndShield.Id > 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.AutoDroneAndShield.Id)
		end)
		if ok and owns then
			data.HasAutoCollector = true
			data.HasOfflineShield = true
		end
	end

	if gp.DoubleCapacity.Id > 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.DoubleCapacity.Id)
		end)
		if ok and owns then
			data.HasDoubleCapacity = true
		end
	end

	if gp.TitaniumLasers.Id > 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.TitaniumLasers.Id)
		end)
		if ok and owns then
			data.HasTitaniumLasers = true
		end
	end

	dataSvc.SyncClient(player)
end

return EconomyService
