# Trait Audit: UT_noxpaxe

**Audit date:** 2026-04-04
**Auditor:** Claude (automated deep-audit)
**Repo head:** UTMods `2dfd077` / UniversalTraits `2dfd077`

---

## 1. Identity

| Field | Value |
|---|---|
| Trait ID (namespaced) | `UniversalTraits:UT_noxpaxe` |
| Series | Phase 2 — No-XP Series |
| Source Lua | `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_noxpaxe.lua` |
| Script definition | `UniversalTraits/media/scripts/UT_character_traits.txt` line 1464 |
| Registry line | `UniversalTraits/media/registries.lua` line 209 |
| UI translation key | `UI_UT_noxpaxe` / `UI_UT_noxpaxeDesc` |
| UI name | "No XP: Axe" |
| UI description | "You'll never get any better with axes. Disables XP gain in Axe." |
| Inspiration source | MoreTraits `noxpaxe` (ToadTraits) |

---

## 2. Script Definition (`UT_character_traits.txt`)

```
character_trait_definition UniversalTraits:UT_noxpaxe
{
    IsProfessionTrait = false,
    DisabledInMultiplayer = true,
    CharacterTrait = UniversalTraits:UT_noxpaxe,
    Cost = 2,
    UIName = UI_UT_noxpaxe,
    UIDescription = UI_UT_noxpaxeDesc,
}
```

- **Cost:** +2 points (positive = flaw; player gains 2 points at character creation)
- **IsProfessionTrait:** false — available to all occupations
- **DisabledInMultiplayer:** true — single-player only
- **XPBoosts block:** absent — no starting skill level bonuses granted by the script definition

---

## 3. Registry

`registries.lua` line 209, inside the `-- PHASE 2 -- LUA-DRIVEN: NO-XP SERIES` block:

```lua
UTTraitsRegistries.UT_noxpaxe = CharacterTrait.register("UniversalTraits:UT_noxpaxe")
```

B42 `CharacterTrait.register` links the Lua runtime handle to the script-defined trait. The call is unconditional at shared load time; no version guard.

Neighbours in the registry block (same series):

```
UT_noxpshooter   (line 208)
UT_noxptechnician (line 209 — immediately above)
UT_noxpaxe       (line 209)
UT_noxpfirstaid  (line 210)
UT_noxpmaintenance (line 211)
UT_noxpsneaky    (line 212)
```

---

## 4. Runtime Lua — Full Source

File: `media/lua/shared/UniversalTraits/traits/UT_noxpaxe.lua` (11 lines)

```lua
-- UT_noxpaxe.lua
-- Disables XP gain for Axe skill

local TRAIT_ID = "UniversalTraits:UT_noxpaxe"

local function onNewGame(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    UTCore.disableXP(player, "Axe")
end

Events.OnNewGame.Add(onNewGame)
```

**Event hook:** `Events.OnNewGame` — fires once when a new game is started. Does **not** fire on save-load.

**Affected perk:** `"Axe"` — single skill, no secondary perk.

Comparison with other No-XP siblings:
- `UT_noxpshooter` — disables `"Aiming"` + `"Reloading"` (two perks)
- `UT_noxptechnician` — disables `"Electricity"` + `"Mechanics"` (two perks)
- `UT_noxpfirstaid` — disables `"Doctor"` (one perk, cost 3)
- `UT_noxpmaintenance` — disables `"Maintenance"` (one perk)
- `UT_noxpsneaky` — disables `"Sneaking"` + `"Lightfoot"` (two perks)

`UT_noxpaxe` is a single-perk disable with cost 2, making it the cheapest in the series (UT_noxpfirstaid costs 3; the twin-perk variants presumably cost more).

---

## 5. Helper Trace

### 5a. `UTCore.hasTrait(player, traitId)`

Defined in `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua`:

```lua
function UTCore.hasTrait(player, traitId)
    if not player then return false end
    local traits = player:getTraits()
    if not traits then return false end
    return traits:contains(traitId)
end
```

- Nil-safe: guards both `player` and the traits list before calling `:contains()`.
- Returns `boolean`. No side effects.
- Argument passed: `"UniversalTraits:UT_noxpaxe"` (fully namespaced).

### 5b. `UTCore.disableXP(player, perkName)`

Defined in `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua`:

```lua
function UTCore.disableXP(player, perkName)
    player:getModData()["UT_xpDisable_" .. perkName] = true
end
```

- Writes moddata key `"UT_xpDisable_Axe" = true` on the player object.
- **Persistence:** moddata is serialized with the save; the flag survives reloads once written. Because the writer hook is `OnNewGame` only, the flag is written exactly once on new-game creation and then persists automatically through save/load cycles without re-registration.
- No nil guard on `player` here — caller (`onNewGame`) already gated through `hasTrait` which returns early if `player` is nil; in practice the `OnNewGame` event always supplies a valid player.

---

## 6. Enforcement: UTCore XPHook

Defined in `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua`:

```lua
local function onAddXP(player, perk, amount)
    if not player or not perk or not amount or amount <= 0 then return end
    local md = player:getModData()

    -- 1. XP disable: cancel the full amount
    if md["UT_xpDisable_" .. perk] then
        player:getXp():AddXP(perk, -amount, false, false, false)
        return
    end
    -- 2. XP multiplier ... (not reached for disabled perks)
    -- 3. Multi-skill penalty ... (not reached for disabled perks)
end

Events.AddXP.Add(onAddXP)
```

**Mechanism:** Every `Events.AddXP` call passes through `onAddXP`. When `UT_xpDisable_Axe` is truthy in moddata, the hook immediately issues a compensating negative `AddXP(-amount)` and returns — the net Axe XP gain is zero. The cancel is absolute: it fires before the multiplier and multi-skill-penalty branches, and those branches are never reached.

**Parameters to AddXP cancel call:** `(perk, -amount, false, false, false)` — the three `false` flags suppress XP bar flash, level-up notification, and event re-firing respectively, so the cancellation is silent.

**Cadence:** Continuous — every Axe XP event for the lifetime of the save is cancelled, not just at spawn.

---

## 7. Mutual Exclusions

No `MutualExclusive` entries exist in `UT_character_traits.txt` for `UT_noxpaxe`. The No-XP series traits in UT are **not** mutually exclusive with each other.

Note: The MoreTraits source mod (`ToadTraits:noxpaxe`) registered many mutual exclusions between its noxp traits (`noxpsneaky`↔`noxpaxe`, `noxptechnician`↔`noxpaxe`, `noxpshooter`↔`noxpaxe`, `noxpaxe`↔`noxpfirstaid`, `noxpaxe`↔`noxpmaintenance`). UT deliberately does not replicate these; all No-XP traits can be combined freely.

---

## 8. Source Mod Comparison (MoreTraits `noxpaxe`)

The original MoreTraits trait (`ToadTraits:noxpaxe`) behaves differently:

- **Cost:** 3 points
- **Registration:** `TraitFactory.addTrait("noxpaxe", ...)` — B41/legacy API
- **Effect at spawn:** `levelPerkByAmount(player, Perks.Axe, 2)` and `levelPerkByAmount(player, Perks.Woodwork, 1)` — grants +2 Axe and +1 Woodwork starting levels as compensation
- **XP block mechanism:** `player:hasTrait(ToadTraitsRegistries.noxpaxe)` checked inside an `OnNewGame` or game-tick handler that calls `player:LevelPerk` repeatedly — a level-capping loop approach rather than a hook cancel
- **Mutual exclusions:** extensively mutually exclusive with other noxp traits in its set

UT's implementation differs in all three respects: cheaper (2 vs 3), no compensating skill level bonus, and uses a clean hook-based cancel rather than a level-cap loop. The Woodwork bonus present in MoreTraits is absent from UT.

---

## 9. Translation

File: `media/lua/shared/Translate/EN/UI_EN.txt`

```
UI_UT_noxpaxe     = "No XP: Axe",
UI_UT_noxpaxeDesc = "You'll never get any better with axes. Disables XP gain in Axe.",
```

- Name is concise and consistent with the series naming convention (`No XP: <Skill>`).
- Description is accurate: XP gain in Axe is fully disabled, not reduced.
- No mention of the compensating stat bonus (none exists in UT).

---

## 10. Test Coverage (`test/run_tests.lua`)

**Registration smoke test** (line 262): `"UniversalTraits:UT_noxpaxe"` is included in the all-traits registration array, confirming the trait is exercised by the round-trip registration test.

**Load order** (line 459): `UT_noxpaxe.lua` is loaded after `UTCore_XPHook.lua`, ensuring the hook is in place before the trait file runs:

```lua
dofile(base .. "../../UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpshooter.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxptechnician.lua")
dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpaxe.lua")   -- line 459
```

**Functional test** (lines 969–973): `UT_noxpaxe` is tested in a shared "single-skill noxp traits" test case:

```lua
test("single-skill noxp traits block their matching XP through the hook", function()
    local axePlayer = fireNewGame("UniversalTraits:UT_noxpaxe")
    Events.AddXP:fire(axePlayer, "Axe", 10)
    assert_true(xpWasCancelled(axePlayer, "Axe", 10), "expected Axe XP to be cancelled")
    -- (firstaid and maintenance also tested in same block)
end)
```

The test creates a mock player with the trait, fires `OnNewGame` (which writes `UT_xpDisable_Axe`), fires `AddXP("Axe", 10)`, and asserts the compensating `-10` cancellation was issued. Coverage is direct and complete for the primary path.

No test covers: non-Axe perks being unaffected (implicit from hook logic), or the trait being absent (early-return path in `onNewGame`).

---

## 11. Issues and Observations

| # | Severity | Issue |
|---|---|---|
| 1 | Low | `onNewGame` writes the moddata flag but there is no `OnLoad`/`OnCreatePlayer` re-application path. If someone edits their save to add the trait after game creation, the flag will not be set until a new game. This is consistent with the rest of the No-XP series but is a known limitation. |
| 2 | Info | Cost is 2, not 3 as in MoreTraits. This may be intentional (single perk, no compensating bonus) but the ratio is different from MoreTraits peers where the single-perk `noxpfirstaid` costs 3 within UT itself. Minor inconsistency within the UT No-XP series. |
| 3 | Info | No compensating Axe or Woodwork level bonus, unlike MoreTraits which granted +2 Axe / +1 Woodwork. If both mods are active, a player taking UT_noxpaxe gets no bonus while a player taking ToadTraits:noxpaxe gets +2/+1 and only costs 3 points. Not a bug, but a balance difference to document. |
| 4 | Info | `DisabledInMultiplayer = true` — consistent with all other No-XP series traits. XP hook operates per-player on moddata so there is no technical barrier to MP, but the design choice is to exclude it. |
| 5 | Info | No mutual exclusions within UT. A player could take all six No-XP traits simultaneously and gain a total of (2+3+1+1+2+cost_of_noxpshooter) points for free. Intended or worth a design review. |

---

## 12. Data Flow Summary

```
[Character creation]
  └─ player selects UT_noxpaxe (+2 points)

[Events.OnNewGame fires]
  └─ onNewGame(player)
       ├─ UTCore.hasTrait(player, "UniversalTraits:UT_noxpaxe")
       │    └─ player:getTraits():contains("UniversalTraits:UT_noxpaxe") → true
       └─ UTCore.disableXP(player, "Axe")
            └─ player:getModData()["UT_xpDisable_Axe"] = true   [persists in save]

[Every Axe XP event for lifetime of save]
  └─ Events.AddXP fires → onAddXP(player, "Axe", amount)
       └─ md["UT_xpDisable_Axe"] == true
            └─ player:getXp():AddXP("Axe", -amount, false, false, false)
                 └─ net Axe XP = 0  (silent cancel)
```

---

## 13. File Inventory

| File | Role |
|---|---|
| `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_noxpaxe.lua` | Trait runtime — OnNewGame hook |
| `UniversalTraits/media/scripts/UT_character_traits.txt` line 1464 | Script definition (cost, name, multiplayer flag) |
| `UniversalTraits/media/registries.lua` line 209 | CharacterTrait.register call |
| `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` lines 449–450 | Display name and description |
| `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` | `UTCore.hasTrait` implementation |
| `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` line 46 | `UTCore.disableXP` implementation |
| `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua` | `Events.AddXP` intercept / cancel logic |
| `UniversalTraits/test/run_tests.lua` lines 262, 459, 969–973 | Registration + functional test coverage |
| `installed-mods/MoreTraits/…/MoreTraitsMainCreationMethods.lua` line 227 | Source mod reference (ToadTraits noxpaxe) |
| `installed-mods/MoreTraits/…/registries.lua` line 84 | Source mod registry reference |
