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
	},
}

type Invite = {
	From: Player,
	Time: number,
}

local InviteTimeout = 20
local Invites: { [Player]: Invite } = {}

local function Free(Player: Player): boolean
	return not Core:GetService("GliderService"):IsFlying(Player)
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
		Core:GetService("GliderService"):Launch({ Invite.From, Player })
	end
end

function DuoService:Init()
	Remotemanager:OnServerEvent(self.Name, "Invite", function(Player, Target)
		self:Invite(Player, Target)
	end)
	Remotemanager:OnServerEvent(self.Name, "Answer", function(Player, From, Accepted)
		self:Answer(Player, From, Accepted)
	end)
	Players.PlayerRemoving:Connect(function(Player)
		Invites[Player] = nil
		for Target, Invite in pairs(Invites) do
			if Invite.From == Player then
				Invites[Target] = nil
			end
		end
	end)
end

return DuoService
