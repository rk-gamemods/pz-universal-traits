# UT_badteeth

## Trait Summary
- UT trait id: `UniversalTraits:UT_badteeth`
- Source mod: MoreTraits (ToadTraits)
- Source trait id: `ToadTraits:badteeth`
- Current cost: -3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `MoreTraits/mods/More Traits/42.13/media/registries.lua` — `ToadTraitsRegistries.badteeth = CharacterTrait.register("ToadTraits:badteeth")` (line 108)
  - `MoreTraits/mods/More Traits/42.13/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` — `TraitFactory.addTrait("badteeth", ..., -3, ...)` (line 255) and `TraitFactory.setMutualExclusive("badteeth", "albino")` (line 393)
  - `MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` — function `badteethtrait(player, playerdata)`, lines 1609–1644; call site at line 4682 inside `OnPlayerUpdate` handler
  - `MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` — same function, lines 1827–1867 (verified identical logic in later version)
- Source trigger path:
  - `badteethtrait(player, playerdata)` is called from the monolithic `OnPlayerUpdate(player, playerdata)` function which is wired to `Events.OnPlayerUpdate`. Fires every game tick.
  - In multiplayer (`isClient()`) the function throttles itself to at most once per 1000 ms wall-clock time using `getTimestampMs()` and `playerdata.lastBadTeethUpdate`.
- Source behavior (verified from 42.13 source, confirmed unchanged in 42.15):
  1. Guard: if player does not have `ToadTraitsRegistries.badteeth`, return immediately.
  2. Read `bodyDamage:getHealthFromFoodTimer()` into `healthTimer`.
  3. **Multiplayer throttle**: if `isClient()`, check `getTimestampMs()`. If less than 1000 ms since `playerdata.lastBadTeethUpdate`, update `fPreviousHealthFromFoodTimer = healthTimer` and return. Otherwise update timestamp and continue.
  4. Initialize `playerdata.fBadTeethLastSentPain = playerdata.fBadTeethLastSentPain or 0`.
  5. **Condition**: if `healthTimer > 1000` **and** `healthTimer > playerdata.fPreviousHealthFromFoodTimer` (timer is actively rising above threshold):
     - `painIncrease = (healthTimer - fPreviousHealthFromFoodTimer) * 0.01`
     - `newPain = math.min(head:getAdditionalPain() + painIncrease, 100)` (head body part, capped at 100)
     - **Singleplayer**: call `head:setAdditionalPain(newPain)` directly.
     - **Multiplayer (client)**: if `math.abs(newPain - fBadTeethLastSentPain) >= 1`, send `sendClientCommand(player, 'ToadTraits', 'BodyPartMechanics', { bodyPart = headPart, partPain = newPain })` and update `fBadTeethLastSentPain`.
  6. Update `playerdata.fPreviousHealthFromFoodTimer = healthTimer`.
- Source cost: **-3**. Source exclusion: `MutuallyExclusiveTraits` with `ToadTraits:albino` (set via `TraitFactory.setMutualExclusive`). Source was multiplayer-capable (no `DisabledInMultiplayer` flag in source; UT adds one).

## Current UT Evidence

### Structure
- Registered in registries.lua: **yes** — `UTTraitsRegistries.UT_badteeth = CharacterTrait.register("UniversalTraits:UT_badteeth")` at line 124
- Defined in UT_character_traits.txt: **yes** — lines 939–947:
  ```
  character_trait_definition UniversalTraits:UT_badteeth
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_badteeth,
      Cost = -3,
      UIName = UI_UT_badteeth,
      UIDescription = UI_UT_badteethDesc,
  }
  ```
- Translation strings present: **yes** —
  - `UI_UT_badteeth = "Bad Teeth"` (UI_EN.txt line 275)
  - `UI_UT_badteethDesc = "Dental problems make eating painful. Eating causes increasing head pain (proportional to food healing). Food effectiveness is not reduced — it just hurts."` (UI_EN.txt line 276)
- Exclusions/grants correct: **N/A** — no `MutuallyExclusiveTraits` or `GrantedTraits` in UT script block. Source had mutual exclusion with `ToadTraits:albino`; that exclusion does not translate to UT namespace, so its omission is correct. UT has no equivalent cross-trait exclusion for `UT_badteeth` and `UT_albino`.
- Runtime Lua file exists: **yes** — `media/lua/shared/UniversalTraits/traits/UT_badteeth.lua` (24 lines)

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_badteeth.lua` (complete, 24 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua` — `UTCore.registerPeriodicHandler` implementation
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait`, `UTCore.getModData`, `UTCore.setModData` definitions
  - `test/UTTestMocks.lua` lines 199–227 — test stubs for all UTCore helpers used
- Event registrations:
  - `UTCore.registerPeriodicHandler(TRAIT_ID, "OnPlayerUpdate", handler)` — registers via `UTCore_Events.lua`. The framework wraps the handler as `function() handlerFn(getPlayer()) end` and calls `Events.OnPlayerUpdate.Add(wrappedFn)`. Idempotent (keyed by `traitId .. "::" .. intervalEvent`).
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe: checks `player:getTraits():contains(traitId)`. Returns false if player or traits is nil.
  - `UTCore.getModData(player, "badteethTimer", 0)` — reads `player:getModData()["badteethTimer"]`; returns default `0` if nil.
  - `UTCore.setModData(player, "badteethTimer", timer)` — writes `player:getModData()["badteethTimer"] = timer`.
- Runtime chain (plain language):
  1. Every game tick, PZ fires `Events.OnPlayerUpdate`. The `UTCore_Events` wrapper calls `handler(getPlayer())`.
  2. Guard: if player does not have `UniversalTraits:UT_badteeth`, return immediately.
  3. Call `player:getBodyDamage()` → `bd`. If `bd` is nil, return immediately.
  4. Read `bd:getHealthFromFoodTimer()` → `timer` (a float that rises while food is actively healing the player).
  5. Read previous timer value from moddata: `prev = UTCore.getModData(player, "badteethTimer", 0)`.
  6. Unconditionally write current timer back: `UTCore.setModData(player, "badteethTimer", timer)`.
  7. **Condition**: if `timer > 1000` **and** `timer > prev` (i.e., the food-heal timer is both above the 1000 threshold and still rising):
     - Get head body part: `bd:getBodyPart(BodyPartType.Head)` → `head`. If `head` is nil, skip.
     - Read current head pain: `head:getAdditionalPain()` → `current`.
     - Compute new pain: `math.min(current + (timer - prev) * 0.01, 100)`.
     - Set: `head:setAdditionalPain(newPain)`.
- Actual behavior (exact values):
  - **Cadence**: every game tick (`OnPlayerUpdate`), no throttle of any kind in the UT implementation.
  - **Trigger condition**: food-heal timer must be actively rising above 1000. The timer rises while food is being metabolized into HP; it stops rising once the food pulse is complete. The threshold of 1000 means only a meaningful food-healing event triggers pain (small snacks below threshold do not fire the condition).
  - **Pain increment per tick**: `(timer - prev) * 0.01`. Because `timer` and `prev` are consecutive tick readings, `timer - prev` is the per-tick increase in the food-heal timer. Pain grows proportionally to how fast the food is healing — larger meals cause faster pain accumulation.
  - **Pain cap**: `math.min(..., 100)`. Head `additionalPain` cannot exceed 100.
  - **Pain target**: head body part only (`BodyPartType.Head`).
  - **Pain decay**: the trait does not clear or reduce head pain. Natural pain recovery applies as normal per the base game.
  - **Multiplayer**: `DisabledInMultiplayer = true` in script block. Trait is absent from MP character creation. The handler runs unconditionally (no `isClient()` branch). The `DisabledInMultiplayer` flag is the sole MP guard.
  - **Moddata key**: `"badteethTimer"` — stores last observed food-heal timer value. Persists across ticks. Default of `0` on first call means the very first tick where timer > 1000 will correctly fire (prev=0, timer>1000>0).

## Description Integrity
- Display name check: UT uses "Bad Teeth"; source uses "Bad Teeth" (same). Accurate.
- Description check: "Dental problems make eating painful. Eating causes increasing head pain (proportional to food healing). Food effectiveness is not reduced — it just hurts."
  - The description correctly identifies the mechanic: head pain proportional to food healing. This matches the implementation.
  - "Food effectiveness is not reduced" is accurate — no calorie, hunger, or thirst penalty exists.
  - "Increasing" head pain is accurate — pain accumulates tick by tick while the heal timer rises.
- Missing or misleading details:
  1. **Missing**: No mention that the effect only triggers while food is actively healing HP (the `healthFromFoodTimer > 1000` threshold). Eating a small snack that does not surpass the timer threshold produces no pain at all — this nuance is invisible to the player.
  2. **Missing**: The description does not clarify that pain only accumulates *while food healing is actively occurring*, not persistently after eating. Once the food pulse ends the timer stops rising and no further pain is added.
  3. **Minor**: "Increasing" is accurate but could be clearer — pain increases during eating events and then stops. It does not continuously increase after eating.
  4. The description is accurate enough for player use; the omissions are details of internal mechanics rather than misleading claims about the effect.

## Balance Review
- Upside: none — pure negative trait, returns 3 points.
- Downside: head `additionalPain` accumulates each tick the food-heal timer is rising above 1000. The per-tick pain delta is `(timerDelta) * 0.01`. A typical large meal may drive the food-heal timer through a range of several thousand units over many ticks; at 0.01× scaling this could produce tens of points of head pain per meal. Pain decays naturally over time (base game pain recovery) so the effect is episodic: pain spikes during and shortly after a significant meal, then subsides.
- Uptime: not constant. Pain only accumulates during active food-healing pulses. Between meals the trait is entirely inert. Frequency depends on how often the player eats and how nutritious the food is. Players who eat frequently (e.g., heavy exercisers) feel this more often.
- Peer comparison: `UT_deprived` (food/water stat penalties, -6 cost), `UT_sore` (persistent baseline pain floor of 20, -3 cost via `UTCore.applyStatFloor`). `UT_badteeth` at -3 is structurally comparable to `UT_sore` in cost. Both apply head/body pain but via different mechanics: `UT_sore` applies a *floor* (minimum pain always present), while `UT_badteeth` applies *episodic spikes* only during eating. Sore may be more consistently impactful for combat play; badteeth is more impactful for players who rely on food as a primary healing source.
- Stack or exclusion notes: no MutuallyExclusiveTraits in UT script block. Stacks freely with `UT_sore` — a player with both would have a persistent pain floor of 20 plus episodic eating-related head pain spikes on top. The combined effect is meaningful but not unplayable. Source excluded badteeth from `albino`; UT does not replicate this.
- Multiplayer note: `DisabledInMultiplayer = true`. Source was multiplayer-capable with a networking layer (`sendClientCommand`). UT dropped the networking complexity by disabling the trait in MP entirely. This is a deliberate simplification; acceptable given UT's pattern.
- Cost verdict: **-3 is defensible**. The effect is episodic and affects only head pain. Head pain impacts combat accuracy/efficiency but is not life-threatening and decays over time. Players who eat infrequently or only eat small amounts effectively feel minimal downside. A more aggressive scavenger eating large meals regularly gets more pain. -3 is at the low end of the pain-inducing trait range and feels proportionate given the conditional nature of the trigger.

## Regression Proof
- Existing test: `"UniversalTraits:UT_badteeth"` appears in the Phase 1 Stat Modifiers smoke-test ID list at `test/run_tests.lua` line 231. This list is exercised by the "all trait IDs registered with CharacterTrait" and "script trait definitions resolve cleanly" tests.
- What it proves: (1) `CharacterTrait.register("UniversalTraits:UT_badteeth")` has been called and the ID is in the registry; (2) the script definition block exists, the `CharacterTrait` field matches the block ID, and the registered ID resolves.
- Missing proof: No per-trait moddata spot-check test for `UT_badteeth`. The runtime `handler()` function — the timer threshold condition, the pain increment formula, the head body-part nil guard, and the moddata persistence — is entirely untested.
- Minimum next test if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_badteeth.lua")

  test("UT_badteeth: rising food-heal timer above 1000 adds head pain proportionally", function()
      local p = MockPlayer({ "UniversalTraits:UT_badteeth" })
      -- Seed previous timer value to simulate a meal in progress
      UTCore.setModData(p, "badteethTimer", 1050)
      -- Simulate next tick: timer has risen by 100 units
      p:getBodyDamage():setHealthFromFoodTimer(1150)
      withActivePlayer(p, function() Events.OnPlayerUpdate:fire(p) end)
      -- Expected pain: 0 + (1150 - 1050) * 0.01 = 1.0
      local head = p:getBodyDamage():getBodyPart(BodyPartType.Head)
      assert_eq(head:getAdditionalPain(), 1.0, "head pain should be 1.0 after 100-unit timer rise")
  end)

  test("UT_badteeth: timer below 1000 does not add head pain", function()
      local p = MockPlayer({ "UniversalTraits:UT_badteeth" })
      UTCore.setModData(p, "badteethTimer", 900)
      p:getBodyDamage():setHealthFromFoodTimer(950)
      withActivePlayer(p, function() Events.OnPlayerUpdate:fire(p) end)
      local head = p:getBodyDamage():getBodyPart(BodyPartType.Head)
      assert_eq(head:getAdditionalPain(), 0, "head pain should not change when timer < 1000")
  end)

  test("UT_badteeth: timer not rising (timer <= prev) does not add head pain", function()
      local p = MockPlayer({ "UniversalTraits:UT_badteeth" })
      UTCore.setModData(p, "badteethTimer", 1200)
      p:getBodyDamage():setHealthFromFoodTimer(1200)  -- same value, not rising
      withActivePlayer(p, function() Events.OnPlayerUpdate:fire(p) end)
      local head = p:getBodyDamage():getBodyPart(BodyPartType.Head)
      assert_eq(head:getAdditionalPain(), 0, "head pain should not change when timer is flat")
  end)

  test("UT_badteeth: head pain is capped at 100", function()
      local p = MockPlayer({ "UniversalTraits:UT_badteeth" })
      p:getBodyDamage():getBodyPart(BodyPartType.Head):setAdditionalPain(99.5)
      UTCore.setModData(p, "badteethTimer", 1000)
      p:getBodyDamage():setHealthFromFoodTimer(2000)  -- delta = 1000, pain increase = 10
      withActivePlayer(p, function() Events.OnPlayerUpdate:fire(p) end)
      local head = p:getBodyDamage():getBodyPart(BodyPartType.Head)
      assert_eq(head:getAdditionalPain(), 100, "head pain should be capped at 100")
  end)
  ```

## Final Verdict
- Source origin: confirmed — MoreTraits `ToadTraits:badteeth` (42.13 and 42.15 verified). Source used `playerdata` fields (`fPreviousHealthFromFoodTimer`, `fBadTeethLastSentPain`, `lastBadTeethUpdate`) stored on a per-player data object passed into the function. Source was multiplayer-capable with a 1000 ms timestamp throttle and client command networking for body-part pain synchronization. Source cost: -3. Source mutual exclusion: `badteeth` x `albino`.
- UT implementation: faithfully preserves the core mechanic — food-heal timer delta above 1000 drives head pain at 0.01× scaling, capped at 100. Replaces `playerdata` fields with `UTCore.getModData/setModData` (keyed `"badteethTimer"`). Drops the multiplayer throttle and networking entirely, offset by `DisabledInMultiplayer = true`. Removes the `fPreviousHealthFromFoodTimer`/`lastBadTeethUpdate` complexity — the moddata key doubles as the previous-timer store, which is a clean simplification. Uses `UTCore.registerPeriodicHandler` (consistent with UT pattern). Adds a nil guard on `bd` (not in source). Adds nil guard on `head` (not in source). The simplification is accurate and faithful to source intent.
- Description: **accurate**. "Head pain proportional to food healing" is a correct plain-language description of the mechanic. The threshold nuance (timer > 1000) and the episodic nature (only while healing is actively occurring) are not communicated, but the core effect is not misrepresented.
- Balance: **acceptable** at -3. Episodic, conditional, affects only head pain, and pain decays naturally. Peer `UT_sore` at the same cost applies a persistent pain floor which is arguably more consistently impactful. The cost is reasonable.
- Regression proof: **weak**. ID registration and script-block structure are covered. The runtime handler — the threshold condition, pain formula, cap, nil guards, and moddata round-trip — has zero direct test coverage.
- Action needed:
  1. **Add moddata spot-check tests** per the minimum test block above, covering: normal pain accumulation, timer-below-threshold no-op, flat-timer no-op, and the 100-cap behavior.
  2. **Optional description enhancement**: add a sentence clarifying that pain only occurs while food is actively healing HP, not merely after eating any food. This is a usability improvement, not a correction.
- Open gaps:
  - Source had `MutuallyExclusiveTraits` with `UT_albino` (the source `ToadTraits:badteeth` x `ToadTraits:albino` exclusion). UT does not replicate this. Whether `UT_badteeth` and `UT_albino` should be mutually exclusive in UT is an open design question — stacking them would result in head pain from both eating and sun exposure simultaneously, which may be excessive. Confirm intentional omission or add the exclusion.
  - No test covers the `bd == nil` or `head == nil` guard branches. These are defensive guards that cannot realistically fire for a live player but are untested.
