local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local StudsService = {
	Name = "StudsService",
	Priority = 5,
	Remotes = {
		GetStuds = "Function",
		Updated = "Event",
	},
}

local Startingstuds = 1000
local Values: { [Player]: IntValue } = {}

function StudsService:EnsurePlayer(Player: Player): IntValue
	local Value = Values[Player]
	if not Value then
		local Leaderstats = Instance.new("Folder")
		Leaderstats.Name = "leaderstats"
		Value = Instance.new("IntValue")
		Value.Name = "Studs"
		Value.Value = Startingstuds
		Value.Parent = Leaderstats
		Leaderstats.Parent = Player
		Values[Player] = Value
	end
	return Value
end

function StudsService:Push(Player: Player, Gained: number)
	Remotemanager:FireClient(self.Name, "Updated", Player, self:EnsurePlayer(Player).Value, Gained)
end

function StudsService:Add(Player: Player, Amount: number)
	self:EnsurePlayer(Player).Value += Amount
	self:Push(Player, Amount)
end

function StudsService:Spend(Player: Player, Amount: number): boolean
	local Value = self:EnsurePlayer(Player)
	if Value.Value < Amount then
		return false
	end
	Value.Value -= Amount
	self:Push(Player, 0)
	return true
end

function StudsService:Init()
	Core:GetService("DataService"):Register("Studs", {
		Load = function(Player, Saved)
			self:EnsurePlayer(Player).Value = Saved
			self:Push(Player, 0)
		end,
		Save = function(Player)
			return self:EnsurePlayer(Player).Value
		end,
		Clear = function(Player)
			Values[Player] = nil
		end,
	})

	Remotemanager:OnServerInvoke(self.Name, "GetStuds", function(Player)
		Core:GetService("DataService"):WaitForLoad(Player)
		return self:EnsurePlayer(Player).Value
	end)
	Players.PlayerAdded:Connect(function(Player)
		self:EnsurePlayer(Player)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		self:EnsurePlayer(Player)
	end
end

return StudsService
