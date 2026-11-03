local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)

local PlaytimeService = {
	Name = "PlaytimeService",
	Priority = 6,
}

local Banked: { [Player]: number } = {}
local Joined: { [Player]: number } = {}

function PlaytimeService:Get(Player: Player): number
	return (Banked[Player] or 0) + os.clock() - Joined[Player]
end

function PlaytimeService:Init()
	Core:GetService("DataService"):Register("Playtime", {
		Load = function(Player, Saved)
			Banked[Player] = Saved
		end,
		Save = function(Player)
			return math.floor(self:Get(Player))
		end,
		Clear = function(Player)
			Banked[Player] = nil
			Joined[Player] = nil
		end,
	})

	Players.PlayerAdded:Connect(function(Player)
		Joined[Player] = os.clock()
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		Joined[Player] = os.clock()
	end
end

return PlaytimeService
