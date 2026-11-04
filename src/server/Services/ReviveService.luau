local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Store = require(ReplicatedStorage.Shared.Config.Store)

local ReviveService = {
	Name = "ReviveService",
	Priority = 9,
	Remotes = {
		GetRevives = "Function",
		Updated = "Event",
	},
}

local Ladder = Store.ReviveLadder
local StepSize = 2

local Counts: { [Player]: number } = {}
local Bought: { [Player]: number } = {}

function ReviveService:Get(Player: Player): number
	return Counts[Player] or 0
end

function ReviveService:Step(Player: Player): number
	return math.min((Bought[Player] or 0) // StepSize + 1, #Ladder)
end

function ReviveService:Offer(Player: Player): string
	return Ladder[self:Step(Player)].Name
end

function ReviveService:Push(Player: Player)
	Remotemanager:FireClient(self.Name, "Updated", Player, self:Get(Player), self:Step(Player))
end

function ReviveService:Credit(Player: Player, Amount: number)
	Counts[Player] = self:Get(Player) + Amount
end

function ReviveService:Add(Player: Player, Amount: number)
	self:Credit(Player, Amount)
	self:Push(Player)
	Core:GetService("GliderService"):Refilled(Player)
end

function ReviveService:Climb(Player: Player)
	Bought[Player] = (Bought[Player] or 0) + 1
	self:Push(Player)
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
	local Data = Core:GetService("DataService")
	Data:Register("Revives", {
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
	Data:Register("RevivesBought", {
		Load = function(Player, Saved)
			Bought[Player] = Saved
			self:Push(Player)
		end,
		Save = function(Player)
			return Bought[Player]
		end,
		Clear = function(Player)
			Bought[Player] = nil
		end,
	})

	Remotemanager:OnServerInvoke(self.Name, "GetRevives", function(Player)
		Data:WaitForLoad(Player)
		return self:Get(Player), self:Step(Player)
	end)
end

return ReviveService
