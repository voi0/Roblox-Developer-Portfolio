--!strict
--[[
	Client Boot Script — STARWEAVE
	Orchestrates all client-side controllers: 3D World Sanctuary,
	Spatial Garden, Audio Experience, VFX Engine, and Master UI.
	Located in: StarterPlayerScripts.Client
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SoundController = require(script.Controllers.SoundController)
local VFXController = require(script.Controllers.VFXController)
local WorldController = require(script.Controllers.WorldController)
local UIController = require(script.Controllers.UIController)
local PetController = require(script.Controllers.PetController)
local TutorialController = require(script.Controllers.TutorialController)
local NotificationUI = require(script.UI.NotificationUI)

local player = Players.LocalPlayer

local playerData: any = nil
local isInitialized = false

-- ============================================================
-- INITIALIZE SYSTEMS ON DATA READY
-- ============================================================
local function initializeGame(data: any)
	if isInitialized then
		playerData = data
		UIController.Update(data)
		WorldController.Update(data)
		PetController.Update(data)
		return
	end

	isInitialized = true
	playerData = data

	print("========================================")
	print("  ✨ STARWEAVE Client Booting...")
	print("========================================")

	SoundController.Init()
	VFXController.Init()
	WorldController.Init()
	WorldController.StartRenderLoop()
	PetController.Init()
	TutorialController.Init()
	UIController.Init()

	UIController.Update(data)
	WorldController.Update(data)
	PetController.Update(data)
	TutorialController.CheckStart(data)

	print("========================================")
	print("  ✅ STARWEAVE Sanctuary Loaded!")
	print("========================================")
end

local dataReady = ReplicatedStorage:WaitForChild("DataReady") :: RemoteEvent
dataReady.OnClientEvent:Connect(function(data)
	initializeGame(data)
end)

-- Robust fallback: invoke GetData in case DataReady fired before client listener attached
task.spawn(function()
	task.wait(0.2)
	if not isInitialized then
		local getData = ReplicatedStorage:WaitForChild("GetData", 10) :: RemoteFunction?
		if getData and not isInitialized then
			local data = getData:InvokeServer()
			if data and not isInitialized then
				initializeGame(data)
			end
		end
	end
end)

-- ============================================================
-- LIVE GARDEN EVENT LISTENER
-- ============================================================
local gardenUpdate = ReplicatedStorage:WaitForChild("GardenUpdate") :: RemoteEvent

gardenUpdate.OnClientEvent:Connect(function(action: string, plotIndex: number, data: any)
	if not playerData then return end

	if action == "Planted" then
		if playerData.Garden and playerData.Garden[plotIndex] then
			playerData.Garden[plotIndex].Plant = data
		end
		WorldController.UpdatePlantVisual(plotIndex, data)
		UIController.Update(playerData)
		TutorialController.OnPlantPlanted(plotIndex)

	elseif action == "Ready" then
		if playerData.Garden and playerData.Garden[plotIndex] then
			playerData.Garden[plotIndex].Plant = data
		end
		SoundController.Play("PlantReady")
		WorldController.UpdatePlantVisual(plotIndex, data)
		UIController.Update(playerData)

	elseif action == "Harvested" then
		local harvestResult = data
		if playerData.Garden and playerData.Garden[plotIndex] then
			playerData.Garden[plotIndex].Plant = nil
		end

		if harvestResult then
			-- Update local Stardust balance
			playerData.Stardust = (playerData.Stardust or 0) + (harvestResult.FinalValue or 0)
			playerData.TotalHarvests = (playerData.TotalHarvests or 0) + 1

			if harvestResult.IsNewCollection and harvestResult.SeedId and harvestResult.MutationTier then
				local cKey = harvestResult.SeedId .. "_" .. harvestResult.MutationTier
				if not playerData.PlantCollection then playerData.PlantCollection = {} end
				playerData.PlantCollection[cKey] = true
			end

			-- Audio & Visual Juice
			local tier = harvestResult.MutationTier or "None"
			if tier == "Primordial" then
				SoundController.Play("HarvestPrimordial")
			elseif harvestResult.IsRare then
				SoundController.Play("HarvestRare")
			else
				SoundController.Play("HarvestCommon")
			end

			-- Spawn 3D Burst in World
			local plotModel = WorldController._plotModels[plotIndex]
			local worldPos = Vector3.new(0, 1, 25)
			if plotModel then
				local soil = plotModel:FindFirstChild("Soil") :: BasePart?
				if soil then
					worldPos = soil.Position
				end
			end
			VFXController.SpawnHarvestBurst(worldPos, tier)

			-- Toast and Rare Popup
			NotificationUI.ShowHarvest(harvestResult)
			TutorialController.OnPlantHarvested(plotIndex)
		end

		WorldController.UpdatePlantVisual(plotIndex, nil)
		UIController.Update(playerData)

	elseif action == "PlotUnlocked" then
		if playerData.Garden and playerData.Garden[plotIndex] then
			playerData.Garden[plotIndex].Unlocked = true
		end
		SoundController.Play("PlantReady")
		WorldController.Update(playerData)
		UIController.Update(playerData)
	end
end)

-- ============================================================
-- WEATHER & ATMOSPHERE LISTENER
-- ============================================================
local weatherChanged = ReplicatedStorage:WaitForChild("WeatherChanged") :: RemoteEvent

weatherChanged.OnClientEvent:Connect(function(isActive: boolean)
	UIController.SetWeather(isActive)
	if isActive then
		VFXController.AddCameraTrauma(0.4)
		VFXController.FlashScreen(Color3.fromRGB(168, 85, 247), 0.5, 1.0)
	end
end)

-- ============================================================
-- SERVER ANNOUNCEMENTS
-- ============================================================
local announcement = ReplicatedStorage:WaitForChild("ServerAnnouncement") :: RemoteEvent

announcement.OnClientEvent:Connect(function(message: string, tier: string)
	NotificationUI.ShowAnnouncement(message, tier)
	if tier == "Celestial" or tier == "Primordial" then
		SoundController.Play("HarvestRare")
		VFXController.AddCameraTrauma(0.2)
	end
end)

-- ============================================================
-- SHOP UPDATES
-- ============================================================
local shopUpdate = ReplicatedStorage:WaitForChild("ShopUpdate") :: RemoteEvent

shopUpdate.OnClientEvent:Connect(function(action: string, ...)
	if action == "GamepassPurchased" then
		local passName = ...
		NotificationUI.ShowToast(`⭐ Gamepass Unlocked: {passName}!`, Color3.fromRGB(22, 101, 52), 4)
		SoundController.Play("RebirthAscend")
	elseif action == "MysterySeedResult" then
		local seedId, count = ...
		NotificationUI.ShowToast(`🎁 Mystery Box: Unveiled {count}x {seedId}!`, Color3.fromRGB(126, 34, 206), 4)
		SoundController.Play("HarvestRare")
	end
end)

-- ============================================================
-- TRANSCENDENCE / REBIRTH
-- ============================================================
local rebirthComplete = ReplicatedStorage:WaitForChild("RebirthComplete") :: RemoteEvent

rebirthComplete.OnClientEvent:Connect(function(rebirthData: any)
	if not playerData then return end

	playerData.Rebirth.Level = rebirthData.NewLevel
	playerData.Rebirth.CosmicMultiplier = rebirthData.CosmicMultiplier
	playerData.Rebirth.ConstellationPoints = rebirthData.ConstellationPoints
	playerData.Starlight = (playerData.Starlight or 0) + (rebirthData.StarlightReward or 0)

	-- Reset active crops
	if playerData.Garden then
		for _, plot in playerData.Garden do
			plot.Plant = nil
		end
	end

	NotificationUI.ShowToast(`✨ ASCENDED TO REBIRTH LEVEL {rebirthData.NewLevel}!`, Color3.fromRGB(190, 24, 93), 6)
	WorldController.Update(playerData)
	UIController.Update(playerData)
end)
