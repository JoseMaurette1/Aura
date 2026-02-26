-- Client-side controller for the inventory UI
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.BrainrotConfig)
local ViewportUtil   = require(ReplicatedStorage.Shared.ViewportUtil)
local UIManager      = require(script.Parent.UIManager)
local ButtonEffects  = require(script.Parent.ButtonEffects)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

-- Wait for remotes (all created by server on startup)
local EquipRemote         = RemoteEvents:WaitForChild("EquipRemote")
local DeleteItemRemote    = RemoteEvents:WaitForChild("DeleteItemRemote")
local LoadInventoryRemote = RemoteEvents:WaitForChild("LoadInventoryRemote")

local SELECTED_THICKNESS = 3
local HOVER_COLOR        = Color3.fromRGB(40, 40, 50)
local NORMAL_COLOR       = Color3.fromRGB(22, 22, 30)

local InventoryController = {}

local selectedFrame  = nil  -- currently selected inventory frame
local equippedFrame  = nil  -- frame in ItemsScroll that is currently equipped

-- SelectedAura panel references (assigned during init)
local auraPic        = nil
local auraName       = nil
local auraRarity     = nil
local auraRewards    = nil
local equipButton    = nil
local selectedViewport = nil  -- ViewportFrame inside SelectedAura for 3D preview

-- Delete mode state
local deleteModeButton  = nil    -- SelectedAura/DeleteButton, repurposed as mode toggle
local deleteModeActive  = false
local selectedForDelete = {}     -- { [frame] = true }
local itemsScrollRef    = nil    -- captured in init() for use by delete helpers

-- Sort / filter state
local currentSort = "All"        -- "All" | "ByRarity" | "ByName" | "RecentlyAdded"

local SORT_ACTIVE_COLOR   = Color3.fromRGB(55, 180, 100)   -- green — active button
local SORT_INACTIVE_COLOR = Color3.fromRGB(44, 128, 255)   -- blue  — inactive buttons

-- Reassigns LayoutOrder for all item frames based on currentSort.
-- Pass the scroll frame directly (from addItem) or fall back to itemsScrollRef.
local function reapplySort(scroll)
	scroll = scroll or itemsScrollRef
	if not scroll then return end

	local frames = {}
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end

	if currentSort == "ByRarity" then
		-- Rarest first (highest Rarity number = hardest to get)
		table.sort(frames, function(a, b)
			return (a:GetAttribute("Rarity") or 0) > (b:GetAttribute("Rarity") or 0)
		end)
	elseif currentSort == "ByName" then
		table.sort(frames, function(a, b)
			local nameA = (a:GetAttribute("BrainrotName") or ""):lower()
			local nameB = (b:GetAttribute("BrainrotName") or ""):lower()
			return nameA < nameB
		end)
	elseif currentSort == "RecentlyAdded" then
		-- Newest first (highest SlotId = most recently added)
		table.sort(frames, function(a, b)
			return (a:GetAttribute("SlotId") or 0) > (b:GetAttribute("SlotId") or 0)
		end)
	else
		-- "All" — original server order (lowest SlotId first)
		table.sort(frames, function(a, b)
			return (a:GetAttribute("SlotId") or 0) < (b:GetAttribute("SlotId") or 0)
		end)
	end

	for i, frame in ipairs(frames) do
		frame.LayoutOrder = i
	end
end

-- Strip underscores for display only; internal Name/ModelName stays unchanged
local function displayName(name: string): string
	return name:gsub("_", " ")
end

-- Returns black for near-white colors (commons) so strokes stay readable
local function strokeColor(color: Color3): Color3
	local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return lum > 0.7 and Color3.new(0, 0, 0) or color
end

-- Delegate viewport rendering to the shared utility
local function loadModelIntoViewport(viewportFrame, modelName)
	ViewportUtil.loadModelIntoViewport(viewportFrame, modelName)
end

-- Add a small "EQUIPPED" badge to the top of an inventory frame
local function applyEquippedBadge(frame: Frame)
	if frame:FindFirstChild("EquippedBadge") then return end
	local color = frame:GetAttribute("Color") or Color3.new(1, 1, 1)

	local badge = Instance.new("Frame")
	badge.Name               = "EquippedBadge"
	badge.Size               = UDim2.new(1, 0, 0.18, 0)
	badge.Position           = UDim2.new(0, 0, 0, 0)
	badge.BackgroundColor3   = Color3.new(0, 0, 0)
	badge.BackgroundTransparency = 0.25
	badge.BorderSizePixel    = 0
	badge.ZIndex             = 5
	badge.Parent             = frame

	local label = Instance.new("TextLabel")
	label.Size               = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text               = "EQUIPPED"
	label.TextColor3         = color
	label.TextScaled         = true
	label.Font               = Enum.Font.GothamBold
	label.ZIndex             = 6
	label.Parent             = badge
end

local function removeEquippedBadge(frame: Frame)
	local badge = frame:FindFirstChild("EquippedBadge")
	if badge then badge:Destroy() end
end

-- ── Delete mode helpers ───────────────────────────────────────────────────────

local function getDeleteCount()
	local count = 0
	for _ in pairs(selectedForDelete) do count += 1 end
	return count
end

-- Works for TextButton or ImageButton with a TextLabel child
local function setButtonText(btn, text)
	if btn:IsA("TextButton") then
		btn.Text = text
	else
		local label = btn:FindFirstChildWhichIsA("TextLabel")
		if label then label.Text = text end
	end
end

-- Updates DeleteButton label to reflect current delete mode state:
--   Not in mode  → "Delete Mode"
--   In mode, 0   → "Cancel"
--   In mode, N   → "Delete (N)"
local function updateDeleteButton()
	if not deleteModeButton then return end
	if not deleteModeActive then
		setButtonText(deleteModeButton, "Delete Mode")
	else
		local count = getDeleteCount()
		setButtonText(deleteModeButton, count > 0 and ("Delete (" .. count .. ")") or "Cancel")
	end
end

local function setCheckmark(frame: Frame, checked: boolean)
	local overlay = frame:FindFirstChild("DeleteCheckOverlay")
	if not overlay then return end
	local label = overlay:FindFirstChild("CheckLabel")
	if label then label.Text = checked and "✓" or "" end
	overlay.BackgroundColor3       = checked and Color3.fromRGB(200, 50, 70) or Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = checked and 0.2 or 0.6
end

local function addCheckboxOverlay(frame: Frame)
	if frame:FindFirstChild("DeleteCheckOverlay") then return end

	local overlay = Instance.new("Frame")
	overlay.Name                   = "DeleteCheckOverlay"
	overlay.Size                   = UDim2.new(0, 22, 0, 22)
	overlay.Position               = UDim2.new(1, -26, 0, 4)
	overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.6
	overlay.BorderSizePixel        = 0
	overlay.ZIndex                 = 10
	overlay.Parent                 = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = overlay

	local stroke = Instance.new("UIStroke")
	stroke.Color     = Color3.fromRGB(200, 200, 200)
	stroke.Thickness = 1.5
	stroke.Parent    = overlay

	local label = Instance.new("TextLabel")
	label.Name                   = "CheckLabel"
	label.Size                   = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text                   = ""
	label.TextColor3             = Color3.new(1, 1, 1)
	label.TextScaled             = true
	label.Font                   = Enum.Font.GothamBold
	label.ZIndex                 = 11
	label.Parent                 = overlay
end

local function removeCheckboxOverlay(frame: Frame)
	local overlay = frame:FindFirstChild("DeleteCheckOverlay")
	if overlay then overlay:Destroy() end
end

local function enterDeleteMode()
	deleteModeActive  = true
	selectedForDelete = {}
	if equipButton then
		equipButton.Active              = false
		equipButton.BackgroundColor3    = Color3.fromRGB(80, 80, 90)
		equipButton.AutoButtonColor     = false
	end
	if not itemsScrollRef then return end
	for _, child in ipairs(itemsScrollRef:GetChildren()) do
		if child:IsA("Frame") then
			addCheckboxOverlay(child)
		end
	end
	updateDeleteButton()
end

local function exitDeleteMode()
	deleteModeActive  = false
	selectedForDelete = {}
	if equipButton then
		equipButton.Active          = true
		equipButton.BackgroundColor3 = Color3.fromRGB(55, 180, 100)
		equipButton.AutoButtonColor  = true
	end
	if not itemsScrollRef then return end
	for _, child in ipairs(itemsScrollRef:GetChildren()) do
		if child:IsA("Frame") then
			removeCheckboxOverlay(child)
			child.BackgroundColor3 = NORMAL_COLOR
		end
	end
	updateDeleteButton()
end

local function executeBulkDelete()
	local toDelete = {}
	for frame in pairs(selectedForDelete) do
		table.insert(toDelete, frame)
	end

	for _, frame in ipairs(toDelete) do
		if frame == equippedFrame then
			EquipRemote:FireServer(nil)
			equippedFrame = nil
		end
		if frame == selectedFrame then
			selectedFrame = nil
			clearSelectedAuraPanel()
		end
		local slotId = frame:GetAttribute("SlotId")
		if slotId then
			DeleteItemRemote:FireServer(slotId)
		end
		frame:Destroy()
	end
end

local function showConfirmDeletePopup(count: number, onConfirm: () -> ())
	local screenGui = playerGui:WaitForChild("ScreenGui")

	local overlay = Instance.new("ImageButton")
	overlay.Name                   = "DeleteConfirmOverlay"
	overlay.Size                   = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3       = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Image                  = ""
	overlay.ZIndex                 = 50
	overlay.Parent                 = screenGui

	local dialog = Instance.new("Frame")
	dialog.Size              = UDim2.new(0, 300, 0, 160)
	dialog.Position          = UDim2.new(0.5, -150, 0.5, -80)
	dialog.BackgroundColor3  = Color3.fromRGB(20, 25, 35)
	dialog.BorderSizePixel   = 0
	dialog.ZIndex            = 51
	dialog.Parent            = overlay

	local dialogCorner = Instance.new("UICorner")
	dialogCorner.CornerRadius = UDim.new(0, 12)
	dialogCorner.Parent = dialog

	local dialogStroke = Instance.new("UIStroke")
	dialogStroke.Color     = Color3.fromRGB(60, 65, 80)
	dialogStroke.Thickness = 1.5
	dialogStroke.Parent    = dialog

	local title = Instance.new("TextLabel")
	title.Size                   = UDim2.new(1, -20, 0.35, 0)
	title.Position               = UDim2.new(0, 10, 0.05, 0)
	title.BackgroundTransparency = 1
	title.Text                   = "Delete " .. count .. " item" .. (count == 1 and "" or "s") .. "?"
	title.TextColor3             = Color3.new(1, 1, 1)
	title.TextScaled             = true
	title.Font                   = Enum.Font.GothamBold
	title.ZIndex                 = 52
	title.Parent                 = dialog

	local subtitle = Instance.new("TextLabel")
	subtitle.Size                   = UDim2.new(1, -20, 0.22, 0)
	subtitle.Position               = UDim2.new(0, 10, 0.38, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.Text                   = "This cannot be undone."
	subtitle.TextColor3             = Color3.fromRGB(150, 150, 160)
	subtitle.TextScaled             = true
	subtitle.Font                   = Enum.Font.Gotham
	subtitle.ZIndex                 = 52
	subtitle.Parent                 = dialog

	local function makeBtn(text, bgColor, xPos)
		local btn = Instance.new("TextButton")
		btn.Size             = UDim2.new(0.43, 0, 0.28, 0)
		btn.Position         = UDim2.new(xPos, 0, 0.65, 0)
		btn.BackgroundColor3 = bgColor
		btn.Text             = text
		btn.TextColor3       = Color3.new(1, 1, 1)
		btn.TextScaled       = true
		btn.Font             = Enum.Font.GothamBold
		btn.BorderSizePixel  = 0
		btn.ZIndex           = 52
		btn.Parent           = dialog
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = btn
		ButtonEffects.apply(btn)
		return btn
	end

	local confirmBtn = makeBtn("Delete",  Color3.fromRGB(200, 50, 70),  0.06)
	local cancelBtn  = makeBtn("Cancel",  Color3.fromRGB(70, 70, 80),   0.51)

	local function close()
		overlay:Destroy()
	end

	-- Clicking the dim overlay cancels
	overlay.MouseButton1Click:Connect(close)

	confirmBtn.MouseButton1Click:Connect(function()
		close()
		onConfirm()
	end)

	cancelBtn.MouseButton1Click:Connect(close)
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
	if selectedViewport then
		for _, child in ipairs(selectedViewport:GetChildren()) do
			child:Destroy()
		end
	end
	if auraName   then auraName.Text   = ""  end
	if auraRarity then auraRarity.Text = ""  end
	if auraRewards then auraRewards.Text = "" end
	updateEquipButton()
end

local function updateSelectedAuraPanel(frame: Frame)
	if not auraPic or not auraName or not auraRarity then return end

	local color  = frame:GetAttribute("Color") or Color3.new(1, 1, 1)
	local stroke = strokeColor(color)

	auraPic.Image         = ""  -- viewport handles display; keep Image blank
	auraName.Text         = displayName(frame:GetAttribute("BrainrotName") or "")
	auraRarity.Text       = "1 in " .. (frame:GetAttribute("Rarity") or 0)
	auraName.TextColor3   = Color3.new(1, 1, 1)
	auraRarity.TextColor3 = Color3.new(1, 1, 1)

	-- Get rolls reward from brainrot data
	if auraRewards then
		local brainrotName = frame:GetAttribute("BrainrotName")
		local brainrot = BrainrotConfig.getBrainrotByName(brainrotName)
		if brainrot then
			local rolls = BrainrotConfig.getRollsForBrainrot(brainrot)
			auraRewards.Text = "+" .. rolls
			auraRewards.TextColor3 = Color3.new(1, 1, 1)
		end
	end

	local nameStroke   = auraName:FindFirstChildWhichIsA("UIStroke")
	local rarityStroke = auraRarity:FindFirstChildWhichIsA("UIStroke")
	if nameStroke   then nameStroke.Color   = stroke end
	if rarityStroke then rarityStroke.Color = stroke end

	-- Render the 3D model in the SelectedAura viewport
	if selectedViewport then
		local brainrotName = frame:GetAttribute("BrainrotName")
		local brainrot = BrainrotConfig.getBrainrotByName(brainrotName)
		if brainrot then
			loadModelIntoViewport(selectedViewport, brainrot.ModelName)
		end
	end

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
		if not deleteModeActive and selectedFrame ~= frame then
			TweenService:Create(frame, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
				BackgroundColor3 = HOVER_COLOR
			}):Play()
		end
	end)

	btn.MouseLeave:Connect(function()
		if not deleteModeActive then
			TweenService:Create(frame, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
				BackgroundColor3 = NORMAL_COLOR
			}):Play()
		end
	end)

	btn.MouseButton1Click:Connect(function()
		if deleteModeActive then
			-- Toggle checkbox selection
			if selectedForDelete[frame] then
				selectedForDelete[frame] = nil
				setCheckmark(frame, false)
				TweenService:Create(frame, TweenInfo.new(0.1), { BackgroundColor3 = NORMAL_COLOR }):Play()
			else
				selectedForDelete[frame] = true
				setCheckmark(frame, true)
				TweenService:Create(frame, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(55, 18, 22) }):Play()
			end
			updateDeleteButton()
		else
			-- Normal single-select behavior
			if selectedFrame == frame then
				clearStroke(frame)
				selectedFrame = nil
				clearSelectedAuraPanel()
			else
				selectFrame(frame)
			end
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

	-- Outer card frame
	local frame = Instance.new("Frame")
	frame.Name              = brainrot.Name
	frame.BackgroundColor3  = NORMAL_COLOR
	frame.BorderSizePixel   = 0
	frame.ClipsDescendants  = true

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 10)
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
	frame.LayoutOrder = slotId or 0

	-- Thin rarity color bar on the left edge (full card height)
	local rarityBar = Instance.new("Frame")
	rarityBar.Name             = "RarityBar"
	rarityBar.Size             = UDim2.new(0, 4, 1, 0)
	rarityBar.Position         = UDim2.new(0, 0, 0, 0)
	rarityBar.BackgroundColor3 = brainrot.Color
	rarityBar.BorderSizePixel  = 0
	rarityBar.ZIndex           = 4
	rarityBar.Parent           = frame

	-- Image area background (darker to make 3D models pop)
	local imageArea = Instance.new("Frame")
	imageArea.Name             = "ImageArea"
	imageArea.Size             = UDim2.new(1, 0, 0.76, 0)
	imageArea.Position         = UDim2.new(0, 0, 0, 0)
	imageArea.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	imageArea.BorderSizePixel  = 0
	imageArea.ZIndex           = 1
	imageArea.Parent           = frame

	-- ViewportFrame displays the 3D brainrot model
	local viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.Name                   = "ItemViewport"
	viewportFrame.Size                   = UDim2.new(1, 0, 1, 0)
	viewportFrame.BackgroundTransparency = 1
	viewportFrame.ZIndex                 = 2
	viewportFrame.Parent                 = imageArea

	-- Load the 3D model asynchronously
	loadModelIntoViewport(viewportFrame, brainrot.ModelName)

	-- Thin rarity color accent line between image and name
	local accentLine = Instance.new("Frame")
	accentLine.Name             = "AccentLine"
	accentLine.Size             = UDim2.new(1, 0, 0.03, 0)
	accentLine.Position         = UDim2.new(0, 0, 0.76, 0)
	accentLine.BackgroundColor3 = brainrot.Color
	accentLine.BorderSizePixel  = 0
	accentLine.ZIndex           = 2
	accentLine.Parent           = frame

	-- Name label at the bottom (white text — rarity shown by left bar + stroke)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name                   = "ItemName"
	nameLabel.Size                   = UDim2.new(1, -12, 0.21, 0)
	nameLabel.Position               = UDim2.new(0, 8, 0.79, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.BorderSizePixel        = 0
	nameLabel.Text                   = displayName(brainrot.Name)
	nameLabel.TextColor3             = Color3.new(1, 1, 1)
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

	-- If delete mode is already active when this item is added, give it a checkbox
	if deleteModeActive then
		addCheckboxOverlay(frame)
	end

	-- Re-sort so the new item lands in the right position for the active filter
	reapplySort(itemsScroll)
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
		auraPic     = auraFrame:WaitForChild("BrainrotPic")
		auraName    = auraFrame:WaitForChild("SelectedName")
		auraRarity  = auraFrame:WaitForChild("SelectedRarity")
		auraRewards = auraFrame:WaitForChild("SelectedRewards")

		-- Create a persistent ViewportFrame inside BrainrotPic for 3D preview
		-- BrainrotPic acts as the container; Image is always blank
		auraPic.Image                  = ""
		auraPic.BackgroundTransparency = 1

		selectedViewport = Instance.new("ViewportFrame")
		selectedViewport.Name                   = "SelectedViewport"
		selectedViewport.Size                   = UDim2.new(1, 0, 1, 0)
		selectedViewport.BackgroundTransparency = 1
		selectedViewport.Parent                 = auraPic
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

	-- Wire up DeleteButton — repurposed as delete mode toggle
	task.spawn(function()
		local selectedAura = inventoryFrame:WaitForChild("SelectedAura")
		deleteModeButton   = selectedAura:WaitForChild("DeleteButton")
		ButtonEffects.apply(deleteModeButton)
		setButtonText(deleteModeButton, "Delete Mode")

		deleteModeButton.MouseButton1Click:Connect(function()
			if not deleteModeActive then
				-- Enter delete mode, clear any single-selection first
				if selectedFrame then
					clearStroke(selectedFrame)
					selectedFrame = nil
					clearSelectedAuraPanel()
				end
				enterDeleteMode()
			else
				local count = getDeleteCount()
				if count > 0 then
					-- Confirm and bulk delete
					showConfirmDeletePopup(count, function()
						executeBulkDelete()
						exitDeleteMode()
					end)
				else
					-- Nothing selected — just cancel
					exitDeleteMode()
				end
			end
		end)

		-- Exit delete mode cleanly when inventory closes
		inventoryFrame:GetPropertyChangedSignal("Visible"):Connect(function()
			if not inventoryFrame.Visible and deleteModeActive then
				exitDeleteMode()
			end
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

		itemsScrollRef = itemsScroll  -- expose to delete mode helpers

		for _, child in ipairs(itemsScroll:GetChildren()) do
			registerItemFrame(child)
		end

		itemsScroll.ChildAdded:Connect(function(child)
			registerItemFrame(child)
		end)
	end)

	-- Wire up sort / filter buttons at InventoryGUI/FilterGUI/
	task.spawn(function()
		local filterGUI = inventoryFrame:WaitForChild("FilterGUI")

		local function findChildCI(parent, name)
			local lower = name:lower()
			for _, child in ipairs(parent:GetChildren()) do
				if child.Name:lower() == lower then return child end
			end
			return nil
		end

		-- { buttonName, sortKey }
		local SORT_BUTTONS = {
			{ name = "All",            key = "All"           },
			{ name = "By Rarity",      key = "ByRarity"      },
			{ name = "By Name",        key = "ByName"        },
			{ name = "Recently Added", key = "RecentlyAdded" },
		}

		local buttonRefs = {}

		local function refreshSortColors()
			for _, entry in ipairs(buttonRefs) do
				entry.btn.ImageColor3 = (currentSort == entry.key) and SORT_ACTIVE_COLOR or SORT_INACTIVE_COLOR
			end
		end

		for _, entry in ipairs(SORT_BUTTONS) do
			local container = findChildCI(filterGUI, entry.name)
			local btn = container and container:FindFirstChildWhichIsA("ImageButton")
			if btn then
				table.insert(buttonRefs, { btn = btn, key = entry.key })
				ButtonEffects.apply(btn)

				btn.MouseButton1Click:Connect(function()
					currentSort = entry.key
					refreshSortColors()
					reapplySort()
				end)
			else
				warn("[InventoryController] Filter button not found at FilterGUI/" .. entry.name .. "/ImageButton")
			end
		end

		-- Set initial color state
		refreshSortColors()
	end)

	print("[Client] Inventory Controller initialized")
end

return InventoryController
