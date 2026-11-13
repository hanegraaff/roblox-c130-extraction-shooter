# P07 destruction verification

Implementation selected on 2026-11-13 on `plan/07-destruction`, from main
`e4c6e3a2506a9e9ac5574bdf42242f77f8200650`. P06, P13 and P14 are integrated.
This record will preserve candidate hashes, actual results, defects and limits;
the existing baseline does not validate newly implemented destruction.

Required environments are the full host gate, real Studio geometry/collision/
thermal/physics checks, two actual clients plus a late join, repeated resets,
and focused operated review. A representative actual destruction capture must
replace the README image after visible behavior stabilizes.

The existing `tests.rbxlx` Studio instance
`eea79821-d1ee-47bb-b6c6-cdf494d9ba94` was confirmed in Edit. The same test
document and Rojo `PlayersVsC130Tests` mapping on port 34872 will be reused.
Source and live-place ownership transfer explicitly between developer and tester.
No P07 suite has run at selection; no completion or publication is claimed.

Before writing/running new tests, the developer proposed and the primary agent
recorded D46–D48: firedAt-based consecutive accepted outcomes (including explicit
miss/expiry), 0.225-second maximum gap, zero first-impact credit, 1e-7 threshold
tolerance, capped stage credit with uninterrupted timing retained across stages;
central 50% opening; four fragments/transition, 48 live, eight-second lifetime,
launch at most 12 studs/second and 4 radians/second. Rejected requests leave
progress unchanged. Geometry/player-damage queries finish their batch before
residual geometry swaps. These defaults precede candidate test results.

## Development checks before a stable candidate

On the uncommitted development source, the developer's first focused Lune unit
run passed 54/54 (four new P07 cases). The integration run discovered 50,
passed 49 and failed one: exact repeated 0.15-second aircraft cadence exposed
floating-point readiness comparison rejection. The seven new destruction-ledger
cases passed in that run. This is a recorded failed development check, not a
passing full gate or engine result. The developer applied the pre-recorded
D46 readiness tolerance before the next full gate; independent verification
and exact stable source hashes remain pending.

For A6, read-only testing research found the official testing guide describes
live client-count adjustment, but the installed UI route is unverified. The
planned manual harness starts with two actual clients, records accumulating/
Damaged/Destroyed panels, waits for old debris to expire, then publishes an
explicit late-join checkpoint without resetting. A genuinely new third player
must join afterward and spectate the same round. Initially connected players
will not be relabeled as late joiners; this required check is still unrun.

## First committed candidate and independent findings

Source `e577ee4e0f364fb6084d096627cf1b4b23dae6a7`, tree
`9f357932834b7364760f8c3a2ead6bfa9893d0ba`, snapshots the first compiled
implementation. The developer's host gate passed 54 unit / 51 integration
with 353 authored part transforms per build; clean solo Studio passed 134
server / 6 client. Earlier development runs executed their named cases but had
a stale Edit `ReplicatedStorage.BootstrapStatus` left by the prior low-level
Run diagnostic. The developer preserved that inventory, removed only the
confirmed runtime folder and reran cleanly: actual Uptime advanced 13→33,
Running stayed true and no new bootstrap-ownership error appeared. No
production-code workaround was added. Direct Run cleanup must cover runtime
instances as well as Workspace attributes.

Independent pre-launch review reproduced a high-priority A2/A7 defect with the
actual DestructionService: 61 valid shots at 0.15-second cadence with 0.6-second
flight should complete nine seconds, but the adapter's idle wall-clock cutoff
discarded the valid in-flight tail and left progress zero. D49 records an
ordered interruption barrier correction before its new regression tests.
The tester also confirmed the unrun manual harness needed an authoritative
M102 readiness wait after traversal, and P05/P14 upper-panel helpers still
assumed BasePart registry roots instead of the new Model representation.
These are unresolved findings on the first candidate, not a multiplayer pass.
Actual creating-shot player protection and rendered thermal review also remain
required beyond the current geometry/batch helper checks.

A fourth adapter defect was confirmed before launch: a string PanelId on
unregistered/permanent cover was passed to the strict ledger, whose correct
unknown-ID rejection left the accepted shot frontier unresolved and stalled
later panel outcomes. The adapter must classify the actual current registered
model/descendant identity and consume other valid impacts as nonstructural
outcomes; direct malformed service inputs still reject without mutation.
The developer owns all four targeted corrections while the tester holds
read-only. The original [flight-tail reproduction](p07-flight-cutoff.txt) is
preserved separately from subsequent results.


## Corrected frozen candidate and independent checks

Candidate `cb530a0175f683f933d93fa7546b377614788c39`, tree
`9bfcf88f9c52dbfd57db77858ed7ad56ebc337eb`, fixes the four findings above.
D49 specifies the ordered interruption barrier; terminal cancellation still
invalidates all pending outcomes. Runtime/tests/assets scope SHA256 is
`62872c861b1c3ad6703b408b5df3ef4548fb68df8f2345f006135bb9b975554e`
over 103 files. The [candidate metadata](p07-candidate-cb530a0.json) and
[independent file hashes](p07-source-files-cb530a0.json) identify that scope.

The developer and independent tester each ran `python3 scripts/verify.py`
against unchanged candidate source: exit 0, **54 unit / 53 integration**,
zero suite failures/skips. Formatting, lint, strict type analysis, builds,
expected-failure/empty-suite/type/artifact-corruption probes and release/test
isolation checks passed. Each artifact contained 353 authored parts;
artifact inspection covered 7,146 visible-part pairs, 432 release / 515 test
Instances and 40 release runtime scripts. Environment: macOS 26.6.2 arm64,
Python 3.10.4, pinned Rojo 7.7.1, StyLua 2.6.0, Selene 0.32.0, Lune 0.11.1,
Wally 0.3.2 and luau-lsp 1.70.1.

The [corrected flight-tail reproduction](p07-flight-cutoff-corrected.txt)
executes the actual service: the original timestamp-cutoff schedule remains
stage 0, while the corrected ordered accepted prefix reaches stage 1 after
nine accepted seconds plus 0.6 seconds of flight. Committed integration tests
also cover partial-prefix clearing, no bridging/resurrection and terminal
cancellation. This is deterministic service evidence, not a multiplayer run.

On Studio 0.747.0.7471481, both independently started ordinary solo Play
sessions passed **137 server / 6 client**, zero failures/skips/errors. The
[developer report](p07-developer-clean-studio-137.json) records first actual
client at 0.148815 seconds and Bootstrap Uptime 13→31; the
[independent report](p07-tester-clean-studio-137.json) records 0.141554 seconds
and Uptime 11→23. Both ran from a clean Edit document with no bootstrap-ownership
error. The tester compared all 97 mapped script lengths and rolling hashes
against local source with zero mismatches; the external SHA256 manifest is
separate. An existing asset-type mismatch for `rbxassetid://203785492` was
observed in console. Signed-in user identifiers are redacted in saved reports.

Named engine tests include all-111-panel geometry/identity/support checks,
actual fragment fall/contact/group/query/avatar/cap/lifetime assertions,
registered-impact classification, geometry-batch pre-impact queries and
repeated map/reset cleanup. The pre-impact helper case does **not** yet prove
creating-shot actual-player blast protection or rendered thermal readability.

Native two-client/actual late-join checks, actual-player blast checks,
P05/P14 multiplayer regressions, operated readability and the new representative
capture remain pending. The same original Edit document was returned clean,
then armed with test-only `ManualHarness='P07'` for the requested native launch.
No P07 completion, merge or Roblox publication is claimed.
