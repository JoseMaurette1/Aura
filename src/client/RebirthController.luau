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
		local rollsValue   = leaderstats:WaitForChild("Rolls")
		local rebirthsValue = leaderstats:WaitForChild("Rebirths")

		-- RebirthRemote
		local remoteEvents  = ReplicatedStorage:WaitForChild("RemoteEvents")
		local rebirthRemote = remoteEvents:WaitForChild("RebirthRemote")

		local function updateUI()
			local rebirthCount = rebirthsValue.Value
			local rolls        = rollsValue.Value
			local cost         = BrainrotConfig.getRebirthCost(rebirthCount)

			beforeLuck.Text      = BrainrotConfig.getLuck(rebirthCount) .. "x"
			afterLuck.Text       = BrainrotConfig.getNextLuck(rebirthCount) .. "x"
			rebirthProgress.Text = rolls .. " / " .. cost

			prestigeButton.Active = rolls >= cost
			prestigeButton.AutoButtonColor = rolls >= cost
			prestigeButton.ImageTransparency = rolls >= cost and 0 or 0.5
		end

		-- Initial update
		updateUI()

		-- ── Auto Rebirth (gamepass) ──────────────────────────────────────────
		-- Fires the rebirth remote automatically when rolls hit the cost.
		-- A pending flag prevents double-firing while waiting for server response.
		local autoRebirthPending = false

		local function tryAutoRebirth()
			if not player:GetAttribute("OwnsAutoRebirth") then return end
			if autoRebirthPending then return end
			local cost = BrainrotConfig.getRebirthCost(rebirthsValue.Value)
			if rollsValue.Value >= cost then
				autoRebirthPending = true
				rebirthRemote:FireServer()
			end
		end

		-- React to rolls changes — update UI and check auto rebirth
		rollsValue.Changed:Connect(function()
			updateUI()
			tryAutoRebirth()
		end)

		-- React to rebirth count changes — clear pending flag so next threshold works
		rebirthsValue.Changed:Connect(function()
			updateUI()
			autoRebirthPending = false
		end)

		ButtonEffects.applyPrimary(prestigeButton)

		-- Prestige button click — fire server
		prestigeButton.MouseButton1Click:Connect(function()
			local cost = BrainrotConfig.getRebirthCost(rebirthsValue.Value)
			if rollsValue.Value >= cost then
				rebirthRemote:FireServer()
			end
		end)
	end)

	print("[Client] Rebirth Controller initialized")
end

return RebirthController
