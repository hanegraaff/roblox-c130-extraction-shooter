# Pure rule suites

`Config.spec.luau`, `Validation.spec.luau` and `RateLimit.spec.luau` cover P01/R01/R13 finite inputs, exact boundaries, malformed/oversized payloads and injected-time token accounting. Rejected calls must preserve input or rate state; valid requests still succeed afterward.

`MapRules.spec.luau` covers finite/matching circular map configuration, the inclusive combat disk, 720-stud diameter/equal-radius orbit and sampled poses. `RoleService` and `RoundRules` cases exercise production populations, deterministic rotation, phase/deadline and outcome ordering. Aircraft and building-layout cases cover the canonical orbit, distinct lenses, server aim envelope and versioned panel authoring.

`AircraftPanRules.spec.luau` now targets P18/R05/R06/R17: full world-square focus at both lenses, labelled movement directions, edge sliding/reversal, orbit samples including near-overhead views, held map focus, bounded frame-time/diagonal movement, invalid inputs, translated levels and reticle rasterization. These are math tests; native input and camera feel require Studio.

`PanelDamageRules.spec.luau` targets P18/R09: one-howitzer Total, exact one/two-earned-second 30mm boundaries, fractional surplus, persistent interrupted/mixed credit, invalid elapsed time and irreversible Pristine/Light/Heavy/Total appearance. It does not establish collision, physical fragments or rendered distinction.

`PlayerPresentation.spec.luau` covers role and phase, result reasons, empty
and changing spectator targets, launcher/readiness feedback, rejected actions
and effects settings. `WeaponSoundRules.spec.luau` covers positional playback
timing and stale or out-of-range cue rejection. Native layout, targeting and
keyboard behavior have separate Studio checks. [Player experience harness](../../docs/testing.md#run-the-player-experience-harness)

`P11Metrics.spec.luau` drives the test-only metrics module in Lune. Three
cases cover empty and invalid frame samples, upward-rounded nearest-rank p95
with overflow, and retained-memory growth at equivalent reset points. The
actual timing and memory measurements are collected from Studio processes.
[P11 procedure](../../docs/testing.md#run-the-p11-performance-harness)

Run `lune run scripts/run_tests.luau unit` from the repository root after setup, with Rokit tools on PATH. Each spec returns a function accepting `(test, actualModule)`; it does not copy production rules. The standalone runner discovers these files and loads filesystem modules. The Studio server wrapper registers the same cases with TestEZ using mapped ModuleScripts, proving dependency loading in both runtimes.

Authoritative RoleService/RoundRules load from the server package in Lune and Studio; they are not replicated for testing. Add deterministic gameplay rule cases as their plans implement them. Inject clocks/randomness and test observable boundaries rather than private implementation details.
