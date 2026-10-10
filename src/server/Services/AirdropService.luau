--!strict
--[[
	AirdropService.luau — Central Plaza Golden Crate Event for VAULT WARS: STEAL & DEFEND TYCOON
	Orchestrates scheduled high-stakes drops descending directly over the Central Plaza Monolith.
	Features:
	- Armored crate with animated warning flare & descent beam.
	- 3.5s channeled ProximityPrompt to crack the vault.
	- Massive $250,000 cash jackpot + guaranteed high-tier relic (Diamond / Void / Celestial).
	- Server-wide broadcast celebration.
	Located in: ServerScriptService.Server.Services.AirdropService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local RelicData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelicData"))

local AirdropService = {}
AirdropService._currentCrate = nil :: Model?
AirdropService._isDropping = false

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

local function createPart(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ============================================================
-- INITIALIZE AIRDROP LOOP
-- ============================================================
function AirdropService.Init()
	print("  [AirdropService] Initializing Central Plaza Golden Airdrop Engine...")

	-- Schedule drops: First drop in 45 seconds for immediate test / action, then every 8 minutes
	task.delay(45, function()
		AirdropService.SpawnAirdrop()
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Airdrop.IntervalSeconds)
			AirdropService.SpawnAirdrop()
		end
	end)

	print("  [AirdropService] Airdrop loop active (Interval: " .. tostring(Config.Airdrop.IntervalSeconds) .. "s) ✓")
end

-- ============================================================
-- SPAWN & ANIMATE AIRDROP CRATE
-- ============================================================
function AirdropService.SpawnAirdrop()
	if AirdropService._currentCrate then
		-- Clean up previous unopened crate if any
		AirdropService._currentCrate:Destroy()
		AirdropService._currentCrate = nil
	end

	local arena = Workspace:FindFirstChild("VaultWarsArena")
	if not arena then return end

	local crateModel = Instance.new("Model")
	crateModel.Name = "GoldenAirdropCrate"
	crateModel.Parent = arena
	AirdropService._currentCrate = crateModel
	AirdropService._isDropping = true

	-- Target landing spot: Just North of Central Monolith at (0, 3, -10)
	local targetPos = Vector3.new(0, 3, -10)
	local startPos = targetPos + Vector3.new(0, Config.Airdrop.DropAltitude, 0)

	-- 1. Main Crate Body
	local crateBody = createPart(
		"CrateBody",
		Vector3.new(6, 6, 6),
		CFrame.new(startPos),
		Color3.fromRGB(24, 24, 32),
		Enum.Material.Metal,
		crateModel
	)
	crateModel.PrimaryPart = crateBody

	-- Gold Trim Bands
	local trimTop = createPart(
		"TrimTop",
		Vector3.new(6.2, 0.6, 6.2),
		CFrame.new(startPos + Vector3.new(0, 2.7, 0)),
		Color3.fromRGB(250, 204, 21),
		Enum.Material.Neon,
		crateModel
	)
	local trimBottom = createPart(
		"TrimBottom",
		Vector3.new(6.2, 0.6, 6.2),
		CFrame.new(startPos - Vector3.new(0, 2.7, 0)),
		Color3.fromRGB(250, 204, 21),
		Enum.Material.Neon,
		crateModel
	)

	-- Beacon Beam (Sky pillar)
	local beacon = Instance.new("Part")
	beacon.Name = "DescentBeacon"
	beacon.Size = Vector3.new(0.8, 120, 0.8)
	beacon.CFrame = CFrame.new(startPos + Vector3.new(0, 60, 0))
	beacon.Color = Color3.fromRGB(250, 204, 21)
	beacon.Material = Enum.Material.Neon
	beacon.Transparency = 0.4
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.Parent = crateModel

	-- PointLight
	local pLight = Instance.new("PointLight")
	pLight.Color = Color3.fromRGB(250, 204, 21)
	pLight.Brightness = 4
	pLight.Range = 36
	pLight.Parent = crateBody

	-- Billboard GUI
	local bGui = Instance.new("BillboardGui")
	bGui.Name = "AirdropBillboard"
	bGui.Size = UDim2.new(0, 320, 0, 60)
	bGui.StudsOffset = Vector3.new(0, 4.5, 0)
	bGui.AlwaysOnTop = true
	bGui.Parent = crateBody

	local bLabel = Instance.new("TextLabel")
	bLabel.Size = UDim2.new(1, 0, 1, 0)
	bLabel.BackgroundTransparency = 1
	bLabel.Text = "GOLDEN VAULT AIRDROP INBOUND..."
	bLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
	bLabel.TextSize = 14
	bLabel.Font = Enum.Font.GothamBlack
	bLabel.Parent = bGui

	-- Broadcast incoming announcement
	local notifEvt = ReplicatedStorage:FindFirstChild("NotificationBroadcast") :: RemoteEvent?
	if notifEvt then
		notifEvt:FireAllClients({
			Title = "GOLDEN AIRDROP INBOUND!",
			Message = "A massive vault crate is descending onto the Central Plaza!",
			Type = "Airdrop",
			Duration = 5,
		})
	end

	-- 2. Animate Descent over DescentDuration (12s)
	local duration = Config.Airdrop.DescentDuration
	local tInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local tweenBody = TweenService:Create(crateBody, tInfo, { CFrame = CFrame.new(targetPos) })
	local tweenTop = TweenService:Create(trimTop, tInfo, { CFrame = CFrame.new(targetPos + Vector3.new(0, 2.7, 0)) })
	local tweenBottom = TweenService:Create(trimBottom, tInfo, { CFrame = CFrame.new(targetPos - Vector3.new(0, 2.7, 0)) })
	local tweenBeacon = TweenService:Create(beacon, tInfo, { CFrame = CFrame.new(targetPos + Vector3.new(0, 60, 0)) })

	tweenBody:Play()
	tweenTop:Play()
	tweenBottom:Play()
	tweenBeacon:Play()

	task.delay(duration, function()
		if not crateModel or not crateModel.Parent then return end
		AirdropService._isDropping = false

		-- Ground impact flare
		beacon:Destroy()
		bLabel.Text = "CENTRAL GOLDEN CRATE\n[HOLD E] TO CRACK ($250K + RELIC)"
		bLabel.Font = Enum.Font.BuilderSansExtraBold

		-- Setup Proximity Prompt
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = "CENTRAL GOLDEN AIRDROP"
		prompt.ActionText = "CRACK CRATE"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = Config.Airdrop.ChannelDurationSeconds -- 3.5s
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.Parent = crateBody

		prompt.Triggered:Connect(function(winner: Player)
			AirdropService.CrackAirdrop(winner, crateModel, targetPos)
		end)
	end)
end

-- ============================================================
-- CRACK AIRDROP & AWARD REWARDS
-- ============================================================
function AirdropService.CrackAirdrop(winner: Player, crateModel: Model, pos: Vector3)
	if not crateModel or not crateModel.Parent then return end

	local dataSvc = getDataService()
	if not dataSvc then return end

	-- Award cash
	local cashJackpot = Config.Airdrop.JackpotCash
	dataSvc.AddBankedCash(winner, cashJackpot)

	-- Guaranteed high tier relic roll (Legendary 60%, Mythic 35%, Secret Celestial 5%)
	local relicRoll = math.random(1, 100)
	local relicDef = RelicData.Catalog.DiamondSkull
	if relicRoll <= 5 then
		relicDef = RelicData.Catalog.CelestialCrown
	elseif relicRoll <= 40 then
		relicDef = RelicData.Catalog.VoidChronometer
	end

	dataSvc.AddRelic(winner, relicDef.Id, 1)

	-- Award massive XP for cracking central airdrop (+500 XP)
	local progMod = script.Parent:FindFirstChild("ProgressionService")
	if progMod then
		local ps = require(progMod :: ModuleScript)
		ps.AwardXP(winner, Config.Progression.XPAwards.AirdropCracked, "Airdrop Cracked")
	end

	-- Destroy crate
	crateModel:Destroy()
	AirdropService._currentCrate = nil

	-- Explosion Shockwave FX
	local shock = Instance.new("Part")
	shock.Name = "AirdropShockwave"
	shock.Size = Vector3.new(4, 0.4, 4)
	shock.CFrame = CFrame.new(pos)
	shock.Color = Color3.fromRGB(250, 204, 21)
	shock.Material = Enum.Material.Neon
	shock.Anchored = true
	shock.CanCollide = false
	shock.Parent = Workspace

	local shockTween = TweenService:Create(shock, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(44, 0.2, 44),
		Transparency = 1,
	})
	shockTween:Play()
	shockTween.Completed:Connect(function()
		shock:Destroy()
	end)

	-- Server broadcast
	local notifEvt = ReplicatedStorage:FindFirstChild("NotificationBroadcast") :: RemoteEvent?
	if notifEvt then
		notifEvt:FireAllClients({
			Title = "AIRDROP CRACKED!",
			Message = `{winner.DisplayName} cracked the Golden Crate! ($250K + {relicDef.Name})`,
			Type = "Jackpot",
			Duration = 7,
		})
	end

	print(`  [AirdropService] {winner.Name} cracked Golden Crate! +${cashJackpot} & {relicDef.Name}`)
end

return AirdropService
