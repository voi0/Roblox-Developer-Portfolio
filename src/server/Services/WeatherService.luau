--!strict
--[[
	WeatherService.luau — Dynamic Cosmic Atmospheric Weather System for STARWEAVE
	Cycles between 4 dynamic celestial weather phenomena:
	  - 🌌 SUPERNOVA AURORA: +150% Mutation Luck, purple sky & nebula shimmer
	  - 🌠 METEOR SHOWER: 2.0x Stardust Harvest Sell Multiplier, golden meteor trails
	  - ☀️ SOLAR FLARE: 3.0x Crop Growth Speed, warm golden radiance
	  - ✨ CALM STARLIGHT: Peaceful celestial sanctuary
	Located in: ServerScriptService.Server.Services.WeatherService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local WeatherService = {}
WeatherService._initialized = false
WeatherService._activeWeather = "clear"
WeatherService._timeRemaining = 0

WeatherService.Events = {
	supernova = {
		Id = "supernova",
		Name = "SUPERNOVA AURORA",
		Icon = "🌌",
		Description = "Celestial Aurora envelops the sanctuary! Mutation Luck +150%!",
		MultiplierText = "2.5x LUCK",
		LuckMultiplier = 2.5,
		SellMultiplier = 1.0,
		GrowthMultiplier = 1.0,
		BadgeColor = Color3.fromRGB(192, 132, 252),
		Ambient = Color3.fromRGB(150, 90, 210),
		OutdoorAmbient = Color3.fromRGB(180, 110, 240),
		ColorShift_Top = Color3.fromRGB(220, 150, 255),
		ColorShift_Bottom = Color3.fromRGB(100, 40, 160),
		FogColor = Color3.fromRGB(80, 40, 120),
	},
	meteor_shower = {
		Id = "meteor_shower",
		Name = "METEOR SHOWER",
		Icon = "🌠",
		Description = "Stardust meteors rain from the cosmos! All crop sell value doubled!",
		MultiplierText = "2.0x SELL",
		LuckMultiplier = 1.0,
		SellMultiplier = 2.0,
		GrowthMultiplier = 1.0,
		BadgeColor = Color3.fromRGB(250, 204, 21),
		Ambient = Color3.fromRGB(210, 160, 80),
		OutdoorAmbient = Color3.fromRGB(240, 190, 100),
		ColorShift_Top = Color3.fromRGB(255, 230, 150),
		ColorShift_Bottom = Color3.fromRGB(130, 80, 20),
		FogColor = Color3.fromRGB(90, 55, 20),
	},
	solar_flare = {
		Id = "solar_flare",
		Name = "SOLAR FLARE",
		Icon = "☀️",
		Description = "Solar radiance intensifies! Crops grow 3x faster!",
		MultiplierText = "3.0x GROWTH",
		LuckMultiplier = 1.0,
		SellMultiplier = 1.0,
		GrowthMultiplier = 3.0,
		BadgeColor = Color3.fromRGB(251, 146, 60),
		Ambient = Color3.fromRGB(220, 120, 70),
		OutdoorAmbient = Color3.fromRGB(255, 150, 90),
		ColorShift_Top = Color3.fromRGB(255, 200, 120),
		ColorShift_Bottom = Color3.fromRGB(150, 65, 30),
		FogColor = Color3.fromRGB(110, 45, 25),
	},
	clear = {
		Id = "clear",
		Name = "CALM STARLIGHT",
		Icon = "✨",
		Description = "Peaceful tranquility fills the cosmic sanctuary.",
		MultiplierText = "NORMAL",
		LuckMultiplier = 1.0,
		SellMultiplier = 1.0,
		GrowthMultiplier = 1.0,
		BadgeColor = Color3.fromRGB(148, 163, 184),
		Ambient = Color3.fromRGB(120, 110, 160),
		OutdoorAmbient = Color3.fromRGB(145, 135, 185),
		ColorShift_Top = Color3.fromRGB(245, 230, 255),
		ColorShift_Bottom = Color3.fromRGB(80, 65, 120),
		FogColor = Color3.fromRGB(45, 30, 75),
	},
}

local STORM_SEQUENCE = { "meteor_shower", "supernova", "solar_flare" }
local CALM_DURATION = 80 -- seconds between storms
local STORM_DURATION = 45 -- duration of storm event

function WeatherService.GetActiveWeather(): any
	return WeatherService.Events[WeatherService._activeWeather] or WeatherService.Events.clear
end

function WeatherService.GetLuckMultiplier(): number
	local w = WeatherService.GetActiveWeather()
	return w.LuckMultiplier or 1.0
end

function WeatherService.GetSellMultiplier(): number
	local w = WeatherService.GetActiveWeather()
	return w.SellMultiplier or 1.0
end

function WeatherService.GetGrowthMultiplier(): number
	local w = WeatherService.GetActiveWeather()
	return w.GrowthMultiplier or 1.0
end

function WeatherService.GetTimeRemaining(): number
	return WeatherService._timeRemaining
end

function WeatherService.SetWeather(weatherId: string, duration: number)
	local weather = WeatherService.Events[weatherId] or WeatherService.Events.clear
	WeatherService._activeWeather = weather.Id
	WeatherService._timeRemaining = duration

	-- Apply server lighting
	Lighting.Ambient = weather.Ambient
	Lighting.OutdoorAmbient = weather.OutdoorAmbient
	Lighting.ColorShift_Top = weather.ColorShift_Top
	Lighting.ColorShift_Bottom = weather.ColorShift_Bottom
	Lighting.FogColor = weather.FogColor

	-- Broadcast to all clients
	local weatherEvent = ReplicatedStorage:FindFirstChild("WeatherChanged")
	if weatherEvent and weatherEvent:IsA("RemoteEvent") then
		weatherEvent:FireAllClients({
			Id = weather.Id,
			Name = weather.Name,
			Icon = weather.Icon,
			Description = weather.Description,
			MultiplierText = weather.MultiplierText,
			Duration = duration,
			BadgeColor = weather.BadgeColor,
			Ambient = weather.Ambient,
			OutdoorAmbient = weather.OutdoorAmbient,
			ColorShift_Top = weather.ColorShift_Top,
			IsActive = (weather.Id ~= "clear"),
		})
	end

	-- Announce to server if active storm
	if weather.Id ~= "clear" then
		local announceEvent = ReplicatedStorage:FindFirstChild("ServerAnnouncement")
		if announceEvent and announceEvent:IsA("RemoteEvent") then
			announceEvent:FireAllClients(string.format("%s %s STARTED! %s", weather.Icon, weather.Name, weather.Description), "Celestial")
		end
	end

	print(string.format("[WeatherService] Weather transitioned to %s (%ds)", weather.Name, duration))
end

function WeatherService.Init()
	if WeatherService._initialized then return end
	WeatherService._initialized = true

	-- Remote event for weather synchronization
	local weatherEvent = ReplicatedStorage:FindFirstChild("WeatherChanged")
	if not weatherEvent then
		weatherEvent = Instance.new("RemoteEvent")
		weatherEvent.Name = "WeatherChanged"
		weatherEvent.Parent = ReplicatedStorage
	end

	-- Remote function for client weather state queries
	local weatherReq = Instance.new("RemoteFunction")
	weatherReq.Name = "WeatherRequest"
	weatherReq.Parent = ReplicatedStorage

	weatherReq.OnServerInvoke = function(player: Player)
		local current = WeatherService.GetActiveWeather()
		return {
			Id = current.Id,
			Name = current.Name,
			Icon = current.Icon,
			Description = current.Description,
			MultiplierText = current.MultiplierText,
			Duration = WeatherService._timeRemaining,
			BadgeColor = current.BadgeColor,
			IsActive = (current.Id ~= "clear"),
		}
	end

	-- Sync weather state to newly joined players
	Players.PlayerAdded:Connect(function(player)
		local current = WeatherService.GetActiveWeather()
		task.delay(1.5, function()
			if player.Parent and weatherEvent then
				weatherEvent:FireClient(player, {
					Id = current.Id,
					Name = current.Name,
					Icon = current.Icon,
					Description = current.Description,
					MultiplierText = current.MultiplierText,
					Duration = WeatherService._timeRemaining,
					BadgeColor = current.BadgeColor,
					Ambient = current.Ambient,
					OutdoorAmbient = current.OutdoorAmbient,
					ColorShift_Top = current.ColorShift_Top,
					IsActive = (current.Id ~= "clear"),
				})
			end
		end)
	end)

	-- Master Weather Cycle Loop
	task.spawn(function()
		local stormIndex = 1

		while true do
			-- Phase 1: Calm Starlight
			WeatherService.SetWeather("clear", CALM_DURATION)
			for t = CALM_DURATION, 1, -1 do
				WeatherService._timeRemaining = t
				task.wait(1)
			end

			-- Phase 2: Cosmic Storm Event
			local chosenStorm = STORM_SEQUENCE[stormIndex]
			stormIndex = (stormIndex % #STORM_SEQUENCE) + 1

			WeatherService.SetWeather(chosenStorm, STORM_DURATION)
			for t = STORM_DURATION, 1, -1 do
				WeatherService._timeRemaining = t
				task.wait(1)
			end
		end
	end)

	print("[WeatherService] Initialized ✓")
end

return WeatherService
