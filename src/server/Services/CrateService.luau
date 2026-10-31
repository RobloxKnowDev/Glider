local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Crates = require(ReplicatedStorage.Shared.Config.Crates)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local CrateRoll = require(ReplicatedStorage.Shared.Utils.CrateRoll)

local CrateService = {
	Name = "CrateService",
	Priority = 15,
	Remotes = {
		Open = "Event",
		Purchase = "Event",
		Opened = "Event",
		Refused = "Event",
	},
}

local SpinTime = 5
local DuplicateRefund = 0.5
local PromptDistance = 10
local OpenMargin = 10
local EventCheck = 30
local Generator = Random.new()
local Opening: { [Player]: boolean } = {}
local Npcs = {
	GliderNpc = "BasicGlider",
	TrailNpc = "BasicTrail",
}
local Spots: { [string]: { BasePart } } = {}

local function Live(Name: string): boolean
	local Event = Crates[Name].Event
	if not Event then
		return true
	end
	local Now = os.time()
	return Now >= Events[Event].Start and Now < Events[Event].Finish
end

function CrateService:Ready(Player: Player, Name: any): boolean
	if typeof(Name) ~= "string" or not Spots[Name] or Opening[Player] or not Live(Name) or not Core:GetService("DataService"):IsLoaded(Player) then
		return false
	end
	local Character = Player.Character
	if not Character then
		return false
	end
	for _, Spot in ipairs(Spots[Name]) do
		if (Character:GetPivot().Position - Spot.Position).Magnitude <= PromptDistance + OpenMargin then
			return true
		end
	end
	return false
end

function CrateService:Roll(Player: Player, Name: string)
	local Crate = Crates[Name]
	local Reward = CrateRoll(Crate.Rewards, Generator)
	local Refund = if Core:GetService("InventoryService"):Give(Player, Reward.Category, Reward.Name)
		then 0
		else math.floor(Crate.Price * DuplicateRefund)
	Core:GetService("StudsService"):Credit(Player, Refund)
	Opening[Player] = true
	Remotemanager:FireClient(self.Name, "Opened", Player, Name, Reward.Category, Reward.Name, Refund, SpinTime)
	task.delay(SpinTime, function()
		Opening[Player] = nil
	end)
end

function CrateService:Open(Player: Player, Name: any)
	if not self:Ready(Player, Name) then
		return
	end
	if not Core:GetService("StudsService"):Spend(Player, Crates[Name].Price) then
		Remotemanager:FireClient(self.Name, "Refused", Player)
		return
	end
	self:Roll(Player, Name)
end

function CrateService:Purchase(Player: Player, Name: any)
	if self:Ready(Player, Name) then
		Core:GetService("StoreService"):Buy(Player, "Crate", Name)
	end
end

function CrateService:Init()
	Remotemanager:OnServerEvent(self.Name, "Open", function(Player, Name)
		self:Open(Player, Name)
	end)
	Remotemanager:OnServerEvent(self.Name, "Purchase", function(Player, Name)
		self:Purchase(Player, Name)
	end)
end

function CrateService:Prompt(Part: BasePart, Name: string)
	table.insert(Spots[Name], Part)
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.ActionText = "Open"
	Prompt.ObjectText = Crates[Name].Title .. " Crate"
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = PromptDistance
	Prompt.RequiresLineOfSight = false
	Prompt:SetAttribute("Crate", Name)
	Prompt.Parent = Part
end

function CrateService:Start()
	local Folder = Workspace:WaitForChild("Crates")
	local Seasonal: { [Instance]: string } = {}
	for _, Crate in ipairs(Folder:GetChildren()) do
		local Name = Crate.Name
		assert(Crates[Name], 'Workspace.Crates."' .. Name .. '" has no entry in Shared.Config.Crates')
		if Crates[Name].Event then
			Seasonal[Crate] = Name
		end
		Spots[Name] = {}
		self:Prompt(Crate:WaitForChild("Box") :: BasePart, Name)
	end
	for _, Stand in ipairs(Workspace:WaitForChild("Lobby"):WaitForChild("Stands"):GetChildren()) do
		local Skins = Stand:FindFirstChild("Skins")
		if Skins then
			for Npc, Name in pairs(Npcs) do
				self:Prompt(Skins:WaitForChild(Npc):WaitForChild("HumanoidRootPart") :: BasePart, Name)
			end
		end
	end
	task.spawn(function()
		while true do
			for Crate, Name in pairs(Seasonal) do
				Crate.Parent = if Live(Name) then Folder else ServerStorage
			end
			task.wait(EventCheck)
		end
	end)
end

return CrateService
