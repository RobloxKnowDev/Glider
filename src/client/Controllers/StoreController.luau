local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local GlidersConfig = require(ReplicatedStorage.Shared.Config.Gliders)
local TrailsConfig = require(ReplicatedStorage.Shared.Config.Trails)
local Images = require(ReplicatedStorage.Shared.Config.Images)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local GainBurst = require(ReplicatedStorage.Shared.Utils.GainBurst)
local GliderShowcase = require(ReplicatedStorage.Shared.Utils.GliderShowcase)
local NewBadge = require(ReplicatedStorage.Shared.Utils.NewBadge)
local RobuxPrice = require(ReplicatedStorage.Shared.Utils.RobuxPrice)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)
local UiGradient = require(ReplicatedStorage.Shared.Utils.UiGradient)

local StoreController = {
	Name = "StoreController",
	Priority = 30,
}

type Pack = {
	Name: string,
	Product: number?,
	Gamepass: number?,
	Price: number?,
}

type Entry = {
	Name: string,
	Rarity: string,
	Multiplier: number?,
	New: boolean?,
}

type Style = {
	Background: Color3,
	Stroke: Color3,
	TextStroke: Color3,
}

type Offer = {
	Style: Style,
	Button: GuiButton,
	Stroke: UIStroke,
	Text: TextLabel,
	TextStroke: UIStroke,
	Price: number?,
	Owned: boolean,
}

type Spinner = {
	Model: Model,
	Base: CFrame,
	Angle: number,
}

local NoticeStyle: GainBurst.Style = {
	Color = Color3.new(1, 1, 1),
	Stroke = Color3.new(0, 0, 0),
}
local Robux = "\u{E002}"
local White = Color3.new(1, 1, 1)
local OwnedStyle: Style = {
	Background = Color3.fromRGB(110, 110, 110),
	Stroke = Color3.fromRGB(150, 150, 150),
	TextStroke = Color3.fromRGB(60, 60, 60),
}
local BuyStyle: Style = {
	Background = Color3.fromRGB(230, 165, 0),
	Stroke = Color3.fromRGB(255, 215, 60),
	TextStroke = Color3.fromRGB(125, 90, 0),
}
local Items = { "Gliders", "Trails" }
local NewZIndex = 12
local SpinSpeed = math.rad(90)
local SpinReturnResponse = 8
local SpinInfo = TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1)
local JumpDelay = 3
local JumpHeight = 0.2
local JumpTilt = 10
local RiseInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FallInfo = TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)

function StoreController:Paint(Offer: Offer)
	local Owned = Offer.Owned and not Core:GetController("GiftController").target
	local Style = if Owned then OwnedStyle else Offer.Style
	Offer.Button.BackgroundColor3 = Style.Background
	Offer.Stroke.Color = Style.Stroke
	Offer.TextStroke.Color = Style.TextStroke
	if Owned then
		Translation.Set(Offer.Text, "Owned")
	else
		Translation.Raw(Offer.Text, Offer.Price .. Robux)
	end
end

function StoreController:Refresh()
	for _, Offer in pairs(self.offers) do
		self:Paint(Offer)
	end
end

function StoreController:Bind(Button: GuiButton, Section: string, Pack: Pack, Style: Style?)
	local Key = Section .. "." .. Pack.Name
	local Text = Button:WaitForChild("Text") :: TextLabel
	UiFade.BindButton(Button)
	Button.Activated:Connect(function()
		local Target = Core:GetController("GiftController").target
		local Offer = self.offers[Key]
		if Target or not (Offer and Offer.Owned) then
			Remotemanager:FireServer("StoreService", "Buy", Section, Pack.Name, Target)
		end
	end)
	if not Pack.Gamepass then
		task.spawn(function()
			Translation.Raw(Text, RobuxPrice(Pack) .. Robux)
		end)
		return
	end

	local Stroke = Button:WaitForChild("UIStroke") :: UIStroke
	local TextStroke = Text:WaitForChild("UIStroke") :: UIStroke
	local Offer: Offer = {
		Style = Style or {
			Background = Button.BackgroundColor3,
			Stroke = Stroke.Color,
			TextStroke = TextStroke.Color,
		},
		Button = Button,
		Stroke = Stroke,
		Text = Text,
		TextStroke = TextStroke,
		Price = Pack.Price,
		Owned = false,
	}
	self.offers[Key] = Offer
	self:Paint(Offer)
	task.spawn(function()
		Offer.Price = RobuxPrice(Pack)
		self:Paint(Offer)
	end)
end

function StoreController:Card(Section: string, Pack: Pack, Entry: Entry)
	local Holder = self.scrolling:WaitForChild((string.gsub(Pack.Name, " ", ""))) :: GuiObject
	for _, Child in ipairs(Holder:GetChildren()) do
		if Child.Name == "Name" then
			Translation.Set(Child :: TextLabel, Pack.Name)
		end
	end
	local Tier = Rarities[Entry.Rarity]
	local Rarity = Holder:WaitForChild("Rarity") :: TextLabel
	local RarityStroke = Rarity:WaitForChild("UIStroke") :: UIStroke
	Translation.Set(Rarity, Entry.Rarity)
	Rarity.TextColor3 = White
	UiGradient.Ensure(Rarity).Color = Tier.Gradient
	RarityStroke.Color = Tier.Stroke
	if Entry.New then
		NewBadge.Right(Holder, Rarity.FontFace, NewZIndex)
	end

	if Section == "Gliders" then
		local Model, Base = GliderShowcase(Holder:WaitForChild("ViewportFrame") :: ViewportFrame, self.models:WaitForChild(Pack.Name) :: Model)
		local Spinner: Spinner = { Model = Model, Base = Base, Angle = 0 }
		table.insert(self.spinners, Spinner)
		Holder.MouseEnter:Connect(function()
			self.hovered = Spinner
		end)
		Holder.MouseLeave:Connect(function()
			if self.hovered == Spinner then
				self.hovered = nil
			end
		end)
	else
		local Icon = Holder:WaitForChild("Icon") :: ImageLabel
		Icon.Image = Images.Trail[Pack.Name]
		Translation.Set(Holder:WaitForChild("Multiplier") :: TextLabel, "x{1} Cash", Entry.Multiplier)
	end
	self:Bind(Holder:WaitForChild("BuyButton") :: GuiButton, Section, Pack, BuyStyle)
end

function StoreController:Apply(State)
	for _, Section in ipairs(Items) do
		for _, Pack in ipairs(Store[Section]) do
			local Offer = self.offers[Section .. "." .. Pack.Name]
			Offer.Owned = State[Section].Owned[Pack.Name] == true
			self:Paint(Offer)
		end
	end
end

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
	self.models = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Glider")
	self.spinners = {} :: { Spinner }
	self.hovered = nil :: Spinner?

	local Effect = StoreButton:WaitForChild("Effect") :: ImageLabel
	TweenService:Create(Effect, SpinInfo, { Rotation = Effect.Rotation + 360 }):Play()
	local Icon = StoreButton:WaitForChild("Icon") :: GuiObject
	local Rest = Icon.Position
	local Tilt = Icon.Rotation
	task.spawn(function()
		while true do
			task.wait(JumpDelay)
			local Rise = TweenService:Create(Icon, RiseInfo, { Position = Rest - UDim2.fromScale(0, JumpHeight), Rotation = Tilt + JumpTilt })
			Rise:Play()
			Rise.Completed:Wait()
			TweenService:Create(Icon, FallInfo, { Position = Rest, Rotation = Tilt }):Play()
		end
	end)

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
	Frame:GetPropertyChangedSignal("Visible"):Connect(function()
		self.hovered = nil
	end)

	self.offers = {} :: { [string]: Offer }
	for _, Pack in ipairs(Store.Cash) do
		self:Bind(Scrolling:WaitForChild(Pack.Name):WaitForChild("Frame"):WaitForChild("BuyButton") :: GuiButton, "Cash", Pack)
	end
	for _, Section in ipairs({ "Revive", "Skip", "Spin", "StarterPack" }) do
		local Holder = Scrolling:WaitForChild(Section):WaitForChild("Frame")
		for _, Pack in ipairs(Store[Section]) do
			self:Bind(Holder:WaitForChild(Pack.Name) :: GuiButton, Section, Pack)
		end
	end
	for Section, Catalog in pairs({ Gliders = GlidersConfig, Trails = TrailsConfig }) do
		local Entries: { [string]: Entry } = {}
		for _, Entry in ipairs(Catalog.List) do
			Entries[Entry.Name] = Entry
		end
		for _, Pack in ipairs(Store[Section]) do
			self:Card(Section, Pack, Entries[Pack.Name])
		end
	end

	Remotemanager:OnClientEvent("StoreService", "Obtained", function(Trail)
		GainBurst.Notice(Images.Trail[Trail], NoticeStyle, "{1} Trail obtained!", Translation.Format(Trail))
	end)
	Remotemanager:OnClientEvent("StoreService", "Claimed", function(Key)
		self:Own(Key)
	end)
	Remotemanager:OnClientEvent("InventoryService", "Updated", function(State)
		self:Apply(State)
	end)

	RunService.RenderStepped:Connect(function(Dt)
		for _, Spinner in ipairs(self.spinners) do
			if Spinner == self.hovered then
				Spinner.Angle = (Spinner.Angle + SpinSpeed * Dt + math.pi) % (2 * math.pi) - math.pi
			elseif Spinner.Angle ~= 0 then
				Spinner.Angle = if math.abs(Spinner.Angle) < 0.001 then 0 else Spinner.Angle * math.exp(-SpinReturnResponse * Dt)
			else
				continue
			end
			Spinner.Model:PivotTo(CFrame.Angles(0, Spinner.Angle, 0) * Spinner.Base)
		end
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
	local Offer = self.offers[Key]
	Offer.Owned = true
	self:Paint(Offer)
end

function StoreController:Start()
	task.spawn(function()
		for _, Key in ipairs(Remotemanager:InvokeServer("StoreService", "GetPasses")) do
			self:Own(Key)
		end
	end)
	task.spawn(function()
		self:Apply(Remotemanager:InvokeServer("InventoryService", "GetState"))
	end)
end

return StoreController
