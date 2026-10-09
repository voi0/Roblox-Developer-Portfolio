--!strict
--[[
	FusionService.luau — Relic Synthesis & Radiant Mutation Engine for VAULT WARS
	Allows tycoons to combine 3 duplicate relics of the same tier into 1 higher-tier relic,
	featuring a 20% chance for a Supercharged Radiant Mutation (+50% bonus value).
	Located in: ServerScriptService.Server.Services.FusionService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RelicData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelicData"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local FusionService = {}

-- Progression ladder for fusion:
-- GoldStack -> EmeraldMatrix -> RubyArtifact -> DiamondSkull -> VoidChronometer -> CelestialCrown
local FUSION_LADDER: { [string]: string } = {
	GoldStack = "EmeraldMatrix",
	EmeraldMatrix = "RubyArtifact",
	RubyArtifact = "DiamondSkull",
	DiamondSkull = "VoidChronometer",
	VoidChronometer = "CelestialCrown",
}

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
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

function FusionService.Init()
	print("  [FusionService] Initializing Relic Synthesis & Radiant Mutation Altar...")

	local fuseRF = ReplicatedStorage:FindFirstChild("FuseRelicsRequest") :: RemoteFunction?
	if not fuseRF then
		fuseRF = Instance.new("RemoteFunction")
		fuseRF.Name = "FuseRelicsRequest"
		fuseRF.Parent = ReplicatedStorage
	end

	fuseRF.OnServerInvoke = function(player: Player, relicId: string)
		return FusionService.FuseRelics(player, relicId)
	end

	local fusionEvt = ReplicatedStorage:FindFirstChild("RelicFused") :: RemoteEvent?
	if not fusionEvt then
		fusionEvt = Instance.new("RemoteEvent")
		fusionEvt.Name = "RelicFused"
		fusionEvt.Parent = ReplicatedStorage
	end

	print("  [FusionService] Relic Fusion Altar online ✓")
end

function FusionService.FuseRelics(player: Player, relicId: string): (boolean, string, any?)
	local dataSvc = getDataService()
	if not dataSvc then return false, "DataService unavailable", nil end

	local data = dataSvc.GetData(player)
	if not data then return false, "No player data found", nil end

	local currentCount = (data.RelicInventory and data.RelicInventory[relicId]) or 0
	if currentCount < 3 then
		return false, `Need 3x copies to fuse (You have {currentCount})`, nil
	end

	local currentDef = RelicData.Catalog[relicId]
	if not currentDef then
		return false, "Invalid relic ID", nil
	end

	local nextRelicId = FUSION_LADDER[relicId]
	local isMaxTier = (nextRelicId == nil)

	-- Deduct 3 copies
	if not dataSvc.RemoveRelic(player, relicId, 3) then
		return false, "Failed to deduct relics", nil
	end

	local progSvc = getProgressionService()
	local hasAlchemical = progSvc and progSvc.HasPerk(player, "AlchemicalResonance")
	-- Alchemical Resonance doubles Supercharged Mutation chance to 40% (vs 20%)
	local radiantThreshold = hasAlchemical and 40 or 20
	local isRadiant = (math.random(1, 100) <= radiantThreshold)

	-- Award XP for successful synthesis
	if progSvc then
		progSvc.AwardXP(player, Config.Progression.XPAwards.FuseRelic, "Relic Synthesized")
	end

	if isMaxTier then
		-- Fusing 3 Celestial Crowns grants 1 Radiant Crown + $100M Jackpot
		local bonusCash = isRadiant and 150_000_000 or 100_000_000
		dataSvc.AddRelic(player, "CelestialCrown", 1)
		dataSvc.AddBanked(player, bonusCash)

		local fusionEvt = ReplicatedStorage:FindFirstChild("RelicFused") :: RemoteEvent?
		if fusionEvt then
			fusionEvt:FireAllClients(player.DisplayName, "Celestial Archon Crown (Radiant Zenith)", true, bonusCash)
		end

		return true, `MAX SYNTHESIS! Awarded Celestial Archon Crown & +${bonusCash}!`, {
			NextRelicId = "CelestialCrown",
			IsRadiant = true,
			BonusCash = bonusCash,
		}
	end

	local nextDef = RelicData.Catalog[nextRelicId]
	if not nextDef then
		return false, "Next relic definition not found", nil
	end

	-- Add next tier relic
	dataSvc.AddRelic(player, nextRelicId, 1)

	local bonusCash = 0
	if isRadiant then
		-- Radiant Mutation grants +50% bonus cash payout directly into bank!
		local baseIncome = Config.Economy.GetConveyorIncome(data.ConveyorLevel, data.PrestigeTokens)
		bonusCash = math.floor(baseIncome * nextDef.BaseMultiplier * 1.5)
		dataSvc.AddBanked(player, bonusCash)
	end

	-- Broadcast if Radiant or high tier (Epic+)
	local fusionEvt = ReplicatedStorage:FindFirstChild("RelicFused") :: RemoteEvent?
	if fusionEvt then
		fusionEvt:FireAllClients(player.DisplayName, nextDef.Name, isRadiant, bonusCash)
	end

	-- Report contract action
	local contractSvc = getContractService()
	if contractSvc then
		contractSvc.ReportAction(player, "SynthesizeRelic", 1)
	end

	local msg = isRadiant 
		and `🌟 RADIANT MUTATION! Forged {nextDef.Name} with +${bonusCash} bonus!`
		or `Successfully synthesized {nextDef.Name}!`

	print(`  [FusionService] {player.Name} fused 3x {currentDef.Name} -> {nextDef.Name} (Radiant: {isRadiant})`)

	return true, msg, {
		NextRelicId = nextRelicId,
		NextRelicName = nextDef.Name,
		IsRadiant = isRadiant,
		BonusCash = bonusCash,
	}
end

return FusionService
