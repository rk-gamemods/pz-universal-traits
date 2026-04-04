# UTMods QA Checklist — 2026-03-29

## P0 — Correctness Bugs (Fix Now)

### Bug A: `applyCarryWeight` from OnNewGame — carry weight lost on save/load

`UTCore.applyCarryWeight()` calls `player:setMaxWeightBase()` (transient runtime state).
These 5 traits set it from `OnNewGame` (fires once on new character only), so carry weight
bonus/penalty vanishes when loading a save. Fix: move to `OnCreatePlayer`.

- [x] `UT_sorelegs.lua` — has `-2` carry + speed mod. Move `applyCarryWeight(-2)` call to `OnCreatePlayer`
- [x] `UT_packmule.lua` — `+2` carry. Switch `OnNewGame` → `OnCreatePlayer`
- [x] `UT_packmouse.lua` — `-2` carry. Switch `OnNewGame` → `OnCreatePlayer`
- [x] `UT_humanhamster.lua` — `+2` carry. Switch `OnNewGame` → `OnCreatePlayer`
- [x] `UT_preparedpack.lua` — `+3` carry. Switch `OnNewGame` → `OnCreatePlayer`

Comparison: `UT_cangrabless` and `UT_cangrabmore` already correctly use `OnCreatePlayer`.

### Bug B: AGENTS.md per-trait template shows `OnNewGame` as default pattern

- [x] Update per-trait Lua file template (AGENTS.md lines ~192-206) to show `OnCreatePlayer` for ongoing handlers. Keep `OnNewGame` example only for one-time spawn effects.

### Bug C: UT_martial description says 4× damage, code does 3×

- [x] Fix `UI_EN.txt` description to say 3× instead of 4×
- [x] Add SmallBlunt skill dependency to description
- [x] Add endurance scaling range (0.35×–1.35×)

---

## P0 — AGENTS.md Stale Data

- [x] Update trait file count: "95 files" → "121 files"
- [x] Update UT_CORE test count: "38" → "41"  
- [x] Update UniversalTraits test count: "45 passing / 47 total" → "46 passing / 48 total"
- [x] Update combined count: "83 passing" → "87 passing"
- [x] Add missing UTCore module docs: `UTCore_BleedDecayHook.lua`
- [x] Add missing UTCore module docs: `UTCore_BleedDrainHook.lua`
- [x] Add missing UTCore module docs: `UTCore_MeleeDelayHook.lua`
- [x] Add `UT_martial.applyBonusDamage(player, target, endurance)` to API reference
- [x] Fix Deferred Work: remove stale "XP hooks not implemented yet" (already implemented as UTCore_XPHook.lua)

---

## P1 — Critical Description Issues

### Descriptions that misrepresent actual effects

- [x] `UT_mundane` — description only mentions -20% XP. Must add: "Disables special combat abilities from other traits (Martial Artist, Action Hero)"
- [x] `UT_actionhero` — says "scales with nearby enemy count" but omits 3 distance zones (≤2/≤5/≤10 tiles) with different crit chance and damage multipliers
- [x] `UT_badteeth` — says "painful and limits what you can consume" but code only adds head pain, doesn't limit food. Clarify: eating causes head pain; it does NOT reduce food effectiveness
- [x] `UT_noodlelegs` — says "-20% movement speed" but omits endurance drain (-0.005/sec)

### Descriptions with no specific values

- [x] `UT_packmule` — "carry far more" → "+2 base carry weight"
- [x] `UT_packmouse` — "struggle to carry" → "-2 base carry weight"
- [x] `UT_pacer` — "extended periods indoors" → quantify (~20 seconds before unhappiness kicks in)
- [x] `UT_gimp` — "movement speed is reduced" → "-50% movement speed"
- [x] `UT_anemic` — "reduced" → quantify the actual bleed decay multiplier

---

## P2 — Test Coverage Gaps (Plan)

### High-risk untested traits

- [x] Vehicle traits (`UT_driver`, `UT_expertdriver`, `UT_poordriver`) — added vehicle mock coverage for each trait's applied modifiers
- [x] Stamina state machines (`UT_indefatigable`, `UT_hardy`, `UT_secondwind`) — added cooldown and recovery-path tests
- [x] Infection traits (`UT_immuneresponse`, `UT_immunocompromised`, `UT_superimmune`) — added infection/fatigue mock coverage

### Test infrastructure improvements

- [ ] Unify MockPlayer implementations (UTCoreMocks.lua vs UTTestMocks.lua) — currently two diverged implementations
- [x] Add `ZombRand` mock with configurable return values (currently always returns 0 — can't test failure paths)
- [x] Add WorkSpeedHook negative/zero duration edge case test

### Medium-risk untested traits

- [x] `UT_idealweight` — added integration coverage for overweight and underweight calorie adjustments
- [x] `UT_butterfingers` — added timed roll coverage for the drop flag mechanic
- [x] All 6 `noxp*` traits — verify `disableXP` flag actually blocks XP through hook

---

## P3 — Performance & Balance (Polish)

### Performance

- [x] `UT_expertdriver` — moved off `OnPlayerUpdate`; now uses the shared event-driven vehicle trait path and restores baseline on exit
- [x] `UT_poordriver` — moved off `OnPlayerUpdate`; now uses the shared event-driven vehicle trait path and restores baseline on exit
- [x] Replace per-frame vehicle polling with enter/load sync + exit restore instead of adding a throttle band-aid

### Cost imbalances

- [x] `UT_preparedpack` (cost 1, +3 carry) vs `UT_packmule` — rebalance to keep `Prepared: Pack` as the cheap starter option and raise `Pack Mule` to `+6` carry at cost `3`
- [x] `UT_quickworker` (+30%, cost 9) vs `UT_slowworker` — reduce `UT_slowworker` cost from `-9` to `-5` and fix the stale description to match the real `+50%` work duration penalty

---

## Audit Metadata

- **Audit date**: 2026-03-29
- **Verification update**: 2026-04-04
- **Files audited**: 121 trait files, 13 UTCore modules, 2 test suites, 2 mock files, AGENTS.md, UI_EN.txt, UT_character_traits.txt
- **Current verified test results**: 52/52 UT_CORE, 70/70 UniversalTraits
- **Current pre-existing failures**: 0

---

## Future Follow-Up / Review

- [x] Design review: `UT_driver` is still not script-side mutually exclusive with `UT_expertdriver` or `UT_poordriver`. Runtime priority now prefers the stronger tier if multiple driver traits are somehow present, but character creation rules are still ambiguous and should be made explicit if that combination is not intended.
