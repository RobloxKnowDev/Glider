local GliderFrame = require(script.Parent.GliderFrame)

local FieldOfView = 40
local Zoom = 1.35
local ViewDirection = (CFrame.Angles(0, math.rad(35), 0) * CFrame.Angles(math.rad(25), 0, 0)).LookVector
local LightLift = math.rad(20)
local LightColor = Color3.fromRGB(160, 160, 160)
local Ambient = Color3.fromRGB(170, 170, 170)

local function GliderShowcase(Viewport: ViewportFrame, Template: Model): (Model, CFrame)
	local Model = Template:Clone()
	local Bar = Model:WaitForChild("Bar") :: BasePart
	Model:PivotTo(GliderFrame(Bar):Inverse() * Bar.CFrame:ToObjectSpace(Model:GetPivot()))
	local Box, Size = Model:GetBoundingBox()
	Model:PivotTo(CFrame.new(-Box.Position) * Model:GetPivot())

	local Camera = Instance.new("Camera")
	Camera.FieldOfView = FieldOfView
	Camera.CFrame = CFrame.lookAt(ViewDirection * Size.Magnitude / 2 / math.sin(math.rad(FieldOfView / 2)) / Zoom, Vector3.zero)
	Camera.Parent = Viewport
	Viewport.CurrentCamera = Camera
	Viewport.LightDirection = Camera.CFrame:VectorToWorldSpace(Vector3.new(0, -math.sin(LightLift), -math.cos(LightLift)))
	Viewport.LightColor = LightColor
	Viewport.Ambient = Ambient
	Model.Parent = Viewport
	return Model, Model:GetPivot()
end

return GliderShowcase
