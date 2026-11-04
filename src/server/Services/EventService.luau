local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local EventService = {
	Name = "EventService",
	Priority = 9,
	Remotes = {
		IsReturning = "Function",
	},
}

function EventService:Init()
	Remotemanager:OnServerInvoke(self.Name, "IsReturning", function(Player)
		local Data = Core:GetService("DataService")
		Data:WaitForLoad(Player)
		return not Data:IsNewProfile(Player)
	end)
end

return EventService
