# UT_albino

## Trait Summary
- UT trait id: `UniversalTraits:UT_albino`
- Source mod: MoreTraits (ToadTraits)
- Source trait id: `ToadTraits:albino`
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `MoreTraits/mods/More Traits/42.13/media/scripts/ToadTraits.txt` — script definition
  - `MoreTraits/mods/More Traits/42.13/media/registries.lua` — `ToadTraitsRegistries.albino = CharacterTrait.register("ToadTraits:albino")`
  - `MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` — functions `albino()` and `AlbinoTimer()`, lines 2302–2352 and 2355–2382
  - `MoreTraits/mods/More Traits/42/media/lua/shared/Translate/EN/UI_EN.txt` — source display name and description
- Source trigger path:
  - `albino(player, playerdata)` — called inside `OnPlayerUpdate(player)`, which is wired to `Events.OnPlayerUpdate`. Runs every game tick (throttled in multiplayer by a 1000ms timestamp guard).
  - `AlbinoTimer(player, playerdata)` — called inside `EveryOneMinute()`, which is wired to `Events.EveryOneMinute`. Runs once per in-game minute.
- Source behavior:
  - **AlbinoTimer** (EveryOneMinute): accumulates `AlbinoTimeSpentOutside` (0–40 cap) when the player is outside between in-game hours 8–17. Increment is +1 per minute bare, +0.5 per minute holding an umbrella. Decrements by 1/minute when outside at night, by 2/minute when indoors. Tracks time-weighted UV exposure as a pain budget.
  - **albino** (OnPlayerUpdate, ~every tick with multiplayer throttle): reads `AlbinoTimeSpentOutside` as `modpain`. Computes `finalPain`:
    - Outside, daytime (tod 8–17): `finalPain = modpain` (bare) or `modpain / 1.5` (umbrella). Triggers halo text announce on first tick pain crosses PAIN < 25.
    - Outside, nighttime: `finalPain = modpain / 2` (recovery halved).
    - Indoors: `finalPain = modpain / 4` (fast recovery).
  - Sets head body-part `additionalPain` to `finalPain` directly (singleplayer). In multiplayer sends a client command to server for body-part pain. No stress or fatigue effect.
  - Source cost: **-5**. Source exclusion: `MutuallyExclusiveTraits = ToadTraits:badteeth`. Source display name: "Sun Sensitivity". Source multiplayer flag: `DisabledInMultiplayer = false`.

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_albino = CharacterTrait.register("UniversalTraits:UT_albino")` at line 257
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_albino { IsProfessionTrait = false, DisabledInMultiplayer = true, CharacterTrait = UniversalTraits:UT_albino, Cost = -4, UIName = UI_UT_albino, UIDescription = UI_UT_albinoDesc, }`
- Translation strings present: yes — `UI_UT_albino = "Albino"` and `UI_UT_albinoDesc = "You lack melanin and sunlight has always been your enemy. Prolonged outdoor exposure causes real physical harm."` (UI_EN.txt lines 548–549)
- Exclusions/grants correct: N/A — no `MutuallyExclusiveTraits` or `GrantedTraits` defined in UT script block; source had `MutuallyExclusiveTraits = ToadTraits:badteeth` which does not translate to UT namespace, so omission is correct
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_albino.lua`

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_albino.lua` (25 lines, complete)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait` definition
  - `test/UTTestMocks.lua` lines 199–204 — test stub for `UTCore.hasTrait`
- Event registrations:
  - `Events.EveryOneMinute.Add(handler)` — raw direct registration, NOT via `UTCore.registerPeriodicHandler`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe wrapper: checks `player:getTraits():contains(traitId)`; returns false if player or traits is nil
- Runtime chain (plain language):
  1. Every in-game minute PZ fires `Events.EveryOneMinute`.
  2. `handler()` runs (no arguments — calls `getPlayer()` internally, singleplayer only).
  3. Guard: if no player, exit. If player does not have `UniversalTraits:UT_albino`, exit.
  4. If `player:isOutside()` is true: read `getGameTime():getTimeOfDay()`. If value is between 0.25 and 0.75 (inclusive):
     - Call `player:getStats():setStress(math.min(1, currentStress + 0.03))`.
     - Call `player:getStats():setFatigue(math.min(1, currentFatigue + 0.02))`.
     - Set `player:getModData()["UT_albinoDamage"] = true`.
     - Otherwise (outside but outside the daytime band): set `UT_albinoDamage = false`.
  5. If `player:isOutside()` is false: set `UT_albinoDamage = false`.
- Actual behavior (exact values):
  - Cadence: once per in-game minute.
  - Daytime window: `timeOfDay >= 0.25 and timeOfDay <= 0.75` — this is a 0.0–1.0 fractional day scale. 0.25 = 06:00, 0.75 = 18:00 (a 12-hour window, roughly dawn to dusk). **This is a different scale from the source** which used integer hours `tod > 8 and tod < 17` (08:00–17:00, a 9-hour window).
  - Effect when active: +0.03 stress per minute, +0.02 fatigue per minute. Capped at 1.0 by `math.min`.
  - Effect when inactive (indoors or night): no reduction applied — stress and fatigue recover at their natural rates.
  - Moddata flag `UT_albinoDamage` is set true when actively taking effect, false otherwise. This flag is not read by any other UT file (informational/debug only based on evidence reviewed).
  - No pain mechanic. No umbrella mitigation. No accumulator state. No multiplayer body-part command.
  - `DisabledInMultiplayer = true` in script block — trait is entirely absent from multiplayer character creation, so the singleplayer-only `getPlayer()` pattern is consistent.

## Description Integrity
- Display name check: UT uses "Albino"; source uses "Sun Sensitivity". The UT name is accurate to the biological condition and arguably better identifies the trait, but it differs from the source naming convention. Acceptable.
- Description check: "You lack melanin and sunlight has always been your enemy. Prolonged outdoor exposure causes real physical harm." — describes head pain accumulation ("real physical harm"), which matches the source mechanic. However the UT implementation applies **stress and fatigue**, not pain. The description is misleading for UT's actual effect. "Real physical harm" strongly implies body damage or pain; the actual UT effect is stress (+0.03/min) and fatigue (+0.02/min).
- Missing or misleading details:
  1. **Misleading**: "Prolonged outdoor exposure causes real physical harm" — UT applies stress and fatigue, not pain or body damage. No accumulation mechanic exists in UT; harm begins immediately on the first daytime-outdoor minute.
  2. **Missing**: No mention of the time-of-day window (daytime only, roughly 06:00–18:00).
  3. **Missing**: No mention of the stat magnitudes (+0.03 stress/min, +0.02 fatigue/min).
  4. **Missing**: Source umbrella mitigation is absent from UT; description does not reference it, which is correct, but the absence of any mitigation option is a design gap not surfaced to the player.

## Balance Review
- Upside: none — pure negative trait, returns 4 points.
- Downside: +0.03 stress/min and +0.02 fatigue/min when outside between 06:00–18:00. At those rates: stress reaches 1.0 from 0 in ~33 minutes continuous outdoor exposure; fatigue reaches 1.0 from 0 in ~50 minutes. In practice both stats start elevated and natural recovery partially offsets, but daytime outdoor play is meaningfully degraded.
- Uptime: active only when outside during daytime. Indoor players (base builders, crafters) feel almost nothing. Outdoor scavengers or farmers feel it heavily during the entire daylight half of the game clock. Uptime scales with playstyle, not a fixed fraction of game time.
- Peer comparison: UT_fearofthedark (+stress/fatigue at night, also EveryOneMinute), UT_coldsensitive and UT_heatsensitive (temperature-gated stat penalties). Albino is the daytime-outdoor counterpart. At -4 cost it is cheaper than UT_fibromyalgia (-8) and UT_weathersensitive; comparable to UT_fearofthedark and UT_heatsensitive. The 12-hour daytime window is wide — day runs roughly 06:00–18:00 in default PZ settings — making this trait active for the majority of daytime play if the player goes outside at all.
- Stack or exclusion notes: no MutuallyExclusiveTraits in UT script block. Stacks freely with UT_heatsensitive, UT_fearofthedark, and similar stat-draining traits. Combined with UT_fearofthedark the player is penalized both day and night, leaving no stress-neutral time window outdoors, which may be a harsh but intentional design space.
- Cost verdict: -4 is defensible. The trait is ignorable for indoor players and punishing for outdoor-focused characters. The lack of any mitigation mechanic (no umbrella equivalent) compared to the source's umbrella system slightly overweights the penalty vs. the point return. -4 is at the low end; -5 (source cost) would be reasonable if no mitigation exists. **Acceptable at -4; revisit if a mitigation item is ever added.**

## Regression Proof
- Existing test: `UT_albino` appears in the Phase 3b smoke-test ID list at `test/run_tests.lua` line 287. This list is checked by the "all 198 trait IDs registered with CharacterTrait" test and the "script trait definitions resolve cleanly" test.
- What it proves: (1) `CharacterTrait.register("UniversalTraits:UT_albino")` has been called and the trait ID is present in the registry; (2) the script definition block exists, the `CharacterTrait` field matches the block ID, and the registered ID resolves. Neither test exercises the Lua runtime handler.
- Missing proof: No moddata spot-check test for `UT_albino`. The runtime `handler()` function — its daytime condition, stress/fatigue increments, `UT_albinoDamage` flag transitions, and guard behavior — is entirely untested.
- Minimum next test if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_albino.lua")

  test("UT_albino: outside in daytime raises stress, fatigue, and sets UT_albinoDamage=true", function()
      local p = MockPlayer({ "UniversalTraits:UT_albino" })
      p:setOutside(true)
      -- timeOfDay = 0.5 (noon, inside 0.25–0.75 window)
      getGameTime():setTimeOfDay(0.5)
      withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
      assert_true(p:getStats():getStress() > 0, "stress should increase")
      assert_true(p:getStats():getFatigue() > 0, "fatigue should increase")
      assert_eq(p:getModData()["UT_albinoDamage"], true, "UT_albinoDamage should be true")
  end)

  test("UT_albino: outside at night clears UT_albinoDamage, no stat change", function()
      local p = MockPlayer({ "UniversalTraits:UT_albino" })
      p:setOutside(true)
      -- timeOfDay = 0.1 (early morning, before 0.25)
      getGameTime():setTimeOfDay(0.1)
      withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
      assert_eq(p:getStats():getStress(), 0, "stress should not change at night")
      assert_eq(p:getModData()["UT_albinoDamage"], false, "UT_albinoDamage should be false at night")
  end)

  test("UT_albino: indoors clears UT_albinoDamage regardless of time", function()
      local p = MockPlayer({ "UniversalTraits:UT_albino" })
      p:setOutside(false)
      getGameTime():setTimeOfDay(0.5)
      withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
      assert_eq(p:getModData()["UT_albinoDamage"], false, "UT_albinoDamage should be false indoors")
  end)
  ```

## Final Verdict
- Source origin: confirmed — MoreTraits `ToadTraits:albino`. Source used a two-function model: `AlbinoTimer` (EveryOneMinute) accumulates a UV exposure budget (0–40) and `albino` (OnPlayerUpdate) translates that budget into head `additionalPain` with umbrella mitigation. Source cost was -5. Source was multiplayer-capable with client command networking.
- UT implementation: simplified single-function approach via `Events.EveryOneMinute`. Trades the pain/accumulator model for direct stress (+0.03/min) and fatigue (+0.02/min) when outside in daytime (0.25–0.75 fractional day). Removes umbrella mitigation and the pain accumulator entirely. `DisabledInMultiplayer = true` sidesteps the networking complexity. Uses raw `Events.EveryOneMinute.Add` instead of `UTCore.registerPeriodicHandler` — inconsistent with the majority of UT periodic traits but not functionally wrong for singleplayer.
- Description: **misleading**. "Real physical harm" implies pain or body damage; the actual effect is stress and fatigue. No time-of-day window is communicated. Needs a rewrite.
- Balance: **acceptable** at -4. The 12-hour daytime window is wide and no mitigation exists, so -5 (source cost) would also be defensible. Current cost is not wrong.
- Regression proof: **weak**. ID registration and script-block structure are covered. The runtime handler has zero coverage — stress/fatigue increments, the 0.25–0.75 time window, and the `UT_albinoDamage` flag are all untested.
- Action needed:
  1. **Fix description** — rewrite to accurately state stress and fatigue effects, not "physical harm". Example: "You lack melanin and sunlight is your enemy. Spending time outdoors during daylight hours raises your stress and fatigue."
  2. **Migrate event registration** to `UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)` for consistency with the UT pattern (handler signature must then accept `player` as argument and drop the internal `getPlayer()` call).
  3. **Add moddata spot-check tests** per the minimum test block above.
- Open gaps:
  - `UT_albinoDamage` moddata flag is written but never read by any other UT file in the indexed repo. Its purpose is unclear — likely a leftover debug/status flag. Confirm intended use or remove it.
  - No umbrella or hat mitigation exists in UT. Whether this is intentional simplification or a missing feature should be decided explicitly.
  - The daytime window (0.25–0.75 = 06:00–18:00) is wider than the source (08:00–17:00). This may be intentional but is undocumented.
