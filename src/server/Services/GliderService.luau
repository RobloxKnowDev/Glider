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
		Quit = "Event",
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

type Level = {
	Spawn: BasePart,
	Finish: BasePart,
	Revives: { BasePart },
}

type Rider = {
	Weld: Weld,
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Height: number,
	Ragdoll: Ragdoll.Handle?,
}

type Flight = {
	Glider: Model,
	Bar: BasePart,
	Frame: CFrame,
	Limit: number,
	Level: number,
	Last: Vector3,
	Collected: { [Model]: boolean },
	Crashed: boolean,
	Passing: boolean,
	Pilot: Player,
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
	local Index = Core:GetService("LevelService"):Get(Host)
	local Start = Facing(self.levels[Index].Spawn, 0)
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
	Glider:SetAttribute("Level", Index)

	local Seats = Instance.new("Folder")
	Seats.Name = "Riders"
	Seats.Parent = Glider

	local Flight: Flight = {
		Glider = Glider,
		Bar = Bar,
		Frame = Frame,
		Limit = Limit,
		Level = Index,
		Last = Start.Position,
		Collected = {},
		Crashed = false,
		Passing = false,
		Pilot = Host,
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
		Remotemanager:FireClient(self.Name, "Started", Player, Glider.Name, Start, self.route)
		Core:GetService("RecordService"):Resume(Player)
	end
end

function GliderService:Arrived(Flight: Flight): boolean
	local Bodies: { Instance } = { Flight.Glider }
	for _, Rider in pairs(Flight.Riders) do
		table.insert(Bodies, Rider.Character)
	end
	self.touch.FilterDescendantsInstances = Bodies
	return #Workspace:GetPartsInPart(self.levels[Flight.Level].Finish, self.touch) > 0
end

function GliderService:Advance(Flight: Flight)
	local Next = Flight.Level + 1
	for Player in pairs(Flight.Riders) do
		Core:GetService("LevelService"):Reach(Player, Next)
	end
	if self.levels[Next] then
		Flight.Level = Next
		Flight.Glider:SetAttribute("Level", Next)
		return
	end
	for Player in pairs(Flight.Riders) do
		Core:GetService("RecordService"):Finish(Player)
	end
	self:Dismount(Flight)
	for Player in pairs(Flight.Riders) do
		Core:GetService("LevelService"):Reset(Player)
	end
end

function GliderService:Dismount(Flight: Flight)
	Flight.Passing = true
	Freeze(Flight.Glider, true)
	for Player, Rider in pairs(Flight.Riders) do
		Freeze(Rider.Character, true)
		Rider.Weld.Enabled = false
		Remotemanager:FireClient(self.Name, "Launching", Player)
	end
	task.wait(LaunchDelay)
	if Active[Flight] and not Flight.Crashed then
		self:Recover(Flight)
	end
end

function GliderService:Skippable(Player: Player): boolean
	if Pending[Player] then
		return false
	end
	local Flight = Flights[Player]
	if Flight then
		return not Flight.Crashed and not Flight.Passing and self.levels[Flight.Level + 1] ~= nil
	end
	return self.levels[Core:GetService("LevelService"):Get(Player) + 1] ~= nil
end

function GliderService:Skip(Player: Player)
	local LevelService = Core:GetService("LevelService")
	local RecordService = Core:GetService("RecordService")
	local Flight = Flights[Player]
	if not Flight then
		local Next = LevelService:Get(Player) + 1
		local Team = Core:GetService("DuoService"):Team(Player)
		for Index, Member in ipairs(Team) do
			LevelService:Reach(Member, Next)
			RecordService:Taint(Member)
			if not self:IsFlying(Member) and Alive(Member) then
				LevelService:Land(Member, Member.Character :: Model, (Index - (#Team + 1) / 2) * SpawnSpacing)
			end
		end
		return
	end

	for Rider in pairs(Flight.Riders) do
		LevelService:Reach(Rider, Flight.Level + 1)
		RecordService:Taint(Rider)
	end
	self:Dismount(Flight)
end

function GliderService:Quit(Player: Player)
	local Flight = Flights[Player]
	if not Flight or Flight.Passing or (Flight.Crashed and not Flight.Deciding) then
		return
	end
	for Rider in pairs(Flight.Riders) do
		Core:GetService("LevelService"):Reset(Rider)
	end
	if Flight.Crashed then
		self:Respawn(Flight)
		return
	end
	self:Dismount(Flight)
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

function GliderService:Nearest(Flight: Flight): CFrame
	local Level = self.levels[Flight.Level]
	local Best, Distance = Level.Spawn, math.huge
	for _, Part in ipairs(Level.Revives) do
		local Gap = (Part.Position - Flight.Last).Magnitude
		if Gap < Distance then
			Best, Distance = Part, Gap
		end
	end
	return Facing(Best, 0)
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
		Core:GetService("RecordService"):Pause(Player)
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

	local Start = self:Nearest(Flight)
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
	Flight.Crashed = false
	for Player in pairs(Flight.Riders) do
		Remotemanager:FireClient(self.Name, "Revived", Player, Flight.Glider.Name, Start)
		Core:GetService("RecordService"):Resume(Player)
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
	for Player, Rider in pairs(Flight.Riders) do
		Index += 1
		if Rider.Ragdoll then
			Ragdoll.Disable(Rider.Ragdoll)
			Rider.Ragdoll = nil
		end
		Core:GetService("LevelService"):Land(Player, Rider.Character, (Index - (Count + 1) / 2) * SpawnSpacing)
		Freeze(Rider.Character, false)
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
		Core:GetService("RecordService"):Pause(Player)
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
	Core:GetService("RecordService"):Pause(Player)
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
		if Flight and not Flight.Passing then
			self:Crash(Flight, false)
		end
	end)
	Remotemanager:OnServerEvent(self.Name, "Revive", function(Player)
		self:UseRevive(Player)
	end)
	Remotemanager:OnServerEvent(self.Name, "Continue", function(Player)
		self:Continue(Player)
	end)
	Remotemanager:OnServerEvent(self.Name, "Quit", function(Player)
		self:Quit(Player)
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
	local Folder = Workspace:WaitForChild("Level")
	self.levels = {} :: { Level }
	self.route = {}
	for Index = 1, #Folder:GetChildren() do
		local Stage = Folder:WaitForChild(tostring(Index))
		local Spawn = Stage:WaitForChild("SpawnPart") :: BasePart
		Spawn.Anchored = true
		Spawn.CanCollide = false
		Spawn.CanQuery = false
		Spawn.CanTouch = false
		Spawn.Transparency = 1
		local Finish = Stage:WaitForChild("Finish") :: BasePart
		Finish.CanCollide = false
		local Revives: { BasePart } = {}
		for _, Child in ipairs(Stage:WaitForChild("Revive"):GetChildren()) do
			local Part = Child :: BasePart
			Part.Anchored = true
			Part.CanCollide = false
			Part.CanQuery = false
			Part.CanTouch = false
			Part.Transparency = 1
			table.insert(Revives, Part)
		end
		table.insert(self.levels, { Spawn = Spawn, Finish = Finish, Revives = Revives })
		table.insert(self.route, { Spawn = Spawn.Position, Finish = Finish.Position })
	end
	self.touch = OverlapParams.new()
	self.touch.FilterType = Enum.RaycastFilterType.Include

	local Rings = Workspace:WaitForChild("RingsFolder")
	self.rings = {}
	for _, Model in ipairs(Rings:GetChildren()) do
		table.insert(self.rings, Measure(Model :: Model))
	end
	RunService.Heartbeat:Connect(function()
		local Now = os.clock()
		for Flight in pairs(Active) do
			if not Flight.Crashed then
				if Flight.Passing then
					continue
				end
				self:Collect(Flight)
				if self:Arrived(Flight) then
					task.spawn(self.Advance, self, Flight)
				end
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
