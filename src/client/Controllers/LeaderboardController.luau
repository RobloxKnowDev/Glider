local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local LeaderboardController = {
	Name = "LeaderboardController",
	Priority = 33,
}

local Buttons = {
	Solo = "SoloButton",
	Duo = "DuoButton",
}

function LeaderboardController:Show(Card: Instance)
	if Card:IsA("GuiObject") then
		Card.Visible = Card:GetAttribute("Mode") == self.mode
	end
end

function LeaderboardController:Bind(Ui: Instance)
	local Gui = Ui:WaitForChild("SurfaceGui")
	local Row = Gui:WaitForChild("Button")
	local Frame = Gui:WaitForChild("ScrollingFrame")
	local function Refresh()
		for _, Card in ipairs(Frame:GetChildren()) do
			self:Show(Card)
		end
	end
	for Mode, Name in pairs(Buttons) do
		local Button = Row:WaitForChild(Name) :: GuiButton
		UiFade.BindButton(Button)
		Button.Activated:Connect(function()
			self.mode = Mode
			Refresh()
		end)
	end
	Frame.ChildAdded:Connect(function(Card)
		self:Show(Card)
	end)
	Refresh()
end

function LeaderboardController:Init()
	self.mode = "Solo"
	task.spawn(function()
		local Best = Workspace:WaitForChild("Lobby"):WaitForChild("Leaderboards"):WaitForChild("Best")
		Best.ChildAdded:Connect(function(Child)
			if Child.Name == "Ui" then
				self:Bind(Child)
			end
		end)
		local Ui = Best:FindFirstChild("Ui")
		if Ui then
			self:Bind(Ui)
		end
	end)
end

return LeaderboardController
