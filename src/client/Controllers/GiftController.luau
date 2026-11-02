local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local Confetti = require(ReplicatedStorage.Shared.Utils.Confetti)
local GainBurst = require(ReplicatedStorage.Shared.Utils.GainBurst)
local NumberAbbreviator = require(ReplicatedStorage.Shared.Utils.NumberAbbreviator)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local GiftController = {
	Name = "GiftController",
	Priority = 31,
}

type Pack = {
	Name: string,
	Studs: number?,
	Revives: number?,
	Skips: number?,
	Spins: number?,
}

local Player = Players.LocalPlayer
local RefusedVolume = 0.6
local EmptyWidth = 0.8
local EmptyHeight = 0.15
local ConfettiStyle: Confetti.Style = {
	Count = 30,
	Size = 0.011,
	Speed = NumberRange.new(0.6, 0.9),
}
local NoticeStyle: GainBurst.Style = {
	Color = Color3.new(1, 1, 1),
	Stroke = Color3.new(0, 0, 0),
}

local Packs: { [string]: { [string]: Pack } } = {}
for Section, List in pairs(Store) do
	Packs[Section] = {}
	for _, Pack in ipairs(List) do
		Packs[Section][Pack.Name] = Pack
	end
end

local function Headshot(Other: Player): string
	return "rbxthumb://type=AvatarHeadShot&id=" .. Other.UserId .. "&w=150&h=150"
end

local function Count(Amount: number, Unit: string): string
	return Translation.Format(if Amount == 1 then "{1} " .. Unit else "{1} " .. Unit .. "s", Amount)
end

local function Describe(Section: string, Name: string): string
	local Pack = Packs[Section][Name]
	if Section == "Gliders" then
		return Translation.Format("{1} Glider", Translation.Format(Name))
	elseif Section == "Trails" then
		return Translation.Format("{1} Trail", Translation.Format(Name))
	elseif Section == "StarterPack" then
		return Translation.Format("Starter Pack")
	elseif Pack.Studs then
		return NumberAbbreviator(Pack.Studs) .. "$"
	elseif Pack.Revives then
		return Count(Pack.Revives, "Revive")
	elseif Pack.Skips then
		return Count(Pack.Skips, "Skip")
	end
	return Count(Pack.Spins, "Spin")
end

function GiftController:Select(Other: Player?)
	self.target = Other
	if Other then
		Translation.Raw(self.name, Other.DisplayName)
	else
		Translation.Set(self.name, self.label)
	end
	Core:GetController("StoreController"):Refresh()
end

function GiftController:Add(Other: Player)
	local Clone = self.template:Clone()
	Clone.Name = Other.Name
	local Holder = Clone:WaitForChild("Frame")
	local Button = Holder:WaitForChild("SelectButton") :: GuiButton
	local Icon = Holder:WaitForChild("Icon") :: ImageLabel
	Icon.Image = Headshot(Other)
	Translation.Raw(Holder:WaitForChild("Name") :: TextLabel, Other.DisplayName)
	self.cards[Other] = Clone
	self.empty.Visible = false

	UiFade.BindButton(Button)
	Button.Activated:Connect(function()
		self:Select(Other)
		self.page.Visible = false
	end)
	Clone.Parent = self.scrolling
end

function GiftController:Init()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Frame = PlayerGui:WaitForChild("StoreUi"):WaitForChild("Frame") :: GuiObject
	local GiftButton = Frame:WaitForChild("GiftButton") :: GuiButton
	local NameGift = Frame:WaitForChild("NameGift") :: TextLabel
	local Page = Frame:WaitForChild("GiftPage") :: GuiObject
	local CloseButton = Page:WaitForChild("CloseButton") :: GuiButton
	local Scrolling = Page:WaitForChild("ScrollingFrame") :: ScrollingFrame
	local Template = Scrolling:WaitForChild("Template") :: GuiObject
	Template.Parent = nil
	Page.Visible = false

	local Empty = Instance.new("Frame")
	Empty.Name = "Empty"
	Empty.AnchorPoint = Scrolling.AnchorPoint
	Empty.Position = Scrolling.Position
	Empty.Size = Scrolling.Size
	Empty.BackgroundTransparency = 1
	Empty.ZIndex = Scrolling.ZIndex + 1
	Empty.Parent = Page
	local Message = Page:WaitForChild("Text"):Clone() :: TextLabel
	Message.AnchorPoint = Vector2.new(0.5, 0.5)
	Message.Position = UDim2.fromScale(0.5, 0.5)
	Message.Size = UDim2.fromScale(EmptyWidth, EmptyHeight)
	Message.Parent = Empty
	Translation.Set(Message, "No other players in the server")

	self.page = Page
	self.empty = Empty
	self.scrolling = Scrolling
	self.template = Template
	self.name = NameGift
	self.label = NameGift.Text
	self.cards = {} :: { [Player]: GuiObject }
	self.target = nil :: Player?
	for _, Other in ipairs(Players:GetPlayers()) do
		if Other ~= Player then
			self:Add(Other)
		end
	end
	Players.PlayerAdded:Connect(function(Other)
		self:Add(Other)
	end)
	Players.PlayerRemoving:Connect(function(Other)
		if Other == Player then
			return
		end
		self.cards[Other]:Destroy()
		self.cards[Other] = nil
		self.empty.Visible = next(self.cards) == nil
		if self.target == Other then
			self:Select(nil)
		end
	end)

	UiFade.BindButton(GiftButton)
	UiFade.BindButton(CloseButton)
	GiftButton.Activated:Connect(function()
		if self.target then
			self:Select(nil)
			return
		end
		Page.Visible = not Page.Visible
		if Page.Visible then
			UiFade.Pop(Page)
		end
	end)
	CloseButton.Activated:Connect(function()
		Page.Visible = false
	end)
	NameGift.InputBegan:Connect(function(Input)
		local Pressed = Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch
		if Pressed and self.target then
			UiFade.Click()
			self:Select(nil)
		end
	end)
	Frame:GetPropertyChangedSignal("Visible"):Connect(function()
		Page.Visible = false
	end)

	Remotemanager:OnClientEvent("StoreService", "Gifted", function(From, Section, Name)
		GainBurst.Notice(nil, NoticeStyle, "{1} gifted you {2}!", From, Describe(Section, Name))
		Confetti.Burst(ConfettiStyle)
	end)
	Remotemanager:OnClientEvent("StoreService", "Sent", function(To, Section, Name)
		GainBurst.Notice(nil, NoticeStyle, "You gifted {1} to {2}!", Describe(Section, Name), To)
		Confetti.Burst(ConfettiStyle)
	end)
	Remotemanager:OnClientEvent("StoreService", "Refused", function(To)
		Sfx.Play(Sounds.Ui.Negative, RefusedVolume)
		GainBurst.Notice(nil, NoticeStyle, "{1} already has it!", To)
	end)
end

return GiftController
