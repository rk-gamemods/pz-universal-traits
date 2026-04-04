# UT_snorer

## Trait Summary
- UT trait id: UT_snorer
- Source mod: MoreSimpleTraits (`mods/MoreSimpleTraits` and `mods/MoreSimpleTraitsVanilla`)
- Source trait id: `Snorer` (registered via `TraitFactory.addTrait("Snorer", ...)`)
- Current cost: -2
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt`
- Source trigger path: `Events.EveryTenMinutes.Add(snorertrait)` — `snorertrait()` fires every ten in-game minutes; if the player has trait `"Snorer"` and is asleep, it calls `addSound` at the player's position with two independent random rolls: `ZombRand(17) == 0` emits a radius-15/volume-20 sound; `ZombRand(80) == 0` emits a radius-22/volume-26 sound
- Source behavior: probabilistic sound emission while the player is sleeping — no multiplier or moddata key; the effect is implemented as direct periodic `addSound` calls, not as a stored noise multiplier

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_snorer = CharacterTrait.register("UniversalTraits:UT_snorer")` (line 185)
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_snorer`, `Cost = -2`, `DisabledInMultiplayer = true`
- Translation strings present: yes — `UI_UT_snorer = "Snorer"`, `UI_UT_snorerDesc = "You rattle the walls when you sleep. Noise output while sleeping is doubled (×2.0 noise multiplier), attracting nearby zombies."`
- Exclusions/grants correct: N/A — no `MutuallyExclusiveTraits` or grants defined in the script block
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_snorer.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/scripts/UT_character_traits.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua`
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`, `UTCore.applyNoiseMod(player, 2.0)`
- Runtime chain (plain language):
  1. On new game start, `onNewGame` fires for the player.
  2. `UTCore.hasTrait` checks whether the player has `UniversalTraits:UT_snorer`.
  3. If yes, `UTCore.applyNoiseMod(player, 2.0)` is called.
  4. `UTCore.applyNoiseMod` (defined in `UTCore_StatModifiers.lua` line 71) writes `player:getModData()["UT_noiseMult"] = 2.0` into player mod data.
  5. The key `UT_noiseMult` is never read by any other script in the UTMods codebase — no sleep-tick hook, no `addSound` call, and no noise-roll modifier reads it. The multiplier is stored but has no consumer.
- Actual behavior (exact values): Sets `UT_noiseMult = 2.0` on the player's mod data at new-game time. Because no code reads this key to emit noise or scale sound radius, the trait has **no runtime effect** in the current implementation.

## Description Integrity
- Display name check: "Snorer" — matches the source and concept; name is accurate.
- Description check: "You rattle the walls when you sleep. Noise output while sleeping is doubled (×2.0 noise multiplier), attracting nearby zombies." — the multiplier value (×2.0) is consistent with the value written to mod data, and the zombie-attraction framing accurately describes the intended hazard. However, the effect is currently inert because no code consumes `UT_noiseMult` to actually emit sound or scale noise.
- Missing or misleading details: The description claims a live mechanical effect (doubled noise while sleeping, zombie attraction) that does not apply. The multiplier is stored but never applied. The description is accurate to intent but misleading about current behavior.

## Balance Review
- Upside: none
- Downside: none (intended: ×2.0 noise multiplier while sleeping, attracting zombies; actual: zero effect)
- Uptime: N/A — effect is never active
- Peer comparison:
  - Source mod (MoreSimpleTraits) implements snoring via probabilistic direct `addSound` calls every ten minutes, which is a real runtime hazard. The UT rewrite replaced that with a moddata-stored multiplier that no consumer reads — a regression from the source behavior.
  - `UT_restfulsleeper` and `UT_quickrest` (both Sleep & Rest phase-mates) store their values via UT_CORE hooks (`applySleepQuality`) — the pattern is consistent, but `UT_noiseMult` uniquely has no downstream consumer among the sleep tier traits.
- Stack or exclusion notes: no exclusions defined; could stack with other traits with no interaction. No natural exclusion with stealth or quiet-sleep traits is enforced.
- Cost verdict: wrong — the player receives -2 points for a trait that currently has no gameplay effect; they are being charged for a broken mechanic. Source cost was also -2, so the cost value is correct in intent but wrong in practice.

## Regression Proof
- Existing test: `UT_snorer` appears in the batch trait list in `run_tests.lua` (line 258), confirming it is included in the batch registration sweep. No dedicated behavioral test exists.
- What it proves: The trait ID is registered in UTTraitsRegistries. Nothing about runtime behavior is verified.
- Missing proof: No test confirms that (a) `UT_noiseMult = 2.0` is set on new game when the trait is present, (b) it is not set when the trait is absent, or (c) any sleep-noise hook reads `UT_noiseMult` and emits proportionally larger sounds.
- Minimum next test if needed: A unit test that mocks `Events.OnNewGame`, fires it with a player who has the trait, and asserts `player:getModData()["UT_noiseMult"] == 2.0`; plus an assertion that a player without the trait does not have the key set. A third test should verify a sleep-noise consumer hook applies the multiplier — but that consumer does not currently exist, so the code fix must come first.

## Final Verdict
- Source origin: MoreSimpleTraits — `Snorer` trait; cost -2, disabled when sleep is off; source used probabilistic `addSound` calls on `EveryTenMinutes`
- UT implementation: drifted — the trait writes `UT_noiseMult = 2.0` to mod data at new-game time via `UTCore.applyNoiseMod`, but no code anywhere in the UTMods codebase reads `UT_noiseMult` to emit sleep noise or scale sound radius; the effect is inert end-to-end
- Description: misleading in practice — text claims ×2.0 noise while sleeping attracts zombies, but the stored multiplier is never consumed; the stated effect does not occur
- Balance: wrong — -2 cost for a trait with no active gameplay effect; cost value matches source intent but not actual behavior
- Regression proof: missing
- Action needed: code fix — a sleep-tick hook (e.g., on `EveryTenMinutes` or `OnPlayerUpdate`) must be written to read `UT_noiseMult` from mod data and call `addSound` with scaled radius/volume when the player is asleep; alternatively, port the source's direct probabilistic `addSound` approach rather than the moddata-multiplier pattern; description and cost should be re-evaluated after the fix
- Open gaps:
  - `UT_noiseMult` key is written by `UTCore.applyNoiseMod` but has no consumer anywhere in UTMods production code — the trait is effectively a stub
  - Source mod disabled the trait when sleep was globally off (`not SleepEnabled`); UT uses `DisabledInMultiplayer = true` instead — these are not equivalent; single-player games with sleep disabled are not covered by the UT guard
  - `OnNewGame` only fires for new saves; players loading an existing save who acquire the trait dynamically (if that is ever supported) would not have `UT_noiseMult` set
  - No mutual exclusion with any stealth or quiet-sleep trait is enforced
  - The ×2.0 multiplier implies a baseline sleep noise value, but no baseline is defined or documented; the consumer hook would need to establish what "1.0×" noise means in practice
