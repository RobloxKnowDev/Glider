local Tweenservice = game:GetService("TweenService")

local Sounds = require(script.Parent.Parent.Config.Sounds)
local Sfx = require(script.Parent.Sfx)

local Uifade = {}

local Defaultduration = 0.2
local Fadeeasing = Enum.EasingStyle.Quad
local Fadedirection = Enum.EasingDirection.Out

local Popduration = 0.26
local Popstartscale = 0.72
local Popeasing = Enum.EasingStyle.Back
local Popdirection = Enum.EasingDirection.Out

local Hoverscale = 1.08
local Pressscale = 0.95
local Hoverinfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Hovervolume = 0.7
local Clickvolume = 0.5

local Fadeproperties = {
	Frame = { "BackgroundTransparency" },
	ScrollingFrame = { "BackgroundTransparency" },
	CanvasGroup = { "BackgroundTransparency", "GroupTransparency" },
	ImageLabel = { "BackgroundTransparency", "ImageTransparency" },
	ImageButton = { "BackgroundTransparency", "ImageTransparency" },
	TextLabel = { "BackgroundTransparency", "TextTransparency", "TextStrokeTransparency" },
	TextButton = { "BackgroundTransparency", "TextTransparency", "TextStrokeTransparency" },
}

local Bases = setmetatable({}, { __mode = "k" })
local Tweens = setmetatable({}, { __mode = "k" })
local States = setmetatable({}, { __mode = "k" })
local Scaletweens = setmetatable({}, { __mode = "k" })
local Scalebases = setmetatable({}, { __mode = "k" })
local Sizetweens = setmetatable({}, { __mode = "k" })

local function Getbase(Element: Instance)
	local Base = Bases[Element]
	if Base then
		return Base
	end

	local Target = Element :: any
	Base = {}
	for _, Property in ipairs(Fadeproperties[Element.ClassName]) do
		Base[Property] = Target[Property]
	end
	Bases[Element] = Base
	return Base
end

local function Ensurescale(Element: GuiObject): UIScale
	local Existing = Element:FindFirstChildOfClass("UIScale")
	if Existing then
		return Existing
	end

	local Scale = Instance.new("UIScale")
	Scale.Parent = Element
	return Scale
end

local function Getbasescale(Scale: UIScale): number
	local Basescale = Scalebases[Scale]
	if not Basescale then
		Basescale = Scale.Scale
		Scalebases[Scale] = Basescale
	end
	return Basescale
end

local function Playscale(Element: GuiObject, Scale: UIScale, Goalscale: number, Info: TweenInfo)
	local Running = Scaletweens[Element]
	if Running then
		Running:Cancel()
		Scaletweens[Element] = nil
	end

	local Tween = Tweenservice:Create(Scale, Info, { Scale = Goalscale })
	Scaletweens[Element] = Tween
	Tween.Completed:Once(function()
		if Scaletweens[Element] == Tween then
			Scaletweens[Element] = nil
		end
	end)
	Tween:Play()
end

function Uifade.Pop(Element: GuiObject, Duration: number?)
	local Scale = Ensurescale(Element)
	local Basescale = Getbasescale(Scale)
	Scale.Scale = Basescale * Popstartscale
	Playscale(Element, Scale, Basescale, TweenInfo.new(Duration or Popduration, Popeasing, Popdirection))
end

local function Playsize(Button: GuiButton, Goalsize: UDim2, Info: TweenInfo)
	local Running = Sizetweens[Button]
	if Running then
		Running:Cancel()
		Sizetweens[Button] = nil
	end

	local Tween = Tweenservice:Create(Button, Info, { Size = Goalsize })
	Sizetweens[Button] = Tween
	Tween.Completed:Once(function()
		if Sizetweens[Button] == Tween then
			Sizetweens[Button] = nil
		end
	end)
	Tween:Play()
end

function Uifade.Hover()
	Sfx.Play(Sounds.Ui.Hover, Hovervolume)
end

function Uifade.Click()
	Sfx.Play(Sounds.Ui.Click, Clickvolume)
end

local function Bindstates(Button: GuiButton, Animate: (Multiplier: number) -> (), Reset: () -> ())
	local Hovering = false

	Button.MouseEnter:Connect(function()
		Hovering = true
		Animate(Hoverscale)
		Uifade.Hover()
	end)
	Button.MouseLeave:Connect(function()
		Hovering = false
		Animate(1)
	end)
	Button.SelectionGained:Connect(function()
		Hovering = true
		Animate(Hoverscale)
		Uifade.Hover()
	end)
	Button.SelectionLost:Connect(function()
		Hovering = false
		Animate(1)
	end)
	Button.MouseButton1Down:Connect(function()
		Animate(Pressscale)
		Uifade.Click()
	end)
	Button.MouseButton1Up:Connect(function()
		Animate(if Hovering then Hoverscale else 1)
	end)
	Button:GetPropertyChangedSignal("Visible"):Connect(function()
		if Button.Visible then
			return
		end
		Hovering = false
		Reset()
	end)
end

function Uifade.BindButton(Button: GuiButton)
	local Scale = Ensurescale(Button)
	local Basescale = Getbasescale(Scale)

	Bindstates(Button, function(Multiplier: number)
		Playscale(Button, Scale, Basescale * Multiplier, Hoverinfo)
	end, function()
		local Running = Scaletweens[Button]
		if Running then
			Running:Cancel()
			Scaletweens[Button] = nil
		end
		Scale.Scale = Basescale
	end)
end

function Uifade.BindButtonSize(Button: GuiButton)
	local Basesize = Button.Size

	Bindstates(Button, function(Multiplier: number)
		local Goalsize = UDim2.new(
			Basesize.X.Scale * Multiplier,
			Basesize.X.Offset * Multiplier,
			Basesize.Y.Scale * Multiplier,
			Basesize.Y.Offset * Multiplier
		)
		Playsize(Button, Goalsize, Hoverinfo)
	end, function()
		local Running = Sizetweens[Button]
		if Running then
			Running:Cancel()
			Sizetweens[Button] = nil
		end
		Button.Size = Basesize
	end)
end

function Uifade.SetVisible(Element: GuiObject, Visible: boolean, Duration: number?): boolean
	if States[Element] == Visible then
		return false
	end

	local Isfirst = States[Element] == nil
	States[Element] = Visible
	Element.Interactable = Visible

	local Base = Getbase(Element)
	local Target = Element :: any
	local Running = Tweens[Element]
	if Running then
		Running:Cancel()
		Tweens[Element] = nil
	end

	if Isfirst then
		for Property, Value in pairs(Base) do
			Target[Property] = if Visible then Value else 1
		end
		Element.Visible = Visible
		return false
	end

	local Goal = {}
	for Property, Value in pairs(Base) do
		Goal[Property] = if Visible then Value else 1
	end

	if Visible then
		if not Element.Visible then
			for Property in pairs(Base) do
				Target[Property] = 1
			end
		end
		Element.Visible = true
	end

	local Tween =
		Tweenservice:Create(Element, TweenInfo.new(Duration or Defaultduration, Fadeeasing, Fadedirection), Goal)
	Tweens[Element] = Tween
	Tween.Completed:Once(function(State)
		if Tweens[Element] == Tween then
			Tweens[Element] = nil
		end
		if not Visible and State == Enum.PlaybackState.Completed then
			Element.Visible = false
		end
	end)
	Tween:Play()
	return true
end

return Uifade
