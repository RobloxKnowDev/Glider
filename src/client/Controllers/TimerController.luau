local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Images = require(ReplicatedStorage.Shared.Config.Images)
local Format = require(ReplicatedStorage.Shared.Utils.Chrono)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local TimerController = {
	Name = "TimerController",
	Priority = 22,
}

type Racer = {
	Bar: BasePart,
	Front: string,
	Size: number,
	Count: number,
	Markers: { [Instance]: ImageLabel },
	Connections: { RBXScriptConnection },
}

type Run = {
	Began: number,
	Frozen: number?,
	Glider: Instance,
	Level: number,
	Best: number,
	Racers: { [Instance]: Racer },
	Segments: { Frame },
	Connections: { RBXScriptConnection },
}

local Player = Players.LocalPlayer
local Flat = Vector3.new(1, 0, 1)
local TopMargin = 8
local TouchLift = 30
local Width = 0.4
local MinWidth = 260
local MaxWidth = 520
local ReferenceHeight = 720
local TimerHeight = 32
local TrackTop = 46
local TrackHeight = 12
local SegmentGap = 8
local MarkerSize = 34
local OtherSize = 26
local StackOffset = 10
local SelfLayer = 5
local PartnerLayer = 4
local FrontLayer = 3
local BackLayer = 2
local FlagSize = 22
local LeaveGap = 20
local LeaveWidth = 160
local LeaveHeight = 44
local BestHeight = 24
local BestMargin = 10
local TextColor = Color3.new(1, 1, 1)
local OutlineColor = Color3.new(0, 0, 0)
local TrackColor = Color3.new(0, 0, 0)
local TrackTransparency = 0.45
local FillColor = Color3.fromRGB(80, 200, 255)
local CrashColor = Color3.fromRGB(255, 80, 80)
local BestColor = Color3.fromRGB(255, 220, 40)

local function Round(Object: GuiObject)
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0.5, 0)
	Corner.Parent = Object
end

local function Outline(Object: GuiObject, Color: Color3, Thickness: number)
	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color
	Stroke.Thickness = Thickness
	Stroke.Parent = Object
end

function TimerController:Marker(UserId: string, Size: number, Layer: number): ImageLabel
	local Marker = Instance.new("ImageLabel")
	Marker.Name = UserId
	Marker.AnchorPoint = Vector2.new(0.5, 0.5)
	Marker.Size = UDim2.fromOffset(Size, Size)
	Marker.BackgroundColor3 = FillColor
	Marker.BorderSizePixel = 0
	Marker.Image = "rbxthumb://type=AvatarHeadShot&id=" .. UserId .. "&w=150&h=150"
	Marker.ZIndex = Layer
	Round(Marker)
	Outline(Marker, TextColor, 2)
	Marker.Parent = self.track
	return Marker
end

function TimerController:Join(Run: Run, Glider: Instance)
	local Own = Glider == Run.Glider
	local Bar = Glider:WaitForChild("Bar") :: BasePart
	local Seats = Glider:WaitForChild("Riders")
	if self.run ~= Run or not Glider.Parent then
		return
	end
	local Racer: Racer = {
		Bar = Bar,
		Front = if Own then tostring(Player.UserId) else tostring(Glider:GetAttribute("Pilot")),
		Size = if Own then MarkerSize else OtherSize,
		Count = 0,
		Markers = {},
		Connections = {},
	}
	local function Board(Weld: Instance)
		local Front = Weld.Name == Racer.Front
		local Layer = if Own
			then (if Front then SelfLayer else PartnerLayer)
			else (if Front then FrontLayer else BackLayer)
		Racer.Markers[Weld] = self:Marker(Weld.Name, Racer.Size, Layer)
		Racer.Count += 1
	end
	for _, Weld in ipairs(Seats:GetChildren()) do
		Board(Weld)
	end
	table.insert(Racer.Connections, Seats.ChildAdded:Connect(Board))
	table.insert(
		Racer.Connections,
		Seats.ChildRemoved:Connect(function(Weld)
			Racer.Markers[Weld]:Destroy()
			Racer.Markers[Weld] = nil
			Racer.Count -= 1
		end)
	)
	Run.Racers[Glider] = Racer
end

function TimerController:Leave(Run: Run, Glider: Instance)
	local Racer = Run.Racers[Glider]
	if not Racer then
		return
	end
	for _, Connection in ipairs(Racer.Connections) do
		Connection:Disconnect()
	end
	for _, Marker in pairs(Racer.Markers) do
		Marker:Destroy()
	end
	Run.Racers[Glider] = nil
end

function TimerController:Segment(Index: number, Count: number): (Frame, Frame)
	local Segment = Instance.new("Frame")
	Segment.Name = tostring(Index)
	Segment.Position = UDim2.new((Index - 1) / Count, SegmentGap / 2, 0, 0)
	Segment.Size = UDim2.new(1 / Count, -SegmentGap, 1, 0)
	Segment.BackgroundColor3 = TrackColor
	Segment.BackgroundTransparency = TrackTransparency
	Segment.BorderSizePixel = 0
	Segment.Parent = self.track
	Round(Segment)
	Outline(Segment, TextColor, 2)

	local Fill = Instance.new("Frame")
	Fill.Name = "Fill"
	Fill.Size = UDim2.fromScale(0, 1)
	Fill.BackgroundColor3 = FillColor
	Fill.BorderSizePixel = 0
	Fill.Parent = Segment
	Round(Fill)
	return Segment, Fill
end

function TimerController:Begin(Name: string, Route: { { Spawn: Vector3, Finish: Vector3, Section: number } })
	local Folder = Workspace:WaitForChild("Gliders")
	local Glider = Folder:WaitForChild(Name)
	local Bar = Glider:WaitForChild("Bar") :: BasePart
	Glider:WaitForChild("Riders"):WaitForChild(tostring(Player.UserId))

	local Count = Route[#Route].Section
	local First: { number } = {}
	local Size: { number } = {}
	for Index, Stage in ipairs(Route) do
		if not First[Stage.Section] then
			First[Stage.Section] = Index
			Size[Stage.Section] = 0
		end
		Size[Stage.Section] += 1
	end
	local Segments: { Frame } = {}
	local Fills: { Frame } = {}
	for Index = 1, Count do
		local Segment, Fill = self:Segment(Index, Count)
		table.insert(Segments, Segment)
		table.insert(Fills, Fill)
	end

	local function Done(Level: number, Position: Vector3): number
		local Stage = Route[Level]
		return math.clamp(
			1 - ((Stage.Finish - Position) * Flat).Magnitude / ((Stage.Finish - Stage.Spawn) * Flat).Magnitude,
			0,
			1
		)
	end
	local function Locate(Level: number, Part: number): (number, number)
		local Section = Route[Level].Section
		return Section, (Level - First[Section] + Part) / Size[Section]
	end

	local Run: Run = {
		Began = os.clock() - self.elapsed,
		Frozen = nil,
		Glider = Glider,
		Level = 0,
		Best = 0,
		Racers = {},
		Segments = Segments,
		Connections = {},
	}
	local function Update()
		if not Run.Frozen then
			Translation.Raw(self.timer, Format(os.clock() - Run.Began))
			local Current: number = Glider:GetAttribute("Level")
			if Current ~= Run.Level then
				Run.Level = Current
				Run.Best = 0
			end
			Run.Best = math.max(Run.Best, Done(Run.Level, Bar.Position))
			local Section, Progress = Locate(Run.Level, Run.Best)
			for Index, Fill in ipairs(Fills) do
				Fill.Size = UDim2.fromScale(if Index < Section then 1 elseif Index == Section then Progress else 0, 1)
			end
		end
		for Other, Racer in pairs(Run.Racers) do
			local Section, Progress
			if Other == Glider then
				Section, Progress = Locate(Run.Level, Run.Best)
			else
				local Level: number = Other:GetAttribute("Level")
				Section, Progress = Locate(Level, Done(Level, Racer.Bar.Position))
			end
			for Weld, Marker in pairs(Racer.Markers) do
				local Shift = if Racer.Count > 1 and Weld.Name ~= Racer.Front then StackOffset else 0
				Marker.Position = UDim2.new((Section - 1 + Progress) / Count, SegmentGap * (0.5 - Progress) - Shift, 0.5, 0)
			end
		end
	end

	self.run = Run
	for _, Other in ipairs(Folder:GetChildren()) do
		task.spawn(self.Join, self, Run, Other)
	end
	table.insert(
		Run.Connections,
		Folder.ChildAdded:Connect(function(Other)
			self:Join(Run, Other)
		end)
	)
	table.insert(
		Run.Connections,
		Folder.ChildRemoved:Connect(function(Other)
			self:Leave(Run, Other)
		end)
	)
	table.insert(Run.Connections, RunService.RenderStepped:Connect(Update))

	self.timer.TextColor3 = TextColor
	Update()
	self.gui.Enabled = true
	self.lobby.Visible = false
end

function TimerController:Freeze()
	local Run = self.run
	if not Run or Run.Frozen then
		return
	end
	Run.Frozen = os.clock()
	self.timer.TextColor3 = CrashColor
end

function TimerController:Resume()
	local Run = self.run
	if not Run then
		return
	end
	Run.Best = 0
	if not Run.Frozen then
		return
	end
	Run.Began += os.clock() - Run.Frozen
	Run.Frozen = nil
	self.timer.TextColor3 = TextColor
end

function TimerController:Reset()
	self.elapsed = 0
	local Run = self.run
	if not Run then
		return
	end
	local Now = os.clock()
	Run.Began = Now
	Run.Frozen = Now
	self.timer.TextColor3 = TextColor
	Translation.Raw(self.timer, Format(0))
end

function TimerController:Record()
	local Duo = Player:GetAttribute("Grouped")
	local Time = if Duo then self.duo else self.solo
	local Text = if Time then Format(Time) else "--:--.--"
	local Pattern = if Duo then "Daily Best Duo: {1}" else "Daily Best Solo: {1}"
	Translation.Set(self.best, Pattern, Text)
	Translation.Set(self.lobby, Pattern, Text)
end

function TimerController:Finish()
	local Run = self.run
	if not Run then
		return
	end
	self.run = nil
	self.elapsed = (Run.Frozen or os.clock()) - Run.Began
	for _, Connection in ipairs(Run.Connections) do
		Connection:Disconnect()
	end
	for Glider in pairs(Run.Racers) do
		self:Leave(Run, Glider)
	end
	for _, Segment in ipairs(Run.Segments) do
		Segment:Destroy()
	end
	self.gui.Enabled = false
	self.lobby.Visible = true
end

function TimerController:Init()
	local Hud = Player:WaitForChild("PlayerGui"):WaitForChild("HUD")
	local Font = (Hud:WaitForChild("CoinFrame"):WaitForChild("Text") :: TextLabel).FontFace

	local Gui = Instance.new("ScreenGui")
	Gui.Name = "TimerUi"
	Gui.ResetOnSpawn = false
	Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Gui.Enabled = false

	local Top = Instance.new("Frame")
	Top.Name = "Top"
	Top.AnchorPoint = Vector2.new(0.5, 0)
	Top.BackgroundTransparency = 1
	Top.Parent = Gui

	local Limit = Instance.new("UISizeConstraint")
	Limit.MinSize = Vector2.new(MinWidth, 0)
	Limit.MaxSize = Vector2.new(MaxWidth, math.huge)
	Limit.Parent = Top

	local Scale = Instance.new("UIScale")
	Scale.Parent = Top
	local Camera = Workspace.CurrentCamera
	local function Fit()
		local Ratio = math.min(Camera.ViewportSize.Y / ReferenceHeight, 1)
		local Lift = if UserInputService.PreferredInput == Enum.PreferredInput.Touch then TouchLift else 0
		Scale.Scale = Ratio
		Top.Position = UDim2.new(0.5, 0, 0, TopMargin - Lift)
		Top.Size = UDim2.new(Width / Ratio, 0, 0, TrackTop + TrackHeight)
	end
	Fit()
	Camera:GetPropertyChangedSignal("ViewportSize"):Connect(Fit)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(Fit)

	local Timer = Instance.new("TextLabel")
	Timer.Name = "Timer"
	Timer.Size = UDim2.new(1, 0, 0, TimerHeight)
	Timer.BackgroundTransparency = 1
	Timer.FontFace = Font
	Timer.TextColor3 = TextColor
	Timer.TextScaled = true
	Timer.Parent = Top
	Outline(Timer, OutlineColor, 2.5)

	local Track = Instance.new("Frame")
	Track.Name = "Track"
	Track.Position = UDim2.fromOffset(0, TrackTop)
	Track.Size = UDim2.new(1, 0, 0, TrackHeight)
	Track.BackgroundTransparency = 1
	Track.Parent = Top

	local Flag = Instance.new("TextLabel")
	Flag.Name = "Flag"
	Flag.AnchorPoint = Vector2.new(0, 0.5)
	Flag.Position = UDim2.new(1, 6, 0.5, 0)
	Flag.Size = UDim2.fromOffset(FlagSize, FlagSize)
	Flag.BackgroundTransparency = 1
	Flag.TextScaled = true
	Flag.Parent = Track
	Translation.Raw(Flag, "🏁")

	local Leave = Hud:WaitForChild("Right"):WaitForChild("LeaveButton"):Clone() :: GuiButton
	Leave.AnchorPoint = Vector2.new(0.5, 0)
	Leave.Position = UDim2.new(0.5, 0, 1, LeaveGap)
	Leave.Size = UDim2.fromOffset(LeaveWidth, LeaveHeight)
	Leave.Visible = true
	Leave.Parent = Top
	Translation.Set(Leave:WaitForChild("Text") :: TextLabel, "Leave Race")

	local Texture = Instance.new("ImageLabel")
	Texture.Name = "Texture"
	Texture.Size = UDim2.fromScale(1, 1)
	Texture.BackgroundTransparency = 1
	Texture.Image = Images.Timer.Leave
	Texture.ScaleType = Enum.ScaleType.Crop
	Texture.ZIndex = 0
	Texture.Parent = Leave

	UiFade.BindButton(Leave)
	Leave.Activated:Connect(function()
		Remotemanager:FireServer("GliderService", "Quit")
	end)

	local Best = Instance.new("TextLabel")
	Best.Name = "Best"
	Best.Position = UDim2.new(0, 0, 1, LeaveGap + (LeaveHeight - BestHeight) / 2)
	Best.Size = UDim2.new(0.5, -(LeaveWidth / 2 + BestMargin), 0, BestHeight)
	Best.BackgroundTransparency = 1
	Best.FontFace = Font
	Best.TextColor3 = BestColor
	Best.TextScaled = true
	Best.TextXAlignment = Enum.TextXAlignment.Left
	Best.Parent = Top
	Outline(Best, OutlineColor, 2)

	Gui.Parent = Player:WaitForChild("PlayerGui")
	self.gui = Gui
	self.timer = Timer
	self.track = Track
	self.best = Best
	self.lobby = Hud:WaitForChild("BestText") :: TextLabel
	self.elapsed = 0
	self.solo = nil :: number?
	self.duo = nil :: number?
	self:Record()
	Player:GetAttributeChangedSignal("Grouped"):Connect(function()
		self:Record()
	end)

	Remotemanager:OnClientEvent("GliderService", "Started", function(Name, _, Route)
		self:Begin(Name, Route)
	end)
	Remotemanager:OnClientEvent("GliderService", "Crashed", function()
		self:Freeze()
	end)
	Remotemanager:OnClientEvent("GliderService", "Revived", function()
		self:Resume()
	end)
	Remotemanager:OnClientEvent("GliderService", "Stopped", function()
		self:Finish()
	end)
	Remotemanager:OnClientEvent("LevelService", "Reset", function()
		self:Reset()
	end)
	Remotemanager:OnClientEvent("RecordService", "Updated", function(Solo, Duo)
		self.solo = Solo
		self.duo = Duo
		self:Record()
	end)
end

function TimerController:Start()
	task.spawn(function()
		self.solo, self.duo = Remotemanager:InvokeServer("RecordService", "GetRecord")
		self:Record()
	end)
end

return TimerController
