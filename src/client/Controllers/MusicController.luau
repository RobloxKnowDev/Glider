local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Icon = require(ReplicatedStorage.Shared.Packages.Icon)
local Images = require(ReplicatedStorage.Shared.Config.Images)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local MusicController = {
	Name = "MusicController",
	Priority = 32,
}

local MusicVolume = 0.3

function MusicController:Set(Enabled: boolean)
	self.enabled = Enabled
	self.music.Playing = Enabled
	self.button:setImage(if Enabled then Images.Music.On else Images.Music.Off)
end

function MusicController:Init()
	local Group = Instance.new("SoundGroup")
	Group.Name = "Music"
	Group.Parent = SoundService

	local Music = Instance.new("Sound")
	Music.Name = "Music"
	Music.SoundId = Sounds.Music.Main
	Music.Volume = MusicVolume
	Music.Looped = true
	Music.SoundGroup = Group
	Music.Parent = SoundService
	self.music = Music
	self.enabled = true

	self.button = Icon.new()
		:setName("Music")
		:setImage(Images.Music.On)
		:setCaption(Translation.Format("Music"))
		:oneClick()
	self.button.viewingStarted:Connect(function()
		UiFade.Hover()
	end)
	self.button.selected:Connect(function()
		UiFade.Click()
		self:Set(not self.enabled)
		Remotemanager:FireServer("SettingsService", "SetSetting", "Music", self.enabled)
	end)
end

function MusicController:Start()
	task.spawn(function()
		self:Set(Remotemanager:InvokeServer("SettingsService", "GetSettings").Music)
	end)
end

return MusicController
