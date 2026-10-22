-- Tile rules. Pure functions over a player record: no replication, no waiting, easy to reason
-- about and easy to unit-test later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("RollRush"):WaitForChild("Config"))

local Effects = {}

-- Applies the tile under `record.index` in place and returns what to tell the player.
--   { kind, text?, steps? }  steps = extra tiles to move immediately (warp)
function Effects.apply(record, tileIndex)
	local kind = Config.TileAt(tileIndex)
	local result = { kind = kind }

	if kind == "coin" then
		record.coins += Config.Rules.CoinGain
		result.text = string.format("+%d coins", Config.Rules.CoinGain)
	elseif kind == "trap" then
		local loss = math.min(Config.Rules.TrapLoss, record.coins)
		record.coins -= loss
		result.text = string.format("-%d coins", loss)
	elseif kind == "star" then
		if record.coins >= Config.Rules.StarCost then
			record.coins -= Config.Rules.StarCost
			record.stars += 1
			result.text = string.format("star bought for %d coins", Config.Rules.StarCost)
		else
			result.text = string.format("needs %d coins for the star", Config.Rules.StarCost)
		end
	elseif kind == "boost" then
		record.extraSteps += Config.Rules.BoostSteps
		result.text = string.format("+%d steps next turn", Config.Rules.BoostSteps)
	elseif kind == "warp" then
		result.steps = Config.Rules.WarpSteps
		result.text = string.format("warped %d tiles", Config.Rules.WarpSteps)
	elseif kind == "start" then
		result.text = "passed the start"
	end

	return result
end

return Effects
