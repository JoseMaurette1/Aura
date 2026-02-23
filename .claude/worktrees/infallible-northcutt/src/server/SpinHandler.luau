-- Server-side handler for spin requests
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.BrainrotConfig)
local DataManager    = require(script.Parent.DataManager)

local SpinHandler = {}

-- SpinHandler creates the RemoteEvents folder; all other server modules find it via WaitForChild
local RemoteEvents = Instance.new("Folder")
RemoteEvents.Name   = "RemoteEvents"
RemoteEvents.Parent = ReplicatedStorage

local SpinRemote = Instance.new("RemoteEvent")
SpinRemote.Name   = "SpinRemote"
SpinRemote.Parent = RemoteEvents

-- Hand the folder to DataManager so it can append its own remotes and hook PlayerAdded
DataManager.init(RemoteEvents)

local PITY_CFG = BrainrotConfig.PityConfig

-- ── Spin request ───────────────────────────────────────────────────────────────
SpinRemote.OnServerEvent:Connect(function(player: Player)
	-- Read all three pity counters
	local pityUncommon  = DataManager.getPityCount(player)
	local pityLegendary = DataManager.getPityLegendary(player)
	local pityMythic    = DataManager.getPityMythic(player)

	local brainrot
	local isPityDrop = false
	local luck = BrainrotConfig.getLuck(DataManager.getRebirthCount(player))

	-- Check pity triggers highest-tier first so mythic pity beats legendary pity etc.
	if PITY_CFG.Enabled and pityMythic >= PITY_CFG.Mythic.Threshold then
		brainrot    = BrainrotConfig.getGuaranteedMythicBrainrot()
		isPityDrop  = true
		pityUncommon  = 0
		pityLegendary = 0
		pityMythic    = 0
		print("[Server] " .. player.Name .. " hit MYTHIC pity! Got: " .. brainrot.Name)

	elseif PITY_CFG.Enabled and pityLegendary >= PITY_CFG.Legendary.Threshold then
		brainrot    = BrainrotConfig.getGuaranteedLegendaryBrainrot()
		isPityDrop  = true
		pityUncommon  = 0
		pityLegendary = 0
		-- mythic counter keeps running (legendary doesn't satisfy mythic pity)
		pityMythic    = pityMythic + 1
		print("[Server] " .. player.Name .. " hit LEGENDARY pity! Got: " .. brainrot.Name)

	elseif PITY_CFG.Enabled and pityUncommon >= PITY_CFG.Uncommon.Threshold then
		brainrot    = BrainrotConfig.getGuaranteedRareBrainrot()
		isPityDrop  = true
		pityUncommon  = 0
		-- legendary/mythic counters keep running
		pityLegendary = pityLegendary + 1
		pityMythic    = pityMythic    + 1
		print("[Server] " .. player.Name .. " hit UNCOMMON pity! Got: " .. brainrot.Name)

	else
		brainrot = BrainrotConfig.getRandomBrainrot(luck)
		local r  = brainrot.Rarity

		if r >= PITY_CFG.Mythic.MinRarity then
			-- Mythic: resets all counters
			pityUncommon  = 0
			pityLegendary = 0
			pityMythic    = 0
			print("[Server] " .. player.Name .. " got MYTHIC naturally — all pity reset.")
		elseif r >= PITY_CFG.Legendary.MinRarity then
			-- Legendary: resets uncommon + legendary, mythic keeps going
			pityUncommon  = 0
			pityLegendary = 0
			pityMythic    = pityMythic + 1
			print("[Server] " .. player.Name .. " got LEGENDARY naturally — uncommon/legendary pity reset.")
		elseif r >= PITY_CFG.Uncommon.MinRarity then
			-- Uncommon: resets only uncommon counter
			pityUncommon  = 0
			pityLegendary = pityLegendary + 1
			pityMythic    = pityMythic    + 1
			print("[Server] " .. player.Name .. " got UNCOMMON naturally — uncommon pity reset.")
		else
			-- Common: all counters increment
			pityUncommon  = pityUncommon  + 1
			pityLegendary = pityLegendary + 1
			pityMythic    = pityMythic    + 1
		end
	end

	-- Persist updated counters
	DataManager.setPityCount(player,    pityUncommon)
	DataManager.setPityLegendary(player, pityLegendary)
	DataManager.setPityMythic(player,    pityMythic)

	-- Near-miss check
	local shouldShowNearMiss = false
	local nearMissBrainrot   = nil

	if BrainrotConfig.NearMissConfig.Enabled and not isPityDrop then
		if brainrot.Rarity < BrainrotConfig.NearMissConfig.MinRarityToShow then
			if math.random() < BrainrotConfig.NearMissConfig.Chance then
				shouldShowNearMiss = true
				nearMissBrainrot   = BrainrotConfig.getSuperRareBrainrot()
			end
		end
	end

	-- Persist item and award money
	local slotId          = DataManager.addItem(player, brainrot.Name)
	local equippedName    = DataManager.getEquippedBrainrot(player)
	local equippedBrainrot = equippedName and BrainrotConfig.getBrainrotByName(equippedName) or nil
	local moneyReward     = BrainrotConfig.getMoneyForBrainrot(equippedBrainrot)
	DataManager.addMoney(player, moneyReward)

	print("[Server] " .. player.Name .. " rolled " .. brainrot.Name
		.. " (1/" .. brainrot.Rarity .. ")"
		.. " | U:" .. pityUncommon .. "/" .. PITY_CFG.Uncommon.Threshold
		.. " L:" .. pityLegendary  .. "/" .. PITY_CFG.Legendary.Threshold
		.. " M:" .. pityMythic     .. "/" .. PITY_CFG.Mythic.Threshold)

	SpinRemote:FireClient(player, {
		Result           = brainrot,
		SlotId           = slotId,
		NearMiss         = shouldShowNearMiss,
		NearMissBrainrot = nearMissBrainrot,
		IsPityDrop       = isPityDrop,
		-- Per-tier pity state for the UI bars
		Pity = {
			uncommonCount  = pityUncommon,
			uncommonMax    = PITY_CFG.Uncommon.Threshold,
			legendaryCount = pityLegendary,
			legendaryMax   = PITY_CFG.Legendary.Threshold,
			mythicCount    = pityMythic,
			mythicMax      = PITY_CFG.Mythic.Threshold,
		},
	})
end)

return SpinHandler
