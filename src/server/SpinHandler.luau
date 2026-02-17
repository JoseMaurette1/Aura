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

-- ── Spin request ───────────────────────────────────────────────────────────────
SpinRemote.OnServerEvent:Connect(function(player: Player)
	local pityCount  = DataManager.getPityCount(player)
	local brainrot
	local isPityDrop = false

	-- Pity guarantee
	if BrainrotConfig.PityConfig.Enabled and pityCount >= BrainrotConfig.PityConfig.PityThreshold then
		brainrot     = BrainrotConfig.getGuaranteedRareBrainrot()
		isPityDrop   = true
		DataManager.setPityCount(player, 0)
		print("[Server] " .. player.Name .. " hit pity! Got: " .. brainrot.Name)
	else
		brainrot   = BrainrotConfig.getRandomBrainrot()
		pityCount  = pityCount + 1

		if BrainrotConfig.countsForPityReset(brainrot) then
			pityCount = 0
			print("[Server] " .. player.Name .. " got rare naturally — pity reset.")
		end

		DataManager.setPityCount(player, pityCount)
	end

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

	-- Persist the new item and award money
	local slotId = DataManager.addItem(player, brainrot.Name)
	DataManager.addMoney(player, brainrot.MoneyReward)

	local currentPity = DataManager.getPityCount(player)
	print("[Server] " .. player.Name .. " rolled " .. brainrot.Name
		.. " (1/" .. brainrot.Rarity .. ") | Pity: "
		.. currentPity .. "/" .. BrainrotConfig.PityConfig.PityThreshold)

	SpinRemote:FireClient(player, {
		Result          = brainrot,
		SlotId          = slotId,
		NearMiss        = shouldShowNearMiss,
		NearMissBrainrot = nearMissBrainrot,
		PityCounter     = currentPity,
		PityMax         = BrainrotConfig.PityConfig.PityThreshold,
		IsPityDrop      = isPityDrop,
	})
end)

return SpinHandler
