--!strict
--[[
	RoundService.luau — Authoritative Game Loop State Machine for ESCAPE THE PACK
	Controls Intermission, Hero Selection, 3 Crossing Waves, Infection, and Rewards.
	Located in: ServerScriptService.Server.Services.RoundService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local RoundService = {}
RoundService._state = "Intermission" :: Types.RoundState
RoundService._waveIndex = 1
RoundService._timeRemaining = 0
RoundService._roles = {} :: { [Player]: Types.PlayerRole }
RoundService._heroPlayer = nil :: Player?
RoundService._isHeroMode = false
RoundService._safeRunners = {} :: { [Player]: boolean }

local function getArenaService(): any?
	local svc = script.Parent:FindFirstChild("ArenaService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

local function getTagService(): any?
	local svc = script.Parent:FindFirstChild("TagService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

local function getDataService(): any?
	local svc = script.Parent:FindFirstChild("DataService")
	if svc then return require(svc :: ModuleScript) end
	return nil
end

-- ============================================================
-- BROADCAST HELPERS
-- ============================================================
local function broadcastState()
	local evt = ReplicatedStorage:FindFirstChild("RoundStateChanged") :: RemoteEvent?
	if evt then
		local aliveRunners = 0
		local chasers = 0
		for p, role in RoundService._roles do
			if role == "Runner" and not (getTagService() and getTagService().IsDowned(p)) then
				aliveRunners += 1
			elseif role == "Chaser" then
				chasers += 1
			end
		end

		for _, p in Players:GetPlayers() do
			evt:FireClient(p, {
				State = RoundService._state,
				WaveIndex = RoundService._waveIndex,
				TimeRemaining = RoundService._timeRemaining,
				AliveRunners = aliveRunners,
				Chasers = chasers,
				IsHeroMode = RoundService._isHeroMode,
				HeroName = RoundService._heroPlayer and RoundService._heroPlayer.DisplayName or nil,
				MyRole = RoundService._roles[p] or "Spectator",
			})
		end
	end
end

-- ============================================================
-- CORE LOOP RUNNER
-- ============================================================
function RoundService.Init()
	print("  [RoundService] Initializing Game Loop State Machine...")

	local remotes = { "RoundStateChanged", "HeroPrompt", "HeroDecision", "WaveCrossed" }
	for _, name in remotes do
		if not ReplicatedStorage:FindFirstChild(name) then
			local evt = Instance.new("RemoteEvent")
			evt.Name = name
			evt.Parent = ReplicatedStorage
		end
	end

	-- Listen for Hero Decision response
	local heroDecisionEvt = ReplicatedStorage:FindFirstChild("HeroDecision") :: RemoteEvent?
	if heroDecisionEvt then
		heroDecisionEvt.OnServerEvent:Connect(function(player: Player, choice: string)
			if player == RoundService._heroPlayer and RoundService._state == "HeroSelection" then
				RoundService._isHeroMode = (choice == "Hero")
				print(`  [RoundService] {player.Name} chose: {choice}!`)
			end
		end)
	end

	-- Connect Player Leaving to clear roles
	Players.PlayerRemoving:Connect(function(p: Player)
		RoundService._roles[p] = nil
		RoundService._safeRunners[p] = nil
		if RoundService._heroPlayer == p then
			RoundService._heroPlayer = nil
		end
	end)

	-- Start loop in background thread
	task.spawn(RoundService._mainLoop)

	print("  [RoundService] Game Loop State Machine online ✓")
end

function RoundService._mainLoop()
	while true do
		-- ── 1. INTERMISSION ──
		RoundService._state = "Intermission"
		RoundService._heroPlayer = nil
		RoundService._isHeroMode = false
		RoundService._roles = {}
		RoundService._safeRunners = {}
		local tagSvc = getTagService()
		if tagSvc then tagSvc.ResetAll() end

		local arenaSvc = getArenaService()
		if arenaSvc then
			arenaSvc.SetStartGate(true)
			arenaSvc.SetFinishGate(true)
		end

		local intermissionTime = Config.Round.IntermissionDuration
		while intermissionTime > 0 do
			RoundService._timeRemaining = intermissionTime
			broadcastState()
			task.wait(1)
			intermissionTime -= 1
		end

		-- Check player count
		local allPlayers = Players:GetPlayers()
		if #allPlayers < Config.Round.MinPlayersToStart then
			task.wait(2)
			continue
		end

		-- ── 2. TEAM ASSIGNMENT ──
		-- 1 Random Chaser, rest are Runners
		local chaserIndex = math.random(1, #allPlayers)
		local initialChaser = allPlayers[chaserIndex]

		for i, p in allPlayers do
			if p == initialChaser and #allPlayers > 1 then
				RoundService._roles[p] = "Chaser"
			else
				RoundService._roles[p] = "Runner"
			end
		end
		-- In singleplayer Studio test, assign player as Runner to test crossing!
		if #allPlayers == 1 then
			RoundService._roles[allPlayers[1]] = "Runner"
		end

		-- ── 3. HERO SELECTION ──
		local runnerCandidates = {}
		for p, role in RoundService._roles do
			if role == "Runner" then table.insert(runnerCandidates, p) end
		end

		if #runnerCandidates > 0 then
			local selectedHero = runnerCandidates[math.random(1, #runnerCandidates)]
			RoundService._heroPlayer = selectedHero
			RoundService._state = "HeroSelection"

			local heroPromptEvt = ReplicatedStorage:FindFirstChild("HeroPrompt") :: RemoteEvent?
			if heroPromptEvt then
				heroPromptEvt:FireClient(selectedHero)
			end

			local heroTimer = Config.Round.HeroSelectionDuration
			while heroTimer > 0 do
				RoundService._timeRemaining = heroTimer
				broadcastState()
				task.wait(1)
				heroTimer -= 1
			end
		end

		-- ── 4. THREE CROSSING WAVES ──
		local matchWon = false
		for wave = 1, Config.Round.TotalWaves do
			RoundService._waveIndex = wave
			RoundService._state = "RoundActive"
			RoundService._safeRunners = {}

			-- Teleport Players to starting end of this wave
			local isForward = (wave % 2 == 1)
			local startCF = isForward and arenaSvc.GetStartZoneCFrame() or arenaSvc.GetFinishZoneCFrame()
			local finishCF = isForward and arenaSvc.GetFinishZoneCFrame() or arenaSvc.GetStartZoneCFrame()

			for p, role in RoundService._roles do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					if role == "Runner" then
						if RoundService._isHeroMode and p ~= RoundService._heroPlayer then
							-- Spectate in safe zone behind gate
							root.CFrame = startCF + Vector3.new(math.random(-15, 15), 3, math.random(-8, 8))
						else
							root.CFrame = startCF + Vector3.new(math.random(-25, 25), 3, math.random(-8, 8))
						end
					elseif role == "Chaser" then
						-- Chaser spawns in center arena
						root.CFrame = CFrame.new(0, 3, 0)
					end
				end
			end

			-- Countdown Gate Drop (3 seconds)
			if arenaSvc then
				arenaSvc.SetStartGate(true)
			end
			for countdown = 3, 1, -1 do
				RoundService._timeRemaining = countdown
				broadcastState()
				task.wait(1)
			end

			-- Gates Open!
			if arenaSvc then
				arenaSvc.SetStartGate(false)
				arenaSvc.SetFinishGate(false)
			end

			-- Active Wave Timer (35 seconds)
			local waveTime = Config.Round.WaveDuration
			while waveTime > 0 do
				RoundService._timeRemaining = waveTime

				-- Check if runners reached the goal
				for p, role in RoundService._roles do
					if role == "Runner" and not RoundService._safeRunners[p] and not (tagSvc and tagSvc.IsDowned(p)) then
						local char = p.Character
						local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and arenaSvc and arenaSvc.IsInFinishZone(root.Position, wave) then
							RoundService._safeRunners[p] = true
							local dataSvc = getDataService()
							if dataSvc then dataSvc.RecordWaveCrossing(p) end

							local waveCrossedEvt = ReplicatedStorage:FindFirstChild("WaveCrossed") :: RemoteEvent?
							if waveCrossedEvt then waveCrossedEvt:FireClient(p, wave) end
						end
					end
				end

				-- Check if all runners are safe or downed
				local activeRunnersLeft = 0
				for p, role in RoundService._roles do
					if role == "Runner" and not RoundService._safeRunners[p] and not (tagSvc and tagSvc.IsDowned(p)) then
						activeRunnersLeft += 1
					end
				end

				if activeRunnersLeft == 0 then
					break -- Wave completed early!
				end

				broadcastState()
				task.wait(1)
				waveTime -= 1
			end

			-- Wave Over: Close gates
			if arenaSvc then
				arenaSvc.SetStartGate(true)
				arenaSvc.SetFinishGate(true)
			end

			-- ── INFECTION STEP: Convert any un-revived downed runners into Chasers ──
			for p, role in RoundService._roles do
				if role == "Runner" then
					if (tagSvc and tagSvc.IsDowned(p)) or not RoundService._safeRunners[p] then
						RoundService._roles[p] = "Chaser"
						if tagSvc then tagSvc.ClearDowned(p) end
						print(`  [RoundService] {p.Name} failed crossing and converted to CHASER!`)
					end
				end
			end

			-- Check if any runners survived
			local remainingRunners = 0
			for _, role in RoundService._roles do
				if role == "Runner" then remainingRunners += 1 end
			end

			if remainingRunners == 0 then
				print("  [RoundService] All runners eliminated! Chasers Win!")
				break
			end

			if wave == Config.Round.TotalWaves then
				matchWon = true
			else
				-- Rest between waves
				RoundService._state = "RoundIntermission"
				task.wait(Config.Round.InterWaveRest)
			end
		end

		-- ── 5. MATCH OVER & REWARDS ──
		RoundService._state = "MatchOver"
		RoundService._timeRemaining = 6

		local dataSvc = getDataService()
		for p, role in RoundService._roles do
			if role == "Runner" and matchWon then
				local isHero = (RoundService._isHeroMode and p == RoundService._heroPlayer)
				if dataSvc then dataSvc.RecordMatchWin(p, isHero) end
			end
		end

		while RoundService._timeRemaining > 0 do
			broadcastState()
			task.wait(1)
			RoundService._timeRemaining -= 1
		end

		-- Teleport everyone back to Spectator Lobby
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and arenaSvc then
				root.CFrame = arenaSvc.GetLobbyCFrame() + Vector3.new(math.random(-15, 15), 0, math.random(-10, 10))
			end
		end
	end
end

-- ============================================================
-- PUBLIC ACCESSORS
-- ============================================================
function RoundService.GetPlayerRole(player: Player): Types.PlayerRole
	return RoundService._roles[player] or "Spectator"
end

function RoundService.IsRoundActive(): boolean
	return RoundService._state == "RoundActive"
end

function RoundService.GetState(): Types.RoundState
	return RoundService._state
end

return RoundService
