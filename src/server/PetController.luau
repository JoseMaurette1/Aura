-- Server-side handler for brainrot equip/unequip (pet following system)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

local BrainrotConfig = require(ReplicatedStorage.Shared.BrainrotConfig)

local PetController = {}

-- How far to the right of the player the pet floats
local PET_SIDE_DISTANCE = 5
-- How many studs above HRP the pet hovers (HRP is ~3 studs above ground, so 3 = head height)
local PET_FLOAT_HEIGHT  = 3
-- Smoothing speed (higher = snappier follow)
local PET_FOLLOW_SPEED  = 8

-- Active pets per player: { [userId] = { model: Model, connection: RBXScriptConnection } }
local activePets = {}

-- Create EquipRemote inside the existing RemoteEvents folder (SpinHandler creates it first)
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local EquipRemote  = Instance.new("RemoteEvent")
EquipRemote.Name   = "EquipRemote"
EquipRemote.Parent = RemoteEvents

-- Compute the world CFrame the pet should float at beside the player
local function getTargetCFrame(hrp: BasePart): CFrame
	local right     = hrp.CFrame.RightVector
	local targetPos = Vector3.new(
		hrp.Position.X + right.X * PET_SIDE_DISTANCE,
		hrp.Position.Y + PET_FLOAT_HEIGHT,
		hrp.Position.Z + right.Z * PET_SIDE_DISTANCE
	)
	return CFrame.lookAt(targetPos, targetPos + hrp.CFrame.LookVector)
end

local function removePet(userId: number)
	local petData = activePets[userId]
	if not petData then return end

	if petData.connection then
		petData.connection:Disconnect()
	end

	if petData.model and petData.model.Parent then
		petData.model:Destroy()
	end

	activePets[userId] = nil
end

local function spawnPet(player: Player, brainrotName: string)
	local userId = player.UserId
	removePet(userId)

	-- Validate the brainrot exists in config
	local brainrotData = BrainrotConfig.getBrainrotByName(brainrotName)
	if not brainrotData then
		warn("[PetController] Unknown brainrot requested: " .. tostring(brainrotName))
		return
	end

	-- Find the model template in ServerStorage
	local brainrotsFolder = ServerStorage:FindFirstChild("Brainrots")
	if not brainrotsFolder then
		warn("[PetController] ServerStorage/Brainrots folder not found")
		return
	end

	local modelTemplate = brainrotsFolder:FindFirstChild(brainrotData.ModelName)
	if not modelTemplate then
		warn("[PetController] Model not found for: " .. brainrotData.ModelName)
		return
	end

	-- Clone the model into Workspace
	local petModel  = modelTemplate:Clone()
	petModel.Name   = player.Name .. "_Pet"

	-- Anchor every part so physics doesn't fight PivotTo in the follow loop
	for _, part in ipairs(petModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored   = true
			part.CanCollide = false
		end
	end

	petModel.Parent = workspace

	-- Snap immediately to float position so the pet doesn't lerp in from (0,0,0)
	local character = player.Character
	local hrp       = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		petModel:PivotTo(getTargetCFrame(hrp))
	end

	-- Smooth follow loop
	local connection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		if not petModel or not petModel.Parent then
			connection:Disconnect()
			activePets[userId] = nil
			return
		end

		local char = player.Character
		if not char then return end

		local hrp2 = char:FindFirstChild("HumanoidRootPart")
		if not hrp2 then return end

		local alpha = 1 - math.exp(-PET_FOLLOW_SPEED * dt)
		petModel:PivotTo(petModel:GetPivot():Lerp(getTargetCFrame(hrp2), alpha))
	end)

	activePets[userId] = { model = petModel, connection = connection }
	print("[PetController] Spawned pet '" .. brainrotName .. "' for " .. player.Name)
end

-- Client fires EquipRemote with a brainrot name to equip, or nil to unequip
EquipRemote.OnServerEvent:Connect(function(player: Player, brainrotName)
	if brainrotName == nil then
		removePet(player.UserId)
		print("[PetController] " .. player.Name .. " unequipped pet")
	else
		spawnPet(player, tostring(brainrotName))
	end
end)

-- Clean up when a player leaves
Players.PlayerRemoving:Connect(function(player: Player)
	removePet(player.UserId)
end)

return PetController
