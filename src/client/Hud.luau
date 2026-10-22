-- HUD only. No game rules live here: this file renders the last snapshot it was given and
-- reports the roll button press upward.

local Players = game:GetService("Players")

local Hud = {}
Hud.__index = Hud

local ACCENT = Color3.fromRGB(150, 110, 240)
local BG = Color3.fromRGB(22, 22, 30)
local TEXT = Color3.fromRGB(236, 236, 244)
local MUTED = Color3.fromRGB(150, 152, 168)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
	return c
end

local function label(parent, size, position, text, textSize)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = textSize
	l.TextColor3 = TEXT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

function Hud.new()
	local self = setmetatable({}, Hud)
	self.onRoll = nil
	self.rows = {}

	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "RollRushHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	self.gui = gui

	-- Status: whose turn / which round.
	local statusBar = Instance.new("Frame")
	statusBar.Name = "Status"
	statusBar.AnchorPoint = Vector2.new(0.5, 0)
	statusBar.Position = UDim2.new(0.5, 0, 0, 14)
	statusBar.Size = UDim2.new(0, 420, 0, 44)
	statusBar.BackgroundColor3 = BG
	statusBar.BackgroundTransparency = 0.15
	statusBar.Parent = gui
	corner(statusBar, 12)

	self.statusLabel = label(statusBar, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), "RollRush", 18)
	self.statusLabel.TextXAlignment = Enum.TextXAlignment.Center

	-- Roster.
	local roster = Instance.new("Frame")
	roster.Name = "Roster"
	roster.AnchorPoint = Vector2.new(1, 0)
	roster.Position = UDim2.new(1, -14, 0, 14)
	roster.Size = UDim2.new(0, 240, 0, 56)
	roster.BackgroundColor3 = BG
	roster.BackgroundTransparency = 0.15
	roster.Parent = gui
	corner(roster, 12)

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.Parent = roster
	self.roster = roster
	self.rosterLayout = list

	-- Roll button.
	local button = Instance.new("TextButton")
	button.Name = "Roll"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -24)
	button.Size = UDim2.new(0, 220, 0, 58)
	button.BackgroundColor3 = ACCENT
	button.Text = "ROLL"
	button.Font = Enum.Font.GothamBold
	button.TextSize = 24
	button.TextColor3 = Color3.fromRGB(20, 18, 30)
	button.AutoButtonColor = true
	button.Parent = gui
	corner(button, 14)
	self.button = button

	button.Activated:Connect(function()
		if self.onRoll then
			self.onRoll()
		end
	end)

	-- Toast (last tile effect / notices).
	self.toastLabel = label(gui, UDim2.new(0, 460, 0, 30), UDim2.new(0.5, -230, 1, -100), "", 18)
	self.toastLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.toastLabel.TextTransparency = 1

	-- Big banner for game over.
	self.banner = label(gui, UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0.42, 0), "", 34)
	self.banner.TextXAlignment = Enum.TextXAlignment.Center
	self.banner.Font = Enum.Font.GothamBold
	self.banner.TextTransparency = 1

	self.diceTimer = 0
	self:setRollEnabled(false)
	return self
end

function Hud:setRollEnabled(enabled)
	self.button.Visible = enabled
end

function Hud:setStatus(snapshot)
	local current = nil
	for _, p in ipairs(snapshot.players) do
		if p.userId == snapshot.currentUserId then
			current = p
		end
	end

	if snapshot.phase == "playing" and current then
		self.statusLabel.Text = string.format(
			"Round %d  -  %s's turn",
			snapshot.round,
			current.name
		)
	else
		self.statusLabel.Text = string.format(
			"%s  -  waiting (%d/%d players)",
			"RollRush",
			#snapshot.players,
			2
		)
	end
end

function Hud:setPlayers(players, currentUserId)
	for _, row in pairs(self.rows) do
		row:Destroy()
	end
	self.rows = {}

	for index, p in ipairs(players) do
		local row = Instance.new("Frame")
		row.Name = "Row_" .. p.userId
		row.Size = UDim2.new(1, -16, 0, 34)
		row.LayoutOrder = index
		row.BackgroundColor3 = (p.userId == currentUserId) and ACCENT or Color3.fromRGB(38, 38, 50)
		row.BackgroundTransparency = (p.userId == currentUserId) and 0.55 or 0.35
		row.Parent = self.roster
		corner(row, 8)

		local name = label(row, UDim2.new(0.55, 0, 1, 0), UDim2.new(0, 10, 0, 0), p.name, 16)
		name.Font = Enum.Font.GothamBold

		local stats = label(
			row,
			UDim2.new(0.45, -12, 1, 0),
			UDim2.new(0.55, 0, 0, 0),
			string.format("%d c   %d *", p.coins, p.stars),
			16
		)
		stats.TextXAlignment = Enum.TextXAlignment.Right
		stats.TextColor3 = MUTED

		table.insert(self.rows, row)
	end

	local count = math.max(1, #players)
	self.roster.Size = UDim2.new(0, 240, 0, 14 + count * 40)
end

function Hud:showRoll(userId, base, total)
	local bonus = (total or base) - base
	if bonus > 0 then
		self:toast(string.format("rolled %d (+%d bonus)", base, bonus))
	else
		self:toast(string.format("rolled %d", base))
	end
end

local toastToken = 0
function Hud:toast(text)
	toastToken += 1
	local mine = toastToken
	self.toastLabel.Text = text
	self.toastLabel.TextTransparency = 0

	task.spawn(function()
		task.wait(2.5)
		if toastToken == mine then
			-- Fade out, but only if no newer toast replaced this one.
			for i = 1, 10 do
				if toastToken ~= mine then
					return
				end
				self.toastLabel.TextTransparency = i / 10
				task.wait(0.04)
			end
		end
	end)
end

function Hud:banner(text)
	self.banner.Text = text
	self.banner.TextTransparency = 0
	task.delay(4, function()
		self.banner.TextTransparency = 1
	end)
end

return Hud
