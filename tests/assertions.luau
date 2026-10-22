-- Assertions for the pure game logic (Config, Board, EffectService).
-- tests/run.sh inlines those modules as globals before this file runs, so no Studio needed.

local failures = 0
local checks = 0

local function check(name, condition, detail)
	checks += 1
	if condition then
		print("ok   " .. name)
	else
		failures += 1
		print("FAIL " .. name .. (detail ~= nil and ("  -> " .. tostring(detail)) or ""))
	end
end

-- ---------- Config ----------
check("layout has 32 tiles", Config.TileCount() == 32, Config.TileCount())

local validKinds = {
	start = true,
	plain = true,
	coin = true,
	trap = true,
	star = true,
	boost = true,
	warp = true,
}

local kindsOk = true
local starCount = 0
for i = 1, Config.TileCount() do
	local kind = Config.TileAt(i)
	if not validKinds[kind] then
		kindsOk = false
	end
	if kind == "star" then
		starCount += 1
	end
end

check("every tile kind is known", kindsOk)
check("board holds 3 stars", starCount == 3, starCount)
check("tile 1 is start", Config.TileAt(1) == "start", Config.TileAt(1))
check("TileAt wraps forward", Config.TileAt(33) == Config.TileAt(1))
check("TileAt wraps backward", Config.TileAt(0) == Config.TileAt(32))

-- ---------- Board geometry ----------
check("Count matches layout", Board.Count() == Config.TileCount())
check("Wrap(0) is the last tile", Board.Wrap(0) == 32, Board.Wrap(0))
check("Wrap(33) is tile 1", Board.Wrap(33) == 1, Board.Wrap(33))
check("Wrap(-1) is tile 31", Board.Wrap(-1) == 31, Board.Wrap(-1))

local positions = {}
local seen = {}
local allUnique = true
for i = 1, Board.Count() do
	local p = Board.PositionOf(i)
	positions[i] = p
	local key = string.format("%.3f,%.3f", p.X, p.Z)
	if seen[key] then
		allUnique = false
	end
	seen[key] = i
end
check("all 32 tile positions are unique", allUnique)

-- The whole point of sharing corners: every step (including 32 -> 1) is exactly one tile apart.
-- A gap here means the ring visually jumps and characters cut the corner.
local spacing = Config.Board.Spacing
local uniform = true
local worst = 0
for i = 1, Board.Count() do
	local a = positions[i]
	local b = positions[Board.Wrap(i + 1)]
	local dx, dz = a.X - b.X, a.Z - b.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	local delta = math.abs(dist - spacing)
	if delta > 1e-6 then
		uniform = false
		if delta > worst then
			worst = delta
		end
	end
end
check("every step is one tile apart (ring closes)", uniform, "worst delta " .. tostring(worst))

local sumX, sumZ = 0, 0
for i = 1, Board.Count() do
	sumX += positions[i].X
	sumZ += positions[i].Z
end
check("ring is centred on the origin", math.abs(sumX) < 1e-6 and math.abs(sumZ) < 1e-6, sumX .. "," .. sumZ)

-- ---------- Tile rules ----------
local firstOf = {}
for i = 1, Config.TileCount() do
	local kind = Config.TileAt(i)
	if firstOf[kind] == nil then
		firstOf[kind] = i
	end
end

local function record(coins, stars)
	return {
		coins = coins or Config.Rules.StartCoins,
		stars = stars or 0,
		extraSteps = 0,
		index = 1,
	}
end

local r = record()
Effects.apply(r, firstOf.coin)
check("coin tile adds coins", r.coins == Config.Rules.StartCoins + Config.Rules.CoinGain, r.coins)

r = record()
Effects.apply(r, firstOf.trap)
check("trap tile subtracts coins", r.coins == Config.Rules.StartCoins - Config.Rules.TrapLoss, r.coins)

r = record(3)
Effects.apply(r, firstOf.trap)
check("trap never pushes coins below zero", r.coins == 0, r.coins)

r = record(Config.Rules.StarCost)
Effects.apply(r, firstOf.star)
check("star tile buys a star", r.stars == 1 and r.coins == 0, r.coins .. " coins / " .. r.stars .. " stars")

r = record(Config.Rules.StarCost - 1)
Effects.apply(r, firstOf.star)
check(
	"star tile refuses without enough coins",
	r.stars == 0 and r.coins == Config.Rules.StarCost - 1,
	r.coins .. " coins / " .. r.stars .. " stars"
)

r = record()
Effects.apply(r, firstOf.boost)
check("boost banks extra steps", r.extraSteps == Config.Rules.BoostSteps, r.extraSteps)

r = record()
local warpResult = Effects.apply(r, firstOf.warp)
check("warp reports its step count", warpResult.steps == Config.Rules.WarpSteps, warpResult.steps)

r = record()
local plainResult = Effects.apply(r, firstOf.plain)
check(
	"plain tile changes nothing",
	r.coins == Config.Rules.StartCoins and plainResult.text == nil,
	plainResult.text
)

print("")
print(string.format("%d checks, %d failed", checks, failures))
if failures > 0 then
	error("logic test failed", 0)
end
