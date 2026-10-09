--!strict
--[[
	HeistService.luau — Full Heist State Machine for VAULT WARS: STEAL & DEFEND TYCOON
	Orchestrates relic snatching, overhead carrying welds, speed debuffs,
	siren alarm beacons, and high-stakes bank deposits.
	Located in: ServerScriptService.Server.Services.HeistService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local HeistService = {}
HeistService._carrying = {} :: { [Player]: { Payload: Types.StolenItemPayload, Model: Part, Weld: Weld } }

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

local function getPlotService(): any?
	local svc = script.Parent:FindFirstChild("PlotService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

function HeistService.Init()
	print("  [HeistService] Initializing Physical Heist & Escape Engine...")

	-- Player death / disconnect handling
	Players.PlayerRemoving:Connect(function(player: Player)
		HeistService.DropLoot(player)
	end)

	print("  [HeistService] Physical Heist Engine online ✓")
end

-- ============================================================
-- START HEIST (SNATCH ITEM FROM CONVEYOR)
-- ============================================================
function HeistService.StartHeist(thief: Player, itemPart: Part, sourcePlot: any)
	if HeistService.IsCarryingLoot(thief) then return end

	local char = thief.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not root or not hum or hum.Health <= 0 then return end

	local value = itemPart:GetAttribute("Value") :: number or 100
	local itemName = itemPart:GetAttribute("ItemName") :: string or "Cash Stack"
	local tier = itemPart:GetAttribute("Tier") :: Types.RelicTier or "Common"

	-- Remove original part from conveyor
	itemPart:Destroy()

	-- Create Carry Model (Welded above head)
	local carryPart = Instance.new("Part")
	carryPart.Name = "CarriedLoot"
	carryPart.Size = Vector3.new(2.4, 1.6, 1.2)
	carryPart.Color = (tier == "Common") and Color3.fromRGB(234, 179, 8) or Color3.fromRGB(56, 189, 248)
	carryPart.Material = Enum.Material.Neon
	carryPart.CanCollide = false
	carryPart.Massless = true
	carryPart.CFrame = root.CFrame * CFrame.new(0, 3.4, 0)
	carryPart.Parent = char

	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = carryPart
	weld.C0 = CFrame.new(0, 3.4, 0)
	weld.Parent = carryPart

	-- Floating text above carry model
	local bGui = Instance.new("BillboardGui")
	bGui.Name = "StolenTag"
	bGui.Size = UDim2.new(0, 160, 0, 40)
	bGui.StudsOffset = Vector3.new(0, 1.5, 0)
	bGui.AlwaysOnTop = true
	bGui.Parent = carryPart

	local sLabel = Instance.new("TextLabel")
	sLabel.Size = UDim2.new(1, 0, 1, 0)
	sLabel.BackgroundTransparency = 1
	sLabel.Text = `🚨 STOLEN: {itemName}\n+${value}`
	sLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
	sLabel.TextSize = 12
	sLabel.Font = Enum.Font.GothamBlack
	sLabel.Parent = bGui

	-- Apply Carry Speed Debuff
	hum.WalkSpeed = Config.Heist.CarryDebuffSpeed
	hum.JumpPower = 35

	-- Listen for death
	hum.Died:Connect(function()
		HeistService.DropLoot(thief)
	end)

	local payload: Types.StolenItemPayload = {
		Id = itemName,
		Name = itemName,
		Tier = tier,
		Value = value,
		SourcePlotIndex = sourcePlot.Index,
		ThiefUserId = thief.UserId,
	}

	HeistService._carrying[thief] = {
		Payload = payload,
		Model = carryPart,
		Weld = weld,
	}

	-- Trigger base breach alarm
	HeistService.TriggerBreachAlarm(sourcePlot, thief)

	-- Broadcast high-tier heist to server
	if tier == "Epic" or tier == "Legendary" or tier == "Mythic" or tier == "Secret" then
		local bcastEvt = ReplicatedStorage:FindFirstChild("HeistBroadcast") :: RemoteEvent?
		if bcastEvt then
			local victimName = sourcePlot.Owner and sourcePlot.Owner.DisplayName or "Vacant"
			bcastEvt:FireAllClients(thief.DisplayName, victimName, itemName, value)
		end
	end

	print(`  [HeistService] {thief.Name} snatched {itemName} (${value}) from Plot #{sourcePlot.Index}!`)
end

-- ============================================================
-- TRIGGER BASE ALARM & SIREN
-- ============================================================
function HeistService.TriggerBreachAlarm(plot: any, intruder: Player)
	if plot.IsBreached then return end
	plot.IsBreached = true
	plot.BreachExpiry = os.clock() + Config.Heist.BreachAlarmDuration

	local siren = plot.Siren :: Part?
	local owner = plot.Owner :: Player?

	-- Notify Owner
	if owner then
		local breachEvt = ReplicatedStorage:FindFirstChild("BreachAlert") :: RemoteEvent?
		if breachEvt then
			breachEvt:FireClient(owner, intruder.DisplayName)
		end
	end

	-- Spin & Pulse Siren
	task.spawn(function()
		while os.clock() < plot.BreachExpiry do
			if siren and siren.Parent then
				siren.CFrame = siren.CFrame * CFrame.Angles(0, math.rad(24), 0)
			end
			task.wait(0.04)
		end
		plot.IsBreached = false
	end)
end

-- ============================================================
-- DEPOSIT STOLEN LOOT AT THIEF'S OWN BASE
-- ============================================================
function HeistService.DepositStolenLoot(thief: Player): boolean
	local carryInfo = HeistService._carrying[thief]
	if not carryInfo then return false end

	local payload = carryInfo.Payload
	local char = thief.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Config.Heist.NormalWalkSpeed
		hum.JumpPower = 50
	end

	-- Destroy visual carried part
	if carryInfo.Model and carryInfo.Model.Parent then
		carryInfo.Model:Destroy()
	end
	HeistService._carrying[thief] = nil

	-- Deduct from victim's unbanked stash
	local plotSvc = getPlotService()
	local dataSvc = getDataService()
	if plotSvc and dataSvc then
		local victimPlot = plotSvc.GetPlotByIndex(payload.SourcePlotIndex)
		if victimPlot and victimPlot.Owner then
			dataSvc.DeductUnbanked(victimPlot.Owner, payload.Value)
		end

		-- Record loot directly into thief's bank
		dataSvc.RecordSuccessfulHeist(thief, payload.Value)
	end

	-- Server-wide chat celebration
	local victimPlot = plotSvc and plotSvc.GetPlotByIndex(payload.SourcePlotIndex)
	local victimName = (victimPlot and victimPlot.Owner) and victimPlot.Owner.DisplayName or "Vault"

	local bcastEvt = ReplicatedStorage:FindFirstChild("HeistBroadcast") :: RemoteEvent?
	if bcastEvt then
		bcastEvt:FireAllClients(thief.DisplayName, victimName, payload.Name, payload.Value)
	end

	print(`  [HeistService] {thief.Name} successfully deposited stolen {payload.Name} (+${payload.Value})!`)
	return true
end

function HeistService.DropLoot(thief: Player)
	local carryInfo = HeistService._carrying[thief]
	if not carryInfo then return end

	local char = thief.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Config.Heist.NormalWalkSpeed
		hum.JumpPower = 50
	end

	if carryInfo.Model and carryInfo.Model.Parent then
		carryInfo.Model:Destroy()
	end
	HeistService._carrying[thief] = nil
end

function HeistService.IsCarryingLoot(player: Player): boolean
	return HeistService._carrying[player] ~= nil
end

return HeistService
