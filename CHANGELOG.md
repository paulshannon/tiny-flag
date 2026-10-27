# Changelog

All notable changes to this project. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

Each release's section becomes the notes of its GitHub Release (`tools/release_notes.sh`). On a `release/vX.Y.Z` branch, rename **Unreleased** to `[X.Y.Z] - YYYY-MM-DD` and set the same version in `project.godot` (`application/config/version`).

## [Unreleased]

### Added
- **Project created from [paulshannon/game-starter](https://github.com/paulshannon/game-starter)** at `bc6085f`: the shared multiplayer framework, tools, tests, deploy files and CI, plus the two skeleton games (`box_arena_2d`, `box_arena_3d`) to build Tiny Flag from.
- Kenney pixel-art packs (CC0): Tiny Battle, Tiny City, Tiny Dungeon, Tiny Factory, Tiny Farm, Tiny Ski, Tiny Town, under `assets/kenney/`. The default 2D texture filter is now Nearest so they stay crisp.
- **Tiny Flag**, a turn-based two-team capture the flag game (`games/tiny_flag/`), now the default game (`?game=flag`, port 9082). It plays over the network with headless bot clients: simultaneous planning, lockstep playback, fog of war enforced by the server, bots on empty sides, spectators one turn behind. Client visuals come next. Deploy files (`/ws/flag` in both Caddyfiles, a `game-flag` compose service, `kenney-mp@flag`) and CI's restart smoke cover it.
