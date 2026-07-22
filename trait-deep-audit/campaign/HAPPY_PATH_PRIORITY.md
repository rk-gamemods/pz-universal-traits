# UTMods Happy-Path Priority

This is the small operational queue for making the mod usable and reliable first. The exhaustive remediation queue remains authoritative for eventual whole-product closure, but it is not the day-to-day execution order.

## Completed On Development

- Wood Splitter: vanilla Axeman behavior, grant, and reciprocal selection exclusion implemented and proven statically.
- Unwavering: English copy and runtime evidence reconciled without changing the mechanic.
- Action Hero: handler lifecycle corrected and focused regression coverage added.
- Scrounger: current event contract, collection indexing, player resolution, and repeated-load behavior corrected.
- Maniac: `OnZombieDead` attacker resolution corrected.
- Super Immune: direct zombie-infection channel correction completed.
- Motion Sickness: stale runtime evidence reconciled and regeneration made recoverable.
- Immune Response: direct zombie-infection channel correction completed; food sickness and zombie fever can no longer be copied into zombie infection.
- Immunocompromised: direct zombie-infection channel correction and reload-safe minute registration completed.
- Brittle: pre-campaign fracture behavior reconciled; the real weapon-hit argument order, elapsed-time cooldown, exact fracture API, and reload-safe handler are statically proven.

## Next Gameplay Blockers

Work one trait at a time. Before changing behavior, prove the accepted pre-campaign intent from `master`. If the intended outcome is not certain, stop and request a decision.

1. `UT_glassbody`: correct the hit event and Java-Lua contract while preserving the pre-campaign damage intent.
2. `UT_anorexy`: replace or bound the every-update meal detector only after proving the pre-campaign trigger and stress magnitude.
3. Item-consumption lifecycle: prove whether the shared wrapper still stacks after repeated startup or world-entry lifecycles, then correct the shared infrastructure with focused caller regression tests.

## Contract Reconciliation Before Any Fix

These records may be stale because later development commits or tests already changed the implementation. Reconcile each record against current source before treating it as an open defect.

- Timed-action event registry for Paramedic and Pit Crew. Current tests reject fabricated events and exercise the shared duration path.
- Unwavering Translator blocker. Current English copy passes the Translator confusable gate, but the release-blocker record still references the old finding.

## Package Blockers

- Bouncer I source/release medical-perk drift.
- Bouncer II source/release medical-perk drift.
- Antique source/release container API drift.
- `UniversalTraits/poster.png` is absent from both `master` and `development`; read-only package verification reports `missing-source:poster.png`. An approved source asset is required rather than inventing one.
- Final UniversalTraits release-tree reconciliation after the functional and package blockers above are closed.

## Current Validation Baseline

- UT_CORE standard-Lua suite: 248 passed.
- UniversalTraits standard-Lua suite: 448 passed after the Immunocompromised correction.
- Campaign validator: structurally valid, with the exhaustive queue reduced from 2,380 to 2,360 records by the infection-channel and Brittle reconciliations.
- Campaign generator tests: 101 passed.
- UniversalTraits package content parity: no release issues, but the package verdict is blocked by the missing source poster.

## Runtime Proof Boundary

Static source tracing and producer-faithful mocks do not replace a game run. Each completed trait retains an exact current-version in-game requirement where needed, normally a full Exit to Desktop, relaunch, cadence observation, and save/load check. Multiplayer and backward save migration are not part of this campaign.
