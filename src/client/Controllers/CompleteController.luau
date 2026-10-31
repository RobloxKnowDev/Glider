local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Format = require(ReplicatedStorage.Shared.Utils.Chrono)
local Sfx = require(ReplicatedStorage.Shared.Utils.Sfx)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)

local CompleteController = {
	Name = "CompleteController",
	Priority = 27,
}

type Confetti = {
	Piece: Frame,
	Position: Vector2,
	Velocity: Vector2,
	Spin: number,
	Phase: number,
}

local Player = Players.LocalPlayer
local DisplayOrder = 90
local BannerY = 0.2
local BannerHeight = 0.24
local TitleHeight = 0.62
local InfoHeight = 0.26
local InfoGap = 14
local BandColor = Color3.new(0, 0, 0)
local BandTransparency = 0.35
local TitleTop = Color3.fromRGB(255, 245, 140)
local TitleBottom = Color3.fromRGB(255, 160, 20)
local TitleStroke = Color3.fromRGB(110, 50, 0)
local TitleThickness = 4
local TextColor = Color3.new(1, 1, 1)
local OutlineColor = Color3.new(0, 0, 0)
local BestColor = Color3.fromRGB(21, 255, 0)
local BestStroke = Color3.fromRGB(26, 98, 0)
local InfoThickness = 2.5
local SlamScale = 2.5
local SlamTilt = -6
local PulseScale = 1.06
local InfoDelay = 0.35
local BestDelay = 0.65
local HoldTime = 3.5
local BandInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local SlamInfo = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local AppearInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PopInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PulseInfo = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local FadeInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local ConfettiCount = 70
local ConfettiSize = 0.016
local ConfettiSpeed = NumberRange.new(0.9, 1.4)
local ConfettiAngle = NumberRange.new(55, 80)
local ConfettiSpin = 360
local ConfettiFlip = 8
local ConfettiGravity = 1.2
local ConfettiDrag = 1.5
local ConfettiFall = 0.25
local ConfettiSway = 0.015
local ConfettiLife = 3.5
local ConfettiFade = 0.6
local ConfettiColors = {
	Color3.fromRGB(255, 70, 90),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(110, 230, 90),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 255, 255),
}
local FanfareVolume = 0.5

local function Pick(Range: NumberRange): number
	return Range.Min + math.random() * (Range.Max - Range.Min)
end

local function Pop(Scale: UIScale, Delay: number)
	task.delay(Delay, function()
		TweenService:Create(Scale, PopInfo, { Scale = 1 }):Play()
	end)
end

local function Fade(Root: Instance)
	for _, Object in ipairs(Root:GetDescendants()) do
		if Object:IsA("TextLabel") then
			TweenService:Create(Object, FadeInfo, { TextTransparency = 1 }):Play()
		elseif Object:IsA("UIStroke") then
			TweenService:Create(Object, FadeInfo, { Transparency = 1 }):Play()
		elseif Object:IsA("Frame") then
			TweenService:Create(Object, FadeInfo, { BackgroundTransparency = 1 }):Play()
		end
	end
end

function CompleteController:Label(Name: string, Color: Color3, Stroke: Color3, Thickness: number): (TextLabel, UIScale, UIStroke)
	local Label = Instance.new("TextLabel")
	Label.Name = Name
	Label.BackgroundTransparency = 1
	Label.FontFace = self.font
	Label.TextColor3 = Color
	Label.TextScaled = true

	local Outline = Instance.new("UIStroke")
	Outline.Color = Stroke
	Outline.Thickness = Thickness
	Outline.Parent = Label

	local Scale = Instance.new("UIScale")
	Scale.Scale = 0
	Scale.Parent = Label
	return Label, Scale, Outline
end

function CompleteController:Line(Name: string, Color: Color3, Stroke: Color3, Order: number, Parent: Frame): (TextLabel, UIScale)
	local Label, Scale = self:Label(Name, Color, Stroke, InfoThickness)
	Label.LayoutOrder = Order
	Label.Size = UDim2.fromScale(0, 1)
	Label.AutomaticSize = Enum.AutomaticSize.X
	Label.TextScaled = false
	Label.TextSize = self.gui.AbsoluteSize.Y * BannerHeight * InfoHeight
	Label.Parent = Parent
	return Label, Scale
end

function CompleteController:Burst()
	local Screen = self.gui.AbsoluteSize
	local Height = Screen.Y
	local Size = Height * ConfettiSize
	local Pieces: { Confetti } = {}
	for Index = 1, ConfettiCount do
		local Side = if Index % 2 == 0 then 1 else -1
		local Angle = math.rad(Pick(ConfettiAngle))
		local Start = Vector2.new(if Side == 1 then 0 else Screen.X, Height)
		local Piece = Instance.new("Frame")
		Piece.AnchorPoint = Vector2.new(0.5, 0.5)
		Piece.Position = UDim2.fromOffset(Start.X, Start.Y)
		Piece.Size = UDim2.fromOffset(Size, Size / 2)
		Piece.BackgroundColor3 = ConfettiColors[math.random(#ConfettiColors)]
		Piece.BorderSizePixel = 0
		Piece.Rotation = math.random(0, 360)
		Piece.Parent = self.gui
		table.insert(Pieces, {
			Piece = Piece,
			Position = Start,
			Velocity = Vector2.new(Side * math.cos(Angle), -math.sin(Angle)) * Pick(ConfettiSpeed) * Height,
			Spin = (math.random() * 2 - 1) * ConfettiSpin,
			Phase = math.random() * 2 * math.pi,
		})
	end

	local Started = os.clock()
	local Connection: RBXScriptConnection
	Connection = RunService.RenderStepped:Connect(function(Dt)
		local Elapsed = os.clock() - Started
		local Transparency = math.clamp((Elapsed - ConfettiLife + ConfettiFade) / ConfettiFade, 0, 1)
		for _, Confetti in ipairs(Pieces) do
			local Velocity = Confetti.Velocity + Vector2.new(0, ConfettiGravity * Height * Dt)
			Confetti.Velocity = Vector2.new(Velocity.X * math.exp(-ConfettiDrag * Dt), math.min(Velocity.Y, ConfettiFall * Height))
			Confetti.Position += Confetti.Velocity * Dt
			local Wave = Elapsed * ConfettiFlip + Confetti.Phase
			Confetti.Piece.Position = UDim2.fromOffset(Confetti.Position.X + math.sin(Wave) * ConfettiSway * Height, Confetti.Position.Y)
			Confetti.Piece.Size = UDim2.fromOffset(Size * math.abs(math.cos(Wave)), Size / 2)
			Confetti.Piece.Rotation += Confetti.Spin * Dt
			Confetti.Piece.BackgroundTransparency = Transparency
		end
		if Elapsed >= ConfettiLife then
			Connection:Disconnect()
			for _, Confetti in ipairs(Pieces) do
				Confetti.Piece:Destroy()
			end
		end
	end)
end

function CompleteController:Show(Time: number, Record: boolean)
	local Banner = Instance.new("Frame")
	Banner.Name = "Banner"
	Banner.AnchorPoint = Vector2.new(0.5, 0.5)
	Banner.Position = UDim2.fromScale(0.5, BannerY)
	Banner.Size = UDim2.fromScale(1, BannerHeight)
	Banner.BackgroundTransparency = 1
	Banner.ZIndex = 2
	Banner.Parent = self.gui

	local Band = Instance.new("Frame")
	Band.Name = "Band"
	Band.AnchorPoint = Vector2.new(0.5, 0.5)
	Band.Position = UDim2.fromScale(0.5, 0.5)
	Band.Size = UDim2.fromScale(0, 1)
	Band.BackgroundColor3 = BandColor
	Band.BackgroundTransparency = BandTransparency
	Band.BorderSizePixel = 0
	Band.Parent = Banner

	local Edges = Instance.new("UIGradient")
	Edges.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(0.7, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	Edges.Parent = Band

	local Title, TitleScale, TitleOutline = self:Label("Title", TextColor, TitleStroke, TitleThickness)
	Title.AnchorPoint = Vector2.new(0.5, 0.5)
	Title.Position = UDim2.fromScale(0.5, TitleHeight / 2)
	Title.Size = UDim2.fromScale(1, TitleHeight)
	Title.Rotation = SlamTilt
	Title.TextTransparency = 1
	Title.Parent = Banner
	Translation.Set(Title, "FINISH!")
	TitleScale.Scale = SlamScale
	TitleOutline.Transparency = 1

	local Gold = Instance.new("UIGradient")
	Gold.Color = ColorSequence.new(TitleTop, TitleBottom)
	Gold.Rotation = 90
	Gold.Parent = Title

	local Info = Instance.new("Frame")
	Info.Name = "Info"
	Info.AnchorPoint = Vector2.new(0.5, 0)
	Info.Position = UDim2.fromScale(0.5, TitleHeight)
	Info.Size = UDim2.fromScale(0, InfoHeight)
	Info.AutomaticSize = Enum.AutomaticSize.X
	Info.BackgroundTransparency = 1
	Info.Parent = Banner

	local Layout = Instance.new("UIListLayout")
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.Padding = UDim.new(0, InfoGap)
	Layout.Parent = Info

	local Clock, ClockScale = self:Line("Clock", TextColor, OutlineColor, 1, Info)
	Translation.Raw(Clock, Format(Time))
	Pop(ClockScale, InfoDelay)
	if Record then
		local Best, BestScale = self:Line("Best", BestColor, BestStroke, 2, Info)
		Translation.Set(Best, "New Best!")
		Pop(BestScale, BestDelay)
	end

	Sfx.Play(Sounds.Complete.Fanfare, FanfareVolume)
	self:Burst()
	TweenService:Create(Band, BandInfo, { Size = UDim2.fromScale(1, 1) }):Play()
	TweenService:Create(Title, AppearInfo, { TextTransparency = 0 }):Play()
	TweenService:Create(TitleOutline, AppearInfo, { Transparency = 0 }):Play()
	TweenService:Create(Title, SlamInfo, { Rotation = 0 }):Play()
	local Slam = TweenService:Create(TitleScale, SlamInfo, { Scale = 1 })
	Slam.Completed:Once(function()
		TweenService:Create(TitleScale, PulseInfo, { Scale = PulseScale }):Play()
	end)
	Slam:Play()

	task.delay(HoldTime, function()
		Fade(Banner)
		local Close = TweenService:Create(Band, FadeInfo, { Size = UDim2.fromScale(0, 1) })
		Close:Play()
		Close.Completed:Wait()
		Banner:Destroy()
	end)
end

function CompleteController:Init()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Hud = PlayerGui:WaitForChild("HUD")
	self.font = (Hud:WaitForChild("CoinFrame"):WaitForChild("Text") :: TextLabel).FontFace

	local Gui = Instance.new("ScreenGui")
	Gui.Name = "CompleteUi"
	Gui.ResetOnSpawn = false
	Gui.IgnoreGuiInset = true
	Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Gui.DisplayOrder = DisplayOrder
	Gui.Parent = PlayerGui
	self.gui = Gui

	Remotemanager:OnClientEvent("GliderService", "Completed", function(Time, Record)
		Core:GetController("TransitionController"):Wait()
		self:Show(Time, Record)
	end)
end

return CompleteController
