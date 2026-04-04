# UT_selfdestructive

## Trait Summary
- UT trait id: UT_selfdestructive
- Source mod: MoreTraits (by Toad)
- Source trait id: selfdestructive (TraitFactory, no namespace prefix)
- Current cost: -6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (trait registration, line 234; mutual exclusion, line 325)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/client/MoreTraits.lua` (runtime implementation, `ToadTraitDepressive` lines 1262–1286 and `CheckSelfHarm` lines 1301–1317; event registration lines 4461, 4383)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/shared/Translate/EN/UI_EN.txt` (English display strings, lines 68–69)
- Source registration:
  - `TraitFactory.addTrait("selfdestructive", getText("UI_trait_selfdestructive"), -4, getText("UI_trait_selfdestructivedesc"), false, false)`
  - `TraitFactory.setMutualExclusive("blissful", "selfdestructive")`
- Source trigger path:
  - `Events.OnPlayerUpdate.Add(MainPlayerUpdate)` fires `MainPlayerUpdate` every player update tick, which calls `CheckSelfHarm(player)`.
  - `Events.EveryOneMinute.Add(EveryOneMinute)` fires `EveryOneMinute` once per in-game minute, which calls `ToadTraitDepressive()`.
- Source behavior (two independent effects):
  1. **Depression amplification** (`ToadTraitDepressive`, per minute): If the player has the `depressive` trait and rolls a random depression check, having `selfdestructive` increases the base chance of triggering a depression episode by +1 (out of 100). This is a modifier on top of the `depressive` mechanic, not an independent effect — the source `selfdestructive` had no standalone depression trigger.
  2. **Health drain while sad** (`CheckSelfHarm`, per player update tick): If unhappiness >= 25, and overall body health is above the threshold `(100 - unhappiness / modifier)`, every body part takes `0.001 * GameSpeedMultiplier()` damage per tick. The modifier defaults to 3, reduced to 2 if the player also has `depressive` (making the health-drain threshold higher, i.e., drain starts sooner). This is a continuous body damage loop conditional on sustained unhappiness.
  - Source cost: -4 points. Source mutual exclusion: with "blissful" (the happiness-recovery counterpart). No exclusion from "depressive" in source — the two traits actively interact and stack.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — `registries.lua` line 248: `UTTraitsRegistries.UT_selfdestructive = CharacterTrait.register("UniversalTraits:UT_selfdestructive")`
- Defined in UT_character_traits.txt: yes — lines 1669–1677
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `Cost = -6`
  - `UIName = UI_UT_selfdestructive`
  - `UIDescription = UI_UT_selfdestructiveDesc`
  - No `MutuallyExclusiveTraits` declared
- Translation strings present: yes
  - `UI_UT_selfdestructive = "Self-Destructive"`
  - `UI_UT_selfdestructiveDesc = "You have always been your own worst enemy. You act against your own interests in ways that are hard to explain, even to yourself."`
- Exclusions/grants correct: source had one mutual exclusion with "blissful"; UT declares no mutual exclusions. UT has a `UT_optimist` trait that is the thematic counterpart to `UT_depressive`; no exclusion between `UT_selfdestructive` and `UT_optimist` is declared. This is a divergence from the source design intent.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_selfdestructive.lua`

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_selfdestructive.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1669–1677)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 521–522)
- Event registrations: `Events.EveryTenMinutes.Add(handler)`
- UT_CORE hooks used: `UTCore.hasTrait`
- Runtime chain (plain language):
  1. Every 10 in-game minutes, `handler` fires.
  2. `getPlayer()` is called; if nil, returns early.
  3. `UTCore.hasTrait(player, "UniversalTraits:UT_selfdestructive")` is checked; if not present, returns early.
  4. `ZombRand(10) < 2` — a 20% probability roll.
  5. If the roll succeeds:
     - `stats:setStress(math.min(1, stats:getStress() + 0.1))` — stress increases by +0.1, capped at 1.0.
     - `stats:setFatigue(math.min(1, stats:getFatigue() + 0.05))` — fatigue increases by +0.05, capped at 1.0.
- Actual behavior (exact values): Every 10 in-game minutes, there is a 20% (2-in-10) chance of a stress spike of +0.1 and a fatigue spike of +0.05. Both are capped at their maximums. No body damage. No unhappiness check. No interaction with the `depressive` trait. No health drain. No depression amplification.

## Description Integrity
- Display name check: "Self-Destructive" — matches the source display name exactly. No issue.
- Description check: "You have always been your own worst enemy. You act against your own interests in ways that are hard to explain, even to yourself." — this is entirely flavor text. It makes no mechanistic claim whatsoever. It does not mention stress, fatigue, timing, probability, or magnitude of effect.
- Missing or misleading details:
  - The description is pure flavor. A player reading it cannot determine what the trait does, when it triggers, or at what magnitude. This is a complete description gap — the player has no mechanical information to make an informed character-creation choice.
  - The source description was: "When the going gets tough, you crumble. While sad, your health begins to decline down to a maximum relative to your unhappiness level." The UT implementation bears no mechanistic resemblance to this — the UT version does not involve sadness, unhappiness, or health decline at all.
  - The UT implementation is a periodic random stress/fatigue spike mechanic. The description should disclose: the 10-minute trigger interval, the 20% probability per check, the +0.1 stress and +0.05 fatigue magnitudes on a hit.

## Balance Review
- Upside (for player): none. This is a pure downside negative trait.
- Downside: 20% chance every 10 in-game minutes of +0.1 stress and +0.05 fatigue. Expected stress gain per hour (6 checks): 6 × 0.2 × 0.1 = +0.12 stress/hour. Expected fatigue gain per hour: 6 × 0.2 × 0.05 = +0.06 fatigue/hour. These are modest but persistent pressures requiring ongoing management.
- Uptime: continuous; the check fires unconditionally every 10 minutes regardless of player state (mood, health, activity). Unlike the source, there is no unhappiness threshold gating the effect.
- Cost: -6 points (UT) vs. -4 points (source MoreTraits).
- Source comparison:
  - The source behavior was significantly more severe: continuous body damage to all body parts scaled by unhappiness level (conditional on unhappiness >= 25 and overall health above the drain threshold), plus increased chance of triggering full depression episodes while also having `depressive`. The source was a conditional health-drain loop — far harsher in high-unhappiness scenarios.
  - The UT behavior is a simple unconditional periodic stress/fatigue poke with 20% probability. This is substantially weaker than the source: no health damage, no body part deterioration, no unhappiness dependency, no interaction with other traits.
  - UT charges -6 (more negative = more points granted to player) against the source's -4. The larger negative cost implies the designer considered the UT version more punishing than the source, but the actual implementation is mechanically weaker on almost every axis.
- Peer comparison:
  - `UT_paranoia` (cost -4): panic +0.06 every 10 minutes (unconditional). That is a comparable structure — same trigger interval, similar magnitude on a single stat, no probability gate. `UT_selfdestructive` at -6 fires on only 20% of 10-minute ticks, hitting two stats. The probability gate makes the effective average rate significantly lower than `UT_paranoia` despite costing 2 more points.
  - `UT_depressive` (cost -4): operates as a periodic-check trait in the same batch. No cross-interaction with `UT_selfdestructive` in UT, unlike the source where the two traits explicitly interacted.
- Missing mutual exclusion: the source excluded `selfdestructive` from `blissful`. UT has a `UT_optimist` which serves a similar conceptual role. No exclusion is declared between `UT_selfdestructive` and `UT_optimist`. A player can currently take both.
- Stack or exclusion notes: No declared exclusions in UT. No declared interaction with `UT_depressive`, `UT_melancholic`, or `UT_optimist`. The UT implementation is fully independent of all other mood traits.
- Cost verdict: questionable — the UT implementation is weaker than the source but the UT cost is larger in magnitude (-6 vs. -4). The -6 cost is not obviously justified by the mechanics. Compared to `UT_paranoia` at -4 (unconditional every-10-minute hit), the gated 20% probability of `UT_selfdestructive` for two stats does not clearly warrant a -6 value over -4.

## Regression Proof
- Existing tests:
  - `run_tests.lua` line 283: `"UniversalTraits:UT_selfdestructive"` appears in the `expected_ids` list (Phase 3b — Periodic-Check, 25 traits). This is covered by the all-traits registration count test at line 312 (`test("all 198 trait IDs registered with CharacterTrait", ...)`). Proves the trait ID is enumerable in the registration sweep.
  - No dedicated named test for `UT_selfdestructive` was found in `run_tests.lua`.
- What the tests prove: The trait ID is registered and present in the canonical expected_ids list. Nothing more.
- Missing proof:
  - No test verifies that `handler` fires on `Events.EveryTenMinutes`.
  - No test verifies that `ZombRand(10) < 2` is the correct probability gate (20%).
  - No test verifies that a player with the trait receives +0.1 stress and +0.05 fatigue on a successful roll.
  - No test verifies that a player without the trait receives no stat changes.
  - No test verifies the `math.min(1, ...)` cap prevents overflow above 1.0.
  - No test verifies behavior when `getPlayer()` returns nil.
- Minimum next test if needed: Mock a player with `UTCore.hasTrait` returning true and `ZombRand` fixed to return 1 (< 2 = hit); call `handler()`; assert `stats:getStress()` increased by 0.1 and `stats:getFatigue()` increased by 0.05. Also: fix `ZombRand` to return 5 (>= 2 = miss); call `handler()`; assert no stat changes.

## Final Verdict
- Source origin: proven — MoreTraits "selfdestructive" confirmed via `TraitFactory.addTrait("selfdestructive", ...)` in `MoreTraitsMainCreationMethods.lua` line 234 and the two-function runtime implementation (`ToadTraitDepressive` + `CheckSelfHarm`) in `MoreTraits.lua`
- UT implementation: substantially redesigned — the source implemented two mechanics (depression-episode amplification via per-minute check; continuous per-tick body damage to all parts scaled by unhappiness level when unhappiness >= 25). The UT version replaces both with a single unconditional per-10-minute 20% probability roll that applies +0.1 stress and +0.05 fatigue. There is no health damage, no unhappiness dependency, no body part loop, and no interaction with other mood traits.
- Description: non-informative — the description is pure flavor text with zero mechanistic content. A player cannot determine from the description what the trait does, when it fires, what stats it affects, or at what probability. This is a complete player-facing description gap.
- Balance: questionable — the UT implementation is mechanically weaker than the source (stress/fatigue poke vs. body part health drain) but costs more in magnitude (-6 UT vs. -4 source). The cost is not well-calibrated relative to peer trait `UT_paranoia` (-4, unconditional, same interval structure).
- Regression proof: minimally protected — only covered by the all-traits registration sweep; no behavioral tests exist
- Action needed: description fix (required), cost review, mutual exclusion gap (consider adding `UT_optimist` exclusion), add behavioral tests
- Open gaps:
  - Description discloses no mechanics; must be rewritten to describe the 10-minute interval, 20% probability, and exact stat deltas (+0.1 stress, +0.05 fatigue)
  - Source mutual exclusion with "blissful" has no UT equivalent; `UT_optimist` is the natural counterpart but no exclusion is declared — a player can hold both simultaneously
  - Cost of -6 vs. source -4 is not obviously justified given the weaker UT implementation; consider adjusting to -4 to match `UT_paranoia` parity, or document the rationale for -6
  - No cross-interaction with `UT_depressive` or `UT_melancholic` in UT, unlike the source where `selfdestructive` + `depressive` stacked in a meaningful way; whether the UT design intentionally removes that interaction should be confirmed
  - `DisabledInMultiplayer = true` in UT; source had no multiplayer restriction — confirm this is intentional
  - No behavioral tests for the handler function
