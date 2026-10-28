local Localizationservice = game:GetService("LocalizationService")
local Players = game:GetService("Players")

type Binding = { Pattern: string, Values: { n: number, [number]: any }, Text: string }

local Translation = {}

local Placeholder = "{(%d+)}"
local Loadtimeout = 5
local Retrycount = 5
local Retrydelay = 2
local Player = Players.LocalPlayer
local Translator: Translator? = nil
local Cache: { [string]: string } = {}
local Captures: { [string]: TextLabel } = {}
local Bindings: { [TextLabel]: Binding } = setmetatable({}, { __mode = "k" }) :: any

local Capturegui = Instance.new("ScreenGui")
Capturegui.Name = "TranslationCapture"
Capturegui.ResetOnSpawn = false
Capturegui.DisplayOrder = -1
Capturegui.Parent = Player:WaitForChild("PlayerGui")

local function Haswords(Pattern: string): boolean
	return string.find((string.gsub(Pattern, Placeholder, "")), "%a") ~= nil
end

local function Capture(Pattern: string): TextLabel
	local Label = Captures[Pattern]
	if Label then
		return Label
	end
	Label = Instance.new("TextLabel")
	Label.Name = "Capture"
	Label.BackgroundTransparency = 1
	Label.TextTransparency = 1
	Label.Size = UDim2.fromOffset(1, 1)
	Label.Text = Pattern
	Label.Parent = Capturegui
	Captures[Pattern] = Label
	return Label
end

local function Translate(Pattern: string): string
	local Label = Capture(Pattern)
	if not Translator then
		return Pattern
	end
	local Cached = Cache[Pattern]
	if Cached then
		return Cached
	end
	local Text = Translator:Translate(Label, Pattern)
	for Index in string.gmatch(Pattern, Placeholder) do
		if not string.find(Text, "{" .. Index .. "}", 1, true) then
			Text = Pattern
			break
		end
	end
	Cache[Pattern] = Text
	return Text
end

function Translation.Format(Pattern: string, ...: any): string
	local Text = if Haswords(Pattern) then Translate(Pattern) else Pattern
	local Values = table.pack(...)
	if Values.n == 0 then
		return Text
	end
	return (string.gsub(Text, Placeholder, function(Index: string): string
		local Value = Values[tonumber(Index) :: number]
		return if Value == nil then "{" .. Index .. "}" else tostring(Value)
	end))
end

function Translation.Set(Label: TextLabel, Pattern: string, ...: any)
	local Text = Translation.Format(Pattern, ...)
	local Binding = Bindings[Label]
	if Binding and Binding.Pattern == Pattern and Binding.Text == Text and Label.Text == Text then
		return
	end
	Label.AutoLocalize = false
	Label.Text = Text
	Bindings[Label] = { Pattern = Pattern, Values = table.pack(...), Text = Text }
end

function Translation.Raw(Label: TextLabel, Text: string)
	Label.AutoLocalize = false
	Label.Text = Text
	Bindings[Label] = nil
end

function Translation.Prepare(Patterns: { string })
	for _, Pattern in ipairs(Patterns) do
		if Haswords(Pattern) then
			Capture(Pattern)
		end
	end
end

local function Refresh()
	table.clear(Cache)
	for Label, Binding in pairs(Bindings) do
		if Label.Text == Binding.Text then
			Binding.Text = Translation.Format(Binding.Pattern, table.unpack(Binding.Values, 1, Binding.Values.n))
			Label.Text = Binding.Text
		end
	end
end

function Translation.Load()
	local Attempted = false
	task.spawn(function()
		for _ = 1, Retrycount do
			local Success, Result = pcall(Localizationservice.GetTranslatorForPlayerAsync, Localizationservice, Player)
			Attempted = true
			if Success then
				Translator = Result
				Result:GetPropertyChangedSignal("LocaleId"):Connect(Refresh)
				Refresh()
				return
			end
			warn("Translation: " .. tostring(Result))
			task.wait(Retrydelay)
		end
	end)
	local Deadline = os.clock() + Loadtimeout
	while not Attempted and os.clock() < Deadline do
		task.wait()
	end
end

return Translation
