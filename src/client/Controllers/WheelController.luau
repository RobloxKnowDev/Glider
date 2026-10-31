local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Wheel = require(ReplicatedStorage.Shared.Config.Wheel)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local WheelController = {
	Name = "WheelController",
	Priority = 13,
}

type Spin = {
	Began: number,
	Duration: number,
	Start: number,
	Finish: number,
}

local Tau = 2 * math.pi
local IdleSpeed = math.rad(15)
local SpinTurns = 4
local SpinStyle = Enum.EasingStyle.Quart
local Landing = 0.3
local RevealTime = 2
local TickVolume = 0.35
local TickPitch = 0.08
local WinVolume = 4
local RefusedVolume = 0.6

local function Thinnest(Size: Vector3): Vector3
	return if Size.X <= Size.Y and Size.X <= Size.Z
		then Vector3.xAxis
		elseif Size.Y <= Size.Z then Vector3.yAxis
		else Vector3.zAxis
end

local function Turn(Axis: Vector3, From: Vector3, To: Vector3): number
	local A = From - Axis * From:Dot(Axis)
	local B = To - Axis * To:Dot(Axis)
	return math.atan2(Axis:Dot(A:Cross(B)), A:Dot(B))
end

local function Clock(Seconds: number): string
	return string.format("%02d:%02d:%02d", Seconds // 3600, Seconds // 60 % 60, Seconds % 60)
end

function WheelController:Build()
	local Base = self.model:WaitForChild("Base") :: BasePart
	self.hinge = Base.CFrame
	self.axis = Thinnest(Base.Size)
	local function Add(Part: Instance)
		if Part:IsA("BasePart") and self.names[Part.Name] then
			self.parts[Part] = self.hinge:ToObjectSpace(Part.CFrame)
		end
	end
	for _, Part in ipairs(self.model:GetChildren()) do
		Add(Part)
	end
	self.model.ChildAdded:Connect(Add)
	self.model.ChildRemoved:Connect(function(Part)
		self.parts[Part] = nil
		self.marks[Part] = nil
	end)
	RunService.RenderStepped:Connect(function(Dt)
		self:Update(Dt)
	end)
end

function WheelController:Under(): BasePart?
	local Best, Closest = nil, math.huge
	for Part, Mark in pairs(self.marks) do
		local Offset = math.abs((Mark + self.angle + math.pi) % Tau - math.pi)
		if Offset < Closest then
			Best, Closest = Part, Offset
		end
	end
	return Best
end

function WheelController:Spin(Index: number, Duration: number)
	local Arrow = self.hinge:PointToObjectSpace((self.model:WaitForChild("Fleche") :: BasePart).Position)
	local Color = Wheel[Index].Color
	local Choices: { number } = {}
	local Count = 0
	self.marks = {}
	for Part, Local in pairs(self.parts) do
		if Part.Name ~= "Base" then
			local Mark = Turn(self.axis, Arrow, Local.Position)
			self.marks[Part] = Mark
			Count += 1
			if Part.Name == Color then
				table.insert(Choices, Mark)
			end
		end
	end
	local Target = -Choices[self.generator:NextInteger(1, #Choices)] + self.generator:NextNumber(-Landing, Landing) * math.pi / Count
	local Spin: Spin = {
		Began = os.clock(),
		Duration = Duration,
		Start = self.angle,
		Finish = self.angle + (Target - self.angle) % Tau + SpinTurns * Tau,
	}
	self.spin = Spin
	self.under = self:Under()
end

function WheelController:Update(Dt: number)
	local Now = os.clock()
	local Spin: Spin? = self.spin
	if Spin then
		local Alpha = math.min((Now - Spin.Began) / Spin.Duration, 1)
		self.angle = Spin.Start + (Spin.Finish - Spin.Start) * TweenService:GetValue(Alpha, SpinStyle, Enum.EasingDirection.Out)
		local Under = self:Under()
		if Under ~= self.under then
			self.under = Under
			Sfx.Play(Sounds.Wheel.Tick, TickVolume, 1 + self.generator:NextNumber(-TickPitch, TickPitch))
		end
		if Alpha >= 1 then
			self.spin = nil
			self.angle %= Tau
			self.rest = Now + RevealTime
			Sfx.Play(Sounds.Wheel.Win, WinVolume)
		end
	elseif Now >= self.rest then
		self.angle = (self.angle + IdleSpeed * Dt) % Tau
	end

	local Rotation = self.hinge * CFrame.fromAxisAngle(self.axis, self.angle)
	local Parts: { BasePart } = {}
	local Frames: { CFrame } = {}
	for Part, Local in pairs(self.parts) do
		table.insert(Parts, Part)
		table.insert(Frames, Rotation * Local)
	end
	Workspace:BulkMoveTo(Parts, Frames, Enum.BulkMoveMode.FireCFrameChanged)
end

function WheelController:Show(Label: TextLabel)
	local Text = if self.count > 0 then "Ready" else Clock(math.max(0, math.ceil(self.next - Workspace:GetServerTimeNow())))
	if Text == self.shown then
		return
	end
	self.shown = Text
	if self.count > 0 then
		Translation.Set(Label, Text)
	else
		Translation.Raw(Label, Text)
	end
end

function WheelController:Init()
	self.model = Workspace:WaitForChild("DailyWheel")
	self.names = { Base = true }
	for _, Reward in ipairs(Wheel) do
		self.names[Reward.Color] = true
	end
	self.parts = {} :: { [BasePart]: CFrame }
	self.marks = {} :: { [BasePart]: number }
	self.generator = Random.new()
	self.angle = 0
	self.rest = 0
	self.count = 0
	self.next = 0
	task.spawn(self.Build, self)
	task.spawn(function()
		local Label = self.model:WaitForChild("BoardUi"):WaitForChild("TimeText") :: TextLabel
		RunService.RenderStepped:Connect(function()
			self:Show(Label)
		end)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(Prompt)
		if (Prompt.Parent :: Instance).Parent == self.model then
			UiFade.Click()
			Remotemanager:FireServer("SpinService", "Spin")
		end
	end)
	Remotemanager:OnClientEvent("SpinService", "Spun", function(Index, Duration)
		self:Spin(Index, Duration)
	end)
	Remotemanager:OnClientEvent("SpinService", "Refused", function()
		Sfx.Play(Sounds.Ui.Negative, RefusedVolume)
	end)
	Remotemanager:OnClientEvent("SpinService", "Updated", function(Count, Next)
		self.count = Count
		self.next = Next
	end)
end

function WheelController:Start()
	task.spawn(function()
		self.count, self.next = Remotemanager:InvokeServer("SpinService", "GetSpins")
	end)
end

return WheelController
