local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local AdminService = {
	Name = "AdminService",
	Priority = 20,
	Remotes = {
		IsAdmin = "Function",
		Run = "Function",
	},
}

type Command = {
	Name: string,
	Usage: string,
	Description: string,
	Arguments: number,
	Run: (Admin: Player, Args: { string }) -> string,
}

type Item = {
	Category: string,
	Name: string,
}

local Admins: { [number]: boolean } = {}
local ResetMessage = "Your data was reset. Please rejoin."
local Categories = { "Gliders", "Trails" }
local Catalogs = {
	Gliders = require(ReplicatedStorage.Shared.Config.Gliders),
	Trails = require(ReplicatedStorage.Shared.Config.Trails),
}

local function Target(Admin: Player, Name: string?): Player
	if not Name or string.lower(Name) == "me" then
		return Admin
	end
	local Search = string.lower(Name)
	local Found: Player? = nil
	for _, Player in ipairs(Players:GetPlayers()) do
		local Username = string.lower(Player.Name)
		if Username == Search then
			return Player
		end
		if string.sub(Username, 1, #Search) == Search or string.sub(string.lower(Player.DisplayName), 1, #Search) == Search then
			Found = Player
		end
	end
	if not Found then
		error("No player matches " .. Name, 0)
	end
	return Found
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

local function Summary(Names: { string }, Player: Player, Verb: string, Empty: string): string
	if #Names == 0 then
		return Empty
	end
	return Verb .. " " .. table.concat(Names, ", ") .. " - " .. Player.Name
end

local Commands: { Command }
Commands = {
	{
		Name = "help",
		Usage = "help",
		Description = "List the commands",
		Arguments = 0,
		Run = function()
			local Lines = {}
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
		Name = "studs",
		Usage = "studs <amount> [player]",
		Description = "Give Studs",
		Arguments = 1,
		Run = function(Admin, Args)
			local Value = Amount(Args[1], 1)
			local Player = Target(Admin, Args[2])
			Core:GetService("StudsService"):Add(Player, Value)
			return "Gave " .. Value .. "$ - " .. Player.Name
		end,
	},
	{
		Name = "setstuds",
		Usage = "setstuds <amount> [player]",
		Description = "Set the Studs balance",
		Arguments = 1,
		Run = function(Admin, Args)
			local Value = Amount(Args[1], 0)
			local Player = Target(Admin, Args[2])
			Core:GetService("StudsService"):Set(Player, Value)
			return "Balance set to " .. Value .. "$ - " .. Player.Name
		end,
	},
	{
		Name = "revives",
		Usage = "revives <amount> [player]",
		Description = "Give revives",
		Arguments = 1,
		Run = function(Admin, Args)
			local Value = Amount(Args[1], 1)
			local Player = Target(Admin, Args[2])
			local Revives = Core:GetService("ReviveService")
			Revives:Add(Player, Value)
			return "Gave " .. Value .. " revives (" .. Revives:Get(Player) .. " total) - " .. Player.Name
		end,
	},
	{
		Name = "skips",
		Usage = "skips <amount> [player]",
		Description = "Give skips",
		Arguments = 1,
		Run = function(Admin, Args)
			local Value = Amount(Args[1], 1)
			local Player = Target(Admin, Args[2])
			local Skips = Core:GetService("SkipService")
			Skips:Add(Player, Value)
			return "Gave " .. Value .. " skips (" .. Skips:Get(Player) .. " total) - " .. Player.Name
		end,
	},
	{
		Name = "spins",
		Usage = "spins <amount> [player]",
		Description = "Give wheel spins",
		Arguments = 1,
		Run = function(Admin, Args)
			local Value = Amount(Args[1], 1)
			local Player = Target(Admin, Args[2])
			local Spins = Core:GetService("SpinService")
			Spins:Add(Player, Value)
			return "Gave " .. Value .. " spins (" .. Spins:Get(Player) .. " total) - " .. Player.Name
		end,
	},
	{
		Name = "level",
		Usage = "level <number> [player]",
		Description = "Set the level and teleport to its SpawnLocation (the next Play starts from its SpawnPart)",
		Arguments = 1,
		Run = function(Admin, Args)
			local Levels = Core:GetService("LevelService")
			local Value = Amount(Args[1], 1)
			if Value > Levels:Count() then
				error("There are only " .. Levels:Count() .. " levels", 0)
			end
			local Player = Target(Admin, Args[2])
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
		Run = function(Admin, Args)
			local Player = Target(Admin, Args[2])
			local Inventory = Core:GetService("InventoryService")
			local Given = {}
			for _, Item in ipairs(Items(Args[1])) do
				if Inventory:Give(Player, Item.Category, Item.Name) then
					table.insert(Given, Item.Name)
				end
			end
			return Summary(Given, Player, "Gave", "Already owned")
		end,
	},
	{
		Name = "take",
		Usage = "take <item|gliders|trails|all> [player]",
		Description = "Remove gliders or trails (not the default ones)",
		Arguments = 1,
		Run = function(Admin, Args)
			local Player = Target(Admin, Args[2])
			local Inventory = Core:GetService("InventoryService")
			local Taken = {}
			for _, Item in ipairs(Items(Args[1])) do
				if Inventory:Take(Player, Item.Category, Item.Name) then
					table.insert(Taken, Item.Name)
				end
			end
			return Summary(Taken, Player, "Took", "Nothing to take")
		end,
	},
	{
		Name = "resetdata",
		Usage = "resetdata [player]",
		Description = "Erase the save and kick the player",
		Arguments = 0,
		Run = function(Admin, Args)
			local Player = Target(Admin, Args[1])
			local Success, Result = Core:GetService("DataService"):Wipe(Player.UserId)
			if not Success then
				error("Could not reset the data: " .. Result, 0)
			end
			task.defer(Player.Kick, Player, ResetMessage)
			return "Data reset (" .. Result .. ") - " .. Player.Name
		end,
	},
}

function AdminService:IsAdmin(Player: Player): boolean
	return RunService:IsStudio()
		or Admins[Player.UserId] == true
		or (game.CreatorType == Enum.CreatorType.User and game.CreatorId == Player.UserId)
end

function AdminService:Run(Admin: Player, Text: string): (boolean, string)
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
			local Success, Result = pcall(Command.Run, Admin, Args)
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

return AdminService
