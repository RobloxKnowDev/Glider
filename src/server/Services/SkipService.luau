local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local SkipService = {
	Name = "SkipService",
	Priority = 9,
	Remotes = {
		GetSkips = "Function",
		Updated = "Event",
	},
}

local Counts: { [Player]: number } = {}

function SkipService:Get(Player: Player): number
	return Counts[Player] or 0
end

function SkipService:Push(Player: Player)
	Remotemanager:FireClient(self.Name, "Updated", Player, self:Get(Player))
end

function SkipService:Add(Player: Player, Amount: number)
	Counts[Player] = self:Get(Player) + Amount
	self:Push(Player)
end

function SkipService:Init()
	Core:GetService("DataService"):Register("Skips", {
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

	Remotemanager:OnServerInvoke(self.Name, "GetSkips", function(Player)
		Core:GetService("DataService"):WaitForLoad(Player)
		return self:Get(Player)
	end)
end

return SkipService
