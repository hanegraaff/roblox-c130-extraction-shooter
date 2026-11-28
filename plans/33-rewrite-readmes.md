# P33 — Write the C-130 Assault README

**Depends on** P26–P31. **Requirements** R15, R30. [Roadmap](../roadmap.md#mvp-completion) · [Requirements](../requirements.md)

The root [README](../README.md) is the learning guide for a reader who can work with Git and code but has never used Roblox, built a game or opened Blender. By the end they should be able to play a round, run the project locally and trace one player action through the code. Give the guide a dedicated writing pass and editorial review. The owner may choose the strongest available model for the writing pass.

## Required README outline

Use **C-130 Assault** as the title and these three main sections in order. Put each topic and its illustrations in the root document so a reader can follow it from start to finish.

### Game

1. **Game description and basic rules.** Walk through a round from lobby to result. Explain the two roles, their controls and objectives, what cover does and how each side wins.
2. **Screenshots.** Embed captioned captures from the tested build. Show what a Ground player sees when the C-130 arrives, what that same battlefield looks like through the operator’s thermal sights, and details of the lobby, landmarks and equipment that players can find.
3. **How to find the game on Roblox.** Give the title, current audience and verified experience link when available. While access is private, explain who can join and how an invited tester opens the experience. Give public discovery instructions once public access is verified.

### Project / Development Setup

1. **Set up for local development.** Explain what Roblox Studio, Rojo and Luau do. Take the reader from a clean checkout through branch selection, tool and dependency setup, and connecting the matching Rojo server and Studio plugin in Edit mode.
2. **Build and test.** Walk through both project mappings, ports and stable place files, play a round in both roles, sync a small edit into the same document and run the host and Studio tests. Give the expected result beside each command or Studio action.
3. **Publish to Roblox.** Show how to verify the production document against the tested build, select the intended experience and place, publish the game file and confirm the resulting place version. Explain how publishing a version and choosing its audience work. Keep the test place local.
4. **Invite test players.** Show the owner how to grant playtest access for the selected audience and share the experience link. Show the invited player which account to use, how to join and how to tell when a second player is needed to start.

### Game Design

1. **Anatomy of a Roblox game.** Briefly define an experience, a place, a running server and a player client. Use joining the lobby to explain what Roblox starts, hosts and replicates.
2. **Game architecture.** Map those concepts to this game. Follow one action, such as picking up a launcher, from client input through the server’s decision to what both players see. Explain the reason the server owns the decision.
3. **Code organization.** Map the actual repository paths to the Roblox services where their code runs. Explain each main package’s responsibility, where tests live and how Rojo connects files in Git to the objects in Studio.
4. **Code description.** Link a small selection of the most important scripts in the tested revision. For each, describe when it runs, what it does and a design choice it explains. Connect the round lifecycle, server rules and client presentation to examples the reader encountered in play.
5. **Blender models.** Explain how an editable scene becomes a model in the game. Embed a selection of model screenshots, including the chosen P16 `blender_outpost.png` with its Blender-authoring caption. Link the editable sources and pair at least one Blender view with the same asset in play.

## Acceptance

1. **A1 · Editorial and source review.** Read the root guide in the order above as a developer new to Roblox and game development. Check all twelve topics, first-use definitions, code explanations against the cited scripts, and local paths and heading links. Consolidate overlapping newcomer instructions in the root. Keep specialist API contracts, asset provenance and historical evidence available at their existing references.
2. **A2 · Newcomer walkthrough.** From a clean checkout, follow only the README to build both places, sync in Edit mode, play both roles, make a reversible local edit and run both test paths. Record and fix steps that required guessing, then repeat them. Check the publishing and invitation directions against the current owner workflow and the stated access mode. A documentation review can verify those directions without changing the live place or audience.
3. **A3 · Illustrated guide.** Read the rendered README on desktop and phone. Check that both screenshot sections display inline, every image has useful alt text and a caption, and readers can distinguish gameplay, Blender viewports and Blender renders. Trace gameplay captures to the tested revision and Blender images to their source scenes. Check the paired views show the same model.

Record the reviewed source, walkthrough results and any corrections in the completion record. Suitable gameplay captures can also be used in P34.

## Completion record

Planned checks have no results yet.
