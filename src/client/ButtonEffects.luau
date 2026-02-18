-- Reusable hover and click animations for GuiButtons.
-- Uses UIScale so effects never conflict with a button's Size, Position, or Color.
local TweenService = game:GetService("TweenService")

local ButtonEffects = {}

local function getOrCreateUIScale(btn: GuiButton): UIScale
	local existing = btn:FindFirstChildWhichIsA("UIScale")
	if existing then return existing end
	local s = Instance.new("UIScale")
	s.Scale  = 1
	s.Parent = btn
	return s
end

local function applyInternal(btn: GuiButton, hoverScale: number, clickScale: number)
	local uiScale    = getOrCreateUIScale(btn)
	local isHovering = false

	btn.MouseEnter:Connect(function()
		isHovering = true
		TweenService:Create(uiScale,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = hoverScale }
		):Play()
	end)

	btn.MouseLeave:Connect(function()
		isHovering = false
		TweenService:Create(uiScale,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(uiScale,
			TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = clickScale }
		):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		-- Return to hover scale if still hovering, otherwise back to normal
		local target = isHovering and hoverScale or 1.0
		TweenService:Create(uiScale,
			TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = target }
		):Play()
	end)
end

-- Standard: nav buttons, action buttons (open shop, equip, delete, invite, etc.)
function ButtonEffects.apply(btn: GuiButton)
	applyInternal(btn, 1.06, 0.93)
end

-- Primary: high-impact buttons (RollButton, PrestigeButton) — more pronounced feel
function ButtonEffects.applyPrimary(btn: GuiButton)
	applyInternal(btn, 1.09, 0.91)
end

-- Subtle: exit buttons, small toggles — barely noticeable but adds polish
function ButtonEffects.applySubtle(btn: GuiButton)
	applyInternal(btn, 1.04, 0.96)
end

return ButtonEffects
