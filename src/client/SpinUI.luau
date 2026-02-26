-- Client-side spin animation controller
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BrainrotConfig      = require(ReplicatedStorage.Shared.BrainrotConfig)
local InventoryController = require(script.Parent.InventoryController)
local SettingsController  = require(script.Parent.SettingsController)
local ButtonEffects       = require(script.Parent.ButtonEffects)

local RemoteEvents     = ReplicatedStorage:WaitForChild("RemoteEvents")
local SpinRemote       = RemoteEvents:WaitForChild("SpinRemote")
local DeleteItemRemote = RemoteEvents:WaitForChild("DeleteItemRemote")
local PityLoadRemote   = RemoteEvents:WaitForChild("PityLoadRemote")

local SpinUI = {}
SpinUI.IsSpinning = false

local function displayName(name: string): string
	return name:gsub("_", " ")
end

-- Rarity tier helpers for visual effects
local function getRarityTier(rarity: number): string
	if rarity <= 25   then return "Common"
	elseif rarity <= 100  then return "Uncommon"
	elseif rarity <= 1000 then return "Rare"
	elseif rarity <= 5000 then return "Legendary"
	else                       return "Mythic"
	end
end

local RARITY_EFFECTS = {
	Common    = { flashColor = nil,                           punchBonus = 0,  confetti = false },
	Uncommon  = { flashColor = nil,                           punchBonus = 8,  confetti = false },
	Rare      = { flashColor = nil,                           punchBonus = 20, confetti = false },
	Legendary = { flashColor = Color3.fromRGB(255, 200, 50), punchBonus = 36, confetti = true  },
	Mythic    = { flashColor = Color3.fromRGB(255, 50, 50),  punchBonus = 52, confetti = true  },
}

local function flashScreen(rarityFlash, color, intensity)
	rarityFlash.BackgroundColor3 = color
	rarityFlash.BackgroundTransparency = intensity
	TweenService:Create(rarityFlash, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	}):Play()
end

local function spawnConfetti(screenGui, color)
	local COLORS = { color, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 230, 100) }
	for _ = 1, 28 do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, math.random(6, 14), 0, math.random(6, 14))
		dot.Position = UDim2.new(0.5, 0, 0.5, 0)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = COLORS[math.random(1, #COLORS)]
		dot.BorderSizePixel = 0
		dot.ZIndex = 45
		dot.Parent = screenGui

		local angle = math.random() * math.pi * 2
		local dist  = math.random(120, 380)
		local ox    = math.floor(math.cos(angle) * dist)
		local oy    = math.floor(math.sin(angle) * dist)

		task.spawn(function()
			TweenService:Create(dot, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position             = UDim2.new(0.5, ox, 0.5, oy),
				BackgroundTransparency = 1,
			}):Play()
			task.wait(0.9)
			dot:Destroy()
		end)
	end
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

	local rarityFlash = screenGui:WaitForChild("RarityFlash")
	local landedSize  = brainrotName.TextSize

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

	ButtonEffects.applyPrimary(rollButton)
	rollButton.MouseButton1Click:Connect(SpinUI.triggerSpin)

	-- Shared landing sequence (result snap → effects → punch → shake → cleanup)
	local function landResult(result, slotId)
		brainrotName.Text   = displayName(result.Name)
		brainrotRarity.Text = "1 in " .. result.Rarity
		nameStroke.Color    = result.Color
		rarityStroke.Color  = result.Color

		local tier         = getRarityTier(result.Rarity)
		local effects      = RARITY_EFFECTS[tier]
		local willAutoDelete = SettingsController.shouldAutoDelete(result)

		-- Suppress flash and confetti when the item is auto-deleted — quieter feedback
		if not willAutoDelete then
			if effects.flashColor then
				local intensity = tier == "Mythic" and 0.15 or 0.3
				flashScreen(rarityFlash, effects.flashColor, intensity)
			end
			if effects.confetti then
				spawnConfetti(screenGui, result.Color)
			end
		end

		local punchAmount = 14 + effects.punchBonus
		brainrotName.TextSize = landedSize + punchAmount
		TweenService:Create(brainrotName, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextSize = landedSize
		}):Play()
		task.wait(0.12)

		shakeFrame(spinningFrame)
		if slotId then
			if willAutoDelete then
				DeleteItemRemote:FireServer(slotId)
			else
				InventoryController.addItem(result, slotId)
			end
		end
		spinningFrame.Visible = false
		rollButton.Active     = true
		SpinUI.IsSpinning     = false
	end

	SpinRemote.OnClientEvent:Connect(function(data)
		local result = data.Result
		local slotId = data.SlotId
		if data.Pity then updatePityBars(data.Pity) end

		task.spawn(function()
			-- ── Skip Animation gamepass: jump straight to result ───────────────
			if player:GetAttribute("OwnsSkipAnimation") then
				landResult(result, slotId)
				return
			end

			-- ── Normal 5-second cycling animation ─────────────────────────────
			local totalDuration = 5
			local startTime     = tick()
			local lastUpdate    = startTime

			while true do
				local elapsed = tick() - startTime
				if elapsed >= totalDuration then break end

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
					brainrotName.Text   = displayName(b.Name)
					brainrotRarity.Text = "1 in " .. b.Rarity
					nameStroke.Color    = b.Color
					rarityStroke.Color  = b.Color
					lastUpdate = tick()
				end

				task.wait()
			end

			landResult(result, slotId)
		end)
	end)

	print("[Client] Spin UI initialized")
end

return SpinUI
