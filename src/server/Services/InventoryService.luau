local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local InventoryService = {
	Name = "InventoryService",
	Priority = 7,
	Remotes = {
		GetState = "Function",
		Equip = "Event",
		Unequip = "Event",
		Updated = "Event",
	},
}

type Catalog = {
	Default: string,
	List: { { Name: string } },
}

type Inventory = {
	Owned: { [string]: boolean },
	Equipped: string,
}

local Catalogs: { [string]: Catalog } = {
	Gliders = require(ReplicatedStorage.Shared.Config.Gliders),
	Trails = require(ReplicatedStorage.Shared.Config.Trails),
}

local StudioUnlocked: { [string]: boolean } = { Trails = true }
local Testing = RunService:IsStudio()

local function Unlocked(Category: string): boolean
	return Testing and StudioUnlocked[Category] == true
end

local Items: { [string]: { [string]: boolean } } = {}
for Category, Catalog in pairs(Catalogs) do
	Items[Category] = {}
	for _, Entry in ipairs(Catalog.List) do
		Items[Category][Entry.Name] = true
	end
end

local States: { [Player]: { [string]: Inventory } } = {}

function InventoryService:EnsurePlayer(Player: Player): { [string]: Inventory }
	local State = States[Player]
	if not State then
		State = {}
		for Category, Catalog in pairs(Catalogs) do
			local Owned = { [Catalog.Default] = true }
			if Unlocked(Category) then
				for _, Entry in ipairs(Catalog.List) do
					Owned[Entry.Name] = true
				end
			end
			State[Category] = {
				Owned = Owned,
				Equipped = Catalog.Default,
			}
		end
		States[Player] = State
	end
	return State
end

function InventoryService:GetEquipped(Player: Player, Category: string): string
	return self:EnsurePlayer(Player)[Category].Equipped
end

function InventoryService:Push(Player: Player)
	Remotemanager:FireClient(self.Name, "Updated", Player, self:EnsurePlayer(Player))
end

function InventoryService:Give(Player: Player, Category: string, Name: string)
	self:EnsurePlayer(Player)[Category].Owned[Name] = true
	self:Push(Player)
end

function InventoryService:Equip(Player: Player, Category: any, Name: any)
	local Inventory = self:EnsurePlayer(Player)[Category]
	if not Inventory or not Inventory.Owned[Name] then
		return
	end
	Inventory.Equipped = Name
	self:Push(Player)
end

function InventoryService:Unequip(Player: Player, Category: any, Name: any)
	local Inventory = self:EnsurePlayer(Player)[Category]
	if not Inventory or Inventory.Equipped ~= Name then
		return
	end
	Inventory.Equipped = Catalogs[Category].Default
	self:Push(Player)
end

function InventoryService:Init()
	for Category in pairs(Catalogs) do
		Core:GetService("DataService"):Register(Category, {
			Load = function(Player, Saved)
				local Inventory = self:EnsurePlayer(Player)[Category]
				for _, Name in ipairs(Saved.Owned) do
					if Items[Category][Name] then
						Inventory.Owned[Name] = true
					end
				end
				if Inventory.Owned[Saved.Equipped] then
					Inventory.Equipped = Saved.Equipped
				end
			end,
			Save = function(Player)
				if Unlocked(Category) then
					return nil
				end
				local Inventory = self:EnsurePlayer(Player)[Category]
				local Owned = {}
				for Name in pairs(Inventory.Owned) do
					table.insert(Owned, Name)
				end
				return { Owned = Owned, Equipped = Inventory.Equipped }
			end,
			Clear = function(Player)
				States[Player] = nil
			end,
		})
	end

	Remotemanager:OnServerInvoke(self.Name, "GetState", function(Player)
		Core:GetService("DataService"):WaitForLoad(Player)
		return self:EnsurePlayer(Player)
	end)
	Remotemanager:OnServerEvent(self.Name, "Equip", function(Player, Category, Name)
		self:Equip(Player, Category, Name)
	end)
	Remotemanager:OnServerEvent(self.Name, "Unequip", function(Player, Category, Name)
		self:Unequip(Player, Category, Name)
	end)
end

return InventoryService
