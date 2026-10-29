local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local DuoService = {
	Name = "DuoService",
	Priority = 12,
	Remotes = {
		Invite = "Event",
		Answer = "Event",
		Invited = "Event",
		Declined = "Event",
		Start = "Event",
		Leave = "Event",
		Grouped = "Event",
	},
}

type Invite = {
	From: Player,
	Time: number,
}

type Group = {
	Owner: Player,
	Member: Player,
}

local InviteTimeout = 20
local Invites: { [Player]: Invite } = {}
local Groups: { [Player]: Group } = {}

local function Free(Player: Player): boolean
	return not Groups[Player] and not Core:GetService("GliderService"):IsFlying(Player)
end

function DuoService:Invite(Player: Player, Target: any)
	if typeof(Target) ~= "Instance" or not Target:IsA("Player") or Target == Player or not Free(Player) or not Free(Target) then
		return
	end
	Invites[Target] = { From = Player, Time = os.clock() }
	Remotemanager:FireClient(self.Name, "Invited", Target, Player, InviteTimeout)
end

function DuoService:Answer(Player: Player, From: any, Accepted: any)
	local Invite = Invites[Player]
	if not Invite or Invite.From ~= From then
		return
	end
	Invites[Player] = nil
	if Accepted ~= true then
		Remotemanager:FireClient(self.Name, "Declined", Invite.From, Player)
		return
	end
	if os.clock() - Invite.Time <= InviteTimeout and Free(Invite.From) and Free(Player) then
		self:Form(Invite.From, Player)
	end
end

function DuoService:Form(Owner: Player, Member: Player)
	local Group: Group = { Owner = Owner, Member = Member }
	for _, Player in ipairs({ Owner, Member }) do
		Groups[Player] = Group
		Player:SetAttribute("Grouped", true)
		Remotemanager:FireClient(self.Name, "Grouped", Player, Owner, Member)
	end
end

function DuoService:Leave(Player: Player)
	local Group = Groups[Player]
	if not Group then
		return
	end
	for _, Other in ipairs({ Group.Owner, Group.Member }) do
		Groups[Other] = nil
		Other:SetAttribute("Grouped", nil)
		Remotemanager:FireClient(self.Name, "Grouped", Other, nil, nil)
		Core:GetService("GliderService"):Wreck(Other)
	end
end

function DuoService:Launch(Player: Player)
	local Group = Groups[Player]
	if not Group or Group.Owner ~= Player then
		return
	end
	Core:GetService("GliderService"):Launch({ Group.Owner, Group.Member })
end

function DuoService:Init()
	Remotemanager:OnServerEvent(self.Name, "Invite", function(Player, Target)
		self:Invite(Player, Target)
	end)
	Remotemanager:OnServerEvent(self.Name, "Answer", function(Player, From, Accepted)
		self:Answer(Player, From, Accepted)
	end)
	Remotemanager:OnServerEvent(self.Name, "Start", function(Player)
		self:Launch(Player)
	end)
	Remotemanager:OnServerEvent(self.Name, "Leave", function(Player)
		self:Leave(Player)
	end)
	Players.PlayerRemoving:Connect(function(Player)
		self:Leave(Player)
		Invites[Player] = nil
		for Target, Invite in pairs(Invites) do
			if Invite.From == Player then
				Invites[Target] = nil
			end
		end
	end)
end

return DuoService
