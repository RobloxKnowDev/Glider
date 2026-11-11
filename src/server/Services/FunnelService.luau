local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local FunnelService = {
	Name = "FunnelService",
	Priority = 2,
	Remotes = {
		Play = "Event",
	},
}

local Levels = 14
local Steps = { "Welcome", "Play", "Solo" }
for Level = 1, Levels do
	table.insert(Steps, "Level " .. Level .. " Passed")
end
table.insert(Steps, "Race Finished")
table.insert(Steps, "Crate Opened")

local Numbers: { [string]: number } = {}
for Index, Step in ipairs(Steps) do
	Numbers[Step] = Index
end
local Logged: { [Player]: { [string]: boolean } } = {}

function FunnelService:Log(Player: Player, Step: string)
	local Done = Logged[Player]
	if not Done or Done[Step] then
		return
	end
	Done[Step] = true
	AnalyticsService:LogOnboardingFunnelStepEvent(Player, Numbers[Step], Step)
end

function FunnelService:Pass(Player: Player, Level: number)
	if Level <= Levels then
		self:Log(Player, "Level " .. Level .. " Passed")
	end
end

function FunnelService:Welcome(Player: Player)
	Logged[Player] = {}
	self:Log(Player, "Welcome")
end

function FunnelService:Init()
	Remotemanager:OnServerEvent(self.Name, "Play", function(Player)
		self:Log(Player, "Play")
	end)
	Players.PlayerAdded:Connect(function(Player)
		self:Welcome(Player)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		self:Welcome(Player)
	end
	Players.PlayerRemoving:Connect(function(Player)
		Logged[Player] = nil
	end)
end

return FunnelService
