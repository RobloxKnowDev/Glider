local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local CollisionService = {
	Name = "CollisionService",
	Priority = 3,
}

local Groups = { "Players", "Gliders", "Ragdolls" }

local function Join(Part: Instance)
	if Part:IsA("BasePart") then
		Part.CollisionGroup = "Players"
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

function CollisionService:Glider(Glider: Model)
	for _, Part in ipairs(Glider:GetDescendants()) do
		if Part:IsA("BasePart") then
			Part.CollisionGroup = "Gliders"
		end
	end
end

function CollisionService:Init()
	for _, Group in ipairs(Groups) do
		PhysicsService:RegisterCollisionGroup(Group)
	end
	for _, First in ipairs(Groups) do
		for _, Second in ipairs(Groups) do
			PhysicsService:CollisionGroupSetCollidable(First, Second, false)
		end
	end

	Players.PlayerAdded:Connect(function(Player)
		self:Track(Player)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		self:Track(Player)
	end
end

return CollisionService
