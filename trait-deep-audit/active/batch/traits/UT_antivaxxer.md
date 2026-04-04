# UT_antivaxxer

## Trait Summary

- UT trait id: UT_antivaxxer
- Source mod: SomewhatTraits (SomewhatTraitsCore)
- Source trait id: SWAntivaxxer (trait key: "SWAntivaxxer")
- Current cost: -3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.12/media/lua/client/SWSomewhatTraitsCore.lua` (lines 113, 433–442, 1071–1072) — legacy client implementation
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.12/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` (lines 26, 96) — NPC creation and trait registration
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.12/media/lua/shared/Translate/EN/UI_EN.txt` (lines 41–42) — English source translation
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/registries.lua` (line 29) — B42.13 registry (trait commented out)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/registries.lua` (line 29) — B42.15 registry (trait commented out)
- Source cost: -3 (from `TraitFactory.addTrait("SWAntivaxxer", ..., -3, ...)` in 42.12 NPCs file; consistent with UT cost -3).
- Source description (EN): name "Anti-vaxxer", description "Can't use cures." (UI_EN.txt lines 41–42).
- Source status across versions:
  - B42.12 (SomewhatTraitsCore): fully implemented; trait fires at character creation.
  - B42.13 and B42.15 (SomewhatTraits registries): `"SWAntivaxxer"` is **commented out** (`--"SWAntivaxxer", -- -3`). No B42.15 implementation exists in SomewhatTraitsCore 42.15 files. The trait was **dropped** by the source mod from B42.13 onward.
- Source trigger path (B42.12 legacy):
  - `Events.OnCreatePlayer` fires → reads all traits onto local booleans including `hasSWAntivaxxer = character:HasTrait("SWAntivaxxer")`.
  - If `hasSWAntivaxxer`, calls `SWAntivaxxer()` immediately in the same handler.
- Source behavior (SWAntivaxxer function, lines 433–442):
  1. Calls `getScriptManager():getAllRecipes()` — returns `ArrayList<Recipe>`.
  2. Iterates 0-indexed: `for i = 0, allRecipes:size() - 1`.
  3. For each recipe, calls `recipe:getOriginalname()` to get the raw script-level identifier.
  4. If `originalName:contains("Inject")` (Java String method, case-sensitive), then:
     - `recipe:setIsHidden(true)` — **note: `Recipe` Java class has no `setIsHidden()` method; only `EvolvedRecipe` does. This call is also a silent runtime failure in the source.**
     - `recipe:setCanPerform("SWIdontWantToLiveOnThisPlanetAnymore")` — sets a nonsense perform-condition string.
  5. Effect: in source, `setIsHidden` fails silently on `Recipe` objects; `setCanPerform` is what actually blocks use.
- Source NPC: `["SWAntivaxxer"] = true, --can't use cures` marks it as an NPC-applicable trait in the 42.12 NPC creation table (MainCreationMethods.lua line 26).
- Source mutual exclusions: none observed in reviewed files.
- Source `DisabledInMultiplayer`: not specified in a 42.12 script definition file (the trait predates the B42 script-definition format). The B42.13/42.15 registries omit it entirely.

## Current UT Evidence

### Structure

- Registered in test harness: yes (`test/run_tests.lua` line 233, grouped in "Stat Modifiers (20)")
- Defined in UT_character_traits.txt: yes (lines 990–998)
  - `Cost = -3`
  - `DisabledInMultiplayer = true`
  - `IsProfessionTrait = false`
  - No `MutuallyExclusiveTraits` declared
- Translation strings present: yes
  - `UI_UT_antivaxxer = "Anti-Vaxxer"` (UI_EN.txt line 290)
  - `UI_UT_antivaxxerDesc = "Your distrust of medicine makes you resistant to treatment. Medical items are less effective on you."` (UI_EN.txt line 291)
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_antivaxxer.lua`)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_antivaxxer.lua` (full file, 19 lines)
  - `media/scripts/UT_character_traits.txt` (lines 990–998)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 290–291)
  - `test/run_tests.lua` (line 233)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 11–16) — `UTCore.hasTrait`
  - `PZCodebase/Java/source/zombie/scripting/objects/Recipe.java` — `getName()`, `getOriginalname()`, `hidden` field
  - `PZCodebase/Java/source/zombie/scripting/objects/EvolvedRecipe.java` (line 707) — `setIsHidden()`
  - `PZCodebase/Java/source/zombie/scripting/ScriptManager.java` (line 725) — `getAllRecipes()` return type
- Event registrations:
  - `Events.OnCreatePlayer.Add(onCreatePlayer)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe trait check (returns false if player or traits are nil; calls `player:getTraits():contains(traitId)`)
- Runtime chain (plain language):
  1. On `OnCreatePlayer`: receives `playerIndex` (integer) and `player` (IsoPlayer).
  2. Calls `UTCore.hasTrait(player, "UniversalTraits:UT_antivaxxer")`. If the player does not have the trait, exits immediately.
  3. Calls `getScriptManager():getAllRecipes()` — returns a Java `ArrayList<Recipe>`.
  4. Iterates `for i = 0, recipes:size() - 1 do` (0-indexed, correct).
  5. For each recipe `r`, calls `r:getName()` — returns the **translated display name** via `Translator.getRecipeName(name)`.
  6. If `string.find(r:getName(), "Inject")` is truthy (Lua pattern match, case-sensitive), calls `r:setIsHidden(true)`.
  7. Fires once at character creation; no subsequent repeat.
- Actual behavior (exact values):
  - Filter method: `string.find(r:getName(), "Inject")` — matches any recipe whose translated display name contains the substring "Inject" (case-sensitive, no anchoring).
  - Mutation call: `r:setIsHidden(true)` on a `Recipe` object.
  - **`Recipe.java` has no `setIsHidden()` method.** The field `hidden` is public but there is no setter named `setIsHidden` on `Recipe`. Only `EvolvedRecipe` (a separate class that does not extend `Recipe`) has `setIsHidden(boolean)`. This call will produce a Kahlua/Java interop error or silently fail for every recipe in the list.
  - Frequency: once per character creation event, not repeated.

## Description Integrity

- Display name check: "Anti-Vaxxer" — matches source name "Anti-vaxxer" (capitalisation difference only; acceptable).
- Description check: `UI_UT_antivaxxerDesc` reads: "Your distrust of medicine makes you resistant to treatment. Medical items are less effective on you."
- Issues found:
  1. **Description is completely detached from implementation.** The code attempts to hide recipes containing "Inject" in their name. The description says "Medical items are less effective on you" — this implies a stat modifier (reduced healing, slower bandage progress, lower medicine effectiveness, etc.). No such stat modifier exists anywhere in the file. The code touches recipe visibility, not item effectiveness. A player reading the description would expect reduced healing from medical items; what the code does (if it worked) is hide injection recipes.
  2. **The source description ("Can't use cures") is also inaccurate for the same reason.** Even in the source, `setIsHidden` fails on `Recipe` objects (the method does not exist on that class); `setCanPerform` with a dummy string was the actual blocker in the source, and UT did not port that call at all.
  3. **"Medical items are less effective" implies a numeric penalty that does not exist.** There is no modifier on `BodyDamage`, no reduced heal multiplier, no `addModifier` call, and no `EveryOneMinute` or similar periodic hook. The only hook is `OnCreatePlayer`.
  4. **Locale sensitivity.** The filter uses `r:getName()` (translated display name) rather than `r:getOriginalname()` (raw script identifier). In non-English locales, recipe display names are translated and may not contain the English word "Inject". The source used `getOriginalname()`, which is locale-independent. The UT port switched to `getName()`, making the filter locale-dependent.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside claimed by description: "Medical items are less effective." This is not implemented.
- Downside as coded: attempts to hide all recipes whose translated display name contains "Inject." Due to the `setIsHidden` bug (wrong class), this has no runtime effect. The trait is **mechanically inert** as implemented.
- Source cost: -3. UT cost: -3. Cost matches source, but both are effectively for a non-functional trait.
- Rate analysis: not applicable — no periodic effect.
- Peer comparison: the trait provides free points in its current state. Any player can take -3 points with zero actual penalty.
- Stack or exclusion notes: no `MutuallyExclusiveTraits` declared. No natural conflicts.
- Cost verdict: -3 is invalid for a trait that applies no effect. The cost should reflect the intended penalty once the implementation is fixed.

## Regression Proof

- Existing test: `UT_antivaxxer` is listed in the Stat Modifiers registration sweep (`run_tests.lua` line 233), confirming the trait ID is registered with `CharacterTrait`. This is the only observed test reference.
- What it proves: the trait ID `"UniversalTraits:UT_antivaxxer"` exists in the CharacterTrait registry. It does not test runtime behavior.
- Missing proof:
  1. No test that `onCreatePlayer` fires and iterates recipes when the trait is present.
  2. No test that recipes containing "Inject" are hidden (and recipes not containing "Inject" are unaffected).
  3. No test that the handler exits when the player does not have the trait.
  4. No test that guards against `recipes` being nil or empty.
  5. No test capturing the `setIsHidden` call or verifying it reaches the correct recipe objects.
- Minimum next test if needed: "antivaxxer: hides inject recipes on player creation" — mock `getScriptManager():getAllRecipes()` returning a list with one recipe named "Inject Antibiotics" and one named "Bandage Wound"; fire `OnCreatePlayer`; assert `setIsHidden(true)` was called only on the first recipe. This test will immediately surface the `setIsHidden` bug.

## Final Verdict

- Source origin: proven — SomewhatTraits `SWAntivaxxer` is the confirmed source (B42.12 SWSomewhatTraitsCore.lua). The trait was dropped by the source mod in B42.13 and B42.15 (commented out in registries; no 42.15 implementation found). UT preserved the B42.12 concept.
- UT implementation: broken — two independent defects make the trait non-functional:
  1. **`setIsHidden` method does not exist on `Recipe`.** `ScriptManager.getAllRecipes()` returns `ArrayList<Recipe>`. `Recipe.java` exposes a public `hidden` field but no `setIsHidden()` setter. Only `EvolvedRecipe` (a separate, non-related class) has `setIsHidden(boolean)`. Every call to `r:setIsHidden(true)` in the loop will fail at the Java interop layer. The source also had this bug but compensated with `setCanPerform("SWIdontWantToLiveOnThisPlanetAnymore")`, which UT did not port.
  2. **`r:getName()` returns the translated display name, not the script identifier.** The source used `recipe:getOriginalname():contains("Inject")` (locale-independent). UT uses `string.find(r:getName(), "Inject")`, which matches the translated string. In non-English locales, translated recipe names will not contain "Inject" and no recipes will be hidden even if `setIsHidden` worked.
- Description: fully detached from both the source intent and the UT implementation. The description ("Medical items are less effective on you") does not describe recipe hiding. The source description ("Can't use cures") was closer to the intent but the mechanism was never about item effectiveness.
- Balance: the trait is functionally free points — -3 cost, zero runtime penalty. Unacceptable in its current state.
- Regression proof: registration confirmed; zero behavioral tests exist for this trait.
- Action needed:
  1. **Fix the `setIsHidden` call.** Option A: access the public field directly (`r.hidden = true`) if Kahlua/B42 allows public field assignment. Option B: use `getScriptManager():getEvolvedRecipes()` instead if the target recipes are evolved recipes. Option C: port the source's `setCanPerform` approach as a secondary blocker. Verify the correct Java API for the B42 recipe type before any fix.
  2. **Switch to `r:getOriginalname()` for the filter.** Replace `string.find(r:getName(), "Inject")` with `string.find(r:getOriginalname(), "Inject")` to restore locale independence (matching source behavior).
  3. **Decide on the actual mechanic and rewrite the description.** If the intent is to hide injection recipes, the description should say something like "You refuse to use syringes or injections. All injection-based recipes are hidden." If the intent is a medical-item effectiveness penalty (as the current description claims), the implementation must be rebuilt from scratch with a stat modifier or item-use hook.
  4. **Consider whether the trait belongs in UT at all.** The source dropped it from B42.13 onward, suggesting it may have been removed due to implementation issues or balance concerns. Review whether the concept is viable before investing in a fix.
  5. **Add behavioral tests** for: recipe iteration on `OnCreatePlayer`, correct "Inject" matching, non-matching recipes unaffected, and handler guard when trait is absent.
- Open gaps:
  - The exact Kahlua behavior when calling a non-existent Java method (silent nil return vs. error) is not confirmed from the reviewed files. If it raises a Lua error, the entire `onCreatePlayer` handler may silently abort at that line, producing a logged error rather than a no-op.
  - It is not confirmed whether any vanilla PZ B42 recipes use the identifier "Inject" in their `originalname`. If no such recipes exist, the filter is vacuously safe but also vacuously useless.
  - The `setCanPerform` mechanism from the source is not ported; even if `setIsHidden` is fixed, recipes would still appear usable (just hidden). Whether hidden-only is sufficient for the intended UX is undecided.
