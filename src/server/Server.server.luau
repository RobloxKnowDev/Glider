local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

Players.CharacterAutoLoads = true

local Servicesfolder = script.Parent.Services
local Allservices = {}

for _, Module in ipairs(Servicesfolder:GetChildren()) do
	if Module:IsA("ModuleScript") then
		local Service = require(Module)

		if type(Service) == "table" and Service.Name then
			table.insert(Allservices, Service)
			Core:RegisterService(Service)
		end
	end
end

Remotemanager:RegisterServicesRemotes(Allservices)

Core:Start()
