local function FormatDuration(Seconds: number): string
	local Total = math.max(math.ceil(Seconds), 0)
	local Hours = math.floor(Total / 3600)
	local Minutes = math.floor(Total % 3600 / 60)
	if Hours > 0 then
		return string.format("%dh%02dm", Hours, Minutes)
	end
	if Minutes > 0 then
		return string.format("%dm%02ds", Minutes, Total % 60)
	end
	return string.format("%ds", Total)
end

return FormatDuration
