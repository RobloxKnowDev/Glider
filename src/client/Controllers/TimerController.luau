local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)

local TimerController = {
	Name = "TimerController",
	Priority = 22,
}

type Run = {
	Began: number,
	Frozen: number,
	Markers: { ImageLabel },
	Update: () -> (),
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
local MarkerSize = 34
local MarkerSpacing = 22
local FlagSize = 22
local TextColor = Color3.new(1, 1, 1)
local OutlineColor = Color3.new(0, 0, 0)
local TrackColor = Color3.new(0, 0, 0)
local TrackTransparency = 0.45
local FillColor = Color3.fromRGB(80, 200, 255)
local CrashColor = Color3.fromRGB(255, 80, 80)

local function Format(Time: number): string
	local Hundredths = math.floor(Time * 100)
	return string.format("%02d:%02d.%02d", Hundredths // 6000, Hundredths // 100 % 60, Hundredths % 100)
end

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

function TimerController:Begin(Name: string, Start: CFrame, Goal: Vector3)
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

	local Total = ((Goal - Start.Position) * Flat).Magnitude
	local Best = 0
	local Run: Run
	local function Update()
		Translation.Raw(self.timer, Format(os.clock() - Run.Began))
		Best = math.max(Best, math.clamp(1 - ((Goal - Bar.Position) * Flat).Magnitude / Total, 0, 1))
		self.fill.Size = UDim2.fromScale(Best, 1)
		for Index, Marker in ipairs(Markers) do
			Marker.Position = UDim2.new(Best, (Index - (#Markers + 1) / 2) * MarkerSpacing, 0.5, 0)
		end
	end
	Run = {
		Began = os.clock(),
		Frozen = 0,
		Markers = Markers,
		Update = Update,
		Loop = RunService.RenderStepped:Connect(Update),
	}

	self.timer.TextColor3 = TextColor
	Update()
	self.gui.Enabled = true
	self.run = Run
end

function TimerController:Freeze()
	local Run = self.run
	if not Run then
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
	Run.Began += os.clock() - Run.Frozen
	Run.Loop = RunService.RenderStepped:Connect(Run.Update)
	self.timer.TextColor3 = TextColor
end

function TimerController:Finish()
	local Run = self.run
	if not Run then
		return
	end
	self.run = nil
	Run.Loop:Disconnect()
	for _, Marker in ipairs(Run.Markers) do
		Marker:Destroy()
	end
	self.gui.Enabled = false
end

function TimerController:Init()
	local Font = (Player:WaitForChild("PlayerGui"):WaitForChild("HUD"):WaitForChild("CoinFrame"):WaitForChild("Text") :: TextLabel).FontFace

	local Gui = Instance.new("ScreenGui")
	Gui.Name = "TimerUi"
	Gui.ResetOnSpawn = false
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
	Track.BackgroundColor3 = TrackColor
	Track.BackgroundTransparency = TrackTransparency
	Track.BorderSizePixel = 0
	Track.Parent = Top
	Round(Track)
	Outline(Track, TextColor, 2)

	local Fill = Instance.new("Frame")
	Fill.Name = "Fill"
	Fill.Size = UDim2.fromScale(0, 1)
	Fill.BackgroundColor3 = FillColor
	Fill.BorderSizePixel = 0
	Fill.Parent = Track
	Round(Fill)

	local Flag = Instance.new("TextLabel")
	Flag.Name = "Flag"
	Flag.AnchorPoint = Vector2.new(0, 0.5)
	Flag.Position = UDim2.new(1, 6, 0.5, 0)
	Flag.Size = UDim2.fromOffset(FlagSize, FlagSize)
	Flag.BackgroundTransparency = 1
	Flag.TextScaled = true
	Flag.Parent = Track
	Translation.Raw(Flag, "🏁")

	Gui.Parent = Player:WaitForChild("PlayerGui")
	self.gui = Gui
	self.timer = Timer
	self.track = Track
	self.fill = Fill

	Remotemanager:OnClientEvent("GliderService", "Started", function(Name, Start, Goal)
		self:Begin(Name, Start, Goal)
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
end

return TimerController
