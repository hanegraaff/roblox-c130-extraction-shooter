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
