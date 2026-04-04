# Trait Audit: UT_alcoholic_III

**Audit date:** 2026-04-04
**Auditor:** Claude Code (claude-sonnet-4-6)
**Trait ID:** `UniversalTraits:UT_alcoholic_III`
**Display name:** Alcoholic (Severe)
**Tier:** III of III (alcoholic series)

---

## Trait Summary

| Field | Value |
|---|---|
| Trait ID | `UniversalTraits:UT_alcoholic_III` |
| Display name | Alcoholic (Severe) |
| Cost | -10 (negative = disadvantage) |
| Profession trait | No |
| Multiplayer | Disabled |
| Event hook | `Events.EveryOneMinute` |
| Effective cadence | Every 1 in-game minute (no sub-sampling gate) |
| Stress condition | `getDrunkenness() < 0.1` |
| Stress effect | `setStress(min(1, stress + 0.05))` per minute |
| Panic condition | `getDrunkenness() < 0.05` |
| Panic effect | `setPanic(min(1, panic + 0.03))` per minute |
| Mutual exclusions | `UT_alcoholic_I`, `UT_alcoholic_II` |
| Also excluded by | `UT_ironliver` (positive trait, separate MET entry) |
| XPBoosts | None |

---

## Source Evidence

**Source mod:** DynamicTraitsExpandedMoodles (Steam Workshop — "Dynamic Traits")
**Source file:** `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMAddictions.lua`

### What the source mod does

The source defines a single vanilla `Alcoholic` trait (no tiers). The entire alcoholic system lives in `DTEMalcoholicTrait(player)` — a function called on a periodic event — which implements a complex, stateful, escalating withdrawal model using a persistent modData counter (`DTEMalcoholicTrait`) and a sober-time counter (`DTEMtimeSinceLastDrink`):

- **Sober state** (`MoodleType.Drunk == 0`): `DTEMalcoholicTrait += 1` and `DTEMtimeSinceLastDrink += 1` per call
- **Drunk state**: `DTEMalcoholicTrait -= (drunkLevel * 3)` per call; `DTEMtimeSinceLastDrink` resets to 0
- **Lucky/unlucky roll**: 1-in-30 chance each tick adds a random bonus/penalty via `DTEMluckyUnluckyModifier`
- **Counter clamp:** -50,000 to +50,000; sober-time clamp: 4,500 minutes

Multi-stage withdrawal effects (all probabilistic):

| Sober threshold | Effect |
|---|---|
| >1,440 min (24 h) | Anger (ZombRand(60)-gated), Stress +0.10 (ZombRand(55)-gated), Unhappiness +3 (ZombRand(60)-gated) |
| >2,880 min (48 h) | Fatigue +0.05 (ZombRand(70)-gated), Head pain (ZombRand(180)-gated) |
| >4,320 min (72 h) | Food sickness (ZombRand(70)-gated) |

The source trait can also be dynamically acquired/removed at runtime based on the counter (threshold ±44,640).

**Source trait cost:** -8 points (single tier)

**Key divergence:** The source system is dynamic, randomized, multi-stage, and mutable at runtime. UT re-imagines this as three deterministic, static tiers. Tier III is the "severe" end, adding a panic axis absent from tier I and II, and firing every minute rather than every ten minutes.

---

## Current UT Evidence

### Structure

#### Registration (`media/registries.lua`, line 268)

```lua
UTTraitsRegistries.UT_alcoholic_III     = CharacterTrait.register("UniversalTraits:UT_alcoholic_III")
```

Registration is present. It appears third in the alcoholic sequence, immediately after `UT_alcoholic_II` (line 267) and before `UT_addictedtocaffeine` (line 269). `CharacterTrait.register` returns the string ID which is stored in `UTTraitsRegistries.UT_alcoholic_III`. This string is what `UTCore.hasTrait` checks via `traits:contains(traitId)`.

#### Script definition (`media/scripts/UT_character_traits.txt`, lines 1875-1884)

```
character_trait_definition UniversalTraits:UT_alcoholic_III
{
    IsProfessionTrait = false,
    DisabledInMultiplayer = true,
    CharacterTrait = UniversalTraits:UT_alcoholic_III,
    Cost = -10,
    UIName = UI_UT_alcoholic_III,
    UIDescription = UI_UT_alcoholic_IIIDesc,
    MutuallyExclusiveTraits = UniversalTraits:UT_alcoholic_I;UniversalTraits:UT_alcoholic_II,
}
```

All required fields are present. No `XPBoosts` field (correct — no skill bonuses apply to a pure penalty trait). MET correctly lists I and II but not the trait itself.

**Cross-reference — `UT_ironliver` MET block** (`UT_character_traits.txt`, line 1569):
```
MutuallyExclusiveTraits = UniversalTraits:UT_alcoholic_I;UniversalTraits:UT_alcoholic_II;UniversalTraits:UT_alcoholic_III,
```
The engine enforces the iron-liver/alcoholic exclusion bidirectionally. `UT_alcoholic_III` is present in that list. Correct.

#### Translation (`media/lua/shared/Translate/EN/UI_EN.txt`, lines 581-582)

```lua
UI_UT_alcoholic_III     = "Alcoholic (Severe)",
UI_UT_alcoholic_IIIDesc = "Your body demands alcohol. Every in-game minute while below 0.1 drunkenness, stress increases by +0.05. While below 0.05 drunkenness, panic also increases by +0.03 per minute.",
```

Both keys present. `UI_UT_alcoholic_III` matches the `UIName` field in the script definition. `UI_UT_alcoholic_IIIDesc` matches the `UIDescription` field. No typos in the key names.

---

### Runtime Trace

**Full source of `media/lua/shared/UniversalTraits/traits/UT_alcoholic_III.lua` (21 lines):**

```lua
-- UT_alcoholic_III.lua
-- Alcoholic III: severe constant alcohol craving with stress and panic when sober

local TRAIT_ID = "UniversalTraits:UT_alcoholic_III"

local function handler()
    local player = getPlayer()
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    local stats = player:getStats()
    local drunkenness = stats:getDrunkenness()
    if drunkenness < 0.1 then
        stats:setStress(math.min(1, stats:getStress() + 0.05))
    end
    if drunkenness < 0.05 then
        stats:setPanic(math.min(1, stats:getPanic() + 0.03))
    end
end

Events.EveryOneMinute.Add(handler)
```

#### Step-by-step trace

**Line 20:** `Events.EveryOneMinute.Add(handler)` — registers `handler` to fire every 1 in-game minute. This is the highest-frequency event hook in the UT alcoholic series. It fires unconditionally for all players on every in-game minute tick, regardless of trait possession.

**Line 7:** `local player = getPlayer()` — retrieves the local player object. Returns `nil` on dedicated server, or before the player object has been created.

**Line 8:** `if not player then return end` — nil guard. Safe, consistent with all other UT trait files.

**Line 9:** `if not UTCore.hasTrait(player, TRAIT_ID) then return end` — calls `UTCore.hasTrait`.

Tracing into `UTCore.hasTrait` (`UT_CORE/media/lua/shared/UTCore/UTCore_API.lua`, lines 11–16):
```lua
function UTCore.hasTrait(player, traitId)
    if not player then return false end
    local traits = player:getTraits()
    if not traits then return false end
    return traits:contains(traitId)
end
```
- Double nil-checks player and the Java traits list
- `traits:contains("UniversalTraits:UT_alcoholic_III")` — string equality check on the Java `ArrayList`
- If the player does not hold trait III: handler exits here. No stats are read or written.

**Line 10:** `local stats = player:getStats()` — retrieves the `IsoGameCharacter` stats object. Not nil-guarded, but `getStats()` on a non-nil `IsoPlayer` is safe; it cannot return nil in B42.

**Line 11:** `local drunkenness = stats:getDrunkenness()` — caches the float value for reuse in both branch conditions below. Returns a float in [0.0, 1.0]. Caching is correct; calling `getDrunkenness()` once avoids two Java bridge calls.

**Lines 12–14 — Stress branch:**
```lua
if drunkenness < 0.1 then
    stats:setStress(math.min(1, stats:getStress() + 0.05))
end
```
- Threshold: `0.1` — wider than tiers I and II (both use `0.05`)
- This means the player must have a slightly non-trivial blood alcohol level to suppress stress accumulation. A single drink may not always push drunkenness above 0.10 depending on the item.
- `setStress(math.min(1, getStress() + 0.05))` — adds 0.05, caps at 1.0
- **Stress delta per minute: +0.05**
- **Time to max stress from zero (trait alone, continuously sober below 0.1): 20 ticks = 20 in-game minutes**

**Lines 15–17 — Panic branch:**
```lua
if drunkenness < 0.05 then
    stats:setPanic(math.min(1, stats:getPanic() + 0.03))
end
```
- Threshold: `0.05` — the tighter of the two thresholds. Panic only accumulates when the player is in an even deeper sober state than stress.
- `setPanic(math.min(1, getPanic() + 0.03))` — adds 0.03, caps at 1.0
- **Panic delta per minute: +0.03**
- **Time to max panic from zero (trait alone, continuously sober below 0.05): ~33.3 in-game minutes**
- The two branches are independent `if` statements (not `if/elseif`): both execute when `drunkenness < 0.05`, only the stress branch executes when `0.05 <= drunkenness < 0.1`. This is correct and intentional — when deeply sober, the player suffers both stat penalties simultaneously.

**No modData usage.** Unlike tier I (which uses `UT_alcoholicI_ticks` for sub-sampling), tier III has no modData interaction. The handler is stateless: every call at `EveryOneMinute` that passes the trait check will evaluate both branches and write stats. There is no tick-counting, no carry-over state, and nothing persisted to the save.

#### UTCore hooks used

| Hook | Purpose |
|---|---|
| `UTCore.hasTrait(player, TRAIT_ID)` | Nil-safe trait possession check via `traits:contains()` |

No other UTCore APIs are called. No `applyXPMultiplier`, `applyBleedDecayMult`, `applyStrengthCarryWeight`, event-driven hooks, or modData flag methods are used. This is one of the simplest trait implementations in the codebase.

---

## Description Integrity

**Claimed in UI description:** "Your body demands alcohol. Every in-game minute while below 0.1 drunkenness, stress increases by +0.05. While below 0.05 drunkenness, panic also increases by +0.03 per minute."

**Verified against code:**

| Claim | Code reality | Match? |
|---|---|---|
| "Every in-game minute" | `Events.EveryOneMinute` with no sub-sampling gate | YES |
| "while below 0.1 drunkenness" | `drunkenness < 0.1` (strict less-than) | YES — "below 0.1" is accurate for strict `<` |
| "stress increases by +0.05" | `setStress(min(1, stress + 0.05))` | YES — delta is exactly +0.05, capped at 1 |
| "While below 0.05 drunkenness" | second branch: `drunkenness < 0.05` (strict less-than) | YES — "below 0.05" is accurate |
| "panic also increases by +0.03 per minute" | `setPanic(min(1, panic + 0.03))` | YES — delta is exactly +0.03, capped at 1 |

**Description is fully accurate.** Every number, every threshold, and the cadence all match the code exactly. The word "also" correctly communicates that panic is additive to the stress effect rather than a replacement.

---

## Balance Review

### Within the alcoholic tier series

| Trait | Cost | Event | Cadence | Stress delta/effective tick | Stress threshold | Panic delta/min | Panic threshold |
|---|---|---|---|---|---|---|---|
| UT_alcoholic_I (Mild) | -4 | EveryTenMinutes + %3 gate | 30 min | +0.05 | drunk < 0.05 | none | — |
| UT_alcoholic_II (Moderate) | -7 | EveryTenMinutes | 10 min | +0.10 | drunk < 0.05 | none | — |
| UT_alcoholic_III (Severe) | -10 | EveryOneMinute | 1 min | +0.05 | drunk < 0.10 | +0.03 | drunk < 0.05 |

### Stress accumulation rate (if continuously sober at threshold)

| Tier | Stress per in-game hour | Minutes to max stress from zero |
|---|---|---|
| I (Mild) | 2 effective ticks × 0.05 = **+0.10/hr** | 600 min (10 hrs) |
| II (Moderate) | 6 ticks × 0.10 = **+0.60/hr** | 100 min (~1.67 hrs) |
| III (Severe) | 60 ticks × 0.05 = **+3.00/hr** (hard cap) | 20 min |

Tier III saturates stress in 20 in-game minutes of continuous deep sobriety (below 0.1). This is 15× faster than tier II and 30× faster than tier I. The exponential escalation between tiers is steep but appropriate for a "Severe" framing.

### Panic accumulation rate (if continuously sober below 0.05)

| Tier | Panic per in-game hour | Minutes to max panic from zero |
|---|---|---|
| I | 0 | n/a |
| II | 0 | n/a |
| III (Severe) | 60 ticks × 0.03 = **+1.80/hr** (hard cap) | ~33.3 min |

Tier III is the only alcoholic tier that affects panic. Panic in PZ drives the player toward poor decisions (reduced reaction speed, accuracy penalties). Adding panic on top of stress at the severe tier is mechanically appropriate.

### Drunkenness threshold asymmetry

Tier III uses **two different thresholds**: `0.1` for stress and `0.05` for panic. Tiers I and II both use only `0.05` for stress. This creates a bandwidth: a player at `0.05 <= drunkenness < 0.10` suffers stress but not panic. This "partial relief" zone is a deliberate design feature unique to tier III and correctly described in the UI text.

**Practical satisfaction:** In PZ B42, most alcoholic beverages raise drunkenness well above 0.10 with a single drink. However, weak drinks (low-alcohol beverages, small quantities) may only push drunkenness into the 0.05–0.10 band, providing partial relief (panic suppressed, stress still accumulating). A tier III player needs to drink a bit more, or more potent beverages, than a tier I/II player to fully suppress both effects. This is thematically coherent with "severe" dependency.

### Cost evaluation

At -10 points, tier III is the most expensive alcoholic tier and among the most costly negative traits in the UT roster. The combined stress+panic pressure (both saturating in ~20-33 minutes of sobriety) makes this genuinely punishing. A player who cannot reliably source alcohol will face constant max-stress and max-panic within about half an in-game hour, severely impacting combat effectiveness and decision-making.

The source mod's single `Alcoholic` tier was -8 points for a far more complex but less deterministic system. Tier III at -10 points with deterministic per-minute pressure is arguably more severe in sustained play than the source — the source's effects were gated behind 24/48/72-hour thresholds and probabilistic rolls, making them survivable with careful play. Tier III's continuous pressure is relentless.

**No balance bug.** The -10 cost is justified given the mechanical pressure.

### Interaction with alcohol consumption

The stress branch requires `drunkenness >= 0.1` to suppress. The panic branch requires `drunkenness >= 0.05` to suppress. Because `EveryOneMinute` fires every in-game minute, a player must maintain a blood alcohol level above 0.1 at all times to avoid any stress accumulation. In practice this means drinking regularly throughout the day — roughly in line with the "Severe" framing.

### Comparison with UT_addictedtocaffeine

The caffeine addiction trait (`UT_addictedtocaffeine`) also fires on `EveryOneMinute` and uses modData to track caffeine intake state. Unlike tier III, it uses a modData flag (`UT_hadCaffeine`) rather than a live stat check. The tier III alcohol handler is simpler (stateless, pure stat-read/write) and cheaper per call.

---

## Regression Proof

### Test coverage in `test/run_tests.lua`

**Direct registration spot-check for UT_alcoholic_III:** ABSENT.

The test suite contains a named spot-check only for `UT_alcoholic_II`:
```lua
-- line 104
test("UT_alcoholic_II registered", function()
    assert_eq(UTTraitsRegistries.UT_alcoholic_II, "UniversalTraits:UT_alcoholic_II")
end)
```

`UT_alcoholic_I` and `UT_alcoholic_III` have no equivalent dedicated registration tests.

**Mass-list coverage** (lines 292–293):
```lua
"UniversalTraits:UT_alcoholic_I", "UniversalTraits:UT_alcoholic_II",
"UniversalTraits:UT_alcoholic_III", "UniversalTraits:UT_addictedtocaffeine",
```
`UT_alcoholic_III` is included in the exhaustive ID list iterated by the mass-registration coverage test. This test checks that every listed ID has a corresponding entry in `registries.lua`. A missing `UTTraitsRegistries.UT_alcoholic_III` entry would be caught here. A wrong ID string in the Lua handler file itself would **not** be caught.

**Runtime behavior tests:** None. No test exercises `handler()`, the `drunkenness < 0.1` stress branch, the `drunkenness < 0.05` panic branch, the delta math, or the `math.min` ceiling. This is consistent with the rest of the codebase; no UT trait has runtime behavior tests in the current suite.

**Release sync verification:** The file at `release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_alcoholic_III.lua` contains identical content to the source file (both indexed by jCodemunch with matching text). Release is in sync.

**Summary of coverage gaps:**
1. No dedicated `assert_eq(UTTraitsRegistries.UT_alcoholic_III, ...)` spot-check (low risk — covered by mass-list test)
2. No test that `TRAIT_ID` in the Lua file matches the registry entry (the string `"UniversalTraits:UT_alcoholic_III"` must match on both sides)
3. No test for the stress branch threshold (0.1) or delta (+0.05)
4. No test for the panic branch threshold (0.05) or delta (+0.03)
5. No test that both branches execute independently (not `if/elseif`)

---

## Final Verdict

**Status: PASS**

### What is correct

- **Registration:** present and correct in `registries.lua` (line 268), correctly sequenced after tiers I and II
- **Script definition:** complete and correctly formed — all fields present, cost is -10, `CharacterTrait` key matches `TRAIT_ID`, `UIName`/`UIDescription` keys match translation file, MET lists I and II correctly, no spurious self-reference
- **Cross-MET consistency:** `UT_ironliver` MET block (line 1569) correctly lists all three alcoholic tiers, so the exclusion is bidirectional at the engine level
- **Translation:** both `UI_UT_alcoholic_III` and `UI_UT_alcoholic_IIIDesc` keys present; names and descriptions accurate
- **Runtime logic:** clean, minimal, stateless, correct
  - Nil guards on player and trait check are present and correctly ordered
  - `drunkenness` is read once and reused — no redundant Java bridge calls
  - Both branches are independent `if` statements (not `if/elseif`) — correct; deeply sober players suffer both penalties simultaneously
  - `math.min(1, ...)` cap prevents stat overflow on both stress and panic — correct
  - No modData interaction needed and none present (stateless handler is appropriate for a per-minute event)
- **Description integrity:** every claim in `UI_UT_alcoholic_IIIDesc` — cadence, stress threshold, stress delta, panic threshold, panic delta — matches the code exactly
- **Tier consistency:** `TRAIT_ID = "UniversalTraits:UT_alcoholic_III"` in the Lua file matches the script definition key and the registry entry — no mismatch
- **Release sync:** `release/` copy matches source

### Observations (not bugs)

1. **No dedicated registration spot-check test.** `UT_alcoholic_II` has a named test (`test("UT_alcoholic_II registered", ...)`); tiers I and III do not. The mass-list test provides indirect coverage, but a per-trait named assertion would make failures more diagnosable. Low priority.

2. **Threshold asymmetry is correct but subtle.** The stress threshold (0.1) differs from the panic threshold (0.05) and from the threshold used by tiers I and II (both 0.05 for stress). This is intentional design and accurately described in the UI, but it is a detail that could confuse a future maintainer who compares the three files without reading carefully.

### Source fidelity note

The UT tier III implementation is a clean re-imagining of the source mod's `Alcoholic` trait. The source system was dynamic, stateful, probabilistic, and mutable (could be added/removed at runtime via counter thresholds). UT tier III discards all of that in favor of a deterministic, stateless, per-minute dual-stat penalty. The "severe" spirit of the source — constant, relentless pressure when sober — is preserved and arguably intensified: the UT implementation saturates both stress and panic within 20–33 in-game minutes of sobriety, with no randomness and no waiting period. The simplification is appropriate for a universal trait system and the mechanical result is faithful to the original intent.
