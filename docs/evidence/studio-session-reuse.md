# Studio session reuse verification

2026-11-08, macOS arm64, Studio 0.746.0.7461269, pinned Rojo 7.7.1. This maintenance change fixes the iteration workflow; it does not implement another roadmap plan. [Structured results](studio-session-reuse.json) record the actual process and source checks.

## Cause and implemented behavior

The previous file opens were OS commands (`open -a RobloxStudio <file>`), not a Studio MCP file-open tool. The available MCP toolset has no local-place opener. An additional probe sending Open Documents directly to an existing Studio PID also created a new Studio process. Repeated opening was therefore the wrong refresh mechanism. The documented [Studio CLI](https://create.roblox.com/docs/studio/cli) opens a place at startup and does not expose a documented reuse-current-process argument.

[`launch_studio.py`](../../scripts/launch_studio.py) makes an initial local launch with Studio fully closed. It validates the file, serializes concurrent helper calls, queries exact-name Studio PIDs, and refuses to launch if one is already running. It uses an argument array with the documented `--task EditFile --localPlaceFile` flags, never a shell-built file command. An unexpected process-query failure, unsupported file/platform or blocked concurrent launch fails closed. It never closes Studio, changes its settings or retries a failed launch.

For iteration, the existing confirmed MCP document is updated through the official [Rojo live-sync workflow](https://rojo.space/docs/v7/getting-started/new-game/#live-syncing-into-studio). The CLI-installed plugin is `~/Documents/Roblox/Plugins/RojoManagedPlugin.rbxm`. The local server serves `test.project.json` on `127.0.0.1:34872`; the connected project is PlayersVsC130Tests. It watches repository files and sends changes to the already-open test document. This does not publish the game.

The plugin was first installed while a play client was active, and connection attempts reported `Http requests can only be executed by game server`. The user observed the toolbar only during Play. After the user saved/quit Studio, the guarded CLI launched exactly one process, and its log confirmed Rojo loaded with `dm=Edit`. The user connected successfully in Edit. The project instructions now require this mode check and describe the first-install restart case.

## Actual verification

- Initial launch: zero Studio PIDs → exactly one PID (73836); MCP identified local test document `p02-tests-5c809beff70b.rbxlx`, place 0, instance `21f6fc11-4429-4148-9764-89a36987e5e9`, in Edit.
- Duplicate request: `python3 scripts/launch_studio.py build/p02-tests-5c809beff70b.rbxlx` returned 2 without launching; process list unchanged.
- Invalid extension (`README.md`) and missing place each returned 1; process list unchanged.
- A temporary comment added with the normal `apply_patch` editing tool appeared in `ReplicatedStorage.Shared.MapRules` through live sync: editor source 3501 bytes / Adler32 3332136112. Reversing the patch restored 3462 bytes / Adler32 3154857652, matching the original file SHA256 `2b981f7336e81b2c8fa7584979b3ecf7f09e5dbf2020cf9ff266f66a56656b52`.
- The same MCP instance and sole Studio PID remained throughout. No additional Studio process was created by source updates or their reversal.
- A fresh post-sync Play passed 23 server and 2 client cases, zero failures/skips/errors, one actual client; the disk remained at `(0,-2,0)`. Play was stopped, Edit confirmed, and Rojo remained connected afterward.
- `python3 -m py_compile scripts/launch_studio.py`, repository/whitespace checks and the complete `python3 scripts/verify.py` passed. [Full host log](studio-session-verify.txt): 14 unit / 2 integration, all static/rejection/build/isolation gates, and the existing five geometry corruption probes passed.

During diagnosis, direct in-place Python writes were not observed by the watcher in the initial probes. Atomic file replacement and the normal `apply_patch` edit/reversal were observed. This is why the workflow requires inspecting the expected synced source/world state before starting tests, rather than assuming that a connected panel proves the candidate arrived. Temporary comments were removed; gameplay source is unchanged.

The local test document is left in Edit with Rojo connected, and the loopback sync server is running. Runtime player identifiers and complete launch logs are not committed. No cloud place change, publication, automatic app termination or unrelated-source change occurred.
