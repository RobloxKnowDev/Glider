local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Images = require(ReplicatedStorage.Shared.Config.Images)
local GainBurst = require(ReplicatedStorage.Shared.Utils.GainBurst)
local NumberAbbreviator = require(ReplicatedStorage.Shared.Utils.NumberAbbreviator)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)

local CounterController = {
	Name = "CounterController",
	Priority = 26,
}

type Counter = {
	Icon: GuiObject,
	Scale: UIScale,
	Label: TextLabel,
	Color: Color3,
	Image: string,
	Count: number,
	Pending: number,
	Ready: boolean,
}

local Player = Players.LocalPlayer
local PopupStyle: GainBurst.Style = {
	Color = Color3.new(1, 1, 1),
	Stroke = Color3.new(0, 0, 0),
}
local GainColor = Color3.fromRGB(21, 255, 0)
local BumpScale = 1.3
local BumpInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FlashInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function Symbol(Image: string): ImageLabel
	local Label = Instance.new("ImageLabel")
	Label.BackgroundTransparency = 1
	Label.ScaleType = Enum.ScaleType.Fit
	Label.Image = Image
	return Label
end

function CounterController:Counter(Frame: Instance, Image: string): Counter
	local Icon = Frame:WaitForChild("Icon") :: ImageLabel
	local Label = Frame:WaitForChild("Text") :: TextLabel
	local Scale = Instance.new("UIScale")
	Scale.Parent = Icon
	local Counter: Counter = {
		Icon = Icon,
		Scale = Scale,
		Label = Label,
		Color = Label.TextColor3,
		Image = Image,
		Count = 0,
		Pending = 0,
		Ready = false,
	}
	self:Show(Counter)
	return Counter
end

function CounterController:Show(Counter: Counter)
	Translation.Raw(Counter.Label, NumberAbbreviator(math.round(Counter.Count - Counter.Pending)))
end

function CounterController:Land(Counter: Counter, Share: number)
	Counter.Pending -= Share
	self:Show(Counter)
	Counter.Scale.Scale = BumpScale
	TweenService:Create(Counter.Scale, BumpInfo, { Scale = 1 }):Play()
	Counter.Label.TextColor3 = GainColor
	TweenService:Create(Counter.Label, FlashInfo, { TextColor3 = Counter.Color }):Play()
end

function CounterController:Set(Counter: Counter, Count: number)
	local Gained = Count - Counter.Count
	Counter.Count = Count
	if Counter.Ready and Gained > 0 and not Player:GetAttribute("Flying") then
		Counter.Pending += Gained
		GainBurst.Play(Counter.Icon, Gained, PopupStyle, function()
			return Symbol(Counter.Image)
		end, function(Share)
			self:Land(Counter, Share)
		end)
	end
	self:Show(Counter)
end

function CounterController:Track(Counter: Counter, Service: string, Getter: string)
	Remotemanager:OnClientEvent(Service, "Updated", function(Count)
		self:Set(Counter, Count)
	end)
	task.spawn(function()
		self:Set(Counter, Remotemanager:InvokeServer(Service, Getter))
		Counter.Ready = true
	end)
end

function CounterController:Init()
	local TopRight = Player:WaitForChild("PlayerGui"):WaitForChild("HUD"):WaitForChild("TopRight")
	self.revives = self:Counter(TopRight:WaitForChild("Revive"), Images.Counter.Revive)
	self.skips = self:Counter(TopRight:WaitForChild("Skip"), Images.Counter.Skip)
end

function CounterController:Start()
	self:Track(self.revives, "ReviveService", "GetRevives")
	self:Track(self.skips, "SkipService", "GetSkips")
end

return CounterController
