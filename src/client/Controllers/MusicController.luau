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

local Playlist = {
	{ Name = "Main", Volume = 0.3 },
	{ Name = "Moonlight", Volume = 0.47 },
	{ Name = "Elevator", Volume = 0.34 },
	{ Name = "Morning", Volume = 0.75 },
	{ Name = "Adventure", Volume = 0.31 },
	{ Name = "Vibes", Volume = 0.63 },
}

function MusicController:Set(Enabled: boolean)
	self.enabled = Enabled
	self.music.Playing = Enabled
	self.button:setImage(if Enabled then Images.Music.On else Images.Music.Off)
end

function MusicController:Load(Index: number)
	local Track = Playlist[Index]
	self.index = Index
	self.music.SoundId = Sounds.Music[Track.Name]
	self.music.Volume = Track.Volume
	self.music.TimePosition = 0
end

function MusicController:Init()
	local Group = Instance.new("SoundGroup")
	Group.Name = "Music"
	Group.Parent = SoundService

	local Music = Instance.new("Sound")
	Music.Name = "Music"
	Music.SoundGroup = Group
	Music.Parent = SoundService
	Music.Ended:Connect(function()
		self:Load(self.index % #Playlist + 1)
		Music:Play()
	end)
	self.music = Music
	self.enabled = true
	self:Load(1)

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
