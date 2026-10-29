local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local GliderFrame = require(ReplicatedStorage.Shared.Utils.GliderFrame)
local GliderSeat = require(ReplicatedStorage.Shared.Utils.GliderSeat)
local Ragdoll = require(script.Parent.Parent.Utils.Ragdoll)

local GliderService = {
	Name = "GliderService",
	Priority = 10,
	Remotes = {
		Play = "Event",
		Move = "Event",
		Crash = "Event",
		Revive = "Event",
		Continue = "Event",
		Launching = "Event",
		Started = "Event",
		Crashed = "Event",
		Countdown = "Event",
		Revived = "Event",
		Respawning = "Event",
		Stopped = "Event",
		Ring = "Event",
	},
}

type Ring = {
	Model: Model,
	Frame: CFrame,
	Axis: Vector3,
	Radius: number,
}

type Rider = {
	Weld: Weld,
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Height: number,
	Ragdoll: Ragdoll.Handle?,
}

type Sample = {
	Time: number,
	Frame: CFrame,
}

type Flight = {
	Glider: Model,
	Bar: BasePart,
	Frame: CFrame,
	Limit: number,
	Last: Vector3,
	Collected: { [Model]: boolean },
	Crashed: boolean,
	Pilot: Player,
	History: { Sample },
	Deciding: boolean,
	Deadline: number?,
	Remaining: number,
	Buyer: Player?,
	Riders: { [Player]: Rider },
	Connections: { RBXScriptConnection },
}

local Flights: { [Player]: Flight } = {}
local Pending: { [Player]: boolean } = {}
local Active: { [Flight]: boolean } = {}
local Single = Store.Revive[1]
local LaunchDelay = 0.7
local RespawnTime = 2
local VoidMargin = 60
local ReviveTime = 10
local ResumeTime = 3
local RewindTime = 3
local ScanDirections = 24
local ScanDistance = 300
local ScanDrop = 0.2
local ScanBias = 40
local Flat = Vector3.new(1, 0, 1)
local HistoryInterval = 0.2
local RiderGap = 3
local RiderMargin = 1.5
local SpawnSpacing = 4

local function Finite(Value: any): boolean
	return type(Value) == "number" and Value == Value and math.abs(Value) ~= math.huge
end

local function Alive(Player: Player): boolean
	local Character = Player.Character
	return Player.Parent == Players and Character ~= nil and (Character:WaitForChild("Humanoid") :: Humanoid).Health > 0
end

local function Grip(Character: Model): number
	local RootJoint = Character:WaitForChild("LowerTorso"):WaitForChild("Root") :: Motor6D
	local Waist = Character:WaitForChild("UpperTorso"):WaitForChild("Waist") :: Motor6D
	local Shoulder = Character:WaitForChild("RightUpperArm"):WaitForChild("RightShoulder") :: Motor6D
	local Elbow = Character:WaitForChild("RightLowerArm"):WaitForChild("RightElbow") :: Motor6D
	local Wrist = Character:WaitForChild("RightHand"):WaitForChild("RightWrist") :: Motor6D
	local Pivot = RootJoint.C0 * RootJoint.C1:Inverse() * Waist.C0 * Waist.C1:Inverse() * Shoulder.C0
	local Hand = Pivot * Shoulder.C1:Inverse() * Elbow.C0 * Elbow.C1:Inverse() * Wrist.C0 * Wrist.C1:Inverse()
	return 2 * Pivot.Y - Hand.Y
end

local function Facing(Part: BasePart, Lift: number): CFrame
	local Look = Part.CFrame.LookVector
	return CFrame.new(Part.Position + Vector3.yAxis * Lift) * CFrame.Angles(0, math.atan2(-Look.X, -Look.Z), 0)
end

local function Spread(Index: number, Count: number, Limit: number): number
	return (2 * Index - Count - 1) * math.min(RiderGap, Limit)
end

local function Freeze(Model: Model, Anchored: boolean)
	for _, Part in ipairs(Model:GetDescendants()) do
		if Part:IsA("BasePart") then
			Part.Anchored = Anchored
		end
	end
end

local function Measure(Model: Model): Ring
	local Frame, Size = Model:GetBoundingBox()
	if Size.X <= Size.Y and Size.X <= Size.Z then
		return { Model = Model, Frame = Frame, Axis = Vector3.xAxis, Radius = math.min(Size.Y, Size.Z) / 2 }
	elseif Size.Y <= Size.Z then
		return { Model = Model, Frame = Frame, Axis = Vector3.yAxis, Radius = math.min(Size.X, Size.Z) / 2 }
	end
	return { Model = Model, Frame = Frame, Axis = Vector3.zAxis, Radius = math.min(Size.X, Size.Y) / 2 }
end

function GliderService:IsFlying(Player: Player): boolean
	return Flights[Player] ~= nil or Pending[Player] ~= nil
end

function GliderService:Launch(Team: { Player })
	for _, Player in ipairs(Team) do
		if self:IsFlying(Player) or not Alive(Player) then
			return
		end
	end
	for _, Player in ipairs(Team) do
		Pending[Player] = true
		Player:SetAttribute("Flying", true)
		Remotemanager:FireClient(self.Name, "Launching", Player)
	end
	task.wait(LaunchDelay)
	local Ready = true
	for _, Player in ipairs(Team) do
		Pending[Player] = nil
		Ready = Ready and Alive(Player)
	end
	if not Ready then
		for _, Player in ipairs(Team) do
			if Player.Parent == Players then
				Player:SetAttribute("Flying", nil)
				Remotemanager:FireClient(self.Name, "Stopped", Player)
			end
		end
		return
	end

	local Host = Team[1]
	local Start = Facing(self.spawn, 0)
	local Inventory = Core:GetService("InventoryService")
	local Glider = (self.models:WaitForChild(Inventory:GetEquipped(Host, "Gliders")) :: Model):Clone()
	local Bar = Glider:WaitForChild("Bar") :: BasePart
	local Frame = GliderFrame(Bar)
	local Limit = math.max(Bar.Size.X, Bar.Size.Y, Bar.Size.Z) / 2 - RiderMargin
	Core:GetService("TrailService"):Attach(Bar, Frame, Inventory:GetEquipped(Host, "Trails"))
	Glider:PivotTo(Start * Frame:Inverse() * Bar.CFrame:ToObjectSpace(Glider:GetPivot()))
	for _, Part in ipairs(Glider:GetDescendants()) do
		if Part:IsA("BasePart") and Part ~= Bar then
			local Joint = Instance.new("WeldConstraint")
			Joint.Part0 = Bar
			Joint.Part1 = Part
			Joint.Parent = Part
		end
	end
	Bar.RootPriority = 127
	Glider.PrimaryPart = Bar
	Glider.Name = tostring(Host.UserId)
	Glider.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	Glider:SetAttribute("Frame", Frame)
	Glider:SetAttribute("Limit", Limit)
	Glider:SetAttribute("Pilot", Host.UserId)

	local Seats = Instance.new("Folder")
	Seats.Name = "Riders"
	Seats.Parent = Glider

	local Flight: Flight = {
		Glider = Glider,
		Bar = Bar,
		Frame = Frame,
		Limit = Limit,
		Last = Start.Position,
		Collected = {},
		Crashed = false,
		Pilot = Host,
		History = { { Time = os.clock(), Frame = Start } },
		Deciding = false,
		Deadline = nil,
		Remaining = 0,
		Buyer = nil,
		Riders = {},
		Connections = {},
	}
	for Index, Player in ipairs(Team) do
		local Character = Player.Character :: Model
		local Root = Character:WaitForChild("HumanoidRootPart") :: BasePart
		local Height = -Grip(Character)
		local Offset = Spread(Index, #Team, Limit)
		local Weld = Instance.new("Weld")
		Weld.Name = tostring(Player.UserId)
		Weld.Part0 = Bar
		Weld.Part1 = Root
		Weld.C0 = GliderSeat(Frame, Height, Offset)
		Weld:SetAttribute("Height", Height)
		Weld:SetAttribute("Offset", Offset)
		Weld.Parent = Seats
		Flight.Riders[Player] = {
			Weld = Weld,
			Character = Character,
			Humanoid = Character:WaitForChild("Humanoid") :: Humanoid,
			Root = Root,
			Height = Height,
			Ragdoll = nil,
		}
	end

	Glider.Parent = self.folder
	for _, Part in ipairs(Glider:GetDescendants()) do
		if Part:IsA("BasePart") then
			Part.Anchored = false
		end
	end
	Bar:SetNetworkOwner(Host)
	Active[Flight] = true

	for Player, Rider in pairs(Flight.Riders) do
		Rider.Humanoid.PlatformStand = true
		Flights[Player] = Flight
		table.insert(
			Flight.Connections,
			Player.CharacterRemoving:Connect(function()
				self:Leave(Player)
			end)
		)
		table.insert(
			Flight.Connections,
			Rider.Humanoid.Died:Connect(function()
				self:Leave(Player)
			end)
		)
		Remotemanager:FireClient(self.Name, "Started", Player, Glider.Name, Start, self.finish.Position)
	end
end

function GliderService:Move(Player: Player, Offset: any)
	local Flight = Flights[Player]
	if not Flight or Flight.Crashed or not Finite(Offset) then
		return
	end
	self:Place(Flight, Flight.Riders[Player], math.clamp(Offset, -Flight.Limit, Flight.Limit))
end

function GliderService:Place(Flight: Flight, Rider: Rider, Offset: number)
	Rider.Weld.C0 = GliderSeat(Flight.Frame, Rider.Height, Offset)
	Rider.Weld:SetAttribute("Offset", Offset)
end

function GliderService:Center(Flight: Flight)
	local Order: { Rider } = {}
	for _, Rider in pairs(Flight.Riders) do
		table.insert(Order, Rider)
	end
	table.sort(Order, function(A, B)
		return A.Weld:GetAttribute("Offset") < B.Weld:GetAttribute("Offset")
	end)
	for Index, Rider in ipairs(Order) do
		self:Place(Flight, Rider, Spread(Index, #Order, Flight.Limit))
	end
end

function GliderService:Aim(Position: Vector3, Radius: number): CFrame
	local Ignored = table.clone(self.ghosts)
	for _, Player in ipairs(Players:GetPlayers()) do
		if Player.Character then
			table.insert(Ignored, Player.Character)
		end
	end
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = Ignored
	Params.RespectCanCollide = true

	local Toward = ((self.finish.Position - Position) * Flat).Unit
	local Best, Score = 0, -math.huge
	for Index = 1, ScanDirections do
		local Yaw = Index / ScanDirections * 2 * math.pi
		local Ahead = CFrame.Angles(0, Yaw, 0).LookVector
		local Hit = Workspace:Spherecast(Position, Radius, (Ahead - Vector3.yAxis * ScanDrop).Unit * ScanDistance, Params)
		local Value = (if Hit then Hit.Distance else ScanDistance) + ScanBias * Ahead:Dot(Toward)
		if Value > Score then
			Best, Score = Yaw, Value
		end
	end
	return CFrame.new(Position) * CFrame.Angles(0, Best, 0)
end

function GliderService:Collect(Flight: Flight)
	local Position = Flight.Bar.Position
	for _, Ring in ipairs(self.rings) do
		if not Flight.Collected[Ring.Model] then
			local Before = Ring.Frame:PointToObjectSpace(Flight.Last)
			local After = Ring.Frame:PointToObjectSpace(Position)
			local A = Before:Dot(Ring.Axis)
			local B = After:Dot(Ring.Axis)
			if (A < 0) ~= (B < 0) then
				local Hit = Before:Lerp(After, A / (A - B))
				if (Hit - Ring.Axis * Hit:Dot(Ring.Axis)).Magnitude <= Ring.Radius then
					Flight.Collected[Ring.Model] = true
					for Player in pairs(Flight.Riders) do
						Core:GetService("StudsService"):Add(Player, Ring.Model:GetAttribute("Reward"))
						Remotemanager:FireClient(self.Name, "Ring", Player, Ring.Model)
					end
				end
			end
		end
	end
	Flight.Last = Position
end

function GliderService:Record(Flight: Flight, Now: number)
	local History = Flight.History
	if Now - History[#History].Time < HistoryInterval then
		return
	end
	table.insert(History, { Time = Now, Frame = Flight.Bar.CFrame * Flight.Frame })
	while Now - History[1].Time > RewindTime do
		table.remove(History, 1)
	end
end

function GliderService:Crash(Flight: Flight, Final: boolean)
	if Flight.Crashed then
		if Final and Flight.Deciding then
			self:Respawn(Flight)
		end
		return
	end
	Flight.Crashed = true
	for Player, Rider in pairs(Flight.Riders) do
		Rider.Weld.Enabled = false
		Rider.Ragdoll = Ragdoll.Enable(Rider.Character)
		Remotemanager:FireClient(self.Name, "Crashed", Player)
	end
	if Final then
		self:Respawn(Flight)
		return
	end
	Flight.Deciding = true
	Flight.Deadline = os.clock() + ReviveTime
	self:Countdown(Flight)
end

function GliderService:Wreck(Player: Player)
	local Flight = Flights[Player]
	if Flight then
		self:Crash(Flight, true)
	end
end

function GliderService:Guard(Flight: Flight)
	local Floor = Workspace.FallenPartsDestroyHeight + VoidMargin
	if not Flight.Bar.Anchored and Flight.Bar.Position.Y < Floor then
		Freeze(Flight.Glider, true)
	end
	for _, Rider in pairs(Flight.Riders) do
		if not Rider.Root.Anchored and Rider.Root.Position.Y < Floor then
			Freeze(Rider.Character, true)
		end
	end
end

function GliderService:Countdown(Flight: Flight)
	local Remaining = if Flight.Deadline then Flight.Deadline - os.clock() else Flight.Remaining
	for Player in pairs(Flight.Riders) do
		Remotemanager:FireClient(self.Name, "Countdown", Player, Remaining, Flight.Deadline == nil, Flight.Pilot)
	end
end

function GliderService:Pause(Flight: Flight)
	Flight.Remaining = (Flight.Deadline :: number) - os.clock()
	Flight.Deadline = nil
	self:Countdown(Flight)
end

function GliderService:Resume(Flight: Flight)
	if not Flight.Deciding or Flight.Deadline then
		return
	end
	Flight.Deadline = os.clock() + math.max(Flight.Remaining, ResumeTime)
	self:Countdown(Flight)
end

function GliderService:UseRevive(Player: Player)
	local Flight = Flights[Player]
	if
		not Flight
		or Flight.Pilot ~= Player
		or not Flight.Deciding
		or not Core:GetService("DataService"):IsLoaded(Player)
	then
		return
	end
	if Core:GetService("ReviveService"):Use(Player) then
		self:Revive(Flight)
	elseif not Flight.Buyer then
		Flight.Buyer = Player
		self:Pause(Flight)
		Core:GetService("StoreService"):Buy(Player, "Revive", Single.Name)
	end
end

function GliderService:Refilled(Player: Player)
	local Flight = Flights[Player]
	if Flight and Flight.Buyer == Player then
		Flight.Buyer = nil
		task.spawn(self.UseRevive, self, Player)
	end
end

function GliderService:Continue(Player: Player)
	local Flight = Flights[Player]
	if not Flight or Flight.Pilot ~= Player or not Flight.Deciding then
		return
	end
	self:Respawn(Flight)
end

function GliderService:Revive(Flight: Flight)
	Flight.Deciding = false
	Flight.Buyer = nil
	for Player in pairs(Flight.Riders) do
		Remotemanager:FireClient(self.Name, "Launching", Player)
	end
	task.wait(LaunchDelay)
	if not Active[Flight] then
		return
	end

	local Start = self:Aim(Flight.History[1].Frame.Position, Flight.Limit + RiderMargin)
	Freeze(Flight.Glider, false)
	Flight.Glider:PivotTo(Start * Flight.Frame:Inverse() * Flight.Bar.CFrame:ToObjectSpace(Flight.Glider:GetPivot()))
	Flight.Bar.AssemblyLinearVelocity = Vector3.zero
	Flight.Bar.AssemblyAngularVelocity = Vector3.zero
	for _, Rider in pairs(Flight.Riders) do
		Ragdoll.Disable(Rider.Ragdoll :: Ragdoll.Handle)
		Rider.Ragdoll = nil
		Freeze(Rider.Character, false)
		Rider.Weld.Enabled = true
	end
	self:Center(Flight)
	Flight.Bar:SetNetworkOwner(Flight.Pilot)
	Flight.Last = Start.Position
	Flight.History = { { Time = os.clock(), Frame = Start } }
	Flight.Crashed = false
	for Player in pairs(Flight.Riders) do
		Remotemanager:FireClient(self.Name, "Revived", Player, Flight.Glider.Name, Start)
	end
end

function GliderService:Respawn(Flight: Flight)
	Flight.Deciding = false
	Flight.Buyer = nil
	for Player in pairs(Flight.Riders) do
		Remotemanager:FireClient(self.Name, "Respawning", Player)
	end
	task.delay(RespawnTime, function()
		if Active[Flight] then
			self:Recover(Flight)
		end
	end)
end

function GliderService:Recover(Flight: Flight)
	local Count = 0
	for _ in pairs(Flight.Riders) do
		Count += 1
	end
	local Index = 0
	for _, Rider in pairs(Flight.Riders) do
		Index += 1
		Ragdoll.Disable(Rider.Ragdoll :: Ragdoll.Handle)
		Freeze(Rider.Character, false)
		local Spot = Facing(self.respawn, self.respawn.Size.Y / 2 + Rider.Humanoid.HipHeight + Rider.Root.Size.Y / 2)
		Rider.Character:PivotTo(Spot * CFrame.new((Index - (Count + 1) / 2) * SpawnSpacing, 0, 0))
		Rider.Root.AssemblyLinearVelocity = Vector3.zero
		Rider.Root.AssemblyAngularVelocity = Vector3.zero
	end
	self:Stop(Flight)
end

function GliderService:Stop(Flight: Flight)
	if not Active[Flight] then
		return
	end
	Active[Flight] = nil
	for _, Connection in ipairs(Flight.Connections) do
		Connection:Disconnect()
	end
	for Player, Rider in pairs(Flight.Riders) do
		Flights[Player] = nil
		Player:SetAttribute("Flying", nil)
		Rider.Humanoid.PlatformStand = false
		Remotemanager:FireClient(self.Name, "Stopped", Player)
	end
	Flight.Glider:Destroy()
end

function GliderService:Leave(Player: Player)
	local Flight = Flights[Player]
	if not Flight then
		return
	end
	local Rider = Flight.Riders[Player]
	Flight.Riders[Player] = nil
	Flights[Player] = nil
	Player:SetAttribute("Flying", nil)
	Rider.Weld:Destroy()
	Remotemanager:FireClient(self.Name, "Stopped", Player)
	if not next(Flight.Riders) then
		self:Stop(Flight)
		return
	end
	self:Crash(Flight, true)
end

function GliderService:Init()
	Players.RespawnTime = RespawnTime
	self.models = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Glider")

	self.folder = Instance.new("Folder")
	self.folder.Name = "Gliders"
	self.folder.Parent = Workspace

	Remotemanager:OnServerEvent(self.Name, "Play", function(Player)
		self:Launch({ Player })
	end)
	Remotemanager:OnServerEvent(self.Name, "Move", function(Player, Offset)
		self:Move(Player, Offset)
	end)
	Remotemanager:OnServerEvent(self.Name, "Crash", function(Player)
		local Flight = Flights[Player]
		if Flight then
			self:Crash(Flight, false)
		end
	end)
	Remotemanager:OnServerEvent(self.Name, "Revive", function(Player)
		self:UseRevive(Player)
	end)
	Remotemanager:OnServerEvent(self.Name, "Continue", function(Player)
		self:Continue(Player)
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(UserId, Product, Purchased)
		local Player = Players:GetPlayerByUserId(UserId)
		local Flight = Player and Flights[Player]
		if not Flight or Flight.Buyer ~= Player or Product ~= Single.Product then
			return
		end
		if not Purchased then
			Flight.Buyer = nil
		end
		self:Resume(Flight)
	end)
	Players.PlayerRemoving:Connect(function(Player)
		self:Leave(Player)
	end)
end

function GliderService:Start()
	self.spawn = Workspace:WaitForChild("SpawnPart") :: BasePart
	self.spawn.Anchored = true
	self.spawn.CanCollide = false
	self.spawn.CanQuery = false
	self.spawn.CanTouch = false
	self.spawn.Transparency = 1
	self.respawn = Workspace:WaitForChild("SpawnLocation") :: BasePart
	self.finish = Workspace:WaitForChild("Finish") :: BasePart
	self.finish.CanCollide = false

	local Rings = Workspace:WaitForChild("RingsFolder")
	self.ghosts = { self.folder, Rings, Workspace:WaitForChild("Windzones") }
	self.rings = {}
	for _, Model in ipairs(Rings:GetChildren()) do
		table.insert(self.rings, Measure(Model :: Model))
	end
	RunService.Heartbeat:Connect(function()
		local Now = os.clock()
		for Flight in pairs(Active) do
			if not Flight.Crashed then
				self:Collect(Flight)
				self:Record(Flight, Now)
				continue
			end
			self:Guard(Flight)
			if Flight.Deciding and Flight.Deadline and Now >= Flight.Deadline then
				self:Respawn(Flight)
			end
		end
	end)
end

return GliderService
