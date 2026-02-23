-- Client-side controller for the rebirth UI
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.BrainrotConfig)
local UIManager      = require(script.Parent.UIManager)
local ButtonEffects  = require(script.Parent.ButtonEffects)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RebirthController = {}

function RebirthController.init()
	local screenGui     = playerGui:WaitForChild("ScreenGui")
	local rebirthFrame  = screenGui:WaitForChild("RebirthGUI")
	local rebirthButton = screenGui:WaitForChild("RebirthButton")

	rebirthFrame.Visible = false
	ButtonEffects.apply(rebirthButton)

	rebirthButton.MouseButton1Click:Connect(function()
		UIManager.open(rebirthFrame)
	end)

	task.spawn(function()
		-- Exit button
		local header     = rebirthFrame:WaitForChild("RebirthHeader")
		local exitButton = header:WaitForChild("RebirthExitButton")
		ButtonEffects.applySubtle(exitButton)
		exitButton.MouseButton1Click:Connect(function()
			UIManager.close(rebirthFrame)
		end)

		-- UI label references
		local rebirthArea    = rebirthFrame:WaitForChild("RebirthArea")
		local beforeButton   = rebirthArea:WaitForChild("BeforeButton")
		local afterButton    = rebirthArea:WaitForChild("AfterButton")
		local rebirthSection = rebirthArea:WaitForChild("RebirthSection")
		local rebirthBar     = rebirthSection:WaitForChild("RebirthBar")
		local prestigeButton = rebirthArea:WaitForChild("PrestigeButton")

		local beforeLuck      = beforeButton:WaitForChild("BeforeLuck")
		local afterLuck       = afterButton:WaitForChild("AfterLuck")
		local rebirthProgress = rebirthBar:WaitForChild("RebirthProgress")

		-- Leaderstats references
		local leaderstats  = player:WaitForChild("leaderstats")
		local moneyValue   = leaderstats:WaitForChild("Money")
		local rebirthsValue = leaderstats:WaitForChild("Rebirths")

		-- RebirthRemote
		local remoteEvents  = ReplicatedStorage:WaitForChild("RemoteEvents")
		local rebirthRemote = remoteEvents:WaitForChild("RebirthRemote")

		local function updateUI()
			local rebirthCount = rebirthsValue.Value
			local money        = moneyValue.Value
			local cost         = BrainrotConfig.getRebirthCost(rebirthCount)

			beforeLuck.Text      = BrainrotConfig.getLuck(rebirthCount) .. "x"
			afterLuck.Text       = BrainrotConfig.getNextLuck(rebirthCount) .. "x"
			rebirthProgress.Text = money .. " / " .. cost

			prestigeButton.Active = money >= cost
			prestigeButton.AutoButtonColor = money >= cost
			prestigeButton.ImageTransparency = money >= cost and 0 or 0.5
		end

		-- Initial update
		updateUI()

		-- React to money changes
		moneyValue.Changed:Connect(updateUI)

		-- React to rebirth count changes (after server confirms)
		rebirthsValue.Changed:Connect(updateUI)

		ButtonEffects.applyPrimary(prestigeButton)

		-- Prestige button click — fire server
		prestigeButton.MouseButton1Click:Connect(function()
			local cost = BrainrotConfig.getRebirthCost(rebirthsValue.Value)
			if moneyValue.Value >= cost then
				rebirthRemote:FireServer()
			end
		end)
	end)

	print("[Client] Rebirth Controller initialized")
end

return RebirthController
