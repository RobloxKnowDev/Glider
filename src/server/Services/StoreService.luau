local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Store = require(ReplicatedStorage.Shared.Config.Store)

local StoreService = {
	Name = "StoreService",
	Priority = 16,
	Remotes = {
		Buy = "Event",
		Obtained = "Event",
		GetPasses = "Function",
		Claimed = "Event",
		Gifted = "Event",
		Sent = "Event",
		Refused = "Event",
	},
}

type Gift = {
	Product: number,
	Target: Player,
}

type Pack = {
	Name: string,
	Product: number?,
	Gamepass: number?,
	Gift: number?,
	Studs: number?,
	Trail: string?,
	Revives: number?,
	Skips: number?,
	Spins: number?,
	Crate: string?,
}

type Sale = {
	Section: string,
	Pack: Pack,
}

local Inventory = {
	Gliders = true,
	Trails = true,
}

local Packs: { [string]: { [string]: Pack } } = {}
local Products: { [number]: Sale } = {}
local Passes: { [string]: Pack } = {}
for Section, List in pairs(Store) do
	Packs[Section] = {}
	for _, Pack in ipairs(List) do
		Packs[Section][Pack.Name] = Pack
		local Sale = { Section = Section, Pack = Pack }
		if Pack.Gift then
			Products[Pack.Gift] = Sale
		end
		if Pack.Product then
			Products[Pack.Product] = Sale
		elseif not Inventory[Section] then
			Passes[Section .. "." .. Pack.Name] = Pack
		end
	end
end

local Claimed: { [Player]: { [string]: boolean } } = {}
local Gifts: { [Player]: Gift } = {}

local function Grant(Player: Player, Pack: Pack)
	if Pack.Studs then
		Core:GetService("StudsService"):Add(Player, Pack.Studs)
	end
	if Pack.Trail and Core:GetService("InventoryService"):Give(Player, "Trails", Pack.Trail) then
		Remotemanager:FireClient(StoreService.Name, "Obtained", Player, Pack.Trail)
	end
	if Pack.Revives then
		Core:GetService("ReviveService"):Add(Player, Pack.Revives)
	end
	if Pack.Skips then
		Core:GetService("SkipService"):Add(Player, Pack.Skips)
	end
	if Pack.Spins then
		Core:GetService("SpinService"):Add(Player, Pack.Spins)
	end
	if Pack.Crate then
		Core:GetService("CrateService"):Roll(Player, Pack.Crate)
	end
end

local function Owns(Player: Player, Section: string, Pack: Pack): boolean
	if Inventory[Section] then
		return Core:GetService("InventoryService"):Owns(Player, Section, Pack.Name)
	end
	return Pack.Gamepass ~= nil and StoreService:EnsurePlayer(Player)[Section .. "." .. Pack.Name] == true
end

local function Present(Player: Player, Section: string, Pack: Pack)
	if Inventory[Section] then
		Core:GetService("InventoryService"):Give(Player, Section, Pack.Name)
	elseif Pack.Gamepass then
		StoreService:Claim(Player, Section .. "." .. Pack.Name)
	else
		Grant(Player, Pack)
	end
end

local function Deliver(Player: Player, Target: Player?, Section: string, Pack: Pack)
	local Data = Core:GetService("DataService")
	local Recipient = if Target and Data:IsLoaded(Target) and not Owns(Target, Section, Pack) then Target else Player
	Present(Recipient, Section, Pack)
	if Recipient == Player then
		return
	end
	Remotemanager:FireClient(StoreService.Name, "Gifted", Recipient, Player.DisplayName, Section, Pack.Name)
	Remotemanager:FireClient(StoreService.Name, "Sent", Player, Recipient.DisplayName, Section, Pack.Name)
	task.spawn(Data.Save, Data, Recipient)
end

local function Giftable(Player: Player, Target: any): boolean
	return typeof(Target) == "Instance"
		and Target:IsA("Player")
		and Target ~= Player
		and Core:GetService("DataService"):IsLoaded(Target)
end

function StoreService:EnsurePlayer(Player: Player): { [string]: boolean }
	local Owned = Claimed[Player]
	if not Owned then
		Owned = {}
		Claimed[Player] = Owned
	end
	return Owned
end

function StoreService:Keys(Player: Player): { string }
	local Keys = {}
	for Key in pairs(self:EnsurePlayer(Player)) do
		table.insert(Keys, Key)
	end
	return Keys
end

function StoreService:Claim(Player: Player, Key: string)
	local Owned = self:EnsurePlayer(Player)
	if Owned[Key] then
		return
	end
	Owned[Key] = true
	Grant(Player, Passes[Key])
	Remotemanager:FireClient(self.Name, "Claimed", Player, Key)
	local Data = Core:GetService("DataService")
	task.spawn(Data.Save, Data, Player)
end

function StoreService:Buy(Player: Player, Section: any, Name: any, Target: any)
	local List = Packs[Section]
	local Pack = List and List[Name]
	if not Pack or not Core:GetService("DataService"):IsLoaded(Player) or (Target ~= nil and not Giftable(Player, Target)) then
		return
	end
	if Target == nil and Inventory[Section] then
		Core:GetService("InventoryService"):Buy(Player, Section, Name)
		return
	end
	if Target and Owns(Target, Section, Pack) then
		Remotemanager:FireClient(self.Name, "Refused", Player, Target.DisplayName)
		return
	end
	if Pack.Gamepass and not Target then
		if Pack.Gamepass == 0 then
			self:Claim(Player, Section .. "." .. Name)
		else
			MarketplaceService:PromptGamePassPurchase(Player, Pack.Gamepass)
		end
		return
	end
	local Product = Pack.Gift or Pack.Product
	if Product == 0 then
		Deliver(Player, Target, Section, Pack)
	else
		Gifts[Player] = if Target then { Product = Product, Target = Target } else nil
		MarketplaceService:PromptProductPurchase(Player, Product)
	end
end

function StoreService:ProcessReceipt(Receipt): Enum.ProductPurchaseDecision
	local Player = Players:GetPlayerByUserId(Receipt.PlayerId)
	local Sale = Products[Receipt.ProductId]
	if not Player or not Sale then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Core:GetService("DataService"):ProcessPurchase(Player, Receipt.PurchaseId, function()
		local Gift = Gifts[Player]
		local Target = nil
		if Gift and Gift.Product == Receipt.ProductId then
			Gifts[Player] = nil
			Target = Gift.Target
		end
		Deliver(Player, Target, Sale.Section, Sale.Pack)
		Core:GetService("LeaderboardService"):Spend(Player, Receipt.CurrencySpent)
		return true
	end)
end

function StoreService:CheckGamepasses(Player: Player)
	Core:GetService("DataService"):WaitForLoad(Player)
	for Key, Pack in pairs(Passes) do
		if Pack.Gamepass ~= 0 and Player.Parent and not self:EnsurePlayer(Player)[Key] then
			local Success, Owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, Player.UserId, Pack.Gamepass)
			if Success and Owned then
				self:Claim(Player, Key)
			end
		end
	end
end

function StoreService:Init()
	Core:GetService("DataService"):Register("Passes", {
		Load = function(Player, Saved)
			local Owned = self:EnsurePlayer(Player)
			for _, Key in ipairs(Saved) do
				Owned[Key] = true
			end
		end,
		Save = function(Player)
			return self:Keys(Player)
		end,
		Clear = function(Player)
			Claimed[Player] = nil
		end,
	})

	Remotemanager:OnServerEvent(self.Name, "Buy", function(Player, Section, Name, Target)
		self:Buy(Player, Section, Name, Target)
	end)
	Remotemanager:OnServerInvoke(self.Name, "GetPasses", function(Player)
		Core:GetService("DataService"):WaitForLoad(Player)
		return self:Keys(Player)
	end)
	MarketplaceService.ProcessReceipt = function(Receipt)
		return self:ProcessReceipt(Receipt)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(Player, Id, Purchased)
		if not Purchased then
			return
		end
		for Key, Pack in pairs(Passes) do
			if Pack.Gamepass == Id then
				self:Claim(Player, Key)
			end
		end
	end)
end

function StoreService:Start()
	Players.PlayerAdded:Connect(function(Player)
		self:CheckGamepasses(Player)
	end)
	Players.PlayerRemoving:Connect(function(Player)
		Gifts[Player] = nil
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(self.CheckGamepasses, self, Player)
	end
end

return StoreService
