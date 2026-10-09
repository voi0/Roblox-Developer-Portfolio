--!strict
--[[
	HeistController.luau — Client Heist Event Listener & Tactical Feedback for VAULT WARS
	Coordinates Breach Alarms, Toast Alerts, SFX, and Camera Trauma.
	Located in: StarterPlayerScripts.Client.Controllers.HeistController
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local HeistController = {}

local function getVaultHUD(): any?
	local uiFolder = script.Parent.Parent:FindFirstChild("UI")
	local hud = uiFolder and uiFolder:FindFirstChild("VaultHUD")
	if hud then return require(hud :: ModuleScript) end
	return nil
end

local function getNotificationUI(): any?
	local uiFolder = script.Parent.Parent:FindFirstChild("UI")
	local notif = uiFolder and uiFolder:FindFirstChild("NotificationUI")
	if notif then return require(notif :: ModuleScript) end
	return nil
end

local function getSoundController(): any?
	local snd = script.Parent:FindFirstChild("SoundController")
	if snd then return require(snd :: ModuleScript) end
	return nil
end

local function getVFXController(): any?
	local vfx = script.Parent:FindFirstChild("VFXController")
	if vfx then return require(vfx :: ModuleScript) end
	return nil
end

function HeistController.Init()
	print("  [HeistController] Initializing Client Heist Listener...")

	-- 1. Breach Alert (Your vault is being raided!)
	local breachEvt = ReplicatedStorage:WaitForChild("BreachAlert", 15) :: RemoteEvent?
	if breachEvt then
		breachEvt.OnClientEvent:Connect(function(intruderName: string)
			local hud = getVaultHUD()
			if hud then hud.ShowBreachAlert(intruderName) end

			local notif = getNotificationUI()
			if notif then
				notif.ShowToast("Heist", "🚨 SECURITY BREACH!", `{intruderName} has entered your vault!`)
			end

			local snd = getSoundController()
			if snd then snd.Play("BreachAlarm") end

			local vfx = getVFXController()
			if vfx then vfx.AddCameraTrauma(0.4) end
		end)
	end

	-- 2. Rare Relic Minted Broadcast
	local relicEvt = ReplicatedStorage:WaitForChild("RelicMinted", 15) :: RemoteEvent?
	if relicEvt then
		relicEvt.OnClientEvent:Connect(function(ownerName: string, relicName: string, tier: string, value: number)
			local notif = getNotificationUI()
			if notif then
				notif.ShowToast("Relic", `🌟 {tier} Relic Minted!`, `{ownerName} discovered {relicName} (+${value})`)
			end

			local snd = getSoundController()
			if snd then snd.Play("RelicDropRare") end
		end)
	end

	-- 3. Successful Heist Broadcast & Security Tackle
	local heistEvt = ReplicatedStorage:WaitForChild("HeistBroadcast", 15) :: RemoteEvent?
	if heistEvt then
		heistEvt.OnClientEvent:Connect(function(thiefName: string, victimName: string, itemName: string, value: number)
			local notif = getNotificationUI()
			local snd = getSoundController()
			local vfx = getVFXController()

			if itemName == "TACKLE_STOPPED" then
				if notif then
					notif.ShowToast("Defense", "⚡ Thief Tackled!", `{thiefName} zapped {victimName} and recovered ${value}!`)
				end
				if snd then snd.Play("TackleHit") end
				if vfx and player.Character then
					local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then vfx.PlayTackleImpact(root.Position) end
				end
			else
				if notif then
					notif.ShowToast("Heist", "🚨 Successful Heist!", `{thiefName} stole {itemName} (+${value}) from {victimName}!`)
				end
				if snd then snd.Play("CashCollect") end
			end
		end)
	end

	-- 4. Relic Fusion Broadcast
	local fusionEvt = ReplicatedStorage:WaitForChild("RelicFused", 15) :: RemoteEvent?
	if fusionEvt then
		fusionEvt.OnClientEvent:Connect(function(playerName: string, relicName: string, isRadiant: boolean, bonusCash: number)
			local notif = getNotificationUI()
			local snd = getSoundController()
			local vfx = getVFXController()

			if notif then
				if isRadiant then
					notif.ShowToast("Fusion", "🌟 Radiant Mutation!", `{playerName} forged Radiant {relicName}! (+${bonusCash} Bonus)`)
				else
					notif.ShowToast("Fusion", "🔮 Relic Synthesis", `{playerName} synthesized {relicName}!`)
				end
			end
			if snd then snd.Play("FusionSynth") end
			if isRadiant and vfx and player.Character then
				local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then vfx.PlayRadiantAscent(root.Position, relicName) end
			end
		end)
	end

	print("  [HeistController] Client Heist Listener online ✓")
end

return HeistController
