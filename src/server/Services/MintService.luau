--!strict
--[[
	MintService.luau — Automated Conveyor Mint & RNG Relic Spawner for VAULT WARS
	Periodically mints cash stacks and rare unbanked relics onto player conveyors,
	broadcasting server alerts when Mythic and Secret relics drop.
	Located in: ServerScriptService.Server.Services.MintService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RelicData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelicData"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local MintService = {}
MintService._activeItems = {} :: { [number]: { Instance } }

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

local function getHeistService(): any?
	local svc = script.Parent:FindFirstChild("HeistService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

function MintService.Init()
	print("  [MintService] Initializing Conveyor Mint & RNG Relic Engine...")

	-- Start Minting Loop
	task.spawn(MintService._mintLoop)

	print("  [MintService] Conveyor Mint Engine online ✓")
end

function MintService._mintLoop()
	while true do
		task.wait(Config.Mint.DropIntervalSeconds)

		local plotSvc = getPlotService()
		local dataSvc = getDataService()
		if not plotSvc or not dataSvc then continue end

		for i = 1, Config.Arena.PlotCount do
			local plot = plotSvc.GetPlotByIndex(i)
			if not plot or not plot.Owner then continue end

			local owner = plot.Owner
			local data = dataSvc.GetData(owner)
			if not data then continue end

			-- Check active conveyor capacity
			if not MintService._activeItems[i] then
				MintService._activeItems[i] = {}
			end

			-- Clean dead references
			local cleanList = {}
			for _, item in MintService._activeItems[i] do
				if item and item.Parent then
					table.insert(cleanList, item)
				end
			end
			MintService._activeItems[i] = cleanList

			local maxCapacity = Config.Mint.MaxUnbankedItemsPerPlot
			if data.HasDoubleCapacity then
				maxCapacity *= 2
			end

			if #cleanList >= maxCapacity then
				-- Conveyor is full, stall drop
				continue
			end

			-- Calculate Base Income
			local baseIncome = Config.Economy.GetConveyorIncome(data.ConveyorLevel, data.PrestigeTokens)
			local isRelic = math.random() <= Config.Mint.RelicRNGChance
			local finalValue = baseIncome
			local relicDef: Types.RelicDefinition? = nil

			if isRelic then
				relicDef = RelicData.RollRandomRelic(1)
				finalValue = math.floor(baseIncome * relicDef.BaseMultiplier)

				if relicDef.Broadcast then
					local mintedEvt = ReplicatedStorage:FindFirstChild("RelicMinted") :: RemoteEvent?
					if mintedEvt then
						mintedEvt:FireAllClients(owner.DisplayName, relicDef.Name, relicDef.Tier, finalValue)
					end
				end
			end

			-- If Auto-Collector Drone is owned, directly deposit into bank
			if data.HasAutoCollector then
				dataSvc.AddBanked(owner, finalValue)
				if relicDef then
					dataSvc.AddRelic(owner, relicDef.Id, 1)
				end
			else
				dataSvc.AddUnbanked(owner, finalValue)
				-- Spawn physical visual item on conveyor
				MintService.SpawnConveyorItem(plot, finalValue, relicDef)
			end
		end
	end
end

function MintService.SpawnConveyorItem(plot: any, value: number, relicDef: Types.RelicDefinition?)
	local conveyor = plot.Conveyor :: Part?
	if not conveyor then return end

	local isRelic = relicDef ~= nil
	local itemSize = isRelic and Vector3.new(2.4, 1.8, 1.2) or Vector3.new(2.2, 0.8, 1.4)
	local itemColor = isRelic and relicDef.Color or Color3.fromRGB(250, 204, 21)
	local itemMat = isRelic and relicDef.Material or Enum.Material.SmoothPlastic
	local itemName = isRelic and relicDef.Name or "Cash Stack"

	local item = Instance.new("Part")
	item.Name = isRelic and ("Relic_" .. relicDef.Id) or "CashStack"
	item.Size = itemSize
	item.Color = itemColor
	item.Material = itemMat
	item.Anchored = true
	item.CanCollide = false
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth

	-- Tag attributes for heist snatching
	item:SetAttribute("Value", value)
	item:SetAttribute("PlotIndex", plot.Index)
	item:SetAttribute("ItemName", itemName)
	item:SetAttribute("Tier", isRelic and relicDef.Tier or "Common")
	item:SetAttribute("RelicId", isRelic and relicDef.Id or "")

	-- Billboard display
	local bGui = Instance.new("BillboardGui")
	bGui.Name = "ValueTag"
	bGui.Size = UDim2.new(0, 120, 0, 36)
	bGui.StudsOffset = Vector3.new(0, 1.8, 0)
	bGui.AlwaysOnTop = true
	bGui.Parent = item

	local tagLabel = Instance.new("TextLabel")
	tagLabel.Size = UDim2.new(1, 0, 1, 0)
	tagLabel.BackgroundTransparency = 1
	tagLabel.Text = isRelic and `{itemName}\n+${value}` or `+${value}`
	tagLabel.TextColor3 = itemColor
	tagLabel.TextSize = 11
	tagLabel.Font = Enum.Font.GothamBlack
	tagLabel.Parent = bGui

	-- Start at head of conveyor (local Z = -conveyorLength/2 + 2)
	local startCF = plot.CF * CFrame.new(8, 3.8, -Config.Mint.ConveyorLength / 2 + 2)
	local endCF = plot.CF * CFrame.new(8, 3.8, Config.Mint.ConveyorLength / 2 - 2)
	item.CFrame = startCF
	item.Parent = plot.Folder

	table.insert(MintService._activeItems[plot.Index], item)

	-- Tween along conveyor belt
	local travelTime = Config.Mint.ConveyorLength / Config.Mint.ConveyorSpeed
	local tween = TweenService:Create(item, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {
		CFrame = endCF
	})
	tween:Play()

	-- Touch trigger for owner auto-bank or enemy heist
	local touchConn: RBXScriptConnection? = nil
	touchConn = item.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player or not item.Parent then return end

		local plotOwner = plot.Owner
		if player == plotOwner then
			-- Owner collected from conveyor -> auto-deposit to unbanked stash or bank directly
			-- Item disappears from belt
			if touchConn then touchConn:Disconnect() end
			if relicDef then
				local dataSvc = getDataService()
				if dataSvc then
					dataSvc.AddRelic(player, relicDef.Id, 1)
				end
			end
			item:Destroy()
		else
			-- Intruder touches unbanked item -> HEIST SNATCH!
			local heistSvc = getHeistService()
			if heistSvc and not heistSvc.IsCarryingLoot(player) then
				if touchConn then touchConn:Disconnect() end
				heistSvc.StartHeist(player, item, plot)
			end
		end
	end)

	-- Auto-deposit at end of conveyor if uncollected by intruder
	task.delay(travelTime + 0.5, function()
		if item and item.Parent and not item:GetAttribute("IsHeisted") then
			if touchConn then touchConn:Disconnect() end
			if relicDef and plot.Owner then
				local dataSvc = getDataService()
				if dataSvc then
					dataSvc.AddRelic(plot.Owner, relicDef.Id, 1)
				end
			end
			item:Destroy()
		end
	end)

	-- Safety cleanup
	Debris:AddItem(item, 45)
end

return MintService
