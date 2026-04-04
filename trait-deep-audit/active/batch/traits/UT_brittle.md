# UT_brittle

## Trait Summary
- UT trait id: UT_brittle
- Source mod: unknown — no direct source trait found in installed-mods research; the "BrittleKnees" trait in DynamicTraitsExpandedMoodles is a fitness-reduction trait, not a fracture-chance trait; no fracture-multiplier trait was located in any researched source mod
- Source trait id: unknown
- Current cost: -6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/shared/Translate/EN/UI_EN.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTByBodyConditions.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTexpandedMoodleEffects.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreTraits/mods/More Traits - Dynamic/media/lua/client/MoreTraits - Dynamic.lua`
- Source trigger path: unknown — no source mod implements a standalone static fracture-chance multiplier trait; DynamicTraitsExpandedMoodles "BrittleKnees" is a dynamic fitness-level trait tied to body weight, not a fracture-chance modifier
- Source behavior: unknown — no matching source behavior found; the concept (increased fracture chance) is original or drawn from an unresearched mod

## Current UT Evidence
### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: N/A — no MutuallyExclusiveTraits or grants defined in script block
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_brittle.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/scripts/UT_character_traits.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`
- Runtime chain (plain language):
  1. On new game start, `onNewGame` fires for the player.
  2. `UTCore.hasTrait` checks whether the player has `UniversalTraits:UT_brittle`.
  3. If yes, writes `player:getModData()["UT_fractureMult"] = 1.5` into player mod data.
  4. The key `UT_fractureMult` is never read by any other script in the UTMods codebase — the multiplier is stored but has no consumer.
- Actual behavior (exact values): Sets `UT_fractureMult = 1.5` on the player's mod data at new-game time. Because no code reads this key to modify fracture rolls, the trait has **no runtime effect** in the current implementation.

## Description Integrity
- Display name check: "Brittle" — matches the concept of increased fracture susceptibility; name is accurate to intent.
- Description check: "Your bones are fragile and snap under stress. Fracture chance is increased by +50%." — the +50% claim is consistent with the 1.5 multiplier written to mod data, but the effect is currently inert because no fracture-roll code consumes `UT_fractureMult`.
- Missing or misleading details: The description is misleading in practice: it asserts a live mechanical effect (+50% fracture chance) that does not actually apply. The multiplier is written but never applied.

## Balance Review
- Upside: none
- Downside: none (intended: +50% fracture chance; actual: zero effect)
- Uptime: N/A — effect is never active
- Peer comparison: UT_glassbody at -10 cost applies a real ×1.5 incoming damage multiplier. UT_brittle at -6 cost claims a +50% fracture penalty but delivers nothing.
- Stack or exclusion notes: no exclusions defined; could stack with any other trait with no interaction
- Cost verdict: wrong — the player receives -6 points for a trait that currently has no gameplay effect; they are being charged for a broken mechanic

## Regression Proof
- Existing test: UT_brittle appears in the batch trait list in `run_tests.lua` (line 250), confirming it is included in the batch registration sweep. No dedicated behavioral test exists.
- What it proves: The trait ID is registered in UTTraitsRegistries. Nothing about runtime behavior is verified.
- Missing proof: No test confirms that (a) `UT_fractureMult` is set on new game when the trait is present, (b) it is not set when the trait is absent, or (c) any fracture-roll code reads and applies the multiplier.
- Minimum next test if needed: A unit test that mocks `Events.OnNewGame`, fires it with a player who has the trait, and asserts `player:getModData()["UT_fractureMult"] == 1.5`; plus a second assertion that a player without the trait does not have the key set. A third test should verify the consumer hook applies the multiplier — but that consumer does not currently exist, so the code fix must come first.

## Final Verdict
- Source origin: unknown
- UT implementation: drifted — the trait writes a mod data key at new-game time but no code reads that key; the stated effect is not implemented end-to-end
- Description: misleading — claims +50% fracture chance but the effect is inert
- Balance: wrong — -6 cost for a trait with no active effect
- Regression proof: missing
- Action needed: code fix — a fracture-roll hook (e.g., intercepting the game's fracture chance calculation) must be written to read `UT_fractureMult` and apply it; alternatively the mod data approach must be replaced with a direct hook; description and cost should be re-evaluated after the fix
- Open gaps:
  - No source mod identified that implements a static fracture-chance multiplier trait; origin of the concept is unconfirmed
  - `UT_fractureMult` key is written but has no consumer anywhere in UTMods — the trait is effectively a stub
  - No mutual exclusion with UT_analgesia (which suppresses pain from injuries) — unclear if they should interact
  - OnNewGame only fires for new saves; players loading an existing save without the trait who later acquire it (if dynamic trait grant is ever added) would not have the key set — load-game hook not present
