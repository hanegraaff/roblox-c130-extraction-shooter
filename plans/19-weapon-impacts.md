# P19 — Weapon impacts, blast radius and audio

**Milestone:** Combat presentation. **Dependencies:** P05, P07, P08, P10, P11, P18. **Requirements:** R07–R09, R12, R14, R22 and proposed R23. [Roadmap](../roadmap.md) · [Design](../game-design.md#combat-cover-and-destruction) · [Decisions](../docs/decisions.md)

## Capability and player experience

A 105mm shell explodes at its first confirmed impact anywhere on the playable battlefield. On open ground, the operator sees a fireball, dust and fading smoke at the point of contact and hears the blast even when the area is empty. If the shell lands on a road beside a building, that ground contact is the center of the same 25-stud blast. It can damage exposed Ground players and open several nearby wall panels in one shot. A shell hitting a wall, roof, rock or other solid scenery uses the same rule. Cover is evaluated as it stood when the shell landed.

| Weapon | Current game | Proposed experience |
| --- | --- | --- |
| 105mm M102 | Brief impact marker, 100 damage to an exposed Ground player within 18 studs, direct panel destruction | At every confirmed battlefield impact, a fast fireball gives way to outward dust or chips and a fading smoke plume. Apply a **25-stud gameplay radius** and a **six-second reload** between shells. Destroy exposed registered panels within reach. |
| 30mm GAU-23/A | Small impact marker, 4-stud player blast radius, persistent direct panel damage | Each impact reads as a small, directional burst of particles with a wisp of smoke. A burst of fire should trace its way across the surface without hiding the aim point. Keep the existing damage profile and two earned seconds of direct building-panel hits. |
| Ground rocket launcher | A short ribbon trail follows the projectile. Collisions already produce an impact sound. | Follow the rocket with a tapering smoke trail. On first contact with terrain, a building or the aircraft, end emission and show one flash, particles and short smoke tail at the contact point. Fade the existing trail on impact or expiry. |

**Rocket scope for review.** Apply the same quality, readability, performance and cleanup rules to rocket effects. The enlarged damage radius and panel demolition belong to the howitzer. A direct rocket still deals 100 aircraft health once. World hits and near misses deal zero aircraft damage. The M-7 is included in the sound pass.

## Implementation

1. **Resolve the blast against existing cover.** The earlier P19 candidate used a 36-stud blast and a four-second reload. The user requests about 30% less reach and two more seconds between shots. Use 25 studs, a 30.6% reduction, and a six-second reload. Resolve each confirmed hit from its contact point, including Terrain and solid map parts used for ground, roads and buildings. Play the explosion even if the blast finds zero targets. Use one 25-stud setting for exposed-player splash and structural reach across the active level. Align the M102 warning footprint and nearby Ground warning with that setting. Preserve 100 base damage, the existing exposure check and the minimum input cadence. [CombatService](../src/server/CombatService.luau) · [CombatRuntime](../src/server/CombatRuntime.luau) · [PresentationEffects](../src/client/PresentationEffects.luau)
2. **Choose the panels once per impact.** Query the active level’s panel registry on every confirmed impact, including hits with no direct panel ID. Include the directly struck panel when present. For nearby live panel colliders, test the nearest point on each remaining solid surface. Include the panel if that point lies within 25 studs inclusive and is visible from just outside the impact surface on the incoming side. Use the actual registered pieces so a large panel can qualify by its edge and a hole is not treated as a solid face. Gather unique panel IDs and player awards against the geometry at the start of the damage batch. Carry the panel set as one accepted shot through the ordered destruction service and apply Total once per panel. A newly opened wall first benefits a later batch. Stable supports, floors, stairs and the outside lobby remain protected. Keep the existing physical fragment budget across the whole burst. [DestructionService](../src/server/DestructionService.luau)
3. **Render from confirmed contacts.** Send compact server-to-client impact cues carrying round and shot identity, weapon, contact point, surface normal and a coarse surface type. Handle distinct same-frame shots and deduplicate repeats. An aim endpoint or expired flight in empty space produces no explosion. Attach cosmetic smoke to the existing replicated rocket flight and streamline the current impact marker to avoid a second flash. Render one howitzer burst per shell even when it opens several panels. The server owns all damage, openings and collision. [LauncherRuntime](../src/server/LauncherRuntime.luau)
4. **Keep the first frame cheap.** Preload a small shared set of textures and sounds, reuse local emitters, and cap live bursts, particle counts, trail lifetimes, transparent overlap and sound voices. At low settings or under load, drop distant smoke and secondary particles first. Keep essential hit and warning text readable at zero intensity. Provide a lightweight first-contact cue if an optional asset is still loading. Use inert effects and clear active instances, connections and delayed playback on round reset or controller teardown.

## Recommended audio direction

Give each weapon a sound players can recognize during overlapping fire. The current mix already places shots in the world and delays distant reports, but the 30mm report and all three impact cues reuse the same bundled explosion at different pitches. Start by auditioning these replacements at matched listening volume. [WeaponSoundRules](../src/shared/WeaponSoundRules.luau) · [WeaponAudio](../src/client/WeaponAudio.luau)

| Cue | Recommended mix |
| --- | --- |
| 105mm | Give the aircraft report a deep initial thump. At the point of impact, play a short crack with a low boom and a decaying tail. A dusty thud on soil or a brief rattle on a building should locate the landing even with the screen turned away. |
| 30mm | Use a compact per-shot report and two or three short impact variations. Keep tails short enough to hear the rhythm of a burst. |
| Rocket | Pair a launch whoosh near the shooter with a distinct impact punch at the hit point. A short metallic tail on an aircraft hit helps distinguish it from a ground strike. |
| M-7 | Use a dry, sharp local report and a quieter distant crack. Leave room in the mix for incoming-fire warnings. |

Pre-mix the attack, body and tail into one short asset per variant where practical. Keep muzzle and impact positional, retain the existing distance delay, preload off the firing path, and keep the existing limits of 24 active voices and 48 pending cues. Audition under sustained fire on headphones and small speakers. Select original or permitted Creator Store sounds, confirm playback access in the intended experience, record provenance in the asset manifest and keep a bundled fallback. [Roblox audio assets](https://create.roblox.com/docs/audio/assets) · [Positional playback](https://create.roblox.com/docs/sound/objects#positional-audio)

## Acceptance criteria

| ID | Future test and pass condition |
| --- | --- |
| A1 · M102 reach and cover | Extend `CombatService` and `DestructionService` tests. For exposed players and panel surfaces, check just inside, exactly at and just beyond 25 studs, including a target beyond the old 18-stud limit. Check an empty ground strike (one impact cue, zero awards), a ground strike beside a wall (no direct panel ID, exposed panels destroyed), a direct strike spanning neighboring panels, an intervening wall, overlapping panel pieces, and two shots resolved in one batch. Each eligible target is affected once. Prove a second howitzer shot is rejected before six seconds and accepted at the reload boundary, including after a weapon switch. Duplicate, stale, rejected and post-deadline shots produce no damage. |
| A2 · Battlefield coverage | In Studio with two actual clients, exercise the impact scenarios below. Use ordinary firing controls for the open-ground shot and a ground strike beside a building. Both clients must agree on contact location and resulting openings. Verify fragment caps, protected supports and lobby, and pristine reset. |
| A3 · Distinct impacts and rocket flight | Add a Studio impact-cue suite covering 105mm and repeated 30mm on terrain and building surfaces, and rockets against the aircraft, terrain, a building and empty-space expiry. Check one cue per contact, trail start/stop, no impact on expiry, fixed direct rocket damage, no rocket demolition and unchanged 30mm progression. Simulate duplicate or delayed cues and replay into a new round. Verify teardown and stale-cue rejection. |
| A4 · Readability and audio | With Ground and operator clients, identify each weapon from sound alone and compare the proposed mix with the current mix at matched volume. Verify nearby versus distant playback, reduced effects, mute, text warnings and missing-asset fallback. At both thermal zooms check the reticle, white targets, solid cover and newly opened sight lines during a burst. Record Ground and thermal clips with audio and observations. |
| A5 · Responsiveness and cost | Compare baseline and candidate using the same five-minute P11 workload, hardware, two actual clients, 1080p and quality 8. Include sustained 30mm, multi-panel howitzer blasts and concurrent rocket trails. Record per-role p95 frame time (≤33.3 ms), server scheduler p95 (≤16.7 ms), peak resources and impact receipt-to-first-visible-frame latency (proposed p95 ≤2 rendered frames at normal intensity). Exercise low-quality effects and five resets. Active transient counts return to baseline and pools stay bounded. Run the full host gate with `python3 scripts/verify.py` and the affected native combat, destruction, launcher and presentation regressions. [Testing procedure](../docs/testing.md) |

The stronger explosions should show a distinct initial flash and a visible fireball and smoke plume for the howitzer at normal operator distances. Keep the 30mm burst shorter and smaller, and make rocket contact readable against both terrain and buildings. Evaluate normal effects at both thermal zooms and verify that the revised bursts still leave room to track players and aim.

### A2 impact scenarios

| Shot | What to verify |
| --- | --- |
| Empty ground, well clear of targets and buildings | Across desert sand, forest floor, a paved depot road and the Seedship’s red terrain, each shell produces one visible and audible explosion at the actual ground contact. The panel registry and player health record zero changes. |
| Open ground with an exposed Ground player | Place the player between 18 and 25 studs from contact. The ground strike deals the configured damage once, even with no building nearby. Repeat with solid cover between contact and player to verify protection. |
| Ground immediately beside each destructible landmark | Cover the Sandbreak bunker, Salt Flats hangar, Vesper Radar, military depot and Prism Seedship. Confirm the hit was on the ground. Record nearby panel IDs and distances. Exposed in-range panels reach Total, shielded and out-of-range panels keep their prior state, and a ray passes through the new opening. |
| Direct wall or roof contact | Include a small-panel cluster and an elevated roof. The burst originates on the struck surface. The direct panel and exposed neighboring panels within 25 studs reach Total once each. |

## Focused human check

From Ground, watch a howitzer round land on an empty stretch of terrain, then watch another land just short of a building. The dust should mark the ground contact even when panels break several studs away. Follow a rocket from launch to contact while 30mm fire continues nearby. From the operator seat, follow the ground strike at both zooms and aim through the resulting breach as smoke clears. Review the clips with sound muted to judge visual cues, then listen without video to judge the mix. Record which shots are hard to locate or distinguish and whether smoke hides a target, warning or opening long enough to interfere with the next action.

## Documentation changes

On implementation, update the player guide, weapon profiles and cover rules, the client/server package contracts, asset provenance, and the testing guide with measured budgets and evidence.

## Completion record

### First implementation candidate

Candidate `eac79eb5d112ce0b3898fb7a68fbed58a3187013` (tree `72b11a49d68f03c4723af85125e90dc22560ed85`) passed 82 unit and 78 integration cases locally. The full host gate stopped at Selene on unlabeled assertions in new tests.

The independent tester ran the P05 SDK two-client scenario in Roblox Studio `0.748.0.7481526` on the local Rojo test document. Edit parity matched 176 scripts and five poses. Two actual clients joined. Server baseline passed 195/196 and both client baselines passed 17/19. The P19 client emitter case passed on both clients. The server geometry case omitted two ground-level panels, so the staged P05 combat cases did not start. Native rays reported the road at the same endpoint as the candidate panels, while an actual intervening screen stopped the ray before the hidden panel. The tester ended the session and confirmed Edit was restored. [Native report and diagnosis](../docs/evidence/p19/eac79eb-native-attempt.json)

The tester also confirmed in Studio Edit that preloading transient typed Sound instances succeeded for all four referenced samples. Preloading the raw ID strings failed in the same probe. The candidate uses typed preload instances. This verifies the preload mechanism. Operated sound quality remains a separate check.

### Corrected candidate and native combat

Candidate `15ba23561bfce4b6efb1edc0dfe7fc35f1cf2845` (tree `57743f32b04426d0f8e5d39125a16f7c87539167`) accepts a coincident endpoint within 0.005 studs while preserving earlier blockers. It retains accepted impact sounds briefly into Results and prunes pre-Results muzzle sounds. Native regression probes retain the exact 36-stud boundary and an earlier thin obstruction.

The independent tester built the Rojo test artifact with SHA-256 `7690bf9b88e6fda236dade63fdde96c3ad2b8b3b2ec439ad0edcf964a581dc41` and confirmed matching Edit parity for 176 scripts and five poses. In the same Studio version, `ExecuteMultiplayerTestAsync(2, {kind = "P05"})` passed **9/9** with two actual clients. The server smoke passed **196/196** and each client passed **19/19**, with no failures, errors or skips.

- **A1:** Portable combat radius and ordered panel award tests passed. The native `BlastGeometry` case passed, including an exposed panel at exactly 36 studs and separate shielding before the endpoint.
- **A2:** The staged P05 case confirmed an empty terrain hit with no panel or health awards. It also confirmed ground-centered impacts opening 1 Outpost panel, 4 Vesper panels, 3 hangar panels, 10 Sandbreak panels and 4 Seedship panels. Both clients observed the burst point and the resulting openings. These shots used the production transports with controlled poses and aim.
- **A3 and A4:** Native client admission and cleanup tests passed. The staged session recorded both roles with audio tracks and observed loaded, playing gunship reports and a ground-observed heavy impact. It did not supply a matched-volume comparison or validate each rocket collision mode.

[Two-client report and capture manifest](../docs/evidence/p19/15ba235-native-p05.json) identifies the actual observations, capture drops and cleanup. The source of the runtime and combat tests stayed identical through the subsequent documentation and release-allowlist changes.

### Host gate and delivery

`python3 scripts/verify.py` passed on macOS 26.6.2 arm64 with Python 3.10. It ran 83 unit, 78 integration, 26 tooling and 58 asset tests with zero unexpected failures. Static and rejection checks passed. Both Rojo builds reconstructed 11,459 authored transforms. The release contained 67 runtime scripts and excluded native tests. Source and verification inputs match `a4babb37770f0b5654fc78d942265a4edd7fe98e` (tree `41421b19d10c769f02aa4d18bbf6046a604d3e70`). [Passing GitHub Verify #580](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/45389802948)

- Release build SHA-256 `01cefcd9797fb10a1ec7604c44167f56e01a7226551faa3b2b1aff88fd0c5879`
- Test build SHA-256 `7eb159581b643711df51d27f3bed8c97c96cd7684349cb72eb89f498383fb3a1`

The technical writer checked the player guide, source and asset contracts, and contributor setup and testing procedures against the implementation. The root README retains the selected Blender image and caption. P19 is on `plan/19-weapon-impacts` in [draft PR #67](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/67).

The separate normal-controls SDK attempt stalled before either client connected. The disposable child remained in Edit and was closed after Studio Stop and normal termination failed. The original local editor remained open and the SDK returned without a test result. Ordinary firing input, rocket-specific collision and expiry, and full rendered and listening review are still open. [Operated startup and cleanup receipt](../docs/evidence/p19/15ba235-operated-attempt.json)

### Candidate profile

The first profile attempt returned 3/4 cases. Both clients passed smoke and cleanup passed. One client's viewport missed the preflight deadline, so the workload did not run. [Preflight report](../docs/evidence/p19/468242d-profile-preflight.json)

The retry ran the full 300-second workload on the source-bound `468242d` test build with two actual Studio clients at a stable 1920×1080 and quality 8 on an Apple M1 Pro with 16 GB. It admitted 848 chain shots, 32 howitzer shots, 150 rifle shots and 71 rockets. Gunship p95 was **67.9 ms**, above the 33.3 ms budget, while Ground p95 was **18.0 ms** and server scheduler p95 was **0.7 ms**. Cleanup passed. The five-minute profile returned 3/4 cases. Of 352 sampled on-screen impacts, all were ready on the first `PreRender` after receipt. Each client peaked at five bursts and one active smoke trail. The frame probe measures readiness rather than first visible pixels. [Candidate profile report](../docs/evidence/p19/468242d-profile-candidate.json)

The paired baseline used the same profiling code with pre-P19 production source and the same device, quality and two-client Studio configuration. Reproduce its fixture from `40c97a9` with regenerated historical test metadata. The local comparison tree matched 170 scripts and five poses in Edit. It admitted 825 chain shots, 32 howitzer shots, 150 rifle shots and 71 rockets. All four checks passed. [Baseline profile report](../docs/evidence/p19/717608d-profile-baseline.json)

| Five-minute run | Gunship p95 | Ground p95 | Server scheduler p95 |
| --- | ---: | ---: | ---: |
| Baseline | 18.5 ms | 18.7 ms | 0.7 ms |
| P19 | 67.9 ms | 18.0 ms | 0.7 ms |
| P19 recheck | 25.7 ms | 67.5 ms | 0.7 ms |

The unchanged-source P19 recheck again passed 3/4 cases, with 800 chain shots, 31 howitzer shots, 150 rifle shots and 71 rockets. All 415 sampled on-screen impacts were ready on the first frame, with the same peaks of five bursts and one trail on each client. Two spot checks during this run showed the roughly 67 ms frame interval moving between clients, with near-zero reported GPU frame time during the slower intervals. The cause of the frame pacing remains unconfirmed. A5's client frame budget remains unmet, and the low-effects and five-reset acceptance remain open. The paired runs passed shutdown cleanup. The original device and graphics settings were restored in Edit. [Recheck report](../docs/evidence/p19/468242d-profile-recheck.json)

### Ordinary two-client retry

The independent tester ran `ExecuteMultiplayerTestAsync(2, {kind = "P19OperatedRetry"})` in the local document with unchanged gameplay source. The actual Gunship and Ground clients passed 19/19 smoke cases each, and the server passed 196/196. The tester selected M102 and fired with the published keyboard and mouse controls. A strike on empty terrain produced a contact burst on both clients with zero panel or health awards. A ground strike beside Sandbreak opened eight registered panels on the server and both clients, with Ground health still full.

The Ground avatar followed the walkable Seedship route, picked up the launcher at its authored location and fired through normal controls. Both clients observed the same rocket contact and burst. The Ground client measured a following smoke anchor about 0.9 studs behind the rocket, and the flight, trail and burst expired. Aircraft health remained 1,000. The native reset restored all eight Sandbreak panels to Pristine with one collider each on the server and both clients. Transient combat, audio and effect holders cleared. The original document returned to Edit with its simulator and selector restored. [Operated report and three local clip manifests](../docs/evidence/p19/15ba235-operated-native.json)

Required open evidence includes additional empty-ground surfaces and direct roof coverage in the focused battlefield matrix, rocket building and aircraft impacts and empty-air expiry, full rendered review at both thermal zooms and matched-volume listening, and the A5 client frame, low-effects and five-reset checks. The staged and operated captures document the tested scenes and audio playback.

The independent frame review found a visible flash at both sampled 40° thermal landings while the reticle, impact text and distant white target remained clear. The Ground clip shows the orange rocket contact. Smoke and fireball contrast were subtle at the reviewed distances. [Frame observations and local capture hashes](../docs/evidence/p19/15ba235-frame-review.json)

### Stronger impacts and revised howitzer tuning

At the user's request the next candidate reduces the howitzer radius from 36 to 25 studs, increases its single-shell reload from four to six seconds, and makes the impact effects easier to see. Full howitzer effects now use a bright expanding flash, larger fireball and a thicker smoke plume at operator distances. The 30mm and rocket flashes are modestly larger, with the heavy shell still distinct. The expanding flash and particle emitters remain client cosmetics with bounded pools. Reduced stays smaller and Off clears active visuals.

Source `49a54bbe68268aa668bbb78c281df51e1a3004d8` (tree `70c97ce0f27629ca901df880fb61d27b3b99cabf`) passed `python3 scripts/verify.py` on macOS arm64. The gate passed 83 unit, 78 integration, 26 tooling and 58 asset cases, including the 25-stud inclusive boundary and a six-second reload retained through weapon switching. Both builds and test isolation passed. The test artifact SHA-256 is `cd335e8b5387dc00ba037c97c77a41bd6396156ad1270059c18d1185cc18ede1`. [GitHub Verify #590](https://github.com/hanegraaff/roblox-c130-extraction-shooter/actions/runs/45401444576) passed on `8deaeec`, whose build and test inputs match the candidate.

The independent tester matched 176 scripts and five poses in the local Studio Edit document. The revised P05 case now targets four terrain surfaces, five landmark ground strikes and an elevated roof. The new Replay scenario sends live shell and rocket intents through five consecutive two-client resets and checks empty-air rocket expiry. The previous 36-stud combat and profile reports above retain their original source scope.

Both `ExecuteMultiplayerTestAsync(2, {kind = "P05"})` attempts stalled in Studio startup. Each child remained in Edit with zero clients after 90 seconds, so no gameplay assertions ran. The tester closed the two disposable children and then ran ordinary solo Play on the confirmed local source. Roblox Studio `0.748.0.7481526` passed **196/196 server** and **19/19 client** smoke cases, including the native 25-stud blast boundary and the revised Full, Reduced and Off effects checks. The one actual client used both operator zooms in a local cosmetic fixture. At about 380 studs the 40° Full howitzer flash and rising plume were distinct in the captured frames, while Reduced had a smaller flash and plume. The sampled 30° chain-gun contact was brief. These fixtures verify native presentation without authoritative fire or replication. The original test document returned to Edit with its ordinary selector and graphics settings restored. [Tuned Studio receipts and local capture hashes](../docs/evidence/p19/49a54bb-studio-tuning.json)

Fresh two-client combat and rocket flight coverage, five-round Replay, a measured performance profile, normal-input visual review and matched-volume listening remain open on the tuned source. No older test was reclassified as a tuned-candidate pass.

### Tuned normal-controls session

The independent tester used the tuned gameplay source in an ordinary local Studio **Server & Clients** session. The server passed **196/196** smoke cases and two players deployed. The operator fired the M102 at open terrain through the normal targeting and firing controls at 40°. The server recorded zero damaged panels, and both clients received the same contact and showed a Full flash.

The Ground player walked to the Seedship, picked up the launcher, and fired at terrain and the Sandbreak roof. Both clients observed rocket flight with smoke and the same Ground and Solid contacts. A third rocket fired into clear sky expired after about five seconds on both clients. It produced no contact, and no active rocket objects remained on the server or either client. Aircraft health stayed at 1,000 throughout these three shots.

The operator fired the 30mm at 30° and the howitzer at 40° with Reduced Effects while the Ground client used Effects Off. Both clients received the matching contacts. Reduced showed a smaller flash for both calibres. Off showed no matching visible impact parts. The tester captured local audio-bearing clips. Matched-volume listening, an aircraft rocket hit and an ordinary reset were outside this session's verified coverage. The coordinator ended the session after collecting evidence and confirmed the original document returned to Edit. [Two-client combat receipts and clip manifests](../docs/evidence/p19/49a54bb-operated-two-client.json)
