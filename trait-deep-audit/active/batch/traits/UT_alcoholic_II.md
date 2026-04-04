# Trait Audit: UT_alcoholic_II

**Audit date:** 2026-04-04
**Auditor:** Claude Code (claude-sonnet-4-6)
**Trait ID:** `UniversalTraits:UT_alcoholic_II`
**Display name:** Alcoholic (Moderate)
**Tier:** II of III (alcoholic series)

---

## Trait Summary

| Field | Value |
|---|---|
| Trait ID | `UniversalTraits:UT_alcoholic_II` |
| Display name | Alcoholic (Moderate) |
| Cost | -7 (negative = disadvantage) |
| Profession trait | No |
| Multiplayer | Disabled |
| Event hook | `Events.EveryTenMinutes` |
| Effective cadence | Every 10 in-game minutes (no tick-gate) |
| Condition | `getDrunkenness() < 0.05` (functionally sober) |
| Effect | `setStress(min(1, stress + 0.10))` |
| Mutual exclusions | `UT_alcoholic_I`, `UT_alcoholic_III` |
| Also excluded by | `UT_ironliver` (positive trait, separate MET entry) |
| XPBoosts | None |

---

## Source Evidence

**Source mod:** DynamicTraitsExpandedMoodles (Steam Workshop mod "Dynamic Traits")
**Source file (registration):** `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/NPCs/DTEMMainCreationMethods.lua`, line 473
**Source file (runtime):** `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMAddictions.lua`

### What the source mod does

The source mod defines a single monolithic `Alcoholic` trait (not split into tiers) using `TraitFactory.addTrait`:

```lua
-- DTEMMainCreationMethods.lua:473
TraitFactory.addTrait("Alcoholic", getText("UI_trait_Alcoholic"), -8,
    getText("UI_trait_AlcoholicDesc"), false)
```

**Source trait cost:** -8 points (single tier; UT_alcoholic_II maps to the middle of this band)

### Source runtime behavior (DTEMAddictions.lua)

The source `DTEMalcoholicTrait(player)` function implements a complex escalating withdrawal system with a persistent counter (`DTEMalcoholicTrait` in modData):

- **Sober state** (`MoodleType.Drunk == 0`): counter increments +1 per call; `timeSinceLastDrink` also increments
- **Drunk state**: counter decrements by `(drunkLevel * 3)` per call; `timeSinceLastDrink` resets to 0
- **Lucky/unlucky modifier**: 1-in-30 chance adds a random bonus/penalty
- **Counter clamp:** -50,000 to +50,000

Withdrawal effects (all probabilistic, keyed to `timeSinceLastDrink`):

| Threshold (timeSinceLastDrink in minutes) | Effect |
|---|---|
| > 1440 (24 h) | Anger, Stress +0.10 (ZombRand(55) gated), Unhappiness +3 (ZombRand(60) gated) |
| > 2880 (48 h) | Fatigue +0.05 (ZombRand(70) gated), Head pain (ZombRand(180) gated) |
| > 4320 (72 h) | Food sickness (ZombRand(70) gated) |

Trait can be dynamically removed/added at runtime:
- Counter > 44,640: trait removed (recovery)
- Counter < -44,640: trait added (onset)

**Key divergence from UT implementation:** The source is a single dynamic trait with time-gated, probabilistic, multi-effect withdrawal and runtime trait mutation. UT splits the concept into three static, deterministic tiers. `UT_alcoholic_II` captures the "moderate craving" middle band: no escalation logic, no persistent state, pure stress accumulation at a rate higher than tier I but without the panic effect of tier III.

---

## Current UT Evidence

### Structure

#### Registration (`media/registries.lua`, line 267)

```lua
UTTraitsRegistries.UT_alcoholic_II = CharacterTrait.register("UniversalTraits:UT_alcoholic_II")
```

Registration is present and correctly ordered (after `UT_alcoholic_I` at line 266, before `UT_alcoholic_III` at line 268). The value stored in `UTTraitsRegistries.UT_alcoholic_II` is the string `"UniversalTraits:UT_alcoholic_II"`, which is what `UTCore.hasTrait` checks via `traits:contains(traitId)`.

#### Script definition (`media/scripts/UT_character_traits.txt`, lines 1864-1873)

```
character_trait_definition UniversalTraits:UT_alcoholic_II
{
    IsProfessionTrait = false,
    DisabledInMultiplayer = true,
    CharacterTrait = UniversalTraits:UT_alcoholic_II,
    Cost = -7,
    UIName = UI_UT_alcoholic_II,
    UIDescription = UI_UT_alcoholic_IIDesc,
    MutuallyExclusiveTraits = UniversalTraits:UT_alcoholic_I;UniversalTraits:UT_alcoholic_III,
}
```

All required fields are present. No `XPBoosts` field (correct — penalty trait, no skill bonuses). MET lists I and III but not the trait itself (correct).

**Note:** `UT_ironliver` (lines ~1564-1570 in the same file) lists all three alcoholic tiers in its own MET block:
```
MutuallyExclusiveTraits = UniversalTraits:UT_alcoholic_I;UniversalTraits:UT_alcoholic_II;UniversalTraits:UT_alcoholic_III,
```
This enforces iron-liver/alcoholic exclusion bidirectionally via the engine. Correct.

#### Translation (`media/lua/shared/Translate/EN/UI_EN.txt`, lines 578-579)

```lua
UI_UT_alcoholic_II     = "Alcoholic (Moderate)",
UI_UT_alcoholic_IIDesc = "Alcohol is a regular need rather than a want. Every 10 in-game minutes while sober (drunkenness below 0.05), stress increases by +0.10.",
```

Both keys present. `UI_UT_alcoholic_II` matches the `UIName` field in the script definition. `UI_UT_alcoholic_IIDesc` matches the `UIDescription` field. No missing keys, no orphaned keys.

---

### Runtime Trace

**Full source of `media/lua/shared/UniversalTraits/traits/UT_alcoholic_II.lua` (16 lines):**

```lua
-- UT_alcoholic_II.lua
-- Alcoholic II: moderate alcohol craving triggers significant stress when sober

local TRAIT_ID = "UniversalTraits:UT_alcoholic_II"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    if stats:getDrunkenness() < 0.05 then
        stats:setStress(math.min(1, stats:getStress() + 0.10))
    end
end

Events.EveryTenMinutes.Add(handler)
```

#### Step-by-step trace

**Line 16:** `Events.EveryTenMinutes.Add(handler)` registers `handler` to fire every 10 in-game minutes. This event fires for all players unconditionally — the trait guard is inside the function, not at registration.

**Line 7:** `local player = getPlayer()` — retrieves the local player. Returns `nil` server-side before a player is created.

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
- Double nil-checks: player object and the traits list
- `traits:contains("UniversalTraits:UT_alcoholic_II")` — Java `ArrayList` contains check on the full namespaced string
- If player does not hold this trait: handler exits here, no further computation

**Line 10:** `local stats = player:getStats()` — retrieves the `IsoGameCharacter` stats object. Not nil-guarded here; in the PZ runtime `getStats()` never returns nil for a valid `IsoPlayer`, so this is acceptable.

**Line 11:** `if stats:getDrunkenness() < 0.05 then`
- `getDrunkenness()` returns a float in [0, 1]
- Threshold 0.05 = 5% drunkenness — the "functionally sober" boundary
- At drunkenness 0.05 or above: no stress is applied (craving considered satisfied)
- The threshold is strict less-than: at exactly 0.05 the condition is false, no stress

**Line 12:** `stats:setStress(math.min(1, stats:getStress() + 0.10))`
- Reads current stress value, adds 0.10 (ten percent of the 0-1 range)
- `math.min(1, ...)` clamps the result at the maximum of 1.0
- No lower-bound protection needed (adding a positive delta cannot produce a negative result)
- **Stress delta per tick: +0.10**

#### Cadence analysis

Unlike tier I, there is **no tick-gate modulo division**. Every `EveryTenMinutes` event that passes the sober check applies the full +0.10 delta.

- `EveryTenMinutes` fires 6 times per in-game hour
- **Stress per hour (continuously sober): 6 × 0.10 = +0.60**
- **Time to max stress from zero (no mitigation): 10 ticks = 100 in-game minutes ≈ 1 hour 40 minutes**

Compare to tier I: `EveryTenMinutes` with `% 3` gate = effective 30-minute cadence, +0.05/tick = +0.10/hr. Tier II applies stress 6× faster per hour.

#### ModData usage

`UT_alcoholic_II` does **not** use `getModData()`. There is no persistent state, no tick counter, and no save/load concern. The handler is entirely stateless: it reads two stats and conditionally writes one. This is simpler than tier I (which maintains `UT_alcoholicI_ticks`) and tier III (also stateless).

#### UTCore hooks used

| Hook | Purpose |
|---|---|
| `UTCore.hasTrait(player, TRAIT_ID)` | Nil-safe trait possession check via `traits:contains()` |

No other UTCore APIs used. No `applyXPMultiplier`, no `applyBleedDecayMult`, no `UTCore.hasAnyTrait`, no state flags. This is the simplest possible stateless implementation in the series.

---

## Description Integrity

**Claimed in UI description:** "Alcohol is a regular need rather than a want. Every 10 in-game minutes while sober (drunkenness below 0.05), stress increases by +0.10."

**Verified against code:**

| Claim | Code reality | Match? |
|---|---|---|
| "Every 10 in-game minutes" | `Events.EveryTenMinutes` with no tick-gate | YES — fires on every event, no skip |
| "while sober" | `getDrunkenness() < 0.05` | YES |
| "drunkenness below 0.05" | `< 0.05` strict less-than; at exactly 0.05 no stress | YES — "below 0.05" is accurate |
| "stress increases by +0.10" | `setStress(min(1, stress + 0.10))` | YES — delta is exactly +0.10, capped at 1 |

**Description is fully accurate.** Every claim in the UI text is confirmed verbatim by the code. No discrepancy.

---

## Balance Review

### Within the alcoholic tier series

| Trait | Cost | Cadence | Stress delta/tick | Additional effects | Stress per in-game hour (sober) |
|---|---|---|---|---|---|
| UT_alcoholic_I (Mild) | -4 | 30 min (10 min × % 3) | +0.05 | none | +0.10/hr |
| UT_alcoholic_II (Moderate) | -7 | 10 min (no gate) | +0.10 | none | +0.60/hr |
| UT_alcoholic_III (Severe) | -10 | 1 min | +0.05 stress (drunk < 0.10) | +0.03 panic/min (drunk < 0.05) | +3.00 stress/hr + up to +1.80 panic/hr |

**Tier II vs. tier I:**
- Stress accumulation rate is 6× higher (0.60/hr vs. 0.10/hr)
- Cost increase is 3 points (-7 vs. -4), a 75% cost increase for 6× the pressure
- No additional stats affected beyond stress — tier II is purely a stress-rate escalation

**Tier II vs. tier III:**
- Tier III fires on `EveryOneMinute` (6× faster than tier II's `EveryTenMinutes`)
- Tier III has a wider drunkenness threshold (0.10 vs. 0.05) — harder to satisfy
- Tier III adds panic on top of stress
- Cost increase from II to III is 3 more points (-10 vs. -7) — proportionate to the jump in severity

**Tier II threshold evaluation:**
The 0.05 drunkenness threshold shared with tier I means the trait is still easily satisfied: one drink raises drunkenness well above 0.05. At +0.60/hr, however, a player who goes 2 in-game hours without a drink (e.g., overnight sleep without pre-drinking) will accumulate 1.20 points of stress clamped to 1.0 — reaching max stress. This is a meaningful penalty that will show up in gameplay, unlike tier I which can be ignored for hours.

**Cost/effect evaluation:**
- -7 points for 0.60 stress/hr is reasonable. Stress at max reduces recovery rates and can trigger anxiety responses. A player must actively maintain some alcohol in their system, or accept significant stress buildup every sleep cycle if they did not drink beforehand.
- The source mod's single `Alcoholic` trait was -8 for a far more punishing dynamic system. Tier II at -7 is slightly cheaper than the source's equivalent but with a deterministic, predictable effect instead of probabilistic withdrawal escalation. This is appropriate for UT's simplified model.
- **No balance bug.** The -7 cost for tier II is defensible and internally consistent with the series.

### Interaction with alcohol consumption

At the 0.05 threshold, even a small drink satisfies the trait for at least one 10-minute tick, often several. The player must drink roughly once per 10-minute block during waking play to keep stress suppressed entirely. This creates a light but persistent resource pressure — more noticeable than tier I, but far less demanding than tier III's 1-minute cadence.

### Interaction with stress management

Stress is mitigated by sleep, reading, TV, and boredom mechanics. At +0.60/hr, a 10-hour sleep cycle accumulates at most +6.0 theoretical stress (capped at 1.0) during sober sleep. This means a player who sleeps without pre-drinking will routinely wake at max stress. Tier II thus creates a real choice between pre-sleep drinking and starting each day stressed.

---

## Regression Proof

### Test coverage in `test/run_tests.lua`

**Dedicated spot-check test** — PRESENT (line 104):

```lua
test("UT_alcoholic_II registered", function()
    assert_eq(UTTraitsRegistries.UT_alcoholic_II, "UniversalTraits:UT_alcoholic_II")
end)
```

This is the only trait in the alcoholic series with its own named registration test. It verifies that `registries.lua` stores exactly the string `"UniversalTraits:UT_alcoholic_II"` under `UTTraitsRegistries.UT_alcoholic_II`.

**Mass-list coverage** (lines 292-293):

```lua
"UniversalTraits:UT_alcoholic_I", "UniversalTraits:UT_alcoholic_II",
"UniversalTraits:UT_alcoholic_III", "UniversalTraits:UT_addictedtocaffeine",
```

`UT_alcoholic_II` is included in the exhaustive expected-IDs list (labelled "Phase 3b — Periodic-Check"). The mass registration test (`"all 198 trait IDs registered with CharacterTrait"`) iterates this list and confirms each ID appears in `CharacterTrait._registered`. This provides a second, independent coverage layer.

**Runtime behavior tests:** None. No test exercises `handler()`, the `getDrunkenness()` threshold, or the stress delta math. This is consistent with all other traits in the suite (no trait has runtime behavior tests).

**Summary of coverage:**

| Coverage point | Status |
|---|---|
| Named registration spot-check | PRESENT (line 104) |
| Mass-list registration coverage | PRESENT (line 292) |
| TRAIT_ID constant correctness in Lua handler | Not directly tested (covered indirectly by spot-check verifying the registry string) |
| `getDrunkenness() < 0.05` threshold correctness | Not tested |
| Stress delta (+0.10) correctness | Not tested |
| No-tick-gate (fires every 10 min, not every 30) | Not tested |
| ModData: no persistent state / no collision risk | Not applicable (no modData used) |

**Observation:** `UT_alcoholic_II` has better test coverage than its siblings (I and III both lack named spot-checks). The spot-check at line 104 was likely written when II was the first alcoholic tier implemented or was used as the series reference.

---

## Final Verdict

**Status: PASS — no issues found**

### What is correct

- **Registration:** Present and correctly ordered in `registries.lua` (line 267), value is exact correct string
- **Script definition:** Complete and correctly formed — all required fields, Cost is -7, MET lists I and III only, no spurious fields
- **Translation:** Both `UI_UT_alcoholic_II` and `UI_UT_alcoholic_IIDesc` keys present, content accurate
- **Runtime logic:** Clean, minimal, fully stateless — nil guard on player, `UTCore.hasTrait` guard, no tick-gate (correctly fires every 10 minutes as documented), stress delta matches description exactly, `math.min` cap is correct
- **Tier consistency:** `TRAIT_ID` constant in Lua (`"UniversalTraits:UT_alcoholic_II"`) matches script definition, registry entry, and the spot-check test string — all four sites agree
- **No modData usage:** No persistent state, no save/load edge cases, no key collision risk with tier I (`UT_alcoholicI_ticks`) or any other trait
- **Release sync:** `release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_alcoholic_II.lua` content confirmed identical to source file via search
- **No dead code, no unreachable branches, no missing nil guards**
- **Description integrity: perfect** — every claim in the UI description is verified verbatim by the code
- **Test coverage:** Tier II has the strongest registration test coverage in the alcoholic series (dedicated spot-check + mass list)

### Distinguishing characteristics vs. tier I

Tier II is the only tier in the series with **no tick-gate**: tier I uses `% 3` to fire every 30 minutes, tier III uses `EveryOneMinute` for 1-minute cadence. Tier II sits at exactly the raw `EveryTenMinutes` cadence — the simplest possible implementation. This is also why tier II has no `getModData()` call while tier I does (tier I needs `UT_alcoholicI_ticks` to implement its throttle). Tier II is the cleanest code in the series.

### Source fidelity note

The UT implementation is a deliberate re-imagining. The source mod's single `Alcoholic` trait (-8 points) implements a complex, stateful, probabilistic, time-gated multi-effect withdrawal system with dynamic trait acquisition and removal. UT replaces this with three deterministic, stateless (or nearly stateless), stress-only tiers. `UT_alcoholic_II` most closely parallels the source mod's core withdrawal stress effect (>24 h sober: stress +0.10, ZombRand(55) gated) but strips the randomness and escalation timing, delivering a clean per-tick rate instead. The simplification is intentional and appropriate.
