local SoundService = game:GetService("SoundService")

local Sfx = {}

local Group = Instance.new("SoundGroup")
Group.Name = "Sfx"
Group.Parent = SoundService

local Pools: { [string]: { Sound } } = {}

local function Create(Id: string): Sound
	local Sound = Instance.new("Sound")
	Sound.SoundId = Id
	Sound.SoundGroup = Group
	Sound.Parent = SoundService
	return Sound
end

local function Pool(Id: string): { Sound }
	local List = Pools[Id]
	if not List then
		List = { Create(Id) }
		Pools[Id] = List
	end
	return List
end

function Sfx.Prepare(Id: string): Sound
	return Pool(Id)[1]
end

function Sfx.Play(Id: string, Volume: number, Speed: number?)
	local List = Pool(Id)
	local Sound
	for _, Idle in ipairs(List) do
		if not Idle.IsPlaying then
			Sound = Idle
			break
		end
	end
	if not Sound then
		Sound = Create(Id)
		table.insert(List, Sound)
	end
	Sound.Volume = Volume
	Sound.PlaybackSpeed = Speed or 1
	Sound.TimePosition = 0
	Sound:Play()
end

function Sfx.Loop(Id: string, Volume: number): Sound
	local Sound = Create(Id)
	Sound.Volume = Volume
	Sound.Looped = true
	Sound:Play()
	return Sound
end

return Sfx
