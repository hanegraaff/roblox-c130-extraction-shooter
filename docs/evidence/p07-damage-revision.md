# P07 damage revision — 2026-11-13

The user removed the real late-joining-player scenario from current P07
acceptance and reported three remaining issues: Light/Heavy damage was not
visually distinct, the battlefield starting shelter stayed immune, and 30mm
damage disappeared after stopping fire. The user clarified the shelter is the
battlefield spawn structure, not the outside waiting lobby.

Dedicated branch `fix/p07-progressive-persistent-damage` starts at
`ebf5bd4d19a1237ccc346479c0d5dea282616058`, containing unmerged dependency
[PR #29](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/29).
Main remains `e4c6e3a2506a9e9ac5574bdf42242f77f8200650`. No previous gate
count is a pass for this changed behavior. No merge/publication is authorized.

## Confirmed source causes

- `PanelDamageRules.interrupt` zeroed sustained credit. Idle, miss/target,
  selection/reload and eligibility barriers eventually called it, causing
  partial damage and its appearance to heal.
- `PanelGeometry.publish` based appearance only on stage-local progress.
  Completing a stage reset that progress to zero and restored the original
  color/material, despite a Heavy structural state.
- All nine Ground anchors deploy inside the legacy shelter. Its seven
  colliders were in `Battlefield.Permanent`, while DestructionRuntime captured
  only the three multi-story building registries. Every shelter impact was
  therefore nonstructural. The other 111 panels were registered correctly.

## Steering recorded before new tests

D50 waives the real late-join test without deleting runtime spectator authority
or relabeling old timeouts as passing. D51 selects persistent per-panel earned
credit and continuity-only interruptions. D52 selects distinct Pristine/Light/
Heavy/Total appearance, retaining three/six heavy-hit and nine-second stage
thresholds. D53 records faithful starting-shelter panelization: 42 roof and
34 wall panels replacing all seven old colliders, preserving union/entrances/
anchors and yielding 187 total panels. D54 records the proposed grayscale-safe
crack/luminance/material defaults before implementation tests. These dimensions,
colors and counts are tuning defaults; clear progressive damage and complete
building coverage are user requirements.

Required fresh checks include deterministic persistent damage across all break
causes and alternating targets, ordered in-flight/barrier/terminal/reset cases,
engine visual/collider/query distinctions, complete shelter union/registry and
spawn protection, actual two-client progression/replication/reset and focused
normal/thermal/native-firing review. The existing Edit document
`eea79821-d1ee-47bb-b6c6-cdf494d9ba94` and Rojo port 34872 are retained.

The old [P07 evidence](p07-destruction.md) remains historical and source-specific.
No revised implementation/test pass is claimed at this steering checkpoint.
