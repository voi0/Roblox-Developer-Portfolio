--!strict
--[[
	ObjectiveTracker.luau — Pinned On-Screen Guided Objective Tracker for STARWEAVE
	Ensures players always have a clear, dopamine-rich immediate target on screen.
	Located in: StarterPlayerScripts.Client.UI.ObjectiveTracker
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ObjectiveData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ObjectiveData"))
local UILib = require(script.Parent.UILib)

local ObjectiveTracker = {}
ObjectiveTracker._frame = nil :: Frame?
ObjectiveTracker._titleLabel = nil :: TextLabel?
ObjectiveTracker._progressLabel = nil :: TextLabel?
ObjectiveTracker._progressFill = nil :: Frame?
ObjectiveTracker._rewardLabel = nil :: TextLabel?
ObjectiveTracker._lastObjectiveId = 0

local function getSoundController(): any?
	local ctrl = script.Parent.Parent:FindFirstChild("Controllers")
	local sc = ctrl and ctrl:FindFirstChild("SoundController")
	if sc then return require(sc :: ModuleScript) end
	return nil
end

function ObjectiveTracker.Create(parentGui: ScreenGui)
	local existing = parentGui:FindFirstChild("ObjectiveTrackerCard")
	if existing then existing:Destroy() end

	local card = Instance.new("Frame")
	card.Name = "ObjectiveTrackerCard"
	card.Size = UDim2.new(0, 250, 0, 80)
	card.Position = UDim2.new(0, 16, 0, 116)
	card.BackgroundColor3 = UILib.Colors.Surface0
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	card.ZIndex = 8
	card.Parent = parentGui
	ObjectiveTracker._frame = card

	UILib.ApplyCorner(card, 14)
	local stroke = UILib.ApplyStroke(card, UILib.Colors.StrokeDark, 2.5)
	stroke.Name = "CardStroke"

	-- Left glowing accent indicator bar
	local accentBar = Instance.new("Frame")
	accentBar.Name = "AccentBar"
	accentBar.Size = UDim2.new(0, 5, 1, -16)
	accentBar.Position = UDim2.new(0, 8, 0, 8)
	accentBar.BackgroundColor3 = UILib.Colors.Gold
	accentBar.BorderSizePixel = 0
	accentBar.ZIndex = 9
	accentBar.Parent = card
	UILib.ApplyPill(accentBar)

	-- Header label
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, -28, 0, 14)
	header.Position = UDim2.new(0, 20, 0, 8)
	header.BackgroundTransparency = 1
	header.Text = "★ CURRENT OBJECTIVE"
	header.TextColor3 = UILib.Colors.GoldBright
	header.TextSize = 11
	header.Font = UILib.Fonts.Black
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.ZIndex = 9
	header.Parent = card
	UILib.ApplyTextStroke(header, UILib.Colors.StrokeDark, 2.5)

	-- Objective Title
	local title = Instance.new("TextLabel")
	title.Name = "ObjectiveTitle"
	title.Size = UDim2.new(1, -28, 0, 16)
	title.Position = UDim2.new(0, 20, 0, 25)
	title.BackgroundTransparency = 1
	title.Text = "Plant 3 Cosmic Seeds"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 13
	title.Font = UILib.Fonts.Black
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.ZIndex = 9
	title.Parent = card
	UILib.ApplyTextStroke(title, UILib.Colors.StrokeDark, 2.5)
	ObjectiveTracker._titleLabel = title

	-- Progress Bar Background
	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(1, -28, 0, 8)
	barBg.Position = UDim2.new(0, 20, 0, 47)
	barBg.BackgroundColor3 = Color3.fromRGB(16, 12, 28)
	barBg.BorderSizePixel = 0
	barBg.ZIndex = 9
	barBg.Parent = card
	UILib.ApplyPill(barBg)

	-- Progress Fill
	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.fromScale(0.33, 1)
	barFill.BackgroundColor3 = UILib.Colors.Gold
	barFill.BorderSizePixel = 0
	barFill.ZIndex = 10
	barFill.Parent = barBg
	UILib.ApplyPill(barFill)
	ObjectiveTracker._progressFill = barFill

	-- Bottom details (Progress count on left, Reward on right)
	local progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "ProgressLabel"
	progressLabel.Size = UDim2.new(0.4, 0, 0, 14)
	progressLabel.Position = UDim2.new(0, 20, 0, 58)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "0 / 3"
	progressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	progressLabel.TextSize = 11
	progressLabel.Font = UILib.Fonts.Black
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.ZIndex = 9
	progressLabel.Parent = card
	UILib.ApplyTextStroke(progressLabel, UILib.Colors.StrokeDark, 2.5)
	ObjectiveTracker._progressLabel = progressLabel

	local rewardLabel = Instance.new("TextLabel")
	rewardLabel.Name = "RewardLabel"
	rewardLabel.Size = UDim2.new(0.55, 0, 0, 14)
	rewardLabel.Position = UDim2.new(1, -145, 0, 58)
	rewardLabel.BackgroundTransparency = 1
	rewardLabel.Text = "+250 Stardust  +5 Gems"
	rewardLabel.TextColor3 = UILib.Colors.GreenBright
	rewardLabel.TextSize = 11
	rewardLabel.Font = UILib.Fonts.Black
	rewardLabel.TextXAlignment = Enum.TextXAlignment.Right
	rewardLabel.ZIndex = 9
	rewardLabel.Parent = card
	UILib.ApplyTextStroke(rewardLabel, UILib.Colors.StrokeDark, 2.5)
	ObjectiveTracker._rewardLabel = rewardLabel
end

function ObjectiveTracker.Update(data: any)
	if not (data and ObjectiveTracker._frame) then return end

	local currentId = data.CurrentObjectiveId or 1
	local objDef = ObjectiveData.GetObjective(currentId)

	if not objDef then
		-- All objectives completed!
		if ObjectiveTracker._titleLabel then
			ObjectiveTracker._titleLabel.Text = "All Objectives Completed! 🎉"
		end
		if ObjectiveTracker._progressLabel then
			ObjectiveTracker._progressLabel.Text = "Master Gardener"
		end
		if ObjectiveTracker._rewardLabel then
			ObjectiveTracker._rewardLabel.Text = "Infinite Ascension"
		end
		if ObjectiveTracker._progressFill then
			ObjectiveTracker._progressFill.Size = UDim2.fromScale(1, 1)
		end
		return
	end

	local progress = data.ObjectiveProgress or 0
	local target = objDef.Target

	if ObjectiveTracker._titleLabel then
		ObjectiveTracker._titleLabel.Text = objDef.Title
	end

	if ObjectiveTracker._progressLabel then
		ObjectiveTracker._progressLabel.Text = string.format("%d / %d", math.min(progress, target), target)
	end

	if ObjectiveTracker._progressFill then
		local pct = math.clamp(progress / target, 0, 1)
		TweenService:Create(ObjectiveTracker._progressFill, UILib.Timing.Normal, {
			Size = UDim2.fromScale(pct, 1),
		}):Play()
	end

	if ObjectiveTracker._rewardLabel then
		local parts = {}
		if objDef.RewardStardust > 0 then
			table.insert(parts, string.format("+%s Stardust", UILib.FormatNumber(objDef.RewardStardust)))
		end
		if objDef.RewardGems > 0 then
			table.insert(parts, string.format("+%d Gems", objDef.RewardGems))
		end
		ObjectiveTracker._rewardLabel.Text = table.concat(parts, "  ")
	end

	-- Objective change slide-in animation
	if ObjectiveTracker._lastObjectiveId ~= 0 and ObjectiveTracker._lastObjectiveId ~= currentId then
		local frame = ObjectiveTracker._frame
		if frame then
			TweenService:Create(frame, UILib.Timing.Fast, {
				Position = UDim2.new(0, 30, 0, 116),
			}):Play()
			task.delay(0.15, function()
				TweenService:Create(frame, UILib.Timing.Spring, {
					Position = UDim2.new(0, 16, 0, 116),
				}):Play()
			end)
		end
	end
	ObjectiveTracker._lastObjectiveId = currentId
end

function ObjectiveTracker.OnCompleted(objDef: any)
	local sound = getSoundController()
	if sound then sound.Play("PlantReady") end

	local frame = ObjectiveTracker._frame
	if not frame then return end

	local stroke = frame:FindFirstChild("CardStroke") :: UIStroke?
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Color3.fromRGB(74, 222, 128),
			Thickness = 2.5,
			Transparency = 0,
		}):Play()

		task.delay(0.6, function()
			TweenService:Create(stroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Color = UILib.Colors.Gold,
				Thickness = 1.2,
				Transparency = 0.45,
			}):Play()
		end)
	end
end

return ObjectiveTracker
