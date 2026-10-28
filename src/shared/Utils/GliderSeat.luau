local function GliderSeat(Frame: CFrame, Height: number, Offset: number): CFrame
	return Frame * CFrame.new(Offset, Height, 0)
end

return GliderSeat
