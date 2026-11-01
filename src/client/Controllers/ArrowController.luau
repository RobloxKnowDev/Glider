local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local ArrowController = {
	Name = "ArrowController",
	Priority = 24,
}

type Arrow = {
	Button: GuiButton,
	Console: ImageLabel,
	Touch: TextLabel,
	Direction: number,
	Key: Enum.KeyCode,
}

local Player = Players.LocalPlayer
local Bindings = {
	ArrowLeft = { Direction = -1, Key = Enum.KeyCode.A },
	ArrowRight = { Direction = 1, Key = Enum.KeyCode.D },
}
local Shown = {
	Started = true,
	Revived = true,
	Launching = false,
	Crashed = false,
	Stopped = false,
}

function ArrowController:Refresh()
	local Input = UserInputService.PreferredInput
	for _, Arrow in ipairs(self.arrows) do
		Arrow.Console.Visible = Input == Enum.PreferredInput.Gamepad
		Arrow.Touch.Visible = Input == Enum.PreferredInput.KeyboardAndMouse
		Translation.Raw(Arrow.Touch, UserInputService:GetStringForKeyCode(Arrow.Key))
	end
end

function ArrowController:Show(Visible: boolean)
	table.clear(self.holds)
	for _, Arrow in ipairs(self.arrows) do
		Arrow.Button.Visible = Visible
	end
end

function ArrowController:Direction(): number
	local Total = 0
	for _, Direction in pairs(self.holds) do
		Total += Direction
	end
	return math.clamp(Total, -1, 1)
end

function ArrowController:Init()
	local Folder = Player:WaitForChild("PlayerGui"):WaitForChild("PlayUi"):WaitForChild("Arrow")
	self.holds = {} :: { [InputObject]: number }
	self.arrows = {} :: { Arrow }
	for Name, Binding in pairs(Bindings) do
		local Button = Folder:WaitForChild(Name) :: GuiButton
		local Arrow: Arrow = {
			Button = Button,
			Console = Button:WaitForChild("Console") :: ImageLabel,
			Touch = Button:WaitForChild("Touch") :: TextLabel,
			Direction = Binding.Direction,
			Key = Binding.Key,
		}
		table.insert(self.arrows, Arrow)
		UiFade.BindButton(Button)
		Button.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				self.holds[Input] = Arrow.Direction
			end
		end)
	end
	UserInputService.InputEnded:Connect(function(Input)
		self.holds[Input] = nil
	end)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		self:Refresh()
	end)
	self:Refresh()

	self:Show(false)
	for Remote, Visible in pairs(Shown) do
		Remotemanager:OnClientEvent("GliderService", Remote, function()
			self:Show(Visible)
		end)
	end

	local function Joystick()
		GuiService.TouchControlsEnabled = not Player:GetAttribute("Flying")
	end
	Player:GetAttributeChangedSignal("Flying"):Connect(Joystick)
	Joystick()
end

return ArrowController
