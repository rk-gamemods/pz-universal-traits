# UT_immuneresponse

## Trait Summary

- UT trait id: UT_immuneresponse
- Source mod: SomewhatTraits (SWTraits)
- Source trait id: SWTraits:SWImmuneResponse
- Current cost: 6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/scripts/SWTraits_character_traits.txt` (script definition, Cost = 4, lines 48–56)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (source EN strings, lines 12–13)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (legacy client runtime, lines 257–280)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` (B42 server runtime, lines 144–157)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/client/SWTraitsCore.lua_` (B42 client runtime, lines 158–171)
- Source trigger path (legacy client): `Events.OnTick.Add(SWImmuneResponse)` — fires every game tick
- Source trigger path (B42 server): `Events.OnTick.Add(SWImmuneResponse)` — server-side tick
- Source trigger path (B42 client): `Events.OnPlayerUpdate.Add(SWImmuneResponse)` — fires on player update
- Source behavior (legacy client):
  - Guards: exits if `ribbit` (frog companion check) or `character` are nil; exits if `not hasSWImmuneResponse`; exits if `not bodyDamage:isInfected()`
  - Reads `stats:getFatigue()` and `stats:getEndurance()` and `moodles:getMoodleLevel(MoodleType.Sick)`
  - Computes `extraFatigue = timeMultiplier * (moodleLevel + 1) * 0.0003` and `extraEndurance = timeMultiplier * (moodleLevel + 1) * 0.001`
  - Reduces fatigue by `extraFatigue` (floored at `minFatigue`) and increases endurance by `extraEndurance` (capped at `maxEndurance`) per tick while infected
  - Does NOT directly manipulate infectionLevel
- Source behavior (B42 server):
  - Guards: exits if no player; exits if player does not have SWImmuneResponse; exits if `not player:getBodyDamage():isInfected()`
  - Computes `extraFatigue = dayLengthMultiplier * (moodleLevel + 1) * 0.0003` and `extraEndurance = (moodleLevel + 1) * 0.001` per tick
  - Calls `stats:remove(CharacterStat.FATIGUE, extraFatigue)` and `stats:add(CharacterStat.ENDURANCE, extraEndurance)`
- Source behavior (B42 client):
  - Same logic as B42 server but with `timeMultiplier * dayLengthMultiplier` scaling for fatigue; fired on `OnPlayerUpdate`
- Source description (EN): "Improves endurance recovery when infected with knox, based on Sickness moodle lvl."
- Source cost: 4 (across all reviewed versions: 42.13, 42.15); no mutual exclusion defined in source script blocks
- Source multiplayer flag: `DisabledInMultiplayer = false` in all source versions

## Current UT Evidence

### Structure

- Registered in registries.lua: unknown (not checked — confirmed present in `test/run_tests.lua` Phase 3b — Periodic-Check batch list at line 284, which confirms it is a known trait id)
- Defined in UT_character_traits.txt: yes — lines 1690–1698
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_immuneresponse`
  - `Cost = 6`
  - `UIName = UI_UT_immuneresponse`
  - `UIDescription = UI_UT_immuneresponseDesc`
  - No `MutuallyExclusiveTraits` field
- Translation strings present: yes — `UI_UT_immuneresponse = "Immune Response"` and `UI_UT_immuneresponseDesc = "Your body fights back hard and fast. When illness takes hold, your immune system kicks into overdrive and burns it out sooner."` in `media/lua/shared/Translate/EN/UI_EN.txt` (lines 527–528)
- Exclusions/grants correct: no mutual exclusion defined; source also had no exclusions, so this is consistent — however, see Balance Review for commentary on related UT traits
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_immuneresponse.lua`

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_immuneresponse.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1690–1698)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 527–528)
  - `test/run_tests.lua` (lines 284, 469, 1086–1094)
- Event registrations:
  - `Events.EveryTenMinutes.Add(handler)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` — standard guard
- Runtime chain (plain language):
  1. Every ten in-game minutes, fires `handler`.
  2. Gets the local player via `getPlayer()`; exits if no player.
  3. Checks if the player has `UniversalTraits:UT_immuneresponse` via `UTCore.hasTrait`; exits if not.
  4. Gets `player:getBodyDamage()`; if bodyDamage exists and `getInfectionLevel()` is non-nil and greater than 0, sets infectionLevel to `math.max(0, infectionLevel - 0.03)`.
  5. Gets `player:getStats()`; sets fatigue to `math.max(0, stats:getFatigue() - 0.02)`.
- Actual behavior (exact values):
  - Infection reduction: −0.03 per ten in-game minutes while infectionLevel > 0; floors at 0 (never goes negative)
  - Fatigue reduction: −0.02 per ten in-game minutes, unconditional (fires whether infected or not); floors at 0
  - No Sickness moodle scaling (present in source, absent in UT)
  - No endurance restoration (present in source, absent in UT)
  - No `isInfected()` guard: the fatigue reduction fires unconditionally whenever the player has the trait, regardless of infection state; the infectionLevel reduction has its own `> 0` guard

## Description Integrity

- Display name check: "Immune Response" — matches source exactly; appropriate
- Description check (full text): "Your body fights back hard and fast. When illness takes hold, your immune system kicks into overdrive and burns it out sooner."
- Accuracy of description:
  - "burns it out sooner" — directionally accurate for the infectionLevel drain (−0.03 per ten minutes while infected)
  - "When illness takes hold" — implies the fatigue reduction is conditional on being infected; this is false; the fatigue drain fires every ten minutes regardless of infection state
  - The description makes no mention of fatigue reduction at all, yet this is the second mechanic the runtime always applies
  - The description implies the trait targets infection specifically, but the UT runtime also reduces fatigue unconditionally, which is a persistent passive benefit entirely separate from infection
- Missing or misleading details:
  - The description omits the fatigue reduction mechanic entirely
  - The phrasing "when illness takes hold" incorrectly implies a conditional gate that does not exist for the fatigue effect
  - The source trait's primary mechanic was endurance recovery (scaled by Sickness moodle level) while infected; UT replaces this with direct infectionLevel drainage, which is a fundamentally different mechanism — the description does not reflect which mechanic is actually present
  - No quantitative information is given (−0.03 infection, −0.02 fatigue per ten minutes)

## Balance Review

- Upside 1 (infection drain): −0.03 infectionLevel per ten in-game minutes while infectionLevel > 0; at infectionLevel = 1.0, infection reaches 0 after ~33.3 ten-minute ticks (roughly 5.5 in-game hours at default day length). This is a substantial passive infection drain.
- Upside 2 (fatigue drain): −0.02 fatigue per ten in-game minutes, unconditional and always-on. Fatigue range is 0–1; this drains the full range in ~500 in-game minutes (~8.3 hours), providing a perpetual mild fatigue advantage even when healthy.
- Downside: none (positive trait with no penalty)
- Uptime: Infection drain is gated on infectionLevel > 0 (inactive when healthy). Fatigue drain is always active.
- Magnitude assessment:
  - The infection drain is meaningful and directly reduces a major survival threat; in vanilla, infection (from cuts/scratches with zombie bacteria, not zombie virus) clears naturally over time — this trait materially accelerates that process
  - The fatigue drain is a hidden permanent bonus not described anywhere; it effectively gives the player a slight ongoing stamina advantage at all times, not just during illness
  - The combination of both effects for 6 points is arguably generous, especially given the unconditional fatigue drain
- Peer comparison: `UT_immunocompromised` (Cost = −6, mutual exclusion with `UT_superimmune`) and `UT_superimmune` (Cost = 8, mutual exclusion with `UT_immunocompromised`) exist as the immune-system trait cluster in UT. `UT_immuneresponse` (Cost = 6) has no mutual exclusion with either, meaning a player could theoretically combine it with `UT_superimmune` for stacked immune benefit. Whether `UT_superimmune` applies independent effects that would make the combination degenerate requires separate audit, but the absence of a cross-exclusion is a design gap.
- Source cost vs. UT cost: source SWImmuneResponse cost was 4 (confirmed across 42.13 and 42.15); UT raises this to 6. The cost increase is not necessarily wrong given that UT adds a direct infectionLevel drain that the source never applied, but the unconditional fatigue drain further amplifies value beyond the source mechanic.
- Stack or exclusion notes: No mutual exclusion with `UT_immunocompromised` or `UT_superimmune` in UT definition block. Source had no mutual exclusions either, but UT has introduced an immune-system trait family that creates potential stacking concerns absent from the original.

## Regression Proof

- Existing tests:
  - `run_tests.lua` line 284: lists `"UniversalTraits:UT_immuneresponse"` in the Phase 3b — Periodic-Check batch array. Existence/registration check only.
  - `run_tests.lua` line 469: `dofile(...)` for `UT_immuneresponse.lua` — confirms the file loads without parse error.
  - `run_tests.lua` lines 1086–1094: named behavioral test — "immuneresponse reduces infection and fatigue every ten minutes"
    - Constructs `MockPlayer({ "UniversalTraits:UT_immuneresponse" }, { infectionLevel = 0.5, fatigue = 0.4 })`
    - Calls `withActivePlayer(player, function() Events.EveryTenMinutes:fire() end)`
    - Asserts `math.abs(player:getBodyDamage():getInfectionLevel() - 0.47) < 0.0001` (infection drops by 0.03)
    - Asserts `math.abs(player:getStats():getFatigue() - 0.38) < 0.0001` (fatigue drops by 0.02)
- What it proves: Core arithmetic is covered — a single fire of `EveryTenMinutes` with infection > 0 correctly reduces infection by 0.03 and fatigue by 0.02.
- Missing proof:
  - No test verifies that the infectionLevel drain stops at 0 (floor behavior) — e.g., infectionLevel = 0.01 should produce infectionLevel = 0, not a negative value
  - No test verifies behavior when infectionLevel is exactly 0 or nil (the `> 0` guard and nil guard paths)
  - No test verifies that fatigue reduction applies even when infectionLevel is 0 (confirming the unconditional nature of the fatigue drain)
  - No test verifies that the handler exits cleanly when the player does not have the trait
  - No test verifies behavior when `getBodyDamage()` returns nil
- Minimum next tests if needed:
  1. MockPlayer with `UT_immuneresponse`, `infectionLevel = 0.01`, fire `EveryTenMinutes`; assert infectionLevel equals 0.
  2. MockPlayer with `UT_immuneresponse`, `infectionLevel = 0`, `fatigue = 0.5`, fire `EveryTenMinutes`; assert infectionLevel still 0, assert fatigue equals 0.48 (confirming unconditional fatigue drain).
  3. MockPlayer without `UT_immuneresponse`, `infectionLevel = 0.5`, fire `EveryTenMinutes`; assert infectionLevel unchanged at 0.5.

## Final Verdict

- Source origin: proven — SomewhatTraits SWImmuneResponse confirmed in script definitions (42.13, 42.15), EN translations, and runtime (legacy client, B42 server, B42 client versions)
- UT implementation: substantially drifted — source mechanic was fatigue and endurance recovery scaled by Sickness moodle level while infected (no direct infectionLevel manipulation); UT replaces this with direct infectionLevel drain (−0.03 per ten minutes while infected) and an unconditional fatigue drain (−0.02 per ten minutes, always active). These are different mechanisms with a different scope of effect. Source's endurance recovery is entirely absent in UT.
- Description: inaccurate and incomplete — "burns it out sooner" is a vague but directionally acceptable description of the infectionLevel drain; however, the unconditional fatigue reduction is completely unmentioned, and the "when illness takes hold" framing falsely implies the fatigue drain is infection-gated. The description needs rewriting to reflect both mechanics accurately.
- Balance: possibly over-valued at 6 points — the infectionLevel drain alone could justify 4–5 points (matching or slightly exceeding source); the hidden unconditional fatigue drain adds unannounced permanent value. The combination without any mutual exclusion against `UT_superimmune` creates a potential stacking gap.
- Regression proof: partially protected — one behavioral test covers the core arithmetic path (infection > 0 and fatigue both reduce correctly on a single fire). Floor behavior, unconditional fatigue path, and no-trait guard are untested.
- Action needed: doc fix + test fix + design gap review
- Open gaps:
  - Rewrite `UI_UT_immuneresponseDesc` to accurately describe both effects: infection drain rate (−0.03 per ten in-game minutes while infection > 0) and unconditional fatigue drain (−0.02 per ten in-game minutes, always active)
  - Decide whether the fatigue drain should be conditional on infection (matching source intent) or remain unconditional (document the design choice explicitly)
  - Consider adding `MutuallyExclusiveTraits = UniversalTraits:UT_superimmune` to prevent stacking two immune-positive traits, or document why stacking is acceptable
  - Add behavioral tests for floor behavior (infectionLevel approaches 0), unconditional fatigue drain when healthy, and no-trait guard
  - Confirm whether `DisabledInMultiplayer = true` is intentional given the trait uses `getPlayer()` (single-player API); source had `DisabledInMultiplayer = false` — if multiplayer support is ever desired, the runtime would need to be converted to a player-parameter event
