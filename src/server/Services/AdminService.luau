local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Chrono = require(ReplicatedStorage.Shared.Utils.Chrono)
local FormatDuration = require(ReplicatedStorage.Shared.Utils.DurationFormatter)
local NumberAbbreviator = require(ReplicatedStorage.Shared.Utils.NumberAbbreviator)

local AdminService = {
	Name = "AdminService",
	Priority = 20,
	Remotes = {
		IsAdmin = "Function",
		Run = "Function",
	},
}

type Account = {
	UserId: number,
	Name: string,
	Player: Player?,
}

type Command = {
	Name: string,
	Usage: string,
	Description: string,
	Arguments: number,
	Target: number?,
	Anywhere: boolean?,
	Run: ((Args: { string }) -> string)?,
	Live: ((Player: Player, Args: { string }) -> string)?,
	Offline: ((Account: Account, Args: { string }) -> string)?,
}

type Item = {
	Category: string,
	Name: string,
}

type Reply = {
	Success: boolean,
	Result: string,
}

local Admins: { [number]: boolean } = {
	[2024446314] = true,
	[2024462699] = true,
}
local ResetMessage = "Your data was reset. Please rejoin."
local RequestTopic = "AdminRequest"
local ReplyTopic = "AdminReply"
local ReplyTimeout = 10
local ReplyPoll = 0.1
local ReplyLimit = 900
local PlayerHelp = "[player]: name in this server, exact username or #UserId (other server or offline too)"
local Categories = { "Gliders", "Trails" }
local Catalogs = {
	Gliders = require(ReplicatedStorage.Shared.Config.Gliders),
	Trails = require(ReplicatedStorage.Shared.Config.Trails),
}

local Pending: { [string]: boolean } = {}
local Replies: { [string]: Reply } = {}

local function Present(Player: Player): Account
	return { UserId = Player.UserId, Name = Player.Name, Player = Player }
end

local function Find(Admin: Player?, Name: string?): Account
	if not Name or string.lower(Name) == "me" then
		if not Admin then
			error("No player given", 0)
		end
		return Present(Admin)
	end
	local UserId = if string.sub(Name, 1, 1) == "#" then tonumber(string.sub(Name, 2)) else nil
	if not UserId then
		local Search = string.lower(Name)
		local Found: Player? = nil
		for _, Player in ipairs(Players:GetPlayers()) do
			local Username = string.lower(Player.Name)
			if Username == Search then
				Found = Player
				break
			end
			if string.sub(Username, 1, #Search) == Search or string.sub(string.lower(Player.DisplayName), 1, #Search) == Search then
				Found = Player
			end
		end
		if Found then
			return Present(Found)
		end
		local Success, Result = pcall(Players.GetUserIdFromNameAsync, Players, Name)
		if not Success then
			error("No player named " .. Name, 0)
		end
		UserId = Result
	end
	local Player = Players:GetPlayerByUserId(UserId :: number)
	if Player then
		return Present(Player)
	end
	local Success, Username = pcall(Players.GetNameFromUserIdAsync, Players, UserId)
	return { UserId = UserId :: number, Name = if Success then Username else "#" .. UserId, Player = nil }
end

local function Amount(Text: string, Minimum: number): number
	local Value = tonumber(Text)
	if not Value or Value % 1 ~= 0 or Value < Minimum then
		error("Amount must be a whole number of at least " .. Minimum, 0)
	end
	return Value
end

local function Items(Name: string): { Item }
	local Search = string.lower(Name)
	local Found: { Item } = {}
	for _, Category in ipairs(Categories) do
		for _, Entry in ipairs(Catalogs[Category].List) do
			if Search == "all" or Search == string.lower(Category) or Search == string.lower((string.gsub(Entry.Name, " ", ""))) then
				table.insert(Found, { Category = Category, Name = Entry.Name })
			end
		end
	end
	if #Found == 0 then
		error("No item named " .. Name .. ", type items", 0)
	end
	return Found
end

local function Summary(Names: { string }, Name: string, Verb: string, Empty: string): string
	if #Names == 0 then
		return Empty
	end
	return Verb .. " " .. table.concat(Names, ", ") .. " - " .. Name
end

local function Edit(Account: Account, Change: ({ [string]: any }) -> any): any
	local Success, Result = Core:GetService("DataService"):Edit(Account.UserId, Change)
	if not Success then
		error("Could not edit the save of " .. Account.Name .. ": " .. tostring(Result), 0)
	end
	return Result
end

local function Bump(Account: Account, Section: string, Value: number): number
	return Edit(Account, function(Data)
		Data[Section] = (Data[Section] or 0) + Value
		return Data[Section]
	end)
end

local function Stock(Data: { [string]: any }, Category: string): { Owned: { string }, Equipped: string }
	local Default = Catalogs[Category].Default
	if not Data[Category] then
		Data[Category] = { Owned = { Default }, Equipped = Default }
	end
	return Data[Category]
end

local function Reset(Account: Account): string
	local Success, Result = Core:GetService("DataService"):Wipe(Account.UserId)
	if not Success then
		error("Could not reset the data: " .. Result, 0)
	end
	local Erased, Problem = Core:GetService("LeaderboardService"):Erase(Account.UserId)
	if Account.Player then
		task.defer(Account.Player.Kick, Account.Player, ResetMessage)
	end
	if not Erased then
		error("Data reset (" .. Result .. "), but the leaderboards could not be cleared: " .. tostring(Problem), 0)
	end
	return "Data and leaderboards reset (" .. Result .. ") - " .. Account.Name
end

local function Best(Time: number?): string
	return if Time then Chrono(Time) else "--:--.--"
end

local function Stamp(Milliseconds: number): string
	return DateTime.fromUnixTimestampMillis(Milliseconds):FormatUniversalTime("YYYY-MM-DD HH:mm", "en-us") .. " UTC"
end

local function Holdings(Inventory: { Owned: { string }, Equipped: string }?, Category: string): string
	local Catalog = Catalogs[Category]
	if not Inventory then
		return Category .. ": " .. Catalog.Default .. " only"
	end
	return string.format(
		"%s (%d/%d, equipped %s): %s",
		Category,
		#Inventory.Owned,
		#Catalog.List,
		Inventory.Equipped,
		table.concat(Inventory.Owned, ", ")
	)
end

local function Bought(Purchase: { Item: string, Robux: number, Time: number, Note: string?, Studio: boolean? }): string
	local Parts = { Stamp(Purchase.Time * 1000), Purchase.Item }
	if Purchase.Robux > 0 then
		table.insert(Parts, Purchase.Robux .. " Robux")
	end
	if Purchase.Note then
		table.insert(Parts, Purchase.Note)
	end
	if Purchase.Studio then
		table.insert(Parts, "Studio test")
	end
	return "  " .. table.concat(Parts, " | ")
end

local function Inspect(Account: Account): string
	local Data = Core:GetService("DataService")
	local Read, Saved, Info = Data:Read(Account.UserId)
	if not Read then
		error("Could not read the save of " .. Account.Name .. ": " .. tostring(Saved), 0)
	end
	local Sections = Saved
	local Status = "offline"
	if Account.Player then
		local Peeked, Snapshot = Data:Peek(Account.Player)
		if Peeked then
			Sections = Snapshot
		end
		Status = "in this server"
	elseif Info and Info.Session and Info.Session.Active then
		Status = if Info.Session.Studio then "in a Studio session" else "in another server"
	end
	local Header = Account.Name .. " (#" .. Account.UserId .. ") - " .. Status
	if type(Sections) ~= "table" then
		return Header .. "\nNo save"
	end
	local Passes = Sections.Passes or {}
	local Today = Core:GetService("RecordService"):Today()
	local Daily = if Sections.Daily and Sections.Daily.Day == Today then Sections.Daily else {}
	local Lines = {
		Header,
		"Playtime: " .. FormatDuration(Sections.Playtime or 0),
		"Cash: " .. NumberAbbreviator(Sections.Studs or 0) .. "$ | Robux spent: " .. NumberAbbreviator(Sections.Spent or 0),
		"Daily best solo: " .. Best(Daily.Solo) .. " | Daily best duo: " .. Best(Daily.Duo),
		"All-time best solo: " .. Best(Sections.Record) .. " | All-time best duo: " .. Best(Sections.DuoRecord),
		"Revives: " .. (Sections.Revives or 0) .. " (" .. (Sections.RevivesBought or 0) .. " bought after a crash) | Skips: " .. (Sections.Skips or 0) .. " | Spins: " .. (Sections.Spins or 0),
	}
	for _, Category in ipairs(Categories) do
		table.insert(Lines, Holdings(Sections[Category], Category))
	end
	table.insert(Lines, "Packs: " .. (if #Passes > 0 then table.concat(Passes, ", ") else "none"))
	local History = Sections.History or {}
	table.insert(Lines, "Purchase log: " .. (if #History > 0 then #History .. " entries" else "none"))
	for _, Purchase in ipairs(History) do
		table.insert(Lines, Bought(Purchase))
	end
	table.insert(Lines, "Group reward: " .. (if Sections.Group then "claimed" else "not claimed"))
	table.insert(Lines, "Tutorial: " .. (if Sections.Tutorial then "done" else "not done"))
	if Account.Player then
		table.insert(Lines, "Level: " .. Core:GetService("LevelService"):Get(Account.Player) .. " (this session)")
	end
	if Info then
		local Purchases = #(Saved._Purchases or {})
		table.insert(Lines, "Save: created " .. Stamp(Info.Created) .. ", updated " .. Stamp(Info.Updated) .. ", " .. Purchases .. " purchases")
	end
	return table.concat(Lines, "\n")
end

local Commands: { Command }
Commands = {
	{
		Name = "help",
		Usage = "help",
		Description = "List the commands",
		Arguments = 0,
		Run = function()
			local Lines = { PlayerHelp }
			for _, Command in ipairs(Commands) do
				table.insert(Lines, Command.Usage .. "  -  " .. Command.Description)
			end
			return table.concat(Lines, "\n")
		end,
	},
	{
		Name = "items",
		Usage = "items",
		Description = "List the gliders and trails",
		Arguments = 0,
		Run = function()
			local Lines = {}
			for _, Category in ipairs(Categories) do
				local Names = {}
				for _, Entry in ipairs(Catalogs[Category].List) do
					table.insert(Names, Entry.Name)
				end
				table.insert(Lines, Category .. ": " .. table.concat(Names, ", "))
			end
			return table.concat(Lines, "\n")
		end,
	},
	{
		Name = "inspect",
		Usage = "inspect [player]",
		Description = "Show the playtime, Cash, Robux spent, records, items and save of a player",
		Arguments = 0,
		Target = 1,
		Anywhere = true,
		Live = function(Player)
			return Inspect(Present(Player))
		end,
		Offline = function(Account)
			return Inspect(Account)
		end,
	},
	{
		Name = "studs",
		Usage = "studs <amount> [player]",
		Description = "Give Studs",
		Arguments = 1,
		Target = 2,
		Live = function(Player, Args)
			local Value = Amount(Args[1], 1)
			Core:GetService("StudsService"):Add(Player, Value)
			return "Gave " .. Value .. "$ - " .. Player.Name
		end,
		Offline = function(Account, Args)
			local Value = Amount(Args[1], 1)
			local Total = Bump(Account, "Studs", Value)
			return "Gave " .. Value .. "$ (" .. Total .. "$ total) - " .. Account.Name
		end,
	},
	{
		Name = "setstuds",
		Usage = "setstuds <amount> [player]",
		Description = "Set the Studs balance",
		Arguments = 1,
		Target = 2,
		Live = function(Player, Args)
			local Value = Amount(Args[1], 0)
			Core:GetService("StudsService"):Set(Player, Value)
			return "Balance set to " .. Value .. "$ - " .. Player.Name
		end,
		Offline = function(Account, Args)
			local Value = Amount(Args[1], 0)
			Edit(Account, function(Data)
				Data.Studs = Value
			end)
			return "Balance set to " .. Value .. "$ - " .. Account.Name
		end,
	},
	{
		Name = "revives",
		Usage = "revives <amount> [player]",
		Description = "Give revives",
		Arguments = 1,
		Target = 2,
		Live = function(Player, Args)
			local Value = Amount(Args[1], 1)
			local Revives = Core:GetService("ReviveService")
			Revives:Add(Player, Value)
			return "Gave " .. Value .. " revives (" .. Revives:Get(Player) .. " total) - " .. Player.Name
		end,
		Offline = function(Account, Args)
			local Value = Amount(Args[1], 1)
			return "Gave " .. Value .. " revives (" .. Bump(Account, "Revives", Value) .. " total) - " .. Account.Name
		end,
	},
	{
		Name = "skips",
		Usage = "skips <amount> [player]",
		Description = "Give skips",
		Arguments = 1,
		Target = 2,
		Live = function(Player, Args)
			local Value = Amount(Args[1], 1)
			local Skips = Core:GetService("SkipService")
			Skips:Add(Player, Value)
			return "Gave " .. Value .. " skips (" .. Skips:Get(Player) .. " total) - " .. Player.Name
		end,
		Offline = function(Account, Args)
			local Value = Amount(Args[1], 1)
			return "Gave " .. Value .. " skips (" .. Bump(Account, "Skips", Value) .. " total) - " .. Account.Name
		end,
	},
	{
		Name = "spins",
		Usage = "spins <amount> [player]",
		Description = "Give wheel spins",
		Arguments = 1,
		Target = 2,
		Live = function(Player, Args)
			local Value = Amount(Args[1], 1)
			local Spins = Core:GetService("SpinService")
			Spins:Add(Player, Value)
			return "Gave " .. Value .. " spins (" .. Spins:Get(Player) .. " total) - " .. Player.Name
		end,
		Offline = function(Account, Args)
			local Value = Amount(Args[1], 1)
			return "Gave " .. Value .. " spins (" .. Bump(Account, "Spins", Value) .. " total) - " .. Account.Name
		end,
	},
	{
		Name = "spent",
		Usage = "spent <amount> [player]",
		Description = "Set the Robux spent shown on the top spenders leaderboard (0 removes the player)",
		Arguments = 1,
		Target = 2,
		Live = function(Player, Args)
			local Value = Amount(Args[1], 0)
			if Player.UserId <= 0 then
				error("Test players are not shown on the leaderboards", 0)
			end
			Core:GetService("LeaderboardService"):Set(Player, Value)
			return "Robux spent set to " .. Value .. " - " .. Player.Name
		end,
		Offline = function(Account, Args)
			local Value = Amount(Args[1], 0)
			Edit(Account, function(Data)
				Data.Spent = Value
			end)
			Core:GetService("LeaderboardService"):Write("Robux", Account.UserId, Value, true)
			return "Robux spent set to " .. Value .. " - " .. Account.Name
		end,
	},
	{
		Name = "level",
		Usage = "level <number> [player]",
		Description = "Set the level and teleport to its SpawnLocation (the next Play starts from its SpawnPart, not saved)",
		Arguments = 1,
		Target = 2,
		Live = function(Player, Args)
			local Levels = Core:GetService("LevelService")
			local Value = Amount(Args[1], 1)
			if Value > Levels:Count() then
				error("There are only " .. Levels:Count() .. " levels", 0)
			end
			if Core:GetService("GliderService"):IsFlying(Player) then
				error(Player.Name .. " is flying", 0)
			end
			Levels:Visit(Player.Character, Value)
			Levels:Set(Player, Value)
			return "Level set to " .. Value .. " - " .. Player.Name
		end,
	},
	{
		Name = "give",
		Usage = "give <item|gliders|trails|all> [player]",
		Description = "Give gliders or trails",
		Arguments = 1,
		Target = 2,
		Live = function(Player, Args)
			local Inventory = Core:GetService("InventoryService")
			local Given = {}
			for _, Item in ipairs(Items(Args[1])) do
				if Inventory:Give(Player, Item.Category, Item.Name) then
					table.insert(Given, Item.Name)
				end
			end
			return Summary(Given, Player.Name, "Gave", "Already owned")
		end,
		Offline = function(Account, Args)
			local Wanted = Items(Args[1])
			local Given = Edit(Account, function(Data)
				local Added = {}
				for _, Item in ipairs(Wanted) do
					local Owned = Stock(Data, Item.Category).Owned
					if not table.find(Owned, Item.Name) then
						table.insert(Owned, Item.Name)
						table.insert(Added, Item.Name)
					end
				end
				return Added
			end)
			return Summary(Given, Account.Name, "Gave", "Already owned")
		end,
	},
	{
		Name = "take",
		Usage = "take <item|gliders|trails|all> [player]",
		Description = "Remove gliders or trails (not the default ones)",
		Arguments = 1,
		Target = 2,
		Live = function(Player, Args)
			local Inventory = Core:GetService("InventoryService")
			local Taken = {}
			for _, Item in ipairs(Items(Args[1])) do
				if Inventory:Take(Player, Item.Category, Item.Name) then
					table.insert(Taken, Item.Name)
				end
			end
			return Summary(Taken, Player.Name, "Took", "Nothing to take")
		end,
		Offline = function(Account, Args)
			local Wanted = Items(Args[1])
			local Taken = Edit(Account, function(Data)
				local Removed = {}
				for _, Item in ipairs(Wanted) do
					local Default = Catalogs[Item.Category].Default
					local Inventory = Stock(Data, Item.Category)
					local Index = table.find(Inventory.Owned, Item.Name)
					if Index and Item.Name ~= Default then
						table.remove(Inventory.Owned, Index)
						table.insert(Removed, Item.Name)
						if Inventory.Equipped == Item.Name then
							Inventory.Equipped = Default
						end
					end
				end
				return Removed
			end)
			return Summary(Taken, Account.Name, "Took", "Nothing to take")
		end,
	},
	{
		Name = "resetdata",
		Usage = "resetdata [player]",
		Description = "Erase the save and the leaderboard entries, then kick the player",
		Arguments = 0,
		Target = 1,
		Live = function(Player)
			return Reset(Present(Player))
		end,
		Offline = function(Account)
			return Reset(Account)
		end,
	},
}

function AdminService:IsAdmin(Player: Player): boolean
	return RunService:IsStudio()
		or Admins[Player.UserId] == true
		or (game.CreatorType == Enum.CreatorType.User and game.CreatorId == Player.UserId)
end

function AdminService:Forward(Job: string, Text: string): string
	local Id = HttpService:GenerateGUID(false)
	Pending[Id] = true
	local Published, Problem = pcall(MessagingService.PublishAsync, MessagingService, RequestTopic, {
		Job = Job,
		From = game.JobId,
		Id = Id,
		Text = Text,
	})
	if not Published then
		Pending[Id] = nil
		error("Could not reach the other server: " .. tostring(Problem), 0)
	end
	local Deadline = os.clock() + ReplyTimeout
	while not Replies[Id] and os.clock() < Deadline do
		task.wait(ReplyPoll)
	end
	local Answer = Replies[Id]
	Pending[Id] = nil
	Replies[Id] = nil
	if not Answer then
		error("No answer from the other server", 0)
	end
	if not Answer.Success then
		error(Answer.Result, 0)
	end
	return Answer.Result
end

function AdminService:Dispatch(Command: Command, Admin: Player?, Args: { string }, Relayed: boolean): string
	local Position = Command.Target
	if not Position then
		return (Command.Run :: (Args: { string }) -> string)(Args)
	end
	local Account = Find(Admin, Args[Position])
	if Account.Player then
		return (Command.Live :: (Player: Player, Args: { string }) -> string)(Account.Player, Args)
	end
	if Relayed then
		error(Account.Name .. " is no longer in that server", 0)
	end
	local Offline = Command.Offline
	if Command.Anywhere and Offline then
		return Offline(Account, Args)
	end
	local Read, Saved, Info = Core:GetService("DataService"):Read(Account.UserId)
	if not Read then
		error("Could not read the save of " .. Account.Name .. ": " .. tostring(Saved), 0)
	end
	local Session = Info and Info.Session
	if Session and Session.Active and not Session.Thisserver then
		if Session.Studio then
			error(Account.Name .. " is in a Studio session", 0)
		end
		Args[Position] = "#" .. Account.UserId
		return self:Forward(Session.Job, Command.Name .. " " .. table.concat(Args, " ")) .. " (other server)"
	end
	if not Offline then
		error(Account.Name .. " is not in a server", 0)
	end
	return Offline(Account, Args) .. " (offline)"
end

function AdminService:Run(Admin: Player?, Text: string, Relayed: boolean?): (boolean, string)
	local Args = {}
	for Word in string.gmatch(Text, "%S+") do
		table.insert(Args, Word)
	end
	local Name = string.lower(table.remove(Args, 1) or "")
	for _, Command in ipairs(Commands) do
		if Command.Name == Name then
			if #Args < Command.Arguments then
				return false, "Usage: " .. Command.Usage
			end
			local Success, Result = pcall(self.Dispatch, self, Command, Admin, Args, Relayed == true)
			return Success, tostring(Result)
		end
	end
	return false, "Unknown command " .. Name .. ", type help"
end

function AdminService:Init()
	Remotemanager:OnServerInvoke(self.Name, "IsAdmin", function(Player)
		return self:IsAdmin(Player)
	end)
	Remotemanager:OnServerInvoke(self.Name, "Run", function(Player, Text)
		if not self:IsAdmin(Player) or type(Text) ~= "string" then
			return false, "Not allowed"
		end
		return self:Run(Player, Text)
	end)
end

function AdminService:Start()
	local Subscribed, Problem = pcall(function()
		MessagingService:SubscribeAsync(RequestTopic, function(Message)
			local Data = Message.Data
			if Data.Job ~= game.JobId then
				return
			end
			local Success, Result = self:Run(nil, Data.Text, true)
			pcall(MessagingService.PublishAsync, MessagingService, ReplyTopic, {
				From = Data.From,
				Id = Data.Id,
				Success = Success,
				Result = string.sub(Result, 1, ReplyLimit),
			})
		end)
		MessagingService:SubscribeAsync(ReplyTopic, function(Message)
			local Data = Message.Data
			if Data.From == game.JobId and Pending[Data.Id] then
				Replies[Data.Id] = { Success = Data.Success, Result = Data.Result }
			end
		end)
	end)
	if not Subscribed then
		warn("AdminService: commands for players in other servers are unavailable: " .. tostring(Problem))
	end
end

return AdminService
