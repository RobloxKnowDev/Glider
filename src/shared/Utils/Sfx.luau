local SoundService = game:GetService("SoundService")

local Sfx = {}

local Group = Instance.new("SoundGroup")
Group.Name = "Sfx"
Group.Parent = SoundService

local function Create(Id: string, Volume: number): Sound
	local Sound = Instance.new("Sound")
	Sound.SoundId = Id
	Sound.Volume = Volume
	Sound.SoundGroup = Group
	Sound.Parent = SoundService
	return Sound
end

function Sfx.Play(Id: string, Volume: number, Speed: number?)
	local Sound = Create(Id, Volume)
	Sound.PlaybackSpeed = Speed or 1
	Sound.Ended:Once(function()
		Sound:Destroy()
	end)
	Sound:Play()
end

function Sfx.Loop(Id: string, Volume: number): Sound
	local Sound = Create(Id, Volume)
	Sound.Looped = true
	Sound:Play()
	return Sound
end

return Sfx
