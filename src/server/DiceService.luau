-- Server-only RNG. Clients never roll; they are only told the result.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("RollRush"):WaitForChild("Config"))

local Dice = {}

Dice.rng = Random.new(os.time())

-- Returns base roll and the total after this turn's banked bonus steps.
function Dice.roll(extraSteps)
	local base = Dice.rng:NextInteger(Config.Dice.Min, Config.Dice.Max)
	local bonus = math.max(0, extraSteps or 0)
	return base, base + bonus
end

return Dice
