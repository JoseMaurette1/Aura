-- Persistent data management using DataStoreService
-- Owns save/load/delete for all player data (inventory, money, pity counter)
local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local STORE_NAME = "PlayerData_v1"
local dataStore  = DataStoreService:GetDataStore(STORE_NAME)

-- In-memory cache per player
-- [userId] = { inventory: {[slotId] = name}, nextSlotId: N, money: N, pityCount: N }
local cache = {}

local function defaultData()
	return { inventory = {}, nextSlotId = 1, money = 0, pityCount = 0 }
end

-- Flatten sparse slot dict to a sorted array for JSON-safe serialization
local function serializeData(data)
	local entries = {}
	for slotId, name in pairs(data.inventory) do
		table.insert(entries, { slotId = slotId, name = name })
	end
	table.sort(entries, function(a, b) return a.slotId < b.slotId end)

	local invArray = {}
	for _, entry in ipairs(entries) do
		table.insert(invArray, entry.name)
	end

	return { inventory = invArray, money = data.money, pityCount = data.pityCount }
end

-- Rebuild in-memory struct from raw DataStore table
local function deserializeData(raw)
	local data = defaultData()
	data.money     = raw.money     or 0
	data.pityCount = raw.pityCount or 0

	if raw.inventory then
		for i, name in ipairs(raw.inventory) do
			data.inventory[i] = name
			data.nextSlotId   = i + 1
		end
	end

	return data
end

local function updateLeaderstats(player, money)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local mv = ls:FindFirstChild("Money")
		if mv then mv.Value = money end
	end
end

local function savePlayer(userId)
	local data = cache[userId]
	if not data then return end

	local ok, err = pcall(function()
		dataStore:SetAsync(userId, serializeData(data))
	end)

	if not ok then
		warn("[DataManager] Save failed for " .. userId .. ": " .. tostring(err))
	end
end

local DataManager = {}

-- Call this once from SpinHandler after it creates the RemoteEvents folder
function DataManager.init(remoteEventsFolder)
	-- Create the two remotes this module owns
	local loadRemote = Instance.new("RemoteEvent")
	loadRemote.Name  = "LoadInventoryRemote"
	loadRemote.Parent = remoteEventsFolder

	local deleteRemote = Instance.new("RemoteEvent")
	deleteRemote.Name  = "DeleteItemRemote"
	deleteRemote.Parent = remoteEventsFolder

	-- ── Player joined ──────────────────────────────────────────────────────────
	Players.PlayerAdded:Connect(function(player)
		local userId = tostring(player.UserId)

		-- Create leaderstats immediately with 0 money; updated after load
		local leaderstats = Instance.new("Folder")
		leaderstats.Name   = "leaderstats"
		leaderstats.Parent = player

		local moneyValue = Instance.new("IntValue")
		moneyValue.Name   = "Money"
		moneyValue.Value  = 0
		moneyValue.Parent = leaderstats

		-- Load from DataStore (yields — that's fine, we're in a PlayerAdded handler)
		local ok, raw = pcall(function()
			return dataStore:GetAsync(userId)
		end)

		local data
		if ok and raw then
			data = deserializeData(raw)
		else
			if not ok then
				warn("[DataManager] Load failed for " .. player.Name .. ": " .. tostring(raw))
			end
			data = defaultData()
		end

		cache[userId] = data
		moneyValue.Value = data.money

		-- Send saved inventory to client as {slotId, name} pairs
		local loadList = {}
		for slotId, name in pairs(data.inventory) do
			table.insert(loadList, { slotId = slotId, name = name })
		end
		-- Sort by slotId so client receives items in original roll order
		table.sort(loadList, function(a, b) return a.slotId < b.slotId end)

		loadRemote:FireClient(player, loadList)
		print("[DataManager] Loaded " .. #loadList .. " items for " .. player.Name)
	end)

	-- ── Player leaving ─────────────────────────────────────────────────────────
	Players.PlayerRemoving:Connect(function(player)
		local userId = tostring(player.UserId)
		savePlayer(userId)
		cache[userId] = nil
	end)

	-- ── Client wants to delete a slot ──────────────────────────────────────────
	deleteRemote.OnServerEvent:Connect(function(player, slotId)
		local userId = tostring(player.UserId)
		local data   = cache[userId]
		if data and type(slotId) == "number" then
			data.inventory[slotId] = nil
		end
	end)

	-- ── Save everyone on server shutdown ───────────────────────────────────────
	game:BindToClose(function()
		for userId in pairs(cache) do
			savePlayer(userId)
		end
	end)
end

-- Add a new item; returns the slotId the client should store on its frame
function DataManager.addItem(player, brainrotName)
	local data = cache[tostring(player.UserId)]
	if not data then return nil end

	local slotId            = data.nextSlotId
	data.inventory[slotId]  = brainrotName
	data.nextSlotId         = slotId + 1
	return slotId
end

function DataManager.addMoney(player, amount)
	local data = cache[tostring(player.UserId)]
	if not data then return 0 end
	data.money = data.money + amount
	updateLeaderstats(player, data.money)
	return data.money
end

function DataManager.getMoney(player)
	local data = cache[tostring(player.UserId)]
	return data and data.money or 0
end

function DataManager.getPityCount(player)
	local data = cache[tostring(player.UserId)]
	return data and data.pityCount or 0
end

function DataManager.setPityCount(player, count)
	local data = cache[tostring(player.UserId)]
	if data then data.pityCount = count end
end

return DataManager
