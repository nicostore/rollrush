-- RollRush shared tuning + the fixed board layout.
--
-- Both sides read the SAME numbers: the server is the only authority on state, the client just
-- replays what it is told. Keeping the layout a literal table (not RNG) means the server can
-- build the board and any client can label a tile index without a round-trip.

local Config = {}

Config.Game = {
	Name = "RollRush",
	MinPlayers = 2,
	MaxPlayers = 4,
	TurnSeconds = 7,   -- hard deadline; the server force-rolls so a turn can never stall
	WinStars = 3,
	MaxRounds = 10,
	RestartSeconds = 8,
}

Config.Rules = {
	StartCoins = 20,
	CoinGain = 10,
	TrapLoss = 8,
	StarCost = 20,
	BoostSteps = 3,
	WarpSteps = 4,
}

Config.Dice = {
	Min = 1,
	Max = 6,
}

-- 32 tiles, fixed order. Indices are 1-based to match Luau arrays.
Config.Layout = {
	"start", -- 1
	"coin",
	"plain",
	"trap",
	"boost",
	"coin",
	"plain",
	"warp",
	"coin", -- 9
	"plain",
	"trap",
	"coin",
	"star",
	"plain",
	"coin",
	"trap",
	"boost", -- 17
	"plain",
	"coin",
	"plain",
	"coin",
	"trap",
	"star",
	"plain",
	"coin", -- 25
	"warp",
	"trap",
	"coin",
	"plain",
	"boost",
	"coin",
	"star", -- 32
}

Config.Board = {
	SideTiles = 8, -- steps per side; the four corners are shared between sides
	Spacing = 9,
	TileSize = 6,
	TileHeight = 0.6,
	SpawnHeight = 4,
}

function Config.TileCount()
	return #Config.Layout
end

function Config.TileAt(index)
	local n = #Config.Layout
	local wrapped = ((index - 1) % n) + 1
	return Config.Layout[wrapped]
end

return Config
