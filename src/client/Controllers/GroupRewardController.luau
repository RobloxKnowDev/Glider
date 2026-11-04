local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local GainBurst = require(ReplicatedStorage.Shared.Utils.GainBurst)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local GroupRewardController = {
	Name = "GroupRewardController",
	Priority = 31,
}

local Player = Players.LocalPlayer
local InviteInterval = 600
local NoticeStyle: GainBurst.Style = {
	Color = Color3.new(1, 1, 1),
	Stroke = Color3.new(0, 0, 0),
}

function GroupRewardController:Joined(GroupId: number): boolean
	local Event = Core:GetController("EventController")
	while Event.prompting do
		task.wait()
	end
	self.joining = true
	local Success, Status = pcall(GroupService.PromptJoinAsync, GroupService, GroupId)
	self.joining = false
	return Success and (Status == Enum.GroupMembershipStatus.Joined or Status == Enum.GroupMembershipStatus.AlreadyMember)
end

function GroupRewardController:Claim()
	if self.claiming then
		return
	end
	self.claiming = true
	local Status, GroupId = Remotemanager:InvokeServer("GroupRewardService", "Claim")
	if Status == "Join" and self:Joined(GroupId) then
		Status = Remotemanager:InvokeServer("GroupRewardService", "Claim")
	end
	if Status == "Claimed" then
		GainBurst.Notice(nil, NoticeStyle, "Group reward already claimed!")
	end
	self.claiming = false
end

function GroupRewardController:Settle()
	local Transition = Core:GetController("TransitionController")
	Transition:Wait()
	while Player:GetAttribute("Flying") do
		Player:GetAttributeChangedSignal("Flying"):Wait()
		Transition:Wait()
	end
end

function GroupRewardController:Greeted()
	if not self.greeted then
		self.greet.Event:Wait()
	end
end

function GroupRewardController:Invite(): boolean
	local GroupId, Member = Remotemanager:InvokeServer("GroupRewardService", "Status")
	if Member then
		return true
	end
	if self.claiming or not self:Joined(GroupId) then
		return false
	end
	self:Claim()
	return true
end

function GroupRewardController:Init()
	local Chest = Workspace:WaitForChild("GroupRewardChest")
	self.claiming = false
	self.joining = false
	self.greeted = false
	self.greet = Instance.new("BindableEvent")
	ProximityPromptService.PromptTriggered:Connect(function(Prompt)
		if (Prompt.Parent :: Instance).Parent == Chest then
			UiFade.Click()
			task.spawn(self.Claim, self)
		end
	end)
end

function GroupRewardController:Start()
	task.spawn(function()
		local Loading = Player:WaitForChild("PlayerGui"):WaitForChild("LoadingUi")
		if not Loading:GetAttribute("Ready") then
			Loading:GetAttributeChangedSignal("Ready"):Wait()
		end
		self:Settle()
		local Member = self:Invite()
		self.greeted = true
		self.greet:Fire()
		while not Member do
			task.wait(InviteInterval)
			self:Settle()
			Member = self:Invite()
		end
	end)
end

return GroupRewardController
