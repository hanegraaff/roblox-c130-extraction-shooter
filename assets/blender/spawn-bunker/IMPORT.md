# Sandbreak native reconstruction

The approved Roblox upload inventory resolves the 32 source model batches. The earlier two-panel pilot calibrates native scale and the 180° correction about Roblox +Y. [Upload inventory](../../../docs/evidence/sandbreak-batch-uploads.json) · [Pilot receipt](../../../docs/evidence/sandbreak-pilot.json)

The Studio batch inspection reads the latest approved asset version for each row in the upload inventory, validates mesh identity, unscaled dimensions, centers and texture presence, and captures genuine Roblox mesh data. Collision profiles are created with Studio's precise convex decomposition and captured in the same native model format. `capture_native_batch.luau` writes chunks to a temporary folder in the isolated local place. Each batch uses the staged inspection rows in `native-index.json`.

Build the managed models from the resulting capture files:

```sh
python3 scripts/sandbreak/record_native.py
lune run scripts/sandbreak/assemble_native.luau build/sandbreak-import
python3 scripts/sandbreak/record_native.py --record
python3 scripts/p17_harness.py --write
python3 scripts/verify.py
```

The batch record includes Roblox asset and native version IDs, capture hashes and the upload binding. The generated `SandbreakBunker` and `SandbreakPanelVariants` model files belong under `assets/models`. The active map installs them before taking its pristine reset snapshot. It places the hall at `(0, 0, 120)`, attaches the roof and wall panels to the existing shelter registry, and keeps the nine deployment positions. Stable jambs own collision independently. Independent dressing stays outside weapon and thermal occlusion. The shared structural ledger presents the imported Light and Heavy states and supplies physical fragments and reset.

The local probe in `scripts/sandbreak/check_native_world.luau` exercises the actual managed assets once Rojo links the isolated test place. It checks the native roof breach, overhead spawn cover, all four approaches, representative damage states and reset. The operated client checks cover normal and thermal readability, entering and leaving the hall, and two-client replication.

## Studio verification

The isolated Edit probe rebuilt the 32 captured native batches in memory and used the current source installer at the deployment site. It verified one shelter registry, zero legacy panels, 225 protected spawn-sample columns and 252 clear approach rays. It exercised the shared damage ledger through Light, Heavy, Total and reset on one wall and one roof. Rollback restored the original shelter during the replacement validation.

A separate one-client Play preview used the same native geometry at a temporary location. A real Humanoid walked out of and into each entrance. The normal camera followed the Humanoid at its observed 12.5-stud distance in the hall. On that client, the production thermal presentation module hid 1,260 independent detail pieces, kept 873 structural visuals visible, and restored ground art on teardown. The Edit review caught overlapping ground and floor surfaces. Raising the finish and markings by 0.0625 stud removed the visible flicker while preserving ground collision.

The live Rojo-synced `tests.rbxlx` Edit DataModel repeated the placement and damage probe using the managed asset banks. Studio again found all 103 Sandbreak panels, zero legacy panels, 225 protected spawn-sample columns and 252 clear approach rays. [Machine-readable Studio results](../../../docs/evidence/sandbreak-studio.json) · [Exterior preview](../../../docs/images/spawn-bunker/studio-yard.jpg) · [Hall preview](../../../docs/images/spawn-bunker/studio-hall.jpg)

A native **Server & Clients** match passed all 198 server checks and all 14 smoke checks on each client. Both clients loaded the full 103-panel replacement. The Ground avatar spawned inside the hall. The Ground camera showed the yard dressing, and the operator's thermal view hid 1,136 marked details while retaining the sampled structural meshes.

The operator fired six M102 shots into roof panel `SB.R.07.07` through the production weapon remote. The server and both clients measured 203 blocked sample rays through Pristine and Light, 96 in Heavy and zero in Total. Ground surrender ended the round through the normal result and reset flow. All three peers saw the original cover restored, all 103 panels present, and no leftover fragments. The next deployment started with the pristine roof.

This is historical pre-P18 evidence. The current candidate rejects the `Sandbreak` selector before allocating runtime resources because it asserts the old damage thresholds. Reproduce that scenario from its recorded source revision. Current balance acceptance uses [P18 with three clients and the adapted P05 fire/flight regression with two](../../../docs/testing.md#run-the-p18-rebalancing-harness), plus actual avatar navigation and rendered cover review. The historical native selector was `ServerStorage.DevelopmentSettings.ManualHarness = "Sandbreak"`, with two clients and `Workspace.ManualSandbreakReport`; its recorded match used normal Studio controls after the launcher opened without that selector.
