--!strict
--[[
	FusionModal.luau — Tactical Cyber-Glass Relic Fusion Center for VAULT WARS
	Displays player's relic inventory and enables 3-to-1 synthesis into higher tiers
	with 20% Supercharged Radiant Mutation odds.
	Located in: StarterPlayerScripts.Client.UI.FusionModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RelicData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelicData"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local ModelEngine = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelEngine"))

local player = Players.LocalPlayer
local FusionModal = {}

FusionModal._frame = nil :: Frame?
FusionModal._isOpen = false
FusionModal._currentData = nil :: Types.PlayerData?
FusionModal._cards = {} :: { [string]: any }
FusionModal._statusLabel = nil :: TextLabel?

-- FUSION TIER ORDER
local FUSION_TIERS = {
	{ Id = "GoldStack", NextId = "EmeraldMatrix", NextName = "Emerald Matrix Core" },
	{ Id = "EmeraldMatrix", NextId = "RubyArtifact", NextName = "Ruby Skull Artifact" },
	{ Id = "RubyArtifact", NextId = "DiamondSkull", NextName = "Diamond Chrono Skull" },
	{ Id = "DiamondSkull", NextId = "VoidChronometer", NextName = "Void Eye Chronometer" },
	{ Id = "VoidChronometer", NextId = "CelestialCrown", NextName = "Celestial Archon Crown" },
	{ Id = "CelestialCrown", NextId = "CelestialCrown", NextName = "Radiant Zenith Crown" },
}

function FusionModal.Create(parentGui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "FusionModal"
	frame.Size = UDim2.new(0, 580, 0, 520)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(11, 13, 20)
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 50
	frame.Parent = parentGui
	FusionModal._frame = frame

	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(168, 85, 247)
	stroke.Thickness = 2

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundTransparency = 1
	header.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 28)
	title.Position = UDim2.new(0, 20, 0, 6)
	title.BackgroundTransparency = 1
	title.Text = "🔮 RELIC FUSION ALTAR"
	title.TextColor3 = Color3.fromRGB(216, 180, 254)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -60, 0, 18)
	subtitle.Position = UDim2.new(0, 20, 0, 32)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Combine 3x matching relics • 20% Chance for Radiant Mutation (+50% Payout)"
	subtitle.TextColor3 = Color3.fromRGB(148, 163, 184)
	subtitle.TextSize = 11
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = header
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

	closeBtn.MouseButton1Click:Connect(function()
		FusionModal.Close()
	end)

	-- Scrollable List Container
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "RelicList"
	scroll.Size = UDim2.new(1, -32, 1, -120)
	scroll.Position = UDim2.new(0, 16, 0, 64)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(168, 85, 247)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 430)
	scroll.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = scroll

	-- Build Relic Fusion Cards
	for _, fEntry in FUSION_TIERS do
		local relicDef = RelicData.Catalog[fEntry.Id]
		if not relicDef then continue end

		local card = Instance.new("Frame")
		card.Name = "Card_" .. fEntry.Id
		card.Size = UDim2.new(1, -6, 0, 74)
		card.BackgroundColor3 = Color3.fromRGB(24, 24, 27)
		card.BorderSizePixel = 0
		card.Parent = scroll
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

		local cStroke = Instance.new("UIStroke", card)
		cStroke.Color = Color3.fromRGB(39, 39, 42)

		-- Live 3D Rotating Relic Viewport
		local vp = Instance.new("ViewportFrame")
		vp.Name = "RelicViewport"
		vp.Size = UDim2.new(0, 56, 0, 56)
		vp.Position = UDim2.new(0, 10, 0.5, 0)
		vp.AnchorPoint = Vector2.new(0, 0.5)
		vp.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
		vp.BorderSizePixel = 0
		vp.Parent = card
		Instance.new("UICorner", vp).CornerRadius = UDim.new(0, 8)
		local vpStroke = Instance.new("UIStroke", vp)
		vpStroke.Color = relicDef.Color
		vpStroke.Thickness = 1.5

		local relic3D = ModelEngine.CreateRelicModel(fEntry.Id, CFrame.new(0, 0, 0))
		relic3D.Parent = vp

		local vpCam = Instance.new("Camera")
		vpCam.CFrame = CFrame.lookAt(Vector3.new(0, 1.5, 4.2), Vector3.new(0, 1.5, 0))
		vpCam.Parent = vp
		vp.CurrentCamera = vpCam

		task.spawn(function()
			local rot = math.random() * math.pi
			while vp and vp.Parent do
				rot += 0.025
				if relic3D and relic3D.PrimaryPart then
					relic3D:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, rot, 0))
				end
				task.wait(0.03)
			end
		end)

		-- Relic Name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 220, 0, 20)
		nameLabel.Position = UDim2.new(0, 74, 0, 14)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = `{relicDef.Name} ({relicDef.Tier})`
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 13
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		-- Synthesis Target
		local targetLabel = Instance.new("TextLabel")
		targetLabel.Size = UDim2.new(0, 240, 0, 18)
		targetLabel.Position = UDim2.new(0, 74, 0, 38)
		targetLabel.BackgroundTransparency = 1
		targetLabel.Text = `→ Yields: {fEntry.NextName}`
		targetLabel.TextColor3 = Color3.fromRGB(161, 161, 170)
		targetLabel.TextSize = 11
		targetLabel.Font = Enum.Font.GothamMedium
		targetLabel.TextXAlignment = Enum.TextXAlignment.Left
		targetLabel.Parent = card

		-- Owned Count Pill
		local countPill = Instance.new("TextLabel")
		countPill.Name = "CountPill"
		countPill.Size = UDim2.new(0, 90, 0, 24)
		countPill.Position = UDim2.new(1, -225, 0.5, 0)
		countPill.AnchorPoint = Vector2.new(0, 0.5)
		countPill.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
		countPill.Text = "Owned: 0 / 3"
		countPill.TextColor3 = Color3.fromRGB(148, 163, 184)
		countPill.TextSize = 11
		countPill.Font = Enum.Font.GothamBlack
		countPill.Parent = card
		Instance.new("UICorner", countPill).CornerRadius = UDim.new(0, 6)

		-- Tactile 3D Extruded Fuse Button
		local fuseBtn = Instance.new("TextButton")
		fuseBtn.Name = "FuseButton"
		fuseBtn.Size = UDim2.new(0, 120, 0, 40)
		fuseBtn.Position = UDim2.new(1, -130, 0.5, 0)
		fuseBtn.AnchorPoint = Vector2.new(0, 0.5)
		fuseBtn.BackgroundColor3 = Color3.fromRGB(63, 63, 70)
		fuseBtn.Text = "FUSE 3x"
		fuseBtn.TextColor3 = Color3.fromRGB(161, 161, 170)
		fuseBtn.TextSize = 12
		fuseBtn.Font = Enum.Font.GothamBlack
		fuseBtn.AutoButtonColor = false
		fuseBtn.Parent = card
		Instance.new("UICorner", fuseBtn).CornerRadius = UDim.new(0, 8)

		local fBtnStroke = Instance.new("UIStroke", fuseBtn)
		fBtnStroke.Color = Color3.fromRGB(39, 39, 42)
		fBtnStroke.Thickness = 2

		fuseBtn.MouseEnter:Connect(function()
			if fuseBtn.BackgroundColor3 ~= Color3.fromRGB(63, 63, 70) then
				TweenService:Create(fuseBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, 124, 0, 42)
				}):Play()
			end
		end)
		fuseBtn.MouseLeave:Connect(function()
			TweenService:Create(fuseBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 120, 0, 40)
			}):Play()
		end)

		fuseBtn.MouseButton1Click:Connect(function()
			FusionModal.OnFuseClick(fEntry.Id)
		end)

		FusionModal._cards[fEntry.Id] = {
			Card = card,
			Stroke = cStroke,
			CountPill = countPill,
			FuseBtn = fuseBtn,
			RelicDef = relicDef,
			Entry = fEntry,
		}
	end

	-- Bottom Status Toast Label
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -32, 0, 36)
	statusLabel.Position = UDim2.new(0, 16, 1, -44)
	statusLabel.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	statusLabel.Text = "Select 3 duplicate relics to synthesize into the next tier."
	statusLabel.TextColor3 = Color3.fromRGB(203, 213, 225)
	statusLabel.TextSize = 11
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.Parent = frame
	Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 8)
	FusionModal._statusLabel = statusLabel

	print("  [FusionModal] Relic Fusion Altar UI initialized ✓")
end

-- ============================================================
-- OPEN / CLOSE / TOGGLE
-- ============================================================
function FusionModal.Open()
	if not FusionModal._frame then return end
	FusionModal._isOpen = true
	FusionModal._frame.Visible = true

	if FusionModal._currentData then
		FusionModal.Update(FusionModal._currentData)
	end
end

function FusionModal.Close()
	if not FusionModal._frame then return end
	FusionModal._isOpen = false
	FusionModal._frame.Visible = false
end

function FusionModal.Toggle()
	if FusionModal._isOpen then
		FusionModal.Close()
	else
		FusionModal.Open()
	end
end

-- ============================================================
-- UPDATE CARDS FROM PLAYER INVENTORY
-- ============================================================
function FusionModal.Update(data: Types.PlayerData)
	if not data then return end
	FusionModal._currentData = data

	local inv = data.RelicInventory or {}

	for relicId, cardData in FusionModal._cards do
		local count = inv[relicId] or 0
		local hasEnough = count >= 3

		cardData.CountPill.Text = `Owned: {count} / 3`

		if hasEnough then
			cardData.CountPill.TextColor3 = Color3.fromRGB(16, 185, 129)
			cardData.FuseBtn.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
			cardData.FuseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			cardData.FuseBtn.Text = "🔮 FUSE 3x"
			cardData.Stroke.Color = Color3.fromRGB(168, 85, 247)
		else
			cardData.CountPill.TextColor3 = Color3.fromRGB(148, 163, 184)
			cardData.FuseBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
			cardData.FuseBtn.TextColor3 = Color3.fromRGB(113, 113, 122)
			cardData.FuseBtn.Text = "NEED 3x"
			cardData.Stroke.Color = Color3.fromRGB(39, 39, 42)
		end
	end
end

-- ============================================================
-- HANDLE FUSE BUTTON CLICK
-- ============================================================
function FusionModal.OnFuseClick(relicId: string)
	local cardData = FusionModal._cards[relicId]
	if not cardData then return end

	local inv = (FusionModal._currentData and FusionModal._currentData.RelicInventory) or {}
	local count = inv[relicId] or 0
	if count < 3 then
		if FusionModal._statusLabel then
			FusionModal._statusLabel.Text = `⚠️ Need 3 copies to synthesize. You have {count}.`
			FusionModal._statusLabel.TextColor3 = Color3.fromRGB(245, 158, 11)
		end
		return
	end

	-- Button click bounce tween
	local btn = cardData.FuseBtn :: TextButton
	TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 114, 0, 34)
	}):Play()
	task.delay(0.08, function()
		if btn and btn.Parent then
			TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 120, 0, 38)
			}):Play()
		end
	end)

	local fuseRF = ReplicatedStorage:FindFirstChild("FuseRelicsRequest") :: RemoteFunction?
	if not fuseRF then return end

	task.spawn(function()
		local success, msg, payload = fuseRF:InvokeServer(relicId)
		if FusionModal._statusLabel then
			FusionModal._statusLabel.Text = msg or (success and "Synthesis Complete!" or "Fusion Failed")
			if success then
				if payload and payload.IsRadiant then
					FusionModal._statusLabel.TextColor3 = Color3.fromRGB(250, 204, 21)
				else
					FusionModal._statusLabel.TextColor3 = Color3.fromRGB(16, 185, 129)
				end
			else
				FusionModal._statusLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
			end
		end
	end)
end

return FusionModal
