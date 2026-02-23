-- Client-side controller for the codes UI and TungTungTungSahur proximity interaction
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIManager     = require(script.Parent.UIManager)
local ButtonEffects = require(script.Parent.ButtonEffects)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CodesController = {}

function CodesController.init()
	local screenGui     = playerGui:WaitForChild("ScreenGui")
	local codesGUI      = screenGui:WaitForChild("CodesGUI")
	local codeSection   = codesGUI:WaitForChild("CodeSection")
	local codeBox       = codeSection:WaitForChild("CodeBox")
	local redeemButton  = codesGUI:WaitForChild("RedeemButton")
	local feedbackLabel = codesGUI:WaitForChild("FeedbackLabel")
	local exitButton    = codesGUI:WaitForChild("ExitButton")
	local codesButton   = screenGui:WaitForChild("CodesButton")

	codesGUI.Visible = false

	ButtonEffects.apply(redeemButton)
	ButtonEffects.applySubtle(exitButton)
	ButtonEffects.applySubtle(codesButton)

	-- CodesButton opens the codes GUI
	codesButton.MouseButton1Click:Connect(function()
		feedbackLabel.Text = ""
		codeBox.Text       = ""
		UIManager.open(codesGUI)
	end)

	-- ProximityPrompt wired up independently — doesn't depend on remotes being ready
	task.spawn(function()
		local npc    = workspace:WaitForChild("TungTungTungSahur")
		local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function()
				feedbackLabel.Text = ""
				codeBox.Text       = ""
				UIManager.open(codesGUI)
			end)
		else
			warn("[CodesController] No ProximityPrompt found in TungTungTungSahur")
		end
	end)

	exitButton.MouseButton1Click:Connect(function()
		feedbackLabel.Text = ""
		codeBox.Text       = ""
		UIManager.close(codesGUI)
	end)

	-- Redeem button and server response wired in their own spawn so WaitForChild
	-- on the remote never blocks the ProximityPrompt connection above
	task.spawn(function()
		local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
		local redeemRemote = RemoteEvents:WaitForChild("RedeemCodeRemote")

		redeemButton.MouseButton1Click:Connect(function()
			local code = codeBox.Text:upper():gsub("%s+", "")
			if code == "" then return end

			redeemButton.Active      = false
			feedbackLabel.Text       = "Redeeming..."
			feedbackLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

			redeemRemote:FireServer(code)
		end)

		redeemRemote.OnClientEvent:Connect(function(result)
			redeemButton.Active      = true
			feedbackLabel.Text       = result.message
			feedbackLabel.TextColor3 = result.success
				and Color3.fromRGB(80, 220, 80)
				or  Color3.fromRGB(220, 80, 80)

			if result.success then
				codeBox.Text = ""
			end
		end)
	end)

	print("[Client] Codes Controller initialized")
end

return CodesController
