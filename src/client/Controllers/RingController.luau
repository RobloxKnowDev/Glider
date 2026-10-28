local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local RingController = {
	Name = "RingController",
	Priority = 12,
}

local White = Color3.new(1, 1, 1)
local GhostScale = 1.8
local GhostInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FlashTransparency = 0.3
local FlashInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function RingController:Pop(Ring: Model)
	local Ghost = Ring:Clone()
	Ghost:WaitForChild("Text"):Destroy()
	for _, Part in ipairs(Ghost:GetDescendants()) do
		if Part:IsA("BasePart") then
			Part.Anchored = true
			Part.CanCollide = false
			Part.CanQuery = false
			Part.CanTouch = false
			TweenService:Create(Part, GhostInfo, { Transparency = 1 }):Play()
		end
	end
	local Scale = Instance.new("NumberValue")
	Scale.Value = Ghost:GetScale()
	Scale.Changed:Connect(function(Value)
		Ghost:ScaleTo(Value)
	end)
	Ghost.Parent = Ring.Parent
	local Grow = TweenService:Create(Scale, GhostInfo, { Value = Scale.Value * GhostScale })
	Grow.Completed:Once(function()
		Ghost:Destroy()
	end)
	Grow:Play()

	local Flash = Instance.new("Highlight")
	Flash.FillColor = White
	Flash.OutlineColor = White
	Flash.FillTransparency = FlashTransparency
	Flash.DepthMode = Enum.HighlightDepthMode.Occluded
	Flash.Parent = Ring
	local Fade = TweenService:Create(Flash, FlashInfo, { FillTransparency = 1, OutlineTransparency = 1 })
	Fade.Completed:Once(function()
		Flash:Destroy()
	end)
	Fade:Play()
end

function RingController:Init()
	Remotemanager:OnClientEvent("GliderService", "Ring", function(Ring)
		self:Pop(Ring)
	end)
end

return RingController
