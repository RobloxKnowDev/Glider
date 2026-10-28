local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local GliderController = {
	Name = "GliderController",
	Priority = 10,
}

local Player = Players.LocalPlayer

local ForwardSpeed = 30
local SinkSpeed = 6
local WindLiftSpeed = 40
local LiftResponse = 6
local SinkResponse = 2
local RingBoost = 12
local BoostResponse = 1.5
local MaxBank = math.rad(30)
local TurnSpeed = math.rad(30)
local BankResponse = 3
local Deadzone = 0.1

local RiderSpeed = 10
local RiderGap = 3
local SendInterval = 0.1

local CameraDistance = 30
local CameraHeight = 12
local CameraLookAhead = 40
local CameraRoll = 0.3
local DragSpeed = math.rad(0.3)
local StickSpeed = math.rad(150)
local StickDeadzone = 0.2
local PitchLimit = math.rad(35)
local ReturnDelay = 2.5
local ReturnResponse = 3

local function Approach(Current: number, Target: number, Response: number, Dt: number): number
	return Current + (Target - Current) * (1 - math.exp(-Response * Dt))
end

function GliderController:Begin(Name: string, Start: CFrame)
	local Character = Player.Character
	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	local Head = Character:WaitForChild("Head") :: BasePart
	local Folder = Workspace:WaitForChild("Gliders")
	local Rings = Workspace:WaitForChild("RingsFolder")
	local Windzones = Workspace:WaitForChild("Windzones")
	local Glider = Folder:WaitForChild(Name) :: Model
	local Bar = Glider:WaitForChild("Bar") :: BasePart
	local Frame: CFrame = Glider:GetAttribute("Frame")
	local Unframe = Frame:Inverse()
	local Limit: number = Glider:GetAttribute("Limit")
	local Pilot = Glider:GetAttribute("Pilot") == Player.UserId

	local RiderController = Core:GetController("RiderController")
	local Seats = Glider:WaitForChild("Riders")
	local Mine = Seats:WaitForChild(tostring(Player.UserId)) :: Weld
	local Me = RiderController:Track(Mine)
	local Crew = { Me }
	for _, Weld in ipairs(Seats:GetChildren()) do
		if Weld ~= Mine then
			table.insert(Crew, RiderController:Track(Weld :: Weld))
		end
	end

	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.RespectCanCollide = true

	local Camera = Workspace.CurrentCamera
	Camera.CameraType = Enum.CameraType.Scriptable
	local Transition = Core:GetController("TransitionController")

	local Position = Start.Position
	local _, Yaw = Start:ToOrientation()
	local Bank = 0
	local Climb = -SinkSpeed
	local Boost = 0
	local Sendtimer = 0
	local OrbitYaw = 0
	local OrbitPitch = 0
	local Idle = 0
	local Stick = Vector2.zero
	local Locked = false
	local Follow: Vector3? = nil

	local function Crash()
		if Follow then
			return
		end
		Follow = Camera.CFrame.Position - Head.Position
		task.spawn(Transition.Play, Transition, Character, function()
			while self.flight do
				task.wait()
			end
			return Character
		end)
	end

	local function Orbit(Turn: number, Tilt: number)
		OrbitYaw = (OrbitYaw - Turn + math.pi) % (2 * math.pi) - math.pi
		OrbitPitch = math.clamp(OrbitPitch - Tilt, -PitchLimit, PitchLimit)
		Idle = 0
	end

	local Look = UserInputService.InputChanged:Connect(function(Input, Processed)
		if Input.UserInputType == Enum.UserInputType.MouseMovement then
			if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
				Orbit(Input.Delta.X * DragSpeed, Input.Delta.Y * DragSpeed)
			end
		elseif Input.UserInputType == Enum.UserInputType.Touch then
			if not Processed then
				Orbit(Input.Delta.X * DragSpeed, Input.Delta.Y * DragSpeed)
			end
		elseif Input.KeyCode == Enum.KeyCode.Thumbstick2 then
			Stick = Vector2.new(Input.Position.X, -Input.Position.Y)
		end
	end)

	local Loop = RunService.RenderStepped:Connect(function(Dt)
		if Follow then
			Camera.CFrame = CFrame.lookAt(Head.Position + Follow, Head.Position)
			return
		end
		if Humanoid.Health <= 0 then
			Follow = Camera.CFrame.Position - Head.Position
			return
		end

		local View = Camera.CFrame.LookVector
		local Offset = math.clamp(
			Me.Offset + Humanoid.MoveDirection:Dot(Vector3.new(-View.Z, 0, View.X).Unit) * RiderSpeed * Dt,
			-Limit,
			Limit
		)
		local Total = 0
		local Count = 1
		for _, Rider in ipairs(Crew) do
			if Rider ~= Me and Rider.Weld.Parent then
				if math.abs(Offset - Rider.Offset) < RiderGap then
					Offset = math.clamp(
						if Me.Offset < Rider.Offset then Rider.Offset - RiderGap else Rider.Offset + RiderGap,
						-Limit,
						Limit
					)
				end
				Total += Rider.Offset
				Count += 1
			end
		end
		RiderController:Steer(Me, Offset)
		Total += Offset

		local Heading
		if Pilot then
			local Balance = Total / Count / Limit
			local Lean = math.sign(Balance) * math.max(math.abs(Balance) - Deadzone, 0) / (1 - Deadzone)
			Bank = Approach(Bank, Lean * MaxBank, BankResponse, Dt)
			local Turn = Bank / MaxBank * TurnSpeed
			Yaw -= Turn * Dt
			Heading = CFrame.Angles(0, Yaw, 0)
			local Inside = false
			for _, Wind in ipairs(Windzones:GetChildren()) do
				local Zone = Wind :: BasePart
				local Local = Zone.CFrame:PointToObjectSpace(Position)
				if
					math.abs(Local.X) <= Zone.Size.X / 2
					and math.abs(Local.Y) <= Zone.Size.Y / 2
					and math.abs(Local.Z) <= Zone.Size.Z / 2
				then
					Inside = true
					break
				end
			end
			Climb = if Inside
				then Approach(Climb, WindLiftSpeed, LiftResponse, Dt)
				else Approach(Climb, -SinkSpeed, SinkResponse, Dt)
			Boost = Approach(Boost, 0, BoostResponse, Dt)
			local Velocity = Heading.LookVector * (ForwardSpeed + Boost) + Vector3.yAxis * Climb
			Position += Velocity * Dt
			Bar.CFrame = CFrame.new(Position) * Heading * CFrame.Angles(0, 0, -Bank) * Unframe
			Bar.AssemblyLinearVelocity = Velocity
			Bar.AssemblyAngularVelocity = Vector3.new(0, -Turn, 0)
		else
			local Seat = Bar.CFrame * Frame
			local Ahead = Seat.LookVector
			Position = Seat.Position
			Yaw = math.atan2(-Ahead.X, -Ahead.Z)
			Bank = math.asin(math.clamp(-Seat.RightVector.Y, -1, 1))
			Heading = CFrame.Angles(0, Yaw, 0)
		end

		Sendtimer += Dt
		if Sendtimer >= SendInterval then
			Sendtimer = 0
			Remotemanager:FireServer("GliderService", "Move", Offset)
		end

		local Dragging = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		if Dragging ~= Locked then
			Locked = Dragging
			UserInputService.MouseBehavior = if Dragging
				then Enum.MouseBehavior.LockCurrentPosition
				else Enum.MouseBehavior.Default
		end
		if Stick.Magnitude > StickDeadzone then
			Orbit(Stick.X * StickSpeed * Dt, Stick.Y * StickSpeed * Dt)
		end
		Idle += Dt
		if Idle > ReturnDelay then
			OrbitYaw = Approach(OrbitYaw, 0, ReturnResponse, Dt)
			OrbitPitch = Approach(OrbitPitch, 0, ReturnResponse, Dt)
		end
		local Rig = Heading * CFrame.Angles(0, OrbitYaw, 0) * CFrame.Angles(OrbitPitch, 0, 0)
		local Eye = Position + Rig:VectorToWorldSpace(Vector3.new(0, CameraHeight, CameraDistance))
		Camera.CFrame = CFrame.lookAt(Eye, Position + Rig.LookVector * CameraLookAhead)
			* CFrame.Angles(0, 0, -Bank * CameraRoll)

		if not Pilot then
			return
		end
		local Ghosts: { Instance } = { Folder, Rings, Windzones }
		for _, Other in ipairs(Players:GetPlayers()) do
			if Other.Character then
				table.insert(Ghosts, Other.Character)
			end
		end
		Params.FilterDescendantsInstances = Ghosts
		local Bodies: { Model } = { Glider }
		for _, Rider in ipairs(Crew) do
			if Rider.Character and Rider.Weld.Parent then
				table.insert(Bodies, Rider.Character)
			end
		end
		for _, Body in ipairs(Bodies) do
			local Box, Size = Body:GetBoundingBox()
			if #Workspace:GetPartBoundsInBox(Box, Size, Params) > 0 then
				Crash()
				Remotemanager:FireServer("GliderService", "Crash")
				return
			end
		end
	end)

	self.flight = {
		Connections = { Loop, Look },
		Crash = Crash,
		Ring = function()
			Boost = RingBoost
		end,
	}
end

function GliderController:Finish()
	local Flight = self.flight
	if not Flight then
		return
	end
	self.flight = nil
	for _, Connection in ipairs(Flight.Connections) do
		Connection:Disconnect()
	end
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

function GliderController:Init()
	local Transition = Core:GetController("TransitionController")
	Remotemanager:OnClientEvent("GliderService", "Launching", function()
		self.launching = true
		Transition:Shut(Player.Character)
	end)
	Remotemanager:OnClientEvent("GliderService", "Started", function(Name, Start)
		self.launching = false
		self:Begin(Name, Start)
		Transition:Reveal(Player.Character)
	end)
	Remotemanager:OnClientEvent("GliderService", "Crashed", function()
		if self.flight then
			self.flight.Crash()
		end
	end)
	Remotemanager:OnClientEvent("GliderService", "Ring", function()
		if self.flight then
			self.flight.Ring()
		end
	end)
	Remotemanager:OnClientEvent("GliderService", "Stopped", function()
		self:Finish()
		if self.launching then
			self.launching = false
			Transition:Reveal(Player.Character)
		end
	end)
end

return GliderController
