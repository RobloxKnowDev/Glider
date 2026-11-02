local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Confetti = {}

export type Style = {
	Count: number,
	Size: number,
	Speed: NumberRange,
}

type Piece = {
	Frame: Frame,
	Position: Vector2,
	Velocity: Vector2,
	Spin: number,
	Phase: number,
}

local DisplayOrder = 89
local Angle = NumberRange.new(55, 80)
local Spin = 360
local Flip = 8
local Gravity = 1.2
local Drag = 1.5
local Fall = 0.25
local Sway = 0.015
local Life = 3.5
local Fade = 0.6
local Colors = {
	Color3.fromRGB(255, 70, 90),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(110, 230, 90),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 255, 255),
}

local Layer: ScreenGui

local function Setup()
	if Layer then
		return
	end
	Layer = Instance.new("ScreenGui")
	Layer.Name = "ConfettiUi"
	Layer.ResetOnSpawn = false
	Layer.IgnoreGuiInset = true
	Layer.DisplayOrder = DisplayOrder
	Layer.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function Pick(Range: NumberRange): number
	return Range.Min + math.random() * (Range.Max - Range.Min)
end

function Confetti.Burst(Style: Style)
	Setup()
	local Screen = Workspace.CurrentCamera.ViewportSize
	local Height = Screen.Y
	local Size = Height * Style.Size
	local Pieces: { Piece } = {}
	for Index = 1, Style.Count do
		local Side = if Index % 2 == 0 then 1 else -1
		local Launch = math.rad(Pick(Angle))
		local Start = Vector2.new(if Side == 1 then 0 else Screen.X, Height)
		local Frame = Instance.new("Frame")
		Frame.AnchorPoint = Vector2.new(0.5, 0.5)
		Frame.Position = UDim2.fromOffset(Start.X, Start.Y)
		Frame.Size = UDim2.fromOffset(Size, Size / 2)
		Frame.BackgroundColor3 = Colors[math.random(#Colors)]
		Frame.BorderSizePixel = 0
		Frame.Rotation = math.random(0, 360)
		Frame.Parent = Layer
		table.insert(Pieces, {
			Frame = Frame,
			Position = Start,
			Velocity = Vector2.new(Side * math.cos(Launch), -math.sin(Launch)) * Pick(Style.Speed) * Height,
			Spin = (math.random() * 2 - 1) * Spin,
			Phase = math.random() * 2 * math.pi,
		})
	end

	local Started = os.clock()
	local Connection: RBXScriptConnection
	Connection = RunService.RenderStepped:Connect(function(Dt)
		local Elapsed = os.clock() - Started
		local Transparency = math.clamp((Elapsed - Life + Fade) / Fade, 0, 1)
		for _, Piece in ipairs(Pieces) do
			local Velocity = Piece.Velocity + Vector2.new(0, Gravity * Height * Dt)
			Piece.Velocity = Vector2.new(Velocity.X * math.exp(-Drag * Dt), math.min(Velocity.Y, Fall * Height))
			Piece.Position += Piece.Velocity * Dt
			local Wave = Elapsed * Flip + Piece.Phase
			Piece.Frame.Position = UDim2.fromOffset(Piece.Position.X + math.sin(Wave) * Sway * Height, Piece.Position.Y)
			Piece.Frame.Size = UDim2.fromOffset(Size * math.abs(math.cos(Wave)), Size / 2)
			Piece.Frame.Rotation += Piece.Spin * Dt
			Piece.Frame.BackgroundTransparency = Transparency
		end
		if Elapsed >= Life then
			Connection:Disconnect()
			for _, Piece in ipairs(Pieces) do
				Piece.Frame:Destroy()
			end
		end
	end)
end

return Confetti
