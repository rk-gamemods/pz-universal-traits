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
- Glass Body: restored the pre-campaign all-source +50 percent damage contract through resolved body-health deltas; pre-resolution weapon-event defects, recursive amplification, player replacement, and reload behavior are regression-protected.
- Anorexy: restored the pre-campaign one-meal +0.10 stress contract through completed and interrupted food-consumption paths; the +10 scale bug, food-timer misses, per-update polling, and wrapper reload behavior are regression-protected.
- Competitive Eater: restored the accepted per-meal 10-point boredom and 0.05 hunger relief through completed and interrupted consumption paths; the hunger-scale error, food-timer misses, per-update polling, vague description, and one-way Gourmand exclusion are regression-protected.
- Bad Teeth: preserved the accepted 1-percent food-healing-delta head-pain contract while moving it to completed and interrupted consumption boundaries; the per-update poll, persisted timer inference, exact threshold/cap, shared-effect composition, and reciprocal Albino exclusion are regression-protected.

## Next Gameplay Blockers

Work one trait at a time. Before changing behavior, prove the accepted pre-campaign intent from `master`. If the intended outcome is not certain, stop and request a decision.

1. `UT_ascetic`: implementation is paused on the explicit user decision between +0.05 stress and instant maximum stress; all other intent and runtime evidence is traced.
2. Select the next unblocked single-trait blocker from the package and functional queue after Bad Teeth is committed cleanly.

## Contract Reconciliation Before Any Fix

These records may be stale because later development commits or tests already changed the implementation. Reconcile each record against current source before treating it as an open defect.

- Timed-action event registry for Paramedic and Pit Crew. Current tests reject fabricated events and exercise the shared duration path.
- Unwavering Translator blocker. Current English copy passes the Translator confusable gate, but the release-blocker record still references the old finding.

## Package Blockers

- Bouncer I source/release medical-perk drift.
- Bouncer II source/release medical-perk drift.
- Antique source/release container API drift.
- `UniversalTraits/poster.png` and `UT_CORE/poster.png` are absent from both `master` and `development`; read-only package verification reports `missing-source:poster.png` for both packages. Approved source assets are required rather than inventing them.
- Final UniversalTraits release-tree reconciliation after the functional and package blockers above are closed.

## Current Validation Baseline

- UT_CORE standard-Lua suite: 252 passed.
- UniversalTraits standard-Lua suite: 465 passed after the Bad Teeth correction.
- Campaign validator: structurally valid, with 198 traits, 4,752 dimensions, and 2,316 open remediation records.
- Campaign generator tests: 129 passed.
- UniversalTraits package content parity: no release issues, but the package verdict is blocked by the missing source poster.

## Runtime Proof Boundary

Static source tracing and producer-faithful mocks do not replace a game run. Each completed trait retains an exact current-version in-game requirement where needed, normally a full Exit to Desktop, relaunch, cadence observation, and save/load check. Multiplayer and backward save migration are not part of this campaign.
