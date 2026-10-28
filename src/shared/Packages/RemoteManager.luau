local Runservice = game:GetService("RunService")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Remotemanager = {}
Remotemanager.__index = Remotemanager

local Isserver: boolean = Runservice:IsServer()

local Folder: Folder
local Remotes: { [string]: RemoteEvent | RemoteFunction } = {}

local function Getorcreatefolder(): Folder
	if Isserver then
		local Existing = Replicatedstorage:FindFirstChild("Remotes")
		if Existing then
			return Existing :: Folder
		end
		local Folder = Instance.new("Folder")
		Folder.Name = "Remotes"
		Folder.Parent = Replicatedstorage
		return Folder
	else
		return Replicatedstorage:WaitForChild("Remotes") :: Folder
	end
end

local function Createremote(Folder: Folder, Servicename: string, Remotename: string, Remotetype: string)
	local Fullname = Servicename .. "_" .. Remotename
	if Remotetype == "Function" then
		local Rf = Instance.new("RemoteFunction")
		Rf.Name = Fullname
		Rf.Parent = Folder
		Remotes[Fullname] = Rf
	elseif Remotetype == "Event" then
		local Re = Instance.new("RemoteEvent")
		Re.Name = Fullname
		Re.Parent = Folder
		Remotes[Fullname] = Re
	else
		warn("[RemoteManager] unknown type '" .. Remotetype .. "' for " .. Fullname)
	end
end

local function Fetchremote(Folder: Folder, Fullname: string): RemoteEvent | RemoteFunction
	local Remote = Folder:WaitForChild(Fullname, 10)
	assert(Remote, "[RemoteManager] Remote not found: " .. Fullname)
	Remotes[Fullname] = Remote :: RemoteEvent | RemoteFunction
	return Remote :: RemoteEvent | RemoteFunction
end

function Remotemanager:RegisterServicesRemotes(Services: { any })
	Folder = Getorcreatefolder()
	for _, Service in pairs(Services) do
		if Service.Remotes then
			for Remotename, Remotetype in pairs(Service.Remotes) do
				Createremote(Folder, Service.Name, Remotename, Remotetype)
			end
		end
	end
end

function Remotemanager:OnServerInvoke(Servicename: string, Remotename: string, Handler: (Player: Player, ...any) -> any)
	assert(Isserver, "[RemoteManager] OnServerInvoke is server only")
	local Fullname = Servicename .. "_" .. Remotename
	local Remote = Remotes[Fullname]
	assert(Remote, "[RemoteManager] Remote not found: " .. Fullname)
	assert(Remote:IsA("RemoteFunction"), "[RemoteManager] " .. Fullname .. " n'est pas une RemoteFunction");
	(Remote :: RemoteFunction).OnServerInvoke = Handler
end

function Remotemanager:OnServerEvent(Servicename: string, Remotename: string, Handler: (Player: Player, ...any) -> ())
	assert(Isserver, "[RemoteManager] OnServerEvent is server only")
	local Fullname = Servicename .. "_" .. Remotename
	local Remote = Remotes[Fullname]
	assert(Remote, "[RemoteManager] Remote not found: " .. Fullname)
	assert(Remote:IsA("RemoteEvent"), "[RemoteManager] " .. Fullname .. " n'est pas un RemoteEvent");
	(Remote :: RemoteEvent).OnServerEvent:Connect(Handler)
end

function Remotemanager:FireClient(Servicename: string, Remotename: string, Player: Player, ...: any)
	assert(Isserver, "[RemoteManager] FireClient is server only")
	local Fullname = Servicename .. "_" .. Remotename
	local Remote = Remotes[Fullname]
	assert(Remote and Remote:IsA("RemoteEvent"), "[RemoteManager] RemoteEvent not found: " .. Fullname);
	(Remote :: RemoteEvent):FireClient(Player, ...)
end

function Remotemanager:FireAllClients(Servicename: string, Remotename: string, ...: any)
	assert(Isserver, "[RemoteManager] FireAllClients is server only")
	local Fullname = Servicename .. "_" .. Remotename
	local Remote = Remotes[Fullname]
	assert(Remote and Remote:IsA("RemoteEvent"), "[RemoteManager] RemoteEvent not found: " .. Fullname);
	(Remote :: RemoteEvent):FireAllClients(...)
end

function Remotemanager:InvokeServer(Servicename: string, Remotename: string, ...: any): any
	assert(not Isserver, "[RemoteManager] InvokeServer is client only")
	Folder = Folder or Getorcreatefolder()
	local Fullname = Servicename .. "_" .. Remotename
	local Remote = Remotes[Fullname] or Fetchremote(Folder, Fullname)
	assert(Remote:IsA("RemoteFunction"), "[RemoteManager] " .. Fullname .. " n'est pas une RemoteFunction")
	return (Remote :: RemoteFunction):InvokeServer(...)
end

function Remotemanager:FireServer(Servicename: string, Remotename: string, ...: any)
	assert(not Isserver, "[RemoteManager] FireServer is client only")
	Folder = Folder or Getorcreatefolder()
	local Fullname = Servicename .. "_" .. Remotename
	local Remote = Remotes[Fullname] or Fetchremote(Folder, Fullname)
	assert(Remote:IsA("RemoteEvent"), "[RemoteManager] " .. Fullname .. " n'est pas un RemoteEvent");
	(Remote :: RemoteEvent):FireServer(...)
end

function Remotemanager:OnClientEvent(Servicename: string, Remotename: string, Handler: (...any) -> ())
	assert(not Isserver, "[RemoteManager] OnClientEvent is client only")
	Folder = Folder or Getorcreatefolder()
	local Fullname = Servicename .. "_" .. Remotename
	local Remote = Remotes[Fullname] or Fetchremote(Folder, Fullname)
	assert(Remote:IsA("RemoteEvent"), "[RemoteManager] " .. Fullname .. " n'est pas un RemoteEvent");
	(Remote :: RemoteEvent).OnClientEvent:Connect(Handler)
end

return Remotemanager
