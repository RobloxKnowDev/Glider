local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Scenery = require(ReplicatedStorage.Shared.Utils.Scenery)

local SceneryController = {
	Name = "SceneryController",
	Priority = 12,
}

function SceneryController:Watch(Folder: Instance)
	local function Add(Part: Instance)
		if Part:IsA("BasePart") and Part:GetAttribute("Hinge") then
			self.pieces[Part] = Scenery.Read(Part)
		end
	end
	for _, Part in ipairs(Folder:GetDescendants()) do
		Add(Part)
	end
	Folder.DescendantAdded:Connect(Add)
	Folder.DescendantRemoving:Connect(function(Part)
		self.pieces[Part] = nil
	end)
end

function SceneryController:Pose()
	local Time = Workspace:GetServerTimeNow()
	local Parts: { BasePart } = {}
	local Frames: { CFrame } = {}
	for Part, Piece in pairs(self.pieces) do
		table.insert(Parts, Part)
		table.insert(Frames, Scenery.Pose(Piece, Time))
	end
	Workspace:BulkMoveTo(Parts, Frames, Enum.BulkMoveMode.FireCFrameChanged)
end

function SceneryController:Init()
	self.pieces = {} :: { [BasePart]: Scenery.Piece }
	self:Watch(Workspace:WaitForChild("WindTurbines"))
	self:Watch(Workspace:WaitForChild("AnimatedLog"))
	self:Watch(Workspace:WaitForChild("SpikesModels"))
	self:Watch(Workspace:WaitForChild("BirdsZones"))
	RunService.RenderStepped:Connect(function()
		self:Pose()
	end)
end

return SceneryController
