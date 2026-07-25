# ADR 0001: UT_CORE Is a Required Product Component

Status: accepted

## Context

UniversalTraits contains many traits that need common event adapters, stat
modifiers, lifecycle handling, and compatibility guards. Duplicating these
mechanisms inside individual trait files increases conflict and maintenance
risk.

## Decision

`UT_CORE` and `UniversalTraits` are required parts of one product. Shared
mechanisms live in `UT_CORE`; trait-specific conditions and outcomes remain in
UniversalTraits.

## Consequences

- Both packages are audited and released together.
- Shared changes require review of every consumer.
- Trait files do not duplicate a shared hook to bypass the core contract.
- Source, release, tests, and documentation treat the integration as a product
  boundary.
