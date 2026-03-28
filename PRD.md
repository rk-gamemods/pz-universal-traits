# UniversalTraits — Product Requirements Document

**Version:** 1.0
**Date:** 2026-03-27
**Status:** Draft

---

## 1. Mod Identity

| Field | Value |
|-------|-------|
| **Mod ID** | `UniversalTraits` |
| **Display Name** | Universal Traits |
| **Workshop Description** | A comprehensive character-creation trait pack for Build 42. Consolidates and deduplicates content from multiple trait mods into one clean, conflict-free package. All traits use the `UT_` prefix — no vanilla overrides, no ID collisions. Single-player only. |
| **B42 Version Target** | 42.15+ (uses `CharacterTrait.register()` + `registries.lua` + script-based definitions) |
| **Scope** | Single-player only. Multiplayer is explicitly out of scope. |
| **mod.info fields** | `name=Universal Traits`, `id=UniversalTraits`, `description=...`, `poster=poster.png`, `require=UT_CORE` (see Section 9) |

---

## 2. Folder Structure

### 2.1 UT_CORE (Required Dependency)

```text
UT_CORE/
  mod.info                                    # Root mod.info (PZ mod list discovery)
  poster.png                                  # Source poster
  media/
    lua/
      shared/UTCore/                          # Canonical source code
        UTCore_API.lua                        # Public API: stat helpers, event wrappers
        UTCore_Events.lua                     # Shared event hook infrastructure
        UTCore_StatModifiers.lua              # Stat modifier application helpers
        UTCore_SpawnEffects.lua               # Spawn-with-condition helpers (injury, burns, etc.)
        UTCore_TraitChecks.lua                # hasTrait convenience wrappers
  release/
    UT_CORE/
      mod.info
      42.0/
        mod.info
        poster.png
        media/
          lua/shared/UTCore/                  # Deployed copies
  test/
    run_tests.lua
    UTCoreMocks.lua
  planning/
```

### 2.2 UniversalTraits (Main Mod — requires UT_CORE)

```text
UniversalTraits/
  mod.info                                    # Root mod.info
  poster.png                                  # Source poster
  media/
    registries.lua                            # CharacterTrait.register() for ALL UT_ traits
    scripts/
      UT_character_traits.txt                 # All character_trait_definition blocks
    lua/
      shared/
        UniversalTraits/
          UT_MET.lua                          # Mutual exclusivity table + trait interaction logic
          traits/                             # Per-trait effect files (scripted traits only)
            UT_indefatigable.lua
            UT_hardy.lua
            UT_superimmune.lua
            UT_alcoholic_I.lua
            UT_alcoholic_II.lua
            UT_alcoholic_III.lua
            ...                               # One file per scripted trait
      client/
        UniversalTraits/
          UT_Translations.lua                 # Translation string registration
  release/
    UniversalTraits/
      mod.info
      42.0/
        mod.info
        poster.png
        media/
          registries.lua
          scripts/UT_character_traits.txt
          lua/
            shared/UniversalTraits/...
            client/UniversalTraits/...
  test/
    run_tests.lua
    UTTestMocks.lua
  research/
    TRAIT_AUDIT.md                            # This audit (already exists)
  planning/
```

### 2.3 Key Layout Rules (from AGENTS.md)

- `media/` at project root is the single source of truth for code
- `release/ModName/42.0/` is the deployable package — PZ reads `42.0/media/` at startup
- Root-level `media/`, `mod.info`, and `poster.png` are NOT loaded by PZ B42 directly
- `release/` is built from source via sync; deployed via `robocopy /MIR` to `C:\Users\Admin\Zomboid\mods\`
- No symlinks or junctions — plain files only

---

## 3. Trait Inclusion List

All traits use the `UT_` prefix. The **Registration Format** column indicates the B42.13+ pattern used:

- **Script-only:** Defined entirely in `UT_character_traits.txt` (XPBoost, cost, mutual exclusivity). No Lua effect file needed.
- **Script + Lua:** Script definition for cost/UI + a per-trait Lua file for runtime effects.

### 3.1 Phase 1 — Low Complexity (Data-Driven)

These traits are fully defined via `character_trait_definition` script blocks. They require no runtime Lua — the engine handles XPBoost natively via `XPBoosts = Perk=level` in the script.

| UT ID | Display Name | Cost | Type | Source Mod(s) | Notes |
|-------|-------------|------|------|---------------|-------|
| **XP Boost — Prepared Series** | | | | | |
| UT_preparedfood | Prepared: Food | 1 | XPBoost (Cooking×1) | MoreTraits | |
| UT_preparedammo | Prepared: Ammo | 1 | XPBoost (Aiming×1, Reloading×1) | MoreTraits | |
| UT_preparedmedical | Prepared: Medical | 1 | XPBoost (Doctor×1) | MoreTraits | |
| UT_preparedcarpentry | Prepared: Carpentry | 1 | XPBoost (Woodwork×1) | MoreTraits | |
| UT_preparedcamp | Prepared: Camping | 1 | XPBoost (Fishing×1) | MoreTraits | |
| UT_preparedweapons | Prepared: Weapons | 1 | XPBoost (Maintenance×1) | MoreTraits | |
| UT_preparedcars | Prepared: Cars | 1 | XPBoost (Mechanics×1) | MoreTraits | |
| UT_preparedcartography | Prepared: Cartography | 1 | XPBoost (Cartography×1) | MoreTraits | |
| **XP Boost — Movement & Stealth** | | | | | |
| UT_swift | Swift | 2 | XPBoost (Lightfoot×1) | MoreTraits | |
| UT_flexible | Flexible | 3 | XPBoost (Nimble×1) | MoreTraits | |
| UT_quiet | Quiet | 2 | XPBoost (Sneak×1, Lightfoot×1) | MoreTraits | |
| UT_olympian | Olympian | 5 | XPBoost (Sprinting×1, Fitness×1) | MoreTraits | |
| UT_evasive | Evasive | 8 | XPBoost (Nimble×1, Sprinting×1) | MoreTraits | |
| UT_marathonrunner | Marathon Runner | 5 | XPBoost (Sprinting×2) | MoreSimpleTraits | |
| UT_strongnimble | Strong Nimble | 7 | XPBoost (Nimble×2, Strength×1) | MoreSimpleTraits | |
| UT_taut | Taut | 6 | XPBoost (Fitness×2) | MoreSimpleTraits | |
| UT_ninjaway | Ninja Way | 5 | XPBoost (Sneak×2, Lightfoot×1) | MoreSimpleTraits | |
| UT_gymgoer | Gym-Goer | 5 | XPBoost (Fitness×1) | MoreTraits | |
| UT_sprintdemon | Sprint Demon | 1 | XPBoost (Sprinting×1) | SomewhatTraits | |
| UT_trekker | Trekker | 4 | XPBoost (Fitness×1, Sprinting×1) | SomewhatTraits | |
| **XP Boost — Combat (Melee)** | | | | | |
| UT_martial | Martial Artist | 5 | XPBoost (Fitness×1, SmallBlunt×1) | MoreTraits | |
| UT_bladetwirl | Practiced Swordsman | 5 | XPBoost (LongBlade×1, SmallBlade×1) | MoreTraits | |
| UT_blunttwirl | Thuggish | 5 | XPBoost (Blunt×1) | MoreTraits | |
| UT_tavernbrawler | Tavern Brawler | 3 | XPBoost (SmallBlunt×1) | MoreTraits | |
| UT_grunt | Grunt Worker | 4 | XPBoost (Woodwork×1, SmallBlunt×1, Masonry×1, Blacksmith×1) | MoreTraits | |
| UT_actionhero | Action Hero | 8 | XPBoost (multi-combat) | MoreTraits | |
| UT_cruelty | Cruelty | 4 | XPBoost (all weapon perks×1) | MoreSimpleTraits | |
| UT_sharpshooter | Sharpshooter | 6 | XPBoost (Aiming×2) | MoreSimpleTraits | |
| **XP Boost — Combat (Prowess Series)** | | | | | |
| UT_problunt | Prowess: Blunt | 7 | XPBoost (Blunt perks) | MoreTraits | |
| UT_problade | Prowess: Blade | 7 | XPBoost (Blade perks) | MoreTraits | |
| UT_progun | Prowess: Guns | 7 | XPBoost (Gun perks) | MoreTraits | |
| UT_prospear | Prowess: Spear | 7 | XPBoost (Spear×2) | MoreTraits | |
| **XP Boost — Combat (Specialization Series)** | | | | | |
| UT_specweapons | Specialization: Weapons | 12 | XPBoost (multi-weapon×4) | MoreTraits | |
| UT_speccrafting | Specialization: Craftworks | 12 | XPBoost (crafting×4) | MoreTraits | |
| UT_specfood | Specialization: Food & Farm | 12 | XPBoost (food/farm×4) | MoreTraits | |
| UT_specguns | Specialization: Guns | 12 | XPBoost (Aiming×4, Reloading×4) | MoreTraits | |
| UT_specmove | Specialization: Maneuvering | 12 | XPBoost (movement×4) | MoreTraits | |
| UT_specaid | Specialization: First Aid | 12 | XPBoost (Doctor×8) | MoreTraits | |
| UT_terminator | Terminator | 14 | XPBoost (all combat high) | MoreTraits | |
| **XP Boost — CombatTraits Weapon Tree** | | | | | |
| UT_heavyswing | Heavy Swing | 8 | XPBoost (all melee high) | CombatTraits | |
| UT_twohanded | Two-Handed | 8 | XPBoost (two-handed weapons) | CombatTraits | |
| UT_onehanded | One-Handed | 8 | XPBoost (one-handed weapons) | CombatTraits | |
| UT_axes | Axes | 6 | XPBoost (Axe perks) | CombatTraits | |
| UT_twohanded_axes | Two-Handed Axes | 5 | XPBoost (Axe 2h) | CombatTraits | |
| UT_onehanded_axes | One-Handed Axes | 5 | XPBoost (Axe 1h) | CombatTraits | |
| UT_blunts | Blunts | 7 | XPBoost (Blunt perks) | CombatTraits | |
| UT_twohanded_blunts | Two-Handed Blunts | 5 | XPBoost (Blunt 2h) | CombatTraits | |
| UT_onehanded_blunts | One-Handed Blunts | 5 | XPBoost (Blunt 1h) | CombatTraits | |
| UT_long_blunts | Long Blunts | 6 | XPBoost (Long Blunt) | CombatTraits | |
| UT_short_blunts | Short Blunts | 4 | XPBoost (Short Blunt) | CombatTraits | |
| UT_blades | Blades | 7 | XPBoost (Blade perks) | CombatTraits | |
| UT_twohanded_blades | Two-Handed Blades | 5 | XPBoost (Blade 2h) | CombatTraits | |
| UT_onehanded_blades | One-Handed Blades | 5 | XPBoost (Blade 1h) | CombatTraits | |
| UT_long_blades | Long Blades | 6 | XPBoost (Long Blade) | CombatTraits | |
| UT_short_blades | Short Blades | 4 | XPBoost (Short Blade) | CombatTraits | |
| UT_spears | Spears | 6 | XPBoost (Spear perks) | CombatTraits | |
| **XP Boost — Crafting & Knowledge** | | | | | |
| UT_ingenuitive | Ingenuitive | 9 | XPBoost (Electricity×2, MetalWelding×1) | MoreTraits | |
| UT_generator | Generator Knowledge | 2 | XPBoost (Electricity×1) | MoreTraits | |
| UT_tinkerer | Tinkerer | 5 | XPBoost (Electricity×1, Mechanics×1, Tailoring×1, FlintKnapping×1) | MoreTraits | |
| UT_scrapper | Scrapper | 3 | XPBoost (Scavenging×1) + loot find boost | MoreTraits | Stacks additively with Scrounger on shared loot-finding effect; Scavenging XP is a secondary mod-specific skill (no-op if that mod absent) |
| UT_scrounger | Scrounger | 5 | XPBoost (Scavenging×1) + loot find boost | MoreTraits | Stacks additively with Scrapper; both can be taken for stronger combined loot effect |
| UT_natural | Natural Eater | 4 | XPBoost (Cooking×1) | MoreTraits | |
| UT_wildsman | Wildsman | 8 | XPBoost (PlantScavenging×1, Fishing×1) | MoreTraits | |
| UT_mushroomer | Mushroomer | 4 | XPBoost (PlantScavenging×2) | MoreSimpleTraits | |
| UT_antique | Antique Collector | 6 | XPBoost | MoreTraits | |
| UT_blissful | Blissful | 3 | XPBoost | MoreTraits | |
| UT_gordanite | Gordanite | 6 | XPBoost | MoreTraits | |
| UT_graverobber | Grave Robber | 7 | XPBoost | MoreTraits | |
| UT_vagabond | Vagabond | 3 | XPBoost | MoreTraits | |
| UT_crafty | Crafty | 5 | XPBoost (crafting perks) | SomewhatTraits | |
| UT_paramedic | Paramedic | 5 | XPBoost (Doctor×2) | SomewhatTraits | |
| UT_pitcrew | Pit Crew | 5 | XPBoost (Mechanics×2) | SomewhatTraits | |
| UT_prodigy | Prodigy | 6 | XPBoost (all perks×1) | DTEM | |
| UT_driver | Driver | 2 | XPBoost (Driving×1) | RPKDrivingSkill | Detached from custom skill system |
| UT_amateurelectrician | Amateur Electrician | 1 | XPBoost (Electricity×1) | DTEM | |
| **XP Boost — FillerTraits (non-cheat)** | | | | | |
| UT_trackman | Trackman | 6 | XPBoost | FillerTraits | |
| UT_cleaver | Cleaver | 4 | XPBoost (LongBlade×1) | FillerTraits | |
| UT_woodsplitter | Wood Splitter | 4 | XPBoost (Axe×1) | FillerTraits | |
| UT_improviser | Improviser | 4 | XPBoost (Maintenance×1) | FillerTraits | |
| **Stat Modifier — Simple (No Runtime Logic)** | | | | | |
| UT_packmule | Pack Mule | 7 | Stat: +carry weight | MoreTraits | |
| UT_packmouse | Pack Mouse | -7 | Stat: -carry weight | MoreTraits | |
| UT_gimp | Slowpoke | -8 | Stat: -speed | MoreTraits | |
| UT_anemic | Anemic | -4 | Stat modifier | MoreTraits | |
| UT_badteeth | Bad Teeth | -3 | Stat modifier | MoreTraits | |
| UT_deprived | Deprived | -6 | Stat modifier | MoreTraits | |
| UT_couchdweller | Couch Dweller | 2 | Stat modifier | SomewhatTraits | |
| UT_sloth | Sloth | 2 | Stat modifier | SomewhatTraits | |
| UT_squirrel | Squirrel | 2 | Stat: +carry weight | SomewhatTraits | |
| UT_antivaxxer | Anti-Vaxxer | -3 | Stat modifier | SomewhatTraits | |
| UT_flimsy | Flimsy | -4 | Stat modifier | SomewhatTraits | |
| UT_sundayrunner | Sunday Runner | -1 | Stat: -sprint speed | SomewhatTraits | |
| UT_lesssweaty | Less Sweaty | 2 | Stat: -sweat/smell | MoreSimpleTraits | |
| UT_highsweaty | High Sweaty | -3 | Stat: +sweat/smell | MoreSimpleTraits | |
| UT_cangrabmore | Can Grab More | 2 | Stat modifier | MoreSimpleTraits | |
| UT_cangrabless | Can Grab Less | -2 | Stat modifier | MoreSimpleTraits | |
| UT_backpacker | Backpacker | 8 | Stat: +carry weight | FillerTraits | |
| UT_topheavy | Topheavy | -4 | Stat modifier | FillerTraits | |
| UT_sore | Sore | -6 | Stat modifier | FillerTraits | |
| UT_staunch | Staunch | 10 | Stat modifier | FillerTraits | |

**Phase 1 total: ~96 traits** (all script-only, no runtime Lua required)

---

### 3.2 Phase 2 — Medium Complexity (Runtime Stat Modifiers & hasTrait Checks)

These traits need a Lua effect file that runs at character creation or checks `hasTrait` at specific low-frequency moments. They do NOT fire on every game tick.

| UT ID | Display Name | Cost | Effect Type | Event Frequency | Source Mod(s) | Notes |
|-------|-------------|------|-------------|-----------------|---------------|-------|
| **Stat Modifiers (Applied Once at Spawn or on Specific Events)** | | | | | | |
| UT_preparedpack | Prepared: Pack | 1 | Stat: +inventory slots at spawn | Once (OnNewGame) | MoreTraits | |
| UT_fast | Fast | 6 | Stat: +movement speed | Once (OnNewGame) | MoreTraits | |
| UT_thickblood | Thick Blooded | 4 | Stat: reduced bleed rate | Once (OnNewGame) | MoreTraits | |
| UT_leadfoot | Lead Foot | 2 | Stat: +vehicle speed | Per vehicle enter | MoreTraits | |
| UT_quickworker | Quick Worker | 9 | Stat: +work speed | Once (OnNewGame) | MoreTraits | |
| UT_batteringram | Battering Ram | 7 | Stat: +push/shove | Once (OnNewGame) | MoreTraits | |
| UT_fitted | Fitted | 4 | Stat: -encumbrance | Once (OnNewGame) | MoreTraits | |
| UT_restfulsleeper | Restful Sleeper | 6 | Stat: +sleep quality | Per sleep event | MoreTraits | |
| UT_unwavering | Unwavering | 6 | Stat: panic resistance | On panic event | MoreTraits | |
| UT_idealweight | Ideal Weight | 4 | Stat modifier | Once (OnNewGame) | MoreTraits | |
| UT_quickrest | Quick Rest | 3 | Stat: +rest recovery | Per sleep event | MoreTraits | |
| UT_glassbody | Glass Body | -10 | Stat: +damage taken | Once (OnNewGame) | MoreTraits | |
| UT_slowworker | Slow Worker | -9 | Stat: -work speed | Once (OnNewGame) | MoreTraits | |
| UT_mundane | Mundane | -9 | Stat: global XP penalty | Once (OnNewGame) | MoreTraits | |
| UT_incomprehensive | Incomprehensive | -10 | Stat: skill cap reduction | Once (OnNewGame) | MoreTraits | |
| UT_noodlelegs | Noodle Legs | -6 | Stat: -speed | Once (OnNewGame) | MoreTraits | |
| UT_antigun | Anti-Gun Activist | -6 | Stat: -firearms | Once (OnNewGame) | MoreTraits | |
| UT_pacer | Pacer | 4 | Stat: +walking speed | Once (OnNewGame) | SomewhatTraits | |
| UT_ironliver | Iron Liver | 3 | Stat: alcohol tolerance | On consume | SomewhatTraits | |
| UT_brittle | Brittle | -6 | Stat: +fracture chance | On injury event | SomewhatTraits | |
| UT_flailer | Flailer | -4 | Stat: -combat accuracy | Per attack | SomewhatTraits | |
| UT_flatearther | Flat Earther | -4 | Stat: -reading speed | Per read event | SomewhatTraits | |
| UT_luddite | Luddite | -4 | Stat: -electrical XP | Once (OnNewGame) | SomewhatTraits | |
| UT_lurcher | Lurcher | -5 | Stat: -movement | Once (OnNewGame) | SomewhatTraits | |
| UT_onetrickpony | One Trick Pony | -4 | Stat: multi-skill penalty | Once (OnNewGame) | SomewhatTraits | |
| UT_owlperson | Night Owl | -1 | Stat: night vision / day penalty | Time-of-day check | MoreSimpleTraits | |
| UT_larkperson | Early Bird | -1 | Stat: day bonus / night penalty | Time-of-day check | MoreSimpleTraits | |
| UT_slack | Slack | -6 | Stat: -work speed | Once (OnNewGame) | MoreSimpleTraits | |
| UT_sorelegs | Sore Legs | -8 | Stat: -speed, -fitness | Once (OnNewGame) | MoreSimpleTraits | |
| UT_snorer | Snorer | -2 | Stat: +noise while sleeping | Per sleep event | MoreSimpleTraits | |
| UT_heavilybleedingwounds | Heavily Bleeding Wounds | -4 | Stat: +bleed rate | Once (OnNewGame) | MoreSimpleTraits | |
| UT_weaklybleedingwounds | Weakly Bleeding Wounds | 3 | Stat: -bleed rate | Once (OnNewGame) | MoreSimpleTraits | |
| UT_durability | Durability | 3 | Stat: +item durability | Per use event | MoreSimpleTraits | |
| UT_analgesia | Analgesia | 10 | Stat: pain disable | Once (OnNewGame) | FillerTraits | |
| UT_photographicmemory | Photographic Memory | 20 | Stat: +reading/skill | Once (OnNewGame) | FillerTraits | |
| UT_fasthands | Fast Hands | 12 | Stat modifier | Once (OnNewGame) | FillerTraits | |
| **No-XP Series (Negative Traits)** | | | | | | |
| UT_noxpshooter | No XP: Shooting | 3 | XP disable (firearms) | Once (OnNewGame) | MoreTraits | |
| UT_noxptechnician | No XP: Tech | 3 | XP disable (tech perks) | Once (OnNewGame) | MoreTraits | |
| UT_noxpaxe | No XP: Axe | 3 | XP disable (Axe) | Once (OnNewGame) | MoreTraits | |
| UT_noxpfirstaid | No XP: First Aid | 3 | XP disable (Doctor) | Once (OnNewGame) | MoreTraits | |
| UT_noxpmaintenance | No XP: Maintenance | 3 | XP disable (Maintenance) | Once (OnNewGame) | MoreTraits | |
| UT_noxpsneaky | No XP: Sneaky | 3 | XP disable (Sneak/Lightfoot) | Once (OnNewGame) | MoreTraits | |
| **hasTrait Checks (Low-Frequency)** | | | | | | |
| UT_expertdriver | Expert Driver | 5 | hasTrait check in vehicle code | Per vehicle tick | MoreTraits | |
| UT_poordriver | Student Driver | -5 | hasTrait check in vehicle code | Per vehicle tick | MoreTraits | |
| UT_gourmand | Gourmand | 4 | hasTrait check on eat | Per eat event | MoreTraits | |
| UT_ascetic | Ascetic | -4 | hasTrait check on eat (restrict) | Per eat event | MoreTraits | |

**Phase 2 total: ~45 traits**

---

### 3.3 Phase 3 — High Complexity (Event-Driven Runtime Logic)

Each trait in this phase requires individual risk assessment before implementation begins. These traits fire event handlers at runtime and maintain state.

| UT ID | Display Name | Cost | Event Pattern | Frequency Profile | Source Mod(s) | Risk Notes |
|-------|-------------|------|---------------|-------------------|---------------|------------|
| **Stamina & Endurance** | | | | | | |
| UT_indefatigable | Indefatigable | 10 | Stamina system with cooldown state | Per-tick while active | MoreTraits | Needs cooldown to avoid per-tick cost; implement as periodic check (every N ticks) |
| UT_hardy | Hardy | 6 | Endurance tracking, sub-state traits | Per exertion event | MoreTraits | Sub-state traits add complexity; consider simplifying to stat modifiers |
| UT_secondwind | Second Wind | 10 | Stamina recovery trigger | On stamina-depleted event | MoreTraits | Needs internal cooldown to prevent exploit loops |
| **Immune System** | | | | | | |
| UT_superimmune | Super-Immune | 10 | Infection resistance handler | Per infection check | MoreTraits | Sub-state notification traits; verify B42 infection API |
| UT_immunocompromised | Immunocompromised | -10 | Infection vulnerability | Per infection check | MoreTraits | Mirror of superimmune |
| UT_immuneresponse | Immune Response | 4 | Illness recovery boost | Per health tick | SomewhatTraits | Must not fire every game tick — use periodic check |
| **Mood & Panic** | | | | | | |
| UT_depressive | Depressive | -4 | Mood penalty handler | Periodic (every 10min game time) | MoreTraits | Must NOT fire per-tick; use timer-based check |
| UT_fearful | Fearful | -7 | Panic boost handler | On panic trigger event | MoreTraits | Event-driven — acceptable frequency |
| UT_paranoia | Paranoia | -4 | Ambient panic handler | Periodic (every 10min) | MoreTraits | Must NOT fire per-tick |
| UT_selfdestructive | Self-Destructive | -4 | Self-harm handler | Periodic | MoreTraits | Needs careful state management |
| UT_melancholic | Melancholic | -4 | Mood penalty | Periodic | DTEM | Similar to depressive — share logic via UT_CORE |
| UT_nervouswreck | Nervous Wreck | -4 | Panic amplifier | On panic trigger | DTEM | |
| UT_scardycat | Scaredy Cat | -3 | Panic amplifier | On panic trigger | SomewhatTraits | |
| UT_maniac | Maniac | 4 | Combat mood boost | On kill event | SomewhatTraits | Event-driven — acceptable |
| UT_optimist | Optimist | 7 | Mood bonus handler | Periodic | FillerTraits | |
| UT_pessimist | Pessimist | -4 | Mood penalty handler | Periodic | FillerTraits | |
| UT_mstoptimist | Upbeat | 2 | Mood bonus handler | Periodic | MoreSimpleTraits | Different power level from FT Optimist |
| **Substance & Dietary** | | | | | | |
| UT_alcoholic_I | Alcoholic I | -3 | Alcohol craving (mild) | Periodic (every 30min) | SomewhatTraits (`SWDrunkard`) | Tier 1 — see Section 6 |
| UT_alcoholic_II | Alcoholic II | -8 | Alcohol craving (moderate) | Periodic (every 15min) | DTEM (`Alcoholic`) | Tier 2 |
| UT_alcoholic_III | Alcoholic III | -14 | Alcohol craving (severe) | Periodic (every 5min) | MoreTraits (`drinker`) | Tier 3 — most punishing |
| UT_anorexy | Anorexia | -6 | Food restriction handler | Per eat event | DTEM | |
| UT_addictedtocaffeine | Addicted to Caffeine | -4 | Caffeine craving handler | Periodic | DTEM | |
| UT_pillsallergy | Allergic to Pills | -6 | Medicine reaction | Per consume event | DTEM | Event-driven — acceptable |
| UT_wildplantsallergy | Allergic to Wild Plants | -4 | Plant reaction handler | Per consume event | DTEM | |
| UT_allergic | Allergic | -3 | General allergy handler | Per consume event | MoreSimpleTraits | |
| UT_competitiveeater | Competitive Eater | 4 | Food bonus handler | Per eat event | SomewhatTraits | |
| UT_ravenous | Ravenous | -2 | Hunger amplifier | Periodic | SomewhatTraits | |
| UT_sensitivestomach | Sensitive Stomach | -2 | Food reaction handler | Per eat event | MoreSimpleTraits | |
| UT_adaptivemetabolism | Adaptive Metabolism | 5 | Metabolism handler | Periodic | SomewhatTraits | |
| UT_accmetabolism | Accelerated Metabolism | 2 | Food/weight handler | Periodic | MoreSimpleTraits | |
| **Physical Conditions** | | | | | | |
| UT_motionsickness | Motion Sickness | -6 | Vehicle nausea handler | Per vehicle tick | MoreTraits | **Flag: fires per vehicle tick — needs throttle** |
| UT_albino | Sun Sensitivity | -5 | UV damage handler | Periodic outdoor check | MoreTraits | Must NOT fire per-tick; use periodic outdoor check |
| UT_butterfingers | Butterfingers | -12 | Item drop handler | Per item action | MoreTraits | Event-driven — acceptable |
| UT_amputee | Amputee | -16 | Complex limb system | Multiple events | MoreTraits | **Highest complexity trait — defer to Phase 3b** |
| UT_fibromyalgia | Fibromyalgia | -10 | Pain system handler | Periodic | DTEM | |
| UT_bigorexia | Bigorexia | -8 | Body image handler | Periodic | DTEM | |
| UT_acrophobic | Acrophobic | -3 | Height fear handler | Per floor-change event | SomewhatTraits | |
| UT_vehophobic | Vehophobic | -6 | Vehicle fear handler | Per vehicle enter | SomewhatTraits | Event-driven — acceptable |
| UT_weathersensitive | Weather Sensitive | -2 | Weather mood handler | Per weather change | MoreSimpleTraits | |
| UT_panicattacks | Panic Attacks | -4 | Random panic handler | Periodic (random interval) | MoreSimpleTraits | |
| UT_fearofthedark | Fear of the Dark | -1 | Darkness mood handler | Periodic light check | MoreSimpleTraits | |
| **Spawn-With-Condition** | | | | | | |
| UT_injured_I | Injured I | -4 | Spawns with minor injury | Once (OnNewGame) | SomewhatTraits / MoreTraits | Tier 1 — see Section 6 |
| UT_injured_II | Injured II | -8 | Spawns with serious injury | Once (OnNewGame) | New tier (gap fill) | Tier 2 |
| UT_broke | Broke Leg | -8 | Spawns with broken leg | Once (OnNewGame) | MoreTraits | |
| UT_burned | Burned | -20 | Spawns with burns | Once (OnNewGame) | MoreTraits | |
| **Temperature & Environment** | | | | | | |
| UT_coldsensitive | Cold Sensitive | -2 | Temperature handler | Periodic | SomewhatTraits | |
| UT_heatsensitive | Heat Sensitive | -2 | Temperature handler | Periodic | SomewhatTraits | |
| **Fitness & Physical** | | | | | | |
| UT_physicallyactive | Physically Active | 10 | Fitness gain handler | Per exercise event | DTEM | |
| UT_sedentary | Sedentary | -10 | Fitness loss handler | Periodic | DTEM | |
| UT_humanhamster | Human Hamster | 3 | Storage system handler | Per inventory event | SomewhatTraits | |
| **Tiered — Bouncer** | | | | | | |
| UT_bouncer_I | Bouncer I | 4 | XPBoost (combat) | Script-only | SomewhatTraits | Tier 1 — lower power |
| UT_bouncer_II | Bouncer II | 5 | XPBoost (Strength×1, SmallBlunt×1) | Script-only | MoreTraits | Tier 2 — higher power |
| **Tiered — Gun Specialist** | | | | | | |
| UT_gunspecialist_I | Gun Specialist I | 4 | XPBoost (Aiming×1, Reloading×1) | Script-only | MST (`Gunfan`) | Tier 1 |
| UT_gunspecialist_II | Gun Specialist II | 6 | XPBoost (Aiming×2, Reloading×2, Nimble×1) | Script-only | B42_RainsFirearms | Tier 2 |
| UT_gunspecialist_III | Gun Specialist III | 8 | XPBoost (Aiming×2, Reloading×2) | Script-only | MoreTraits | Tier 3 |

**Phase 3 total: ~55 traits**

> **Note on Bouncer and Gun Specialist tiers:** These are XPBoost-only and could technically ship in Phase 1, but their deduplication decisions and tier balancing warrant the extra review cycle of Phase 3 planning. They may be promoted to Phase 1 after review.

**Phase 3b (Deferred — Individual Risk Assessment Required):**

- `UT_amputee` — the most complex trait in the entire set. Requires a custom limb system with multiple body part states, equipment restrictions, and animation hooks. Must be prototyped and tested in isolation before inclusion.

---

## 4. Trait Exclusion List

| Trait / Mod | Reason for Exclusion |
|-------------|---------------------|
| **EvolvingTraitsWorld (all 22 traits)** | Different paradigm — earned during gameplay, not character-creation. Out of scope for this mod. See Section 10 for compatibility notes. |
| **LastPushTrait (`LastPush`)** | Dynamic/earned trait (cost=0, granted at runtime). Not a character-creation trait. |
| **DynamicTraitsExpandedMoodles vanilla re-registers (~80 traits)** | Re-registers vanilla traits with `cost=0`. This is the highest conflict risk pattern — violates the "never override vanilla" rule. |
| **300PointsTrait (`300Points`)** | Point economy mod (-300 cost). Not a trait — it's a point cheat. |
| **InfiniteTraitPointsB42** | UI mod that removes the point cap. Contains no trait content. |
| **ToughnessSkill (`tough`)** | Tightly coupled to a custom Toughness skill system. The trait cannot be meaningfully separated from its skill tree without reimplementation. Out of scope for Phase 1-3; could be revisited if custom skill integration is added later. |
| **FillerTraits cheat traits** | `Invincible` (cost 0), `Indomitable` (cost 0), `Immune` (cost 22 but grants total immunity) — these are cheat-tier traits that break game balance. |
| **FillerTraits `Frail`** | ID conflict with DTEM's `Frail` (cost=0 dynamic). The concept is already covered by `UT_flimsy` and `UT_glassbody`. |
| **FillerTraits `BearBelly`** | 12-point carry weight boost is excessively strong; `UT_backpacker` (8pt) and `UT_packmule` (7pt) already cover this niche. |
| **FillerTraits `BigLeague`, `BrushClearer`, `Axmen`** | 12-point XPBoost traits that overlap directly with the CombatTraits weapon tree. The SW weapon tree is better structured with mutual exclusivity. |
| **MoreTraits vanilla re-registers** | `Lucky`, `Unlucky`, `LightDrinker`, `HeavyDrinker` — these re-register vanilla trait IDs. Excluded per the "never override vanilla" rule. |
| **MoreSimpleTraits (entire mod)** | Not B42-versioned (uses root `media/` layout). All unique traits from this mod that are worth keeping are sourced from their content (display names, costs, effects) and re-implemented under UT_ IDs. The mod itself is not a dependency. Where MST and DTEM share IDs, the better-implemented version was chosen. |
| **SomewhatTraits `SWFrogCompanion`** | Tonally inconsistent with a character-trait mod. Novelty/flavor trait that spawns a frog companion — excluded for tonal consistency. |
| **DynamicTraitsExpandedMoodles `Nightmares`** | cost=0 suggests dynamic/earned trait, not character-creation. |
| **CombatTraits `Melee-matician`** | Hyphen in ID (`Melee-matician`) is a Lua key lookup risk. The standalone MeleematricianTrait mod uses the same ID at a different cost (4 vs 12). Both excluded — the concept is covered by `UT_heavyswing`. |
| **CombatTraits commented-out traits** | `SWTwoHandedSpears`, `SWOneHandedSpears` — commented out in source, not currently active. |
| **MoreSimpleTraits ID-conflict traits** | `Sneaky`, `Lightfooted`, `Nimble`, and all `AM`-prefixed IDs conflict with DTEM. These are simple XPBoost traits already covered by UT equivalents. |

---

## 5. Implementation Phases

### Phase 1: Data-Driven Traits (Ship First)

**Scope:** ~96 XPBoost and simple stat-modifier traits that are fully defined in `character_trait_definition` script blocks. Zero runtime Lua.

**Deliverables:**

1. `UT_CORE` mod skeleton (mod.info, folder structure, empty API stubs)
2. `UniversalTraits/media/registries.lua` — registers all Phase 1 trait IDs via `CharacterTrait.register()`
3. `UniversalTraits/media/scripts/UT_character_traits.txt` — all `character_trait_definition` blocks with `XPBoosts`, `Cost`, `UIName`, `UIDescription`
4. `UniversalTraits/media/lua/shared/UniversalTraits/UT_MET.lua` — mutual exclusivity rules (especially for the CombatTraits weapon tree)
5. `UniversalTraits/media/lua/client/UniversalTraits/UT_Translations.lua` — all UI string registrations
6. Release folder sync, deployment, in-game verification

**Exit criteria:** All Phase 1 traits appear in character creation screen with correct names, costs, descriptions, XPBoosts, and mutual exclusivity rules. No errors in console.

### Phase 2: Stat Modifier & hasTrait Traits

**Scope:** ~45 traits that need a Lua file for stat modification at spawn or low-frequency hasTrait checks.

**Deliverables:**

1. `UT_CORE` stat modifier helpers (`UTCore_StatModifiers.lua`) — shared functions for speed modifiers, carry weight, bleed rate, work speed, etc.
2. Per-trait Lua files in `traits/` directory
3. Updated `registries.lua` and script file with Phase 2 trait definitions
4. Updated MET with new mutual exclusivity rules

**Exit criteria:** All Phase 2 traits function correctly in-game. Stat modifiers verified via debug overlay or console inspection.

### Phase 3: Event-Driven Runtime Traits

**Scope:** ~55 traits with runtime event handlers. Each trait requires individual risk assessment.

**Pre-implementation gate for each trait:**

1. Identify the exact PZ event(s) the trait hooks into
2. Measure or estimate the event's fire frequency
3. Design a throttling/caching strategy if the event fires more than once per in-game minute
4. Document the state the trait needs to track and how it persists across save/load
5. Write the trait's effect file using UT_CORE helpers

**Sub-phases:**

- **3a:** Spawn-with-condition traits (injured, broke, burned) — fire once at OnNewGame, lowest runtime risk
- **3b:** Periodic-check traits (mood, panic, temperature, metabolism) — must use timer-based checks, never per-tick
- **3c:** Event-driven traits (on-eat, on-kill, on-consume, on-vehicle-enter) — acceptable frequency, event-driven
- **3d:** Complex state traits (indefatigable, hardy, secondwind, amputee) — require full state management and save/load support

**Exit criteria:** Each trait passes individual risk assessment, functions correctly in extended play sessions (30+ in-game days), and does not measurably impact frame rate.

---

## 6. Deduplication Decisions

### 6.1 Alcoholic Variants → Tier Series

| Source | Original ID | Original Cost | Assessment |
|--------|------------|---------------|------------|
| SomewhatTraits | `SWDrunkard` | -3 | Mildest — occasional craving |
| DTEM | `Alcoholic` | -8 | Moderate — regular craving with withdrawal |
| MoreTraits | `drinker` | -14 | Severe — constant craving, heavy penalties |

**Decision:** Consolidate into `UT_alcoholic_I` (-3), `UT_alcoholic_II` (-8), `UT_alcoholic_III` (-14). Three meaningfully different power levels justify a tier series. The tiers are mutually exclusive with each other. Display names: "Alcoholic I", "Alcoholic II", "Alcoholic III".

Implementation: Shared craving/withdrawal logic in UT_CORE with configurable severity passed by each tier's effect file.

### 6.2 Injured-Start Variants → Tier Series

| Source | Original ID | Original Cost | Assessment |
|--------|------------|---------------|------------|
| SomewhatTraits | `SWInjured` | -4 | Minor injury at spawn |
| MoreTraits | `injured` | -4 | Same cost, similar concept |

**Decision:** Both have the same cost but the implementations may differ in injury severity. Consolidate into `UT_injured_I` (-4, minor injury) and `UT_injured_II` (-8, serious injury — new tier filling a gap). The original implementations are functionally similar enough that one tier would suffice, but the -8 tier adds design space for players who want a harder start without taking `UT_broke` (-8, broken leg) or `UT_burned` (-20).

Implementation: Shared spawn-injury logic in `UTCore_SpawnEffects.lua` with configurable injury tables.

### 6.3 Gun Specialist Variants → Tier Series

| Source | Original ID | Original Cost | Assessment |
|--------|------------|---------------|------------|
| MoreSimpleTraits | `Gunfan` | 4 | Aiming×1, Reloading×1 |
| B42_RainsFirearms | `gunenthusiastRFNGP` | 6 | Aiming×2, Reloading×2, Nimble×1 |
| MoreTraits | `gunspecialist` | 8 | Aiming×2, Reloading×2 |

**Decision:** Three distinct power levels. Consolidate into `UT_gunspecialist_I` (4pt), `UT_gunspecialist_II` (6pt), `UT_gunspecialist_III` (8pt). Mutually exclusive with each other and with `UT_specguns` (12pt Specialization: Guns).

Note: The Tier II version from B42_RainsFirearms includes Nimble×1 which the others don't — this is a meaningful differentiation, not just a power scaling. Preserve it.

### 6.4 Bouncer Variants → Tier Series

| Source | Original ID | Original Cost | Assessment |
|--------|------------|---------------|------------|
| SomewhatTraits | `SWBouncer` | 4 | XPBoost (lower power) |
| MoreTraits | `bouncer` | 5 | XPBoost (Strength×1, SmallBlunt×1) |

**Decision:** Marginally different power levels. Consolidate into `UT_bouncer_I` (4pt) and `UT_bouncer_II` (5pt). Mutually exclusive with each other. The cost and XPBoost differences are small but the source mods valued them differently, so preserving both tiers respects the original mod authors' balance intentions.

---

## 7. Conflict Prevention Rules

These rules are mandatory for all UniversalTraits code:

1. **UT_ prefix on all trait IDs.** Every trait registered by this mod must use the `UT_` prefix (e.g., `UT_swift`, `UT_gunspecialist_II`). No exceptions.

2. **Never re-register vanilla traits.** Do not call `CharacterTrait.register()` with any ID that exists in the base game's `character_traits.txt`. Do not modify vanilla trait costs, descriptions, or XPBoosts.

3. **Never assume load order.** All UT code must function regardless of whether other trait mods load before or after it. Use `CharacterTrait.register("UniversalTraits:UT_xxx")` with the mod namespace prefix to guarantee uniqueness.

4. **Namespace all registry entries.** Use `UniversalTraits:UT_xxx` as the full registry path (matching the SomewhatTraits/CombatTraits pattern of `ModName:TraitID`).

5. **No global table pollution.** All UT Lua state must live under a single `UniversalTraits` or `UT` global table. Do not add keys to `_G`, `ISBaseObject`, or any vanilla table.

6. **No monkey-patching vanilla functions.** Do not override, wrap, or replace any vanilla Lua function. Use the PZ event system (`Events.OnXxx.Add()`) for all hooks.

7. **Defensive hasTrait checks.** When checking for a trait, always use the full namespaced ID. Never assume a trait exists — guard with nil checks.

8. **Script module isolation.** All `character_trait_definition` blocks must be inside a `module UniversalTraits { }` block in the script file, preventing name collisions with other mods' script modules.

9. **No file path collisions.** All Lua files must be under `lua/shared/UniversalTraits/` or `lua/client/UniversalTraits/` — never in a generic or shared namespace that another mod might also use.

10. **Save/load safety.** Any trait that stores persistent state must use PZ's ModData system with a `UT_` prefixed key. Never store state in global variables that don't survive save/load.

---

## 8. Event Frequency Profiles

Traits that fire runtime logic must be classified by event frequency to prevent performance issues.

| Category | Max Acceptable Frequency | Pattern | Traits |
|----------|------------------------|---------|--------|
| **Once (OnNewGame)** | 1× per game | Apply stat at spawn, never again | All spawn-condition traits, most stat modifiers |
| **Per-event (low freq)** | 1-10× per in-game day | On eat, on consume, on kill, on vehicle enter/exit | Dietary traits, combat mood traits, vehicle traits |
| **Periodic (timer)** | Every 10-30 game minutes | Timer-based check, NOT per-tick | Mood traits, panic traits, craving traits, temperature |
| **Per-tick** | 60× per real second | **FORBIDDEN for trait logic** | None — any trait that would need per-tick must be redesigned |

**Performance rules:**

- No trait handler may run on `EveryOneMinute` or faster unless it contains only a single `hasTrait` check and early-return
- All periodic traits must use `Events.EveryTenMinutes` or slower by default
- Traits that check environmental conditions (weather, light, temperature) must cache the result and only recompute on the relevant change event
- Motion sickness (`UT_motionsickness`) must throttle its vehicle-tick handler to check only every N ticks, not every frame

---

## 9. UT_CORE Decision and Specification

### Decision: GO

**Reasoning:**

The trait set includes ~55 high-complexity traits that share significant infrastructure:

| Shared Pattern | Trait Count Using It | Without UT_CORE | With UT_CORE |
|---------------|---------------------|-----------------|--------------|
| Stat modifier application at spawn | ~35 | Each trait duplicates stat-setting boilerplate | Single `UTCore.applyStat(player, stat, value)` call |
| Periodic timer-based checks | ~20 | Each trait registers its own timer event | Single timer dispatcher calls registered trait handlers |
| Spawn-with-condition (injury/burns) | ~4 | Each trait duplicates body damage setup | Single `UTCore.applySpawnCondition(player, condition)` |
| Craving/withdrawal loop | ~5 | Each substance trait duplicates craving logic | Parameterized `UTCore.cravingLoop(player, substance, severity)` |
| Mood modifier application | ~8 | Duplicate mood math | Single `UTCore.applyMoodModifier(player, amount, reason)` |
| hasTrait defensive wrapper | All scripted traits | Repeated nil-check boilerplate | Single `UTCore.hasTrait(player, id)` |

Without UT_CORE, the `traits/` directory would contain ~55 files each with 30-60 lines of duplicated setup, event registration, and stat application code. With UT_CORE, each trait file becomes a thin declarative call into shared infrastructure — typically 5-15 lines.

The abstraction is **earned** — it serves at least 5 distinct shared patterns used by 20+ traits each.

**Trade-off assessment:**

- Load complexity: +1 mod dependency (trivial for single-player; player enables both in mod list)
- Maintenance overhead: Lower — bug fixes in shared logic propagate to all traits automatically
- Mod size: Marginally larger total, but each individual trait file is much smaller and more auditable
- Abstraction cost: Justified by the trait count and pattern repetition

### UT_CORE API Surface

```text
UTCore_API.lua (public API)
├── UTCore.applyStat(player, statName, value)        -- Apply a stat modifier at spawn
├── UTCore.applyXPModifier(player, perk, multiplier) -- Apply XP rate modifier
├── UTCore.applySpawnCondition(player, conditionTable) -- Apply injury/burn/break at spawn
├── UTCore.hasTrait(player, traitId)                 -- Defensive hasTrait check (nil-safe)
├── UTCore.registerPeriodicHandler(traitId, intervalEvent, handlerFn) -- Register a periodic check
├── UTCore.unregisterPeriodicHandler(traitId)        -- Clean up on trait removal
├── UTCore.applyMoodModifier(player, amount, reason) -- Apply mood change
├── UTCore.getModData(player, key, default)          -- Safe ModData access with UT_ prefix
└── UTCore.setModData(player, key, value)            -- Safe ModData write with UT_ prefix

UTCore_Events.lua (event infrastructure)
├── Centralized event listener registration
├── Timer dispatcher for periodic-check traits
└── Save/load hooks for persistent trait state

UTCore_StatModifiers.lua (stat helpers)
├── Speed modifier helpers
├── Carry weight helpers
├── Bleed rate helpers
├── Work speed helpers
└── Damage multiplier helpers

UTCore_SpawnEffects.lua (spawn condition helpers)
├── Injury application (configurable severity)
├── Burn application
├── Fracture application
└── Equipment restriction helpers

UTCore_TraitChecks.lua (hasTrait wrappers)
├── Single-trait check
├── Any-of-set check (for tier series)
└── Mutual exclusivity enforcement at runtime
```

### What UT_CORE Does NOT Contain

- Trait definitions (those live in UniversalTraits)
- Translation strings
- UI code
- Any mod-specific game logic
- Trait-specific game logic that cannot plausibly be reused. The bar for inclusion in UT_CORE is not "currently used by 2+ traits" — it is "represents a general pattern that future traits would reasonably need." A helper for applying spawn injuries belongs in UT_CORE even if only one trait uses it today, because spawn-with-condition is a clear category that invites future expansion. A helper that calculates frog companion pathing does not, because that is inherently specific to one trait concept. When in doubt, ask: "If someone added a new trait tomorrow, would they reach for this helper?" If yes, it belongs in UT_CORE.

---

## 10. ETW Compatibility Note

### Findings

Evolving Traits World (Workshop 2914075159) registers 22 earned traits via the standard `CharacterTrait.register()` API. There is **no external mod integration API** — ETW does not expose a registration function, compatibility layer, or hook system for other mods to register traits with it.

ETW's trait registration file (`ETWRegistryType.lua`) declares traits as metadata types but provides no public API for external mods to register or interact with.

### Compatibility Recommendations

1. **ID collision avoidance:** UniversalTraits uses the `UT_` prefix on all IDs. ETW uses unprefixed IDs (`Bloodlust`, `GymRat`, etc.). No collision risk exists between the two mods.

2. **Stacking awareness (README note).** Some UT traits cover similar ground to ETW earned traits (e.g., `UT_gunspecialist` vs ETW `GunEnthusiast`). UT traits are selected at character creation; ETW traits are earned during play. A player could have both, and the effects would stack. This is by design — the character-creation trait represents innate aptitude, the ETW trait represents practiced skill. However, if the combined stacking would produce absurdly strong effects, this should be documented in the mod's README compatibility section as a warning with specific examples. It is not UniversalTraits' job to prevent stacking — but it is polite to warn players which combinations may be overpowered when used alongside specific mods.

3. **No active integration needed.** Since ETW exposes no API, there is nothing for UT to hook into. If a future ETW version adds a mod registration API, UT's clean `UT_`-prefixed structure would make integration straightforward.

4. **Pluviophile / Pluviophobia — excluded.** These weather-mood traits have ID collisions across DTEM and ETW. Rather than implementing conditional registration (which adds load-time complexity and requires API verification), these traits are excluded from UniversalTraits entirely. Added to the Future Research list (Section 14) for potential revisiting.

---

## 11. Mutual Exclusivity Rules

The following mutual exclusivity groups must be enforced in `UT_MET.lua`:

| Group | Traits | Rule |
|-------|--------|------|
| Alcoholic tier | UT_alcoholic_I, II, III | Pick one |
| Injured tier | UT_injured_I, II | Pick one |
| Gun Specialist tier | UT_gunspecialist_I, II, III | Pick one; also exclusive with UT_specguns |
| Bouncer tier | UT_bouncer_I, II | Pick one |
| Combat weapon tree | All UT_heavyswing, UT_twohanded, UT_onehanded, UT_axes, ... | Follows CombatTraits hierarchy — specifics exclude generals |
| Speed positive vs negative | UT_fast vs UT_noodlelegs, UT_gimp | Cannot take both |
| Carry weight positive vs negative | UT_packmule, UT_squirrel, UT_backpacker vs UT_packmouse, UT_topheavy | Positive excludes negative |
| Bleed rate positive vs negative | UT_thickblood, UT_weaklybleedingwounds vs UT_heavilybleedingwounds | Cannot take both |
| Work speed positive vs negative | UT_quickworker vs UT_slowworker, UT_slack | Cannot take both |
| Mood positive vs negative | UT_optimist, UT_mstoptimist, UT_blissful vs UT_depressive, UT_melancholic, UT_pessimist | Cannot take both categories |
| Immune positive vs negative | UT_superimmune, UT_immuneresponse vs UT_immunocompromised | Cannot take both |
| Metabolism variants | UT_adaptivemetabolism vs UT_accmetabolism | Different systems — pick one |
| Panic variants | UT_fearful, UT_scardycat, UT_nervouswreck, UT_panicattacks | Pick one (stacking would be degenerate) |
| Sweat variants | UT_lesssweaty vs UT_highsweaty | Cannot take both |
| Grab variants | UT_cangrabmore vs UT_cangrabless | Cannot take both |
| Night/Day | UT_owlperson vs UT_larkperson | Cannot take both |
| Driver variants | UT_expertdriver vs UT_poordriver | Cannot take both |

---

## 12. Resolved Questions

These questions were raised during PRD drafting and resolved before finalization.

### Q1: Cost rebalancing

**Decision:** Preserve original costs by default. Rebalance only where logically obvious — specifically where deduplication produced tier series (Alcoholic I/II/III, Gun Specialist I/II/III, etc.) and the original costs need adjustment to form a coherent progression, or where a trait's function was modified during consolidation in a way that changes its power level. No speculative rebalancing pass.

### Q2: Translation strings

**Decision:** Write new English translation strings for all UT_ traits. Do not copy source mod strings verbatim if they are inaccurate to the trait's actual functionality. English is the only required language. Prioritize clarity and accuracy over fidelity to source mod wording. This is a writing task, not a translation task — the goal is to describe what each trait actually does.

### Q3: CombatTraits weapon tree granularity

**Decision: Needs further detail.** The CombatTraits weapon tree hierarchy is:

```text
UT_heavyswing (8pt) — All melee weapons
├── UT_twohanded (8pt) — All two-handed weapons
│   ├── UT_twohanded_axes (5pt)
│   ├── UT_twohanded_blunts (5pt)
│   ├── UT_twohanded_blades (5pt)
│   └── [UT_twohanded_spears — excluded, was commented out in source]
├── UT_onehanded (8pt) — All one-handed weapons
│   ├── UT_onehanded_axes (5pt)
│   ├── UT_onehanded_blunts (5pt)
│   ├── UT_onehanded_blades (5pt)
│   └── [UT_onehanded_spears — excluded, was commented out in source]
├── UT_axes (6pt) — All axes (1h + 2h)
├── UT_blunts (7pt) — All blunts (1h + 2h)
│   ├── UT_long_blunts (6pt)
│   └── UT_short_blunts (4pt)
├── UT_blades (7pt) — All blades (1h + 2h)
│   ├── UT_long_blades (6pt)
│   └── UT_short_blades (4pt)
└── UT_spears (6pt) — All spears
```

**Mutual exclusivity rule (from CombatTraits source):** All SW weapon traits are mutually exclusive with each other. A player picks ONE weapon specialization. Specific nodes (e.g., `UT_twohanded_axes`) are cheaper but narrower than general nodes (e.g., `UT_axes`).

**Naming convention for clarity:** All weapon tree traits use a consistent naming theme that makes the group relationship obvious — the "Weapon Specialization:" prefix or similar grouping cue in display names (e.g., "Weapon Spec: Two-Handed", "Weapon Spec: Axes", "Weapon Spec: Short Blades"). This makes it visually clear in the character creation UI that these traits are part of a single pick-one group without cluttering descriptions with non-functional text. The overlapping coverage (handedness axis vs weapon-family axis) becomes intuitive when the naming signals "these are all the same category of choice."

### Q4: Frog Companion

**Decision:** Excluded. Tonally inconsistent with a character-trait mod. Moved to exclusion list.

### Q5: Scrapper vs Scrounger

**Decision:** Both traits are retained. They are not simple XP duplicates — both boost loot discovery rates in addition to Scavenging XP, and their effects are additive when both are taken (taking both strengthens the shared loot-finding effect). The Scavenging XP boost is a secondary enhancement for a mod-specific skill and does nothing if that mod is not installed. Since they stack meaningfully and serve different cost tiers (3pt vs 5pt), both remain as separate traits, not a tier series.

### Q6: Trait cap / point budget

**Decision:** Out of scope. The vanilla point system is designed so that negative traits provide points for positive traits. The total number of traits a player can take depends on how many drawbacks they accept. Modifying the point budget is a separate concern — players who want more points can install a dedicated point mod.

### Q7: Versioned directory

**Decision:** Use `42/` (or `42.0/`). No subversion on the folder name. A mod that works on 42.15 should also work when loaded from a `42.0/` directory, but the reverse (42.0 mod in 42.15 folder) may not be true. Using `42.0/` maximizes forward compatibility. No source mod observed uses subversioned folders in practice.

### Q8: Vanilla mutual exclusivity

**Decision:** UT traits that are functionally very similar to a vanilla trait should be renamed as a higher tier of that vanilla trait and made mutually exclusive with it. For example, if `UT_fast` provides a stronger version of vanilla `SpeedDemon`'s movement speed bonus, it should be renamed `UT_speeddemon_II` with display name "Speed Demon II" and set mutually exclusive with `base:SpeedDemon`. The UT version must be strictly better and more expensive than the vanilla version to justify the tier.

This policy applies only when:

- The UT trait's primary effect is genuinely the same mechanic as the vanilla trait (not just thematically similar)
- The UT version is a clear power upgrade
- The naming makes the relationship obvious to the player

Traits that are thematically adjacent but mechanically distinct (e.g., `UT_evasive` and vanilla `Nimble`) remain independent with no mutual exclusivity.

**Action required:** During Phase 2 implementation, audit all UT stat-modifier traits against vanilla stat-modifier traits. Identify candidates for tier-series renaming. This audit cannot be completed in the PRD because it requires verifying the actual runtime effects of vanilla traits in the Java source, not just their script definitions (vanilla `SpeedDemon` has no XPBoost in its script definition — its speed bonus is applied in Java code and must be compared against `UT_fast`'s Lua implementation).

---

---

## 14. Future Research

Ideas and deferred items that are out of scope for this PRD but worth revisiting in future versions:

- **Pluviophile / Pluviophobia** — weather-mood traits excluded due to DTEM/ETW ID collisions. Could be added with conditional registration if a clean mod-detection API is verified.
- **ToughnessSkill integration** — the Toughness trait is tightly coupled to a custom skill system. Could be revisited if UT adds custom skill support.
- **ETW earned-trait compatibility layer** — if a future ETW version exposes a mod registration API, UT could register its trait IDs for earned-trait interactions.
- **Localization** — English-only for now. Community translation support could be added post-launch.
