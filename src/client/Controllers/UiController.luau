local Lighting = game:GetService("Lighting")
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
local Transition = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function UiController:Backdrop(Shown: boolean)
	TweenService:Create(self.blur, Transition, { Size = if Shown then BlurSize else 0 }):Play()
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
end

return UiController
