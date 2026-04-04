# UT_heatsensitive
## Trait Summary
- UT trait id: UT_heatsensitive
- Source mod: SomewhatTraits / SomewhatTraitsCore (by SomewhatNormal)
- Source trait id: SWHeatSensitive
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` (B41 registration, line 102; NPC table, line 33; mutual exclusion, line 112)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.12/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` (42.x registration, line 103; NPC table, line 33; mutual exclusion, line 113)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (B41 client implementation, local var at line 120)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.12/media/lua/client/SWSomewhatTraitsCore.lua` (42.12 client implementation, lines 566–580)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.13/media/lua/server/SWTraitsCore_server.lua` (42.13/42.15 server implementation, lines 315–324)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/registries.lua` (42.13 registry, line 36)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/registries.lua` (42.15 registry, line 36)
- Source behavior — B41 / 42.12 client (`SWSomewhatTraitsCore.lua`):
  - Module-level locals `hasSWHeatSensitive` and cached `stats`, `moodles`, `character`, `ribbit`, `maxStress`, `timeMultiplier` are set once in a setup callback.
  - `SWHeatSensitive()` is registered on `Events.OnTick`.
  - Guard: `if not (ribbit and character) then return end` — early exit if game not ready.
  - Guard: `if not hasSWHeatSensitive then return end` — early exit if trait not held.
  - Reads `stress = stats:getStress() - stats:getStressFromCigarettes()` (isolates non-cigarette stress).
  - Reads `moodleLevel = moodles:getMoodleLevel(MoodleType.Hyperthermia)` — integer 0–4.
  - Computes `extraStress = timeMultiplier * moodleLevel * 0.01`.
  - Applies only when `moodleLevel > 0 and stress < maxStress`:
    - `newStress = stress + extraStress`; clamped to `maxStress`.
    - `stats:setStress(newStress)`.
  - Effect: **stress only**; scales with Hyperthermia moodle level (0 at no heat, up to `4 * 0.01 * timeMultiplier` per tick at Hyperthermia level 4). No fatigue penalty.
- Source behavior — 42.13/42.15 server (`SWTraitsCore_server.lua`):
  - `SWHeatSensitive()` registered on `Events.OnTick` (server-side equivalent).
  - Guard: `if not player then return end`.
  - Guard: `if not player:hasTrait(SWT.traits.SWHeatSensitive) then return end`.
  - Reads `stats = player:getStats()`.
  - Reads `moodleLevel = player:getMoodleLevel(MoodleType.HYPERTHERMIA)`.
  - Computes `extraStress = moodleLevel * 0.01` (no `timeMultiplier` in server version).
  - Calls `stats:add(CharacterStat.STRESS, extraStress)` unconditionally (no zero-guard on moodleLevel, no maxStress cap in this version).
  - Effect: same stress-from-hyperthermia moodle concept; server version omits `timeMultiplier` and the `stress < maxStress` ceiling guard.
- Source trigger path: `Events.OnTick` — fires every game tick. No throttle.
- Source effects: **stress only**, proportional to Hyperthermia moodle level. No fatigue effect in either version. Effect is zero when player is not overheating.
- Source trait registration: `TraitFactory.addTrait("SWHeatSensitive", ..., -2, ...)` — cost **-2** in source.
- Source mutual exclusion: `TraitFactory.setMutualExclusive("SWColdSensitive", "SWHeatSensitive")` — cold-sensitive and heat-sensitive cannot be taken together in source.
- Source NPC table: `["SWHeatSensitive"] = true` — eligible for NPC random assignment.

## Current UT Evidence
### Structure
- Registered in run_tests.lua: yes — `"UniversalTraits:UT_heatsensitive"` at line 291 of `test/run_tests.lua`, in the Phase 3b — Periodic-Check (25) block, on the same line as `"UniversalTraits:UT_sedentary"`.
- Defined in UT_character_traits.txt: yes —
  ```
  character_trait_definition UniversalTraits:UT_heatsensitive
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_heatsensitive,
      Cost = -4,
      UIName = UI_UT_heatsensitive,
      UIDescription = UI_UT_heatsensitiveDesc,
  }
  ```
  No `MutuallyExclusiveTraits` field present.
- Registered in registries.lua: yes — line 264:
  `UTTraitsRegistries.UT_heatsensitive = CharacterTrait.register("UniversalTraits:UT_heatsensitive")`
  Immediately follows `UT_coldsensitive` registration (line 263) and precedes `UT_sedentary` (line 265).
- Translation strings present: yes —
  - `UI_UT_heatsensitive = "Heat Sensitive"` (UI_EN.txt, line 569)
  - `UI_UT_heatsensitiveDesc = "Heat hits you harder than most. High temperatures sap your strength and leave you struggling when others are merely warm."` (UI_EN.txt, line 570)
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_heatsensitive.lua` (17 lines)

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_heatsensitive.lua` (full file, 17 lines)
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_coldsensitive.lua` (full file, 17 lines — sibling trait for comparison)
  - `UniversalTraits/media/scripts/UT_character_traits.txt` (lines 1833–1841)
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` (lines 569–570)
  - `UniversalTraits/test/run_tests.lua` (line 291)
  - `UniversalTraits/test/UTTestMocks.lua` (MockPlayer definition, lines 117–199; UTCore stub, lines 200–240)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.12/media/lua/client/SWSomewhatTraitsCore.lua` (lines 566–580, source)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.13/media/lua/server/SWTraitsCore_server.lua` (lines 315–324, source)
- Event registration: `Events.EveryTenMinutes.Add(handler)` — registered once at module load time. Fires once every ten in-game minutes. No guard against multiple registrations.
- Runtime chain (plain language):
  1. Every ten in-game minutes, `handler()` fires.
  2. Calls `getPlayer()`. If nil (no local player), returns immediately.
  3. Calls `UTCore.hasTrait(player, "UniversalTraits:UT_heatsensitive")`. At runtime, `UTCore.hasTrait` delegates to `player:getTraits():contains(traitId)` — a direct B42 trait-set lookup. If false, returns immediately.
  4. Calls `player:getBodyTemperature()`. If the return value is **not greater than 38.0**, the handler does nothing and returns.
  5. If body temperature > 38.0:
     - `stats = player:getStats()`
     - `stats:setStress(math.min(1, stats:getStress() + 0.08))` — adds 0.08 to current stress, clamped at 1.0 (full stress).
     - `stats:setFatigue(math.min(1, stats:getFatigue() + 0.05))` — adds 0.05 to current fatigue, clamped at 1.0 (full fatigue).
- Exact numbers per trigger (body temp > 38.0):
  - Stress delta: **+0.08** (out of 1.0 max)
  - Fatigue delta: **+0.05** (out of 1.0 max)
  - Cadence: **once per ten in-game minutes**
  - Ceiling: both are clamped by `math.min(1, current + delta)` — cannot exceed 1.0
- Trigger condition: `player:getBodyTemperature() > 38.0` — a single threshold with no scaling. Effect is binary: either fully applied or not at all, regardless of whether temperature is 38.1°C or 50°C.
- No modData used. No per-tick state. No memory between calls.
- UTCore.hasTrait production path: `player:getTraits():contains(traitId)` — the test mock matches production behavior; the stub is transparent.
- Sibling trait comparison (`UT_coldsensitive.lua`): structurally identical — same 17-line file, same event, same deltas, mirrored threshold (`< 36.0` cold vs `> 38.0` heat). The two traits are exact mirror images in implementation.

## UT Divergences from Source
1. **Fatigue added**: Source applies stress only. UT adds a fatigue penalty of +0.05 per trigger in addition to the stress penalty. This is a new effect not present in any source version.
2. **Trigger mechanism replaced**: Source reads `getMoodleLevel(MoodleType.Hyperthermia)` and scales stress proportionally (level 0 = no effect, level 1–4 = increasing stress per tick). UT reads `player:getBodyTemperature()` against a fixed threshold (>38.0) with a flat delta. The source response is gradual and moodle-level-proportional; UT's is binary and threshold-gated.
3. **Cadence changed**: Source fires on `Events.OnTick` (every game tick, no throttle). UT fires on `Events.EveryTenMinutes` (once per ten in-game minutes). This is a dramatic reduction in firing frequency — the effect accumulates far more slowly in UT.
4. **Stress amount changed**: Source adds `moodleLevel * 0.01 * timeMultiplier` per tick. At tick rate, even level-1 hyperthermia accumulates stress very quickly. UT adds a flat 0.08 every ten minutes regardless of temperature severity. These are not directly comparable quantities, but the UT rate is substantially lower in practice.
5. **maxStress cap removed**: Source (42.12 client) guards `stress < maxStress` before applying the increment. UT uses `math.min(1, ...)` inline — functionally equivalent capping but unconditionally written; no separate `maxStress` variable needed.
6. **Cigarette stress subtracted in source, not UT**: Source (42.12 client) reads `stats:getStress() - stats:getStressFromCigarettes()` to isolate non-cigarette stress before adding. UT reads `stats:getStress()` directly. Under UT, a heavy smoker's cigarette stress partially counts toward the ceiling, which could slightly dampen the effective increment in edge cases.
7. **Trait check method**: Source uses `hasTrait` as a cached boolean (B41 client) or `player:hasTrait(SWT.traits.SWHeatSensitive)` (B42 server). UT uses `UTCore.hasTrait(player, "UniversalTraits:UT_heatsensitive")` — the UT-standard namespaced pattern.
8. **Cost doubled**: Source registers at **-2**. UT defines at **-4**.
9. **Mutual exclusion absent**: Source calls `TraitFactory.setMutualExclusive("SWColdSensitive", "SWHeatSensitive")`. UT defines no `MutuallyExclusiveTraits` between `UT_coldsensitive` and `UT_heatsensitive` in the script file. A player can take both in UT simultaneously.

## Description Integrity
- Display name check: `"Heat Sensitive"` — direct translation of source concept; accurate.
- Description check: `"Heat hits you harder than most. High temperatures sap your strength and leave you struggling when others are merely warm."`
  - "Sap your strength" — partially accurate: UT applies both stress (+0.08) and fatigue (+0.05) per ten-minute trigger. Fatigue does reduce effective strength and endurance, so this is defensible.
  - "High temperatures" — the threshold is `getBodyTemperature() > 38.0`. In PZ terms 38°C is a mildly elevated body temperature, not an extreme. The description's implication of "high" temperature is broadly accurate but the threshold is lower than "high" connotes — normal human body temperature is 37°C; 38.0 is a low-grade fever threshold.
  - "Leave you struggling" — implies impairment. Stress and fatigue accumulation over time does create real gameplay impairment; the description is directionally correct.
  - No mention of fatigue: the description implies stress ("struggling") but not fatigue ("sap your strength" is closer to fatigue). Neither effect is named explicitly, which is consistent with other UT descriptions — acceptable.
  - Missing detail: the description gives no indication of cadence or threshold. A player cannot know that this fires every ten minutes only when body temp exceeds 38°C. Acceptable by UT convention (descriptions are flavour, not mechanics documentation).
- Overall: description is thematically consistent with both implemented effects (stress + fatigue). No factual contradictions. Wording is slightly misleading in implying the threshold is "high" when it is mild, but this is minor.

## Balance Review
- Downside: +0.08 stress and +0.05 fatigue per ten in-game minutes while body temperature exceeds 38.0°C. Both stats are clamped at 1.0.
- Upside: none. Pure negative trait.
- Severity assessment: mild. The trigger condition (body temp > 38.0) requires the player to be actively overheating, which in PZ is an avoidable condition through clothing choice and environmental management. The cadence (every ten minutes) means the penalty accumulates slowly — stress reaches maximum in ~2 in-game hours of sustained overheating, fatigue in ~3.3 hours. Outside hot conditions the trait is entirely inert.
- Comparison to sibling `UT_coldsensitive`: structurally identical implementation (same deltas, same cadence, mirror threshold). Balance parity is maintained between the two temperature sensitivity traits. Neither is more severe than the other in UT.
- Comparison to source: source fires every tick with moodle-scaled increments. Even at Hyperthermia level 1, the source stress accumulation per second is orders of magnitude faster than UT's ten-minute cadence. UT is dramatically weaker than source on stress accumulation speed.
- Cost: -4 points. Source cost is **-2**. UT doubled the cost while delivering a weaker effect than source (slower cadence, but added fatigue). Adding fatigue partially compensates but does not reach source-level severity. At -4, this is one of the more expensive temperature traits if compared against vanilla PZ temperature-related traits. The cost inflation is unjustified relative to the reduced intensity compared to source.
- Fatigue addition: fatigue accumulation is the most significant departure from source. In PZ, fatigue leads to speed reduction and eventually forces rest. Adding fatigue to a heat-sensitivity trait makes the trait more impactful in sustained hot conditions than the source ever was, even though the per-event deltas are smaller. The two-stat approach is a reasonable design choice but is unattributed to source.
- Mutual exclusion gap: no exclusion between `UT_heatsensitive` and `UT_coldsensitive`. A player could take both simultaneously in UT. While mechanically the conditions are different (one triggers above 38°C, the other below 36°C), there is a narrow band (36–38°C) where neither triggers. Outside that band one or the other would always be applying. Taking both at -8 total for a character who is always either overheating or underheating may actually be under-priced for extreme-temperature playthroughs. Source explicitly excluded this combination.
- No interaction with weather moodle: source uses `MoodleType.Hyperthermia` as its trigger. UT uses raw `getBodyTemperature()`. In edge cases these can diverge: a player can have a body temperature above 38°C without reaching the Hyperthermia moodle (the moodle has its own internal threshold), and vice versa. UT's trigger may fire in situations where the source's would not.

## Regression Proof
- Existing tests (run_tests.lua): `"UniversalTraits:UT_heatsensitive"` appears at line 291 in the Phase 3b — Periodic-Check block. It is covered by the batch registration test that confirms all trait IDs register with `CharacterTrait` without error. No dedicated behaviour test exists.
- What the registration test proves: the trait ID successfully calls `CharacterTrait.register` at load time without error. It does not test any runtime behaviour.
- MockPlayer gap: `UTTestMocks.lua` does not define `getBodyTemperature` on the mock player object. Any behaviour test for this trait would require adding `getBodyTemperature` to the mock (or to `opts`) before the trait handler can be exercised in the test harness.
- Missing proof:
  - No test verifies that `handler()` applies +0.08 stress and +0.05 fatigue when body temperature > 38.0.
  - No test verifies that `handler()` is a complete no-op when body temperature is exactly 38.0 (boundary — not strictly greater than).
  - No test verifies that `handler()` is a complete no-op when body temperature is below 38.0 (e.g., 37.5°C).
  - No test verifies that stress is clamped at 1.0 (i.e., `math.min(1, 0.95 + 0.08)` = 1.0, not 1.03).
  - No test verifies that fatigue is clamped at 1.0.
  - No test verifies that `handler()` is a no-op for a player without the trait.
  - No test verifies that `handler()` is a no-op when `getPlayer()` returns nil.
- Minimum next tests if needed (requires `getBodyTemperature` added to MockPlayer):
  - Test: player with trait, `getBodyTemperature()` returns 38.5 → stress increases by 0.08, fatigue increases by 0.05.
  - Test: player with trait, `getBodyTemperature()` returns 38.0 (boundary) → stress and fatigue unchanged.
  - Test: player with trait, `getBodyTemperature()` returns 37.0 → stress and fatigue unchanged.
  - Test: player with trait, stress already 0.96, temp > 38.0 → stress becomes 1.0 (not 1.04).
  - Test: player with trait, fatigue already 0.97, temp > 38.0 → fatigue becomes 1.0 (not 1.02).
  - Test: player without trait → handler returns immediately; stats unchanged.
  - Test: `getPlayer()` returns nil → handler returns immediately; no error.

## Final Verdict
- Source origin: confirmed — trait originates from SomewhatTraits (`SWHeatSensitive`), source cost -2. The concept (heat causes stress via Hyperthermia moodle) is faithfully preserved in spirit.
- UT implementation: redesigned port. The core idea (overheating harms the player via stress) is retained, but every mechanical detail differs from source: trigger mechanism (body temperature threshold vs. Hyperthermia moodle level), scaling (binary flat delta vs. moodle-proportional per-tick), cadence (EveryTenMinutes vs. OnTick), and effects (stress + fatigue vs. stress only). The UT version is weaker per-tick but adds a second stat. The result is a slower, binary, dual-stat debuff rather than a fast, graduated, single-stat debuff.
- Sibling symmetry: `UT_heatsensitive` and `UT_coldsensitive` are exact mirror implementations. This is clean and maintainable.
- Description: thematically accurate, no factual contradictions, acceptable by UT conventions.
- Balance: cost is inflated (-4 vs. source -2) for a weaker-than-source stress effect. The added fatigue partially compensates but likely not to the full -4 value, especially given the avoidability of the trigger condition. Cost should be reviewed.
- Regression proof: registration only — no behaviour tests exist. MockPlayer requires `getBodyTemperature` before behaviour tests are possible.
- Action needed: balance review, mutual exclusion decision, test coverage
- Open gaps:
  1. **Cost mismatch**: source cost is -2; UT charges -4. The added fatigue effect partially justifies the increase but the reduced cadence (EveryTenMinutes vs. OnTick) and binary threshold likely leave the net severity below the -4 price point. Evaluate against peer traits at -4.
  2. **Mutual exclusion absent**: source explicitly excludes `SWColdSensitive` and `SWHeatSensitive` from co-existing. UT has no such exclusion between `UT_coldsensitive` and `UT_heatsensitive`. A player can take both, paying -8 for a character who is penalised at both temperature extremes. Decide whether this is intended or an oversight — add `MutuallyExclusiveTraits` to the script definition if not.
  3. **Boundary behaviour**: the condition is `> 38.0` (strict greater-than), not `>= 38.0`. The exact value 38.0 does not trigger. Document or adjust if a ≥ threshold is intended.
  4. **No interaction with Hyperthermia moodle**: UT's trigger can diverge from the visual Hyperthermia moodle (different internal thresholds). Consider whether using the moodle level (as source did) would produce more predictable, player-readable behaviour — the moodle is the player-visible signal for overheating.
  5. **No behaviour tests**: add `getBodyTemperature` to MockPlayer, then add: trigger-applies-both-stats, below-threshold-no-op, at-boundary-no-op, stress-clamp, fatigue-clamp, no-op-without-trait, no-op-on-nil-player.
  6. **Fatigue addition is undocumented design decision**: the addition of fatigue is a UT-originated effect with no source precedent. It is the most significant mechanical departure. If intentional, it should be noted in a design comment in the Lua file.
