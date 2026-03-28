# UniversalTraits — Implementation Plan

**Goal:** Build a comprehensive B42 character-creation trait mod consolidating ~200 traits from multiple source mods into a clean, conflict-free, UT_-prefixed package.

**Architecture:** Two-mod layout — `UT_CORE` (shared Lua infrastructure, required dependency) + `UniversalTraits` (trait definitions, scripts, translations). Source in `media/`, synced to `release/ModName/42/media/` (PZ B42 standard: `42/` subfolder is required for all B42 mods). Three implementation phases ordered by complexity.

**Tech Stack:** Lua 5.x (PZ B42 Kahlua), B42 `CharacterTrait.register()` + `character_trait_definition` script blocks, standard Lua 5.x test runner.

**Test runner:**
- UT_CORE: `"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua`
- UniversalTraits: `"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua`

**Release sync (run from repo root):**
```bash
cp -r UniversalTraits/media/. UniversalTraits/release/UniversalTraits/42/media/
cp -r UT_CORE/media/. UT_CORE/release/UT_CORE/42/media/
```

**Deploy to live mods:**
```bash
cp -r UniversalTraits/release/UniversalTraits/. "C:/Users/Admin/Zomboid/mods/UniversalTraits/"
cp -r UT_CORE/release/UT_CORE/. "C:/Users/Admin/Zomboid/mods/UT_CORE/"
```

---

## Progress Tracker

| Phase | Status | Traits |
|-------|--------|--------|
| Phase 1 | ✅ Complete | 99 traits (script-only) |
| Phase 2 | ✅ Complete (2026-03-28) | 46 traits (stat modifiers + hasTrait checks) |
| Phase 3 | ✅ Complete (2026-03-28) | 54 traits (event-driven); UT_amputee deferred |
| **Total registered** | ✅ **199 traits** | 36 tests passing |

> See [AGENTS.md](../AGENTS.md) for full project knowledge, API reference, and known gaps.

---

## Phase 1 — Data-Driven Traits (Script-Only) ✅ COMPLETE

**All 99 traits fully implemented and committed.**

### Deliverables — Status

| File | Status |
|------|--------|
| `UT_CORE/mod.info` + release copies | ✅ |
| `UniversalTraits/mod.info` + release copies | ✅ |
| `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` | ✅ `hasTrait()` |
| `UT_CORE/media/lua/shared/UTCore/UTCore_TraitChecks.lua` | ✅ `hasAnyTrait()`, `getModData()`, `setModData()` |
| `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua` | ✅ stub |
| `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` | ✅ stub |
| `UT_CORE/media/lua/shared/UTCore/UTCore_SpawnEffects.lua` | ✅ stub |
| `UT_CORE/test/run_tests.lua` | ✅ 7 tests passing |
| `UniversalTraits/media/registries.lua` | ✅ 99 IDs registered |
| `UniversalTraits/media/scripts/UT_character_traits.txt` | ✅ 99 trait blocks |
| `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` | ✅ 99 UIName+UIDescription entries |
| `UniversalTraits/test/run_tests.lua` | ✅ 11 tests passing |
| Release folder sync (both mods) | ✅ |

### Remaining Phase 1 items

- [ ] `UniversalTraits/media/lua/shared/UniversalTraits/UT_MET.lua` — runtime mutual exclusivity enforcement table (script-level MET already in UT_character_traits.txt via `MutuallyExclusiveTraits` fields; this file is for any runtime enforcement or cross-reference queries)
- [ ] In-game verification: load mod in PZ B42, open character creation, confirm all traits appear with correct names/costs/descriptions/XPBoosts/MET
- [ ] poster.png for both mods (cosmetic — not required for function)

---

## Phase 2 — Stat Modifier & hasTrait Traits (~45 traits)

All Phase 2 traits need a Lua effect file. Most apply stats once at `OnNewGame`; a few check `hasTrait` at specific events.

### Phase 2 trait list

| UT ID | Display Name | Cost | Effect | Event |
|-------|-------------|------|--------|-------|
| UT_preparedpack | Prepared: Pack | 1 | +inventory slots at spawn | OnNewGame |
| UT_fast | Fast | 6 | +movement speed | OnNewGame |
| UT_thickblood | Thick Blooded | 4 | reduced bleed rate | OnNewGame |
| UT_leadfoot | Lead Foot | 2 | +vehicle speed | OnVehicleEnter |
| UT_quickworker | Quick Worker | 9 | +work speed | OnNewGame |
| UT_batteringram | Battering Ram | 7 | +push/shove force | OnNewGame |
| UT_fitted | Fitted | 4 | -encumbrance | OnNewGame |
| UT_restfulsleeper | Restful Sleeper | 6 | +sleep quality | OnSleepStart |
| UT_unwavering | Unwavering | 6 | panic resistance | OnPanicEvent |
| UT_idealweight | Ideal Weight | 4 | stat modifier | OnNewGame |
| UT_quickrest | Quick Rest | 3 | +rest recovery | OnSleepStart |
| UT_glassbody | Glass Body | -10 | +damage taken | OnNewGame |
| UT_slowworker | Slow Worker | -9 | -work speed | OnNewGame |
| UT_mundane | Mundane | -9 | global XP penalty | OnNewGame |
| UT_incomprehensive | Incomprehensive | -10 | skill cap reduction | OnNewGame |
| UT_noodlelegs | Noodle Legs | -6 | -speed | OnNewGame |
| UT_antigun | Anti-Gun Activist | -6 | -firearms XP | OnNewGame |
| UT_pacer | Pacer | 4 | +walking speed | OnNewGame |
| UT_ironliver | Iron Liver | 3 | alcohol tolerance | OnConsumeItem |
| UT_brittle | Brittle | -6 | +fracture chance | OnInjuryEvent |
| UT_flailer | Flailer | -4 | -combat accuracy | OnAttack |
| UT_flatearther | Flat Earther | -4 | -reading speed | OnReadItem |
| UT_luddite | Luddite | -4 | -electrical XP | OnNewGame |
| UT_lurcher | Lurcher | -5 | -movement | OnNewGame |
| UT_onetrickpony | One Trick Pony | -4 | multi-skill penalty | OnNewGame |
| UT_owlperson | Night Owl | -1 | night bonus / day penalty | TimedCheck |
| UT_larkperson | Early Bird | -1 | day bonus / night penalty | TimedCheck |
| UT_slack | Slack | -6 | -work speed | OnNewGame |
| UT_sorelegs | Sore Legs | -8 | -speed, -fitness | OnNewGame |
| UT_snorer | Snorer | -2 | +noise while sleeping | OnSleepStart |
| UT_heavilybleedingwounds | Heavily Bleeding Wounds | -4 | +bleed rate | OnNewGame |
| UT_weaklybleedingwounds | Weakly Bleeding Wounds | 3 | -bleed rate | OnNewGame |
| UT_durability | Durability | 3 | +item durability | OnItemUse |
| UT_analgesia | Analgesia | 10 | pain disable | OnNewGame |
| UT_photographicmemory | Photographic Memory | 20 | +reading/skill | OnNewGame |
| UT_fasthands | Fast Hands | 12 | stat modifier | OnNewGame |
| UT_noxpshooter | No XP: Shooting | 3 | disable firearms XP | OnNewGame |
| UT_noxptechnician | No XP: Tech | 3 | disable tech XP | OnNewGame |
| UT_noxpaxe | No XP: Axe | 3 | disable Axe XP | OnNewGame |
| UT_noxpfirstaid | No XP: First Aid | 3 | disable Doctor XP | OnNewGame |
| UT_noxpmaintenance | No XP: Maintenance | 3 | disable Maintenance XP | OnNewGame |
| UT_noxpsneaky | No XP: Sneaky | 3 | disable Sneak/Lightfoot XP | OnNewGame |
| UT_expertdriver | Expert Driver | 5 | hasTrait in vehicle code | OnVehicleTick |
| UT_poordriver | Student Driver | -5 | hasTrait in vehicle code | OnVehicleTick |
| UT_gourmand | Gourmand | 4 | hasTrait on eat | OnEat |
| UT_ascetic | Ascetic | -4 | restrict eating | OnEat |

### Phase 2 deliverables

- [ ] `UTCore_StatModifiers.lua` — implement helpers: `applySpeedModifier`, `applyCarryWeight`, `applyBleedRate`, `applyWorkSpeed`, `applyXPMultiplier`, `disableXP`
- [ ] `UTCore_SpawnEffects.lua` — implement `applySpawnStats(player, statTable)` for OnNewGame application
- [ ] `UTCore_Events.lua` — implement shared periodic timer infrastructure (for time-of-day checks, etc.)
- [ ] Add Phase 2 trait IDs to `registries.lua`
- [ ] Add Phase 2 `character_trait_definition` blocks to `UT_character_traits.txt`
- [ ] Per-trait Lua files in `UniversalTraits/media/lua/shared/UniversalTraits/traits/`
- [ ] Add Phase 2 translation strings to `UI_EN.txt`
- [ ] Sync release, commit

---

## Phase 3 — Event-Driven Runtime Traits (~55 traits)

Each Phase 3 trait requires individual risk assessment before implementation. **Rule: no handler fires more than once per in-game minute unless it's a specific point event (eat, kill, item pickup).**

### Phase 3a — Spawn-With-Condition (lowest risk, fire once)

| UT ID | Effect | Risk |
|-------|--------|------|
| UT_injured_I | Spawns with minor injury | Low — OnNewGame only |
| UT_injured_II | Spawns with serious injury | Low — OnNewGame only |
| UT_broke | Spawns with broken leg | Low — OnNewGame only |
| UT_burned | Spawns with severe burns | Low — OnNewGame only |

### Phase 3b — Periodic-Check Traits (timer-based, never per-tick)

| UT ID | Effect | Check Interval |
|-------|--------|----------------|
| UT_depressive | Mood penalty | Every 10 in-game minutes |
| UT_paranoia | Ambient panic | Every 10 in-game minutes |
| UT_selfdestructive | Self-harm event | Periodic |
| UT_melancholic | Mood penalty | Every 10 in-game minutes |
| UT_immuneresponse | Illness recovery boost | Per health tick (throttled) |
| UT_owlperson | Night vision/day penalty | Every 5 in-game minutes |
| UT_larkperson | Day bonus/night penalty | Every 5 in-game minutes |
| UT_ravenous | Hunger amplifier | Periodic |
| UT_optimist | Mood bonus | Periodic |
| UT_pessimist | Mood penalty | Periodic |
| UT_mstoptimist | Mood bonus | Periodic |
| UT_adaptivemetabolism | Metabolism handler | Periodic |
| UT_accmetabolism | Food/weight handler | Periodic |
| UT_albino | UV damage (outdoor) | Periodic outdoor check |
| UT_fibromyalgia | Pain handler | Periodic |
| UT_bigorexia | Body image handler | Periodic |
| UT_weathersensitive | Weather mood | Per weather change |
| UT_panicattacks | Random panic | Periodic random interval |
| UT_fearofthedark | Darkness mood | Periodic light check |
| UT_coldsensitive | Temperature penalty | Periodic |
| UT_heatsensitive | Temperature penalty | Periodic |
| UT_sedentary | Fitness loss | Periodic |
| UT_alcoholic_I | Craving (mild) | Every 30 in-game minutes |
| UT_alcoholic_II | Craving (moderate) | Every 15 in-game minutes |
| UT_alcoholic_III | Craving (severe) | Every 5 in-game minutes |

### Phase 3c — Event-Driven Traits (specific events, acceptable frequency)

| UT ID | Effect | Event |
|-------|--------|-------|
| UT_fearful | Panic boost | OnPanicTrigger |
| UT_nervouswreck | Panic amplifier | OnPanicTrigger |
| UT_scardycat | Panic amplifier | OnPanicTrigger |
| UT_maniac | Combat mood boost | OnKill |
| UT_anorexy | Food restriction | OnEat |
| UT_addictedtocaffeine | Caffeine craving | Periodic + OnConsume |
| UT_pillsallergy | Medicine reaction | OnConsumeMedicine |
| UT_wildplantsallergy | Plant reaction | OnConsumeFood |
| UT_allergic | General allergy | OnConsumeFood |
| UT_competitiveeater | Food bonus | OnEat |
| UT_sensitivestomach | Food reaction | OnEat |
| UT_butterfingers | Item drop | OnItemAction |
| UT_acrophobic | Height fear | OnFloorChange |
| UT_vehophobic | Vehicle fear | OnVehicleEnter |
| UT_motionsickness | Vehicle nausea | OnVehicleTick (throttled) |
| UT_physicallyactive | Fitness gain | OnExercise |
| UT_humanhamster | Storage handler | OnInventoryEvent |
| UT_ironliver | Alcohol tolerance | OnConsumeItem |
| UT_superimmune | Infection resistance | OnInfectionCheck |
| UT_immunocompromised | Infection vulnerability | OnInfectionCheck |
| UT_bouncer_I | XPBoost (combat) | Script-only |
| UT_bouncer_II | XPBoost (Strength, SmallBlunt) | Script-only |
| UT_gunspecialist_I | XPBoost (Aiming×1, Reloading×1) | Script-only |
| UT_gunspecialist_II | XPBoost (Aiming×2, Reloading×2, Nimble×1) | Script-only |
| UT_gunspecialist_III | XPBoost (Aiming×2, Reloading×2) | Script-only |

### Phase 3d — Complex State Traits (full state management required)

| UT ID | Effect | Risk |
|-------|--------|------|
| UT_indefatigable | Stamina system with cooldown | High — needs per-tick throttle |
| UT_hardy | Endurance tracking, sub-state traits | High — sub-states |
| UT_secondwind | Stamina recovery trigger | High — needs cooldown |
| UT_amputee | Complex limb system | **Highest — defer to Phase 3b** |

### Phase 3 pre-implementation gate (per trait)

Before writing any Phase 3 trait handler:
1. Identify exact PZ event(s) it hooks
2. Measure/estimate fire frequency
3. Design throttle/cache strategy if > once per in-game minute
4. Document state the trait tracks and how it persists across save/load
5. Write effect file using UT_CORE helpers

---

## Key Constraints

- All trait IDs use `UT_` prefix — never override vanilla
- `DisabledInMultiplayer = true` on all traits
- No per-tick handlers without explicit throttling
- Periodic handlers: use timer-based checks (every N seconds real time or N in-game minutes)
- Release sync must happen after every code change before testing in-game
- UT_CORE tests must pass before any commit

## File Conventions

| Purpose | Location |
|---------|----------|
| Trait ID registrations | `UniversalTraits/media/registries.lua` |
| Script definitions | `UniversalTraits/media/scripts/UT_character_traits.txt` |
| MET runtime table | `UniversalTraits/media/lua/shared/UniversalTraits/UT_MET.lua` |
| Per-trait Lua effects | `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_<id>.lua` |
| Translations | `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` |
| UT_CORE shared API | `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` |
| UT_CORE stat helpers | `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` |
| UT_CORE spawn effects | `UT_CORE/media/lua/shared/UTCore/UTCore_SpawnEffects.lua` |
| UT_CORE event infra | `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua` |
