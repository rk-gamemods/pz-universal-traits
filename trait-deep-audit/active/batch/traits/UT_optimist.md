# UT_optimist

## Trait Summary
- UT trait id: UT_optimist
- Source mod: FillerTraits (`Optimist`) — one source analogue identified; MoreSimpleTraits `MSTOptimist` is a distinct trait with its own UT wrapper (`UT_mstoptimist`)
- Source trait id: `Optimist` (FillerTraits, no namespace prefix)
- Current cost: 2
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/client/UpgradeTraits.lua` (runtime implementation — `Optimist`, lines 265–273, 324)
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/shared/NPCs/UpgradeMainCreationMethods.lua` (trait registration and mutual exclusion — lines 9, 51)

- Source registration:
  - FillerTraits: `TraitFactory.addTrait("Optimist", ...)` called in `UpgradeMainCreationMethods.lua` line 9
  - FillerTraits: `player:HasTrait("Optimist")` checked inline in `Optimist()` in `UpgradeTraits.lua` line 271

- Source trigger path:
  - FillerTraits: `Events.OnPlayerUpdate.Add(Optimist)` — runs every player update tick (per-frame, not periodic)

- Source behavior (FillerTraits — `Optimist`, lines 265–273):
  - If the player has `Optimist`:
    - `player:getBodyDamage():setUnhappynessLevel(0)` — clamps unhappiness to exactly 0 every player update tick
  - Effect is purely `UnhappynessLevel`-based; completely suppresses unhappiness rather than reducing it gradually
  - No stress or panic manipulation

- Source display name: `getText("Optimist")` — rendered as `"Optimist"` (line 9)
- Source description: `getText("Things could be worse... \n Cannot become sad.")` — "Things could be worse... / Cannot become sad." (line 9)
- Source cost: `7` points (FillerTraits, `UpgradeMainCreationMethods.lua` line 9)
- Source exclusions:
  - FillerTraits: `TraitFactory.setMutualExclusive("Optimist", "Pessimist")` (line 51) — bidirectional with Pessimist only

- Note on MoreSimpleTraits `MSTOptimist`: this source exists in the research corpus (`MSTMainFile.lua`) and operates on unhappiness suppression (caps `UnhappynessLevel` at 49 if the player has been in depression under 48 hours) and boredom reduction. UT wraps this source separately as `UT_mstoptimist`. It is **not** the source for `UT_optimist`.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_optimist = CharacterTrait.register("UniversalTraits:UT_optimist")` at line 252, under the `-- PHASE 3b -- PERIODIC-CHECK TRAITS` block
- Defined in UT_character_traits.txt: yes — lines 1710–1719
  - `Cost = 2`
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_pessimist;UniversalTraits:UT_depressive;UniversalTraits:UT_melancholic`
- Translation strings present: yes
  - `UI_UT_optimist = "Optimist"` (line 533)
  - `UI_UT_optimistDesc = "You genuinely believe things will work out. Every 10 in-game minutes, stress decreases by −0.06 and panic decreases by −0.04."` (line 534)
- Exclusions verified:
  - `UT_pessimist` (lines 1721–1730) lists `UniversalTraits:UT_optimist` in its `MutuallyExclusiveTraits` — bidirectional confirmed
  - `UT_depressive` (lines 1648–1657) lists `UniversalTraits:UT_optimist` in its `MutuallyExclusiveTraits` — bidirectional confirmed
  - `UT_melancholic` (lines 1679–1688) lists `UniversalTraits:UT_optimist` in its `MutuallyExclusiveTraits` — bidirectional confirmed
  - `UT_mstoptimist` is **not** listed in `UT_optimist`'s exclusion block — a player could hold both `UT_optimist` and `UT_mstoptimist` simultaneously
- Runtime Lua file exists: yes — `UT_optimist.lua`

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_optimist.lua` (full file, 15 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1710–1719)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 533–534)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (full — `UTCore.hasTrait` definition)
- Event registrations: `Events.EveryTenMinutes.Add(handler)` — raw event registration, not via `UTCore.registerPeriodicHandler`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`
- Runtime chain (plain language):
  1. `handler` fires every 10 in-game minutes via `Events.EveryTenMinutes`.
  2. `getPlayer()` is called; if nil, the function returns early.
  3. `UTCore.hasTrait(player, TRAIT_ID)` resolves to `player:getTraits():contains("UniversalTraits:UT_optimist")`; if the player does not hold the trait, the function returns early.
  4. `player:getStats()` is called; the `stats` object is stored locally.
  5. Stress is set to `math.max(0, stats:getStress() - 0.06)` — stress decreases by exactly 0.06 per tick, floored at 0.
  6. Panic is set to `math.max(0, stats:getPanic() - 0.04)` — panic decreases by exactly 0.04 per tick, floored at 0.
  7. No sleep check — the handler fires regardless of whether the player is asleep.
  8. No randomness — both decrements are flat and deterministic every tick.
  9. No unhappiness (`UnhappynessLevel`) manipulation of any kind.
- Actual behavior (exact values): Every 10 in-game minutes, stress decreases by −0.06 (floor 0) and panic decreases by −0.04 (floor 0). Starting from a full stress value of 1.0, the trait alone drains stress to zero in approximately 17 ticks (~2 hours 50 minutes of in-game time). Starting from full panic of 1.0, panic drains to zero in 25 ticks (~4 hours 10 minutes of in-game time). Both drains are unconditional and fire during sleep.

## Description Integrity
- Display name check: `"Optimist"` — matches the FillerTraits source name exactly. No issue.
- Description check: `"You genuinely believe things will work out. Every 10 in-game minutes, stress decreases by −0.06 and panic decreases by −0.04."`
- Accuracy issues found:
  1. **Stress decrement value accurate** — the description claims −0.06 per 10 minutes; the Lua confirms `math.max(0, stats:getStress() - 0.06)`. Exact match.
  2. **Panic decrement value accurate** — the description claims −0.04 per 10 minutes; the Lua confirms `math.max(0, stats:getPanic() - 0.04)`. Exact match.
  3. **Floor not disclosed** — both decrements are floored at 0 (cannot go negative). The description does not mention this, but it is standard behavior for all stats and is not misleading.
  4. **No sleep exemption disclosed** — the handler fires unconditionally, including during sleep. The description does not claim a sleep exemption, so this is correct silence — no issue.
  5. **Stat divergence from source** — the FillerTraits source clamps `UnhappynessLevel` to 0 on every player update tick (effectively suppressing all sadness). The UT implementation does not touch `UnhappynessLevel` at all; it reduces `Stress` and `Panic` instead. The description makes no reference to unhappiness suppression and accurately describes the UT behavior — but the mechanical divergence from source is substantial and undisclosed.
  6. **Frequency divergence from source** — FillerTraits fires `OnPlayerUpdate` (every game tick, effectively continuous). UT fires `EveryTenMinutes`. The description correctly states the UT cadence; the source cadence is not referenced. This is correct but the behavioral difference (continuous lock vs. periodic nudge) is large.
- Overall description verdict: the description is mechanically accurate against the actual Lua — both stated values and the stated stat names match exactly. No false claims. The divergence from source behavior (stat type, cadence, and effect magnitude) is not mentioned, which is appropriate given the UT is a deliberate rewrite.

## Balance Review
- Upside (two simultaneous effects):
  - Stress drain: −0.06 per 10 minutes. From full stress (1.0), clears in ~17 ticks (~170 in-game minutes). From mid-stress (0.5), clears in ~9 ticks (~90 minutes).
  - Panic drain: −0.04 per 10 minutes. From full panic (1.0), clears in 25 ticks (~250 in-game minutes). From mid-panic (0.5), clears in 13 ticks (~130 minutes).
  - Combined, this makes the player significantly more resilient to combat and horror stress accumulation.
- Downside: none — this is a purely positive trait
- Uptime: 100% — fires unconditionally every 10 minutes including during sleep, looting, and all other activities
- Cost: 2 points (UT)
- Source cost: 7 points (FillerTraits `Optimist`) — UT cost is substantially lower, but the UT effect is also substantially weaker (periodic drain vs. unconditional suppression)
- Peer comparison:
  - `UT_pessimist` (cost −2): +0.05 stress every 10 minutes — stress increase at slightly lower magnitude than UT_optimist's stress decrease. Pessimist is priced symmetrically at −2; optimist at +2. Mirror pricing is self-consistent.
  - `UT_melancholic` (cost −3): +0.05 stress every 10 minutes — same magnitude as pessimist, priced at −3. Melancholic's extra −1 cost relative to pessimist is unexplained if the Lua behavior is identical (both raise stress by 0.05); one point of difference may reflect flavor or future-proofing.
  - `UT_depressive` (cost −4): +0.08 stress every 10 minutes — stronger stress debuff priced at −4. Depressive at −4 vs. optimist at +2 reflects an asymmetry: the negative mood traits cost more in absolute terms than optimist grants, even though optimist provides two stat drains. This may be intentional (stress is more punishing than panic in vanilla) or may warrant re-examination.
  - `UT_paranoia` (cost −4): +0.06 panic every 10 minutes. Optimist's panic drain (−0.04 per tick) is directionally opposite but smaller in magnitude than paranoia's gain. A player cannot hold both (due to mutual exclusion via the optimist-depressive-melancholic chain? — no, paranoia is not in UT_optimist's exclusion list).
- Mutual exclusion gaps:
  - `UT_paranoia` is not excluded by `UT_optimist`. Paranoia adds +0.06 panic every 10 minutes; optimist removes −0.04 panic every 10 minutes. Combined net: +0.02 panic per tick. A player can hold both, and the optimist partially offsets paranoia. This may be intentional.
  - `UT_mstoptimist` is not excluded by `UT_optimist`. Both are positive mood traits reducing stress-adjacent stats. Stacking them may be stronger than intended: UT_mstoptimist also provides stress reduction (under specific conditions), compounding the optimist's unconditional drain.
- Cost verdict: 2 points is plausible given the dual drain effect. The FillerTraits source was 7 points but had a far stronger mechanic (complete unhappiness suppression on every tick). At the UT scale, +2 for guaranteed periodic dual-drain with no downside seems slightly low compared to the −2 to −4 range for single-stat periodic debuffs of equal or smaller magnitude, but is defensible.

## Regression Proof
- Existing tests:
  - `run_tests.lua` line 285: `"UniversalTraits:UT_optimist"` appears in the `expected_ids` table (Phase 3b — Periodic-Check group). Proves the trait is enumerable in the full 198-count registration test.
  - `run_tests.lua` lines 324–339: the "script costs match the current balance decisions" test reads `UT_character_traits.txt` and asserts costs for specific traits — `UT_optimist` is not among the explicitly asserted traits, so cost 2 is not regression-protected.
  - `run_tests.lua` lines 347–403: the "script trait definitions resolve cleanly" test verifies that every `CharacterTrait` value in the script matches a registered ID and that all `MutuallyExclusiveTraits` entries resolve to registered IDs. This confirms that `UT_pessimist`, `UT_depressive`, and `UT_melancholic` are valid exclusion targets. The test is structural only.
- What the tests prove: The trait is registered and discoverable. All three mutual exclusion targets are valid registered IDs. No behavioral runtime logic is proven.
- Missing proof:
  - No test verifies that `handler` decreases stress by exactly 0.06 per call.
  - No test verifies that `handler` decreases panic by exactly 0.04 per call.
  - No test verifies the `math.max(0, ...)` floor — i.e., that stress and panic do not go negative.
  - No test verifies that the handler exits early when the player does not have the trait (trait-check guard).
  - No test verifies that the handler exits early when `getPlayer()` returns nil (nil-guard).
  - No test verifies that the handler fires on `EveryTenMinutes` and not on a different event.
  - No test verifies the cost of `UT_optimist` (currently 2) in `UT_character_traits.txt`.
- Minimum next test if needed: Mock `player:getStats()` returning a stats object with `getStress() == 0.05` and `getPanic() == 0.03`. Invoke `handler` with the player holding `"UniversalTraits:UT_optimist"`. Assert `setStress` is called with `0.0` (floored from −0.01) and `setPanic` is called with `0.0` (floored from −0.01). Then repeat with `getStress() == 0.5` and `getPanic() == 0.5` and assert `setStress(0.44)` and `setPanic(0.46)`.

## Final Verdict
- Source origin: FillerTraits `Optimist` confirmed as source analogue (continuous `OnPlayerUpdate` unhappiness suppression, cost 7, mutual exclusion with Pessimist only). MoreSimpleTraits `MSTOptimist` is explicitly a separate trait covered by `UT_mstoptimist` and is not the source for this trait.
- UT implementation: simplified and stat-substituted — the FillerTraits source clamps `UnhappynessLevel` to 0 on every player update tick. The UT version instead applies a periodic drain of stress (−0.06) and panic (−0.04) every 10 in-game minutes via `Events.EveryTenMinutes`. No unhappiness manipulation. No sleep exemption (source had none either, since `OnPlayerUpdate` fires regardless). The UT version is meaningfully weaker than the source (periodic vs. continuous; drain vs. suppression; two different stats vs. unhappiness).
- Description: mechanically accurate for the UT implementation — both stated values (−0.06 stress, −0.04 panic) and the stated cadence (every 10 in-game minutes) match the Lua exactly. No false claims. The stat substitution from source (unhappiness → stress+panic) is not disclosed, which is appropriate for a deliberate rewrite.
- Balance: cost of 2 points is plausible but sits slightly low relative to peer negative mood traits (−2 to −4 for single-stat periodic debuffs). No downside to the trait. The dual-stat drain is unique in the Periodic-Check group.
- Regression proof: partially protected — registration and exclusion target validity are proven; all runtime behavior (both drain values, both floors, nil-guard, trait-guard, event binding) is unproven.
- Action needed: low urgency overall. Consider:
  1. Adding cost assertion for `UT_optimist` to the "script costs" test.
  2. Deciding whether `UT_mstoptimist` should be mutually exclusive with `UT_optimist` (currently no exclusion exists — stacking is possible).
  3. Deciding whether `UT_paranoia` stacking with `UT_optimist` is intentional (net result is +0.02 panic per 10 minutes — optimist partially cancels paranoia).
- Open gaps:
  - `UT_mstoptimist` is not excluded by `UT_optimist` — confirm whether stacking two positive mood traits is intended
  - `UT_paranoia` is not excluded by `UT_optimist` — confirm whether partial panic-offset stacking is intended
  - `DisabledInMultiplayer = true` — FillerTraits source does not document a multiplayer restriction; confirm this is an intentional UT policy decision rather than an oversight
  - No behavioral unit test coverage for either stat drain, either floor, nil-guard, or trait-guard — add before this trait is considered regression-safe
  - Cost (2) is not regression-protected in `run_tests.lua` — add a cost assertion to the balance test if cost stability matters
