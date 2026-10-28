# Tiny Flag — design

Date: 2026-10-27. Status: agreed in conversation, awaiting written-spec review.

## Intent

A browser game for two people: **two-team capture the flag, 2D, tag only, simultaneous turns**, on a farm map where terrain changes how far you move and what you can see. Built on the game-starter framework (server-authoritative, WebSocket, headless server, Kenney art).

Success for the first playable version:
- Two people in two browser tabs (or one person against a bot) play a whole match to a result.
- Hidden pieces are genuinely hidden: no client ever receives an enemy position its team couldn't see.
- `tools/verify.sh` passes with a `flag` smoke test that plays real turns over WebSockets.

**Decided in conversation:** capture the flag, 2 teams, 2D, tag only, turn based; simultaneous turns; 1v1, each person commands a whole squad; paths with movement points resolved in lockstep; tagged pieces go back to base; line-of-sight vision with crops that hide; turn orders + per-team results over the network (not synced nodes, not client-side resolution). **Proposed by Claude and accepted:** every number below (map size, costs, squad size, timer, win condition).

## 1. Board, terrain, squads, match

**Board.** One hand-built map, **64 × 36 tiles** of 16 px (it was 32 × 18; enlarged so there's room to manoeuvre and hide). Columns 0–31 are Red's half, 32–63 Blue's. At 1280 × 720 it fits the screen at zoom 1, between the HUD bars. The map is mirror-symmetric left↔right (with the base characters swapped), so neither side has an advantage; a unit test checks the symmetry. Each half has a **3 × 3 base**: the flag stands on the centre tile, and the other 8 tiles are home tiles for the pieces. Maps are text files, one character per tile, read by the server, the tests and the client alike.

| Char | Terrain | Move cost (half-points) | Blocks sight | Hides a piece on it |
|---|---|---|---|---|
| `.` | grass | 2 | no | no |
| `=` | dirt path | 1 | no | no |
| `w` | tall crops (wheat, corn) | 4 | no | yes, from viewers not adjacent |
| `t` | tree | 4 | yes | no |
| `h` | hedge / fence | impassable | yes | — |
| `B` | building (drawn as hay bales) | impassable | yes | — |
| `~` | pond / stream | impassable | no | — |
| `R` / `U` | Red / Blue base | 2 | no | no |

Map constraints the farm map must meet (tested): symmetric; both bases fully reachable from each other; at least two distinct routes between the bases (blocking any one hedge gap still leaves a path); crops and trees in the middle third so stealth matters where the teams meet.

**Squads.** Each side has **5 pieces**, each starting on its own home tile. Each piece has **8 half-points** of movement per turn (6 while carrying a flag) and sees **5 tiles** around it.

**Turns.** Simultaneous. Planning lasts up to **30 s**, ending early once both sides lock in. A piece with no order stays where it is.

**Flags and scoring.** A piece picks up the enemy flag by entering its tile. Stepping on your own flag does nothing. Carrying the enemy flag into your own base scores a **capture**. A carrier is always visible to both teams, crops or not. A tagged carrier drops the flag, which goes straight home. After a capture, both flags go home and every piece returns to its home tile.

**Winning.** First to **3 captures**. After **80 turns** (40 on the first, smaller map) the side with more captures wins; equal is a draw. The result shows for 10 s, then a new match starts with the same people on the same sides.

**Who plays.** The first two people to join get Red and Blue; anyone after that spectates. A side with no person (alone in the match, or after a disconnect) is played by a server bot. The next person to join takes over a bot's side at the start of the next turn. A reconnecting person gets a fresh peer id, so they can't be told apart from a newcomer: they simply take the bot-held side. A server restart starts a new match.

## 2. A turn

**Planning.** The client shows the team's current view: own pieces, enemies in sight, both flags, and faded "last seen" markers. These markers are drawn by the client from positions it was legitimately sent.
- Mouse: click a piece, click a tile. An A* path appears. Clicking another tile extends the path from its end (to route around things). Right-click or ✕ clears it.
- Paths can span several turns. The part within the piece's movement points is drawn green with its cost and is what gets sent; the rest is drawn pale with the number of turns the whole path takes. At the next turn start the rest becomes that piece's plan (sent at once, and editable like any other), but only if the piece ended the turn where its sent part ended: a tagged piece, a capture reset, or a piece that stopped when it picked up a flag drops it. This is client-side only; the server still gets one turn's path per piece.
- Touch: tap a piece, tap a tile, tap the same tile again to confirm.
- **Lock in** sends the orders. Until the timer ends you can still change them; every change is sent again.
- Movement is 4-way (no diagonals).
- Keyboard and controller order entry comes later (a GitHub issue, not this spec).

**Resolution** (server, deterministic). Time is 8 ticks, one per half-point. A piece enters the next tile on its path at the tick where its running path cost reaches that tile. Each tick runs in this order:
1. **Move.** Every piece due this tick enters its next tile, all at once.
2. **Meet.** Opposing pieces meet if they are on the same tile, or swapped tiles this tick. Of each meeting, every piece that is on enemy ground after the move is **tagged**. One tile can't be on both halves, so a same-tile meeting tags exactly one piece. A swap across the halfway line puts both on enemy ground, so both are tagged. A tagged piece stops for the rest of the turn, drops any flag (it goes home), and at the start of the next turn reappears on its home tile. The tagger keeps following its path.
3. **Pick up.** An untagged piece that entered the enemy flag's tile picks it up.
4. **Capture.** A carrier inside its own base scores. This ends the turn's movement and resets the board as above.

Pieces on the same team can share and pass through tiles. Adjacent enemies don't meet.

**Vision.** A team sees a tile if any of its pieces is within 5 tiles (Euclidean, `dx² + dy² ≤ 25`) with clear line of sight. Line of sight runs from tile centre to tile centre, and every tile the line touches strictly between them must not block sight. A blocking tile can itself be seen; what's behind it can't. Terrain is always visible, but pieces show only when their tile is seen, with two exceptions:
- A piece on tall crops shows only to enemies on an adjacent tile (8-neighbourhood) or the same tile.
- A flag carrier always shows.

Flags are always visible: they are either home or carried. A team always sees all of its own pieces.

**Playback.** Each person gets the turn's ticks filtered to what their team saw at each tick (vision computed after that tick's moves), plus the events they witnessed. Every event involving their own pieces counts as witnessed. Pickups and captures are always announced, since flags are always visible. The client animates tile by tile, about 2–3 s per turn. The next turn starts when both sides report `playback_done`, or after 4 s; the planning timer starts then, so slow animation doesn't eat thinking time.

## 3. Code structure

All game code is in `games/tiny_flag/`. The `sim/` files are pure rules (no nodes), unit-tested, and run on the server, by bots and in tests.

| File | Responsibility |
|---|---|
| `maps/farm.txt` | the first map |
| `sim/flag_map.gd` — `FlagMap` | parse a map; terrain table; halves; bases, home tiles and flag tiles |
| `sim/flag_state.gd` — `FlagState` | pieces (id, team, tile, carrying, tagged), score, turn number; copyable plain data |
| `sim/flag_path.gd` — `FlagPath` | A*, path cost, order validation |
| `sim/flag_vision.gd` — `FlagVision` | line of sight, crop hiding, carrier rule; a team's visible pieces |
| `sim/flag_resolver.gd` — `FlagResolver` | `resolve(state, orders) -> {state, ticks, events}` |
| `sim/flag_bot.gd` — `FlagBot` | orders for a side, from that side's view only |
| `flag_match.gd` — `FlagMatch` | server: phases, timer, sides (person / bot), spectators, sending per-team views |
| `tiny_flag_game.gd` — `TinyFlagGame` | `GameBase` subclass: RPCs, player node per person (team or spectator), client build |
| `client/board_view.gd` | `TileMapLayer` terrain (Tiny Farm), pieces and flags (Tiny Battle), last-seen markers, playback animation |
| `client/order_input.gd` | mouse and touch order entry, path preview |
| `client/turn_hud.gd` | timer, Lock in, score, event messages |
| `client/flag_menu.gd` | `GameMenu` subclass: Play, Controls |

Files stay under ~300 lines; split further if they grow.

**Fit with the starter.**
- `GameBase` still does seats, join requests, rejoin, the menu and smoke reporting. Each person gets one plain player node (spawn data: id, team or spectator).
- Pieces are not synced nodes. `BoardView` draws them from the turn messages. `InputRelay`, `PlayerNet`, `SnapshotBuffer` and `ServerBots` aren't used: a turn game has no input stream or interpolation, and the bot side lives in `FlagMatch` without a seat. The game's README says this, so nobody "fixes" it back.
- `TinyFlagGame` overrides `_process`, `_player_leaving` and `smoke_report`; the base versions assume moving players.
- **Starter change:** a `GameBase.touch_stick() -> bool` hook (default `true`). When it's false, `main.gd` builds `TouchControls` with the Menu button only, because the floating stick would swallow taps on the left half of the board. Ported to game-starter in its own PR.
- `Protocol.PORTS["flag"] = 9082`, `DEFAULT_GAME = "flag"`, `flag` in `tools/smoke.sh`'s `all` list, a `/ws/flag` route in both Caddyfiles, and the instance in `deploy/`.
- The box arenas are deleted in their own commit once Tiny Flag passes `verify.sh` (also from `main.gd`, `PORTS`, `smoke.sh` and `deploy/`).

**Messages.** All are reliable. Every `any_peer` RPC checks the sender and sanitizes every argument.

| Direction | RPC | Content / checks |
|---|---|---|
| client → server | `submit_orders(turn: int, orders: Array)` | Each order is `[piece_id: int, path: PackedInt32Array]`, the path as flat x, y tile pairs (Godot has no packed Vector2i array). Dropped unless `turn` is current and in planning, and the sender plays a side. Per order: the piece must be the sender's and untagged; no piece twice; at most 5 orders; a path is at most 16 steps (an even-length array) inside the map, each step 4-adjacent and passable, total cost within movement points. A bad order is dropped alone (that piece stays). |
| client → server | `lock_in(turn: int)` | sender plays a side, `turn` is current |
| client → server | `playback_done(turn: int)` | same |
| server → one peer | `turn_started(turn, seconds_left, view)` | `view`: own pieces, visible enemies, flags, score, turn limit |
| server → one peer | `turn_resolved(turn, ticks, events)` | per tick: positions of own and visible enemy pieces; witnessed events (tag, pickup, capture, drop) |
| server → one peer | `match_over(result)` | winner or draw, final score |

Spectators get the **public view**: a piece is in their rows only if both teams can see it (own pieces count as seen by their team, so in effect: the opposing team can see it), and flag carriers always. Of the events they get pickups, captures, and a tag only if both pieces are in that tick's public rows (always true for a real tag: a meeting on one tile or an orthogonal swap). On top of that they run **one turn late**: `turn_resolved` for a turn, and the view of its start, only after it has resolved. A spectator, such as a player's second browser tab, therefore never sees a piece that either team couldn't, and can't pass a player positions that player couldn't see while planning.

## 4. Testing

**Unit tests** (`tests/unit/test_tiny_flag_*.gd`):
- map parsing, bad map input, symmetry and the reachability / two-route constraints on `farm.txt`
- path costs, A*, order validation accept and reject cases (wrong owner, gaps, walls, over budget, too long, NaN/huge coords)
- vision: radius, hedge and tree blocking, crops hiding except when adjacent, carriers always visible
- resolver: same-tile tag on each half, swap on one half, swap across the line (both tagged), tagger continues, tagged stop and respawn, pickup, tag-same-tick-as-pickup (tag wins), carrier movement points, capture and reset, the turn-limit result
- filtering: for random seeded matches, no team's playback or view ever contains an enemy outside its vision
- a full bot-vs-bot match that finishes within the turn limit, deterministically

**Smoke test** (`tools/smoke.sh flag`, in `verify.sh` via `all`). Two `--bot` clients become Red and Blue; bots plan with `FlagBot`, lock in at once and skip animation.
- Server report: ≥ 3 turns resolved, both sides' pieces moved, no invalid orders from bots.
- Each client: received `turn_resolved` for ≥ 3 turns, its own pieces moved, and its **leak check passed**. The client recomputes its own vision each tick from the map and its own positions, and asserts every enemy it was sent was visible.
- The restart smoke runs for `flag`: bots rejoin and a new match plays.

**By hand:** `tools/export.sh web`, two browser tabs and one phone. Restart the server while connected; the page must offer Rejoin and work after it.

## Out of scope for this spec

Keyboard and controller order entry, more maps, sound, lobbies and matchmaking, more than two people playing, replays, client-side prediction. Each becomes a GitHub issue when wanted.
