local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local PlayController = {
	Name = "PlayController",
	Priority = 20,
}

type Style = {
	Background: Color3,
	Stroke: Color3,
	TextStroke: Color3,
}

type Card = {
	Player: Player,
	Clone: GuiObject,
	Button: GuiButton,
	Stroke: UIStroke,
	Text: TextLabel,
	TextStroke: UIStroke,
	Label: string?,
	Token: number,
}

local Player = Players.LocalPlayer
local SentTime = 5
local DeclinedTime = 3
local BusyStyle: Style = {
	Background = Color3.fromRGB(110, 110, 110),
	Stroke = Color3.fromRGB(150, 150, 150),
	TextStroke = Color3.fromRGB(60, 60, 60),
}

function PlayController:Paint(Card: Card)
	local Style, Text = self.style, "Invite"
	if Card.Player:GetAttribute("Flying") then
		Style, Text = BusyStyle, "Playing"
	elseif Card.Label then
		Style, Text = BusyStyle, Card.Label
	end
	Card.Button.BackgroundColor3 = Style.Background
	Card.Stroke.Color = Style.Stroke
	Card.TextStroke.Color = Style.TextStroke
	Translation.Set(Card.Text, Text)
end

function PlayController:Hold(Card: Card, Label: string, Time: number)
	Card.Token += 1
	local Token = Card.Token
	Card.Label = Label
	self:Paint(Card)
	task.delay(Time, function()
		if Card.Token == Token then
			Card.Label = nil
			self:Paint(Card)
		end
	end)
end

function PlayController:Add(Other: Player)
	local Clone = self.template:Clone()
	Clone.Name = Other.Name
	local Holder = Clone:WaitForChild("Frame")
	local Button = Holder:WaitForChild("InviteButton") :: GuiButton
	local Text = Button:WaitForChild("Text") :: TextLabel
	local Icon = Holder:WaitForChild("Icon") :: ImageLabel
	Icon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. Other.UserId .. "&w=150&h=150"
	Translation.Raw(Holder:WaitForChild("Name") :: TextLabel, Other.DisplayName)

	local Card: Card = {
		Player = Other,
		Clone = Clone,
		Button = Button,
		Stroke = Button:WaitForChild("UIStroke") :: UIStroke,
		Text = Text,
		TextStroke = Text:WaitForChild("UIStroke") :: UIStroke,
		Label = nil,
		Token = 0,
	}
	self.cards[Other] = Card

	UiFade.BindButton(Button)
	Button.Activated:Connect(function()
		if Card.Label or Other:GetAttribute("Flying") then
			return
		end
		self:Hold(Card, "Sent", SentTime)
		Remotemanager:FireServer("DuoService", "Invite", Other)
	end)
	Other:GetAttributeChangedSignal("Flying"):Connect(function()
		self:Paint(Card)
	end)
	self:Paint(Card)
	Clone.Parent = self.scrolling
end

function PlayController:Init()
	local Ui = Core:GetController("UiController")
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Gui = PlayerGui:WaitForChild("PlayUi") :: ScreenGui
	local Left = PlayerGui:WaitForChild("HUD"):WaitForChild("Left") :: GuiObject
	local PlayButton = Gui:WaitForChild("PlayButton") :: GuiButton
	local MainFrame = Gui:WaitForChild("MainFrame") :: GuiObject
	local CloseButton = MainFrame:WaitForChild("Top"):WaitForChild("CloseButton") :: GuiButton
	local SoloButton = MainFrame:WaitForChild("SoloButton") :: GuiButton
	local DuoButton = MainFrame:WaitForChild("DuoButton") :: GuiButton
	local DuoPage = MainFrame:WaitForChild("DuoPage") :: GuiObject
	local DuoCloseButton = DuoPage:WaitForChild("CloseButton") :: GuiButton
	local Scrolling = DuoPage:WaitForChild("ScrollingFrame") :: ScrollingFrame
	local Template = Scrolling:WaitForChild("Template") :: GuiObject
	local Message = Gui:WaitForChild("Message") :: GuiObject
	local MessageText = Message:WaitForChild("Text") :: TextLabel
	local AcceptButton = Message:WaitForChild("AcceptButton") :: GuiButton
	local DeclineButton = Message:WaitForChild("DeclineButton") :: GuiButton

	local InviteButton = Template:WaitForChild("Frame"):WaitForChild("InviteButton") :: GuiButton
	self.style = {
		Background = InviteButton.BackgroundColor3,
		Stroke = (InviteButton:WaitForChild("UIStroke") :: UIStroke).Color,
		TextStroke = (InviteButton:WaitForChild("Text"):WaitForChild("UIStroke") :: UIStroke).Color,
	}
	local function Page(Duo: boolean)
		DuoPage.Visible = Duo
		SoloButton.Visible = not Duo
		DuoButton.Visible = not Duo
	end
	Template.Parent = nil
	MainFrame.Visible = false
	Message.Visible = false
	Page(false)

	self.template = Template
	self.scrolling = Scrolling
	self.cards = {}
	for _, Other in ipairs(Players:GetPlayers()) do
		if Other ~= Player then
			self:Add(Other)
		end
	end
	Players.PlayerAdded:Connect(function(Other)
		self:Add(Other)
	end)
	Players.PlayerRemoving:Connect(function(Other)
		if Other ~= Player then
			self.cards[Other].Clone:Destroy()
			self.cards[Other] = nil
		end
	end)

	for _, Button in ipairs({ PlayButton, CloseButton, SoloButton, DuoButton, DuoCloseButton, AcceptButton, DeclineButton }) do
		UiFade.BindButton(Button)
	end
	PlayButton.Activated:Connect(function()
		Ui:Toggle(MainFrame)
	end)
	CloseButton.Activated:Connect(function()
		Ui:Close()
	end)
	SoloButton.Activated:Connect(function()
		Ui:Close()
		Remotemanager:FireServer("GliderService", "Play")
	end)
	DuoButton.Activated:Connect(function()
		Page(true)
		UiFade.Pop(DuoPage)
	end)
	DuoCloseButton.Activated:Connect(function()
		Page(false)
	end)
	MainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		Page(false)
	end)

	self.token = 0
	local function Answer(Accepted: boolean)
		self.token += 1
		Message.Visible = false
		Remotemanager:FireServer("DuoService", "Answer", self.inviter, Accepted)
	end
	AcceptButton.Activated:Connect(function()
		Answer(true)
	end)
	DeclineButton.Activated:Connect(function()
		Answer(false)
	end)
	Remotemanager:OnClientEvent("DuoService", "Invited", function(From, Timeout)
		self.token += 1
		local Token = self.token
		self.inviter = From
		Translation.Set(MessageText, "{1} invites you to play duo!", From.DisplayName)
		Message.Visible = true
		UiFade.Pop(Message)
		task.delay(Timeout, function()
			if self.token == Token then
				Message.Visible = false
			end
		end)
	end)
	Remotemanager:OnClientEvent("DuoService", "Declined", function(Other)
		self:Hold(self.cards[Other], "Declined", DeclinedTime)
	end)

	Remotemanager:OnClientEvent("GliderService", "Launching", function()
		Ui:Close()
		self.token += 1
		Message.Visible = false
		Gui.Enabled = false
		Left.Visible = false
	end)
	Remotemanager:OnClientEvent("GliderService", "Stopped", function()
		Gui.Enabled = true
		Left.Visible = true
	end)
end

return PlayController
