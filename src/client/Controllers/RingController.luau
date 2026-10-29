local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)

local RingController = {
	Name = "RingController",
	Priority = 12,
}

type Float = {
	Base: CFrame,
	Phase: number,
}

local FloatHeight = 1
local FloatSpeed = 1.5
local PhaseSpread = 0.05
local PassVolume = 1.5
local White = Color3.new(1, 1, 1)
local GhostScale = 1.8
local GhostInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FlashTransparency = 0.3
local FlashInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function RingController:Pop(Ring: Model)
	Sfx.Play(Sounds.Ring.Pass, PassVolume)
	local Ghost = Ring:Clone()
	Ghost:WaitForChild("Text"):Destroy()
	for _, Item in ipairs(Ghost:GetDescendants()) do
		if Item:IsA("BasePart") then
			Item.Anchored = true
			Item.CanCollide = false
			Item.CanQuery = false
			Item.CanTouch = false
		end
		if Item:IsA("BasePart") or Item:IsA("Decal") then
			TweenService:Create(Item, GhostInfo, { Transparency = 1 }):Play()
		end
	end
	local Scale = Instance.new("NumberValue")
	Scale.Value = Ghost:GetScale()
	Scale.Changed:Connect(function(Value)
		Ghost:ScaleTo(Value)
	end)
	Ghost.Parent = Workspace
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

function RingController:Float(Ring: Model)
	local Origin = Ring:GetPivot().Position
	local Phase = (Origin.X + Origin.Z) * PhaseSpread
	local function Add(Part: Instance)
		if Part:IsA("BasePart") then
			self.floating[Part] = { Base = Part.CFrame, Phase = Phase }
		end
	end
	for _, Part in ipairs(Ring:GetDescendants()) do
		Add(Part)
	end
	Ring.DescendantAdded:Connect(Add)
	Ring.DescendantRemoving:Connect(function(Part)
		self.floating[Part] = nil
	end)
end

function RingController:Init()
	self.floating = {} :: { [BasePart]: Float }
	local Folder = Workspace:WaitForChild("RingsFolder")
	Folder.ChildAdded:Connect(function(Ring)
		self:Float(Ring :: Model)
	end)
	for _, Ring in ipairs(Folder:GetChildren()) do
		self:Float(Ring :: Model)
	end

	RunService.RenderStepped:Connect(function()
		local Time = os.clock()
		local Parts: { BasePart } = {}
		local Frames: { CFrame } = {}
		for Part, Float in pairs(self.floating) do
			table.insert(Parts, Part)
			table.insert(Frames, Float.Base + Vector3.yAxis * math.sin(Time * FloatSpeed + Float.Phase) * FloatHeight)
		end
		Workspace:BulkMoveTo(Parts, Frames, Enum.BulkMoveMode.FireCFrameChanged)
	end)

	Remotemanager:OnClientEvent("GliderService", "Ring", function(Ring)
		self:Pop(Ring)
	end)
end

return RingController
