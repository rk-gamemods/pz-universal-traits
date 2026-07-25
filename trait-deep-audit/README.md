# Trait Deep Audit

Status: current entrypoint

## Purpose

Maintain complete evidence without forcing every trait task to repeat the whole
campaign. The system preserves exhaustive accounting while prioritizing a
usable, reliable single-player happy path.

## Start Here

```powershell
py -3 tools\utmods_workflow.py status
py -3 tools\utmods_workflow.py catalog --check
```

At-a-glance review:

- `campaign/trait_catalog.csv`: sortable grid with trait cost, description,
  runtime path, events, audit state, open evidence count, and release blockers.
- `campaign/trait_catalog.json`: complete structured catalog with authority and
  source hashes.

The catalog is generated. Edit the owning source named in the JSON, then
rebuild.

## Status Meanings

- `proven-correct`: current evidence proves the stated contract.
- `confirmed-defect`: current evidence proves incorrect behavior or data.
- `coverage-gap`: the harness or evidence is insufficient to test a required
  contract.
- `runtime-unproven`: the remaining proof requires current engine observation
  or a stronger runtime simulation.
- approved non-goals remain explicit and are never relabeled proven.

## Views

| Artifact | What it counts |
| --- | --- |
| `final_trait_ledger.json` | One normalized record per trait |
| `dimension_ledger_rows.jsonl` | One row per trait and canonical dimension |
| `remediation_queue.jsonl` | Every open dimension and finding |
| `remediation_summary.json` | Named counts derived from queue rows |
| `release_blocker_queue.json` | Reviewed semantic blockers for a release profile |
| `release_profile.json` | Supported scope, risk tiers, and classification state |

The exhaustive queue is not the normal-play release gate. A release profile may
leave Tier 2 or Tier 3 work open, but the evidence state remains visible.

## Efficient Workflow

1. Resolve the trait in the catalog.
2. Retrieve existing trait, finding, mechanism, and queue evidence.
3. Run the dependency planner:

   ```powershell
   py -3 tools\utmods_workflow.py plan --changed-file <path>
   ```

4. Deep trace only the missing or stale path.
5. Work on one trait or one shared mechanism.
6. Run focused tests during iteration.
7. Regenerate shared views once after the focused work is stable.
8. Run the full campaign suite only at an integration milestone or release
   decision.

See
[`../docs/architecture/evidence-workflow.md`](../docs/architecture/evidence-workflow.md).

## Focused Tests

Exact module:

```powershell
py -3 -B campaign\tools\run_campaign_tests.py `
  --module test_evidence_compiler.py
```

Dependency-selected modules:

```powershell
py -3 -B campaign\tools\run_campaign_tests.py `
  --changed-file trait-deep-audit/campaign/tools/evidence_compiler/catalog.py
```

Full campaign:

```powershell
py -3 -B campaign\tools\run_campaign_tests.py
```

## Release Readiness

```powershell
py -3 tools\utmods_workflow.py release-gate
```

The gate fails closed while classification is incomplete, blocker dependencies
are unresolved, current provenance is stale, or live blocker identities remain
open. It does not require the entire exhaustive backlog to disappear.

## Legacy Campaign Assets

The batch JSONL, independent reviews, resolutions, recurring findings, and
trait-specific generators remain evidence during migration. Existing generator
outputs must not be discarded.

The 39 trait-specific generators currently duplicate planning, rendering,
transaction, and full-campaign rebuild logic. New shared primitives belong in
`campaign/tools/evidence_compiler/`. A legacy generator is retired only after
byte-equivalent output and generic transaction/fixed-point proof.

Current migration plan: [`PLAN.md`](PLAN.md).
