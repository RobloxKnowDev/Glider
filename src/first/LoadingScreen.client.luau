local Players = game:GetService("Players")
local Replicatedfirst = game:GetService("ReplicatedFirst")

local Displayorder = 10000
local Maximumwait = 25

local Gui = Instance.new("ScreenGui")
Gui.Name = "LoadingUi"
Gui.DisplayOrder = Displayorder
Gui.IgnoreGuiInset = true
Gui.ClipToDeviceSafeArea = false
Gui.ResetOnSpawn = false

local Cover = Instance.new("Frame")
Cover.Name = "Cover"
Cover.AnchorPoint = Vector2.new(0.5, 0.5)
Cover.Position = UDim2.fromScale(0.5, 0.5)
Cover.Size = UDim2.fromScale(3, 3)
Cover.BackgroundColor3 = Color3.new(0, 0, 0)
Cover.BorderSizePixel = 0
Cover.Active = true
Cover.Parent = Gui

Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
Replicatedfirst:RemoveDefaultLoadingScreen()

task.delay(Maximumwait, function()
	Gui:SetAttribute("Ready", true)
end)
if Gui:GetAttribute("Ready") ~= true then
	Gui:GetAttributeChangedSignal("Ready"):Wait()
end
Gui:Destroy()
