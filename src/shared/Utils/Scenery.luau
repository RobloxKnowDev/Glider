local TweenService = game:GetService("TweenService")

local SpinSpeed = math.rad(90)
local SwingAngle = math.rad(70)
local SwingSpeed = 1.5
local SwingStyle = Enum.EasingStyle.Cubic
local RiseCycle = 4
local RiseTime = 0.6
local HoldTime = 1.2
local FallTime = 1
local RiseMin = 15
local RiseMax = 50
local RiseChance = 0.35
local RiseStyle = Enum.EasingStyle.Quad
local FallStyle = Enum.EasingStyle.Sine
local FlySpeed = 20
local FlapSpeed = 12
local FlapAngle = math.rad(35)
local LoopPoints = 6
local LoopSamples = 12
local ZoneMargin = 6

export type Piece = {
	Part: BasePart,
	Motion: string,
	Hinge: CFrame,
	Axis: Vector3,
	Phase: number,
	Count: number?,
	Zone: CFrame?,
	Extent: Vector3?,
	Local: CFrame,
}

type Plan = {
	Cycle: number,
	Height: number,
	Delay: number,
}

type Loop = {
	Points: { Vector3 },
	Marks: { number },
	Length: number,
	Offset: number,
	Time: number,
	Root: CFrame,
}

local Scenery = {}

local Plans: { [number]: Plan } = {}
local Loops: { [number]: Loop } = {}

function Scenery.Read(Part: BasePart): Piece
	local Hinge: CFrame = Part:GetAttribute("Hinge")
	return {
		Part = Part,
		Motion = Part:GetAttribute("Motion"),
		Hinge = Hinge,
		Axis = Part:GetAttribute("Axis"),
		Phase = Part:GetAttribute("Phase"),
		Count = Part:GetAttribute("Count"),
		Zone = Part:GetAttribute("Zone"),
		Extent = Part:GetAttribute("Extent"),
		Local = Hinge:ToObjectSpace(Part:GetAttribute("Rest")),
	}
end

function Scenery.Mark(Part: BasePart, Motion: string, Hinge: CFrame, Axis: Vector3, Phase: number, Count: number?): Piece
	Part:SetAttribute("Motion", Motion)
	Part:SetAttribute("Hinge", Hinge)
	Part:SetAttribute("Axis", Axis)
	Part:SetAttribute("Phase", Phase)
	Part:SetAttribute("Count", Count)
	Part:SetAttribute("Rest", Part.CFrame)
	return Scenery.Read(Part)
end

local function Swing(Time: number, Phase: number): number
	local Cycle = ((Time * SwingSpeed + Phase) / math.pi) % 2
	local Progress = if Cycle < 1 then Cycle else 2 - Cycle
	return SwingAngle * (2 * TweenService:GetValue(Progress, SwingStyle, Enum.EasingDirection.InOut) - 1)
end

local function Draw(Index: number, Count: number, Cycle: number): Plan
	local Current = Plans[Index]
	if Current and Current.Cycle == Cycle then
		return Current
	end
	local Lead = Random.new(Cycle):NextInteger(1, Count)
	local Roll = Random.new(Cycle * Count + Index)
	local Raised = Roll:NextNumber() < RiseChance or Index == Lead
	Current = {
		Cycle = Cycle,
		Height = if Raised then Roll:NextNumber(RiseMin, RiseMax) else 0,
		Delay = Roll:NextNumber(0, RiseCycle - RiseTime - HoldTime - FallTime),
	}
	Plans[Index] = Current
	return Current
end

local function Rise(Time: number, Index: number, Count: number): number
	local Cycle = Time // RiseCycle
	local Plan = Draw(Index, Count, Cycle)
	local Elapsed = Time - Cycle * RiseCycle - Plan.Delay
	if Elapsed < 0 then
		return 0
	elseif Elapsed < RiseTime then
		return Plan.Height * TweenService:GetValue(Elapsed / RiseTime, RiseStyle, Enum.EasingDirection.Out)
	elseif Elapsed < RiseTime + HoldTime then
		return Plan.Height
	elseif Elapsed < RiseTime + HoldTime + FallTime then
		local Progress = (Elapsed - RiseTime - HoldTime) / FallTime
		return Plan.Height * (1 - TweenService:GetValue(Progress, FallStyle, Enum.EasingDirection.InOut))
	end
	return 0
end

local function Spline(Points: { Vector3 }, Segment: number, Progress: number): (Vector3, Vector3)
	local Count = #Points
	local A = Points[(Segment - 2) % Count + 1]
	local B = Points[Segment]
	local C = Points[Segment % Count + 1]
	local D = Points[(Segment + 1) % Count + 1]
	local Linear = C - A
	local Square = 2 * A - 5 * B + 4 * C - D
	local Cube = 3 * B - A - 3 * C + D
	local Position = 0.5 * (2 * B + Linear * Progress + Square * Progress ^ 2 + Cube * Progress ^ 3)
	local Tangent = 0.5 * (Linear + 2 * Square * Progress + 3 * Cube * Progress ^ 2)
	return Position, Tangent
end

local function Plot(Piece: Piece): Loop
	local Zone = Piece.Zone :: CFrame
	local Reach = ((Piece.Extent :: Vector3) / 2 - Vector3.one * ZoneMargin):Max(Vector3.zero)
	local Roll = Random.new(Piece.Phase)
	local Points: { Vector3 } = {}
	for _ = 1, LoopPoints do
		local Spot = Vector3.new(
			Roll:NextNumber(-Reach.X, Reach.X),
			Roll:NextNumber(-Reach.Y, Reach.Y),
			Roll:NextNumber(-Reach.Z, Reach.Z)
		)
		table.insert(Points, Zone:PointToWorldSpace(Spot))
	end
	local Marks = { 0 }
	local Last = Points[1]
	for Segment = 1, LoopPoints do
		for Step = 1, LoopSamples do
			local Point = Spline(Points, Segment, Step / LoopSamples)
			table.insert(Marks, Marks[#Marks] + (Point - Last).Magnitude)
			Last = Point
		end
	end
	local Length = Marks[#Marks]
	local Loop: Loop = {
		Points = Points,
		Marks = Marks,
		Length = Length,
		Offset = Roll:NextNumber(0, Length),
		Time = -1,
		Root = CFrame.identity,
	}
	Loops[Piece.Phase] = Loop
	return Loop
end

local function Flight(Piece: Piece, Time: number): CFrame
	local Loop = Loops[Piece.Phase] or Plot(Piece)
	if Loop.Time ~= Time then
		local Distance = (Time * FlySpeed + Loop.Offset) % Loop.Length
		local Marks = Loop.Marks
		local Low, High = 1, #Marks
		while High - Low > 1 do
			local Middle = (Low + High) // 2
			if Marks[Middle] <= Distance then
				Low = Middle
			else
				High = Middle
			end
		end
		local Step = Low - 1 + (Distance - Marks[Low]) / (Marks[High] - Marks[Low])
		local Position, Tangent = Spline(Loop.Points, Step // LoopSamples + 1, Step % LoopSamples / LoopSamples)
		Loop.Time = Time
		Loop.Root = CFrame.lookAt(Position, Position + Tangent)
	end
	return Loop.Root
end

function Scenery.Pose(Piece: Piece, Time: number): CFrame
	if Piece.Motion == "Fly" then
		return Flight(Piece, Time) * Piece.Hinge * Piece.Local
	elseif Piece.Motion == "Flap" then
		local Angle = FlapAngle * math.sin(Time * FlapSpeed + Piece.Phase)
		return Flight(Piece, Time) * Piece.Hinge * CFrame.fromAxisAngle(Piece.Axis, Angle) * Piece.Local
	elseif Piece.Motion == "Rise" then
		return Piece.Hinge * Piece.Local + Piece.Axis * Rise(Time, Piece.Phase, Piece.Count :: number)
	end
	local Angle = if Piece.Motion == "Swing"
		then Swing(Time, Piece.Phase)
		else (Time * SpinSpeed + Piece.Phase) % (2 * math.pi)
	return Piece.Hinge * CFrame.fromAxisAngle(Piece.Axis, Angle) * Piece.Local
end

return Scenery
