-- Server-side handler for gamepass ownership checks and purchase grants
local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService         = game:GetService("RunService")

-- TODO: replace 0 with the real GamePass ID from the Roblox Developer Dashboard
local AUTO_CLICK_GAMEPASS_ID = 0

-- Set to true so you automatically own the pass when playtesting in Studio
local STUDIO_OVERRIDE = true

local GamepassHandler = {}

local function grantAutoClick(player: Player)
	player:SetAttribute("OwnsAutoClick", true)
end

function GamepassHandler.init()
	Players.PlayerAdded:Connect(function(player)
		-- Studio bypass — skips the real ownership check during development
		if RunService:IsStudio() and STUDIO_OVERRIDE then
			grantAutoClick(player)
			print("[GamepassHandler] Studio override: granted AutoClick to " .. player.Name)
			return
		end

		-- Skip if no valid gamepass ID has been set yet
		if AUTO_CLICK_GAMEPASS_ID == 0 then return end

		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, AUTO_CLICK_GAMEPASS_ID)
		end)

		if ok and owns then
			grantAutoClick(player)
			print("[GamepassHandler] " .. player.Name .. " already owns AutoClick pass")
		end
	end)

	-- Grant immediately when purchase completes — no rejoin needed
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if passId == AUTO_CLICK_GAMEPASS_ID and wasPurchased then
			grantAutoClick(player)
			print("[GamepassHandler] " .. player.Name .. " purchased AutoClick gamepass!")
		end
	end)
end

return GamepassHandler
