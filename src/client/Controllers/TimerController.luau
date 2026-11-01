local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

type Run = {
	Began: number,
	Frozen: number?,
	Markers: { ImageLabel },
	Segments: { Frame },
	Update: () -> (),
	Rewind: () -> (),
	Loop: RBXScriptConnection,
}

local Player = Players.LocalPlayer
local Flat = Vector3.new(1, 0, 1)
local TopMargin = 8
local Width = 0.4
local MinWidth = 260
local MaxWidth = 520
local TimerHeight = 32
local TrackTop = 46
local TrackHeight = 12
local SegmentGap = 8
local MarkerSize = 34
local MarkerSpacing = 22
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

function TimerController:Marker(UserId: string): ImageLabel
	local Marker = Instance.new("ImageLabel")
	Marker.Name = UserId
	Marker.AnchorPoint = Vector2.new(0.5, 0.5)
	Marker.Size = UDim2.fromOffset(MarkerSize, MarkerSize)
	Marker.BackgroundColor3 = FillColor
	Marker.BorderSizePixel = 0
	Marker.Image = "rbxthumb://type=AvatarHeadShot&id=" .. UserId .. "&w=150&h=150"
	Marker.ZIndex = 2
	Round(Marker)
	Outline(Marker, TextColor, 2)
	Marker.Parent = self.track
	return Marker
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

function TimerController:Begin(Name: string, Route: { { Spawn: Vector3, Finish: Vector3 } })
	local Glider = Workspace:WaitForChild("Gliders"):WaitForChild(Name)
	local Bar = Glider:WaitForChild("Bar") :: BasePart
	local Seats = Glider:WaitForChild("Riders")
	Seats:WaitForChild(tostring(Player.UserId))
	local Riders = Seats:GetChildren()
	table.sort(Riders, function(A, B)
		return A:GetAttribute("Offset") < B:GetAttribute("Offset")
	end)
	local Markers = {}
	for _, Weld in ipairs(Riders) do
		table.insert(Markers, self:Marker(Weld.Name))
	end

	local Count = #Route
	local Segments: { Frame } = {}
	local Fills: { Frame } = {}
	for Index = 1, Count do
		local Segment, Fill = self:Segment(Index, Count)
		table.insert(Segments, Segment)
		table.insert(Fills, Fill)
	end

	local Level = 0
	local Best = 0
	local Run: Run
	local function Update()
		Translation.Raw(self.timer, Format(os.clock() - Run.Began))
		local Current: number = Glider:GetAttribute("Level")
		if Current ~= Level then
			Level = Current
			Best = 0
		end
		local Stage = Route[Level]
		Best = math.max(
			Best,
			math.clamp(
				1 - ((Stage.Finish - Bar.Position) * Flat).Magnitude / ((Stage.Finish - Stage.Spawn) * Flat).Magnitude,
				0,
				1
			)
		)
		for Index, Fill in ipairs(Fills) do
			Fill.Size = UDim2.fromScale(if Index < Level then 1 elseif Index == Level then Best else 0, 1)
		end
		for Index, Marker in ipairs(Markers) do
			Marker.Position = UDim2.new(
				(Level - 1 + Best) / Count,
				SegmentGap * (0.5 - Best) + (Index - (#Markers + 1) / 2) * MarkerSpacing,
				0.5,
				0
			)
		end
	end
	Run = {
		Began = os.clock() - self.elapsed,
		Frozen = nil,
		Markers = Markers,
		Segments = Segments,
		Update = Update,
		Rewind = function()
			Best = 0
		end,
		Loop = RunService.RenderStepped:Connect(Update),
	}

	self.timer.TextColor3 = TextColor
	Update()
	self.gui.Enabled = true
	self.lobby.Visible = false
	self.run = Run
end

function TimerController:Freeze()
	local Run = self.run
	if not Run or Run.Frozen then
		return
	end
	Run.Loop:Disconnect()
	Run.Frozen = os.clock()
	self.timer.TextColor3 = CrashColor
end

function TimerController:Resume()
	local Run = self.run
	if not Run then
		return
	end
	Run.Rewind()
	if not Run.Frozen then
		return
	end
	Run.Began += os.clock() - Run.Frozen
	Run.Frozen = nil
	Run.Loop = RunService.RenderStepped:Connect(Run.Update)
	self.timer.TextColor3 = TextColor
end

function TimerController:Reset()
	self.elapsed = 0
	local Run = self.run
	if not Run then
		return
	end
	local Now = os.clock()
	Run.Loop:Disconnect()
	Run.Began = Now
	Run.Frozen = Now
	self.timer.TextColor3 = TextColor
	Translation.Raw(self.timer, Format(0))
end

function TimerController:Record()
	local Duo = Player:GetAttribute("Grouped")
	local Time = if Duo then self.duo else self.solo
	local Text = if Time then Format(Time) else "--:--.--"
	local Pattern = if Duo then "Best Duo: {1}" else "Best Solo: {1}"
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
	Run.Loop:Disconnect()
	for _, Marker in ipairs(Run.Markers) do
		Marker:Destroy()
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
	Top.Position = UDim2.new(0.5, 0, 0, TopMargin)
	Top.Size = UDim2.new(Width, 0, 0, TrackTop + TrackHeight)
	Top.BackgroundTransparency = 1
	Top.Parent = Gui

	local Limit = Instance.new("UISizeConstraint")
	Limit.MinSize = Vector2.new(MinWidth, 0)
	Limit.MaxSize = Vector2.new(MaxWidth, math.huge)
	Limit.Parent = Top

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
