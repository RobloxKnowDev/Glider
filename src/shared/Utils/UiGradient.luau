local UiGradient = {}

function UiGradient.Ensure(Object: GuiObject): UIGradient
	local Existing = Object:FindFirstChildOfClass("UIGradient")
	if Existing then
		return Existing
	end
	local Gradient = Instance.new("UIGradient")
	Gradient.Rotation = 90
	Gradient.Parent = Object
	return Gradient
end

return UiGradient
