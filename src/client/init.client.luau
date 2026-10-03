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

local player = Players.LocalPlayer

print("========================================")
print("  ✨ STARWEAVE Client Starting...")
print("========================================")

local controllersFolder = script:WaitForChild("Controllers", 15) :: Folder
local uiFolder = script:WaitForChild("UI", 15) :: Folder

if not controllersFolder or not uiFolder then
	warn("[Client] Critical: Controllers or UI folder not replicated in time!")
end

local function safeRequire(parent: Folder?, name: string): any?
	if not parent then return nil end
	local child = parent:WaitForChild(name, 10) :: ModuleScript?
	if not child then
		warn(`[Client] Missing module: {name}`)
		return nil
	end
	local success, result = pcall(function()
		return require(child)
	end)
	if success then
		return result
	else
		warn(`[Client] Error requiring {name}: {tostring(result)}`)
		return nil
	end
end

local SoundController = safeRequire(controllersFolder, "SoundController")
local VFXController = safeRequire(controllersFolder, "VFXController")
local WorldController = safeRequire(controllersFolder, "WorldController")
local UIController = safeRequire(controllersFolder, "UIController")
local PetController = safeRequire(controllersFolder, "PetController")
local TutorialController = safeRequire(controllersFolder, "TutorialController")
local NotificationUI = safeRequire(uiFolder, "NotificationUI")

local playerData: any = nil
local isInitialized = false

-- ============================================================
-- INITIALIZE SYSTEMS
-- ============================================================
local function initializeGame(data: any)
	if isInitialized then
		playerData = data
		if UIController then UIController.Update(data) end
		if WorldController then WorldController.Update(data) end
		if PetController then PetController.Update(data) end
		return
	end

	isInitialized = true
	playerData = data

	print("  [Client] Initializing subsystems...")

	if SoundController then
		pcall(function() SoundController.Init() end)
		print("  [Client] SoundController ready ✓")
	end
	if VFXController then
		pcall(function() VFXController.Init() end)
		print("  [Client] VFXController ready ✓")
	end
	if WorldController then
		pcall(function()
			WorldController.Init()
			WorldController.StartRenderLoop()
		end)
		print("  [Client] WorldController (3D Sanctuary) ready ✓")
	end
	if PetController then
		pcall(function() PetController.Init() end)
		print("  [Client] PetController ready ✓")
	end
	if TutorialController then
		pcall(function() TutorialController.Init() end)
		print("  [Client] TutorialController ready ✓")
	end
	if UIController then
		pcall(function() UIController.Init() end)
		print("  [Client] UIController (HUD & Modals) ready ✓")
	end

	-- Push initial data
	if UIController then UIController.Update(data) end
	if WorldController then WorldController.Update(data) end
	if PetController then PetController.Update(data) end
	if TutorialController then TutorialController.CheckStart(data) end

	print("========================================")
	print("  ✅ STARWEAVE Sanctuary Loaded & Live!")
	print("========================================")
end

-- ============================================================
-- DATA BOOTSTRAP (Concurrent & Fallback Protected)
-- ============================================================
task.spawn(function()
	local dataReady = ReplicatedStorage:WaitForChild("DataReady", 15) :: RemoteEvent?
	if dataReady then
		dataReady.OnClientEvent:Connect(function(data)
			if not isInitialized then
				initializeGame(data)
			else
				playerData = data
				if UIController then UIController.Update(data) end
				if WorldController then WorldController.Update(data) end
				if PetController then PetController.Update(data) end
			end
		end)
	end
end)

task.spawn(function()
	local getData = ReplicatedStorage:WaitForChild("GetData", 15) :: RemoteFunction?
	if getData then
		for _ = 1, 15 do
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

	-- Guaranteed Emergency Boot: If server data takes > 2.5s, spawn immediately!
	if not isInitialized then
		warn("[Client] Launching sanctuary with default profile...")
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
			if WorldController then WorldController.UpdatePlantVisual(plotIndex, data) end
			if UIController then UIController.Update(playerData) end
			if TutorialController then TutorialController.OnPlantPlanted(plotIndex) end

		elseif action == "Ready" then
			if playerData.Garden and playerData.Garden[plotIndex] then
				playerData.Garden[plotIndex].Plant = data
			end
			if SoundController then SoundController.Play("PlantReady") end
			if WorldController then WorldController.UpdatePlantVisual(plotIndex, data) end
			if UIController then UIController.Update(playerData) end

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
				if SoundController then
					if tier == "Primordial" then
						SoundController.Play("HarvestPrimordial")
					elseif harvestResult.IsRare then
						SoundController.Play("HarvestRare")
					else
						SoundController.Play("HarvestCommon")
					end
				end

				if WorldController and VFXController then
					local plotModel = WorldController._plotModels[plotIndex]
					local worldPos = Vector3.new(0, 1, 25)
					if plotModel then
						local soil = plotModel:FindFirstChild("Soil") :: BasePart?
						if soil then worldPos = soil.Position end
					end
					VFXController.SpawnHarvestBurst(worldPos, tier)
				end

				if NotificationUI then NotificationUI.ShowHarvest(harvestResult) end
				if TutorialController then TutorialController.OnPlantHarvested(plotIndex) end
			end

			if WorldController then WorldController.UpdatePlantVisual(plotIndex, nil) end
			if UIController then UIController.Update(playerData) end

		elseif action == "PlotUnlocked" then
			if playerData.Garden and playerData.Garden[plotIndex] then
				playerData.Garden[plotIndex].Unlocked = true
			end
			if SoundController then SoundController.Play("PlantReady") end
			if WorldController then WorldController.Update(playerData) end
			if UIController then UIController.Update(playerData) end
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
		if UIController then UIController.SetWeather(isActive) end
		if isActive and VFXController then
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
		if NotificationUI then NotificationUI.ShowAnnouncement(message, tier) end
		if (tier == "Celestial" or tier == "Primordial") and SoundController and VFXController then
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
			if NotificationUI then
				NotificationUI.ShowToast(`⭐ Gamepass Unlocked: {passName}!`, Color3.fromRGB(22, 101, 52), 4)
			end
			if SoundController then SoundController.Play("RebirthAscend") end
		elseif action == "MysterySeedResult" then
			local seedId, count = ...
			if NotificationUI then
				NotificationUI.ShowToast(`🎁 Mystery Box: Unveiled {count}x {seedId}!`, Color3.fromRGB(126, 34, 206), 4)
			end
			if SoundController then SoundController.Play("HarvestRare") end
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

		if NotificationUI then
			NotificationUI.ShowToast(`✨ ASCENDED TO REBIRTH LEVEL {rebirthData.NewLevel}!`, Color3.fromRGB(190, 24, 93), 6)
		end
		if WorldController then WorldController.Update(playerData) end
		if UIController then UIController.Update(playerData) end
	end)
end)
