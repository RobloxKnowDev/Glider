local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)

local GliderController = {
	Name = "GliderController",
	Priority = 10,
}

local Player = Players.LocalPlayer

local ForwardSpeed = 30
local LevelSpeed = 5
local SinkSpeed = 6
local WindLiftSpeed = 25
local LiftResponse = 6
local SinkResponse = 2
local TurbinePush = 30
local PushResponse = 3
local DriftResponse = 1.5
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
local CrashDistance = 18
local CrashResponse = 4
local RingFieldOfView = 10
local KickInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SettleInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local LaunchVolume = 1.5
local WindVolume = 0.35
local WindMin = 0.8
local WindMax = 1.4
local GustVolume = 0.6
local BoostVolume = 0.6
local CrashVolume = 0.8
local ThudVolume = 0.7
local FinishVolume = 1.3

local function Approach(Current: number, Target: number, Response: number, Dt: number): number
	return Current + (Target - Current) * (1 - math.exp(-Response * Dt))
end

local function Within(Zone: BasePart, Point: Vector3): boolean
	local Local = Zone.CFrame:PointToObjectSpace(Point)
	return math.abs(Local.X) <= Zone.Size.X / 2
		and math.abs(Local.Y) <= Zone.Size.Y / 2
		and math.abs(Local.Z) <= Zone.Size.Z / 2
end

function GliderController:Begin(Name: string, Start: CFrame)
	local Character = Player.Character
	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	local Head = Character:WaitForChild("Head") :: BasePart
	local Root = Character:WaitForChild("HumanoidRootPart") :: BasePart
	local Folder = Workspace:WaitForChild("Gliders")
	local Rings = Workspace:WaitForChild("RingsFolder")
	local Windzones = Workspace:WaitForChild("Windzones")
	local TurbineZones = Workspace:WaitForChild("WindTurbineZones")
	local Glider = Folder:WaitForChild(Name) :: Model
	local Bar = Glider:WaitForChild("Bar") :: BasePart
	local Frame: CFrame = Glider:GetAttribute("Frame")
	local Unframe = Frame:Inverse()
	local Limit: number = Glider:GetAttribute("Limit")
	local Pilot = Glider:GetAttribute("Pilot") == Player.UserId

	local SceneryController = Core:GetController("SceneryController")
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
	for _, Rider in ipairs(Crew) do
		RiderController:Reset(Rider)
	end

	local Near = OverlapParams.new()
	Near.FilterType = Enum.RaycastFilterType.Exclude
	Near.RespectCanCollide = true
	local Touch = OverlapParams.new()
	Touch.FilterType = Enum.RaycastFilterType.Include
	Touch.RespectCanCollide = true
	local Hull: { BasePart } = {}
	for _, Part in ipairs(Glider:GetDescendants()) do
		if Part:IsA("BasePart") and Part.Transparency < 1 then
			table.insert(Hull, Part)
		end
	end

	local Camera = Workspace.CurrentCamera
	Camera.CameraType = Enum.CameraType.Scriptable

	local Position = Start.Position
	local _, Yaw = Start:ToOrientation()
	local Bank = 0
	local Climb = -SinkSpeed
	local Drift = Vector3.zero
	local Boost = 0
	local Sendtimer = 0
	local OrbitYaw = 0
	local OrbitPitch = 0
	local Idle = 0
	local Stick = Vector2.zero
	local Locked = false
	local Follow: Vector3? = nil
	local Watch = Vector3.zero
	local Gusting = false
	local Wind = Sfx.Loop(Sounds.Flight.Wind, WindVolume)
	Sfx.Play(Sounds.Flight.Launch, LaunchVolume)

	local function Crash()
		if Follow then
			return
		end
		Watch = Camera.CFrame.Position
		Follow = (Watch - Head.Position).Unit * CrashDistance
		Locked = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		Wind:Stop()
		Sfx.Play(Sounds.Flight.Crash, CrashVolume)
		Sfx.Play(Sounds.Flight.Thud, ThudVolume)
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
			Watch = Watch:Lerp(Head.Position + Follow, 1 - math.exp(-CrashResponse * Dt))
			Camera.CFrame = CFrame.lookAt(Watch, Head.Position)
			return
		end
		if self.launching then
			return
		end
		SceneryController:Aim(Root.Position.Y)

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

		local Inside = false
		for _, Zone in ipairs(Windzones:GetChildren()) do
			if Within(Zone :: BasePart, Position) then
				Inside = true
				break
			end
		end
		local Push: Vector3? = nil
		for _, Child in ipairs(TurbineZones:GetChildren()) do
			local Zone = Child :: BasePart
			if Within(Zone, Position) then
				Push = Zone.CFrame.LookVector * TurbinePush
				break
			end
		end
		local Blowing = Inside or Push ~= nil
		if Blowing and not Gusting then
			Sfx.Play(Sounds.Flight.Gust, GustVolume)
		end
		Gusting = Blowing

		local Heading
		if Pilot then
			local Balance = math.clamp(Total / Count / (Limit - (Count - 1) * RiderGap / 2), -1, 1)
			local Lean = math.sign(Balance) * math.max(math.abs(Balance) - Deadzone, 0) / (1 - Deadzone)
			Bank = Approach(Bank, Lean * MaxBank, BankResponse, Dt)
			local Turn = Bank / MaxBank * TurnSpeed
			Yaw -= Turn * Dt
			Heading = CFrame.Angles(0, Yaw, 0)
			Climb = if Inside
				then Approach(Climb, WindLiftSpeed, LiftResponse, Dt)
				else Approach(Climb, -SinkSpeed, SinkResponse, Dt)
			Drift = if Push
				then Drift:Lerp(Push, 1 - math.exp(-PushResponse * Dt))
				else Drift:Lerp(Vector3.zero, 1 - math.exp(-DriftResponse * Dt))
			Boost = Approach(Boost, 0, BoostResponse, Dt)
			local Speed = ForwardSpeed + (Glider:GetAttribute("Level") - 1) * LevelSpeed
			local Velocity = Heading.LookVector * (Speed + Boost) + Vector3.yAxis * Climb + Drift
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

		local Rush = math.clamp(Bar.AssemblyLinearVelocity.Magnitude / ForwardSpeed, WindMin, WindMax)
		Wind.Volume = WindVolume * Rush
		Wind.PlaybackSpeed = Rush

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
		SceneryController:Pose()
		local Ghosts: { Instance } = { Folder, Rings, Windzones, TurbineZones }
		for _, Other in ipairs(Players:GetPlayers()) do
			if Other.Character then
				table.insert(Ghosts, Other.Character)
			end
		end
		Near.FilterDescendantsInstances = Ghosts
		local Bodies: { Model } = { Glider }
		local Shapes = table.clone(Hull)
		for _, Rider in ipairs(Crew) do
			if Rider.Character and Rider.Weld.Parent then
				table.insert(Bodies, Rider.Character)
				for _, Part in ipairs(Rider.Character:GetChildren()) do
					if Part:IsA("BasePart") and Part.Transparency < 1 then
						table.insert(Shapes, Part)
					end
				end
			end
		end
		local Obstacles: { Instance } = {}
		for _, Body in ipairs(Bodies) do
			local Box, Size = Body:GetBoundingBox()
			for _, Part in ipairs(Workspace:GetPartBoundsInBox(Box, Size, Near)) do
				if Part.Transparency < 1 then
					table.insert(Obstacles, Part)
				end
			end
		end
		if #Obstacles == 0 then
			return
		end
		Touch.FilterDescendantsInstances = Obstacles
		for _, Part in ipairs(Shapes) do
			if #Workspace:GetPartsInPart(Part, Touch) > 0 then
				Crash()
				Remotemanager:FireServer("GliderService", "Crash")
				return
			end
		end
	end)

	local Died = Humanoid.Died:Connect(function()
		self:Finish()
	end)

	self.flight = {
		Connections = { Loop, Look, Died },
		Wind = Wind,
		Crash = Crash,
		Ring = function()
			Boost = RingBoost
			Sfx.Play(Sounds.Flight.Boost, BoostVolume)
			self:Kick()
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
	Flight.Wind:Destroy()
	Core:GetController("SceneryController"):Aim(nil)
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

function GliderController:Kick()
	local Camera = Workspace.CurrentCamera
	local Kick = TweenService:Create(Camera, KickInfo, { FieldOfView = self.fieldOfView + RingFieldOfView })
	Kick.Completed:Once(function(State)
		if State == Enum.PlaybackState.Completed then
			TweenService:Create(Camera, SettleInfo, { FieldOfView = self.fieldOfView }):Play()
		end
	end)
	Kick:Play()
end

function GliderController:Init()
	self.fieldOfView = Workspace.CurrentCamera.FieldOfView
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
	Remotemanager:OnClientEvent("GliderService", "Revived", function(Name, Start)
		self.launching = false
		self:Finish()
		self:Begin(Name, Start)
		Transition:Reveal(Player.Character)
	end)
	Remotemanager:OnClientEvent("GliderService", "Respawning", function()
		local Character = Player.Character
		Transition:Play(Character, function()
			while self.flight do
				task.wait()
			end
			return Character
		end)
	end)
	Remotemanager:OnClientEvent("GliderService", "Ring", function()
		if self.flight then
			self.flight.Ring()
		end
	end)
	Remotemanager:OnClientEvent("GliderService", "Finished", function()
		Sfx.Play(Sounds.Flight.Finish, FinishVolume)
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
