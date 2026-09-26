--!strict
--[[
	Client Boot Script — STARWEAVE
	Initializes client-side controllers and UI.
	Located in: StarterPlayerScripts.Client
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- ============================================================
-- WAIT FOR DATA
-- ============================================================
local dataReady = ReplicatedStorage:WaitForChild("DataReady") :: RemoteEvent
local playerData: any = nil

dataReady.OnClientEvent:Connect(function(data)
	playerData = data
	print("[Client] Data received! Welcome to Starweave ✨")
	-- TODO: Initialize UI controllers here
end)

-- ============================================================
-- GARDEN UPDATE LISTENER
-- ============================================================
local gardenUpdate = ReplicatedStorage:WaitForChild("GardenUpdate") :: RemoteEvent

gardenUpdate.OnClientEvent:Connect(function(action: string, plotIndex: number, data: any)
	if action == "Planted" then
		print(`[Garden] Planted seed in plot {plotIndex}`)
		-- TODO: Play planting animation, update UI

	elseif action == "Ready" then
		print(`[Garden] Plot {plotIndex} is ready to harvest! 🌿`)
		-- TODO: Show harvest indicator, play sparkle effect

	elseif action == "Harvested" then
		if data then
			local tierDisplay = data.MutationTier
			local multiplier = data.MutationMultiplier
			local value = data.FinalValue

			if data.IsRare then
				print(`[Garden] 🌟 RARE HARVEST! {tierDisplay} mutation ({multiplier}x) = {value} Stardust!`)
				-- TODO: Play epic harvest animation, screen shake, particles
			else
				print(`[Garden] Harvested: {tierDisplay} ({multiplier}x) = {value} Stardust`)
				-- TODO: Play normal harvest animation
			end

			if data.IsNewCollection then
				print(`[Garden] 📚 NEW COLLECTION ENTRY!`)
				-- TODO: Show collection popup
			end
		end

	elseif action == "PlotUnlocked" then
		print(`[Garden] Plot {plotIndex} unlocked! 🔓`)
		-- TODO: Play unlock animation
	end
end)

-- ============================================================
-- WEATHER LISTENER
-- ============================================================
local weatherChanged = ReplicatedStorage:WaitForChild("WeatherChanged") :: RemoteEvent

weatherChanged.OnClientEvent:Connect(function(isActive: boolean)
	if isActive then
		print("[Weather] ⚡ MUTATION STORM! All mutation chances doubled!")
		-- TODO: Start storm visual effects (particles, lighting changes)
	else
		print("[Weather] Storm has passed.")
		-- TODO: Stop storm visual effects
	end
end)

-- ============================================================
-- SERVER ANNOUNCEMENTS
-- ============================================================
local announcement = ReplicatedStorage:WaitForChild("ServerAnnouncement") :: RemoteEvent

announcement.OnClientEvent:Connect(function(message: string, tier: string)
	print(`[Announce] {message}`)
	-- TODO: Show in-game announcement banner with tier-colored text
end)

-- ============================================================
-- SHOP UPDATES
-- ============================================================
local shopUpdate = ReplicatedStorage:WaitForChild("ShopUpdate") :: RemoteEvent

shopUpdate.OnClientEvent:Connect(function(action: string, ...)
	if action == "GamepassPurchased" then
		local passName = ...
		print(`[Shop] Gamepass purchased: {passName} ✅`)
		-- TODO: Show purchase confirmation, update UI flags

	elseif action == "MysterySeedResult" then
		local seedId, count = ...
		print(`[Shop] Mystery Seed Box: Got {count}x {seedId}! 🎁`)
		-- TODO: Show seed reveal animation
	end
end)

-- ============================================================
-- REBIRTH
-- ============================================================
local rebirthComplete = ReplicatedStorage:WaitForChild("RebirthComplete") :: RemoteEvent

rebirthComplete.OnClientEvent:Connect(function(rebirthData: any)
	print(`[Rebirth] ✨ TRANSCENDED to Level {rebirthData.NewLevel}!`)
	print(`  Cosmic Multiplier: {rebirthData.CosmicMultiplier}x`)
	print(`  Constellation Points: {rebirthData.ConstellationPoints}`)
	print(`  Starlight Reward: {rebirthData.StarlightReward}`)
	-- TODO: Play epic transcendence animation, screen effects
end)

-- ============================================================
-- CONVENIENCE: API FOR UI CONTROLLERS
-- ============================================================
local ClientAPI = {}

function ClientAPI.PlantSeed(plotIndex: number, seedId: string)
	local gardenRequest = ReplicatedStorage:WaitForChild("GardenRequest") :: RemoteFunction
	return gardenRequest:InvokeServer("Plant", plotIndex, seedId)
end

function ClientAPI.HarvestPlant(plotIndex: number)
	local gardenRequest = ReplicatedStorage:WaitForChild("GardenRequest") :: RemoteFunction
	return gardenRequest:InvokeServer("Harvest", plotIndex)
end

function ClientAPI.UnlockPlot(plotIndex: number)
	local gardenRequest = ReplicatedStorage:WaitForChild("GardenRequest") :: RemoteFunction
	return gardenRequest:InvokeServer("UnlockPlot", plotIndex)
end

function ClientAPI.BuySeed(seedId: string, count: number)
	local gardenRequest = ReplicatedStorage:WaitForChild("GardenRequest") :: RemoteFunction
	return gardenRequest:InvokeServer("BuySeed", seedId, count)
end

function ClientAPI.Rebirth()
	local economyRequest = ReplicatedStorage:WaitForChild("EconomyRequest") :: RemoteFunction
	return economyRequest:InvokeServer("Rebirth")
end

function ClientAPI.UpgradeConstellation(upgradeId: string)
	local economyRequest = ReplicatedStorage:WaitForChild("EconomyRequest") :: RemoteFunction
	return economyRequest:InvokeServer("UpgradeConstellation", upgradeId)
end

function ClientAPI.ClaimLoginReward()
	local economyRequest = ReplicatedStorage:WaitForChild("EconomyRequest") :: RemoteFunction
	return economyRequest:InvokeServer("ClaimLogin")
end

function ClientAPI.GetData()
	return playerData
end

-- Make API available to other client modules
local apiModule = Instance.new("ModuleScript")
apiModule.Name = "ClientAPI"
apiModule.Parent = script
-- Note: In production, this would be a proper ModuleScript in the client folder.
-- For now, other client scripts can require this module.

print("[Client] Starweave client initialized ✨")
