-- Ensures only one panel (GUI frame) is visible at a time.
-- Any panel that calls UIManager.open() will automatically close the current one.
local UIManager = {}

local activeFrame = nil

function UIManager.open(frame)
	if activeFrame and activeFrame ~= frame then
		activeFrame.Visible = false
	end
	activeFrame = frame
	frame.Visible = true
end

function UIManager.close(frame)
	if activeFrame == frame then
		activeFrame = nil
	end
	frame.Visible = false
end

return UIManager
