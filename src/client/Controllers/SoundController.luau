--!strict
--[[
	SoundController.luau — Audio and Acoustic Experience for STARWEAVE
	Handles sound effects for UI micro-interactions, planting, harvesting,
	rare mutation fanfares, ambient celestial tone, and looping BGM.
	Located in: StarterPlayerScripts.Client.Controllers.SoundController
]]

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local SoundController = {}
SoundController._sounds = {} :: { [string]: Sound }
SoundController._soundGroup = nil :: SoundGroup?
SoundController._bgmSound = nil :: Sound?
SoundController._isMuted = false

-- Curated Roblox universal sound assets for crisp, satisfying game feel
local SOUND_CONFIG = {
	ButtonClick = {
		Id = "rbxassetid://6895079853",
		Volume = 0.5,
		PitchRange = { 0.95, 1.05 },
	},
	ButtonHover = {
		Id = "rbxassetid://6895079683",
		Volume = 0.25,
		PitchRange = { 1.0, 1.1 },
	},
	PlantSeed = {
		Id = "rbxassetid://9114223170",
		Volume = 0.65,
		PitchRange = { 0.9, 1.1 },
	},
	PlantReady = {
		Id = "rbxassetid://9069609200",
		Volume = 0.7,
		PitchRange = { 0.98, 1.02 },
	},
	HarvestCommon = {
		Id = "rbxassetid://6026978586",
		Volume = 0.6,
		PitchRange = { 0.95, 1.05 },
	},
	HarvestRare = {
		Id = "rbxassetid://5153734608",
		Volume = 0.85,
		PitchRange = { 1.0, 1.05 },
	},
	HarvestPrimordial = {
		Id = "rbxassetid://138090596",
		Volume = 1.0,
		PitchRange = { 0.95, 1.0 },
	},
	RebirthAscend = {
		Id = "rbxassetid://4590662766",
		Volume = 0.9,
		PitchRange = { 1.0, 1.0 },
	},
	StormAlert = {
		Id = "rbxassetid://5530115049",
		Volume = 0.75,
		PitchRange = { 1.0, 1.0 },
	},
}

-- Ethereal cosmic soundtrack
local BGM_ASSET_ID = "rbxassetid://1843404009"

function SoundController.Init()
	local soundGroup = Instance.new("SoundGroup")
	soundGroup.Name = "StarweaveAudio"
	soundGroup.Volume = 0.85
	soundGroup.Parent = SoundService
	SoundController._soundGroup = soundGroup

	local soundsToPreload: { Instance } = {}

	for name, config in SOUND_CONFIG do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = config.Id
		sound.Volume = config.Volume
		sound.SoundGroup = soundGroup
		sound.Parent = soundGroup
		SoundController._sounds[name] = sound
		table.insert(soundsToPreload, sound)
	end

	-- Ambient Looping BGM
	local bgm = Instance.new("Sound")
	bgm.Name = "CosmicAmbianceBGM"
	bgm.SoundId = BGM_ASSET_ID
	bgm.Volume = 0.28
	bgm.Looped = true
	bgm.SoundGroup = soundGroup
	bgm.Parent = soundGroup
	SoundController._bgmSound = bgm
	table.insert(soundsToPreload, bgm)

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(soundsToPreload)
		end)
		-- Start soft BGM fade-in
		if SoundController._bgmSound and not SoundController._isMuted then
			SoundController._bgmSound:Play()
		end
	end)
end

function SoundController.Play(name: string, customPitch: number?)
	if SoundController._isMuted then return end

	local sound = SoundController._sounds[name]
	if not sound then return end

	local config = SOUND_CONFIG[name]
	local soundInstance = sound:Clone()
	soundInstance.Parent = SoundController._soundGroup

	if customPitch then
		soundInstance.PlaybackSpeed = customPitch
	elseif config and config.PitchRange then
		local minP = config.PitchRange[1]
		local maxP = config.PitchRange[2]
		soundInstance.PlaybackSpeed = minP + math.random() * (maxP - minP)
	end

	soundInstance:Play()
	soundInstance.Ended:Once(function()
		soundInstance:Destroy()
	end)
end

function SoundController.ToggleMute(): boolean
	SoundController._isMuted = not SoundController._isMuted
	if SoundController._soundGroup then
		SoundController._soundGroup.Volume = SoundController._isMuted and 0 or 0.85
	end
	return SoundController._isMuted
end

function SoundController.SetBGMVolume(volume: number)
	if SoundController._bgmSound then
		SoundController._bgmSound.Volume = math.clamp(volume, 0, 1)
	end
end

return SoundController
