local GroupService = game:GetService("GroupService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local GainBurst = require(ReplicatedStorage.Shared.Utils.GainBurst)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local GroupRewardController = {
	Name = "GroupRewardController",
	Priority = 31,
}

local NoticeStyle: GainBurst.Style = {
	Color = Color3.new(1, 1, 1),
	Stroke = Color3.new(0, 0, 0),
}

local function Joined(GroupId: number): boolean
	local Success, Status = pcall(GroupService.PromptJoinAsync, GroupService, GroupId)
	return Success and (Status == Enum.GroupMembershipStatus.Joined or Status == Enum.GroupMembershipStatus.AlreadyMember)
end

function GroupRewardController:Claim()
	if self.claiming then
		return
	end
	self.claiming = true
	local Status, GroupId = Remotemanager:InvokeServer("GroupRewardService", "Claim")
	if Status == "Join" and Joined(GroupId) then
		Status = Remotemanager:InvokeServer("GroupRewardService", "Claim")
	end
	if Status == "Claimed" then
		GainBurst.Notice(nil, NoticeStyle, "Group reward already claimed!")
	end
	self.claiming = false
end

function GroupRewardController:Init()
	local Chest = Workspace:WaitForChild("GroupRewardChest")
	self.claiming = false
	ProximityPromptService.PromptTriggered:Connect(function(Prompt)
		if (Prompt.Parent :: Instance).Parent == Chest then
			UiFade.Click()
			task.spawn(self.Claim, self)
		end
	end)
end

return GroupRewardController
