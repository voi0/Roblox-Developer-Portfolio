--!strict
--[[
	LeaderboardService.luau — Live Plaza Leaderboard for VAULT WARS: STEAL & DEFEND TYCOON
	Renders real-time Server Net Worth rankings and Top Thieves on the Central Monolith,
	featuring player avatar heads, rank badges, and currency formatting.
	Located in: ServerScriptService.Server.Services.LeaderboardService
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LeaderboardService = {}

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

local function formatCurrency(n: number): string
	n = math.floor(n or 0)
	if n >= 1e12 then return string.format("$%.2fT", n / 1e12)
	elseif n >= 1e9 then return string.format("$%.2fB", n / 1e9)
	elseif n >= 1e6 then return string.format("$%.2fM", n / 1e6)
	elseif n >= 1e3 then return string.format("$%.1fK", n / 1e3)
	else return "$" .. tostring(n) end
end

function LeaderboardService.Init()
	print("  [LeaderboardService] Initializing Central Plaza Leaderboard...")

	task.spawn(function()
		while true do
			task.wait(5)
			LeaderboardService.UpdateDisplay()
		end
	end)

	print("  [LeaderboardService] Central Leaderboard online ✓")
end

function LeaderboardService.UpdateDisplay()
	local arena = Workspace:FindFirstChild("VaultWarsArena")
	if not arena then return end

	local monolith = arena:FindFirstChild("CenterMonolith") :: Part?
	if not monolith then return end

	local sGui = monolith:FindFirstChild("LeaderboardGui") :: SurfaceGui?
	if not sGui then return end

	local listFrame = sGui:FindFirstChild("LeaderboardList") :: Frame?
	if not listFrame then return end

	local dataSvc = getDataService()
	if not dataSvc then return end

	-- Collect players & net worth
	local playerList = {}
	for _, p in Players:GetPlayers() do
		local data = dataSvc.GetData(p)
		if data then
			table.insert(playerList, {
				Player = p,
				Name = p.DisplayName,
				Banked = data.BankedCash or 0,
				Stolen = data.TotalCashStolen or 0,
			})
		end
	end

	-- Sort by Banked Cash descending
	table.sort(playerList, function(a, b)
		return a.Banked > b.Banked
	end)

	-- Clear old rows
	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end

	local layout = listFrame:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.Parent = listFrame
	end

	-- Render top rows
	for rank = 1, math.min(8, #playerList) do
		local item = playerList[rank]
		local row = Instance.new("Frame")
		row.Name = "Row_" .. rank
		row.Size = UDim2.new(1, -16, 0, 52)
		row.Position = UDim2.new(0, 8, 0, 0)
		row.BackgroundColor3 = (rank == 1) and Color3.fromRGB(30, 41, 59) or Color3.fromRGB(15, 23, 42)
		row.BorderSizePixel = 0
		row.Parent = listFrame
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

		local rankColor = Color3.fromRGB(203, 213, 225)
		local rankPrefix = `#` .. tostring(rank)
		if rank == 1 then
			rankColor = Color3.fromRGB(250, 204, 21)
			rankPrefix = "#1"
		elseif rank == 2 then
			rankColor = Color3.fromRGB(226, 232, 240)
			rankPrefix = "#2"
		elseif rank == 3 then
			rankColor = Color3.fromRGB(245, 158, 11)
			rankPrefix = "#3"
		end

		local rankLabel = Instance.new("TextLabel")
		rankLabel.Size = UDim2.new(0, 70, 1, 0)
		rankLabel.Position = UDim2.new(0, 10, 0, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.Text = rankPrefix
		rankLabel.TextColor3 = rankColor
		rankLabel.TextSize = 16
		rankLabel.Font = Enum.Font.GothamBlack
		rankLabel.TextXAlignment = Enum.TextXAlignment.Left
		rankLabel.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 180, 1, 0)
		nameLabel.Position = UDim2.new(0, 85, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = item.Name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = row

		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Size = UDim2.new(0, 110, 1, 0)
		scoreLabel.Position = UDim2.new(1, -120, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.Text = formatCurrency(item.Banked)
		scoreLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
		scoreLabel.TextSize = 15
		scoreLabel.Font = Enum.Font.GothamBlack
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.Parent = row
	end
end

return LeaderboardService
