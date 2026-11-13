# P08 launcher verification

## Candidate and environment

Work began on 2026-11-13 on `plan/08-rocket-launcher`, from integrated
`origin/main` commit `c7210bed7e28938640c04b450d827cd727d6215d`.
A fresh `git fetch origin` confirmed that dependency source before branching;
the working tree was clean. No existing open P08 PR was found.

The primary agent coordinates implementation, independent testing and prose
review through the repository's feature-developer, feature-tester and
technical-writer roles. Exact tested candidate hashes and results will be
recorded after verification. No result below is inferred from historical P07
evidence.

## Acceptance ledger

| Criterion | Required evidence | Current evidence |
| --- | --- | --- |
| A1 | Full host gate; one identity/owner/representation under raced and repeated claims | Pending candidate |
| A2 | Runtime role/life/round/shape/replay/rate/reach/movement rejection without mutation, then valid pickup; retained M-7 | Pending candidate |
| A3 | Drop/death/reset/disconnect reload continuity, valid recovery/fallback, terminal precedence | Pending candidate |
| A4 | Actual swept rockets: two nonlethal direct hits, third ground win; mixed rifle damage, cover/miss/duplicate rejection; feasible reload timing | Pending candidate |
| A5 | Three actual clients: operator and two ground players, raced pickup, death/disconnect/recovery, replicated owner/readiness/health, reconnect authority | Pending Studio candidate |
| A6 | Repeated pristine reset, one anchor launcher and no old tool/projectile/callback authority | Pending candidate |

Focused operated review must cover both approaches, pickup, M-7/launcher
selection, firing/misses/reload, drop/recovery, desktop/touch controls and clear
team feedback. A screenshot does not replace multiplayer evidence.

## Initial Studio availability

The initial MCP query returned no instances. Studio is installed at
`/Applications/RobloxStudio.app`; a subsequent process check found Studio PID
92781. The guarded command `python3 scripts/launch_studio.py build/tests.rbxlx`
exited 2 without launching another process because that instance was already
running. MCP then listed `e45b78d9-003f-45ad-b35e-00e5a5ed494a` as Unavailable,
with `Place is not open`. The user reported they were not signed in and would
sign in. No engine gate has passed at this checkpoint. The existing Rojo
listener on localhost:34872 is not proof of a plugin connection or synchronized
candidate.

P08 retains its own A5 requirements. D50's waiver of a real late-join scenario
applies only to P07 and is not a waiver for P08.

After the user signed in and opened the file, the same instance reported
`tests.rbxlx`, Edit mode, local `placeId = 0`, Studio
`0.747.0.7471481`. Read-only inspection confirmed ServerTests, ClientTests,
DevelopmentSettings and the new LauncherService/LauncherRuntime; ManualHarness
was nil and BootstrapStatus absent. The mapped modules establish that source
synchronization is working, but do not establish a passing Play session.

The installed server's `rbx-unit-test` guidance was consulted; tests conform to
the existing automatic TestEZ runners. Its `rbx-docs-search` and `rbx-permissions`
guidance were also consulted before looking up the official
[StudioTestService reference](https://create.roblox.com/docs/reference/engine/classes/StudioTestService).
The documented methods add clients or remove a client, without a same-identity
reconnect parameter/method. The testing-modes guide returned no reconnect
procedure. This bounds the available automation; it does not convert a
deterministic tombstone test into actual reconnect evidence.
