local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local GroupRewardService = {
	Name = "GroupRewardService",
	Priority = 17,
	Remotes = {
		Claim = "Function",
	},
}

local GroupId = 0
local Reward = 1_000
local PromptDistance = 10
local Claimed: { [Player]: boolean } = {}
local Checking: { [Player]: boolean } = {}

local function Member(Player: Player): boolean
	if GroupId == 0 then
		return true
	end
	local Success, Groups = pcall(GroupService.GetGroupsAsync, GroupService, Player.UserId)
	if not Success then
		return false
	end
	for _, Group in ipairs(Groups) do
		if Group.Id == GroupId then
			return true
		end
	end
	return false
end

function GroupRewardService:Claim(Player: Player): (string, number)
	local Data = Core:GetService("DataService")
	if Checking[Player] or not Data:IsLoaded(Player) then
		return "Busy", GroupId
	end
	if Claimed[Player] then
		return "Claimed", GroupId
	end
	Checking[Player] = true
	local Joined = Member(Player)
	Checking[Player] = nil
	if not Player.Parent then
		return "Busy", GroupId
	end
	if not Joined then
		return "Join", GroupId
	end
	Claimed[Player] = true
	Core:GetService("StudsService"):Add(Player, Reward)
	task.spawn(Data.Save, Data, Player)
	return "Rewarded", GroupId
end

function GroupRewardService:Init()
	Core:GetService("DataService"):Register("Group", {
		Load = function(Player, Saved)
			Claimed[Player] = Saved
		end,
		Save = function(Player)
			return Claimed[Player]
		end,
		Clear = function(Player)
			Claimed[Player] = nil
			Checking[Player] = nil
		end,
	})

	Remotemanager:OnServerInvoke(self.Name, "Claim", function(Player)
		return self:Claim(Player)
	end)
end

function GroupRewardService:Start()
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.ActionText = "Claim"
	Prompt.ObjectText = "Group Reward"
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = PromptDistance
	Prompt.RequiresLineOfSight = false
	Prompt.Parent = Workspace:WaitForChild("GroupRewardChest"):WaitForChild("Cube")
end

return GroupRewardService
