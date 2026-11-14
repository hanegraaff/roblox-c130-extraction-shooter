# Independent P17 preparation review — 2026-11-14

The bounded preparation candidate is suitable for a draft PR. P17 is incomplete:
the active battlefield still has the primitive Outpost, and no imported-art,
integrated navigation/performance or human-approval result is established.

## Sources and environment

- Initial tested source: `16ea1664d9d15b113fc9244c187a772969f54bc3`, tree `6f7efcff83e232c532d4c2cc404e9e9a19c0f2d1`.
- Corrected tooling/runtime candidate: `03c9c06c88b25d7d85fceed881ef8b25cc4e7e59`, tree `e3ee056df1dca3928fe3d53465f00480c9daf8fb`.
- The only Luau difference between those candidates is an ApprovedOutpost header changing “immutable” to “trusted”; executable data/code is identical. Independent comparison verified this.
- Studio `0.747.0.7471481`, original local `tests.rbxlx`, studio ID `e8a5a6d7-8d8c-4326-ab03-c3185048e07f`, test mapping through Rojo localhost:34872. Exact Source-string comparisons of all eight changed/new server modules matched the repository before initial Play.
- No source, tests, assets, baselines or documentation were edited by the tester. Diagnostic probes used temporary copies or destroyed unparented Instance fixtures. Reports below are ignored build artifacts for the coordinator to preserve.

## Consolidated findings

1. **P2, A1/R01/R19 — resolved:** initial `p17_assets.py` trusted a mutable package lock as approval. A disposable valid UV change to `corrugated_wall-pristine.obj`, coordinated lock refresh and regenerated descriptor/manifest passed both the P17 definition check and all seven P16 audits despite unchanged approved Blender/FBX/review evidence. Reproduction `/tmp/p17_export_probe.py`; initial evidence `/tmp/p17-export-probe-result.json`. The fix pins the exact package-lock SHA from approved commit e8fb840 before consuming any export. Independent `git show` hashing confirms `eda4926391d6c1f19d35186a4b8d56db13a6e3e36cda256e43be0e414210b3b2`. The original probe now rejects at `approved P16 input: package-lock.json` before generation; five focused P17 Python tests pass. Evidence `/tmp/p17-independent-export-fix.txt`.
2. **Required validation gap, A1–A6/R20:** approved cloud assets, ownership/access, actual catalog-loaded appearance, real integrated replacement and associated navigation/thermal/fragments/replication/reset/performance/human approval are unavailable. The new material engine fixtures explicitly use empty test-only cosmetic MeshParts and cannot satisfy these criteria. This is a disclosed access/dependency gap, not a passing replacement.
3. **Required evidence gap, A5:** the passing P08 harness self-ended before its server and two of three raw client smoke reports were collected. Only UserId −1's seven-case report was captured directly. Its complete eleven-case report proves three actual clients and the named launcher scenarios; it does not contain baseline reports. One separately authorized ordinary three-client baseline attempt connected only two actual clients. That separate session passed 164 server / seven on each of those two clients, but its third-client baseline remains unavailable. Neither the separate result nor readiness/dispatch preconditions are retroactive raw-baseline proof for the passing P08 session.

No remaining material implementation defect was found in the bounded preparation after the export-trust fix. No subjective approval of unimported art is given.

## Executed checks

| Check | Actual result | Evidence |
| --- | --- | --- |
| Independent `python3 scripts/verify.py` on 16ea166 | PASS: 59 unit, 65 integration, seven P16 audits, one P17 definition check, 26 asset regressions, ten manifest regressions; format/lint/strict types, both builds, probes, geometry and release isolation | `/tmp/p17-independent-verify.txt` |
| `python3 -m unittest discover -s tests/assets -p test_p17_assets.py -v` after correction | PASS: five cases, including coordinated export/lock/descriptor/manifest rejection | `/tmp/p17-independent-export-fix.txt` and tool results |
| `python3 scripts/p17_assets.py` on 03c9c06 | PASS: six families, 24 appearances, 24 fragment sources; `cloud_import_verified=false` | Tool result |
| Fresh ordinary solo Studio Play on 16ea166 | PASS: 164 server / seven client; one actual client; zero failures/skips/errors | `build/p17-solo-16ea166.json` |
| Missing-import preflight on 03c9c06 | PASS: material Model returns `missing approved material-panel assets`, without changing private tree or collision-group ownership; fixture destroyed | `build/p17-missing-import-preflight-03c9c06.json` |
| SDK `ExecuteMultiplayerTestAsync(2,{kind='P07'})` on 16ea166 | PASS: 7/7; two actual clients; fresh 164 server / seven per client. Both clients and server compare all 187 panels. Two damaged-to-pristine resets each begin with four live fragments and two pending projectiles | `build/p17-p07-sdk-result-16ea166.json` |
| SDK `ExecuteMultiplayerTestAsync(2,{kind='P05'})` on 03c9c06 | PASS: 8/8; two actual clients; fresh 164 server / seven per client | `build/p17-p05-sdk-03c9c06.json` |
| SDK `ExecuteMultiplayerTestAsync(2,{kind='P14'})` on 03c9c06 | PASS: 6/6; two initial actual clients; fresh 164 server / seven per client. GAU23/M102 each span a full orbit (90.99/90.93 seconds, all 16 bins); actual operator-departure assertion and teardown pass | `build/p17-p14-complete-03c9c06.json` |
| SDK `ExecuteMultiplayerTestAsync(3,{kind='P08'})` on 03c9c06 | Harness PASS: 11/11; initial/peak three actual clients, current two after client-leave; 149 traces, zero dropped. Raw-baseline capture limitation above remains | `build/p17-p08-complete-03c9c06.json` |
| Separate SDK `ExecuteMultiplayerTestAsync(3,{kind='P17Baseline'})` on 03c9c06 | INCOMPLETE: requested three, observed two after one bounded attempt; 164 server and seven per observed client pass; third client absent | `build/p17-separate-baseline3-03c9c06.json`, `build/p17-separate-baseline3-return-03c9c06.json` |

The P14/P08 complete reports were recovered in 20,000-character chunks because a single MCP return truncates above 100,000 characters. Both reconstructed full JSON reports parse successfully. Do not use the earlier truncated `build/p17-p14-sdk-03c9c06.json` as complete evidence.

## Final cleanup

Every owned SDK/Play session ended. The original tests.rbxlx is back in Edit,
RunService is stopped, ManualHarness is nil, BootstrapStatus is absent and all
five tester-owned P17QA result attributes were removed after preservation.
`Workspace:GetAttributes()` is empty, matching the initial Edit state. The final
Studio inventory contains only the original confirmed test document. A temporary
additional Edit document appeared during the final SDK launch and was left alone;
the owned server EndTest automatically removed all SDK-created children.

No asset upload, cloud save, game publication, merge or user-art approval was performed.

## Coordinator archive paths

The report above retains the tester’s original working-artifact paths. The committed equivalents are:

- [Initial independent host gate](independent-host-16ea166.txt)
- [Approval defect before correction](historical-export-trust-16ea166.json)
- [Independent approval correction recheck](independent-export-fix.txt)
- [Solo smoke](solo-16ea166.json)
- [Missing-import preflight](missing-import-preflight-03c9c06.json)
- [P07](p07-16ea166.json)
- [P05](p05-03c9c06.json)
- [Complete P14](p14-03c9c06.json)
- [Complete P08](p08-03c9c06.json)
- [Separate incomplete three-client baseline attempt](separate-baseline3-03c9c06.json)
- [Separate baseline return/cleanup report](separate-baseline3-return-03c9c06.json)
