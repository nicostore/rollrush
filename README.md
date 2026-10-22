# RollRush

A 4-player board party game for Roblox: roll, walk the ring, grab coins and stars.

Original design — mechanics inspired by the board-party genre, all art/naming/code our own.

## What works today (MVP)

- Board of 32 tiles built at runtime on the server (no manual Studio work)
- 2-4 players, server-owned turn order
- Server-side dice (1-6), server-side movement — clients cannot cheat a roll or a step
- Tile effects: coin, trap, star (costs coins), boost (banked steps), warp (moves immediately)
- Turn deadline watchdog: a player who idles is auto-rolled, so a turn never stalls
- HUD: roster with coins/stars, current-turn highlight, ROLL button, toasts, game-over banner
- Win at 3 stars, or highest stars after 10 rounds; auto-return to lobby

## Not built yet (deliberately left out of the MVP)

- Minigames between rounds
- Item shop / inventory (buy traps, steals, dice upgrades)
- Persistence (DataStore): coins/stars reset every session
- Custom characters and cosmetics — for now the default avatar walks the board
- Private lobbies / matchmaking (everyone in the server shares one game)

## Layout

```
default.project.json      Rojo project: maps src/ into the DataModel
src/shared/               -> ReplicatedStorage.RollRush   (used by both sides)
  Config.luau               tuning + the fixed 32-tile layout
  Board.luau                tile index -> world position
  Remotes.luau              remote names + creation (server creates, client waits)
src/server/               -> ServerScriptService.RollRush (one Script + modules)
  init.server.luau          bootstrap: board, remotes, player lifecycle, deadline watchdog
  State.luau                the only mutable game state
  TurnService.luau          turn order, movement, win condition
  DiceService.luau          server RNG
  EffectService.luau        tile rules
  BoardBuilder.luau         spawns the visible board
src/client/               -> StarterPlayerScripts.RollRush (one LocalScript + module)
  init.client.luau          wires remotes to the HUD
  Hud.luau                  HUD rendering only
tests/                    headless logic test (no Studio needed)
```

**Design rule:** all rules live on the server. The client renders what it is told and asks
permission to roll. `State.luau` is the only file that mutates game state; the client files contain
no rules at all. Keep it that way when adding features — it is what makes the dice un-cheatable.

## Setup on your PC

1. Install [Rojo](https://rojo.space) (`rojo --version` should print 7.x) and the
   [Rojo Studio plugin](https://create.roblox.com/store/asset/13916111004).
2. Clone this repo.
3. From the repo root: `rojo serve`
4. Open a place in Roblox Studio → Rojo plugin → **Connect**.
5. Press Play. Two players (Studio → Test → Start Server with 2 players) to see a full game.

Prefer a single file? `rojo build -o RollRush.rbxlx` then open that in Studio.

## Tests

```bash
bash tests/run.sh
```

Inlines Config/Board/EffectService into a Luau CLI script and asserts 21 things: the ring is a
uniform square with no corner gaps, indices wrap correctly, and every tile rule is right (including
that a trap never pushes coins below zero and a star needs enough coins). Needs `luau` — set
`LUAU=/path/to/luau` if it is not on your PATH.

## Tuning

Everything numeric is in `src/shared/Config.luau`: board layout, tile rewards, star cost, dice
range, turn timer, win condition.

Adding a tile type: add it to `Config.Layout`, add a colour in `BoardBuilder.COLORS`, and add a
branch in `EffectService.apply`. That is the whole surface.
