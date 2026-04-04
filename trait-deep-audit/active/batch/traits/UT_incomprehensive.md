# UT_incomprehensive

## Trait Summary

- UT trait id: UT_incomprehensive
- Source mod: More Traits (ToadTraits)
- Source trait id: ToadTraits:incomprehensive
- Current cost: -10
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/scripts/ToadTraits.txt` (trait definition, lines 404–413)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/Translate/EN/UI_EN.txt` (translation strings, lines 60–61)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` (runtime implementation — container loot removal and foraging penalty hooks, lines 1012–1105 and 3043–3045)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42/media/lua/client/MoreTraits - Dynamic.lua` (dynamic removal logic, lines 593–596)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/scripts/ToadTraits.txt` (line 852 — `ToadTraits:scrounger` declares symmetric mutual exclusion)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/Foraging/ToadTraitsforageDefinitions.lua` (foraging vision penalty, line 4)
- Source trait definition (ToadTraits.txt, lines 404–413):
  - `Cost = -10`
  - `DisabledInMultiplayer = false`
  - `MutuallyExclusiveTraits = ToadTraits:scrounger`
- Source trigger paths:
  1. `ISInventoryPage` rendering hook — `ToadTraitIncomprehensive(page, player)` is called each time the inventory UI opens/refreshes. For each non-floor, non-dead-body container in `page.backpacks` whose mod data does not yet carry `bScroungerorIncomprehensiveRolled = true`, the flag is set and `containerObj:transmitModData()` is called. Then `ZombRand(100) <= baseChance` determines whether items are removed. The base chance is `SandboxVars.MoreTraits.IncomprehensiveChance` (default 10, i.e. 10% per container per first open). Items to remove are gathered by iterating the container's item list, picking one random item per unique type and removing up to a calculated `removeCount` of it. In multiplayer the removal is delegated via `sendClientCommand(player, 'ToadTraits', 'Incomprehensive', args)` and handled server-side by `ProcessTraitLootRemoval` in `MoreTraitsCC.lua`.
  2. Foraging bonus adjustment — in the foraging system, when calculating a container search's secondary chance, `incomprehensive` applies `chance = chance - 2` (capped at minimum 1). The `ToadTraitsforageDefinitions.lua` file also registers the trait with `visionBonus = -1.0` for field foraging.
  3. Dynamic removal (More Traits - Dynamic): if `SandboxVars.MoreTraitsDynamic.IncomprehensiveDynamic == true` and the player reaches `SandboxVars.MoreTraitsDynamic.IncomprehensiveDynamicSkill` in the Scavenging perk (requires the ScavengingSkill or ScavengingSkillFixed mod), the trait is removed and a green halo text fires.
  4. Lucky/unlucky modifiers — if the player also has `ToadTraits:lucky`, `baseChance` is reduced by `5 * luckimpact`; if they have `ToadTraits:unlucky`, it is increased by `5 * luckimpact`.
- Source behavior:
  - Per container open (first open only, not repeatable): 10% chance (sandbox-configurable) to randomly remove a subset of items from that container. Items from dead bodies and floor containers are excluded.
  - Foraging secondary chance: −2 to search chance (minimum 1); foraging vision bonus: −1.0.
  - Dynamic removal: trait can be removed at a configurable Scavenging skill threshold.
  - Multiplayer: uses client→server command delegation for the removal step.
- Source EN description (UI_EN.txt, lines 60–61): "You're not as thorough as most. You tend to find less items while searching containers."
- Source cost: −10 points.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes (line 193, Phase 2 — Psychology & Modifiers block)
  - `UTTraitsRegistries.UT_incomprehensive = CharacterTrait.register("UniversalTraits:UT_incomprehensive")`
  - Registered after `UT_mundane` and before `UT_photographicmemory`.
- Defined in UT_character_traits.txt: yes (lines 1380–1388)
  - `Cost = -10`
  - `DisabledInMultiplayer = true`
  - No `MutuallyExclusiveTraits` field — the source mutual exclusion with `ToadTraits:scrounger` is dropped entirely (scrounger does not exist in UT).
- Translation strings present: yes (UI_EN.txt lines 419–420)
  - `UI_UT_incomprehensive = "Incomprehensive"`
  - `UI_UT_incomprehensiveDesc = "Complex ideas just do not stick for you. Your effective skill cap is reduced by 2 in all skills."`
- Exclusions/grants correct: no exclusions declared; the source exclusion (`ToadTraits:scrounger`) has no UT equivalent and is correctly absent. No grants.
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_incomprehensive.lua`, 11 lines)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_incomprehensive.lua` (full file, 11 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1380–1388)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 419–420)
  - `media/registries.lua` (line 193)
  - `test/run_tests.lua` (line 261 — trait in recognised-trait list; no `dofile` and no `test(...)` block for this trait)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 11–16 — `UTCore.hasTrait` implementation)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)` — fires once at new game start; no other event hooks.
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe presence check; calls `player:getTraits():contains(traitId)`.
- Runtime chain (plain language):
  1. At new game start, `Events.OnNewGame` fires and calls `onNewGame(player)`.
  2. `UTCore.hasTrait(player, "UniversalTraits:UT_incomprehensive")` is checked. If false, the handler returns immediately.
  3. If true, `player:getModData()["UT_skillCapReduction"] = 2` is written directly to the player's mod data table. No UTCore helper wraps this write; it is a raw mod data assignment.
  4. No further hooks are registered. The key `UT_skillCapReduction` sits in mod data and is expected to be read by some downstream system at runtime.
- Actual behavior (exact values):
  - On new game: writes `modData["UT_skillCapReduction"] = 2` (integer literal).
  - No periodic handler. No XP hook. No stat modifier. No loot manipulation.
- Downstream consumer of `UT_skillCapReduction`: **not found in the UTMods or UniversalTraits repos**. A search across the entire UTMods index for `UT_skillCapReduction` returns only the two copies of `UT_incomprehensive.lua` (dev and release). No hook, system, or consumer reads this key. The value is written to mod data and never acted upon.

## Description Integrity

- Display name check: `UI_UT_incomprehensive = "Incomprehensive"` — name matches source exactly.
- Description check: `UI_UT_incomprehensiveDesc = "Complex ideas just do not stick for you. Your effective skill cap is reduced by 2 in all skills."` — this description claims a skill cap reduction of 2 across all skills.
- Source description for comparison: "You're not as thorough as most. You tend to find less items while searching containers." — the source effect is container loot removal, not a skill cap. The UT description describes a completely different mechanic.
- Missing or misleading details: **The description is inaccurate with respect to the implementation.** The description promises a skill cap reduction of 2 in all skills. The implementation writes `UT_skillCapReduction = 2` to mod data but nothing reads that key. The promised cap reduction does not happen. The source's loot-removal and foraging-penalty effects are not implemented. The description does not mention loot or foraging because those were intentionally redesigned, but the replacement mechanic (skill cap) is not implemented either. The trait is currently inert: it applies a point cost of −10 and does nothing at runtime.

## Balance Review

- Upside: none — pure negative trait.
- Downside (claimed by description): skill cap reduced by 2 in all skills, applied once at new game.
- Downside (actual): none — `UT_skillCapReduction = 2` is written to mod data but has no consumer. The trait is mechanically inert.
- Uptime: N/A — the effect does not function.
- Peer comparison (if the skill cap reduction worked as described):
  - `UT_mundane` (−9 cost): XP gain reduced to ×0.8 in seven specific skills, plus disables special combat abilities. Broad but shallow XP rate penalty.
  - `UT_flatearther` (−4 cost): −30% MetaGame XP and −30% reading speed. Narrow scope.
  - `UT_luddite` (−4 cost): −40% Electrical XP. Single skill.
  - A universal skill cap reduction by 2 (from 10 to 8 in every skill) would be a severe long-game handicap, arguably stronger than any existing peer at −10 cost. Whether that would be proportionate depends on how skill caps work in B42. The question is moot until the mechanic is implemented.
- Source comparison: the source trait applied a probabilistic loot penalty (10% chance per container first open to remove random items) and a small foraging vision penalty (−1.0 vision, −2 search chance). UT abandons both and substitutes a skill cap reduction that is not implemented. Neither the source behavior nor the described UT behavior is currently active.
- Cost verdict: the −10 point cost is a direct carry-over from source. If the skill cap reduction were functional, the cost would need evaluation against B42 cap mechanics. Currently the cost penalises the player for zero mechanical gain, which is an unacceptable balance state.

## Regression Proof

- Existing test: `UniversalTraits:UT_incomprehensive` appears in the recognised-trait list at line 261 of `run_tests.lua` (Phase 2 — Psychology & Modifiers group). This confirms the trait ID string is registered with the test harness.
- `dofile` check: `UT_incomprehensive.lua` is **not loaded** by a `dofile` call anywhere in `run_tests.lua`. The trait's `onNewGame` handler is never registered in the test environment.
- `test(...)` block: none exists for `UT_incomprehensive`.
- What is proven: the trait ID string is correctly formed and present in the harness's known-trait registry. Nothing else is proven.
- What is not proven:
  1. The `onNewGame` handler fires and executes without error.
  2. `player:getModData()["UT_skillCapReduction"] = 2` is written correctly.
  3. Any downstream system reads `UT_skillCapReduction` and applies the cap reduction.
- Minimum tests needed:
  1. `dofile` the `UT_incomprehensive.lua` trait file in `run_tests.lua`.
  2. Add a `test(...)` block that fires `OnNewGame` with `UniversalTraits:UT_incomprehensive` and asserts `modData["UT_skillCapReduction"] == 2`.
  3. Once a consumer is implemented, add an integration test that confirms the cap reduction is enforced (e.g. asserting that a perk level cannot exceed `maxLevel - 2` for a player with the trait).

## Final Verdict

- Source origin: proven — `ToadTraits:incomprehensive` from More Traits confirmed. Definition (Cost = −10, one mutual exclusion with `scrounger`), EN translation, and runtime implementation traced in More Traits 42.13 source. Source effect: probabilistic per-container loot removal (10% default chance, first-open-only per container) and foraging vision/search penalties.
- UT implementation: **incomplete redesign with broken mechanic.** The source loot-removal behavior was intentionally replaced with a different concept (universal skill cap reduction by 2). The replacement concept is half-implemented: `onNewGame` correctly writes `modData["UT_skillCapReduction"] = 2` but no UTCore hook, XP hook, or perk-level hook reads this key and enforces the cap. The trait is mechanically inert at runtime.
- Description: **inaccurate** — the description promises a skill cap reduction of 2 in all skills. This effect does not occur because the consumer does not exist. Neither the promised UT effect nor the source effects are present at runtime.
- Balance: **broken** — the player pays −10 points and receives no mechanical benefit or disadvantage. This is the worst possible balance state for a negative trait.
- Regression proof: absent — the `UT_incomprehensive.lua` file is not loaded in `run_tests.lua` and no test block exercises the handler. Even the write of `UT_skillCapReduction` is untested.
- Action needed (priority: high):
  1. **Implement the consumer.** A UTCore hook must read `modData["UT_skillCapReduction"]` and cap perk level gain accordingly (e.g. in `Events.LevelPerk` or equivalent). Until this exists, the trait does nothing.
  2. **Add `dofile` and a test block** in `run_tests.lua` to assert the moddata write fires correctly.
  3. **Add a cap-enforcement test** once the consumer hook exists.
  4. **Correct the description or the mechanic** to ensure they match each other at release.
- Open gaps:
  1. No consumer of `UT_skillCapReduction` exists anywhere in the UTMods repo. The key is written and never read.
  2. No test loads or fires the `UT_incomprehensive.lua` `onNewGame` handler.
  3. No test asserts that `modData["UT_skillCapReduction"]` equals 2 after `OnNewGame`.
  4. The source's loot-removal and foraging-penalty effects are not implemented and are not documented as deliberate omissions anywhere in the trait files.
  5. The mutual exclusion with `ToadTraits:scrounger` is dropped; this is correct since scrounger does not exist in UT, but there is no UT-equivalent exclusion (e.g. with a future Scrounger trait) documented or planned.
