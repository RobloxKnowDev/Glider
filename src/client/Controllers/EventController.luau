local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local EventController = {
	Name = "EventController",
	Priority = 33,
}

local EventId = "2601049150447551111"
local PopupInterval = 300

function EventController:Missing(): boolean
	local Success, Status = pcall(SocialService.GetEventRsvpStatusAsync, SocialService, EventId)
	return Success and Status ~= Enum.RsvpStatus.Going
end

function EventController:Prompt()
	local Group = Core:GetController("GroupRewardController")
	Group:Settle()
	while Group.joining do
		task.wait()
	end
	self.prompting = true
	pcall(SocialService.PromptRsvpToEventAsync, SocialService, EventId)
	self.prompting = false
end

function EventController:Init()
	self.prompting = false
end

function EventController:Start()
	task.spawn(function()
		Core:GetController("GroupRewardController"):Greeted()
		if not Remotemanager:InvokeServer("EventService", "IsReturning") then
			task.wait(PopupInterval)
		end
		while true do
			if self:Missing() then
				self:Prompt()
			end
			task.wait(PopupInterval)
		end
	end)
end

return EventController
