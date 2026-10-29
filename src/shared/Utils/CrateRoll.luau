export type Reward = {
	Category: string,
	Name: string,
	Chance: number,
}

local function CrateRoll(Rewards: { Reward }, Generator: Random): Reward
	local Total = 0
	for _, Reward in ipairs(Rewards) do
		Total += Reward.Chance
	end
	local Value = Generator:NextNumber() * Total
	for _, Reward in ipairs(Rewards) do
		if Value < Reward.Chance then
			return Reward
		end
		Value -= Reward.Chance
	end
	return Rewards[#Rewards]
end

return CrateRoll
