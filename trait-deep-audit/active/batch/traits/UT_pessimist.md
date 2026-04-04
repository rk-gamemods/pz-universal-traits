# UT_pessimist

## Trait Summary
- UT trait id: `UniversalTraits:UT_pessimist`
- Source mod: FillerTraits
- Source trait id: `Pessimist`
- Current cost: -2
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/shared/NPCs/UpgradeMainCreationMethods.lua` lines 9-10, 51
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/client/UpgradeTraits.lua` lines 289-299, 325
- Source registration:
  - `TraitFactory.addTrait("Pessimist", getText("Pessimist"), -4, getText("Will always be at least a little sad."), false, false)`
- Source trigger path:
  - `Events.OnPlayerUpdate.Add(Pessimist)` — runs every player update tick.
- Source behavior:
  - If the player has trait `Pessimist`, the source checks `bodydamage:getUnhappynessLevel() < 40`.
  - When below 40, it calls `bodydamage:setUnhappynessLevel(40)`.
  - Net effect: the source trait enforces a continuous **minimum unhappiness floor of 40**. It does **not** add stress, panic, or periodic mood drift.
- Source display name: `Pessimist`
- Source description: `Will always be at least a little sad.`
- Source cost: **-4**
- Source exclusions:
  - `TraitFactory.setMutualExclusive("Optimist", "Pessimist")` — source excludes `Optimist` only.

## Current UT Evidence

### Structure
- Registered in `registries.lua`: yes — `UTTraitsRegistries.UT_pessimist = CharacterTrait.register("UniversalTraits:UT_pessimist")` at line 253.
- Defined in `UT_character_traits.txt`: yes — lines 1721-1730:
  ```text
  character_trait_definition UniversalTraits:UT_pessimist
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_pessimist,
      Cost = -2,
      UIName = UI_UT_pessimist,
      UIDescription = UI_UT_pessimistDesc,
      MutuallyExclusiveTraits = UniversalTraits:UT_optimist;UniversalTraits:UT_mstoptimist,
  }
  ```
- Translation strings present: yes
  - `UI_UT_pessimist = "Pessimist"` (`UI_EN.txt` line 536)
  - `UI_UT_pessimistDesc = "You expect the worst and, frankly, you are usually right. Every 10 in-game minutes, stress increases by +0.05."` (`UI_EN.txt` line 537)
  - Mirrored in `UI.json` lines 288-289.
- Exclusions verified:
  - `UT_optimist` excludes `UT_pessimist` — bidirectional confirmed.
  - `UT_mstoptimist` excludes `UT_pessimist` — bidirectional confirmed.
  - `UT_depressive` and `UT_melancholic` do **not** exclude `UT_pessimist`, so all three negative mood traits can stack.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_pessimist.lua`.
- UT_MET coverage: missing for this mood pair. `UT_MET.lua` currently contains no mood group for `UT_optimist` / `UT_pessimist` / `UT_mstoptimist`, so the Lua-side reference table does not mirror this trait's script exclusions.

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_pessimist.lua` (full file, 14 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (`UTCore.hasTrait`)
  - `test/UTTestMocks.lua` (stats mock supports `getStress` / `setStress`)
- Full runtime file:
  ```lua
  -- UT_pessimist.lua
  -- Pessimist: mild steady stress increase from negative outlook

  local TRAIT_ID = "UniversalTraits:UT_pessimist"

  local function handler()
      local player = getPlayer()
      if not player then return end
      if not UTCore.hasTrait(player, TRAIT_ID) then return end
      local stats = player:getStats()
      stats:setStress(math.min(1, stats:getStress() + 0.05))
  end

  Events.EveryTenMinutes.Add(handler)
  ```
- Event registrations:
  - `Events.EveryTenMinutes.Add(handler)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe wrapper around `player:getTraits():contains(traitId)`.
- Runtime chain (plain language):
  1. Every 10 in-game minutes, PZ fires `Events.EveryTenMinutes`.
  2. `handler()` calls `getPlayer()`; if nil, it exits.
  3. `UTCore.hasTrait(player, "UniversalTraits:UT_pessimist")` gates the effect; if absent, it exits.
  4. Reads `player:getStats()`.
  5. Applies `stats:setStress(math.min(1, stats:getStress() + 0.05))`.
- Actual behavior (exact values):
  - Cadence: once per 10 in-game minutes.
  - Stress delta: **+0.05** per tick.
  - Hourly rate: **+0.30 stress per in-game hour**.
  - Full meter time from 0.0 to 1.0: about **3 hours 20 minutes** if no other effect lowers stress.
  - Clamp: capped at 1.0 via `math.min`.
  - No unhappiness manipulation.
  - No panic manipulation.
  - No moddata, cooldowns, helper chains, or conditional branches beyond the trait/player guards.

## Description Integrity
- Display name check: `Pessimist` matches both source and current UT naming.
- Current description: `You expect the worst and, frankly, you are usually right. Every 10 in-game minutes, stress increases by +0.05.`
- Accuracy against current UT code:
  1. **Accurate** — cadence is every 10 in-game minutes.
  2. **Accurate** — stat affected is stress.
  3. **Accurate** — magnitude is +0.05 per tick.
  4. **Acceptable omission** — the 1.0 clamp is not stated, but that is standard and not misleading.
- Source-faithfulness check:
  - The source trait was **not** a periodic stress trait. It enforced a constant **minimum unhappiness floor of 40** on `OnPlayerUpdate`.
  - The UT description is truthful for the current implementation, but this is a **design rewrite**, not a faithful port.

## Balance Review
- Upside: none — negative trait only.
- Downside:
  - +0.05 stress every 10 minutes with 100% uptime.
  - Always active as long as the player has the trait; no location, time, weather, combat, or item condition gates.
- Peer comparison:
  - `UT_melancholic` has the **same Lua behavior** (`+0.05 stress` every 10 minutes) but costs **-3**.
  - `UT_depressive` is stronger (`+0.08 stress` every 10 minutes) and costs **-4**.
  - This makes `UT_pessimist` look mechanically under-rewarded relative to `UT_melancholic`, because both currently do the same thing but `UT_pessimist` only returns 2 points.
- Source comparison:
  - Source cost was **-4** with a stronger, more continuous unhappiness-floor mechanic.
  - UT changed both the mechanic and the price, so a cheaper UT cost is understandable.
- Exclusion review:
  - Source only excluded `Optimist`; UT also excludes `UT_mstoptimist`, which is sensible.
  - However, `UT_pessimist` can stack with `UT_depressive` and `UT_melancholic`, even though all three are negative mood traits and two of them occupy overlapping stress-per-tick space.
  - `UT_optimist` excludes all three negative mood traits, but `UT_pessimist` itself does not exclude the other two. That asymmetry is a correction gap.
- Cost verdict: **questionable**.
  - In isolation, -2 is plausible for a mild always-on stress tax.
  - Relative to current UT peers, it is inconsistent because `UT_melancholic` is mechanically identical but priced at -3.

## Regression Proof
- Existing tests found:
  - `UniversalTraits:UT_pessimist` appears in the `expected_ids` table at `test/run_tests.lua` line 285.
  - That feeds the broader tests:
    1. `all 198 trait IDs registered with CharacterTrait`
    2. `script trait definitions resolve cleanly and preserve UT_MET coverage`
- What those tests prove:
  - Registration exists.
  - The script block exists.
  - Script-side mutual exclusions reference registered IDs.
- What is **not** proven:
  1. No runtime test proves `EveryTenMinutes` raises stress by exactly +0.05.
  2. No runtime test proves the `math.min(1, ...)` clamp.
  3. No runtime test proves the no-trait guard.
  4. No runtime test proves the nil-player guard.
  5. No explicit cost assertion locks `UT_pessimist` at -2.
- Minimum next tests if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_pessimist.lua")

  test("UT_pessimist adds 0.05 stress every ten minutes", function()
      local player = MockPlayer({ "UniversalTraits:UT_pessimist" }, { stress = 0.0 })
      withActivePlayer(player, function()
          Events.EveryTe
