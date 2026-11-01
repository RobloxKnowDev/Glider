local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local InviteController = {
	Name = "InviteController",
	Priority = 30,
}

local Player = Players.LocalPlayer
local RefusedVolume = 0.6

local function Invite()
	local Success, Allowed = pcall(SocialService.CanSendGameInviteAsync, SocialService, Player)
	if Success and Allowed then
		SocialService:PromptGameInvite(Player)
	else
		Sfx.Play(Sounds.Ui.Negative, RefusedVolume)
	end
end

function InviteController:Init()
	local Hud = Player:WaitForChild("PlayerGui"):WaitForChild("HUD")
	local Button = Hud:WaitForChild("Left"):WaitForChild("InviteButton") :: GuiButton
	local Boost = Hud:WaitForChild("BoostFrame"):WaitForChild("FriendBoost") :: GuiButton
	local Percent = Boost:WaitForChild("Percent") :: TextLabel
	UiFade.BindButtonSize(Button)
	UiFade.BindButtonSize(Boost)
	Button.Activated:Connect(Invite)
	Boost.Activated:Connect(Invite)

	local function Show()
		local Value = Player:GetAttribute("FriendBoost")
		if Value then
			Translation.Set(Percent, "+{1}% Cash", Value)
		end
	end
	Player:GetAttributeChangedSignal("FriendBoost"):Connect(Show)
	Show()
end

return InviteController
