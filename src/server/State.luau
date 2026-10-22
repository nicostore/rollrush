-- Authoritative game state. Every mutable value lives in these tables and nothing else writes them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("RollRush"):WaitForChild("Config"))

local State = {}

State.phase = "lobby" -- lobby | playing | over
State.round = 1
State.turnOrder = {} -- array of userIds, stable join order
State.turnIndex = 0 -- index into turnOrder; 0 means "not started"
State.deadline = 0 -- os.clock() value after which the server force-rolls (0 = disarmed)
State.players = {} -- [userId] = record

local function blank(userId, displayName)
	return {
		userId = userId,
		name = displayName,
		index = 1, -- tile index, 1-based
		coins = Config.Rules.StartCoins,
		stars = 0,
		extraSteps = 0, -- consumed by the next roll (boost tile)
	}
end

function State.add(userId, displayName)
	local existing = State.players[userId]
	if existing then
		existing.name = displayName
		return existing
	end

	local record = blank(userId, displayName)
	State.players[userId] = record
	table.insert(State.turnOrder, userId)
	return record
end

function State.remove(userId)
	if not State.players[userId] then
		return
	end
	State.players[userId] = nil

	for i, id in ipairs(State.turnOrder) do
		if id == userId then
			table.remove(State.turnOrder, i)
			if State.turnIndex >= i then
				State.turnIndex = math.max(0, State.turnIndex - 1)
			end
			break
		end
	end
end

function State.count()
	return #State.turnOrder
end

function State.current()
	local id = State.turnOrder[State.turnIndex]
	if id == nil then
		return nil
	end
	return State.players[id]
end

function State.byUserId(userId)
	return State.players[userId]
end

-- Flat copy for the wire. Never hand out the live records.
function State.snapshot()
	local list = {}
	for _, id in ipairs(State.turnOrder) do
		local record = State.players[id]
		if record then
			table.insert(list, {
				userId = record.userId,
				name = record.name,
				index = record.index,
				coins = record.coins,
				stars = record.stars,
			})
		end
	end

	return {
		phase = State.phase,
		round = State.round,
		currentUserId = State.turnOrder[State.turnIndex],
		players = list,
	}
end

function State.reset()
	State.phase = "lobby"
	State.round = 1
	State.turnIndex = 0
	State.deadline = 0
	for _, id in ipairs(State.turnOrder) do
		local record = State.players[id]
		if record then
			record.index = 1
			record.coins = Config.Rules.StartCoins
			record.stars = 0
			record.extraSteps = 0
		end
	end
end

return State
