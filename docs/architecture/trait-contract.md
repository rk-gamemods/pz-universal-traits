# Trait Representation Contract

Status: current

## Purpose

Define where each trait fact belongs and which dependent surfaces must remain
consistent. This document owns technical representation, not product intent.

## Sources of Truth

| Fact | Editable authority |
| --- | --- |
| Trait ID, cost, XP boosts, grants, exclusions | `UniversalTraits/media/scripts/UT_character_traits.txt` |
| Registration | `UniversalTraits/media/registries.lua` |
| English name and description | `UniversalTraits/media/lua/shared/Translate/EN/UI.json` |
| Runtime behavior | Source Lua under `UniversalTraits/media/lua/` and `UT_CORE/media/lua/` |
| Product intent and supported scope | `PRD.md` |
| Audit state and proof | Structured campaign evidence |
| Review grid | Generated `trait_catalog.csv` |
| Packaged copy | Derived `release/*/42.0/` |

No generated view becomes editable authority merely because it is easier to
read.

## Identity and Registration

- Each shipped trait has one `UniversalTraits:UT_*` identity.
- Registration, definition, name key, and description key must reconcile in
  both directions.
- A dedicated runtime file is not required for a data-only trait.
- File presence alone does not add or remove a product trait.

## Cost, XP, Grants, and Exclusions

- `Cost`, `XPBoosts`, `GrantedTraits`, and `MutuallyExclusiveTraits` are owned by
  the script definition.
- Exclusions are bidirectional when either trait can be selected independently.
- `UT_MET.lua` is a Lua-side reference and tooling surface. It does not replace
  script-side character-creation exclusions.
- A trait that grants another selectable trait must exclude the granted trait
  unless a different product outcome is explicitly approved.
- Numeric or exclusion changes require description, balance, test, catalog, and
  audit review.

## Names and Descriptions

- Every registered trait requires an English display name and description.
- A description states the actual player-facing result. It must not promise an
  unimplemented path or hide material behavior.
- Fixing wording to match unchanged behavior is documentation work.
- Changing behavior to match previously inaccurate wording is a functionality
  change and must preserve or explicitly revise product intent.

## Runtime Behavior

- Trait Lua owns trait-specific conditions and outcomes.
- `UT_CORE` owns reusable hooks, state modifiers, event adapters, and shared
  lifecycle mechanisms.
- A trait must not reproduce a shared hook merely to avoid understanding the
  existing service.
- Shared mechanisms need an exact consumer and parameter contract.
- State ownership, reset, player switching, reload, and teardown must be
  explicit where the mechanism persists or patches shared behavior.

## Intent and Baseline

- The intended player outcome is protected by `PRD.md`.
- The pre-campaign baseline is the state before the current campaign modified
  the trait.
- Upstream source mods establish provenance and possible rationale. They do not
  automatically override current product decisions.
- Uncertainty becomes a user question. It is not resolved by inference.

## Derived Views

`trait_catalog.json` records exact source hashes and complete structured rows.
`trait_catalog.csv` is an abbreviated grid for sorting and review. Rebuild both
through:

```powershell
py -3 tools\utmods_workflow.py catalog --write
py -3 tools\utmods_workflow.py catalog --check
```

Reverse synchronization from the grid is intentionally unavailable until an
explicitly guarded and tested edit contract exists.
