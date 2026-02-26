-- Client-side controller for the shop UI and gamepass purchases
local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BrainrotConfig      = require(ReplicatedStorage.Shared.BrainrotConfig)
local UIManager           = require(script.Parent.UIManager)
local ButtonEffects       = require(script.Parent.ButtonEffects)
local InventoryController = require(script.Parent.InventoryController)

-- ── Gamepass IDs ─────────────────────────────────────────────────────────────
-- Must match the IDs in GamepassHandler.luau on the server
local GAMEPASS_IDS = {
    VIP           = 3545255159,   -- 450 Robux  — permanent 2x luck on every pull
    TwoXLuck      = 3545254961,   -- 199 Robux  — 2x luck on every 10th pull
    SkipAnimation = 3545255933,   -- 150 Robux  — skip the 5-second spin animation
    StarterPack   = 3545255351,   -- 200 Robux  — grants 3 rare brainrots (one-time)
    OpPack        = 3545255660,   -- 500 Robux  — grants 3 legendary brainrots (one-time)
    AutoRebirth = 3545264556,     -- 450 Robux  - grants Auto rebirth
}

local RemoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local packGrantRemote = RemoteEvents:WaitForChild("PackGrantRemote")

local ShopController = {}

-- ── Prompt helpers ────────────────────────────────────────────────────────────
local function promptPass(passId)
	if passId == 0 then
		warn("[ShopController] Gamepass ID not set yet — fill in GAMEPASS_IDS in ShopController and GamepassHandler")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, passId)
end

-- Updates a buy button to show "OWNED" if the player already has the pass.
-- Works for both TextButton and ImageButton.
local function refreshOwnedState(button, attrName, ownedLabel)
	local function markOwned()
		button.Active = false
		if button:IsA("TextButton") then
			button.Text             = ownedLabel or "✓ OWNED"
			button.BackgroundColor3 = Color3.fromRGB(55, 180, 100)
		else
			-- ImageButton — tint green and show a TextLabel overlay if one exists
			button.ImageColor3 = Color3.fromRGB(55, 180, 100)
			local label = button:FindFirstChildWhichIsA("TextLabel")
			if label then
				label.Text      = ownedLabel or "✓ OWNED"
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end

	if player:GetAttribute(attrName) then
		markOwned()
	end

	-- Also update in real-time if they buy during this session
	player:GetAttributeChangedSignal(attrName):Connect(function()
		if player:GetAttribute(attrName) then
			markOwned()
		end
	end)
end

-- ── Pack grant listener ───────────────────────────────────────────────────────
-- Server fires this when Starter Pack or OP Pack items are granted.
-- We add each item to the inventory UI immediately.
packGrantRemote.OnClientEvent:Connect(function(grantedItems)
	for _, item in ipairs(grantedItems) do
		local brainrot = BrainrotConfig.getBrainrotByName(item.name)
		if brainrot then
			InventoryController.addItem(brainrot, item.slotId)
		end
	end
end)

-- ── Main init ─────────────────────────────────────────────────────────────────
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

		-- ── Wire up each gamepass buy button ────────────────────────────────
		-- Hierarchy: ShopGUI > ShopArea > ScrollingFrame > [ItemFrame] > Button
		local scroll = shopFrame:WaitForChild("ShopArea"):WaitForChild("ScrollingFrame")

		-- Debug: print all children so you can confirm exact names in Output
		print("[ShopController] ScrollingFrame children:")
		for _, child in ipairs(scroll:GetChildren()) do
			print("  →", child.Name)
		end

		-- Case-insensitive find so minor capitalization mismatches don't hang the script
		local function findChildCI(parent, name)
			local lower = name:lower()
			for _, child in ipairs(parent:GetChildren()) do
				if child.Name:lower() == lower then return child end
			end
			return nil
		end

		local function wireButton(itemFrameName, passId, attrName)
			local itemFrame = findChildCI(scroll, itemFrameName)
			if not itemFrame then
				warn("[ShopController] Item frame not found: '" .. itemFrameName .. "' — check exact name in Studio")
				return
			end

			local btn = findChildCI(itemFrame, "Button")
			if not btn then
				warn("[ShopController] 'Button' not found inside '" .. itemFrameName .. "' — check Studio hierarchy")
				return
			end

			print("[ShopController] Wired: " .. itemFrameName)
			ButtonEffects.apply(btn)
			refreshOwnedState(btn, attrName, "✓ OWNED")

			btn.MouseButton1Click:Connect(function()
				promptPass(passId)
			end)
		end

		wireButton("VIP",             GAMEPASS_IDS.VIP,           "OwnsVIP")
		wireButton("2xLuck",          GAMEPASS_IDS.TwoXLuck,      "Owns2xLuck")
		wireButton("Skip Animation",  GAMEPASS_IDS.SkipAnimation, "OwnsSkipAnimation")
		wireButton("Starter Pack",    GAMEPASS_IDS.StarterPack,   "OwnsStarterPack")
		wireButton("OP Pack",         GAMEPASS_IDS.OpPack,        "OwnsOpPack")
		wireButton("AutoRebirth",     GAMEPASS_IDS.AutoRebirth,   "OwnsAutoRebirth")

	end)

	print("[Client] Shop Controller initialized")
end

return ShopController
