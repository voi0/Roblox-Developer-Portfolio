--!strict
--[[
	Client Boot Script — VAULT WARS: STEAL & DEFEND TYCOON
	Orchestrates Tactical Glassmorphic HUD, Upgrades Center, and Heist Alerts.
	Located in: StarterPlayerScripts.Client
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Disable default backpack so custom HUD is clean
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
print("  ⚡ VAULT WARS Client Starting...")
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

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local VaultHUD = safeRequire(uiFolder, "VaultHUD")
local UpgradesModal = safeRequire(uiFolder, "UpgradesModal")
local FusionModal = safeRequire(uiFolder, "FusionModal")
local HeistController = safeRequire(controllersFolder, "HeistController")

local localPlayerData: any = nil

-- ============================================================
-- 1. INITIALIZE UI & CONTROLLERS
-- ============================================================
if VaultHUD then
	VaultHUD.Create()

	if UpgradesModal and VaultHUD._gui then
		UpgradesModal.Create(VaultHUD._gui)
		VaultHUD.SetUpgradesCallback(function()
			UpgradesModal.Toggle()
		end)
	end

	if FusionModal and VaultHUD._gui then
		FusionModal.Create(VaultHUD._gui)
		VaultHUD.SetFusionCallback(function()
			FusionModal.Toggle()
		end)
	end
end

if HeistController then
	pcall(function() HeistController.Init() end)
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

	player.CameraMinZoomDistance = 4
	player.CameraMaxZoomDistance = 50
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
	localPlayerData = data
	if VaultHUD then VaultHUD.Update(data) end
	if UpgradesModal then UpgradesModal.Update(data) end
	if FusionModal then FusionModal.Update(data) end
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

	local openFusion = ReplicatedStorage:WaitForChild("OpenFusionModal", 15) :: RemoteEvent?
	if openFusion then
		openFusion.OnClientEvent:Connect(function()
			if FusionModal then FusionModal.Open() end
		end
	end

	local carryEvt = ReplicatedStorage:WaitForChild("CarryingStateChanged", 15) :: RemoteEvent?
	if carryEvt then
		carryEvt.OnClientEvent:Connect(function(isCarrying: boolean, payload: any?)
			if VaultHUD then
				VaultHUD.SetCarryingState(isCarrying, payload)
			end
		end)
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
-- 4. KEYBOARD HOTKEYS: [U] UPGRADES, [B] FUSION, [F] TACKLE, [ESC] CLOSE
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.U then
		if UpgradesModal then UpgradesModal.Toggle() end

	elseif input.KeyCode == Enum.KeyCode.B then
		if FusionModal then FusionModal.Toggle() end

	-- ⚡ [F] SECURITY TACKLE / ZAP INTRUDER
	elseif input.KeyCode == Enum.KeyCode.F then
		local tackleRF = ReplicatedStorage:FindFirstChild("SecurityTackle") :: RemoteFunction?
		if tackleRF then
			pcall(function()
				tackleRF:InvokeServer()
			end)
		end

	elseif input.KeyCode == Enum.KeyCode.Escape then
		if UpgradesModal and UpgradesModal._isOpen then
			UpgradesModal.Close()
		end
		if FusionModal and FusionModal._isOpen then
			FusionModal.Close()
		end
	end
end)

print("========================================")
print("  ✅ VAULT WARS Client Online!")
print("========================================")
