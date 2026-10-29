local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local LevelService = {
	Name = "LevelService",
	Priority = 9,
	Remotes = {
		Reset = "Event",
	},
}

local Levels: { [Player]: number } = {}

function LevelService:Get(Player: Player): number
	return Levels[Player] or 1
end

function LevelService:Reach(Player: Player, Level: number)
	if Level == self:Get(Player) + 1 then
		Levels[Player] = Level
	end
end

function LevelService:Reset(Player: Player)
	Levels[Player] = 1
	Core:GetService("RecordService"):Reset(Player)
	Remotemanager:FireClient(self.Name, "Reset", Player)
end

function LevelService:Set(Player: Player, Level: number)
	Levels[Player] = Level
	Core:GetService("RecordService"):Taint(Player)
end

function LevelService:Count(): number
	return #self.spawns
end

function LevelService:Place(Character: Model, Spawn: BasePart, Shift: number)
	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	local Root = Character:WaitForChild("HumanoidRootPart") :: BasePart
	local Look = Spawn.CFrame.LookVector
	local Lift = Spawn.Size.Y / 2 + Humanoid.HipHeight + Root.Size.Y / 2
	Character:PivotTo(
		CFrame.new(Spawn.Position + Vector3.yAxis * Lift)
			* CFrame.Angles(0, math.atan2(-Look.X, -Look.Z), 0)
			* CFrame.new(Shift, 0, 0)
	)
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero
end

function LevelService:Land(Player: Player, Character: Model, Shift: number)
	self:Place(Character, self.spawns[self:Get(Player)] or self.spawns[1], Shift)
end

function LevelService:Track(Player: Player)
	local function Spawn(Character: Model)
		Character:WaitForChild("HumanoidRootPart")
		task.wait()
		self:Land(Player, Character, 0)
	end
	Player.CharacterAdded:Connect(Spawn)
	if Player.Character then
		task.spawn(Spawn, Player.Character)
	end
end

function LevelService:Init()
	local Folder = Workspace:WaitForChild("Level")
	self.spawns = {} :: { BasePart }
	for Index = 1, #Folder:GetChildren() do
		table.insert(self.spawns, Folder:WaitForChild(tostring(Index)):WaitForChild("SpawnLocation") :: BasePart)
	end

	Players.PlayerAdded:Connect(function(Player)
		self:Track(Player)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		self:Track(Player)
	end
	Players.PlayerRemoving:Connect(function(Player)
		Levels[Player] = nil
	end)
end

return LevelService
