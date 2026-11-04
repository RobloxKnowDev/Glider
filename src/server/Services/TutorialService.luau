local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local TutorialService = {
	Name = "TutorialService",
	Priority = 9,
	Remotes = {
		GetDone = "Function",
		Done = "Event",
	},
}

local Finished: { [Player]: boolean } = {}

function TutorialService:Init()
	local Data = Core:GetService("DataService")
	Data:Register("Tutorial", {
		Load = function(Player, Saved)
			Finished[Player] = Saved
		end,
		Save = function(Player)
			return Finished[Player]
		end,
		Clear = function(Player)
			Finished[Player] = nil
		end,
	})

	Remotemanager:OnServerInvoke(self.Name, "GetDone", function(Player)
		Data:WaitForLoad(Player)
		return Finished[Player] == true
	end)
	Remotemanager:OnServerEvent(self.Name, "Done", function(Player)
		Finished[Player] = true
	end)
end

return TutorialService
