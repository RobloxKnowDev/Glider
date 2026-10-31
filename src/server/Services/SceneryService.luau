local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Scenery = require(ReplicatedStorage.Shared.Utils.Scenery)

local SceneryService = {
	Name = "SceneryService",
	Priority = 12,
}

local PhaseSpread = 0.05
local BirdsPerZone = 4
local FallReach = 2000
local Flat = Vector3.new(1, 0, 1)

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
			Child.CanCollide = true
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
		Zone.Transparency = 1
		Zone.CanCollide = false
		Zone.CanQuery = false
		Zone.CanTouch = false
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
		Zone.Transparency = 1
		Zone.CanCollide = false
		Zone.CanQuery = false
		Zone.CanTouch = false

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
				Part.CanCollide = true
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
	local Ground = RaycastParams.new()
	Ground.FilterType = Enum.RaycastFilterType.Exclude
	Ground.FilterDescendantsInstances = {
		Folder,
		Workspace:WaitForChild("RingsFolder"),
		Workspace:WaitForChild("Windzones"),
		Workspace:WaitForChild("WindTurbineZones"),
	}
	Ground.RespectCanCollide = true
	local Icicles = Folder:GetChildren()
	for Index, Child in ipairs(Icicles) do
		local Box, Size = (Child :: Model):GetBoundingBox()
		local Length = Span(Box, Size, Vector3.yAxis)
		local Top = Box.Position + Vector3.yAxis * Length / 2
		local Tip = Top - Vector3.yAxis * Length
		local Floor = Workspace:Raycast(Tip, -Vector3.yAxis * FallReach, Ground) :: RaycastResult
		for _, Part in ipairs(Child:GetDescendants()) do
			if Part:IsA("JointInstance") or Part:IsA("WeldConstraint") then
				Part:Destroy()
			elseif Part:IsA("BasePart") then
				Part.Anchored = true
				Part.CanCollide = true
				Part:SetAttribute("Drop", Tip.Y - Floor.Position.Y)
				Part:SetAttribute("Length", Length)
				Scenery.Mark(Part, "Fall", CFrame.new(Top), Vector3.zero, Index, #Icicles)
			end
		end
	end
end

function SceneryService:Turn(Folder: Instance)
	local Gliders = Folder:GetChildren()
	for Index, Child in ipairs(Gliders) do
		local Box = (Child :: Model):GetBoundingBox()
		for _, Part in ipairs(Child:GetDescendants()) do
			if Part:IsA("JointInstance") or Part:IsA("WeldConstraint") then
				Part:Destroy()
			elseif Part:IsA("BasePart") then
				Part.Anchored = true
				Scenery.Mark(Part, "Turn", CFrame.new(Box.Position), Vector3.yAxis, Index, #Gliders)
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
	self:Flock(Workspace:WaitForChild("BirdsZones"))
	self:Whirl(Workspace:WaitForChild("TornadoZone"))
	self:Turn(Workspace:WaitForChild("RotatingGliders"))

	RunService.Heartbeat:Connect(function()
		local Time = Workspace:GetServerTimeNow()
		for _, Piece in ipairs(self.pieces) do
			Piece.Part.CFrame = Scenery.Pose(Piece, Time)
		end
	end)
end

return SceneryService
