# Prepare and verify a Roblox release

This is the reusable checklist for a future Roblox release. The [P12 legacy implementation handoff](../plans/12-mvp-release.md) is closed by user direction; its recorded unavailable/unrun checks remain historical facts. The current local game is integrated on `main`. Routine setup uses the [root guide](../README.md#set-up-locally).

The checks below are unverified for a future named release and apply when that release is requested. Closeout and source integration grant no new publication authorization; use only authorization that covers the actual candidate, place and audience.

| Future release check | Evidence at legacy closeout |
| --- | --- |
| Exact publication/version and destination audience | Unverified for a future candidate |
| Platform access, asset permissions and live asset loading | Unverified for a future candidate; recheck its actual destination |
| Real 6- and 10-player capacity/outcome sessions | Unverified |
| Live frame-time, latency and convergence workload | Unverified |
| Live 30-minute retained-memory/replay soak | Unverified |

## Prepare the candidate from Git

Use a clean checkout of the selected candidate commit with the repository history
available for asset provenance. Run both commands from the repository root.

```sh
python3 scripts/setup.py
python3 scripts/prepare_release.py
```

The command runs `scripts/verify.py`, checks the runtime script sources in both
Rojo builds against the checkout and matches the release's cloud asset IDs to
the committed asset records. On success, `build/release-receipt.json` records
the commit and tree, build SHA-256s, tool and dependency pins, manifest and asset
inventory. The Vesper inventory is derived from a separate build of the two
native banks and their import receipt. Retain that receipt and the host log with the exact candidate. Keep
the generated place files in local or CI artifact storage.

Open `build/tests.rbxlx` as a separate local Studio test document or sync the
candidate to the existing test document with `test.project.json`. Collect fresh
[engine and multiplayer reports](testing.md#studio-execution-and-evidence) for
the candidate. Keep the test build local. The upload candidate is
`build/game.rbxlx`, built from `default.project.json` with the production
two-player minimum and ten-minute rounds. The host checks establish release
isolation. Destination permissions, live asset loading and play are separate
checks below.

## Verify the destination and prepare rollback

1. Record the candidate commit, release SHA-256, manifest fingerprint, owner
   and exact experience, universe ID and place ID in that release’s evidence. Confirm
   the place in the experience's **Places** list in Creator Dashboard and
   check that its maximum player count is ten. Verify the desired access mode
   and the permitted tester group. [Configure games and places](https://create.roblox.com/docs/projects/configure-experiences), [place capacity](https://create.roblox.com/docs/reference/engine/classes/Players#MaxPlayers)
2. Use the receipt's full mesh, texture and audio inventory to check moderation
   and use permissions for the destination experience under that owner. Use
   Creator Dashboard's asset permissions for restricted assets and confirm each
   required grant or open-use status. Record the inventory checked and unresolved
   IDs. Handle an absent grant with the asset owner before publishing.
   [Asset privacy](https://create.roblox.com/docs/projects/assets/privacy), [audio assets](https://create.roblox.com/docs/audio/assets)
3. Record the currently known-good published version and its source or retained
   build hash, along with the audience settings. Keep a copy of the known-good
   build or confirm it is available in Version History. For a first publication,
   record the plan for closing playtest access if the smoke checks fail.
   [Version History](https://create.roblox.com/docs/projects/version-history)
4. Record explicit authorization that covers this candidate, place and audience
   before publication. If it is missing, retain the prepared candidate and the
   local evidence. Use Playtesters access only when authorized for the named
   audience. [Publish and set playtest access](https://create.roblox.com/docs/production/publishing/publish-games-and-places)

## Publish and smoke-test the exact build

Recheck the release file's SHA-256 immediately before publication. Open that
artifact as a local release document in Studio and publish it to the authorized
place. Enter the candidate commit in the version notes. Use Studio for the
Outpost's `SurfaceAppearance` instances because the Open Cloud place publishing
guide lists limitations for that type. [Studio publishing](https://create.roblox.com/docs/production/publishing/publish-games-and-places), [Open Cloud place publishing limitations](https://create.roblox.com/docs/cloud/guides/usage-place-publishing#limitations)

Confirm the published version in the target place's Version History and record
the version, timestamp and authorized play link. Join a fresh Roblox server and
confirm the running place/version and expected audience. Use the running server
version where available to distinguish new servers from those already running an
older build. [Running place version](https://create.roblox.com/docs/reference/engine/classes/DataModel#PlaceVersion)

- Confirm an authorized tester can join and walk in the lobby while waiting for
  a second player. Check that the test panel and development fixtures are absent.
- When a second tester joins, verify the round starts with one C-130 operator
  and one Ground player.
  Check the Outpost exterior, rooms and panel stages for loaded meshes and
  textures, and check the in-game audio cues and asset-load errors under the
  target experience. Save the observed client/device and error results.
- If the build fails smoke or has a material gameplay or replication defect,
  follow the recorded rollback. Restore the known-good place version, publish
  the restored version to the authorized destination and verify it from a fresh
  server. Existing servers may still run the superseded version. Record the
  restored version, resulting published version and follow-up smoke.
  [Restore a prior version](https://create.roblox.com/docs/projects/version-history#restore-to-a-previous-version)

## Run the 6- and 10-player acceptance sessions

Run with six and with ten connected Roblox player clients in the same server
for each cohort. A round can deploy as soon as two players are present after
the lobby wait. If that happens while the group is joining, let the setup round
end and keep the full group connected. Start measured rounds at the desired
roster size, with one operator and everyone else on Ground. Repeat each
of the three outcome paths at each full roster size, keeping the roster connected
through Results and reset.

D75 waived the dedicated late-join exercise for the historical P12 candidate.
When a future acceptance run includes this exercise, start a round with space
for a fresh participant and add that participant after deployment. Record
the client counts before and after the join. The late joiner must remain a
spectator without active equipment or a round life until the next lobby. D59
covers the same-identity reconnect exclusion.

| Exercise | Expected observations |
| --- | --- |
| Aircraft destroyed | Confirm maximum health is 1,000 × deployment Ground players, excluding the operator, and remains fixed through deaths/departures. Each direct rocket removes 100 and each M-7 hit removes 5, capped at remaining health. Continue until exactly one Ground win commits. Recover a launcher with a teammate after a drop or carrier loss, preserving reload timing. |
| Ground eliminated | The C-130 wins once when the last life is lost. Check that eliminated players follow living teammates or see the overview and cannot act. Reinforce both weapons' readiness checks by switching between them during reload. |
| Timeout | Let the normal round deadline expire with a living Ground player and an intact aircraft. Confirm the C-130 win and timeout reason on all clients. |
| Terrain, controls and cover | Walk the usable floors/routes in Salt Flats, Vesper, the Outpost and Seedship, reach all four launchers and check the Outpost’s interior camera entry and exit. Use both weapon zooms with directional panning across square edges/corners, immediate reversal and independent aim. Check thermal and shot occlusion around an intact panel and through a real opening. |
| Progressive destruction | One direct 105mm hit must remove a registered panel completely. Use a fresh panel to show Light damage, a Heavy opening at one earned 30mm second and Total at two, including persistent credit across an interruption. Check that paused time earns no credit and actual fragments fall. Exercise the starting shelter as well as multi-story cover. |
| Reset and replay | Confirm the same winner and reason on all clients. After Results, check lobby control, intact terrain and panels, cleared debris, restored aircraft and equipment readiness, and one fresh launcher at each of the four anchors at the next deployment. |

Record source/build and place version, actual counts, anonymous role labels,
device and input types, observed results and deviations. Keep participant names,
account IDs, private server access codes and unredacted roster captures out of
Git. Update the player README with the verified play link, audience, tested
devices and known limitations after live verification.

## Measure the live 10-player workload

Use the [release budgets](testing.md#objective-release-budgets). Pin the operator
and Ground desktop render viewport to 1920×1080, record graphics quality and keep
the clients in comparable foreground conditions. Run five loaded minutes with
both gunship weapons, rifles, rockets, progressive panel openings and concurrent
fragments. Record the load and actual client count. Measure p95 client frame time
against 33.3 ms in each role and server frame time against 16.7 ms. Record exactly
which timing the tool reports, the sample count, capture coverage and gaps.

The desktop client MicroProfiler can write frame dumps. An editor can capture
short server dumps from the live Developer Console. Plan capture windows across
the full workload or arrange full-duration frame collection before the session.
A short dump can diagnose a spike. Claim the workload p95 only with adequate data
covering the five minutes. [MicroProfiler](https://create.roblox.com/docs/performance-optimization/microprofiler), [live diagnostics](https://create.roblox.com/docs/performance-optimization/identify)

Warm up the actual server and clients, then run at least 30 loaded minutes
through repeated matches and resets. Compare retained memory at equivalent lobby
checkpoints after warmup and each reset on the same processes. Record the samples,
percent growth and trend against the 10% limit. Use Developer Console memory
categories and observed game-owned resource counts to distinguish engine caching
from uncollected game state. Record missing measurements and replication defects
with their conditions. At comparable live reset points, check that observable
aircraft, launcher and debris state returns to baseline. [Developer Console](https://create.roblox.com/docs/studio/developer-console)

Record live latency and convergence around shared events at the release latency
target. Capture the ping source and readings, round and action, agreement across
clients, and any duplicate damage or result. The historical local P11 fixtures remain reproducible from their recorded source revision; their selector rejects on current source. Any future current-source cleanup/latency automation needs its own validated fixture. Keep local results tied to their Studio environment and live results tied to the named release. [P11 workloads](testing.md#run-the-p11-performance-harness)
