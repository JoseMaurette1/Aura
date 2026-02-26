-- Server-side handler for brainrot equip/unequip (pet following system)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

local BrainrotConfig = require(ReplicatedStorage.Shared.BrainrotConfig)
local DataManager    = require(script.Parent.DataManager)

local PetController = {}

local function displayName(name: string): string
	return name:gsub("_", " ")
end

-- Tiny clearance above ground to prevent z-fighting / clipping into the floor
local PET_GROUND_CLEARANCE = 0.05
-- Smoothing speed (higher = snappier follow)
local PET_FOLLOW_SPEED     = 8

-- Local-space offsets per equip slot, relative to the player's HRP orientation.
-- X = right (+) / left (-), Z = behind (+) / forward (-)
-- Add more entries here when multi-equip is implemented.
local PET_SLOT_OFFSETS = {
    Vector3.new( 5, 0,  0),  -- slot 1: right
    Vector3.new(-5, 0,  0),  -- slot 2: left
    Vector3.new( 7, 0,  3),  -- slot 3: right-back
    Vector3.new(-7, 0,  3),  -- slot 4: left-back
    Vector3.new( 0, 0,  6),  -- slot 5: directly behind
}

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

-- Returns how many studs below the model's pivot its bounding-box bottom sits.
-- Used to place the pivot so the bottom of the model touches the ground.
local function getFootOffset(model: Model): number
	local boundCF, boundSize = model:GetBoundingBox()
	local pivotY  = model:GetPivot().Position.Y
	local bottomY = boundCF.Position.Y - boundSize.Y / 2
	return math.max(0, pivotY - bottomY)
end

-- Raycast straight down to find the ground Y at a given X,Z.
-- excludeList should contain the player's character (and the pet model if already spawned).
local function getGroundY(x: number, z: number, fromY: number, excludeList: {Instance}): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList

	local origin = Vector3.new(x, fromY + 15, z)
	local result = workspace:Raycast(origin, Vector3.new(0, -80, 0), params)
	return result and result.Position.Y or (fromY - 3)
end

-- Compute the world CFrame the pet should stand at beside the player.
-- slotIndex picks from PET_SLOT_OFFSETS; footOffset keeps the bottom on the ground.
local function getTargetCFrame(hrp: BasePart, slotIndex: number, footOffset: number, excludeList: {Instance}): CFrame
	local slotOffset  = PET_SLOT_OFFSETS[slotIndex] or PET_SLOT_OFFSETS[1]
	local worldOffset = hrp.CFrame:VectorToWorldSpace(slotOffset)

	local targetX = hrp.Position.X + worldOffset.X
	local targetZ = hrp.Position.Z + worldOffset.Z
	local groundY = getGroundY(targetX, targetZ, hrp.Position.Y, excludeList)
	local targetY = groundY + footOffset + PET_GROUND_CLEARANCE

	-- Face the same horizontal direction as the player
	local look = hrp.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then flatLook = Vector3.new(0, 0, -1) else flatLook = flatLook.Unit end

	local targetPos = Vector3.new(targetX, targetY, targetZ)
	return CFrame.lookAt(targetPos, targetPos + flatLook)
end

-- Map a brainrot's Rarity number to its rarity folder name
local function getRarityFolder(rarity: number): string
	if rarity <= 25   then return "Common"
	elseif rarity <= 100  then return "Uncommon"
	elseif rarity <= 1000 then return "Rare"
	elseif rarity <= 5000 then return "Legendary"
	else                       return "Mythic"
	end
end

-- Helper to find a model by name, trying both underscore and space versions
local function findModelInFolder(folder, modelName)
	-- Try exact name first
	local model = folder:FindFirstChild(modelName, true)
	if model then return model end

	-- Try with underscores replaced by spaces
	local altName = modelName:gsub("_", " ")
	if altName ~= modelName then
		model = folder:FindFirstChild(altName, true)
		if model then return model end
	end

	return nil
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

	local prefix  = getRarityFolder(brainrotData.Rarity)
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

local function spawnPet(player: Player, brainrotName: string, slotIndex: number?)
	local slot   = slotIndex or 1
	local userId = player.UserId
	removePet(userId)

	-- Validate the brainrot exists in config
	local brainrotData = BrainrotConfig.getBrainrotByName(brainrotName)
	if not brainrotData then
		warn("[PetController] Unknown brainrot requested: " .. tostring(brainrotName))
		return
	end

	-- Find the pet model template in ServerStorage/Brainrots/<RarityFolder>/
	local brainrotsFolder = ServerStorage:FindFirstChild("Brainrots")
	if not brainrotsFolder then
		warn("[PetController] ServerStorage/Brainrots folder not found")
		return
	end

	local rarityFolder = brainrotsFolder:FindFirstChild(getRarityFolder(brainrotData.Rarity))
	local modelTemplate = rarityFolder and findModelInFolder(rarityFolder, brainrotData.ModelName)

	-- Fallback: search all subfolders in case model is in a different rarity folder
	if not modelTemplate then
		modelTemplate = findModelInFolder(brainrotsFolder, brainrotData.ModelName)
	end

	if not modelTemplate then
		warn("[PetController] Model not found anywhere in Brainrots/ for: " .. brainrotData.ModelName)
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

	-- Calculate foot offset BEFORE parenting to workspace (pivot/bbox are already relative)
	local footOffset  = getFootOffset(petModel)
	local excludeList = { character }

	petModel.Parent = workspace

	if hrp then
		petModel:PivotTo(getTargetCFrame(hrp, slot, footOffset, excludeList))
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
		-- Tier name with stars for Rare and above
		local tierName
		local folder = getRarityFolder(brainrotData.Rarity)
		if folder == "Mythic"        then tierName = "MYTHIC"
		elseif folder == "Legendary" then tierName = "LEGENDARY"
		elseif folder == "Rare"      then tierName = "RARE"
		elseif folder == "Uncommon"  then tierName = "UNCOMMON"
		else                              tierName = "COMMON"
		end

		billboard             = Instance.new("BillboardGui")
		billboard.Name        = "BrainrotLabel"
		billboard.Size        = UDim2.new(0, 220, 0, 82)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = false
		billboard.Parent      = head

		-- Dark card background
		local bg = Instance.new("Frame")
		bg.Size                   = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3       = Color3.fromRGB(12, 12, 18)
		bg.BackgroundTransparency = 0.25
		bg.BorderSizePixel        = 0
		bg.Parent                 = billboard

		local bgCorner = Instance.new("UICorner")
		bgCorner.CornerRadius = UDim.new(0, 8)
		bgCorner.Parent = bg

		-- Header strip in rarity color
		local header = Instance.new("Frame")
		header.Size             = UDim2.new(1, 0, 0.34, 0)
		header.BackgroundColor3 = brainrotData.Color
		header.BackgroundTransparency = 0.2
		header.BorderSizePixel  = 0
		header.ZIndex           = 2
		header.Parent           = bg

		local headerCorner = Instance.new("UICorner")
		headerCorner.CornerRadius = UDim.new(0, 8)
		headerCorner.Parent = header

		-- Cover bottom corners of header so only top is rounded
		local headerFill = Instance.new("Frame")
		headerFill.Size             = UDim2.new(1, 0, 0.5, 0)
		headerFill.Position         = UDim2.new(0, 0, 0.5, 0)
		headerFill.BackgroundColor3 = brainrotData.Color
		headerFill.BackgroundTransparency = 0.2
		headerFill.BorderSizePixel  = 0
		headerFill.ZIndex           = 2
		headerFill.Parent           = header

		local tierLabel = Instance.new("TextLabel")
		tierLabel.Size                   = UDim2.new(1, 0, 1, 0)
		tierLabel.BackgroundTransparency = 1
		tierLabel.Text                   = tierName
		tierLabel.TextColor3             = Color3.new(1, 1, 1)
		tierLabel.TextScaled             = true
		tierLabel.Font                   = Enum.Font.GothamBold
		tierLabel.ZIndex                 = 3
		tierLabel.Parent                 = header

		local tierStroke     = Instance.new("UIStroke")
		tierStroke.Color     = Color3.fromRGB(0, 0, 0)
		tierStroke.Thickness = 1.5
		tierStroke.Parent    = tierLabel

		-- Brainrot name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size                   = UDim2.new(1, -10, 0.37, 0)
		nameLabel.Position               = UDim2.new(0, 5, 0.34, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.BorderSizePixel        = 0
		nameLabel.Text                   = displayName(brainrotData.Name)
		nameLabel.TextColor3             = Color3.new(1, 1, 1)
		nameLabel.TextScaled             = true
		nameLabel.Font                   = Enum.Font.GothamBold
		nameLabel.ZIndex                 = 2
		nameLabel.Parent                 = bg

		local nameStroke     = Instance.new("UIStroke")
		nameStroke.Color     = Color3.fromRGB(0, 0, 0)
		nameStroke.Thickness = 1.5
		nameStroke.Parent    = nameLabel

		-- "1 in X" rarity
		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size                   = UDim2.new(1, -10, 0.27, 0)
		rarityLabel.Position               = UDim2.new(0, 5, 0.71, 0)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.BorderSizePixel        = 0
		rarityLabel.Text                   = "1 in " .. brainrotData.Rarity
		rarityLabel.TextColor3             = brainrotData.Color
		rarityLabel.TextScaled             = true
		rarityLabel.Font                   = Enum.Font.Gotham
		rarityLabel.ZIndex                 = 2
		rarityLabel.Parent                 = bg

		local rarityStroke     = Instance.new("UIStroke")
		rarityStroke.Color     = Color3.fromRGB(0, 0, 0)
		rarityStroke.Thickness = 1.5
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

		local alpha  = 1 - math.exp(-PET_FOLLOW_SPEED * dt)
		local target = getTargetCFrame(hrp2, slot, footOffset, { char, petModel })
		petModel:PivotTo(petModel:GetPivot():Lerp(target, alpha))
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
