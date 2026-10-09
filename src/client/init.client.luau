--!strict
--[[
	Client Boot Script — ESCAPE THE PACK
	Orchestrates Movement Physics, Round State Listener, Tactical Survival HUD,
	Tactical Locker Modal, and Chaser Tag Actions.
	Located in: StarterPlayerScripts.Client
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Disable default backpack so custom survival HUD is clean
task.spawn(function()
	for _ = 1, 15 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then break end
		task.wait(0.2)
	end
end)

print("========================================")
print("  ⚡ ESCAPE THE PACK Client Starting...")
print("========================================")

local controllersFolder = script:WaitForChild("Controllers", 15) :: Folder
local uiFolder = script:WaitForChild("UI", 15) :: Folder

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

local AbilityData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AbilityData"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MovementController = safeRequire(controllersFolder, "MovementController")
local RoundController = safeRequire(controllersFolder, "RoundController")
local SoundController = safeRequire(controllersFolder, "SoundController")
local HUDController = safeRequire(uiFolder, "HUDController")
local LockerModal = safeRequire(uiFolder, "LockerModal")

local playerData: any = {
	Coins = Config.Economy.StartingCoins,
	Gems = Config.Economy.StartingGems,
	EquippedAbility = "Cloak",
	UnlockedAbilities = { Cloak = true },
}

-- ============================================================
-- 1. INITIALIZE CLIENT SUBSYSTEMS
-- ============================================================
if HUDController then
	HUDController.Create()
	HUDController.UpdateData(playerData)

	if LockerModal and HUDController._gui then
		LockerModal.Create(HUDController._gui)
		LockerModal.Update(playerData)
		HUDController.SetLockerCallback(function()
			LockerModal.Toggle()
		end)
	end
end

if SoundController then
	pcall(function() SoundController.Init() end)
end

if MovementController then
	pcall(function() MovementController.Init() end)
	if HUDController then
		MovementController.OnDash = function(cooldownDuration: number)
			HUDController.TriggerDashCooldown(cooldownDuration)
		end
	end
end

if RoundController then
	pcall(function() RoundController.Init() end)
end

-- ============================================================
-- 2. CAMERA SETUP (Third person dynamic tracking)
-- ============================================================
local function setupCamera(char: Model)
	local humanoid = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then return end

	local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid

	player.CameraMinZoomDistance = 3
	player.CameraMaxZoomDistance = 45
end

if player.Character then
	task.spawn(setupCamera, player.Character)
end
player.CharacterAdded:Connect(setupCamera)

-- ============================================================
-- 3. DATA REPLICATION LISTENERS
-- ============================================================
local function onDataReceived(data: any)
	if not data then return end
	playerData = data
	if HUDController then HUDController.UpdateData(data) end
	if LockerModal then LockerModal.Update(data) end
end

task.spawn(function()
	local dataReady = ReplicatedStorage:WaitForChild("DataReady", 15) :: RemoteEvent?
	if dataReady then
		dataReady.OnClientEvent:Connect(onDataReceived)
	end

	local dataUpdate = ReplicatedStorage:WaitForChild("DataUpdate", 15) :: RemoteEvent?
	if dataUpdate then
		dataUpdate.OnClientEvent:Connect(onDataReceived)
	end

	local getData = ReplicatedStorage:WaitForChild("GetData", 15) :: RemoteFunction?
	if getData then
		for _ = 1, 10 do
			local success, data = pcall(function()
				return getData:InvokeServer()
			end)
			if success and data then
				onDataReceived(data)
				break
			end
			task.wait(0.3)
		end
	end
end)

-- ============================================================
-- 4. DOWNED & REVIVED EVENT LISTENERS
-- ============================================================
task.spawn(function()
	local downedEvt = ReplicatedStorage:WaitForChild("PlayerDowned", 15) :: RemoteEvent?
	if downedEvt then
		downedEvt.OnClientEvent:Connect(function(downedPlayer: Player, attacker: Player?)
			if downedPlayer == player then
				if HUDController then HUDController.SetDownedState(true) end
			end
		end)
	end

	local revivedEvt = ReplicatedStorage:WaitForChild("PlayerRevived", 15) :: RemoteEvent?
	if revivedEvt then
		revivedEvt.OnClientEvent:Connect(function(revivedPlayer: Player, reviver: Player?)
			if revivedPlayer == player then
				if HUDController then HUDController.SetDownedState(false) end
			end
		end)
	end
end)

-- ============================================================
-- 5. INPUT HANDLING: [Q] ABILITY, [B] LOCKER, [LMB] CHASER ATTACK
-- ============================================================
local lastAbilityUse = 0

local function tryUseAbility()
	local abilityId = playerData and playerData.EquippedAbility or "Cloak"
	local def = AbilityData[abilityId]
	if not def then return end

	local now = os.clock()
	if now - lastAbilityUse < def.Cooldown then return end

	local useAbilityRF = ReplicatedStorage:FindFirstChild("UseAbility") :: RemoteFunction?
	if useAbilityRF then
		local success, err = useAbilityRF:InvokeServer(abilityId)
		if success then
			lastAbilityUse = os.clock()
			if HUDController then
				HUDController.TriggerAbilityCooldown(def.Cooldown)
			end
			if SoundController then
				SoundController.Play("ButtonClick")
			end
		else
			warn(`[Ability] Failed to use {abilityId}: {tostring(err)}`)
		end
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	-- ⚡ USE EQUIPPED ABILITY [Q]
	if input.KeyCode == Enum.KeyCode.Q then
		tryUseAbility()

	-- ⚡ TOGGLE LOCKER [B] / [L]
	elseif input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.L then
		if LockerModal then LockerModal.Toggle() end

	-- ✕ CLOSE MODAL ON ESCAPE
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if LockerModal and LockerModal._isOpen then
			LockerModal.Close()
		end

	-- 🔪 CHASER KNIFE SLICE ON LEFT CLICK
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if HUDController and HUDController._currentRole == "Chaser" then
			local knifeEvt = ReplicatedStorage:FindFirstChild("KnifeSwing") :: RemoteEvent?
			if knifeEvt then
				knifeEvt:FireServer()
				if SoundController then
					SoundController.Play("ButtonClick")
				end
			end
		end
	end
end)

print("========================================")
print("  ✅ ESCAPE THE PACK Client Online!")
print("========================================")
