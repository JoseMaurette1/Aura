-- Client-side controller for the settings UI (auto-delete by rarity tier)
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIManager     = require(script.Parent.UIManager)
local ButtonEffects = require(script.Parent.ButtonEffects)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SettingsController = {}

-- Tracks which rarity tiers are set to auto-delete (true = delete, false/nil = keep)
local autoDeleteTiers = {}

local TIERS = { "Common", "Uncommon", "Rare", "Legendary", "Mythic" }

-- Rarity → tier name (must match the Scroll child names in Studio)
local function getTierName(rarity: number): string
	if rarity <= 25   then return "Common"
	elseif rarity <= 100  then return "Uncommon"
	elseif rarity <= 1000 then return "Rare"
	elseif rarity <= 5000 then return "Legendary"
	else                       return "Mythic"
	end
end

-- Returns true if this brainrot should be auto-deleted (not added to inventory)
function SettingsController.shouldAutoDelete(brainrot): boolean
	return autoDeleteTiers[getTierName(brainrot.Rarity)] == true
end

-- Visual helpers: UIStroke on selected button, none on deselected
local SELECTED_YES_COLOR = Color3.fromRGB(80, 220, 80)   -- green
local SELECTED_NO_COLOR  = Color3.fromRGB(220, 80,  80)  -- red
local STROKE_THICKNESS   = 3

local function applyStroke(btn: ImageButton, color: Color3)
	local existing = btn:FindFirstChildWhichIsA("UIStroke")
	if existing then existing:Destroy() end
	local stroke = Instance.new("UIStroke")
	stroke.Color           = color
	stroke.Thickness       = STROKE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent          = btn
end

local function clearStroke(btn: ImageButton)
	local existing = btn:FindFirstChildWhichIsA("UIStroke")
	if existing then existing:Destroy() end
end

function SettingsController.init()
	local screenGui      = playerGui:WaitForChild("ScreenGui")
	local settingsButton = screenGui:WaitForChild("SettingsButton")
	local settingsFrame  = settingsButton:WaitForChild("SettingsGUI")

	settingsFrame.Visible = false
	ButtonEffects.apply(settingsButton)

	settingsButton.MouseButton1Click:Connect(function()
		UIManager.open(settingsFrame)
	end)

	task.spawn(function()
		local exitButton = settingsFrame:WaitForChild("ExitButton")
		ButtonEffects.applySubtle(exitButton)
		exitButton.MouseButton1Click:Connect(function()
			UIManager.close(settingsFrame)
		end)
	end)

	task.spawn(function()
		local scroll = settingsFrame:WaitForChild("Scroll")

		for _, tierName in ipairs(TIERS) do
			local tierFrame = scroll:WaitForChild(tierName)
			local yesBtn    = tierFrame:WaitForChild("Yes")
			local noBtn     = tierFrame:WaitForChild("No")

			ButtonEffects.applySubtle(yesBtn)
			ButtonEffects.applySubtle(noBtn)

			-- Wire up Yes button
			yesBtn.MouseButton1Click:Connect(function()
				if autoDeleteTiers[tierName] == true then
					-- Clicking Yes again deselects it (toggle off)
					autoDeleteTiers[tierName] = false
					clearStroke(yesBtn)
				else
					autoDeleteTiers[tierName] = true
					applyStroke(yesBtn, SELECTED_YES_COLOR)
					clearStroke(noBtn)
				end
			end)

			-- Wire up No button
			noBtn.MouseButton1Click:Connect(function()
				autoDeleteTiers[tierName] = false
				applyStroke(noBtn, SELECTED_NO_COLOR)
				clearStroke(yesBtn)
			end)
		end
	end)

	print("[Client] Settings Controller initialized")
end

return SettingsController
