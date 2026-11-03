local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local CollisionService = {
	Name = "CollisionService",
	Priority = 3,
}

local Group = "Players"

local function Join(Part: Instance)
	if Part:IsA("BasePart") then
		Part.CollisionGroup = Group
	end
end

function CollisionService:Track(Player: Player)
	local function Spawn(Character: Model)
		for _, Part in ipairs(Character:GetChildren()) do
			Join(Part)
		end
		Character.ChildAdded:Connect(Join)
	end
	Player.CharacterAdded:Connect(Spawn)
	if Player.Character then
		task.spawn(Spawn, Player.Character)
	end
end

function CollisionService:Init()
	PhysicsService:RegisterCollisionGroup(Group)
	PhysicsService:CollisionGroupSetCollidable(Group, Group, false)

	Players.PlayerAdded:Connect(function(Player)
		self:Track(Player)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		self:Track(Player)
	end
end

return CollisionService
