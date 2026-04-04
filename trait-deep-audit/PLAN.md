# Trait Deep Audit Loop Plan

This loop is scoped only to `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\trait-deep-audit`.
This folder is the plan and the audit system. Do not create audit planning files at the UTMods root.

## Scope Root

- `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\trait-deep-audit`

## Canonical Planning Files In Scope

- `trait-deep-audit/README.md`
- `trait-deep-audit/active/batch/00_batch_checklist.md`
- `trait-deep-audit/active/batch/traits/*.md`
- `trait-deep-audit/plan-parallel-trait-audit.prompt.md`

## Execution Contract

- The audit system is self-contained in this folder.
- Work is trait-by-trait unless the checklist explicitly tracks a batch-level issue.
- The checklist is the active backlog and priority map.
- Trait files under `active/batch/traits/` are the per-unit evidence records.
- Do not create competing master plans outside this folder.
- Active `/loop-run` behavior prefers `trait-deep-audit/plan-parallel-trait-audit.prompt.md` and must keep launching parallel trait-audit workers while executable traits remain.

## Current State

- Active batch exists at `trait-deep-audit/active/batch/`
- Checklist exists and is the current loop tracker
- Status from checklist: `in progress (107/~170 traits audited)`
- Priority accounting recorded in the checklist:
  - P0 inert/broken traits: complete for the audited set
  - P1 wrong descriptions: partial
  - P2 balance issues: not addressed
  - P3 missing mutual exclusions: not addressed
  - P4 test gaps: addressed for P0-fixed traits only

## Next Restart Step

Resume from `trait-deep-audit/active/batch/00_batch_checklist.md` and take the next explicitly intended slice from that backlog, staying inside this folder's audit workflow.

## Recent Run Log

- 2026-04-04: Created local checkpoint `loop/checkpoint-20260404-171928-sundayrunner-audit` and completed `UT_sundayrunner` audit. Evidence file: `active/batch/traits/UT_sundayrunner.md`. Checklist advanced to `108/~170 traits audited`; key findings were a false Fitness description, missing `UT_sprintdemon` mutual exclusion, and missing behavioral test coverage.
- 2026-04-04: Added `plan-parallel-trait-audit.prompt.md` as the active prompt-plan override so `/loop-run` treats the remaining trait queue as a massively parallel research checklist instead of stopping after one completed trait.

## Non-Goals

- Do not create planning files at `UTMods/` root
- Do not treat outside planning docs as the audit contract for this loop
- Do not mark a trait complete without its trait file evidence
- Do not collapse P1, P2, P3, and P4 into one vague objective

## Evidence Required

- Checklist status updated in `trait-deep-audit/active/batch/00_batch_checklist.md`
- Per-trait evidence captured in the relevant file under `trait-deep-audit/active/batch/traits/`
- Any batch-wide findings recorded in the checklist or a batch-local research/artifact file

## Agent Preflight Matrix

| Agent | Required/Conditional | Ready/Issue/Skipped | Trigger or Skip Rationale | Working Doc Status | Notes |
| --- | --- | --- | --- | --- | --- |
| product-owner | Required | READY | Checklist already defines active priorities and partial completion state | In-folder docs present | Follow checklist priority tiers |
| system-architect | Required | READY | README defines audit structure, lanes, and failure conditions | In-folder docs present | Use README as structural contract |
| software-engineer | Required | READY | Batch/checklist state is clear enough to resume concrete work | In-folder docs present | Stay scoped to chosen backlog slice |
| sdet-tester | Required | READY | P4 status and missing-proof expectations are explicitly documented | In-folder docs present | Use trait files to capture missing proof |
| qa-auditor | Required | READY | README defines trait completion failure conditions and evidence model | In-folder docs present | Do not accept checklist-only completion |
| qa-review | Required | READY | Description integrity and verdict rules are explicitly defined | In-folder docs present | Keep player-facing accuracy central |
| what-if-analyst | Conditional | SKIPPED | Not needed for loop init | Not created | Revisit only after baseline slice completes |
| security-engineer | Conditional | SKIPPED | Audit loop does not touch auth, secrets, or trust boundaries by default | Not created | Invoke only if scope changes |
| performance-engineer | Conditional | SKIPPED | No hot-path or scale decision in loop init | Not created | Invoke only if runtime performance becomes part of the slice |
| sre-devops | Conditional | SKIPPED | No deployment/runtime-config work in loop init | Not created | Invoke only for deploy parity work |
| compliance-privacy | Conditional | SKIPPED | No sensitive-data handling change in scope | Not created | Invoke only if scope changes |
| technical-writer | Conditional | READY | README and checklist already provide the audit contract | In-folder docs present | Keep this file thin and in-scope |
| workspace-steward | Conditional | READY | Corrected loop control is now placed inside the intended folder | In-folder docs present | Do not create duplicate planning surfaces outside this folder |
