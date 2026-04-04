# UT_couchdweller

## Trait Summary
- UT trait id: `UniversalTraits:UT_couchdweller`
- Source mod: SomewhatTraits
- Source trait id: `SWCouchDweller`
- Current cost: 2 (positive — player pays 2 points to take it)
- Scripted: yes
- Owner: agent
- Status: DESCRIPTION BUG — fix required

---

## Source Evidence

### Files reviewed

| File | Key lines | Notes |
|---|---|---|
| `SomewhatTraits/mods/SomewhatTraits/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` | 9, 75, 119 | Registration (base/legacy) |
| `SomewhatTraits/mods/SomewhatTraits/42.12/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` | 9, 76, 120 | Registration (B42.12 variant) |
| `SomewhatTraits/mods/SomewhatTraitsCore/42.12/media/lua/client/SWSomewhatTraitsCore.lua` | 100, 183–205, 1058 | Client-side runtime (OnTick) |
| `SomewhatTraits/mods/SomewhatTraitsCore/42.13/media/lua/server/SWTraitsCore_server.lua` | 1–53, 104–116 | Server-side runtime (OnTick with 5 s stagger) |
| `SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` | 104–116 | Server-side runtime — identical to 42.13 |
| `SomewhatTraits/mods/SomewhatTraits/42.13/media/registries.lua` | 14 | `"SWCouchDweller", -- 2` |
| `SomewhatTraits/mods/SomewhatTraits/42.15/media/registries.lua` | 14 | Identical |
| `SomewhatTraits/mods/SomewhatTraits/42.13/media/lua/shared/SWTraits_MET.lua` | 41–45 | Mutual exclusion: `SWCouchDweller` ↔ `Claustrophobic` |
| `SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/SWTraits_MET.lua` | 41–45 | Identical |
| `SomewhatTraits/mods/SomewhatTraits/media/lua/shared/Translate/EN/UI_EN.txt` | 4–5 | Source UI strings |

### Source registration
```
TraitFactory.addTrait("SWCouchDweller", getText("UI_trait_SWCouchDweller"), 2, getText("UI_trait_SWCouchDwellerDesc"), false)
```
- Cost: **+2** (positive trait)
- Non-profession trait
- Source UI name: `"Couch Dweller"`
- Source description: `"Reduces unhappiness and slows down boredom gain when indoors."`

### Source behavior — server side (42.13 / 42.15, canonical path)

File: `SomewhatTraitsCore/42.13/media/lua/server/SWTraitsCore_server.lua`

The server file has a single `OnTick` dispatcher that runs every tick and internally staggers across players on a **5-second timer** (`timer = 5000 ms`, divided by player count). When a player's slot fires, `player` and `outside` module-locals are refreshed. All individual trait handlers subscribe to `Events.OnTick` and check these cached locals.

```lua
-- dispatcher (lines 31–53)
Events.OnTick.Add(function()
    player = nil
    ...
    if numPlayers > 0 and currentTime > timestamp + timer then
        timestamp = currentTime
        timer = 5000 / numPlayers
        player = getSpecificPlayer(playerIndex) -- or players:get(playerIndex) on server
        if player and not player:isDead() then
            outside = player:isOutside()
            ...
        end
        playerIndex = playerIndex + 1
    end
    currentTime = getTimestampMs()
end)

-- SWCouchDweller handler (lines 104–116)
local function SWCouchDweller()
    if not player then return end
    if not player:hasTrait(SWT.traits.SWCouchDweller) then return end
    if outside then return end
    local stats = player:getStats()
    local extraBoredom    = 1.0
    local extraUnhappyness = 1.0
    stats:remove(CharacterStat.BOREDOM, 1.0)
    stats:remove(CharacterStat.UNHAPPINESS, 1.0)
end
Events.OnTick.Add(SWCouchDweller)
```

**Effective cadence**: once every ~5 seconds per player (stagger timer), not every tick.
**No floor clamps in server code.** Values can go to zero or below via repeated `remove` calls; PZ engine presumably clamps at 0.

### Source behavior — client side (42.12, legacy path)

File: `SomewhatTraitsCore/42.12/media/lua/client/SWSomewhatTraitsCore.lua`

Client path uses `bodyDamage:getBoredomLevel()` / `bodyDamage:getUnhappynessLevel()` with explicit floor clamping and `timeMultiplier = 0.8`, `minBoredomLevel = 1`, `minUnhappynessLevel = 1`:

```lua
-- (lines 191–203)
local extraBoredom     = timeMultiplier * 0.1   -- 0.08 per tick
local extraUnhappyness = timeMultiplier          -- 0.8 per tick
if boredomLevel > minBoredomLevel then
    local newBoredom = boredomLevel - extraBoredom
    if newBoredom < minBoredomLevel then newBoredom = minBoredomLevel end
    bodyDamage:setBoredomLevel(newBoredom)
end
if unhappynessLevel > minUnhappynessLevel then
    local newUnhappyness = unhappynessLevel - extraUnhappyness
    if newUnhappyness < minUnhappynessLevel then newUnhappyness = minUnhappynessLevel end
    bodyDamage:setUnhappynessLevel(newUnhappyness)
end
```

The client path is visibly more conservative (0.08 boredom per tick, floor at 1). The server path removes 1.0 per ~5-second interval. UT follows the simpler server path.

### Source mutual exclusion
- `SWCouchDweller` ↔ `Claustrophobic` (vanilla trait). Both directions set via `CharacterTraitDefinition.getMutuallyExclusiveTraits():add(...)`.
- No other mutual exclusions declared.

---

## Current UT Evidence

### Structure

**Registry** (`UniversalTraits/media/registries.lua` line 126):
```lua
UTTraitsRegistries.UT_couchdweller  = CharacterTrait.register("UniversalTraits:UT_couchdweller")
```
Registered correctly. Namespace: `UniversalTraits:UT_couchdweller`.

**Script block** (`UniversalTraits/media/scripts/UT_character_traits.txt` lines 959–967):
```
character_trait_definition UniversalTraits:UT_couchdweller
{
    IsProfessionTrait = false,
    DisabledInMultiplayer = true,
    CharacterTrait = UniversalTraits:UT_couchdweller,
    Cost = 2,
    UIName = UI_UT_couchdweller,
    UIDescription = UI_UT_couchdwellerDesc,
}
```
Cost `2` matches source. `DisabledInMultiplayer = true` (consistent with all UT stat-modifier traits). No `XPBoostMap`, no `FreeRecipes`, no `MutualExclusive` entries in the script block — no mutual exclusion with Claustrophobic is carried over (design decision to drop it, or oversight; see Balance Review).

**Translation** (`UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` lines 281–282):
```lua
UI_UT_couchdweller     = "Couch Dweller",
UI_UT_couchdwellerDesc = "A sedentary lifestyle means you tire quickly. Endurance is reduced.",
```

**Test list** (`UniversalTraits/test/run_tests.lua` line 232):
```lua
"UniversalTraits:UT_couchdweller", "UniversalTraits:UT_sloth",
```
Trait is present in the smoke-test trait list (registration check). No behaviour-specific test case exists.

**Release sync**: `release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_couchdweller.lua` is byte-for-byte identical to the working copy. `release/UniversalTraits/42/media/registries.lua` is also identical to working copy.

### Runtime Trace

**File**: `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_couchdweller.lua`

```lua
-- UT_couchdweller.lua
-- Source: SomewhatTraits SWTraitsCore_server.lua — SWCouchDweller().
-- EveryOneMinute: while indoors, reduce boredom and unhappiness passively.

local TRAIT_ID = "UniversalTraits:UT_couchdweller"

local function handler(player)
    if not UTCore.hasTrait(player, TRAIT_ID) then return end
    if player:isOutside() then return end
    local stats = player:getStats()
    stats:remove(CharacterStat.BOREDOM, 1.0)
    stats:remove(CharacterStat.UNHAPPINESS, 1.0)
end

UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)
```

**Call chain:**

1. `UTCore.registerPeriodicHandler("UniversalTraits:UT_couchdweller", "EveryOneMinute", handler)`
   - Defined in `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua` line 16.
   - Builds key `"UniversalTraits:UT_couchdweller::EveryOneMinute"`.
   - Idempotent: skips if key already exists in `UTCore._periodicHandlers`.
   - Wraps `handler` in `wrappedFn = function() if getPlayer then handlerFn(getPlayer()) end end`.
   - Calls `Events["EveryOneMinute"].Add(wrappedFn)`.
   - **`EveryOneMinute` is a standard PZ server event that fires once per in-game minute.**

2. On each `EveryOneMinute` tick, `wrappedFn` calls `getPlayer()`.
   - `getPlayer()` returns the local player (single-player). In multiplayer this would return the first player; trait is `DisabledInMultiplayer = true` so MP is excluded.

3. `handler(player)`:
   - `UTCore.hasTrait(player, TRAIT_ID)` → `UTCore_API.lua` line 11: `player:getTraits():contains("UniversalTraits:UT_couchdweller")`. Returns `false` and exits if trait not held.
   - `player:isOutside()` → PZ Java method. Returns `true` if player is in an exterior cell. If `true`, exits — effect is indoor-only.
   - `player:getStats()` → returns `IsoGameCharacter.Stats` object.
   - `stats:remove(CharacterStat.BOREDOM, 1.0)` → subtracts 1.0 from the BOREDOM stat. No floor clamp in Lua; PZ engine clamps at 0.
   - `stats:remove(CharacterStat.UNHAPPINESS, 1.0)` → subtracts 1.0 from UNHAPPINESS. Same clamping.

**Effective cadence**: once per in-game minute (real-time interval depends on sandbox day-length setting; default day = 1 hr real time → `EveryOneMinute` fires approximately once per real second at default speed).

**Rate comparison vs source**:
- Source server (42.13): removes 1.0 boredom + 1.0 unhappiness every ~5 real seconds per player.
- UT: removes 1.0 boredom + 1.0 unhappiness every 1 in-game minute. At default day length (1-hr real day, 1440 in-game minutes) `EveryOneMinute` fires roughly once per real second — comparable magnitude. Functionally equivalent intent; exact feel varies with sandbox day speed. No floor clamp discrepancy: PZ engine clamps both APIs at 0.

---

## Description Integrity

**CRITICAL BUG: The description is completely wrong for this trait.**

| | Text |
|---|---|
| Source (SomewhatTraits) | `"Reduces unhappiness and slows down boredom gain when indoors."` |
| UT current | `"A sedentary lifestyle means you tire quickly. Endurance is reduced."` |

The current UT description describes a **negative endurance trait** (e.g. a "Sloth"-type penalty). The runtime does nothing to endurance — it removes boredom and unhappiness when indoors. The description belongs to a different trait entirely. This is a copy-paste error.

**Cost sign is also contradictory**: the trait costs `+2` (positive, player spends points), which is consistent with a benefit. The description implies it is a negative. A player reading the UI would believe they are buying a drawback, when the runtime gives a benefit.

**Correct description should be**: `"Reduces unhappiness and slows boredom gain while indoors."` (matching source intent and actual runtime behaviour).

---

## Balance Review

### Cost vs effect
- Source cost: **+2** (player pays 2 points for a positive trait).
- UT cost: **+2** — correctly carried over.
- Effect: -1.0 boredom and -1.0 unhappiness per in-game minute while indoors. At default day speed this is ~1 unit per real second. Boredom and unhappiness both run 0–100; passive NPC gain rates are slow (fractions per second). A flat 1.0/minute drain is a meaningful but not overwhelming comfort benefit. +2 points is a reasonable price.

### Missing mutual exclusion
- Source declares `SWCouchDweller` ↔ `Claustrophobic` mutual exclusion.
- UT has no mutual exclusion block in the script definition.
- `Claustrophobic` is a vanilla negative trait. Allowing a player to take both would let them stack the indoor comfort bonus against the stress penalty — arguably a valid combination thematically, but inconsistent with the source design intent. Whether to restore the exclusion is a design call; it is not a runtime bug.

### No XPBoost
- Source has no XP skill bonuses. UT correctly has none.

### `DisabledInMultiplayer = true`
- Source runs on a single-player-focused OnTick stagger. UT marks trait disabled in multiplayer. Consistent.

---

## Regression Proof

| Check | Result |
|---|---|
| `CharacterTrait.register` call in `registries.lua` | PASS — line 126 |
| Script block present in `UT_character_traits.txt` | PASS — lines 959–967 |
| `Cost = 2` matches source | PASS |
| `IsProfessionTrait = false` | PASS |
| `DisabledInMultiplayer = true` | PASS |
| UI key `UI_UT_couchdweller` resolves in `UI_EN.txt` | PASS — line 281 |
| UI key `UI_UT_couchdwellerDesc` resolves in `UI_EN.txt` | PASS — line 282 |
| Trait ID in `run_tests.lua` smoke list | PASS — line 232 |
| `TRAIT_ID` constant matches registry string | PASS — both `"UniversalTraits:UT_couchdweller"` |
| `EveryOneMinute` is a valid PZ event name | PASS — documented PZ event |
| `registerPeriodicHandler` idempotent guard | PASS — key-based, will not double-register |
| `UTCore.hasTrait` nil-safe guard | PASS — returns false if player is nil |
| `player:isOutside()` indoor gate | PASS — correctly excludes outdoor ticks |
| `stats:remove(CharacterStat.BOREDOM, 1.0)` | PASS — correct stat enum, correct amount |
| `stats:remove(CharacterStat.UNHAPPINESS, 1.0)` | PASS — correct stat enum, correct amount |
| Release folder synced to working copy | PASS — byte-for-byte identical |
| **Description text matches runtime behaviour** | **FAIL — endurance description on a boredom/unhappiness trait** |

---

## Final Verdict

**Status: FAIL — description bug blocks release.**

The trait is structurally complete and the runtime logic is correct: it removes 1.0 boredom and 1.0 unhappiness per in-game minute while indoors, fired via `EveryOneMinute`, consistent with the SomewhatTraits source intent and cost. Registration, script block, release sync, and test list are all clean.

**The only blocking issue** is the description in `UI_EN.txt`:

```
-- CURRENT (wrong):
UI_UT_couchdwellerDesc = "A sedentary lifestyle means you tire quickly. Endurance is reduced.",

-- REQUIRED:
UI_UT_couchdwellerDesc = "Reduces unhappiness and slows boredom gain while indoors.",
```

Fix that line and the trait is shippable. The missing Claustrophobic mutual exclusion is a design decision to record but not a blocker.
