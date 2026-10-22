-- Server entry point: build the board, create the remotes, then own the game loop.
-- `script` here is the RollRush Script in ServerScriptService whose children are the modules.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("RollRush")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local State = require(script.State)
local BoardBuilder = require(script.BoardBuilder)
local Turn = require(script.TurnService)

Remotes.init()
BoardBuilder.build()

-- Server -> client
Remotes.get("GetState").OnServerInvoke = function()
	return State.snapshot()
end

-- Client -> server. Everything is re-validated: the client's word is only a hint.
Remotes.get("RequestRoll").OnServerInvoke = function(player)
	local record = State.byUserId(player.UserId)
	if not record then
		return { ok = false, reason = "you are not in this game" }
	end
	if State.phase ~= "playing" then
		return { ok = false, reason = "game is not running" }
	end

	local current = State.current()
	if not current or current.userId ~= player.UserId then
		return { ok = false, reason = "not your turn" }
	end
	if Turn.isBusy() then
		return { ok = false, reason = "still resolving the last roll" }
	end
	if State.deadline > 0 and os.clock() > State.deadline then
		return { ok = false, reason = "turn already expired" }
	end

	State.deadline = 0
	Turn.resolve(record)
	return { ok = true }
end

local function onPlayerAdded(player)
	State.add(player.UserId, player.DisplayName)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(Vector3.new(0, Config.Board.SpawnHeight, 0))
		end
	end)

	if State.phase == "playing" then
		Remotes.get("Toast"):FireAllClients(player.DisplayName .. " joined mid-game")
	end

	task.defer(function()
		Remotes.get("StateSync"):FireAllClients(State.snapshot())
	end)

	-- Start as soon as the lobby has enough players (once).
	if State.phase == "lobby" and State.count() >= Config.Game.MinPlayers then
		task.wait(2)
		if State.phase == "lobby" and State.count() >= Config.Game.MinPlayers then
			Turn.startGame()
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	State.remove(player.UserId)
	task.defer(function()
		Remotes.get("StateSync"):FireAllClients(State.snapshot())
	end)
	if State.phase == "playing" and State.count() < Config.Game.MinPlayers then
		Turn.finish("Not enough players left. Back to the lobby.")
	end
end)

-- Turn deadline watchdog: a turn can never stall the game, even if the player walks away.
task.spawn(function()
	while true do
		RunService.Heartbeat:Wait()
		if State.phase == "playing" and State.deadline > 0 and os.clock() > State.deadline then
			local record = State.current()
			State.deadline = 0
			if record and not Turn.isBusy() then
				Remotes.get("Toast"):FireAllClients(record.name .. " ran out of time - auto-rolling")
				Turn.resolve(record)
			end
		end
	end
end)

Turn.prepareLobby()
