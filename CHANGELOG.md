# Changelog

All notable changes to this project. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

Each release's section becomes the notes of its GitHub Release (`tools/release_notes.sh`). On a `release/vX.Y.Z` branch, rename **Unreleased** to `[X.Y.Z] - YYYY-MM-DD` and set the same version in `project.godot` (`application/config/version`).

## [Unreleased]

### Added
- **Project created from [paulshannon/game-starter](https://github.com/paulshannon/game-starter)** at `bc6085f`: the shared multiplayer framework, tools, tests, deploy files and CI, plus the two skeleton games (`box_arena_2d`, `box_arena_3d`) to build Tiny Flag from.
- Kenney interface packs (CC0): Input Prompts, Mobile Controls, UI Pack, Interface Sounds, Emotes, Cursor Pack, under `assets/kenney/`.
- Kenney pixel-art packs (CC0): Tiny Battle, Tiny City, Tiny Dungeon, Tiny Factory, Tiny Farm, Tiny Ski, Tiny Town, under `assets/kenney/`. The default 2D texture filter is now Nearest so they stay crisp.
- **Tiny Flag**, a turn-based two-team capture the flag game (`games/tiny_flag/`), now the default game (`?game=flag`, port 9082). It plays over the network with headless bot clients: simultaneous planning, lockstep playback, fog of war enforced by the server, bots on empty sides, spectators one turn behind. It's playable in the browser with mouse or touch: a Kenney farm board (Tiny Farm terrain, Tiny Battle soldiers and flags), click or tap to plan paths with their cost, Lock in, an animated playback with event messages, faded last-seen markers for enemies out of sight, score and countdown, and a start menu with Play and Controls. Deploy files (`/ws/flag` in both Caddyfiles, a `game-flag` compose service, `kenney-mp@flag`) and CI's restart smoke cover it.
- Tiny Flag's HUD and menu are themed with the Kenney UI Pack: its buttons (Blue, a green Lock in, a yellow Clear path with the pack's cross), light panels behind the HUD text, a team-coloured "You" tag and result banner, and the Kenney Future font. The Clear path button's ✕ used to draw as a missing-glyph box in the browser.

### Changed
- Tiny Flag's farm map is four times larger: 64 × 36 tiles instead of 32 × 18, with flanking lanes, farmyards, orchards, ponds and wide wheat fields in the middle. The turn limit doubles to 80 so a match still has time for captures.
- The web build is ~2.4 MB of game data instead of ~17.7 MB: both export presets leave out the Kenney packs Tiny Flag doesn't load (Cursor, Emotes, Input Prompts, Interface Sounds, Mobile Controls, Tiny City/Dungeon/Factory/Ski/Town). Tiny Farm, Tiny Battle and the UI Pack (the HUD and menu theme) are still exported.
- `GameBase.touch_stick()` is now in the starter too (paulshannon/game-starter `b206f8a`, which includes this repo's `if stick_enabled:` cleanup of the stick drawing).

### Removed
- The starter's box-arena skeletons (`box_arena_2d`, `box_arena_3d`): Tiny Flag is the only game here now (`Protocol.PORTS`, `tools/smoke.sh all`, the Caddyfiles, compose services and systemd notes list just `flag`). `tools/run_server.sh`, `tools/run_client.sh` and the Docker entrypoint default to `Protocol.DEFAULT_GAME` when no game is named; the image defaults to `GAME=flag`. To start another game, copy a skeleton from paulshannon/game-starter.

### Fixed
- Tiny Flag trees are whole: the board drew the bottom half of Tiny Farm's two-tile pine (a trunk with no top), and now uses the pack's one-tile pine.
- Tiny Flag spectators see only the public view (pieces both teams can see, plus flag carriers), still one turn behind. They used to get every piece, so a second browser tab could see through the fog of war.
- Tiny Flag's result banner appears once the final turn's playback has finished, instead of covering the board while the winning move animates.
- A Tiny Flag finger whose release was taken by a button, or lost to an app switch or system gesture, no longer blocks every later tap until the next turn: fingers are tracked from every input event and forgotten when the window loses focus.
- Tiny Flag board taps work in real browsers: the order input took only touch index 0 as the first finger, but browsers number touches freely (iOS Safari uses large ids, Chrome counts up), so taps on pieces and tiles were ignored. Now any lone finger counts.
- Tagged pieces in Tiny Flag are back on their home tile and can be ordered in the very next planning phase (they used to sit out an extra turn where they were caught).
