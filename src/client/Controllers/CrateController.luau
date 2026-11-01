local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Crates = require(ReplicatedStorage.Shared.Config.Crates)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local GlidersConfig = require(ReplicatedStorage.Shared.Config.Gliders)
local TrailsConfig = require(ReplicatedStorage.Shared.Config.Trails)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Images = require(ReplicatedStorage.Shared.Config.Images)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local CrateRoll = require(ReplicatedStorage.Shared.Utils.CrateRoll)
local GliderShowcase = require(ReplicatedStorage.Shared.Utils.GliderShowcase)
local NumberAbbreviator = require(ReplicatedStorage.Shared.Utils.NumberAbbreviator)
local RobuxPrice = require(ReplicatedStorage.Shared.Utils.RobuxPrice)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)
local UiGradient = require(ReplicatedStorage.Shared.Utils.UiGradient)

local CrateController = {
	Name = "CrateController",
	Priority = 24,
}

type Entry = {
	Name: string,
	Rarity: string,
	Multiplier: number?,
}

type Card = {
	Clone: GuiObject,
	Scale: UIScale,
	Dim: Frame,
}

type Spin = {
	Began: number,
	Duration: number,
	Start: number,
	Finish: number,
}

type Style = {
	Background: Color3,
	Stroke: Color3,
	TextStroke: Color3,
}

local Player = Players.LocalPlayer
local SpinCards = 40
local Landing = 0.35
local CardGap = 0.15
local CenterScale = 1.15
local IdleSpeed = 0.6
local SnapResponse = 8
local FocusResponse = 10
local RevealTime = 2.5
local WinScale = 1.08
local DimTransparency = 0.5
local DimZIndex = 10
local CloseMargin = 4
local White = Color3.new(1, 1, 1)
local Black = Color3.new(0, 0, 0)
local Robux = "\u{E002}"
local LockedStyle: Style = {
	Background = Color3.fromRGB(110, 110, 110),
	Stroke = Color3.fromRGB(150, 150, 150),
	TextStroke = Color3.fromRGB(60, 60, 60),
}
local TickScale = 1.35
local TickInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PayVolume = 0.6
local OpenVolume = 1.2
local TickVolume = 0.35
local TickPitch = 0.08
local RevealVolume = {
	Common = 0.5,
	Rare = 0.9,
	Epic = 4,
	Legendary = 1,
	Mythic = 5,
}
local DuplicateVolume = 0.6
local RefusedVolume = 0.6

function CrateController:Card(Index: number): Card
	local Reward = if Index == self.win
		then self.prize
		elseif self.spin then CrateRoll(self.contents, self.generator)
		else self.contents[(Index - 1) % #self.contents + 1]
	local Entry: Entry = self.entries[Reward.Category][Reward.Name]
	local Tier = Rarities[Entry.Rarity]
	local Clone = self.template:Clone()
	Clone.Name = "Card"
	Clone.AnchorPoint = Vector2.new(0.5, self.template.AnchorPoint.Y)
	Clone.Visible = true

	for _, Child in ipairs(Clone:GetChildren()) do
		if Child.Name == "Name" then
			Translation.Set(Child :: TextLabel, Entry.Name)
		end
	end
	local Rarity = Clone:WaitForChild("Rarity") :: TextLabel
	local RarityStroke = Rarity:WaitForChild("UIStroke") :: UIStroke
	Translation.Set(Rarity, Entry.Rarity)
	Rarity.TextColor3 = White
	UiGradient.Ensure(Rarity).Color = Tier.Gradient
	RarityStroke.Color = Tier.Stroke
	Translation.Raw(Clone:WaitForChild("Percent") :: TextLabel, NumberAbbreviator(Reward.Chance / self.total * 100) .. "%")

	local Viewport = Clone:WaitForChild("ViewportFrame") :: ViewportFrame
	local Icon = Clone:WaitForChild("IconTrail") :: ImageLabel
	local Multiplier = Clone:WaitForChild("Multiplier") :: TextLabel
	Viewport.Visible = Reward.Category == "Gliders"
	Icon.Visible = Reward.Category == "Trails"
	Multiplier.Visible = Reward.Category == "Trails"
	if Reward.Category == "Gliders" then
		GliderShowcase(Viewport, self.models:WaitForChild(Reward.Name) :: Model)
	else
		Icon.Image = Images.Trail[Reward.Name]
		Translation.Set(Multiplier, "x{1} Cash", Entry.Multiplier)
	end

	local Scale = Instance.new("UIScale")
	Scale.Parent = Clone
	local Dim = Instance.new("Frame")
	Dim.Name = "Dim"
	Dim.Size = UDim2.fromScale(1, 1)
	Dim.BackgroundColor3 = Black
	Dim.BackgroundTransparency = 1
	Dim.BorderSizePixel = 0
	Dim.ZIndex = DimZIndex
	Clone:WaitForChild("UICorner"):Clone().Parent = Dim
	Dim.Parent = Clone

	Clone.Parent = self.frame
	local Card: Card = { Clone = Clone, Scale = Scale, Dim = Dim }
	self.cards[Index] = Card
	return Card
end

function CrateController:Layout()
	local Step = self.template.AbsoluteSize.X / self.frame.AbsoluteSize.X * (1 + CardGap)
	local Reach = math.ceil(0.5 / Step) + 1
	local First = math.floor(self.travel) - Reach
	local Last = math.ceil(self.travel) + Reach
	for Index, Card in pairs(self.cards) do
		if Index < First or Index > Last then
			Card.Clone:Destroy()
			self.cards[Index] = nil
		end
	end
	local Height = self.template.Position.Y
	for Index = First, Last do
		local Card = self.cards[Index] or self:Card(Index)
		local Offset = (Index - self.travel) * Step
		local Center = math.max(0, 1 - math.abs(Offset) / Step)
		local Winner = Index == self.win
		Card.Clone.Position = UDim2.new(UDim.new(0.5 + Offset, 0), Height)
		Card.Scale.Scale = (1 + (CenterScale - 1) * Center) * (if Winner then 1 + (WinScale - 1) * self.focus else 1)
		Card.Dim.BackgroundTransparency = if Winner then 1 else 1 - (1 - DimTransparency) * self.focus
	end
end

function CrateController:Paint(Style: Style)
	self.buy.BackgroundColor3 = Style.Background
	self.buyStroke.Color = Style.Stroke
	self.priceStroke.Color = Style.TextStroke
end

function CrateController:Tick()
	Sfx.Play(Sounds.Crate.Tick, TickVolume, 1 + self.generator:NextNumber(-TickPitch, TickPitch))
	for _, Scale in ipairs(self.arrows) do
		Scale.Scale = TickScale
		TweenService:Create(Scale, TickInfo, { Scale = 1 }):Play()
	end
end

function CrateController:Settle()
	if self.refund > 0 then
		Core:GetController("StudsController"):Credit(self.refund)
		self.refund = 0
	end
end

function CrateController:Show(Prompt: ProximityPrompt)
	local Spot = Prompt.Parent :: BasePart
	local Name: string = Prompt:GetAttribute("Crate")
	local Crate = Crates[Name]
	self.crate = Name
	local Order = {}
	for Index, Reward in ipairs(Crate.Rewards) do
		Order[Reward] = Index
	end
	self.contents = table.clone(Crate.Rewards)
	table.sort(self.contents, function(A, B)
		local RankA = Rarities[self.entries[A.Category][A.Name].Rarity].Rank
		local RankB = Rarities[self.entries[B.Category][B.Name].Rarity].Rank
		if RankA ~= RankB then
			return RankA < RankB
		end
		return Order[A] < Order[B]
	end)
	self.total = 0
	for _, Reward in ipairs(Crate.Rewards) do
		self.total += Reward.Chance
	end
	self.origin = Spot.Position
	self.reach = Prompt.MaxActivationDistance + CloseMargin
	self.travel = 1
	self.focus = 0
	self.revealed = 0
	self.win = nil
	self.affordable = nil
	self.icon.Image = Images.Crate[Name]
	Translation.Set(self.title, "{1} Crate", Translation.Format(Crate.Title))
	Translation.Raw(self.price, NumberAbbreviator(Crate.Price) .. "$")
	task.spawn(function()
		local Price = RobuxPrice(self.offers[Name])
		if self.crate == Name then
			Translation.Raw(self.robux, Price .. Robux)
		end
	end)
	ProximityPromptService.Enabled = false
	Core:GetController("UiController"):Open(self.main)
end

function CrateController:Reset()
	self:Settle()
	self.crate = nil
	self.spin = nil
	for Index, Card in pairs(self.cards) do
		Card.Clone:Destroy()
		self.cards[Index] = nil
	end
	ProximityPromptService.Enabled = true
end

function CrateController:Buy()
	if self.spin then
		return
	end
	if Core:GetController("StudsController"):Get() < Crates[self.crate].Price then
		self:Refuse()
		return
	end
	Remotemanager:FireServer("CrateService", "Open", self.crate)
end

function CrateController:Purchase()
	if not self.spin then
		Remotemanager:FireServer("CrateService", "Purchase", self.crate)
	end
end

function CrateController:Refuse()
	Sfx.Play(Sounds.Ui.Negative, RefusedVolume)
	Core:GetController("StoreController"):Cash()
end

function CrateController:Roll(Crate: string, Category: string, Name: string, Refund: number, SpinTime: number)
	self.refund += Refund
	if self.crate ~= Crate then
		self:Settle()
		return
	end
	for _, Reward in ipairs(self.contents) do
		if Reward.Category == Category and Reward.Name == Name then
			self.prize = Reward
		end
	end
	Sfx.Play(Sounds.Crate.Pay, PayVolume)
	Sfx.Play(Sounds.Crate.Open, OpenVolume)
	self.revealed = 0
	self.win = math.floor(self.travel) + SpinCards
	self.under = math.floor(self.travel + 0.5)
	local Spin: Spin = {
		Began = os.clock(),
		Duration = SpinTime,
		Start = self.travel,
		Finish = self.win + self.generator:NextNumber(-Landing, Landing),
	}
	self.spin = Spin
end

function CrateController:Reveal()
	self.spin = nil
	self.revealed = os.clock() + RevealTime
	local Entry: Entry = self.entries[self.prize.Category][self.prize.Name]
	Sfx.Play(Sounds.Reveal[Entry.Rarity], RevealVolume[Entry.Rarity])
	if self.refund > 0 then
		Sfx.Play(Sounds.Crate.Duplicate, DuplicateVolume)
	end
	self:Settle()
end

function CrateController:Update(Dt: number)
	if not self.crate then
		return
	end
	local Character = Player.Character
	if not self.spin and (not Character or (Character:GetPivot().Position - self.origin).Magnitude > self.reach) then
		Core:GetController("UiController"):Close()
		return
	end
	local Affordable = Core:GetController("StudsController"):Get() >= Crates[self.crate].Price
	if Affordable ~= self.affordable then
		self.affordable = Affordable
		self:Paint(if Affordable then self.style else LockedStyle)
	end

	local Now = os.clock()
	local Spin: Spin? = self.spin
	if Spin then
		local Alpha = math.min((Now - Spin.Began) / Spin.Duration, 1)
		self.travel = Spin.Start + (Spin.Finish - Spin.Start) * TweenService:GetValue(Alpha, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		local Under = math.floor(self.travel + 0.5)
		if Under ~= self.under then
			self.under = Under
			self:Tick()
		end
		if Alpha >= 1 then
			self:Reveal()
		end
	elseif Now < self.revealed then
		self.travel += (self.win - self.travel) * (1 - math.exp(-SnapResponse * Dt))
	else
		self.travel += IdleSpeed * Dt
	end
	local Focus = if not self.spin and Now < self.revealed then 1 else 0
	self.focus += (Focus - self.focus) * (1 - math.exp(-FocusResponse * Dt))
	self:Layout()
end

function CrateController:Init()
	local Main = Player:WaitForChild("PlayerGui"):WaitForChild("CrateUi"):WaitForChild("Main") :: GuiObject
	local Frame = Main:WaitForChild("Frame") :: GuiObject
	local Template = Frame:WaitForChild("Template") :: GuiObject
	local Buy = Main:WaitForChild("BuyButton") :: GuiButton
	local Price = Buy:WaitForChild("Text") :: TextLabel
	local RobuxButton = Main:WaitForChild("RobuxButton") :: GuiButton
	local Top = Main:WaitForChild("Top")
	local CloseButton = Top:WaitForChild("CloseButton") :: GuiButton
	self.main = Main
	self.frame = Frame
	self.template = Template
	self.buy = Buy
	self.buyStroke = Buy:WaitForChild("UIStroke") :: UIStroke
	self.price = Price
	self.priceStroke = Price:WaitForChild("UIStroke") :: UIStroke
	self.robux = RobuxButton:WaitForChild("Text") :: TextLabel
	self.title = Top:WaitForChild("Text") :: TextLabel
	self.icon = Main:WaitForChild("IconCrate") :: ImageLabel
	self.style = {
		Background = Buy.BackgroundColor3,
		Stroke = self.buyStroke.Color,
		TextStroke = self.priceStroke.Color,
	} :: Style
	self.models = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Glider")
	self.generator = Random.new()
	self.cards = {} :: { [number]: Card }
	self.arrows = {} :: { UIScale }
	self.refund = 0
	self.offers = {}
	for _, Pack in ipairs(Store.Crate) do
		self.offers[Pack.Name] = Pack
	end
	self.entries = {}
	for Category, Catalog in pairs({ Gliders = GlidersConfig, Trails = TrailsConfig }) do
		self.entries[Category] = {}
		for _, Entry in ipairs(Catalog.List) do
			self.entries[Category][Entry.Name] = Entry
		end
	end
	Template.Visible = false
	Main.Visible = false
	for _, Name in ipairs({ "Arrow1", "Arrow2" }) do
		local Arrow = Main:WaitForChild(Name) :: GuiObject
		Arrow.ZIndex = Frame.ZIndex + 1
		local Scale = Instance.new("UIScale")
		Scale.Parent = Arrow
		table.insert(self.arrows, Scale)
	end

	UiFade.BindButton(Buy)
	UiFade.BindButton(RobuxButton)
	UiFade.BindButton(CloseButton)
	Buy.Activated:Connect(function()
		self:Buy()
	end)
	RobuxButton.Activated:Connect(function()
		self:Purchase()
	end)
	CloseButton.Activated:Connect(function()
		if not self.spin then
			Core:GetController("UiController"):Close()
		end
	end)
	Main:GetPropertyChangedSignal("Visible"):Connect(function()
		if not Main.Visible then
			self:Reset()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(Prompt)
		if Prompt:GetAttribute("Crate") then
			UiFade.Click()
			self:Show(Prompt)
		end
	end)
	RunService.RenderStepped:Connect(function(Dt)
		self:Update(Dt)
	end)
	Remotemanager:OnClientEvent("CrateService", "Opened", function(Crate, Category, Name, Refund, SpinTime)
		self:Roll(Crate, Category, Name, Refund, SpinTime)
	end)
	Remotemanager:OnClientEvent("CrateService", "Refused", function()
		self:Refuse()
	end)
end

return CrateController
