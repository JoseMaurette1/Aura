-- Client-side controller for the inventory UI
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SELECTED_THICKNESS = 3
local HOVER_COLOR  = Color3.fromRGB(60, 60, 60)
local NORMAL_COLOR = Color3.fromRGB(35, 35, 35)

local InventoryController = {}

local selectedFrame    = nil  -- currently selected inventory frame
local equippedBrainrot = nil  -- currently equipped brainrot data

-- SelectedAura panel references (assigned during init)
local auraPic    = nil
local auraName   = nil
local auraRarity = nil

-- Returns black for near-white colors (commons) so the stroke stays readable
local function strokeColor(color)
	local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return lum > 0.7 and Color3.new(0, 0, 0) or color
end

local function clearSelectedAuraPanel()
	if auraPic    then auraPic.Image   = ""  end
	if auraName   then auraName.Text   = ""  end
	if auraRarity then auraRarity.Text = ""  end
end

local function updateSelectedAuraPanel(frame)
	if not auraPic or not auraName or not auraRarity then return end

	local color    = frame:GetAttribute("Color") or Color3.new(1, 1, 1)
	local stroke   = strokeColor(color)

	auraPic.Image       = frame:GetAttribute("ImageId")      or ""
	auraName.Text       = frame:GetAttribute("BrainrotName") or ""
	auraRarity.Text     = "1 in " .. (frame:GetAttribute("Rarity") or 0)
	auraName.TextColor3   = Color3.new(1, 1, 1)
	auraRarity.TextColor3 = Color3.new(1, 1, 1)

	local nameStroke   = auraName:FindFirstChildWhichIsA("UIStroke")
	local rarityStroke = auraRarity:FindFirstChildWhichIsA("UIStroke")
	if nameStroke   then nameStroke.Color   = stroke end
	if rarityStroke then rarityStroke.Color = stroke end
end

local function applyBillboard(brainrot)
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local existing = hrp:FindFirstChild("AuraBillboard")
	if existing then existing:Destroy() end

	if not brainrot then return end

	local color  = brainrot.Color
	local stroke = strokeColor(color)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "AuraBillboard"
	billboard.Size = UDim2.new(0, 260, 0, 64)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = hrp

	-- Dark card background
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BackgroundTransparency = 0.35
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bg

	-- Rarity color accent bar on the left edge
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 4, 1, 0)
	accent.BackgroundColor3 = color
	accent.BorderSizePixel = 0
	accent.ZIndex = 2
	accent.Parent = bg

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 4)
	accentCorner.Parent = accent

	-- Brainrot name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -14, 0.56, 0)
	nameLabel.Position = UDim2.new(0, 10, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = brainrot.Name
	nameLabel.TextColor3 = color
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 3
	nameLabel.Parent = bg

	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = stroke
	nameStroke.Thickness = 1.5
	nameStroke.Parent = nameLabel

	-- Rarity line below the name
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, -14, 0.36, 0)
	rarityLabel.Position = UDim2.new(0, 10, 0.60, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = "1 in " .. brainrot.Rarity
	rarityLabel.TextColor3 = color
	rarityLabel.TextTransparency = 0.15
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.ZIndex = 3
	rarityLabel.Parent = bg

	local rarityStroke = Instance.new("UIStroke")
	rarityStroke.Color = stroke
	rarityStroke.Thickness = 1
	rarityStroke.Parent = rarityLabel
end

local function clearStroke(frame)
	local stroke = frame:FindFirstChildWhichIsA("UIStroke")
	if stroke then stroke:Destroy() end
end

local function applyStroke(frame, color)
	clearStroke(frame)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = SELECTED_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
end

local function selectFrame(frame)
	if selectedFrame and selectedFrame ~= frame then
		clearStroke(selectedFrame)
	end

	selectedFrame = frame
	if selectedFrame then
		local color = frame:GetAttribute("Color") or Color3.new(1, 1, 1)
		applyStroke(selectedFrame, color)
		updateSelectedAuraPanel(selectedFrame)
	end
end

local function registerItemFrame(frame)
	if not frame:IsA("Frame") then return end

	local btn = frame:FindFirstChildWhichIsA("ImageButton")
	if not btn then return end

	-- Hover highlight
	btn.MouseEnter:Connect(function()
		if selectedFrame ~= frame then
			TweenService:Create(frame, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
				BackgroundColor3 = HOVER_COLOR
			}):Play()
		end
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(frame, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
			BackgroundColor3 = NORMAL_COLOR
		}):Play()
	end)

	btn.MouseButton1Click:Connect(function()
		if selectedFrame == frame then
			clearStroke(frame)
			selectedFrame = nil
			clearSelectedAuraPanel()
		else
			selectFrame(frame)
		end
	end)
end

function InventoryController.addItem(brainrot)
	local screenGui = playerGui:WaitForChild("ScreenGui")
	local itemsScroll = screenGui
		:WaitForChild("InventoryGUI")
		:WaitForChild("InventoryArea")
		:WaitForChild("ItemsScroll")

	local frame = Instance.new("Frame")
	frame.Name = brainrot.Name
	frame.BackgroundColor3 = NORMAL_COLOR
	frame.BorderSizePixel = 0

	-- Store brainrot data as attributes so selectFrame can read them
	frame:SetAttribute("BrainrotName", brainrot.Name)
	frame:SetAttribute("Rarity",       brainrot.Rarity)
	frame:SetAttribute("ImageId",      brainrot.ImageId)
	frame:SetAttribute("Color",        brainrot.Color)

	-- ImageButton: main click target, shows brainrot image
	local imageButton = Instance.new("ImageButton")
	imageButton.Name = "ItemButton"
	imageButton.Size = UDim2.new(1, 0, 1, 0)
	imageButton.BackgroundTransparency = 1
	imageButton.Image = brainrot.ImageId
	imageButton.Parent = frame

	-- ImageLabel: rarity color tint bar at the bottom
	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = "RarityBar"
	imageLabel.Size = UDim2.new(1, 0, 0.08, 0)
	imageLabel.Position = UDim2.new(0, 0, 0.92, 0)
	imageLabel.BackgroundColor3 = brainrot.Color
	imageLabel.BackgroundTransparency = 0.3
	imageLabel.Image = ""
	imageLabel.ZIndex = 2
	imageLabel.Parent = frame

	-- Name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.Size = UDim2.new(1, 0, 0.25, 0)
	nameLabel.Position = UDim2.new(0, 0, 0.67, 0)
	nameLabel.BackgroundTransparency = 0.4
	nameLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.Text = brainrot.Name
	nameLabel.TextColor3 = brainrot.Color
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.ZIndex = 2
	nameLabel.Parent = frame

	frame.Parent = itemsScroll
end

function InventoryController.init()
	local screenGui = playerGui:WaitForChild("ScreenGui")
	local inventoryFrame = screenGui:WaitForChild("InventoryGUI")
	local openButton = screenGui:WaitForChild("AuraButton")

	inventoryFrame.Visible = false

	openButton.MouseButton1Click:Connect(function()
		inventoryFrame.Visible = true
	end)

	task.spawn(function()
		local header = inventoryFrame:WaitForChild("InventoryHeader")
		local exitButton = header:WaitForChild("ExitButton")
		exitButton.MouseButton1Click:Connect(function()
			inventoryFrame.Visible = false
			if selectedFrame then
				clearStroke(selectedFrame)
				selectedFrame = nil
				clearSelectedAuraPanel()
			end
		end)
	end)

	-- Wire up SelectedAura panel separately so it can't block item registration
	task.spawn(function()
		local selectedAura = inventoryFrame:WaitForChild("SelectedAura")
		local auraFrame    = selectedAura:WaitForChild("Frame")
		auraPic    = auraFrame:WaitForChild("BrainrotPic")
		auraName   = auraFrame:WaitForChild("SelectedName")
		auraRarity = auraFrame:WaitForChild("SelectedRarity")

		local deleteButton = selectedAura:WaitForChild("DeleteButton")
		deleteButton.MouseButton1Click:Connect(function()
			if not selectedFrame then return end

			-- If the deleted item was equipped, remove the billboard too
			local deleteName = selectedFrame:GetAttribute("BrainrotName")
			if equippedBrainrot and equippedBrainrot.Name == deleteName then
				equippedBrainrot = nil
				applyBillboard(nil)
			end

			local toDelete = selectedFrame
			selectedFrame = nil
			clearSelectedAuraPanel()
			toDelete:Destroy()
		end)

		local equipButton = selectedAura:WaitForChild("EquipButton")
		equipButton.MouseButton1Click:Connect(function()
			if not selectedFrame then return end

			local brainrot = {
				Name    = selectedFrame:GetAttribute("BrainrotName"),
				Rarity  = selectedFrame:GetAttribute("Rarity"),
				ImageId = selectedFrame:GetAttribute("ImageId"),
				Color   = selectedFrame:GetAttribute("Color"),
			}
			equippedBrainrot = brainrot
			applyBillboard(brainrot)
		end)

		-- Re-apply billboard on respawn
		player.CharacterAdded:Connect(function()
			if equippedBrainrot then
				task.wait()  -- one frame for HumanoidRootPart to load
				applyBillboard(equippedBrainrot)
			end
		end)
	end)

	-- Wire up ItemsScroll independently so SelectedAura delays never block it
	task.spawn(function()
		local itemsScroll = inventoryFrame
			:WaitForChild("InventoryArea")
			:WaitForChild("ItemsScroll")

		for _, child in ipairs(itemsScroll:GetChildren()) do
			registerItemFrame(child)
		end

		itemsScroll.ChildAdded:Connect(function(child)
			registerItemFrame(child)
		end)
	end)

	print("[Client] Inventory Controller initialized")
end

return InventoryController
