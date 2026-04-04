# Trait Audit: UT_alcoholic_I

**Audit date:** 2026-04-04
**Auditor:** Claude Code (claude-sonnet-4-6)
**Trait ID:** `UniversalTraits:UT_alcoholic_I`
**Display name:** Alcoholic (Mild)
**Tier:** I of III (alcoholic series)

---

## Trait Summary

| Field | Value |
|---|---|
| Trait ID | `UniversalTraits:UT_alcoholic_I` |
| Display name | Alcoholic (Mild) |
| Cost | -4 (negative = disadvantage) |
| Profession trait | No |
| Multiplayer | Disabled |
| Event hook | `Events.EveryTenMinutes` |
| Effective cadence | Every 30 in-game minutes |
| Condition | `getDrunkenness() < 0.05` (functionally sober) |
| Effect | `setStress(min(1, stress + 0.05))` |
| Mutual exclusions | `UT_alcoholic_II`, `UT_alcoholic_III` |
| Also excluded by | `UT_ironliver` (positive trait, separate MET entry) |
| XPBoosts | None |

---

## Source Evidence

**Source mod:** DynamicTraitsExpandedMoodles (Steam Workshop mod "Dynamic Traits")
**Source file:** `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/NPCs/DTEMMainCreationMethods.lua`, line 473
**Source file (runtime):** `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMAddictions.lua`

### What the source mod does

The source mod defines a single monolithic vanilla `Alcoholic` trait using `TraitFactory.addTrait`:

```lua
-- DTEMMainCreationMethods.lua:473
TraitFactory.addTrait("Alcoholic", getText("UI_trait_Alcoholic"), -8,
    getText("UI_trait_AlcoholicDesc"), false)
```

**Source trait cost:** -8 points (single tier, no splitting)
**Source description:** "You need alcohol flowing through your veins to feel good."

### Source runtime behavior (DTEMAddictions.lua)

The source `DTEMalcoholicTrait(player)` function implements a complex escalating withdrawal system with a persistent counter (`DTEMalcoholicTrait` in modData):

- **Sober state** (`MoodleType.Drunk == 0`): counter increments +1 per call; `timeSinceLastDrink` also increments
- **Drunk state**: counter decrements by `(drunkLevel * 3)` per call; `timeSinceLastDrink` resets to 0
- **Lucky/unlucky modifier**: 1-in-30 chance adds a random bonus/penalty
- **Counter clamp:** -50,000 to +50,000

Withdrawal effects (all probabilistic, not guaranteed each tick):

| Threshold (timeSinceLastDrink minutes) | Effect |
|---|---|
| >1440 (24 h) | Anger, Stress +0.10 (ZombRand(55) gated), Unhappiness +3 (ZombRand(60) gated) |
| >2880 (48 h) | Fatigue +0.05 (ZombRand(70) gated), Head pain (ZombRand(180) gated) |
| >4320 (72 h) | Food sickness (ZombRand(70) gated) |

Trait can be dynamically removed/added at runtime:
- Counter > 44,640: trait removed (recovery)
- Counter < -44,640: trait added (onset)

**Key divergence from UT implementation:** The source trait is a single, dynamic, escalating system. UT splits this into three static tiers and uses a much simpler, deterministic stress ramp with no time-gated withdrawal progression and no dynamic trait acquisition/removal.

---

## Current UT Evidence

### Structure

#### Registration (`media/registries.lua`, line 266)

```lua
UTTraitsRegistries.UT_alcoholic_I = CharacterTrait.register("UniversalTraits:UT_alcoholic_I")
```

Registration is present and correct. The returned value is the string `"UniversalTraits:UT_alcoholic_I"` (via `CharacterTrait.register`), which is what `UTCore.hasTrait` checks via `traits:contains(traitId)`.

#### Script definition (`media/scripts/UT_character_traits.txt`, lines 1853-1862)

```
character_trait_definition UniversalTraits:UT_alcoholic_I
{
    IsProfessionTrait = false,
    DisabledInMultiplayer = true,
    CharacterTrait = UniversalTraits:UT_alcoholic_I,
    Cost = -4,
    UIName = UI_UT_alcoholic_I,
    UIDescription = UI_UT_alcoholic_IDesc,
    MutuallyExclusiveTraits = UniversalTraits:UT_alcoholic_II;UniversalTraits:UT_alcoholic_III,
}
```

All required fields are present. No `XPBoosts` field (correct — this is a penalty trait with no skill bonuses). MET correctly lists II and III but NOT the trait itself.

**Note:** `UT_ironliver` (a positive trait, lines ~1560-1570) lists all three alcoholic tiers in its own MET block:
```
MutuallyExclusiveTraits = UniversalTraits:UT_alcoholic_I;UniversalTraits:UT_alcoholic_II;UniversalTraits:UT_alcoholic_III,
```
This means the engine enforces iron-liver/alcoholic exclusion bidirectionally. Correct.

#### Translation (`media/lua/shared/Translate/EN/UI_EN.txt`, lines 575-576)

```lua
UI_UT_alcoholic_I     = "Alcoholic (Mild)",
UI_UT_alcoholic_IDesc = "You enjoy a drink more than most. Every 30 in-game minutes while sober (drunkenness below 0.05), stress increases by +0.05.",
```

Both keys present. UIName key `UI_UT_alcoholic_I` matches script definition. UIDescription key `UI_UT_alcoholic_IDesc` matches script definition.

---

### Runtime Trace

**Full source of `media/lua/shared/UniversalTraits/traits/UT_alcoholic_I.lua` (19 lines):**

```lua
-- UT_alcoholic_I.lua
-- Alcoholic I: mild alcohol craving triggers stress every ~30 in-game minutes when sober

local TRAIT_ID = "UniversalTraits:UT_alcoholic_I"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local md = player:getModData()
    md.UT_alcoholicI_ticks = (md.UT_alcoholicI_ticks or 0) + 1
    if md.UT_alcoholicI_ticks % 3 ~= 0 then return end
    local stats = player:getStats()
    if stats:getDrunkenness() < 0.05 then
        stats:setStress(math.min(1, stats:getStress() + 0.05))
    end
end

Events.EveryTenMinutes.Add(handler)
```

#### Step-by-step trace

**Line 19:** `Events.EveryTenMinutes.Add(handler)` registers `handler` to fire every 10 in-game minutes. This fires unconditionally for all players every 10 minutes, regardless of trait possession.

**Line 7:** `local player = getPlayer()` — retrieves the local player. Returns `nil` in a server-only context or before player is created.

**Line 8:** `if not player then return end` — nil guard. Safe.

**Line 9:** `if not UTCore.hasTrait(player, TRAIT_ID) then return end` — calls `UTCore.hasTrait`.

Tracing into `UTCore.hasTrait` (`UT_CORE/media/lua/shared/UTCore/UTCore_API.lua`, lines 11-16):
```lua
function UTCore.hasTrait(player, traitId)
    if not player then return false end
    local traits = player:getTraits()
    if not traits then return false end
    return traits:contains(traitId)
end
```
- Double nil-checks player and traits list
- Returns `traits:contains("UniversalTraits:UT_alcoholic_I")` — a Java `ArrayList` contains check on the trait ID string
- If player does not have trait I: handler exits here (cheap, no further work done)

**Lines 10-11:** `local md = player:getModData()` and `md.UT_alcoholicI_ticks = (md.UT_alcoholicI_ticks or 0) + 1`
- `getModData()` returns a Lua table persisted to save data
- Key: `UT_alcoholicI_ticks` (string key, unique to this trait)
- First call: initializes to 0 then increments to 1 (the `or 0` handles nil-on-first-load)
- Increments unconditionally on every call where trait is held

**Line 12:** `if md.UT_alcoholicI_ticks % 3 ~= 0 then return end`
- The modulo-3 gate. Handler fires every 10 in-game minutes; this gate passes only on ticks 3, 6, 9, 12, ... (i.e., every 3rd call)
- **Effective cadence: 10 minutes × 3 = 30 in-game minutes**
- On ticks 1 and 2 (and 4, 5, etc.): exits here with no stat effect

**Line 13:** `local stats = player:getStats()` — retrieves the `IsoGameCharacter` stats object.

**Line 14:** `if stats:getDrunkenness() < 0.05 then`
- `getDrunkenness()` returns a float in [0, 1]
- Threshold 0.05 = 5% drunkenness. This is effectively the "functionally sober" threshold
- At 0.05 or above (any noticeable alcohol in system): no stress applied — the craving is satisfied

**Line 15:** `stats:setStress(math.min(1, stats:getStress() + 0.05))`
- Reads current stress, adds 0.05, caps at 1.0
- `math.min` prevents overflow above the 1.0 ceiling
- No floor protection needed (stress + positive delta cannot go below zero)
- **Stress delta per effective tick: +0.05**
- **Maximum stress accumulation rate (from trait alone, no mitigation): +0.05 per 30 minutes**
- **Time to max stress from zero: 20 effective ticks = 600 in-game minutes = 10 in-game hours**

#### Tick accumulation and save/load behavior

`UT_alcoholicI_ticks` persists to save data via `getModData()`. On load:
- If `UT_alcoholicI_ticks` was 1 or 2 at save time, it resumes from that position — no skip or reset
- The counter never resets; it grows monotonically for the lifetime of the save
- **Integer overflow risk:** Lua numbers are doubles (64-bit floats). The integer precision ceiling is 2^53 ≈ 9×10^15. At one increment per 10 in-game minutes, this will never overflow in any realistic play session.
- **Modulo correctness:** `(x % 3 == 0)` for all positive integers, including very large ones, is reliable in Lua with double precision up to at least 2^53.

#### UTCore hooks used

| Hook | Purpose |
|---|---|
| `UTCore.hasTrait(player, traitId)` | Nil-safe trait possession check via `traits:contains()` |

No other UTCore APIs are called. No `applyXPMultiplier`, `applyBleedDecayMult`, `applyStrengthCarryWeight`, or state-flag methods are used. This is one of the simplest possible trait implementations.

---

## Description Integrity

**Claimed in UI description:** "Every 30 in-game minutes while sober (drunkenness below 0.05), stress increases by +0.05."

**Verified against code:**

| Claim | Code reality | Match? |
|---|---|---|
| "Every 30 in-game minutes" | `EveryTenMinutes` × `% 3` = 30-minute cadence | YES |
| "while sober" | `getDrunkenness() < 0.05` | YES — threshold matches |
| "drunkenness below 0.05" | `< 0.05` is strict less-than; at exactly 0.05 no stress is applied | YES, description says "below 0.05" which is accurate |
| "stress increases by +0.05" | `setStress(min(1, stress + 0.05))` | YES — delta is exactly +0.05, capped at 1 |

**Description is fully accurate.** No discrepancy between stated behavior and code.

---

## Balance Review

### Within the alcoholic tier series

| Trait | Cost | Cadence | Stress delta/tick | Condition | Additional effect |
|---|---|---|---|---|---|
| UT_alcoholic_I (Mild) | -4 | 30 min | +0.05 | drunk < 0.05 | none |
| UT_alcoholic_II (Moderate) | -7 | 10 min | +0.10 | drunk < 0.05 | none |
| UT_alcoholic_III (Severe) | -10 | 1 min | +0.05 stress | drunk < 0.10 | +0.03 panic/min when drunk < 0.05 |

**Stress rate comparison:**

| Tier | Stress per in-game hour (60 min) if continuously sober |
|---|---|
| I (Mild) | 2 ticks × 0.05 = +0.10/hr |
| II (Moderate) | 6 ticks × 0.10 = +0.60/hr |
| III (Severe) | 60 ticks × 0.05 = +3.00/hr (capped at 1.0 max) |

The tier I rate of +0.10/hr is mild: it takes 10 in-game hours of continuous sobriety to reach max stress from zero. By comparison, tier II takes ~1.67 hours and tier III saturates in ~20 minutes. The escalation curve between tiers is steep (6× from I to II, then 5× from II to III), which is appropriate for "mild/moderate/severe" framing.

**Cost evaluation:**

- Tier I at -4 points buys very little pressure. Stress at +0.05 per 30 min is easily offset by in-game activities (sleeping, reading, boredom reduction). A player who drinks alcohol occasionally (even once every in-game day) will rarely accumulate meaningful stress from this trait alone.
- The source mod's single `Alcoholic` trait was -8 points for a far more punishing system (time-gated withdrawal with anger, pain, and food sickness). UT's tier I is arguably generous at -4 given how mild its effect is. This may be intentional (tier split means players can choose severity).
- **No balance bug.** The -4 cost for tier I is defensible.

### Interaction with alcohol consumption

The trait only suppresses when `drunkenness >= 0.05`. In PZ Build 42, a single sip of most alcoholic beverages raises drunkenness above 0.05. This means the trait is very easy to satisfy: one drink every ~30 in-game minutes keeps stress suppressed entirely. This reinforces the "mild" framing but also means the -4 cost feels like free points to players who drink casually.

### Interaction with stress management

Stress is reduced by: sleep, reading, watching TV, boredom mechanics. At +0.05 per 30 min accumulation rate, any single sleep cycle will outpace the trait's entire day of sober stress. This confirms tier I is genuinely mild.

---

## Regression Proof

### Test coverage in `test/run_tests.lua`

**Direct test for UT_alcoholic_I registration:** ABSENT.

The test suite contains a spot-check for `UT_alcoholic_II`:
```lua
-- line 104
test("UT_alcoholic_II registered", function()
    assert_eq(UTTraitsRegistries.UT_alcoholic_II, "UniversalTraits:UT_alcoholic_II")
end)
```

`UT_alcoholic_I` and `UT_alcoholic_III` have **no dedicated registration spot-check tests**.

However, `UT_alcoholic_I` IS included in the exhaustive ID list that the mass-registration coverage test iterates (lines 292-293):
```lua
"UniversalTraits:UT_alcoholic_I", "UniversalTraits:UT_alcoholic_II",
"UniversalTraits:UT_alcoholic_III", "UniversalTraits:UT_addictedtocaffeine",
```

This list is used by `collectRegisteredIdsFromRegistries` and checked against the `registries.lua` entries, so the registration is indirectly covered. The mass test would catch a missing registration entry. It would **not** catch a wrong ID string in the Lua handler itself.

**Runtime behavior tests:** None. No test exercises the `handler()` function, the `% 3` cadence gate, the `getDrunkenness()` threshold, or the stress delta math. This is consistent with the rest of the codebase (no trait has runtime behavior tests in the current suite).

**Summary of coverage gaps:**
1. No dedicated `assert_eq(UTTraitsRegistries.UT_alcoholic_I, ...)` spot-check (low risk — covered by mass test)
2. No test for `TRAIT_ID` constant correctness in the Lua file vs. the registry entry
3. No test for the `% 3` tick-gate math
4. No test for stress accumulation behavior

---

## Final Verdict

**Status: PASS with one observation**

### What is correct

- Registration: present and correct in `registries.lua` (line 266)
- Script definition: complete and correctly formed — all fields present, cost is -4, MET lists II and III correctly
- Translation: both UI name and description keys present and accurate
- Runtime logic: clean, minimal, correct — nil guards on player, UTCore.hasTrait guard, tick-based cadence math is sound, stress delta matches description exactly
- Tier consistency: TRAIT_ID constant in Lua (`"UniversalTraits:UT_alcoholic_I"`) matches the script definition key and the registry entry
- Release sync: `release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_alcoholic_I.lua` is byte-identical to the source file (confirmed by matching content in both search results)
- No dead code, no unreachable branches, no missing nil guards
- No modData key collisions with other traits (key `UT_alcoholicI_ticks` is unique)

### Observation (not a bug)

**Missing spot-check test for UT_alcoholic_I registration.** The test at line 104 covers `UT_alcoholic_II` by name but `UT_alcoholic_I` has no equivalent. It is covered by the mass-list test, but a per-trait named assertion would make failures more diagnosable. Low priority.

### Source fidelity note

The UT implementation is a clean re-imagining rather than a port. The source mod's `Alcoholic` trait is a complex, dynamic, escalating withdrawal system with randomized multi-stage effects and runtime trait mutation. UT replaces this with three deterministic, tiered, stress-only variants. The tier-I variant captures the "mild craving" spirit of the source at a fraction of the mechanical complexity. The simplification is intentional and appropriate for a universal trait system.
