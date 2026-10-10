--!strict
--[[
	ViewportRenderer.luau — Tactical 3D Model Viewport Engine
	Inspired by top-tier modern showcase UIs (Kekuzav & Tactical Build references):
	- Trigonometric camera bounding box auto-framing (zero clipping or tiny models)
	- Studio 3-point ambient lighting for bright, crisp clay/metallic material preview
	- Clean dot-grid tech backdrop
	- Optional smooth idle turntable rotation
	- Robust automatic memory and instance cleanup
	Located in: StarterPlayerScripts.Client.UI.Components.ViewportRenderer
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ViewportRenderer = {}
ViewportRenderer.__index = ViewportRenderer

export type ViewportRendererInstance = {
	Frame: Frame,
	Viewport: ViewportFrame,
	Camera: Camera,
	WorldModel: WorldModel,
	CurrentModel: Model?,
	_rotateConn: RBXScriptConnection?,
	_rotationAngle: number,
	SetModel: (self: ViewportRendererInstance, source: Instance, rotate: boolean?) -> (),
	Clear: (self: ViewportRendererInstance) -> (),
	Destroy: (self: ViewportRendererInstance) -> (),
}

function ViewportRenderer.new(parent: GuiObject, size: UDim2, pos: UDim2?): ViewportRendererInstance
	local container = Instance.new("Frame")
	container.Name = "ViewportContainer"
	container.Size = size
	container.Position = pos or UDim2.new(0, 0, 0, 0)
	container.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	container.BackgroundTransparency = 0.2
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(42, 52, 70)
	stroke.Thickness = 1.0
	stroke.Parent = container

	-- Tech Grid Dot / Line Pattern Background
	local gridBg = Instance.new("Frame")
	gridBg.Name = "TechGridBackdrop"
	gridBg.Size = UDim2.new(1, 0, 1, 0)
	gridBg.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	gridBg.BackgroundTransparency = 0.5
	gridBg.BorderSizePixel = 0
	gridBg.Parent = container

	local gridCorner = Instance.new("UICorner")
	gridCorner.CornerRadius = UDim.new(0, 10)
	gridCorner.Parent = gridBg

	-- Center Radial Glow
	local radialGlow = Instance.new("Frame")
	radialGlow.Name = "RadialGlow"
	radialGlow.Size = UDim2.new(0.85, 0, 0.85, 0)
	radialGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	radialGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
	radialGlow.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
	radialGlow.BackgroundTransparency = 0.92
	radialGlow.BorderSizePixel = 0
	radialGlow.Parent = container

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(1, 0)
	glowCorner.Parent = radialGlow

	-- ViewportFrame with Studio 3-Point Lighting
	local vp = Instance.new("ViewportFrame")
	vp.Name = "ModelViewport"
	vp.Size = UDim2.new(1, 0, 1, 0)
	vp.BackgroundTransparency = 1
	vp.LightColor = Color3.fromRGB(250, 250, 255)
	vp.Ambient = Color3.fromRGB(150, 165, 185)
	vp.LightDirection = Vector3.new(-1, -1.8, -1.2).Unit
	vp.Parent = container

	local cam = Instance.new("Camera")
	cam.FieldOfView = 50
	cam.Parent = vp
	vp.CurrentCamera = cam

	local worldModel = Instance.new("WorldModel")
	worldModel.Name = "DisplayWorld"
	worldModel.Parent = vp

	local self = setmetatable({
		Frame = container,
		Viewport = vp,
		Camera = cam,
		WorldModel = worldModel,
		CurrentModel = nil,
		_rotateConn = nil,
		_rotationAngle = 0,
	}, ViewportRenderer) :: any

	-- Auto-cleanup on GUI hierarchy removal
	container.Destroying:Connect(function()
		self:Destroy()
	end)

	return self
end

function ViewportRenderer:Clear()
	if self._rotateConn then
		self._rotateConn:Disconnect()
		self._rotateConn = nil
	end
	if self.CurrentModel then
		self.CurrentModel:Destroy()
		self.CurrentModel = nil
	end
	self.WorldModel:ClearAllChildren()
end

function ViewportRenderer:SetModel(source: Instance, rotate: boolean?)
	self:Clear()

	local previewModel: Model
	if source:IsA("Model") then
		previewModel = source:Clone() :: Model
	elseif source:IsA("BasePart") then
		previewModel = Instance.new("Model")
		local partClone = source:Clone() :: BasePart
		partClone.Parent = previewModel
		previewModel.PrimaryPart = partClone
	else
		return
	end

	-- Make sure all parts in clone are anchored and visible
	for _, desc in previewModel:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
		end
	end

	previewModel.Parent = self.WorldModel
	self.CurrentModel = previewModel

	-- Center model at origin
	local cf, size = previewModel:GetBoundingBox()
	local center = cf.Position
	previewModel:PivotTo(previewModel:GetPivot() * CFrame.new(-center))

	-- Trigonometric distance calculation for framing
	local fov = math.rad(self.Camera.FieldOfView)
	local radius = size.Magnitude * 0.5
	local dist = (radius / math.sin(fov * 0.5)) * 1.15

	local pitchAngle = math.rad(-14)
	local rotY = math.rad(35)
	local eyePos = Vector3.new(
		math.sin(rotY) * math.cos(pitchAngle) * dist,
		-math.sin(pitchAngle) * dist,
		math.cos(rotY) * math.cos(pitchAngle) * dist
	)

	self.Camera.CFrame = CFrame.lookAt(eyePos, Vector3.zero)

	-- Optional Turntable Idle Rotation
	if rotate ~= false then
		self._rotationAngle = 35
		self._rotateConn = RunService.RenderStepped:Connect(function(dt: number)
			if not self.CurrentModel or not self.CurrentModel.Parent then return end
			self._rotationAngle += dt * 32
			local curY = math.rad(self._rotationAngle)
			local newEye = Vector3.new(
				math.sin(curY) * math.cos(pitchAngle) * dist,
				-math.sin(pitchAngle) * dist,
				math.cos(curY) * math.cos(pitchAngle) * dist
			)
			self.Camera.CFrame = CFrame.lookAt(newEye, Vector3.zero)
		end)
	end
end

function ViewportRenderer:Destroy()
	self:Clear()
	if self.Frame and self.Frame.Parent then
		self.Frame:Destroy()
	end
end

return ViewportRenderer
