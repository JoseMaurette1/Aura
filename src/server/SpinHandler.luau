-- Server-side handler for spin requests
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BrainrotConfig = require(ReplicatedStorage.Shared.BrainrotConfig)

local SpinHandler = {}

-- Remote events folder
local RemoteEvents = Instance.new("Folder")
RemoteEvents.Name = "RemoteEvents"
RemoteEvents.Parent = ReplicatedStorage

-- Create remote event for spin requests
local SpinRemote = Instance.new("RemoteEvent")
SpinRemote.Name = "SpinRemote"
SpinRemote.Parent = RemoteEvents

-- Player data storage (in a real game, use DataStores)
local PlayerData = {}

-- Initialize player data
local function initializePlayerData(player: Player)
	if not PlayerData[player.UserId] then
		PlayerData[player.UserId] = {
			Money = 0,
			Inventory = {},
			TotalSpins = 0,
			PityCounter = 0 -- Tracks rolls since last rare drop
		}
	end
end

-- Handle player joining
Players.PlayerAdded:Connect(function(player)
	initializePlayerData(player)

	-- Create leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local moneyValue = Instance.new("IntValue")
	moneyValue.Name = "Money"
	moneyValue.Value = PlayerData[player.UserId].Money
	moneyValue.Parent = leaderstats

	print(`[Server] Player {player.Name} joined with {PlayerData[player.UserId].Money} money`)
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	-- In a real game, save data to DataStore here
	PlayerData[player.UserId] = nil
end)

-- Handle spin request
SpinRemote.OnServerEvent:Connect(function(player: Player)
	initializePlayerData(player)

	local playerData = PlayerData[player.UserId]

	-- Check pity system
	local brainrot
	local isPityDrop = false

	if BrainrotConfig.PityConfig.Enabled and playerData.PityCounter >= BrainrotConfig.PityConfig.PityThreshold then
		-- Guarantee a rare drop
		brainrot = BrainrotConfig.getGuaranteedRareBrainrot()
		isPityDrop = true
		playerData.PityCounter = 0
		print(`[Server] {player.Name} hit pity! Guaranteed rare drop: {brainrot.Name}`)
	else
		-- Normal random drop
		brainrot = BrainrotConfig.getRandomBrainrot()

		-- Update pity counter
		playerData.PityCounter = playerData.PityCounter + 1

		-- Reset pity if they got a rare naturally
		if BrainrotConfig.countsForPityReset(brainrot) then
			playerData.PityCounter = 0
			print(`[Server] {player.Name} got rare naturally! Pity reset.`)
		end
	end

	-- Check for near-miss effect
	local shouldShowNearMiss = false
	local nearMissBrainrot = nil

	if BrainrotConfig.NearMissConfig.Enabled and not isPityDrop then
		-- Don't show near-miss if they already got something rare
		if brainrot.Rarity < BrainrotConfig.NearMissConfig.MinRarityToShow then
			local nearMissRoll = math.random()
			if nearMissRoll < BrainrotConfig.NearMissConfig.Chance then
				shouldShowNearMiss = true
				nearMissBrainrot = BrainrotConfig.getSuperRareBrainrot()
				print(`[Server] {player.Name} near-miss! Showing {nearMissBrainrot.Name} nearby`)
			end
		end
	end

	-- Update player data
	playerData.Money = playerData.Money + brainrot.MoneyReward
	playerData.TotalSpins = playerData.TotalSpins + 1

	-- Add to inventory
	table.insert(playerData.Inventory, {
		Name = brainrot.Name,
		Timestamp = os.time()
	})

	-- Update leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local moneyValue = leaderstats:FindFirstChild("Money")
		if moneyValue then
			moneyValue.Value = playerData.Money
		end
	end

	local pityInfo = `(Pity: {playerData.PityCounter}/{BrainrotConfig.PityConfig.PityThreshold})`
	print(`[Server] {player.Name} spun and got {brainrot.Name} (1/{brainrot.Rarity}) - Reward: ${brainrot.MoneyReward} {pityInfo}`)

	-- Send result back to client with near-miss info
	SpinRemote:FireClient(player, {
		Result = brainrot,
		NearMiss = shouldShowNearMiss,
		NearMissBrainrot = nearMissBrainrot,
		PityCounter = playerData.PityCounter,
		PityMax = BrainrotConfig.PityConfig.PityThreshold,
		IsPityDrop = isPityDrop
	})
end)

return SpinHandler
