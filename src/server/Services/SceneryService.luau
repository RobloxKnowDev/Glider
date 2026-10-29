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
local Flat = Vector3.new(1, 0, 1)

local function Shoulder(Wing: Model, Out: Vector3): CFrame
	local Box, Size = Wing:GetBoundingBox()
	local Reach = math.abs(Out:Dot(Box.RightVector)) * Size.X
		+ math.abs(Out:Dot(Box.UpVector)) * Size.Y
		+ math.abs(Out:Dot(Box.LookVector)) * Size.Z
	return CFrame.new(Box.Position - Out * Reach / 2)
end

function SceneryService:Flap(Wing: Model, Out: Vector3, Index: number)
	local Hinge = Shoulder(Wing, Out)
	local Axis = Out:Cross(Vector3.yAxis)
	for _, Part in ipairs(Wing:GetDescendants()) do
		if Part:IsA("BasePart") then
			Scenery.Mark(Part, "Flap", Hinge, Axis, Index)
		end
	end
end

function SceneryService:Hatch(Model: Model, Zone: BasePart, Index: number, Folder: Instance)
	local Bird = Model:Clone()
	Bird:PivotTo(CFrame.identity)
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

	local Ail1 = Bird:WaitForChild("Ail1") :: Model
	local Ail2 = Bird:WaitForChild("Ail2") :: Model
	local Out = ((Ail1:GetBoundingBox().Position - Ail2:GetBoundingBox().Position) * Flat).Unit
	self:Flap(Ail1, Out, Index)
	self:Flap(Ail2, -Out, Index)
	for _, Part in ipairs(Bird:GetDescendants()) do
		if Part:IsA("BasePart") and not Part:IsDescendantOf(Ail1) and not Part:IsDescendantOf(Ail2) then
			Scenery.Mark(Part, "Fly", CFrame.identity, Vector3.zero, Index)
		end
	end

	Bird.Name = "Bird"
	Bird.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	Bird:PivotTo(Zone.CFrame)
	Bird.Parent = Folder
end

function SceneryService:Flock(Folder: Instance)
	local Model = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Level"):WaitForChild("BirdModel") :: Model
	local Index = 0
	for _, Child in ipairs(Folder:GetChildren()) do
		local Zone = Child :: BasePart
		Zone.Transparency = 1
		Zone.CanCollide = false
		Zone.CanQuery = false
		Zone.CanTouch = false
		for _ = 1, BirdsPerZone do
			Index += 1
			self:Hatch(Model, Zone, Index, Folder)
		end
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

function SceneryService:Start()
	self.pieces = {} :: { Scenery.Piece }
	for _, Turbine in ipairs(Workspace:WaitForChild("WindTurbines"):GetChildren()) do
		self:Spin(Turbine :: Model)
	end
	self:Swing(Workspace:WaitForChild("AnimatedLog") :: Model)
	self:Rise(Workspace:WaitForChild("SpikesModels"))
	self:Flock(Workspace:WaitForChild("BirdsZones"))

	RunService.Heartbeat:Connect(function()
		local Time = Workspace:GetServerTimeNow()
		for _, Piece in ipairs(self.pieces) do
			Piece.Part.CFrame = Scenery.Pose(Piece, Time)
		end
	end)
end

return SceneryService
