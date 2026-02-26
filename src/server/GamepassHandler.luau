-- Server-side handler for all gamepass ownership checks and purchase grants
local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService         = game:GetService("RunService")

local DataManager = require(script.Parent.DataManager)

-- ── Gamepass IDs ────────────────────────────────────────────────────────────
-- TODO: Replace every 0 with the real ID from the Roblox Creator Dashboard
-- (Create Universe → Monetization → Passes or Products)
local GAMEPASS_IDS = {
    VIP           = 3545255159,   -- 450 Robux  — permanent 2x luck on every pull
    TwoXLuck      = 3545254961,   -- 199 Robux  — 2x luck on every 10th pull
    SkipAnimation = 3545255933,   -- 150 Robux  — skip the 5-second spin animation
    StarterPack   = 3545255351,   -- 200 Robux  — grants 3 rare brainrots (one-time)
    OpPack        = 3545255660,   -- 500 Robux  — grants 3 legendary brainrots (one-time)
    AutoRebirth = 3545264556,     -- 450 Robux  - grants Auto rebirth
}

-- ── Pack contents ───────────────────────────────────────────────────────────
-- TODO: Replace these with whichever brainrots you want to include.
--       Names must match exactly (including spaces/underscores) as they appear
--       in BrainrotConfig.Brainrots[].Name
local STARTER_PACK_BRAINROTS = {
	"Bombardiro Crocodilo",    -- 1/500 Rare  (CHANGE ME)
	"Tung Tung Tung Sahur",    -- 1/500 Rare  (CHANGE ME)
	"Ballerina Cappuccina",    -- 1/500 Rare  (CHANGE ME)
}

local OP_PACK_BRAINROTS = {
	"Orcalero Orcala",         -- 1/2500 Legendary  (CHANGE ME)
	"Strawberry Elephant",           -- 1/2500 Legendary  (CHANGE ME)
	"Tigroligre Frutonni",    -- 1/2500 Legendary  (CHANGE ME)
}

-- ── Studio override ─────────────────────────────────────────────────────────
-- When true, all passes are auto-granted to every player in Studio playtests.
-- Set to false before publishing to live.
local STUDIO_OVERRIDE = true

-- ── Internal state ──────────────────────────────────────────────────────────
local packGrantRemote  -- created in init()

-- ── Helpers ─────────────────────────────────────────────────────────────────
local function checkOwns(player, passId)
	if passId == 0 then return false end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and owns
end

local function grantPackItems(player, brainrotNames)
	local granted = {}
	for _, name in ipairs(brainrotNames) do
		local slotId = DataManager.addItem(player, name)
		if slotId then
			table.insert(granted, { name = name, slotId = slotId })
		end
	end
	if #granted > 0 and packGrantRemote then
		packGrantRemote:FireClient(player, granted)
	end
end

local function grantStarterPack(player)
	if DataManager.hasRedeemedStarterPack(player) then
		-- Already granted — just set the attribute so the shop shows "OWNED"
		player:SetAttribute("OwnsStarterPack", true)
		return
	end
	DataManager.markStarterPackRedeemed(player)
	player:SetAttribute("OwnsStarterPack", true)
	grantPackItems(player, STARTER_PACK_BRAINROTS)
	print("[GamepassHandler] Granted Starter Pack to " .. player.Name)
end

local function grantOpPack(player)
	if DataManager.hasRedeemedOpPack(player) then
		-- Already granted — just set the attribute so the shop shows "OWNED"
		player:SetAttribute("OwnsOpPack", true)
		return
	end
	DataManager.markOpPackRedeemed(player)
	player:SetAttribute("OwnsOpPack", true)
	grantPackItems(player, OP_PACK_BRAINROTS)
	print("[GamepassHandler] Granted OP Pack to " .. player.Name)
end

-- Sets attributes for luck/animation passes and grants packs if owned.
-- Must be called AFTER DataManager.waitForPlayer() so cache is ready.
local function applyGamepasses(player)
	if RunService:IsStudio() and STUDIO_OVERRIDE then
		player:SetAttribute("OwnsVIP",           true)
		player:SetAttribute("Owns2xLuck",        true)
		player:SetAttribute("OwnsSkipAnimation", true)
		player:SetAttribute("OwnsAutoRebirth",   true)
		grantStarterPack(player)
		grantOpPack(player)
		print("[GamepassHandler] Studio override: granted all passes to " .. player.Name)
		return
	end

	if checkOwns(player, GAMEPASS_IDS.VIP) then
		player:SetAttribute("OwnsVIP", true)
		print("[GamepassHandler] " .. player.Name .. " owns VIP")
	end

	if checkOwns(player, GAMEPASS_IDS.TwoXLuck) then
		player:SetAttribute("Owns2xLuck", true)
		print("[GamepassHandler] " .. player.Name .. " owns 2x Luck")
	end

	if checkOwns(player, GAMEPASS_IDS.SkipAnimation) then
		player:SetAttribute("OwnsSkipAnimation", true)
		print("[GamepassHandler] " .. player.Name .. " owns Skip Animation")
	end

	if checkOwns(player, GAMEPASS_IDS.AutoRebirth) then
		player:SetAttribute("OwnsAutoRebirth", true)
		print("[GamepassHandler] " .. player.Name .. " owns AutoRebirth")
	end

	if checkOwns(player, GAMEPASS_IDS.StarterPack) then
		grantStarterPack(player)
	end

	if checkOwns(player, GAMEPASS_IDS.OpPack) then
		grantOpPack(player)
	end
end

-- ── Public API ───────────────────────────────────────────────────────────────
local GamepassHandler = {}

-- Call once from init.server.luau, passing the RemoteEvents folder
function GamepassHandler.init(remoteEventsFolder)
	-- Create the remote the client listens to for pack item grants
	packGrantRemote        = Instance.new("RemoteEvent")
	packGrantRemote.Name   = "PackGrantRemote"
	packGrantRemote.Parent = remoteEventsFolder

	-- On join: wait for DataManager to load player data, then check passes
	Players.PlayerAdded:Connect(function(player)
		DataManager.waitForPlayer(player)
		applyGamepasses(player)
	end)

	-- On purchase: apply the benefit immediately without requiring a rejoin
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then return end

		if passId == GAMEPASS_IDS.VIP then
			player:SetAttribute("OwnsVIP", true)
			print("[GamepassHandler] " .. player.Name .. " purchased VIP!")

		elseif passId == GAMEPASS_IDS.TwoXLuck then
			player:SetAttribute("Owns2xLuck", true)
			print("[GamepassHandler] " .. player.Name .. " purchased 2x Luck!")

		elseif passId == GAMEPASS_IDS.SkipAnimation then
			player:SetAttribute("OwnsSkipAnimation", true)
			print("[GamepassHandler] " .. player.Name .. " purchased Skip Animation!")

		elseif passId == GAMEPASS_IDS.StarterPack then
			grantStarterPack(player)
			print("[GamepassHandler] " .. player.Name .. " purchased Starter Pack!")

		elseif passId == GAMEPASS_IDS.OpPack then
			grantOpPack(player)
			print("[GamepassHandler] " .. player.Name .. " purchased OP Pack!")

		elseif passId == GAMEPASS_IDS.AutoRebirth then
			player:SetAttribute("OwnsAutoRebirth", true)
			print("[GamepassHandler] " .. player.Name .. " purchased AutoRebirth!")
		end
	end)
end

return GamepassHandler
