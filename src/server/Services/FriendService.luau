local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FriendService = {
	Name = "FriendService",
	Priority = 6,
}

local BoostPerFriend = 10
local Testing = RunService:IsStudio()
local Friends: { [Player]: { [Player]: boolean } } = {}

local function Befriended(Player: Player, Other: Player): boolean
	if Testing then
		return true
	end
	local Success, Result = pcall(Player.IsFriendsWith, Player, Other.UserId)
	return Success and Result
end

local function Refresh(Player: Player)
	local Count = 0
	for _ in pairs(Friends[Player]) do
		Count += 1
	end
	Player:SetAttribute("FriendBoost", Count * BoostPerFriend)
end

function FriendService:Boost(Player: Player, Amount: number): number
	return math.round(Amount * (100 + Player:GetAttribute("FriendBoost")) / 100)
end

function FriendService:Join(Player: Player)
	Friends[Player] = {}
	Player:SetAttribute("FriendBoost", 0)
	for _, Other in ipairs(Players:GetPlayers()) do
		if Other ~= Player then
			task.spawn(function()
				if Befriended(Player, Other) and Friends[Player] and Friends[Other] then
					Friends[Player][Other] = true
					Friends[Other][Player] = true
					Refresh(Player)
					Refresh(Other)
				end
			end)
		end
	end
end

function FriendService:Leave(Player: Player)
	for Other in pairs(Friends[Player]) do
		Friends[Other][Player] = nil
		Refresh(Other)
	end
	Friends[Player] = nil
end

function FriendService:Init()
	Players.PlayerAdded:Connect(function(Player)
		self:Join(Player)
	end)
	Players.PlayerRemoving:Connect(function(Player)
		self:Leave(Player)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		self:Join(Player)
	end
end

return FriendService
