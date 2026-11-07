---
name: implement-next-plan
description: Implement one eligible roadmap plan for this Roblox C-130 extraction shooter using developer, tester, and technical-writer subagents, with automated and Studio evidence and GitHub delivery. Use for the full next-feature loop, not design-only work, isolated edits, or review-only requests.
---

# Implement the next plan

Deliver one complete capability from this repository's roadmap. The primary agent coordinates plan selection, integration, evidence and GitHub delivery. Delegate implementation, independent testing and documentation to the three project roles. Keep the loop small; do not add a separate planning/review committee or run the entire roadmap.

## 1. Select or resume

Read `AGENTS.md`, `game-design.md`, `requirements.md`, `architecture.md`, `roadmap.md`, `docs/testing.md` and the selected plan. Inspect local changes, branch, remote and any existing plan PR before changing state. Preserve unrelated work.

Resume the current In progress plan first. Reassess a previously Blocked plan when new evidence or user input may have cleared its blocker; resume it only when the missing condition is actually satisfied. Otherwise select the lowest-numbered Ready plan with Complete dependencies. If needed, promote the first Planned plan whose dependencies are complete. Do not bypass an unresolved Blocked prerequisite. If no plan has satisfied roadmap dependencies or all are complete, report that fact; do not invent post-MVP work. User-directed plan/scope takes precedence, but explain any unsatisfied dependency before dependent implementation.

Before implementation, resolve the selected plan's dependency source. A dependency's open PR may contain required source absent from main: use a branch containing that source or resolve integration first. Absence from the current branch is an integration step, not proof that no plan can be selected. Create/reuse a `plan/NN-short-name` branch unless the user chose another. Reconcile remote changes without discarding local work. Mark only the selected plan In progress in `roadmap.md` and identify its acceptance criteria and required test environments.

## 2. Develop, test, fix

1. Delegate to **`feature_developer`**, using `.codex/agents/feature-developer.toml`. Give the plan, requirement IDs, architecture constraints and ownership of source/configuration/tests. Ask for working implementation, documented APIs, focused checks and criterion-to-test mapping.
2. Give the stable candidate to **`feature_tester`**, using `.codex/agents/feature-tester.toml`. Supply the plan and actual candidate, not just the developer's conclusion. The tester runs relevant checks, inspects adversarial cases and exercises required Studio server/client behavior. Its report distinguishes verified behavior from unavailable checks and subjective feel.
3. Return one consolidated defect list to the developer. Recheck affected cases after corrections. Broaden or repeat testing only for new changes, failures or unresolved concerns. Continue until material findings are fixed; if a required external capability is unavailable or repeated attempts expose the same unresolved blocker, document it and complete independent work instead of cycling indefinitely.

Use actual custom-agent selection when supported. Otherwise spawn an agent with the corresponding TOML's `developer_instructions` verbatim plus the task context. Roles inherit the parent model/settings; no special model is required. Run write ownership sequentially so agents do not overwrite each other. If delegation is unavailable, disclose that limitation and do useful implementation/checks; do not claim independent review or mark its required review complete.

## 3. Update the whole experience narrative

After behavior stabilizes, delegate to **`technical_writer`**, using `.codex/agents/technical-writer.toml`. Give verified behavior, changed source/tests and evidence. The writer updates player-facing README, contributor/package docs and relevant design/architecture explanations as a cohesive description of the current system. Planned features remain explicitly planned. It does not invent test counts, screenshots, release IDs or publication facts.

If the writer finds a material implementation contradiction, resolve it and recheck the affected behavior. The primary agent alone owns roadmap status and the plan's evidence record.

## 4. Verify and deliver one increment

Run the full current `python3 scripts/verify.py` gate on the final candidate, unless the tester already ran that exact gate on unchanged relevant content. Validate subsequent documentation changes with the repository checker. Run every required Studio scenario and preserve the report. Unit tests, a Rojo build or source inspection cannot replace engine/replication evidence. Required zero-count/skipped/unavailable suites remain incomplete.

Record each acceptance criterion's test/command, actual result, environment/client count, source commit/tree, tester findings and documentation review in the plan. Keep large logs in bounded evidence/artifacts. Stage only the task's changes, commit and push to the configured GitHub repository, then create/update a reviewable PR with the resulting player behavior, validation and limitations. Preserve a draft if required gates remain open. Do not merge without user authorization; reuse authorization already given rather than asking again.

Set Complete only when `AGENTS.md`'s definition of done is met; otherwise retain In progress or record a concrete Blocked reason. Promote the next eligible dependency-complete plan to Ready but **do not implement it**. If status, PR links or evidence changed after the candidate commit, run the repository checker and commit/push those final records too. Verify the final remote head and task files are recorded before reporting delivery. Refer to the tested source commit/tree in evidence rather than trying to embed a commit's own future hash. Report the capability, checks, GitHub link and remaining limitations.

Roblox publication is separate. Only perform it when required by the selected plan and explicitly authorized for the actual destination/audience. Prepare the concrete candidate first; if authorization is missing, ask once with the source/build, experience/place, audience and evidence. A GitHub push or a request to implement a feature does not authorize publication. P12 cannot be Complete without its real 6/10-player and release evidence.
