local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local GainBurst = require(ReplicatedStorage.Shared.Utils.GainBurst)
local NumberAbbreviator = require(ReplicatedStorage.Shared.Utils.NumberAbbreviator)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)

local StudsController = {
	Name = "StudsController",
	Priority = 25,
}

local GainColor = Color3.fromRGB(21, 255, 0)
local GainStyle: GainBurst.Style = {
	Color = GainColor,
	Stroke = Color3.fromRGB(26, 98, 0),
}
local BumpScale = 1.15
local BumpInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FlashInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function StudsController:Show()
	Translation.Raw(self.text, NumberAbbreviator(math.round(self.value - self.pending)) .. "$")
end

function StudsController:Land(Share: number)
	self.pending -= Share
	self:Show()
	self.scale.Scale = BumpScale
	TweenService:Create(self.scale, BumpInfo, { Scale = 1 }):Play()
	self.text.TextColor3 = GainColor
	TweenService:Create(self.text, FlashInfo, { TextColor3 = self.color }):Play()
end

function StudsController:Get(): number
	return self.value
end

function StudsController:Credit(Amount: number)
	self.value += Amount
	self:Gain(Amount)
end

function StudsController:Gain(Amount: number)
	self.pending += Amount
	self:Show()
	task.spawn(function()
		Core:GetController("TransitionController"):Wait()
		GainBurst.Play(self.text, Amount, GainStyle, function()
			return GainBurst.Label("$", GainStyle)
		end, function(Share)
			self:Land(Share)
		end)
	end)
end

function StudsController:Init()
	self.text = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("HUD"):WaitForChild("CoinFrame"):WaitForChild("Text") :: TextLabel
	self.color = self.text.TextColor3
	self.scale = Instance.new("UIScale")
	self.scale.Parent = self.text
	self.value = 0
	self.pending = 0
end

function StudsController:Start()
	Remotemanager:OnClientEvent("StudsService", "Updated", function(Value, Gained)
		self.value = Value
		if Gained > 0 then
			self:Gain(Gained)
		else
			self:Show()
		end
	end)
	task.spawn(function()
		self.value = Remotemanager:InvokeServer("StudsService", "GetStuds")
		self:Show()
	end)
end

return StudsController
