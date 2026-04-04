# UT_allergic

## Trait Summary
- UT trait id: UT_allergic
- Source mod: MoreSimpleTraits (`mods/MoreSimpleTraits` and `mods/MoreSimpleTraitsVanilla`)
- Source trait id: `MSTAllergic` (registered via `TraitFactory.addTrait("MSTAllergic", ...)`)
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraitsVanilla/mods/MoreSimpleTraitsVanilla/media/lua/client/MSTMainFile.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt`
- Source cost: -3 (both `mods/MoreSimpleTraits` and `mods/MoreSimpleTraitsVanilla` register `MSTAllergic` at -3)
- Source mutual exclusion: `TraitFactory.setMutualExclusive("MSTAllergic", "Resilient")` — mutually exclusive with the vanilla Resilient trait in the Vanilla variant
- Source trigger path: `Events.EveryTenMinutes.Add(allergictrait)` — `allergictrait()` fires every ten in-game minutes; if the player has trait `"MSTAllergic"` and is not asleep, a sneeze roll is made
- Source behavior:
  - Base sneeze chance roll: `ZombRand(288) == 0`; if the player also has `ProneToIllness`, the denominator is tightened to `ZombRand(230) == 0` (higher frequency)
  - On a successful roll, if the player does **not** have toilet paper or a tissue equipped: `player:Say(getText("IGUI_PlayerText_Sneeze"))`, `addSound` at radius 32/volume 40 indoors or radius 46/volume 58 outdoors, and `player:playEmote("mstsneeze")`
  - If the player **does** have toilet paper or a tissue equipped: a second `ZombRand(2) == 0` roll determines whether one charge of that item is consumed; the player says the muffled sneeze text; `addSound` at radius 4/volume 6; emote plays
  - No moddata key is written; the effect is entirely runtime — probabilistic sound emission and item consumption each tick

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_allergic = CharacterTrait.register("UniversalTraits:UT_allergic")` (line 282), placed in the Phase 3c — Event-Driven block
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_allergic`, `IsProfessionTrait = false`, `DisabledInMultiplayer = true`, `Cost = -4`, `UIName = UI_UT_allergic`, `UIDescription = UI_UT_allergicDesc`; no `MutuallyExclusiveTraits` field present
- Translation strings present: yes — `UI_UT_allergic = "Allergic"`, `UI_UT_allergicDesc = "Your body reacts badly to things that others tolerate fine. Food allergies can turn a meal into a medical event."`
- Exclusions/grants correct: no — the source excluded `MSTAllergic` from pairing with `Resilient`; UT defines no exclusion at all
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_allergic.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/scripts/UT_character_traits.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`
- Runtime chain (plain language):
  1. On new game start, `onNewGame` fires for the player.
  2. `UTCore.hasTrait` checks whether the player has `UniversalTraits:UT_allergic`.
  3. If yes, `player:getModData()["UT_generalAllergyFlag"] = true` is written to player mod data.
  4. No further code runs. No periodic tick hook is registered.
- Actual behavior (exact values): Sets `UT_generalAllergyFlag = true` in player mod data at new-game time. No other script in the UTMods codebase reads `UT_generalAllergyFlag`. No sneeze roll, no sound emission, no item consumption, no emote — the trait has **no runtime effect** in the current implementation.

## Description Integrity
- Display name check: "Allergic" — matches the source trait name and concept; name is accurate.
- Description check: "Your body reacts badly to things that others tolerate fine. Food allergies can turn a meal into a medical event." — the description is thematically plausible but factually wrong about the actual mechanic. The source trait is not a food allergy; it is a sneezing trait that emits noise and optionally consumes tissue/toilet paper. The UT description invents a food-allergy framing that does not exist in the source and does not exist in the UT implementation either.
- Missing or misleading details: The description does not mention sneezing, noise emission, zombie attraction, or tissue consumption — the actual mechanics of the source. It implies a food-related effect that is implemented nowhere. The description is doubly wrong: wrong about mechanism (not food allergies) and wrong about current state (no effect at all).

## Balance Review
- Upside: none
- Downside: none (intended by source: probabilistic sneezing that emits noise and attracts zombies, with tissue items mitigating volume; actual: zero effect)
- Uptime: N/A — effect is never active
- Peer comparison:
  - Source mod implements the trait via a periodic `EveryTenMinutes` tick with probabilistic `addSound` calls and emote playback — a real and meaningful stealth hazard. The UT rewrite discards all of that in favor of writing a moddata flag that nothing reads.
  - `UT_snorer` follows an identical broken pattern: `OnNewGame` writes a moddata key (`UT_noiseMult`) that no consumer reads. `UT_allergic` repeats this failure with `UT_generalAllergyFlag`.
  - `UT_pillsallergy` and `UT_wildplantsallergy` are sibling allergy traits in the same Phase 3c block and likely warrant comparison when reviewing the allergy tier as a whole.
- Stack or exclusion notes: no exclusions defined in UT; source excluded `MSTAllergic` from `Resilient` — that guard is absent. The trait could currently be stacked with any other trait without restriction.
- Cost verdict: wrong — UT charges -4 points (one point more than the source's -3) for a trait that currently has no gameplay effect. The cost increase is unjustified relative to source and doubly unjustified given the broken implementation.

## Regression Proof
- Existing test: `UniversalTraits:UT_allergic` appears in the batch trait list in `run_tests.lua` (line 293), in the Phase 3c — Event-Driven group. No dedicated behavioral test exists.
- What it proves: The trait ID is registered in UTTraitsRegistries and survives the batch registration sweep. Nothing about runtime behavior is verified.
- Missing proof: No test confirms that (a) `UT_generalAllergyFlag = true` is set in mod data when the trait is present on new game, (b) it is not set when the trait is absent, or (c) any periodic tick hook reads the flag and fires a sneeze roll with noise emission.

## Final Verdict
- Source origin: MoreSimpleTraits — `MSTAllergic` trait; cost -3; periodic `EveryTenMinutes` tick that rolls `ZombRand(288) == 0` (or 230 with `ProneToIllness`) for a sneeze event that emits noise at varying radii indoors/outdoors and optionally consumes a tissue or toilet paper item; mutually exclusive with `Resilient` in the Vanilla variant
- UT implementation: drifted — the trait writes `UT_generalAllergyFlag = true` to mod data at new-game time via a bare `OnNewGame` handler, but no periodic tick hook exists anywhere in the UTMods codebase that reads this flag to fire sneeze rolls, emit sounds, or consume items; the effect is inert end-to-end
- Description: wrong on two counts — the framing is "food allergies" which is not what the source trait does (it is a sneezing/noise trait), and the current implementation has no runtime effect of any kind; the description does not mention sneezing, noise, zombie attraction, or tissue consumption
- Balance: wrong — -4 cost for a trait with no active gameplay effect; cost is also one point higher than the source without justification
- Regression proof: missing
- Action needed: code fix — a periodic tick hook (e.g., `Events.EveryTenMinutes.Add`) must be written to read `UT_generalAllergyFlag` (or re-check `UTCore.hasTrait`) and fire a sneeze roll with `addSound` at appropriate radii and an emote; tissue/toilet paper mitigation should be ported from the source; description must be rewritten to describe sneezing and noise rather than food allergies; cost should be re-evaluated against -3 source after the fix; mutual exclusion with a resilience or illness-resistance trait should be considered
- Open gaps:
  - `UT_generalAllergyFlag` is written by `OnNewGame` but has no consumer anywhere in UTMods production code — the trait is a stub
  - Description invents a food-allergy mechanic that neither the source nor the UT implementation supports
  - Cost is -4 vs. source -3 with no documented rationale for the increase
  - Source's `ProneToIllness` interaction (tightening the sneeze roll from 1-in-288 to 1-in-230) is not ported
  - Source's tissue/toilet paper mitigation (muffled sneeze at radius 4/volume 6, item charge consumed) is not ported
  - Source's mutual exclusion with `Resilient` is not ported; no equivalent exclusion exists in UT
  - `OnNewGame` only fires for new saves; players loading an existing save who acquire the trait dynamically (if ever supported) would not have `UT_generalAllergyFlag` set
  - `DisabledInMultiplayer = true` is the UT guard; source had no explicit multiplayer disable but relied on the `TraitFactory` registration context — these are not equivalent and the single-player-with-no-trait-mod case is not covered
  - No interaction is defined with `UT_pillsallergy` or `UT_wildplantsallergy`, which share the allergy theme and could logically stack or conflict
