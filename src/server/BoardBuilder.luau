-- Spawns the visible board from Config + Board. Runs once on the server; parts replicate.
-- Anchored parts only, so the client never has to trust anything here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("RollRush")
local Config = require(Shared:WaitForChild("Config"))
local Board = require(Shared:WaitForChild("Board"))

local BoardBuilder = {}

local COLORS = {
	start = Color3.fromRGB(80, 200, 120),
	plain = Color3.fromRGB(150, 150, 162),
	coin = Color3.fromRGB(238, 198, 70),
	trap = Color3.fromRGB(206, 78, 78),
	star = Color3.fromRGB(150, 110, 240),
	boost = Color3.fromRGB(88, 176, 238),
	warp = Color3.fromRGB(238, 130, 60),
}

local function makeLabel(part, text)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(300, 300)
	gui.LightInfluence = 0
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(25, 25, 32)
	label.Text = text
	label.Parent = gui
end

function BoardBuilder.build()
	local previous = workspace:FindFirstChild("RollRushBoard")
	if previous then
		previous:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "RollRushBoard"
	folder.Parent = workspace

	local size = Config.Board.TileSize
	local height = Config.Board.TileHeight

	for i = 1, Board.Count() do
		local kind = Config.TileAt(i)

		local tile = Instance.new("Part")
		tile.Name = string.format("Tile_%02d_%s", i, kind)
		tile.Anchored = true
		tile.CanCollide = true
		tile.Size = Vector3.new(size, height, size)
		tile.Position = Board.PositionOf(i) + Vector3.new(0, height / 2, 0)
		tile.Color = COLORS[kind] or COLORS.plain
		tile.Material = Enum.Material.SmoothPlastic
		tile.TopSurface = Enum.SurfaceType.Smooth
		tile.BottomSurface = Enum.SurfaceType.Smooth
		tile.Parent = folder

		makeLabel(tile, string.upper(kind))
	end

	-- Ground pad so the ring does not float over the void.
	local pad = Instance.new("Part")
	pad.Name = "CenterPad"
	pad.Anchored = true
	pad.Size = Vector3.new(28, 1, 28)
	pad.Position = Vector3.new(0, -0.5, 0)
	pad.Color = Color3.fromRGB(58, 58, 72)
	pad.Material = Enum.Material.Slate
	pad.Parent = folder

	return folder
end

return BoardBuilder
