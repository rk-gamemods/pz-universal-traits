# UT_deprived

## Trait Summary
- UT trait id: `UniversalTraits:UT_deprived`
- Source mod: MoreTraits (ToadTraits)
- Source trait id: `ToadTraits:deprived`
- Current cost: -6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `MoreTraits/mods/More Traits/42.15/media/registries.lua` — `ToadTraitsRegistries.deprived = CharacterTrait.register("ToadTraits:deprived")` (line 119)
  - `MoreTraits/mods/More Traits/42.15/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` — `TraitFactory.addTrait("deprived", ..., -6, ...)` (line 273); `TraitFactory.setMutualExclusive("deprived", "preparedfood")` through `"preparedcoordination"` (lines 312–320, 8 exclusions total)
  - `MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` — `character_trait_definition ToadTraits:deprived` (lines 184–193): `Cost = -6`, `DisabledInMultiplayer = false`, `MutuallyExclusiveTraits = ToadTraits:preparedammo;ToadTraits:preparedcamp;ToadTraits:preparedcar;ToadTraits:preparedcoordination;ToadTraits:preparedfood;ToadTraits:preparedmedical;ToadTraits:preparedpack;ToadTraits:preparedrepair;ToadTraits:preparedweapon`
  - `MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` — `initToadTraitsItems()` function, lines 235–243: spawn-item handler
  - `MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` — `UI_trait_deprived = "Deprived"` (line 186); `UI_trait_depriveddesc = "You begin the game with absolutely nothing - not even clothes!"` (line 187)
- Source trigger path:
  - The source fires inside `initToadTraitsItems(player)`, which is called once during `OnNewGame`. The function walks all item-granting/stripping trait branches in a flat if/return chain; the `deprived` branch is tested first and, if matched, strips the player then returns — so no other branch can fire for the same player.
- Source behavior (verified from 42.15, confirmed identical in 42.13 and legacy 42):
  1. Guard: if `player:hasTrait(ToadTraitsRegistries.deprived)` is false, skip.
  2. Call `player:clearWornItems()` — removes all equipped clothing.
  3. Call `inv:removeAllItems()` — empties the player's inventory entirely.
  4. Call `player:createKeyRing()` — adds a fresh key ring (minimal item to prevent the game softlocking on an empty key-ring slot).
  5. **Optional**: if `SandboxVars.MoreTraits.ForgivingDeprived` is truthy, call `inv:AddItem("Base.Belt2")` — gives the player a single belt when the sandbox option is enabled.
  6. Return immediately — no further item-granting trait branches execute.
- Source cost: **-6**. Source exclusions: 8 `ToadTraits:prepared*` variants (ammo, camp, car, coordination, food, medical, pack, repair, weapon). Source was multiplayer-capable (`DisabledInMultiplayer = false`) with no special networking needed (spawn-only, runs once, no sync issues).

## Current UT Evidence

### Structure
- Registered in registries.lua: **yes** — `UTTraitsRegistries.UT_deprived = CharacterTrait.register("UniversalTraits:UT_deprived")` at line 125, in the `-- PHASE 1 -- STAT MODIFIERS` section of registries.lua (categorisation note: this trait has runtime Lua, not merely stat modifiers — the section heading is a minor labelling inaccuracy in registries.lua, not a functional issue).
- Defined in UT_character_traits.txt: **yes** — lines 949–957:
  ```
  character_trait_definition UniversalTraits:UT_deprived
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_deprived,
      Cost = -6,
      UIName = UI_UT_deprived,
      UIDescription = UI_UT_deprivedDesc,
  }
  ```
- Translation strings present: **yes** —
  - `UI_UT_deprived = "Deprived"` (UI_EN.txt line 278)
  - `UI_UT_deprivedDesc = "Years of neglect have left your body in poor condition. Multiple physical stats are reduced."` (UI_EN.txt line 279)
- Exclusions/grants correct: **N/A** — no `MutuallyExclusiveTraits` or `GrantedTraits` in UT script block. Source had 8 mutual exclusions against `ToadTraits:prepared*` variants. These do not translate to UT namespace — no UT equivalents of the `prepared*` family exist. Omission is correct.
- Runtime Lua file exists: **yes** — `media/lua/shared/UniversalTraits/traits/UT_deprived.lua` (13 lines total including comments and blank lines)
- Trait icon present: **yes** — `media/ui/Traits/trait_UT_deprived.png` confirmed via glob.

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_deprived.lua` (complete, 13 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait` definition (lines 11–16)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_SpawnEffects.lua` — `UTCore.stripSpawnItems` definition (lines 63–68)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)` — registered at module load time (line 12). Fires exactly once per new game. No periodic or update-loop registration.
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe wrapper: checks `player:getTraits():contains(traitId)`. Returns `false` if `player` or `traits` is nil.
  - `UTCore.stripSpawnItems(player)` — defined in `UTCore_SpawnEffects.lua`:
    1. `player:clearWornItems()` — strips all worn clothing.
    2. `local inv = player:getInventory()` — retrieves inventory with a local nil guard: `if inv then inv:removeAllItems() end`.
    3. `player:createKeyRing()` — restores a fresh key ring.
- Runtime chain (plain language):
  1. `Events.OnNewGame` fires once when a new game is started.
  2. `onNewGame(player)` is called with the new player object.
  3. Guard: `if not UTCore.hasTrait(player, "UniversalTraits:UT_deprived") then return end` — exits immediately if the trait is absent.
  4. Calls `UTCore.stripSpawnItems(player)`:
     - All worn clothing is cleared (`clearWornItems`).
     - All inventory items are removed (`removeAllItems`), with a nil guard on `inv`.
     - A key ring is created (`createKeyRing`).
  5. Function ends. No moddata is written. No further effects occur at any point in the game after spawn.
- Actual behavior (exact values/conditions):
  - **Cadence**: fires exactly once — on `OnNewGame`. There is no ongoing runtime effect. After the new-game event the trait is entirely inert.
  - **Trigger condition**: player has `UniversalTraits:UT_deprived` at the moment `OnNewGame` fires.
  - **Inventory result**: player spawns with zero items and zero worn clothing, plus one key ring (added by `createKeyRing`).
  - **Multiplayer**: `DisabledInMultiplayer = true` in script block. Trait is absent from MP character creation. No MP networking concerns given the trait is entirely spawn-time.
  - **Sandbox/forgiveness option**: MoreTraits source had `SandboxVars.MoreTraits.ForgivingDeprived` which optionally granted a belt. UT does **not** replicate this sandbox option. The UT implementation always produces a fully stripped spawn with no conditional leniency.
  - **Moddata**: none written or read. The trait is stateless after spawn.
  - **No stat modifiers**: despite the UI description claiming "multiple physical stats are reduced", the Lua file contains **no stat modification code whatsoever**. Only spawn stripping occurs. See Description Integrity section.

## Description Integrity
- Display name check: UT uses "Deprived"; source uses "Deprived" (same). Accurate.
- Description check: `"Years of neglect have left your body in poor condition. Multiple physical stats are reduced."`
  - **This description is factually incorrect.** The runtime Lua (`UT_deprived.lua`) contains no stat modification code. The only effect is `UTCore.stripSpawnItems` — stripping clothing and inventory at spawn. No stats (hunger rate, thirst rate, endurance, carry weight, speed, etc.) are altered at any point.
  - The phrase "multiple physical stats are reduced" implies ongoing stat penalties. These do not exist anywhere in the implementation.
  - The actual mechanic — spawning with no items or clothing — is not mentioned in the description at all.
  - The source description ("You begin the game with absolutely nothing - not even clothes!") accurately described the mechanic. The UT description replaced this with a false claim.
- Missing or misleading details:
  1. **Incorrect**: "Multiple physical stats are reduced" — no stat reductions exist anywhere in UT_deprived.lua or in any UTCore hook called by it.
  2. **Missing**: The description does not state that the player spawns with no clothing.
  3. **Missing**: The description does not state that the player spawns with no inventory items.
  4. **Missing**: The description does not communicate that the effect is spawn-only (one-time, not ongoing).
  5. **Misleading**: "Years of neglect have left your body in poor condition" implies a physical/bodily debuff, not an item-stripping mechanic. This framing misleads the player about the nature of the penalty.

## Balance Review
- Upside: none — pure negative trait, returns 6 points.
- Downside: player spawns with no clothing and no items (except a key ring). This is an extreme early-game disadvantage: no weapon, no food, no water, no clothing (meaning temperature vulnerability from day one). Looting basic clothing and a weapon immediately is mandatory.
- Uptime: one-time spawn effect, then entirely inert. The trait has zero ongoing gameplay cost after the first few minutes of a run.
- Peer comparison: most -6 traits in UT have **ongoing** runtime effects. For example, UT traits at -5 or -6 typically involve periodic stat penalties, XP suppression, or combat modifiers that fire repeatedly throughout the game. `UT_deprived` at -6 is a one-time spawn hardship with zero long-run cost — the difficulty spike is entirely front-loaded. Once a player survives the first few minutes of a naked spawn and acquires basic gear, the trait is free points.
- Stack or exclusion notes: no `MutuallyExclusiveTraits` in UT script block. Freely stackable. A player can combine `UT_deprived` with `UT_preparedpack` (if UT has such a trait) or any inventory-granting trait; since `UT_deprived` fires on `OnNewGame` and strips items, load order with other spawn-item traits matters. If any other `OnNewGame` handler grants items **before** `UT_deprived` fires, those items will be stripped. If they fire **after**, those items will survive. The UT trait file gives no ordering guarantee. Source addressed this by using a flat if/return chain inside a single function (explicit ordering); UT uses separate event registrations (implicit, load-order-dependent).
- Multiplayer note: `DisabledInMultiplayer = true`. Source was multiplayer-capable. UT disables in MP; this is consistent with the UT pattern and there are no networking requirements for a one-time spawn strip.
- Cost verdict: **-6 is too generous (player-favorable) relative to ongoing-effect traits at the same cost.** The spawn hardship is severe but time-limited — a skilled player clears the disadvantage in under five minutes of play. Long-running traits at -6 impose costs for the entire game session. Consideration: reduce cost to -4 or -5, or add an ongoing stat penalty to match the description and justify the full -6 point value.

## Regression Proof
- Existing test: `"UniversalTraits:UT_deprived"` appears in the smoke-test KNOWN_TRAITS list at `test/run_tests.lua` line 231, under the `-- Stat Modifiers (20)` comment (another indicator of the categorisation inaccuracy — deprived is not a stat modifier).
- What it proves: (1) `CharacterTrait.register("UniversalTraits:UT_deprived")` has been called and the ID is in the registry; (2) the script definition block exists, the `CharacterTrait` field matches the block ID, and the registered ID resolves.
- What it does not prove: the runtime behaviour of `onNewGame`. The event handler — the `hasTrait` guard, the `stripSpawnItems` call, and the resulting state of the player's inventory and clothing — has zero direct test coverage.
- `UT_deprived` is **not** loaded via `dofile` in the per-trait moddata section of `run_tests.lua` (lines 444–474). No `fireNewGame` test exists for this trait.
- Minimum next test if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_deprived.lua")

  test("UT_deprived: OnNewGame clears inventory and clothing, creates key ring", function()
      local stripped = false
      local invCleared = false
      local keyRingCreated = false
      local p = MockPlayer({ "UniversalTraits:UT_deprived" })
      -- Patch UTCore.stripSpawnItems to verify it is called
      local originalStrip = UTCore.stripSpawnItems
      UTCore.stripSpawnItems = function(player)
          stripped = true
          originalStrip(player)
      end
      Events.OnNewGame:fire(p)
      UTCore.stripSpawnItems = originalStrip
      assert_true(stripped, "UTCore.stripSpawnItems should have been called")
  end)

  test("UT_deprived: OnNewGame does nothing for player without trait", function()
      local stripped = false
      local p = MockPlayer({})  -- no trait
      local originalStrip = UTCore.stripSpawnItems
      UTCore.stripSpawnItems = function(player) stripped = true end
      Events.OnNewGame:fire(p)
      UTCore.stripSpawnItems = originalStrip
      assert_true(not stripped, "stripSpawnItems should NOT be called without trait")
  end)
  ```

## Final Verdict
- Source origin: confirmed — MoreTraits `ToadTraits:deprived` (42.13, 42.15, and legacy 42 all verified identical). Source effect: full spawn strip (clothing + inventory + key ring restore) via `initToadTraitsItems()` on `OnNewGame`. Source also had a sandbox option (`ForgivingDeprived`) that granted a belt as a concession. Source cost: -6. Source had 8 mutual exclusions against `ToadTraits:prepared*` variants. Source was multiplayer-enabled.
- UT implementation: faithfully preserves the core mechanic — `OnNewGame` guard + `UTCore.stripSpawnItems` (which mirrors the source's three-step strip exactly: `clearWornItems`, `removeAllItems`, `createKeyRing`). The UTCore wrapper adds a nil guard on `inv` not present in source. Drops the `ForgivingDeprived` sandbox option — always full strip, no lenience. Drops the 8 mutual exclusions (no UT equivalents exist). Adds `DisabledInMultiplayer = true`. The implementation is clean, minimal, and correct.
- **Description: INCORRECT.** The UI description claims "Multiple physical stats are reduced." No such stat reductions exist in the implementation. The actual effect (naked spawn, no items) is not communicated to the player. This is a significant accuracy failure — the description contradicts the code.
- Balance: **questionable at -6.** One-time spawn penalty with zero ongoing cost. Other -6 traits in UT impose persistent gameplay constraints. Consider either reducing the cost or adding a small ongoing penalty to match the description and the point value.
- Regression proof: **weak.** ID registration and script-block structure are covered by the smoke test. The `onNewGame` handler — the hasTrait guard and the stripSpawnItems call — has zero direct test coverage.
- Action needed:
  1. **Fix description immediately.** Replace `"Years of neglect have left your body in poor condition. Multiple physical stats are reduced."` with accurate text describing the naked spawn. Example: `"You begin with nothing — no clothing, no gear, just a key ring. Whatever you need, you find it yourself."` Do not claim stat reductions that do not exist.
  2. **Review cost.** At -6, this trait is front-loaded with no long-run cost. Either reduce to -4 or -5, or add an ongoing penalty (e.g. small hunger/thirst rate increase via stat modifier, or a minor carry-weight reduction) to justify the full 6 points.
  3. **Add moddata/event tests** per the minimum test block above.
  4. **Fix registries.lua categorisation label** (minor): `UT_deprived` is listed under `-- PHASE 1 -- STAT MODIFIERS` but is a spawn-strip trait with runtime Lua, not a stat modifier. Consider moving it to a more accurate section heading (e.g. `-- PHASE 2 -- SPAWN / INVENTORY`) alongside `UT_preparedpack`.
  5. **Consider replicating ForgivingDeprived** as a UT sandbox option, or confirm intentional omission. Without the option, the trait is harder than the source in all cases.
- Open gaps:
  - No ongoing stat penalty exists to justify the description or the -6 cost. If a stat penalty is desired, it must be added explicitly (likely via `UTCore.applySpawnStats` or a moddata key consumed by a stat-modifier hook).
  - Spawn ordering with other item-granting traits is unguaranteed. If `UT_preparedpack` or any future spawn-grant trait fires `OnNewGame` after `UT_deprived`, its items survive (deprived stripped first). If it fires before, its items are stripped. This ordering ambiguity should be documented or resolved by a single consolidated spawn handler.
  - The `player:createKeyRing()` call is preserved from the source. Confirm that `createKeyRing` is idempotent (does not add a second key ring if one already exists). If it is not idempotent this is a latent bug for any scenario where the player already has a key ring at spawn.
