local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local InviteController = {
	Name = "InviteController",
	Priority = 30,
}

local Player = Players.LocalPlayer
local RefusedVolume = 0.6

function InviteController:Init()
	local Button = Player:WaitForChild("PlayerGui"):WaitForChild("HUD"):WaitForChild("Left"):WaitForChild("InviteButton") :: GuiButton
	UiFade.BindButtonSize(Button)
	Button.Activated:Connect(function()
		local Success, Allowed = pcall(SocialService.CanSendGameInviteAsync, SocialService, Player)
		if Success and Allowed then
			SocialService:PromptGameInvite(Player)
		else
			Sfx.Play(Sounds.Ui.Negative, RefusedVolume)
		end
	end)
end

return InviteController
