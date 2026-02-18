-- Client-side spin animation controller
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BrainrotConfig      = require(ReplicatedStorage.Shared.BrainrotConfig)
local InventoryController = require(script.Parent.InventoryController)
local SettingsController  = require(script.Parent.SettingsController)

local RemoteEvents     = ReplicatedStorage:WaitForChild("RemoteEvents")
local SpinRemote       = RemoteEvents:WaitForChild("SpinRemote")
local DeleteItemRemote = RemoteEvents:WaitForChild("DeleteItemRemote")
local PityLoadRemote   = RemoteEvents:WaitForChild("PityLoadRemote")

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

	-- Pity bars
	local pityFrame       = screenGui:WaitForChild("PityFrame")
	local uncommonBar     = pityFrame:WaitForChild("UncommonBar")
	local legendaryBar    = pityFrame:WaitForChild("LegendaryBar")
	local mythicBar       = pityFrame:WaitForChild("MythicBar")
	local uncommonProgress  = uncommonBar:WaitForChild("UncommonProgress")
	local legendaryProgress = legendaryBar:WaitForChild("LegendaryProgress")
	local mythicProgress    = mythicBar:WaitForChild("MythicProgress")

	local function updatePityBars(pity)
		uncommonProgress.Text  = pity.uncommonCount  .. " / " .. pity.uncommonMax
		legendaryProgress.Text = pity.legendaryCount .. " / " .. pity.legendaryMax
		mythicProgress.Text    = pity.mythicCount    .. " / " .. pity.mythicMax
	end

	-- Set initial pity values as soon as server sends them on join
	PityLoadRemote.OnClientEvent:Connect(updatePityBars)

	local landedSize = brainrotName.TextSize

	spinningFrame.Visible = false

	function SpinUI.triggerSpin()
		if SpinUI.IsSpinning then return end
		SpinUI.IsSpinning = true
		rollButton.Active = false

		brainrotName.Text = "???"
		brainrotRarity.Text = "???"
		spinningFrame.Visible = true

		SpinRemote:FireServer()
	end

	rollButton.MouseButton1Click:Connect(SpinUI.triggerSpin)

	SpinRemote.OnClientEvent:Connect(function(data)
		local result = data.Result
		local slotId = data.SlotId
		if data.Pity then updatePityBars(data.Pity) end

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
			if slotId then
				if SettingsController.shouldAutoDelete(result) then
					-- Auto-delete: remove from server data and skip inventory
					DeleteItemRemote:FireServer(slotId)
				else
					InventoryController.addItem(result, slotId)
				end
			end
			spinningFrame.Visible = false
			rollButton.Active = true
			SpinUI.IsSpinning = false
		end)
	end)

	print("[Client] Spin UI initialized")
end

return SpinUI
