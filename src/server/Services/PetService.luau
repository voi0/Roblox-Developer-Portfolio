--!strict
--[[
	PetService.luau — Companion & Hatching Management for STARWEAVE
	Handles companion equipping, stat updates, and cosmic egg hatching.
	Located in: ServerScriptService.Server.Services.PetService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetData = require(ReplicatedStorage.Shared.PetData)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService: any = nil

local PetService = {}
PetService._initialized = false

-- Egg drop rates
local EGG_COST = 2500 -- Stardust
local EGG_TABLE = {
	{ Id = "stardust_wisp", Weight = 60 },
	{ Id = "nebula_sprite", Weight = 25 },
	{ Id = "solar_phoenix", Weight = 10 },
	{ Id = "astral_dragon", Weight = 4 },
	{ Id = "celestial_kitsune", Weight = 0.9 },
	{ Id = "void_pup", Weight = 0.1 },
}

function PetService.HatchEgg(player: Player): (boolean, string, any?)
	local data = DataService.GetData(player)
	if not data then return false, "Data not loaded.", nil end

	if not DataService.RemoveCurrency(player, "Stardust", EGG_COST) then
		return false, `Need {EGG_COST} Stardust to awaken a Celestial Egg.`, nil
	end

	-- Roll weighted table
	local totalWeight = 0
	for _, entry in EGG_TABLE do
		totalWeight = totalWeight + entry.Weight
	end

	local roll = math.random() * totalWeight
	local accumulated = 0
	local selectedPetId = "stardust_wisp"

	for _, entry in EGG_TABLE do
		accumulated = accumulated + entry.Weight
		if roll <= accumulated then
			selectedPetId = entry.Id
			break
		end
	end

	local petDef = PetData.GetPet(selectedPetId)
	if not petDef then return false, "Unknown pet.", nil end

	local petInstance = {
		Id = selectedPetId,
		Name = petDef.Name,
		Tier = petDef.Tier,
		MutationLuckBonus = petDef.BaseMutationLuck,
		HarvestSpeedBonus = petDef.BaseHarvestSpeed,
		Level = 1,
		Experience = 0,
	}

	if not data.Pets then data.Pets = {} end
	table.insert(data.Pets, petInstance)

	-- Auto-equip if first pet
	if #data.Pets == 1 then
		data.EquippedPetIndex = 1
	end

	return true, `Awakened a {petDef.Name}!`, petInstance
end

function PetService.EquipPet(player: Player, petIndex: number): (boolean, string)
	local data = DataService.GetData(player)
	if not data or not data.Pets then return false, "Data not loaded." end

	local pet = data.Pets[petIndex]
	if not pet then return false, "Pet not found." end

	data.EquippedPetIndex = petIndex
	return true, `Equipped {pet.Name}!`
end

function PetService.UnequipPet(player: Player): (boolean, string)
	local data = DataService.GetData(player)
	if not data then return false, "Data not loaded." end

	data.EquippedPetIndex = nil
	return true, "Unequipped companion."
end

function PetService.Init()
	if PetService._initialized then return end
	PetService._initialized = true

	local ServerScriptService = game:GetService("ServerScriptService")
	DataService = require(ServerScriptService.Server.Services.DataService)

	local petRequest = Instance.new("RemoteFunction")
	petRequest.Name = "PetRequest"
	petRequest.Parent = ReplicatedStorage

	petRequest.OnServerInvoke = function(player: Player, action: string, ...: any): any
		if action == "Hatch" then
			local success, message, pet = PetService.HatchEgg(player)
			return { Success = success, Message = message, Pet = pet }
		elseif action == "Equip" then
			local index = ...
			local success, message = PetService.EquipPet(player, index :: number)
			return { Success = success, Message = message }
		elseif action == "Unequip" then
			local success, message = PetService.UnequipPet(player)
			return { Success = success, Message = message }
		end
		return { Success = false, Message = "Unknown action." }
	end

	print("[PetService] Initialized ✓")
end

return PetService
