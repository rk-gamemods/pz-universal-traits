# UniversalTraits Product Requirements

Status: current

Product: `UT_CORE` plus `UniversalTraits`

Supported target: current Project Zomboid Build 42 snapshot, `42.0` package
layout

## Authority

This document owns current product intent, supported scope, product-level
behavior, and non-goals. It does not own repository layout, API signatures,
commands, implementation phases, progress counts, or exhaustive trait lists.

The earlier March 2026 draft remains available in Git history and the dated
planning records. Current trait inventory is generated from source.

## Product Identity

UniversalTraits is a large single-player trait collection. `UT_CORE` supplies
shared services and hooks used by the trait package. The two packages are
developed, audited, tested, and released as one product.

## Goals

- Provide the intended player-facing outcome of every shipped trait.
- Keep trait names, descriptions, cost, XP, grants, exclusions, and runtime
  behavior consistent.
- Remain reliable through ordinary supported single-player lifecycle events.
- Detect game-version drift, unsupported APIs, shared-hook conflicts, and
  package drift before release.
- Make trait review and maintenance cheap enough to repeat safely.

## Non-Goals

- Multiplayer support.
- Compatibility with pre-Build-42 layouts.
- Migration of previous saves. Existing saves may be invalidated.
- Automatic preservation of behavior accidentally introduced during the audit
  campaign.
- Silent changes to trait intent, balance, or player-facing outcome.

## Trait Intent

Each trait has an honest intended player outcome. A defect is corrected by
restoring that outcome, even when the implementation must change. The outcome
itself may change only with explicit user approval.

When the current campaign has already changed a trait, the comparison baseline
is the state immediately before that campaign change. Older upstream mods are
evidence about origin and rationale, not automatic authority over the current
product.

## Product Capabilities

- Data-driven traits may use script fields such as cost, XP boosts, grants, and
  mutual exclusions without a dedicated runtime file.
- Runtime traits may use narrowly scoped `UT_CORE` services and verified game
  events.
- Shared mechanisms may serve several traits when their lifecycle and
  parameter contracts are explicit.
- English display names and descriptions are shipped for every registered
  trait.
- Source, `42.0` release package, and authorized live copy must reconcile.

## Trait Selection Principles

- Every shipped trait must have a unique registered identity and script
  definition.
- Traits that create redundant, conflicting, or self-defeating selection paths
  require explicit exclusions.
- A trait that grants another selectable trait must exclude that trait unless a
  different product outcome is explicitly approved.
- Trait inclusion and removal are product decisions. They are not inferred from
  file presence alone.

The current source-derived inventory is:

- [`trait-deep-audit/campaign/trait_catalog.csv`](trait-deep-audit/campaign/trait_catalog.csv)
- [`trait-deep-audit/campaign/trait_catalog.json`](trait-deep-audit/campaign/trait_catalog.json)

## Balance Policy

- Cost and numeric effects must match the intended strength and player-facing
  description.
- Balance changes require an explicit rationale and review of dependent
  descriptions, exclusions, tests, and audit evidence.
- Lack of runtime proof is not evidence that a trait should be weakened,
  removed, or redefined.

## Compatibility Policy

- Avoid ID collisions and unsafe global monkey patches.
- Allow intentional stacking only when composition is verified.
- Treat shared-hook lifecycle, current event names, Java-Lua exposure, and
  source-release parity as release-critical.
- External mod integration requires a verified current API. Historical
  observations do not establish current compatibility.

## Release Policy

Normal-play single-player readiness and exhaustive audit completion are
different milestones:

- Release readiness requires the supported profile's blockers and required
  proofs to close.
- Exhaustive completion requires every non-approved evidence obligation to
  become proven-correct.
- A nonblocking backlog item keeps its honest evidence state.

See
[`docs/architecture/evidence-workflow.md`](docs/architecture/evidence-workflow.md)
and [`trait-deep-audit/README.md`](trait-deep-audit/README.md).

## Current Decisions and Open Work

- Accepted architecture decisions live under `docs/decisions/`.
- Current development priorities live in [`planning/ROADMAP.md`](planning/ROADMAP.md).
- Historical plans are indexed by [`planning/README.md`](planning/README.md).
- Research evidence is indexed by [`research/README.md`](research/README.md).
- Trait implementation rules live in
  [`docs/architecture/trait-contract.md`](docs/architecture/trait-contract.md).
