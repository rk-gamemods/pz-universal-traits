# UT_depressive

## Trait Summary
- UT trait id: UT_depressive
- Source mod: MoreSimpleTraits (MSTDepressive) and MoreTraits (ToadTraits:depressive) — two independent source analogues identified
- Source trait id: `MSTDepressive` (MoreSimpleTraits), `depressive` (MoreTraits, no namespace prefix)
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` (runtime implementation — `depressivemoodtrait`, lines 896–906, 1131)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt` (source display strings, lines 100–101)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/client/MoreTraits.lua` (runtime implementation — `ToadTraitDepressive`, `CheckSelfHarm`, lines 1262–1299, 1301–1313, 4383)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/shared/Translate/EN/UI_EN.txt` (source display strings, lines 66–67)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (script definition — `ToadTraits:depressive`, lines 173–182)

- Source registration:
  - MoreSimpleTraits: `player:HasTrait("MSTDepressive")` checked inline in `depressivemoodtrait`
  - MoreTraits: `player:HasTrait("depressive")` checked inline in `ToadTraitDepressive` and `CheckSelfHarm`

- Source trigger path:
  - MoreSimpleTraits: `Events.EveryTenMinutes.Add(depressivemoodtrait)` — runs every 10 in-game minutes
  - MoreTraits: `ToadTraitDepressive()` called from a per-tick update function (hooked into the main player tick loop, line 4383 in `MoreTraits.lua`)

- Source behavior (MoreSimpleTraits — `depressivemoodtrait`, lines 896–906):
  - If the player has `MSTDepressive` and is **not** asleep:
    - `MSTincreaseUnhappyness(player, ZombRand(15), ZombRand(5))` — increases unhappiness by a random amount each 10-minute tick
    - With a 1-in-864 chance per tick (roughly once per 4 in-game days), additionally applies `MSTincreaseUnhappyness(player, 0, ZombRand(39)+61)` — a large unhappiness spike of 61–100 units
  - Effect is purely `UnhappynessLevel`-based; no stress manipulation

- Source behavior (MoreTraits — `ToadTraitDepressive`, lines 1262–1299):
  - Increments `player:getBodyDamage():getUnhappynessLevel()` by `0.001` each tick the player has `depressive`
  - Incorporates `Lucky` and `Unlucky` trait modifiers (`basechance` adjustment, specifics around line 1265–1270)
  - Also has a `Brooding` trait interaction (line 1272) — exact effect not fully visible in the excerpt but modifies the depression stacking mechanic
  - `CheckSelfHarm` (line 1301): if the player has `depressive`, the self-harm modifier is reduced by 1 (from 3 to 2), making physical self-harm more likely when deeply unhappy in combination with `selfdestructive`

- Source display name:
  - MoreSimpleTraits: `UI_trait_depressivemood = "Depressive"`
  - MoreTraits: `UI_trait_depressive = "Depressive"`
- Source description:
  - MoreSimpleTraits: `UI_trait_depressivemooddesc = "Often sad. Sometimes get Depressed for no reason."`
  - MoreTraits: `UI_trait_depressivedesc = "You're prone to bouts of sadness. You occassionally become sad. While depressed, sadness stacks until removed."`
- Source cost:
  - MoreSimpleTraits: not found in reviewed files (unknown)
  - MoreTraits (`ToadTraits:depressive` script definition): `Cost = -4`
- Source exclusions:
  - MoreTraits: `MutuallyExclusiveTraits = ToadTraits:blissful` (blissful excludes depressive; depressive excludes blissful — bidirectional)
  - MoreSimpleTraits: not found in reviewed files (unknown)

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — `run_tests.lua` line 100–102 confirms `UTTraitsRegistries.UT_depressive == "UniversalTraits:UT_depressive"`; also appears in the `expected_ids` list at line 282 (Phase 3b — Periodic-Check group)
- Defined in UT_character_traits.txt: yes — lines 1648–1657
  - `Cost = -4`
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_optimist`
- Translation strings present: yes
  - `UI_UT_depressive = "Depressive"` (line 515)
  - `UI_UT_depressiveDesc = "A heavy sadness follows you everywhere. Every 10 in-game minutes, stress increases by +0.08."` (line 516)
- Exclusions verified:
  - `UT_optimist` (line 1710–1719) lists `UT_depressive` in its `MutuallyExclusiveTraits` — bidirectional confirmed
  - `UT_pessimist` (line 1721) and `UT_melancholic` also appear in `UT_optimist`'s exclusion list alongside `UT_depressive`, but `UT_depressive`'s own definition does not list pessimist or melancholic as mutual exclusions — asymmetric in that direction
- Runtime Lua file exists: yes — `UT_depressive.lua`

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_depressive.lua` (full file, 14 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1648–1657)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 515–516)
- Event registrations: `Events.EveryTenMinutes.Add(handler)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`
- Runtime chain (plain language):
  1. `handler` fires every 10 in-game minutes via `Events.EveryTenMinutes`.
  2. `getPlayer()` is called; if nil, the function returns early.
  3. `UTCore.hasTrait(player, TRAIT_ID)` is called; if the player does not have `UniversalTraits:UT_depressive`, the function returns early.
  4. `player:getStats():getStress()` is read.
  5. Stress is set to `math.min(1, currentStress + 0.08)` — i.e., stress increases by exactly 0.08 per 10-minute tick, capped at the maximum value of 1.0.
  6. No sleep check — the handler fires regardless of whether the player is asleep.
  7. No randomness — the stress increment is flat and deterministic every tick.
- Actual behavior (exact values): Every 10 in-game minutes, stress increases by +0.08, hard-capped at 1.0. From a stress floor of 0, the trait reaches maximum stress in approximately 12.5 ticks (2 hours 5 minutes of in-game time). No unhappiness manipulation, no random depression spikes, no Lucky/Unlucky interaction, no sleep exemption.

## Description Integrity
- Display name check: "Depressive" — matches both source names exactly. No issue.
- Description check: `"A heavy sadness follows you everywhere. Every 10 in-game minutes, stress increases by +0.08."`
- Accuracy issues found:
  1. **Stat named is correct but the framing is potentially misleading** — the description says "stress increases by +0.08" and the Lua confirms exactly `stats:setStress(math.min(1, stats:getStress() + 0.08))`. The value and stat are accurate.
  2. **"heavy sadness"** — the description frames this as a sadness/unhappiness trait (consistent with source naming and flavor), but the UT implementation affects *stress*, not `UnhappynessLevel`. The flavor copy implies emotional suffering; the mechanical stat is stress. This is not an inaccuracy per se (stress is mood-adjacent), but the flavor language does not signal that stress—not unhappiness—is the operative stat.
  3. **No sleep exemption disclosed** — the MoreSimpleTraits source explicitly skips the effect while the player is asleep (`not player:isAsleep()`). The UT implementation has no such check; the stress increment fires unconditionally including during sleep. This behavioral divergence from source is not disclosed.
  4. **No random spike mechanic** — the MoreSimpleTraits source includes a rare large unhappiness spike (1-in-864 chance per tick). The UT version has no randomness; the description does not claim any, so this is correct silence.
  5. **Source stat divergence not disclosed** — MoreSimpleTraits raises `UnhappynessLevel`; MoreTraits raises `UnhappynessLevel`; UT raises `Stress`. The in-game effect is mechanically different. The description does not acknowledge this change from source behavior.
- Overall description verdict: the mechanical claim ("+0.08 stress per 10 minutes") is factually accurate against the Lua. The flavor framing implies unhappiness/sadness, which diverges from the actual stat modified. No outright false statement, but the sleep-during behavior and the stat swap from source are undisclosed.

## Balance Review
- Downside: +0.08 stress every 10 minutes, capped at 1.0. Starting from 0, full stress is reached in ~125 in-game minutes (just over 2 in-game hours). Stress at max triggers panic, affects combat effectiveness, and can accelerate other negative states depending on vanilla systems.
- Upside: none (purely negative trait)
- Uptime: 100% — fires unconditionally every 10 minutes while the trait is held, including during sleep, looting, and all other activities
- Cost: -4 points (UT)
- Source cost: -4 (MoreTraits `ToadTraits:depressive`); MoreSimpleTraits cost unknown
- Peer comparison:
  - `UT_melancholic` is listed in the same Phase 3b Periodic-Check group and is mutually exclusive with `UT_optimist` alongside `UT_depressive`; melancholic likely operates on unhappiness rather than stress, making depressive and melancholic thematically parallel but mechanically distinct
  - `UT_paranoia` (also Phase 3b, -4 cost in UT_character_traits.txt) provides a point of comparison — if paranoia delivers a similar or weaker periodic debuff for the same -4, depressive is appropriately priced; if paranoia delivers a weaker effect, depressive may be slightly underpriced (too cheap for the player)
  - Maximum stress is a hard ceiling; once at 1.0, additional stress ticks are no-ops — meaning the trait's marginal cost in-game diminishes once stress is already maxed from other sources
- Sleep behavior divergence: the UT version applies stress during sleep, which is absent from the MoreSimpleTraits source. This means UT depressive is strictly worse than the MST source during sleep periods — a hidden balance difference
- Cost verdict: -4 points is consistent with the MoreTraits source cost and is plausible given the strong passive debuff. The lack of a sleep exemption makes the UT version marginally harsher than the MST source, but this is not documented. Balance is acceptable but not precisely matched to either source.

## Regression Proof
- Existing tests:
  - `run_tests.lua` line 100–102: `test("UT_depressive registered", ...)` — asserts `UTTraitsRegistries.UT_depressive == "UniversalTraits:UT_depressive"`. Proves the registry entry exists.
  - `run_tests.lua` line 282: `"UniversalTraits:UT_depressive"` appears in the `expected_ids` table (Phase 3b — Periodic-Check group). Proves the trait is enumerable in the full registration count test.
- What the tests prove: The trait is registered and discoverable. Nothing more.
- Missing proof:
  - No test verifies that the `handler` function increases stress by exactly `0.08` per call.
  - No test verifies the `math.min(1, ...)` cap — i.e., that stress does not exceed 1.0 when already at or near maximum.
  - No test verifies that the handler exits early when the player does not have the trait (trait-check guard).
  - No test verifies that the handler exits early when `getPlayer()` returns nil (nil-guard).
  - No test verifies mutual exclusion with `UT_optimist` is enforced at the script level.
  - No test verifies that the trait fires on `EveryTenMinutes` and not on a different event.
- Minimum next test if needed: Mock `player:getStats()` returning a stats object with `getStress() == 0.95`. Invoke `handler` with the player holding `UniversalTraits:UT_depressive`. Assert that `setStress` is called with `1.0` (capped, not `1.03`). Then repeat with `getStress() == 0.5` and assert `setStress` receives `0.58`.

## Final Verdict
- Source origin: two analogues confirmed — MoreSimpleTraits `MSTDepressive` (periodic unhappiness raises via `EveryTenMinutes`) and MoreTraits `ToadTraits:depressive` (per-tick unhappiness raise with Lucky/Unlucky/Brooding interactions and self-harm modifier). The UT implementation draws its timing model from MoreSimpleTraits (10-minute event) but replaces unhappiness manipulation with stress manipulation, giving it a distinct mechanical identity from both sources.
- UT implementation: simplified and stat-substituted — both sources manipulate `UnhappynessLevel`; UT manipulates `Stress`. The MoreSimpleTraits sleep exemption is absent. The MoreTraits Lucky/Unlucky interaction and self-harm modifier synergy are absent. The MoreSimpleTraits rare large-spike mechanic is absent. The UT version is flatter and more predictable than either source.
- Description: mechanically accurate for the stated claim ("+0.08 stress per 10 minutes") — the value and stat match the Lua exactly. The flavor language implies unhappiness/sadness rather than stress. The sleep-behavior change from source (no exemption in UT) and the stat substitution (stress vs. unhappiness) are undisclosed.
- Balance: -4 cost matches the MoreTraits source cost; the UT version is slightly harsher than the MST source due to the missing sleep exemption. Plausible.
- Regression proof: partially protected — registration proven; all runtime behavior unproven.
- Action needed: description clarification (low urgency — current description is accurate, flavor could be tightened to reference stress explicitly); sleep-exemption decision should be confirmed as intentional; optional test additions for stress-cap and trait-guard logic.
- Open gaps:
  - Confirm whether omitting the sleep exemption (present in MoreSimpleTraits source) is intentional design or an oversight
  - Confirm whether the stat substitution (stress instead of unhappiness) relative to both source mods is intentional — if so, consider whether the description should explicitly say "stress" rather than relying on flavor language
  - `DisabledInMultiplayer = true` — both source mods set `DisabledInMultiplayer = false`; this divergence should be a confirmed intentional decision
  - Mutual exclusion scope: `UT_depressive`'s definition only lists `UT_optimist` as an exclusion, but `UT_optimist` lists `UT_pessimist`, `UT_depressive`, and `UT_melancholic`. Depressive does not block pessimist or melancholic directly — confirm whether a player can hold both `UT_depressive` and `UT_melancholic` simultaneously, and whether that stacking is intended
  - No test coverage for the stress-increment logic, the 1.0 cap, or the trait-guard; add behavioral unit tests before this trait is considered regression-safe
