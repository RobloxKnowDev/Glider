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

local Records: { [Player]: number } = {}
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

function RecordService:Finish(Player: Player)
	self:Pause(Player)
	local Levels = Core:GetService("LevelService")
	if Levels:Get(Player) <= Levels:Count() or not Runs[Player].Clean then
		return
	end
	local Time = Runs[Player].Elapsed
	local Record = Records[Player]
	if Record and Record <= Time then
		return
	end
	Records[Player] = Time
	Remotemanager:FireClient(self.Name, "Updated", Player, Time)
end

function RecordService:Init()
	Core:GetService("DataService"):Register("Record", {
		Load = function(Player, Saved)
			Records[Player] = Saved
			Remotemanager:FireClient(self.Name, "Updated", Player, Saved)
		end,
		Save = function(Player)
			return Records[Player]
		end,
		Clear = function(Player)
			Records[Player] = nil
		end,
	})

	Remotemanager:OnServerInvoke(self.Name, "GetRecord", function(Player)
		Core:GetService("DataService"):WaitForLoad(Player)
		return Records[Player]
	end)
	Players.PlayerRemoving:Connect(function(Player)
		Runs[Player] = nil
	end)
end

return RecordService
