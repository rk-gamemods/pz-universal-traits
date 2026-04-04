# UT_bouncer_I

## Trait Summary

- UT trait id: UT_bouncer_I
- Source mod: More Traits (ToadTraitsDynamic / hypnotoadtrance)
- Source trait id: `bouncer` (registry key: `ToadTraitsRegistries.bouncer`)
- Current cost: 4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` (lines 69, 1890–1931) — shared runtime update loop; B42.13 version
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42.13/media/lua/shared/MoreTraits - Dynamic.lua` (lines 435–444) — dynamic (unlock-at-runtime) variant
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42/media/lua/client/MoreTraits - Dynamic.lua` (lines 368–373) — legacy B42 client dynamic variant
  - `research/installed-mods/EvolvingTraitsWorld/mods/Evolving Traits World - Mark Dynamic Traits/42/media/lua/shared/NPCs/ETWSubmodCreationMethods.lua` (line 99) — external mod notes `bouncer` as a dynamic alt-name

- Source data structure: `iBouncercooldown` is stored in a per-player `playerdata` table (initialised to `0`), not in `modData`.
- Source parameters (all sandbox-configurable via `SandboxVars.MoreTraits`):
  - `BouncerEffectiveness` — stagger chance in percent; default `5`
  - `BouncerCooldown` — ticks between triggers; default `60`
  - `BouncerDistance` — proximity radius for "close" enemies; default `1.75`
- Source lucky/unlucky integration: if the player also has `ToadTraitsRegistries.lucky`, chance += `luckimpact` (default `1`); if `unlucky`, chance -= `luckimpact`.
- Source trigger path:
  - Called from the More Traits per-tick update loop (all-player update function) as `bouncerupdate(player, playerdata)`.
  - Event: called every game tick (inside a continuous OnPlayerUpdate/OnTick loop).
- Source behavior (B42.13 shared, `bouncerupdate`):
  1. If player does not have `ToadTraitsRegistries.bouncer`, return immediately.
  2. If `playerdata.iBouncercooldown > 0`, decrement by 1 and return.
  3. Read sandbox vars for `chance`, `cooldown`, `distance` (defaults: 5, 60, 1.75).
  4. Apply lucky/unlucky modifier to `chance`.
  5. Get `enemies = player:getSpottedList()`. If `size() < 3`, return.
  6. Iterate enemies: for each where `enemy:isZombie()` and `enemy:DistTo(player) <= distance`, increment `closeEnemyCount`. Once `closeEnemyCount >= 3`, if `not enemy:isKnockedDown()` and `ZombRand(0, 101) <= chance`, call `enemy:setStaggerBack(true)`, set `playerdata.iBouncercooldown = cooldown`, break.
- Source conditions on stagger: (a) spotted-list size >= 3, (b) at least 3 zombies within distance, (c) target is not already knocked down, (d) random roll passes.
- Dynamic unlock condition (More Traits - Dynamic): `lvlSmallBlunt >= BouncerDynamicSmallBlunt` and `lvlStrength >= BouncerDynamicStrength` (sandbox-configured thresholds); grants +1 XP boost to `Perks.SmallBlunt` on unlock.
- Source `DisabledInMultiplayer`: not flagged in the source script definitions reviewed; the trait is not explicitly marked MP-disabled in More Traits.

## Current UT Evidence

### Structure

- Registered in test harness: yes (`run_tests.lua` line 304, in the Phase 3c registration sweep array)
- Registered in `registries.lua`: yes (line 292)
  - `UTTraitsRegistries.UT_bouncer_I = CharacterTrait.register("UniversalTraits:UT_bouncer_I")`
  - `UTTraitsRegistries.UT_bouncer_II = CharacterTrait.register("UniversalTraits:UT_bouncer_II")` (line 293, companion tier)
- Defined in `UT_character_traits.txt`: yes (lines 2082–2092)
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_bouncer_I`
  - `Cost = 4`
  - `UIName = UI_UT_bouncer_I`
  - `UIDescription = UI_UT_bouncer_IDesc`
  - `XPBoosts = Strength=1;SmallBlunt=1`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_bouncer_II`
- Companion tier `UT_bouncer_II` defined (lines 2094–2104): `Cost = 6`, `XPBoosts = Strength=2;SmallBlunt=2`, mutually exclusive with `UT_bouncer_I`.
- Translation strings present: yes
  - `UI_UT_bouncer_I = "Bouncer"` (UI_EN.txt line 644)
  - `UI_UT_bouncer_IDesc = "Years working the door taught you how to handle yourself. Start at Strength 6 and Short Blunt level 1. When surrounded by 3 or more zombies, chance to automatically stagger one back."` (line 645)
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_bouncer_I.lua`, 47 lines)
- UT_MET.lua group membership: `UT_bouncer_I` and `UT_bouncer_II` are **not** listed in any group in `UT_MET.lua`. Their mutual exclusion is enforced only via the script `MutuallyExclusiveTraits` declarations; they have no UT_MET runtime group.

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_bouncer_I.lua` (full file, 47 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 11–16) — `UTCore.hasTrait` implementation
  - `media/scripts/UT_character_traits.txt` (lines 2082–2104)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 644–648)
  - `test/run_tests.lua` (lines 612–676)

- Event registrations:
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)` (line 46) — fires every game-engine update tick for the local player.

- Local constants:
  - `TRAIT_I  = "UniversalTraits:UT_bouncer_I"` (line 6)
  - `TRAIT_II = "UniversalTraits:UT_bouncer_II"` (line 7)

- UTCore hooks used:
  - `UTCore.hasTrait(player, TRAIT_I)` — nil-safe check via `player:getTraits():contains(traitId)` (UTCore_API.lua line 15)
  - `UTCore.hasTrait(player, TRAIT_II)` — same; the single handler serves both tiers

- Runtime chain (plain language):
  1. `onPlayerUpdate(player)` fires every tick.
  2. Guard: if `player` is nil, return.
  3. Guard: if player has neither `UT_bouncer_I` nor `UT_bouncer_II`, return.
  4. Read (or initialize) `md["UT_bouncer_cooldown"]` from `player:getModData()`. If `nil`, set to `0`.
  5. If `md["UT_bouncer_cooldown"] > 0`, decrement by 1 and return (skipping all further logic this tick).
  6. Get `spottedList = player:getSpottedList()`. If `size() < 3`, return.
  7. Iterate spotted list from index 0 to `size()-1`. For each enemy where `player:DistTo(enemy) < 1.75`, append to `closeEnemies` table.
  8. If `#closeEnemies < 3`, return.
  9. Roll `ZombRand(100)`. If result `< 5` (i.e., 5% chance):
     - Call `closeEnemies[1]:setStaggerBack(true)` — staggers the **first** close enemy only (index 1 in the Lua table, which corresponds to the first spotted enemy that was within range).
     - Set `md["UT_bouncer_cooldown"] = 60`.

- Exact numerical parameters:
  - Proximity radius: `< 1.75` tiles (strict less-than; enemy at exactly 1.75 is excluded)
  - Minimum enemy count (spotted): 3
  - Minimum enemy count (close): 3
  - Stagger chance: 5% per tick when cooldown is 0 and conditions are met
  - Cooldown length: 60 ticks
  - Stagger target: `closeEnemies[1]` only — always the first close enemy encountered in iteration order

- Cadence summary: when cooldown is 0 and all conditions hold, there is a 5% chance per tick to stagger one enemy and reset the cooldown to 60. The expected number of ticks between triggers (given all conditions continuously met) is `(1/0.05) + 60 = 80 ticks`.

## Description Integrity

- Display name check: "Bouncer" — matches source trait colloquial name.
- Description check: `UI_UT_bouncer_IDesc` reads: "Years working the door taught you how to handle yourself. Start at Strength 6 and Short Blunt level 1. When surrounded by 3 or more zombies, chance to automatically stagger one back."
- Issues found:
  1. **"Start at Strength 6 and Short Blunt level 1" is inaccurate.** The XPBoosts field is `Strength=1;SmallBlunt=1`. In PZ B42, `XPBoosts` grant **+N to the skill's XP multiplier** — they are not starting level grants. The description says "Start at Strength 6 and Short Blunt level 1", which implies the player begins at a specific absolute skill level. This is categorically wrong. The boost gives +1 XP rate multiplier to Strength and +1 to SmallBlunt; the player does not start at any specified level. The correct description phrasing should read "+1 to Strength and +1 to Short Blunt XP gains" or similar.
  2. **Only one enemy is staggered despite "stagger one back" appearing accurate.** The description says "stagger one back" and the code does stagger exactly one, so this phrase is correct. However, it is always `closeEnemies[1]` — the first close enemy by iteration order, not a random selection. This implementation detail is not a description flaw but may be a design intent question (always first vs. random).
  3. **"Surrounded by 3 or more zombies" — partially accurate.** The code checks that the spotted list has ≥ 3 entries (line 26) AND that at least 3 of those are within 1.75 tiles (lines 29–37). The description says "surrounded by 3 or more zombies" without specifying the proximity radius (1.75 tiles), so it is directionally correct but omits the explicit range gate. This is minor flavor imprecision rather than a factual error.
  4. **No mention of cooldown.** The 60-tick cooldown between triggers is a significant constraint that the description omits. Players may expect the stagger to fire on every eligible tick; the actual rate is much lower. This is not a hard error but is a material omission for informed decision-making.

## Balance Review

- Upside:
  - Passive stagger of a nearby enemy when surrounded by ≥ 3 enemies.
  - 5% chance per tick when conditions are met, up to once per 60 ticks.
  - XPBoosts: +1 Strength, +1 SmallBlunt (faster XP accumulation).
  - Combined with `UT_bouncer_II` (mutually exclusive tier) for heavier investment: +2/+2 XP boosts at Cost 6.

- Downside / cost: positive trait; costs 4 character creation points.

- Uptime analysis:
  - Requires ≥ 3 enemies in the spotted list AND ≥ 3 within 1.75 tiles simultaneously. This is a tight spatial requirement — 1.75 tiles is very close quarters. In normal PZ combat, engaging 3 enemies simultaneously within 1.75 tiles is a high-danger scenario. The trait is situationally useful but does not activate in typical single-zombie encounters.
  - When cooldown > 0 the stagger is completely suppressed. A 60-tick cooldown at ~20 ticks/second means approximately 3 seconds of suppression after each trigger.

- Divergences from source that affect balance:
  1. **No sandbox configurability.** The source exposed `BouncerEffectiveness`, `BouncerCooldown`, and `BouncerDistance` as sandbox variables. The UT implementation hardcodes all three (5%, 60 ticks, 1.75 tiles). Server operators cannot tune the trait. This is a design regression.
  2. **No lucky/unlucky integration.** The source added/subtracted `luckimpact` from the chance when those traits were present. The UT implementation ignores lucky/unlucky entirely.
  3. **No `isKnockedDown()` guard.** The source skipped already-knocked-down enemies as stagger targets. The UT implementation calls `closeEnemies[1]:setStaggerBack(true)` without checking if the target is already knocked down. This means stagger is wasted on an enemy that is already falling.
  4. **`DistTo` direction.** Source uses `enemy:DistTo(player)` (distance from enemy to player); UT uses `player:DistTo(enemy)` (distance from player to enemy). In practice both are symmetric distance calls but the source calls from the enemy's reference frame. Functionally equivalent given symmetric distance.
  5. **Single-target selection.** Source selects the enemy that crossed the count threshold (the 3rd+ zombie in iteration) while UT always picks `closeEnemies[1]` — the first-enumerated close enemy, which is not guaranteed to be the most dangerous or nearest. Minor behavioral difference.
  6. **Spotted-list check discrepancy.** UT checks `spottedList:size() < 3` then separately checks close enemies. Source checks `enemies:size() < 3` then accumulates close enemies inline. The UT two-pass approach is functionally correct but does not short-circuit on the close-enemy count mid-iteration.
  7. **`DisabledInMultiplayer = true`.** The UT version disables this trait in multiplayer. The source did not flag it as MP-restricted. This is a UT-wide policy decision; however, the trait uses `Events.OnPlayerUpdate` (which fires per local player) and `player:getModData()` — both are standard patterns used by many UT traits that are also MP-disabled, so this is consistent with UT convention.

- Cost verdict: 4 points is reasonable for a passive combat-survival trait that activates in high-danger crowd situations. The XP boosts (+1 Strength, +1 SmallBlunt) add meaningful long-term value. The tier-II variant at Cost 6 with doubled XP boosts provides a clear upgrade path. However, the missing `isKnockedDown()` guard and hardcoded parameters are correctness and flexibility gaps that reduce the real-world value relative to the source.

- Peer comparison:
  - `UT_batteringram` (if present) also triggers on proximity/collision events; these are not mutually exclusive. Their effects could stack synergistically without being excluded.
  - No mutual exclusion exists with other combat traits that also raise or affect close-combat behavior. This is consistent with source but worth noting.

## Regression Proof

- Test location: `test/run_tests.lua` lines 612–676
- Tests present:
  1. **"bouncer stagger fires when >=3 close enemies and cooldown=0"** (lines 641–658):
     - Sets up 4 enemies at distance 1.5 (all within 1.75), player has `UT_bouncer_I`, cooldown not set (nil → 0).
     - Fires `Events.OnPlayerUpdate`.
     - ZombRand is stubbed to always return 0 (so `0 < 5` is always true).
     - Asserts that at least one enemy has `_staggerBack = true`.
     - Asserts `player:getModData()["UT_bouncer_cooldown"] == 60`.
     - **Proves**: stagger fires, cooldown is set to 60.
  2. **"bouncer stagger does NOT fire during cooldown"** (lines 660–676):
     - Same 4-enemy setup. Player has `UT_bouncer_I`. Cooldown pre-set to `30`.
     - Fires `Events.OnPlayerUpdate`.
     - Asserts no enemy has `_staggerBack = true`.
     - Asserts `player:getModData()["UT_bouncer_cooldown"] == 29`.
     - **Proves**: stagger is suppressed during cooldown, cooldown decrements correctly.

- What the tests prove:
  - The happy-path trigger (conditions met, cooldown 0, stagger fires).
  - Cooldown initialization from nil to 0 (implicit in test 1).
  - Cooldown suppression and decrement (test 2).

- Missing proof:
  1. No test for `#closeEnemies < 3` suppression (spotted list has ≥ 3 but close enemies count < 3 — e.g., enemies at distance 2.0 are not close).
  2. No test for spotted-list `size() < 3` early-exit (fewer than 3 enemies visible total).
  3. No test that `UT_bouncer_II` activates the same handler (the single file handles both via `TRAIT_I or TRAIT_II`; no test passes `UT_bouncer_II` as the active trait).
  4. No test for the `ZombRand` failure path — ZombRand returning ≥ 5 should not stagger and should not set cooldown. The stub always returns 0, so the 95% non-trigger case is untested.
  5. No test for the nil-player guard (`player == nil` early return on line 10).
  6. No test that a player with neither trait is a no-op (though this is standard guard coverage common to all traits).
  7. No test that `closeEnemies[1]:setStaggerBack(true)` specifically targets element 1 (the first in-range enemy), verifying the selection order.

- Minimum next test if needed: "bouncer: no stagger when all enemies are too far" — mock 4 enemies at distance 2.0 (outside 1.75 radius), fire `OnPlayerUpdate`, assert no stagger and cooldown remains 0.

## Final Verdict

- Source origin: proven — More Traits `bouncer` (ToadTraitsRegistries.bouncer) is the confirmed source; `bouncerupdate` function located and read in full at `MoreTraits .lua` lines 1890–1931.
- UT implementation: drifted — the core concept (passive stagger when surrounded by 3+ close enemies, with cooldown) is faithfully reproduced, but with multiple divergences:
  1. **Hardcoded parameters** — source exposed chance, cooldown, and distance as sandbox variables; UT hardcodes all three (5%, 60, 1.75). Server operators lose configurability.
  2. **Missing `isKnockedDown()` guard** — source skipped enemies already knocked down; UT does not, meaning the stagger roll can be wasted on a falling zombie.
  3. **Missing lucky/unlucky integration** — source adjusted chance based on the player's luck traits; UT ignores this entirely.
  4. **Target selection** — source staggers the enemy that crossed the 3-count threshold (the 3rd+ close zombie in iteration); UT always staggers `closeEnemies[1]` (first close zombie enumerated), regardless of iteration position.
  5. **`DisabledInMultiplayer = true`** — source was not MP-restricted; UT applies its standard MP-disable policy.
- Description: contains one factual error and one material omission:
  1. **Error**: "Start at Strength 6 and Short Blunt level 1" misrepresents `XPBoosts`. XPBoosts grant additional XP multiplier bonuses, not starting levels. This must be corrected.
  2. **Omission**: the 60-tick cooldown is not mentioned. Players cannot assess the effective stagger frequency without this information.
- Balance: cost-4 with +1/+1 XP boosts is reasonable for a situational passive combat ability. The trait pair (I at 4, II at 6) provides a sensible investment scale. The missing `isKnockedDown()` guard is a minor correctness defect that wastes triggers. The removed sandbox configurability is a design regression relative to source.
- Regression proof: two behavioral tests exist and cover the primary trigger and cooldown-suppression paths. Key gaps: close-enemy-too-far suppression, TRAIT_II activation, random failure path, nil-player guard.
- Action needed:
  1. **Fix description** — replace "Start at Strength 6 and Short Blunt level 1" with correct XPBoost language (e.g., "+1 to Strength and +1 to Short Blunt XP gains").
  2. **Add `isKnockedDown()` guard** — before calling `setStaggerBack`, check `if not closeEnemies[1]:isKnockedDown() then` to avoid wasting the stagger roll and cooldown on an already-falling zombie.
  3. **Consider adding cooldown mention to description** — "…has a short cooldown between triggers" or similar would inform player choice.
  4. **Optional: consider sandbox-configurable parameters** — restoring `BouncerEffectiveness`, `BouncerCooldown`, and `BouncerDistance` as sandbox options would bring UT closer to source parity and give server operators control.
  5. **Add missing tests**: close-enemy-too-far suppression, TRAIT_II activation path, ZombRand ≥ 5 non-trigger path.
- Open gaps:
  - No `UT_MET.lua` group for the bouncer pair. This is correct — their mutual exclusion is enforced by the `.txt` definition and they are not in an architectural conflict with any other UT group. No UT_MET entry is needed.
  - `UT_bouncer_II`'s runtime behavior is identical to `UT_bouncer_I` (same handler, same parameters) — the only difference between the two tiers is the script cost and XPBoosts. Whether the tier-II should have a stronger stagger (e.g., lower cooldown, higher chance, or larger radius) is an open design question not addressed by the current implementation.
