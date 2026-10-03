--!strict
--[[
	Client Boot Script — STARWEAVE
	Orchestrates all client-side controllers: 3D World Sanctuary,
	Spatial Garden, Audio Experience, VFX Engine, Master UI, and Live Events.
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
-- INITIALIZE SYSTEMS
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

-- ============================================================
-- BULLETPROOF DATA BOOTSTRAP (Never blocks main thread)
-- ============================================================
task.spawn(function()
	local dataReady = ReplicatedStorage:WaitForChild("DataReady", 15) :: RemoteEvent?
	if dataReady then
		dataReady.OnClientEvent:Connect(function(data)
			if not isInitialized then
				initializeGame(data)
			else
				playerData = data
				UIController.Update(data)
				WorldController.Update(data)
				PetController.Update(data)
			end
		end)
	end
end)

-- Polling bootstrap via GetData RemoteFunction
task.spawn(function()
	local getData = ReplicatedStorage:WaitForChild("GetData", 15) :: RemoteFunction?
	if getData then
		for _ = 1, 20 do
			if isInitialized then break end
			local success, data = pcall(function()
				return getData:InvokeServer()
			end)
			if success and data and not isInitialized then
				initializeGame(data)
				break
			end
			task.wait(0.3)
		end
	end

	-- Emergency Fallback: If network or server data takes > 4 seconds,
	-- launch world with default local data so the player is NEVER on an empty baseplate!
	if not isInitialized then
		warn("[Client] Server data took longer than expected. Bootstrapping local sanctuary...")
		local fallbackData = {
			Stardust = 100,
			NebulaGems = 10,
			Starlight = 0,
			GardenSize = 9,
			Garden = {},
			SeedInventory = { starseed_basic = 5 },
			PlantCollection = {},
			Pets = {},
			Rebirth = { Level = 0, CosmicMultiplier = 1.0, ConstellationPoints = 0, ConstellationTree = {} },
			Level = 1,
			Experience = 0,
		}
		for i = 1, 9 do
			table.insert(fallbackData.Garden, { Index = i, Unlocked = true, Plant = nil })
		end
		initializeGame(fallbackData)
	end
end)

-- ============================================================
-- LIVE GARDEN EVENT LISTENER
-- ============================================================
task.spawn(function()
	local gardenUpdate = ReplicatedStorage:WaitForChild("GardenUpdate", 20) :: RemoteEvent?
	if not gardenUpdate then return end

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
				playerData.Stardust = (playerData.Stardust or 0) + (harvestResult.FinalValue or 0)
				playerData.TotalHarvests = (playerData.TotalHarvests or 0) + 1

				if harvestResult.IsNewCollection and harvestResult.SeedId and harvestResult.MutationTier then
					local cKey = harvestResult.SeedId .. "_" .. harvestResult.MutationTier
					if not playerData.PlantCollection then playerData.PlantCollection = {} end
					playerData.PlantCollection[cKey] = true
				end

				local tier = harvestResult.MutationTier or "None"
				if tier == "Primordial" then
					SoundController.Play("HarvestPrimordial")
				elseif harvestResult.IsRare then
					SoundController.Play("HarvestRare")
				else
					SoundController.Play("HarvestCommon")
				end

				local plotModel = WorldController._plotModels[plotIndex]
				local worldPos = Vector3.new(0, 1, 25)
				if plotModel then
					local soil = plotModel:FindFirstChild("Soil") :: BasePart?
					if soil then
						worldPos = soil.Position
					end
				end
				VFXController.SpawnHarvestBurst(worldPos, tier)

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
end)

-- ============================================================
-- WEATHER & ATMOSPHERE LISTENER
-- ============================================================
task.spawn(function()
	local weatherChanged = ReplicatedStorage:WaitForChild("WeatherChanged", 20) :: RemoteEvent?
	if not weatherChanged then return end

	weatherChanged.OnClientEvent:Connect(function(isActive: boolean)
		UIController.SetWeather(isActive)
		if isActive then
			VFXController.AddCameraTrauma(0.4)
			VFXController.FlashScreen(Color3.fromRGB(168, 85, 247), 0.5, 1.0)
		end
	end)
end)

-- ============================================================
-- SERVER ANNOUNCEMENTS
-- ============================================================
task.spawn(function()
	local announcement = ReplicatedStorage:WaitForChild("ServerAnnouncement", 20) :: RemoteEvent?
	if not announcement then return end

	announcement.OnClientEvent:Connect(function(message: string, tier: string)
		NotificationUI.ShowAnnouncement(message, tier)
		if tier == "Celestial" or tier == "Primordial" then
			SoundController.Play("HarvestRare")
			VFXController.AddCameraTrauma(0.2)
		end
	end)
end)

-- ============================================================
-- SHOP UPDATES
-- ============================================================
task.spawn(function()
	local shopUpdate = ReplicatedStorage:WaitForChild("ShopUpdate", 20) :: RemoteEvent?
	if not shopUpdate then return end

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
end)

-- ============================================================
-- TRANSCENDENCE / REBIRTH
-- ============================================================
task.spawn(function()
	local rebirthComplete = ReplicatedStorage:WaitForChild("RebirthComplete", 20) :: RemoteEvent?
	if not rebirthComplete then return end

	rebirthComplete.OnClientEvent:Connect(function(rebirthData: any)
		if not playerData then return end

		playerData.Rebirth.Level = rebirthData.NewLevel
		playerData.Rebirth.CosmicMultiplier = rebirthData.CosmicMultiplier
		playerData.Rebirth.ConstellationPoints = rebirthData.ConstellationPoints
		playerData.Starlight = (playerData.Starlight or 0) + (rebirthData.StarlightReward or 0)

		if playerData.Garden then
			for _, plot in playerData.Garden do
				plot.Plant = nil
			end
		end

		NotificationUI.ShowToast(`✨ ASCENDED TO REBIRTH LEVEL {rebirthData.NewLevel}!`, Color3.fromRGB(190, 24, 93), 6)
		WorldController.Update(playerData)
		UIController.Update(playerData)
	end)
end)
