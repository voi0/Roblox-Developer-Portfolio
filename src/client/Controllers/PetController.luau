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

local PetData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetData"))

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
		if not root then return end

		-- Offset target: over right shoulder, slightly hovering
		local t = os.clock()
		local hoverY = math.sin(t * 3.2) * 0.35
		local bobRoll = math.sin(t * 1.8) * 0.06
		local targetOffset = Vector3.new(3.2, 2.0 + hoverY, 1.8)
		local targetCFrame = root.CFrame * CFrame.new(targetOffset) * CFrame.Angles(0, math.rad(180), bobRoll)

		-- Smooth model pivot lerp
		local currentCF = model:GetPivot()
		local newCF = currentCF:Lerp(targetCFrame, math.clamp(dt * 7, 0, 1))
		model:PivotTo(newCF)
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

	local assetsFolder = ReplicatedStorage:FindFirstChild("StarweaveAssets")
	local template = assetsFolder and (
		assetsFolder:FindFirstChild("Pet_" .. petInstance.Id)
		or assetsFolder:FindFirstChild("Pet_" .. string.lower(petInstance.Name or ""))
	) :: Model?

	local model: Model
	local anchorPart: BasePart

	if template then
		-- Clone the User's Real 3D Imported Pet Model (Astral Kitsune, Hatchling Dragon, etc.)
		model = template:Clone()
		model.Name = `Companion_{player.Name}`
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		if not model.PrimaryPart then
			model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
		end
		anchorPart = model.PrimaryPart or Instance.new("Part")
	else
		-- Celestial Wisp Fallback for non-modeled companions
		model = Instance.new("Model")
		model.Name = `Companion_{player.Name}`

		local core = Instance.new("Part")
		core.Name = "PetCore"
		core.Shape = Enum.PartType.Ball
		core.Size = Vector3.new(1.2, 1.2, 1.2)
		core.Material = Enum.Material.Neon
		core.Color = petColor
		core.CanCollide = false
		core.Anchored = true
		core.Parent = model
		model.PrimaryPart = core
		anchorPart = core

		local ring = Instance.new("Part")
		ring.Name = "OrbitRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.06, 2.0, 2.0)
		ring.CFrame = CFrame.new(core.Position) * CFrame.Angles(0, 0, math.rad(90))
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 255, 255)
		ring.Transparency = 0.5
		ring.CanCollide = false
		ring.Anchored = true
		ring.Parent = model

		task.spawn(function()
			while ring.Parent do
				ring.CFrame = core.CFrame * CFrame.Angles(0.03, 0.05, 0)
				task.wait(0.03)
			end
		end)
	end

	-- Ambient Starlight Motes
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchorPart

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, petColor),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	emitter.LightEmission = 0.85
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(0.6, 1.8)
	emitter.Rate = 14
	emitter.Parent = attachment

	-- Floating Name Pill
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PetTag"
	billboard.Size = UDim2.new(0, 110, 0, 24)
	billboard.StudsOffset = Vector3.new(0, 1.6, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 35
	billboard.Parent = anchorPart

	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = Color3.fromRGB(15, 12, 30)
	pill.BackgroundTransparency = 0.2
	pill.BorderSizePixel = 0
	pill.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = pill

	local stroke = Instance.new("UIStroke")
	stroke.Color = petColor
	stroke.Thickness = 1.2
	stroke.Parent = pill

	local tagLabel = Instance.new("TextLabel")
	tagLabel.Size = UDim2.fromScale(1, 1)
	tagLabel.BackgroundTransparency = 1
	tagLabel.Text = petInstance.Name or petDef and petDef.Name or "Companion"
	tagLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	tagLabel.TextSize = 11
	tagLabel.Font = Enum.Font.GothamBold
	tagLabel.Parent = pill

	model.Parent = Workspace
	PetController._activePetModel = model
end

function PetController.ClearPetModel()
	if PetController._activePetModel then
		PetController._activePetModel:Destroy()
		PetController._activePetModel = nil
	end
end

return PetController
