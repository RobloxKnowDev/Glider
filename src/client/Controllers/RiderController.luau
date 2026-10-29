local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GliderSeat = require(ReplicatedStorage.Shared.Utils.GliderSeat)

local RiderController = {
	Name = "RiderController",
	Priority = 8,
}

type Joints = {
	RightShoulder: Motor6D,
	LeftShoulder: Motor6D,
	RightHip: Motor6D,
	LeftHip: Motor6D,
}

type Rider = {
	Weld: Weld,
	Frame: CFrame,
	Height: number,
	Offset: number,
	Target: number?,
	Phase: number,
	Shimmy: number,
	Direction: number,
	Character: Model?,
	Joints: Joints?,
}

local Response = 12
local Raised = CFrame.Angles(math.pi, 0, 0)
local Spread = math.rad(8)
local Stride = 3
local Reach = math.rad(30)
local ShimmyResponse = 10
local Trail = math.rad(12)
local Kick = math.rad(10)

local Riders: { [Weld]: Rider } = {}

local function Approach(Current: number, Target: number, Rate: number, Dt: number): number
	return Current + (Target - Current) * (1 - math.exp(-Rate * Dt))
end

local function Pose(Joints: Joints, Rider: Rider)
	local Wave = math.sin(Rider.Phase)
	local Swing = Kick * Rider.Shimmy * Wave
	local Lag = -Rider.Direction * Trail * Rider.Shimmy
	local Stretch = Rider.Direction * Reach * Rider.Shimmy
	Joints.RightShoulder.Transform = Raised * CFrame.Angles(0, 0, Spread + Stretch * math.max(Wave, 0))
	Joints.LeftShoulder.Transform = Raised * CFrame.Angles(0, 0, Stretch * math.max(-Wave, 0) - Spread)
	Joints.RightHip.Transform = CFrame.Angles(Swing, 0, Lag)
	Joints.LeftHip.Transform = CFrame.Angles(-Swing, 0, Lag)
end

local function Rest(Joints: Joints)
	Joints.RightShoulder.Transform = CFrame.identity
	Joints.LeftShoulder.Transform = CFrame.identity
	Joints.RightHip.Transform = CFrame.identity
	Joints.LeftHip.Transform = CFrame.identity
end

function RiderController:Track(Weld: Weld): Rider
	local Existing = Riders[Weld]
	if Existing then
		return Existing
	end
	local Glider = (Weld.Parent :: Instance).Parent :: Model
	local Rider: Rider = {
		Weld = Weld,
		Frame = Glider:GetAttribute("Frame"),
		Height = Weld:GetAttribute("Height"),
		Offset = Weld:GetAttribute("Offset"),
		Target = nil,
		Phase = 0,
		Shimmy = 0,
		Direction = 1,
		Character = nil,
		Joints = nil,
	}
	Riders[Weld] = Rider
	task.spawn(function()
		if not Weld.Part1 then
			Weld:GetPropertyChangedSignal("Part1"):Wait()
		end
		local Character = (Weld.Part1 :: BasePart).Parent :: Model
		Rider.Joints = {
			RightShoulder = Character:WaitForChild("RightUpperArm"):WaitForChild("RightShoulder") :: Motor6D,
			LeftShoulder = Character:WaitForChild("LeftUpperArm"):WaitForChild("LeftShoulder") :: Motor6D,
			RightHip = Character:WaitForChild("RightUpperLeg"):WaitForChild("RightHip") :: Motor6D,
			LeftHip = Character:WaitForChild("LeftUpperLeg"):WaitForChild("LeftHip") :: Motor6D,
		}
		Rider.Character = Character
	end)
	return Rider
end

function RiderController:Steer(Rider: Rider, Offset: number)
	Rider.Target = Offset
end

function RiderController:Reset(Rider: Rider)
	Rider.Offset = Rider.Weld:GetAttribute("Offset")
	Rider.Target = nil
end

function RiderController:Init()
	local Folder = Workspace:WaitForChild("Gliders")
	local function Board(Glider: Instance)
		for _, Weld in ipairs(Glider:WaitForChild("Riders"):GetChildren()) do
			self:Track(Weld :: Weld)
		end
	end
	Folder.ChildAdded:Connect(Board)
	for _, Glider in ipairs(Folder:GetChildren()) do
		task.spawn(Board, Glider)
	end

	RunService.RenderStepped:Connect(function(Dt)
		for Weld, Rider in pairs(Riders) do
			if not Weld.Parent then
				if Rider.Joints then
					Rest(Rider.Joints)
				end
				Riders[Weld] = nil
				continue
			end
			local Offset = Rider.Target or Approach(Rider.Offset, Weld:GetAttribute("Offset"), Response, Dt)
			local Moved = Offset - Rider.Offset
			if Moved ~= 0 then
				Rider.Direction = math.sign(Moved)
			end
			Rider.Phase += math.abs(Moved) / Stride * math.pi
			Rider.Shimmy = Approach(Rider.Shimmy, if math.abs(Moved) > 0.5 * Dt then 1 else 0, ShimmyResponse, Dt)
			Rider.Offset = Offset
			Weld.C0 = GliderSeat(Rider.Frame, Rider.Height, Offset)
		end
	end)
	RunService.PreSimulation:Connect(function()
		for _, Rider in pairs(Riders) do
			if Rider.Joints then
				Pose(Rider.Joints, Rider)
			end
		end
	end)
end

return RiderController
