local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Images = require(ReplicatedStorage.Shared.Config.Images)
local TrailsConfig = require(ReplicatedStorage.Shared.Config.Trails)

local TrailService = {
	Name = "TrailService",
	Priority = 8,
}

local TrailWidth = 0.4
local TrailLifetime = 0.6
local TrailLightEmission = 0.5
local TrailTransparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.5),
	NumberSequenceKeypoint.new(0.15, 0.2),
	NumberSequenceKeypoint.new(1, 1),
})
local TrailWidthScale = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.4),
	NumberSequenceKeypoint.new(0.15, 1),
	NumberSequenceKeypoint.new(1, 0),
})

local SparkleRate = 30
local SparkleLifetime = NumberRange.new(0.5, 0.9)
local SparkleSpeed = NumberRange.new(0.5, 2)
local SparkleSpin = NumberRange.new(-180, 180)
local SparkleDrag = 3
local SparkleSize = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.2, 0.5),
	NumberSequenceKeypoint.new(1, 0),
})
local SparkleTransparency = NumberSequence.new(0, 0.4)

local ParticleRate = 6
local ParticleLifetime = NumberRange.new(0.8, 1.2)
local ParticleSpeed = NumberRange.new(0.5, 1.5)
local ParticleTilt = NumberRange.new(-20, 20)
local ParticleSpin = NumberRange.new(-45, 45)
local ParticleDrag = 2
local ParticleGlow = 0.8
local ParticleSize = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.15, 1.5),
	NumberSequenceKeypoint.new(1, 0.5),
})
local ParticleTransparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.4),
	NumberSequenceKeypoint.new(0.6, 0.4),
	NumberSequenceKeypoint.new(1, 1),
})

local Colors: { [string]: ColorSequence } = {}
local Sparkles: { [string]: ColorSequence } = {}
local Particles: { [string]: string } = {}
for _, Entry in ipairs(TrailsConfig.List) do
	Colors[Entry.Name] = Entry.Color
	Sparkles[Entry.Name] = Entry.Sparkles
	Particles[Entry.Name] = Entry.Particle
end

function TrailService:Attach(Bar: BasePart, Frame: CFrame, Name: string)
	for _, Child in ipairs(Bar:GetChildren()) do
		if Child:IsA("Attachment") then
			local Wing = Child :: Attachment
			local Edge = Instance.new("Attachment")
			Edge.Name = "TrailAttachment"
			Edge.Position = Wing.Position + Frame.UpVector * TrailWidth
			Edge.Parent = Bar

			local Trail = Instance.new("Trail")
			Trail.Attachment0 = Wing
			Trail.Attachment1 = Edge
			Trail.Color = Colors[Name]
			Trail.Transparency = TrailTransparency
			Trail.WidthScale = TrailWidthScale
			Trail.Lifetime = TrailLifetime
			Trail.FaceCamera = true
			Trail.LightEmission = TrailLightEmission
			Trail.LightInfluence = 0
			Trail.Parent = Bar

			local Sparkle = Sparkles[Name]
			if Sparkle then
				local Emitter = Instance.new("ParticleEmitter")
				Emitter.Color = Sparkle
				Emitter.Size = SparkleSize
				Emitter.Transparency = SparkleTransparency
				Emitter.Lifetime = SparkleLifetime
				Emitter.Rate = SparkleRate
				Emitter.Speed = SparkleSpeed
				Emitter.SpreadAngle = Vector2.new(180, 180)
				Emitter.Rotation = NumberRange.new(0, 360)
				Emitter.RotSpeed = SparkleSpin
				Emitter.Drag = SparkleDrag
				Emitter.LightEmission = 1
				Emitter.LightInfluence = 0
				Emitter.Parent = Wing
			end

			local Particle = Particles[Name]
			if Particle then
				local Emitter = Instance.new("ParticleEmitter")
				Emitter.Texture = Images.Particle[Particle]
				Emitter.Size = ParticleSize
				Emitter.Transparency = ParticleTransparency
				Emitter.Lifetime = ParticleLifetime
				Emitter.Rate = ParticleRate
				Emitter.Speed = ParticleSpeed
				Emitter.SpreadAngle = Vector2.new(180, 180)
				Emitter.Rotation = ParticleTilt
				Emitter.RotSpeed = ParticleSpin
				Emitter.Drag = ParticleDrag
				Emitter.LightEmission = ParticleGlow
				Emitter.LightInfluence = 0
				Emitter.Parent = Wing
			end
		end
	end
end

return TrailService
