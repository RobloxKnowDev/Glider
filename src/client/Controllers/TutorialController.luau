local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Images = require(ReplicatedStorage.Shared.Config.Images)

local TutorialController = {
	Name = "TutorialController",
	Priority = 26,
}

local Player = Players.LocalPlayer
local DisplayOrder = 95
local HandSize = 0.13
local HandTip = Vector2.new(0.39, 0.18)
local HandSpot = Vector2.new(0.6, 0.65)
local TapDirection = Vector2.new(0.35, 1).Unit
local TapDistance = 0.22
local TapSpeed = 5

function TutorialController:Finish()
	if self.done ~= true then
		self.done = true
		Remotemanager:FireServer("TutorialService", "Done")
	end
end

function TutorialController:Target(): GuiObject?
	if self.done ~= false or not self.ready then
		return nil
	end
	local Current = Core:GetController("UiController").current
	if Current == self.main then
		return if self.solo.Visible then self.solo else nil
	end
	if Current or not self.play.Visible or Core:GetController("PlayController").role then
		return nil
	end
	return self.play
end

function TutorialController:Render()
	local Target = self:Target()
	local Hand = self.hand
	Hand.Visible = Target ~= nil
	if not Target then
		return
	end
	local Size = self.gui.AbsoluteSize.Y * HandSize
	local Tap = TapDirection * math.abs(math.sin(os.clock() * TapSpeed)) * TapDistance * Size
	local Spot = Target.AbsolutePosition + Target.AbsoluteSize * HandSpot - self.gui.AbsolutePosition + Tap
	Hand.Size = UDim2.fromOffset(Size, Size)
	Hand.Position = UDim2.fromOffset(Spot.X, Spot.Y)
end

function TutorialController:Init()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local PlayUi = PlayerGui:WaitForChild("PlayUi")
	local MainFrame = PlayUi:WaitForChild("MainFrame") :: GuiObject
	local SoloButton = MainFrame:WaitForChild("SoloButton") :: GuiButton

	local Gui = Instance.new("ScreenGui")
	Gui.Name = "TutorialUi"
	Gui.ResetOnSpawn = false
	Gui.IgnoreGuiInset = true
	Gui.DisplayOrder = DisplayOrder

	local Hand = Instance.new("ImageLabel")
	Hand.Name = "Hand"
	Hand.AnchorPoint = HandTip
	Hand.BackgroundTransparency = 1
	Hand.Image = Images.Tutorial.Hand
	Hand.ScaleType = Enum.ScaleType.Fit
	Hand.Interactable = false
	Hand.Visible = false
	Hand.Parent = Gui

	Gui.Parent = PlayerGui
	self.gui = Gui
	self.hand = Hand
	self.main = MainFrame
	self.play = PlayUi:WaitForChild("PlayButton") :: GuiObject
	self.solo = SoloButton
	self.done = nil :: boolean?
	self.ready = false

	SoloButton.Activated:Connect(function()
		self:Finish()
	end)
	RunService.RenderStepped:Connect(function()
		self:Render()
	end)
end

function TutorialController:Start()
	task.spawn(function()
		local Done = Remotemanager:InvokeServer("TutorialService", "GetDone")
		if self.done == nil then
			self.done = Done
		end
	end)
	task.spawn(function()
		local Loading = Player:WaitForChild("PlayerGui"):WaitForChild("LoadingUi")
		if not Loading:GetAttribute("Ready") then
			Loading:GetAttributeChangedSignal("Ready"):Wait()
		end
		Core:GetController("TransitionController"):Wait()
		self.ready = true
	end)
end

return TutorialController
