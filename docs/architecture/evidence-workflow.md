# Evidence Workflow

Status: current

## Goal

Inspect a source path once, preserve the result with provenance, and reuse it
for later questions until its declared boundary changes.

## Evidence Views

The campaign has several views that must not be conflated:

| View | Unit | Purpose |
| --- | --- | --- |
| Trait catalog | One source definition | At-a-glance product and audit navigation |
| Final trait ledger | One trait | Overall normalized audit state |
| Dimension ledger | One trait and canonical dimension | Exhaustive evidence accounting |
| Finding inventory | One distinct defect or gap | Reproduction and correction tracking |
| Remediation queue | One open dimension or finding | Exhaustive work backlog |
| Release blocker identities | One reviewed semantic blocker | Supported-profile release decision |

Different counts are valid only when their entity and closure rule are named.

## Efficient Investigation Lifecycle

1. Resolve the trait, mechanism, queue ID, or product surface in the generated
   indexes.
2. Check evidence freshness against source hash, game snapshot, lifecycle,
   parameter bounds, and API contract.
3. Reuse current evidence when it answers the question.
4. Retrieve only the missing source and call paths.
5. Deep trace unique, high-risk, stateful, frequent, Java-Lua, or
   intent-sensitive paths.
6. Write the result once to its owning structured evidence.
7. Regenerate dependent views once after the focused work stabilizes.

Agents receive compact exception packets at decision points. They should not
re-read every trait and every global artifact for routine changes.

## Proof Reuse

A family proof may be referenced by several traits only when all of these
match:

- production entry point and implementation hash;
- current PZ snapshot and relevant Java-Lua API;
- lifecycle and event registration;
- state ownership, persistence, cleanup, and teardown;
- parameter schema and validated bounds;
- test and mock contract;
- absence of a trait-specific override.

Every consumer still proves:

- correct trait identity and registration;
- correct parameters, numbers, and cadence;
- correct grants, exclusions, and stacking;
- correct name and description;
- correct source and package inclusion.

Shared missing proof should use one stable obligation identity with explicit
consumers. Do not repeat the same prose as hundreds of independent unknowns.

## Risk Tiers

- Tier 0: load, parser, shared-hook, event, corruption, and package failures
  reachable in normal play.
- Tier 1: common supported single-player lifecycle and interaction paths.
- Tier 2: bounded optional or unusual supported scenarios without a path into
  Tier 0 or Tier 1.
- Tier 3: exhaustive assurance and redundant confirmation.
- Tier 4: explicit user-approved non-goal.

Risk tier does not change evidence state.

## Release Readiness

The supported profile is current-build normal-play single player. Release
readiness requires:

- current source inventory provenance;
- complete source-to-ledger membership;
- unique findings and queue IDs;
- complete Tier 0 and Tier 1 classification;
- closed live blocker identities and dependencies;
- current translation, event, shared-hook, and package evidence;
- one internally consistent generation epoch.

The release gate must fail while classification is incomplete. Exhaustive
completion remains stronger: every non-approved obligation becomes
`proven-correct`.

## Dependency-Aware Workflow

Use:

```powershell
py -3 tools\utmods_workflow.py plan --changed-file <path>
```

The artifact graph calculates the downstream evidence closure and recommended
campaign tests. It uses content and declared dependencies, not a habit of
running every generator after every edit.

Use:

```powershell
py -3 tools\utmods_workflow.py status
py -3 tools\utmods_workflow.py release-gate
```

`status` reports truth without failing merely because work remains.
`release-gate` fails when the supported release profile is not proven ready.

## Compiler Migration

The current trait-specific generators remain compatibility evidence while the
shared compiler is introduced. New work must centralize:

- schema validation;
- unique row selection;
- canonical rendering;
- dependency invalidation;
- source fingerprints;
- transaction and rollback;
- ledger, queue, and manifest derivation.

A legacy generator is retired only after the shared path produces byte-equivalent
outputs and passes the generic transaction and fixed-point contract.
