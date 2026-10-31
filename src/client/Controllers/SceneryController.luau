local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Scenery = require(ReplicatedStorage.Shared.Utils.Scenery)

local SceneryController = {
	Name = "SceneryController",
	Priority = 12,
}

local ShardCount = 24
local ShardColor = ColorSequence.new(Color3.fromRGB(215, 240, 255))
local ShardLifetime = NumberRange.new(0.5, 0.9)
local ShardSpeed = NumberRange.new(15, 30)
local ShardSpread = Vector2.new(70, 70)
local ShardSpin = NumberRange.new(-360, 360)
local ShardDrag = 2
local ShardFall = Vector3.new(0, -80, 0)
local ShardSize = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1.2),
	NumberSequenceKeypoint.new(1, 0),
})
local ShardTransparency = NumberSequence.new(0, 1)

type Shard = {
	Emitter: ParticleEmitter,
	Strikes: number,
}

function SceneryController:Crack(Piece: Scenery.Piece)
	if self.shards[Piece.Phase] then
		return
	end
	local Spot = Instance.new("Attachment")
	Spot.Position = Piece.Hinge.Position - Vector3.yAxis * ((Piece.Length :: number) + (Piece.Drop :: number))
	Spot.Parent = Workspace.Terrain

	local Emitter = Instance.new("ParticleEmitter")
	Emitter.Color = ShardColor
	Emitter.Size = ShardSize
	Emitter.Transparency = ShardTransparency
	Emitter.Lifetime = ShardLifetime
	Emitter.Rate = 0
	Emitter.Speed = ShardSpeed
	Emitter.SpreadAngle = ShardSpread
	Emitter.Rotation = NumberRange.new(0, 360)
	Emitter.RotSpeed = ShardSpin
	Emitter.Drag = ShardDrag
	Emitter.Acceleration = ShardFall
	Emitter.Parent = Spot

	self.shards[Piece.Phase] = {
		Emitter = Emitter,
		Strikes = Scenery.Strikes(Piece, Workspace:GetServerTimeNow()),
	}
end

function SceneryController:Watch(Folder: Instance)
	local function Add(Part: Instance)
		if Part:IsA("BasePart") and Part:GetAttribute("Hinge") then
			local Piece = Scenery.Read(Part)
			self.pieces[Part] = Piece
			if Piece.Motion == "Fall" then
				self:Crack(Piece)
			end
		end
	end
	for _, Part in ipairs(Folder:GetDescendants()) do
		Add(Part)
	end
	Folder.DescendantAdded:Connect(Add)
	Folder.DescendantRemoving:Connect(function(Part)
		self.pieces[Part] = nil
	end)
end

function SceneryController:Pose()
	local Time = Workspace:GetServerTimeNow()
	local Parts: { BasePart } = {}
	local Frames: { CFrame } = {}
	for Part, Piece in pairs(self.pieces) do
		local Scale = Scenery.Scale(Piece, Time)
		if Scale ~= Piece.Scale then
			Piece.Scale = Scale
			Part.Size = Piece.Size * Scale
		end
		if Piece.Motion == "Fall" then
			local Shard: Shard = self.shards[Piece.Phase]
			local Strikes = Scenery.Strikes(Piece, Time)
			if Strikes ~= Shard.Strikes then
				Shard.Strikes = Strikes
				Shard.Emitter:Emit(ShardCount)
			end
		end
		table.insert(Parts, Part)
		table.insert(Frames, Scenery.Pose(Piece, Time, self.altitude))
	end
	Workspace:BulkMoveTo(Parts, Frames, Enum.BulkMoveMode.FireCFrameChanged)
end

function SceneryController:Aim(Altitude: number?)
	self.altitude = Altitude
end

function SceneryController:Init()
	self.pieces = {} :: { [BasePart]: Scenery.Piece }
	self.shards = {} :: { [number]: Shard }
	self:Watch(Workspace:WaitForChild("WindTurbines"))
	self:Watch(Workspace:WaitForChild("AnimatedLog"))
	self:Watch(Workspace:WaitForChild("SpikesModels"))
	self:Watch(Workspace:WaitForChild("BirdsZones"))
	self:Watch(Workspace:WaitForChild("TornadoZone"))
	self:Watch(Workspace:WaitForChild("GlaceModels"))
	self:Watch(Workspace:WaitForChild("RotatingGliders"))
	RunService.RenderStepped:Connect(function()
		self:Pose()
	end)
end

return SceneryController
