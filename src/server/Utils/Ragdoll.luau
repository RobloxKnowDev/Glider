local Ragdoll = {}

export type Handle = {
	Humanoid: Humanoid,
	Root: BasePart,
	Collide: boolean,
	Motors: { Motor6D },
	Parts: { Instance },
}

type Joint = {
	Part: string,
	Motor: string,
	Swing: number,
	Twist: number,
}

local Joints: { Joint } = {
	{ Part = "Head", Motor = "Neck", Swing = 35, Twist = 45 },
	{ Part = "UpperTorso", Motor = "Waist", Swing = 25, Twist = 20 },
	{ Part = "RightUpperArm", Motor = "RightShoulder", Swing = 110, Twist = 60 },
	{ Part = "LeftUpperArm", Motor = "LeftShoulder", Swing = 110, Twist = 60 },
	{ Part = "RightLowerArm", Motor = "RightElbow", Swing = 75, Twist = 10 },
	{ Part = "LeftLowerArm", Motor = "LeftElbow", Swing = 75, Twist = 10 },
	{ Part = "RightHand", Motor = "RightWrist", Swing = 35, Twist = 20 },
	{ Part = "LeftHand", Motor = "LeftWrist", Swing = 35, Twist = 20 },
	{ Part = "RightUpperLeg", Motor = "RightHip", Swing = 75, Twist = 20 },
	{ Part = "LeftUpperLeg", Motor = "LeftHip", Swing = 75, Twist = 20 },
	{ Part = "RightLowerLeg", Motor = "RightKnee", Swing = 75, Twist = 5 },
	{ Part = "LeftLowerLeg", Motor = "LeftKnee", Swing = 75, Twist = 5 },
	{ Part = "RightFoot", Motor = "RightAnkle", Swing = 25, Twist = 10 },
	{ Part = "LeftFoot", Motor = "LeftAnkle", Swing = 25, Twist = 10 },
}
local Bodies = { "LowerTorso" }
for _, Joint in ipairs(Joints) do
	table.insert(Bodies, Joint.Part)
end

local Axis = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))
local ColliderScale = 0.8

local function Collider(Part: BasePart): BasePart
	local Box = Instance.new("Part")
	Box.Name = "Collider"
	Box.Size = Part.Size * ColliderScale
	Box.CFrame = Part.CFrame
	Box.Transparency = 1
	Box.Massless = true
	Box.CanCollide = true
	Box.CanQuery = false
	Box.CanTouch = false
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = Part
	Weld.Part1 = Box
	Weld.Parent = Box
	Box.Parent = Part
	return Box
end

function Ragdoll.Enable(Character: Model): Handle
	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	local Root = Character:WaitForChild("HumanoidRootPart") :: BasePart
	local Handle: Handle = { Humanoid = Humanoid, Root = Root, Collide = Root.CanCollide, Motors = {}, Parts = {} }
	Humanoid.RequiresNeck = false
	Root.CanCollide = false

	local Colliders: { [BasePart]: BasePart } = {}
	for _, Name in ipairs(Bodies) do
		local Part = Character:WaitForChild(Name) :: BasePart
		Colliders[Part] = Collider(Part)
		table.insert(Handle.Parts, Colliders[Part])
	end

	for _, Joint in ipairs(Joints) do
		local Motor = Character:WaitForChild(Joint.Part):WaitForChild(Joint.Motor) :: Motor6D
		local Part0 = Motor.Part0 :: BasePart
		local Part1 = Motor.Part1 :: BasePart

		local Attachment0 = Instance.new("Attachment")
		Attachment0.CFrame = Motor.C0 * Axis
		Attachment0.Parent = Part0
		local Attachment1 = Instance.new("Attachment")
		Attachment1.CFrame = Motor.C1 * Axis
		Attachment1.Parent = Part1

		local Socket = Instance.new("BallSocketConstraint")
		Socket.Attachment0 = Attachment0
		Socket.Attachment1 = Attachment1
		Socket.LimitsEnabled = true
		Socket.UpperAngle = Joint.Swing
		Socket.TwistLimitsEnabled = true
		Socket.TwistLowerAngle = -Joint.Twist
		Socket.TwistUpperAngle = Joint.Twist
		Socket.Parent = Part1
		table.insert(Handle.Parts, Attachment0)
		table.insert(Handle.Parts, Attachment1)
		table.insert(Handle.Parts, Socket)

		for _, A in ipairs({ Part0, Colliders[Part0] }) do
			for _, B in ipairs({ Part1, Colliders[Part1] }) do
				local Ghost = Instance.new("NoCollisionConstraint")
				Ghost.Part0 = A
				Ghost.Part1 = B
				Ghost.Parent = Part1
				table.insert(Handle.Parts, Ghost)
			end
		end

		Motor.Enabled = false
		table.insert(Handle.Motors, Motor)
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
	Handle.Root.CanCollide = Handle.Collide
	Handle.Humanoid.RequiresNeck = true
end

return Ragdoll
