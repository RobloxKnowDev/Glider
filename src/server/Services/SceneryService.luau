local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Propeller = require(ReplicatedStorage.Shared.Utils.Propeller)
local Scenery = require(ReplicatedStorage.Shared.Utils.Scenery)

local SceneryService = {
	Name = "SceneryService",
	Priority = 12,
}

local PhaseSpread = 0.05
local BirdsPerZone = 4
local FallReach = 2000
local Flat = Vector3.new(1, 0, 1)
local DebrisPerZone = 20
local DebrisMin = 2
local DebrisMax = 10
local DebrisRatio = 0.3
local DebrisColor = Color3.fromRGB(81, 83, 91)
local DebrisMaterial = Enum.Material.Slate
local HurlRatio = 0.25
local HurlHop = 15
local HurlTries = 6
local HurlShare = 0.8
local MarkLift = 200
local SinkDepth = 200
local TraceStep = 0.05
local Faces = { "TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface" }

type Barrage = {
	Motion: string,
	Amount: number,
	Bulk: NumberRange,
	Color: Color3,
	Fan: number,
	Reach: NumberRange,
	Loft: NumberRange,
}

local Rockfall: Barrage = {
	Motion = "Slide",
	Amount = 40,
	Bulk = NumberRange.new(7, 13),
	Color = Color3.fromRGB(58, 59, 64),
	Fan = math.rad(70),
	Reach = NumberRange.new(150, 150),
	Loft = NumberRange.new(0.08, 0.2),
}
local Eruption: Barrage = {
	Motion = "Erupt",
	Amount = 45,
	Bulk = NumberRange.new(12, 22),
	Color = Color3.fromRGB(255, 94, 0),
	Fan = math.pi,
	Reach = NumberRange.new(0, 100),
	Loft = NumberRange.new(0.35, 0.6),
}

local function Ground(Folder: Instance): RaycastParams
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {
		Folder,
		Workspace:WaitForChild("RingsFolder"),
		Workspace:WaitForChild("Windzones"),
		Workspace:WaitForChild("WindTurbineZones"),
		Workspace:WaitForChild("InvisibleWalls"),
		Workspace:WaitForChild("SpawnDebriesZone"),
		Workspace:WaitForChild("RocksFallingZones"),
	}
	Params.RespectCanCollide = true
	return Params
end

local function Within(Zone: BasePart, Point: Vector3): boolean
	local Local = Zone.CFrame:PointToObjectSpace(Point)
	return math.abs(Local.X) <= Zone.Size.X / 2
		and math.abs(Local.Y) <= Zone.Size.Y / 2
		and math.abs(Local.Z) <= Zone.Size.Z / 2
end

local function Scatter(Roll: Random, Reach: Vector3): Vector3
	return Vector3.new(
		Roll:NextNumber(-Reach.X, Reach.X),
		Roll:NextNumber(-Reach.Y, Reach.Y),
		Roll:NextNumber(-Reach.Z, Reach.Z)
	)
end

local function Course(Point: Vector3): (Vector3, number)
	local Closest, Low, Nearest = Vector3.zero, 0, math.huge
	for _, Stage in ipairs(Workspace:WaitForChild("Level"):GetChildren()) do
		local Spawn = (Stage:WaitForChild("SpawnPart") :: BasePart).Position
		local Finish = (Stage:WaitForChild("Finish") :: BasePart).Position
		local Path = (Finish - Spawn) * Flat
		local Along = math.clamp(((Point - Spawn) * Flat):Dot(Path) / Path:Dot(Path), 0, 1)
		local Spot = Spawn:Lerp(Finish, Along)
		local Gap = ((Spot - Point) * Flat).Magnitude
		if Gap < Nearest then
			Closest, Low, Nearest = Spot, math.min(Spawn.Y, Finish.Y), Gap
		end
	end
	return Closest, Low
end

local function Hide(Zone: BasePart)
	Zone.Transparency = 1
	Zone.CanCollide = false
	Zone.CanQuery = false
	Zone.CanTouch = false
end

local function Span(Box: CFrame, Size: Vector3, Direction: Vector3): number
	return math.abs(Direction:Dot(Box.RightVector)) * Size.X
		+ math.abs(Direction:Dot(Box.UpVector)) * Size.Y
		+ math.abs(Direction:Dot(Box.LookVector)) * Size.Z
end

local function Shoulder(Wing: Model, Out: Vector3): CFrame
	local Box, Size = Wing:GetBoundingBox()
	return CFrame.new(Box.Position - Out * Span(Box, Size, Out) / 2)
end

function SceneryService:Flap(Wing: Model, Out: Vector3, Index: number, Count: number)
	local Hinge = Shoulder(Wing, Out)
	local Axis = Out:Cross(Vector3.yAxis)
	for _, Part in ipairs(Wing:GetDescendants()) do
		if Part:IsA("BasePart") then
			Scenery.Mark(Part, "Flap", Hinge, Axis, Index, Count)
		end
	end
end

function SceneryService:Hatch(Model: Model, Zone: BasePart, Index: number, Count: number, Folder: Instance)
	local Bird = Model:Clone()
	local Ail1 = Bird:WaitForChild("Ail1") :: Model
	local Ail2 = Bird:WaitForChild("Ail2") :: Model
	local Span = ((Ail2:GetBoundingBox().Position - Ail1:GetBoundingBox().Position) * Flat).Unit
	local Body = CFrame.fromMatrix(Bird:GetBoundingBox().Position, Span, Vector3.yAxis)
	Bird:PivotTo(Body:Inverse() * Bird:GetPivot())
	for _, Child in ipairs(Bird:GetDescendants()) do
		if Child:IsA("JointInstance") or Child:IsA("WeldConstraint") then
			Child:Destroy()
		elseif Child:IsA("BasePart") then
			Child.Anchored = true
			Child.CanCollide = false
			Child:SetAttribute("Zone", Zone.CFrame)
			Child:SetAttribute("Extent", Zone.Size)
		end
	end

	self:Flap(Ail1, -Vector3.xAxis, Index, Count)
	self:Flap(Ail2, Vector3.xAxis, Index, Count)
	for _, Part in ipairs(Bird:GetDescendants()) do
		if Part:IsA("BasePart") and not Part:IsDescendantOf(Ail1) and not Part:IsDescendantOf(Ail2) then
			Scenery.Mark(Part, "Fly", CFrame.identity, Vector3.zero, Index, Count)
		end
	end

	Bird.Name = "Bird"
	Bird.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	Bird:PivotTo(Zone.CFrame * Bird:GetPivot())
	Bird.Parent = Folder
end

function SceneryService:Flock(Folder: Instance)
	local Model = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Level"):WaitForChild("BirdModel") :: Model
	local Zones = Folder:GetChildren()
	local Index = 0
	for _, Child in ipairs(Zones) do
		local Zone = Child :: BasePart
		Hide(Zone)
		for _ = 1, BirdsPerZone do
			Index += 1
			self:Hatch(Model, Zone, Index, #Zones * BirdsPerZone, Folder)
		end
	end
end

function SceneryService:Whirl(Folder: Instance)
	local Model = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Level"):WaitForChild("Tornado") :: Model
	for Index, Child in ipairs(Folder:GetChildren()) do
		local Zone = Child :: BasePart
		Hide(Zone)

		local Tornado = Model:Clone()
		Tornado:PivotTo(CFrame.identity)
		local Box, Size = Tornado:GetBoundingBox()
		local Radius = math.max(Size.X, Size.Z) / 2
		local Reach = Vector3.new(Zone.Size.X / 2 - Radius, 0, Zone.Size.Z / 2 - Radius):Max(Vector3.zero)
		local Base = Zone.CFrame * CFrame.new(0, -Zone.Size.Y / 2, 0)
		Tornado:PivotTo(Base * CFrame.new(Vector3.yAxis * Size.Y / 2 - Box.Position))
		for _, Part in ipairs(Tornado:GetDescendants()) do
			if Part:IsA("JointInstance") or Part:IsA("WeldConstraint") then
				Part:Destroy()
			elseif Part:IsA("BasePart") then
				Part.Anchored = true
				Part.CanCollide = false
				Part.CanQuery = true
				Part:SetAttribute("Extent", Reach)
				Scenery.Mark(Part, "Whirl", Base, Vector3.yAxis, Index)
			end
		end

		Tornado.Name = "Tornado"
		Tornado.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		Tornado.Parent = Folder
	end
end

function SceneryService:Spin(Turbine: Model)
	local Rotor = Turbine:WaitForChild("RotatingPart") :: BasePart
	local Size = Rotor.Size
	local Hinge = Rotor.CFrame.Rotation + Rotor:GetPivot().Position
	local Axis = if Size.X <= Size.Y and Size.X <= Size.Z
		then Vector3.xAxis
		elseif Size.Y <= Size.Z then Vector3.yAxis
		else Vector3.zAxis
	table.insert(self.pieces, Scenery.Mark(Rotor, "Spin", Hinge, Axis, (Hinge.X + Hinge.Z) * PhaseSpread))
end

function SceneryService:Swing(Log: Model)
	local Hinge = (Log:WaitForChild("Pivot") :: BasePart).CFrame
	for _, Part in ipairs(Log:GetDescendants()) do
		if Part:IsA("BasePart") then
			table.insert(self.pieces, Scenery.Mark(Part, "Swing", Hinge, Vector3.zAxis, 0))
		end
	end
end

function SceneryService:Rise(Folder: Instance)
	local Spikes = Folder:GetChildren()
	for Index, Spike in ipairs(Spikes) do
		local Hinge = (Spike :: Model):GetPivot()
		for _, Part in ipairs(Spike:GetDescendants()) do
			if Part:IsA("BasePart") then
				table.insert(self.pieces, Scenery.Mark(Part, "Rise", Hinge, Vector3.yAxis, Index, #Spikes))
			end
		end
	end
end

function SceneryService:Drop(Folder: Instance)
	local Floor = Ground(Folder)
	local Icicles = Folder:GetChildren()
	for Index, Child in ipairs(Icicles) do
		local Box, Size = (Child :: Model):GetBoundingBox()
		local Length = Span(Box, Size, Vector3.yAxis)
		local Top = Box.Position + Vector3.yAxis * Length / 2
		local Tip = Top - Vector3.yAxis * Length
		local Hit = Workspace:Raycast(Tip, -Vector3.yAxis * FallReach, Floor) :: RaycastResult
		for _, Part in ipairs(Child:GetDescendants()) do
			if Part:IsA("JointInstance") or Part:IsA("WeldConstraint") then
				Part:Destroy()
			elseif Part:IsA("BasePart") then
				Part.Anchored = true
				Part.CanCollide = true
				Part:SetAttribute("Drop", Tip.Y - Hit.Position.Y)
				Part:SetAttribute("Length", Length)
				Scenery.Mark(Part, "Fall", CFrame.new(Top), Vector3.zero, Index, #Icicles)
			end
		end
	end
end

function SceneryService:Rain(Folder: Instance)
	local Floor = Ground(Folder)
	local Roll = Random.new()
	local Zones = Folder:GetChildren()
	local Count = #Zones * DebrisPerZone
	local Index = 0
	for _, Child in ipairs(Zones) do
		local Zone = Child :: BasePart
		Hide(Zone)
		local Top = Zone.Position.Y + Zone.Size.Y / 2
		local Bottom = Zone.Position - Vector3.yAxis * Zone.Size.Y / 2
		local Hit = Workspace:Raycast(Bottom, -Vector3.yAxis * FallReach, Floor) :: RaycastResult

		local Debris = Instance.new("Model")
		Debris.Name = "Debris"
		Debris.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		for _ = 1, DebrisPerZone do
			Index += 1
			local Rock = Instance.new("Part")
			Rock.Name = "Rock"
			Rock.Size = Roll:NextNumber(DebrisMin, DebrisMax)
				* Vector3.new(
					Roll:NextNumber(1 - DebrisRatio, 1 + DebrisRatio),
					Roll:NextNumber(1 - DebrisRatio, 1 + DebrisRatio),
					Roll:NextNumber(1 - DebrisRatio, 1 + DebrisRatio)
				)
			Rock.Color = DebrisColor
			Rock.Material = DebrisMaterial
			Rock.Anchored = true
			Rock.CanTouch = false
			Rock.CFrame = Zone.CFrame
			Rock:SetAttribute("Extent", Zone.Size)
			Rock:SetAttribute("Drop", Top - Hit.Position.Y)
			Scenery.Mark(Rock, "Rain", Zone.CFrame, Vector3.zero, Index, Count)
			Rock.Parent = Debris
		end
		Debris.Parent = Folder
	end
end

function SceneryService:Trace(
	Zone: BasePart,
	Motion: string,
	Start: Vector3,
	Throw: Vector3,
	Time: number,
	Floor: RaycastParams
): number
	local Before = Start
	for Step = 1, math.ceil(Time / TraceStep) do
		local After = Scenery.Arc(Motion, Start, Throw, Step * TraceStep)
		if After.Y < Before.Y and not Within(Zone, Before) then
			local Hit = Workspace:Raycast(Before, After - Before, Floor)
			if Hit then
				return (Step - 1 + (Hit.Position - Before).Magnitude / (After - Before).Magnitude) * TraceStep
			end
		end
		Before = After
	end
	return Time
end

function SceneryService:Hurl(
	Zone: BasePart,
	Style: Barrage,
	Toward: Vector3,
	Near: number,
	Sink: number,
	First: number,
	Count: number,
	Floor: RaycastParams
): Model
	Hide(Zone)
	local Roll = Random.new()
	local Ceiling = Zone.Position.Y + Zone.Size.Y / 2 + MarkLift
	local Rocks: { BasePart } = {}
	local Span = 0
	for _ = 1, Style.Amount do
		local Rock = Instance.new("Part")
		Rock.Name = "Rock"
		Rock.Size = Roll:NextNumber(Style.Bulk.Min, Style.Bulk.Max)
			* (Vector3.one + Scatter(Roll, Vector3.one * HurlRatio))
		Rock.Color = Style.Color
		Rock.Material = Enum.Material.Plastic
		for _, Face in ipairs(Faces) do
			(Rock :: any)[Face] = Enum.SurfaceType.Studs
		end
		Rock.Anchored = true
		Rock.CanTouch = false

		local Room = (Zone.Size / 2 - Vector3.one * Rock.Size.Magnitude / 2):Max(Vector3.zero)
		local Start, Throw, Flight, Gone = Zone.Position, Vector3.zero, 0, -1
		for _ = 1, HurlTries do
			local Origin = Zone.CFrame:PointToWorldSpace(Scatter(Roll, Room))
			local Way = CFrame.fromAxisAngle(Vector3.yAxis, Roll:NextNumber(-Style.Fan, Style.Fan)) * Toward
			local Distance = Near + Roll:NextNumber(Style.Reach.Min, Style.Reach.Max)
			local Mark = Origin + Way * Distance
			local Hit = Workspace:Raycast(Vector3.new(Mark.X, Ceiling, Mark.Z), -Vector3.yAxis * FallReach, Floor)
			local Target = if Hit then Hit.Position else Vector3.new(Mark.X, Sink, Mark.Z)
			local Apex = math.max(Distance * Roll:NextNumber(Style.Loft.Min, Style.Loft.Max), HurlHop)
			local Launch, Time = Scenery.Lob(Style.Motion, Origin, Target, Apex)
			local Flown = self:Trace(Zone, Style.Motion, Origin, Launch, Time, Floor)
			local Landing = Scenery.Arc(Style.Motion, Origin, Launch, Flown)
			local Travel = ((Landing - Origin) * Flat).Magnitude
			if Travel > Gone then
				Start, Throw, Flight, Gone = Origin, Launch, Flown, Travel
			end
			if Flown >= Time * HurlShare then
				Start, Throw, Flight = Origin, Launch, Flown
				break
			end
		end
		Span = math.max(Span, Flight)
		Rock.CFrame = CFrame.new(Start)
		Rock:SetAttribute("Zone", Zone.CFrame)
		Rock:SetAttribute("Extent", Zone.Size)
		Rock:SetAttribute("Throw", Throw)
		Rock:SetAttribute("Flight", Flight)
		table.insert(Rocks, Rock)
	end

	local Model = Instance.new("Model")
	Model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for Index, Rock in ipairs(Rocks) do
		Rock:SetAttribute("Span", Span)
		Scenery.Mark(Rock, Style.Motion, Rock.CFrame, Vector3.zero, First + Index, Count)
		Rock.Parent = Model
	end
	return Model
end

function SceneryService:Slide(Folder: Instance)
	local Floor = Ground(Folder)
	local Zones = Folder:GetChildren()
	for Index, Child in ipairs(Zones) do
		local Zone = Child :: BasePart
		local Closest, Low = Course(Zone.Position)
		local Toward = ((Closest - Zone.Position) * Flat).Unit
		local Rocks = self:Hurl(
			Zone,
			Rockfall,
			Toward,
			0,
			Low - SinkDepth,
			(Index - 1) * Rockfall.Amount,
			#Zones * Rockfall.Amount,
			Floor
		)
		Rocks.Name = "Rocks"
		Rocks.Parent = Folder
	end
end

function SceneryService:Erupt(Volcano: Model)
	local Zone = Volcano:WaitForChild("VolcanoZone") :: BasePart
	local Box, Size = Volcano:GetBoundingBox()
	local Foot = math.max(Size.X, Size.Z) / 2 + ((Box.Position - Zone.Position) * Flat).Magnitude
	local _, Low = Course(Zone.Position)
	local Lava = self:Hurl(Zone, Eruption, Vector3.xAxis, Foot, Low - SinkDepth, 0, Eruption.Amount, Ground(Zone))
	Lava.Name = "Lava"
	Lava.Parent = Volcano
end

function SceneryService:Storm(Folder: Instance)
	local Zones = Folder:GetChildren()
	for Index, Child in ipairs(Zones) do
		local Zone = Child :: BasePart
		Hide(Zone)
		Zone:SetAttribute("Phase", Index)
		Zone:SetAttribute("Count", #Zones)
	end
end

function SceneryService:Turn(Folder: Instance)
	local Gliders = Folder:GetChildren()
	for Index, Child in ipairs(Gliders) do
		local Glider = Child :: Model
		local Hinge = CFrame.new(Glider:GetBoundingBox().Position)
		local Helice = Glider:FindFirstChild("Helice")
		local Hub = if Helice then Propeller.Hub(Glider) else nil
		for _, Part in ipairs(Glider:GetDescendants()) do
			if Part:IsA("JointInstance") or Part:IsA("WeldConstraint") then
				Part:Destroy()
			elseif Part:IsA("BasePart") then
				Part.Anchored = true
				if Hub and Part:IsDescendantOf(Helice :: Instance) then
					Part:SetAttribute("Hub", Hub)
					Scenery.Mark(Part, "Propel", Hinge, Vector3.yAxis, Index, #Gliders)
				else
					Scenery.Mark(Part, "Turn", Hinge, Vector3.yAxis, Index, #Gliders)
				end
			end
		end
	end
end

function SceneryService:Start()
	self.pieces = {} :: { Scenery.Piece }
	for _, Turbine in ipairs(Workspace:WaitForChild("WindTurbines"):GetChildren()) do
		self:Spin(Turbine :: Model)
	end
	self:Swing(Workspace:WaitForChild("AnimatedLog") :: Model)
	self:Rise(Workspace:WaitForChild("SpikesModels"))
	self:Drop(Workspace:WaitForChild("GlaceModels"))
	self:Rain(Workspace:WaitForChild("SpawnDebriesZone"))
	self:Flock(Workspace:WaitForChild("BirdsZones"))
	self:Whirl(Workspace:WaitForChild("TornadoZone"))
	self:Storm(Workspace:WaitForChild("SnowWindZones"))
	self:Erupt(Workspace:WaitForChild("Volcano") :: Model)
	self:Slide(Workspace:WaitForChild("RocksFallingZones"))
	self:Turn(Workspace:WaitForChild("RotatingGliders"))

	RunService.Heartbeat:Connect(function()
		local Time = Workspace:GetServerTimeNow()
		for _, Piece in ipairs(self.pieces) do
			Piece.Part.CFrame = Scenery.Pose(Piece, Time)
		end
	end)
end

return SceneryService
