local Ragdoll = {}

export type Handle = {
	Motors: { Motor6D },
	Parts: { Instance },
}

local SwingDegrees = 45
local TwistDegrees = 45

function Ragdoll.Enable(Character: Model): Handle
	local Handle: Handle = { Motors = {}, Parts = {} }
	for _, Motor in ipairs(Character:GetDescendants()) do
		if Motor:IsA("Motor6D") and Motor.Name ~= "Root" and Motor.Name ~= "Neck" then
			local Part0 = Motor.Part0 :: BasePart
			local Part1 = Motor.Part1 :: BasePart

			local Attachment0 = Instance.new("Attachment")
			Attachment0.CFrame = Motor.C0
			Attachment0.Parent = Part0
			local Attachment1 = Instance.new("Attachment")
			Attachment1.CFrame = Motor.C1
			Attachment1.Parent = Part1

			local Socket = Instance.new("BallSocketConstraint")
			Socket.Attachment0 = Attachment0
			Socket.Attachment1 = Attachment1
			Socket.LimitsEnabled = true
			Socket.UpperAngle = SwingDegrees
			Socket.TwistLimitsEnabled = true
			Socket.TwistLowerAngle = -TwistDegrees
			Socket.TwistUpperAngle = TwistDegrees
			Socket.Parent = Part1

			local Ghost = Instance.new("NoCollisionConstraint")
			Ghost.Part0 = Part0
			Ghost.Part1 = Part1
			Ghost.Parent = Part1

			Motor.Enabled = false
			table.insert(Handle.Motors, Motor)
			table.insert(Handle.Parts, Attachment0)
			table.insert(Handle.Parts, Attachment1)
			table.insert(Handle.Parts, Socket)
			table.insert(Handle.Parts, Ghost)
		end
	end
	return Handle
end

function Ragdoll.Disable(Handle: Handle)
	for _, Part in ipairs(Handle.Parts) do
		Part:Destroy()
	end
	for _, Motor in ipairs(Handle.Motors) do
		Motor.Enabled = true
	end
end

return Ragdoll
