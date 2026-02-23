-- Opens ShopGUI when the local player stands inside Workspace/Shop/SimulatorCircle,
-- closes it when they leave. Uses a Heartbeat distance check instead of Touched/TouchEnded
-- to avoid the flicker caused by individual limbs briefly leaving the part while running.
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIManager = require(script.Parent.UIManager)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SimulatorCircleController = {}

function SimulatorCircleController.init()
	local shop   = workspace:WaitForChild("Shop")
	local circle = shop:WaitForChild("SimulatorCircle")

	local screenGui = playerGui:WaitForChild("ScreenGui")
	local shopFrame = screenGui:WaitForChild("ShopGUI")

	-- Determine the trigger radius from the part's size (works for Part / MeshPart cylinders)
	-- Use the larger of X/Z so irregular shapes still feel natural
	local function getRadius()
		local size = circle:IsA("BasePart") and circle.Size
			or circle:IsA("Model") and circle:GetExtentsSize()
			or Vector3.new(10, 10, 10)
		return math.max(size.X, size.Z) / 2
	end

	local function getCircleCenter()
		if circle:IsA("BasePart") then
			return circle.Position
		elseif circle:IsA("Model") then
			return circle:GetBoundingBox().Position
		end
		return Vector3.zero
	end

	local isInside = false

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		-- 2-D (XZ) distance so height doesn't affect the trigger
		local center = getCircleCenter()
		local dx     = hrp.Position.X - center.X
		local dz     = hrp.Position.Z - center.Z
		local dist   = math.sqrt(dx * dx + dz * dz)

		local inside = dist <= getRadius()

		if inside and not isInside then
			isInside = true
			UIManager.open(shopFrame)
		elseif not inside and isInside then
			isInside = false
			UIManager.close(shopFrame)
		end
	end)

	print("[Client] SimulatorCircle Controller initialized")
end

return SimulatorCircleController
