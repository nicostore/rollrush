-- Board geometry: tile index -> world position on the ring.
-- Pure math, no state, so the server can build tiles and clients can place effects identically.
--
-- The ring is a square of 4 sides x SIDE steps. Corners are SHARED between sides, so every
-- consecutive pair of tiles is exactly Spacing apart (including the 32 -> 1 wrap). If you change
-- the mapping, keep tests/logic_test.luau green: it asserts uniform step distance and uniqueness.

local Config = require(script.Parent.Config)

local Board = {}

local SIDE = Config.Board.SideTiles
local SPACING = Config.Board.Spacing
local GRID = SIDE -- grid coordinates span 0..GRID on both axes

function Board.Count()
	return Config.TileCount()
end

-- Wrap any index (including negative and > count) into 1..count.
function Board.Wrap(index)
	local n = Board.Count()
	return ((index - 1) % n) + 1
end

function Board.PositionOf(index)
	local i = Board.Wrap(index)
	local side = math.floor((i - 1) / SIDE)
	local t = (i - 1) % SIDE

	local gx, gz
	if side == 0 then
		gx, gz = t, 0 -- bottom, left to right
	elseif side == 1 then
		gx, gz = GRID, t -- right, bottom to top
	elseif side == 2 then
		gx, gz = GRID - t, GRID -- top, right to left
	else
		gx, gz = 0, GRID - t -- left, top to bottom
	end

	local half = GRID / 2
	return Vector3.new((gx - half) * SPACING, 0, (gz - half) * SPACING)
end

-- Small ring around a tile so up to 4 characters on the same tile do not stack.
function Board.PadOffset(slot)
	local angle = (slot - 1) * (math.pi / 2)
	local radius = 3.5
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

return Board
