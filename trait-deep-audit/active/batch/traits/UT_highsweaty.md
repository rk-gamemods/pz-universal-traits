# UT_highsweaty

## Trait Summary
- UT trait id: `UniversalTraits:UT_highsweaty`
- Source mod: MoreSimpleTraits
- Source trait id: `HighSweaty`
- Current cost: -3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` line 129 — `TraitFactory.addTrait("HighSweaty", getText("UI_trait_highsweaty"), -3, getText("UI_trait_highsweatydesc"), false)` — original cost **-3**, non-profession trait
  - `MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua` — identical registration in the Vanilla variant
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` lines 213–214 — `TraitFactory.setMutualExclusive("LessSweaty", "HighSweaty")` — mutual exclusion with `LessSweaty`
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` lines 73–99 — `MSTincreaseThirst(player, chance, thirst)` helper: fires only when `chance == 0`; adds `thirst` to `player:getStats():getThirst()`, capped at 0.99
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` lines 93–100 — `MSTincreaseWetness(player, chance, wetness)` helper: fires only when `chance == 0`; adds `wetness` to `player:getBodyDamage():getWetness()`, capped at 99
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` lines 976–998 — `highsweatytrait()` handler wired to `Events.EveryOneMinute`
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` lines 1000–1035 — `highsweatyattack(player, weapon)` handler wired to `Events.OnWeaponSwingHitPoint`
  - `MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/client/MSTVanillaFitnessAction.lua` lines 16–52 — exercise-specific sweat hooks (squat/pushup/situp/barbellcurl); each checks `player:HasTrait("HighSweaty")` and calls `MSTincreaseThirst(player, ZombRand(20), 0.01)` and `MSTincreaseWetness(player, ZombRand(2), ZombRand(10)–ZombRand(12))`
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` lines 1111, 1125 — event registrations for `highsweatyattack` and `highsweatytrait`

- Source trigger paths and full behavior:

  **`highsweatytrait()` — `Events.EveryOneMinute`:**
  - Resolves `player = getPlayer()` and reads `getClimateManager():getRainIntensity()` (stored as `currRainIntensity` but **never used** in the body — dead assignment).
  - Guards on `player:HasTrait("HighSweaty")`.
  - **Idle branch** (`IsRunning() == false and isSprinting() == false`): calls `MSTincreaseWetness(player, ZombRand(7), ZombRand(5))`. Because `MSTincreaseWetness` fires only when `chance == 0`, and `ZombRand(7)` produces 0–6, this fires with **probability 1/7** (~14.3%). When it fires, wetness increases by `ZombRand(5)` (0–4 raw wetness units on a 0–99 scale).
  - **Running branch** (`IsRunning() == true`): calls `MSTincreaseThirst(player, ZombRand(19), 0.01)` (1/19 chance, +0.01 thirst) and `MSTincreaseWetness(player, ZombRand(2), ZombRand(4))` (1/2 chance, +0–3 wetness).
  - **Sprinting branch** (`isSprinting() == true`): calls `MSTincreaseThirst(player, ZombRand(9), 0.01)` (1/9 chance, +0.01 thirst) and `MSTincreaseWetness(player, ZombRand(1), ZombRand(5))` (1/1 = 100% chance, +0–4 wetness — `ZombRand(1)` always returns 0).
  - Note: running and sprinting are mutually exclusive branches; idle is checked first with `==false` on both.

  **`highsweatyattack(player, weapon)` — `Events.OnWeaponSwingHitPoint`:**
  - Re-resolves `player = getPlayer()` (ignores the `player` argument from the event signature — a source code quirk).
  - Guards on `player:HasTrait("HighSweaty") and not player:isAsleep()`.
  - Branches by weapon category:
    - **Blunt / LongBlade / Spear / Axe**: `MSTincreaseThirst(player, ZombRand(20), 0.01)` (1/20 chance, +0.01) + `MSTincreaseWetness(player, ZombRand(4), ZombRand(6))` (1/4 chance, +0–5 wetness)
    - **SmallBlunt**: `MSTincreaseThirst(player, ZombRand(25), 0.01)` (1/25 chance, +0.01) + `MSTincreaseWetness(player, ZombRand(4), ZombRand(4))` (1/4 chance, +0–3 wetness)
    - **SmallBlade**: `MSTincreaseThirst(player, ZombRand(30), 0.01)` (1/30 chance, +0.01) + `MSTincreaseWetness(player, ZombRand(4), ZombRand(2))` (1/4 chance, +0–1 wetness)
    - **Unarmed (standing)**: `MSTincreaseThirst(player, ZombRand(20), 0.01)` (1/20 chance) + `MSTincreaseWetness(player, ZombRand(4), ZombRand(3))` (1/4 chance, +0–2 wetness)
    - **Unarmed (aim at floor / ground stomp)**: `MSTincreaseThirst(player, ZombRand(25), 0.01)` (1/25 chance) + `MSTincreaseWetness(player, ZombRand(4), ZombRand(4))` (1/4 chance, +0–3 wetness)

  **Fitness exercise hooks (Vanilla variant only):**
  - On each exercise rep (squat, pushup, situp, barbellcurl): `MSTincreaseThirst(player, ZombRand(20), 0.01)` (1/20 chance) + `MSTincreaseWetness(player, ZombRand(2), ZombRand(10)–ZombRand(12))` (1/2 chance, +0–9/+0–11 wetness).

- Source cost: **-3** (negative — penalty trait)
- Source mutual exclusions: `HighSweaty` ↔ `LessSweaty`

## Current UT Evidence

### Structure
- Registered in registries.lua: **yes** — `UTTraitsRegistries.UT_highsweaty = CharacterTrait.register("UniversalTraits:UT_highsweaty")` at line 133, immediately after `UT_lesssweaty`
- Defined in UT_character_traits.txt: **yes** — lines 1031–1040:
  ```
  character_trait_definition UniversalTraits:UT_highsweaty
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_highsweaty,
      Cost = -3,
      UIName = UI_UT_highsweaty,
      UIDescription = UI_UT_highsweatyDesc,
      MutuallyExclusiveTraits = UniversalTraits:UT_lesssweaty,
  }
  ```
  No `XPBoosts`, no `GrantedTraits`.
- Translation strings present: **yes** — `UI_EN.txt` lines 302–303:
  - `UI_UT_highsweaty = "High Sweaty"`
  - `UI_UT_highsweatyDesc = "You sweat profusely at the slightest exertion. Physical activity rapidly increases your wetness level."`
- Exclusions/grants correct: **yes** — `MutuallyExclusiveTraits = UniversalTraits:UT_lesssweaty` mirrors the source mutual exclusion (`HighSweaty` ↔ `LessSweaty`). The reciprocal is confirmed: `UT_lesssweaty` script block at line 1028 lists `MutuallyExclusiveTraits = UniversalTraits:UT_highsweaty`.
- Runtime Lua file exists: **yes** — `media/lua/shared/UniversalTraits/traits/UT_highsweaty.lua` (38 lines)
- UT_MET group membership: none identified

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_highsweaty.lua` (38 lines, complete — reproduced in full below)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` lines 11–16 — `UTCore.hasTrait` definition
  - `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua` lines 16–42 — `UTCore.registerPeriodicHandler` definition

- Full Lua file (38 lines):
  ```lua
  -- UT_highsweaty.lua
  -- Source: MoreSimpleTraits MSTMainFile.lua — highsweatytrait() + highsweatyattack().
  -- EveryOneMinute: movement-based wetness and thirst increase.
  -- OnWeaponSwingHitPoint: combat sweat increases wetness and thirst.

  local TRAIT_ID = "UniversalTraits:UT_highsweaty"

  local function handler(player)
      if not UTCore.hasTrait(player, TRAIT_ID) then return end
      local bd = player:getBodyDamage()
      if not bd then return end
      local stats = player:getStats()
      local wetness = bd:getWetness()

      if player:isSprinting() then
          bd:setWetness(math.min(wetness + 0.05, 1.0))
          stats:add(CharacterStat.THIRST, 0.03)
      elseif player:isRunning() then
          bd:setWetness(math.min(wetness + 0.03, 1.0))
          stats:add(CharacterStat.THIRST, 0.02)
      else
          bd:setWetness(math.min(wetness + 0.01, 1.0))
      end
  end

  local function onWeaponSwing(attacker, weapon, target, hitPoint)
      if not attacker or not UTCore.hasTrait(attacker, TRAIT_ID) then return end
      if weapon == nil then return end
      local bd = attacker:getBodyDamage()
      if not bd then return end
      local stats = attacker:getStats()
      bd:setWetness(math.min(bd:getWetness() + 0.02, 1.0))
      stats:add(CharacterStat.THIRST, 0.01)
  end

  UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)
  Events.OnWeaponSwingHitPoint.Add(onWeaponSwing)
  ```

- Event registrations:
  - `UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)` — registered via the UTCore wrapper. This wraps `handler` in a closure that resolves `getPlayer()` at call time and passes the result as the `player` argument to `handler`. The wrapper is idempotent (no double-registration). Internally calls `Events.EveryOneMinute.Add(wrappedFn)`.
  - `Events.OnWeaponSwingHitPoint.Add(onWeaponSwing)` — direct raw registration. Fires on every weapon swing that connects with a hit point. `onWeaponSwing` receives `(attacker, weapon, target, hitPoint)`.

- UTCore hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — defined in `UTCore_API.lua`: nil-safe; returns `false` if `player` is nil or `player:getTraits()` is nil; otherwise returns `traits:contains(traitId)`.
  - `UTCore.registerPeriodicHandler(traitId, intervalEvent, handlerFn)` — defined in `UTCore_Events.lua`: builds a wrapper that calls `handlerFn(getPlayer())` on each event tick; registers once (idempotent key check on `traitId + intervalEvent`); adds wrapper to `Events[intervalEvent]`.

- Runtime chain — `handler` (EveryOneMinute):
  1. `Events.EveryOneMinute` fires (once per in-game minute).
  2. UTCore wrapper calls `handler(getPlayer())`. Singleplayer only (consistent with `DisabledInMultiplayer = true`).
  3. Guard: `UTCore.hasTrait(player, TRAIT_ID)` — if player is nil or lacks the trait, exit.
  4. Guard: `player:getBodyDamage()` into `bd` — if nil, exit.
  5. Read `player:getStats()` into `stats` (no nil guard — see notes).
  6. Read `bd:getWetness()` into `wetness`.
  7. **Sprinting branch**: `setWetness(math.min(wetness + 0.05, 1.0))` + `stats:add(CharacterStat.THIRST, 0.03)`
  8. **Running branch** (else-if): `setWetness(math.min(wetness + 0.03, 1.0))` + `stats:add(CharacterStat.THIRST, 0.02)`
  9. **Idle branch** (else): `setWetness(math.min(wetness + 0.01, 1.0))` — no thirst effect

- Runtime chain — `onWeaponSwing` (OnWeaponSwingHitPoint):
  1. `Events.OnWeaponSwingHitPoint` fires on every weapon hit.
  2. Guard: `attacker` not nil and `UTCore.hasTrait(attacker, TRAIT_ID)` — exit if either fails.
  3. Guard: `weapon ~= nil` — exit if no weapon.
  4. Guard: `attacker:getBodyDamage()` into `bd` — exit if nil.
  5. Read `attacker:getStats()` into `stats` (no nil guard — see notes).
  6. `bd:setWetness(math.min(bd:getWetness() + 0.02, 1.0))` — wetness +0.02 per hit, capped at 1.0.
  7. `stats:add(CharacterStat.THIRST, 0.01)` — thirst +0.01 per hit.

- `stats` nil guard: **absent** in both `handler` and `onWeaponSwing`. `player:getStats()` / `attacker:getStats()` is called without nil-checking the return. In practice PZ always provides a valid stats object for a live player, so this is low risk, but it is a minor deviation from fully defensive patterns.

- Wetness scale note: The UT implementation uses the 0.0–1.0 normalized scale (same range as `CharacterStat`), while the source MST code uses the raw integer wetness scale (0–99 units). They are measuring the same field differently. The UT values (0.01, 0.03, 0.05, 0.02) operate on the same normalized range as the vanilla game's own wetness API.

- Actual behavior — exact values per cadence:

  **EveryOneMinute (periodic handler):**
  | Movement state | Wetness delta | Thirst delta |
  |---|---|---|
  | Idle (not running, not sprinting) | +0.01 | none |
  | Running | +0.03 | +0.02 |
  | Sprinting | +0.05 | +0.03 |

  All wetness values are clamped at 1.0. Thirst uses `stats:add(CharacterStat.THIRST, n)` which applies the value directly — no manual cap is written, but PZ's own stat system clamps thirst at 1.0 internally.

  **OnWeaponSwingHitPoint (per successful hit):**
  - Wetness: +0.02 per hit, capped at 1.0.
  - Thirst: +0.01 per hit.
  - No weapon-category branching — all weapons trigger the same flat increment. This is a simplification versus the source, which branched by Blunt/LongBlade/SmallBlade/Unarmed with different probability windows.
  - No sleep guard — the source checked `not player:isAsleep()`, but the UT version does not. In practice the player cannot swing a weapon while asleep, so this is a non-issue functionally, but the guard is absent.

  **Wetness rate context:**
  - Idle: +0.01/min. From 0 to full (1.0) in 100 minutes of pure idle — this is the baseline "you're sweating even standing still" effect.
  - Running: +0.03/min. From 0 to 1.0 in ~33 minutes of sustained running.
  - Sprinting: +0.05/min. From 0 to 1.0 in 20 minutes of sustained sprinting.
  - Combat (10 hits/min estimate): +0.02 × 10 = +0.20/min additional wetness on top of periodic — in heavy combat the combined effect can saturate wetness in under 5 minutes.

## Description Integrity
- Display name check: `"High Sweaty"` — grammatically awkward (adjective used as noun phrase). The source MST display name (resolved from `getText("UI_trait_highsweaty")`) is not directly visible in indexed Lua; the UT name pattern follows the source trait ID string. "Heavy Sweater" or "Excessive Sweating" would be cleaner English, but the current name is intelligible and consistent with other UT naming conventions.
- Description check: `"You sweat profusely at the slightest exertion. Physical activity rapidly increases your wetness level."`
  - "Sweat profusely at the slightest exertion" — accurate in spirit. However the implementation also adds wetness while idle (+0.01/min), not only during exertion. The idle wetness increase is unmentioned.
  - "Physical activity rapidly increases your wetness level" — accurate for running and sprinting. Also accurate for combat hits.
  - **Missing**: thirst drain is entirely unmentioned. Thirst increases +0.02/min running, +0.03/min sprinting, and +0.01 per weapon hit. In heavy combat or extended running this is a meaningful water demand.
  - **Missing**: idle wetness increase (+0.01/min unconditionally). The description implies the trait is conditional on "exertion" but the idle branch fires regardless.
  - **Missing**: combat wetness/thirst component — no mention that swinging a weapon also triggers the effect.
  - No fabricated mechanics — everything described exists in code. The omissions are additive (the description undersells the penalty), not misleading.

## Balance Review
- Upside: none — pure negative trait, returns 3 points.
- Downside:
  - **Wetness**: Idle rate (+0.01/min) means even standing around slowly saturates the wetness meter. At running speed (+0.03/min) the player reaches full wetness in ~33 minutes of sustained movement. Wetness causes clothing to become wet, which reduces insulation and contributes to hypothermia risk and encumbrance discomfort in cold/rainy weather. It also has cosmetic/morale implications depending on other traits.
  - **Thirst (periodic)**: Running adds +0.02/min, sprinting +0.03/min. The PZ baseline thirst drain is approximately 0.003–0.006/min at rest. During a 30-minute run, this trait adds +0.6 on top of baseline — roughly equivalent to drinking a full bottle of water's worth of thirst per 30-minute run session.
  - **Thirst (combat)**: +0.01 per hit. A fight against a moderate zombie horde (20–40 hits) adds +0.20–0.40 thirst per engagement. This is significant during extended combat sequences.
  - **Uptime**: The idle wetness increase is always active — 100% uptime during all non-sleeping time. The thirst components only activate during running, sprinting, or combat, making them conditional on playstyle.
  - **Wetness consequence severity**: Wetness itself is not directly lethal. Its primary consequence is temperature regulation (cold/wet = hypothermia risk, relevant in winter or rain) and minor morale effects. In warm dry conditions wetness is less punishing.
- Peer comparison:
  - `UT_lesssweaty` (+2) is the direct counterpart — reduces wetness. The mutual exclusion is correct and symmetrical.
  - At -3 this is cheaper than most always-on dual-stat penalty traits. The wetness mechanic is softer than hunger/thirst drain (which directly threatens survival) because wetness consequences are conditional on environment and temperature.
- Stack or exclusion notes:
  - `MutuallyExclusiveTraits = UniversalTraits:UT_lesssweaty` is correctly declared in both trait blocks.
  - Stacks freely with temperature-sensitive traits (`UT_coldsensitive`, etc.). The combination of high wetness rate + cold sensitivity would be particularly punishing in winter.
  - No interaction with hunger traits or the vanilla `Outdoorsman` trait (which reduces wetness from rain).
- Cost verdict: **-3 is reasonable**. The always-on idle wetness and the thirst drain during activity are genuine quality-of-life costs, but wetness is a softer resource than hunger/thirst — its consequences depend on environmental context. The -3 cost is consistent with other conditional-severity penalty traits.

## Regression Proof
- Existing test: `"UniversalTraits:UT_highsweaty"` appears in the Phase 1 smoke-test ID list at `test/run_tests.lua` line 229, paired with `UT_lesssweaty`. This list is validated by two tests:
  1. `"all N trait IDs registered with CharacterTrait"` — confirms `CharacterTrait.register("UniversalTraits:UT_highsweaty")` has been called and the ID resolves.
  2. `"script trait definitions resolve cleanly and preserve UT_MET coverage"` — confirms the script block exists, `CharacterTrait` field matches the block ID, and that `MutuallyExclusiveTraits = UniversalTraits:UT_lesssweaty` references a registered ID (it does — `UT_lesssweaty` is at line 132 in registries.lua).
- What these tests prove: ID registration and script-block structural integrity, including mutual exclusion reference validity.
- Missing proof: No moddata spot-check test for `UT_highsweaty`. Neither the `handler` nor `onWeaponSwing` function is exercised at runtime by any test. The stat increments, wetness clamping, guard behavior for nil `bd`, the movement branching logic, and the per-hit combat effect are all untested.
- Minimum next tests if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_highsweaty.lua")

  test("UT_highsweaty: idle increases wetness by 0.01 per minute, no thirst change", function()
      local p = MockPlayer({ "UniversalTraits:UT_highsweaty" })
      p:getBodyDamage():setWetness(0.5)
      p:getStats():setThirst(0.3)
      p._running = false; p._sprinting = false
      withActivePlayer(p, function()
          Events.EveryOneMinute:fire()
      end)
      assert_close(p:getBodyDamage():getWetness(), 0.51, 0.0001, "expected wetness +0.01")
      assert_eq(p:getStats():getThirst(), 0.3, "thirst should not change when idle")
  end)

  test("UT_highsweaty: running increases wetness by 0.03 and thirst by 0.02", function()
      local p = MockPlayer({ "UniversalTraits:UT_highsweaty" })
      p:getBodyDamage():setWetness(0.0)
      p:getStats():setThirst(0.0)
      p._running = true; p._sprinting = false
      withActivePlayer(p, function()
          Events.EveryOneMinute:fire()
      end)
      assert_close(p:getBodyDamage():getWetness(), 0.03, 0.0001, "expected wetness +0.03")
      assert_close(p:getStats():getThirst(), 0.02, 0.0001, "expected thirst +0.02")
  end)

  test("UT_highsweaty: sprinting increases wetness by 0.05 and thirst by 0.03", function()
      local p = MockPlayer({ "UniversalTraits:UT_highsweaty" })
      p:getBodyDamage():setWetness(0.0)
      p:getStats():setThirst(0.0)
      p._sprinting = true
      withActivePlayer(p, function()
          Events.EveryOneMinute:fire()
      end)
      assert_close(p:getBodyDamage():getWetness(), 0.05, 0.0001, "expected wetness +0.05")
      assert_close(p:getStats():getThirst(), 0.03, 0.0001, "expected thirst +0.03")
  end)

  test("UT_highsweaty: wetness clamped at 1.0", function()
      local p = MockPlayer({ "UniversalTraits:UT_highsweaty" })
      p:getBodyDamage():setWetness(0.99)
      p._sprinting = true
      withActivePlayer(p, function()
          Events.EveryOneMinute:fire()
      end)
      assert_eq(p:getBodyDamage():getWetness(), 1.0, "wetness must not exceed 1.0")
  end)

  test("UT_highsweaty: weapon hit adds wetness 0.02 and thirst 0.01", function()
      local p = MockPlayer({ "UniversalTraits:UT_highsweaty" })
      p:getBodyDamage():setWetness(0.5)
      p:getStats():setThirst(0.2)
      local weapon = MockWeapon()
      Events.OnWeaponSwingHitPoint:fire(p, weapon, nil, nil)
      assert_close(p:getBodyDamage():getWetness(), 0.52, 0.0001, "expected wetness +0.02 per hit")
      assert_close(p:getStats():getThirst(), 0.21, 0.0001, "expected thirst +0.01 per hit")
  end)

  test("UT_highsweaty: no effect when player lacks trait", function()
      local p = MockPlayer({})
      p:getBodyDamage():setWetness(0.5)
      p:getStats():setThirst(0.2)
      withActivePlayer(p, function()
          Events.EveryOneMinute:fire()
      end)
      assert_eq(p:getBodyDamage():getWetness(), 0.5, "wetness unchanged without trait")
      assert_eq(p:getStats():getThirst(), 0.2, "thirst unchanged without trait")
  end)
  ```

## Final Verdict
- Source origin: **confirmed** — MoreSimpleTraits `HighSweaty` (present in both `MoreSimpleTraits` and `MoreSimpleTraitsVanilla` variants). Source cost **-3** (identical to UT). Source used two handlers: `highsweatytrait()` on `EveryOneMinute` (probabilistic wetness/thirst increases gated by `ZombRand(n) == 0` chance rolls, with separate idle/running/sprinting branches) and `highsweatyattack()` on `OnWeaponSwingHitPoint` (probabilistic per-weapon-category wetness/thirst increases). Fitness exercise hooks present in the Vanilla variant. Source used a raw wetness integer scale (0–99); source used `MSTincreaseThirst` / `MSTincreaseWetness` helpers that applied effects only when a `chance` argument rolled zero.
- UT implementation: **faithful re-implementation with normalization**. UT preserves the two-trigger structure (periodic + weapon hit), the movement-state branching (idle/running/sprinting), and the mutual exclusion with `UT_lesssweaty`. The primary differences are:
  1. **Deterministic vs probabilistic**: UT applies fixed deltas every tick; the source used `ZombRand(n)` chance rolls making the source effect probabilistic and variable-magnitude. UT is more predictable.
  2. **Scale normalization**: UT uses the 0.0–1.0 normalized wetness range; the source used raw 0–99 integer units. The UT values are calibrated to the normalized scale.
  3. **No weapon-category branching in combat**: UT applies a flat +0.02 wetness / +0.01 thirst per hit regardless of weapon type. The source branched by Blunt/SmallBlunt/SmallBlade/Unarmed with different probability windows. The UT simplification is cleaner.
  4. **No exercise-specific hooks**: The source Vanilla variant had per-exercise fitness action hooks. UT does not replicate these — the periodic handler covers general movement.
  5. **UTCore routing**: The periodic handler uses `UTCore.registerPeriodicHandler` (idempotent, wrapper-based). The weapon hit handler uses direct `Events.OnWeaponSwingHitPoint.Add`. Both are correct patterns.
- Description: **partially accurate but incomplete**. "Sweat profusely at the slightest exertion" — accurate but omits the unconditional idle wetness increase (the trait fires even while standing still). "Physical activity rapidly increases your wetness level" — accurate but omits the thirst drain component and the per-hit combat sweat. No fabricated claims. Needs an update to mention thirst and idle wetness.
- Balance: **-3 is appropriate**. Wetness is a softer penalty resource than hunger/thirst — its severity depends on environmental temperature and weather. The always-on idle effect (+0.01/min) is mild; the movement-scaled effects (+0.03/+0.05/min with thirst) are meaningful during active play. The combat hit effect adds real pressure during fights. The cost matches the conditional-but-persistent nature of the burden.
- Regression proof: **structural only**. ID registration, script-block validity, and mutual exclusion reference are covered by smoke tests. The runtime handlers — stat increments, wetness clamping, movement branching, combat trigger, nil guards — have zero runtime test coverage.
- Action needed:
  1. **Fix display name** — "High Sweaty" is grammatically awkward. Recommended: `"Excessive Sweater"` or `"Heavy Sweater"`. Low priority but worth fixing before a public release.
  2. **Fix description** — add thirst drain, idle wetness, and combat trigger. Example: `"You sweat excessively even at rest, and profusely during any physical activity or combat. Your wetness level rises constantly, and running, sprinting, or fighting also leaves you noticeably thirstier."`
  3. **Add runtime tests** — the six test cases above cover the critical branches (idle/running/sprinting wetness, thirst gating, clamping, combat hit, no-trait guard).
  4. **Optional**: add nil guard on `player:getStats()` in both `handler` and `onWeaponSwing` for consistency with the defensive pattern used elsewhere in UT (e.g., the `bd` nil check already present in this file).
  5. **Optional**: add sleep guard to `onWeaponSwing` (matching the source's `not player:isAsleep()` check). Functionally not needed since the player cannot swing while asleep, but improves parity with source intent.
- Open gaps:
  - No `stats` nil guard in either handler. Low risk but inconsistent.
  - No sleep guard in `onWeaponSwing`. Functionally harmless — noted for completeness.
  - The source's exercise-specific fitness hooks (squat/pushup/situp/barbellcurl in the Vanilla variant) are not replicated. These added extra wetness/thirst during formal exercise actions. Whether this is an intentional scope reduction or an oversight is not documented.
  - `ZombRand` is absent from the UT implementation — all deltas are fixed, making the UT version fully deterministic. The source's stochastic behavior (effects that fired probabilistically each minute) produced a more variable experience. The deterministic UT version is easier to balance and test, which is the right call.
