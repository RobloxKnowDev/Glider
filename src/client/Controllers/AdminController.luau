local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)

local AdminController = {
	Name = "AdminController",
	Priority = 40,
}

local Player = Players.LocalPlayer
local ToggleKey = Enum.KeyCode.F2
local Width = 0.9
local MaxWidth = 620
local Height = 320
local Margin = 16
local Padding = 10
local TitleHeight = 22
local InputHeight = 34
local TextSize = 16
local MaxLines = 200
local Radius = UDim.new(0, 10)
local Mono = Font.fromEnum(Enum.Font.RobotoMono)
local Background = Color3.fromRGB(18, 20, 28)
local BackgroundTransparency = 0.1
local InputBackground = Color3.fromRGB(34, 37, 50)
local Accent = Color3.fromRGB(255, 210, 60)
local EchoColor = Color3.fromRGB(150, 155, 175)
local OutputColor = Color3.new(1, 1, 1)
local ErrorColor = Color3.fromRGB(255, 90, 90)

local function Round(Object: GuiObject)
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = Radius
	Corner.Parent = Object
end

local function Label(Color: Color3): TextLabel
	local Object = Instance.new("TextLabel")
	Object.BackgroundTransparency = 1
	Object.FontFace = Mono
	Object.TextSize = TextSize
	Object.TextColor3 = Color
	Object.TextXAlignment = Enum.TextXAlignment.Left
	return Object
end

function AdminController:Print(Text: string, Color: Color3)
	self.count += 1
	local Line = Label(Color)
	Line.LayoutOrder = self.count
	Line.Size = UDim2.fromScale(1, 0)
	Line.AutomaticSize = Enum.AutomaticSize.Y
	Line.TextWrapped = true
	Translation.Raw(Line, Text)
	Line.Parent = self.log
	table.insert(self.lines, Line)
	if #self.lines > MaxLines then
		self.lines[1]:Destroy()
		table.remove(self.lines, 1)
	end
end

function AdminController:Submit(Text: string)
	if not string.find(Text, "%S") then
		return
	end
	table.insert(self.history, Text)
	self.cursor = #self.history + 1
	self:Print("> " .. Text, EchoColor)
	local Success, Output = Remotemanager:InvokeServer("AdminService", "Run", Text)
	self:Print(Output, if Success then OutputColor else ErrorColor)
end

function AdminController:Browse(Step: number)
	self.cursor = math.clamp(self.cursor + Step, 1, #self.history + 1)
	self.box.Text = self.history[self.cursor] or ""
	self.box.CursorPosition = #self.box.Text + 1
end

function AdminController:Toggle()
	self.panel.Visible = not self.panel.Visible
	if self.panel.Visible then
		task.defer(self.box.CaptureFocus, self.box)
	else
		self.box:ReleaseFocus()
	end
end

function AdminController:Build()
	self.count = 0
	self.lines = {}
	self.history = {}
	self.cursor = 1

	local Gui = Instance.new("ScreenGui")
	Gui.Name = "AdminUi"
	Gui.ResetOnSpawn = false
	Gui.DisplayOrder = 100

	local Panel = Instance.new("Frame")
	Panel.Name = "Panel"
	Panel.AnchorPoint = Vector2.new(0.5, 1)
	Panel.Position = UDim2.new(0.5, 0, 1, -Margin)
	Panel.Size = UDim2.new(Width, 0, 0, Height)
	Panel.BackgroundColor3 = Background
	Panel.BackgroundTransparency = BackgroundTransparency
	Panel.Visible = false
	Panel.Parent = Gui
	Round(Panel)
	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Accent
	Stroke.Thickness = 2
	Stroke.Parent = Panel
	local Limit = Instance.new("UISizeConstraint")
	Limit.MaxSize = Vector2.new(MaxWidth, math.huge)
	Limit.Parent = Panel

	local Title = Label(Accent)
	Title.Name = "Title"
	Title.Position = UDim2.fromOffset(Padding, Padding)
	Title.Size = UDim2.new(1, -2 * Padding, 0, TitleHeight)
	Translation.Raw(Title, "Admin panel  [" .. ToggleKey.Name .. "]")
	Title.Parent = Panel

	local Log = Instance.new("ScrollingFrame")
	Log.Name = "Log"
	Log.Position = UDim2.fromOffset(Padding, 2 * Padding + TitleHeight)
	Log.Size = UDim2.new(1, -2 * Padding, 1, -(4 * Padding + TitleHeight + InputHeight))
	Log.BackgroundTransparency = 1
	Log.BorderSizePixel = 0
	Log.ScrollBarThickness = 4
	Log.CanvasSize = UDim2.new()
	Log.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Log.Parent = Panel
	local List = Instance.new("UIListLayout")
	List.SortOrder = Enum.SortOrder.LayoutOrder
	List.Padding = UDim.new(0, 4)
	List.Parent = Log
	Log:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
		Log.CanvasPosition = Vector2.new(0, math.max(Log.AbsoluteCanvasSize.Y - Log.AbsoluteWindowSize.Y, 0))
	end)

	local Box = Instance.new("TextBox")
	Box.Name = "Input"
	Box.AnchorPoint = Vector2.new(0, 1)
	Box.Position = UDim2.new(0, Padding, 1, -Padding)
	Box.Size = UDim2.new(1, -2 * Padding, 0, InputHeight)
	Box.BackgroundColor3 = InputBackground
	Box.FontFace = Mono
	Box.TextSize = TextSize
	Box.TextColor3 = OutputColor
	Box.TextXAlignment = Enum.TextXAlignment.Left
	Box.ClearTextOnFocus = false
	Box.Text = ""
	Box.PlaceholderText = "Type a command (help)"
	Box.PlaceholderColor3 = EchoColor
	Box.AutoLocalize = false
	Box.Parent = Panel
	Round(Box)
	local Inset = Instance.new("UIPadding")
	Inset.PaddingLeft = UDim.new(0, Padding)
	Inset.PaddingRight = UDim.new(0, Padding)
	Inset.Parent = Box

	Gui.Parent = Player:WaitForChild("PlayerGui")
	self.panel = Panel
	self.log = Log
	self.box = Box
	self:Print("Type help to list the commands.", EchoColor)

	Box.FocusLost:Connect(function(Entered)
		if not Entered then
			return
		end
		local Text = Box.Text
		Box.Text = ""
		task.defer(Box.CaptureFocus, Box)
		self:Submit(Text)
	end)
	UserInputService.InputBegan:Connect(function(Input)
		if Input.KeyCode == ToggleKey then
			self:Toggle()
		elseif Box:IsFocused() and Input.KeyCode == Enum.KeyCode.Up then
			self:Browse(-1)
		elseif Box:IsFocused() and Input.KeyCode == Enum.KeyCode.Down then
			self:Browse(1)
		end
	end)
end

function AdminController:Start()
	task.spawn(function()
		if Remotemanager:InvokeServer("AdminService", "IsAdmin") then
			self:Build()
		end
	end)
end

return AdminController
