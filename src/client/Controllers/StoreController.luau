local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Images = require(ReplicatedStorage.Shared.Config.Images)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local GainBurst = require(ReplicatedStorage.Shared.Utils.GainBurst)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local StoreController = {
	Name = "StoreController",
	Priority = 30,
}

type Pack = {
	Name: string,
	Gamepass: number?,
}

local NoticeStyle: GainBurst.Style = {
	Color = Color3.new(1, 1, 1),
	Stroke = Color3.new(0, 0, 0),
}
local OwnedStyle = {
	Background = Color3.fromRGB(110, 110, 110),
	Stroke = Color3.fromRGB(150, 150, 150),
	TextStroke = Color3.fromRGB(60, 60, 60),
}

function StoreController:Init()
	local Ui = Core:GetController("UiController")
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local Hud = PlayerGui:WaitForChild("HUD")
	local Frame = PlayerGui:WaitForChild("StoreUi"):WaitForChild("Frame") :: GuiObject
	local Scrolling = Frame:WaitForChild("Scrolling") :: ScrollingFrame
	local CloseButton = Frame:WaitForChild("Top"):WaitForChild("CloseButton") :: GuiButton
	local StoreButton = Hud:WaitForChild("Left"):WaitForChild("StoreButton") :: GuiButton
	local CoinButton = Hud:WaitForChild("CoinFrame"):WaitForChild("BuyButton") :: GuiButton
	Frame.Visible = false
	self.frame = Frame
	self.scrolling = Scrolling
	self.cash = Scrolling:WaitForChild("TextCash") :: GuiObject

	UiFade.BindButtonSize(StoreButton)
	UiFade.BindButton(CoinButton)
	UiFade.BindButton(CloseButton)
	StoreButton.Activated:Connect(function()
		Ui:Toggle(Frame)
	end)
	CoinButton.Activated:Connect(function()
		if Frame.Visible then
			Ui:Close()
		else
			self:Cash()
		end
	end)
	CloseButton.Activated:Connect(function()
		Ui:Close()
	end)

	self.passes = {}
	self.owned = {}
	local function Bind(Button: GuiButton, Section: string, Pack: Pack)
		local Key = Section .. "." .. Pack.Name
		if Pack.Gamepass then
			self.passes[Key] = Button
		end
		UiFade.BindButton(Button)
		Button.Activated:Connect(function()
			if not self.owned[Key] then
				Remotemanager:FireServer("StoreService", "Buy", Section, Pack.Name)
			end
		end)
	end
	for _, Pack in ipairs(Store.Cash) do
		Bind(Scrolling:WaitForChild(Pack.Name):WaitForChild("Frame"):WaitForChild("BuyButton") :: GuiButton, "Cash", Pack)
	end
	for _, Section in ipairs({ "Revive", "Skip", "StarterPack" }) do
		local Holder = Scrolling:WaitForChild(Section):WaitForChild("Frame")
		for _, Pack in ipairs(Store[Section]) do
			Bind(Holder:WaitForChild(Pack.Name) :: GuiButton, Section, Pack)
		end
	end

	Remotemanager:OnClientEvent("StoreService", "Obtained", function(Trail)
		GainBurst.Notice(Images.Trail[Trail], NoticeStyle, "{1} Trail obtained!", Translation.Format(Trail))
	end)
	Remotemanager:OnClientEvent("StoreService", "Claimed", function(Key)
		self:Own(Key)
	end)
end

function StoreController:Cash()
	if not self.frame.Visible then
		local Offset = self.cash.AbsolutePosition.Y - self.scrolling.AbsolutePosition.Y
		self.scrolling.CanvasPosition = Vector2.new(self.scrolling.CanvasPosition.X, self.scrolling.CanvasPosition.Y + Offset)
	end
	Core:GetController("UiController"):Open(self.frame)
end

function StoreController:Own(Key: string)
	self.owned[Key] = true
	local Button = self.passes[Key]
	local Stroke = Button:WaitForChild("UIStroke") :: UIStroke
	local Text = Button:WaitForChild("Text") :: TextLabel
	local TextStroke = Text:WaitForChild("UIStroke") :: UIStroke
	Button.BackgroundColor3 = OwnedStyle.Background
	Stroke.Color = OwnedStyle.Stroke
	TextStroke.Color = OwnedStyle.TextStroke
	Translation.Set(Text, "Owned")
end

function StoreController:Start()
	task.spawn(function()
		for _, Key in ipairs(Remotemanager:InvokeServer("StoreService", "GetPasses")) do
			self:Own(Key)
		end
	end)
end

return StoreController
