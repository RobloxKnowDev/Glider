local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Images = require(ReplicatedStorage.Shared.Config.Images)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)

local BlizzardController = {
	Name = "BlizzardController",
	Priority = 12,
}

local CalmTime = 7
local StormTime = 6
local RampTime = 0.6
local GustDepth = 0.4
local GustSpeed = 5
local HeaveDepth = 0.35
local HeaveSpeed = 3.7

local FlakeDensity = 0.001
local FlakeLimit = 1300
local FlakeCalm = 0.07
local FlakeSize = NumberSequence.new(0.9, 1.5)
local FlakeTransparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.15, 0.1),
	NumberSequenceKeypoint.new(0.8, 0.1),
	NumberSequenceKeypoint.new(1, 1),
})
local FlakeLifetime = NumberRange.new(1, 1.5)
local FlakeSpeed = NumberRange.new(0, 4)
local FlakeSpin = NumberRange.new(-180, 180)
local FlakeFall = Vector3.new(0, -14, 0)
local FlakeForce = 420
local FlakeGlow = 0.4
local MistDensity = 0.00007
local MistLimit = 150
local MistColor = ColorSequence.new(Color3.fromRGB(232, 242, 255))
local MistSize = NumberSequence.new(18, 36)
local MistTransparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.72),
	NumberSequenceKeypoint.new(0.7, 0.72),
	NumberSequenceKeypoint.new(1, 1),
})
local MistLifetime = NumberRange.new(1.6, 2.4)
local MistSpin = NumberRange.new(-40, 40)
local MistForce = 240
local WindDrag = 4
local FlurryRate = 1100
local FlurrySize = Vector3.new(100, 70, 100)
local FlurryLead = 45

local VeilResponse = 5
local VeilBrightness = 0.2
local VeilContrast = -0.25
local VeilSaturation = -0.7
local VeilTint = Color3.fromRGB(208, 226, 255)

local WindVolume = 0.42
local WindReach = 300

type Squall = {
	Zone: BasePart,
	Phase: number,
	Count: number,
	Round: number,
	Wind: Vector3,
	Strength: number,
	Flakes: ParticleEmitter,
	Flurry: number,
	Mist: ParticleEmitter,
	Haze: number,
	Sound: Sound,
}

local function Blow(Squall: Squall, Time: number): number
	local Cycle = CalmTime + StormTime
	local Beat = Time / Cycle + (Squall.Phase - 1) / Squall.Count
	local Round = Beat // 1
	if Squall.Round ~= Round then
		local Angle = Random.new(Round * Squall.Count + Squall.Phase):NextNumber(0, 2 * math.pi)
		Squall.Round = Round
		Squall.Wind = Vector3.new(math.cos(Angle), 0, math.sin(Angle))
	end
	local Clock = (Beat - Round) * Cycle - CalmTime
	return math.clamp(math.min(Clock, StormTime - Clock) / RampTime, 0, 1)
end

local function Gale(Squall: Squall, Time: number, Strength: number): Vector3
	local Surge = 1 + GustDepth * math.sin(Time * GustSpeed + Squall.Phase)
	local Heave = HeaveDepth * math.sin(Time * HeaveSpeed + Squall.Phase * 2)
	return (Squall.Wind * Surge + Vector3.yAxis * Heave) * Strength
end

local function Gap(Zone: BasePart, Point: Vector3): number
	local Half = Zone.Size / 2
	local Local = Zone.CFrame:PointToObjectSpace(Point)
	return (Local - Local:Max(-Half):Min(Half)).Magnitude
end

local function Emitter(Zone: BasePart): ParticleEmitter
	local Snow = Instance.new("ParticleEmitter")
	Snow.Shape = Enum.ParticleEmitterShape.Box
	Snow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	Snow.Rotation = NumberRange.new(0, 360)
	Snow.Drag = WindDrag
	Snow.Rate = 0
	Snow.Parent = Zone
	return Snow
end

local function Flake(Zone: BasePart): ParticleEmitter
	local Flakes = Emitter(Zone)
	Flakes.Size = FlakeSize
	Flakes.Transparency = FlakeTransparency
	Flakes.Lifetime = FlakeLifetime
	Flakes.Speed = FlakeSpeed
	Flakes.RotSpeed = FlakeSpin
	Flakes.LightEmission = FlakeGlow
	return Flakes
end

function BlizzardController:Build(Zone: BasePart)
	local Volume = Zone.Size.X * Zone.Size.Y * Zone.Size.Z
	local Flakes = Flake(Zone)
	local Mist = Emitter(Zone)
	Mist.Texture = Images.Scenery.Smoke
	Mist.Color = MistColor
	Mist.Size = MistSize
	Mist.Transparency = MistTransparency
	Mist.Lifetime = MistLifetime
	Mist.Speed = NumberRange.new(0)
	Mist.RotSpeed = MistSpin

	self.squalls[Zone] = {
		Zone = Zone,
		Phase = Zone:GetAttribute("Phase"),
		Count = Zone:GetAttribute("Count"),
		Round = -1,
		Wind = Vector3.xAxis,
		Strength = -1,
		Flakes = Flakes,
		Flurry = math.min(Volume * FlakeDensity, FlakeLimit),
		Mist = Mist,
		Haze = math.min(Volume * MistDensity, MistLimit),
		Sound = Sfx.Loop(Sounds.Blizzard.Wind, 0),
	}
end

function BlizzardController:Gust(Position: Vector3): Vector3?
	local Time = Workspace:GetServerTimeNow()
	for Zone, Squall in pairs(self.squalls) do
		local Strength = Blow(Squall, Time)
		if Strength > 0 and Gap(Zone, Position) == 0 then
			return Gale(Squall, Time, Strength)
		end
	end
	return nil
end

function BlizzardController:Render(Dt: number)
	local Time = Workspace:GetServerTimeNow()
	local View = (Workspace.CurrentCamera :: Camera).CFrame
	local Camera = View.Position
	local Flurry = self.flurry :: ParticleEmitter
	local Veil = 0
	for Zone, Squall: Squall in pairs(self.squalls) do
		local Strength = Blow(Squall, Time)
		local Wind = Gale(Squall, Time, Strength)
		local Far = Gap(Zone, Camera)
		Squall.Sound.Volume = WindVolume * Strength * math.clamp(1 - Far / WindReach, 0, 1)
		if Far == 0 and Strength > Veil then
			Veil = Strength
			Flurry.Acceleration = FlakeFall + Wind * FlakeForce
		end
		if Strength ~= Squall.Strength then
			Squall.Strength = Strength
			Squall.Flakes.Rate = Squall.Flurry * (FlakeCalm + (1 - FlakeCalm) * Strength)
			Squall.Mist.Rate = Squall.Haze * Strength
		end
		Squall.Flakes.Acceleration = FlakeFall + Wind * FlakeForce
		Squall.Mist.Acceleration = Wind * MistForce
	end
	local Box = Flurry.Parent :: BasePart
	Box.CFrame = CFrame.new(Camera + View.LookVector * FlurryLead)
	Flurry.Rate = FlurryRate * Veil

	self.veil += (Veil - self.veil) * (1 - math.exp(-VeilResponse * Dt))
	local Tint = self.tint :: ColorCorrectionEffect
	Tint.Brightness = VeilBrightness * self.veil
	Tint.Contrast = VeilContrast * self.veil
	Tint.Saturation = VeilSaturation * self.veil
	Tint.TintColor = Color3.new(1, 1, 1):Lerp(VeilTint, self.veil)
end

function BlizzardController:Init()
	self.squalls = {} :: { [BasePart]: Squall }
	self.veil = 0
	self.tint = Instance.new("ColorCorrectionEffect")
	self.tint.Parent = Lighting

	local Box = Instance.new("Part")
	Box.Name = "Flurry"
	Box.Size = FlurrySize
	Box.Transparency = 1
	Box.Anchored = true
	Box.CanCollide = false
	Box.CanQuery = false
	Box.CanTouch = false
	Box.Parent = Workspace
	self.flurry = Flake(Box)

	local Folder = Workspace:WaitForChild("SnowWindZones")
	for _, Zone in ipairs(Folder:GetChildren()) do
		self:Build(Zone :: BasePart)
	end
	Folder.ChildAdded:Connect(function(Zone)
		self:Build(Zone :: BasePart)
	end)
	Folder.ChildRemoved:Connect(function(Zone)
		self.squalls[Zone].Sound:Destroy()
		self.squalls[Zone] = nil
	end)
	RunService.RenderStepped:Connect(function(Dt)
		self:Render(Dt)
	end)
end

return BlizzardController
