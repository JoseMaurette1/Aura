-- Persistent data management using DataStoreService
-- Owns save/load/delete for all player data (inventory, money, pity counter)
local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local STORE_NAME = "PlayerData_v1"
local dataStore  = DataStoreService:GetDataStore(STORE_NAME)

-- In-memory cache per player
-- [userId] = { inventory, nextSlotId, money, pityCount, pityLegendary, pityMythic, rebirthCount, equippedBrainrot }
local cache = {}

local function defaultData()
	return {
		inventory        = {},
		nextSlotId       = 1,
		money            = 0,
		pityCount        = 0,   -- spins since last uncommon+ (uncommon pity)
		pityLegendary    = 0,   -- spins since last legendary+
		pityMythic       = 0,   -- spins since last mythic
		rebirthCount     = 0,
		equippedBrainrot = nil,
		redeemedCodes    = {},  -- set: { ["CODENAME"] = true }
	}
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

	-- Serialize redeemedCodes set → array for JSON safety
	local redeemedArray = {}
	for code in pairs(data.redeemedCodes) do
		table.insert(redeemedArray, code)
	end

	return {
		inventory      = invArray,
		money          = data.money,
		pityCount      = data.pityCount,
		pityLegendary  = data.pityLegendary,
		pityMythic     = data.pityMythic,
		rebirthCount   = data.rebirthCount,
		redeemedCodes  = redeemedArray,
	}
end

-- Rebuild in-memory struct from raw DataStore table
local function deserializeData(raw)
	local data = defaultData()
	data.money          = raw.money          or 0
	data.pityCount      = raw.pityCount      or 0
	data.pityLegendary  = raw.pityLegendary  or 0
	data.pityMythic     = raw.pityMythic     or 0
	data.rebirthCount   = raw.rebirthCount   or 0

	-- Deserialize redeemedCodes array → set for O(1) lookup
	if raw.redeemedCodes then
		for _, code in ipairs(raw.redeemedCodes) do
			data.redeemedCodes[code] = true
		end
	end

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

local function updateRebirthLeaderstats(player, rebirthCount)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local rv = ls:FindFirstChild("Rebirths")
		if rv then rv.Value = rebirthCount end
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
	-- Create the remotes this module owns
	local loadRemote = Instance.new("RemoteEvent")
	loadRemote.Name  = "LoadInventoryRemote"
	loadRemote.Parent = remoteEventsFolder

	local pityLoadRemote = Instance.new("RemoteEvent")
	pityLoadRemote.Name  = "PityLoadRemote"
	pityLoadRemote.Parent = remoteEventsFolder

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

		local rebirthsValue = Instance.new("IntValue")
		rebirthsValue.Name   = "Rebirths"
		rebirthsValue.Value  = 0
		rebirthsValue.Parent = leaderstats

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
		moneyValue.Value    = data.money
		rebirthsValue.Value = data.rebirthCount

		-- Send saved inventory to client as {slotId, name} pairs
		local loadList = {}
		for slotId, name in pairs(data.inventory) do
			table.insert(loadList, { slotId = slotId, name = name })
		end
		-- Sort by slotId so client receives items in original roll order
		table.sort(loadList, function(a, b) return a.slotId < b.slotId end)

		loadRemote:FireClient(player, loadList)

		-- Send initial pity counts so the UI bars show correct values on join
		pityLoadRemote:FireClient(player, {
			uncommonCount  = data.pityCount,
			uncommonMax    = 50,
			legendaryCount = data.pityLegendary,
			legendaryMax   = 300,
			mythicCount    = data.pityMythic,
			mythicMax      = 1000,
		})

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

-- Add a new item; returns the slotId the client should store on its frame.
-- Returns nil if inventory is full (100-slot cap).
function DataManager.addItem(player, brainrotName)
	local data = cache[tostring(player.UserId)]
	if not data then return nil end

	local count = 0
	for _ in pairs(data.inventory) do count += 1 end
	if count >= 100 then return nil end

	local slotId            = data.nextSlotId
	data.inventory[slotId]  = brainrotName
	data.nextSlotId         = slotId + 1
	return slotId
end

function DataManager.setEquippedBrainrot(player, brainrotName)
	local data = cache[tostring(player.UserId)]
	if data then data.equippedBrainrot = brainrotName end
end

function DataManager.getEquippedBrainrot(player)
	local data = cache[tostring(player.UserId)]
	return data and data.equippedBrainrot or nil
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

function DataManager.getPityLegendary(player)
	local data = cache[tostring(player.UserId)]
	return data and data.pityLegendary or 0
end

function DataManager.setPityLegendary(player, count)
	local data = cache[tostring(player.UserId)]
	if data then data.pityLegendary = count end
end

function DataManager.getPityMythic(player)
	local data = cache[tostring(player.UserId)]
	return data and data.pityMythic or 0
end

function DataManager.setPityMythic(player, count)
	local data = cache[tostring(player.UserId)]
	if data then data.pityMythic = count end
end

function DataManager.getRebirthCount(player)
	local data = cache[tostring(player.UserId)]
	return data and data.rebirthCount or 0
end

function DataManager.setRebirthCount(player, count)
	local data = cache[tostring(player.UserId)]
	if not data then return end
	data.rebirthCount = count
	updateRebirthLeaderstats(player, count)
end

function DataManager.hasRedeemedCode(player, code: string): boolean
	local data = cache[tostring(player.UserId)]
	return data and data.redeemedCodes[code] == true or false
end

function DataManager.markCodeRedeemed(player, code: string)
	local data = cache[tostring(player.UserId)]
	if data then data.redeemedCodes[code] = true end
end

function DataManager.resetMoney(player)
	local data = cache[tostring(player.UserId)]
	if not data then return end
	data.money = 0
	updateLeaderstats(player, 0)
end

return DataManager
