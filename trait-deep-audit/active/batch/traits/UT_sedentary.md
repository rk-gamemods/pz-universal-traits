# UT_sedentary

## Trait Summary

- UT trait id: UT_sedentary
- Source mod: DynamicTraitsExpandedMoodles (Dynamic Traits)
- Source trait id: Sedentary
- Current cost: -3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/NPCs/DTEMMainCreationMethods.lua`
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMByOtherConditions.lua`
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMexpandedActionsEffects.lua`
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMMainFile.lua`
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/Translate/EN/UI_EN.txt`
- Source registration: `TraitFactory.addTrait("Sedentary", getText("UI_trait_Sedentary"), -10, getText("UI_trait_SedentaryDesc"), false)` — cost -10 in source, not free, player-selectable.
- Source mutual exclusions: `Sedentary` is mutually exclusive with `PhysicallyActive`, `PhysicallyActive2`, `Strong`, `Athletic`, `Fit`.
- Source behavior: The trait is dynamic, not static. It is earned at runtime via an activity accumulator (`DTEMphysicallyActiveSedentaryTraits`): the accumulator decrements by 0.5 each tick of `DTEMactiveSedentaryTraits` (called from the main update loop), and the trait is applied when the accumulator reaches -20000. It is removed when the accumulator rises back into the -20000..40000 neutral band. The trait can also be selected at character creation (cost -10). When held, chopping trees applies random pain to both forearms and upper arms (`ZombRand(10)` points each, with `ZombRand(15)` duration). The activity accumulator is initialized to -60000 if the player starts with the trait selected.
- Source description: `UI_trait_Sedentary = "Sedentary"` / `UI_trait_SedentaryDesc = "Inactive lifestyle. You don't like wasting energy."` — vague; no numbers.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — line 265: `UTTraitsRegistries.UT_sedentary = CharacterTrait.register("UniversalTraits:UT_sedentary")`
- Defined in UT_character_traits.txt: yes — lines 1843–1851:
  ```
  character_trait_definition UniversalTraits:UT_sedentary
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_sedentary,
      Cost = -3,
      UIName = UI_UT_sedentary,
      UIDescription = UI_UT_sedentaryDesc,
  }
  ```
- Translation strings present: yes — `UI_UT_sedentary = "Sedentary"` / `UI_UT_sedentaryDesc = "Your body has grown accustomed to doing as little as possible. Fitness fades faster for you without consistent effort."` (UI_EN.txt lines 572–573)
- XPBoosts in script definition: none
- Exclusions/grants: none declared in the script block
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_sedentary.lua`
- Release copy in sync: yes — `release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_sedentary.lua` is byte-identical

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_sedentary.lua` (full file, 15 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (for `UTCore.hasTrait` implementation)
  - `test/run_tests.lua` (registration list, line 285)
- Event registrations: `Events.EveryHours.Add(handler)` — fires once per in-game hour
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`
- ModData keys written: `player:getModData()["UT_sedentaryPenalty"] = true`
- ModData key consumers: none found anywhere in the UTMods codebase — `UT_sedentaryPenalty` is written but never read by any other file
- Runtime chain (plain language):
  1. At module load time, `Events.EveryHours.Add(handler)` registers the handler with the PZ event system.
  2. Once per in-game hour, the PZ engine calls `handler()`.
  3. `getPlayer()` is called; if nil (dedicated server or pre-spawn), the function returns immediately.
  4. `UTCore.hasTrait(player, "UniversalTraits:UT_sedentary")` is called. Internally: `player:getTraits():contains("UniversalTraits:UT_sedentary")` — a nil-safe Java collection check. Returns `false` if player does not have the trait; handler exits.
  5. If the player has the trait: `player:getStats()` retrieves the stats object, then `stats:setEndurance(math.max(0, stats:getEndurance() - 0.01))` reduces the current endurance value by 0.01, clamped at 0 so it cannot go negative.
  6. `player:getModData()["UT_sedentaryPenalty"] = true` is written unconditionally after the endurance reduction — this key is a sentinel/diagnostic flag; no other code reads or acts on it.
- Exact numbers and cadence: −0.01 endurance per in-game hour; endurance range is 0.0–1.0 (or the player's maximum stamina, depending on PZ version); at full endurance (1.0), the trait would drain it to 0 in 100 in-game hours of continuous activation. The drain is additive with any natural recovery/drain already occurring and fires even if the player is asleep.
- Edge cases observed:
  - The handler uses `getPlayer()` (single-player / client-host call). On a dedicated server this returns nil and the handler exits harmlessly; however, the trait is also marked `DisabledInMultiplayer = true` in the script definition, so this should never fire in MP regardless.
  - No minimum-endurance floor other than `math.max(0, ...)` — endurance will be pinned at 0 indefinitely if the player stays completely inactive.
  - The handler fires every real in-game hour regardless of player activity level; there is no activity-based gating (unlike the source mod's accumulator system).
  - `UT_sedentaryPenalty = true` is written on every firing but is never cleared and never consumed. This appears to be an unfinished hook intended for future cross-trait interaction.

## Description Integrity

- Display name check: "Sedentary" — matches source name exactly; no issue.
- Description check: `"Your body has grown accustomed to doing as little as possible. Fitness fades faster for you without consistent effort."` — the description says "Fitness fades faster" but the runtime applies a drain to **endurance** (`stats:setEndurance`), not to the Fitness perk level or XP. This is a **description mismatch**: the player-visible text implies the Fitness skill is degrading, while the actual effect is a per-hour reduction of the stamina/endurance float stat.
- Missing details: The description gives no numbers (no "−0.01 per hour" or equivalent). The description does not mention the ModData sentinel key, which is expected, but also does not acknowledge that the drain occurs even when resting or sleeping.
- Accurate elements: "body has grown accustomed to doing as little as possible" correctly implies a passive penalty; "without consistent effort" is thematically appropriate.

## Balance Review

- Upside: −3 points returned at character creation.
- Downside: −0.01 endurance per in-game hour, every hour, permanently.
- Uptime: 100% — fires unconditionally once per in-game hour as long as the player is in-game and alive. No activity gate.
- Severity context: Endurance is a float on a 0–1 scale. The natural endurance recovery in PZ is activity-dependent (sprinting, exercise raise it; rest recovers it). A −0.01/hr drain means a resting player with endurance at 1.0 would reach 0 after 100 in-game hours — roughly 4 in-game days — but in practice endurance is always fluctuating with activity, so the drain acts as a permanent small tax on the player's stamina ceiling. The practical impact depends heavily on playstyle: sedentary (ironically) base players who rest frequently may never notice; active runners will feel the drain accumulate.
- Source cost comparison: Source cost was **−10** (substantial point refund) for a dynamic trait that also applied limb pain during physical exertion. UT cost is **−3**, which is drastically cheaper, but the UT behavior is also a simplified subset of source behavior (no pain, no activity accumulator).
- Peer comparison within UT: The trait "Couch Dweller" (`UI_UT_couchdwellerDesc = "A sedentary lifestyle means you tire quickly. Endurance is reduced."`) appears in the translation file and seems thematically identical — a sedentary-archetype trait that reduces endurance. The relationship between UT_sedentary and whichever trait maps to "Couch Dweller" needs clarification; if both are active simultaneously the endurance penalty stacks.
- Stack or exclusion notes: No mutual exclusions are declared in the UT script definition. The source had five mutual exclusions (PhysicallyActive, PhysicallyActive2, Strong, Athletic, Fit). None are replicated in UT. A player could simultaneously hold UT_sedentary and any UT athletics/fitness positive trait.
- Cost verdict: The −3 cost is low for a permanent stat drain that the player cannot mitigate. However the drain is small and the description mismatch (Fitness vs. endurance) makes the trait's actual strength hard to evaluate accurately. If the drain is intended to be on endurance (stamina float), −3 is reasonable to slightly cheap. If it was intended to affect Fitness XP or level, the implementation is wrong and cost cannot be evaluated against intent.

## Regression Proof

- Existing test: `"UniversalTraits:UT_sedentary"` appears in the registration list in `run_tests.lua` line 285, within the Phase 3b batch. This confirms the trait id resolves without a crash during the test harness load.
- What it proves: The trait id is registered, the script file loads without Lua parse errors, and the event is attached without fatal error.
- Missing proof: No test asserts that `handler()` is called and reduces endurance by 0.01. No test verifies that `UTCore.hasTrait` guard prevents the drain when the trait is absent. No test checks that endurance is clamped at 0 rather than going negative.
- Minimum next test if needed: Create a mock player with `UniversalTraits:UT_sedentary`, set `stats:getEndurance()` to 0.05, fire `EveryHours`, and assert `stats:getEndurance() == 0.04`. Also test with endurance at 0.0 and assert it remains 0.0 (clamping). Test without the trait to confirm the guard exits cleanly.

## Final Verdict

- Source origin: confirmed — source trait "Sedentary" from DynamicTraitsExpandedMoodles verified; `TraitFactory.addTrait("Sedentary", ..., -10, ...)` at line 479 of DTEMMainCreationMethods.lua. UT correctly captured the name and negative-cost character (though cost is −3 vs. source −10, a deliberate simplification).
- UT implementation: partially faithful — the core concept (inactive lifestyle drains endurance) is thematically correct, but the implementation is a significant simplification: no activity accumulator, no limb pain, no mutual exclusions, no dynamic earning/loss of the trait. The source's richest behavior (the dynamic add/remove based on real play behavior) is entirely absent.
- Description: **inaccurate** — "Fitness fades faster" describes Fitness perk degradation; the runtime drains endurance (a float stat), not Fitness XP or level. This is a misleading description.
- Balance: acceptable but unverified against intent — −3 for a constant −0.01/hr endurance drain is reasonable if the endurance target is correct; if the intent was to drain Fitness the cost and behavior both need revisiting.
- Regression proof: partially protected — registration smoke-test exists; no behavioral assertion for the hourly drain, no clamp test.
- Action needed: description fix (required), behavior verification (confirm endurance drain is intended and not a mistake for Fitness perk drain), mutual exclusion review (consider adding exclusions vs. UT athletics traits), consume or remove `UT_sedentaryPenalty` ModData key, add behavioral unit tests.
- Open gaps:
  - Description says "Fitness fades" but code drains `endurance` (`stats:setEndurance`). Either the description must be corrected to say "Endurance slowly drains" or the implementation must be changed to drain Fitness XP/level.
  - `player:getModData()["UT_sedentaryPenalty"] = true` is written every hour but never read by any other file in the codebase. It should either be wired to a consuming system or removed.
  - No mutual exclusions declared — a player can combine UT_sedentary with UT positive fitness/athletics traits without restriction, unlike the source mod.
  - The drain fires while the player is asleep or standing still; there is no activity gate. The source mod gated the drain on a continuous inactivity accumulator. Consider whether the drain should only fire during low-activity periods.
  - Source cost was −10; UT cost is −3. The large gap is not documented. If future alignment to source behavior is desired, cost will need revision upward.
  - No behavioral unit tests for: hourly drain value, clamp at 0, guard on trait absence.
