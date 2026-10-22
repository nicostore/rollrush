-- Client entry: mirror server broadcasts into the HUD. Deliberately logic-free.
-- `script` is the RollRush LocalScript in StarterPlayerScripts; Hud is its child module.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("RollRush")
local Remotes = require(Shared:WaitForChild("Remotes"))

local Hud = require(script.Hud)

local player = Players.LocalPlayer
local hud = Hud.new()

local requestRoll = Remotes.get("RequestRoll")
local stateSync = Remotes.get("StateSync")
local turnStarted = Remotes.get("TurnStarted")
local rollResolved = Remotes.get("RollResolved")
local toast = Remotes.get("Toast")
local gameOver = Remotes.get("GameOver")

local latest = {
	phase = "lobby",
	round = 1,
	currentUserId = nil,
	players = {},
}

local function refresh()
	local myTurn = latest.phase == "playing" and latest.currentUserId == player.UserId
	hud:setPlayers(latest.players or {}, latest.currentUserId)
	hud:setRollEnabled(myTurn)
	hud:setStatus(latest)
end

stateSync.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) == "table" then
		latest = snapshot
		refresh()
	end
end)

turnStarted.OnClientEvent:Connect(function(userId, round)
	latest.currentUserId = userId
	if round then
		latest.round = round
	end
	refresh()
end)

rollResolved.OnClientEvent:Connect(function(userId, base, total)
	hud:showRoll(userId, base, total)
end)

toast.OnClientEvent:Connect(function(text)
	hud:toast(tostring(text))
end)

gameOver.OnClientEvent:Connect(function(text)
	hud:banner(tostring(text))
end)

hud.onRoll = function()
	local ok, result = pcall(function()
		return requestRoll:InvokeServer()
	end)

	if not ok then
		hud:toast("roll failed: " .. tostring(result))
		return
	end

	if type(result) == "table" and not result.ok and result.reason then
		hud:toast(result.reason)
	end
end

-- Pull the current state once: covers joining after the first broadcast.
task.spawn(function()
	local ok, snapshot = pcall(function()
		return Remotes.get("GetState"):InvokeServer()
	end)
	if ok and type(snapshot) == "table" then
		latest = snapshot
		refresh()
	end
end)

refresh()
