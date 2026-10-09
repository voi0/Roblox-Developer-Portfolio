--!strict
--[[
	ContractModal.luau — Bento-Grid Daily Syndicate Operations & Wanted Board for VAULT WARS
	Displays 3 Daily Operations with live progress bars and claimable rewards,
	alongside the server-wide Wanted Burglary Bounty Board.
	Located in: StarterPlayerScripts.Client.UI.ContractModal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local UILib = require(script.Parent:WaitForChild("UILib"))

local function playSound(action: string)
	local controllers = script.Parent.Parent:FindFirstChild("Controllers")
	local sc = controllers and controllers:FindFirstChild("SoundController")
	if sc then
		local mod = require(sc :: ModuleScript)
		if action == "click" and mod.PlayButtonClick then
			mod.PlayButtonClick()
		elseif action == "success" and mod.PlayPurchaseSuccess then
			mod.PlayPurchaseSuccess()
		end
	end
end

local ContractModal = {}
ContractModal._gui = nil :: ScreenGui?
ContractModal._mainFrame = nil :: Frame?
ContractModal._contractsContainer = nil :: Frame?
ContractModal._bountiesContainer = nil :: Frame?
ContractModal._tokenLabel = nil :: TextLabel?
ContractModal._isOpen = false
ContractModal._cachedContracts = {} :: { [string]: any }
ContractModal._cachedBounties = {} :: { any }

-- ============================================================
-- CONSTRUCT BENTO MODAL
-- ============================================================
function ContractModal.Create(parentGui: ScreenGui)
	ContractModal._gui = parentGui

	local modal = Instance.new("Frame")
	modal.Name = "ContractModal"
	modal.Size = UDim2.new(0, 780, 0, 520)
	modal.Position = UDim2.new(0.5, 0, 0.5, 0)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
	modal.BackgroundTransparency = 0.05
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = parentGui
	ContractModal._mainFrame = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(245, 158, 11)
	stroke.Thickness = 2
	stroke.Parent = modal

	-- ── 1. HEADER ──
	local header = Instance.new("Frame")
	header.Name = "ModalHeader"
	header.Size = UDim2.new(1, -32, 0, 54)
	header.Position = UDim2.new(0, 16, 0, 14)
	header.BackgroundTransparency = 1
	header.Parent = modal

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.65, 0, 0, 28)
	title.BackgroundTransparency = 1
	title.Text = "⚡ SYNDICATE BLACK MARKET OPERATIONS"
	title.TextColor3 = Color3.fromRGB(250, 204, 21)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(0.65, 0, 0, 20)
	sub.Position = UDim2.new(0, 0, 0, 28)
	sub.BackgroundTransparency = 1
	sub.Text = "DAILY HIGH-STAKES CONTRACTS & LIVE SERVER WANTED BOUNTIES"
	sub.TextColor3 = Color3.fromRGB(148, 163, 184)
	sub.TextSize = 11
	sub.Font = Enum.Font.GothamMedium
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Parent = header

	-- Syndicate Token Counter Badge
	local tokenBadge = Instance.new("Frame")
	tokenBadge.Name = "TokenBadge"
	tokenBadge.Size = UDim2.new(0, 150, 0, 36)
	tokenBadge.Position = UDim2.new(1, -200, 0, 8)
	tokenBadge.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	tokenBadge.Parent = header

	local tbCorner = Instance.new("UICorner")
	tbCorner.CornerRadius = UDim.new(0, 10)
	tbCorner.Parent = tokenBadge

	local tbStroke = Instance.new("UIStroke")
	tbStroke.Color = Color3.fromRGB(245, 158, 11)
	tbStroke.Thickness = 1.5
	tbStroke.Parent = tokenBadge

	local tbText = Instance.new("TextLabel")
	tbText.Name = "TokenText"
	tbText.Size = UDim2.new(1, 0, 1, 0)
	tbText.BackgroundTransparency = 1
	tbText.Text = "⚡ TOKENS: 0"
	tbText.TextColor3 = Color3.fromRGB(250, 204, 21)
	tbText.TextSize = 13
	tbText.Font = Enum.Font.GothamBlack
	tbText.Parent = tokenBadge
	ContractModal._tokenLabel = tbText

	-- Close Button [X]
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -36, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.Parent = header

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 10)
	cbCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		playSound("click")
		ContractModal.Close()
	end)

	-- ── 2. TWO-COLUMN BENTO CONTENT ──
	local content = Instance.new("Frame")
	content.Name = "ContentBody"
	content.Size = UDim2.new(1, -32, 1, -88)
	content.Position = UDim2.new(0, 16, 0, 74)
	content.BackgroundTransparency = 1
	content.Parent = modal

	-- Left Column: 3 Daily Contract Cards (65% width)
	local leftCol = Instance.new("ScrollingFrame")
	leftCol.Name = "ContractsCol"
	leftCol.Size = UDim2.new(0.64, 0, 1, 0)
	leftCol.BackgroundTransparency = 1
	leftCol.BorderSizePixel = 0
	leftCol.ScrollBarThickness = 4
	leftCol.ScrollBarImageColor3 = Color3.fromRGB(245, 158, 11)
	leftCol.Parent = content
	ContractModal._contractsContainer = leftCol

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = leftCol

	-- Right Column: Server Wanted Bounty Board (34% width)
	local rightCol = Instance.new("Frame")
	rightCol.Name = "BountiesCol"
	rightCol.Size = UDim2.new(0.34, 0, 1, 0)
	rightCol.Position = UDim2.new(0.66, 0, 0, 0)
	rightCol.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	rightCol.Parent = content

	local rcCorner = Instance.new("UICorner")
	rcCorner.CornerRadius = UDim.new(0, 14)
	rcCorner.Parent = rightCol

	local rcStroke = Instance.new("UIStroke")
	rcStroke.Color = Color3.fromRGB(239, 68, 68)
	rcStroke.Thickness = 1.5
	rcStroke.Parent = rightCol

	local bHeader = Instance.new("TextLabel")
	bHeader.Size = UDim2.new(1, -16, 0, 36)
	bHeader.Position = UDim2.new(0, 8, 0, 8)
	bHeader.BackgroundTransparency = 1
	bHeader.Text = "🎯 WANTED BURGLARS"
	bHeader.TextColor3 = Color3.fromRGB(239, 68, 68)
	bHeader.TextSize = 14
	bHeader.Font = Enum.Font.GothamBlack
	bHeader.Parent = rightCol

	local bountyList = Instance.new("Frame")
	bountyList.Name = "BountyList"
	bountyList.Size = UDim2.new(1, -16, 1, -50)
	bountyList.Position = UDim2.new(0, 8, 0, 44)
	bountyList.BackgroundTransparency = 1
	bountyList.Parent = rightCol
	ContractModal._bountiesContainer = bountyList

	local blLayout = Instance.new("UIListLayout")
	blLayout.Padding = UDim.new(0, 8)
	blLayout.SortOrder = Enum.SortOrder.LayoutOrder
	blLayout.Parent = bountyList

	-- Listen for server open remote
	local openEvt = ReplicatedStorage:WaitForChild("OpenContractModal", 10) :: RemoteEvent?
	if openEvt then
		openEvt.OnClientEvent:Connect(function()
			ContractModal.Open()
		end)
	end

	-- Listen for progress updates
	local updateEvt = ReplicatedStorage:WaitForChild("ContractProgressUpdated", 10) :: RemoteEvent?
	if updateEvt then
		updateEvt.OnClientEvent:Connect(function(contracts: any)
			ContractModal._cachedContracts = contracts or {}
			ContractModal.Refresh()
		end)
	end
end

-- ============================================================
-- REFRESH UI STATE
-- ============================================================
function ContractModal.Refresh()
	if not ContractModal._contractsContainer or not ContractModal._bountiesContainer then return end

	-- Update Tokens
	local dataRF = ReplicatedStorage:FindFirstChild("GetData") :: RemoteFunction?
	if dataRF then
		task.spawn(function()
			local data = dataRF:InvokeServer()
			if data and ContractModal._tokenLabel then
				ContractModal._tokenLabel.Text = `⚡ TOKENS: {data.SyndicateTokens or 0}`
			end
		end)
	end

	-- ── 1. POPULATE CONTRACTS ──
	for _, child in ContractModal._contractsContainer:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end

	local contracts = ContractModal._cachedContracts
	local count = 0

	for id, contract in contracts do
		count += 1
		local card = Instance.new("Frame")
		card.Name = `Card_{id}`
		card.Size = UDim2.new(1, 0, 0, 120)
		card.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
		card.Parent = ContractModal._contractsContainer

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 12)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = contract.IsCompleted and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(71, 85, 105)
		cStroke.Thickness = 1.5
		cStroke.Parent = card

		-- Title
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(0.65, 0, 0, 22)
		title.Position = UDim2.new(0, 12, 0, 10)
		title.BackgroundTransparency = 1
		title.Text = contract.Title
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextSize = 13
		title.Font = Enum.Font.GothamBlack
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = card

		-- Description
		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(0.65, 0, 0, 32)
		desc.Position = UDim2.new(0, 12, 0, 32)
		desc.BackgroundTransparency = 1
		desc.Text = contract.Description
		desc.TextColor3 = Color3.fromRGB(148, 163, 184)
		desc.TextSize = 11
		desc.Font = Enum.Font.Gotham
		desc.TextWrapped = true
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Parent = card

		-- Progress Bar Background
		local pBg = Instance.new("Frame")
		pBg.Size = UDim2.new(0.65, 0, 0, 12)
		pBg.Position = UDim2.new(0, 12, 0, 72)
		pBg.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
		pBg.Parent = card

		local pbCorner = Instance.new("UICorner")
		pbCorner.CornerRadius = UDim.new(0, 6)
		pbCorner.Parent = pBg

		-- Progress Bar Fill
		local pct = math.clamp(contract.CurrentCount / math.max(1, contract.TargetCount), 0, 1)
		local pFill = Instance.new("Frame")
		pFill.Size = UDim2.new(pct, 0, 1, 0)
		pFill.BackgroundColor3 = contract.IsCompleted and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(245, 158, 11)
		pFill.Parent = pBg

		local pfCorner = Instance.new("UICorner")
		pfCorner.CornerRadius = UDim.new(0, 6)
		pfCorner.Parent = pFill

		-- Progress Numeric Label
		local pNum = Instance.new("TextLabel")
		pNum.Size = UDim2.new(0.65, 0, 0, 18)
		pNum.Position = UDim2.new(0, 12, 0, 88)
		pNum.BackgroundTransparency = 1
		pNum.Text = `{contract.CurrentCount} / {contract.TargetCount}`
		pNum.TextColor3 = Color3.fromRGB(203, 213, 225)
		pNum.TextSize = 10
		pNum.Font = Enum.Font.GothamBold
		pNum.TextXAlignment = Enum.TextXAlignment.Left
		pNum.Parent = card

		-- Rewards Text
		local rText = Instance.new("TextLabel")
		rText.Size = UDim2.new(0.3, 0, 0, 48)
		rText.Position = UDim2.new(0.68, 0, 0, 10)
		rText.BackgroundTransparency = 1
		rText.Text = `+${contract.RewardCash} Cash\n+{contract.RewardXP} XP\n+{contract.RewardTokens} ⚡ Tokens`
		rText.TextColor3 = Color3.fromRGB(250, 204, 21)
		rText.TextSize = 11
		rText.Font = Enum.Font.GothamBold
		rText.TextXAlignment = Enum.TextXAlignment.Right
		rText.Parent = card

		-- Claim / Status Button
		local actionBtn = Instance.new("TextButton")
		actionBtn.Size = UDim2.new(0.28, 0, 0, 36)
		actionBtn.Position = UDim2.new(0.70, 0, 0, 68)
		actionBtn.Parent = card

		local abCorner = Instance.new("UICorner")
		abCorner.CornerRadius = UDim.new(0, 10)
		abCorner.Parent = actionBtn

		if contract.IsClaimed then
			actionBtn.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
			actionBtn.Text = "CLAIMED ✓"
			actionBtn.TextColor3 = Color3.fromRGB(148, 163, 184)
			actionBtn.Active = false
		elseif contract.IsCompleted then
			actionBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
			actionBtn.Text = "CLAIM REWARD"
			actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			actionBtn.Font = Enum.Font.GothamBlack
			actionBtn.TextSize = 11

			actionBtn.MouseButton1Click:Connect(function()
				playSound("success")
				local claimRF = ReplicatedStorage:FindFirstChild("ClaimContractReward") :: RemoteFunction?
				if claimRF then
					task.spawn(function()
						local success, msg = claimRF:InvokeServer(contract.Id)
						if success then
							contract.IsClaimed = true
							ContractModal.Refresh()
						end
					end)
				end
			end)
		else
			actionBtn.BackgroundColor3 = Color3.fromRGB(39, 39, 42)
			actionBtn.Text = "IN PROGRESS"
			actionBtn.TextColor3 = Color3.fromRGB(113, 113, 122)
			actionBtn.Font = Enum.Font.Gotham
			actionBtn.TextSize = 11
			actionBtn.Active = false
		end
	end

	-- ── 2. POPULATE WANTED BOUNTIES ──
	for _, child in ContractModal._bountiesContainer:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end

	local bountiesRF = ReplicatedStorage:FindFirstChild("GetWantedBounties") :: RemoteFunction?
	if bountiesRF then
		task.spawn(function()
			local list = bountiesRF:InvokeServer()
			if not list or not ContractModal._bountiesContainer then return end

			for idx, b in list do
				local bCard = Instance.new("Frame")
				bCard.Name = `Bounty_{idx}`
				bCard.Size = UDim2.new(1, 0, 0, 80)
				bCard.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
				bCard.Parent = ContractModal._bountiesContainer

				local bcCorner = Instance.new("UICorner")
				bcCorner.CornerRadius = UDim.new(0, 10)
				bcCorner.Parent = bCard

				local bcStroke = Instance.new("UIStroke")
				bcStroke.Color = (idx == 1) and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(71, 85, 105)
				bcStroke.Thickness = 1
				bcStroke.Parent = bCard

				local rankBadge = Instance.new("TextLabel")
				rankBadge.Size = UDim2.new(0, 24, 0, 24)
				rankBadge.Position = UDim2.new(0, 8, 0, 8)
				rankBadge.BackgroundColor3 = (idx == 1) and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(51, 65, 85)
				rankBadge.Text = `#{idx}`
				rankBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
				rankBadge.TextSize = 11
				rankBadge.Font = Enum.Font.GothamBlack
				rankBadge.Parent = bCard

				local rbCorner = Instance.new("UICorner")
				rbCorner.CornerRadius = UDim.new(0, 6)
				rbCorner.Parent = rankBadge

				local pName = Instance.new("TextLabel")
				pName.Size = UDim2.new(1, -44, 0, 22)
				pName.Position = UDim2.new(0, 38, 0, 8)
				pName.BackgroundTransparency = 1
				pName.Text = b.DisplayName
				pName.TextColor3 = Color3.fromRGB(241, 245, 249)
				pName.TextSize = 12
				pName.Font = Enum.Font.GothamBold
				pName.TextXAlignment = Enum.TextXAlignment.Left
				pName.Parent = bCard

				local bountyVal = Instance.new("TextLabel")
				bountyVal.Size = UDim2.new(1, -16, 0, 20)
				bountyVal.Position = UDim2.new(0, 8, 0, 36)
				bountyVal.BackgroundTransparency = 1
				bountyVal.Text = `BOUNTY: ${b.BountyCash}`
				bountyVal.TextColor3 = Color3.fromRGB(250, 204, 21)
				bountyVal.TextSize = 12
				bountyVal.Font = Enum.Font.GothamBlack
				bountyVal.TextXAlignment = Enum.TextXAlignment.Left
				bountyVal.Parent = bCard

				local subText = Instance.new("TextLabel")
				subText.Size = UDim2.new(1, -16, 0, 16)
				subText.Position = UDim2.new(0, 8, 0, 58)
				subText.BackgroundTransparency = 1
				subText.Text = `Carried: ${b.UnbankedCash} | Heists: {b.HeistsWon}`
				subText.TextColor3 = Color3.fromRGB(148, 163, 184)
				subText.TextSize = 10
				subText.Font = Enum.Font.Gotham
				subText.TextXAlignment = Enum.TextXAlignment.Left
				subText.Parent = bCard
			end
		end)
	end
end

-- ============================================================
-- OPEN / CLOSE MODAL
-- ============================================================
function ContractModal.Open()
	if ContractModal._isOpen then return end
	ContractModal._isOpen = true

	local getRF = ReplicatedStorage:FindFirstChild("GetContracts") :: RemoteFunction?
	if getRF then
		task.spawn(function()
			local res = getRF:InvokeServer()
			ContractModal._cachedContracts = res or {}
			ContractModal.Refresh()
		end)
	end

	if ContractModal._mainFrame then
		ContractModal._mainFrame.Visible = true
		ContractModal._mainFrame.Position = UDim2.new(0.5, 0, 0.55, 0)
		ContractModal._mainFrame.BackgroundTransparency = 0.5
		TweenService:Create(ContractModal._mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundTransparency = 0.05,
		}):Play()
	end
end

function ContractModal.Close()
	if not ContractModal._isOpen then return end
	ContractModal._isOpen = false

	if ContractModal._mainFrame then
		local tw = TweenService:Create(ContractModal._mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0.55, 0),
			BackgroundTransparency = 1,
		})
		tw:Play()
		tw.Completed:Connect(function()
			if not ContractModal._isOpen and ContractModal._mainFrame then
				ContractModal._mainFrame.Visible = false
			end
		end)
	end
end

function ContractModal.IsOpen(): boolean
	return ContractModal._isOpen
end

return ContractModal
