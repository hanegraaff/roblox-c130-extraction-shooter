# P33 — Write the C-130 Assault README

**Source dependencies** P26–P31. **Requirements** R15, R30. [Roadmap](../roadmap.md#mvp-completion) · [Requirements](../requirements.md)

The root [README](../README.md) showcases C-130 Assault and serves as the complete guide for a reader who can work with Git and code but has never used Roblox, built a game or opened Blender. By the end they should be able to play a round, build and test the project locally, publish it with their chosen audience and trace one player action through the code. Give the guide a dedicated writing pass and editorial review. The owner may choose the strongest available model for the writing pass.

Describe the game and project as they exist today, in a consistent voice. Subfolder READMEs can expand into package contracts, fixture operation, asset provenance and reconstruction details. The paths readers commonly take should be complete in the root guide. Condense the [roadmap](../roadmap.md) around the major stages in the game's development and the remaining milestones. Keep plan status and links there, with implementation details, verification and traceability in the individual plans and evidence records.

Use the integrated rocket launcher source for this guide. The launcher plan's pending desktop and phone fit review and its deferred final-MVP multiplayer acceptance remain tracked in its [completion record](29-rocket-launcher-model.md#completion-record).

## Required README outline

Use **C-130 Assault** as the title and these three main sections in order. Put each topic and its illustrations in the root document so a reader can follow it from start to finish.

### Game

1. **Game description and basic rules.** Walk through a round from lobby to result. Explain the two roles, their controls and objectives, what cover does and how each side wins.
2. **Screenshots.** Embed captioned captures from the tested build. Show what a Ground player sees when the C-130 arrives, what that same battlefield looks like through the operator’s thermal sights, and details of the lobby, landmarks and equipment that players can find.
3. **How to find the game on Roblox.** Give the title, current audience and verified experience link when available. While access is private, explain who can join and how an invited tester opens the experience. Give public discovery instructions once public access is verified.

### Project / Development Setup

1. **Set up for local development.** Explain what Roblox Studio, Rojo and Luau do. Take the reader from a clean checkout through branch selection, tool and dependency setup, and connecting the matching Rojo server and Studio plugin in Edit mode.
2. **Build and test.** Walk through both project mappings, ports and stable place files, play a round in both roles, sync a small edit into the same document and run the host and Studio tests. Give the expected result beside each command or Studio action.
3. **Publish to Roblox.** Show how to verify the production document against the tested build, select the intended experience and place, publish the game file and confirm the resulting place version. Include two step-by-step owner walkthroughs, one for keeping a published experience private with invited access and one for releasing it publicly. Explain audience settings and public publishing eligibility using current Roblox documentation. Show how to verify access in each case. Keep the test place local.
4. **Invite test players.** Show the owner how to grant playtest access for the selected audience and share the experience link. Show the invited player which account to use, how to join and how to tell when a second player is needed to start.

### Game Design

1. **Anatomy of a Roblox game.** Briefly define an experience, a place, a running server and a player client. Use joining the lobby to explain what Roblox starts, hosts and replicates.
2. **Game architecture.** Map those concepts to this game. Follow one action, such as picking up a launcher, from client input through the server’s decision to what both players see. Explain the reason the server owns the decision.
3. **Code organization.** Map the actual repository paths to the Roblox services where their code runs. Explain each main package’s responsibility, where tests live and how Rojo connects files in Git to the objects in Studio.
4. **Code description.** Link a small selection of the most important scripts in the tested revision. For each, describe when it runs, what it does and a design choice it explains. Connect the round lifecycle, server rules and client presentation to examples the reader encountered in play.
5. **Blender models.** Explain how an editable scene becomes a model in the game. Embed a selection of model screenshots, including the chosen P16 `blender_outpost.png` with its Blender-authoring caption. Link the editable sources and pair at least one Blender view with the same asset in play.

## Acceptance

1. **A1 · Editorial and source review.** Read the root guide in the order above as a developer new to Roblox and game development. Check all twelve topics, first-use definitions, code explanations against the cited scripts, and local paths and heading links. Confirm the root guide can be read from start to finish, subfolder READMEs add specialist detail, and the project narrative describes the current experience without a plan-by-plan recap. Check that the roadmap tells the overall development story and preserves plan status and links to detailed records.
2. **A2 · Newcomer walkthrough.** From a clean checkout, follow only the README to build both places, sync in Edit mode, play both roles, make a reversible local edit and run both test paths. Record and fix steps that required guessing, then repeat them. Check both private and public publishing walkthroughs and the invitation directions against the current owner workflow and the stated access mode. A documentation review can verify those directions without changing the live place or audience.
3. **A3 · Illustrated guide.** Read the rendered README on desktop and phone. Check that both screenshot sections display inline, every image has useful alt text and a caption, and readers can distinguish gameplay, Blender viewports and Blender renders. Trace gameplay captures to the tested revision and Blender images to their source scenes. Check the paired views show the same model.

Record the reviewed source, walkthrough results and any corrections in the completion record. Suitable gameplay captures can also be used in P34.

## Completion record

### 2026-11-28 · Guide and walkthrough

| Criterion | Observed result |
| --- | --- |
| A1 · Editorial and source review | The independent tester reviewed all twelve topics against the mappings, runtime, control handlers and asset records. They checked 47 local README references and incoming README and roadmap anchors. Corrections included the current Studio testing toolbar, the private playtest link, and when to check the audience of an existing destination. The roadmap keeps its plan index and links to detailed evidence. Package and test READMEs retain specialist procedures and contracts. |
| A2 · Newcomer walkthrough | From a clean checkout, `python3 scripts/setup.py` and `python3 scripts/verify.py` produced both stable builds. A fresh local production document started in the protected lobby with **Waiting for 2 players** and no test panel. In the synced test document, changing the duration label in `HumanTestPanel.luau` reached the same Edit document, showed **Sync check: 60 seconds** in fresh Play, and reverted to **Next round: 60 seconds**. Solo smoke passed 219 server and 24 client cases. The ordinary multiplayer playthrough used two actual Studio clients, passed 219 server and 24 client cases on each client, and exercised Ground movement through the bunker exit, aircraft arrival, thermal weapon selection and a howitzer shot. The server and both clients agreed on the operator win by timeout and returned to the lobby. Both private and public directions were reviewed against the current Roblox workflow. |
| A3 · Illustrated guide | Independent review rendered the guide with GitHub-flavored Markdown and Chrome 158.0.8127.89 at 1280 × 1050 and 390 × 844. All seven images loaded with alt text and adjacent captions at both sizes, with no page-width overflow. The matched gameplay views share the active clock and Ground player. The reviewer matched the Outpost's teal facade, stairs and balcony in its authoring viewport and Studio image, and checked the separate Blender render and remaining gameplay sources. Reviewed README Git blob `bcbcdd13a686ec67350f1206913d947584f829ee`. |

Local verification used macOS 27.2.1 arm64, Rojo 7.7.1 and Roblox Studio 0.748.0.7481526 on runtime tree `81636ea6e00ded92f599b4f1bdbb38fefd81b869`. The host verifier passed 101 unit, 103 integration, 27 tooling and 81 asset regression tests, seven Blender package audits, formatting, lint, strict type analysis, expected rejection probes and artifact isolation. It inspected 14,726 release and 14,813 test transforms and found 80 runtime scripts in the release place. Both Studio sessions returned to Edit. The existing game-named window contained the test mapping, which the mapping check caught. The production check used the clean artifact in a separate local document. The ordinary multiplayer session used `StudioTestService:ExecuteMultiplayerTestAsync(2, {})` to open the native clients and the README's test panel controls to play the rounds.

| Place file | SHA-256 |
| --- | --- |
| `build/game.rbxlx` | `b996dd626e82f627606cd941bcfb5990d53707a4a58bda3a9a1490a72fedf45c` |
| `build/tests.rbxlx` | `71433c0eccbbdba2609eaf159017ce350fb1cfdcdd4a43691a2a2c361a2cd4b1` |

The availability section reflects the last verified private owner playtest. The review confirmed Studio's **Open from File**, **Publish** and **Publish As** menu entries and checked version, audience and collaborator steps against current Creator Hub documentation. No Roblox upload, audience change or new live access check was performed. [Publishing and audiences](https://create.roblox.com/docs/production/publishing/publish-games-and-places) · [Version history](https://create.roblox.com/docs/projects/version-history) · [Collaboration permissions](https://create.roblox.com/docs/projects/collaboration)

### Gameplay captures

Both images are from the same active local round with two Studio clients on runtime source `fc8febb13d25189d21d9c28a42f9f4525af5990d`. The Ground player walked through Sandbreak's north opening during the head start. Studio's testing panel was hidden locally for the captures. The Ground camera was framed on the circling aircraft with a temporary client camera override. The operator image uses the normal thermal camera and shows the same player in white. Both images are 1787 × 1080 Studio captures.

| View | Capture | SHA-256 |
| --- | --- | --- |
| Ground after arrival | [Ground](../docs/evidence/p33/ground.jpg) | `b8f6e05a0b5d44c14708854db26e404c0b4c0d45f0d9336200ec51d3192e7c45` |
| Operator, 30mm | [Thermal](../docs/evidence/p33/thermal.jpg) | `d7725b7a5d952b7e03ae4c5c424f9ab3755b0abdae7c148c25e29b90811026d4` |
