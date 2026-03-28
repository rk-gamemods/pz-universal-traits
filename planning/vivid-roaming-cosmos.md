# UTMods Completion & Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the 6 missing runtime hooks in UT_CORE so that all 199 traits have actual in-game effect, and expand the test suite to cover behavioral correctness.

**Architecture:** Four new UTCore hook modules live exclusively in `UT_CORE/media/lua/shared/UTCore/`. Each module registers one event handler and reads moddata keys already set by existing trait files — no trait files are modified. Tests use the existing `UTCoreMocks.lua` stub pattern (standard Lua 5.x, no PZ runtime required).

**Tech Stack:** Lua 5.x (PZ B42 Kahlua), standard Lua 5.x test runner at `C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe`, PZ B42 events (`Events.AddXP`, `Events.OnPlayerMove`, `Events.OnGameBoot`, `Events.OnPlayerUpdate`).

**Test commands (run from repo root):**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua
```

**Repo root:** `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods`

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| CREATE | `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua` | `Events.AddXP` handler; reads `UT_xpMult_*`, `UT_xpDisable_*`, `UT_multiSkillPenalty` |
| CREATE | `UT_CORE/media/lua/shared/UTCore/UTCore_SpeedHook.lua` | `Events.OnPlayerMove` handler; reads `UT_speedMod` |
| CREATE | `UT_CORE/media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua` | `Events.OnGameBoot` hook; overrides `getDuration()` globally; reads `UT_workSpeedMod`, `UT_readSpeedMod` |
| CREATE | `UT_CORE/media/lua/shared/UTCore/UTCore_BleedHook.lua` | `Events.OnPlayerUpdate` throttled handler; reads `UT_bleedMult` |
| UPDATE | `UT_CORE/test/run_tests.lua` | Add 10 behavioral tests for all 4 new hook modules (25 total) |
| UPDATE | `UniversalTraits/test/run_tests.lua` | Add 7 moddata spot-check tests for gap traits (28 total) |
| UPDATE | `AGENTS.md` | Mark all 6 gaps resolved; document new hook modules |

**No trait files are modified.** All moddata keys are already written correctly by existing trait handlers.

---

## Task 1: UTCore_XPHook — AddXP intercept

**Files:**

- Create: `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua`
- Modify: `UT_CORE/test/run_tests.lua`
- Modify: `UT_CORE/test/UTCoreMocks.lua`

### Background

`UTCore.applyXPMultiplier(player, perkName, multiplier)` writes `UT_xpMult_<perkName>` to moddata.
`UTCore.disableXP(player, perkName)` writes `UT_xpDisable_<perkName> = true` to moddata.
`UT_onetrickpony.lua` writes `UT_multiSkillPenalty = true` to moddata.
None of these are read anywhere. This task creates the `Events.AddXP` handler that reads all three.

**B42 AddXP note:** `Events.AddXP` fires with `(player, perk, amount)`. XP cannot be truly cancelled from a hook — the pattern is to immediately call `player:getXp():AddXP(perk, -correction, false, false, false)` to negate it. This is the standard approach used by research mods.

- [ ] **Step 1: Add `Events.AddXP` mock to `UTCoreMocks.lua`**

Open `UT_CORE/test/UTCoreMocks.lua`. Append at the bottom (before any closing code):

```lua
-- Mock XP system
if not _G.Perks then _G.Perks = {} end

if not _G.Events then _G.Events = {} end
if not _G.Events.AddXP then
    _G.Events.AddXP = { _handlers = {} }
    _G.Events.AddXP.Add = function(self, fn) table.insert(self._handlers, fn) end
    _G.Events.AddXP.fire = function(self, player, perk, amount)
        for _, fn in ipairs(self._handlers) do fn(player, perk, amount) end
    end
end

-- Extend mock player with XP tracking
function MockPlayer:addXpCall(perk, amount)
    if not self._xpCalls then self._xpCalls = {} end
    table.insert(self._xpCalls, { perk = perk, amount = amount })
end

function MockPlayer:getXpCalls()
    return self._xpCalls or {}
end

-- Extend mock player with getXp() returning a table that records AddXP calls
function MockPlayer:getXp()
    local player = self
    return {
        AddXP = function(self2, perk, amount, a, b, c)
            player:addXpCall(perk, amount)
        end
    }
end
```

- [ ] **Step 2: Run existing tests to confirm mock change didn't break anything**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
```

Expected: all existing tests still pass (currently 15).

- [ ] **Step 3: Write failing tests for XPHook in `run_tests.lua`**

Open `UT_CORE/test/run_tests.lua`. Add these 4 tests before the final `print("All tests passed.")` line:

```lua
-- ===== UTCore_XPHook Tests =====
dofile("UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua")

-- Test: XP multiplier is applied
local xpMultPlayer = MockPlayer.new()
xpMultPlayer:getModData()["UT_xpMult_Aiming"] = 2.0
Events.AddXP:fire(xpMultPlayer, "Aiming", 10)
local xpCalls = xpMultPlayer:getXpCalls()
-- Should have one correction call for the extra 10 XP (net = 20)
assert(#xpCalls >= 1, "XP multiplier: expected correction AddXP call")
local totalXP = 0
for _, c in ipairs(xpCalls) do
    if c.perk == "Aiming" then totalXP = totalXP + c.amount end
end
assert(totalXP == 10, "XP multiplier: correction should add 10 more (2x of original 10), got " .. totalXP)
print("PASS: XP multiplier applied")

-- Test: XP disable cancels XP
local xpDisablePlayer = MockPlayer.new()
xpDisablePlayer:getModData()["UT_xpDisable_Aiming"] = true
Events.AddXP:fire(xpDisablePlayer, "Aiming", 10)
local disableCalls = xpDisablePlayer:getXpCalls()
local disableTotal = 0
for _, c in ipairs(disableCalls) do
    if c.perk == "Aiming" then disableTotal = disableTotal + c.amount end
end
assert(disableTotal == -10, "XP disable: correction should be -10 to cancel, got " .. disableTotal)
print("PASS: XP disable cancels gain")

-- Test: multi-skill penalty fires when 2+ perks gain XP in same minute
local multiPlayer = MockPlayer.new()
multiPlayer:getModData()["UT_multiSkillPenalty"] = true
Events.AddXP:fire(multiPlayer, "Aiming", 10)   -- first perk this minute
Events.AddXP:fire(multiPlayer, "Reloading", 10) -- second perk → penalty should fire
local multiCalls = multiPlayer:getXpCalls()
local reloadingTotal = 0
for _, c in ipairs(multiCalls) do
    if c.perk == "Reloading" then reloadingTotal = reloadingTotal + c.amount end
end
assert(reloadingTotal < 0, "Multi-skill penalty: second perk should have negative correction, got " .. reloadingTotal)
print("PASS: Multi-skill penalty fires for 2nd perk")

-- Test: multi-skill penalty does NOT fire for single perk
local singlePlayer = MockPlayer.new()
singlePlayer:getModData()["UT_multiSkillPenalty"] = true
Events.AddXP:fire(singlePlayer, "Aiming", 10)   -- only perk this minute
local singleCalls = singlePlayer:getXpCalls()
local singleTotal = 0
for _, c in ipairs(singleCalls) do
    if c.perk == "Aiming" then singleTotal = singleTotal + c.amount end
end
assert(singleTotal >= 0, "Multi-skill penalty: single perk should not be penalized, got " .. singleTotal)
print("PASS: Multi-skill penalty skips single-perk session")
```

- [ ] **Step 4: Run tests to confirm they fail**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
```

Expected: error loading `UTCore_XPHook.lua` (file doesn't exist yet).

- [ ] **Step 5: Create `UTCore_XPHook.lua`**

Create `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua`:

```lua
-- UTCore_XPHook.lua
-- Intercepts Events.AddXP to apply UT_ XP multipliers, disables, and multi-skill penalties.
-- Traits set moddata keys; this module reads them and applies corrections.

UTCore = UTCore or {}

-- Tracks which perks earned XP this in-game minute (per player, keyed by perk name).
-- Reset at the start of each new in-game minute via EveryOneMinute.
local _xpPerksThisMinute = {}

local function resetXPTracking()
    _xpPerksThisMinute = {}
end

if Events and Events.EveryOneMinute then
    Events.EveryOneMinute.Add(resetXPTracking)
end

-- Called by Events.AddXP handler.
-- perk: string perk name (e.g. "Aiming")
-- amount: XP amount being added (positive)
local function onAddXP(player, perk, amount)
    if not player or not perk or not amount or amount <= 0 then return end
    local md = player:getModData()

    -- 1. XP disable: cancel the full amount
    if md["UT_xpDisable_" .. perk] then
        player:getXp():AddXP(perk, -amount, false, false, false)
        return
    end

    -- 2. XP multiplier: add the bonus delta
    local mult = md["UT_xpMult_" .. perk]
    if mult and mult ~= 1.0 then
        local bonus = math.floor(amount * (mult - 1.0))
        if bonus ~= 0 then
            player:getXp():AddXP(perk, bonus, false, false, false)
        end
    end

    -- 3. Multi-skill penalty (UT_onetrickpony): 50% penalty on 2nd+ perk per minute
    if md["UT_multiSkillPenalty"] then
        local pid = tostring(player)
        if not _xpPerksThisMinute[pid] then
            _xpPerksThisMinute[pid] = {}
        end
        local seen = _xpPerksThisMinute[pid]
        if not seen[perk] then
            seen[perk] = true
        end
        -- Count distinct perks seen this minute
        local count = 0
        for _ in pairs(seen) do count = count + 1 end
        if count > 1 then
            -- Apply 50% penalty (subtract half the original amount)
            local penalty = -math.floor(amount * 0.5)
            player:getXp():AddXP(perk, penalty, false, false, false)
        end
    end
end

if Events and Events.AddXP then
    Events.AddXP.Add(onAddXP)
end
```

- [ ] **Step 6: Run tests to confirm XPHook tests pass**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
```

Expected: 19 tests passing (15 existing + 4 new XPHook tests).

- [ ] **Step 7: Commit**

```bash
cd "C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods"
git add UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua UT_CORE/test/UTCoreMocks.lua UT_CORE/test/run_tests.lua
git commit -m "feat: implement UTCore_XPHook for AddXP interception (XP mult, disable, onetrickpony)"
```

---

## Task 2: UTCore_SpeedHook — OnPlayerMove delta multiplier

**Files:**

- Create: `UT_CORE/media/lua/shared/UTCore/UTCore_SpeedHook.lua`
- Modify: `UT_CORE/test/UTCoreMocks.lua`
- Modify: `UT_CORE/test/run_tests.lua`

### Background

`UTCore.applySpeedModifier(player, amount)` writes `UT_speedMod` to moddata (e.g. `0.3` = 30% faster).
The hook uses `Events.OnPlayerMove`. It reads previous X/Y from moddata (`UT_prevX`, `UT_prevY`), computes the movement delta, multiplies it by `(1 + UT_speedMod)`, and repositions the player. A teleport guard skips adjustments when delta > 5 tiles.

- [ ] **Step 1: Add `Events.OnPlayerMove` mock and `setX`/`setY`/`getX`/`getY` to MockPlayer**

Open `UT_CORE/test/UTCoreMocks.lua`. Append:

```lua
-- Mock position tracking for SpeedHook
function MockPlayer:getX() return self._x or 0 end
function MockPlayer:getY() return self._y or 0 end
function MockPlayer:setX(v) self._x = v end
function MockPlayer:setY(v) self._y = v end
function MockPlayer:isLocalPlayer() return true end

-- Simulate a move: set new position before firing event
function MockPlayer:moveTo(x, y)
    self._x = x
    self._y = y
end

if not _G.Events.OnPlayerMove then
    _G.Events.OnPlayerMove = { _handlers = {} }
    _G.Events.OnPlayerMove.Add = function(self, fn) table.insert(self._handlers, fn) end
    _G.Events.OnPlayerMove.fire = function(self)
        for _, fn in ipairs(self._handlers) do fn() end
    end
end

-- getPlayer() global mock override (SpeedHook uses getPlayer())
_G._mockSpeedPlayer = nil
_G.getPlayer = function() return _G._mockSpeedPlayer end
```

- [ ] **Step 2: Write failing tests for SpeedHook**

In `UT_CORE/test/run_tests.lua`, add before `print("All tests passed.")`:

```lua
-- ===== UTCore_SpeedHook Tests =====
dofile("UT_CORE/media/lua/shared/UTCore/UTCore_SpeedHook.lua")

-- Test: positive speedMod amplifies movement delta
local speedPlayer = MockPlayer.new()
speedPlayer:getModData()["UT_speedMod"] = 0.5  -- 50% faster
speedPlayer:moveTo(0, 0)
_G._mockSpeedPlayer = speedPlayer
Events.OnPlayerMove:fire()  -- first call: stores prevX/prevY = 0,0
speedPlayer:moveTo(2, 0)    -- player moved 2 units on X
Events.OnPlayerMove:fire()  -- second call: should amplify to 3 units (2 * 1.5)
local resultX = speedPlayer:getX()
assert(math.abs(resultX - 3.0) < 0.01, "SpeedHook positive: expected X=3.0, got " .. tostring(resultX))
print("PASS: Speed hook amplifies movement (fast)")

-- Test: negative speedMod reduces movement delta
local slowPlayer = MockPlayer.new()
slowPlayer:getModData()["UT_speedMod"] = -0.3  -- 30% slower
slowPlayer:moveTo(0, 0)
_G._mockSpeedPlayer = slowPlayer
Events.OnPlayerMove:fire()
slowPlayer:moveTo(2, 0)
Events.OnPlayerMove:fire()
local slowX = slowPlayer:getX()
assert(math.abs(slowX - 1.4) < 0.01, "SpeedHook negative: expected X=1.4, got " .. tostring(slowX))
print("PASS: Speed hook reduces movement (slow)")

-- Test: teleport guard skips adjustment when delta > 5
local telePlayer = MockPlayer.new()
telePlayer:getModData()["UT_speedMod"] = 0.5
telePlayer:moveTo(0, 0)
_G._mockSpeedPlayer = telePlayer
Events.OnPlayerMove:fire()
telePlayer:moveTo(10, 0)  -- delta = 10, exceeds guard threshold
Events.OnPlayerMove:fire()
local teleX = telePlayer:getX()
assert(math.abs(teleX - 10.0) < 0.01, "SpeedHook teleport guard: X should be unchanged at 10.0, got " .. tostring(teleX))
print("PASS: Speed hook teleport guard skips large delta")

_G._mockSpeedPlayer = nil
```

- [ ] **Step 3: Run tests to confirm they fail**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
```

Expected: error loading `UTCore_SpeedHook.lua`.

- [ ] **Step 4: Create `UTCore_SpeedHook.lua`**

Create `UT_CORE/media/lua/shared/UTCore/UTCore_SpeedHook.lua`:

```lua
-- UTCore_SpeedHook.lua
-- Applies movement speed modifiers stored in UT_speedMod moddata.
-- Uses Events.OnPlayerMove: reads previous position from moddata, computes delta,
-- multiplies by (1 + UT_speedMod), repositions player.
-- Teleport guard: skips if delta > 5 tiles on either axis.

UTCore = UTCore or {}

local TELEPORT_GUARD = 5.0

local function onPlayerMove()
    local player = getPlayer()
    if not player then return end
    if not player:isLocalPlayer() then return end

    local md = player:getModData()
    local mod = md["UT_speedMod"]
    if not mod or mod == 0 then
        -- Still update prevX/prevY so next call has a baseline
        md["UT_prevX"] = player:getX()
        md["UT_prevY"] = player:getY()
        return
    end

    local newX = player:getX()
    local newY = player:getY()
    local prevX = md["UT_prevX"]
    local prevY = md["UT_prevY"]

    if prevX == nil or prevY == nil then
        md["UT_prevX"] = newX
        md["UT_prevY"] = newY
        return
    end

    local dx = newX - prevX
    local dy = newY - prevY

    -- Teleport guard
    if math.abs(dx) > TELEPORT_GUARD or math.abs(dy) > TELEPORT_GUARD then
        md["UT_prevX"] = newX
        md["UT_prevY"] = newY
        return
    end

    if dx ~= 0 or dy ~= 0 then
        local factor = 1.0 + mod
        player:setX(prevX + dx * factor)
        player:setY(prevY + dy * factor)
    end

    md["UT_prevX"] = player:getX()
    md["UT_prevY"] = player:getY()
end

if Events and Events.OnPlayerMove then
    Events.OnPlayerMove.Add(onPlayerMove)
end
```

- [ ] **Step 5: Run tests to confirm SpeedHook tests pass**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
```

Expected: 22 tests passing (19 + 3 new SpeedHook).

- [ ] **Step 6: Commit**

```bash
git add UT_CORE/media/lua/shared/UTCore/UTCore_SpeedHook.lua UT_CORE/test/UTCoreMocks.lua UT_CORE/test/run_tests.lua
git commit -m "feat: implement UTCore_SpeedHook for OnPlayerMove speed delta multiplication"
```

---

## Task 3: UTCore_WorkSpeedHook — getDuration() override

**Files:**

- Create: `UT_CORE/media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua`
- Modify: `UT_CORE/test/UTCoreMocks.lua`
- Modify: `UT_CORE/test/run_tests.lua`

### Background

`UTCore.applyWorkSpeed(player, delta)` writes `UT_workSpeedMod` (negative = faster, positive = slower).
`UT_flatearther.lua` writes `UT_readSpeedMod = 0.3` (30% slower reading).
`UT_photographicmemory.lua` writes `UT_readSpeedMod = -0.2` (20% faster reading).
The hook overrides `getDuration()` on all TimedAction tables at `Events.OnGameBoot`. For `ISReadABook` actions, both `UT_workSpeedMod` and `UT_readSpeedMod` are combined.

- [ ] **Step 1: Add `Events.OnGameBoot` mock and mock TimedAction to UTCoreMocks**

Open `UT_CORE/test/UTCoreMocks.lua`. Append:

```lua
-- Mock OnGameBoot
if not _G.Events.OnGameBoot then
    _G.Events.OnGameBoot = { _handlers = {} }
    _G.Events.OnGameBoot.Add = function(self, fn) table.insert(self._handlers, fn) end
    _G.Events.OnGameBoot.fire = function(self)
        for _, fn in ipairs(self._handlers) do fn() end
    end
end

-- Mock TimedAction for work speed tests
MockTimedAction = {}
MockTimedAction.__index = MockTimedAction

function MockTimedAction.new(player, actionType, baseDuration)
    local t = setmetatable({}, MockTimedAction)
    t.character = player
    t.Type = actionType or "ISCraftItem"
    t.maxTime = baseDuration or 100
    t.getDuration = function(self2) return self2.maxTime end
    return t
end

-- Register a global table with getDuration so the hook can find it
_G.MockTimedAction = MockTimedAction
```

- [ ] **Step 2: Write failing tests for WorkSpeedHook**

In `UT_CORE/test/run_tests.lua`, add before `print("All tests passed.")`:

```lua
-- ===== UTCore_WorkSpeedHook Tests =====
dofile("UT_CORE/media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua")
Events.OnGameBoot:fire()  -- triggers getDuration override on all globals

-- Test: negative workSpeedMod shortens duration (faster worker)
local fastWorker = MockPlayer.new()
fastWorker:getModData()["UT_workSpeedMod"] = -0.5
local action1 = MockTimedAction.new(fastWorker, "ISCraftItem", 100)
local result1 = action1:getDuration()
assert(math.abs(result1 - 50) < 1, "WorkSpeed fast: expected ~50, got " .. tostring(result1))
print("PASS: Work speed negative mod shortens duration")

-- Test: positive workSpeedMod lengthens duration (slower worker)
local slowWorker = MockPlayer.new()
slowWorker:getModData()["UT_workSpeedMod"] = 0.5
local action2 = MockTimedAction.new(slowWorker, "ISCraftItem", 100)
local result2 = action2:getDuration()
assert(math.abs(result2 - 150) < 1, "WorkSpeed slow: expected ~150, got " .. tostring(result2))
print("PASS: Work speed positive mod lengthens duration")

-- Test: ISReadABook gets readSpeedMod applied on top of workSpeedMod
local readPlayer = MockPlayer.new()
readPlayer:getModData()["UT_workSpeedMod"] = 0     -- no general work mod
readPlayer:getModData()["UT_readSpeedMod"] = 0.3   -- 30% slower reading
local action3 = MockTimedAction.new(readPlayer, "ISReadABook", 100)
local result3 = action3:getDuration()
assert(math.abs(result3 - 130) < 1, "WorkSpeed read: expected ~130, got " .. tostring(result3))
print("PASS: Read speed mod applied to ISReadABook duration")
```

- [ ] **Step 3: Run tests to confirm they fail**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
```

Expected: error loading `UTCore_WorkSpeedHook.lua`.

- [ ] **Step 4: Create `UTCore_WorkSpeedHook.lua`**

Create `UT_CORE/media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua`:

```lua
-- UTCore_WorkSpeedHook.lua
-- At OnGameBoot, wraps getDuration() on all global TimedAction tables.
-- Reads UT_workSpeedMod (general) and UT_readSpeedMod (ISReadABook only) from player moddata.
-- Modifiers are additive deltas: -0.5 = 50% faster, +0.5 = 50% slower.
-- Minimum returned duration is always 1.

UTCore = UTCore or {}

-- Apply work/read speed modifiers to a base duration.
-- self: the TimedAction instance (has self.character and self.Type)
-- base: the original duration from the unpatched getDuration()
function UTCore.applyWorkDuration(self, base)
    if not base or base <= 1 then return base end
    local player = self.character
    if not player then return base end

    local md = player:getModData()
    local workMod = md["UT_workSpeedMod"] or 0
    local readMod = 0
    if self.Type == "ISReadABook" then
        readMod = md["UT_readSpeedMod"] or 0
    end

    local totalMod = workMod + readMod
    if totalMod == 0 then return base end

    return math.max(1, math.floor(base * (1.0 + totalMod)))
end

local function patchTimedActions()
    for _, v in pairs(_G) do
        if type(v) == "table" and type(v.getDuration) == "function" then
            local orig = v.getDuration
            v.getDuration = function(self2)
                local base = orig(self2)
                return UTCore.applyWorkDuration(self2, base)
            end
        end
    end
end

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(patchTimedActions)
end
```

- [ ] **Step 5: Run tests to confirm WorkSpeedHook tests pass**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
```

Expected: 25 tests passing (22 + 3 new WorkSpeedHook). This is the final UT_CORE test count target.

- [ ] **Step 6: Commit**

```bash
git add UT_CORE/media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua UT_CORE/test/UTCoreMocks.lua UT_CORE/test/run_tests.lua
git commit -m "feat: implement UTCore_WorkSpeedHook for getDuration override (work speed + read speed)"
```

---

## Task 4: UTCore_BleedHook — bleeding body part iteration

**Files:**

- Create: `UT_CORE/media/lua/shared/UTCore/UTCore_BleedHook.lua`
- Modify: `UT_CORE/test/UTCoreMocks.lua`
- Modify: `UT_CORE/test/run_tests.lua`

### Background

Three traits write `UT_bleedMult`:

- `UT_thickblood`: 0.4 (slow bleed — call `AddHealth` to counteract)
- `UT_weaklybleedingwounds`: 0.6 (slow bleed)
- `UT_heavilybleedingwounds`: 2.0 (fast bleed — call `ReduceHealth` to accelerate)

The hook runs every 30 `OnPlayerUpdate` ticks. For each bleeding, non-stemmed body part:

- If `UT_bleedMult < 1.0`: call `bodyPart:AddHealth(0.002 * (1.0 - mult))` — counteracts bleed
- If `UT_bleedMult > 1.0`: call `bodyPart:ReduceHealth(0.001 * (mult - 1.0))` — accelerates bleed
- Neck body part gets `× 2` on both

- [ ] **Step 1: Add BodyDamage/BodyPart mocks and OnPlayerUpdate mock to UTCoreMocks**

Open `UT_CORE/test/UTCoreMocks.lua`. Append:

```lua
-- Mock BodyPart
MockBodyPart = {}
MockBodyPart.__index = MockBodyPart
function MockBodyPart.new(partType, isBleeding, isStemmed)
    local b = setmetatable({}, MockBodyPart)
    b._type = partType or "Torso_Upper"
    b._bleeding = isBleeding or false
    b._stemmed = isStemmed or false
    b._health = 1.0
    b._addHealthCalls = 0
    b._reduceHealthCalls = 0
    b._addHealthTotal = 0
    b._reduceHealthTotal = 0
    return b
end
function MockBodyPart:getType() return self._type end
function MockBodyPart:bleeding() return self._bleeding end
function MockBodyPart:IsBleedingStemmed() return self._stemmed end
function MockBodyPart:getHealth() return self._health end
function MockBodyPart:AddHealth(v)
    self._addHealthCalls = self._addHealthCalls + 1
    self._addHealthTotal = self._addHealthTotal + v
    self._health = self._health + v
end
function MockBodyPart:ReduceHealth(v)
    self._reduceHealthCalls = self._reduceHealthCalls + 1
    self._reduceHealthTotal = self._reduceHealthTotal + v
    self._health = self._health - v
end

-- Mock BodyPartsList (Java-like size()/get(i))
MockBodyPartsList = {}
MockBodyPartsList.__index = MockBodyPartsList
function MockBodyPartsList.new(parts)
    local l = setmetatable({}, MockBodyPartsList)
    l._parts = parts or {}
    return l
end
function MockBodyPartsList:size() return #self._parts end
function MockBodyPartsList:get(i) return self._parts[i + 1] end  -- 0-indexed like Java

-- Mock BodyDamage
MockBodyDamage = {}
MockBodyDamage.__index = MockBodyDamage
function MockBodyDamage.new(parts)
    local d = setmetatable({}, MockBodyDamage)
    d._parts = MockBodyPartsList.new(parts)
    d._bleedingCount = 0
    for _, p in ipairs(parts or {}) do
        if p:bleeding() then d._bleedingCount = d._bleedingCount + 1 end
    end
    return d
end
function MockBodyDamage:getBodyParts() return self._parts end
function MockBodyDamage:getNumPartsBleeding() return self._bleedingCount end

-- Extend MockPlayer with getBodyDamage()
function MockPlayer:setBodyDamage(bd) self._bodyDamage = bd end
function MockPlayer:getBodyDamage() return self._bodyDamage end

-- OnPlayerUpdate mock (throttle test uses tick counter)
if not _G.Events.OnPlayerUpdate then
    _G.Events.OnPlayerUpdate = { _handlers = {} }
    _G.Events.OnPlayerUpdate.Add = function(self, fn) table.insert(self._handlers, fn) end
    _G.Events.OnPlayerUpdate.fire = function(self, player)
        for _, fn in ipairs(self._handlers) do fn(player) end
    end
end

-- BodyPartType constants used by BleedHook
if not _G.BodyPartType then
    _G.BodyPartType = { Neck = "Neck" }
end
```

- [ ] **Step 2: Write failing tests for BleedHook**

In `UT_CORE/test/run_tests.lua`, add before `print("All tests passed.")`:

```lua
-- ===== UTCore_BleedHook Tests =====
dofile("UT_CORE/media/lua/shared/UTCore/UTCore_BleedHook.lua")

-- Test: AddHealth called for mult < 1.0 (thickblood)
local thickPlayer = MockPlayer.new()
thickPlayer:getModData()["UT_bleedMult"] = 0.4
local torso = MockBodyPart.new("Torso_Upper", true, false)
local bd1 = MockBodyDamage.new({ torso })
thickPlayer:setBodyDamage(bd1)
_G._mockSpeedPlayer = thickPlayer  -- reuse getPlayer mock
-- Fire OnPlayerUpdate 30 times to pass throttle
for i = 1, 30 do Events.OnPlayerUpdate:fire(thickPlayer) end
assert(torso._addHealthCalls >= 1, "BleedHook mult<1: expected AddHealth call, got " .. torso._addHealthCalls)
print("PASS: BleedHook calls AddHealth for mult < 1.0")

-- Test: ReduceHealth called for mult > 1.0 (heavilybleedingwounds)
local heavyPlayer = MockPlayer.new()
heavyPlayer:getModData()["UT_bleedMult"] = 2.0
local torso2 = MockBodyPart.new("Torso_Upper", true, false)
local bd2 = MockBodyDamage.new({ torso2 })
heavyPlayer:setBodyDamage(bd2)
_G._mockSpeedPlayer = heavyPlayer
for i = 1, 30 do Events.OnPlayerUpdate:fire(heavyPlayer) end
assert(torso2._reduceHealthCalls >= 1, "BleedHook mult>1: expected ReduceHealth call, got " .. torso2._reduceHealthCalls)
print("PASS: BleedHook calls ReduceHealth for mult > 1.0")

_G._mockSpeedPlayer = nil
```

- [ ] **Step 3: Run tests to confirm they fail**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
```

Expected: error loading `UTCore_BleedHook.lua`.

- [ ] **Step 4: Create `UTCore_BleedHook.lua`**

Create `UT_CORE/media/lua/shared/UTCore/UTCore_BleedHook.lua`:

```lua
-- UTCore_BleedHook.lua
-- Applies UT_bleedMult moddata to active bleeding body parts.
-- Throttled: fires every 30 OnPlayerUpdate ticks.
-- mult < 1.0: counteracts bleeding via AddHealth
-- mult > 1.0: accelerates bleeding via ReduceHealth
-- Neck body part receives 2× adjustment.

UTCore = UTCore or {}

local THROTTLE = 30
local _tickCounter = 0

local function onPlayerUpdate(player)
    if not player then return end
    _tickCounter = _tickCounter + 1
    if _tickCounter < THROTTLE then return end
    _tickCounter = 0

    local md = player:getModData()
    local mult = md["UT_bleedMult"]
    if not mult or mult == 1.0 then return end

    local bd = player:getBodyDamage()
    if not bd then return end
    if bd:getNumPartsBleeding() == 0 then return end

    local parts = bd:getBodyParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part:bleeding() and not part:IsBleedingStemmed() then
            local neckMult = (part:getType() == BodyPartType.Neck) and 2.0 or 1.0
            if mult < 1.0 then
                part:AddHealth(0.002 * (1.0 - mult) * neckMult)
            else
                part:ReduceHealth(0.001 * (mult - 1.0) * neckMult)
            end
        end
    end
end

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end
```

- [ ] **Step 5: Run tests to confirm BleedHook tests pass**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
```

Expected: 27 tests passing (25 + 2 new BleedHook).

**Note:** Total is now 27, not 25 — the spec target of 25 was before BleedHook tests were counted separately. Final UT_CORE count will be 27.

- [ ] **Step 6: Commit**

```bash
git add UT_CORE/media/lua/shared/UTCore/UTCore_BleedHook.lua UT_CORE/test/UTCoreMocks.lua UT_CORE/test/run_tests.lua
git commit -m "feat: implement UTCore_BleedHook for bleed rate modification via BodyPart health adjustment"
```

---

## Task 5: UniversalTraits behavioral moddata tests

**Files:**

- Modify: `UniversalTraits/test/run_tests.lua`

### Background

The UniversalTraits test suite currently only validates that 199 traits are registered. It doesn't test that individual trait Lua files actually write the expected moddata keys when called. This task adds spot-check tests for the 7 gap traits to confirm moddata is set correctly (the hooks in Tasks 1–4 depend on these keys being set).

- [ ] **Step 1: Write failing tests for gap trait moddata**

Open `UniversalTraits/test/run_tests.lua`. Add these 7 tests before the final `print("All tests passed.")` line:

```lua
-- ===== Per-trait moddata spot checks =====
-- These tests confirm gap traits write the moddata keys that UTCore hooks read.
-- Each test: create a mock player, fire OnNewGame, assert moddata key set.

-- Load the trait files being tested
dofile("UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_onetrickpony.lua")
dofile("UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_flatearther.lua")
dofile("UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_fast.lua")
dofile("UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_noodlelegs.lua")
dofile("UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_quickworker.lua")
dofile("UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_thickblood.lua")
dofile("UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_heavilybleedingwounds.lua")

-- Helper: fire OnNewGame for a player with the given traitId active
local function fireNewGame(traitId)
    local p = MockPlayer.new()
    p:addTrait(traitId)
    Events.OnNewGame:fire(p)
    return p
end

-- UT_onetrickpony sets UT_multiSkillPenalty = true
local otp = fireNewGame("UniversalTraits:UT_onetrickpony")
assert(otp:getModData()["UT_multiSkillPenalty"] == true,
    "UT_onetrickpony: expected UT_multiSkillPenalty=true")
print("PASS: UT_onetrickpony sets UT_multiSkillPenalty")

-- UT_flatearther sets UT_readSpeedMod > 0 (slower reading)
local fe = fireNewGame("UniversalTraits:UT_flatearther")
local feRead = fe:getModData()["UT_readSpeedMod"]
assert(type(feRead) == "number" and feRead > 0,
    "UT_flatearther: expected UT_readSpeedMod > 0, got " .. tostring(feRead))
print("PASS: UT_flatearther sets UT_readSpeedMod positive")

-- UT_fast sets UT_speedMod > 0 (faster movement)
local fast = fireNewGame("UniversalTraits:UT_fast")
local fastMod = fast:getModData()["UT_speedMod"]
assert(type(fastMod) == "number" and fastMod > 0,
    "UT_fast: expected UT_speedMod > 0, got " .. tostring(fastMod))
print("PASS: UT_fast sets UT_speedMod positive")

-- UT_noodlelegs sets UT_speedMod < 0 (slower movement)
local noodle = fireNewGame("UniversalTraits:UT_noodlelegs")
local noodleMod = noodle:getModData()["UT_speedMod"]
assert(type(noodleMod) == "number" and noodleMod < 0,
    "UT_noodlelegs: expected UT_speedMod < 0, got " .. tostring(noodleMod))
print("PASS: UT_noodlelegs sets UT_speedMod negative")

-- UT_quickworker sets UT_workSpeedMod < 0 (faster work)
local qw = fireNewGame("UniversalTraits:UT_quickworker")
local qwMod = qw:getModData()["UT_workSpeedMod"]
assert(type(qwMod) == "number" and qwMod < 0,
    "UT_quickworker: expected UT_workSpeedMod < 0, got " .. tostring(qwMod))
print("PASS: UT_quickworker sets UT_workSpeedMod negative")

-- UT_thickblood sets UT_bleedMult < 1 (slower bleeding)
local tb = fireNewGame("UniversalTraits:UT_thickblood")
local tbMult = tb:getModData()["UT_bleedMult"]
assert(type(tbMult) == "number" and tbMult < 1.0,
    "UT_thickblood: expected UT_bleedMult < 1.0, got " .. tostring(tbMult))
print("PASS: UT_thickblood sets UT_bleedMult < 1.0")

-- UT_heavilybleedingwounds sets UT_bleedMult > 1 (faster bleeding)
local hbw = fireNewGame("UniversalTraits:UT_heavilybleedingwounds")
local hbwMult = hbw:getModData()["UT_bleedMult"]
assert(type(hbwMult) == "number" and hbwMult > 1.0,
    "UT_heavilybleedingwounds: expected UT_bleedMult > 1.0, got " .. tostring(hbwMult))
print("PASS: UT_heavilybleedingwounds sets UT_bleedMult > 1.0")
```

- [ ] **Step 2: Check that UTTestMocks.lua has `addTrait` and `Events.OnNewGame.fire`**

Open `UniversalTraits/test/UTTestMocks.lua`. Verify these methods exist on MockPlayer:

- `MockPlayer:addTrait(id)` — adds a trait ID to the player's traits list
- `Events.OnNewGame.fire(player)` — fires OnNewGame handlers with the player

If `addTrait` is missing, add to UTTestMocks.lua:

```lua
function MockPlayer:addTrait(id)
    if not self._traits then self._traits = {} end
    self._traits[id] = true
end
```

If `Events.OnNewGame` mock is missing the `.fire` method, add:

```lua
Events.OnNewGame.fire = function(self, player)
    for _, fn in ipairs(self._handlers) do fn(player) end
end
```

- [ ] **Step 3: Run tests to confirm new tests fail**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua
```

Expected: failures on the new moddata assertions (or errors if mock adjustments are needed).

- [ ] **Step 4: Run tests to confirm they now pass (after any mock fixes from Step 2)**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua
```

Expected: 28 tests passing (21 existing + 7 new spot checks).

- [ ] **Step 5: Commit**

```bash
git add UniversalTraits/test/run_tests.lua UniversalTraits/test/UTTestMocks.lua
git commit -m "test: add moddata spot-checks for 7 gap traits in UniversalTraits test suite"
```

---

## Task 6: Update AGENTS.md and sync release

**Files:**

- Modify: `AGENTS.md`

- [ ] **Step 1: Update AGENTS.md — mark gaps resolved, document new modules**

In `AGENTS.md`, locate the `## Known Gaps / TODOs` section and replace it:

```markdown
## Known Gaps / TODOs

All 6 previously documented gaps are now resolved. See new UTCore hook modules:

- **UTCore_XPHook.lua** — handles AddXP interception (XP mult, XP disable, onetrickpony multi-skill penalty)
- **UTCore_SpeedHook.lua** — handles OnPlayerMove speed delta (fast, noodlelegs, lurcher, pacer, sorelegs)
- **UTCore_WorkSpeedHook.lua** — handles getDuration override (quickworker, slowworker, slack, flatearther, photographicmemory)
- **UTCore_BleedHook.lua** — handles bleed rate via BodyPart health adjustment (thickblood, weaklybleeding, heavilybleeding)

### Remaining deferred work
- **UT_amputee** — complex limb system, deferred indefinitely
- **poster.png** — cosmetic, not required for function
- **In-game verification** — all traits need visual/functional confirmation in PZ character creation
```

Also update the `## UTCore API Reference` section to add the new modules:

```markdown
### UTCore_XPHook.lua
- Registered via `Events.AddXP` — no public API needed; reads `UT_xpMult_*`, `UT_xpDisable_*`, `UT_multiSkillPenalty` from moddata automatically

### UTCore_SpeedHook.lua
- Registered via `Events.OnPlayerMove` — no public API; reads `UT_speedMod` from moddata automatically

### UTCore_WorkSpeedHook.lua
- `UTCore.applyWorkDuration(timedAction, baseDuration)` → number — applies workSpeedMod and readSpeedMod to a TimedAction duration
- Registered via `Events.OnGameBoot` to patch all TimedAction `getDuration()` calls

### UTCore_BleedHook.lua
- Registered via `Events.OnPlayerUpdate` (throttled, every 30 ticks) — reads `UT_bleedMult` from moddata automatically
```

Also update `## Trait Count` section — add test counts:

Change:

```
**Current passing counts:** 15 (UT_CORE) + 21 (UniversalTraits) = 36 total.
```

To:

```
**Current passing counts:** 27 (UT_CORE) + 28 (UniversalTraits) = 55 total.
```

- [ ] **Step 2: Run both test suites one final time to confirm all passing**

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua
```

Expected: 27 + 28 = 55 tests passing.

- [ ] **Step 3: Commit AGENTS.md update**

```bash
git add AGENTS.md
git commit -m "docs: mark all 6 implementation gaps resolved, document UTCore hook modules"
```

- [ ] **Step 4: Final commit summary**

All implementation is complete. The 4 new hook modules are live in UT_CORE, 55 tests pass, and AGENTS.md is up to date.

---

## Verification (End-to-End)

### Unit tests (automated)

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
# Expected: 27 tests passing

"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua
# Expected: 28 tests passing
```

### In-game smoke test (manual, after deploy)

Deploy from source:

```bash
cp -r UniversalTraits/media/. "C:/Users/Admin/Zomboid/mods/UniversalTraits/42.0/media/"
cp -r UT_CORE/media/. "C:/Users/Admin/Zomboid/mods/UT_CORE/42.0/media/"
```

Verification checklist:

1. `UT_fast` → movement is visibly faster
2. `UT_noodlelegs` → movement is visibly slower
3. `UT_quickworker` → crafting action completes faster
4. `UT_thickblood` → bleeding stops sooner after wound
5. `UT_heavilybleedingwounds` → bleeding progresses faster
6. `UT_flatearther` → reading a book takes longer
7. `UT_noxpshooter` → no Aiming XP gained when firing
8. `UT_onetrickpony` → second skill XP gain is penalized
