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

-- ============================================================
-- INITIALIZE SYSTEMS IMMEDIATELY ON CLIENT START
-- ============================================================
print("  [Client] Initializing subsystems immediately...")

if SoundController then
	local s, err = pcall(function() SoundController.Init() end)
	if s then
		print("  [Client] SoundController ready ✓")
	else
		warn(`  [Client] SoundController Init error: {tostring(err)}`)
	end
end

if VFXController then
	local s, err = pcall(function() VFXController.Init() end)
	if s then
		print("  [Client] VFXController ready ✓")
	else
		warn(`  [Client] VFXController Init error: {tostring(err)}`)
	end
end

if WorldController then
	local s, err = pcall(function()
		WorldController.Init()
		WorldController.StartRenderLoop()
	end)
	if s then
		print("  [Client] WorldController (3D Sanctuary) ready ✓")
	else
		warn(`  [Client] WorldController Init error: {tostring(err)}`)
	end
end

if PetController then
	local s, err = pcall(function() PetController.Init() end)
	if s then
		print("  [Client] PetController ready ✓")
	else
		warn(`  [Client] PetController Init error: {tostring(err)}`)
	end
end

if UIController then
	local s, err = pcall(function() UIController.Init() end)
	if s then
		print("  [Client] UIController (HUD & Modals) ready ✓")
	else
		warn(`  [Client] UIController Init error: {tostring(err)}`)
	end
end

if TutorialController then
	local s, err = pcall(function() TutorialController.Init() end)
	if s then
		print("  [Client] TutorialController ready ✓")
	else
		warn(`  [Client] TutorialController Init error: {tostring(err)}`)
	end
end

-- Immediate initial UI populate (ensures TopBar, SeedBar, and Dock appear instantly)
local defaultStartingData = {
	Stardust = 0,
	NebulaGems = 0,
	Starlight = 0,
	Level = 1,
	Rebirth = { Level = 0, CosmicMultiplier = 1.0, ConstellationPoints = 0, ConstellationTree = {} },
	SeedInventory = { starseed_basic = 5 },
	Garden = {},
	PlantCollection = {},
	Pets = {},
}
for i = 1, 9 do
	table.insert(defaultStartingData.Garden, { Index = i, Unlocked = true, Plant = nil })
end
if UIController then UIController.Update(defaultStartingData) end
if WorldController then WorldController.Update(defaultStartingData) end

-- ============================================================
-- DATA SYNC HANDLER
-- ============================================================
local function onDataLoaded(data: any)
	if not data then return end
	playerData = data
	print("  [Client] Synchronizing live player profile...")
	if UIController then UIController.Update(data) end
	if WorldController then WorldController.Update(data) end
	if PetController then PetController.Update(data) end
	if TutorialController then TutorialController.CheckStart(data) end
end

-- Data Bootstrap Listener
task.spawn(function()
	local dataReady = ReplicatedStorage:WaitForChild("DataReady", 15) :: RemoteEvent?
	if dataReady then
		dataReady.OnClientEvent:Connect(onDataLoaded)
	end
end)

task.spawn(function()
	local getData = ReplicatedStorage:WaitForChild("GetData", 15) :: RemoteFunction?
	if getData then
		for _ = 1, 10 do
			if playerData then break end
			local success, data = pcall(function()
				return getData:InvokeServer()
			end)
			if success and data then
				onDataLoaded(data)
				break
			end
			task.wait(0.3)
		end
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

-- ============================================================
-- AFK MEDITATION ALERTS
-- ============================================================
task.spawn(function()
	local afkAlert = ReplicatedStorage:WaitForChild("AFKAlert", 20) :: RemoteEvent?
	if not afkAlert then return end

	afkAlert.OnClientEvent:Connect(function(action: string, amount: number)
		if action == "AFK_TICK" then
			if playerData then
				playerData.Stardust = (playerData.Stardust or 0) + amount
				if UIController then UIController.Update(playerData) end
			end
			if NotificationUI then
				NotificationUI.ShowToast(`✦ +{amount} Stardust (Cosmic Meditation)`, Color3.fromRGB(56, 189, 248), 2.5)
			end
			if SoundController then
				SoundController.Play("ButtonClick")
			end
		end
	end)
end)
