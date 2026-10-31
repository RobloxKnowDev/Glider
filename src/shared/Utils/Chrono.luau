local function FormatChrono(Time: number): string
	local Hundredths = math.floor(Time * 100)
	return string.format("%02d:%02d.%02d", Hundredths // 6000, Hundredths // 100 % 60, Hundredths % 100)
end

return FormatChrono
