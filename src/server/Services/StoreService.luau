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
	},
}

type Pack = {
	Name: string,
	Product: number?,
	Gamepass: number?,
	Studs: number?,
	Trail: string?,
	Revives: number?,
	Skips: number?,
	Spins: number?,
	Crate: string?,
}

local Packs: { [string]: { [string]: Pack } } = {}
local Products: { [number]: Pack } = {}
local Passes: { [string]: Pack } = {}
for Section, List in pairs(Store) do
	Packs[Section] = {}
	for _, Pack in ipairs(List) do
		Packs[Section][Pack.Name] = Pack
		if Pack.Gamepass then
			Passes[Section .. "." .. Pack.Name] = Pack
		else
			Products[Pack.Product] = Pack
		end
	end
end

local Claimed: { [Player]: { [string]: boolean } } = {}

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

function StoreService:Buy(Player: Player, Section: any, Name: any)
	local List = Packs[Section]
	local Pack = List and List[Name]
	if not Pack or not Core:GetService("DataService"):IsLoaded(Player) then
		return
	end
	if Pack.Gamepass == 0 then
		self:Claim(Player, Section .. "." .. Name)
	elseif Pack.Gamepass then
		MarketplaceService:PromptGamePassPurchase(Player, Pack.Gamepass)
	elseif Pack.Product == 0 then
		Grant(Player, Pack)
	else
		MarketplaceService:PromptProductPurchase(Player, Pack.Product)
	end
end

function StoreService:ProcessReceipt(Receipt): Enum.ProductPurchaseDecision
	local Player = Players:GetPlayerByUserId(Receipt.PlayerId)
	local Pack = Products[Receipt.ProductId]
	if not Player or not Pack then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Core:GetService("DataService"):ProcessPurchase(Player, Receipt.PurchaseId, function()
		Grant(Player, Pack)
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

	Remotemanager:OnServerEvent(self.Name, "Buy", function(Player, Section, Name)
		self:Buy(Player, Section, Name)
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
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(self.CheckGamepasses, self, Player)
	end
end

return StoreService
