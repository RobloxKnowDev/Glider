local function AbbreviateNumber(Value: number): string
	local Number = tonumber(Value)
	if not Number then
		warn("Provided value can not be converted into number.")
		return tostring(Value)
	end

	local IsNegative = Number < 0
	if IsNegative then
		Number = math.abs(Number)
	end

	Number = math.round(Number * 100) / 100
	local IntegerPart, DecimalPart = math.modf(Number)
	local FormattedInteger = tostring(IntegerPart)

	while true do
		local Updated, Count = string.gsub(FormattedInteger, "^(-?%d+)(%d%d%d)", "%1,%2")
		FormattedInteger = Updated
		if Count == 0 then
			break
		end
	end

	local Formatted = FormattedInteger
	if DecimalPart ~= 0 then
		local DecimalString = string.format("%.2f", DecimalPart):gsub("^0", ""):gsub("0+$", "")
		DecimalString = DecimalString:gsub("%.$", "")
		Formatted ..= DecimalString
	end

	if IsNegative then
		Formatted = "-" .. Formatted
	end

	return Formatted
end

return AbbreviateNumber
