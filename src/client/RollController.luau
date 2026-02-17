-- Client-side controller for the roll button and pity counter
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PITY_MAX = 10
local PITY_COLOR = Color3.fromRGB(0, 210, 80) -- bright green

local RollController = {}

local function shakeButtonLoop(button, activeRef)
	local originalPos = button.Position
	local offset = 8
	local duration = 0.05

	task.spawn(function()
		while activeRef() do
			for _, x in ipairs({offset, -offset}) do
				if not activeRef() then break end
				TweenService:Create(
					button,
					TweenInfo.new(duration, Enum.EasingStyle.Linear),
					{ Position = UDim2.new(
						originalPos.X.Scale,
						originalPos.X.Offset + x,
						originalPos.Y.Scale,
						originalPos.Y.Offset
					)}
				):Play()
				task.wait(duration)
			end
		end
		button.Position = originalPos
	end)
end

function RollController.init()
	local screenGui = playerGui:WaitForChild("ScreenGui")
	local rollButton = screenGui:WaitForChild("RollButton")
	local pityLabel = rollButton:WaitForChild("Pity")

	local pityCount = 0
	local pityActive = false
	local normalColor = rollButton.BackgroundColor3

	pityLabel.Text = "0/" .. PITY_MAX

	rollButton.MouseButton1Click:Connect(function()
		if not rollButton.Active then return end  -- locked during spin
		if pityActive then
			pityActive = false
			pityCount = 0
			pityLabel.Text = "0/" .. PITY_MAX
			rollButton.BackgroundColor3 = normalColor
			return
		end

		pityCount = pityCount + 1
		pityLabel.Text = pityCount .. "/" .. PITY_MAX

		if pityCount >= PITY_MAX then
			pityActive = true
			print("You Hit Pity")
			rollButton.BackgroundColor3 = PITY_COLOR
			shakeButtonLoop(rollButton, function() return pityActive end)
		end
	end)

	print("[Client] Roll Controller initialized")
end

return RollController
