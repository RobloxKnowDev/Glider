local Datastorerequest = {}

local Basedelay = 1
local Maximumdelay = 8
local Finalcodes = {
	["101"] = true,
	["102"] = true,
	["103"] = true,
	["104"] = true,
	["105"] = true,
	["106"] = true,
	["107"] = true,
	["401"] = true,
	["402"] = true,
	["403"] = true,
	["509"] = true,
	["511"] = true,
	["512"] = true,
	["513"] = true,
}
local Finalnames = { "StudioAccessToApisNotAllowed", "DataModelNoAccess", "LuaWebSrvsNoAccess", "OperationNotAllowed" }

function Datastorerequest.Isretryable(Error: any): boolean
	local Message = tostring(Error)
	local Code = string.match(Message, "^%s*(%d%d%d)")
	if Code and Finalcodes[Code] then
		return false
	end
	for _, Name in ipairs(Finalnames) do
		if string.find(Message, Name, 1, true) then
			return false
		end
	end
	return true
end

function Datastorerequest.Backoff(Attempt: number): number
	return math.min(Maximumdelay, Basedelay * 2 ^ (Attempt - 1)) * (0.5 + math.random())
end

function Datastorerequest.Run(Attempts: number, Callback: () -> ...any): (boolean, ...any)
	local Attempt = 1
	while true do
		local Result = table.pack(pcall(Callback))
		if Result[1] or Attempt >= Attempts or not Datastorerequest.Isretryable(Result[2]) then
			return table.unpack(Result, 1, Result.n)
		end
		task.wait(Datastorerequest.Backoff(Attempt))
		Attempt += 1
	end
end

return Datastorerequest
