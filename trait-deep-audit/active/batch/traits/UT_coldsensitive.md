# UT_coldsensitive

## Trait Summary

- UT trait id: UT_coldsensitive
- Source mod: SomewhatTraits (SomewhatTraitsCore)
- Source trait id: SWTraits:SWColdSensitive (trait key: "SWColdSensitive")
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` (lines 28, 97–98, 112–113) — legacy registration and mutual exclusion
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.12/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` (lines 28, 98, 113) — B42.12 registration
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.12/media/lua/client/SWSomewhatTraitsCore.lua` (lines 115, 474–488, 1074) — B42.12 client implementation
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.13/media/lua/server/SWTraitsCore_server.lua` (lines 269–278) — B42.13 server implementation
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` (lines 269–278) — B42.15 server implementation
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/registries.lua` (line 31) — B42.13 registry
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/registries.lua` (line 31) — B42.15 registry
- Source cost: -2 (B42.13 and B42.15 registry comment: `-- -2`). UT raised this to -4.
- Source description: inline comment in MainCreationMethods.lua: "being cold increases stress, based on Hypothermia moodle lvl".
- Source trigger path:
  - B42.12 client (SWSomewhatTraitsCore.lua): `Events.OnTick.Add(SWColdSensitive)` — fires every game tick.
  - B42.13/B42.15 server (SWTraitsCore_server.lua): `Events.OnTick.Add(SWColdSensitive)` — fires every game tick.
- Source behavior (B42.12 client): Reads `moodleLevel` from `MoodleType.Hypothermia` (0–4 scale). Computes `extraStress = timeMultiplier * moodleLevel * 0.01`. If `moodleLevel > 0` and current non-cigarette stress is below `maxStress`, adds `extraStress` to stress, capped at `maxStress`.
- Source behavior (B42.13/B42.15 server): Reads `moodleLevel` from `MoodleType.HYPOTHERMIA`. Computes `extraStress = moodleLevel * 0.01` (no `timeMultiplier`). Calls `stats:add(CharacterStat.STRESS, extraStress)` unconditionally if the trait is held.
- Source stat affected: **stress** in all reviewed versions. The Hypothermia moodle level gates and scales the increment.
- Source multipliers: `moodleLevel * 0.01` per tick (server); `timeMultiplier * moodleLevel * 0.01` per tick (client). At Hypothermia level 4, the server version adds 0.04 stress per tick; at level 1, it adds 0.01 per tick. Hypothermia level 0 produces no effect in the client version (explicit guard) and effectively zero in the server version (0 * 0.01 = 0).
- Source mutual exclusions: `TraitFactory.setMutualExclusive("SWColdSensitive", "SWHeatSensitive")` — the source explicitly prevents stacking with the heat-sensitive trait.
- Source `DisabledInMultiplayer`: not declared as disabled in the reviewed source scripts; the B42 server implementation runs on the server tick, implying multiplayer was intended to work.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes (`media/registries.lua` line 263)
  - `UTTraitsRegistries.UT_coldsensitive = CharacterTrait.register("UniversalTraits:UT_coldsensitive")`
  - Neighbors in the registry: `UT_fearofthedark` above, `UT_heatsensitive` immediately below — positional sibling pairing is preserved.
- Registered in test harness: yes (`test/run_tests.lua` line 290, grouped in "Phase 3b — Periodic-Check (25)")
- Defined in UT_character_traits.txt: yes (lines 1823–1831)
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_coldsensitive`
  - `Cost = -4`
  - `UIName = UI_UT_coldsensitive`
  - `UIDescription = UI_UT_coldsensitiveDesc`
  - No `MutuallyExclusiveTraits` declared
- Translation strings present: yes (`media/lua/shared/Translate/EN/UI_EN.txt` lines 566–567)
  - `UI_UT_coldsensitive = "Cold Sensitive"`
  - `UI_UT_coldsensitiveDesc = "Cold cuts through you faster than it should. Even mild temperature drops affect your body and your focus."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_coldsensitive.lua`)
- Release copy in sync: yes (`release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_coldsensitive.lua` is byte-identical to the source)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_coldsensitive.lua` (full file, 17 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 11–16) — `UTCore.hasTrait` implementation
  - `media/scripts/UT_character_traits.txt` (lines 1823–1831)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 566–567)
  - `test/run_tests.lua` (line 290)
- Event registrations:
  - `Events.EveryTenMinutes.Add(handler)` — fires once every ten in-game minutes, triggered from `GameTime.java` line 732 via `LuaEventManager.triggerEvent("EveryTenMinutes")`.
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe trait check: calls `player:getTraits():contains(traitId)`. Returns false if player or traits list is nil.
- Runtime chain (plain language):
  1. Every ten in-game minutes: retrieves the local player via `getPlayer()`. If nil, exits immediately.
  2. Calls `UTCore.hasTrait(player, "UniversalTraits:UT_coldsensitive")`. If the player does not hold the trait, exits.
  3. Calls `player:getBodyTemperature()`. If the result is **>= 36.0**, exits — no effect.
  4. If `getBodyTemperature() < 36.0`: retrieves `player:getStats()`.
  5. Sets stress to `math.min(1, stats:getStress() + 0.08)` — adds +0.08 to current stress, capped at 1.0.
  6. Sets fatigue to `math.min(1, stats:getFatigue() + 0.05)` — adds +0.05 to current fatigue, capped at 1.0.
- Actual behavior (exact values):
  - Trigger condition: `player:getBodyTemperature() < 36.0` — raw body temperature reading, not the Hypothermia moodle level. The game's normal body temperature is approximately 37°C; mild cooling drops it below 36.0 before the Hypothermia moodle necessarily appears.
  - Stress increment per ten minutes: flat +0.08, regardless of how far below 36.0 the temperature is.
  - Fatigue increment per ten minutes: flat +0.05, regardless of temperature depth.
  - Both stats are capped at 1.0 via `math.min`.
  - No severity scaling: temperature at 35.9 and temperature at 30.0 produce identical +0.08/+0.05 increments.
  - No Hypothermia moodle involvement: the source used `MoodleType.Hypothermia` as both gate and scalar. UT bypasses the moodle system entirely and reads body temperature directly.
  - Fatigue effect is entirely new: the source added only stress. UT adds both stress and fatigue.
  - Frequency: `EveryTenMinutes` (once per ten in-game minutes) versus source's `OnTick` (every frame). These are structurally different cadences; the absolute per-ten-minute accumulation cannot be directly equated to the per-tick source values without knowing the source `timeMultiplier`.
  - No indoor/outdoor check, no weather interaction.

## Description Integrity

- Display name check: "Cold Sensitive" — matches the source display name "SWColdSensitive" (formatted identically). Pass.
- Description check: `"Cold cuts through you faster than it should. Even mild temperature drops affect your body and your focus."`
- Issues found:
  1. **"Affect your body and your focus" understates the actual effect.** "Your body" maps to fatigue and "your focus" maps to stress — this is plausible flavour language and not technically false. However, the description does not name the stats or their magnitudes (+0.08 stress, +0.05 fatigue per ten minutes), so players cannot reason about the severity.
  2. **"Even mild temperature drops" is ambiguous about the threshold.** The trigger is `getBodyTemperature() < 36.0`. In-game, temperatures can drop below 36.0 before Hypothermia moodles appear. "Mild temperature drops" suggests a very low bar, which is accurate, but the specific 36.0°C threshold is not communicated. Players expecting the effect to track the Hypothermia moodle (as the source did) will be surprised that it fires at sub-moodle temperatures.
  3. **No mention of fatigue.** The source only applied stress. UT adds both stress and fatigue. The addition of fatigue is a behavioral expansion not present in the source and not disclosed in the description. "Your focus" (stress) and "your body" (fatigue) are too vague to serve as adequate disclosure of two separate stat hits.
  4. **No severity communication.** The description implies the effect scales with how cold it is ("even mild" implies worse at extreme cold). The implementation is flat-rate: severity of cold below 36.0 has no effect on the increment size. The description is not false, but it creates a false impression of proportionality.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside per ten in-game minutes while `bodyTemperature < 36.0`:
  - +0.08 stress (capped at 1.0)
  - +0.05 fatigue (capped at 1.0)
- Uptime: depends on the player's environment. Cold weather, rain, wet clothing, and night exposure can drop body temperature below 36.0. Players who actively manage temperature (cooked food, warm clothes, shelter) may rarely trigger the condition. In winter seasons or rainy climates, the condition is nearly constant.
- Rate analysis:
  - Stress: fills from 0 to 1.0 in approximately 125 in-game minutes of continuous cold exposure (12.5 intervals of +0.08). Natural stress decay competes; net depends on sleep and baseline decay rate.
  - Fatigue: fills from 0 to 1.0 in approximately 200 in-game minutes (20 intervals of +0.05). Fatigue has its own recovery mechanics (sleep).
  - The dual-stat drain is the primary balance concern: stress causes anxiety moodle progression and debuffs morale-related actions; fatigue causes tiredness progression and impairs physical performance. A trait that simultaneously ratchets both stats creates compounding pressure during cold exposure.
- Source cost comparison: source cost was -2. UT charges -4. The UT implementation is substantially more severe than the source:
  - Source: only stress, scaled by Hypothermia moodle level (0–4), fires on every tick scaled by `timeMultiplier`.
  - UT: stress + fatigue (a new effect), flat-rate, fires every ten minutes at any sub-36.0 temperature.
  - The removal of moodle scaling (which meant no effect at moodle level 0) and addition of fatigue justify a higher cost than -2. However, the magnitude of -4 versus -2 (a 100% increase) requires scrutiny.
- Peer comparison:
  - `UT_heatsensitive` (line 1833–1841 of script): identical structure — `Cost = -4`, same description template, same 36.0 threshold (inverted: `> 38.0`), same +0.08 stress / +0.05 fatigue pattern. The two traits are perfectly symmetric in the UT implementation.
  - `UT_weathersensitive` exists as a separate trait adjacent in the registry; its relationship to cold/heat sensitivity is not audited here but potential thematic overlap warrants awareness.
  - No mutual exclusion between `UT_coldsensitive` and `UT_heatsensitive` is declared in UT despite the source explicitly preventing this stack. A player could theoretically hold both in UT.
- Stack or exclusion notes:
  - **Missing mutual exclusion with `UT_heatsensitive`.** The source enforced `TraitFactory.setMutualExclusive("SWColdSensitive", "SWHeatSensitive")`. UT has no `MutuallyExclusiveTraits` in either the cold or heat script blocks. This allows a player to select both traits in character creation, receiving -8 points total for two traits that the source author intended to be mutually exclusive.
  - No exclusion from other temperature-interacting traits.
- Cost verdict: -4 is defensible given the dual-stat impact (stress + fatigue) and the low threshold (below 36.0, not tied to the Hypothermia moodle). However, the missing mutual exclusion with `UT_heatsensitive` means a player can bank -8 points by taking both, then manage temperature to avoid triggering either simultaneously — a potential exploit path worth closing.

## Regression Proof

- Existing test: `"UniversalTraits:UT_coldsensitive"` is listed in the Phase 3b registration sweep (`test/run_tests.lua` line 290), confirming the trait ID is registered with `CharacterTrait`. This is the only observed test reference.
- What it proves: the trait ID `"UniversalTraits:UT_coldsensitive"` exists in the CharacterTrait registry and appears in the expected ID list. It does not test runtime behavior.
- Missing proof:
  1. No test that `EveryTenMinutes` fires `handler` and increments stress by exactly +0.08 when `getBodyTemperature() < 36.0`.
  2. No test that `EveryTenMinutes` fires `handler` and increments fatigue by exactly +0.05 when `getBodyTemperature() < 36.0`.
  3. No test that `getBodyTemperature() >= 36.0` suppresses both increments.
  4. No test that stress is capped at 1.0 when pre-increment value is >= 0.93 (+0.08 would exceed 1.0).
  5. No test that fatigue is capped at 1.0 when pre-increment value is >= 0.96 (+0.05 would exceed 1.0).
  6. No test that the handler exits cleanly when `getPlayer()` returns nil.
  7. No test that the handler exits when the player does not have the trait.
- Minimum next test if needed: "coldsensitive: stress and fatigue increment by 0.08 and 0.05 when bodyTemperature < 36.0" — mock `getPlayer()` returning a player with the trait and `getBodyTemperature() = 35.9`, initial stress = 0.0 and fatigue = 0.0, fire `EveryTenMinutes`, assert stress equals 0.08 and fatigue equals 0.05. Also: "coldsensitive: no effect when bodyTemperature >= 36.0" — same setup with `getBodyTemperature() = 36.0`, assert stress and fatigue remain 0.0.

## Final Verdict

- Source origin: proven — SomewhatTraits `SWColdSensitive` is the confirmed source. Reviewed in legacy, B42.12 client, and B42.13/B42.15 server forms. Source cost (-2) does not match UT cost (-4); UT doubled the point refund.
- UT implementation: intentionally redesigned with significant divergences from source:
  1. **Trigger mechanism changed**: source gated and scaled the effect on the Hypothermia moodle level (0–4). UT bypasses the moodle system and reads `player:getBodyTemperature()` directly with a fixed 36.0°C threshold. The UT trigger fires at sub-moodle temperatures; the source only fired when the Hypothermia moodle was active (level ≥ 1).
  2. **Severity scaling removed**: source scaled `extraStress` by moodle level — level 4 produced 4× the effect of level 1. UT applies a flat +0.08/+0.05 regardless of how far below 36.0 the temperature is. Mild and severe cold are identical.
  3. **Fatigue added**: source applied only stress. UT applies both stress (+0.08) and fatigue (+0.05). This is a new behavioral dimension not present in the source and not communicated in the description.
  4. **Event cadence changed**: source ran `OnTick` (every frame). UT runs `EveryTenMinutes` (every ten in-game minutes). These are not comparable in rate without the source `timeMultiplier`; structurally the UT approach is more deliberate and frame-rate-independent.
  5. **Mutual exclusion with `UT_heatsensitive` dropped**: source explicitly prevented stacking with `SWHeatSensitive`. UT has no mutual exclusion declared in either trait's script block, enabling a player to hold both simultaneously.
  6. **Multiplayer disabled**: source ran on the server (implying multiplayer intent). UT marks `DisabledInMultiplayer = true`. This is a UT-wide policy and is likely intentional.
- Description: adequate but incomplete. The flavour language ("cold cuts through you faster," "even mild temperature drops") is appropriate and not factually false. However, it does not disclose the fatigue component, the specific 36.0°C threshold, or the flat (non-scaling) nature of the effect. Correction or expansion is warranted.
- Balance: the cost increase from -2 (source) to -4 (UT) is partially justified by the added fatigue drain and the lower effective trigger threshold (sub-moodle temperatures). The missing mutual exclusion with `UT_heatsensitive` is an oversight that creates a double-dip exploit path worth closing. The flat rate across all cold severities is a deliberate simplification but weakens the proportional feel.
- Regression proof: registration confirmed; zero behavioral tests exist for this trait.
- Action needed:
  1. **Add mutual exclusion with `UT_heatsensitive`.** Declare `MutuallyExclusiveTraits = UniversalTraits:UT_heatsensitive,` in the `UT_coldsensitive` script block (and reciprocally in `UT_heatsensitive`). This restores the source's design intent and closes the double-dip exploit.
  2. **Update description to disclose the fatigue component.** Something like: "Cold cuts through you faster than it should. Even mild temperature drops leave you stressed and drained." — replacing "your body and your focus" with explicit fatigue and stress references.
  3. **Evaluate the flat-rate design decision.** The source scaled by Hypothermia moodle level; the UT version applies the same rate at all temperatures below 36.0. Consider whether mild cold (35.9°C) should genuinely hit as hard as extreme cold (30°C). If proportionality is desired, re-introduce a severity multiplier keyed to how far below 36.0 the temperature is, or re-anchor the trigger to the Hypothermia moodle level.
  4. **Add behavioral tests** for: both increments fire when `bodyTemperature < 36.0`, no effect when `bodyTemperature >= 36.0`, stress cap at 1.0, fatigue cap at 1.0, and handler guard conditions (nil player, trait absent).
- Open gaps:
  - Source `timeMultiplier` value is not available in the reviewed files; the per-tick rate of the legacy client version cannot be quantitatively compared to the UT per-ten-minute rate.
  - The interaction between `UT_coldsensitive` and `UT_weathersensitive` (a neighboring trait in the registry) is not audited here; if `UT_weathersensitive` also penalises during cold conditions, the two may stack unintentionally.
  - No body temperature API documentation was found; the exact scale of `player:getBodyTemperature()` in B42 and whether 36.0 is the correct threshold for "mild cold" versus the Hypothermia moodle onset temperature was not independently verified against PZCodebase sources.
