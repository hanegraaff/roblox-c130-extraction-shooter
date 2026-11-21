# P10 — Player guidance, spectating and presentation

**Milestone:** M6. **Dependencies:** P09. **Requirements:** R04, R12, R15. Status: [roadmap](../roadmap.md).

## Capability and player experience

A new player understands their role, controls, aircraft health, launcher availability and result without a developer narrating the session. Spectating, thermal view, effects and audio feel like one coherent game.

## Implementation

Consolidate role-specific HUD and help, launcher ownership and recovery messages,
WASD pan, mouse aim and recenter guidance, panel-damage progression, weapon-specific
zoom, ammunition, cooldown and health feedback, accessible result reasons, and
spectator target cycling. Add readable stylized cues, audio and effects with
provenance in the asset manifest. P13 and P07 already supply terrain, buildings
and destruction, and P16/P17 supply the detailed Outpost. Important sounds have
visible cues, and labels or icons convey information also shown by color. Add
effect and camera-shake intensity controls. Keep full functionality at 1280×720
and 1920×1080 desktop viewports. The new controls target desktop, alongside
the existing touch controls.

## Acceptance criteria

- **A1:** Full gate passes; view-model tests cover each phase/role, death, destroyed aircraft, operator forfeit, no living spectator targets, rejected actions and result reason.
- **A2:** Engine UI tests show correct role controls, legible aircraft-health/timer/ammo/launcher state and both named aircraft weapons, bounded layout at both target resolutions, and keyboard-operable help/settings.
- **A3:** Spectators follow living teammates only, never gain weapon/interact authority and recover to a neutral view when targets disappear. Role/reset transitions restore camera/input and clear duplicate UI.
- **A4:** Settings change effects without gameplay advantage or state mutation. Required warnings/results have visual equivalents independent of audio/color.
- **A5:** All added assets have provenance and ownership records; their source/reference dependencies build cleanly and no imported unintended scripts remain.

## Focused human check

Have a tester complete both roles from in-game instructions. Inspect thermal
contrast, warning and impact frames, launcher ownership and reload, both weapon
zoom levels while panning, building-panel stages and physical debris, aircraft
destruction and team results, defeat and spectating, and both desktop viewport
sizes. Keep reviewed gameplay captures in the linked evidence record.

## Documentation changes

The dedicated military-outpost art work is scoped separately in
[P16](16-blender-military-outpost-assets.md) (Blender assets and human approval)
and [P17](17-integrate-military-outpost.md) (smaller-Outpost integration).
P10 retains its presentation/onboarding scope. D63 schedules P16/P17 before
P09 and this plan, so onboarding and presentation must describe the approved
Outpost actually present in the tested candidate.

Update the README's player guide and local setup for the current game. Keep the
selected P16 Blender authoring image in the README and link reviewed gameplay
captures in the evidence guide. Document asset credits and current limitations.

## Completion record

P10 adds desktop role help, readiness and launcher status, teammate spectator
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

The ordinary two-client run used the in-game instructions at 1280×720 and
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
