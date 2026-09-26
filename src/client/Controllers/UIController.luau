--!strict
--[[
	UIController.luau — Master User Interface Coordinator for STARWEAVE
	Orchestrates HUD, Modals (Shop, Forge, Compendium, Rebirth),
	modal transitions, backdrop blur depth-of-field, and event distribution.
	Located in: StarterPlayerScripts.Client.Controllers.UIController
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local HUDController = require(script.Parent.Parent.UI.HUDController)
local NotificationUI = require(script.Parent.Parent.UI.NotificationUI)
local ShopModal = require(script.Parent.Parent.UI.ShopModal)
local CollectionModal = require(script.Parent.Parent.UI.CollectionModal)
local RebirthModal = require(script.Parent.Parent.UI.RebirthModal)
local ForgeModal = require(script.Parent.Parent.UI.ForgeModal)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UIController = {}
UIController._blurEffect = nil :: BlurEffect?
UIController._currentOpenModal = nil :: string?

function UIController.Init()
	-- Create Backdrop Blur for cinematic modal focus
	local blur = Lighting:FindFirstChildOfClass("BlurEffect")
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "ModalBackdropBlur"
		blur.Size = 0
		blur.Parent = Lighting
	end
	UIController._blurEffect = blur

	-- Build HUD and Modals
	HUDController.Create()
	NotificationUI.Create()

	local mainGui = HUDController._gui
	if mainGui then
		ShopModal.Create(mainGui)
		CollectionModal.Create(mainGui)
		RebirthModal.Create(mainGui)
		ForgeModal.Create(mainGui)
	end

	-- Listen for Dock Action Triggers
	local actionEvent = HUDController.GetUIActionEvent()
	if actionEvent then
		actionEvent.Event:Connect(function(actionName: string)
			UIController.HandleDockAction(actionName)
		end)
	end
end

function UIController.HandleDockAction(actionName: string)
	if actionName == "OpenShop" then
		UIController.ToggleModal("Shop")
	elseif actionName == "OpenForge" then
		UIController.ToggleModal("Forge")
	elseif actionName == "OpenCollection" then
		UIController.ToggleModal("Collection")
	elseif actionName == "OpenRebirth" then
		UIController.ToggleModal("Rebirth")
	end
end

function UIController.ToggleModal(modalName: string)
	if UIController._currentOpenModal == modalName then
		UIController.CloseAllModals()
		return
	end

	UIController.CloseAllModals()
	UIController._currentOpenModal = modalName

	-- Animate blur in
	if UIController._blurEffect then
		TweenService:Create(UIController._blurEffect, TweenInfo.new(0.3), { Size = 16 }):Play()
	end

	if modalName == "Shop" then
		ShopModal.Open()
	elseif modalName == "Forge" then
		ForgeModal.Open()
	elseif modalName == "Collection" then
		CollectionModal.Open()
	elseif modalName == "Rebirth" then
		RebirthModal.Open()
	end
end

function UIController.CloseAllModals()
	if UIController._currentOpenModal == "Shop" then ShopModal.Close() end
	if UIController._currentOpenModal == "Forge" then ForgeModal.Close() end
	if UIController._currentOpenModal == "Collection" then CollectionModal.Close() end
	if UIController._currentOpenModal == "Rebirth" then RebirthModal.Close() end

	UIController._currentOpenModal = nil

	if UIController._blurEffect then
		TweenService:Create(UIController._blurEffect, TweenInfo.new(0.25), { Size = 0 }):Play()
	end
end

function UIController.Update(playerData: any)
	HUDController.Update(playerData)
	ShopModal.Update(playerData)
	CollectionModal.Update(playerData)
	RebirthModal.Update(playerData)
	ForgeModal.Update(playerData)
end

function UIController.SetWeather(isActive: boolean)
	HUDController.SetWeatherVisible(isActive)
	NotificationUI.ShowWeather(isActive)
end

return UIController
