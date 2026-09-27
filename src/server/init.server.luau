--!strict
--[[
	Server Boot Script — STARWEAVE
	Initializes all server services in the correct order.
	Located in: ServerScriptService.Server
]]

local ServerScriptService = game:GetService("ServerScriptService")

-- Service initialization order matters (dependencies first)
local DataService = require(ServerScriptService.Server.Services.DataService)
local MutationService = require(ServerScriptService.Server.Services.MutationService)
local GardenService = require(ServerScriptService.Server.Services.GardenService)
local EconomyService = require(ServerScriptService.Server.Services.EconomyService)
local PetService = require(ServerScriptService.Server.Services.PetService)

-- Boot sequence
print("========================================")
print("  🌟 STARWEAVE Server Booting...")
print("========================================")

DataService.Init()
MutationService.Init()
GardenService.Init()
EconomyService.Init()
PetService.Init()

print("========================================")
print("  ✅ STARWEAVE Server Online!")
print(`  Seeds: {#(require(game:GetService("ReplicatedStorage").Shared.SeedData).GetUnlockedSeeds(0))} (base)`)
print("========================================")
