# UT_actionhero

## Trait Summary

- UT trait id: UT_actionhero
- Source mod: MoreTraits (hypnotoadtrance)
- Source trait id: ToadTraits:actionhero (trait key: "actionhero")
- Current cost: 8
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua` (line 62) — registry registration
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (line 194) — trait factory registration, cost = 8
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (lines 2325–2395) — full B42.15 runtime logic
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (lines 110–111) — source display name and description
- Source cost: 8 — matches UT cost exactly.
- Source description (EN): "You live for the thick of the fight. You deal only half as much normal damage, but you deal extra damage and have more critical chance the more enemies there are around you. Your damage and critical chance scale based on number and distance of zombies around you."
- Source trigger path: `Events.OnWeaponHitCharacter.Add(actionhero)` — fires on every weapon hit against a character.
- Source behavior (B42.15):
  1. Guards: exits if `weapon` or `actor` is nil. Exits if player does not have `ToadTraits:actionhero`. Exits if weapon is `BareHands` and player does not have `ToadTraits:martial`.
  2. Initialises `critchance = 10`, `multiplier = 0.1`, and computes a local `damage = damage * 0.5` (the incoming damage is halved before any bonus is added — this is the core downside).
  3. Iterates `player:getSpottedList()`. For each enemy that `isZombie()`, measures `distance = enemy:DistTo(player)`. Adds per-zombie bonuses: `dist < 2` → `critchance + 10`, `multiplier + 1.0`; `dist < 5` → `critchance + 5`, `multiplier + 0.4`; `dist < 10` → `critchance + 2`, `multiplier + 0.2`.
  4. Applies Lucky/Unlucky modifiers: `+5 * luckimpact` critchance for Lucky, `−5 * luckimpact` for Unlucky.
  5. Crit roll: `ZombRand(0, 101) <= critchance AND target:isZombie() AND NOT player:hasTrait(ToadTraits:mundane)`. If crit fires, multiplies `damage` by 5.
  6. Applies extra damage: `extraDamage = (damage * multiplier) * 0.1`. Calls `target:setHealth(target:getHealth() - extraDamage)`.
  7. Kill handling: if `target:getHealth() <= 0` and `targetData.TraitKillProcessed` is not set, calls `target:Kill(player)` and increments `player:getZombieKills()`.
- Source mutual exclusions: none observed in source script files.
- Source `DisabledInMultiplayer`: not present in the source trait registration via `TraitFactory.addTrait`; source uses the legacy client-side registration path and does not set this flag.

## Current UT Evidence

### Structure

- Registered in test harness: yes (`run_tests.lua` line 194, grouped in "Combat Melee (8)")
- Registered in `media/registries.lua`: yes (line 42)
  - `UTTraitsRegistries.UT_actionhero = CharacterTrait.register("UniversalTraits:UT_actionhero")`
  - Section: `PHASE 1 -- XP BOOST: COMBAT (MELEE)` — no XPBoosts are declared for this trait in `registries.lua`; the section header is inherited from the surrounding block but does not apply to UT_actionhero specifically.
- Defined in `UT_character_traits.txt`: yes (lines 272–280)
  - `Cost = 8`
  - `DisabledInMultiplayer = true`
  - `IsProfessionTrait = false`
  - No `XPBoosts` field declared
  - No `MutuallyExclusiveTraits` declared
- Translation strings present: yes (`media/lua/shared/Translate/EN/UI_EN.txt` lines 83–84)
  - `UI_UT_actionhero = "Action Hero"`
  - `UI_UT_actionheroDesc = "You fight like the hero of your own action movie. Nearby zombies boost your damage: within 2 tiles (+10% crit, ×1.0 damage), within 5 tiles (+5% crit, ×0.4), within 10 tiles (+2% crit, ×0.2). Bonuses stack per zombie. Disabled by Mundane."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_actionhero.lua`, 45 lines)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_actionhero.lua` (full file, 45 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 11–16) — `UTCore.hasTrait` implementation
  - `media/scripts/UT_character_traits.txt` (lines 272–280)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 83–84)
  - `media/registries.lua` (line 42)
  - `test/run_tests.lua` (lines 544–610)
- Event registrations:
  - `Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)` (line 45)
- UTCore hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — primary trait gate (line 10)
  - `UTCore.hasTrait(player, "UniversalTraits:UT_martial")` — bare-hands guard (line 14)
  - `UTCore.hasTrait(player, "UniversalTraits:UT_mundane")` — crit-suppression guard (line 18)
- `UTCore.hasTrait` implementation: calls `player:getTraits():contains(traitId)` — nil-safe, returns false if player or traits list is absent.
- Runtime chain (plain language):
  1. On every weapon hit against a character: receives `(player, weapon, target)`.
  2. If `player` is nil, exits immediately.
  3. Calls `UTCore.hasTrait(player, "UniversalTraits:UT_actionhero")`. If the player does not have the trait, exits.
  4. If `weapon:getType() == "BareHands"`: calls `UTCore.hasTrait(player, "UniversalTraits:UT_martial")`. If player does not also have UT_martial, exits.
  5. Calls `UTCore.hasTrait(player, "UniversalTraits:UT_mundane")`. If player has UT_mundane, exits (crits disabled globally).
  6. Retrieves `player:getSpottedList()`. Initialises `critchance = 10`, `multiplier = 0.1`.
  7. Iterates `i = 0` to `spottedList:size() - 1`. For each entry, calls `player:DistTo(enemy)`. Applies tier bonuses:
     - `dist <= 2`: `critchance + 10`, `multiplier + 1.0`
     - `dist <= 5`: `critchance + 5`, `multiplier + 0.4`
     - `dist <= 10`: `critchance + 2`, `multiplier + 0.2`
  8. Crit roll: `ZombRand(100) < critchance`. If true: computes `extraDamage = 5 * multiplier * 0.1`. Calls `target:setHealth(target:getHealth() - extraDamage)`.
- Actual behavior (exact values):
  - Base crit chance before any enemies: 10 (out of 100, i.e. 10%).
  - Base multiplier before any enemies: 0.1.
  - Per-enemy bonus at dist <= 2: +10 critchance, +1.0 multiplier.
  - Per-enemy bonus at dist <= 5 (and > 2): +5 critchance, +0.4 multiplier.
  - Per-enemy bonus at dist <= 10 (and > 5): +2 critchance, +0.2 multiplier.
  - Enemies beyond dist 10: no contribution.
  - Example — 5 enemies all at dist 1: `critchance = 10 + 5*10 = 60`, `multiplier = 0.1 + 5*1.0 = 5.1`. ExtraDamage = `5 * 5.1 * 0.1 = 2.55` HP removed from target on a crit (60% chance). On a non-crit, no damage is applied at all.
  - Example — 1 enemy at dist 3: `critchance = 15`, `multiplier = 0.5`. ExtraDamage on crit = `5 * 0.5 * 0.1 = 0.25` HP.
  - Example — 1 enemy at dist 8: `critchance = 12`, `multiplier = 0.3`. ExtraDamage on crit = `5 * 0.3 * 0.1 = 0.15` HP.
  - Maximum theoretical (very large horde at dist <= 2, N enemies): `critchance = 10 + N*10` (uncapped), `multiplier = 0.1 + N*1.0`. ExtraDamage = `5 * (0.1 + N) * 0.1 = 0.5*N + 0.05`. At N=10: critchance 110 (effectively 100%), extraDamage = 5.05 HP.
  - No kill tracking, no Lucky/Unlucky modifier, no `target:isZombie()` guard — the UT implementation fires against any target, not only zombies.
  - ZombRand call: `ZombRand(100)` returns an integer in `[0, 99]`. Crit fires when `result < critchance`. At critchance=10 that is 10/100 = 10%. At critchance=60 it is 60/100 = 60%.

## Description Integrity

- Display name check: "Action Hero" — matches source.
- Description check: `UI_UT_actionheroDesc` reads: "You fight like the hero of your own action movie. Nearby zombies boost your damage: within 2 tiles (+10% crit, ×1.0 damage), within 5 tiles (+5% crit, ×0.4), within 10 tiles (+2% crit, ×0.2). Bonuses stack per zombie. Disabled by Mundane."
- Assessment: the description accurately represents the UT runtime — the three distance tiers, the per-zombie stacking, and the UT_mundane suppression are all correctly stated. The description calls the distance unit "tiles", which corresponds to the game's coordinate unit used in `DistTo`.
- Issues found:
  1. **The description omits the base crit chance.** The description implies damage bonuses only come from nearby zombies, but there is always a baseline 10% crit chance even with zero spotted enemies. A player with no zombies nearby still has a 10% chance to apply extra damage on every hit. The description's phrasing "Nearby zombies boost your damage" implies the effect is zero with no nearby zombies, which is incorrect.
  2. **The extra-damage formula is not intuitive from the description.** The ×1.0 and ×0.4 values listed are multiplier increments fed into `5 * multiplier * 0.1`. The actual extra HP removed per crit is `0.5 * sum_of_multiplier_additions + 0.05`. Players reading "×1.0 damage" will not be able to infer the absolute HP number without knowing the `5 * ... * 0.1` formula. The description accurately lists the multiplier increments, but their meaning is opaque without the base formula being disclosed.
  3. **No disclosure that the effect fires against any target, not only zombies.** The source checked `target:isZombie()` before applying extra damage. The UT implementation does not. The extra damage can therefore fire against friendly NPCs, other players, or animals if such targets can be hit with a weapon. The description says "Nearby zombies boost your damage" — the word "zombies" implies only zombies are affected, but the crit and damage application has no such filter.
  4. **The source's half-damage penalty is absent.** The source implementation computed `damage = damage * 0.5` at the start of the function — the trait imposed a permanent 50% damage reduction on the incoming hit as the cost of the crit bonus. The UT implementation removes this downside entirely: it applies only the bonus extra damage, with no penalty to the weapon's base damage. The source description ("You deal only half as much normal damage") matches the source code. The UT description omits this penalty — correctly, because the UT implementation genuinely does not apply it — but the omission radically changes the balance of the trait from a risk/reward trade-off to a pure upside.

## Balance Review

- Upside: on every weapon hit, if the crit roll passes, applies `extraDamage = 5 * multiplier * 0.1` HP reduction directly to the target. Crit chance and multiplier scale with the number and proximity of spotted enemies.
- Downside: none implemented in UT. The source's 50% base damage penalty was removed.
- Cadence: fires on `Events.OnWeaponHitCharacter` — every time a weapon successfully connects with a character. In melee combat, this can be several times per second in a horde.
- Magnitude at common scenarios:
  - Solo fight (0 nearby spotted): 10% chance, extraDamage = 0.05 HP per crit. Negligible.
  - 3 enemies at dist <= 2: critchance = 40%, multiplier = 3.1, extraDamage = 1.55 HP per crit.
  - 5 enemies at dist <= 2: critchance = 60%, multiplier = 5.1, extraDamage = 2.55 HP per crit.
  - 10 enemies at dist <= 2: critchance = 110% (capped at 100%), multiplier = 10.1, extraDamage = 5.05 HP per crit.
  - Mixed horde (3 at dist 1, 5 at dist 4, 4 at dist 8): critchance = 10 + 30 + 25 + 8 = 73%, multiplier = 0.1 + 3.0 + 2.0 + 0.8 = 5.9, extraDamage = 2.95 HP per crit.
- Context: standard zombie HP in B42 is roughly 100 HP. At 5 nearby enemies, each crit subtracts approximately 2.55 HP. The trait does not kill zombies outright but meaningfully accelerates killing in hordes.
- Source cost comparison: source cost is 8 (positive trait, player pays 8 points). UT cost is 8 — identical. However the UT version is strictly stronger than the source version because it removes the 50% base damage penalty while retaining the full crit bonus system. The source was a balanced trade-off (bonus at the cost of halved base damage). The UT version is a pure bonus at the same cost as the original risk/reward version. This is an overvalue at 8 points.
- No-enemy baseline: the base 10% crit chance provides a minor passive bonus even without enemies nearby. This is active in every fight, making the trait non-zero even in solo kills.
- Interaction with UT_martial: required to use bare-hands with UT_actionhero. No other declared interactions with other traits (no MutuallyExclusiveTraits, no declared synergies).
- UT_mundane interaction: correctly suppresses UT_actionhero entirely via the runtime guard. No script-level mutual exclusion is declared; the suppression is purely runtime. If the player has both traits, UT_mundane wins (UT_actionhero's handler returns early at line 18). This is silent — no UI indication that one trait disables the other at the character creation screen.
- Non-zombie target issue: extraDamage applies to any `target` — NPCs, players, animals. In single-player this is unlikely to matter in practice, but it is a correctness gap.
- Cost verdict: 8 is too low given the source's downside has been removed. The source balanced 8 points against a 50% base damage penalty. Without that penalty, the trait is a pure crit bonus that scales aggressively in hordes. A cost of 10–12 would be more appropriate, or the 50% base damage penalty should be restored to preserve the source's design intent.

## Regression Proof

- Test 1: `"actionhero deals bonus damage when surrounded (5 enemies within 2 tiles)"` (`run_tests.lua` lines 582–595)
  - Setup: 5 spotted enemies all at dist=1. Player has `UniversalTraits:UT_actionhero`. Weapon type = "Axe". Target health = 100.
  - Action: fires `Events.OnWeaponHitCharacter`.
  - Assert: `target:getHealth() < 100` — health has decreased, meaning the crit branch executed and extraDamage was subtracted.
  - Coverage: proves the happy-path crit fires and damages the target in a 5-enemy horde scenario.
  - Limitation: the assert is `< 100` not a precise value. The crit is probabilistic (`ZombRand(100) < 60`); the test will fail if the random roll does not crit. The test mock's `ZombRand` behavior determines whether this is deterministic. If the test harness seeds or overrides `ZombRand`, the test is reliable; if not, it is flaky at 40% failure rate with N=5 enemies.
- Test 2: `"actionhero skipped when player has UT_mundane"` (`run_tests.lua` lines 597–610)
  - Setup: 5 spotted enemies at dist=1. Player has both `UT_actionhero` and `UT_mundane`. Weapon = "Axe". Target health = 100.
  - Action: fires `Events.OnWeaponHitCharacter`.
  - Assert: `target:getHealth() == 100` — health is unchanged.
  - Coverage: proves the UT_mundane guard correctly suppresses the entire handler.
- Registration sweep: `run_tests.lua` line 194 — `"UniversalTraits:UT_actionhero"` is in the full trait-ID list used for the global registration check.
- Missing proof:
  1. No test that the bare-hands guard works correctly (weapon type "BareHands" without UT_martial must produce no damage; with UT_martial it must proceed).
  2. No test that zero spotted enemies still produces the 10% base crit chance (i.e., the base-10 critchance is exercised without any nearby enemies).
  3. No test that enemies beyond dist 10 contribute nothing.
  4. No test that the mid-range tiers (dist <= 5 but > 2, dist <= 10 but > 5) produce the correct increments.
  5. No test that the handler exits cleanly when `player` is nil.
  6. No test that the handler exits when the player does not have the trait.
  7. No test for the precise extraDamage value — only that health is "less than 100", not that it equals `100 - (5 * multiplier * 0.1)`.
  8. No test that the effect fires against a non-zombie target (the `target:isZombie()` omission is untested).
- Flakiness risk: Test 1 is probabilistic. With 5 enemies at dist=1 the crit chance is 60%. A single `ZombRand` call at 60% will fail 40% of the time if not controlled. The harness should mock or seed `ZombRand` to make this test deterministic.

## Final Verdict

- Source origin: proven — MoreTraits `actionhero` is the confirmed source; all source files located and read. Source cost (8) matches UT cost (8).
- UT implementation: simplified and made strictly more powerful — the core concept (crit bonus scaling with nearby enemy count and distance) is preserved and the three distance tiers and per-zombie stacking are faithfully reproduced. However:
  1. **Source downside removed.** The source computed `damage = damage * 0.5` before applying any bonus, halving the weapon's base contribution for that hit. The UT implementation does not apply this penalty. The trait went from a risk/reward design to a pure bonus.
  2. **Lucky/Unlucky modifier removed.** The source adjusted critchance by `±5 * luckimpact` when the player had the Lucky or Unlucky trait. The UT implementation ignores these traits. This is a simplification, not a bug, but it removes a cross-trait interaction that existed in the source.
  3. **`target:isZombie()` guard removed.** The source only applied the kill-crit branch when `target:isZombie()`. The UT implementation applies extraDamage to any target. This is a correctness gap for non-zombie combat.
  4. **Kill-tracking removed.** The source manually called `target:Kill(player)` and incremented `player:getZombieKills()` when extraDamage drove health to zero. The UT implementation does not do this; if extraDamage kills the target, the kill is not attributed. This may result in missed kill-count updates when the bonus damage is the deciding blow.
  5. **Distance comparison differs.** The source used strict `< 2`, `< 5`, `< 10`. The UT uses `<= 2`, `<= 5`, `<= 10`. An enemy at exactly dist=2 falls in the top tier in UT but the mid tier in source. This is a minor boundary-condition drift.
  6. **Multiplayer disabled.** The source used the `TraitFactory` path and did not set `DisabledInMultiplayer`. UT sets `DisabledInMultiplayer = true`. This is consistent with UT-wide policy but removes multiplayer availability.
- Description: accurate for what UT implements, with one factual gap (the always-active 10% base crit chance is not disclosed) and one misleading implication (the effect is not limited to zombie targets despite the description using the word "zombies"). The source's "you deal only half as much normal damage" downside is absent — correctly so, since UT does not implement it, but its absence makes the UT trait mechanically superior while players familiar with MoreTraits will not expect the change.
- Balance: the trait is undercosted at 8 given the removal of the 50% base damage penalty. In source that penalty was the trade-off that justified the cost. Without it, the trait is a passive crit bonus that scales aggressively in hordes with no offsetting downside. Cost should be raised (10–12), or the base-damage halving should be restored.
- Regression proof: two behavioral tests exist. Test 1 is potentially flaky due to uncontrolled probabilistic crit roll. Test 2 (mundane suppression) is fully deterministic and sound. Multiple guard conditions and precision scenarios are untested.
- Action needed:
  1. **Decide on the base damage penalty.** Either restore `damage = damage * 0.5` (matching source intent and justifying cost = 8) or raise the cost to 10–12 to reflect the pure-upside rebalance. Document the decision.
  2. **Add `target:isZombie()` guard** if the trait is intended to affect only zombies (matching source). If non-zombie targets are acceptable, update the description to remove the word "zombies" from "Nearby zombies boost your damage" or add explicit wording about all targets.
  3. **Restore kill attribution** (`target:Kill(player)` + kill counter increment) if the design intends bonus-damage kills to count toward the player's zombie kill score.
  4. **Fix or document the base crit chance.** Add "Base 10% crit chance with no enemies nearby" to the description, or remove the base `critchance = 10` and start at 0 so the no-enemies state truly has no effect.
  5. **Make Test 1 deterministic.** Mock or seed `ZombRand` in the test harness so the 60% crit roll is guaranteed to fire. Alternatively, use enough enemies to push critchance to 110 (11+ enemies at dist <= 2) ensuring a guaranteed crit regardless of the random result.
  6. **Add tests for:** bare-hands guard (with and without UT_martial), distance tier boundaries, no-enemy base crit behavior, precise extraDamage value assertion, nil-player guard, and the non-trait-holder early exit.
- Open gaps:
  - The `luckimpact` variable value in the source is not available in the reviewed files; the magnitude of the Lucky/Unlucky interaction that was removed cannot be quantified without it.
  - The distance boundary drift (`<` vs `<=`) at exactly dist=2, 5, and 10 has no test and may produce subtly different behavior from player expectations if MoreTraits documentation was used as a reference.
  - No MET group is assigned; stacking with other crit-granting or damage-boosting combat traits is unrestricted.
