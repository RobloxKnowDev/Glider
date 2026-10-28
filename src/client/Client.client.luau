local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Translation = require(Replicatedstorage.Shared.Utils.Translation)

local Controllersfolder = script.Parent.Controllers

for _, Module in ipairs(Controllersfolder:GetChildren()) do
	if Module:IsA("ModuleScript") then
		local Controller = require(Module)
		Core:RegisterController(Controller)
	end
end

Translation.Load()
Core:Start()
