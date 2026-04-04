# UT_wildplantsallergy

## Trait Summary

- UT trait id: `UT_wildplantsallergy`
- Source mod: `DynamicTraitsExpandedMoodles`
- Source trait id: `WildPlantsAllergy`
- Current cost: `-3`
- Scripted: yes
- Owner: OpenCode
- Status: complete

## Source Evidence

- Source files reviewed: `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/NPCs/DTEMMainCreationMethods.lua`, `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/Translate/EN/UI_EN.txt`, `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/server/DTEMRecipeCode.lua`, `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMAllergy.lua`, `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMMainFile.lua`, `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMMoodles.lua`
- Source trigger path: character creation registers `WildPlantsAllergy` at `-4`; eating berries, mushrooms, several raw foraged plants, or recipes containing berry/mushroom ingredients calls `DTEMallergyIncrease`; `DTEMEveryOneMinuteMain` then runs allergy decay plus symptom tiers every in-game minute; `DTEMallergyMoodleUpdate` publishes four moodle levels from the shared `DTEMallergy` meter.
- Source behavior: proven. The source trait is a real negative food-allergy system, not a marker. Allergy gain is clamped to `0-100`; raw berry/mushroom/foraged-plant foods add `abs(food:getHungerChange()) * 100`, mushroom recipes add `30`, berry recipes add `15`. Increase is modified by `WeakStomach x1.1` or `IronGut x0.9`, then `ProneToIllness x1.3` or `Resilient x0.7`. Each minute there is a `1/5` chance to reduce the allergy meter by `0-4`, modified by `WeakStomach x0.9` or `IronGut x1.1`, then `SlowHealer x0.8` or `FastHealer x1.2`. Symptoms escalate by threshold: `>20-40` sneeze `1/50` and cough `1/40`; `>40-60` sneeze `1/30`, cough `1/20`, plus `1/5` itching/pain on arms or hands; `>60-80` adds `1/5` itching/pain on legs or neck; `>80-100` also applies fatigue, endurance loss, body-part health loss every minute and has a `1/3` chance to add faint emote, head pain, and food sickness.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: N/A
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed: `UniversalTraits/media/registries.lua`, `UniversalTraits/media/scripts/UT_character_traits.txt`, `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`, `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_wildplantsallergy.lua`, `UniversalTraits/media/lua/shared/UniversalTraits/UT_MET.lua`
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait` only
- Runtime chain (plain language): on new game, the trait checks whether the spawned player has `UniversalTraits:UT_wildplantsallergy`; if true, it writes `UT_wildplantAllergyFlag = true` into player moddata and stops. No current UT file reads that moddata key, no shared UT_CORE allergy handler exists, and the trait is absent from `UT_MET` and from script-side mutual exclusions.
- Actual behavior (exact values): current UT behavior is a one-time boolean write on character creation only: `player:getModData()["UT_wildplantAllergyFlag"] = true`. There is no food interception, no periodic handler, no allergy meter, no moodle, no damage, no fatigue/endurance penalty, no sound/sneeze loop, no save-load re-registration path, and no reset logic beyond whatever clears moddata on a fresh character.

## Description Integrity

- Display name check: partially aligned. `Wild Plant Allergy` still points at the same source concept, but the source specifically targets berries, mushrooms, and selected wild-plant food paths rather than a generic all-purpose wild-food rule.
- Description check: misleading. `Foraged plants that others eat without concern leave you feeling ill. Wild food carries real risk for you.` describes an active penalty, but the shipped UT trait currently does nothing beyond storing an unused flag.
- Missing or misleading details: missing the source trigger scope (berries, mushrooms, recipe ingredients, specific foraged plants), missing all source numbers and escalation thresholds, missing the source cost drift (`-4` source vs `-3` UT), and most importantly missing that the current UT implementation has no live gameplay effect at all.

## Balance Review

- Upside: the player gains `+3` build points from a negative trait that currently has no enforced downside.
- Downside: none in current UT. The only effect is an unused moddata marker.
- Uptime: effectively `100%` free value because the no-op state persists after spawn and never produces a penalty.
- Peer comparison: versus the source trait, UT removed the entire allergy system while still paying the player points; versus other active negative food/health traits, this is materially under-costed because it does not expose the player to any recurring risk.
- Stack or exclusion notes: no `MutuallyExclusiveTraits`, no `UT_MET` group membership, and no current stack prevention. Because the trait is inert, it stacks safely with any food, foraging, healing, or resilience trait and becomes pure free points.
- Cost verdict: wrong

## Regression Proof

- Existing test: only indirect coverage from the trait-id roster in `UniversalTraits/test/run_tests.lua`, which asserts the registered trait list still includes `UniversalTraits:UT_wildplantsallergy`.
- What it proves: the id remains present in the expected registration set.
- Missing proof: there is no automated test that proves wild plants trigger any penalty, no test that the `OnNewGame` flag is written, and no test covering any shared hook or food event path because no such UT path currently exists.
- Minimum next test if needed: after the code fix, add a behavior test that creates a player with `UniversalTraits:UT_wildplantsallergy`, triggers the intended wild-food path with a berry/mushroom/foraged-food mock, and asserts the trait's allergy state or direct penalties increase on that event. If the implementation keeps the spawn flag, add a smaller setup test that fires `Events.OnNewGame` and asserts `UT_wildplantAllergyFlag == true`, but that alone is not sufficient regression proof for the advertised trait behavior.

## Final Verdict

- Source origin: proven
- UT implementation: drifted
- Description: misleading
- Balance: wrong
- Regression proof: missing
- Action needed: code fix
- Open gaps: `UT_wildplantAllergyFlag` is written but never consumed anywhere in UT; the source `-4` active allergy system was reduced to an inert `-3` trait with no exclusions or runtime penalties; no automated test proves any food-triggered allergy behavior or even the current spawn-marker setup.
