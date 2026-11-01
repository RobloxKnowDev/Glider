local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local GlidersConfig = require(ReplicatedStorage.Shared.Config.Gliders)
local TrailsConfig = require(ReplicatedStorage.Shared.Config.Trails)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Images = require(ReplicatedStorage.Shared.Config.Images)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local GliderShowcase = require(ReplicatedStorage.Shared.Utils.GliderShowcase)
local RobuxPrice = require(ReplicatedStorage.Shared.Utils.RobuxPrice)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)
local UiGradient = require(ReplicatedStorage.Shared.Utils.UiGradient)

local InventoryController = {
	Name = "InventoryController",
	Priority = 30,
}

type Style = {
	Background: Color3,
	Stroke: Color3,
	TextStroke: Color3,
}

type Entry = {
	Name: string,
	Rarity: string,
	Multiplier: number?,
}

type Pack = {
	Name: string,
	Gamepass: number?,
	Price: number?,
}

type Catalog = {
	Default: string,
	List: { Entry },
}

type Card = {
	Category: string,
	Name: string,
	Pack: Pack?,
	Price: number?,
	Clone: GuiObject,
	Button: GuiButton,
	Stroke: UIStroke,
	Text: TextLabel,
	TextStroke: UIStroke,
	Lock: Frame,
}

type Spinner = {
	Model: Model,
	Base: CFrame,
	Angle: number,
}

local EquipStyle: Style = {
	Background = Color3.fromRGB(46, 173, 0),
	Stroke = Color3.fromRGB(61, 228, 0),
	TextStroke = Color3.fromRGB(26, 98, 0),
}
local UnequipStyle: Style = {
	Background = Color3.fromRGB(175, 0, 0),
	Stroke = Color3.fromRGB(255, 42, 42),
	TextStroke = Color3.fromRGB(116, 0, 0),
}
local LockedStyle: Style = {
	Background = Color3.fromRGB(110, 110, 110),
	Stroke = Color3.fromRGB(150, 150, 150),
	TextStroke = Color3.fromRGB(60, 60, 60),
}
local BuyStyle: Style = {
	Background = Color3.fromRGB(230, 165, 0),
	Stroke = Color3.fromRGB(255, 215, 60),
	TextStroke = Color3.fromRGB(125, 90, 0),
}
local Robux = "\u{E002}"
local White = Color3.new(1, 1, 1)
local LockTransparency = 0.6
local LockZIndex = 10
local SpinSpeed = math.rad(90)
local SpinReturnResponse = 8
local LockedVolume = 0.6

local function Paint(Card: Card, Style: Style, Text: string)
	Card.Button.BackgroundColor3 = Style.Background
	Card.Stroke.Color = Style.Stroke
	Card.TextStroke.Color = Style.TextStroke
	Translation.Set(Card.Text, Text)
end

function InventoryController:Build(Category: string, Scrolling: ScrollingFrame, Template: GuiObject, Entry: Entry, Index: number): Card
	local Clone = Template:Clone()
	Clone.Name = Entry.Name
	Clone.LayoutOrder = Index
	local Holder = Clone:WaitForChild("Frame")
	local Button = Holder:WaitForChild("BuyButton") :: GuiButton
	local Text = Button:WaitForChild("Text") :: TextLabel

	for _, Child in ipairs(Holder:GetChildren()) do
		if Child.Name == "Name" then
			Translation.Set(Child :: TextLabel, Entry.Name)
		end
	end
	local Tier = Rarities[Entry.Rarity]
	local Rarity = Holder:WaitForChild("Rarity") :: TextLabel
	local RarityStroke = Rarity:WaitForChild("UIStroke") :: UIStroke
	Translation.Set(Rarity, Entry.Rarity)
	Rarity.TextColor3 = White
	UiGradient.Ensure(Rarity).Color = Tier.Gradient
	RarityStroke.Color = Tier.Stroke

	if Category == "Gliders" then
		local Model, Base = GliderShowcase(Holder:WaitForChild("ViewportFrame") :: ViewportFrame, self.models:WaitForChild(Entry.Name) :: Model)
		local Spinner: Spinner = { Model = Model, Base = Base, Angle = 0 }
		table.insert(self.spinners, Spinner)
		Clone.MouseEnter:Connect(function()
			self.hovered = Spinner
		end)
		Clone.MouseLeave:Connect(function()
			if self.hovered == Spinner then
				self.hovered = nil
			end
		end)
	else
		local Icon = Holder:WaitForChild("Icon") :: ImageLabel
		Icon.Image = Images.Trail[Entry.Name]
		Translation.Set(Holder:WaitForChild("Multiplier") :: TextLabel, "x{1} Cash", Entry.Multiplier)
	end

	local Lock = Instance.new("Frame")
	Lock.Name = "Lock"
	Lock.Size = UDim2.fromScale(1, 1)
	Lock.BackgroundColor3 = Color3.new(0, 0, 0)
	Lock.BackgroundTransparency = LockTransparency
	Lock.BorderSizePixel = 0
	Lock.ZIndex = LockZIndex
	local Corner = Holder:WaitForChild("UICorner"):Clone()
	Corner.Parent = Lock
	Lock.Parent = Holder

	local Pack = self.offers[Category][Entry.Name]
	local Card: Card = {
		Category = Category,
		Name = Entry.Name,
		Pack = Pack,
		Price = Pack and Pack.Price,
		Clone = Clone,
		Button = Button,
		Stroke = Button:WaitForChild("UIStroke") :: UIStroke,
		Text = Text,
		TextStroke = Text:WaitForChild("UIStroke") :: UIStroke,
		Lock = Lock,
	}
	if Pack then
		Button.ZIndex = LockZIndex + 1
	end
	UiFade.BindButton(Button)
	Button.Activated:Connect(function()
		local Inventory = self.state[Category]
		if not Inventory.Owned[Card.Name] then
			if Pack then
				Remotemanager:FireServer("InventoryService", "Buy", Category, Card.Name)
			else
				Sfx.Play(Sounds.Ui.Negative, LockedVolume)
			end
			return
		end
		local Action = if Inventory.Equipped == Card.Name then "Unequip" else "Equip"
		Remotemanager:FireServer("InventoryService", Action, Category, Card.Name)
	end)

	Clone.Parent = Scrolling
	return Card
end

function InventoryController:Label(Prompt: ProximityPrompt, Name: string)
	if self.state.Gliders.Owned[Name] then
		Prompt.ActionText = "Owned"
	end
end

function InventoryController:Offer(Name: string)
	UiFade.Click()
	if self.state.Gliders.Owned[Name] then
		Sfx.Play(Sounds.Ui.Negative, LockedVolume)
	else
		Remotemanager:FireServer("InventoryService", "Buy", "Gliders", Name)
	end
end

function InventoryController:Apply(State)
	self.state = State
	for Prompt, Name in pairs(self.prompts) do
		self:Label(Prompt, Name)
	end
	for _, Card in ipairs(self.cards) do
		local Inventory = State[Card.Category]
		local Owned = Inventory.Owned[Card.Name] == true
		Card.Lock.Visible = not Owned and not Card.Pack
		if not Owned and Card.Pack then
			Paint(Card, BuyStyle, Card.Price .. Robux)
		elseif not Owned then
			Paint(Card, LockedStyle, "Locked")
		elseif Inventory.Equipped == Card.Name then
			Paint(Card, UnequipStyle, "UnEquip")
		else
			Paint(Card, EquipStyle, "Equip")
		end
	end
end

function InventoryController:Page(Category: string, Catalog: Catalog, Gui: Instance, OpenButton: GuiButton)
	local Ui = Core:GetController("UiController")
	local Frame = Gui:WaitForChild("Frame") :: GuiObject
	local Scrolling = Frame:WaitForChild("Scrolling") :: ScrollingFrame
	local Template = Scrolling:WaitForChild("Template") :: GuiObject
	local CloseButton = Frame:WaitForChild("Top"):WaitForChild("CloseButton") :: GuiButton
	Template.Parent = nil
	Frame.Visible = false
	self.frames[Category] = Frame

	local Offers: { [string]: Pack } = {}
	for _, Pack in ipairs(Store[Category]) do
		Offers[Pack.Name] = Pack
	end
	self.offers[Category] = Offers

	local Order: { [Entry]: number } = {}
	for Index, Entry in ipairs(Catalog.List) do
		Order[Entry] = Index
	end
	local function Group(Entry: Entry): number
		return if Entry.Name == Catalog.Default then 0 elseif Offers[Entry.Name] then 1 else 1 + Rarities[Entry.Rarity].Rank
	end
	local Sorted = table.clone(Catalog.List)
	table.sort(Sorted, function(A, B)
		if Group(A) ~= Group(B) then
			return Group(A) < Group(B)
		end
		return Order[A] < Order[B]
	end)
	for Index, Entry in ipairs(Sorted) do
		table.insert(self.cards, self:Build(Category, Scrolling, Template, Entry, Index))
	end

	UiFade.BindButtonSize(OpenButton)
	UiFade.BindButton(CloseButton)
	OpenButton.Activated:Connect(function()
		Ui:Toggle(Frame)
	end)
	CloseButton.Activated:Connect(function()
		Ui:Close()
	end)
	Frame:GetPropertyChangedSignal("Visible"):Connect(function()
		self.hovered = nil
	end)
end

function InventoryController:Init()
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local Left = PlayerGui:WaitForChild("HUD"):WaitForChild("Left")
	self.models = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Glider")
	self.cards = {}
	self.spinners = {}
	self.prompts = {} :: { [ProximityPrompt]: string }
	self.frames = {} :: { [string]: GuiObject }
	self.offers = {} :: { [string]: { [string]: Pack } }
	local Display = Workspace:WaitForChild("RotatingGliders")

	self:Page("Gliders", GlidersConfig, PlayerGui:WaitForChild("GliderUi"), Left:WaitForChild("GliderButton") :: GuiButton)
	self:Page("Trails", TrailsConfig, PlayerGui:WaitForChild("TrailUi"), Left:WaitForChild("TrailButton") :: GuiButton)
	self:Apply({
		Gliders = { Owned = { [GlidersConfig.Default] = true }, Equipped = GlidersConfig.Default },
		Trails = { Owned = { [TrailsConfig.Default] = true }, Equipped = TrailsConfig.Default },
	})

	ProximityPromptService.PromptShown:Connect(function(Prompt)
		local Model = (Prompt.Parent :: Instance).Parent :: Instance
		if Model.Parent == Display then
			self.prompts[Prompt] = Model.Name
			self:Label(Prompt, Model.Name)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(Prompt)
		self.prompts[Prompt] = nil
	end)
	ProximityPromptService.PromptTriggered:Connect(function(Prompt)
		local Name = self.prompts[Prompt]
		local Category = Prompt:GetAttribute("Inventory")
		if Name then
			self:Offer(Name)
		elseif Category then
			UiFade.Click()
			Core:GetController("UiController"):Open(self.frames[Category])
		end
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

function InventoryController:Start()
	Remotemanager:OnClientEvent("InventoryService", "Updated", function(State)
		self:Apply(State)
	end)
	task.spawn(function()
		self:Apply(Remotemanager:InvokeServer("InventoryService", "GetState"))
	end)
	for _, Card in ipairs(self.cards) do
		local Pack = Card.Pack
		if Pack then
			task.spawn(function()
				Card.Price = RobuxPrice(Pack)
				self:Apply(self.state)
			end)
		end
	end
end

return InventoryController
