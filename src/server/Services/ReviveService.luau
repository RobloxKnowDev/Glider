local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local ReviveService = {
	Name = "ReviveService",
	Priority = 9,
	Remotes = {
		GetRevives = "Function",
		Updated = "Event",
	},
}

local Counts: { [Player]: number } = {}

function ReviveService:Get(Player: Player): number
	return Counts[Player] or 0
end

function ReviveService:Push(Player: Player)
	Remotemanager:FireClient(self.Name, "Updated", Player, self:Get(Player))
end

function ReviveService:Add(Player: Player, Amount: number)
	Counts[Player] = self:Get(Player) + Amount
	self:Push(Player)
	Core:GetService("GliderService"):Refilled(Player)
end

function ReviveService:Use(Player: Player): boolean
	local Count = self:Get(Player)
	if Count < 1 then
		return false
	end
	Counts[Player] = Count - 1
	self:Push(Player)
	return true
end

function ReviveService:Init()
	Core:GetService("DataService"):Register("Revives", {
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

	Remotemanager:OnServerInvoke(self.Name, "GetRevives", function(Player)
		Core:GetService("DataService"):WaitForLoad(Player)
		return self:Get(Player)
	end)
end

return ReviveService
