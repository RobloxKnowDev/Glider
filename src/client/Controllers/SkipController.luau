local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local RobuxPrice = require(ReplicatedStorage.Shared.Utils.RobuxPrice)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local SkipController = {
	Name = "SkipController",
	Priority = 24,
}

local Player = Players.LocalPlayer
local Single = Store.Skip[1]
local Robux = "\u{E002}"
local RefusedVolume = 0.6

function SkipController:Paint()
	if self.count > 0 then
		Translation.Set(self.text, "Skip({1})", self.count)
	else
		Translation.Set(self.text, "Skip({1})", self.price .. Robux)
	end
end

function SkipController:Init()
	local Button = Player:WaitForChild("PlayerGui"):WaitForChild("HUD"):WaitForChild("SkipButton") :: GuiButton
	self.text = Button:WaitForChild("Text") :: TextLabel
	self.count = 0
	self.price = Single.Price
	self:Paint()

	UiFade.BindButton(Button)
	Button.Activated:Connect(function()
		Remotemanager:FireServer("SkipService", "Use")
	end)
	Remotemanager:OnClientEvent("SkipService", "Updated", function(Count)
		self.count = Count
		self:Paint()
	end)
	Remotemanager:OnClientEvent("SkipService", "Refused", function()
		Sfx.Play(Sounds.Ui.Negative, RefusedVolume)
	end)
end

function SkipController:Start()
	task.spawn(function()
		self.count = Remotemanager:InvokeServer("SkipService", "GetSkips")
		self:Paint()
	end)
	task.spawn(function()
		self.price = RobuxPrice(Single)
		self:Paint()
	end)
end

return SkipController
