-- Client-side controller for the auto-clicker toggle
local Players = game:GetService("Players")

local SpinUI          = require(script.Parent.SpinUI)
local RollController  = require(script.Parent.RollController)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local AutoClickController = {}

local isRunning      = false
local autoClickThread = nil

-- Color feedback on the AutoClickButton
local ACTIVE_COLOR = Color3.fromRGB(80, 220, 80)   -- green when on
local normalColor  = nil                            -- captured from Studio button

local autoClickButton = nil  -- set during init, used to update visuals

local function setButtonVisual(on: boolean)
	if not autoClickButton then return end
	autoClickButton.BackgroundColor3 = on and ACTIVE_COLOR or normalColor
end

local function startAutoClick()
	if isRunning then return end
	isRunning = true
	setButtonVisual(true)

	autoClickThread = task.spawn(function()
		while isRunning do
			if not SpinUI.IsSpinning then
				RollController.onRoll()
				SpinUI.triggerSpin()
			end
			task.wait(0.1)
		end
	end)
end

local function stopAutoClick()
	isRunning = false
	if autoClickThread then
		task.cancel(autoClickThread)
		autoClickThread = nil
	end
	setButtonVisual(false)
end

function AutoClickController.init()
	local screenGui = playerGui:WaitForChild("ScreenGui")
	autoClickButton = screenGui:WaitForChild("AutoClickButton")
	normalColor     = autoClickButton.BackgroundColor3

	autoClickButton.MouseButton1Click:Connect(function()
		if isRunning then
			stopAutoClick()
		else
			startAutoClick()
		end
	end)

	print("[Client] Auto Click Controller initialized")
end

return AutoClickController
