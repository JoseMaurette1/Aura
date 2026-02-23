-- Client-side controller for the codes UI and TungTungTungSahur proximity interaction
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIManager     = require(script.Parent.UIManager)
local ButtonEffects = require(script.Parent.ButtonEffects)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CodesController = {}

function CodesController.init()
	local screenGui    = playerGui:WaitForChild("ScreenGui")
	local codesGUI     = screenGui:WaitForChild("CodesGUI")
	local bgImageLabel = codesGUI:WaitForChild("ImageLabel")
	local codeSection  = codesGUI:WaitForChild("CodeSection")
	local codeBox      = codeSection:WaitForChild("CodeBox")
	local redeemButton = bgImageLabel:WaitForChild("RedeemButton")
	local exitButton   = codesGUI:WaitForChild("ExitButton")
	local codesButton  = screenGui:WaitForChild("CodesButton")

	-- FeedbackLabel is optional — only used if it exists in the GUI
	local feedbackLabel = codesGUI:FindFirstChild("FeedbackLabel", true)

	codesGUI.Visible = false

	ButtonEffects.apply(redeemButton)
	ButtonEffects.applySubtle(exitButton)
	ButtonEffects.applySubtle(codesButton)

	-- CodesButton opens the codes GUI
	codesButton.MouseButton1Click:Connect(function()
		if feedbackLabel then feedbackLabel.Text = "" end
		codeBox.Text = ""
		UIManager.open(codesGUI)
	end)

	-- ExitButton closes the codes GUI
	exitButton.MouseButton1Click:Connect(function()
		if feedbackLabel then feedbackLabel.Text = "" end
		codeBox.Text = ""
		UIManager.close(codesGUI)
	end)

	-- ProximityPrompt wired up independently — doesn't depend on remotes being ready
	task.spawn(function()
		local npc    = workspace:WaitForChild("TungTungTungSahur")
		local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function()
				if feedbackLabel then feedbackLabel.Text = "" end
				codeBox.Text = ""
				UIManager.open(codesGUI)
			end)
		else
			warn("[CodesController] No ProximityPrompt found in TungTungTungSahur")
		end
	end)

	-- Redeem button wired in its own spawn so WaitForChild on the remote
	-- never blocks the button connections above
	task.spawn(function()
		local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
		local redeemRemote = RemoteEvents:WaitForChild("RedeemCodeRemote")

		redeemButton.MouseButton1Click:Connect(function()
			local code = codeBox.Text:upper():gsub("%s+", "")
			if code == "" then return end

			redeemButton.Active = false
			if feedbackLabel then
				feedbackLabel.Text       = "Redeeming..."
				feedbackLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			end

			redeemRemote:FireServer(code)
		end)

		redeemRemote.OnClientEvent:Connect(function(result)
			redeemButton.Active = true
			if feedbackLabel then
				feedbackLabel.Text       = result.message
				feedbackLabel.TextColor3 = result.success
					and Color3.fromRGB(80, 220, 80)
					or  Color3.fromRGB(220, 80, 80)
			end

			if result.success then
				codeBox.Text = ""
			end
		end)
	end)

	print("[Client] Codes Controller initialized")
end

return CodesController
