-- Client-side controller for the inventory UI
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.BrainrotConfig)
local UIManager      = require(script.Parent.UIManager)
local ButtonEffects  = require(script.Parent.ButtonEffects)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

-- Wait for remotes (all created by server on startup)
local EquipRemote        = RemoteEvents:WaitForChild("EquipRemote")
local DeleteItemRemote   = RemoteEvents:WaitForChild("DeleteItemRemote")
local LoadInventoryRemote = RemoteEvents:WaitForChild("LoadInventoryRemote")

local SELECTED_THICKNESS = 3
local HOVER_COLOR        = Color3.fromRGB(60, 60, 60)
local NORMAL_COLOR       = Color3.fromRGB(35, 35, 35)

local InventoryController = {}

local selectedFrame  = nil  -- currently selected inventory frame
local equippedFrame  = nil  -- frame in ItemsScroll that is currently equipped

-- SelectedAura panel references (assigned during init)
local auraPic     = nil
local auraName    = nil
local auraRarity  = nil
local auraRewards = nil
local equipButton = nil

-- Strip underscores for display only; internal Name/ModelName stays unchanged
local function displayName(name: string): string
	return name:gsub("_", " ")
end

-- Returns black for near-white colors (commons) so strokes stay readable
local function strokeColor(color: Color3): Color3
	local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return lum > 0.7 and Color3.new(0, 0, 0) or color
end

-- Add a small "EQUIPPED" badge to the top of an inventory frame
local function applyEquippedBadge(frame: Frame)
	if frame:FindFirstChild("EquippedBadge") then return end
	local color = frame:GetAttribute("Color") or Color3.new(1, 1, 1)

	local badge = Instance.new("Frame")
	badge.Name               = "EquippedBadge"
	badge.Size               = UDim2.new(1, 0, 0.2, 0)
	badge.Position           = UDim2.new(0, 0, 0, 0)
	badge.BackgroundColor3   = Color3.new(0, 0, 0)
	badge.BackgroundTransparency = 0.3
	badge.BorderSizePixel    = 0
	badge.ZIndex             = 3
	badge.Parent             = frame

	local label = Instance.new("TextLabel")
	label.Size               = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text               = "EQUIPPED"
	label.TextColor3         = color
	label.TextScaled         = true
	label.Font               = Enum.Font.GothamBold
	label.ZIndex             = 4
	label.Parent             = badge
end

local function removeEquippedBadge(frame: Frame)
	local badge = frame:FindFirstChild("EquippedBadge")
	if badge then badge:Destroy() end
end

local function updateEquipButton()
	if not equipButton then return end
	if not equipButton:IsA("GuiButton") then return end
	if not selectedFrame then
		equipButton.Text = "Equip"
		return
	end
	equipButton.Text = (selectedFrame == equippedFrame) and "Unequip" or "Equip"
end

local function clearSelectedAuraPanel()
	if auraPic    then auraPic.Image   = ""  end
	if auraName   then auraName.Text   = ""  end
	if auraRarity then auraRarity.Text = ""  end
	if auraRewards then auraRewards.Text = ""  end
	updateEquipButton()
end

local function updateSelectedAuraPanel(frame: Frame)
	if not auraPic or not auraName or not auraRarity then return end

	local color  = frame:GetAttribute("Color") or Color3.new(1, 1, 1)
	local stroke = strokeColor(color)

	auraPic.Image       = frame:GetAttribute("ImageId") or ""
	auraName.Text       = displayName(frame:GetAttribute("BrainrotName") or "")
	auraRarity.Text     = "1 in " .. (frame:GetAttribute("Rarity") or 0)
	auraName.TextColor3   = Color3.new(1, 1, 1)
	auraRarity.TextColor3 = Color3.new(1, 1, 1)

	-- Get money reward from brainrot data
	if auraRewards then
		local brainrotName = frame:GetAttribute("BrainrotName")
		local brainrot = BrainrotConfig.getBrainrotByName(brainrotName)
		if brainrot then
			local money = BrainrotConfig.getMoneyForBrainrot(brainrot)
			auraRewards.Text = "+" .. money
			auraRewards.TextColor3 = Color3.new(1, 1, 1)
		end
	end

	local nameStroke   = auraName:FindFirstChildWhichIsA("UIStroke")
	local rarityStroke = auraRarity:FindFirstChildWhichIsA("UIStroke")
	if nameStroke   then nameStroke.Color   = stroke end
	if rarityStroke then rarityStroke.Color = stroke end

	updateEquipButton()
end

local function clearStroke(frame: Frame)
	local stroke = frame:FindFirstChildWhichIsA("UIStroke")
	if stroke then stroke:Destroy() end
end

local function applyStroke(frame: Frame, color: Color3)
	clearStroke(frame)
	local stroke = Instance.new("UIStroke")
	stroke.Color           = color
	stroke.Thickness       = SELECTED_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent          = frame
end

local function selectFrame(frame: Frame)
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

local function registerItemFrame(frame: Frame)
	if not frame:IsA("Frame") then return end

	local btn = frame:FindFirstChildWhichIsA("ImageButton")
	if not btn then return end

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

-- slotId is the server-assigned slot number, used to tell the server which item to delete
function InventoryController.addItem(brainrot, slotId)
	local screenGui = playerGui:WaitForChild("ScreenGui")
	local itemsScroll = screenGui
		:WaitForChild("InventoryGUI")
		:WaitForChild("InventoryArea")
		:WaitForChild("ItemsScroll")

	local frame = Instance.new("Frame")
	frame.Name              = brainrot.Name
	frame.BackgroundColor3  = Color3.fromRGB(28, 28, 33)
	frame.BorderSizePixel   = 0
	frame.ClipsDescendants  = true

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 8)
	frameCorner.Parent = frame

	-- Store raw name (with underscores) as attribute — used for model lookup
	frame:SetAttribute("BrainrotName", brainrot.Name)
	frame:SetAttribute("Rarity",       brainrot.Rarity)
	frame:SetAttribute("ImageId",      brainrot.ImageId)
	frame:SetAttribute("Color",        brainrot.Color)
	-- SlotId links this frame to the server's saved inventory entry
	if slotId then
		frame:SetAttribute("SlotId", slotId)
	end

	-- Image area background (visible as a placeholder when no image is set)
	local imageArea = Instance.new("Frame")
	imageArea.Name             = "ImageArea"
	imageArea.Size             = UDim2.new(1, 0, 0.66, 0)
	imageArea.Position         = UDim2.new(0, 0, 0, 0)
	imageArea.BackgroundColor3 = Color3.fromRGB(48, 48, 56)
	imageArea.BorderSizePixel  = 0
	imageArea.ZIndex           = 1
	imageArea.Parent           = frame

	-- Actual image displayed inside the image area
	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name                   = "ItemImage"
	imageLabel.Size                   = UDim2.new(1, 0, 1, 0)
	imageLabel.BackgroundTransparency = 1
	imageLabel.Image                  = brainrot.ImageId
	imageLabel.ScaleType              = Enum.ScaleType.Fit
	imageLabel.ZIndex                 = 2
	imageLabel.Parent                 = imageArea

	-- Thin rarity color accent line separating image from name
	local accentLine = Instance.new("Frame")
	accentLine.Name             = "AccentLine"
	accentLine.Size             = UDim2.new(1, 0, 0.04, 0)
	accentLine.Position         = UDim2.new(0, 0, 0.66, 0)
	accentLine.BackgroundColor3 = brainrot.Color
	accentLine.BorderSizePixel  = 0
	accentLine.ZIndex           = 2
	accentLine.Parent           = frame

	-- Name label at the bottom
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name                   = "ItemName"
	nameLabel.Size                   = UDim2.new(1, -8, 0.30, 0)
	nameLabel.Position               = UDim2.new(0, 4, 0.70, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.BorderSizePixel        = 0
	nameLabel.Text                   = displayName(brainrot.Name)
	nameLabel.TextColor3             = brainrot.Color
	nameLabel.TextScaled             = true
	nameLabel.Font                   = Enum.Font.GothamBold
	nameLabel.ZIndex                 = 2
	nameLabel.Parent                 = frame

	-- Full-size invisible button on top — sole click target for the whole frame
	local imageButton = Instance.new("ImageButton")
	imageButton.Name                   = "ItemButton"
	imageButton.Size                   = UDim2.new(1, 0, 1, 0)
	imageButton.BackgroundTransparency = 1
	imageButton.Image                  = ""
	imageButton.ZIndex                 = 3
	imageButton.Parent                 = frame

	frame.Parent = itemsScroll
end

function InventoryController.init()
	local screenGui      = playerGui:WaitForChild("ScreenGui")
	local inventoryFrame = screenGui:WaitForChild("InventoryGUI")
	local openButton     = screenGui:WaitForChild("AuraButton")

	inventoryFrame.Visible = false

	-- Clear selection whenever the inventory is hidden (exit button or UIManager switching panels)
	inventoryFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not inventoryFrame.Visible and selectedFrame then
			clearStroke(selectedFrame)
			selectedFrame = nil
			clearSelectedAuraPanel()
		end
	end)

	ButtonEffects.apply(openButton)
	openButton.MouseButton1Click:Connect(function()
		UIManager.open(inventoryFrame)
	end)

	task.spawn(function()
		local header     = inventoryFrame:WaitForChild("InventoryHeader")
		local exitButton = header:WaitForChild("ExitButton")
		ButtonEffects.applySubtle(exitButton)
		exitButton.MouseButton1Click:Connect(function()
			UIManager.close(inventoryFrame)
		end)
	end)

	-- Wire up SelectedAura display (BrainrotPic, SelectedName, SelectedRarity, SelectedRewards)
	task.spawn(function()
		local selectedAura = inventoryFrame:WaitForChild("SelectedAura")
		local auraFrame    = selectedAura:WaitForChild("Frame")
		auraPic    = auraFrame:WaitForChild("BrainrotPic")
		auraName   = auraFrame:WaitForChild("SelectedName")
		auraRarity = auraFrame:WaitForChild("SelectedRarity")
		auraRewards = auraFrame:WaitForChild("SelectedRewards")
	end)

	-- Wire up EquipButton independently so it never blocks DeleteButton
	task.spawn(function()
		local selectedAura = inventoryFrame:WaitForChild("SelectedAura")
		equipButton = selectedAura:WaitForChild("EquipButton")
		ButtonEffects.apply(equipButton)
		equipButton.MouseButton1Click:Connect(function()
			if not selectedFrame then return end

			if selectedFrame == equippedFrame then
				-- Unequip
				removeEquippedBadge(equippedFrame)
				equippedFrame = nil
				EquipRemote:FireServer(nil)
			else
				-- Swap: remove badge from old, add to new
				if equippedFrame and equippedFrame.Parent then
					removeEquippedBadge(equippedFrame)
				end
				equippedFrame = selectedFrame
				applyEquippedBadge(equippedFrame)
				EquipRemote:FireServer(selectedFrame:GetAttribute("BrainrotName"))
			end
			updateEquipButton()
		end)
	end)

	-- Wire up DeleteButton independently
	task.spawn(function()
		local selectedAura = inventoryFrame:WaitForChild("SelectedAura")
		local deleteButton = selectedAura:WaitForChild("DeleteButton")
		ButtonEffects.apply(deleteButton)
		deleteButton.MouseButton1Click:Connect(function()
			if not selectedFrame then return end

			local toDelete = selectedFrame
			selectedFrame  = nil

			-- If deleting the equipped item, unequip on server too
			if toDelete == equippedFrame then
				EquipRemote:FireServer(nil)
				equippedFrame = nil
			end

			-- Tell server to remove from saved data
			local slotId = toDelete:GetAttribute("SlotId")
			if slotId then
				DeleteItemRemote:FireServer(slotId)
			end

			-- Destroy first so any error in clearSelectedAuraPanel can't block it
			toDelete:Destroy()
			clearSelectedAuraPanel()
		end)
	end)

	-- Listen for saved inventory on join (server fires this after DataStore loads)
	task.spawn(function()
		LoadInventoryRemote.OnClientEvent:Connect(function(loadList)
			for _, item in ipairs(loadList) do
				local brainrot = BrainrotConfig.getBrainrotByName(item.name)
				if brainrot then
					InventoryController.addItem(brainrot, item.slotId)
				else
					warn("[InventoryController] Unknown brainrot in saved data: " .. tostring(item.name))
				end
			end
			print("[Client] Restored " .. #loadList .. " saved items")
		end)
	end)

	-- Wire up ItemsScroll independently
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
