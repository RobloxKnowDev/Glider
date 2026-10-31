local Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 165, 50)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 235, 70)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 220, 100)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(175, 90, 255)),
})

return {
	Default = "White",
	List = {
		{
			Name = "White",
			Rarity = "Common",
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		},
		{
			Name = "Heart",
			Rarity = "Epic",
			Color = ColorSequence.new(Color3.fromRGB(255, 140, 200), Color3.fromRGB(255, 40, 90)),
			Particle = "Heart",
			Gamepass = 0,
			Price = 99,
		},
		{
			Name = "Sky",
			Rarity = "Rare",
			Color = ColorSequence.new(Color3.fromRGB(130, 200, 255)),
		},
		{
			Name = "Sunset",
			Rarity = "Epic",
			Color = ColorSequence.new(Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 70, 140)),
			Sparkles = ColorSequence.new(Color3.fromRGB(255, 225, 130), Color3.fromRGB(255, 130, 175)),
		},
		{
			Name = "Galaxy",
			Rarity = "Legendary",
			Color = ColorSequence.new(Color3.fromRGB(170, 100, 255), Color3.fromRGB(60, 140, 255)),
			Sparkles = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 165, 255)),
		},
		{
			Name = "Rainbow",
			Rarity = "Mythic",
			Color = Rainbow,
			Sparkles = Rainbow,
		},
		{
			Name = "Witch",
			Rarity = "Epic",
			Color = ColorSequence.new(Color3.fromRGB(150, 60, 220), Color3.fromRGB(110, 255, 90)),
			Sparkles = ColorSequence.new(Color3.fromRGB(190, 120, 255), Color3.fromRGB(150, 255, 120)),
		},
		{
			Name = "Pumpkin",
			Rarity = "Legendary",
			Color = ColorSequence.new(Color3.fromRGB(255, 140, 30), Color3.fromRGB(110, 40, 140)),
			Particle = "Pumpkin",
		},
	},
}
