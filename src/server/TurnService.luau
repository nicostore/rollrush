-- Turn engine. The server owns turn order, the deadline, the dice and the movement.
-- Clients receive broadcasts and animate what the server already decided.
--
-- Movement uses Humanoid:MoveTo per tile with a per-tile watchdog instead of waiting on
-- MoveToFinished: MoveToFinished can never fire when a character is blocked or the humanoid is
-- in a bad state, which would hang the whole game. The watchdog always returns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("RollRush")
local Config = require(Shared:WaitForChild("Config"))
local Board = require(Shared:WaitForChild("Board"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local State = require(script.Parent.State)
local Dice = require(script.Parent.DiceService)
local Effects = require(script.Parent.EffectService)

local Turn = {}

local busy = false
local STEP_TIMEOUT = 1.4 -- seconds allowed per tile before we give up and re-place the character

local function characterOf(player)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
end

local function placeAt(player, tileIndex, slot)
	local root, humanoid = characterOf(player)
	if not root then
		return
	end
	local target = Board.PositionOf(tileIndex) + (slot and Board.PadOffset(slot) or Vector3.zero)
	root.CFrame = CFrame.new(target + Vector3.new(0, Config.Board.SpawnHeight, 0))
	if humanoid then
		humanoid.WalkSpeed = 16
	end
end

-- Walk one tile, or give up after STEP_TIMEOUT and snap the character there.
local function stepTo(root, humanoid, target)
	humanoid:MoveTo(target + Vector3.new(0, Config.Board.SpawnHeight, 0))

	local started = os.clock()
	while os.clock() - started < STEP_TIMEOUT do
		local here = root.Position
		local dx, dz = here.X - target.X, here.Z - target.Z
		if (dx * dx + dz * dz) < 6.25 then -- within 2.5 studs
			return true
		end
		RunService.Heartbeat:Wait()
	end

	-- Snapped in, not walked in: keeps the board state and the visible position in sync.
	root.CFrame = CFrame.new(target + Vector3.new(0, Config.Board.SpawnHeight, 0))
	return false
end

local function broadcastState()
	Remotes.get("StateSync"):FireAllClients(State.snapshot())
end

local function slotOf(userId)
	for i, id in ipairs(State.turnOrder) do
		if id == userId then
			return i
		end
	end
	return 1
end

function Turn.isBusy()
	return busy
end

function Turn.stop()
	busy = false
	State.phase = "over"
	State.deadline = 0
end

function Turn.finish(text)
	local wasPlaying = State.phase == "playing"
	Turn.stop()
	broadcastState()
	Remotes.get("GameOver"):FireAllClients(text)

	if not wasPlaying then
		return
	end

	task.spawn(function()
		task.wait(Config.Game.RestartSeconds)
		Turn.prepareLobby()
	end)
end

function Turn.prepareLobby()
	busy = false
	State.reset()

	for _, id in ipairs(State.turnOrder) do
		local player = Players:GetPlayerByUserId(id)
		if player then
			placeAt(player, 1, slotOf(id))
		end
	end

	broadcastState()
	Remotes.get("Toast"):FireAllClients("Waiting for players...")
end

function Turn.startGame()
	if State.count() < Config.Game.MinPlayers then
		Remotes.get("Toast"):FireAllClients(
			string.format("Need %d players to start", Config.Game.MinPlayers)
		)
		return
	end

	busy = false
	State.phase = "playing"
	State.round = 1
	State.turnIndex = 1

	for _, id in ipairs(State.turnOrder) do
		local record = State.byUserId(id)
		if record then
			record.index = 1
			record.coins = Config.Rules.StartCoins
			record.stars = 0
			record.extraSteps = 0
		end
		local player = Players:GetPlayerByUserId(id)
		if player then
			placeAt(player, 1, slotOf(id))
		end
	end

	broadcastState()
	Turn.announceTurn()
end

function Turn.announceTurn()
	local record = State.current()
	if not record then
		return
	end

	State.deadline = os.clock() + Config.Game.TurnSeconds
	Remotes.get("TurnStarted"):FireAllClients(record.userId, State.round)
	broadcastState()
end

function Turn.advance()
	if State.phase ~= "playing" or busy then
		return
	end

	State.turnIndex += 1

	if State.turnIndex > State.count() then
		State.turnIndex = 1
		State.round += 1
		if State.round > Config.Game.MaxRounds then
			local best, bestName = -1, "nobody"
			for _, id in ipairs(State.turnOrder) do
				local record = State.byUserId(id)
				if record and record.stars > best then
					best, bestName = record.stars, record.name
				end
			end
			Turn.finish(string.format("Round limit reached. %s leads with %d stars.", bestName, best))
			return
		end
	end

	Turn.announceTurn()
end

-- Roll for the current player and walk it out. Server decides everything; the client only watches.
function Turn.resolve(record)
	if busy or State.phase ~= "playing" then
		return
	end
	busy = true
	State.deadline = 0

	local base, total = Dice.roll(record.extraSteps)
	record.extraSteps = 0

	Remotes.get("RollResolved"):FireAllClients(record.userId, base, total)

	local player = Players:GetPlayerByUserId(record.userId)
	local root, humanoid = nil, nil
	if player then
		root, humanoid = characterOf(player)
	end

	task.spawn(function()
		-- Step tile by tile so every tile is visibly landed on.
		for _ = 1, total do
			record.index = Board.Wrap(record.index + 1)
			if root and humanoid then
				stepTo(root, humanoid, Board.PositionOf(record.index))
			end
		end
		broadcastState()

		-- Tile effect.
		local effect = Effects.apply(record, record.index)
		broadcastState()

		if effect.text then
			Remotes.get("Toast"):FireAllClients(record.name .. ": " .. effect.text)
		end

		-- Warp tiles move immediately, before the turn is handed over.
		if effect.steps and effect.steps > 0 then
			for _ = 1, effect.steps do
				record.index = Board.Wrap(record.index + 1)
				if root and humanoid then
					stepTo(root, humanoid, Board.PositionOf(record.index))
				end
			end
			local landing = Effects.apply(record, record.index)
			if landing.text then
				Remotes.get("Toast"):FireAllClients(record.name .. ": " .. landing.text)
			end
			broadcastState()
		end

		if record.stars >= Config.Game.WinStars then
			Turn.finish(string.format("%s wins with %d stars!", record.name, record.stars))
			return
		end

		busy = false
		task.wait(0.4)
		Turn.advance()
	end)
end

return Turn
