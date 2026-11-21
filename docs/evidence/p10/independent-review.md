# Independent P10 review

Native acceptance ran on `23bf7ba2bcda17dc45b68b610d2f3628e8e94249`, tree
`97b7f6edc3640a4e1d012b8a38c2509653c3490c`, Rojo test artifact SHA-256
`722a81d5c11431eaa36ec062b0334d78a129eb9113c73c3910d1a5c9b639c912`. The
ordinary two-client operation used `61c63c95dba705a90b0e66b42858bf3780db5558`,
tree `8352f82aba74f681b4fd1227298c53f2506a8d77`. Only P10 harness code and
fixture binding metadata changed between those revisions. Both ran in Studio
0.748.0.7481526 under macOS 26.6.2 (25G83), arm64.

| Criterion | Independent verification |
| --- | --- |
| A1 | `lune run scripts/run_tests.luau unit` passed 77/77. The eleven new view-model tests cover roles and phases, elimination, stale results and forfeit, empty spectator targets, readiness, launcher feedback, local rejection and effect levels. `lune run scripts/run_tests.luau integration` passed 73/73. The parent ran the full host gate. |
| A2 | The four-client harness checked authoritative HUD readiness, both exact named aircraft profiles at 30° and 40°, ground ammo and rejected full magazine reload. Native keyboard H/P and settings arrows passed. Ordinary role operation checked both exact desktop sizes using HD 720/1080 with ActualResolution on live clients. Eight samples covered HUD and Help in both roles and sizes, plus Settings in Ground at 1080p and Operator at 720p. Each sample had no out-of-bound or clipped text and no overlap among measured text controls. The two live visual captures confirmed readability. |
| A3 | Four-client elimination switched from one actual living teammate to another, cycled back and moved on when the watched teammate died. Spectator rifle, pickup and aircraft selection requests caused no authority mutation. Terminal view used the inert neutral subject before normal Lobby views returned. The per-client Studio smoke case separately exercised the no-target branch with an intentionally empty round identity and checked the camera-subject teardown. Runtime teardown removed controls and neutral subjects on all four clients. |
| A4 | H/P and keyboard arrows set both local settings to Off. The four-client test checked zero mutation to aircraft, launcher and Ground rifle authority and a visible muted incoming warning with no cue pulse. A separate replay produced the aircraft-destruction result and persistent readable cue, with the camera steady during the sampled destruction window. Ordinary gunship operation rendered impact and panel-impact text. Both referenced Roblox sounds loaded in actual Studio clients during the ordinary session. |
| A5 | Manifest references the original Luau effect recipe and both Roblox-bundled sounds plus their ownership. Both references existed in the installed Studio and Player resources. The host artifact check verifies mapped scripts and absent test-only modules in release. No external asset or script import was needed. |

The native acceptance command was
`StudioTestService:ExecuteMultiplayerTestAsync(4,{kind="P10"})` in the local
Edit document. All eight discovered cases passed on four distinct actual
clients with zero failures or skips. Tests independently reported 191/191 server
smoke and 13/13 on each actual client. The initial attempts exposed fixture
formatting of Vector2, a disabled ScreenGui whose child visibility flag stayed
true, and an in-script VirtualInput restriction on Roblox's built-in inventory
hotkey. The corrected fixture exercised the actual equipped Tool and server
acknowledgment, and the ordinary MCP native input confirmed the normal One
and Two player actions. The three earlier reports remain scoped to their
failed fixture runs.

The ordinary round used only the labelled test panel and native role input,
apart from a temporary local Camera render binding to track the moving Roblox
aircraft while sending the three actual Ground pointer shots. Starting from
an actual available launcher, Ground used E/Two, fired one practice rocket
and read the reload, then registered three server-owned direct rocket impacts
taking aircraft health 300 → 200 → 100 → 0. Operator panned with W and D at
40° and 30°, respectively, and fired the 105mm at live terrain and a Foundry
panel. The panel advanced from Pristine to Light, and the local HUD displayed
the panel-impact cue and reload. Both clients returned to Lobby with their own
Custom camera, no active combat HUD or ThermalHUD, and fresh aircraft health
300. Ordinary operation did not continue that panel to Heavy/Total or capture
physical debris, and the later SDK aircraft destruction had settings Off.
The live 105mm HUD read `1 rounds ready`, a copy issue without lost meaning
or clipping. No material P10 defect remained in this review.

The SDK session returned to the sole local tests.rbxlx document in Edit.
Device simulation was off and the temporary workspace report attributes and
ManualHarness selector were clear. The original document was handed back to
the parent for further P07 regression and delivery.
