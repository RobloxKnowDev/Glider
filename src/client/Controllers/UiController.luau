local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local UiController = {
	Name = "UiController",
	Priority = 5,
}

local BlurSize = 16
local FieldOfViewZoom = 8
local ShadeTransparency = 0.6
local Transition = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function UiController:Backdrop(Shown: boolean)
	TweenService:Create(self.blur, Transition, { Size = if Shown then BlurSize else 0 }):Play()
	TweenService:Create(self.shade, Transition, { BackgroundTransparency = if Shown then ShadeTransparency else 1 }):Play()
	TweenService:Create(Workspace.CurrentCamera, Transition, {
		FieldOfView = if Shown then self.fieldOfView - FieldOfViewZoom else self.fieldOfView,
	}):Play()
end

function UiController:Open(Frame: GuiObject)
	if self.current == Frame then
		return
	end
	if self.current then
		self.current.Visible = false
	else
		self:Backdrop(true)
	end
	local Gui = Frame.Parent :: ScreenGui
	Gui.DisplayOrder = self.layer.DisplayOrder + 1
	self.current = Frame
	Frame.Visible = true
	UiFade.Pop(Frame)
end

function UiController:Close()
	if not self.current then
		return
	end
	self.current.Visible = false
	self.current = nil
	self:Backdrop(false)
end

function UiController:Toggle(Frame: GuiObject)
	if self.current == Frame then
		self:Close()
	else
		self:Open(Frame)
	end
end

function UiController:Init()
	self.fieldOfView = Workspace.CurrentCamera.FieldOfView
	self.blur = Instance.new("BlurEffect")
	self.blur.Size = 0
	self.blur.Parent = Lighting

	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.layer = Instance.new("ScreenGui")
	self.layer.Name = "BackdropUi"
	self.layer.ResetOnSpawn = false
	self.layer.ScreenInsets = Enum.ScreenInsets.None
	self.layer.DisplayOrder = (PlayerGui:WaitForChild("HUD") :: ScreenGui).DisplayOrder + 1
	self.shade = Instance.new("Frame")
	self.shade.Name = "Shade"
	self.shade.Size = UDim2.fromScale(1, 1)
	self.shade.BackgroundColor3 = Color3.new(0, 0, 0)
	self.shade.BackgroundTransparency = 1
	self.shade.BorderSizePixel = 0
	self.shade.Parent = self.layer
	self.layer.Parent = PlayerGui
end

return UiController
