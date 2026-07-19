# UniversalTraits — Trait Audit

**Date:** 2026-03-27
**Scope:** All installed trait mods audited for consolidation into UniversalTraits (Build 42 only)

---

## Key Architectural Findings

### Two registration formats exist in B42

**Old format (B41-era, still works in B42):**

```lua
-- shared/NPCs/SomeMainCreationMethods.lua
local t = TraitFactory.addTrait("id", getText("UI_trait_id"), cost, getText("UI_trait_iddesc"), false, false)
t:addXPBoost(Perks.SomePerk, 1)
Events.OnGameBoot.Add(function() ... end)
```

**New format (B42.13+):**

- `registries.lua` + MET (Mod Entry Table) pattern
- CombatTraits and SomewhatTraits have already migrated to this
- Empty stub files (`return SWTraits`) suggest the MET table is the actual data source
- **UniversalTraits should use the new format for all traits**

### Cost sign convention

- **Positive cost** = positive trait (player spends points to take it)
- **Negative cost** = negative trait (player gains points from it)

### Conflict-risk pattern: re-registering vanilla traits

DynamicTraitsExpandedMoodles re-registers ~80 vanilla B41 traits with `cost=0` to override costs. This is the most conflict-prone pattern in the entire installed set — it collides with any other mod that touches vanilla trait costs.

---

## Mod Summary

| Mod | Traits | Format | B42 Versioned | Notes |
|-----|--------|--------|---------------|-------|
| MoreTraits | 87 | Old (42.15) | Yes | Most comprehensive single mod |
| DynamicTraitsExpandedMoodles | ~35 custom | Old (42.0) | Yes | +80 vanilla re-registers — HIGH CONFLICT RISK |
| MoreSimpleTraits | 43 | Old (media/) | **No** — B41 layout | Has runtime stat tracking system |
| SomewhatTraits | 35 | New MET (42.15) | Yes | Clean SW-prefixed IDs |
| CombatTraits | 20 | New MET (42.15) | Yes | Clean SW-prefixed IDs |
| EvolvingTraitsWorld | 22 | Dynamic/earned | Yes | **Different paradigm — not character-creation traits** |
| FillerTraits | 21 | Old (media/) | **No** — B41 layout | Some overpowered |
| LastPushTrait | 1 | Old (42.0) | Yes | Dynamic/earned — not selectable |
| MeleematricianTrait | 1 | Old (common/) | Partial | Duplicate of CombatTraits entry |
| ToughnessSkill | 1 | Old (42.0) | Yes | Custom skill system attached |
| RPKDrivingSkill | 1 | Old (42/) | Yes | Custom driving skill system attached |
| B42_RainsFirearms | 1 | Old (42/) | Yes | Firearms XP booster |
| 300PointsTrait | 1 | Old (42.13) | Yes | Point economy mod — not a real trait |
| InfiniteTraitPointsB42 | 0 | UI mod | Yes | Removes point cap — no traits |

---

## Full Trait Table

### MoreTraits (source: `More Traits`, Workshop 1299328280)

| Internal ID | Display Name | Cost | Scripted? | Complexity | Notes |
|-------------|-------------|------|-----------|------------|-------|
| gunspecialist | Gun Specialist | 8 | XPBoost (Aiming×2, Reloading×2) | Low | |
| preparedfood | Prepared: Food | 1 | XPBoost (Cooking×1) | Low | Conditional on sub-mod not installed |
| preparedammo | Prepared: Ammo | 1 | XPBoost (Aiming×1, Reloading×1) | Low | |
| preparedmedical | Prepared: Medical | 1 | XPBoost (Doctor×1) | Low | |
| preparedrepair | Prepared: Carpentry | 1 | XPBoost (Woodwork×1) | Low | |
| preparedcamp | Prepared: Camping | 1 | XPBoost (Fishing×1) | Low | |
| preparedweapon | Prepared: Weapons | 1 | XPBoost (Maintenance×1) | Low | |
| preparedpack | Prepared: Pack | 1 | Stat modifier | Medium | |
| preparedcar | Prepared: Cars | 1 | XPBoost (Mechanics×1) | Low | |
| preparedcoordination | Prepared: Cartography | 1 | XPBoost | Low | |
| swift | Swift | 2 | XPBoost (Lightfoot×1) | Low | |
| ingenuitive | Ingenuitive | 9 | XPBoost (Electricity×2, MetalWelding×1) | Low | |
| generator | Generator Knowledge | 2 | XPBoost (Electricity×1) | Low | |
| olympian | Olympian | 5 | XPBoost (Sprinting×1, Fitness×1) | Low | |
| bouncer | Bouncer | 5 | XPBoost (Strength×1, SmallBlunt×1) | Low | |
| martial | Martial Artist | 5 | XPBoost (Fitness×1, SmallBlunt×1) | Low | |
| flexible | Flexible | 3 | XPBoost (Nimble×1) | Low | |
| grunt | Grunt Worker | 4 | XPBoost (Woodwork×1, SmallBlunt×1, Masonry×1, Blacksmith×1) | Low | |
| quiet | Quiet | 2 | XPBoost (Sneak×1, Lightfoot×1) | Low | |
| tinkerer | Tinkerer | 5 | XPBoost (Electricity×1, Mechanics×1, Tailoring×1, FlintKnapping×1) | Low | |
| scrapper | Scrapper | 3 | XPBoost (Scavenging×1) | Low | |
| wildsman | Wildsman | 8 | XPBoost (PlantScavenging×1, Fishing×1) | Low | |
| natural | Natural Eater | 4 | XPBoost (Cooking×1) | Low | |
| bladetwirl | Practiced Swordsman | 5 | XPBoost (LongBlade×1, SmallBlade×1) | Low | |
| blunttwirl | Thuggish | 5 | XPBoost (Blunt×1) | Low | |
| scrounger | Scrounger | 5 | XPBoost (Scavenging×1) | Low | Possible overlap with scrapper |
| antique | Antique Collector | 6 | XPBoost | Low | |
| evasive | Evasive | 8 | XPBoost (Nimble×1, Sprinting×1) | Low | |
| blissful | Blissful | 3 | XPBoost | Low | |
| specweapons | Specialization: Weapons | 12 | XPBoost (multi-weapon perks×4) | Low | High-cost specialization |
| speccrafting | Specialization: Craftworks | 12 | XPBoost (crafting perks×4) | Low | |
| specfood | Specialization: Food & Farm | 12 | XPBoost (food/farm perks×4) | Low | |
| specguns | Specialization: Guns | 12 | XPBoost (Aiming×4, Reloading×4) | Low | |
| specmove | Specialization: Maneuvering | 12 | XPBoost (movement perks×4) | Low | |
| specaid | Specialization: First Aid | 12 | XPBoost (Doctor×8) | Low | |
| gordanite | Gordanite | 6 | XPBoost | Low | |
| indefatigable | Indefatigable | 10 | Runtime event handler | **High** | Stamina system, has cooldown state |
| hardy | Hardy | 6 | Runtime event handler | **High** | Endurance tracking, has sub-state traits |
| problunt | Prowess: Blunt | 7 | XPBoost (Blunt perks) | Low | |
| problade | Prowess: Blade | 7 | XPBoost (Blade perks) | Low | |
| progun | Prowess: Guns | 7 | XPBoost (Gun perks) | Low | |
| prospear | Prowess: Spear | 7 | XPBoost (Spear×2) | Low | |
| actionhero | Action Hero | 8 | XPBoost (multi) | Low | |
| fast | Fast | 6 | Stat modifier (speed) | Medium | |
| thickblood | Thick Blooded | 4 | Stat modifier (bleed rate) | Medium | |
| expertdriver | Expert Driver | 5 | Runtime hasTrait check in UCWF | Medium | |
| superimmune | Super-Immune | 10 | Runtime handler (infection resistance) | **High** | Has sub-state notification traits |
| packmule | Pack Mule | 7 | Stat modifier (carry weight) | Low | |
| graverobber | Grave Robber | 7 | XPBoost | Low | |
| gourmand | Gourmand | 4 | Runtime hasTrait check | Medium | |
| gymgoer | Gym-Goer | 5 | XPBoost (Fitness×1) | Low | |
| leadfoot | Lead Foot | 2 | Stat modifier (vehicle speed) | Medium | |
| vagabond | Vagabond | 3 | XPBoost | Low | |
| quickworker | Quick Worker | 9 | Stat modifier (work speed) | Medium | |
| batteringram | Battering Ram | 7 | Stat modifier (push/shove) | Medium | |
| fitted | Fitted | 4 | Stat modifier (encumbrance) | Medium | |
| tavernbrawler | Tavern Brawler | 3 | XPBoost (SmallBlunt×1) | Low | |
| secondwind | Second Wind | 10 | Runtime event handler | **High** | Complex stamina recovery |
| restfulsleeper | Restful Sleeper | 6 | Stat modifier (sleep quality) | Medium | |
| noxpshooter | (No XP: Shooting) | 3 | Stat modifier (XP disable) | Medium | |
| noxptechnician | (No XP: Tech) | 3 | Stat modifier (XP disable) | Medium | |
| noxpaxe | (No XP: Axe) | 3 | Stat modifier (XP disable) | Medium | |
| noxpfirstaid | (No XP: First Aid) | 3 | Stat modifier (XP disable) | Medium | |
| noxpmaintenance | (No XP: Maintenance) | 3 | Stat modifier (XP disable) | Medium | |
| noxpsneaky | (No XP: Sneaky) | 3 | Stat modifier (XP disable) | Medium | |
| terminator | Terminator | 14 | XPBoost (all combat perks×high) | Low | |
| unwavering | Unwavering | 6 | Stat modifier (panic resistance) | Medium | |
| idealweight | Ideal Weight | 4 | Stat modifier | Medium | |
| quickrest | Quick Rest | 3 | Stat modifier (rest recovery) | Medium | |
| Lucky | Lucky | 4 | Re-register of vanilla trait | Low | **Conflict risk: vanilla trait** |
| Unlucky | Unlucky | -4 | Re-register of vanilla trait | Low | **Conflict risk: vanilla trait** |
| LightDrinker | Light Drinker | -2 | Re-register of vanilla trait | Low | **Conflict risk: vanilla trait** |
| HeavyDrinker | Heavy Drinker | 3 | Re-register of vanilla trait | Low | **Conflict risk: vanilla trait** |
| antigun | Anti-Gun Activist | -6 | Stat modifier | Medium | |
| noodlelegs | Noodle Legs | -6 | Stat modifier (speed penalty) | Medium | |
| motionsickness | Motion Sickness | -6 | Runtime event handler | **High** | |
| paranoia | Paranoia | -4 | Runtime event handler | **High** | |
| packmouse | Pack Mouse | -7 | Stat modifier (carry penalty) | Low | |
| injured | Injured | -4 | Runtime: spawns with injury | **High** | |
| drinker | Alcoholic | -14 | Runtime event handler | **High** | |
| broke | Broke Leg | -8 | Runtime: spawns with broken leg | **High** | |
| butterfingers | Butterfingers | -12 | Runtime event handler (item drop) | **High** | |
| incomprehensive | Incomprehensive | -10 | Stat modifier (skill cap) | Medium | |
| depressive | Depressive | -4 | Runtime event handler (mood) | **High** | |
| selfdestructive | Self-Destructive | -4 | Runtime event handler | **High** | |
| badteeth | Bad Teeth | -3 | Stat modifier | Low | |
| albino | Sun Sensitivity | -5 | Runtime event handler (UV damage) | **High** | |
| amputee | Amputee | -16 | Runtime: complex limb system | **High** | Most complex trait in set |
| poordriver | Student Driver | -5 | Runtime hasTrait check | Medium | |
| gimp | Slowpoke | -8 | Stat modifier (speed penalty) | Low | |
| anemic | Anemic | -4 | Stat modifier | Low | |
| immunocompromised | Immunocompromised | -10 | Runtime event handler | **High** | |
| ascetic | Ascetic | -4 | Runtime hasTrait check (food restrict) | Medium | |
| fearful | Fearful | -7 | Runtime event handler (panic boost) | **High** | |
| glassbody | Glass Body | -10 | Stat modifier (damage multiplier) | Medium | |
| slowworker | Slow Worker | -9 | Stat modifier | Medium | |
| mundane | Mundane | -9 | Stat modifier (XP penalty global) | Medium | |
| burned | Burned | -20 | Runtime: spawns with burns | **High** | |
| deprived | Deprived | -6 | Stat modifier | Low | |

---

### DynamicTraitsExpandedMoodles (custom traits only — source: Workshop 2459400130)

> **Note:** This mod also re-registers ~80 vanilla B41 traits to override costs. Those are excluded here.
> Many of its "custom" traits (Sneaky, Lightfooted, Nimble, AM-prefixed, weapon fans) overlap with MoreSimpleTraits — same trait IDs.

| Internal ID | Display Name | Cost | Scripted? | Complexity | Notes |
|-------------|-------------|------|-----------|------------|-------|
| AmateurElectrician | Amateur Electrician | 1 | XPBoost | Low | |
| Pluviophile | Pluviophile | 2 | Runtime (weather mood) | **High** | Duplicate of ETW trait |
| Pluviophobia | Pluviophobia | -2 | Runtime (weather mood) | **High** | Duplicate of ETW trait |
| Alcoholic | Alcoholic | -8 | Runtime handler | **High** | Different ID from MT's `drinker` |
| Anorexy | Anorexia | -6 | Runtime handler (food restriction) | **High** | |
| Prodigy | Prodigy | 6 | XPBoost (all perks×1) | Low | |
| PhysicallyActive | Physically Active | 10 | Runtime handler (fitness gain) | **High** | |
| Sedentary | Sedentary | -10 | Runtime handler (fitness loss) | **High** | |
| Nightmares | Nightmares | 0 | Runtime handler (sleep penalty) | **High** | cost=0 means dynamic/earned |
| Fibromyalgia | Fibromyalgia | -10 | Runtime handler (pain system) | **High** | |
| NervousWreck | Nervous Wreck | -4 | Runtime handler (panic) | **High** | |
| Melancholic | Melancholic | -4 | Runtime handler (mood) | **High** | |
| PillsAllergy | Allergic to Pills | -6 | Runtime handler (med reaction) | **High** | |
| WildPlantsAllergy | Allergic to Wild Plants | -4 | Runtime handler | **High** | |
| AddictedToCaffeine | Addicted to Caffeine | -4 | Runtime handler | **High** | Registered twice — **BUG** |
| Bigorexia | Bigorexia | -8 | Runtime handler | **High** | |

---

### MoreSimpleTraits (source: Workshop 2792245343)

> **Warning:** This mod uses the `media/` root layout only — not properly B42-versioned.
> Has a runtime perk-by-level system (`MSTPerksByLevel.lua`) and weight trait system (`MSTWeightTraits.lua`).
> Many trait IDs overlap with DynamicTraitsExpandedMoodles.

| Internal ID | Display Name | Cost | Scripted? | Complexity | Notes |
|-------------|-------------|------|-----------|------------|-------|
| Sneaky | Sneaky | 2 | XPBoost (Sneak×1) | Low | **ID conflict with DTEM** |
| Lightfooted | Lightfooted | 2 | XPBoost (Lightfoot×1) | Low | **ID conflict with DTEM** |
| Nimble | Nimble | 3 | XPBoost (Nimble×1) | Low | **ID conflict with DTEM** |
| MarathonRunner | Marathon Runner | 5 | XPBoost (Sprinting×2) | Low | |
| StrongNimble | Strong Nimble | 7 | XPBoost (Nimble×2, Strength×1) | Low | |
| Taut | Taut | 6 | XPBoost (Fitness×2) | Low | |
| NinjaWay | Ninja Way | 5 | XPBoost (Sneak×2, Lightfoot×1) | Low | |
| AMForager | Forager | 1 | XPBoost (PlantScavenging×1) | Low | **ID conflict with DTEM** |
| AMTrapper | Trapper | 1 | XPBoost (Trapping×1) | Low | **ID conflict with DTEM** |
| Mushroomer | Mushroomer | 4 | XPBoost (PlantScavenging×2) | Low | |
| AMCook | Scullion | 1 | XPBoost (Cooking×1) | Low | **ID conflict with DTEM** |
| AMElectrician | Electrical-technician | 1 | XPBoost (Electricity×1) | Low | **ID conflict with DTEM** |
| AMMechanic | Auto Mechanic | 2 | XPBoost (Mechanics×1) | Low | **ID conflict with DTEM** |
| AMCarpenter | Carpenter | 1 | XPBoost (Woodwork×1) | Low | **ID conflict with DTEM** |
| AMMetalworker | Metalwelder | 2 | XPBoost (MetalWelding×1) | Low | **ID conflict with DTEM** |
| Durabile | Durability | 3 | Stat modifier (item durability) | Medium | **ID conflict with DTEM** |
| Shortbladefan | Piercer | 2 | XPBoost (SmallBlade×1) | Low | **ID conflict with DTEM** |
| Shortbluntfan | Crusher | 3 | XPBoost (SmallBlunt×1) | Low | **ID conflict with DTEM** |
| Cutter | Cutter | 4 | XPBoost (LongBlade×1) | Low | **ID conflict with DTEM** |
| Spearman | Lancer | 5 | XPBoost (Spear×2) | Low | **ID conflict with DTEM** |
| Swordsman | Swordsman | 5 | XPBoost (LongBlade×2) | Low | **ID conflict with DTEM** |
| Cruelty | Cruelty | 4 | XPBoost (all weapon perks×1) | Low | |
| Gunfan | Shooter | 4 | XPBoost (Aiming×1, Reloading×1) | Low | **ID conflict with DTEM** |
| Sharpshooter | Sharpshooter | 6 | XPBoost (Aiming×2) | Low | |
| OwlPerson | Night Owl | -1 | Stat modifier (night vision/day penalty) | Medium | |
| LarkPerson | Early Bird | -1 | Stat modifier | Medium | |
| Slack | Slack | -6 | Stat modifier (work speed penalty) | Medium | |
| WeatherSensitive | Weather Sensitive | -2 | Runtime handler | **High** | |
| SoreLegsTrait | Sore Legs | -8 | Stat modifier (speed/fitness penalty) | Medium | |
| SensitiveStomach | Sensitive Stomach | -2 | Runtime handler | **High** | |
| PanicAttacks | Panic Attacks | -4 | Runtime handler | **High** | |
| MSTAllergic | Allergic | -3 | Runtime handler | **High** | |
| FearoftheDark | Fear of the Dark | -1 | Runtime handler (mood) | **High** | |
| Snorer | Snorer | -2 | Stat modifier (noise while sleeping) | Medium | |
| LessSweaty | Less Sweaty | 2 | Stat modifier (sweat/smell) | Low | |
| HighSweaty | High Sweaty | -3 | Stat modifier (sweat/smell) | Low | |
| CanGrabMore | Can Grab More | 2 | Stat modifier | Low | |
| CanGrabLess | Can Grab Less | -2 | Stat modifier | Low | |
| HeavilyBleedingWounds | Heavily Bleeding Wounds | -4 | Stat modifier (bleed rate) | Medium | |
| WeaklyBleedingWounds | Weakly Bleeding Wounds | 3 | Stat modifier (bleed rate) | Medium | |
| AccMetabolism | Accelerated Metabolism | 2 | Runtime handler (food/weight) | **High** | Part of weight system |
| MSTOptimist | Optimist | 2 | Runtime handler (mood) | **High** | |
| MSTDepressive | Depressive | -4 | Runtime handler (mood) | **High** | Different ID from MT's `depressive` |

---

### SomewhatTraits (source: Workshop 3498347699)

All IDs are prefixed `SW` — good isolation practice.

| Internal ID | Display Name | Cost | Scripted? | Complexity | Notes |
|-------------|-------------|------|-----------|------------|-------|
| SWAdaptiveMetabolism | Adaptive Metabolism | 5 | Runtime handler | **High** | |
| SWBouncer | Bouncer | 4 | XPBoost | Low | Same display name as MT's `bouncer` |
| SWCompetitiveEater | Competitive Eater | 4 | Runtime handler (food) | **High** | |
| SWCouchDweller | Couch Dweller | 2 | Stat modifier | Low | |
| SWCrafty | Crafty | 5 | XPBoost (crafting perks) | Low | |
| SWFrogCompanion | Frog Companion | 3 | Runtime handler | **High** | Registered twice — **possible BUG** |
| SWHumanHamster | Human Hamster | 3 | Runtime handler (storage) | **High** | |
| SWImmuneResponse | Immune Response | 4 | Runtime handler | **High** | |
| SWIronLiver | Iron Liver | 3 | Stat modifier (alcohol tolerance) | Medium | |
| SWManiac | Maniac | 4 | Runtime handler (combat mood) | **High** | |
| SWPacer | Pacer | 4 | Stat modifier (walking speed) | Medium | |
| SWParamedic | Paramedic | 5 | XPBoost (Doctor×2) | Low | |
| SWPitCrew | Pit Crew | 5 | XPBoost (Mechanics×2) | Low | |
| SWSloth | Sloth | 2 | Stat modifier | Low | Positive trait despite lazy name |
| SWSprintDemon | Sprint Demon | 1 | XPBoost (Sprinting×1) | Low | |
| SWSquirrel | Squirrel | 2 | Stat modifier (carry weight) | Low | |
| SWTrekker | Trekker | 4 | XPBoost (Fitness×1, Sprinting×1) | Low | |
| SWAcrophobic | Acrophobic | -3 | Runtime handler | **High** | |
| SWAntivaxxer | Anti-Vaxxer | -3 | Stat modifier | Low | |
| SWBrittle | Brittle | -6 | Stat modifier (bone fracture chance) | Medium | |
| SWColdSensitive | Cold Sensitive | -2 | Runtime handler (temperature) | **High** | |
| SWDrunkard | Drunkard | -3 | Runtime handler | **High** | |
| SWFlailer | Flailer | -4 | Stat modifier (combat accuracy) | Medium | |
| SWFlatEarther | Flat Earther | -4 | Stat modifier (reading speed) | Medium | |
| SWFlimsy | Flimsy | -4 | Stat modifier | Low | |
| SWHeatSensitive | Heat Sensitive | -2 | Runtime handler (temperature) | **High** | |
| SWInjured | Injured | -4 | Runtime: spawns injured | **High** | Same concept as MT `injured` |
| SWLuddite | Luddite | -4 | Stat modifier (electrical XP penalty) | Medium | |
| SWLurcher | Lurcher | -5 | Stat modifier (movement) | Medium | |
| SWOneTrickPony | One Trick Pony | -4 | Stat modifier (multi-skill penalty) | Medium | |
| SWRavenous | Ravenous | -2 | Runtime handler (hunger) | **High** | |
| SWScardycat | Scaredy Cat | -3 | Runtime handler (panic) | **High** | |
| SWSundayRunner | Sunday Runner | -1 | Stat modifier (sprint speed) | Low | |
| SWVehophobic | Vehophobic | -6 | Runtime handler (vehicle fear) | **High** | |

---

### CombatTraits (source: Workshop 3427091746)

All IDs prefixed `SW`. Weapon specialization tree with mutual exclusivity enforcement.

| Internal ID | Display Name | Cost | Scripted? | Complexity | Notes |
|-------------|-------------|------|-----------|------------|-------|
| Melee-matician | Melee-matician | 12 | XPBoost (all melee×high) | Low | Hyphen in ID is unusual — **risk** |
| SWHeavySwing | Heavy Swing | 8 | XPBoost (all melee×high) | Low | |
| SWTwoHanded | Two-Handed | 8 | XPBoost (two-handed weapons) | Low | |
| SWOneHanded | One-Handed | 8 | XPBoost (one-handed weapons) | Low | |
| SWAxes | Axes | 6 | XPBoost (Axe perks) | Low | |
| SWTwoHandedAxes | Two-Handed Axes | 5 | XPBoost (Axe×2h) | Low | |
| SWOneHandedAxes | One-Handed Axes | 5 | XPBoost (Axe×1h) | Low | |
| SWBlunts | Blunts | 7 | XPBoost (Blunt perks) | Low | |
| SWTwoHandedBlunts | Two-Handed Blunts | 5 | XPBoost | Low | |
| SWOneHandedBlunts | One-Handed Blunts | 5 | XPBoost | Low | |
| SWLongBlunts | Long Blunts | 6 | XPBoost | Low | |
| SWShortBlunts | Short Blunts | 4 | XPBoost | Low | |
| SWBlades | Blades | 7 | XPBoost (Blade perks) | Low | |
| SWTwoHandedBlades | Two-Handed Blades | 5 | XPBoost | Low | |
| SWOneHandedBlades | One-Handed Blades | 5 | XPBoost | Low | |
| SWLongBlades | Long Blades | 6 | XPBoost | Low | |
| SWShortBlades | Short Blades | 4 | XPBoost | Low | |
| SWSpears | Spears | 6 | XPBoost (Spear perks) | Low | |
| SWTwoHandedSpears | Two-Handed Spears | 5 | XPBoost — **commented out** | Low | Not currently active |
| SWOneHandedSpears | One-Handed Spears | 5 | XPBoost — **commented out** | Low | Not currently active |

**Mutual exclusivity:** All SW weapon traits are set mutually exclusive with each other and with vanilla `Axeman` if present.

**Current Wood Splitter relevance:** UniversalTraits' new-character-only Axeman-alias decision supersedes treating Wood Splitter as an independent Axe-only trait. Before grants, Wood Splitter must exclude Axeman even when a profession/job supplies it; the intentional post-selection Wood Splitter + granted-Axeman state is not a conflict. Granting Axeman inherits all four inseparable vanilla effects: Axe-category tree damage ×1.5, axe attack-time result ×0.95, chop speed 1.0 instead of 0.8, and new-character eligibility for the rare pine-tree key ring.

---

### EvolvingTraitsWorld (source: Workshop 2914075159)

> **Paradigm note:** ETW traits are **earned during gameplay**, not selected at character creation.
> They are registered with `cost=0` and granted/removed by event listeners based on in-game conditions.
> This is a fundamentally different system — not suitable for direct consolidation into a character-creation trait mod.

| Internal ID | Display Name | Trigger | Complexity |
|-------------|-------------|---------|------------|
| AVClub | AV Club Member | Skill-based | **High** |
| AxeThrower | Axe Thrower | Kill-based | **High** |
| BladeEnthusiast | Blade Enthusiast | Kill-based | **High** |
| Bloodlust | Bloodlust | Kill-based | **High** |
| BodyWorkEnthusiast | Bodywork Enthusiast | Skill-based | **High** |
| FurnitureAssembler | Furniture Assembler | Skill-based | **High** |
| GunEnthusiast | Gun Enthusiast | Kill-based | **High** |
| GymRat | Gym Rat | Stat-based | **High** |
| Hoarder | Hoarder | Inventory-based | **High** |
| HomeCook | Home Cook | Skill-based | **High** |
| Homichlophile | Homichlophile | Location/weather | **High** |
| Homichlophobia | Homichlophobia | Location/weather | **High** |
| KnifeFighter | Knife Fighter | Kill-based | **High** |
| LightStep | Light Step | Stat-based | **High** |
| LowProfile | Low Profile | Behavior-based | **High** |
| PainTolerance | Pain Tolerance | Health-based | **High** |
| PetTherapy | Pet Therapy | Time-based | **High** |
| Pluviophile | Pluviophile | Weather-based | **High** | Duplicate of DTEM trait ID |
| Pluviophobia | Pluviophobia | Weather-based | **High** | Duplicate of DTEM trait ID |
| PolearmFighter | Polearm Fighter | Kill-based | **High** |
| RestorationExpert | Restoration Expert | Skill-based | **High** |
| StickFighter | Stick Fighter | Kill-based | **High** |

**Conflict flag:** `Pluviophile` and `Pluviophobia` IDs clash with DTEM. Both mods register these — last one loaded wins, effects depend on load order.

---

### FillerTraits (source: Workshop 3387501194)

> **Warning:** Uses `media/` root layout only — not properly B42-versioned.

| Internal ID | Display Name | Cost | Scripted? | Complexity | Notes |
|-------------|-------------|------|-----------|------------|-------|
| Invincible | Invincible | 0 | Stat modifier | Low | **Clearly OP / cheat trait** |
| Indomitable | Indomitable | 0 | Stat modifier | Low | **Cheat trait** |
| Immune | Immune | 22 | Stat modifier | Low | **Cheat trait** |
| Analgesia | Analgesia | 10 | Stat modifier (pain disable) | Medium | |
| Sore | Sore | -6 | Stat modifier | Low | |
| Optimist | Optimist | 7 | Runtime handler (mood) | **High** | Different ID from MST's `MSTOptimist` |
| Pessimist | Pessimist | -4 | Runtime handler | **High** | |
| Backpacker | Backpacker | 8 | Stat modifier (carry weight) | Low | |
| Topheavy | Topheavy | -4 | Stat modifier | Low | |
| Frail | Frail | -10 | Stat modifier | Low | **ID conflict with DTEM's Frail (cost=0)** |
| BearBelly | Bear Belly | 12 | Stat modifier (carry weight) | Low | |
| PhotographicMemory | Photographic Memory | 20 | Stat modifier (reading/skill) | Medium | High cost |
| Staunch | Staunch | 10 | Stat modifier | Low | |
| Trackman | Trackman | 6 | XPBoost | Low | |
| Cleaver | Cleaver | 4 | XPBoost (LongBlade×1) | Low | |
| WoodSplitter | Wood Splitter | 4 | XPBoost (Axe×1) | Low | |
| Improviser | Improviser | 4 | XPBoost (Maintenance×1) | Low | |
| BigLeague | Big League | 12 | XPBoost (all melee high) | Low | Overlaps with CombatTraits concepts |
| BrushClearer | Brush Clearer | 12 | XPBoost | Low | |
| Axmen | Axmen | 12 | XPBoost (Axe) | Low | Note: misspelling ("Axmen" not "Axeman") |
| FastHands | Fast Hands | 12 | Stat modifier | Medium | |

> **Current UniversalTraits supersession (2026-07-19):** The `WoodSplitter` row above is historical source-mod evidence only (cost 4, Axe XP only) and is explicitly superseded; it must not be counted as the current `UniversalTraits:UT_woodsplitter` design or as an independent FillerTrait implementation. UniversalTraits retains +1 Axe and uses new-character `GrantedTraits = Axeman`, inheriting vanilla Axeman's 1.5 tree-damage multiplier, 0.95 axe attack-time factor, 1.0 versus 0.8 chop speed, and pine-tree key-ring eligibility. Before grants, Wood Splitter must be mutually exclusive with Axeman, including directly selected and profession/job-supplied Axeman; the intentional post-selection granted pair is not a conflict. The accepted UniversalTraits cost is 4 points; the decision and sensitivity evidence are recorded in `trait-deep-audit/campaign/change-impact/woodsplitter-axeman-balance.json`. The old tree-damage implementation and every existing-save migration, marker/versioning, legacy reconciliation, preservation, retroactive-key-ring, migration-test, and migration-runtime-proof claim are non-goals because saves may be invalidated. Multiplayer support and proof are likewise non-goals. Open proof is limited to new-character selection/grant ordering, profession/job exclusion, and applicable unexecuted tests.

---

### Small / Single-Trait Mods

| Mod | Internal ID | Display Name | Cost | Scripted? | Complexity | Notes |
|-----|-------------|-------------|------|-----------|------------|-------|
| LastPushTrait | LastPush | Last Push | 0 (earned) | Runtime handler | **High** | Dynamic/earned trait — not selectable |
| MeleematricianTrait | Melee-matician | Melee-matician | 4 | XPBoost | Low | Same ID as CombatTraits version (cost 12) — **ID collision** |
| ToughnessSkill | tough | Toughness | 5 | Custom skill system | **High** | Hooks into a full custom Toughness skill |
| RPKDrivingSkill | Driver | Driver | 2 | XPBoost (Driving×1) | Low | Hooks into custom Driving skill system |
| B42_RainsFirearms | gunenthusiastRFNGP | Gun Enthusiast (RFNGP) | 6 | XPBoost (Aiming×2, Reloading×2, Nimble×1) | Low | Different ID from ETW's `GunEnthusiast` |
| 300PointsTrait | 300Points | 300 Points | -300 | None | Low | **Point economy mod — not a real trait** |

---

## Conflict Map

| Conflict Type | Affected Mods | Details |
|--------------|---------------|---------|
| **Same ID, different behavior** | MoreSimpleTraits + DTEM | 11 trait IDs shared: `Sneaky`, `Lightfooted`, `Nimble`, `AMForager`, `AMTrapper`, `AMCook`, `AMElectrician`, `AMMechanic`, `AMCarpenter`, `AMMetalworker`, `Durabile`, `Shortbladefan`, `Shortbluntfan`, `Cutter`, `Spearman`, `Swordsman`, `Gunfan` |
| **Same ID, different cost** | MeleematricianTrait (4pt) + CombatTraits (12pt) | `Melee-matician` registered by both |
| **Same ID, different behavior** | ETW + DTEM | `Pluviophile`, `Pluviophobia` registered by both |
| **Same concept, different ID** | MT `drinker` + DTEM `Alcoholic` + SW `SWDrunkard` | Three separate alcoholic traits |
| **Same concept, different ID** | MT `injured` + SW `SWInjured` | Two separate "starts injured" traits |
| **Same concept, different ID** | MT `bouncer` + SW `SWBouncer` | Same display name, different IDs |
| **Vanilla trait re-registration** | DTEM | Re-registers ~80 vanilla traits with cost=0; collides with any mod touching vanilla costs |
| **ID has hyphen** | CombatTraits | `Melee-matician` — hyphens in trait IDs can cause Lua key lookup issues |
| **Not B42-versioned** | MoreSimpleTraits, FillerTraits | Use `media/` root only; loading behavior in B42 is undefined |
| **Cheat traits** | FillerTraits | `Invincible`, `Indomitable`, `Immune` at cost 0 |

---

## Recommendations for PRD

### Include (clearly unique, useful, non-conflicting)

- MoreTraits core set (XPBoost traits, most stat modifiers) — strip the vanilla re-registers
- CombatTraits SW weapon specialization tree — clean IDs, well-structured, mutual exclusivity logic is a good pattern to carry forward
- SomewhatTraits SW-prefixed set — clean IDs, good variety
- Selected FillerTraits (non-cheat ones: Analgesia, Backpacker, Trackman, Cleaver, Improviser, FastHands); the historical independent WoodSplitter entry is superseded by the current UniversalTraits Axeman-alias design described above
- RPKDrivingSkill's `Driver` trait as a standalone (detach from custom skill system)
- B42_RainsFirearms' `gunenthusiastRFNGP` — rename ID, consolidate with gun specialist concepts

### Exclude or redesign

- **EvolvingTraitsWorld** — different paradigm; earned traits require a separate system; consider as a phase 2 feature
- **LastPushTrait** — same reason; earned/dynamic
- **ToughnessSkill** — the trait itself is fine but it's tightly coupled to a custom skill system
- **DynamicTraitsExpandedMoodles vanilla re-registers** — do not re-register vanilla traits
- **300PointsTrait, InfiniteTraitPointsB42** — point economy mods, not trait content
- **FillerTraits cheat entries** — Invincible, Indomitable, Immune at cost 0
- **MoreSimpleTraits** — all its unique traits are covered by DTEM or other mods; it's not B42-versioned; skip entirely

### Deduplication decisions needed

1. Choose one "alcoholic" trait (MT `drinker`, DTEM `Alcoholic`, SW `SWDrunkard`)
2. Choose one "injured" start trait (MT `injured`, SW `SWInjured`)
3. Choose one "gun specialist" trait (MT `gunspecialist`, B42Firearms `gunenthusiastRFNGP`, ETW `GunEnthusiast`)
4. Assign new clean UT-namespaced IDs to all retained traits (e.g., `UT_gunspecialist`) to prevent future collisions

### Architecture recommendation

- Use new B42.13+ `registries.lua` + MET format for all trait registrations
- Prefix all trait IDs with `UT_` to prevent any future collision
- Do not re-register or override vanilla traits
- Separate XPBoost/stat traits (data-only, low complexity) from runtime-scripted traits (event handlers) into different files
