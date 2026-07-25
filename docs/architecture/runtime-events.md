# Runtime Event and Hook Contract

Status: current

## Event Evidence

- Verify every event name against the current supported PZ snapshot.
- Record the source anchor or runtime observation.
- Do not preserve an unknown event because an older mod used it.
- Standard Lua tests prove harness behavior, not Kahlua or engine exposure.

## Cadence

Choose the slowest event that meets the intended outcome:

- one-time initialization for initial state;
- minute-scale events for slow status changes;
- bounded player updates only when responsiveness requires them;
- direct engine callbacks for actual actions or hits.

Any frequent callback requires:

- an early trait or state exit;
- bounded work per call;
- no broad world or inventory scan;
- no repeated allocation when stable state can be reused;
- explicit cleanup when the trait or player changes;
- a focused performance or cadence assertion.

Noise, movement, inventory, and combat hooks are not generic observation
surfaces. Add them only when the trait's intended outcome requires that exact
engine path.

## Conditional Registration

Prefer registering ongoing work only while it is needed. When global
registration is unavoidable, the handler must return immediately for irrelevant
players and states.

Registration, removal, reload, duplicate load, and stale closure behavior must
be deterministic.

## Shared Wrappers

A shared wrapper must prove:

- one installation;
- idempotent duplicate load;
- preservation of the original function;
- composition with other wrappers;
- exact consumer dispatch;
- deactivation and teardown;
- recovery after reload or player replacement;
- no stale ModData or object ownership assumptions.

One wrapper proof may serve exact consumers. Trait-specific predicates and
numeric effects still require adapter tests.

## State Ownership

- Name the owner of every persistent key, patched object, cached value, and
  original-value snapshot.
- Restore only values owned by the mechanism.
- Do not overwrite unrelated mod state.
- Avoid relying on object identity across reload or save/load unless current
  engine evidence proves it.

## Mocks

- Preserve 0-based Java collection access versus 1-based Lua arrays.
- Model missing methods and bridge failures explicitly.
- Add the smallest mock surface that proves the behavior.
- Do not make a permissive mock turn an unsupported engine call into a pass.
