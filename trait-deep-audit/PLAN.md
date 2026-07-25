# Evidence Compiler Migration Plan

Status: active

## Goal

Replace repeated trait-by-trait whole-campaign generation with one
schema-driven, dependency-aware evidence compiler while preserving every
existing finding, proof, and historical mapping.

## Completed Foundation

- [x] Source-derived 198-trait JSON and CSV catalog.
- [x] Explicit artifact dependency graph.
- [x] Changed-file planning and focused campaign test selection.
- [x] Atomic multi-file catalog writes with rollback test.
- [x] Named status accounting for traits, queue rows, and blockers.
- [x] Separate fail-closed single-player release profile.
- [x] Current documentation authority map and trait change contract.

## Phase 1: Reconcile the Current Generation Epoch

- [ ] Refresh source inventory provenance against current `development` HEAD.
- [ ] Regenerate summary counts from actual queue rows.
- [ ] Reconcile the release-blocker queue digest.
- [ ] Resolve or declare every blocker dependency identity.
- [ ] Regenerate the terminal campaign manifest.

No evidence state changes merely to make this phase pass.

## Phase 2: Shared Compiler Primitives

- [ ] Strict schemas for trait evidence, findings, proofs, obligations, and
      artifact nodes.
- [ ] Shared unique-row selectors and state normalization.
- [ ] Shared canonical JSON/JSONL rendering.
- [ ] Content fingerprints and cache state outside the manifested campaign
      tree.
- [ ] One atomic transaction and rollback implementation.
- [ ] Pure derivation functions for ledger, dimensions, queue, summary, and
      manifest.

## Phase 3: Representative Dual Generation

Migrate one generator from each structural family:

- [ ] Standard overlay generator.
- [ ] External recurring-pattern dependency.
- [ ] Legacy direct writer.
- [ ] Custom transaction writer.

For each:

- [ ] Compile legacy and shared outputs from the same inputs.
- [ ] Require byte-equivalent artifact sets.
- [ ] Prove second-run fixed point.
- [ ] Prove failure atomicity.
- [ ] Preserve every old queue ID through a machine-readable mapping.

## Phase 4: Mechanism Proofs and Obligations

- [ ] Add stable `proof_id` and `obligation_id` schemas.
- [ ] Record implementation hash, game snapshot, lifecycle, API, state, and
      parameter boundaries.
- [ ] Map every consumer explicitly.
- [ ] Expand references back to the old per-trait evidence for reconciliation.
- [ ] Reject orphan, dangling, duplicate, cyclic, or ambiguous mappings.

## Phase 5: Legacy Retirement

- [ ] Convert migrated scripts to thin compatibility wrappers.
- [ ] Move generic safety tests into parameterized compiler suites.
- [ ] Update every documented entrypoint.
- [ ] Remove wrappers only after no callers remain.
- [ ] Archive the old batch workflow after bidirectional inventory
      reconciliation.

## Release Workstream

In parallel with compiler migration:

- [ ] Complete Tier 0 and Tier 1 classification.
- [ ] Close current normal-play blockers.
- [ ] Prove translation, event, shared-hook, and package invariants.
- [ ] Keep Tier 2 and Tier 3 items visible in the exhaustive backlog.

## Stop Conditions

Stop the affected trait or mechanism when:

- intended outcome is uncertain;
- the pre-campaign baseline cannot be established;
- a proof boundary does not match;
- source and generated evidence disagree without a known derivation;
- a migration would discard or silently relabel evidence.

Continue unrelated safe work.
