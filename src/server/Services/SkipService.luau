local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Store = require(ReplicatedStorage.Shared.Config.Store)

local SkipService = {
	Name = "SkipService",
	Priority = 9,
	Remotes = {
		GetSkips = "Function",
		Updated = "Event",
		Use = "Event",
		Refused = "Event",
	},
}

local Single = Store.Skip[1]
local Counts: { [Player]: number } = {}
local Buyers: { [Player]: boolean } = {}

function SkipService:Get(Player: Player): number
	return Counts[Player] or 0
end

function SkipService:Push(Player: Player)
	Remotemanager:FireClient(self.Name, "Updated", Player, self:Get(Player))
end

function SkipService:Add(Player: Player, Amount: number)
	Counts[Player] = self:Get(Player) + Amount
	if Buyers[Player] then
		Buyers[Player] = nil
		task.spawn(self.Use, self, Player)
		return
	end
	self:Push(Player)
end

function SkipService:Use(Player: Player)
	local Gliders = Core:GetService("GliderService")
	if Buyers[Player] or not Core:GetService("DataService"):IsLoaded(Player) or not Gliders:Skippable(Player) then
		self:Push(Player)
		Remotemanager:FireClient(self.Name, "Refused", Player)
		return
	end
	if self:Get(Player) == 0 then
		Buyers[Player] = true
		Core:GetService("StoreService"):Buy(Player, "Skip", Single.Name)
		return
	end
	Counts[Player] -= 1
	self:Push(Player)
	Gliders:Skip(Player)
end

function SkipService:Init()
	Core:GetService("DataService"):Register("Skips", {
		Load = function(Player, Saved)
			Counts[Player] = Saved
			self:Push(Player)
		end,
		Save = function(Player)
			return self:Get(Player)
		end,
		Clear = function(Player)
			Counts[Player] = nil
			Buyers[Player] = nil
		end,
	})

	Remotemanager:OnServerInvoke(self.Name, "GetSkips", function(Player)
		Core:GetService("DataService"):WaitForLoad(Player)
		return self:Get(Player)
	end)
	Remotemanager:OnServerEvent(self.Name, "Use", function(Player)
		self:Use(Player)
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(UserId, Product, Purchased)
		local Player = Players:GetPlayerByUserId(UserId)
		if Player and not Purchased and Product == Single.Product then
			Buyers[Player] = nil
		end
	end)
end

return SkipService
