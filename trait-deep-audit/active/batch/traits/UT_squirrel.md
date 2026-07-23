# UT_squirrel

## Accepted contract

- Trait: `UniversalTraits:UT_squirrel`, display name `Squirrel`, cost 2.
- Intent: slow fatigue accumulation while running or sprinting. Squirrel is not a carry trait.
- Runtime: `EveryOneMinute` samples the active player. A qualifying owner receives exactly `0.0015` fatigue removal. Walking, idling, and a player without the trait receive no benefit.
- The amount is constant per event and does not use `GameTime` multiplier, day length, timers, or sleep-trait modifiers.
- No XP boosts or grants. Multiplayer is disabled.
- Bidirectional exclusions: `UT_packmouse`, `UT_topheavy`, and `UT_sloth`.

## Provenance

The fatigue identity exists in the inspected SomewhatTraits evidence and the original UT port. Pre-campaign bulk translation regeneration introduced the unrelated hoarding and carry-weight description. The accepted UT contract retains the honest fatigue identity but does not import upstream tick cadence, day-length scaling, or sleep-trait rules.

## Exact current evidence

- Source and release runtime are byte-identical: `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_squirrel.lua`.
- Source and release definition blocks are byte-identical and specify cost 2, no XP/grants, multiplayer disabled, and the three accepted exclusions.
- The reverse definition blocks for Pack Mouse, Top Heavy, and Sloth each include Squirrel.
- Source and release registries are byte-identical and register `UniversalTraits:UT_squirrel`.
- Source and release English UI are byte-identical. The current description states the running/sprinting trigger, fixed `0.0015` per-minute fatigue removal, and no walking/idle benefit.
- No Squirrel path changes carry weight, inventory capacity, overload thresholds, or items.

## Runtime and engine trace

`UT_squirrel.lua` registers one shared periodic handler for `EveryOneMinute`. The wrapper resolves `getPlayer()`, then the handler checks trait ownership and `isRunning() or isSprinting()`. It calls `stats:remove(CharacterStat.FATIGUE, 0.0015)` exactly once when qualified.

SVN revision 964 anchors the live event and stat contract used by the implementation: the minute event is produced without handler arguments, `Stats.remove(CharacterStat,float)` delegates through bounded stat mutation, and `CharacterStat.FATIGUE` is the selected stat. This static trace does not prove current-build Kahlua or gameplay execution.

## Regression proof

The focused standard-Lua coverage in `UniversalTraits/test/run_tests.lua` proves:

- exact `0.0015` removal for running and sprinting;
- idle and walking rejection;
- no-trait rejection;
- equal removal across configured game multipliers;
- native lower-bound clamp;
- reload replaces the registered trait/event handler without duplicate effects;
- exact English description and absence of carry claims;
- cost, no XP/grants, multiplayer flag, and all forward and reverse exclusions;
- source/release parity for runtime, UI, definitions, and registries.

`UTTestMocks.lua` supplies controllable movement, fatigue, multiplier, trait, and event fixtures. These are off-game standard-Lua tests, not current-version Kahlua proof.

## Finding dispositions

- `B11-SQUIRREL-001`: proven corrected by accepted commit `e4ed870d28bafadd30ae6e18559e7e6308aaefb8`. English now documents the actual fatigue effect and makes no carry claim.
- `B11-SQUIRREL-002`: proven corrected by the same commit. The runtime uses a constant per-minute amount, and focused tests prove multiplier invariance.
- Independent review: both accepted findings are supported and reconciled. No Squirrel-specific omission remains. Cross-trait Kahlua, save/load, balance/performance, and locale proof IDs remain open.

## Remaining proof and gaps

- Current-build Kahlua execution and gameplay are unobserved.
- Live minute cadence and fast-forward behavior are unobserved.
- Repeated world entry, lifecycle behavior, and current-version save/load are unobserved.
- Rendered English is unobserved.
- Balance telemetry and profiler capture are absent.
- No non-English UniversalTraits locale exists.
- The existing UniversalTraits source poster issue remains a packaging gap.
- Multiplayer, backward save migration, deployment, and upstream timing/day-length/sleep rules are explicit non-goals.

Overall state: `runtime-unproven`.
