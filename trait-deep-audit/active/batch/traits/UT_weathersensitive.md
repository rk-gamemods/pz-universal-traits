# Trait Audit: UT_weathersensitive

**Audit date:** 2026-04-04
**Auditor:** Claude (automated deep-audit)
**Status:** ISSUES FOUND

---

## 1. Trait Summary

| Field | Value |
|---|---|
| Trait ID | `UniversalTraits:UT_weathersensitive` |
| Display name | Weather Sensitive |
| Cost | -2 (negative = drawback) |
| Source mod | MoreSimpleTraits (`WeatherSensitive`) |
| Multiplayer | `DisabledInMultiplayer = true` |
| Profession trait | `IsProfessionTrait = false` |
| MET group | None |
| Handler event | `Events.EveryTenMinutes` |
| Stat affected | Stress |

---

## 2. Source Evidence

**Source mod:** MoreSimpleTraits  
**Files:**
- `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua`
- `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua`
- `MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua`
- `MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/client/MSTMainFile.lua`

**Source registration (MSTMainCreationMethods.lua line 113):**
```lua
local weathersensitive = TraitFactory.addTrait(
    "WeatherSensitive",
    getText("UI_trait_weathersensitive"),
    -2,
    getText("UI_trait_weathersensitivedesc"),
    false,   -- not profession trait
    true     -- available as NPC trait
);
```
Cost in source: **-2**. No XPBoosts. The sixth argument `true` marks it as available for NPC assignment.

**Source runtime logic (`MSTMainFile.lua`, function `MSTWeatherSensitiveTrait`, lines 279–359, fired `EveryTenMinutes`):**

The MST implementation is a multi-step forecast-tracking system:

1. Reads `ClimateManager` -> `ClimateForecaster` for today (`getForecast(0)`) and tomorrow (`getForecast(1)`).
2. Maintains a `ModData` accumulator `MSThoursSinceLastRain` (clamped 0–288, representing ~24 in-game hours at 12 ticks/hour).
3. **Accumulator logic (first `HasTrait` block):**
   - Today is bad weather (blizzard / tropical storm / storm / heavy rain): `+1`
   - Today is clear: `-1`
   - Tomorrow is bad: `+2`
   - Tomorrow is clear: `-(ZombRand(1)+2)` = `-2` or `-3`
4. **Pain application (second `HasTrait` block):**
   - Today bad weather: if Head pain <= 8 and `ZombRand(19)==0`: `MSTincreasePain(player, 0, "Head", ZombRand(27)+27)` — head pain 27–53
   - Tomorrow bad and accumulator <= 143: `MSTincreasePain(player, ZombRand(4), "Head", ZombRand(45))` — additional pain 0–44, emote 1/11 chance
   - Tomorrow clear and accumulator >= 144: `MSTincreasePain(player, ZombRand(4), "Head", ZombRand(40))` — pain 0–39, emote 1/11 chance (barometric pressure drop)

**Source forage penalty (MSTMainCreationMethods.lua lines 314–320):**
```lua
forageSkills["WeatherSensitive"] = {
    name          = "WeatherSensitive",
    type          = "trait",
    visionBonus   = -0.2,
    weatherEffect = -3,
    darknessEffect = -3,
}
```
Source grants: -0.2 vision bonus, -3 weather effect, -3 darkness effect in foraging.

**Source mutual exclusion:** `TraitFactory.setMutualExclusive("WeatherSensitive", "Pluviophile")` — conditional on DynamicTraits mod being active (MoreSimpleTraits full version only; commented out in Vanilla version).

---

## 3. Current UT Evidence

### 3a. Structure

**Script definition** (`media/scripts/UT_character_traits.txt`, lines 1793–1801):
```
character_trait_definition UniversalTraits:UT_weathersensitive
{
    IsProfessionTrait = false,
    DisabledInMultiplayer = true,
    CharacterTrait = UniversalTraits:UT_weathersensitive,
    Cost = -2,
    UIName = UI_UT_weathersensitive,
    UIDescription = UI_UT_weathersensitiveDesc,
}
```
- No `MutuallyExclusiveTraits` block. Source had a conditional mutex with "Pluviophile" (DynamicTraits). UT has no equivalent trait for Pluviophile, so the omission is correct.
- `DisabledInMultiplayer = true` matches the source's NPC-only flag pattern.

**Registry** (`media/registries.lua`, line 260):
```lua
UTTraitsRegistries.UT_weathersensitive = CharacterTrait.register("UniversalTraits:UT_weathersensitive")
```
Confirmed present. Positioned in the block between `UT_bigorexia` and `UT_panicattacks`.

**Translation** (`media/lua/shared/Translate/EN/UI_EN.txt`, lines 557–558):
```lua
UI_UT_weathersensitive      = "Weather Sensitive",
UI_UT_weathersensitiveDesc  = "Your mood shifts with the sky. Storms drag you down; clear days lift you up more than they should.",
```
Both keys present. Script references `UI_UT_weathersensitive` and `UI_UT_weathersensitiveDesc` — keys match exactly.

**Test coverage** (`test/run_tests.lua`, line 289):
```lua
"UniversalTraits:UT_weathersensitive", "UniversalTraits:UT_panicattacks",
```
Listed in the Phase 3b — Periodic-Check trait ID array (25 traits). Covered by the `all 198 trait IDs registered with CharacterTrait` test. No dedicated per-trait moddata or handler test exists.

### 3b. Runtime Trace

**File:** `media/lua/shared/UniversalTraits/traits/UT_weathersensitive.lua` (17 lines total)

```lua
-- UT_weathersensitive.lua
-- Weather Sensitive: random weather-triggered mood fluctuations

local TRAIT_ID = "UniversalTraits:UT_weathersensitive"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if ZombRand(3) == 0 then
        local stats = player:getStats()
        stats:setStress(math.min(1, stats:getStress() + 0.05))
    end
end

Events.EveryTenMinutes.Add(handler)
```

**Step-by-step trace:**

1. **`Events.EveryTenMinutes.Add(handler)`** — registers the handler at file load time (shared/ scope, fires for all local players). Cadence: every 10 real-time minutes (~2 in-game hours at default speed).

2. **`getPlayer()`** — returns the local player object (player index 0 only). No multi-player iteration. Safe nil check on line 8 exits early if no player.

3. **`UTCore.hasTrait(player, TRAIT_ID)`** — resolves via `UTCore_API.lua`:
   ```lua
   function UTCore.hasTrait(player, traitId)
       if not player then return false end
       local traits = player:getTraits()
       if not traits then return false end
       return traits:contains(traitId)
   end
   ```
   Calls `player:getTraits()` (returns Java `ArrayList<String>`) then `:contains(traitId)`. Nil-safe on both player and traits list. Correct.

4. **`ZombRand(3) == 0`** — uniform integer in [0, 2]. Probability of firing: **1/3 (~33.3%)**.

5. **`player:getStats():getStress() + 0.05`** — stress increment: **+0.05** per firing tick. Stress is clamped via `math.min(1, ...)` — cannot exceed 1.0.

6. **No weather check.** The handler fires unconditionally on every EveryTenMinutes tick as long as the player has the trait. The name and description both reference weather but the implementation has no `getClimateManager()` call, no forecast query, and no conditional branch on current weather.

**Effective cadence at default game speed (1 min real = ~1 hr game):**
- `EveryTenMinutes` fires every 10 real minutes = ~10 in-game hours.
- Expected firings per 24 in-game hours: ~2.4 ticks.
- Expected stress applied per 24 in-game hours: 2.4 × (1/3) × 0.05 = **+0.04 stress/day** on average.

**UTCore hooks used:** `UTCore.hasTrait` only. No `UTCore.applyXPMultiplier`, `UTCore.applyBleedDecayMult`, `UTCore.registerPeriodicHandler`, or moddata helpers used.

**ModData:** None read or written. No persistent state.

---

## 4. Description Integrity

| Check | Result |
|---|---|
| Display name matches trait identity | PASS — "Weather Sensitive" is accurate |
| Description references weather mood shifts | PASS — "Your mood shifts with the sky. Storms drag you down; clear days lift you up more than they should." |
| Description implies bidirectional effect | FAIL — description says "clear days lift you up more than they should" implying a positive effect on clear days; the implementation applies only a negative stress increase regardless of weather |
| Description implies weather-reactive logic | FAIL — "Storms drag you down" implies the effect is conditional on stormy weather; the implementation applies stress randomly on every tick with no weather check |
| Cost vs effect accuracy | MARGINAL — cost -2 is low for what is described, but the actual effect is also weaker than described |
| XPBoost mentions in description | PASS — none mentioned, none implemented |
| Source cost preserved | PASS — source cost -2, UT cost -2 |

**Key mismatch:** The description promises a two-sided, weather-aware effect (storms = bad, clear = better-than-normal). The implementation delivers a flat unconditional random stress drip with no weather awareness. A player reading the description would expect:
- Stress/pain spikes specifically during storms.
- Some positive relief or reduced stress during clear weather.

Neither is implemented.

---

## 5. Balance Review

**Source (MST) vs UT comparison:**

| Aspect | MST (source) | UT (current) |
|---|---|---|
| Mechanism | Forecast-aware head pain, barometric tracking | Flat random stress tick |
| Stat affected | Head pain (body damage layer) | Stress (stats layer) |
| Weather conditional | Yes — only fires pain during/before storms | No — fires every tick regardless |
| Positive mechanic | Implicit (pain subsides on clear stretches) | None |
| Foraging penalty | -0.2 vision, -3 weather effect, -3 darkness | None |
| Cost | -2 | -2 |
| ModData | Yes (`MSThoursSinceLastRain` accumulator) | None |

**Effect magnitude:**
- UT stress gain: average ~+0.04 per 24 in-game hours. At this rate, moving stress from 0 to 1.0 takes ~25 in-game days with no natural decay. In practice stress decays through sleep and calm periods, making this a very mild background pressure.
- MST: head pain 27–53 on stormy days (1/20 chance per 10 min tick), plus anticipatory pain before storms. Significantly more impactful and more thematic.

**Balance verdict:** The UT implementation is milder than the source but is also less complex. The -2 cost is defensible for the *actual* (mild unconditional stress drip) behavior, but is under-priced relative to what the description implies (storm-conditional pain/stress spikes). A player who picks this expecting storm-reactive behavior receives a much weaker always-on stress nudge instead.

**Missing features vs source:**
1. No weather-conditioned firing.
2. No head pain (source primary mechanic lost entirely).
3. No barometric accumulator (anticipatory pain before storms).
4. No foraging penalties.
5. No positive clear-weather relief.

---

## 6. Regression Proof

**Test file:** `test/run_tests.lua` line 289  
**Coverage type:** Registration presence only (Phase 3b list membership)

The trait ID `"UniversalTraits:UT_weathersensitive"` appears in the `expected_ids` array under "Phase 3b — Periodic-Check (25)". This means:
- The `all 198 trait IDs registered with CharacterTrait` test will catch a missing `CharacterTrait.register()` call.
- The `script costs match the current balance decisions` test does NOT include a cost assertion for `UT_weathersensitive` — only `packmule`, `preparedpack`, `quickworker`, `slowworker` are spot-checked there. A cost change would not be caught.

**No handler-level test exists.** There is no test that:
- Verifies the handler fires on `EveryTenMinutes`.
- Verifies stress increments by 0.05 when `ZombRand(3)==0`.
- Verifies stress is clamped at 1.0.
- Verifies no-op when trait is absent.

**Regression gaps:**
- Cost regression: undetected.
- Handler behaviour regression: undetected.
- Weather-check regression (if weather logic is ever added): no test to pin the contract.

---

## 7. Final Verdict

**ISSUES FOUND — two independent problems.**

### Issue 1 (CRITICAL): Description does not match implementation

The description states a weather-reactive bidirectional effect. The implementation is a flat unconditional stress drip. A player choosing this trait based on the description will be misled about both the trigger condition and the presence of any positive mechanic.

**Resolution options (choose one):**
- **A — Fix the description** to match the actual behavior: e.g. "A restless mind that never quite settles — stress builds at random as your mood shifts for no clear reason." Remove weather references entirely.
- **B — Fix the implementation** to match the description: add a `getClimateManager()` check, apply stress/pain only during storms, and reduce or remove stress on clear days.

Option B is more interesting gameplay but significantly increases implementation complexity. Option A is a one-line description fix.

### Issue 2 (MINOR): Foraging penalties not carried over from source

MST applies `-0.2 visionBonus`, `-3 weatherEffect`, `-3 darknessEffect` to the foraging system for `WeatherSensitive`. UT has no foraging integration. This is a silent feature gap — not a crash risk, but reduces fidelity to the source trait. Acceptable if UT intentionally omits foraging integration across all traits (verify consistency with other weather-adjacent traits like `UT_coldsensitive` and `UT_heatsensitive`).

### Issue 3 (MINOR): No dedicated regression test

The handler has no unit test. If the stress delta, ZombRand range, or event registration is changed in the future, no test will catch it. A minimal test verifying handler output at `ZombRand==0` and no-op at `ZombRand!=0` should be added.

### Checklist

- [x] Trait ID registered in `registries.lua`
- [x] Script definition present in `UT_character_traits.txt`
- [x] Cost matches source (-2)
- [x] Translation keys present and non-empty (`UI_UT_weathersensitive`, `UI_UT_weathersensitiveDesc`)
- [x] Translation key names match script references exactly
- [x] In `run_tests.lua` expected_ids list
- [x] Handler registered to correct event (`EveryTenMinutes`)
- [x] `UTCore.hasTrait` guard present and correct
- [x] Stress clamped to 1.0
- [x] No moddata leaks (none used)
- [ ] **FAIL: Description accurately describes actual behavior**
- [ ] **FAIL: Implementation matches description (weather-conditioned logic absent)**
- [ ] WARN: Foraging penalties not ported
- [ ] WARN: No handler-level regression test
