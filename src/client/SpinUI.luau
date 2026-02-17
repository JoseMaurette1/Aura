-- Client-side spin animation controller
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BrainrotConfig = require(ReplicatedStorage.Shared.BrainrotConfig)
local InventoryController = require(script.Parent.InventoryController)
local SpinRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SpinRemote")

local SpinUI = {}
SpinUI.IsSpinning = false

local function displayName(name: string): string
	return name:gsub("_", " ")
end

local function shakeFrame(frame)
	local origin = frame.Position
	local ox = origin.X.Offset
	local oy = origin.Y.Offset
	local xs = origin.X.Scale
	local ys = origin.Y.Scale

	local function moveTo(dx)
		TweenService:Create(frame, TweenInfo.new(0.04, Enum.EasingStyle.Linear), {
			Position = UDim2.new(xs, ox + dx, ys, oy)
		}):Play()
	end

	for _, dx in ipairs({ 10, -10, 8, -8, 4, -4, 0 }) do
		moveTo(dx)
		task.wait(0.04)
	end
	frame.Position = origin
end

function SpinUI.init()
	local screenGui = playerGui:WaitForChild("ScreenGui")
	local rollButton = screenGui:WaitForChild("RollButton")
	local spinningFrame = screenGui:WaitForChild("SpinningFrame")
	local brainrotName = spinningFrame:WaitForChild("BrainrotName")
	local brainrotRarity = spinningFrame:WaitForChild("BrainrotRarity")
	local nameStroke = brainrotName:WaitForChild("BrainrotNameStroke")
	local rarityStroke = brainrotRarity:WaitForChild("BrainrotRarityStroke")

	local landedSize = brainrotName.TextSize

	spinningFrame.Visible = false

	rollButton.MouseButton1Click:Connect(function()
		if SpinUI.IsSpinning then return end
		SpinUI.IsSpinning = true
		rollButton.Active = false  -- blocks clicks AND stops RollController counter

		brainrotName.Text = "???"
		brainrotRarity.Text = "???"
		spinningFrame.Visible = true

		SpinRemote:FireServer()
	end)

	SpinRemote.OnClientEvent:Connect(function(data)
		local result = data.Result
		local slotId = data.SlotId

		task.spawn(function()
			local totalDuration = 5
			local startTime = tick()
			local lastUpdate = startTime

			-- Cycle through random brainrots until time is up
			while true do
				local elapsed = tick() - startTime

				if elapsed >= totalDuration then
					break
				end

				local progress = elapsed / totalDuration
				local speed
				if progress < 0.3 then
					speed = 0.05
				elseif progress < 0.7 then
					speed = 0.1
				elseif progress < 0.9 then
					speed = 0.2
				else
					speed = 0.4
				end

				if tick() - lastUpdate >= speed then
					local b = BrainrotConfig.Brainrots[math.random(1, #BrainrotConfig.Brainrots)]
					brainrotName.Text = displayName(b.Name)
					brainrotRarity.Text = "1 in " .. b.Rarity
					nameStroke.Color = b.Color
					rarityStroke.Color = b.Color
					lastUpdate = tick()
				end

				task.wait()
			end

			-- Snap to final result
			brainrotName.Text = displayName(result.Name)
			brainrotRarity.Text = "1 in " .. result.Rarity
			nameStroke.Color = result.Color
			rarityStroke.Color = result.Color

			-- Land punch
			brainrotName.TextSize = landedSize + 14
			TweenService:Create(brainrotName, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				TextSize = landedSize
			}):Play()
			task.wait(0.12)

			-- Shake then instantly hide
			shakeFrame(spinningFrame)
			InventoryController.addItem(result, slotId)
			spinningFrame.Visible = false
			rollButton.Active = true
			SpinUI.IsSpinning = false
		end)
	end)

	print("[Client] Spin UI initialized")
end

return SpinUI
