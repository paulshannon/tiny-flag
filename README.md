# Tiny Flag (Godot 4.7)

A multiplayer browser game in Godot 4.7, built with [Kenney](https://kenney.nl) assets and developed with Claude Code. Tiny Flag is turn-based two-team capture the flag on a Kenney farm board (see `games/tiny_flag/README.md`), on one server-authoritative networking layer.

- **Browser-first:** single-threaded web export on the Compatibility (WebGL 2) renderer. Works on any static host, Safari included.
- **Server-authoritative:** clients send input; a headless dedicated server simulates and replicates state; clients interpolate.
- **Verified by script:** one command compiles every script, runs unit tests, and runs a real server with bot clients over WebSockets.

Built on [paulshannon/game-starter](https://github.com/paulshannon/game-starter), copied at `bc6085f`. The shared framework (networking, input and touch controls, menus, the test runner, tools, deployment, CI) comes from there; fixes to it that any game could use go back to the starter too. [paulshannon/game](https://github.com/paulshannon/game) is another game on the same framework and the fullest example of its patterns (a start menu, a second spawner for entities, server-flown bots, a Kenney UI theme).

`CLAUDE.md` is the development guide (Claude Code reads it automatically). `docs/SESSION_NOTES.md` records how the starter was built: research sources, design reasoning, what was tried and dropped, and how it was verified.

## Quick start

```bash
tools/install_godot.sh --templates   # pinned Godot + export templates into .tools/
tools/verify.sh                      # compile + unit tests + multiplayer smoke test
```

Play locally with native windows (fastest loop):

```bash
tools/run_server.sh                  # terminal 1  (Tiny Flag, the default game)
tools/run_client.sh                  # terminal 2
tools/run_client.sh                  # terminal 3 — a second player
tools/run_client.sh flag "" --bot    # or a bot player
```

Play in the browser:

```bash
tools/export.sh web
tools/run_server.sh                  # terminal 1
tools/serve_web.sh                   # terminal 2 → open http://localhost:8000/
```

Open the page in two tabs to play Red against Blue (a side nobody plays is the server's bot). Tiny Flag is the default and only game (`--game=flag` / `?game=flag`). Click a soldier, click tiles to plan its path, then **Lock in**; on a touch screen, tap a soldier, tap a tile to preview and tap it again to confirm (there is no movement stick). Controls are in `games/tiny_flag/README.md`.

Use the editor normally too: `.tools/godot -e --path .` (or your own Godot 4.7.1). To run server + clients from the editor, set *Debug → Customize Run Instances* with `-- --server` for one instance and `-- --client` for the others.

## Adding the game

Tiny Flag was started from the starter's box-arena skeletons, which have since been removed here; to start another game, copy a `games/box_arena_*` folder from [paulshannon/game-starter](https://github.com/paulshannon/game-starter) and follow *Workflow for a new prototype* in `CLAUDE.md` §7 (`main.gd::_make_game`, `Protocol.PORTS`, `tools/smoke.sh`'s `all` list, `deploy/`).

Keep game code in `games/<name>/` (and its tests in `tests/unit/test_<name>_*.gd`). Anything another game could use goes in `common/`, `client/`, `tests/` (the runner) or `tools/`, and is ported back to the starter in its own PR. Starter changes come in by merging or copying them; note the starter commit in the commit message.

## Adding Kenney art

```bash
tools/add_kenney_pack.sh ~/Downloads/kenney_mini-characters.zip    # → assets/kenney/mini-characters/
tools/kenney_atlas.sh assets/kenney/<2d-pack>                     # 2D only: spritesheet XML → .tres
```

Then load the art from the game's own code (Tiny Flag's tiles and pieces come from `games/tiny_flag/`). The installer keeps the pack's folder structure and License, removes the duplicate FBX/OBJ folders, imports, and records the pack in `CREDITS.md`.

## Layout

```
main.gd / main.tscn      entry point: reads launch config, loads game, hosts or joins
common/net/              transport (Net autoload), protocol constants, launch config,
                         input relay, replication helper
common/sim/              ArenaSim: input sanitizing used by InputRelay — unit-tested
common/game/             GameBase: spawning, despawning, smoke-test reporting
client/                  interpolation buffer, input actions, HUD
games/tiny_flag/         Tiny Flag, turn-based capture the flag (games/tiny_flag/README.md)
tests/                   tiny test runner + unit tests
tools/                   every command (install, check, test, smoke, export, serve, Kenney)
deploy/                  Caddy (HTTPS + wss) and systemd for a single VPS
docs/                    SESSION_NOTES.md (build history) + browser test screenshots
```

## What was verified

On Godot 4.7.1 (Linux): all scripts compile with untyped declarations treated as errors; 22 unit tests pass; server + 2–3 bot clients pass the smoke test in 2D and 3D, both from source and as the exported dedicated-server binary. The web export ran in headless Chromium (WebGL 2 via SwiftShader) against the exported server: the join gate, keyboard input, server movement and the other player all worked, including over HTTPS → `wss://` through the shipped Caddy config. A Kenney-format test pack (GLB + spritesheet XML) went through the installer, atlas converter and the `MODEL_PATH`/`SPRITE_PATH` swap. Not tested: a real macOS machine, Safari, and real Kenney downloads (kenney.nl wasn't reachable from the build environment).

## Branches and releases

The repo uses **git-flow**:

| Branch | What it holds | Branch from | Merge into |
|---|---|---|---|
| `main` | released code only; every commit is a tagged release | — | — |
| `develop` | the integration branch (default branch; open PRs here) | `main` | — |
| `feature/<issue>-<slug>` | one issue or change, e.g. `feature/5-touch-controls` | `develop` | `develop` (PR) |
| `release/vX.Y.Z` | getting a release ready: version, changelog, fixes only | `develop` | `main` **and** `develop` |
| `hotfix/vX.Y.Z` | an urgent fix to a released version | `main` | `main` **and** `develop` |

`main` and `develop` are protected: changes arrive by pull request with CI green. CI refuses PRs into `main` from anything but `release/*` and `hotfix/*`. Because `develop` is the default branch, `Fixes #N` closes an issue when its feature merges into `develop`, not when it ships.

**Cutting a release** (example `v0.1.0`):
1. `git switch -c release/v0.1.0 develop`
2. Set `config/version="0.1.0"` in `project.godot` (`tools/version.sh` prints it), and in `CHANGELOG.md` rename **Unreleased** to `[0.1.0] - YYYY-MM-DD`. Run `tools/verify.sh`.
3. Open a PR `release/v0.1.0` → `main`. After CI passes, merge it.
4. Tag **the merge commit on `main`** and push the tag: `git fetch origin && git tag -a v0.1.0 origin/main -m v0.1.0 && git push origin v0.1.0`. Use git rather than GitHub's "Draft a new release" page. That page creates the Release itself, with generated notes and no files; the workflow will adopt it, but the git route is the intended one. `release.yml` rejects a tag that isn't on `main`'s own merge line.
5. Merge `main` back into `develop` (PR) so the version and changelog land there too, and add a fresh **Unreleased** section.

Pushing the tag runs `.github/workflows/release.yml`. It checks that the tag matches `project.godot`, is on `main` and has changelog notes; re-runs the full CI on the tagged commit; then creates a **GitHub Release** with `game-web-vX.Y.Z.zip`, `game-server-linux-x86_64-vX.Y.Z` and `SHA256SUMS`; and publishes that release's web build to **GitHub Pages**. Nothing is published if any step fails. A hotfix is the same with `hotfix/vX.Y.Z` branched from `main`.

**The published page:** `https://<owner>.github.io/<repo>/` is a landing page linking to every game in `Protocol.PORTS` (built by `tools/make_site.sh`). Pages is HTTPS, so the games need a `wss://` game server, and Pages can't host one. Set the repository variable **`GAME_SERVER_URL`** (Settings → Secrets and variables → Actions → Variables), e.g. `wss://game.example.com`, and the links carry `&server=<url>/ws/<game>` to match the `deploy/` Caddy setup. Without it the page loads but explains that no server is configured.

## Deploying

See `deploy/README.md`: one VPS, Caddy for automatic HTTPS and WebSocket TLS, one systemd service per game. CI (`.github/workflows/ci.yml`) runs the full verification and exports on every push.
