local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Chrono = require(ReplicatedStorage.Shared.Utils.Chrono)
local NumberAbbreviator = require(ReplicatedStorage.Shared.Utils.NumberAbbreviator)
local RobuxPrice = require(ReplicatedStorage.Shared.Utils.RobuxPrice)
local Datastorerequest = require(script.Parent.Parent.Utils.Datastorerequest)

local LeaderboardService = {
	Name = "LeaderboardService",
	Priority = 8,
}

type Board = {
	Key: string,
	Frame: ScrollingFrame,
	Template: GuiObject,
	Mode: string?,
}

type Entry = {
	key: string,
	value: number,
}

local Testing = RunService:IsStudio()
local Size = 50
local RefreshTime = 60
local RequestDelay = 5
local Attempts = 3
local DefaultMode = "Solo"
local Robux = "\u{E002}"
local PlaceColors = {
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(200, 215, 230),
	Color3.fromRGB(215, 130, 60),
}
local Stores = {
	Solo = DataStoreService:GetOrderedDataStore("BestSolo_v1"),
	Duo = DataStoreService:GetOrderedDataStore("BestDuo_v1"),
	Robux = DataStoreService:GetOrderedDataStore("TopSpenders_v1"),
}
local Reads = 3
local Spent: { [Player]: number } = {}

local function Fetch(Key: string): { Entry }?
	local Success, Result = Datastorerequest.Run(Attempts, function()
		return Stores[Key]:GetSortedAsync(Key ~= "Robux", Size):GetCurrentPage()
	end)
	if not Success then
		warn("LeaderboardService: could not read " .. Key .. ": " .. tostring(Result))
		return nil
	end
	return Result
end

local function Value(Key: string, Score: number): string
	if Key == "Robux" then
		return NumberAbbreviator(Score) .. Robux
	end
	return Chrono(Score / 100)
end

function LeaderboardService:Write(Key: string, Player: Player, Value: number, Changed: boolean)
	if Player.UserId <= 0 then
		return
	end
	task.spawn(function()
		local Success, Error = Datastorerequest.Run(Attempts, function()
			if Value > 0 then
				Stores[Key]:SetAsync(tostring(Player.UserId), Value)
			else
				Stores[Key]:RemoveAsync(tostring(Player.UserId))
			end
		end)
		if not Success then
			warn("LeaderboardService: could not save " .. Key .. " for " .. Player.Name .. ": " .. tostring(Error))
		elseif Changed then
			self:Request()
		end
	end)
end

function LeaderboardService:Request()
	if self.requested then
		return
	end
	self.requested = true
	task.delay(RequestDelay, function()
		self.requested = false
		self:Refresh()
	end)
end

function LeaderboardService:Post(Mode: string, Player: Player, Time: number, Changed: boolean)
	self:Write(Mode, Player, math.round(Time * 100), Changed)
end

function LeaderboardService:Spend(Player: Player, Amount: number)
	if Testing then
		return
	end
	Spent[Player] = (Spent[Player] or 0) + Amount
	self:Write("Robux", Player, Spent[Player], true)
end

function LeaderboardService:Set(Player: Player, Amount: number)
	Spent[Player] = Amount
	self:Write("Robux", Player, Amount, true)
end

function LeaderboardService:Fill(Board: Board, Page: { Entry }, Users: { [number]: any })
	for _, Child in ipairs(Board.Frame:GetChildren()) do
		if Child:IsA("GuiObject") and Child:GetAttribute("Mode") == Board.Mode then
			Child:Destroy()
		end
	end
	for Rank, Entry in ipairs(Page) do
		local User = Users[tonumber(Entry.key) :: number]
		if not User then
			continue
		end
		local Card = Board.Template:Clone()
		local Verified = Card:WaitForChild("Verified") :: GuiObject
		local Username = Card:WaitForChild("Name") :: TextLabel
		local Place = Card:WaitForChild("Place") :: TextLabel
		local Score = Card:WaitForChild("Value") :: TextLabel
		Card.LayoutOrder = Rank
		Card:SetAttribute("Mode", Board.Mode)
		Card.Visible = Board.Mode == nil or Board.Mode == DefaultMode
		Verified.Visible = User.HasVerifiedBadge
		Username.Text = User.Username
		Score.Text = Value(Board.Key, Entry.value)
		Place.Text = "#" .. Rank
		if PlaceColors[Rank] then
			Place.TextColor3 = PlaceColors[Rank]
		end
		Card.Parent = Board.Frame
	end
end

function LeaderboardService:Refresh()
	if DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetSortedAsync) < Reads then
		return
	end
	local Pages: { [string]: { Entry } } = {}
	local Ids: { number } = {}
	local Listed: { [number]: boolean } = {}
	for Key in pairs(Stores) do
		local Page = Fetch(Key)
		if not Page then
			return
		end
		Pages[Key] = Page
		for _, Entry in ipairs(Page) do
			local Id = tonumber(Entry.key) :: number
			if not Listed[Id] then
				Listed[Id] = true
				table.insert(Ids, Id)
			end
		end
	end
	local Users: { [number]: any } = {}
	if #Ids > 0 then
		local Success, Infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, Ids)
		if not Success then
			warn("LeaderboardService: could not read user infos: " .. tostring(Infos))
			return
		end
		for _, Info in ipairs(Infos) do
			Users[Info.Id] = Info
		end
	end
	for _, Board in ipairs(self.boards) do
		self:Fill(Board, Pages[Board.Key], Users)
	end
end

function LeaderboardService:Init()
	Core:GetService("DataService"):Register("Spent", {
		Load = function(Player, Saved)
			Spent[Player] = Saved
			self:Write("Robux", Player, Saved, false)
		end,
		Save = function(Player)
			return Spent[Player]
		end,
		Clear = function(Player)
			Spent[Player] = nil
		end,
	})

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(Player, Id, Purchased)
		if not Purchased then
			return
		end
		local Price = RobuxPrice({ Gamepass = Id })
		if Price then
			self:Spend(Player, Price)
		end
	end)
end

function LeaderboardService:Start()
	local Folder = Workspace:WaitForChild("Lobby"):WaitForChild("Leaderboards")
	local function Board(Name: string): (ScrollingFrame, GuiObject)
		local Frame = Folder:WaitForChild(Name):WaitForChild("Ui"):WaitForChild("SurfaceGui"):WaitForChild("ScrollingFrame") :: ScrollingFrame
		local Template = Frame:WaitForChild("Template") :: GuiObject
		Template.Parent = nil
		return Frame, Template
	end
	local BestFrame, BestTemplate = Board("Best")
	local RobuxFrame, RobuxTemplate = Board("Robux")
	self.boards = {
		{ Key = "Solo", Frame = BestFrame, Template = BestTemplate, Mode = "Solo" },
		{ Key = "Duo", Frame = BestFrame, Template = BestTemplate, Mode = "Duo" },
		{ Key = "Robux", Frame = RobuxFrame, Template = RobuxTemplate },
	} :: { Board }

	task.spawn(function()
		while true do
			self:Refresh()
			task.wait(RefreshTime)
		end
	end)
end

return LeaderboardService
