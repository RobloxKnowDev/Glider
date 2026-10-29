local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Datastorerequest = require(script.Parent.Parent.Utils.Datastorerequest)

local Dataservice = {
	Name = "DataService",
	Priority = 1,
}

local Store = DataStoreService:GetDataStore("PlayerData_v1")
local Readoptions = Instance.new("DataStoreGetOptions")
Readoptions.UseCache = false
local Verboselogs = false
local Isstudio = RunService:IsStudio()
local Format = 1
local Autosaveinterval = 20
local Lockexpiry = 180
local Lockwait = 30
local Lockpoll = 5
local Loadattempts = 5
local Saveattempts = 3
local Releaseattempts = 5
local Maximumpurchases = 100
local Maximumsize = 4_000_000
local Maximumdepth = 32
local Shutdowndeadline = 27
local Sectionorder = { "Settings", "Studs", "Gliders", "Trails", "Revives", "Skips", "Spins", "Passes", "Record" }

type Section = {
	Load: (Player, any) -> (),
	Save: (Player) -> any,
	Clear: (Player) -> (),
	Committed: ((Player, { [string]: any }, boolean) -> ())?,
}
type Profile = {
	Id: string,
	Userid: number,
	Name: string,
	Locked: boolean,
	Unlocked: boolean,
	Loaded: boolean,
	Errored: boolean,
	Lost: boolean,
	Released: boolean,
	New: boolean,
	Seq: number,
	Unsafe: { [string]: boolean },
	Warned: { [string]: boolean },
	Purchases: { string },
	Savedpurchases: { [string]: boolean },
	Granting: { [string]: boolean },
}

local Sections: { [string]: Section } = {}
local Profiles: { [Player]: Profile } = {}
local Loadedbyplayer: { [Player]: boolean } = {}
local Blockedbyplayer: { [Player]: boolean } = {}
local Lostbyplayer: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local Releasingbyuserid: { [number]: number } = {}
local Activereleases = 0

local function Log(Message: string)
	if Verboselogs then
		print("[DataService] " .. Message)
	end
end

local function Describe(Value: any): string
	if type(Value) ~= "table" then
		return tostring(Value)
	end
	local Keys = {}
	for Key in pairs(Value) do
		table.insert(Keys, tostring(Key))
	end
	table.sort(Keys)
	return "{" .. table.concat(Keys, ", ") .. "}"
end

local function Kick(Player: Player, Message: string)
	task.defer(function()
		if Player.Parent then
			Player:Kick(Message)
		end
	end)
end

local function Copyvalue(Value: any, Depth: number): (any, string?)
	local Kind = type(Value)
	if Kind == "boolean" then
		return Value, nil
	end
	if Kind == "number" then
		if Value ~= Value or Value == math.huge or Value == -math.huge then
			return nil, "a number that is NaN or infinite"
		end
		return Value, nil
	end
	if Kind == "string" then
		if not utf8.len(Value) then
			return nil, "a string that is not valid UTF-8"
		end
		return Value, nil
	end
	if Kind ~= "table" then
		return nil, "a value of type " .. typeof(Value)
	end
	if Depth > Maximumdepth then
		return nil, "tables nested too deeply"
	end
	local Copy = {}
	local Count = 0
	local Stringkeys = false
	local Numberkeys = false
	for Key, Item in pairs(Value) do
		if type(Key) == "string" then
			if not utf8.len(Key) then
				return nil, "a key that is not valid UTF-8"
			end
			Stringkeys = true
		elseif type(Key) == "number" then
			Numberkeys = true
		else
			return nil, "a key of type " .. typeof(Key)
		end
		local Itemcopy, Problem = Copyvalue(Item, Depth + 1)
		if Problem then
			return nil, Problem
		end
		Copy[Key] = Itemcopy
		Count += 1
	end
	if Numberkeys then
		if Stringkeys then
			return nil, "a table mixing number and string keys"
		end
		for Index = 1, Count do
			if Copy[Index] == nil then
				return nil, "an array with holes"
			end
		end
	end
	return Copy, nil
end

local function Mergepurchases(First: any, Second: any): { string }
	local Merged = {}
	local Seen = {}
	for _, List in ipairs({ First, Second }) do
		if type(List) == "table" then
			for _, Purchaseid in ipairs(List) do
				if type(Purchaseid) == "string" and not Seen[Purchaseid] then
					Seen[Purchaseid] = true
					table.insert(Merged, Purchaseid)
				end
			end
		end
	end
	while #Merged > Maximumpurchases do
		table.remove(Merged, 1)
	end
	return Merged
end

local function Newlock(Profile: Profile, Seq: number): { [string]: any }
	return { Id = Profile.Id, Job = game.JobId, Time = os.time(), Seq = Seq, Studio = Isstudio }
end

local function Ownslock(Profile: Profile, Value: any): boolean
	return type(Value) == "table" and type(Value._Session) == "table" and Value._Session.Id == Profile.Id
end

local function Hassections(Value: { [any]: any }): boolean
	for Key in pairs(Value) do
		if type(Key) ~= "string" or string.sub(Key, 1, 1) ~= "_" then
			return true
		end
	end
	return false
end

local function Refusal(Player: Player, Profile: Profile?): string?
	if not Profile or not Profile.Loaded then
		return "profile not loaded yet"
	end
	if Profile.Errored then
		return "the profile could not be loaded, saving is disabled"
	end
	if Profile.Lost then
		return "the profile is open in another server"
	end
	if Profile.Released then
		return "the player has left"
	end
	if Blockedbyplayer[Player] then
		return "data erased or restored, saving blocked"
	end
	return nil
end

local function Warnonce(Profile: Profile, Name: string, Message: string)
	if Profile.Warned[Name] then
		return
	end
	Profile.Warned[Name] = true
	warn("DataService: " .. Message)
end

local function Applysaved(Player: Player, Profile: Profile, Saved: { [string]: any })
	for _, Name in ipairs(Sectionorder) do
		local Handlers = Sections[Name]
		if Handlers and Saved[Name] ~= nil then
			local Success, Error = pcall(Handlers.Load, Player, Saved[Name])
			if Success then
				Log("applied " .. Name .. " = " .. Describe(Saved[Name]))
			else
				Profile.Unsafe[Name] = true
				warn("DataService: could not load " .. Name .. " for " .. Profile.Name .. ", its stored copy is kept: " .. tostring(Error))
			end
		end
	end
end

local function Buildsnapshot(Player: Player, Profile: Profile): ({ [string]: any }, number)
	local Snapshot = {}
	for _, Name in ipairs(Sectionorder) do
		local Handlers = Sections[Name]
		if Handlers and not Profile.Unsafe[Name] then
			local Success, Value = pcall(Handlers.Save, Player)
			if not Success then
				Warnonce(Profile, Name, "could not save " .. Name .. " for " .. Profile.Name .. ", its stored copy is kept: " .. tostring(Value))
			elseif Value ~= nil then
				local Copy, Problem = Copyvalue(Value, 1)
				if Problem then
					Warnonce(Profile, Name, Name .. " of " .. Profile.Name .. " contains " .. Problem .. ", its stored copy is kept")
				else
					Snapshot[Name] = Copy
					Log("  " .. Name .. " = " .. Describe(Copy))
				end
			end
		end
	end
	Profile.Seq += 1
	return Snapshot, Profile.Seq
end

local function Clearsections(Player: Player)
	for _, Name in ipairs(Sectionorder) do
		local Handlers = Sections[Name]
		if Handlers then
			local Success, Error = pcall(Handlers.Clear, Player)
			if not Success then
				warn("DataService: could not clear " .. Name .. " for " .. Player.Name .. ": " .. tostring(Error))
			end
		end
	end
	Log("memory released for " .. Player.Name)
end

local function Notifycommitted(Player: Player, Snapshot: { [string]: any }, Release: boolean)
	for _, Name in ipairs(Sectionorder) do
		local Handlers = Sections[Name]
		if Handlers and Handlers.Committed then
			local Success, Error = pcall(Handlers.Committed, Player, Snapshot, Release)
			if not Success then
				warn("DataService: " .. Name .. " could not handle a committed save of " .. Player.Name .. ": " .. tostring(Error))
			end
		end
	end
end

local function Write(Player: Player, Profile: Profile, Snapshot: { [string]: any }, Seq: number, Release: boolean, Attempts: number): (boolean, string)
	local Encoded, Json = pcall(HttpService.JSONEncode, HttpService, Snapshot)
	if not Encoded then
		return false, "the save could not be encoded: " .. tostring(Json)
	end
	if #Json > Maximumsize then
		return false, string.format("the save is too large (%d characters)", #Json)
	end
	local Purchases = table.clone(Profile.Purchases)
	local Outcome = "failed"
	local Success, Error = Datastorerequest.Run(Attempts, function()
		Store:UpdateAsync(tostring(Profile.Userid), function(Value)
			if not Ownslock(Profile, Value) then
				Outcome = "lost"
				return nil
			end
			if (tonumber(Value._Session.Seq) or 0) >= Seq then
				Outcome = "stale"
				return nil
			end
			for Name, Section in pairs(Snapshot) do
				Value[Name] = Section
			end
			Value._Purchases = Purchases
			Value._Format = Format
			Value._Session = if Release then nil else Newlock(Profile, Seq)
			Outcome = "written"
			return Value, { Profile.Userid }
		end)
	end)
	if not Success then
		return false, tostring(Error)
	end
	if Outcome == "lost" then
		return false, "lost"
	end
	for _, Purchaseid in ipairs(Purchases) do
		Profile.Savedpurchases[Purchaseid] = true
	end
	Log(Outcome .. " for " .. Profile.Name .. " (save " .. Seq .. ")")
	if Outcome == "written" and (Release or not Profile.Released) then
		Notifycommitted(Player, Snapshot, Release)
	end
	return true, Outcome
end

local function Unlock(Profile: Profile)
	Profile.Unlocked = true
	local Success, Error = Datastorerequest.Run(Releaseattempts, function()
		Store:UpdateAsync(tostring(Profile.Userid), function(Value)
			if not Ownslock(Profile, Value) then
				return nil
			end
			Value._Session = nil
			return Value, { Profile.Userid }
		end)
	end)
	if not Success then
		warn("DataService: could not unlock data for " .. Profile.Name .. ": " .. tostring(Error))
	end
end

local function Saveprofile(Player: Player, Profile: Profile, Attempts: number): (boolean, string)
	local Reason = Refusal(Player, Profile)
	if Reason then
		Log("save refused for " .. Profile.Name .. ": " .. Reason)
		return false, Reason
	end
	local Snapshot, Seq = Buildsnapshot(Player, Profile)
	local Saved, Result = Write(Player, Profile, Snapshot, Seq, false, Attempts)
	if Saved then
		return true, "ok"
	end
	if Result == "lost" then
		Lostbyplayer[Player] = true
		if not Profile.Released and not Blockedbyplayer[Player] then
			Profile.Lost = true
			warn("DataService: " .. Profile.Name .. "'s data was opened in another server, this session stops saving")
			Kick(Player, "Your data was opened in another server. Please rejoin.")
		end
		return false, "the profile is open in another server"
	end
	warn("DataService: could not save data for " .. Profile.Name .. ": " .. Result)
	return false, Result
end

local function Releaseprofile(Player: Player)
	local Profile = Profiles[Player]
	if not Profile or Profile.Released then
		return
	end
	local Writable = Profile.Loaded and not Profile.Errored and not Profile.Lost and not Blockedbyplayer[Player]
	Profile.Released = true
	Profiles[Player] = nil
	Activereleases += 1
	Releasingbyuserid[Profile.Userid] = (Releasingbyuserid[Profile.Userid] or 0) + 1
	Log("releasing " .. Profile.Name)
	local Snapshot = nil
	local Seq = 0
	if Writable then
		Snapshot, Seq = Buildsnapshot(Player, Profile)
	end
	Clearsections(Player)
	Loadedbyplayer[Player] = nil
	Blockedbyplayer[Player] = nil
	if Snapshot then
		Profile.Unlocked = true
		local Saved, Result = Write(Player, Profile, Snapshot, Seq, true, Releaseattempts)
		if Result == "lost" then
			Lostbyplayer[Player] = true
		elseif not Saved then
			warn("DataService: could not save data for " .. Profile.Name .. " when they left: " .. Result)
		end
	elseif Profile.Locked and not Profile.Lost then
		Unlock(Profile)
	end
	Activereleases -= 1
	local Remaining = Releasingbyuserid[Profile.Userid] - 1
	Releasingbyuserid[Profile.Userid] = if Remaining > 0 then Remaining else nil
end

local function Acquire(Profile: Profile, Steal: boolean): (boolean, string, any)
	local Status = "failed"
	local Loaded = nil
	local Success, Error = pcall(function()
		Store:UpdateAsync(tostring(Profile.Userid), function(Value)
			Loaded = nil
			if Value ~= nil and type(Value) ~= "table" then
				Status = "corrupt"
				return nil
			end
			local Current = Value or {}
			local Lock = Current._Session
			if
				type(Lock) == "table"
				and Lock.Id ~= Profile.Id
				and not Steal
				and not (Isstudio and Lock.Studio == true)
				and os.time() - (tonumber(Lock.Time) or 0) < Lockexpiry
			then
				Status = "locked"
				return nil
			end
			Current._Session = Newlock(Profile, 0)
			Status = "acquired"
			Loaded = Current
			return Current, { Profile.Userid }
		end)
	end)
	if not Success then
		return false, "error", Error
	end
	return true, Status, Loaded
end

local function Abortload(Player: Player, Profile: Profile)
	if not Profile.Released then
		Releaseprofile(Player)
	end
	Clearsections(Player)
	if Profile.Locked and not Profile.Unlocked then
		Unlock(Profile)
	end
end

local function Startautosave(Player: Player, Profile: Profile)
	task.spawn(function()
		task.wait(math.random() * Autosaveinterval)
		while not Profile.Released and not Profile.Lost do
			if not Blockedbyplayer[Player] then
				Saveprofile(Player, Profile, Saveattempts)
			end
			task.wait(Autosaveinterval)
		end
	end)
end

local function Loadprofile(Player: Player)
	if Profiles[Player] or not Player.Parent then
		return
	end
	local Profile: Profile = {
		Id = HttpService:GenerateGUID(false),
		Userid = Player.UserId,
		Name = Player.Name,
		Locked = false,
		Unlocked = false,
		Loaded = false,
		Errored = false,
		Lost = false,
		Released = false,
		New = false,
		Seq = 0,
		Unsafe = {},
		Warned = {},
		Purchases = {},
		Savedpurchases = {},
		Granting = {},
	}
	Profiles[Player] = Profile
	local Started = os.clock()
	while Releasingbyuserid[Profile.Userid] and not Profile.Released and os.clock() - Started < Lockwait do
		task.wait()
	end
	Log("loading " .. Profile.Name .. " (key " .. Profile.Userid .. ")")
	Started = os.clock()
	local Failures = 0
	local Saved = nil
	local Failure = "the player left"
	while not Profile.Released and Player.Parent do
		local Success, Status, Result = Acquire(Profile, os.clock() - Started >= Lockwait)
		if Success and Status == "acquired" then
			Profile.Locked = true
			Saved = Result
			break
		elseif Success and Status == "corrupt" then
			Failure = "the stored value is not a table"
			break
		elseif Success then
			Log(Profile.Name .. "'s data is open in another server, waiting")
			task.wait(Lockpoll)
		else
			Failures += 1
			if Failures >= Loadattempts or not Datastorerequest.Isretryable(Result) then
				Failure = tostring(Result)
				break
			end
			task.wait(Datastorerequest.Backoff(Failures))
		end
	end
	if Profile.Released or not Player.Parent then
		Abortload(Player, Profile)
		return
	end
	if not Saved then
		warn("DataService: could not load data for " .. Profile.Name .. ": " .. Failure)
		if Isstudio then
			Profile.Errored = true
			Profile.Loaded = true
			Loadedbyplayer[Player] = true
			warn("DataService: this Studio session continues WITHOUT saving " .. Profile.Name .. "'s data")
		else
			Kick(Player, "Your data could not be loaded. Please rejoin in a moment.")
		end
		return
	end
	Profile.New = not Hassections(Saved)
	for _, Purchaseid in ipairs(Mergepurchases(Saved._Purchases, nil)) do
		table.insert(Profile.Purchases, Purchaseid)
		Profile.Savedpurchases[Purchaseid] = true
	end
	Log("read for " .. Profile.Name .. ": " .. Describe(Saved))
	Applysaved(Player, Profile, Saved)
	if Profile.Released or not Player.Parent then
		Abortload(Player, Profile)
		return
	end
	Profile.Loaded = true
	Loadedbyplayer[Player] = true
	Log(Profile.Name .. " is loaded, saving enabled")
	Startautosave(Player, Profile)
end

function Dataservice:Register(Name: string, Handlers: Section)
	assert(table.find(Sectionorder, Name), "DataService: unknown section " .. Name)
	Sections[Name] = Handlers
	Log("section registered: " .. Name)
end

function Dataservice:IsLoaded(Player: Player): boolean
	return Loadedbyplayer[Player] == true
end

function Dataservice:WaitForLoad(Player: Player)
	while Player.Parent and not Loadedbyplayer[Player] do
		task.wait()
	end
end

function Dataservice:IsNewProfile(Player: Player): boolean
	local Profile = Profiles[Player]
	return Profile ~= nil and Profile.Loaded and not Profile.Errored and Profile.New
end

function Dataservice:IsReleasing(): boolean
	return Activereleases > 0 or next(Profiles) ~= nil
end

function Dataservice:IsLost(Player: Player): boolean
	return Lostbyplayer[Player] == true
end

function Dataservice:IsSectionSafe(Player: Player, Name: string): boolean
	local Profile = Profiles[Player]
	return Profile ~= nil and not Profile.Unsafe[Name]
end

function Dataservice:CanSave(Player: Player): boolean
	return Refusal(Player, Profiles[Player]) == nil
end

function Dataservice:Save(Player: Player): (boolean, string)
	local Profile = Profiles[Player]
	if not Profile then
		return false, "profile not loaded yet"
	end
	return Saveprofile(Player, Profile, Saveattempts)
end

function Dataservice:ProcessPurchase(Player: Player, Purchaseid: string, Grant: () -> boolean): Enum.ProductPurchaseDecision
	self:WaitForLoad(Player)
	local Profile = Profiles[Player]
	if not Profile or Refusal(Player, Profile) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	while Profile.Granting[Purchaseid] do
		task.wait()
	end
	if not table.find(Profile.Purchases, Purchaseid) then
		if Refusal(Player, Profile) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		Profile.Granting[Purchaseid] = true
		local Success, Granted = pcall(Grant)
		Profile.Granting[Purchaseid] = nil
		if not Success then
			warn("DataService: purchase " .. Purchaseid .. " of " .. Profile.Name .. " failed: " .. tostring(Granted))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not Granted then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(Profile.Purchases, Purchaseid)
		while #Profile.Purchases > Maximumpurchases do
			table.remove(Profile.Purchases, 1)
		end
	end
	if not Profile.Savedpurchases[Purchaseid] then
		Saveprofile(Player, Profile, Saveattempts)
	end
	return if Profile.Savedpurchases[Purchaseid]
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

function Dataservice:Wipe(Userid: number): (boolean, string)
	local Player = Players:GetPlayerByUserId(Userid)
	if Player then
		Blockedbyplayer[Player] = true
	end
	local Success, Result = Datastorerequest.Run(Saveattempts, function()
		return Store:RemoveAsync(tostring(Userid))
	end)
	if not Success then
		warn("DataService: could not erase data for " .. Userid .. ": " .. tostring(Result))
		return false, tostring(Result)
	end
	return true, if Result == nil then "no save found" else "save erased"
end

function Dataservice:ListVersions(Userid: number, Count: number): (boolean, any)
	return Datastorerequest.Run(Saveattempts, function()
		local Pages = Store:ListVersionsAsync(tostring(Userid), Enum.SortDirection.Descending, 0, 0, Count)
		local Versions = {}
		for _, Info in ipairs(Pages:GetCurrentPage()) do
			table.insert(Versions, { Version = Info.Version, Time = Info.CreatedTime, Deleted = Info.IsDeleted })
		end
		return Versions
	end)
end

function Dataservice:GetSectionOrder(): { string }
	return table.clone(Sectionorder)
end

function Dataservice:Peek(Player: Player): (boolean, any, any)
	local Profile = Profiles[Player]
	if not Profile then
		return false, "profile not loaded yet", nil
	end
	local Reason = Refusal(Player, Profile)
	if Reason and not Profile.Errored then
		return false, Reason, nil
	end
	local Snapshot = {}
	local Problems = {}
	for _, Name in ipairs(Sectionorder) do
		local Handlers = Sections[Name]
		if not Handlers then
			Problems[Name] = "is not registered"
		elseif Profile.Unsafe[Name] then
			Problems[Name] = "failed to load"
		else
			local Success, Value = pcall(Handlers.Save, Player)
			if not Success then
				Problems[Name] = "failed to read: " .. tostring(Value)
			elseif Value ~= nil then
				local Copy, Problem = Copyvalue(Value, 1)
				if Problem then
					Problems[Name] = "holds " .. Problem
				else
					Snapshot[Name] = Copy
				end
			end
		end
	end
	return true, Snapshot, {
		Seq = Profile.Seq,
		New = Profile.New,
		Purchases = table.clone(Profile.Purchases),
		Problems = Problems,
		Unsaved = Reason,
	}
end

function Dataservice:Read(Userid: number): (boolean, any, any)
	local Success, Value, Keyinfo = Datastorerequest.Run(Saveattempts, function()
		return Store:GetAsync(tostring(Userid), Readoptions)
	end)
	if not Success then
		return false, tostring(Value), nil
	end
	if Value == nil then
		return true, nil, nil
	end
	local Lock = if type(Value) == "table" then Value._Session else nil
	local Session = nil
	if type(Lock) == "table" then
		local Time = tonumber(Lock.Time) or 0
		local Job = tostring(Lock.Job)
		local Studio = Lock.Studio == true
		Session = {
			Job = Job,
			Time = Time,
			Seq = tonumber(Lock.Seq) or 0,
			Studio = Studio,
			Thisserver = not Studio and Job == game.JobId,
			Active = os.time() - Time < Lockexpiry,
		}
	end
	return true, Value, {
		Updated = Keyinfo.UpdatedTime,
		Created = Keyinfo.CreatedTime,
		Version = Keyinfo.Version,
		Session = Session,
	}
end

function Dataservice:Restore(Userid: number, Version: string): (boolean, string, any)
	local Read, Value = Datastorerequest.Run(Saveattempts, function()
		return Store:GetVersionAsync(tostring(Userid), Version)
	end)
	if not Read then
		return false, tostring(Value)
	end
	if type(Value) ~= "table" then
		return false, "this version holds no data"
	end
	local Player = Players:GetPlayerByUserId(Userid)
	if Player then
		Blockedbyplayer[Player] = true
	end
	Value._Session = nil
	local Written, Error = Datastorerequest.Run(Saveattempts, function()
		Store:UpdateAsync(tostring(Userid), function(Current)
			Value._Purchases = Mergepurchases(Value._Purchases, if type(Current) == "table" then Current._Purchases else nil)
			return Value, { Userid }
		end)
	end)
	if not Written then
		if Player then
			Blockedbyplayer[Player] = nil
		end
		warn("DataService: could not restore data for " .. Userid .. ": " .. tostring(Error))
		return false, tostring(Error)
	end
	if Player then
		Kick(Player, "Your data was restored. Please rejoin.")
	end
	return true, "restored", Value
end

function Dataservice:Init()
	Players.PlayerRemoving:Connect(Releaseprofile)
end

function Dataservice:Start()
	for _, Name in ipairs(Sectionorder) do
		if not Sections[Name] then
			warn("DataService: section " .. Name .. " is not registered, its stored copy is kept as is")
		end
	end

	task.spawn(function()
		local Success, Error = pcall(function()
			return Store:GetAsync("Probe")
		end)
		if Success then
			Log("DataStore ready")
		else
			warn("DataService: DATASTORE UNAVAILABLE - " .. tostring(Error))
			warn("DataService: tick Game Settings > Security > Enable Studio Access to API Services")
		end
	end)

	Players.PlayerAdded:Connect(function(Player)
		task.spawn(Loadprofile, Player)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(Loadprofile, Player)
	end

	game:BindToClose(function()
		Log("server shutting down")
		for _, Player in ipairs(Players:GetPlayers()) do
			task.spawn(Releaseprofile, Player)
		end
		local Deadline = os.clock() + Shutdowndeadline
		while Activereleases > 0 and os.clock() < Deadline do
			task.wait()
		end
		Log("server shutdown: saves complete")
	end)
end

return Dataservice
