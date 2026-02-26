-- Shared utility for rendering brainrot models inside ViewportFrames.
-- Used by both InventoryController (single model) and ShopController (3 models side-by-side).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewportUtil = {}

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function findModelInFolder(folder, modelName)
	local model = folder:FindFirstChild(modelName, true)
	if model then return model end
	local altName = modelName:gsub("_", " ")
	if altName ~= modelName then
		model = folder:FindFirstChild(altName, true)
		if model then return model end
	end
	return nil
end

local function centerModel(modelClone)
	local bboxCF, bboxSize = modelClone:GetBoundingBox()
	local bboxCenter = bboxCF.Position
	if modelClone.PrimaryPart then
		local pivotPos    = modelClone:GetPivot().Position
		local newPivotPos = pivotPos - bboxCenter
		modelClone:PivotTo(CFrame.new(newPivotPos))
	else
		local offset = -bboxCenter
		for _, part in ipairs(modelClone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CFrame = part.CFrame + offset
			end
		end
	end
	return bboxSize
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Renders a single model centered inside a ViewportFrame.
function ViewportUtil.loadModelIntoViewport(viewportFrame, modelName)
	for _, child in ipairs(viewportFrame:GetChildren()) do
		child:Destroy()
	end
	if not modelName then return end

	task.spawn(function()
		local brainrotsFolder = ReplicatedStorage:FindFirstChild("Brainrots")
		if not brainrotsFolder then return end

		local modelTemplate = findModelInFolder(brainrotsFolder, modelName)
		if not modelTemplate then return end

		local modelClone = modelTemplate:Clone()
		modelClone.Parent = viewportFrame

		local bboxSize   = centerModel(modelClone)
		local maxDim     = math.max(bboxSize.X, bboxSize.Y, bboxSize.Z)

		local camera = Instance.new("Camera")
		camera.Parent               = viewportFrame
		viewportFrame.CurrentCamera = camera

		local dist   = maxDim * 0.8
		local camPos = Vector3.new(0, dist * 0.35, -dist)
		local lookAt = Vector3.new(0, bboxSize.Y * 0.1, 0)
		camera.CFrame = CFrame.lookAt(camPos, lookAt)
	end)
end

-- Renders up to 3 models side-by-side inside one ViewportFrame.
-- modelNames: array of model name strings, e.g. { "Bombardiro Crocodilo", "Tung Tung Tung Sahur", "Ballerina Cappuccina" }
function ViewportUtil.loadPackIntoViewport(viewportFrame, modelNames)
	for _, child in ipairs(viewportFrame:GetChildren()) do
		child:Destroy()
	end
	if not modelNames or #modelNames == 0 then return end

	task.spawn(function()
		local brainrotsFolder = ReplicatedStorage:FindFirstChild("Brainrots")
		if not brainrotsFolder then return end

		local clones   = {}
		local sizes    = {}
		local GAP      = 0.0   -- world-unit gap between models

		-- Clone and center each model at origin first to get their sizes
		for _, name in ipairs(modelNames) do
			local template = findModelInFolder(brainrotsFolder, name)
			if template then
				local clone = template:Clone()
				clone.Parent = viewportFrame
				local bboxSize = centerModel(clone)
				table.insert(clones, clone)
				table.insert(sizes, bboxSize)
			end
		end

		if #clones == 0 then return end

		-- Calculate total width so we can center the group
		local totalWidth = 0
		for i, sz in ipairs(sizes) do
			totalWidth += sz.X
			if i < #sizes then totalWidth += GAP end
		end

		-- Lay out models left-to-right, group centered at X = 0
		local cursor = -totalWidth / 2
		local maxHeight = 0
		local maxDepth  = 0

		for i, clone in ipairs(clones) do
			local sz = sizes[i]
			local offsetX = cursor + sz.X / 2
			cursor += sz.X + GAP

			if clone.PrimaryPart then
				clone:PivotTo(CFrame.new(offsetX, 0, 0))
			else
				for _, part in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CFrame = part.CFrame + Vector3.new(offsetX, 0, 0)
					end
				end
			end

			if sz.Y > maxHeight then maxHeight = sz.Y end
			if sz.Z > maxDepth  then maxDepth  = sz.Z  end
		end

		-- Set up camera to frame all models
		-- Pull back far enough to show total width + some padding
		local camera = Instance.new("Camera")
		camera.FieldOfView          = 70
		camera.Parent               = viewportFrame
		viewportFrame.CurrentCamera = camera

		local fitWidth  = totalWidth * 0.25
		local fitHeight = maxHeight  * 0.22
		local dist      = math.max(fitWidth, fitHeight, maxDepth * 0.25)

		local camPos = Vector3.new(0, maxHeight * 0.2, -dist)
		local lookAt = Vector3.new(0, maxHeight * 0.05, 0)
		camera.CFrame = CFrame.lookAt(camPos, lookAt)
	end)
end

return ViewportUtil
