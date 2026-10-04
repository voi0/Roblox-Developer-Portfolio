--!strict
--[[
	CollectionModal.luau — Celestial Compendium for STARWEAVE
	Tracks all discovered plant x mutation combinations.
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
	Radiant    = Color3.fromRGB(250, 204, 21),
	Astral     = Color3.fromRGB(168, 85, 247),
	Celestial  = Color3.fromRGB(244, 114, 182),
	Primordial = Color3.fromRGB(248, 250, 252),
}

function CollectionModal.Create(parentGui: ScreenGui)
	local modal = UILib.CreateModalFrame(parentGui, "CollectionModal", 540, 440, ACCENT)
	CollectionModal._frame = modal

	-- Header
	local header = UILib.CreateModalHeader(modal, "Celestial Compendium", "Catalog of discovered cosmic flora & mutations", ACCENT, function()
		SoundController.Play("ButtonClick")
		CollectionModal.Close()
	end)

	-- Progress section (below header)
	local progressFrame = Instance.new("Frame")
	progressFrame.Name = "ProgressFrame"
	progressFrame.Size = UDim2.new(1, -32, 0, 36)
	progressFrame.Position = UDim2.new(0, 16, 0, 56)
	progressFrame.BackgroundTransparency = 1
	progressFrame.ZIndex = modal.ZIndex + 1
	progressFrame.Parent = modal

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "ProgressLabel"
	progressLabel.Size = UDim2.new(1, 0, 0, 14)
	progressLabel.Position = UDim2.new(0, 0, 0, 0)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "COMPENDIUM DISCOVERY: 0 / 96 (0%)"
	progressLabel.TextColor3 = ACCENT
	progressLabel.TextSize = 11
	progressLabel.Font = UILib.Fonts.Bold
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.ZIndex = modal.ZIndex + 2
	progressLabel.Parent = progressFrame

	local progBarBg, progBarFill = UILib.CreateProgressBar(
		progressFrame, "DiscoveryProg",
		UDim2.new(0, 0, 0, 18),
		UDim2.new(1, 0, 0, 6),
		ACCENT
	)

	-- Scrolling grid
	local scroll = UILib.CreateScrollFrame(
		modal, "CompendiumScroll",
		UDim2.new(1, -32, 1, -100),
		UDim2.new(0, 16, 0, 96),
		ACCENT
	)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 116, 0, 110)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
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

			local mutColor = MUTATION_COLORS[mutTier] or Color3.fromRGB(168, 85, 247)

			local card = Instance.new("Frame")
			card.Name = key
			card.BackgroundColor3 = isDiscovered and Color3.fromRGB(22, 18, 36) or Color3.fromRGB(12, 10, 20)
			card.BorderSizePixel = 0
			card.ZIndex = modal.ZIndex + 2
			card.Parent = scroll
			UILib.ApplyCorner(card, 10)

			local stroke = Instance.new("UIStroke")
			stroke.Color = isDiscovered and mutColor or Color3.fromRGB(35, 28, 50)
			stroke.Thickness = isDiscovered and 1.2 or 1
			stroke.Transparency = isDiscovered and 0.35 or 0.7
			stroke.Parent = card

			local grad = Instance.new("UIGradient")
			grad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, isDiscovered and Color3.fromRGB(32, 26, 52) or Color3.fromRGB(16, 12, 24)),
				ColorSequenceKeypoint.new(1, isDiscovered and Color3.fromRGB(18, 14, 30) or Color3.fromRGB(10, 8, 18)),
			})
			grad.Rotation = 90
			grad.Parent = card

			-- Icon
			local icon = Instance.new("TextLabel")
			icon.Size = UDim2.new(1, 0, 0, 28)
			icon.Position = UDim2.new(0, 0, 0, 10)
			icon.BackgroundTransparency = 1
			icon.Text = isDiscovered and "✦" or "🔒"
			icon.TextColor3 = isDiscovered and mutColor or Color3.fromRGB(70, 60, 90)
			icon.TextSize = isDiscovered and 20 or 14
			icon.Font = UILib.Fonts.Bold
			icon.ZIndex = modal.ZIndex + 3
			icon.Parent = card

			-- Name
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, -12, 0, 26)
			nameLabel.Position = UDim2.new(0, 6, 0, 42)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = isDiscovered and seed.Name or "Undiscovered"
			nameLabel.TextColor3 = isDiscovered and Color3.fromRGB(244, 235, 255) or Color3.fromRGB(100, 90, 120)
			nameLabel.TextSize = 10
			nameLabel.Font = UILib.Fonts.Bold
			nameLabel.TextWrapped = true
			nameLabel.ZIndex = modal.ZIndex + 3
			nameLabel.Parent = card

			-- Mutation Pill
			local pill = Instance.new("Frame")
			pill.Size = UDim2.new(1, -20, 0, 18)
			pill.Position = UDim2.new(0, 10, 1, -24)
			pill.BackgroundColor3 = isDiscovered and mutColor or Color3.fromRGB(20, 16, 30)
			pill.BackgroundTransparency = isDiscovered and 0.85 or 0.5
			pill.BorderSizePixel = 0
			pill.ZIndex = modal.ZIndex + 3
			pill.Parent = card
			UILib.ApplyPill(pill)

			local pillText = Instance.new("TextLabel")
			pillText.Size = UDim2.fromScale(1, 1)
			pillText.BackgroundTransparency = 1
			pillText.Text = string.upper(mutTier)
			pillText.TextColor3 = isDiscovered and mutColor or Color3.fromRGB(80, 70, 100)
			pillText.TextSize = 9
			pillText.Font = UILib.Fonts.Bold
			pillText.ZIndex = modal.ZIndex + 4
			pillText.Parent = pill

			table.insert(CollectionModal._cardList, card)
		end
	end

	-- Update progress
	local progressFrame = modal:FindFirstChild("ProgressFrame")
	if progressFrame then
		local progressLabel = progressFrame:FindFirstChild("ProgressLabel") :: TextLabel?
		if progressLabel then
			local pct = totalPossibilities > 0 and math.floor((discoveredCount / totalPossibilities) * 100) or 0
			progressLabel.Text = `COMPENDIUM DISCOVERY: {discoveredCount} / {totalPossibilities} ({pct}%)`
		end
		local progBar = progressFrame:FindFirstChild("DiscoveryProg") :: Frame?
		if progBar then
			local fill = progBar:FindFirstChild("Fill") :: Frame?
			if fill and totalPossibilities > 0 then
				fill.Size = UDim2.fromScale(discoveredCount / totalPossibilities, 1)
			end
		end
	end
end

function CollectionModal.Open()
	if not CollectionModal._frame then return end
	CollectionModal.Refresh()
	UILib.OpenModal(CollectionModal._frame)
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
