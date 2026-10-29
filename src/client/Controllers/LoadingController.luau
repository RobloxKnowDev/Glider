local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Images = require(ReplicatedStorage.Shared.Config.Images)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)

local LoadingController = {
	Name = "LoadingController",
	Priority = 100,
}

local ReadyTimeout = 8

local function AddImages(List: { Instance }, Root: Instance)
	for _, Descendant in ipairs(Root:GetDescendants()) do
		if Descendant:IsA("ImageLabel") or Descendant:IsA("ImageButton") then
			table.insert(List, Descendant)
		end
	end
end

local function AddImageId(List: { Instance }, Id: string)
	local Image = Instance.new("ImageLabel")
	Image.Image = Id
	table.insert(List, Image)
end

local function AddSoundId(List: { Instance }, Id: string)
	table.insert(List, Sfx.Prepare(Id))
end

function LoadingController:Start()
	task.spawn(function()
		local Player = Players.LocalPlayer
		local PlayerGui = Player:WaitForChild("PlayerGui")
		local Gui = PlayerGui:WaitForChild("LoadingUi")
		local Essential = {}
		AddImages(Essential, PlayerGui)
		for _, Group in pairs(Images) do
			for _, Id in pairs(Group) do
				AddImageId(Essential, Id)
			end
		end
		for _, Group in pairs(Sounds) do
			for _, Id in pairs(Group) do
				AddSoundId(Essential, Id)
			end
		end
		local Loaded = false
		task.spawn(function()
			ContentProvider:PreloadAsync(Essential)
			Loaded = true
		end)
		local Deadline = os.clock() + ReadyTimeout
		while not Loaded and os.clock() < Deadline do
			task.wait()
		end
		local Character = Player.Character or Player.CharacterAdded:Wait()
		local Transition = Core:GetController("TransitionController")
		Transition:Blackout()
		Gui:SetAttribute("Ready", true)
		Transition:Reveal(Character)
	end)
end

return LoadingController
