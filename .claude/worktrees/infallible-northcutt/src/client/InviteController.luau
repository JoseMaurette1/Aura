-- Client-side controller for the invite button
-- Uses Roblox's built-in SocialService to show the native invite friends UI
local Players       = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local ButtonEffects = require(script.Parent.ButtonEffects)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local InviteController = {}

function InviteController.init()
	local screenGui    = playerGui:WaitForChild("ScreenGui")
	local inviteButton = screenGui:WaitForChild("InviteButton")
	ButtonEffects.apply(inviteButton)

	-- Check once at startup and cache — avoids a network round-trip on every click
	local canInvite = false
	task.spawn(function()
		local ok, result = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		canInvite = ok and result
	end)

	inviteButton.MouseButton1Click:Connect(function()
		if canInvite then
			SocialService:PromptGameInvite(player)
		end
	end)

	print("[Client] Invite Controller initialized")
end

return InviteController
