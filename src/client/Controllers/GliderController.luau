local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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
local WindLiftSpeed = 20
local LiftResponse = 6
local SinkResponse = 2
local TurbinePush = 30
local PushResponse = 3
local DriftResponse = 1.5
local RingBoost = 12
local BoostResponse = 1.5
local BirdPush = 80
local KnockResponse = 0.75
local KnockGrace = 1
local TornadoLift = 35
local TornadoPush = 120
local TossGrace = 1.5
local RollTime = 1.2
local RollStyle = Enum.EasingStyle.Quad
local BlizzardPush = 110
local GaleResponse = 6
local BlizzardSway = math.rad(24)
local BlizzardNod = math.rad(9)
local BlizzardFlutter = 13
local FlutterRatio = 0.57
local SwayResponse = 6
local CameraShake = math.rad(2.5)
local MaxBank = math.rad(30)
local TurnSpeed = math.rad(45)
local BankResponse = 3
local Deadzone = 0.1

local RiderSpeed = 10
local CenterSpeed = 6
local RiderGap = 3
local SendInterval = 0.1

local CameraDistance = 30
local CameraHeight = 12
local CameraLookAhead = 40
local CameraRoll = 0.3
local CrashDistance = 18
local CrashResponse = 4
local BodyGrace = 1
local RingFieldOfView = 10
local KickInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SettleInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local LaunchVolume = 1.5
local WindVolume = 0.5
local WindMin = 0.8
local WindMax = 1.4
local GustVolume = 0.6
local BoostVolume = 0.6
local CrashVolume = 0.8
local ThudVolume = 0.7
local BirdVolume = 0.7
local TornadoVolume = 0.38
local TornadoStart = 0.3
local FinishVolume = 1.3
local Flat = Vector3.new(1, 0, 1)

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
	local Walls = Workspace:WaitForChild("InvisibleWalls")
	local Birds = Workspace:WaitForChild("BirdsZones")
	local Tornadoes = Workspace:WaitForChild("TornadoZone")
	local Glider = Folder:WaitForChild(Name) :: Model
	local Bar = Glider:WaitForChild("Bar") :: BasePart
	local Frame: CFrame = Glider:GetAttribute("Frame")
	local Unframe = Frame:Inverse()
	local Limit: number = Glider:GetAttribute("Limit")
	local Pilot = Glider:GetAttribute("Pilot") == Player.UserId

	local SceneryController = Core:GetController("SceneryController")
	local BlizzardController = Core:GetController("BlizzardController")
	local RiderController = Core:GetController("RiderController")
	local ArrowController = Core:GetController("ArrowController")
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
	local Partner = Crew[2]
	local Toward = if Partner then math.sign(Partner.Offset - Me.Offset) else 0
	local Rest = -Toward * math.min(RiderGap, Limit)

	local Near = OverlapParams.new()
	Near.FilterType = Enum.RaycastFilterType.Exclude
	Near.RespectCanCollide = true
	local Touch = OverlapParams.new()
	Touch.FilterType = Enum.RaycastFilterType.Include
	Touch.RespectCanCollide = true
	local Flock = OverlapParams.new()
	Flock.FilterType = Enum.RaycastFilterType.Include
	Flock.FilterDescendantsInstances = { Birds }
	local Twister = OverlapParams.new()
	Twister.FilterType = Enum.RaycastFilterType.Include
	Twister.FilterDescendantsInstances = { Tornadoes }
	local Hull: { BasePart } = {}
	for _, Part in ipairs(Glider:GetDescendants()) do
		if Part:IsA("BasePart") and Part.Transparency < 1 then
			table.insert(Hull, Part)
		end
	end

	local Camera = Workspace.CurrentCamera
	Camera.CameraType = Enum.CameraType.Scriptable

	local Position = Start.Position
	local Settle = os.clock() + BodyGrace
	local _, Yaw = Start:ToOrientation()
	local Bank = 0
	local Climb = -SinkSpeed
	local Drift = Vector3.zero
	local Boost = 0
	local Recoil = 0
	local Calm = 0
	local Pecked = false
	local Shove = BirdPush
	local Roll = 0
	local Tossed = -math.huge
	local Spun = false
	local Flutter = 0
	local Stormed = false
	local Sendtimer = 0
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
		Wind:Stop()
		Sfx.Play(Sounds.Flight.Crash, CrashVolume)
		Sfx.Play(Sounds.Flight.Thud, ThudVolume)
	end

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
		local Side = math.clamp(
			Humanoid.MoveDirection:Dot(Vector3.new(-View.Z, 0, View.X).Unit) + ArrowController:Direction(),
			-1,
			1
		)
		local Step = if Side ~= 0
			then Side * RiderSpeed * Dt
			else math.clamp(Rest - Me.Offset, -CenterSpeed * Dt, CenterSpeed * Dt)
		local Offset = math.clamp(Me.Offset + Step, -Limit, Limit)
		local Total = 0
		local Count = 1
		if Partner and Partner.Weld.Parent then
			local Pushing = Side * Toward > 0 and Partner.Weld:GetAttribute("Push") * Toward >= 0
			if not Pushing and (Partner.Offset - Offset) * Toward < RiderGap then
				Offset = Partner.Offset - Toward * RiderGap
			end
			Offset = if Toward > 0
				then math.clamp(Offset, -Limit, Limit - RiderGap)
				else math.clamp(Offset, RiderGap - Limit, Limit)
			local Edge = Offset + Toward * RiderGap
			if Toward > 0 then
				RiderController:Keep(Partner, Edge, Limit)
			else
				RiderController:Keep(Partner, -Limit, Edge)
			end
			Total = Partner.Offset
			Count = 2
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
		local Gale: Vector3? = BlizzardController:Gust(Position)
		if Gale then
			Push = (Push or Vector3.zero) + Gale * BlizzardPush
		end
		if Gale and not Stormed then
			self:Kick()
		end
		Stormed = Gale ~= nil
		Flutter = Approach(Flutter, if Gale then Gale.Magnitude else 0, SwayResponse, Dt)
		local Beat = os.clock() * BlizzardFlutter
		local Sway = Flutter * (math.sin(Beat) + math.sin(Beat * FlutterRatio)) / 2
		local Jolt = Flutter * CameraShake
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
				then Drift:Lerp(Push, 1 - math.exp(-(if Gale then GaleResponse else PushResponse) * Dt))
				else Drift:Lerp(Vector3.zero, 1 - math.exp(-DriftResponse * Dt))
			Boost = Approach(Boost, 0, BoostResponse, Dt)
			Recoil = Approach(Recoil, 0, KnockResponse, Dt)
			local Speed = ForwardSpeed + (Glider:GetAttribute("Level") - 1) * LevelSpeed
			local Forward = (Speed + Boost) * (1 - Recoil) - Shove * Recoil
			local Velocity = Heading.LookVector * Forward + Vector3.yAxis * Climb + Drift
			Position += Velocity * Dt
			local Spin = math.min((os.clock() - Tossed) / RollTime, 1)
			local Flip = Roll * 2 * math.pi * TweenService:GetValue(Spin, RollStyle, Enum.EasingDirection.Out)
			local Nod = Flutter * BlizzardNod * math.cos(Beat * FlutterRatio)
			Bar.CFrame = CFrame.new(Position)
				* Heading
				* CFrame.Angles(Nod, 0, -Bank - Flip - Sway * BlizzardSway)
				* Unframe
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
			Remotemanager:FireServer("GliderService", "Move", Offset, math.sign(Side))
		end

		local Eye = Position + Heading:VectorToWorldSpace(Vector3.new(0, CameraHeight, CameraDistance))
		Camera.CFrame = CFrame.lookAt(Eye, Position + Heading.LookVector * CameraLookAhead)
			* CFrame.Angles(
				Jolt * math.sin(Beat * FlutterRatio),
				Jolt * math.cos(Beat),
				-Bank * CameraRoll + Jolt * math.sin(Beat)
			)

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
		local Settled = os.clock() >= Settle
		for _, Rider in ipairs(Crew) do
			if Settled and Rider.Character and Rider.Weld.Parent then
				table.insert(Bodies, Rider.Character)
				for _, Part in ipairs(Rider.Character:GetChildren()) do
					if Part:IsA("BasePart") and Part.Transparency < 1 then
						table.insert(Shapes, Part)
					end
				end
			end
		end
		local Obstacles: { Instance } = {}
		local Close = false
		local Swept = false
		for _, Body in ipairs(Bodies) do
			local Box, Size = Body:GetBoundingBox()
			for _, Part in ipairs(Workspace:GetPartBoundsInBox(Box, Size, Near)) do
				if Part.Transparency < 1 or Part.Parent == Walls then
					table.insert(Obstacles, Part)
				end
			end
			Close = Close or #Workspace:GetPartBoundsInBox(Box, Size, Flock) > 0
			Swept = Swept or #Workspace:GetPartBoundsInBox(Box, Size, Twister) > 0
		end
		local Touching = false
		if Close then
			for _, Part in ipairs(Shapes) do
				if #Workspace:GetPartsInPart(Part, Flock) > 0 then
					Touching = true
					break
				end
			end
		end
		if Touching and not Pecked and os.clock() >= Calm then
			Recoil = 1
			Shove = BirdPush
			Calm = os.clock() + KnockGrace
			Sfx.Play(Sounds.Flight.Bird, BirdVolume)
		end
		Pecked = Touching
		local Caught: BasePart? = nil
		if Swept then
			for _, Part in ipairs(Shapes) do
				Caught = Workspace:GetPartsInPart(Part, Twister)[1]
				if Caught then
					break
				end
			end
		end
		if Caught and not Spun and os.clock() >= Tossed + TossGrace then
			local Away = (Position - SceneryController:Eye(Caught)) * Flat
			Recoil = 1
			Shove = TornadoPush
			Climb = math.max(Climb, TornadoLift)
			Roll = math.sign(Away:Dot(Heading.RightVector))
			Tossed = os.clock()
			Sfx.Play(Sounds.Flight.Tornado, TornadoVolume, 1, TornadoStart)
			self:Kick()
		end
		Spun = Caught ~= nil
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
		Connections = { Loop, Died },
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
