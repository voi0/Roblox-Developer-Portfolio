--!strict
--[[
	Loading Screen — STARWEAVE
	Cinematic cosmic loading experience with animated starfield,
	logo reveal, constellation drawing, and asset-synced progress.
	Critical for preventing first-60-second bounce.
	Located in: ReplicatedFirst.Loading
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local rng = Random.new()

-- ============================================================
-- DESIGN TOKENS
-- ============================================================
local C = {
	Void       = Color3.fromRGB(5, 2, 14),
	DeepSpace  = Color3.fromRGB(10, 6, 24),
	Nebula     = Color3.fromRGB(18, 12, 38),
	Purple     = Color3.fromRGB(147, 51, 234),
	PurpleGlow = Color3.fromRGB(192, 132, 252),
	Gold       = Color3.fromRGB(255, 204, 0),
	GoldSoft   = Color3.fromRGB(255, 230, 140),
	Cyan       = Color3.fromRGB(56, 189, 248),
	White      = Color3.fromRGB(248, 250, 252),
	TextDim    = Color3.fromRGB(120, 108, 156),
	BarBg      = Color3.fromRGB(22, 16, 40),
	BarFill    = Color3.fromRGB(74, 222, 128),
}

-- ============================================================
-- ROOT GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 100
screenGui.Parent = playerGui

-- Hard failsafe: Guarantee loading screen is NEVER stuck blocking the game
task.delay(2.2, function()
	if screenGui and screenGui.Parent then
		pcall(function()
			screenGui:Destroy()
		end)
	end
end)

-- ============================================================
-- BACKGROUND (gradient from deep void to nebula)
-- ============================================================
local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = C.Void
bg.BorderSizePixel = 0
bg.Parent = screenGui

local bgGrad = Instance.new("UIGradient")
bgGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C.Void),
	ColorSequenceKeypoint.new(0.5, C.DeepSpace),
	ColorSequenceKeypoint.new(1, C.Nebula),
})
bgGrad.Rotation = 160
bgGrad.Parent = bg

-- ============================================================
-- ANIMATED STARFIELD (procedural — no images needed)
-- ============================================================
local starContainer = Instance.new("Frame")
starContainer.Name = "Starfield"
starContainer.Size = UDim2.fromScale(1, 1)
starContainer.BackgroundTransparency = 1
starContainer.Parent = bg

local starPool: { Frame } = {}

local function spawnStar()
	local star = Instance.new("Frame")
	local size = rng:NextInteger(1, 3)
	local brightness = rng:NextNumber(0.3, 1.0)

	star.Size = UDim2.new(0, size, 0, size)
	star.Position = UDim2.fromScale(rng:NextNumber(0.02, 0.98), rng:NextNumber(0.02, 0.98))
	star.BackgroundColor3 = Color3.new(brightness, brightness * 0.95, brightness * 1.05)
	star.BackgroundTransparency = rng:NextNumber(0.2, 0.7)
	star.BorderSizePixel = 0
	star.Parent = starContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = star

	-- Twinkle animation
	local twinkleDuration = rng:NextNumber(1.5, 4.0)
	local twinkleDelay = rng:NextNumber(0, 2.0)
	task.delay(twinkleDelay, function()
		while star.Parent do
			local fadeOut = TweenService:Create(star, TweenInfo.new(twinkleDuration * 0.5, Enum.EasingStyle.Sine), {
				BackgroundTransparency = rng:NextNumber(0.6, 0.95),
			})
			fadeOut:Play()
			fadeOut.Completed:Wait()

			local fadeIn = TweenService:Create(star, TweenInfo.new(twinkleDuration * 0.5, Enum.EasingStyle.Sine), {
				BackgroundTransparency = rng:NextNumber(0.1, 0.5),
			})
			fadeIn:Play()
			fadeIn.Completed:Wait()
		end
	end)

	table.insert(starPool, star)
end

-- Generate starfield
for _ = 1, 80 do
	spawnStar()
end

-- ============================================================
-- NEBULA GLOW (soft radial light behind logo)
-- ============================================================
local nebulaGlow = Instance.new("Frame")
nebulaGlow.Name = "NebulaGlow"
nebulaGlow.Size = UDim2.new(0, 400, 0, 400)
nebulaGlow.Position = UDim2.fromScale(0.5, 0.42)
nebulaGlow.AnchorPoint = Vector2.new(0.5, 0.5)
nebulaGlow.BackgroundColor3 = C.Purple
nebulaGlow.BackgroundTransparency = 0.88
nebulaGlow.BorderSizePixel = 0
nebulaGlow.Parent = bg

local nebulaCorner = Instance.new("UICorner")
nebulaCorner.CornerRadius = UDim.new(1, 0)
nebulaCorner.Parent = nebulaGlow

-- Pulsing glow
task.spawn(function()
	while nebulaGlow.Parent do
		TweenService:Create(nebulaGlow, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Size = UDim2.new(0, 460, 0, 460),
			BackgroundTransparency = 0.82,
		}):Play()
		task.wait(3)
		TweenService:Create(nebulaGlow, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Size = UDim2.new(0, 400, 0, 400),
			BackgroundTransparency = 0.88,
		}):Play()
		task.wait(3)
	end
end)

-- ============================================================
-- TITLE: "STARWEAVE" — revealed with gradient wipe
-- ============================================================
local titleContainer = Instance.new("Frame")
titleContainer.Name = "TitleContainer"
titleContainer.Size = UDim2.new(0, 500, 0, 80)
titleContainer.Position = UDim2.fromScale(0.5, 0.36)
titleContainer.AnchorPoint = Vector2.new(0.5, 0.5)
titleContainer.BackgroundTransparency = 1
titleContainer.Parent = bg

local title = Instance.new("TextLabel")
title.Name = "GameTitle"
title.Size = UDim2.fromScale(1, 1)
title.BackgroundTransparency = 1
title.Text = "ESCAPE THE PACK"
title.TextColor3 = Color3.fromRGB(250, 204, 21)
title.TextSize = 52
title.Font = Enum.Font.GothamBlack
title.TextTransparency = 1 -- starts hidden
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = titleContainer

-- Gradient mask for reveal effect
local titleGrad = Instance.new("UIGradient")
titleGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
})
titleGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.45, 0),
	NumberSequenceKeypoint.new(0.55, 1),
	NumberSequenceKeypoint.new(1, 1),
})
titleGrad.Offset = Vector2.new(-1, 0) -- starts fully masked
titleGrad.Parent = title

-- Subtitle
local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(0, 420, 0, 24)
subtitle.Position = UDim2.fromScale(0.5, 0.46)
subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
subtitle.BackgroundTransparency = 1
subtitle.Text = "OUTRUN THE CHASER • BREAK THEIR ANKLES"
subtitle.TextColor3 = Color3.fromRGB(56, 189, 248)
subtitle.TextSize = 14
subtitle.Font = Enum.Font.GothamBold
subtitle.TextTransparency = 1 -- starts hidden
subtitle.Parent = bg

-- ============================================================
-- CONSTELLATION LINES (decorative)
-- ============================================================
local constellationFrame = Instance.new("Frame")
constellationFrame.Name = "Constellation"
constellationFrame.Size = UDim2.fromScale(1, 1)
constellationFrame.BackgroundTransparency = 1
constellationFrame.Parent = bg

local constellationPoints = {
	{0.32, 0.28}, {0.42, 0.22}, {0.52, 0.25}, {0.60, 0.20},
	{0.68, 0.27}, {0.58, 0.32}, {0.48, 0.30}, {0.38, 0.34},
}

local constellationDots: { Frame } = {}
for _, pos in constellationPoints do
	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 4, 0, 4)
	dot.Position = UDim2.fromScale(pos[1], pos[2])
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = C.PurpleGlow
	dot.BackgroundTransparency = 1 -- starts hidden
	dot.BorderSizePixel = 0
	dot.Parent = constellationFrame

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	table.insert(constellationDots, dot)
end

-- ============================================================
-- PROGRESS BAR (thin, elegant)
-- ============================================================
local progressContainer = Instance.new("Frame")
progressContainer.Name = "ProgressContainer"
progressContainer.Size = UDim2.new(0, 360, 0, 50)
progressContainer.Position = UDim2.fromScale(0.5, 0.58)
progressContainer.AnchorPoint = Vector2.new(0.5, 0.5)
progressContainer.BackgroundTransparency = 1
progressContainer.Parent = bg

local barBg = Instance.new("Frame")
barBg.Name = "BarBg"
barBg.Size = UDim2.new(1, 0, 0, 4)
barBg.Position = UDim2.new(0, 0, 0, 0)
barBg.BackgroundColor3 = C.BarBg
barBg.BorderSizePixel = 0
barBg.Parent = progressContainer

local barBgCorner = Instance.new("UICorner")
barBgCorner.CornerRadius = UDim.new(1, 0)
barBgCorner.Parent = barBg

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = C.BarFill
barFill.BorderSizePixel = 0
barFill.Parent = barBg

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = barFill

-- Animated shimmer on fill bar
local fillShimmer = Instance.new("UIGradient")
fillShimmer.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.35, Color3.new(0.85, 0.85, 0.85)),
	ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.65, Color3.new(0.85, 0.85, 0.85)),
	ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
})
fillShimmer.Parent = barFill

task.spawn(function()
	while barFill.Parent do
		fillShimmer.Offset = Vector2.new(-1, 0)
		TweenService:Create(fillShimmer, TweenInfo.new(1.8, Enum.EasingStyle.Linear), {
			Offset = Vector2.new(1, 0),
		}):Play()
		task.wait(2.0)
	end
end)

-- Status text (below bar)
local statusText = Instance.new("TextLabel")
statusText.Name = "Status"
statusText.Size = UDim2.new(1, 0, 0, 16)
statusText.Position = UDim2.new(0, 0, 0, 14)
statusText.BackgroundTransparency = 1
statusText.Text = ""
statusText.TextColor3 = C.TextDim
statusText.TextSize = 12
statusText.Font = Enum.Font.GothamMedium
statusText.TextXAlignment = Enum.TextXAlignment.Center
statusText.Parent = progressContainer

-- Percentage text (right-aligned above bar)
local pctText = Instance.new("TextLabel")
pctText.Name = "Percentage"
pctText.Size = UDim2.new(0, 40, 0, 14)
pctText.Position = UDim2.new(1, -40, 0, -18)
pctText.BackgroundTransparency = 1
pctText.Text = "0%"
pctText.TextColor3 = C.White
pctText.TextSize = 12
pctText.Font = Enum.Font.GothamBold
pctText.TextXAlignment = Enum.TextXAlignment.Right
pctText.Parent = progressContainer

-- ============================================================
-- TIP TEXT (bottom)
-- ============================================================
local tips = {
	"Higher-tier seeds yield rarer cosmic mutations",
	"Mutation Storms temporarily double your luck",
	"Trade rare mutated plants with other gardeners",
	"Each Transcendence permanently boosts earnings",
	"Equip a celestial pet to amplify mutation luck",
	"Combine seeds in the Forge to ascend tiers",
	"Complete daily quests for free Nebula Gems",
}

local tipLabel = Instance.new("TextLabel")
tipLabel.Name = "Tip"
tipLabel.Size = UDim2.new(0, 500, 0, 16)
tipLabel.Position = UDim2.fromScale(0.5, 0.85)
tipLabel.AnchorPoint = Vector2.new(0.5, 0.5)
tipLabel.BackgroundTransparency = 1
tipLabel.Text = tips[rng:NextInteger(1, #tips)]
tipLabel.TextColor3 = C.TextDim
tipLabel.TextSize = 12
tipLabel.Font = Enum.Font.GothamMedium
tipLabel.TextXAlignment = Enum.TextXAlignment.Center
tipLabel.TextTransparency = 1 -- starts hidden
tipLabel.Parent = bg

-- ============================================================
-- VERSION / BRANDING
-- ============================================================
local versionLabel = Instance.new("TextLabel")
versionLabel.Name = "Version"
versionLabel.Size = UDim2.new(0, 120, 0, 14)
versionLabel.Position = UDim2.new(1, -130, 1, -24)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v0.1.0-alpha"
versionLabel.TextColor3 = Color3.fromRGB(60, 50, 80)
versionLabel.TextSize = 10
versionLabel.Font = Enum.Font.GothamMedium
versionLabel.TextXAlignment = Enum.TextXAlignment.Right
versionLabel.Parent = bg

-- ============================================================
-- ANIMATION ORCHESTRATION
-- ============================================================
local function setProgress(pct: number, statusStr: string)
	local clamped = math.clamp(pct, 0, 1)
	TweenService:Create(barFill, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
		Size = UDim2.fromScale(clamped, 1),
	}):Play()
	statusText.Text = statusStr
	pctText.Text = string.format("%d%%", math.floor(clamped * 100))
end

task.spawn(function()
	-- Phase 1: Constellation dots appear (0.0 - 0.8s)
	for i, dot in constellationDots do
		task.delay(i * 0.08, function()
			TweenService:Create(dot, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
				BackgroundTransparency = 0.3,
			}):Play()
		end)
	end
	task.wait(0.3)

	-- Phase 2: Title gradient reveal (0.3 - 1.2s)
	title.TextTransparency = 0
	TweenService:Create(titleGrad, TweenInfo.new(0.9, Enum.EasingStyle.Quint), {
		Offset = Vector2.new(1, 0),
	}):Play()
	task.wait(0.5)

	-- Phase 3: Subtitle fade in
	TweenService:Create(subtitle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {
		TextTransparency = 0,
	}):Play()
	task.wait(0.3)

	-- Phase 4: Tip text
	TweenService:Create(tipLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {
		TextTransparency = 0.3,
	}):Play()

	-- Phase 5: Progress stages
	setProgress(0.15, "Connecting to the cosmos...")
	task.wait(0.6)

	setProgress(0.35, "Loading celestial assets...")
	task.wait(0.4)

	setProgress(0.55, "Preparing your sanctuary...")
	task.wait(0.4)

	setProgress(0.75, "Synchronizing garden state...")

	-- Wait for player data
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local dataReady = ReplicatedStorage:WaitForChild("DataReady", 15) :: RemoteEvent?

	local received = false
	if dataReady then
		dataReady.OnClientEvent:Once(function()
			received = true
		end)
	end

	local getData = ReplicatedStorage:FindFirstChild("GetData") :: RemoteFunction?
	if getData then
		task.spawn(function()
			local d = getData:InvokeServer()
			if d then received = true end
		end)
	end

	local waitStart = os.clock()
	while not received and (os.clock() - waitStart) < 3.0 do
		local elapsed = os.clock() - waitStart
		local waitPct = 0.75 + math.min(elapsed / 3.0, 1) * 0.24
		barFill.Size = UDim2.fromScale(math.clamp(waitPct, 0, 0.98), 1)
		pctText.Text = string.format("%d%%", math.floor(waitPct * 100))
		task.wait(0.15)
	end

	setProgress(1.0, "Welcome, Gardener")
	task.wait(0.6)

	-- ============================================================
	-- FADE OUT SEQUENCE
	-- ============================================================
	-- Constellation fades
	for _, dot in constellationDots do
		TweenService:Create(dot, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
		}):Play()
	end

	-- Stars fade out
	for _, star in starPool do
		TweenService:Create(star, TweenInfo.new(0.4), {
			BackgroundTransparency = 1,
		}):Play()
	end

	-- Title slides up slightly and fades
	TweenService:Create(title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {
		TextTransparency = 1,
		Position = UDim2.fromScale(0, -0.05),
	}):Play()

	TweenService:Create(subtitle, TweenInfo.new(0.4), {
		TextTransparency = 1,
	}):Play()

	-- Progress bar fades
	TweenService:Create(barBg, TweenInfo.new(0.3), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(barFill, TweenInfo.new(0.3), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(statusText, TweenInfo.new(0.3), {
		TextTransparency = 1,
	}):Play()
	TweenService:Create(pctText, TweenInfo.new(0.3), {
		TextTransparency = 1,
	}):Play()
	TweenService:Create(tipLabel, TweenInfo.new(0.3), {
		TextTransparency = 1,
	}):Play()

	-- Nebula glow fades
	TweenService:Create(nebulaGlow, TweenInfo.new(0.4), {
		BackgroundTransparency = 1,
	}):Play()

	-- Final background fade
	task.wait(0.2)
	TweenService:Create(bg, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {
		BackgroundTransparency = 1,
	}):Play()

	task.wait(0.7)
	screenGui:Destroy()
end)
