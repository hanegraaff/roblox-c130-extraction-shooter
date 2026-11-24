# P19 — Weapon impacts, blast radius and audio

**Milestone:** Combat presentation. **Dependencies:** P05, P07, P08, P10, P11, P18. **Requirements:** R07–R09, R12, R14, R22 and proposed R23. [Roadmap](../roadmap.md) · [Design](../game-design.md#combat-cover-and-destruction) · [Decisions](../docs/decisions.md)

## Capability and player experience

A 105mm shell hitting the Sandbreak spawn bunker should produce one unmistakable explosion. The flash spreads across the wall, dust lifts off the surface, and the smoke thins to reveal a breach several small panels wide. A player behind intact cover at impact survives the blast. From the aircraft, the operator can see where the shell landed and aim the next shot through the opening.

| Weapon | Current game | Proposed experience |
| --- | --- | --- |
| 105mm M102 | Brief impact marker, 100 damage to an exposed Ground player within 18 studs, direct panel destruction | On terrain or a building, a fast fireball gives way to outward dust or chips and a fading smoke plume. Double the gameplay radius to **36 studs** and destroy exposed registered panels within reach. |
| 30mm GAU-23/A | Small impact marker, 4-stud player blast radius, persistent direct panel damage | Each impact reads as a small, directional burst of particles with a wisp of smoke. A burst of fire should trace its way across the surface without hiding the aim point. Keep the existing damage profile and two earned seconds of direct building-panel hits. |
| Ground rocket launcher | A short ribbon trail follows the projectile. Collisions already produce an impact sound. | Follow the rocket with a tapering smoke trail. On first contact with terrain, a building or the aircraft, end emission and show one flash, particles and short smoke tail at the contact point. Fade the existing trail on impact or expiry. |

**Rocket scope for review.** Apply the same quality, readability, performance and cleanup rules to rocket effects. The enlarged damage radius and panel demolition belong to the howitzer. A direct rocket still deals 100 aircraft health once. World hits and near misses deal zero aircraft damage. The M-7 is included in the sound pass.

## Implementation

1. **Resolve the blast against existing cover.** The current server profile defines the 18-stud M102 player radius. Use one 36-stud setting for exposed-player splash and structural reach. Align the M102 warning footprint and nearby Ground warning with that setting. Preserve 100 base damage, the existing exposure check, firing cadence and reload. [CombatService](../src/server/CombatService.luau) · [CombatRuntime](../src/server/CombatRuntime.luau) · [PresentationEffects](../src/client/PresentationEffects.luau)
2. **Choose the panels once per impact.** Always include the directly hit registered building panel. For a terrain or building hit, query nearby live panel colliders and use the nearest point on each remaining solid surface. Include the panel if that point lies within 36 studs inclusive and is visible from just outside the impact surface on the incoming side. Use the actual registered pieces so a large panel can qualify by its edge and a hole is not treated as a solid face. Gather unique panel IDs and player awards against the geometry at the start of the damage batch. Carry the panel set as one accepted shot through the ordered destruction service and apply Total once per panel. A newly opened wall first benefits a later batch. Stable supports, floors, stairs and the outside lobby remain protected. Keep the existing physical fragment budget across the whole burst. [DestructionService](../src/server/DestructionService.luau)
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
| A1 · M102 reach and cover | Extend `CombatService` and `DestructionService` tests. For exposed players and panel surfaces, check just inside, exactly at and just beyond 36 studs, including a target beyond the old 18-stud limit. Check a terrain strike beside a wall, a direct strike spanning neighboring panels, an intervening wall, overlapping panel pieces, and two shots resolved in one batch. Each eligible target is affected once. Duplicate, stale, rejected and post-deadline shots produce no damage. |
| A2 · Real openings | In a Studio server with two actual clients, fire through normal controls at a named small Sandbreak panel. Record the direct, adjacent, shielded and outside-radius panel IDs before and after. Both clients see the same breach, a ray passes through it, and the shielded player was safe on the opening shot. Repeat on another building and verify supports, the lobby, fragment caps and pristine reset. |
| A3 · Distinct impacts and rocket flight | Add a Studio impact-cue suite covering 105mm and repeated 30mm on terrain and building surfaces, and rockets against the aircraft, terrain, a building and empty-space expiry. Check one cue per contact, trail start/stop, no impact on expiry, fixed direct rocket damage, no rocket demolition and unchanged 30mm progression. Simulate duplicate or delayed cues and replay into a new round. Verify teardown and stale-cue rejection. |
| A4 · Readability and audio | With Ground and operator clients, identify each weapon from sound alone and compare the proposed mix with the current mix at matched volume. Verify nearby versus distant playback, reduced effects, mute, text warnings and missing-asset fallback. At both thermal zooms check the reticle, white targets, solid cover and newly opened sight lines during a burst. Record Ground and thermal clips with audio and observations. |
| A5 · Responsiveness and cost | Compare baseline and candidate using the same five-minute P11 workload, hardware, two actual clients, 1080p and quality 8. Include sustained 30mm, multi-panel howitzer blasts and concurrent rocket trails. Record per-role p95 frame time (≤33.3 ms), server scheduler p95 (≤16.7 ms), peak resources and impact receipt-to-first-visible-frame latency (proposed p95 ≤2 rendered frames at normal intensity). Exercise low-quality effects and five resets. Active transient counts return to baseline and pools stay bounded. Run the full host gate with `python3 scripts/verify.py` and the affected native combat, destruction, launcher and presentation regressions. [Testing procedure](../docs/testing.md) |

## Focused human check

From Ground, follow a rocket from launch to contact and watch the edge of a bunker breach while 30mm fire continues nearby. From the operator seat, track an exposed target beside the impact, then aim through the breach as smoke clears. Review the clips with sound muted to judge visual cues, then listen without video to judge the mix. Record which shots are hard to locate or distinguish and whether smoke hides a target, warning or opening long enough to interfere with the next action.

## Documentation changes

On implementation, update the player guide, weapon profiles and cover rules, the client/server package contracts, asset provenance, and the testing guide with measured budgets and evidence.

## Completion record

Reserved for implementation after plan approval. Gameplay checks, Studio captures, audio auditions and performance measurements are unrun.
