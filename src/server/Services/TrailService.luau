local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local Colors: { [string]: ColorSequence } = {}
local Sparkles: { [string]: ColorSequence } = {}
for _, Entry in ipairs(TrailsConfig.List) do
	Colors[Entry.Name] = Entry.Color
	Sparkles[Entry.Name] = Entry.Sparkles
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
		end
	end
end

return TrailService
