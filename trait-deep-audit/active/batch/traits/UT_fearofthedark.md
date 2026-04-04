# UT_fearofthedark

## Trait Summary

- UT trait id: UT_fearofthedark
- Source mod: MoreSimpleTraits (MST)
- Source trait id: `FearoftheDark` (trait key: `"FearoftheDark"`)
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: **BUG FOUND** — wrong day/night API; panic rises 24/7, never recedes during day

---

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` (line 123) — trait registration
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` (lines 1040–1084) — runtime handler
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua` (line 103) — vanilla variant registration
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/client/MSTMainFile.lua` (lines 1040–1084) — vanilla variant runtime (identical logic)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt` (lines 76–77) — English strings
  - `research/installed-mods/EvolvingTraitsWorld/mods/Evolving Traits World - Mark Dynamic Traits/media/lua/shared/NPCs/ETWSubmodCreationMethods.lua` (line 278) — ETW alt-name registration confirming cross-mod awareness of `FearoftheDark`

- Source cost: **-1** (`TraitFactory.addTrait("FearoftheDark", ..., -1, ...)` in both MST and MSTVanilla). UT raised this to -4.

- Source display name: **"Nyctophobic"** (EN); description: `"Fear of the Dark. Gets panicked without light sources. Being in the dark for a long time also increases stress."`

- Source trigger: `Events.EveryOneMinute.Add(fearofthedarktrait)` — fires once per in-game minute.

- Source behavior (full): Checks `player:HasTrait("FearoftheDark")` and `not player:isAsleep()`. Gets `player:getCurrentSquare()` — returns early if nil. Reads `currsquare:getLightLevel(player:getPlayerNum())`. If `lightLevel <= 0.36` (dark square threshold):
  - If `currpanic <= 15`: adds `+5.9` to panic (flat base raise).
  - If player also has `Cowardly` trait AND `currpanic >= 1 AND <= 35`: adds a further `ZombRand(11)+20` (20–30) to panic, plus `+0.05` stress if `currstress <= 0.3`.
  - Otherwise (no Cowardly) AND `currpanic >= 1 AND <= 12`: adds `ZombRand(6)+15` (15–20) to panic, plus `+0.05` stress if `currstress <= 0.3`.
  - Clamps panic to [0, 99].
  - No day-recovery branch: panic is only ever raised by this handler, never reduced.

- Source stat affected: **panic** (primary); **stress** (secondary, small amount under certain conditions).

- Source key mechanic: **light-level sensor** (`getLightLevel` threshold 0.36), not a day/night flag. Works in dark rooms during daytime. Also checks sleep state.

- Source mutual exclusions: `FearoftheDark` vs `NightVision`, `Desensitized`, `Brave` (all three in both MST and MSTVanilla).

- Source `DisabledInMultiplayer`: not set to `true` in MST's own script (MST uses the old `TraitFactory.addTrait` path, not B42 script blocks). No explicit MP restriction in source.

---

## Current UT Evidence

### Structure

- **Runtime file:** `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_fearofthedark.lua`
- **Registry entry (registries.lua, line 262):**
  ```
  UTTraitsRegistries.UT_fearofthedark = CharacterTrait.register("UniversalTraits:UT_fearofthedark")
  ```
- **Script definition (UT_character_traits.txt, lines 1813–1821):**
  ```
  character_trait_definition UniversalTraits:UT_fearofthedark
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_fearofthedark,
      Cost = -4,
      UIName = UI_UT_fearofthedark,
      UIDescription = UI_UT_fearofthedarkDesc,
  }
  ```
  `DisabledInMultiplayer = true` is the universal default for all 198 UT trait definitions — not specific to this trait.

- **Translation strings (UI_EN.txt, lines 563–564):**
  ```
  UI_UT_fearofthedark     = "Fear of the Dark",
  UI_UT_fearofthedarkDesc = "Darkness is not just inconvenient for you, it is genuinely frightening. Being in the dark wears away at your composure.",
  ```

- **Test harness (run_tests.lua, line 290):** `"UniversalTraits:UT_fearofthedark"` is listed in the Phase 2 periodic handler traits array. It participates in the standard registry/script/translation completeness sweep but has no dedicated behaviour test.

---

### Runtime Trace

**Full Lua file (19 lines):**

```lua
-- UT_fearofthedark.lua
-- Fear of the Dark: panic rises at night, slowly subsides during the day

local TRAIT_ID = "UniversalTraits:UT_fearofthedark"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    if getGameTime():getNight() then
        stats:setPanic(math.min(1, stats:getPanic() + 0.04))
    else
        stats:setPanic(math.max(0, stats:getPanic() - 0.01))
    end
end

Events.EveryOneMinute.Add(handler)
```

**Step-by-step trace:**

1. `getPlayer()` — gets the local player; returns early if nil (correct).
2. `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe wrapper over `player:getTraits():contains("UniversalTraits:UT_fearofthedark")`; returns early if trait not held (correct).
3. `player:getStats()` — gets the stats object (standard; correct).
4. **`getGameTime():getNight()`** — **THIS IS THE BUG.** See Bug section below.
5. Night branch: `stats:setPanic(math.min(1, stats:getPanic() + 0.04))` — clamps to `[0, 1]`, adds `0.04` per minute to panic (correct arithmetic, wrong condition gate).
6. Day branch: `stats:setPanic(math.max(0, stats:getPanic() - 0.01))` — subtracts `0.01` per minute (correct arithmetic, but **never reached** due to the bug).
7. `Events.EveryOneMinute.Add(handler)` — fires once per in-game minute (cadence is correct for a gradual stat drift).

**UTCore.hasTrait implementation (UTCore_API.lua, lines 11–16):**
```lua
function UTCore.hasTrait(player, traitId)
    if not player then return false end
    local traits = player:getTraits()
    if not traits then return false end
    return traits:contains(traitId)
end
```
Fully nil-safe. No issues.

**Cadence math (intended design, if bug were fixed):**
- Night: `+0.04` panic/minute. Panic range is `[0, 1]`. Time to full panic from 0: 25 minutes of nighttime.
- Day: `-0.01` panic/minute. Time to drain from full panic: 100 minutes of daytime.
- Net: asymmetric — panic builds 4× faster than it drains. A full night (roughly 6–9 in-game hours) would push panic to cap. A full day would reduce it significantly but not necessarily to zero.

---

## Description Integrity

**UT display name:** "Fear of the Dark"
**UT description:** "Darkness is not just inconvenient for you, it is genuinely frightening. Being in the dark wears away at your composure."

**Source display name (EN):** "Nyctophobic"
**Source description (EN):** "Fear of the Dark. Gets panicked without light sources. Being in the dark for a long time also increases stress."

**Analysis:**

The UT description is thematically consistent and well-written. However, it is **mechanically inaccurate on two counts** due to the runtime bug:

1. The description implies darkness causes composure loss, but due to `getNight()` being always-truthy in Lua, panic rises unconditionally — day and night, indoors and outdoors, in light and in dark. The player never gets relief.
2. The description implies a day/recovery arc ("wears away"). The day-recovery branch (`-0.01`) exists in the code but is never reached.

Additionally, the UT implementation **drops the light-level mechanic** that the source mod used (`getLightLevel <= 0.36`). The source applied the effect only in genuinely dark squares regardless of time of day. The UT version intends a pure day/night flag instead — a legitimate design departure — but the flag call is broken.

The UT description also omits the stress component entirely, which is present in the source but not implemented in UT (UT only touches panic).

**Verdict: Description is accurate to intended design but describes behaviour that does not occur in practice. Fix the bug first, then the description becomes correct.**

---

## Bug Report

### BUG: `getGameTime():getNight()` is not a boolean — panic rises 24/7

**File:** `media/lua/shared/UniversalTraits/traits/UT_fearofthedark.lua`, line 11

**Root cause:**

`GameTime.getNight()` is a Java method defined as:
```java
public float getNight() {
    return ClimateManager.getInstance().getNightStrength();
}
```
It returns a `float` in the range `[0.0, 1.0]` representing night-sky strength (0 = full day, 1 = full night). It is **not** a boolean.

In Lua (including the Kahlua VM used by PZ), only `false` and `nil` are falsy. **All numbers — including `0.0` — are truthy.** Therefore `if getGameTime():getNight() then` evaluates to `true` at all times of day, including noon when `getNightStrength()` returns `0.0`.

**Effect:**
- The `else` branch (day recovery: `-0.01/min`) is **never reached**.
- Panic rises by `+0.04` every in-game minute, always, with no recovery. Within ~25 minutes of game time the player is at max panic (1.0) and stays there permanently.
- The trait is essentially broken: it inflicts constant maximum panic rather than a day/night oscillation.

**Confirmed unique to this trait:** `getNight()` appears in only this one file across the entire UniversalTraits repo. All other time-sensitive UT traits (`UT_albino`, `UT_larkperson`, `UT_owlperson`) correctly use `getGameTime():getTimeOfDay()` compared against numeric thresholds.

**Correct API options:**
- `getGameTime():isNight()` — Java boolean method, returns `true` between dusk and dawn (confirmed in `GameTime.java`, line 1669). This is the direct boolean equivalent and the correct fix.
- `getGameTime():getTimeOfDay()` compared against `getDawn()` / `getDusk()` — more verbose but explicit and season-aware (pattern used by UT_albino, UT_larkperson, UT_owlperson).

**Fix:**
```lua
-- BEFORE (broken):
if getGameTime():getNight() then

-- AFTER (correct):
if getGameTime():isNight() then
```

---

## Balance Review

**Source balance:** Cost -1 in MST. Light-level-gated: only activates in dark squares (`lightLevel <= 0.36`). Panic adds 5.9–30 per minute (MST panic scale appears to use 0–100), capped at 99. Strong but avoidable by staying in lit areas or sleeping.

**UT balance (intended, if fixed):** Cost -4. Pure day/night gate, no light-level check. Intended panic drift: `+0.04/min` night, `-0.01/min` day. Panic scale 0–1. At 25 minutes of night → full panic (1.0). At 100 minutes of day → full recovery. This is a significant debuff with a clear day-safe window.

**UT balance (actual, with bug):** Cost -4. Panic rises to 1.0 within ~25 game-minutes and stays there forever. Effectively one of the harshest debuffs in the mod — permanent max panic. Cost of -4 is wildly too low for this actual effect.

**Design departure from source:** UT removes the light-level sensor and the stress secondary effect. Instead it uses a pure day/night clock. This is a valid simplification, but it changes the nature of the trait: in UT (as intended) the player can mitigate by playing only during daylight hours; in MST the player must always carry a light source. The UT description ("Being in the dark wears away at your composure") better fits the MST mechanic. If the day/night design is intentional, the description should say "At night, your panic slowly builds. During the day it subsides."

**Cost assessment (post-fix):** -4 is defensible for a pure day/night panic oscillation. The daytime recovery (-0.01/min) is generous enough that an active player can manage it. Compare UT_panicattacks at -6 for random panic spikes — fearofthedark at -4 with a predictable nightly schedule is reasonable.

---

## Regression Proof

**Test harness coverage:** `"UniversalTraits:UT_fearofthedark"` is listed in `run_tests.lua` line 290 within the Phase 2 periodic traits array. This means the standard test sweep verifies:
- Registry entry exists and the trait can be registered without error.
- Script definition block is present and parses correctly.
- Translation keys `UI_UT_fearofthedark` and `UI_UT_fearofthedarkDesc` are present in `UI_EN.txt`.

**What the test suite does NOT cover:**
- It does not simulate `EveryOneMinute` firing and verify that panic changes correctly under day vs. night conditions.
- There is no mock for `getGameTime()` that could catch the `getNight()` vs `isNight()` confusion.
- The bug would survive all current tests undetected.

**Regression tests needed after fix:**
1. Night condition: mock `getGameTime():isNight()` returning `true`, fire handler, assert `stats:getPanic()` increased by 0.04 (or clamped to 1.0).
2. Day condition: mock `getGameTime():isNight()` returning `false`, fire handler with panic > 0, assert `stats:getPanic()` decreased by 0.01 (or floored to 0.0).
3. No-player guard: fire handler with `getPlayer()` returning nil — assert no error.
4. Trait-absent guard: fire handler with player lacking the trait — assert panic unchanged.

---

## Final Verdict

**Status: FAIL — runtime bug makes the trait non-functional as designed.**

| Check | Result |
|---|---|
| Registry entry present | PASS |
| Script definition present | PASS |
| Translation keys present | PASS |
| Correct cost in script | PASS (-4) |
| DisabledInMultiplayer set | PASS (universal default for all UT traits) |
| Runtime logic correct | **FAIL** — `getNight()` returns float, always truthy in Lua; `else` branch (day recovery) unreachable |
| Description matches behaviour | FAIL (describes intended behaviour, not actual) |
| Description matches intended design | PASS |
| Source mechanic faithfully ported | PARTIAL — day/night design is an intentional departure from MST's light-level mechanic; the departure itself is acceptable, but the implementation of the day/night check is broken |
| Balance appropriate | PASS for intended design; **FAIL** for actual behaviour (trait is vastly overpowered with bug present) |
| Test coverage adequate | FAIL — no behavioural test; bug passes all existing checks |

**Required fix:**

In `media/lua/shared/UniversalTraits/traits/UT_fearofthedark.lua`, line 11:

```lua
-- Replace:
if getGameTime():getNight() then
-- With:
if getGameTime():isNight() then
```

After fixing, sync `release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_fearofthedark.lua` (identical copy confirmed at same line).

**Optional follow-up:**
- Consider whether to restore the light-level mechanic from MST (more thematic: dark rooms during day should also trigger it).
- Consider whether to add a mild stress component to match source flavour.
- Add a behavioural unit test for day/night branches.
- Update description if the day/night design (rather than light-level design) is confirmed intentional: clarify that the trigger is nightfall, not literal darkness.
