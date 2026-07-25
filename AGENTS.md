# UTMods Agent Contract

## Purpose

Maintain `UT_CORE` and `UniversalTraits` as one single-player Project Zomboid
Build 42 product. Prefer durable indexed evidence and focused validation over
repeating whole-product research for every trait.

This file contains only always-on boundaries and entrypoints. Detailed product,
architecture, audit, and operational material belongs in the linked owner.

## Authority Map

| Subject | Authority |
| --- | --- |
| Product intent, supported scope, non-goals | [`PRD.md`](PRD.md) |
| Trait representation and change cascade | [`docs/architecture/trait-contract.md`](docs/architecture/trait-contract.md) |
| Evidence reuse, release readiness, exhaustive backlog | [`docs/architecture/evidence-workflow.md`](docs/architecture/evidence-workflow.md) |
| Runtime events, cadence, shared hooks | [`docs/architecture/runtime-events.md`](docs/architecture/runtime-events.md) |
| One-trait change procedure | [`TRAIT_CHANGE_CHECKLIST.md`](TRAIT_CHANGE_CHECKLIST.md) |
| Current audit entrypoint and status commands | [`trait-deep-audit/README.md`](trait-deep-audit/README.md) |
| Campaign migration work | [`trait-deep-audit/PLAN.md`](trait-deep-audit/PLAN.md) |
| Product roadmap | [`planning/ROADMAP.md`](planning/ROADMAP.md) |
| Historical plans and research | [`planning/README.md`](planning/README.md), [`research/README.md`](research/README.md) |
| Current code and API behavior | Source code, current tests, and current PZCodebase evidence |

When two documents conflict, stop and resolve the ownership conflict. Do not
choose whichever instruction is more convenient.

## Product Boundary

- Treat `UT_CORE` and `UniversalTraits` as one product with two packages.
- Target only the newest supported Build 42 snapshot and the `42.0` package
  layout.
- Multiplayer support is not in scope.
- Migration of old saves is not in scope. Previous saves may be invalidated.
- Do not edit the read-only `PZCodebase` snapshot.
- Do not deploy, launch the game, publish, or write live mod state without
  explicit authorization.

## Git and Artifact Boundary

- Work on `development`. Keep `master` clean.
- Preserve unrelated user changes.
- Use milestone commits after reviewing the exact diff and passing the
  appropriate checks.
- `media/` is editable source for conventional mod content.
- `release/` and the live mod directory are derived copies. Do not hand-edit
  either.
- Generated campaign views are derived. Their owning sources are named inside
  each generated artifact.

## Efficient Evidence Workflow

Before opening many files:

1. Run the compact status view:

   ```powershell
   py -3 tools\utmods_workflow.py status
   ```

2. Review the generated catalog:

   - `trait-deep-audit/campaign/trait_catalog.csv` for a grid.
   - `trait-deep-audit/campaign/trait_catalog.json` for complete structured
     provenance.

3. Ask the dependency planner for the smallest affected closure:

   ```powershell
   py -3 tools\utmods_workflow.py plan --changed-file <repo-relative-path>
   ```

4. Retrieve existing evidence by trait, mechanism, proof, or queue identity.
   Do not repeat a source dive merely because a new question uses different
   wording.

5. Deep trace only when the existing evidence is absent, stale, contradictory,
   outside its version/hash boundary, or insufficient for the decision.

6. Record a completed investigation in the owning structured evidence so later
   work can reuse it cheaply.

One proof may serve multiple traits only when the implementation hash, entry
point, lifecycle, state ownership, API contract, parameter schema, and validated
parameter bounds match. Each trait still needs its own adapter, numeric,
exclusion, translation, and packaging proof.

## Trait Intent Contract

- The honest intended player outcome of a trait is protected product intent.
- Do not change that outcome without explicit user approval.
- Fix nonfunctional behavior so it produces the already intended outcome.
- The pre-change baseline is the state before the current campaign changed it,
  not an older upstream mod unless current evidence establishes otherwise.
- If intent, baseline, or expected outcome is uncertain, record the exact
  question and stop that trait. Continue unrelated safe work.
- Work on one trait per implementation task unless a shared mechanism change
  is the explicit subject.
- A trait that grants another selectable trait must be mutually exclusive with
  the granted trait unless the user approves different product behavior.

## Change Cascade

Read [`TRAIT_CHANGE_CHECKLIST.md`](TRAIT_CHANGE_CHECKLIST.md) before changing a
trait. A trait change may affect:

- script definition and cost;
- XP boosts, grants, and exclusions;
- English name and description;
- runtime Lua;
- `UT_CORE` hooks or services;
- tests and mocks;
- generated catalog and audit evidence;
- source/release parity;
- product or architecture documentation.

Never change only the first file found.

## Validation Tiers

Use the smallest tier that proves the current iteration:

1. Focused tier: the changed module, trait, parser, or generator contract.
2. Dependency tier: all tests selected by the changed-file planner.
3. Package tier: affected Lua mod suite and source/release verification.
4. Campaign tier: the full bounded campaign suite at integration milestones,
   before a release decision, or after shared compiler/runner changes.
5. In-game tier: only when the required engine behavior cannot be proven by the
   harness and deployment is authorized.

Focused campaign example:

```powershell
py -3 -B trait-deep-audit\campaign\tools\run_campaign_tests.py `
  --changed-file trait-deep-audit/campaign/tools/evidence_compiler/catalog.py
```

Full campaign example:

```powershell
py -3 -B trait-deep-audit\campaign\tools\run_campaign_tests.py
```

Use `C:\Users\Admin\.codex\scripts\bounded-command.py` for commands with
potentially large or long output. A green runner is not proof that its input
inventory or assertions are complete.

## Runtime and Performance

- Treat frequent events, hooks, wrappers, scans, and per-player updates as
  high-risk surfaces.
- Prefer conditional registration, explicit teardown, bounded work, and the
  slowest cadence that meets the intended outcome.
- Never add a broad or noisy hook to compensate for missing evidence.
- Preserve Java list indexing and Kahlua behavior in mocks. Standard Lua tests
  are not the engine.
- Verify shared wrapper installation, idempotence, composition, reload, and
  teardown once per exact mechanism contract, then verify each trait adapter.

## Catalog and Evidence Outputs

Rebuild the at-a-glance catalog after any definition, registration, English UI,
runtime trait file, ledger, queue, or blocker change:

```powershell
py -3 tools\utmods_workflow.py catalog --write
py -3 tools\utmods_workflow.py catalog --check
```

The CSV is a review view, not an editable authority. Change the owning source
listed in `trait_catalog.json`, then regenerate. Reverse synchronization must
not be introduced until it has explicit validation and intent-change guards.

The exhaustive remediation queue and normal-play release readiness are distinct
views. Never relabel an unresolved evidence item as proven merely because it
does not block the supported release profile.

## Normal Operation Blockers

Repair local tool, index, harness, and documentation blockers when they are in
scope. Do not silently bypass configured Munch tools or stale indexes. A local
blocker in one trait does not pause unrelated safe work.

Before completion, report:

- exact files changed;
- focused and full validation actually run;
- generated outputs refreshed;
- deployment state;
- unresolved intent questions, release blockers, or evidence risks.
