local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Scenery = require(ReplicatedStorage.Shared.Utils.Scenery)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)

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
local DustCount = 10
local RainVolume = 1.2
local RainReach = 150

type Shard = {
	Emitter: ParticleEmitter,
	Strikes: number,
}

type Storm = {
	Sound: Sound,
	Zone: CFrame,
	Low: Vector3,
	High: Vector3,
	Total: number,
	Falling: number,
}

local function Burst(Position: Vector3, Color: ColorSequence): ParticleEmitter
	local Spot = Instance.new("Attachment")
	Spot.Position = Position
	Spot.Parent = Workspace.Terrain

	local Emitter = Instance.new("ParticleEmitter")
	Emitter.Color = Color
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
	return Emitter
end

function SceneryController:Crack(Piece: Scenery.Piece)
	if self.shards[Piece.Phase] then
		return
	end
	local Spot = Piece.Hinge.Position - Vector3.yAxis * ((Piece.Length :: number) + (Piece.Drop :: number))
	self.shards[Piece.Phase] = {
		Emitter = Burst(Spot, ShardColor),
		Strikes = Scenery.Strikes(Piece, Workspace:GetServerTimeNow()),
	}
end

function SceneryController:Shower(Part: BasePart, Piece: Scenery.Piece)
	if not self.dust then
		self.dust = Burst(Vector3.zero, ColorSequence.new(Part.Color))
	end
	self.landed[Part] = Scenery.Landed(Piece, Workspace:GetServerTimeNow())

	local Model = Part.Parent :: Instance
	local Storm = self.storms[Model]
	if not Storm then
		local Half = (Piece.Extent :: Vector3) / 2
		Storm = {
			Sound = Sfx.Loop(Sounds.Debris.Rain, 0),
			Zone = Piece.Hinge,
			Low = Vector3.new(-Half.X, Half.Y - (Piece.Drop :: number), -Half.Z),
			High = Half,
			Total = 0,
			Falling = 0,
		}
		self.storms[Model] = Storm
	end
	Storm.Total += 1
	self.rocks[Part] = Storm
end

function SceneryController:Rumble()
	local Camera = (Workspace.CurrentCamera :: Camera).CFrame.Position
	for _, Storm in pairs(self.storms) do
		local Point = Storm.Zone:PointToObjectSpace(Camera)
		local Gap = (Point - Point:Max(Storm.Low):Min(Storm.High)).Magnitude
		local Near = math.clamp(1 - Gap / RainReach, 0, 1)
		Storm.Sound.Volume = RainVolume * Near * Storm.Falling / Storm.Total
		Storm.Falling = 0
	end
end

function SceneryController:Watch(Folder: Instance)
	local function Add(Part: Instance)
		if Part:IsA("BasePart") and Part:GetAttribute("Hinge") then
			local Piece = Scenery.Read(Part)
			self.pieces[Part] = Piece
			if Piece.Motion == "Fall" then
				self:Crack(Piece)
			elseif Piece.Motion == "Rain" then
				self:Shower(Part, Piece)
			end
		end
	end
	for _, Part in ipairs(Folder:GetDescendants()) do
		Add(Part)
	end
	Folder.DescendantAdded:Connect(Add)
	Folder.DescendantRemoving:Connect(function(Part)
		self.pieces[Part] = nil
		self.landed[Part] = nil
		self.rocks[Part] = nil
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
		elseif Piece.Motion == "Rain" then
			if Scale > 0 then
				self.rocks[Part].Falling += 1
			end
			local Landed = Scenery.Landed(Piece, Time)
			if Landed ~= self.landed[Part] then
				self.landed[Part] = Landed
				local Dust = self.dust :: ParticleEmitter
				local Spot = Dust.Parent :: Attachment
				Spot.Position = Scenery.Impact(Piece, Landed - 1)
				Dust:Emit(DustCount)
			end
		end
		table.insert(Parts, Part)
		table.insert(Frames, Scenery.Pose(Piece, Time, self.altitude))
	end
	Workspace:BulkMoveTo(Parts, Frames, Enum.BulkMoveMode.FireCFrameChanged)
	self:Rumble()
end

function SceneryController:Eye(Part: BasePart): Vector3
	return Scenery.Eye(self.pieces[Part], Workspace:GetServerTimeNow())
end

function SceneryController:Aim(Altitude: number?)
	self.altitude = Altitude
end

function SceneryController:Init()
	self.pieces = {} :: { [BasePart]: Scenery.Piece }
	self.shards = {} :: { [number]: Shard }
	self.landed = {} :: { [BasePart]: number }
	self.dust = nil :: ParticleEmitter?
	self.storms = {} :: { [Instance]: Storm }
	self.rocks = {} :: { [BasePart]: Storm }
	self:Watch(Workspace:WaitForChild("WindTurbines"))
	self:Watch(Workspace:WaitForChild("AnimatedLog"))
	self:Watch(Workspace:WaitForChild("SpikesModels"))
	self:Watch(Workspace:WaitForChild("BirdsZones"))
	self:Watch(Workspace:WaitForChild("TornadoZone"))
	self:Watch(Workspace:WaitForChild("GlaceModels"))
	self:Watch(Workspace:WaitForChild("RotatingGliders"))
	self:Watch(Workspace:WaitForChild("SpawnDebriesZone"))
	RunService.RenderStepped:Connect(function()
		self:Pose()
	end)
end

return SceneryController
