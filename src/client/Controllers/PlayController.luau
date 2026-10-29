local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)
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
local InvitedVolume = 0.7
local DeclinedVolume = 0.5
local BusyStyle: Style = {
	Background = Color3.fromRGB(110, 110, 110),
	Stroke = Color3.fromRGB(150, 150, 150),
	TextStroke = Color3.fromRGB(60, 60, 60),
}

local function Headshot(Other: Player): string
	return "rbxthumb://type=AvatarHeadShot&id=" .. Other.UserId .. "&w=150&h=150"
end

function PlayController:Group(Owner: Player?, Member: Player?)
	self.role = if Owner == Player then "Owner" elseif Member == Player then "Member" else nil
	local Play = self.play
	local Style, Text = Play.Style, Play.Label
	if self.role == "Owner" then
		Text = "Start!"
	elseif self.role == "Member" then
		Style, Text = Play.Leave, "Leave"
	end
	Play.Button.BackgroundColor3 = Style.Background
	Play.Stroke.Color = Style.Stroke
	Play.TextStroke.Color = Style.TextStroke
	Translation.Set(Play.Text, Text)

	local Right = self.right
	Right.Frame.Visible = self.role ~= nil
	Right.Leave.Visible = self.role == "Owner"
	if Owner and Member then
		Right.Owner.Image = Headshot(Owner)
		Right.Second.Image = Headshot(Member)
	end
end

function PlayController:Paint(Card: Card)
	local Style, Text = self.style, "Invite"
	if Card.Player:GetAttribute("Flying") then
		Style, Text = BusyStyle, "Playing"
	elseif Card.Player:GetAttribute("Grouped") then
		Style, Text = BusyStyle, "In group"
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
	Icon.Image = Headshot(Other)
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
		if Card.Label or Other:GetAttribute("Flying") or Other:GetAttribute("Grouped") then
			return
		end
		self:Hold(Card, "Sent", SentTime)
		Remotemanager:FireServer("DuoService", "Invite", Other)
	end)
	for _, Attribute in ipairs({ "Flying", "Grouped" }) do
		Other:GetAttributeChangedSignal(Attribute):Connect(function()
			self:Paint(Card)
		end)
	end
	self:Paint(Card)
	Clone.Parent = self.scrolling
end

function PlayController:Init()
	local Ui = Core:GetController("UiController")
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Gui = PlayerGui:WaitForChild("PlayUi") :: ScreenGui
	local Hud = PlayerGui:WaitForChild("HUD")
	local Left = Hud:WaitForChild("Left") :: GuiObject
	local Right = Hud:WaitForChild("Right") :: GuiObject
	local LeaveButton = Right:WaitForChild("LeaveButton") :: GuiButton
	local PlayButton = Gui:WaitForChild("PlayButton") :: GuiButton
	local PlayText = PlayButton:WaitForChild("Text") :: TextLabel
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
	local PlayStroke = PlayButton:WaitForChild("UIStroke") :: UIStroke
	local PlayTextStroke = PlayText:WaitForChild("UIStroke") :: UIStroke
	self.play = {
		Button = PlayButton,
		Stroke = PlayStroke,
		Text = PlayText,
		TextStroke = PlayTextStroke,
		Label = PlayText.Text,
		Style = {
			Background = PlayButton.BackgroundColor3,
			Stroke = PlayStroke.Color,
			TextStroke = PlayTextStroke.Color,
		},
		Leave = {
			Background = LeaveButton.BackgroundColor3,
			Stroke = (LeaveButton:WaitForChild("UIStroke") :: UIStroke).Color,
			TextStroke = (LeaveButton:WaitForChild("Text"):WaitForChild("UIStroke") :: UIStroke).Color,
		},
	}
	self.right = {
		Frame = Right,
		Owner = Right:WaitForChild("IconOwner") :: ImageLabel,
		Second = Right:WaitForChild("IconSecond") :: ImageLabel,
		Leave = LeaveButton,
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
	self:Group(nil, nil)

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

	for _, Button in ipairs({ PlayButton, CloseButton, SoloButton, DuoButton, DuoCloseButton, AcceptButton, DeclineButton, LeaveButton }) do
		UiFade.BindButton(Button)
	end
	PlayButton.Activated:Connect(function()
		if self.role == "Owner" then
			Remotemanager:FireServer("DuoService", "Start")
		elseif self.role == "Member" then
			Remotemanager:FireServer("DuoService", "Leave")
		else
			Ui:Toggle(MainFrame)
		end
	end)
	LeaveButton.Activated:Connect(function()
		Remotemanager:FireServer("DuoService", "Leave")
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
		Sfx.Play(Sounds.Duo.Invited, InvitedVolume)
		task.delay(Timeout, function()
			if self.token == Token then
				Message.Visible = false
			end
		end)
	end)
	Remotemanager:OnClientEvent("DuoService", "Declined", function(Other)
		self:Hold(self.cards[Other], "Declined", DeclinedTime)
		Sfx.Play(Sounds.Duo.Declined, DeclinedVolume)
	end)
	Remotemanager:OnClientEvent("DuoService", "Grouped", function(Owner, Member)
		if MainFrame.Visible then
			Ui:Close()
		end
		self:Group(Owner, Member)
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
