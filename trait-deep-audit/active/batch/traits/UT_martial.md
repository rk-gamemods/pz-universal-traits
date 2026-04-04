# Trait Audit: UT_martial

**Audit date:** 2026-04-04
**Auditor:** Claude (automated deep-read)
**Source commit:** UTMods git HEAD `2dfd07753074755f5c6c0b542128aecb917ba318`

---

## 1. Identity

| Field | Value |
|---|---|
| Trait ID | `UniversalTraits:UT_martial` |
| Display name | Martial Artist |
| Registry key | `UTTraitsRegistries.UT_martial` |
| Registry phase | PHASE 1 — XP BOOST: COMBAT (MELEE) |
| Cost | 5 points |
| `IsProfessionTrait` | false |
| `DisabledInMultiplayer` | **true** |
| Source file | `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_martial.lua` |
| Script definition | `UniversalTraits/media/scripts/UT_character_traits.txt` |

---

## 2. Script Definition (UT_character_traits.txt)

```
character_trait_definition UniversalTraits:UT_martial
{
    IsProfessionTrait = false,
    DisabledInMultiplayer = true,
    CharacterTrait = UniversalTraits:UT_martial,
    Cost = 5,
    UIName = UI_UT_martial,
    UIDescription = UI_UT_martialDesc,
    XPBoosts = Fitness=1;SmallBlunt=1,
}
```

**XPBoosts:** +1 to Fitness, +1 to SmallBlunt (starting skill bonuses, not starting levels).

---

## 3. UI Strings (UI_EN.txt)

```
UI_UT_martial       = "Martial Artist"
UI_UT_martialDesc   = "Your hands are lethal weapons. Bare-hand strikes have a chance to
                       land a critical hit dealing 3× damage (0.6 vs 0.2 base). Critical
                       hit chance scales with Short Blunt skill (5% base + 5% per level).
                       All damage scaled by endurance (×0.35 at empty to ×1.35 at full).
                       Grants Short Blunt experience on each hit."
```

**Note:** The tooltip states 3× damage. The code implements a 3× ratio (crit = 0.6 raw, normal = 0.2 raw), which matches. The tooltip calls the stat "Short Blunt" while the code uses `Perks.SmallBlunt` — these are the same perk under different display names.

---

## 4. Registry (registries.lua)

```lua
-- PHASE 1 -- XP BOOST: COMBAT (MELEE)
UTTraitsRegistries.UT_martial = CharacterTrait.register("UniversalTraits:UT_martial")
```

`CharacterTrait.register` returns the full namespaced string `"UniversalTraits:UT_martial"` and stores it on the table. All internal hasTrait checks use this string directly — they do not use the registry reference. The registry entry is used by external mods (EvolvingTraitsWorld, MoreTraits Dynamic) and by the test suite for registration verification.

---

## 5. Runtime Lua — Full Walk-Through

### 5.1 Module table

```lua
UT_martial = UT_martial or {}
```

Creates a global module table the first time the file loads; idempotent on subsequent loads. This table exposes `applyBonusDamage` as a public API for synergy callers.

---

### 5.2 Public API: `UT_martial.applyBonusDamage(player, target, endurance)`

**Location:** lines 18–53, `UT_martial.lua`

**Purpose:** Shared damage calculation callable by this trait and by other traits (currently `UT_batteringram`). Does **not** drain endurance — the caller is responsible for any endurance drain before calling this.

**Guard — mundane suppression (line 20):**
```lua
if UTCore.hasTrait(player, "UniversalTraits:UT_mundane") then return 0 end
```
If the player has `UT_mundane`, the function returns `0` immediately with no side effects. UT_mundane disables crits and bonus damage globally for the player.

**SmallBlunt level read (lines 22–31):**
```lua
local smallBluntLevel = 0
local ok, level = pcall(function()
    if Perks and Perks.SmallBlunt then
        return player:getPerkLevel(Perks.SmallBlunt)
    end
    return 0
end)
if ok and type(level) == "number" then
    smallBluntLevel = level
end
```
Safe pcall wrapper around `Perks.SmallBlunt`. Falls back to 0 if the API is unavailable (e.g., loading order issue or test environment without the global).

**Crit chance formula (line 33):**
```lua
local critchance = (5 + (smallBluntLevel * 5)) * 0.01
```
| SmallBlunt level | Crit chance |
|---|---|
| 0 | 5% |
| 1 | 10% |
| 2 | 15% |
| 3 | 20% |
| 4 | 25% |
| 5 | 30% |
| 6 | 35% |
| 7 | 40% |
| 8 | 45% |
| 9 | 50% |
| 10 | 55% |

**Damage roll (lines 35–40):**
```lua
if ZombRand(100) < (critchance * 100) then
    damage = 6 * 0.1  -- crit:   0.6 raw
else
    damage = 2 * 0.1  -- normal: 0.2 raw
end
```
`ZombRand(100)` returns an integer in `[0, 99]`. The condition `< critchance * 100` converts critchance (e.g., 0.30) back to an integer threshold (e.g., 30), so the roll is `ZombRand(100) < 30` — a 30% chance. Crit multiplier is 3× (`0.6 / 0.2`).

**Endurance scaling (line 43):**
```lua
damage = damage * (endurance + 0.35)
```
`endurance` is a float in `[0.0, 1.0]` from `player:getStats():getEndurance()`.

| Endurance | Scale multiplier | Normal hit damage | Crit hit damage |
|---|---|---|---|
| 0.0 (empty) | 0.35× | 0.07 | 0.21 |
| 0.25 | 0.60× | 0.12 | 0.36 |
| 0.50 | 0.85× | 0.17 | 0.51 |
| 0.75 | 1.10× | 0.22 | 0.66 |
| 1.0 (full) | 1.35× | 0.27 | 0.81 |

**Health deduction (line 45):**
```lua
pcall(function() target:setHealth(target:getHealth() - damage) end)
```
Direct health subtraction, wrapped in pcall. No kill processing — if the target reaches ≤0 health the engine handles death normally. No `TraitKillProcessed` guard (unlike MoreTraits source, which had its own kill logic).

**XP grant (lines 46–50):**
```lua
pcall(function()
    if Perks and Perks.SmallBlunt then
        player:getXp():AddXP(Perks.SmallBlunt, damage * 2)
    end
end)
```
XP granted = `damage * 2`. This scales with both crit and endurance, so a full-endurance crit at SmallBlunt 5 grants `0.81 * 2 = 1.62 XP` while an empty-endurance normal hit grants `0.07 * 2 = 0.14 XP`.

**Return value:** The damage dealt (float), or `0` if mundane suppressed.

---

### 5.3 Event handler: `onWeaponHitCharacter(player, weapon, target)`

**Location:** lines 55–76, `UT_martial.lua`

**Hook:** `Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)` — registered unconditionally at file load time; the guards inside filter per-call.

**Guard chain:**

1. **Nil player (line 56):** `if not player then return end`
2. **Weapon type (line 59):** `if weapon:getType() ~= "BareHands" then return end` — exits for all non-bare-hand hits. No effect on knives, clubs, etc.
3. **Trait check (line 62):** `if not UTCore.hasTrait(player, TRAIT_ID) then return end` — exits if the player does not have `UT_martial`.

**`UTCore.hasTrait` implementation:**
```lua
function UTCore.hasTrait(player, traitId)
    if not player then return false end
    local traits = player:getTraits()
    if not traits then return false end
    return traits:contains(traitId)
end
```
Nil-safe; calls `player:getTraits():contains(traitId)`.

**Endurance read (lines 64–68):**
```lua
local stats = player.getStats and player:getStats()
local endurance = 1.0
if stats and stats.getEndurance then
    endurance = stats:getEndurance()
end
```
Defaults to `1.0` (full endurance) if `getStats` is unavailable, ensuring the damage is not penalised in edge cases.

**Endurance drain (lines 71–73):**
```lua
if stats and stats.setEndurance then
    stats:setEndurance(math.max(0, endurance - 0.001))
end
```
Drains `0.001` endurance per bare-hand hit. With endurance pool of `1.0`, this means approximately **1,000 bare-hand hits** to fully exhaust endurance via this drain alone. This is intentionally small — the drain is cosmetic/flavour, not a limiting mechanic.

**Delegation (line 75):**
```lua
UT_martial.applyBonusDamage(player, target, endurance)
```
Passes the pre-drain endurance value (before the `- 0.001`). The endurance has already been written to `stats`, but the value passed to `applyBonusDamage` is the value read at line 67, not the post-drain value. This is a deliberate choice noted in the source comment ("Does NOT drain endurance — callers manage that themselves").

---

## 6. UTCore Hook Tracing

### 6.1 `Events.OnWeaponHitCharacter`

- Registered at Lua file-load time (no `OnCreatePlayer` gating).
- Fires once per weapon-hit event from the engine for all players.
- UT_martial's handler runs the guard chain and exits early for non-matching players/weapons.
- Cost per non-matching call: 1 nil-check + 1 string compare + 1 `getTraits():contains()` call.

### 6.2 No `UTCore.declareZombieCollisionHandler` usage

`UT_martial` does **not** register a zombie collision handler. The collision pathway is owned entirely by `UT_batteringram`, which calls `UT_martial.applyBonusDamage` as a synergy.

### 6.3 No periodic/OnPlayerUpdate hook

No tick-based logic. All effects are event-driven via `OnWeaponHitCharacter`.

### 6.4 No moddata usage

`UT_martial` writes nothing to `player:getModData()`. No per-player state is stored.

---

## 7. Synergy Relationships

### 7.1 UT_batteringram (inbound synergy)

**File:** `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_batteringram.lua`

When a player with `UT_batteringram` sprints into a zombie, the collision handler:
1. Cancels the native stagger (`player:setBumpType("")`, `player:setBumpFall(false)`)
2. Knocks the zombie down (`zombie:knockDown(false)`)
3. Drains `0.05` endurance (`ENDURANCE_DRAIN`)
4. Checks `UTCore.hasTrait(player, "UniversalTraits:UT_martial")` and, if true, calls `UT_martial.applyBonusDamage(player, zombie, endurance)` with the **post-drain** endurance value.

The collision-path damage uses the post-drain endurance (after `- 0.05`), while the weapon-hit path uses the pre-drain endurance (before `- 0.001`). This is consistent with each caller managing its own drain.

The endurance passed to `applyBonusDamage` from a batteringram collision is reduced by `0.05` per collision (~20 collisions to exhaust). A player at full endurance (1.0) loses the first `0.05`, so the first collision call receives `endurance = 0.95`, giving a scale of `0.95 + 0.35 = 1.30×`.

### 7.2 UT_actionhero (gating dependency)

**File:** `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_actionhero.lua`

`UT_actionhero` adds its own crit-damage bonus on weapon hits scaled by nearby spotted enemies. For bare-hands hits, `UT_actionhero` requires the player to **also have `UT_martial`**:

```lua
if weapon:getType() == "BareHands" then
    if not UTCore.hasTrait(player, "UniversalTraits:UT_martial") then return end
end
```

Without `UT_martial`, bare-hand `UT_actionhero` hits are silently ignored. `UT_martial` is not required for `UT_actionhero` to function on weapon hits — only bare-hands hits have this gate.

### 7.3 UT_mundane (suppressor)

`UT_mundane` suppresses `UT_martial` entirely via the first guard in `applyBonusDamage`. The function returns `0` without applying damage or XP. The endurance drain in `onWeaponHitCharacter` (line 71–73) still occurs — mundane does not prevent the `0.001` drain, only the damage/XP output.

---

## 8. Installed-Mods Source Reference (MoreTraits)

**Source:** `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` lines 1976–2051

The UT implementation diverges significantly from the MoreTraits original:

| Aspect | MoreTraits original | UT_martial |
|---|---|---|
| Trigger | `Events.OnWeaponHitCharacter` | `Events.OnWeaponHitCharacter` |
| Weapon scope | BareHands OR any weapon if `MartialWeapons` sandbox var set | BareHands only, unconditional |
| Crit formula | `(5 + blunt) * scaling` where `scaling = SandboxVars / 100` | `(5 + blunt * 5) * 0.01` (fixed, no sandbox var) |
| Lucky/Unlucky adjustment | Yes (+/- `luckimpact`) | No |
| Damage base | Uses incoming `damage` parameter, multiplied | Fixed base: 0.6 crit / 0.2 normal |
| Crit multiplier | 4× of incoming damage | 3× (0.6 vs 0.2) |
| Endurance scaling | Step function: 0.25/0.5/0.75/1.0 at 4 thresholds | Linear: `endurance + 0.35` |
| Endurance drain | 0.002 per hit | 0.001 per hit |
| Kill processing | Manual `target:Kill()` + zombie-kill counter | None (engine handles death) |
| XP grant | `martialDamage * 2 * blunt` (scales with level) | `damage * 2` (flat, not level-scaled) |
| Mundane check | `not player:hasTrait(ToadTraitsRegistries.mundane)` | `UTCore.hasTrait(..., "UniversalTraits:UT_mundane")` |
| Multiplayer | Blocked by `DisabledInMultiplayer = true` in script | Same |
| Moddata | None | None |
| Sandbox options | `MartialScaling`, `MartialWeapons`, `MartialDamage` debug | None |

The UT version simplifies and rebalances: fixed damage bases replace the incoming-damage multiplier, the endurance curve is continuous rather than stepped, kill handling is delegated to the engine, and XP no longer compounds with skill level.

---

## 9. Test Coverage (run_tests.lua)

**File:** `UniversalTraits/test/run_tests.lua`

### Registration test (line 54–56)
```lua
test("UT_martial registered", function()
    assert_eq(UTTraitsRegistries.UT_martial, "UniversalTraits:UT_martial")
end)
```
Verifies the registry entry exists and holds the correct string.

### Full trait list membership (line 192)
```lua
"UniversalTraits:UT_martial", -- in the Combat Melee (8) block
```
Included in the comprehensive trait enumeration test that verifies all expected traits are present.

### Damage test — guaranteed crit (lines 772–786)
```lua
test("martial deals bonus damage with bare hands (guaranteed crit)", function()
    -- SmallBlunt level=5 → critchance = (5+25)*0.01 = 0.30 → 30%
    -- ZombRand always returns 0 → 0 < 30 → crit fires
    local player = MockPlayer({ "UniversalTraits:UT_martial" })
    player:setPerkLevel(Perks.SmallBlunt, 5)
    -- endurance = 1.0 (MockPlayer default)
    Events.OnWeaponHitCharacter:fire(player, weapon, target)
    assert_true(target:getHealth() < 100, ...)
end)
```
With `ZombRand` stubbed to always return `0` and endurance at `1.0`, the expected damage is:
- `critchance = (5 + 5*5) * 0.01 = 0.30`
- `damage = 0.6 * (1.0 + 0.35) = 0.81`
- Target health: `100 - 0.81 = 99.19`

### Non-BareHands skip test (lines 788–799)
```lua
test("martial skips when weapon is not BareHands", function()
    local weapon = MockWeapon("Axe")
    Events.OnWeaponHitCharacter:fire(player, weapon, target)
    assert_eq(target:getHealth(), 100, ...)
end)
```
Confirms the weapon-type guard works.

### Batteringram synergy test (lines 940–949)
```lua
test("batteringram with UT_martial damages zombie on collision", function()
    local player = MockPlayer({ "UniversalTraits:UT_batteringram", "UniversalTraits:UT_martial" })
    Events.OnCreatePlayer:fire(0, player)
    player._sprinting = true
    local zombie = MockZombie({ health = 100 })
    fireRamCollision(player, zombie)
    assert_true(zombie:getHealth() < 100, ...)
end)
```
End-to-end synergy: collision fires batteringram handler, which calls `UT_martial.applyBonusDamage`, which reduces zombie health.

**Coverage gaps:**
- No test for mundane suppression path (applyBonusDamage returning 0).
- No test for endurance drain (0.001 write verified implicitly but not asserted).
- No test for XP grant amount.
- No test for actionhero bare-hands gate (lives in actionhero tests, not martial).

---

## 10. Findings and Notes

### F1 — DisabledInMultiplayer is true
The script definition sets `DisabledInMultiplayer = true`. Players in multiplayer cannot take this trait at character creation. The Lua event handler has no multiplayer check inside it — if the trait were ever added to a multiplayer player via console or a Dynamic mod, the handler would fire. This is not a bug (it is intentionally prevented upstream), but warrants awareness for any MP-compatibility work.

### F2 — Endurance passed to applyBonusDamage is pre-drain
`onWeaponHitCharacter` reads endurance, writes `endurance - 0.001` to stats, then passes the original `endurance` value to `applyBonusDamage`. The scaling is therefore based on the slightly-higher pre-drain value. At a drain of 0.001 this is negligible in practice.

### F3 — XP does not scale with SmallBlunt level
MoreTraits XP was `martialDamage * 2 * blunt`, so XP compounded with level. UT_martial uses `damage * 2` — flat. At SmallBlunt 10, MoreTraits would give ~10× the XP per hit; UT_martial gives the same XP regardless of level. Intentional simplification but worth documenting for balance review.

### F4 — applyBonusDamage mundane check vs onWeaponHitCharacter endurance drain
If a player has both `UT_martial` and `UT_mundane`, `onWeaponHitCharacter` still drains `0.001` endurance per bare-hand hit before calling `applyBonusDamage`. `applyBonusDamage` then returns `0`. The drain is not suppressed by mundane. This is very minor (drain = 0.001) but is a behavioural asymmetry: mundane disables damage/XP output, not the endurance cost.

### F5 — No dead-code risk
`UT_martial.applyBonusDamage` is a public API called from `UT_batteringram`; it is not dead code even if `onWeaponHitCharacter` were the only internal caller. The `UT_martial` global table itself is referenced by `UT_actionhero` (guard only, no call) and `UT_batteringram` (direct call).

### F6 — crit chance tooltip accuracy
The tooltip description says "5% base + 5% per level". The code formula is `(5 + smallBluntLevel * 5) * 0.01`. At level 0: 5%. At level 1: 10%. At level 10: 55%. This matches the description. However, the tooltip's claim of "3× damage" refers to the 0.6/0.2 ratio, which is exactly 3×. Both are accurate.

---

## 11. Summary

`UT_martial` is a single-purpose combat trait with a clean, well-encapsulated implementation. Its public `applyBonusDamage` API is the correct design choice given the batteringram synergy. Guards are thorough (nil checks, pcall wrapping, mundane check). The trait is singleplayer-only by script definition. Test coverage is functional but missing mundane-suppression and XP assertions. No bugs found. The main design differences from the MoreTraits source are intentional simplifications: fixed damage bases, continuous endurance scaling, no sandbox variables, and level-flat XP.
