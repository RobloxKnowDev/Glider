local function GliderFrame(Bar: BasePart): CFrame
	local Size = Bar.Size
	local Up = Bar.CFrame:VectorToObjectSpace(Vector3.yAxis)
	local Axis = if Size.X >= Size.Y and Size.X >= Size.Z then Vector3.xAxis elseif Size.Z >= Size.Y then Vector3.zAxis else Vector3.yAxis
	return CFrame.lookAlong(Vector3.zero, Up:Cross(Axis).Unit, Up)
end

return GliderFrame
