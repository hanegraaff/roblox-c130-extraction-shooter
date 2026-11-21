# P10 — Combat presentation and spectating

**Milestone:** M6. **Dependencies:** P09. **Requirements:** R04, R12, R15. Status is tracked in the [roadmap](../roadmap.md).

## Capability and player experience

Both teams see the round state, equipment readiness and aircraft health.
Spectators can cycle through living Ground players. Aircraft and ground
weapons have distinct positional sound.

## Implementation

Show one shared aircraft health bar based on server-confirmed health. Its
width decreases with damage and its fill moves from green through amber to red.
Keep numeric health and the destruction label readable independently of color.
Show weapon names, zoom, cooldown and ammunition, launcher ownership and
recovery, and team results. Keep the Settings and spectator controls.

Play distant 30mm thumps and a deeper 105mm report with a local propagation
delay. Give the M-7 a sharp muzzle report and rockets a launch rush, exhaust
trail and separate impact. Base playback on accepted shots and resolved
impacts. Record asset provenance and preserve visible warnings with effects
muted. Check the HUD at 1280×720 and 1920×1080 and preserve the compact touch
layout.

## Acceptance criteria

- **A1.** The host gate passes. Deterministic tests cover health fractions,
  results, spectator selection, settings and sound timing boundaries.
- **A2.** Studio shows the health bar at full, damaged and destroyed states.
  Both desktop viewports fit the HUD, and touch retains its compact layout.
  Settings remain keyboard operable.
- **A3.** Spectators follow only living Ground targets and get a neutral view
  when targets are unavailable. Reset restores the camera and removes old UI.
- **A4.** Confirmed fire and impacts play weapon-specific effects with staged
  timing. Muting and reset clear queued audio. Warning and result text stay
  visible across effect settings.
- **A5.** The manifest records the audio sources. Both artifacts build and the
  release mapping contains only the required runtime modules.

## Focused Studio check

Check both zooms, launcher status and reload, distinct gunship reports, ground
muzzle and rocket effects, aircraft health through several hits, and lobby
restoration. Record the exact source, Studio environment and playback evidence.

## Completion record

### Original P10 candidate

The original HUD added readiness and launcher status, teammate spectator
cycling, neutral camera fallback, and separate local effects and camera-shake
settings. The default settings are Full effects and Reduced shake. Shake is
confined to the aircraft-destruction view in Results. Essential warning and
result text stays visible with both settings off. [Presentation defaults](../docs/decisions.md)

The integrated dependency is P09 at `c4698cd` on `main`. The production P10
implementation is `fdf2e55`. The fixture-only revisions through `23bf7ba`
retain those production bytes. Studio 0.748.0.7481526 opened the local
`tests.rbxlx` mapped to **PlayersVsC130Tests** on Rojo port 34872. The Edit
source audit matched all 151 mapped Sources by class, path and SHA-256 for
each candidate recorded below. [Test builds and source identities](../docs/evidence/p10/studio-source-identity.json)

The full non-Studio gate `python3 scripts/verify.py` passed on `4442717` with
77 unit, 73 integration, 15 tooling, 48 asset regression and seven P16 audit
cases. It also verified the bound P17 inputs, strict Luau, both clean Rojo
artifacts, 2,804 authored transforms per artifact and release isolation.
[Host report](../docs/evidence/p10/host-4442717.json),
[GitHub Verify 44842352125](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/44842352125)

### Independent acceptance and operated review

`StudioTestService:ExecuteMultiplayerTestAsync(4, { kind = "P10" })` passed
all eight cases on `23bf7ba`, with four distinct actual clients from start
through teardown. Studio smoke passed 191/191 server cases and 13/13 on each
client, with zero failures, errors or skips. [Four-client report](../docs/evidence/p10/four-client-acceptance.json),
[independent review](../docs/evidence/p10/independent-review.md)

| Criterion | Verified behavior |
| --- | --- |
| A1 | `PlayerPresentation.spec.luau` adds 11 deterministic cases covering role and phase, eliminated and late-spectator views, no live targets, competitive results and forfeit, rejected actions, countdown, weapon readiness and effect settings. The existing match integration suite passed 73/73. |
| A2 | The active native HUD shows the timer, aircraft health, Ground health and ammunition, launcher status, and both named aircraft profiles with their 30° and 40° zooms. H and P, arrows, and reload rejection were exercised through keyboard input. The independent two-client run checked both roles at both exact desktop resolutions, including Help. The measured HUD and menus fit without clipping or overlap. |
| A3 | An eliminated client followed two actual Ground teammates in both directions, recovered when its target died and could not change weapon selection, activate the rifle or claim the launcher. The native client spec exercised the empty-target overview. The multiplayer fixture verified neutral Results, restored lobby cameras and removal of HUDs and camera subjects for all four clients. |
| A4 | With both settings Off, the incoming-fire and aircraft-destruction text cues remained visible, the cue pulse was zero, and the destruction view stayed steady during the sampled interval. A settings change preserved authoritative aircraft, launcher and rifle state. The ordinary clients loaded both bundled sounds and displayed 105mm impact and panel-impact cues. |
| A5 | The manifest records the original Luau effect and both Roblox-bundled audio references. The references were present in installed Studio and Roblox Player. Both builds passed artifact isolation, reconstruction, and the runtime-script allowlist. [Asset manifest](../assets/manifest.json) |

The ordinary two-client run exercised both roles at 1280×720 and
1920×1080. Ground reached, picked up and equipped the launcher, read its
reload, and made three actual direct hits reducing aircraft health from 300
to zero. A temporary local camera binding tracked the Roblox aircraft for
those clicks. The Operator panned at both zooms, read the 105mm reload, and
advanced a Foundry panel from Pristine to Light with an actual impact.
Both clients returned to their own lobby cameras, clean role UI and fresh
aircraft health. [Operated trace and viewport measurements](../docs/evidence/p10/operated-review.json),
[Ground capture](../docs/evidence/p10/ground-desktop.jpg),
[Operator capture](../docs/evidence/p10/operator-desktop.jpg)

The two-client P07 regression also passed 7/7 on the P10 source at
`23bf7ba`. It exercised the six-hit Light, Heavy and Total sequence, earned
30mm damage through interruptions, a walkable opening, fragment expiry and
two resets during live fragments and pending impacts. These are engine
observations from the destruction fixture. [Panel and debris regression](../docs/evidence/p10/panel-physics-regression.json)

### Earlier fixture attempts

All three earlier SDK runs started four actual clients and passed 191 server
and 13 per-client smoke cases. The first stopped at diagnostic formatting of
a `Vector2`. The second checked a child label rather than its effective
ScreenGui visibility. The third hit Studio's restriction on synthetic inventory
number keys. The corrected fixture uses the actual M-7 Tool and production
aircraft selection transport for readiness, and uses Studio virtual input for
the new keyboard controls. The operated session used ordinary keyboard input
for weapon selection. [First report](../docs/evidence/p10/first-fixture-attempt.json),
[second report](../docs/evidence/p10/second-fixture-attempt.json),
[third report](../docs/evidence/p10/third-fixture-attempt.json)

### Final wording retest and delivery

The independent render review identified “1 rounds ready” in the 105mm HUD.
`4442717` changes the ready and cooldown labels for exactly one round and
extends the existing readiness unit case. That is the only production change
after the full four-client and physical-panel passes.

Three four-client launch attempts on `4442717` reached two, three and three
actual clients before the startup deadline. The third used
`StudioTestService:AddPlayers(1)` twice within an SDK session that requested
two initial clients. All three timed out before gameplay assertions.
[Initial startup](../docs/evidence/p10/final-startup-attempt.json),
[startup retry](../docs/evidence/p10/final-startup-retry.json),
[staged startup](../docs/evidence/p10/final-staged-startup.json)

The focused two-client SDK retest on `4442717` passed 191 server and 13
per-client smoke cases. Using the ordinary Start button and native **2**,
the Operator moved from the 30° profile with “100 rounds ready” to the
acknowledged 40° profile with “1 round ready.” The corrected profile fit in
the actual 1280×720 and 1920×1080 viewports. The original local test place
returned to Edit with default simulation and all temporary selectors and
reports cleared. [Focused retest](../docs/evidence/p10/final-readiness-retest.json),
[independent pass cleanup](../docs/evidence/p10/edit-cleanup.json)

The technical writer updated the player guide, local setup, test procedure,
defaults and package contracts after reviewing the source. The repository
checker and `git diff --check` passed on the delivery records. P10 is in
[PR #42](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/42)
against `main`.

### Combat presentation revision

The revised HUD keeps one aircraft health bar for both teams. The old
per-hit labels and the match Help panel were removed. Settings and teammate
spectating retain their existing inputs. [Presentation decisions](../docs/decisions.md)

The full host gate passed on `3f6c6f2` with 79 unit tests, 73 integration
tests, 15 tooling checks, 48 asset regression tests and both Rojo builds.
The native layout case checks full, half, nearly empty and destroyed states,
including the disappearance of the former hit overlays. The new timing
tests cover local muzzle response, distant propagation and rejection of
stale or out-of-range cues.

A two-client Studio session on `3f6c6f2` matched all 154 mapped scripts
to the Rojo build. The server passed 191/191 smoke cases and each client
passed 13/13 with zero failures, skips or errors. Actual launcher hits took
health through 300, 200, 100 and zero on both clients. At 100 health the
bar filled one third of its track and fit in the Ground 1280×720 and
Operator 1920×1080 viewports. Both clients displayed the empty red track
and destruction text at zero, then restored their lobby cameras and full
aircraft health.

Both clients loaded and played the 30mm, 105mm, M-7 and launcher fire cues
and the three impact cues. On Ground, measured fire-to-playback times were
about 0.60 seconds for the 30mm, 0.65 seconds for the 105mm and 0.01 seconds
for the local M-7. The live rocket had an exhaust trail. With effects Off,
the Ground client received the final launch and impact and played neither.
Destruction text remained visible, and both clients cleared weapon audio on
reset. Studio telemetry establishes playback and timing. Perceived realism
awaits a listening pass. [Revision evidence](../docs/evidence/p10/combat-presentation-revision.json)

The original four-client run remains the evidence for two-target spectator
cycling and spectator authority. The revision's two-client smoke exercised
the neutral camera, and its ordinary session verified replay cleanup.
