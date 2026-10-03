--!strict
--[[
	CollectionModal.luau — Celestial Compendium for STARWEAVE
	Tracks all discovered plant x mutation combinations (112 total).
	Features discovery progress bar, glowing rarity cards, and locked states.
	Located in: StarterPlayerScripts.Client.UI.CollectionModal
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SeedData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeedData"))
local MutationData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MutationData"))
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local UILib = require(script.Parent.UILib)

local CollectionModal = {}
CollectionModal._frame = nil :: Frame?
CollectionModal._data = nil :: any
CollectionModal._cardList = {} :: { Frame }

local MUTATION_ORDER = { "Sprout", "Bloom", "Radiant", "Astral", "Celestial", "Primordial" }
local ACCENT = Color3.fromRGB(56, 189, 248)

local MUTATION_COLORS: { [string]: Color3 } = {
	Sprout     = Color3.fromRGB(74, 222, 128),
	Bloom      = Color3.fromRGB(56, 189, 248),
	Radiant    = Color3.fromRGB(255, 204, 0),
	Astral     = Color3.fromRGB(168, 85, 247),
	Celestial  = Color3.fromRGB(244, 114, 182),
	Primordial = Color3.fromRGB(248, 250, 252),
}

function CollectionModal.Create(parentGui: ScreenGui)
	local modal = UILib.CreateModalFrame(parentGui, "CollectionModal", 580, 520, ACCENT)
	CollectionModal._frame = modal

	-- Header
	local header = UILib.CreateModalHeader(modal, "Celestial Compendium", "All discovered cosmic flora specimens", ACCENT, function()
		SoundController.Play("ButtonClick")
		CollectionModal.Close()
	end)

	-- Progress section (below header)
	local progressFrame = Instance.new("Frame")
	progressFrame.Name = "ProgressFrame"
	progressFrame.Size = UDim2.new(1, -32, 0, 36)
	progressFrame.Position = UDim2.new(0, 16, 0, 68)
	progressFrame.BackgroundTransparency = 1
	progressFrame.ZIndex = modal.ZIndex + 1
	progressFrame.Parent = modal

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "ProgressLabel"
	progressLabel.Size = UDim2.new(0.5, 0, 0, 14)
	progressLabel.Position = UDim2.new(0, 0, 0, 0)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "Discovered: 0 / 112 (0%)"
	progressLabel.TextColor3 = UILib.Colors.TextSecondary
	progressLabel.TextSize = 12
	progressLabel.Font = UILib.Fonts.Bold
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.ZIndex = modal.ZIndex + 2
	progressLabel.Parent = progressFrame

	local progBarBg, progBarFill = UILib.CreateProgressBar(
		progressFrame, "DiscoveryProg",
		UDim2.new(0, 0, 0, 20),
		UDim2.new(1, 0, 0, 8),
		ACCENT
	)

	-- Scrolling grid
	local scroll = UILib.CreateScrollFrame(
		modal, "CompendiumScroll",
		UDim2.new(1, -32, 1, -116),
		UDim2.new(0, 16, 0, 110),
		ACCENT
	)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 120, 0, 120)
	gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scroll

	CollectionModal.Refresh()
end

function CollectionModal.Refresh()
	local modal = CollectionModal._frame
	if not modal then return end
	local scroll = modal:FindFirstChild("CompendiumScroll") :: ScrollingFrame?
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
			totalPossibilities += 1
			local key = seedId .. "_" .. mutTier
			local isDiscovered = discoveredMap[key] == true
			if isDiscovered then discoveredCount += 1 end

			local mutColor = MUTATION_COLORS[mutTier] or UILib.Colors.Common

			local card = Instance.new("Frame")
			card.Name = key
			card.BackgroundColor3 = isDiscovered and UILib.Colors.Surface2 or Color3.fromRGB(10, 8, 18)
			card.BorderSizePixel = 0
			card.ZIndex = modal.ZIndex + 2
			card.Parent = scroll
			UILib.ApplyCorner(card, 8)

			if isDiscovered then
				UILib.ApplyStroke(card, mutColor, 1, 0.35)
				-- Gradient depth
				local cGrad = Instance.new("UIGradient")
				cGrad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 22, 48)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 12, 30)),
				})
				cGrad.Rotation = 150
				cGrad.Parent = card
			else
				UILib.ApplyStroke(card, Color3.fromRGB(30, 26, 42), 1, 0.7)
			end

			-- Icon / Lock indicator
			local iconLabel = Instance.new("TextLabel")
			iconLabel.Size = UDim2.new(1, 0, 0, 30)
			iconLabel.Position = UDim2.new(0, 0, 0, 8)
			iconLabel.BackgroundTransparency = 1
			iconLabel.Text = isDiscovered and "*" or "?"
			iconLabel.TextColor3 = isDiscovered and mutColor or Color3.fromRGB(50, 44, 65)
			iconLabel.TextSize = isDiscovered and 22 or 18
			iconLabel.Font = UILib.Fonts.Black
			iconLabel.ZIndex = modal.ZIndex + 3
			iconLabel.Parent = card

			-- Name
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, -10, 0, 28)
			nameLabel.Position = UDim2.new(0, 5, 0, 42)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = isDiscovered and seed.Name or "???"
			nameLabel.TextColor3 = isDiscovered and UILib.Colors.TextPrimary or Color3.fromRGB(60, 55, 75)
			nameLabel.TextSize = 11
			nameLabel.Font = UILib.Fonts.Bold
			nameLabel.TextWrapped = true
			nameLabel.ZIndex = modal.ZIndex + 3
			nameLabel.Parent = card

			-- Mutation tier badge
			local tierLabel = Instance.new("TextLabel")
			tierLabel.Size = UDim2.new(1, -10, 0, 14)
			tierLabel.Position = UDim2.new(0, 5, 1, -22)
			tierLabel.BackgroundTransparency = 1
			tierLabel.Text = isDiscovered and mutTier or "Undiscovered"
			tierLabel.TextColor3 = isDiscovered and mutColor or Color3.fromRGB(50, 44, 65)
			tierLabel.TextSize = 9
			tierLabel.Font = UILib.Fonts.Medium
			tierLabel.ZIndex = modal.ZIndex + 3
			tierLabel.Parent = card

			table.insert(CollectionModal._cardList, card)
		end
	end

	-- Update progress
	local progressFrame = modal:FindFirstChild("ProgressFrame")
	if progressFrame then
		local pLabel = progressFrame:FindFirstChild("ProgressLabel") :: TextLabel?
		local fillFrame = progressFrame:FindFirstChild("DiscoveryProgBg")
		local fill = fillFrame and fillFrame:FindFirstChild("Fill") :: Frame?

		local pct = totalPossibilities > 0 and (discoveredCount / totalPossibilities) or 0

		if pLabel then
			pLabel.Text = string.format("Discovered: %d / %d (%d%%)", discoveredCount, totalPossibilities, math.floor(pct * 100))
		end
		if fill then
			TweenService:Create(fill, UILib.Timing.Normal, {
				Size = UDim2.fromScale(pct, 1),
			}):Play()
		end
	end
end

function CollectionModal.Open()
	if not CollectionModal._frame then return end
	UILib.OpenModal(CollectionModal._frame)
	CollectionModal.Refresh()
end

function CollectionModal.Close()
	if not CollectionModal._frame then return end
	UILib.CloseModal(CollectionModal._frame)
end

function CollectionModal.Update(data: any)
	CollectionModal._data = data
	if CollectionModal._frame and CollectionModal._frame.Visible then
		CollectionModal.Refresh()
	end
end

return CollectionModal
