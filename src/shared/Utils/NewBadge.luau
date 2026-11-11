local Translation = require(script.Parent.Translation)

local Width = 0.34
local Ratio = 2.6
local Margin = 0.03
local CornerRotation = 12
local BelowRotation = 0
local BelowGap = 2
local TextColor = Color3.fromRGB(255, 230, 50)
local StrokeColor = Color3.fromRGB(130, 20, 0)
local StrokeThickness = 2

local Alignments = {
	[Enum.TextXAlignment.Left] = 0,
	[Enum.TextXAlignment.Center] = 0.5,
	[Enum.TextXAlignment.Right] = 1,
}

local NewBadge = {}

local function Create(Holder: GuiObject, Font: Font, ZIndex: number, Rotation: number): TextLabel
	local Badge = Instance.new("TextLabel")
	Badge.Name = "New"
	Badge.Size = UDim2.fromScale(Width, 1)
	Badge.Rotation = Rotation
	Badge.BackgroundTransparency = 1
	Badge.FontFace = Font
	Badge.TextColor3 = TextColor
	Badge.TextScaled = true
	Badge.ZIndex = ZIndex
	Translation.Set(Badge, "New!")

	local Aspect = Instance.new("UIAspectRatioConstraint")
	Aspect.AspectRatio = Ratio
	Aspect.DominantAxis = Enum.DominantAxis.Width
	Aspect.Parent = Badge

	local Stroke = Instance.new("UIStroke")
	Stroke.Color = StrokeColor
	Stroke.Thickness = StrokeThickness
	Stroke.Parent = Badge

	Badge.Parent = Holder
	return Badge
end

function NewBadge.Right(Holder: GuiObject, Font: Font, ZIndex: number): TextLabel
	local Badge = Create(Holder, Font, ZIndex, CornerRotation)
	Badge.AnchorPoint = Vector2.new(1, 0)
	Badge.Position = UDim2.fromScale(1 - Margin, Margin)
	return Badge
end

function NewBadge.Left(Holder: GuiObject, Font: Font, ZIndex: number): TextLabel
	local Badge = Create(Holder, Font, ZIndex, -CornerRotation)
	Badge.Position = UDim2.fromScale(Margin, Margin)
	return Badge
end

function NewBadge.Below(Holder: GuiObject, Label: TextLabel, Font: Font, ZIndex: number): TextLabel
	local Badge = Create(Holder, Font, ZIndex, BelowRotation)
	local Align = Alignments[Label.TextXAlignment]
	local Position, Size, Anchor = Label.Position, Label.Size, Label.AnchorPoint
	Badge.TextXAlignment = Label.TextXAlignment
	Badge.AnchorPoint = Vector2.new(Align, 0)
	Badge.Position = UDim2.new(
		Position.X.Scale + Size.X.Scale * (Align - Anchor.X),
		Position.X.Offset + Size.X.Offset * (Align - Anchor.X),
		Position.Y.Scale + Size.Y.Scale * (1 - Anchor.Y),
		Position.Y.Offset + Size.Y.Offset * (1 - Anchor.Y) + BelowGap
	)
	return Badge
end

return NewBadge
