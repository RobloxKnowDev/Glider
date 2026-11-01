local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local RobuxPrice = require(ReplicatedStorage.Shared.Utils.RobuxPrice)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local ReviveController = {
	Name = "ReviveController",
	Priority = 23,
}

local Player = Players.LocalPlayer
local Single = Store.Revive[1]
local Robux = "\u{E002}"
local WaitingDrop = UDim.new(0.3, 0)

function ReviveController:Paint()
	local Owner = self.pilot == Player
	self.reviveButton.Visible = Owner
	self.continueButton.Visible = Owner
	self.waiting.Visible = not Owner
	if self.count > 0 then
		Translation.Set(self.reviveText, "Revive({1})", self.count)
	else
		Translation.Set(self.reviveText, "Revive({1})", self.price .. Robux)
	end
end

function ReviveController:Label()
	Translation.Set(self.continueText, "Continue({1}s)", self.seconds)
	Translation.Set(self.waiting, "Waiting for {1} to revive or continue ({2}s)", self.pilot.DisplayName, self.seconds)
end

function ReviveController:Tick()
	local Left = if self.paused then self.remaining else math.max(self.deadline - os.clock(), 0)
	local Seconds = math.ceil(Left)
	if Seconds ~= self.seconds then
		self.seconds = Seconds
		self:Label()
	end
end

function ReviveController:Show()
	self.seconds = -1
	local Ui = Core:GetController("UiController")
	Ui:Close()
	self:Tick()
	self.frame.Visible = true
	UiFade.Pop(self.frame)
	if self.pilot == Player then
		Ui:Point(self.continueButton)
	end
	self.loop = RunService.RenderStepped:Connect(function()
		self:Tick()
	end)
end

function ReviveController:Hide()
	if not self.loop then
		return
	end
	self.loop:Disconnect()
	self.loop = nil
	self.frame.Visible = false
	Core:GetController("UiController"):Release()
end

function ReviveController:Init()
	local Frame = Player:WaitForChild("PlayerGui"):WaitForChild("ReviveUi"):WaitForChild("Frame") :: GuiObject
	local ReviveButton = Frame:WaitForChild("ReviveButton") :: GuiButton
	local ContinueButton = Frame:WaitForChild("ContinueButton") :: GuiButton
	local Waiting = Frame:WaitForChild("Text"):Clone() :: TextLabel
	Waiting.Name = "Waiting"
	Waiting.Position += UDim2.new(UDim.new(), WaitingDrop)
	Waiting.Parent = Frame
	Frame.Visible = false

	self.frame = Frame
	self.reviveButton = ReviveButton
	self.continueButton = ContinueButton
	self.reviveText = ReviveButton:WaitForChild("Text") :: TextLabel
	self.continueText = ContinueButton:WaitForChild("Text") :: TextLabel
	self.waiting = Waiting
	self.count = 0
	self.price = Single.Price
	self.remaining = 0
	self.deadline = 0
	self.paused = false
	self.seconds = -1
	self.pilot = Player
	self.loop = nil :: RBXScriptConnection?
	self:Paint()

	UiFade.BindButton(ReviveButton)
	UiFade.BindButton(ContinueButton)
	ReviveButton.Activated:Connect(function()
		Remotemanager:FireServer("GliderService", "Revive")
	end)
	ContinueButton.Activated:Connect(function()
		Remotemanager:FireServer("GliderService", "Continue")
	end)

	Remotemanager:OnClientEvent("GliderService", "Countdown", function(Remaining, Paused, Pilot)
		self.remaining = Remaining
		self.deadline = os.clock() + Remaining
		self.paused = Paused
		self.pilot = Pilot
		self:Paint()
		if self.loop then
			self:Label()
		else
			self:Show()
		end
	end)
	for _, Event in ipairs({ "Launching", "Respawning", "Stopped" }) do
		Remotemanager:OnClientEvent("GliderService", Event, function()
			self:Hide()
		end)
	end
	Remotemanager:OnClientEvent("ReviveService", "Updated", function(Count)
		self.count = Count
		self:Paint()
	end)
end

function ReviveController:Start()
	task.spawn(function()
		self.count = Remotemanager:InvokeServer("ReviveService", "GetRevives")
		self:Paint()
	end)
	task.spawn(function()
		self.price = RobuxPrice(Single)
		self:Paint()
	end)
end

return ReviveController
