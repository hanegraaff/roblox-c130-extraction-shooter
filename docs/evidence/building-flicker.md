# Building surface flicker fix — 2026-11-08

The reported building flicker has concrete coplanar geometry causes: all three
ground-floor tops were exactly Y=0, coinciding with the battlefield surface, and
upper slabs/frame members shared overlapping same-facing planes. The original
source is rejected by the new surface checker.

## Source and correction

Tested source: `45e19963cfa5d4c7bdcf43ed01eddc77ec417a74`, tree
`adc3f9b13707adb2494ac726486dee278ed7ccc9`, branch `fix/building-surface-flicker`.
It is based on unmerged P13 source `588a500`, so [PR #13](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/13)
targets `plan/13-terrain-and-buildings` / [PR #12](https://github.com/hanegraaff/roblox-c130-extraction-shooter/pull/12).

- Raise building floors and relative story/panel/navigation geometry by 0.125 studs.
  Ground top is Y=0.125, upper top Y=10.125, roof center Y=20.625. Extend columns
  downward to keep their bases on the ground.
- Shorten beams to meet column edges and inset upper slabs/landings into the frame
  opening, removing positive-area coplanar intersections. The smallest main upper
  slab is now 19 studs wide, plus its adjoining landing/frame surfaces.
- Derive room/divider validation from actual floor height. Relative floor spacing
  remains ten studs; stairs retain sixteen 0.625-stud rises, two-stud runs and
  eight-stud tread width. Existing panel IDs and nominal building footprints remain.

## Verification

`python3 scripts/verify.py > build/building-flicker-verify.txt 2>&1` passes: **33 unit /
18 integration**, formatting/lint/strict types, both builds, 351 authored part
transforms per artifact, 111 panel pivots, rejection probes and release isolation.
The new exact rectangle-subtraction guard checks **7,146 opaque building-part
pairs**, permitting opposing contact faces, edge joins and overlaps concealed by
another opaque support. Three corruption probes reject ground-plane overlap,
overlapping frame/floor faces and duplicate wall panels. A separate invocation
against the original `origin/plan/13-terrain-and-buildings` world rejects the
reported Y=0 floor defect. [Full host log](building-flicker/verify.txt).

Studio 0.746.0.7461269, macOS arm64, local place 0, same existing document
`p02-tests-5c809beff70b.rbxlx`, instance `21f6fc11-4429-4148-9764-89a36987e5e9`.
The existing Rojo test server on 127.0.0.1:34872 delivered source into that document.
No additional Studio process or document was launched.

- Fresh Play: **67/67 server, 2/2 client**, zero errors/failures/skips, one actual client.
- A real server-owned Humanoid walked from the outside entry through all five
  navigation markers to the upper floor of Foundry, Warehouse and Outpost. It was
  staged only at each building's outside start, with no waypoint teleports during
  ascent. All three passes ended at root Y=13.1230; original pose/network ownership
  were restored afterward.
- All **58 mapped scripts** and **351 engine-loaded parts** match the candidate.
  Maximum CFrame component error is 0.0000142927 against 0.001 tolerance.
- Exterior and upper-floor inspection views show separated surfaces and clean
  structural joins. [Current building exterior](building-flicker/current-progress.jpg),
  [upper-floor/stair view](building-flicker/upper-floor.jpg). These are actual Studio
  Edit captures at 1886×1080; focused Play viewport was 1081×619, quality Automatic.
  Static captures supplement the geometric checks; no video-based flicker metric
  was measured. Source terrain was temporarily reconstructed for inspection, then
  the original terrain and camera were restored. Play was stopped in the original
  document and temporary capture state was cleared.

[Structured engine/source/geometry report](building-flicker/studio-report.json).
Documentation and the representative README image describe the current fix branch.
P13's previously recorded multiplayer/fresh-load gates remain open; this targeted
fix does not change roadmap status or claim those checks. No merge or Roblox
publication occurred.
