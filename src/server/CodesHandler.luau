-- Server-side handler for code redemption
local DataManager = require(script.Parent.DataManager)

-- Add/remove codes here as you release them.
-- Each code gives a rolls reward when redeemed once per player.
local CODES = {
	["WELCOME"]   = { rolls = 500  },
	["TUNG100"]   = { rolls = 100  },
	["BRAINROT"]  = { rolls = 1000 },
	["LAUNCH"]    = { rolls = 2500 },
}

local CodesHandler = {}

function CodesHandler.init(remoteEventsFolder)
	local redeemRemote        = Instance.new("RemoteEvent")
	redeemRemote.Name         = "RedeemCodeRemote"
	redeemRemote.Parent       = remoteEventsFolder

	redeemRemote.OnServerEvent:Connect(function(player, code)
		-- Sanity check — never trust client input
		if type(code) ~= "string" or #code > 50 then return end

		local upper    = code:upper():gsub("%s+", "")
		local codeData = CODES[upper]

		if not codeData then
			redeemRemote:FireClient(player, { success = false, message = "Invalid code." })
			return
		end

		if DataManager.hasRedeemedCode(player, upper) then
			redeemRemote:FireClient(player, { success = false, message = "Already redeemed!" })
			return
		end

		-- Mark redeemed and give reward
		DataManager.markCodeRedeemed(player, upper)

		if codeData.rolls then
			DataManager.addRolls(player, codeData.rolls)
		end

		redeemRemote:FireClient(player, {
			success = true,
			message = "Code redeemed! +" .. (codeData.rolls or 0) .. " rolls",
			rolls   = codeData.rolls or 0,
		})

		print("[CodesHandler] " .. player.Name .. " redeemed: " .. upper)
	end)
end

return CodesHandler
