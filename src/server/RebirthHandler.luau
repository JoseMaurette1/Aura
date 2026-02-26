-- Server-side handler for rebirth (prestige) requests
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.BrainrotConfig)
local DataManager    = require(script.Parent.DataManager)

local RebirthHandler = {}

function RebirthHandler.init(remoteEventsFolder)
	local rebirthRemote = Instance.new("RemoteEvent")
	rebirthRemote.Name   = "RebirthRemote"
	rebirthRemote.Parent = remoteEventsFolder

	rebirthRemote.OnServerEvent:Connect(function(player)
		local rolls = DataManager.getRolls(player)
		local currentRebirthCount = DataManager.getRebirthCount(player)
		local cost = BrainrotConfig.getRebirthCost(currentRebirthCount)
		if rolls < cost then return end

		DataManager.resetRolls(player)
		local newCount = currentRebirthCount + 1
		DataManager.setRebirthCount(player, newCount)

		local nextCost = BrainrotConfig.getRebirthCost(newCount)
		rebirthRemote:FireClient(player, { RebirthCount = newCount, NextCost = nextCost })
		print("[Server] " .. player.Name .. " rebirthed! Count: " .. newCount)
	end)
end

return RebirthHandler
