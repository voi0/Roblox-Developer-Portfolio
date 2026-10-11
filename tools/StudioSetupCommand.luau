--!strict
--[[
	StudioSetupCommand.luau — One-Click Studio Command Bar Asset Ingest & Audit Tool
	
	HOW TO USE IN ROBLOX STUDIO:
	1. In Roblox Studio, open the Command Bar (View tab -> click "Command Bar" at the bottom).
	2. Copy and paste this script into the Command Bar and press ENTER.
	3. It will immediately audit all imported Nilo 3D models, move them into ReplicatedStorage.Assets.Models,
	   and print a full technical report in the Output window!
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

print("==========================================================")
print("  [STUDIO TAKEOVER] RUNNING 3D ASSET INGEST & TECHNICAL AUDIT...")
print("==========================================================")

-- 1. Ensure Assets & Models Folders Exist
local assets = ReplicatedStorage:FindFirstChild("Assets") :: Folder?
if not assets then
	assets = Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
end

local modelsFolder = assets:FindFirstChild("Models") :: Folder?
if not modelsFolder then
	modelsFolder = Instance.new("Folder")
	modelsFolder.Name = "Models"
	modelsFolder.Parent = assets
end

-- 2. Keyword Mapping Table
local KEYWORD_MAP = {
	{ keywords = { "mint", "stamper", "press", "coin" }, target = "MintMachine" },
	{ keywords = { "vaultdoor", "vault_door", "bulkhead", "cogdoor", "cog_door", "vault-door" }, target = "VaultDoor" },
	{ keywords = { "turret", "sentry", "defenseturret" }, target = "DefenseTurret" },
	{ keywords = { "drone", "securitydrone", "patrol", "bot" }, target = "SecurityDrone" },
	{ keywords = { "reactor", "tokamak", "fusion", "core" }, target = "ReactorCore" },
	{ keywords = { "safe", "collector", "hopper", "banksafe" }, target = "BankSafeCollector" },
	{ keywords = { "baton", "stun" }, target = "StunBaton" },
	{ keywords = { "jammer", "emp" }, target = "EMPJammer" },
	{ keywords = { "altar", "transmutation", "gate", "portal" }, target = "TransmutationAltar" },
	{ keywords = { "market", "gazebo", "stall", "merchant" }, target = "BlackMarketStall" },
}

local function matchTarget(name: string): string?
	local lower = name:lower()
	if lower:find("vaultwars") or lower:find("facility") or lower:find("arena") or lower:find("cavern") or lower:find("sector") then
		return nil
	end
	for _, entry in KEYWORD_MAP do
		for _, kw in entry.keywords do
			if lower == kw or lower:find(kw) then
				return entry.target
			end
		end
	end
	return nil
end

local reserved = {
	Terrain = true,
	Camera = true,
	SubterraneanFacility = true,
	VaultWarsCavern = true,
	VaultWarsArena = true,
	VaultPlots = true,
	Plots = true,
	Sector7TransitTerminal = true,
	CustomWorldDecor = true,
	AirdropZone = true,
	SpawnLocation = true,
	BedrockFacilityFloor = true,
	PerimeterBlastWalls = true,
	Baseplate = true,
}

local ingestedCount = 0
local auditReport = {}

for _, child in Workspace:GetChildren() do
	if not reserved[child.Name] and not child.Name:find("VaultWars") and (child:IsA("Model") or child:IsA("MeshPart")) then
		local lowerName = child.Name:lower()

		if lowerName:find("prop") or lowerName:find("part-") or lowerName:find("kit") or lowerName:find("industrial") then
			child.Parent = modelsFolder
			ingestedCount += 1
			table.insert(auditReport, `[ENV PROP] Ingested {child.Name} into Assets.Models`)
		else
			local matched = matchTarget(child.Name)
			if not matched and child:IsA("Model") then
				for _, desc in child:GetDescendants() do
					if desc:IsA("MeshPart") or desc:IsA("BasePart") then
						matched = matchTarget(desc.Name)
						if matched then break end
					end
				end
			end

			if matched then
				local partCount = 0
				local subParts = {}
				for _, p in child:GetDescendants() do
					if p:IsA("BasePart") then
						partCount += 1
						table.insert(subParts, p.Name)
						p.Anchored = true
					end
				end

				child.Name = matched
				child.Parent = modelsFolder
				ingestedCount += 1

				local decompositionStatus = (partCount > 1) and `MULTI-PART ({partCount} parts: {table.concat(subParts, ", ")})` or `SINGLE SOLID MESH (Hybrid Rigging will apply)`
				table.insert(auditReport, `[HERO ASSET] {matched} <- {child.Name} | {decompositionStatus}`)
			elseif child:IsA("Model") and not child.Name:find("Baseplate") and not child.Name:find("Script") then
				local pivot = child:GetPivot()
				if (pivot.Position - Vector3.zero).Magnitude < 45 then
					child.Parent = modelsFolder
					ingestedCount += 1
					table.insert(auditReport, `[ORIGIN RELOCATION] Moved loose model {child.Name} to Assets.Models`)
				end
			end
		end
	end
end

print("----------------------------------------------------------")
print(`  TOTAL ASSETS INGESTED: {ingestedCount}`)
for _, line in auditReport do
	print("  ✓ " .. line)
end
print("----------------------------------------------------------")
print("  Assets in ReplicatedStorage.Assets.Models:")
for _, m in modelsFolder:GetChildren() do
	print(`    • {m.Name} ({m.ClassName})`)
end
print("==========================================================")
print("  [SUCCESS] All assets are now safely cataloged in Assets.Models!")
print("==========================================================")
