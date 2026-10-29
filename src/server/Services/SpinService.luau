local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local SpinService = {
	Name = "SpinService",
	Priority = 9,
	Remotes = {
		GetSpins = "Function",
		Updated = "Event",
	},
}

local Counts: { [Player]: number } = {}

function SpinService:Get(Player: Player): number
	return Counts[Player] or 0
end

function SpinService:Push(Player: Player)
	Remotemanager:FireClient(self.Name, "Updated", Player, self:Get(Player))
end

function SpinService:Add(Player: Player, Amount: number)
	Counts[Player] = self:Get(Player) + Amount
	self:Push(Player)
end

function SpinService:Init()
	Core:GetService("DataService"):Register("Spins", {
		Load = function(Player, Saved)
			Counts[Player] = Saved
			self:Push(Player)
		end,
		Save = function(Player)
			return self:Get(Player)
		end,
		Clear = function(Player)
			Counts[Player] = nil
		end,
	})

	Remotemanager:OnServerInvoke(self.Name, "GetSpins", function(Player)
		Core:GetService("DataService"):WaitForLoad(Player)
		return self:Get(Player)
	end)
end

return SpinService
