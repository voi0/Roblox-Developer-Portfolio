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

-- Ensure default backpack is enabled so player can select Stun Baton [1] and EMP Jammer [2]
task.spawn(function()
	for _ = 1, 30 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
		end)
		if ok then break end
		task.wait(0.3)
	end
end)

print("========================================")
print("  VAULT WARS Client Starting...")
print("========================================")

local controllersFolder = (script:FindFirstChild("Controllers") or script:WaitForChild("Controllers", 5)) :: Folder?
local uiFolder = (script:FindFirstChild("UI") or script:WaitForChild("UI", 5)) :: Folder?

local function safeRequire(parent: Folder?, name: string): any?
	if not parent then return nil end
	local child = parent:FindFirstChild(name) or parent:WaitForChild(name, 3) :: ModuleScript?
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

-- ── 1. MOUNT PRIMARY HUD IMMEDIATELY (Zero delay) ──
local VaultHUD = safeRequire(uiFolder, "VaultHUD")
if VaultHUD then
	local ok, err = pcall(function()
		VaultHUD.Create()
	end)
	if ok then
		print("  [Client] Tactical Bento HUD Mounted Instantly ✓")
	else
		warn("  [Client] Failed to mount VaultHUD:", tostring(err))
	end
else
	warn("  [Client] Critical: VaultHUD module could not be loaded!")
end

-- ── 2. INITIALIZE AUDIO, CAMERA & VISUAL ENGINES ──
local CameraController = safeRequire(controllersFolder, "CameraController")
if CameraController then
	pcall(function() CameraController.Init() end)
end

local SoundController = safeRequire(controllersFolder, "SoundController")
if SoundController then
	pcall(function() SoundController.Init() end)
end

local VFXController = safeRequire(controllersFolder, "VFXController")
if VFXController then
	pcall(function() VFXController.Init() end)
end

local AnimationEngine = safeRequire(controllersFolder, "AnimationEngine")
if AnimationEngine then
	pcall(function() AnimationEngine.Init() end)
end

local CustomPromptController = safeRequire(controllersFolder, "CustomPromptController")
if CustomPromptController then
	pcall(function() CustomPromptController.Init() end)
end

local DialogueController = safeRequire(controllersFolder, "DialogueController")
if DialogueController then
	pcall(function() DialogueController.Init() end)
end

local NotificationUI = safeRequire(uiFolder, "NotificationUI")
if NotificationUI then
	pcall(function() NotificationUI.Create() end)
end

-- ── 3. LOAD & ATTACH MODALS TO HUD ──
local UpgradesModal = safeRequire(uiFolder, "UpgradesModal")
local FusionModal = safeRequire(uiFolder, "FusionModal")
local DailyModal = safeRequire(uiFolder, "DailyModal")
local ProgressionModal = safeRequire(uiFolder, "ProgressionModal")
local ContractModal = safeRequire(uiFolder, "ContractModal")

local function closeOtherModals(activeModal: any?)
	if UpgradesModal and UpgradesModal ~= activeModal and UpgradesModal.IsOpen and UpgradesModal.IsOpen() then
		UpgradesModal.Close()
	end
	if FusionModal and FusionModal ~= activeModal and FusionModal.IsOpen and FusionModal.IsOpen() then
		FusionModal.Close()
	end
	if DailyModal and DailyModal ~= activeModal and DailyModal.IsOpen and DailyModal.IsOpen() then
		DailyModal.Close()
	end
	if ProgressionModal and ProgressionModal ~= activeModal and ProgressionModal.IsOpen and ProgressionModal.IsOpen() then
		ProgressionModal.Close()
	end
	if ContractModal and ContractModal ~= activeModal and ContractModal.IsOpen and ContractModal.IsOpen() then
		ContractModal.Close()
	end
end

if VaultHUD and VaultHUD._gui then
	if UpgradesModal then
		pcall(function()
			UpgradesModal.Create(VaultHUD._gui)
			VaultHUD.SetUpgradesCallback(function()
				if UpgradesModal.IsOpen() then
					UpgradesModal.Close()
				else
					closeOtherModals(UpgradesModal)
					UpgradesModal.Open()
				end
			end)
		end)
	end

	if FusionModal then
		pcall(function()
			FusionModal.Create(VaultHUD._gui)
			VaultHUD.SetFusionCallback(function()
				if FusionModal.IsOpen() then
					FusionModal.Close()
				else
					closeOtherModals(FusionModal)
					FusionModal.Open()
				end
			end)
		end)
	end

	if DailyModal then
		pcall(function()
			DailyModal.Create(VaultHUD._gui)
			VaultHUD.SetDailyCallback(function()
				if DailyModal.IsOpen() then
					DailyModal.Close()
				else
					closeOtherModals(DailyModal)
					DailyModal.Open()
				end
			end)
		end)
	end

	if ProgressionModal then
		pcall(function()
			ProgressionModal.Create(VaultHUD._gui)
			VaultHUD.SetProgressCallback(function()
				if ProgressionModal.IsOpen() then
					ProgressionModal.Close()
				else
					closeOtherModals(ProgressionModal)
					ProgressionModal.Open()
				end
			end)
		end)
	end

	if ContractModal then
		pcall(function()
			ContractModal.Create(VaultHUD._gui)
			VaultHUD.SetContractsCallback(function()
				if ContractModal.IsOpen() then
					ContractModal.Close()
				else
					closeOtherModals(ContractModal)
					ContractModal.Open()
				end
			end)
		end)
	end
end

local HeistController = safeRequire(controllersFolder, "HeistController")
if HeistController then
	pcall(function() HeistController.Init() end)
end

-- ============================================================
-- 3. DATA REPLICATION LISTENERS
-- ============================================================
local localPlayerData: any = nil

local function onDataReceived(data: any)
	if not data then return end
	if localPlayerData and data.BankedCash and localPlayerData.BankedCash then
		local gain = data.BankedCash - localPlayerData.BankedCash
		if gain > 0 then
			if SoundController then SoundController.Play("CashCollect") end
			if VFXController and player.Character then
				local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					VFXController.PlayCashDepositBurst(root.Position, `+${gain}`)
				end
			end
		end
	end
	localPlayerData = data
	if VaultHUD then VaultHUD.Update(data) end
	if UpgradesModal then UpgradesModal.Update(data) end
	if FusionModal then FusionModal.Update(data) end
	if DailyModal and DailyModal._isOpen then DailyModal.Refresh() end
	if ProgressionModal then ProgressionModal.Update(data) end
	if ContractModal and ContractModal.IsOpen() then ContractModal.Refresh() end
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
			if FusionModal then
				closeOtherModals(FusionModal)
				FusionModal.Open()
			end
		end)
	end

	local carryEvt = ReplicatedStorage:WaitForChild("CarryingStateChanged", 15) :: RemoteEvent?
	if carryEvt then
		carryEvt.OnClientEvent:Connect(function(isCarrying: boolean, payload: any?)
			if VaultHUD then
				VaultHUD.SetCarryingState(isCarrying, payload)
			end
		end)
	end

	-- Level Up Celebration listener
	local levelUpEvt = ReplicatedStorage:WaitForChild("LevelUpCelebration", 15) :: RemoteEvent?
	if levelUpEvt then
		levelUpEvt.OnClientEvent:Connect(function(level: number, rankTitle: string, newSP: number)
			if SoundController then SoundController.Play("Prestige") end
			if CameraController then CameraController.Shake(0.65, 0.45) end
			if VFXController and player.Character then
				local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					VFXController.PlayLevelUpCelebration(root.Position, level, rankTitle)
				end
			end
			if NotificationUI then
				NotificationUI.Show({
					Title = "LEVEL UP!",
					Message = `Promoted to Level {level} ({string.upper(rankTitle)})!\n+1 Skill Point available!`,
					Type = "Daily",
					Duration = 6,
				})
			end
		end)
	end

	-- Floating 3D XP Gained listener
	local xpGainedEvt = ReplicatedStorage:WaitForChild("XPGained", 15) :: RemoteEvent?
	if xpGainedEvt then
		xpGainedEvt.OnClientEvent:Connect(function(amount: number, reason: string, currentXP: number, reqXP: number)
			if VFXController and player.Character then
				local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					VFXController.PlayFloatingXP(root.Position, amount, reason)
				end
			end
		end)
	end

	-- Base Defense Turret Suppression Fire & Stun listeners
	local turretFire = ReplicatedStorage:WaitForChild("TurretFire", 15) :: RemoteEvent?
	if turretFire then
		turretFire.OnClientEvent:Connect(function(origin: Vector3, targetPos: Vector3, plotIdx: number)
			if SoundController then SoundController.Play("BatonHit") end
			if CameraController then CameraController.Shake(0.35, 0.2) end
			if VFXController then VFXController.PlayTurretFire(origin, targetPos) end
		end)
	end

	local turretDisabled = ReplicatedStorage:WaitForChild("TurretDisabled", 15) :: RemoteEvent?
	if turretDisabled then
		turretDisabled.OnClientEvent:Connect(function(plotIdx: number, dur: number)
			if CameraController then CameraController.Shake(0.7, 0.4) end
			if NotificationUI then
				NotificationUI.Show({
					Title = "EMP DISRUPTION!",
					Message = `Base Turret #{plotIdx} offline for {dur}s!`,
					Type = "Heist",
					Duration = 3,
				})
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
-- 4. KEYBOARD HOTKEYS: [U] UPGRADES, [B] FUSION, [Y] DAILY, [P] PROGRESS, [C] CONTRACTS, [F] TACKLE, [ESC] CLOSE
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.U then
		if UpgradesModal then
			if UpgradesModal.IsOpen() then
				UpgradesModal.Close()
			else
				closeOtherModals(UpgradesModal)
				UpgradesModal.Open()
			end
		end

	elseif input.KeyCode == Enum.KeyCode.B then
		if FusionModal then
			if FusionModal.IsOpen() then
				FusionModal.Close()
			else
				closeOtherModals(FusionModal)
				FusionModal.Open()
			end
		end

	elseif input.KeyCode == Enum.KeyCode.Y then
		if DailyModal then
			if DailyModal.IsOpen() then
				DailyModal.Close()
			else
				closeOtherModals(DailyModal)
				DailyModal.Open()
			end
		end

	elseif input.KeyCode == Enum.KeyCode.P then
		if ProgressionModal then
			if ProgressionModal.IsOpen() then
				ProgressionModal.Close()
			else
				closeOtherModals(ProgressionModal)
				ProgressionModal.Open()
			end
		end

	elseif input.KeyCode == Enum.KeyCode.C then
		if ContractModal then
			if ContractModal.IsOpen() then
				ContractModal.Close()
			else
				closeOtherModals(ContractModal)
				ContractModal.Open()
			end
		end

	-- [F] SECURITY TACKLE / ZAP INTRUDER
	elseif input.KeyCode == Enum.KeyCode.F then
		local tackleRF = ReplicatedStorage:FindFirstChild("SecurityTackle") :: RemoteFunction?
		if tackleRF then
			pcall(function()
				tackleRF:InvokeServer()
			end)
		end

	elseif input.KeyCode == Enum.KeyCode.Escape then
		closeOtherModals(nil)
	end
end)

print("========================================")
print("  VAULT WARS Client Online!")
print("========================================")
