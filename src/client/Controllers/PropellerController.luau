local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Propeller = require(ReplicatedStorage.Shared.Utils.Propeller)

local PropellerController = {
	Name = "PropellerController",
	Priority = 8,
}

function PropellerController:Init()
	local Folder = Workspace:WaitForChild("Gliders")
	local Motors: { [Motor6D]: true } = {}
	local function Add(Child: Instance)
		if Child:IsA("Motor6D") and Child.Name == "Helice" then
			Motors[Child] = true
		end
	end
	for _, Child in ipairs(Folder:GetDescendants()) do
		Add(Child)
	end
	Folder.DescendantAdded:Connect(Add)
	Folder.DescendantRemoving:Connect(function(Child)
		Motors[Child :: Motor6D] = nil
	end)

	RunService.PreSimulation:Connect(function()
		local Spin = Propeller.Spin(os.clock())
		for Motor in pairs(Motors) do
			Motor.Transform = Spin
		end
	end)
end

return PropellerController
