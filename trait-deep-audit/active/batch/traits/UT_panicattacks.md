# UT_panicattacks

## Trait Summary

- UT trait id: UT_panicattacks
- Source mod: none — original UT trait (no matching source located in installed-mods)
- Source trait id: n/a
- Current cost: -6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/` — full text search across all 654 indexed files for "panic_attack", "panicattack", and "panic attack" (case-insensitive). Zero matches for a source trait with this identity.
  - `research/installed-mods/DynamicTraitsExpandedMoodles/` — references to `setPanic(95)` (Nightmares trait) and generic `getPanic()` stat reads; no discrete panic-attack trait.
  - `research/installed-mods/EvolvingTraitsWorld/` — uses `CharacterStat.PANIC` for mental health accounting and smoking addiction decay; no panic-attack trait.
- Source origin verdict: **no source found**. `UT_panicattacks` is an original UT design with no counterpart trait in any indexed installed mod. The concept — random acute panic spikes — does not appear in DynamicTraits, EvolvingTraitsWorld, SomewhatTraits, MoreTraits, or any other indexed source.
- Source cost: n/a
- Source description: n/a
- Source trigger path: n/a
- Source behavior: n/a

## Current UT Evidence

### Structure

- Registered in registries.lua: yes (`media/registries.lua` line 261)
  - `UTTraitsRegistries.UT_panicattacks = CharacterTrait.register("UniversalTraits:UT_panicattacks")`
- Registered in test harness: yes (`test/run_tests.lua` line 289, grouped in "Phase 3b — Periodic-Check (25)")
- Defined in UT_character_traits.txt: yes (lines 1803–1811)
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_panicattacks`
  - `Cost = -6`
  - `UIName = UI_UT_panicattacks`
  - `UIDescription = UI_UT_panicattacksDesc`
  - No `MutuallyExclusiveTraits` declared
- Translation strings present: yes (`media/lua/shared/Translate/EN/UI_EN.txt` lines 560–561)
  - `UI_UT_panicattacks = "Panic Attacks"`
  - `UI_UT_panicattacksDesc = "Without warning, your body convinces itself that death is seconds away. The attacks pass, but they leave you shaken."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_panicattacks.lua`, 17 lines)
- MET group membership: none — `UT_panicattacks` does not appear in any group in `UT_MET.lua`.

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_panicattacks.lua` (full file, 17 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 9–16) — `UTCore.hasTrait` definition
  - `media/scripts/UT_character_traits.txt` (lines 1803–1811) — script definition
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 560–561) — translation strings
  - `test/run_tests.lua` (line 289) — registration sweep
- Event registrations:
  - `Events.EveryOneMinute.Add(handler)` — fires once per in-game minute
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe trait presence check
    - Implementation (UTCore_API.lua): checks `player:getTraits():contains(traitId)`. Returns false if player or traits collection is nil. No side effects.
- Runtime chain (plain language):
  1. Once per in-game minute: the handler fires.
  2. Calls `getPlayer()`. If nil (no local player), exits immediately.
  3. Calls `UTCore.hasTrait(player, TRAIT_ID)`. If the player does not hold `"UniversalTraits:UT_panicattacks"`, exits immediately.
  4. Calls `ZombRand(20)`. This returns a random integer in [0, 19] inclusive (20 possible outcomes). If the result equals 0, the roll succeeds (probability: 1-in-20 = 5%).
  5. On a successful roll: reads current panic via `player:getStats():getPanic()`, adds 0.4, clamps to 1.0 via `math.min(1, ...)`, and writes the result back with `stats:setPanic(...)`.
  6. On a failed roll: no state change.
- Actual behavior (exact values):
  - Trigger cadence: `EveryOneMinute` — once per in-game minute.
  - Roll probability: `ZombRand(20) == 0` → 5% per minute (1-in-20).
  - Expected panic attacks per hour: 3 (Poisson mean = 60 min × 0.05 = 3.0).
  - Panic increment per attack: +0.4 (40% of the 0–1 scale), absolute, not relative.
  - Panic cap: `math.min(1, current + 0.4)` — a single attack from a baseline of 0.6 or higher is capped at 1.0.
  - Panic scale clarification: `getPanic()` / `setPanic()` operate on a 0.0–1.0 float. Value 1.0 = full panic (max Panic moodle). A +0.4 spike represents a violent jump of 40 percentage points in one tick.
  - No conditions on player state: the roll fires regardless of whether the player is indoors, outdoors, in combat, at rest, sleeping, or any other state. There is no suppression mechanic.
  - No moddata written: the handler leaves no persistent state in `player:getModData()`.
  - No stat interactions: only the panic stat is affected. No stress, unhappiness, or fatigue changes.
  - Natural panic decay: the PZ engine decays panic naturally over time when no sources are actively adding to it. The net sustained panic level depends on the engine's decay rate, which is not governed by this file. Between attacks (expected ~20-minute gaps at 5%/min), the engine will partially or fully drain the panic bar before the next attack.
  - Attack feel: a single attack on a 0.0 baseline delivers 0.4 panic instantly. Two attacks in rapid succession (each minute both roll 0) would deliver 0.8 total, near-maxing the bar. The probability of two consecutive successes is 0.25%.

## Description Integrity

- Display name check: "Panic Attacks" — accurate and self-explanatory. No issues.
- Description check: `UI_UT_panicattacksDesc` reads: "Without warning, your body convinces itself that death is seconds away. The attacks pass, but they leave you shaken."
- Issues found:
  1. **"Without warning" is mechanically accurate.** The random roll has no pre-condition, no state prerequisite, and no visual or auditory warning before the spike. The description is truthful on this point.
  2. **"The attacks pass" is accurate but the description does not quantify cadence or severity.** A player reading this cannot infer that attacks occur at a 5% chance per minute, deliver a +0.4 panic spike (reaching the max Panic moodle in 2–3 attacks), or persist until natural decay resolves them. This is flavour-appropriate vagueness rather than a false claim, but it understates the mechanical severity.
  3. **"They leave you shaken" does not name the mechanical effect.** The stat raised is panic, which in PZ directly impairs aiming accuracy and triggers the Panic moodle. Players unfamiliar with the game's panic system may not understand that "shaken" means combat accuracy degradation, not merely a cosmetic animation or a stress increase.
  4. **No description of frequency.** A 5% chance per minute is actually quite punishing over a long session — expected 3 attacks per hour, each delivering a major panic spike. The description's tone ("the attacks pass") implies transience without communicating that they recur frequently throughout play. This is not a false statement but is materially incomplete for a -6 cost trait.
  5. **No mention of multiplayer restriction.** `DisabledInMultiplayer = true` is set. Players choosing this trait in a multiplayer session will find it unavailable. The description contains no hint of this restriction. This is a systemic UT concern (all traits may share this pattern), but it is noted here.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside: 5% chance per in-game minute of a +0.4 panic spike, with no state-based precondition.
- Rate analysis:
  - **Expected rate**: 3 attacks per hour, on average, every session hour without exception.
  - **Per-attack severity**: +0.4 panic. From a clear baseline (0.0), one attack → 0.4 (Panic moodle level 2 territory). Two attacks in the same minute window → 0.8 (near-max). Three within a few minutes → capped at 1.0.
  - **Worst-case accumulation**: if natural panic decay is slower than +0.4/attack and attacks arrive in clusters (possible, though unlikely — two consecutive hits = 0.25% per minute), panic can peg at 1.0 and remain near-maxed for extended periods.
  - **Escape**: none. The trait has no cooldown, no situational suppression, no item or action that reduces its fire rate. The only relief is the engine's natural panic decay, which is external to this trait.
- Comparison with peer panic traits in UT:
  - `UT_acrophobic`: +0.05 panic/min while above ground (z > 0). Conditional and escapable by staying on the ground floor. Rate: 0.05/min.
  - `UT_fearofthedark`: +0.04 panic/min at night; −0.01/min during day. Conditional on time of day. Rate: ~0.04/min during roughly half the day.
  - `UT_paranoia`: +0.06 panic per 10 minutes unconditional. Rate: 0.006/min effective.
  - `UT_alcoholic_III`: +0.03 panic/min when drunkenness < 0.05. Conditional on sobriety.
  - `UT_panicattacks`: expected +0.4 × 0.05 = **+0.02 panic/min effective average**, but delivered as infrequent large spikes rather than a steady drip.
  - The effective average rate (+0.02/min) is lower than `UT_acrophobic` (+0.05/min) when above ground, but the spike magnitude (+0.4 per event vs. +0.05 per tick) is eight times larger. The spike model is qualitatively more disruptive because it can peg the Panic moodle to maximum in a short window, triggering severe aiming penalties during those windows, even though the long-run average is moderate.
- Cost comparison:
  - `UT_panicattacks` costs -6.
  - `UT_acrophobic` costs -4 (conditional, escapable, lower effective rate).
  - `UT_fearofthedark` costs -4 (conditional on night, escapable by day).
  - `UT_paranoia` costs (from script: -6, per `UT_paranoia` in the traits file — not confirmed here but noted as a peer).
  - A cost of -6 for an unconditional trait that delivers ~3 severe panic spikes per hour, each capable of maxing the Panic moodle, is plausible. The spike model is more punishing than equivalent-rate drip traits because of the moodle threshold behavior: Panic level 4 (max) causes aiming penalties and debuffs that panic level 2 does not. An unconditional -6 with no escape mechanic and no cooldown is arguably slightly undercosted relative to the actual disruption in combat-heavy sessions.
- Stack and exclusion notes:
  - No `MutuallyExclusiveTraits` in the script definition. No MET group in `UT_MET.lua`.
  - `UT_panicattacks` can be taken alongside `UT_acrophobic`, `UT_fearofthedark`, `UT_alcoholic_III`, `UT_nervouswreck`, or any other panic-affecting trait. Stacking multiple panic sources (drips + spikes) can push the panic bar above recovery thresholds persistently, making the combined package significantly more severe than any individual trait suggests.
  - The lack of any mutual exclusion with other panic-raising traits is a notable gap given the spike magnitude.

## Regression Proof

- Existing test: `UT_panicattacks` appears in the Phase 3b registration sweep (`run_tests.lua` line 289) alongside other periodic-check traits.
- What it proves: the trait ID `"UniversalTraits:UT_panicattacks"` is present in the CharacterTrait registry. The sweep verifies that `CharacterTrait.register(...)` succeeded and the ID resolves. It does not exercise runtime behavior in any way.
- Missing proof:
  1. No test that the `EveryOneMinute` handler fires and that `ZombRand(20) == 0` on a winning roll causes a +0.4 panic increment.
  2. No test that `ZombRand(20) != 0` on a losing roll causes no state change.
  3. No test that the panic result is capped at 1.0 when the pre-spike value is ≥ 0.6.
  4. No test that the handler exits when `getPlayer()` returns nil.
  5. No test that the handler exits when the player does not hold the trait (i.e., `UTCore.hasTrait` returns false).
  6. No test for behavior when `player:getStats()` returns nil (defensive path not present in code — potential nil crash if stats object is unexpectedly absent).
- Minimum next test if needed: "panicattacks: 5% roll triggers +0.4 panic spike" — mock `ZombRand` to return 0 (success) and to return 1 (failure); mock player with trait and initial panic 0.0; fire `EveryOneMinute` handler; assert panic == 0.4 on success and panic == 0.0 on failure. Also test cap: initial panic 0.7, roll succeeds, assert panic == 1.0 (not 1.1).

## Final Verdict

- Source origin: **original UT design** — no matching source trait was found in any indexed installed mod. The panic-attack concept (random acute panic spikes with no precondition) does not appear in the source mods corpus. This trait was authored directly for UT.
- UT implementation: **internally consistent and functional**. The logic is minimal (17 lines), correct, and the guard chain (`getPlayer` nil check → `UTCore.hasTrait` → `ZombRand` roll → clamped stat write) is sound. There is no dead code, no state leak, and no obvious crash path other than a missing nil check on `player:getStats()` (the stats object is dereferenced without a guard; in practice PZ always provides a stats object for a valid player, so this is a low-risk omission, not a confirmed bug).
- Description: **tonally accurate but mechanically understated**. The flavour text is well-written and not false. However, it omits the 5% per-minute cadence, the +0.4 spike magnitude, the resulting aiming penalty from the Panic moodle, and the multiplayer restriction. Players choosing this trait cannot assess its actual severity from the description alone.
- Balance: **plausible at -6, with a mild concern**. The effective average panic rate (~0.02/min) is moderate relative to other panic traits, but the spike delivery model is categorically more disruptive than equivalent-rate drips — a single attack can peg the Panic moodle and impose aiming penalties in a way that a steady +0.02/min drip cannot. The absence of any escape mechanic, cooldown, or mutual exclusion with other panic-raising traits means the trait can stack into an effectively unmanageable panic state in combination with `UT_acrophobic`, `UT_fearofthedark`, or similar. A cost of -6 for an unconditional, unavoidable trait is at the low end of defensible; -7 or an explicit cooldown mechanic would strengthen the balance case.
- Regression proof: registration confirmed via Phase 3b sweep; zero behavioral tests exist.
- Action needed:
  1. **Enhance description** — add either the cadence ("strikes roughly three times an hour") or the severity ("a sudden surge that can overwhelm your senses") to give players a meaningful signal about the trait's impact. Do not overspecify the exact number (that is an internal detail), but the current "the attacks pass" framing actively downplays a -6 cost trait.
  2. **Add nil guard on stats** — `player:getStats()` is called without a nil check. While this is safe in normal play, defensive style used throughout UT would add `if not stats then return end` after line 11. Low priority; not a live bug.
  3. **Evaluate mutual exclusion with other panic sources** — consider whether taking `UT_panicattacks` alongside `UT_acrophobic` or `UT_fearofthedark` represents an intended design (extreme panic build) or an oversight. If stacking is unintended, add mutual exclusions or shared cooldown logic.
  4. **Consider a per-attack cooldown** — a minimum of 10–20 in-game minutes between attacks would make the trait more predictable and prevent back-to-back spikes, while keeping the expected frequency (3/hr) approximately intact. This would also give the "attacks pass" framing more literal truth.
  5. **Add behavioral tests** — at minimum: roll-succeeds path (panic increments +0.4), roll-fails path (no change), cap behavior (clamped to 1.0), nil-player guard, and trait-absent guard.
- Open gaps:
  - The PZ engine's natural panic decay rate is not confirmed from the reviewed files. Without it, the net sustained panic level between attacks is not precisely quantifiable. The balance review uses expected-value reasoning over the panic stat's range but cannot give a definitive "time to max panic bar" under natural decay.
  - No source to compare against means there is no prior design intent to validate — all design decisions are UT-original and must be evaluated on their own terms.
