local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Images = require(ReplicatedStorage.Shared.Config.Images)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Scenery = require(ReplicatedStorage.Shared.Utils.Scenery)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)

local SceneryController = {
	Name = "SceneryController",
	Priority = 12,
}

type Puff = {
	Texture: string,
	Color: ColorSequence,
	Fade: number,
	Glow: number,
	Lifetime: NumberRange,
	Speed: NumberRange,
	Spread: number,
}

local ShardCount = 24
local ShardColor = ColorSequence.new(Color3.fromRGB(215, 240, 255))
local ShardLifetime = NumberRange.new(0.5, 0.9)
local ShardSpeed = NumberRange.new(15, 30)
local ShardSpread = Vector2.new(70, 70)
local ShardSpin = NumberRange.new(-360, 360)
local ShardDrag = 2
local ShardFall = Vector3.new(0, -80, 0)
local ShardBulk = 1.2
local ShardTransparency = NumberSequence.new(0, 1)
local DustCount = 10
local RainVolume = 1.2
local RainReach = 150

local FireColor = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 226, 120)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 120, 20)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 20, 0)),
})
local PuffSpin = NumberRange.new(-60, 60)
local Dust: Puff = {
	Texture = Images.Scenery.Smoke,
	Color = ColorSequence.new(Color3.fromRGB(128, 122, 116)),
	Fade = 0.45,
	Glow = 0,
	Lifetime = NumberRange.new(0.7, 1.2),
	Speed = NumberRange.new(2, 8),
	Spread = 180,
}
local Flame: Puff = {
	Texture = Images.Scenery.Fire,
	Color = FireColor,
	Fade = 0,
	Glow = 1,
	Lifetime = NumberRange.new(0.35, 0.7),
	Speed = NumberRange.new(2, 8),
	Spread = 180,
}
local Ash: Puff = {
	Texture = Images.Scenery.Smoke,
	Color = ColorSequence.new(Color3.fromRGB(48, 42, 42)),
	Fade = 0.35,
	Glow = 0,
	Lifetime = NumberRange.new(1, 1.6),
	Speed = NumberRange.new(2, 8),
	Spread = 180,
}
local Plume: Puff = {
	Texture = Images.Scenery.Smoke,
	Color = ColorSequence.new(Color3.fromRGB(48, 42, 42), Color3.fromRGB(120, 116, 116)),
	Fade = 0.3,
	Glow = 0,
	Lifetime = NumberRange.new(3, 5),
	Speed = NumberRange.new(25, 45),
	Spread = 12,
}
local Jet: Puff = {
	Texture = Images.Scenery.Fire,
	Color = FireColor,
	Fade = 0,
	Glow = 1,
	Lifetime = NumberRange.new(0.7, 1.2),
	Speed = NumberRange.new(70, 120),
	Spread = 14,
}

local RubbleCount = 22
local RubbleBulk = 4
local EmberCount = 26
local EmberBulk = 3.5
local CloudCount = 6
local CloudSize = NumberRange.new(10, 24)
local WakeRate = 14
local FlameRate = 40
local AshRate = 12
local SlideVolume = 1.2
local SlideReach = 400
local SlideCrowd = 8
local EruptWarn = 2.5
local EruptBurst = 2.5
local EruptVolume = 0.5
local EruptReach = 1200
local ImpactVolume = 0.29
local ImpactStart = 0.23
local ImpactReach = 350
local PlumeRate = { 3, 10, 30 }
local PlumeBurst = 14
local JetRate = { 0, 0, 70 }
local SparkRate = { 0, 12, 90 }
local SparkBulk = 2
local SparkLifetime = NumberRange.new(1.5, 2.5)
local SparkSpeed = NumberRange.new(90, 150)
local SparkSpread = Vector2.new(30, 30)
local GlowLevel = { 1, 3, 8 }
local GlowRange = 60
local GlowColor = Color3.fromRGB(255, 120, 20)

type Shard = {
	Emitter: ParticleEmitter,
	Strikes: number,
}

type Storm = {
	Sound: Sound,
	Volume: number,
	Reach: number,
	Full: number,
	Falling: number,
	Gap: number,
	Zone: CFrame?,
	Low: Vector3?,
	High: Vector3?,
}

type Blast = {
	Chips: ParticleEmitter,
	Cloud: ParticleEmitter?,
	Count: number,
}

type Crater = {
	Piece: Scenery.Piece,
	Plume: ParticleEmitter,
	Jet: ParticleEmitter,
	Sparks: ParticleEmitter,
	Light: PointLight,
	Round: number,
	Heat: number,
}

local function Burst(Position: Vector3, Color: ColorSequence, Bulk: number): ParticleEmitter
	local Spot = Instance.new("Attachment")
	Spot.Position = Position
	Spot.Parent = Workspace.Terrain

	local Emitter = Instance.new("ParticleEmitter")
	Emitter.Color = Color
	Emitter.Size = NumberSequence.new(ShardBulk * Bulk, 0)
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

local function Smoke(Parent: Instance, Style: Puff, Small: number, Large: number, Rate: number): ParticleEmitter
	local Emitter = Instance.new("ParticleEmitter")
	Emitter.Texture = Style.Texture
	Emitter.Color = Style.Color
	Emitter.Size = NumberSequence.new(Small, Large)
	Emitter.Transparency = NumberSequence.new(Style.Fade, 1)
	Emitter.LightEmission = Style.Glow
	Emitter.Lifetime = Style.Lifetime
	Emitter.Speed = Style.Speed
	Emitter.SpreadAngle = Vector2.new(Style.Spread, Style.Spread)
	Emitter.Rotation = NumberRange.new(0, 360)
	Emitter.RotSpeed = PuffSpin
	Emitter.Rate = Rate
	Emitter.Parent = Parent
	return Emitter
end

function SceneryController:Crack(Piece: Scenery.Piece)
	if self.shards[Piece.Phase] then
		return
	end
	local Spot = Piece.Hinge.Position - Vector3.yAxis * ((Piece.Length :: number) + (Piece.Drop :: number))
	self.shards[Piece.Phase] = {
		Emitter = Burst(Spot, ShardColor, 1),
		Strikes = Scenery.Strikes(Piece, Workspace:GetServerTimeNow()),
	}
end

function SceneryController:Shower(Part: BasePart, Piece: Scenery.Piece)
	if not self.blasts.Rain then
		self.blasts.Rain = { Chips = Burst(Vector3.zero, ColorSequence.new(Part.Color), 1), Count = DustCount }
	end
	self.landed[Part] = Scenery.Landed(Piece, Workspace:GetServerTimeNow())

	local Model = Part.Parent :: Instance
	local Storm: Storm = self.storms[Model]
	if not Storm then
		local Half = (Piece.Extent :: Vector3) / 2
		Storm = {
			Sound = Sfx.Loop(Sounds.Debris.Rain, 0),
			Volume = RainVolume,
			Reach = RainReach,
			Full = 0,
			Falling = 0,
			Gap = math.huge,
			Zone = Piece.Hinge,
			Low = Vector3.new(-Half.X, Half.Y - (Piece.Drop :: number), -Half.Z),
			High = Half,
		}
		self.storms[Model] = Storm
	end
	Storm.Full += 1
	self.rocks[Part] = Storm
end

function SceneryController:Tumble(Part: BasePart, Piece: Scenery.Piece)
	local Bulk = Piece.Size.Magnitude / 2
	local Model = Part.Parent :: Instance
	if not self.blasts.Slide then
		local Chips = Burst(Vector3.zero, ColorSequence.new(Part.Color), RubbleBulk)
		self.blasts.Slide = {
			Chips = Chips,
			Cloud = Smoke(Chips.Parent :: Instance, Dust, CloudSize.Min, CloudSize.Max, 0),
			Count = RubbleCount,
		}
	end
	if not self.storms[Model] then
		self.storms[Model] = {
			Sound = Sfx.Loop(Sounds.Rockfall.Slide, 0),
			Volume = SlideVolume,
			Reach = SlideReach,
			Full = SlideCrowd,
			Falling = 0,
			Gap = math.huge,
		}
	end
	self.landed[Part] = Scenery.Landed(Piece, Workspace:GetServerTimeNow())
	self.rocks[Part] = self.storms[Model]
	self.wakes[Part] = { Smoke(Part, Dust, Bulk / 2, Bulk, WakeRate) }
end

function SceneryController:Blaze(Part: BasePart, Piece: Scenery.Piece)
	local Bulk = Piece.Size.Magnitude / 2
	local Model = Part.Parent :: Instance
	if not self.blasts.Erupt then
		local Chips = Burst(Vector3.zero, FireColor, EmberBulk)
		Chips.LightEmission = 1
		self.blasts.Erupt = {
			Chips = Chips,
			Cloud = Smoke(Chips.Parent :: Instance, Flame, CloudSize.Max, CloudSize.Min, 0),
			Count = EmberCount,
		}
	end
	if not self.craters[Model] then
		local Extent = Piece.Extent :: Vector3
		local Width = math.min(Extent.X, Extent.Z)
		local Sparks = Burst((Piece.Zone :: CFrame).Position, FireColor, SparkBulk)
		Sparks.Lifetime = SparkLifetime
		Sparks.Speed = SparkSpeed
		Sparks.SpreadAngle = SparkSpread
		Sparks.LightEmission = 1
		local Spot = Sparks.Parent :: Instance
		local Light = Instance.new("PointLight")
		Light.Color = GlowColor
		Light.Range = GlowRange
		Light.Shadows = false
		Light.Parent = Spot
		self.craters[Model] = {
			Piece = Piece,
			Plume = Smoke(Spot, Plume, Width / 2, Width * 1.5, 0),
			Jet = Smoke(Spot, Jet, Width * 0.6, Width * 0.15, 0),
			Sparks = Sparks,
			Light = Light,
			Round = Scenery.Surge(Piece, Workspace:GetServerTimeNow()),
			Heat = 0,
		}
	end
	self.landed[Part] = Scenery.Landed(Piece, Workspace:GetServerTimeNow())
	self.wakes[Part] = {
		Smoke(Part, Flame, Bulk, Bulk / 4, FlameRate),
		Smoke(Part, Ash, Bulk / 2, Bulk * 1.4, AshRate),
	}
end

function SceneryController:Smash(Piece: Scenery.Piece, Position: Vector3, Camera: Vector3)
	local Blast: Blast = self.blasts[Piece.Motion]
	local Spot = Blast.Chips.Parent :: Attachment
	Spot.Position = Position
	Blast.Chips:Emit(Blast.Count)
	if Blast.Cloud then
		Blast.Cloud:Emit(CloudCount)
	end
	if Piece.Motion == "Erupt" then
		local Near = 1 - (Position - Camera).Magnitude / ImpactReach
		if Near > 0 then
			Sfx.Play(Sounds.Volcano.Impact, ImpactVolume * Near, 1, ImpactStart)
		end
	end
end

function SceneryController:Smolder(Time: number, Camera: Vector3)
	for _, Crater: Crater in pairs(self.craters) do
		local Round, Clock, Left = Scenery.Surge(Crater.Piece, Time)
		local Heat = if Clock < EruptBurst then 3 elseif Left < EruptWarn then 2 else 1
		if Heat ~= Crater.Heat then
			Crater.Heat = Heat
			Crater.Plume.Rate = PlumeRate[Heat]
			Crater.Jet.Rate = JetRate[Heat]
			Crater.Sparks.Rate = SparkRate[Heat]
			Crater.Light.Brightness = GlowLevel[Heat]
		end
		if Round ~= Crater.Round then
			Crater.Round = Round
			Crater.Plume:Emit(PlumeBurst)
			local Near = 1 - ((Crater.Piece.Zone :: CFrame).Position - Camera).Magnitude / EruptReach
			if Near > 0 then
				Sfx.Play(Sounds.Volcano.Erupt, EruptVolume * Near)
			end
		end
	end
end

function SceneryController:Rumble(Camera: Vector3)
	for _, Storm: Storm in pairs(self.storms) do
		local Gap = Storm.Gap
		if Storm.Zone then
			local Point = Storm.Zone:PointToObjectSpace(Camera)
			Gap = (Point - Point:Max(Storm.Low :: Vector3):Min(Storm.High :: Vector3)).Magnitude
		end
		local Near = math.clamp(1 - Gap / Storm.Reach, 0, 1)
		Storm.Sound.Volume = Storm.Volume * Near * math.min(Storm.Falling / Storm.Full, 1)
		Storm.Falling = 0
		Storm.Gap = math.huge
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
			elseif Piece.Motion == "Slide" then
				self:Tumble(Part, Piece)
			elseif Piece.Motion == "Erupt" then
				self:Blaze(Part, Piece)
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
		self.wakes[Part] = nil
	end)
end

function SceneryController:Pose()
	local Time = Workspace:GetServerTimeNow()
	local Camera = (Workspace.CurrentCamera :: Camera).CFrame.Position
	local Parts: { BasePart } = {}
	local Frames: { CFrame } = {}
	for Part, Piece in pairs(self.pieces) do
		local Scale = Scenery.Scale(Piece, Time)
		if Scale ~= Piece.Scale then
			local Wakes: { ParticleEmitter }? = self.wakes[Part]
			if Wakes and (Scale > 0) ~= (Piece.Scale > 0) then
				for _, Wake in ipairs(Wakes) do
					Wake.Enabled = Scale > 0
				end
			end
			Piece.Scale = Scale
			Part.Size = Piece.Size * Scale
		end
		local Frame = Scenery.Pose(Piece, Time, self.altitude)
		if Piece.Motion == "Fall" then
			local Shard: Shard = self.shards[Piece.Phase]
			local Strikes = Scenery.Strikes(Piece, Time)
			if Strikes ~= Shard.Strikes then
				Shard.Strikes = Strikes
				Shard.Emitter:Emit(ShardCount)
			end
		elseif self.landed[Part] then
			local Storm: Storm? = self.rocks[Part]
			if Storm and Scale > 0 then
				Storm.Falling += 1
				Storm.Gap = math.min(Storm.Gap, (Frame.Position - Camera).Magnitude)
			end
			local Landed = Scenery.Landed(Piece, Time)
			if Landed ~= self.landed[Part] then
				self.landed[Part] = Landed
				self:Smash(Piece, Scenery.Impact(Piece, Landed - 1), Camera)
			end
		end
		table.insert(Parts, Part)
		table.insert(Frames, Frame)
	end
	Workspace:BulkMoveTo(Parts, Frames, Enum.BulkMoveMode.FireCFrameChanged)
	self:Rumble(Camera)
	self:Smolder(Time, Camera)
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
	self.blasts = {} :: { [string]: Blast }
	self.storms = {} :: { [Instance]: Storm }
	self.rocks = {} :: { [BasePart]: Storm }
	self.wakes = {} :: { [BasePart]: { ParticleEmitter } }
	self.craters = {} :: { [Instance]: Crater }
	self:Watch(Workspace:WaitForChild("WindTurbines"))
	self:Watch(Workspace:WaitForChild("AnimatedLog"))
	self:Watch(Workspace:WaitForChild("SpikesModels"))
	self:Watch(Workspace:WaitForChild("BirdsZones"))
	self:Watch(Workspace:WaitForChild("TornadoZone"))
	self:Watch(Workspace:WaitForChild("GlaceModels"))
	self:Watch(Workspace:WaitForChild("RotatingGliders"))
	self:Watch(Workspace:WaitForChild("SpawnDebriesZone"))
	self:Watch(Workspace:WaitForChild("RocksFallingZones"))
	self:Watch(Workspace:WaitForChild("Volcano"))
	RunService.RenderStepped:Connect(function()
		self:Pose()
	end)
end

return SceneryController
