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
local FlySpeed = 28
local FlapSpeed = 12
local FlapAngle = math.rad(35)
local ZoneMargin = 6
local PopTime = 0.4
local PopStyle = Enum.EasingStyle.Back
local WhirlSpeed = math.rad(180)
local WanderSpeed = 15
local WanderRatio = 0.7
local IceGrowTime = 0.5
local IceGrowStyle = Enum.EasingStyle.Back
local IceHangTime = 1.5
local IceShakeTime = 0.8
local IceShakeAngle = math.rad(5)
local IceShakeSpeed = 40
local IceShakeRatio = 1.6
local IceGravity = 150
local IceBreakTime = 0.25
local IceBreakStyle = Enum.EasingStyle.Quad
local IceGoneTime = 1
local TurnSpeed = math.rad(45)
local BobHeight = 0.3
local BobSpeed = 2

export type Piece = {
	Part: BasePart,
	Motion: string,
	Hinge: CFrame,
	Axis: Vector3,
	Phase: number,
	Count: number?,
	Zone: CFrame?,
	Extent: Vector3?,
	Drop: number?,
	Length: number?,
	Local: CFrame,
	Size: Vector3,
	Scale: number,
}

type Plan = {
	Cycle: number,
	Height: number,
	Delay: number,
}

type Lane = {
	Offset: number,
	Pass: number,
	Spot: Vector3,
}

local Scenery = {}

local Plans: { [number]: Plan } = {}
local Lanes: { [number]: Lane } = {}

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
		Drop = Part:GetAttribute("Drop"),
		Length = Part:GetAttribute("Length"),
		Local =Hinge:ToObjectSpace(Part:GetAttribute("Rest")),
		Size = Part.Size,
		Scale = 1,
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

local function Track(Piece: Piece, Time: number): (Lane, number)
	local Extent = Piece.Extent :: Vector3
	local Lane = Lanes[Piece.Phase]
	if not Lane then
		Lane = { Offset = Random.new(Piece.Phase):NextNumber(), Pass = -1, Spot = Vector3.zero }
		Lanes[Piece.Phase] = Lane
	end
	local Travel = Time * FlySpeed / Extent.Z + Lane.Offset
	local Pass = Travel // 1
	if Lane.Pass ~= Pass then
		local Reach = (Extent / 2 - Vector3.one * ZoneMargin):Max(Vector3.zero)
		local Roll = Random.new(Pass * (Piece.Count :: number) + Piece.Phase)
		Lane.Pass = Pass
		Lane.Spot = Vector3.new(Roll:NextNumber(-Reach.X, Reach.X), Roll:NextNumber(-Reach.Y, Reach.Y), 0)
	end
	return Lane, Travel % 1
end

local function Grow(Piece: Piece, Progress: number): number
	local Edge = math.min(Progress, 1 - Progress) * (Piece.Extent :: Vector3).Z / FlySpeed
	return TweenService:GetValue(math.min(Edge / PopTime, 1), PopStyle, Enum.EasingDirection.Out)
end

local function Shrink(Local: CFrame, Center: Vector3, Scale: number): CFrame
	return Local.Rotation + Center + (Local.Position - Center) * Scale
end

local function Flight(Piece: Piece, Time: number, Body: CFrame, Altitude: number?): CFrame
	local Lane, Progress = Track(Piece, Time)
	local Extent = Piece.Extent :: Vector3
	local Center = (Piece.Zone :: CFrame) * CFrame.new(Lane.Spot + Vector3.zAxis * Extent.Z * (0.5 - Progress))
	if Altitude then
		Center += Vector3.yAxis * (Altitude - Center.Y)
	end
	return Center * Shrink(Body, Vector3.zero, Grow(Piece, Progress))
end

local function Plunge(Piece: Piece): (number, number)
	local Fall = math.sqrt(2 * (Piece.Drop :: number) / IceGravity)
	return Fall, IceGrowTime + IceHangTime + IceShakeTime + Fall + IceBreakTime + IceGoneTime
end

local function Beat(Piece: Piece, Time: number, Cycle: number): number
	return Time / Cycle + (Piece.Phase - 1) / (Piece.Count :: number)
end

local function Icicle(Piece: Piece, Time: number): (CFrame, Vector3, number)
	local Fall, Cycle = Plunge(Piece)
	local Clock = Beat(Piece, Time, Cycle) % 1 * Cycle
	if Clock < IceGrowTime then
		return CFrame.identity, Vector3.zero, TweenService:GetValue(Clock / IceGrowTime, IceGrowStyle, Enum.EasingDirection.Out)
	end
	Clock -= IceGrowTime + IceHangTime
	if Clock < 0 then
		return CFrame.identity, Vector3.zero, 1
	elseif Clock < IceShakeTime then
		local Angle = IceShakeAngle * Clock / IceShakeTime
		local Tilt = CFrame.Angles(
			Angle * math.sin(Clock * IceShakeSpeed),
			0,
			Angle * math.sin(Clock * IceShakeSpeed * IceShakeRatio)
		)
		return Tilt, Vector3.zero, 1
	end
	Clock -= IceShakeTime
	if Clock < Fall then
		return CFrame.new(0, -IceGravity * Clock * Clock / 2, 0), Vector3.zero, 1
	end
	Clock -= Fall
	local Break = TweenService:GetValue(math.min(Clock / IceBreakTime, 1), IceBreakStyle, Enum.EasingDirection.Out)
	return CFrame.new(0, -(Piece.Drop :: number), 0), Vector3.new(0, -(Piece.Length :: number), 0), 1 - Break
end

function Scenery.Strikes(Piece: Piece, Time: number): number
	local Fall, Cycle = Plunge(Piece)
	return (Beat(Piece, Time, Cycle) - (IceGrowTime + IceHangTime + IceShakeTime + Fall) / Cycle) // 1
end

function Scenery.Scale(Piece: Piece, Time: number): number
	if Piece.Motion == "Fall" then
		local _, _, Scale = Icicle(Piece, Time)
		return Scale
	elseif Piece.Motion ~= "Fly" and Piece.Motion ~= "Flap" then
		return 1
	end
	local _, Progress = Track(Piece, Time)
	return Grow(Piece, Progress)
end

local function Wander(Piece: Piece, Time: number): Vector3
	local Reach = Piece.Extent :: Vector3
	local X = Reach.X * math.sin(Time * WanderSpeed / math.max(Reach.X, 1) + Piece.Phase)
	local Z = Reach.Z * math.sin(Time * WanderSpeed * WanderRatio / math.max(Reach.Z, 1) + Piece.Phase * 2)
	return Vector3.new(X, 0, Z)
end

function Scenery.Pose(Piece: Piece, Time: number, Altitude: number?): CFrame
	if Piece.Motion == "Fly" then
		return Flight(Piece, Time, Piece.Hinge * Piece.Local, Altitude)
	elseif Piece.Motion == "Flap" then
		local Angle = FlapAngle * math.sin(Time * FlapSpeed + Piece.Phase)
		return Flight(Piece, Time, Piece.Hinge * CFrame.fromAxisAngle(Piece.Axis, Angle) * Piece.Local, Altitude)
	elseif Piece.Motion == "Rise" then
		return Piece.Hinge * Piece.Local + Piece.Axis * Rise(Time, Piece.Phase, Piece.Count :: number)
	elseif Piece.Motion == "Whirl" then
		local Angle = (Time * WhirlSpeed) % (2 * math.pi)
		return Piece.Hinge * CFrame.new(Wander(Piece, Time)) * CFrame.fromAxisAngle(Piece.Axis, Angle) * Piece.Local
	elseif Piece.Motion == "Fall" then
		local Frame, Center, Scale = Icicle(Piece, Time)
		return Piece.Hinge * Frame * Shrink(Piece.Local, Center, Scale)
	elseif Piece.Motion == "Turn" then
		local Angle = (Time * TurnSpeed) % (2 * math.pi)
		local Height = BobHeight * math.sin(Time * BobSpeed + 2 * math.pi * (Piece.Phase - 1) / (Piece.Count :: number))
		return Piece.Hinge * CFrame.new(0, Height, 0) * CFrame.fromAxisAngle(Piece.Axis, Angle) * Piece.Local
	end
	local Angle = if Piece.Motion == "Swing"
		then Swing(Time, Piece.Phase)
		else (Time * SpinSpeed + Piece.Phase) % (2 * math.pi)
	return Piece.Hinge * CFrame.fromAxisAngle(Piece.Axis, Angle) * Piece.Local
end

return Scenery
