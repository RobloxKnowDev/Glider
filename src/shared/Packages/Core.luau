local Core = {}
Core.__index = Core

local Services: { [string]: any } = {}
local Controllers: { [string]: any } = {}
local Isserver: boolean = game:GetService("RunService"):IsServer()

function Core:RegisterService(Service: any)
	assert(Service.Name, "[Framework] A Service must have a 'Name' field")
	assert(not Services[Service.Name], "[Framework] Service already registered: " .. Service.Name)
	Services[Service.Name] = Service
end

function Core:RegisterController(Controller: any)
	assert(Controller.Name, "[Framework] A Controller must have a 'Name' field")
	assert(not Controllers[Controller.Name], "[Framework] Controller already registered: " .. Controller.Name)
	Controllers[Controller.Name] = Controller
end

function Core:GetService(Name: string): any
	local S = Services[Name]
	assert(S, "[Framework] Service not found: " .. Name)
	return S
end

function Core:GetController(Name: string): any
	local C = Controllers[Name]
	assert(C, "[Framework] Controller not found: " .. Name)
	return C
end

local function Sortbypriority(Modules: { any }): { any }
	local List = {}
	for _, M in pairs(Modules) do
		table.insert(List, M)
	end
	table.sort(List, function(A, B)
		return (A.Priority or 99) < (B.Priority or 99)
	end)
	return List
end

function Core:Start()
	local Modules = Isserver and Services or Controllers
	local Sorted = Sortbypriority(Modules)

	for _, Module in ipairs(Sorted) do
		if Module.Init then
			local Ok, Err = pcall(function()
				Module:Init()
			end)
			if not Ok then
				warn("[Framework] Error in Init of '" .. Module.Name .. "': " .. tostring(Err))
			end
		end
	end

	for _, Module in ipairs(Sorted) do
		if Module.Start then
			local Ok, Err = pcall(function()
				Module:Start()
			end)
			if not Ok then
				warn("[Framework] Error in Start of '" .. Module.Name .. "': " .. tostring(Err))
			end
		end
	end
end

return Core
