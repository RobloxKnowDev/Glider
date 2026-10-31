local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local RobuxPrice = require(ReplicatedStorage.Shared.Utils.RobuxPrice)

local InventoryService = {
	Name = "InventoryService",
	Priority = 7,
	Remotes = {
		GetState = "Function",
		Equip = "Event",
		Unequip = "Event",
		Buy = "Event",
		Updated = "Event",
	},
}

type Entry = {
	Name: string,
	Gamepass: number?,
	Price: number?,
}

type Catalog = {
	Default: string,
	List: { Entry },
}

type Inventory = {
	Owned: { [string]: boolean },
	Equipped: string,
}

local Catalogs: { [string]: Catalog } = {
	Gliders = require(ReplicatedStorage.Shared.Config.Gliders),
	Trails = require(ReplicatedStorage.Shared.Config.Trails),
}

local StudioUnlocked: { [string]: boolean } = {}
local Testing = RunService:IsStudio()
local PromptDistance = 10
local AnchorSize = Vector3.one * 0.2
local Robux = "\u{E002}"

local function Unlocked(Category: string): boolean
	return Testing and StudioUnlocked[Category] == true
end

local Items: { [string]: { [string]: boolean } } = {}
local Gamepasses: { [string]: { [string]: number } } = {}
for Category, Catalog in pairs(Catalogs) do
	Items[Category] = {}
	Gamepasses[Category] = {}
	for _, Entry in ipairs(Catalog.List) do
		Items[Category][Entry.Name] = true
		Gamepasses[Category][Entry.Name] = Entry.Gamepass
	end
end
local Offers: { [string]: Entry } = {}
for _, Entry in ipairs(Catalogs.Gliders.List) do
	if Entry.Gamepass then
		Offers[Entry.Name] = Entry
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

function InventoryService:Give(Player: Player, Category: string, Name: string): boolean
	local Owned = self:EnsurePlayer(Player)[Category].Owned
	if Owned[Name] then
		return false
	end
	Owned[Name] = true
	self:Push(Player)
	return true
end

function InventoryService:Take(Player: Player, Category: string, Name: string): boolean
	local Inventory = self:EnsurePlayer(Player)[Category]
	if not Inventory.Owned[Name] or Name == Catalogs[Category].Default then
		return false
	end
	Inventory.Owned[Name] = nil
	if Inventory.Equipped == Name then
		Inventory.Equipped = Catalogs[Category].Default
	end
	self:Push(Player)
	return true
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

function InventoryService:Buy(Player: Player, Category: any, Name: any)
	local Passes = Gamepasses[Category]
	local Id = Passes and Passes[Name]
	if not Id or not Core:GetService("DataService"):IsLoaded(Player) then
		return
	end
	if Id == 0 then
		self:Give(Player, Category, Name)
	else
		MarketplaceService:PromptGamePassPurchase(Player, Id)
	end
end

function InventoryService:Grant(Player: Player, Id: number)
	for Category, Passes in pairs(Gamepasses) do
		for Name, Pass in pairs(Passes) do
			if Pass == Id then
				self:Give(Player, Category, Name)
			end
		end
	end
end

function InventoryService:CheckGamepasses(Player: Player)
	Core:GetService("DataService"):WaitForLoad(Player)
	for _, Passes in pairs(Gamepasses) do
		for _, Id in pairs(Passes) do
			if Id ~= 0 and Player.Parent then
				local Success, Owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, Player.UserId, Id)
				if Success and Owned then
					self:Grant(Player, Id)
				end
			end
		end
	end
end

function InventoryService:Display(Model: Model, Entry: Entry)
	local Box, Size = Model:GetBoundingBox()
	local Anchor = Instance.new("Part")
	Anchor.Name = "Prompt"
	Anchor.Size = AnchorSize
	Anchor.CFrame = CFrame.new(Box.Position)
	Anchor.Transparency = 1
	Anchor.Anchored = true
	Anchor.CanCollide = false
	Anchor.CanQuery = false
	Anchor.CanTouch = false

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.ObjectText = Entry.Name .. " Glider"
	Prompt.ActionText = "Buy"
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = PromptDistance + Size.Magnitude / 2
	Prompt.RequiresLineOfSight = false
	Prompt.Parent = Anchor
	Anchor.Parent = Model
	task.spawn(function()
		Prompt.ActionText = RobuxPrice(Entry) .. Robux
	end)
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
	Remotemanager:OnServerEvent(self.Name, "Buy", function(Player, Category, Name)
		self:Buy(Player, Category, Name)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(Player, Id, Purchased)
		if Purchased then
			self:Grant(Player, Id)
		end
	end)
end

function InventoryService:Start()
	for _, Model in ipairs(Workspace:WaitForChild("RotatingGliders"):GetChildren()) do
		local Entry = Offers[Model.Name]
		if Entry then
			self:Display(Model :: Model, Entry)
		end
	end
	Players.PlayerAdded:Connect(function(Player)
		self:CheckGamepasses(Player)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(self.CheckGamepasses, self, Player)
	end
end

return InventoryService
