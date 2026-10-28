local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local NumberAbbreviator = require(ReplicatedStorage.Shared.Utils.NumberAbbreviator)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)

local StudsController = {
	Name = "StudsController",
	Priority = 25,
}

type Coin = {
	Label: TextLabel,
	Spread: Vector2,
	Curve: Vector2,
	Delay: number,
}

local GainColor = Color3.fromRGB(21, 255, 0)
local GainStroke = Color3.fromRGB(26, 98, 0)
local BurstTime = 0.35
local FlyTime = 0.55
local Stagger = 0.06
local PopupHold = 0.8
local PopupInfo = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FadeInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local BumpInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FlashInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function StudsController:Symbol(Text: string): (TextLabel, UIStroke)
	local Label = Instance.new("TextLabel")
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.BackgroundTransparency = 1
	Label.FontFace = self.text.FontFace
	Label.TextColor3 = GainColor
	Label.TextScaled = true
	Label.ZIndex = 10
	Translation.Raw(Label, Text)
	local Stroke = Instance.new("UIStroke")
	Stroke.Thickness = 2
	Stroke.Color = GainStroke
	Stroke.Parent = Label
	return Label, Stroke
end

function StudsController:Show()
	Translation.Raw(self.text, NumberAbbreviator(math.round(self.value - self.pending)) .. "$")
end

function StudsController:Popup(Amount: number)
	local Height = self.text.AbsoluteSize.Y * 2
	local Label, Stroke = self:Symbol("+" .. NumberAbbreviator(Amount) .. "$")
	Label.Position = UDim2.fromScale(0.5, 0.4)
	Label.Size = UDim2.fromOffset(Height * 5, Height)
	local Scale = Instance.new("UIScale")
	Scale.Scale = 0
	Scale.Parent = Label
	Label.Parent = self.hud
	TweenService:Create(Scale, PopupInfo, { Scale = 1 }):Play()
	task.delay(PopupHold, function()
		TweenService:Create(Label, FadeInfo, { Position = UDim2.fromScale(0.5, 0.33), TextTransparency = 1 }):Play()
		local Fade = TweenService:Create(Stroke, FadeInfo, { Transparency = 1 })
		Fade:Play()
		Fade.Completed:Wait()
		Label:Destroy()
	end)
end

function StudsController:Land(Share: number)
	self.pending -= Share
	self:Show()
	self.scale.Scale = 1.15
	TweenService:Create(self.scale, BumpInfo, { Scale = 1 }):Play()
	self.text.TextColor3 = GainColor
	TweenService:Create(self.text, FlashInfo, { TextColor3 = self.color }):Play()
end

function StudsController:Gain(Amount: number)
	self.pending += Amount
	self:Show()
	self:Popup(Amount)

	local Center = self.hud.AbsoluteSize / 2
	local Target = self.text.AbsolutePosition + self.text.AbsoluteSize / 2
	local Size = self.text.AbsoluteSize.Y * 1.3
	local Count = math.clamp(math.floor(math.log10(Amount + 1) * 3), 4, 12)
	local Coins: { Coin } = {}
	for Index = 1, Count do
		local Angle = math.random() * 2 * math.pi
		local Direction = Vector2.new(math.cos(Angle), math.sin(Angle))
		local Spread = Center + Direction * math.random(60, 140)
		local Label = self:Symbol("$")
		Label.Position = UDim2.fromOffset(Center.X, Center.Y)
		Label.Size = UDim2.fromOffset(0, 0)
		Label.Rotation = math.random(-30, 30)
		Label.Parent = self.hud
		table.insert(Coins, {
			Label = Label,
			Spread = Spread,
			Curve = Spread + Direction * 120,
			Delay = BurstTime + (Index - 1) * Stagger,
		})
	end

	local Started = os.clock()
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
				Point = Coin.Spread:Lerp(Coin.Curve, Eased):Lerp(Coin.Curve:Lerp(Target, Eased), Eased)
				Scale = 1 - Eased * 0.4
				if Alpha >= 1 then
					Coin.Label:Destroy()
					table.remove(Coins, Index)
					self:Land(Amount / Count)
					continue
				end
			end
			Coin.Label.Position = UDim2.fromOffset(Point.X, Point.Y)
			Coin.Label.Size = UDim2.fromOffset(Size * Scale, Size * Scale)
		end
		if #Coins == 0 then
			Connection:Disconnect()
		end
	end)
end

function StudsController:Init()
	self.hud = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("HUD")
	local CoinFrame = self.hud:WaitForChild("CoinFrame")
	self.text = CoinFrame:WaitForChild("Text") :: TextLabel
	self.color = self.text.TextColor3
	self.scale = Instance.new("UIScale")
	self.scale.Parent = self.text
	self.value = 0
	self.pending = 0
	UiFade.BindButton(CoinFrame:WaitForChild("BuyButton") :: GuiButton)
end

function StudsController:Start()
	Remotemanager:OnClientEvent("StudsService", "Updated", function(Value, Gained)
		self.value = Value
		if Gained > 0 then
			self:Gain(Gained)
		else
			self:Show()
		end
	end)
	task.spawn(function()
		self.value = Remotemanager:InvokeServer("StudsService", "GetStuds")
		self:Show()
	end)
end

return StudsController
