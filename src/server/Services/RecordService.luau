local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local RecordService = {
	Name = "RecordService",
	Priority = 9,
	Remotes = {
		GetRecord = "Function",
		Updated = "Event",
	},
}

type Run = {
	Elapsed: number,
	Since: number?,
	Clean: boolean,
}

local Sections = {
	Solo = "Record",
	Duo = "DuoRecord",
}
local Records: { [string]: { [Player]: number } } = {
	Solo = {},
	Duo = {},
}
local Runs: { [Player]: Run } = {}

function RecordService:Run(Player: Player): Run
	local Run = Runs[Player]
	if not Run then
		Run = { Elapsed = 0, Since = nil, Clean = true }
		Runs[Player] = Run
	end
	return Run
end

function RecordService:Resume(Player: Player)
	self:Run(Player).Since = os.clock()
end

function RecordService:Pause(Player: Player)
	local Run = Runs[Player]
	if Run and Run.Since then
		Run.Elapsed += os.clock() - Run.Since
		Run.Since = nil
	end
end

function RecordService:Reset(Player: Player)
	Runs[Player] = nil
end

function RecordService:Taint(Player: Player)
	self:Run(Player).Clean = false
end

function RecordService:Push(Player: Player)
	Remotemanager:FireClient(self.Name, "Updated", Player, Records.Solo[Player], Records.Duo[Player])
end

function RecordService:Finish(Player: Player, Mode: string): (number, boolean)
	self:Pause(Player)
	local Levels = Core:GetService("LevelService")
	local Run = self:Run(Player)
	local Time = Run.Elapsed
	if Levels:Get(Player) <= Levels:Count() or not Run.Clean then
		return Time, false
	end
	local Record = Records[Mode][Player]
	if Record and Record <= Time then
		return Time, false
	end
	Records[Mode][Player] = Time
	self:Push(Player)
	Core:GetService("LeaderboardService"):Post(Mode, Player, Time, true)
	return Time, true
end

function RecordService:Init()
	for Mode, Section in pairs(Sections) do
		Core:GetService("DataService"):Register(Section, {
			Load = function(Player, Saved)
				Records[Mode][Player] = Saved
				self:Push(Player)
				Core:GetService("LeaderboardService"):Post(Mode, Player, Saved, false)
			end,
			Save = function(Player)
				return Records[Mode][Player]
			end,
			Clear = function(Player)
				Records[Mode][Player] = nil
			end,
		})
	end

	Remotemanager:OnServerInvoke(self.Name, "GetRecord", function(Player)
		Core:GetService("DataService"):WaitForLoad(Player)
		return Records.Solo[Player], Records.Duo[Player]
	end)
	Players.PlayerRemoving:Connect(function(Player)
		Runs[Player] = nil
	end)
end

return RecordService
