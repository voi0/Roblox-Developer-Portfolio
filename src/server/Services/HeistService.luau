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

	local tackleRF = ReplicatedStorage:FindFirstChild("SecurityTackle") :: RemoteFunction?
	if not tackleRF then
		tackleRF = Instance.new("RemoteFunction")
		tackleRF.Name = "SecurityTackle"
		tackleRF.Parent = ReplicatedStorage
	end
	tackleRF.OnServerInvoke = function(defender: Player, targetPlayer: Player?)
		return HeistService.TackleThief(defender, targetPlayer)
	end

	local carryEvt = ReplicatedStorage:FindFirstChild("CarryingStateChanged") :: RemoteEvent?
	if not carryEvt then
		carryEvt = Instance.new("RemoteEvent")
		carryEvt.Name = "CarryingStateChanged"
		carryEvt.Parent = ReplicatedStorage
	end

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
	local relicId = itemPart:GetAttribute("RelicId") :: string or ""

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
		Id = (relicId ~= "") and relicId or itemName,
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

	-- Notify thief client of carry state (triggers 25 R$ Adrenaline UI)
	local carryEvt = ReplicatedStorage:FindFirstChild("CarryingStateChanged") :: RemoteEvent?
	if carryEvt then
		carryEvt:FireClient(thief, true, payload)
	end

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

	-- Notify thief client that carrying has ended
	local carryEvt = ReplicatedStorage:FindFirstChild("CarryingStateChanged") :: RemoteEvent?
	if carryEvt then
		carryEvt:FireClient(thief, false, nil)
	end

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

		-- If stolen item is a relic, deposit into thief's RelicInventory
		if payload.Id and payload.Id ~= "" and payload.Id ~= "Cash Stack" then
			dataSvc.AddRelic(thief, payload.Id, 1)
		end
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

	local carryEvt = ReplicatedStorage:FindFirstChild("CarryingStateChanged") :: RemoteEvent?
	if carryEvt then
		carryEvt:FireClient(thief, false, nil)
	end
end

function HeistService.TackleThief(defender: Player, targetPlayer: Player?): (boolean, string?)
	local char = defender.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then return false, "No character" end

	-- Find target if not provided
	local target: Player? = targetPlayer
	if not target then
		local closestDist = 9.0
		for _, p in Players:GetPlayers() do
			if p ~= defender and HeistService.IsCarryingLoot(p) then
				local pChar = p.Character
				local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart") :: BasePart?
				if pRoot then
					local dist = (root.Position - pRoot.Position).Magnitude
					if dist <= closestDist then
						closestDist = dist
						target = p
					end
				end
			end
		end
	end

	if not target then return false, "No thief in range" end
	local carryInfo = HeistService._carrying[target]
	if not carryInfo then return false, "Target not carrying loot" end

	local tChar = target.Character
	local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
	if not tRoot or not tHum then return false, "Invalid target" end

	if (root.Position - tRoot.Position).Magnitude > 9.5 then
		return false, "Thief too far"
	end

	local payload = carryInfo.Payload
	HeistService.DropLoot(target)

	task.spawn(function()
		local origSpeed = tHum.WalkSpeed
		tHum.WalkSpeed = 0
		tHum.PlatformStand = true

		local away = (tRoot.Position - root.Position).Unit
		tRoot.AssemblyLinearVelocity = away * 40 + Vector3.new(0, 15, 0)

		task.wait(2.0)
		if tHum and tHum.Parent then
			tHum.PlatformStand = false
			tHum.WalkSpeed = Config.Heist.NormalWalkSpeed
		end
	end)

	local plotSvc = getPlotService()
	local dataSvc = getDataService()
	local defenderPlot = plotSvc and plotSvc.GetPlotForPlayer(defender)
	if defenderPlot and defenderPlot.Index == payload.SourcePlotIndex and dataSvc then
		dataSvc.AddUnbanked(defender, payload.Value)
	end

	if dataSvc then
		dataSvc.AddBanked(defender, 500)
	end

	local bcast = ReplicatedStorage:FindFirstChild("HeistBroadcast") :: RemoteEvent?
	if bcast then
		bcast:FireAllClients(defender.DisplayName, target.DisplayName, "TACKLE_STOPPED", payload.Value)
	end

	return true, `Intercepted {target.DisplayName}!`
end

function HeistService.IsCarryingLoot(player: Player): boolean
	return HeistService._carrying[player] ~= nil
end

return HeistService
