# Trait Audit: UT_noxpsneaky

**Audit date:** 2026-04-04
**Auditor:** Claude (automated deep-audit)
**Trait ID:** `UniversalTraits:UT_noxpsneaky`
**Source file:** `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_noxpsneaky.lua`

---

## 1. Identity

| Field | Value |
|---|---|
| Trait ID | `UniversalTraits:UT_noxpsneaky` |
| Registry key | `UTTraitsRegistries.UT_noxpsneaky` |
| UI name key | `UI_UT_noxpsneaky` |
| UI desc key | `UI_UT_noxpsneakyDesc` |
| Phase | Phase 2 — No-XP Series |
| Category in run_tests.lua | `-- Phase 2 — No-XP Series (6)` |

---

## 2. Script Definition (`UT_character_traits.txt` line 1494)

```
character_trait_definition UniversalTraits:UT_noxpsneaky
{
    IsProfessionTrait = false,
    DisabledInMultiplayer = true,
    CharacterTrait = UniversalTraits:UT_noxpsneaky,
    Cost = 5,
    UIName = UI_UT_noxpsneaky,
    UIDescription = UI_UT_noxpsneakyDesc,
}
```

- **Cost:** +5 points (positive — this is a **positive trait**, player pays for it)
- **IsProfessionTrait:** false — available during free character creation
- **DisabledInMultiplayer:** true — locked out in MP lobbies
- **MutuallyExclusiveTraits:** none declared in script

---

## 3. Registry (`registries.lua` line 212)

```lua
UTTraitsRegistries.UT_noxpsneaky = CharacterTrait.register("UniversalTraits:UT_noxpsneaky")
```

Registered in the Phase 2 No-XP block, after `UT_noxpmaintenance` and before the Phase 2 Timed/Circadian block begins.

---

## 4. UI Strings (`UI_EN.txt` lines 458–459)

```lua
UI_UT_noxpsneaky     = "No XP: Sneaky",
UI_UT_noxpsneakyDesc = "You will never improve at moving silently, no matter how much you practice. Disables XP gain in Sneaking and Lightfoot.",
```

The description correctly names both affected skills.

---

## 5. Runtime Lua — Full Source

**File:** `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_noxpsneaky.lua` (13 lines)

```lua
-- UT_noxpsneaky.lua
-- Disables XP gain for Sneaking and Lightfoot skills

local TRAIT_ID = "UniversalTraits:UT_noxpsneaky"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.disableXP(player, "Sneaking")
    UTCore.disableXP(player, "Lightfoot")
end

Events.OnNewGame.Add(onNewGame)
```

### Event hook

| Event | Handler | Cadence |
|---|---|---|
| `Events.OnNewGame` | `onNewGame(player)` | Once, at new game start only |

There is no `OnCreatePlayer`, `OnLoadPlayer`, `OnPlayerUpdate`, or any other hook. The trait fires **once per new game** and is not re-applied on load or in any periodic tick.

---

## 6. Helper Trace

### 6a. `UTCore.hasTrait(player, traitId)`

**Source:** `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` lines 11–16

```lua
function UTCore.hasTrait(player, traitId)
    if not player then return false end
    local traits = player:getTraits()
    if not traits then return false end
    return traits:contains(traitId)
end
```

- Nil-safe: returns `false` if `player` or `player:getTraits()` is nil.
- Delegates to the Java `ArrayList<CharacterTrait>::contains()` call.
- No side effects.

### 6b. `UTCore.disableXP(player, perkName)`

**Source:** `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` lines 45–48

```lua
-- Stores "UT_xpDisable_<perkName>" = true in moddata.
function UTCore.disableXP(player, perkName)
    player:getModData()["UT_xpDisable_" .. perkName] = true
end
```

Called twice by `onNewGame`:
1. `UTCore.disableXP(player, "Sneaking")` → sets `moddata["UT_xpDisable_Sneaking"] = true`
2. `UTCore.disableXP(player, "Lightfoot")` → sets `moddata["UT_xpDisable_Lightfoot"] = true`

**ModData keys written:**
- `UT_xpDisable_Sneaking`
- `UT_xpDisable_Lightfoot`

### 6c. `UTCore_XPHook.lua` — enforcement

**Source:** `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua` lines 19–27

```lua
local function onAddXP(player, perk, amount)
    if not player or not perk or not amount or amount <= 0 then return end
    local md = player:getModData()

    -- 1. XP disable: cancel the full amount
    if md["UT_xpDisable_" .. perk] then
        player:getXp():AddXP(perk, -amount, false, false, false)
        return
    end
    ...
end

if Events and Events.AddXP then
    Events.AddXP.Add(onAddXP)
end
```

**Enforcement mechanism:** Every time `Events.AddXP` fires for the player:

1. The hook reads `moddata["UT_xpDisable_<perk>"]`.
2. If `true`, it immediately calls `player:getXp():AddXP(perk, -amount, false, false, false)` — issuing a cancelling negative award equal to the full incoming amount.
3. It then `return`s, skipping multiplier and multi-skill-penalty logic entirely.

**Cancellation is immediate and complete** — the net XP change is zero. The hook fires on every single XP event for any perk; it is not rate-limited or batched.

**Perks blocked:**
- `Perks.Sneaking` (internal name `"Sneaking"`)
- `Perks.Lightfoot` (internal name `"Lightfoot"`)

**`AddXP` call flags:** `(perk, -amount, false, false, false)` — `false, false, false` suppresses level-up notifications for the negative correction, which is correct behaviour.

---

## 7. Mutual Exclusions

### In `UT_character_traits.txt`

The `UT_noxpsneaky` block has **no `MutuallyExclusiveTraits` field**. No exclusions are declared in the script file.

### In MoreTraits (installed reference mod, `ToadTraits:noxpsneaky`)

The reference mod (MoreTraits) applied these mutual exclusions to its own equivalent trait at runtime via `TraitFactory.setMutualExclusive`:
- `noxpsneaky` ↔ `noxptechnician`
- `noxpsneaky` ↔ `noxpshooter`
- `noxpsneaky` ↔ `noxpaxe`
- `noxpsneaky` ↔ `noxpfirstaid`
- `noxpsneaky` ↔ `noxpmaintenance`
- `noxpsneaky` ↔ `Conspicuous` (conditional: when `DynamicTraits` mod is active)

**UT has none of these.** The UT No-XP traits do not exclude each other. A player can take any combination of them simultaneously.

---

## 8. Comparison with MoreTraits Source Trait

| Aspect | MoreTraits `ToadTraits:noxpsneaky` | UT `UniversalTraits:UT_noxpsneaky` |
|---|---|---|
| Point cost | 3 | 5 |
| Affected skills | Sneaking (+2), Lightfoot (+1) at new game via `levelPerkByAmount` | Sneaking XP disabled, Lightfoot XP disabled |
| Mechanism | Grants starting skill levels at character creation | Blocks all future XP gain for those skills |
| XP after creation | Not blocked (can still earn XP) | Permanently blocked via moddata flag |
| Mutual exclusions | 5 other noxp traits + conditional Conspicuous | None |
| MP disabled | Not found in reference | Yes (`DisabledInMultiplayer = true`) |

**Key design difference:** MoreTraits `noxpsneaky` is a skill-boost trait that gives starting levels in Sneaking/Lightfoot. UT `UT_noxpsneaky` is a hard XP block — the player starts at normal levels and can never earn more. These are conceptually opposite despite sharing a name.

---

## 9. Test Coverage (`run_tests.lua`)

`"UniversalTraits:UT_noxpsneaky"` appears at **line 263** in the `expected_ids` table under `-- Phase 2 — No-XP Series (6)`.

This table is used by the test harness to verify all expected trait IDs are registered in `CharacterTrait._registered`. The test confirms the trait is present in the registry at load time.

There is no dedicated functional test for `UT_noxpsneaky` specifically. The XP-disable mechanism is tested generically in `UT_CORE/test/run_tests.lua`:
- `"disableXP stores flag in moddata"` — verifies `UTCore.disableXP` writes `UT_xpDisable_<perk> = true`.
- `"XPHook cancels XP when disabled"` — verifies `UTCore_XPHook` fires a `-amount` correction when the flag is set.

---

## 10. Load Order / Timing

1. `registries.lua` loads → `CharacterTrait.register("UniversalTraits:UT_noxpsneaky")` creates the trait object.
2. `UT_character_traits.txt` parsed by PZ script engine → trait registered with Cost=5, no MET.
3. `UTCore_XPHook.lua` loads → `Events.AddXP.Add(onAddXP)` registered. Active for all players for the lifetime of the session.
4. `UT_noxpsneaky.lua` loads → `Events.OnNewGame.Add(onNewGame)` registered.
5. On new game start: `onNewGame(player)` fires → `hasTrait` check → `disableXP` writes two moddata flags.
6. From that point forward: every `AddXP` event for Sneaking or Lightfoot is cancelled by the XPHook.

**Load gap risk:** If a player saves immediately after a new game and reloads, the moddata flags persist in the save. The `OnNewGame` event does not re-fire on load. The flags are permanent in moddata — this is intentional and correct. There is no re-application on load, nor is one needed.

---

## 11. Issues and Findings

| # | Severity | Finding |
|---|---|---|
| 1 | INFO | No mutual exclusions declared in UT. Unlike MoreTraits, a player can freely stack UT_noxpsneaky with UT_noxpshooter, UT_noxptechnician, etc. This appears to be intentional design — each No-XP trait is independent — but it differs from the reference mod. |
| 2 | INFO | Cost is 5 vs MoreTraits' 3. MoreTraits' trait grants skill levels; UT's blocks XP. The cost premium reflects a fundamentally different (stronger) effect. |
| 3 | INFO | `DisabledInMultiplayer = true` means this trait cannot be selected in MP character creation. This is consistent with all other UT No-XP traits. |
| 4 | INFO | No `OnLoadPlayer` hook. Moddata flags survive saves, so re-application on load is not needed. Consistent with other UT_noxp* traits (all use identical structure). |
| 5 | WATCH | The XP cancellation uses `AddXP(perk, -amount, ...)`. If another mod's XP hook fires after UTCore's and also reads the XP value, the net result depends on hook insertion order. This is a systemic UTCore concern, not specific to this trait. |
| 6 | OK | UI description text accurately reflects the mechanic (Sneaking and Lightfoot both named). |
| 7 | OK | Release copy at `release/UniversalTraits/42/...` is byte-for-byte identical to the source — confirmed by search matches. |

---

## 12. Summary

`UT_noxpsneaky` is a straightforward, single-hook positive trait (cost +5) that permanently disables XP gain for the Sneaking and Lightfoot skills. It fires once on `OnNewGame`, writes two moddata flags, and the `UTCore_XPHook` `AddXP` listener enforces the block on every subsequent XP event for those perks. The implementation is minimal, correct, and consistent with the other five No-XP Series traits. No bugs found.
