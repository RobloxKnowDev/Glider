local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sounds = require(script.Parent.Parent.Config.Sounds)
local NumberAbbreviator = require(script.Parent.NumberAbbreviator)
local Sfx = require(script.Parent.Sfx)
local Translation = require(script.Parent.Translation)

local GainBurst = {}

export type Style = {
	Color: Color3,
	Stroke: Color3,
}

type Coin = {
	Symbol: GuiObject,
	Spread: Vector2,
	Curve: Vector2,
	Delay: number,
}

local DisplayOrder = 100
local BurstTime = 0.35
local FlyTime = 0.55
local Stagger = 0.06
local PopupStart = 0.4
local PopupEnd = 0.33
local PopupHold = 0.8
local NoticeStart = 0.85
local NoticeEnd = 0.78
local NoticeHold = 2.5
local NoticeHeight = 60
local NoticeTextScale = 0.75
local NoticeGap = 10
local PopupInfo = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FadeInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local GainVolume = 0.6
local LandVolume = 0.3
local LandPitchStep = 0.06

local Layer: ScreenGui
local Font: Font

local function Setup()
	if Layer then
		return
	end
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local Hud = PlayerGui:WaitForChild("HUD") :: ScreenGui
	Font = (Hud:WaitForChild("CoinFrame"):WaitForChild("Text") :: TextLabel).FontFace
	Layer = Instance.new("ScreenGui")
	Layer.Name = "GainUi"
	Layer.ResetOnSpawn = false
	Layer.ScreenInsets = Hud.ScreenInsets
	Layer.DisplayOrder = DisplayOrder
	Layer.Parent = PlayerGui
end

function GainBurst.Label(Text: string, Style: Style): TextLabel
	Setup()
	local Label = Instance.new("TextLabel")
	Label.BackgroundTransparency = 1
	Label.FontFace = Font
	Label.TextColor3 = Style.Color
	Label.TextScaled = true
	Translation.Raw(Label, Text)
	local Stroke = Instance.new("UIStroke")
	Stroke.Thickness = 2
	Stroke.Color = Style.Stroke
	Stroke.Parent = Label
	return Label
end

local function Fade(Root: Instance)
	for _, Object in ipairs(Root:GetDescendants()) do
		if Object:IsA("TextLabel") then
			TweenService:Create(Object, FadeInfo, { TextTransparency = 1 }):Play()
		elseif Object:IsA("ImageLabel") then
			TweenService:Create(Object, FadeInfo, { ImageTransparency = 1 }):Play()
		elseif Object:IsA("UIStroke") then
			TweenService:Create(Object, FadeInfo, { Transparency = 1 }):Play()
		end
	end
end

local function Row(Name: string, Height: number, Start: number, Gap: number): Frame
	local Holder = Instance.new("Frame")
	Holder.Name = Name
	Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	Holder.Position = UDim2.fromScale(0.5, Start)
	Holder.Size = UDim2.fromOffset(0, Height)
	Holder.AutomaticSize = Enum.AutomaticSize.X
	Holder.BackgroundTransparency = 1

	local Layout = Instance.new("UIListLayout")
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.Padding = UDim.new(0, Gap)
	Layout.Parent = Holder
	return Holder
end

local function Line(Style: Style, Height: number, Size: number, Order: number): TextLabel
	local Label = GainBurst.Label("", Style)
	Label.LayoutOrder = Order
	Label.Size = UDim2.fromOffset(0, Height)
	Label.AutomaticSize = Enum.AutomaticSize.X
	Label.TextScaled = false
	Label.TextSize = Size
	return Label
end

local function Rise(Holder: Frame, Finish: number, Hold: number)
	local Scale = Instance.new("UIScale")
	Scale.Scale = 0
	Scale.Parent = Holder
	Holder.Parent = Layer
	TweenService:Create(Scale, PopupInfo, { Scale = 1 }):Play()
	task.delay(Hold, function()
		Fade(Holder)
		local Tween = TweenService:Create(Holder, FadeInfo, { Position = UDim2.fromScale(0.5, Finish) })
		Tween:Play()
		Tween.Completed:Wait()
		Holder:Destroy()
	end)
end

local function Popup(Amount: number, Style: Style, Symbol: () -> GuiObject, Height: number)
	local Holder = Row("Popup", Height, PopupStart, 0)
	local Text = Line(Style, Height, Height, 1)
	Translation.Raw(Text, "+" .. NumberAbbreviator(Amount))
	Text.Parent = Holder

	local Icon = Symbol()
	Icon.LayoutOrder = 2
	Icon.Size = UDim2.fromOffset(Height, Height)
	Icon.Parent = Holder
	Rise(Holder, PopupEnd, PopupHold)
end

function GainBurst.Notice(Image: string?, Style: Style, Pattern: string, ...: any)
	Setup()
	local Holder = Row("Notice", NoticeHeight, NoticeStart, NoticeGap)
	if Image then
		local Icon = Instance.new("ImageLabel")
		Icon.LayoutOrder = 1
		Icon.Size = UDim2.fromOffset(NoticeHeight, NoticeHeight)
		Icon.BackgroundTransparency = 1
		Icon.ScaleType = Enum.ScaleType.Fit
		Icon.Image = Image
		Icon.Parent = Holder
	end

	local Text = Line(Style, NoticeHeight, NoticeHeight * NoticeTextScale, 2)
	Translation.Set(Text, Pattern, ...)
	Text.Parent = Holder
	Rise(Holder, NoticeEnd, NoticeHold)
end

function GainBurst.Play(Target: GuiObject, Amount: number, Style: Style, Symbol: () -> GuiObject, Land: (Share: number) -> ())
	Setup()
	Popup(Amount, Style, Symbol, Target.AbsoluteSize.Y * 2)
	Sfx.Play(Sounds.Studs.Gain, GainVolume)

	local Center = Layer.AbsoluteSize / 2
	local Goal = Target.AbsolutePosition + Target.AbsoluteSize / 2
	local Size = Target.AbsoluteSize.Y * 1.3
	local Count = math.clamp(math.floor(math.log10(Amount + 1) * 3), 4, 12)
	local Coins: { Coin } = {}
	for Index = 1, Count do
		local Angle = math.random() * 2 * math.pi
		local Direction = Vector2.new(math.cos(Angle), math.sin(Angle))
		local Spread = Center + Direction * math.random(60, 140)
		local Coin = Symbol()
		Coin.AnchorPoint = Vector2.new(0.5, 0.5)
		Coin.Position = UDim2.fromOffset(Center.X, Center.Y)
		Coin.Size = UDim2.fromOffset(0, 0)
		Coin.Rotation = math.random(-30, 30)
		Coin.Parent = Layer
		table.insert(Coins, {
			Symbol = Coin,
			Spread = Spread,
			Curve = Spread + Direction * 120,
			Delay = BurstTime + (Index - 1) * Stagger,
		})
	end

	local Started = os.clock()
	local Landed = 0
	local Connection: RBXScriptConnection
	Connection = RunService.RenderStepped:Connect(function()
		local Elapsed = os.clock() - Started
		for Index = #Coins, 1, -1 do
			local Coin = Coins[Index]
			local Point = Coin.Spread
			local Scale = 1
			if Elapsed < BurstTime then
				local Alpha = Elapsed / BurstTime
				Point = Center:Lerp(Coin.Spread, TweenService:GetValue(Alpha, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
				Scale = Alpha
			elseif Elapsed >= Coin.Delay then
				local Alpha = math.min((Elapsed - Coin.Delay) / FlyTime, 1)
				local Eased = TweenService:GetValue(Alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Point = Coin.Spread:Lerp(Coin.Curve, Eased):Lerp(Coin.Curve:Lerp(Goal, Eased), Eased)
				Scale = 1 - Eased * 0.4
				if Alpha >= 1 then
					Coin.Symbol:Destroy()
					table.remove(Coins, Index)
					Land(Amount / Count)
					Landed += 1
					Sfx.Play(Sounds.Studs.Land, LandVolume, 1 + Landed * LandPitchStep)
					continue
				end
			end
			Coin.Symbol.Position = UDim2.fromOffset(Point.X, Point.Y)
			Coin.Symbol.Size = UDim2.fromOffset(Size * Scale, Size * Scale)
		end
		if #Coins == 0 then
			Connection:Disconnect()
		end
	end)
end

return GainBurst
