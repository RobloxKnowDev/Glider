local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)

local TransitionController = {
	Name = "TransitionController",
	Priority = 15,
}

local Player = Players.LocalPlayer
local Black = Color3.new(0, 0, 0)
local ShrinkTime = 0.5
local PauseSize = 0.3
local PauseTime = 0.6
local CloseTime = 0.3
local ShutTime = 0.5
local OpenDelay = 0.2
local OpenTime = 0.5
local WhooshVolume = 0.4

local function Reach(Center: Vector2, Screen: Vector2): number
	return Vector2.new(math.max(Center.X, Screen.X - Center.X), math.max(Center.Y, Screen.Y - Center.Y)).Magnitude * 2
end

function TransitionController:Aim(Head: BasePart?): number
	local Screen = self.gui.AbsoluteSize
	local Center = Screen / 2
	if Head then
		local Point, Visible = Workspace.CurrentCamera:WorldToViewportPoint(Head.Position)
		if Visible then
			Center = Vector2.new(Point.X, Point.Y)
		end
	end
	self.stroke.Thickness = Screen.Magnitude
	self.hole.Position = UDim2.fromOffset(Center.X, Center.Y)
	return Reach(Center, Screen)
end

function TransitionController:Iris(Diameter: number, Time: number)
	local Tween = TweenService:Create(self.hole, TweenInfo.new(Time, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Size = UDim2.fromOffset(Diameter, Diameter),
	})
	Tween:Play()
	Tween.Completed:Wait()
end

function TransitionController:Close(Character: Model)
	local Full = self:Aim(Character:FindFirstChild("Head") :: BasePart?)
	self.hole.Size = UDim2.fromOffset(Full, Full)
	self.cover.Visible = false
	self.gui.Enabled = true
	Sfx.Play(Sounds.Transition.Close, WhooshVolume)
	self:Iris(self.gui.AbsoluteSize.Y * PauseSize, ShrinkTime)
	task.wait(PauseTime)
	self:Iris(2, CloseTime)
	self.cover.Visible = true
end

function TransitionController:Shut(Character: Model)
	self.token += 1
	local Full = self:Aim(Character:WaitForChild("Head") :: BasePart)
	self.hole.Size = UDim2.fromOffset(Full, Full)
	self.cover.Visible = false
	self.gui.Enabled = true
	Sfx.Play(Sounds.Transition.Close, WhooshVolume)
	self:Iris(2, ShutTime)
	self.cover.Visible = true
end

function TransitionController:Open(Character: Model, Token: number)
	task.wait(OpenDelay)
	if self.token ~= Token then
		return
	end
	local Full = self:Aim(Character:WaitForChild("Head") :: BasePart)
	self.hole.Size = UDim2.fromOffset(2, 2)
	self.cover.Visible = false
	Sfx.Play(Sounds.Transition.Open, WhooshVolume)
	self:Iris(Full, OpenTime)
	if self.token == Token then
		self.gui.Enabled = false
	end
end

function TransitionController:Play(Character: Model, Ready: () -> Model)
	self.token += 1
	local Token = self.token
	self:Close(Character)
	self:Open(Ready(), Token)
end

function TransitionController:Blackout()
	self.token += 1
	self.cover.Visible = true
	self.gui.Enabled = true
end

function TransitionController:Reveal(Character: Model)
	self:Open(Character, self.token)
end

function TransitionController:Watch(Character: Model)
	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	Humanoid.Died:Connect(function()
		self:Play(Character, function()
			local Next = Player.Character
			if Next == Character or not Next then
				Next = Player.CharacterAdded:Wait()
			end
			return Next
		end)
	end)
end

function TransitionController:Init()
	local Gui = Instance.new("ScreenGui")
	Gui.Name = "TransitionUi"
	Gui.ResetOnSpawn = false
	Gui.IgnoreGuiInset = true
	Gui.DisplayOrder = 1000
	Gui.Enabled = false

	local Hole = Instance.new("Frame")
	Hole.Name = "Hole"
	Hole.AnchorPoint = Vector2.new(0.5, 0.5)
	Hole.BackgroundTransparency = 1
	Hole.Parent = Gui

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0.5, 0)
	Corner.Parent = Hole

	local Stroke = Instance.new("UIStroke")
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Stroke.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	Stroke.Color = Black
	Stroke.Parent = Hole

	local Cover = Instance.new("Frame")
	Cover.Name = "Cover"
	Cover.Size = UDim2.fromScale(1, 1)
	Cover.BackgroundColor3 = Black
	Cover.BorderSizePixel = 0
	Cover.Visible = false
	Cover.Parent = Gui

	Gui.Parent = Player:WaitForChild("PlayerGui")
	self.gui = Gui
	self.hole = Hole
	self.stroke = Stroke
	self.cover = Cover
	self.token = 0

	Player.CharacterAdded:Connect(function(Character)
		self:Watch(Character)
	end)
	if Player.Character then
		task.spawn(self.Watch, self, Player.Character)
	end
end

return TransitionController
