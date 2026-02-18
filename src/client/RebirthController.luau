-- Client-side controller for the rebirth UI
local Players = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RebirthController = {}

function RebirthController.init()
	local screenGui    = playerGui:WaitForChild("ScreenGui")
	local rebirthFrame = screenGui:WaitForChild("RebirthGUI")
	local rebirthButton = screenGui:WaitForChild("RebirthButton")

	rebirthFrame.Visible = false

	rebirthButton.MouseButton1Click:Connect(function()
		rebirthFrame.Visible = true
	end)

	task.spawn(function()
		local header     = rebirthFrame:WaitForChild("RebirthHeader")
		local exitButton = header:WaitForChild("RebirthExitButton")
		exitButton.MouseButton1Click:Connect(function()
			rebirthFrame.Visible = false
		end)
	end)

	print("[Client] Rebirth Controller initialized")
end

return RebirthController
