--!strict
--[[
	PetController.luau — 3D Spatial Companion Renderer for STARWEAVE
	Spawns, animates, and positions floating cosmic companions beside the player
	using smooth spring physics, hovering sin-waves, and glowing stardust trails.
	Located in: StarterPlayerScripts.Client.Controllers.PetController
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetData = require(ReplicatedStorage.Shared.PetData)

local player = Players.LocalPlayer

local PetController = {}
PetController._activePetModel = nil :: Model?
PetController._equippedPetData = nil :: any
PetController._renderConnection = nil :: RBXScriptConnection?

function PetController.Init()
	-- Render loop handles companion follower physics
	PetController._renderConnection = RunService.RenderStepped:Connect(function(dt)
		local model = PetController._activePetModel
		local char = player.Character
		if not (model and char) then return end

		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local primaryPart = model.PrimaryPart
		if not (root and primaryPart) then return end

		-- Offset target: over right shoulder, slightly hovering
		local t = os.clock()
		local hoverY = math.sin(t * 3.5) * 0.4
		local bobRoll = math.sin(t * 2) * 0.08
		local targetOffset = Vector3.new(3.2, 2.2 + hoverY, 1.8)
		local targetCFrame = root.CFrame * CFrame.new(targetOffset) * CFrame.Angles(0, 0, bobRoll)

		-- Smooth spring lerp
		primaryPart.CFrame = primaryPart.CFrame:Lerp(targetCFrame, math.clamp(dt * 8, 0, 1))
	end)
end

function PetController.Update(playerData: any)
	if not playerData then return end

	local equippedIndex = playerData.EquippedPetIndex
	local equippedPet = (equippedIndex and playerData.Pets) and playerData.Pets[equippedIndex] or nil

	if not equippedPet then
		PetController.ClearPetModel()
		PetController._equippedPetData = nil
		return
	end

	if PetController._equippedPetData and PetController._equippedPetData.Id == equippedPet.Id then
		return -- Already active
	end

	PetController._equippedPetData = equippedPet
	PetController.SpawnPet(equippedPet)
end

function PetController.SpawnPet(petInstance: any)
	PetController.ClearPetModel()

	local petDef = PetData.GetPet(petInstance.Id)
	local petColor = petDef and petDef.Color or Color3.fromRGB(250, 204, 21)

	local model = Instance.new("Model")
	model.Name = `Companion_{player.Name}`

	-- Core Orb
	local core = Instance.new("Part")
	core.Name = "PetCore"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(1.4, 1.4, 1.4)
	core.Material = Enum.Material.Neon
	core.Color = petColor
	core.CanCollide = false
	core.Anchored = true
	core.Parent = model
	model.PrimaryPart = core

	-- Orbital Satellite Rings
	local ring = Instance.new("Part")
	ring.Name = "OrbitRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.08, 2.4, 2.4)
	ring.CFrame = CFrame.new(core.Position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 255, 255)
	ring.Transparency = 0.4
	ring.CanCollide = false
	ring.Anchored = true
	ring.Parent = model

	-- Particle Trail
	local attachment = Instance.new("Attachment")
	attachment.Parent = core

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, petColor),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.Rate = 18
	emitter.Parent = attachment

	-- Floating Tag
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PetTag"
	billboard.Size = UDim2.new(0, 120, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 1.6, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 40
	billboard.Parent = core

	local tagLabel = Instance.new("TextLabel")
	tagLabel.Size = UDim2.fromScale(1, 1)
	tagLabel.BackgroundTransparency = 1
	tagLabel.Text = petInstance.Name
	tagLabel.TextColor3 = petColor
	tagLabel.TextScaled = true
	tagLabel.Font = Enum.Font.GothamBold
	tagLabel.Parent = billboard

	model.Parent = Workspace
	PetController._activePetModel = model

	-- Ring spin animation
	task.spawn(function()
		while ring.Parent do
			ring.CFrame = core.CFrame * CFrame.Angles(0.03, 0.05, 0)
			task.wait(0.03)
		end
	end)
end

function PetController.ClearPetModel()
	if PetController._activePetModel then
		PetController._activePetModel:Destroy()
		PetController._activePetModel = nil
	end
end

return PetController
