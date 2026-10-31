local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local Wheel = require(ReplicatedStorage.Shared.Config.Wheel)
local CrateRoll = require(ReplicatedStorage.Shared.Utils.CrateRoll)

local SpinService = {
	Name = "SpinService",
	Priority = 9,
	Remotes = {
		GetSpins = "Function",
		Updated = "Event",
		Spin = "Event",
		Spun = "Event",
		Refused = "Event",
	},
}

type Reward = {
	Color: string,
	Chance: number,
	Studs: number?,
	Revives: number?,
	Skips: number?,
}

local SpinTime = 6
local FreeDelay = 24 * 60 * 60
local FreeCheck = 1
local PromptDistance = 10
local SpinMargin = 10
local Single = Store.Spin[1]
local Generator = Random.new()
local Counts: { [Player]: number } = {}
local Next: { [Player]: number } = {}
local Buyers: { [Player]: boolean } = {}
local Spinning: { [Player]: boolean } = {}

function SpinService:Get(Player: Player): number
	return Counts[Player] or 0
end

function SpinService:Push(Player: Player)
	Remotemanager:FireClient(self.Name, "Updated", Player, self:Get(Player), Next[Player] or 0)
end

function SpinService:Add(Player: Player, Amount: number)
	Counts[Player] = self:Get(Player) + Amount
	if Buyers[Player] then
		Buyers[Player] = nil
		task.spawn(self.Spin, self, Player)
		return
	end
	self:Push(Player)
end

function SpinService:Daily(Player: Player)
	local Now = os.time()
	if Now < (Next[Player] or 0) then
		return
	end
	Next[Player] = Now + FreeDelay
	self:Add(Player, 1)
end

function SpinService:Credit(Player: Player, Reward: Reward)
	if Reward.Studs then
		Core:GetService("StudsService"):Credit(Player, Reward.Studs)
	end
	if Reward.Revives then
		Core:GetService("ReviveService"):Credit(Player, Reward.Revives)
	end
	if Reward.Skips then
		Core:GetService("SkipService"):Credit(Player, Reward.Skips)
	end
end

function SpinService:Reveal(Player: Player, Reward: Reward)
	if Reward.Studs then
		Core:GetService("StudsService"):Push(Player, Reward.Studs)
	end
	if Reward.Revives then
		Core:GetService("ReviveService"):Push(Player)
	end
	if Reward.Skips then
		Core:GetService("SkipService"):Push(Player)
	end
end

function SpinService:Spin(Player: Player)
	local Character = Player.Character
	if
		Spinning[Player]
		or Buyers[Player]
		or not Core:GetService("DataService"):IsLoaded(Player)
		or not Character
		or (Character:GetPivot().Position - self.anchor.Position).Magnitude > PromptDistance + SpinMargin
	then
		Remotemanager:FireClient(self.Name, "Refused", Player)
		return
	end
	if self:Get(Player) == 0 then
		Buyers[Player] = true
		Core:GetService("StoreService"):Buy(Player, "Spin", Single.Name)
		return
	end
	Counts[Player] -= 1
	local Reward: Reward = CrateRoll(Wheel, Generator)
	self:Credit(Player, Reward)
	Spinning[Player] = true
	self:Push(Player)
	Remotemanager:FireClient(self.Name, "Spun", Player, table.find(Wheel, Reward), SpinTime)
	task.delay(SpinTime, function()
		Spinning[Player] = nil
		if Player.Parent then
			self:Reveal(Player, Reward)
		end
	end)
end

function SpinService:Init()
	local Data = Core:GetService("DataService")
	Data:Register("Spins", {
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
			Spinning[Player] = nil
		end,
	})
	Data:Register("Wheel", {
		Load = function(Player, Saved)
			Next[Player] = Saved
			self:Push(Player)
		end,
		Save = function(Player)
			return Next[Player]
		end,
		Clear = function(Player)
			Next[Player] = nil
		end,
	})

	Remotemanager:OnServerInvoke(self.Name, "GetSpins", function(Player)
		Data:WaitForLoad(Player)
		return self:Get(Player), Next[Player] or 0
	end)
	Remotemanager:OnServerEvent(self.Name, "Spin", function(Player)
		self:Spin(Player)
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(UserId, Product, Purchased)
		local Player = Players:GetPlayerByUserId(UserId)
		if Player and not Purchased and Product == Single.Product then
			Buyers[Player] = nil
		end
	end)
end

function SpinService:Start()
	local Model = Workspace:WaitForChild("DailyWheel")
	for _, Part in ipairs(Model:GetDescendants()) do
		if Part:IsA("JointInstance") or Part:IsA("WeldConstraint") then
			Part:Destroy()
		elseif Part:IsA("BasePart") then
			Part.Anchored = true
		end
	end
	self.anchor = Model:WaitForChild("Socle") :: BasePart
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.ActionText = "Spin"
	Prompt.ObjectText = "Daily Wheel"
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = PromptDistance
	Prompt.RequiresLineOfSight = false
	Prompt.Parent = self.anchor

	local Data = Core:GetService("DataService")
	task.spawn(function()
		while true do
			for _, Player in ipairs(Players:GetPlayers()) do
				if Data:IsLoaded(Player) then
					self:Daily(Player)
				end
			end
			task.wait(FreeCheck)
		end
	end)
end

return SpinService
