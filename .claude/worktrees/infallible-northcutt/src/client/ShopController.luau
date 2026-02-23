-- Client-side controller for the shop UI
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UIManager     = require(script.Parent.UIManager)
local ButtonEffects = require(script.Parent.ButtonEffects)

local ShopController = {}

function ShopController.init()
	local screenGui  = playerGui:WaitForChild("ScreenGui")
	local shopFrame  = screenGui:WaitForChild("ShopGUI")
	local shopButton = screenGui:WaitForChild("ShopButton")

	shopFrame.Visible = false
	ButtonEffects.apply(shopButton)

	shopButton.MouseButton1Click:Connect(function()
		UIManager.open(shopFrame)
	end)

	task.spawn(function()
		local header     = shopFrame:WaitForChild("ShopHeader")
		local exitButton = header:WaitForChild("ShopExitButton")
		ButtonEffects.applySubtle(exitButton)
		exitButton.MouseButton1Click:Connect(function()
			UIManager.close(shopFrame)
		end)
	end)

	print("[Client] Shop Controller initialized")
end

return ShopController
