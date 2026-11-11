local RunService = game:GetService("RunService")

local GliderFrame = require(script.Parent.GliderFrame)

local SpinSpeed = math.rad(1080)

local Propeller = {}

function Propeller.Hub(Glider: Model): CFrame
	local Bar = Glider:WaitForChild("Bar") :: BasePart
	local Helice = Glider:WaitForChild("Helice") :: Model
	local Frame = Bar.CFrame * GliderFrame(Bar)
	return CFrame.lookAlong(Helice:GetPivot().Position, Frame.LookVector, Frame.UpVector)
end

function Propeller.Spin(Time: number): CFrame
	return CFrame.Angles(0, 0, (Time * SpinSpeed) % (2 * math.pi))
end

function Propeller.Showcase(Glider: Model)
	local Helice = Glider:FindFirstChild("Helice")
	if not Helice then
		return
	end
	local Bar = Glider:WaitForChild("Bar") :: BasePart
	local Hub = Propeller.Hub(Glider)
	local Mount = Bar.CFrame:ToObjectSpace(Hub)
	local Blades: { BasePart } = {}
	local Rests: { CFrame } = {}
	for _, Part in ipairs(Helice:GetDescendants()) do
		if Part:IsA("BasePart") then
			table.insert(Blades, Part)
			table.insert(Rests, Hub:ToObjectSpace(Part.CFrame))
		end
	end
	local Connection: RBXScriptConnection
	Connection = RunService.RenderStepped:Connect(function()
		if not Glider.Parent then
			Connection:Disconnect()
			return
		end
		local Frame = Bar.CFrame * Mount * Propeller.Spin(os.clock())
		for Index, Blade in ipairs(Blades) do
			Blade.CFrame = Frame * Rests[Index]
		end
	end)
end

return Propeller
