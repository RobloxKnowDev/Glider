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

local DayLength = 86400
local DayCheck = 10
local LaunchDay = DateTime.fromUniversalTime(2026, 11, 4).UnixTimestamp // DayLength

local Sections = {
	Solo = "Record",
	Duo = "DuoRecord",
}
local Records: { [string]: { [Player]: number } } = {
	Solo = {},
	Duo = {},
}
local Bests: { [string]: { [Player]: number } } = {
	Solo = {},
	Duo = {},
}
local Runs: { [Player]: Run } = {}

local function Lowest(First: number?, Second: number?): number?
	if First and Second then
		return math.min(First, Second)
	end
	return First or Second
end

function RecordService:Today(): number
	return os.time() // DayLength
end

function RecordService:IsLaunchDay(): boolean
	return self:Today() == LaunchDay
end

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

function RecordService:Roll()
	local Today = self:Today()
	if Today == self.day then
		return
	end
	self.day = Today
	for _, List in pairs(Records) do
		table.clear(List)
	end
	for _, Player in ipairs(Players:GetPlayers()) do
		self:Push(Player)
	end
end

function RecordService:Settle(Player: Player)
	Core:GetService("DataService"):WaitForLoad(Player)
	for Mode, List in pairs(Records) do
		local Time = List[Player]
		if Time then
			Core:GetService("LeaderboardService"):Post(Mode, Player, Time, false)
		end
	end
end

function RecordService:Finish(Player: Player, Mode: string): (number, boolean)
	self:Pause(Player)
	self:Roll()
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
	Bests[Mode][Player] = Lowest(Bests[Mode][Player], Time)
	self:Push(Player)
	Core:GetService("LeaderboardService"):Post(Mode, Player, Time, true)
	return Time, true
end

function RecordService:Init()
	self.day = self:Today()
	local Data = Core:GetService("DataService")
	for Mode, Section in pairs(Sections) do
		Data:Register(Section, {
			Load = function(Player, Saved)
				self:Roll()
				Bests[Mode][Player] = Lowest(Bests[Mode][Player], Saved)
				if self.day == LaunchDay then
					Records[Mode][Player] = Lowest(Records[Mode][Player], Saved)
				end
			end,
			Save = function(Player)
				return Bests[Mode][Player]
			end,
			Clear = function(Player)
				Bests[Mode][Player] = nil
			end,
		})
	end
	Data:Register("Daily", {
		Load = function(Player, Saved)
			self:Roll()
			if Saved.Day ~= self.day then
				return
			end
			for Mode, List in pairs(Records) do
				List[Player] = Lowest(List[Player], Saved[Mode])
				Bests[Mode][Player] = Lowest(Bests[Mode][Player], Saved[Mode])
			end
		end,
		Save = function(Player)
			return { Day = self.day, Solo = Records.Solo[Player], Duo = Records.Duo[Player] }
		end,
		Clear = function(Player)
			for _, List in pairs(Records) do
				List[Player] = nil
			end
		end,
	})

	Remotemanager:OnServerInvoke(self.Name, "GetRecord", function(Player)
		Data:WaitForLoad(Player)
		return Records.Solo[Player], Records.Duo[Player]
	end)
	Players.PlayerAdded:Connect(function(Player)
		self:Settle(Player)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(self.Settle, self, Player)
	end
	Players.PlayerRemoving:Connect(function(Player)
		Runs[Player] = nil
	end)
end

function RecordService:Start()
	task.spawn(function()
		while true do
			task.wait(DayCheck)
			self:Roll()
		end
	end)
end

return RecordService
