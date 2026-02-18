-- Server-side handler for brainrot equip/unequip (pet following system)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

local BrainrotConfig = require(ReplicatedStorage.Shared.BrainrotConfig)
local DataManager    = require(script.Parent.DataManager)

local PetController = {}

-- How far to the right of the player the pet floats
local PET_SIDE_DISTANCE = 5
-- How many studs above HRP the pet hovers
local PET_FLOAT_HEIGHT  = 3
-- Smoothing speed (higher = snappier follow)
local PET_FOLLOW_SPEED  = 8

-- Active pets per player: { [userId] = { model, connection, auraModel, billboard } }
local activePets = {}

-- Locked aura assignments: { [userId] = { [brainrotName] = auraTemplateName } }
-- Assigned randomly on first equip and reused every time after
local auraAssignments = {}

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

-- Map a brainrot's Rarity number to its tier name prefix
local function getTierPrefix(rarity: number): string
	if rarity >= 10000 then return "Mythic"
	elseif rarity >= 2500 then return "Legendary"
	elseif rarity >= 500  then return "Rare"
	elseif rarity >= 75   then return "Uncommon"
	else                       return "Common"
	end
end

-- Scan ServerStorage/BrainrotAura for all children whose name starts with the tier prefix,
-- then return one at random. Returns nil if none found.
local function pickRandomAuraName(brainrotData): string?
	-- Per-brainrot override in BrainrotConfig takes priority
	if brainrotData.AuraName then
		return brainrotData.AuraName
	end

	local auraFolder = ServerStorage:FindFirstChild("BrainrotAura")
	if not auraFolder then
		warn("[PetController] ServerStorage/BrainrotAura folder not found")
		return nil
	end

	local prefix  = getTierPrefix(brainrotData.Rarity)
	local matches = {}
	for _, child in ipairs(auraFolder:GetChildren()) do
		if child.Name:sub(1, #prefix) == prefix then
			table.insert(matches, child.Name)
		end
	end

	if #matches == 0 then return nil end
	return matches[math.random(1, #matches)]
end

-- Returns the locked aura name for this player+brainrot.
-- Assigns a random one on first call and remembers it for all future calls.
local function getOrAssignAura(userId: number, brainrotData): string?
	if not auraAssignments[userId] then
		auraAssignments[userId] = {}
	end

	local key = brainrotData.Name
	if not auraAssignments[userId][key] then
		auraAssignments[userId][key] = pickRandomAuraName(brainrotData)
	end

	return auraAssignments[userId][key]
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

	if petData.auraModel and petData.auraModel.Parent then
		petData.auraModel:Destroy()
	end

	if petData.billboard and petData.billboard.Parent then
		petData.billboard:Destroy()
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

	-- Find the pet model template in ServerStorage
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

	local character = player.Character
	local hrp       = character and character:FindFirstChild("HumanoidRootPart")
	local head      = character and character:FindFirstChild("Head")

	-- Clone the pet model into Workspace
	local petModel = modelTemplate:Clone()
	petModel.Name  = player.Name .. "_Pet"

	for _, part in ipairs(petModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored   = true
			part.CanCollide = false
		end
	end

	petModel.Parent = workspace

	if hrp then
		petModel:PivotTo(getTargetCFrame(hrp))
	end

	-- === Aura: clone the assigned Studio-designed aura from ServerStorage/BrainrotAura ===
	local auraModel = nil
	if hrp then
		local auraName     = getOrAssignAura(userId, brainrotData)
		local auraFolder   = ServerStorage:FindFirstChild("BrainrotAura")
		local auraTemplate = auraName and auraFolder and auraFolder:FindFirstChild(auraName)

		if auraTemplate then
			auraModel      = auraTemplate:Clone()
			auraModel.Name = player.Name .. "_Aura"

			-- Disable collision on every part inside the aura model
			for _, part in ipairs(auraModel:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
					part.Anchored   = false
				end
			end
			-- Also handle the case where the aura itself IS a single BasePart (e.g. a sphere)
			if auraModel:IsA("BasePart") then
				auraModel.CanCollide = false
				auraModel.Anchored   = false
			end

			auraModel.Parent = workspace

			-- Find the anchor part to weld to HRP.
			-- Priority: part named "Root" (rename one part to "Root" in Studio) →
			--           the aura itself if it is a BasePart →
			--           first BasePart found anywhere inside (fallback)
			local anchor = auraModel:FindFirstChild("Root", true)
			if not anchor then
				if auraModel:IsA("BasePart") then
					anchor = auraModel
				else
					for _, part in ipairs(auraModel:GetDescendants()) do
						if part:IsA("BasePart") then
							anchor = part
							break
						end
					end
				end
			end

			if anchor then
				-- Snap to player position then weld so it follows automatically
				anchor.CFrame = hrp.CFrame
				local weld    = Instance.new("WeldConstraint")
				weld.Part0    = hrp
				weld.Part1    = anchor
				weld.Parent   = anchor
			else
				warn("[PetController] Aura '" .. auraName .. "' has no BasePart to weld to HRP")
			end
		elseif auraName then
			warn("[PetController] Aura template not found in BrainrotAura: " .. auraName)
		end
	end

	-- === Overhead label: BillboardGui on the player's Head ===
	local billboard = nil
	if head then
		billboard             = Instance.new("BillboardGui")
		billboard.Name        = "BrainrotLabel"
		billboard.Size        = UDim2.new(0, 240, 0, 60)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = false
		billboard.Parent      = head

		local nameLabel                  = Instance.new("TextLabel")
		nameLabel.Size                   = UDim2.new(1, 0, 0.6, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text                   = brainrotData.Name
		nameLabel.TextColor3             = brainrotData.Color
		nameLabel.TextScaled             = true
		nameLabel.Font                   = Enum.Font.GothamBold
		nameLabel.Parent                 = billboard

		local nameStroke     = Instance.new("UIStroke")
		nameStroke.Color     = Color3.new(0, 0, 0)
		nameStroke.Thickness = 2
		nameStroke.Parent    = nameLabel

		local rarityLabel                  = Instance.new("TextLabel")
		rarityLabel.Size                   = UDim2.new(1, 0, 0.4, 0)
		rarityLabel.Position               = UDim2.new(0, 0, 0.6, 0)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text                   = "1 in " .. brainrotData.Rarity
		rarityLabel.TextColor3             = brainrotData.Color
		rarityLabel.TextScaled             = true
		rarityLabel.Font                   = Enum.Font.Gotham
		rarityLabel.Parent                 = billboard

		local rarityStroke     = Instance.new("UIStroke")
		rarityStroke.Color     = Color3.new(0, 0, 0)
		rarityStroke.Thickness = 2
		rarityStroke.Parent    = rarityLabel
	end

	-- Smooth follow loop (pet model only — aura follows via weld automatically)
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

	activePets[userId] = {
		model      = petModel,
		connection = connection,
		auraModel  = auraModel,
		billboard  = billboard,
	}
	print("[PetController] Spawned pet '" .. brainrotName .. "' for " .. player.Name)
end

-- Client fires EquipRemote with a brainrot name to equip, or nil to unequip
EquipRemote.OnServerEvent:Connect(function(player: Player, brainrotName)
	if brainrotName == nil then
		removePet(player.UserId)
		DataManager.setEquippedBrainrot(player, nil)
		print("[PetController] " .. player.Name .. " unequipped pet")
	else
		spawnPet(player, tostring(brainrotName))
		DataManager.setEquippedBrainrot(player, tostring(brainrotName))
	end
end)

-- Clean up when a player leaves
Players.PlayerRemoving:Connect(function(player: Player)
	auraAssignments[player.UserId] = nil
	removePet(player.UserId)
end)

return PetController
