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
local ModelEngine = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelEngine"))

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

local function getProgressionService(): any?
	local svc = script.Parent:FindFirstChild("ProgressionService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

local function getContractService(): any?
	local svc = script.Parent:FindFirstChild("ContractService")
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
	local lastPlotDropTime: { [number]: number } = {}

	while true do
		task.wait(0.5)

		local plotSvc = getPlotService()
		local dataSvc = getDataService()
		local progSvc = getProgressionService()
		if not plotSvc or not dataSvc then continue end

		local now = os.clock()

		for i = 1, Config.Arena.PlotCount do
			local plot = plotSvc.GetPlotByIndex(i)
			if not plot or not plot.Owner then continue end

			local owner = plot.Owner
			local data = dataSvc.GetData(owner)
			if not data then continue end

			-- Tycoon progression: player must step on [ FREE ] Mint Press to begin minting!
			if not (data.PurchasedUpgrades and data.PurchasedUpgrades["MintPress"]) then
				continue
			end

			-- Check OverchargedPress perk / ConveyorOverclock for faster stamping cycle
			local dropInterval = Config.Mint.DropIntervalSeconds
			if data.PurchasedUpgrades and data.PurchasedUpgrades["ConveyorOverclock"] then
				dropInterval *= 0.5 -- 2x faster minting speed!
			end
			if dataSvc.HasPerk(owner, "OverchargedPress") then
				dropInterval *= 0.65
			end

			if now - (lastPlotDropTime[i] or 0) < dropInterval then
				continue
			end

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
			-- Compounding Treasury perk grants +50% stash capacity
			if dataSvc.HasPerk(owner, "CompoundingTreasury") then
				maxCapacity = math.floor(maxCapacity * 1.5)
			end

			if #cleanList >= maxCapacity then
				-- Conveyor is full, stall drop
				continue
			end

			lastPlotDropTime[i] = now

			-- Calculate Base Income
			local baseIncome = Config.Economy.GetConveyorIncome(data.ConveyorLevel, data.PrestigeTokens)
			if data.PurchasedUpgrades and data.PurchasedUpgrades["ConveyorOverclock"] then
				baseIncome *= 2 -- Overclock doubles bullion payout!
			end

			-- Midas Touch perk: +20% chance to drop pure gold bullion with 1.5x value
			if dataSvc.HasPerk(owner, "MidasTouch") and math.random() <= 0.20 then
				baseIncome = math.floor(baseIncome * 1.5)
			end

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

			-- Award active XP for minted bullion
			if progSvc then
				progSvc.AwardXP(owner, Config.Progression.XPAwards.MintItem, "Mint Item")
			end

			-- If Auto-Collector Drone is owned, directly deposit into bank
			if data.HasAutoCollector then
				dataSvc.AddBanked(owner, finalValue)
				if relicDef then
					dataSvc.AddRelic(owner, relicDef.Id, 1)
				end
				local contractSvc = getContractService()
				if contractSvc then
					contractSvc.ReportAction(owner, "BankBullion", finalValue)
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

	-- Animate hydraulic stamping press with steam puff particles
	if plot.StampingHead then
		local origHeadCF = plot.StampingHead.CFrame
		TweenService:Create(plot.StampingHead, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = origHeadCF * CFrame.new(0, -3.2, 0)
		}):Play()

		-- Steam particle puffs from vents
		for _, ventName in { "SteamVentL", "SteamVentR" } do
			local vent = plot.StampingHead:FindFirstChild(ventName) :: Attachment?
			if vent then
				local p = Instance.new("ParticleEmitter")
				p.Rate = 0
				p.Speed = NumberRange.new(5, 10)
				p.Lifetime = NumberRange.new(0.25, 0.45)
				p.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.4),
					NumberSequenceKeypoint.new(1, 2.0),
				})
				p.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.2),
					NumberSequenceKeypoint.new(1, 1.0),
				})
				p.Color = ColorSequence.new(Color3.fromRGB(241, 245, 249))
				p.Parent = vent
				p:Emit(12)
				Debris:AddItem(p, 0.6)
			end
		end

		task.delay(0.12, function()
			TweenService:Create(plot.StampingHead, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				CFrame = origHeadCF
			}):Play()
		end)
	end

	local isRelic = relicDef ~= nil
	local itemColor = isRelic and relicDef.Color or Color3.fromRGB(250, 204, 21)
	local itemName = isRelic and relicDef.Name or "Cash Stack"

	-- Root hitbox part (transparent container for physics/touch)
	local item = Instance.new("Part")
	item.Name = isRelic and ("Relic_" .. relicDef.Id) or "CashStack"
	item.Size = Vector3.new(2.4, 2.0, 2.4)
	item.Transparency = 1
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

	-- Start at head of conveyor
	local startCF = plot.CF * CFrame.new(8, 2.4, -Config.Mint.ConveyorLength / 2 + 2)
	local endCF = plot.CF * CFrame.new(8, 2.4, Config.Mint.ConveyorLength / 2 - 2)
	item.CFrame = startCF
	item.Parent = plot.Folder

	-- Build sculpted 3D visual model and weld to item root
	local relicId = isRelic and relicDef.Id or "GoldStack"
	local visualModel = ModelEngine.CreateRelicModel(relicId, startCF)
	visualModel.Parent = item
	for _, p in visualModel:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = item
			weld.Part1 = p
			weld.Parent = p
		end
	end

	-- Billboard display
	local bGui = Instance.new("BillboardGui")
	bGui.Name = "ValueTag"
	bGui.Size = UDim2.new(0, 130, 0, 36)
	bGui.StudsOffset = Vector3.new(0, 2.4, 0)
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
