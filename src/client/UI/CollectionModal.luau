--!strict
--[[
	CollectionModal.luau — Celestial Compendium & Discovery Log for STARWEAVE
	Tracks all discovered plant × mutation combinations (112 possibilities).
	Features discovery percentages, glowing rarity cards, and locked silhouette states.
	Located in: StarterPlayerScripts.Client.UI.CollectionModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SeedData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeedData"))
local MutationData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MutationData"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local player = Players.LocalPlayer

local CollectionModal = {}
CollectionModal._frame = nil :: Frame?
CollectionModal._data = nil :: any
CollectionModal._cardList = {} :: { Frame }

local MUTATION_ORDER = { "Sprout", "Bloom", "Radiant", "Astral", "Celestial", "Primordial" }

function CollectionModal.Create(parentGui: ScreenGui)
	local modal = Instance.new("Frame")
	modal.Name = "CollectionModal"
	modal.Size = UDim2.new(0, 560, 0, 500)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.BackgroundColor3 = Color3.fromRGB(15, 11, 28)
	modal.BackgroundTransparency = 0.12
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = parentGui
	CollectionModal._frame = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(56, 189, 248)
	stroke.Thickness = 2
	stroke.Parent = modal

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundTransparency = 1
	header.Parent = modal

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.7, 0, 0, 26)
	title.Position = UDim2.new(0, 20, 0, 12)
	title.BackgroundTransparency = 1
	title.Text = "📚 CELESTIAL COMPENDIUM"
	title.TextColor3 = Color3.fromRGB(56, 189, 248)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "ProgressLabel"
	progressLabel.Size = UDim2.new(0.7, 0, 0, 16)
	progressLabel.Position = UDim2.new(0, 20, 0, 38)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "Discovered: 0 / 112 (0%)"
	progressLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
	progressLabel.TextScaled = true
	progressLabel.Font = Enum.Font.Gotham
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.Parent = header

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -44, 0, 12)
	closeBtn.BackgroundColor3 = Color3.fromRGB(30, 22, 50)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(216, 180, 254)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = header

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		SoundController.Play("ButtonClick")
		CollectionModal.Close()
	end)

	-- Scroll Grid
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "CompendiumScroll"
	scroll.Size = UDim2.new(1, -40, 1, -80)
	scroll.Position = UDim2.new(0, 20, 0, 68)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(56, 189, 248)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 1200)
	scroll.Parent = modal

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 118, 0, 128)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scroll

	CollectionModal.Refresh()
end

function CollectionModal.Refresh()
	local modal = CollectionModal._frame
	if not modal then return end
	local scroll = modal:FindFirstChild("CompendiumScroll") :: ScrollingFrame?
	local progressLabel = modal:FindFirstChild("Header") and modal.Header:FindFirstChild("ProgressLabel") :: TextLabel?
	if not scroll then return end

	for _, card in CollectionModal._cardList do
		card:Destroy()
	end
	table.clear(CollectionModal._cardList)

	local discoveredMap = CollectionModal._data and CollectionModal._data.PlantCollection or {}
	local totalPossibilities = 0
	local discoveredCount = 0

	for seedId, seed in SeedData.Seeds do
		for _, mutTier in MUTATION_ORDER do
			totalPossibilities = totalPossibilities + 1
			local key = seedId .. "_" .. mutTier
			local isDiscovered = discoveredMap[key] == true
			if isDiscovered then
				discoveredCount = discoveredCount + 1
			end

			local mutDef = MutationData.GetByTier(mutTier)
			local tierColor = mutDef and Color3.fromRGB(mutDef.ParticleColor.R, mutDef.ParticleColor.G, mutDef.ParticleColor.B) or Color3.fromRGB(148, 163, 184)

			local card = Instance.new("Frame")
			card.Name = key
			card.BackgroundColor3 = isDiscovered and Color3.fromRGB(24, 18, 42) or Color3.fromRGB(16, 14, 24)
			card.BorderSizePixel = 0
			card.Parent = scroll

			local cardCorner = Instance.new("UICorner")
			cardCorner.CornerRadius = UDim.new(0, 8)
			cardCorner.Parent = card

			local stroke = Instance.new("UIStroke")
			stroke.Color = isDiscovered and tierColor or Color3.fromRGB(39, 39, 42)
			stroke.Thickness = isDiscovered and 1.2 or 1
			stroke.Transparency = isDiscovered and 0.2 or 0.7
			stroke.Parent = card

			local iconLabel = Instance.new("TextLabel")
			iconLabel.Size = UDim2.new(1, 0, 0, 36)
			iconLabel.Position = UDim2.new(0, 0, 0, 10)
			iconLabel.BackgroundTransparency = 1
			iconLabel.Text = isDiscovered and "✨" or "🔒"
			iconLabel.TextScaled = true
			iconLabel.Font = Enum.Font.GothamBold
			iconLabel.TextColor3 = isDiscovered and tierColor or Color3.fromRGB(82, 82, 91)
			iconLabel.Parent = card

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, -12, 0, 32)
			nameLabel.Position = UDim2.new(0, 6, 0, 50)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = isDiscovered and (seed.Name .. "\n(" .. mutTier .. ")") or "???"
			nameLabel.TextColor3 = isDiscovered and Color3.fromRGB(241, 245, 249) or Color3.fromRGB(113, 113, 122)
			nameLabel.TextScaled = true
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.Parent = card

			local subBadge = Instance.new("TextLabel")
			subBadge.Size = UDim2.new(1, -12, 0, 16)
			subBadge.Position = UDim2.new(0, 6, 1, -24)
			subBadge.BackgroundTransparency = 1
			subBadge.Text = isDiscovered and mutTier or "Undiscovered"
			subBadge.TextColor3 = isDiscovered and tierColor or Color3.fromRGB(82, 82, 91)
			subBadge.TextScaled = true
			subBadge.Font = Enum.Font.Gotham
			subBadge.Parent = card

			table.insert(CollectionModal._cardList, card)
		end
	end

	if progressLabel then
		local pct = totalPossibilities > 0 and math.floor((discoveredCount / totalPossibilities) * 100) or 0
		progressLabel.Text = string.format("Discovered: %d / %d (%d%%)", discoveredCount, totalPossibilities, pct)
	end
end

function CollectionModal.Open()
	if not CollectionModal._frame then return end
	CollectionModal._frame.Visible = true
	CollectionModal._frame.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(CollectionModal._frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
	CollectionModal.Refresh()
end

function CollectionModal.Close()
	if not CollectionModal._frame then return end
	local tween = TweenService:Create(CollectionModal._frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0.5, 0.55),
	})
	tween:Play()
	tween.Completed:Once(function()
		CollectionModal._frame.Visible = false
	end)
end

function CollectionModal.Update(data: any)
	CollectionModal._data = data
	if CollectionModal._frame and CollectionModal._frame.Visible then
		CollectionModal.Refresh()
	end
end

return CollectionModal
