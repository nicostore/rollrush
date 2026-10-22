-- Remote plumbing. The server creates, clients wait. Names live here only, so a typo cannot
-- silently fork into two different remotes (which is the usual cause of "nothing happens").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "RollRushRemotes"

local EVENTS = {
	"TurnStarted", -- (userId, round)
	"RollResolved", -- (userId, base, total)
	"StateSync", -- (snapshot)
	"Toast", -- (text)
	"GameOver", -- (text)
}

local FUNCTIONS = {
	"GetState", -- () -> snapshot
	"RequestRoll", -- () -> { ok, reason? }
}

local function folder()
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
end

function Remotes.get(name)
	local f = folder()
	if not f then
		error("RollRush: remote folder never appeared (is the server script running?)", 2)
	end
	return f:WaitForChild(name, 30)
end

-- Server-only. Safe to call twice.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server-only")

	local f = folder()

	for _, name in ipairs(EVENTS) do
		if not f:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = f
		end
	end

	for _, name in ipairs(FUNCTIONS) do
		if not f:FindFirstChild(name) then
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = f
		end
	end
end

return Remotes
