--!strict
--[[
	Server Boot Script — STARWEAVE
	Initializes all server services in the correct order with error protection.
	Located in: ServerScriptService.Server
]]

local ServerScriptService = game:GetService("ServerScriptService")

local servicesFolder = script:WaitForChild("Services", 15) :: Folder
if not servicesFolder then
	error("[Server] Critical: Services folder not found in ServerScriptService.Server!")
end

print("========================================")
print("  🌟 STARWEAVE Server Booting...")
print("========================================")

local serviceNames = {
	"WorldService",
	"DataService",
	"MutationService",
	"GardenService",
	"EconomyService",
	"PetService",
	"QuestService",
	"CodeService",
}

local loadedServices: { [string]: any } = {}

for _, name in serviceNames do
	local module = servicesFolder:WaitForChild(name, 10) :: ModuleScript?
	if module then
		local success, result = pcall(function()
			return require(module)
		end)
		if success and result then
			loadedServices[name] = result
			print(`  [Server] Required: {name} ✓`)
		else
			warn(`  [Server] FAILED to require {name}: {tostring(result)}`)
		end
	else
		warn(`  [Server] Missing module: {name}`)
	end
end

-- Initialize in strict dependency order
for _, name in serviceNames do
	local service = loadedServices[name]
	if service and type(service.Init) == "function" then
		local success, err = pcall(function()
			service.Init()
		end)
		if success then
			print(`  [Server] Initialized: {name} ✓`)
		else
			warn(`  [Server] FAILED to initialize {name}: {tostring(err)}`)
		end
	end
end

print("========================================")
print("  ✅ STARWEAVE Server Online!")
print("========================================")
