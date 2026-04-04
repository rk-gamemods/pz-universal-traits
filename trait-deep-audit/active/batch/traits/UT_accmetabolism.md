# UT_accmetabolism

## Trait Summary
- UT trait id: `UniversalTraits:UT_accmetabolism`
- Source mod: MoreSimpleTraits
- Source trait id: `AccMetabolism`
- Current cost: -3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` line 141 — `TraitFactory.addTrait("AccMetabolism", ..., 2, ..., false)` — original cost **+2**, non-profession trait
  - `MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua` line 120 — identical registration in the Vanilla variant
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` lines 830–843 — `accmetabolismtrait(player, perk, amount)` handler; wired to `Events.AddXP`
  - `MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/client/MSTMainFile.lua` lines 830–843, 1137 — identical Vanilla variant
  - `MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` lines 196, 221–222 — mutual-exclusion setup
  - `MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua` lines 182, 196–197, 207–208 — mutual-exclusion setup
- Source trigger path:
  - `accmetabolismtrait(player, perk, amount)` is wired to `Events.AddXP`. It fires every time any XP is awarded to any skill.
- Source behavior:
  - Reads `player:getStats():getHunger()` (`hunger`). Defines `modifier = 1.25` (the commented-out line `--modifier = modifier;` indicates the value was once variable but is now fixed at 1.25).
  - Condition: `player:HasTrait("AccMetabolism") and hunger < 0.249`. Only fires when the player is currently somewhat hungry (hunger value < 0.249 on a 0–1 scale, where 1 is fully hungry).
  - When condition is met, checks `perk == Perks.Fitness or perk == Perks.Strength`. If either matches: awards a **bonus XP amount** of `amount * (modifier - 1)` = `amount * 0.25` directly via `player:getXp():AddXP(perk, amount, false, false, false)`.
  - Net effect: when the player is moderately hungry, gaining Fitness or Strength XP triggers a 25% bonus XP grant for those two skills only. The source trait is an **XP boost tied to hunger state**, not a hunger drain.
  - Source cost: **+2** (positive — treated as a benefit in character creation).
  - Source mutual exclusions (MoreSimpleTraits base): `AccMetabolism` ↔ `Prodigy` (active); `AccMetabolism` ↔ `LightEater` (commented out — disabled).
  - Source mutual exclusions (MoreSimpleTraitsVanilla): `AccMetabolism` ↔ `LightEater` (active, inside a `ToadTraits == false` guard); `AccMetabolism` ↔ `gymgoer` (commented out — disabled); `AccMetabolism` ↔ `Prodigy` (commented out — disabled).

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_accmetabolism = CharacterTrait.register("UniversalTraits:UT_accmetabolism")` at line 256, between `UT_adaptivemetabolism` and `UT_albino`
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_accmetabolism` at lines 1753–1761:
  ```
  character_trait_definition UniversalTraits:UT_accmetabolism
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_accmetabolism,
      Cost = -3,
      UIName = UI_UT_accmetabolism,
      UIDescription = UI_UT_accmetabolismDesc,
  }
  ```
  No `XPBoosts`, no `MutuallyExclusiveTraits`, no `GrantedTraits`.
- Translation strings present: yes — `UI_EN.txt` lines 545–546:
  - `UI_UT_accmetabolism = "Accelerated Metabolism"`
  - `UI_UT_accmetabolismDesc = "Everything runs fast inside you. Your body burns food quickly and your weight shifts with your diet more than most people experience."`
  - Mirrored in `UI.json` keys 294–295 (identical text).
- Exclusions/grants correct: N/A — no `MutuallyExclusiveTraits` or `GrantedTraits` in UT script block. Source cross-mod exclusions (against `Prodigy`, `LightEater`, vanilla traits) do not translate to UT namespace, so omission is correct.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_accmetabolism.lua` (16 lines)
- UT_MET group membership: none — not present in any `UT_MET` group in `UT_MET.lua`.

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_accmetabolism.lua` (16 lines, complete — reproduced in full below)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait` definition (lines 11–16)
  - `test/UTTestMocks.lua` line 201 — test stub for `UTCore.hasTrait`
- Full Lua file (16 lines):
  ```lua
  -- UT_accmetabolism.lua
  -- Accelerated Metabolism: burns through food and water faster

  local TRAIT_ID = "UniversalTraits:UT_accmetabolism"

  local function handler()
      local player = getPlayer()
      if not player then return end
      if not UTCore.hasTrait(player, TRAIT_ID) then return end
      local stats = player:getStats()
      stats:setHunger(math.min(1, stats:getHunger() + 0.05))
      stats:setThirst(math.min(1, stats:getThirst() + 0.03))
  end

  Events.EveryTenMinutes.Add(handler)
  ```
- Event registrations:
  - `Events.EveryTenMinutes.Add(handler)` — raw direct registration, NOT via `UTCore.registerPeriodicHandler`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe wrapper defined in `UTCore_API.lua`: checks `player:getTraits():contains(traitId)`; returns `false` if `player` or `traits` is nil.
- Runtime chain (plain language):
  1. Every 10 in-game minutes PZ fires `Events.EveryTenMinutes`.
  2. `handler()` runs with no arguments — calls `getPlayer()` internally. Singleplayer only (consistent with `DisabledInMultiplayer = true` in script block).
  3. Guard: if `getPlayer()` returns nil, exit immediately.
  4. Guard: if the player does not have trait `UniversalTraits:UT_accmetabolism`, exit immediately.
  5. Read `player:getStats()` into local `stats`.
  6. Call `stats:setHunger(math.min(1, stats:getHunger() + 0.05))` — raises hunger by 0.05, capped at 1.0.
  7. Call `stats:setThirst(math.min(1, stats:getThirst() + 0.03))` — raises thirst by 0.03, capped at 1.0.
  8. No moddata written. No other hooks, events, or side effects.
- `stats` nil guard: **absent**. `player:getStats()` is called without a nil check on the return value. In practice PZ always provides a valid stats object for a live player, making this a low-risk omission, but it is a deviation from the defensive pattern used elsewhere in UT (e.g., `UT_badteeth.lua` guards `bd` before use).
- Actual behavior (exact values):
  - Cadence: once per 10 in-game minutes.
  - Hunger delta: **+0.05 per 10 minutes** → +0.30 per hour → full hunger meter (0 → 1) in approximately **3 hours 20 minutes** of continuous trait activity, from a fully fed starting state.
  - Thirst delta: **+0.03 per 10 minutes** → +0.18 per hour → full thirst meter (0 → 1) in approximately **5 hours 33 minutes** of continuous trait activity, from fully hydrated.
  - Both stats are clamped at 1.0 by `math.min`. Behavior when already at 1.0: `setHunger(math.min(1, 1 + 0.05))` = `setHunger(1)` — no overflow, no crash.
  - No condition gating — effect fires unconditionally every 10 minutes as long as the player has the trait. No hunger threshold, no activity check, no time-of-day restriction.
  - No XP interaction of any kind. The UT implementation is a **pure stat drain** (hunger + thirst), which is a **complete redesign** of the source mechanic (which was a conditional XP bonus on Fitness/Strength when hungry, triggered on `AddXP`).

## Description Integrity
- Display name check: UT uses "Accelerated Metabolism". The source uses the internal ID string `"AccMetabolism"` with display text via `getText("UI_trait_accmetabolism")` — the actual source display name is not directly visible in the indexed Lua (it resolves at runtime from the source mod's translation file). The UT name is fitting for the UT interpretation (a metabolism that burns resources faster).
- Description check: "Everything runs fast inside you. Your body burns food quickly and your weight shifts with your diet more than most people experience."
  - "Burns food quickly" — accurate. Hunger increases by 0.05/10 min.
  - "Thirst" — **not mentioned at all**. Thirst increases by 0.03/10 min. This is a factual omission.
  - "Your weight shifts with your diet more than most people experience" — the UT implementation contains **no weight mechanic**. The runtime file writes only to hunger and thirst. There is no call to any weight, calorie, BMI, or body-fat API. The description promises a weight-shift mechanic that does not exist in code.
- Missing or misleading details:
  1. **Misleading (fabricated mechanic)**: "your weight shifts with your diet more than most people experience" — no weight or calorie mechanism exists anywhere in the Lua file. This sentence describes behavior that is not implemented.
  2. **Missing**: Thirst drain (+0.03/10 min) is entirely unmentioned.
  3. **Missing**: Cadence — player has no information about whether this is continuous or event-triggered.
  4. **Missing**: Magnitude — "burns food quickly" gives no sense of how fast. At +0.05/10 min, the trait drives the player to full hunger from zero in roughly 3.3 hours, which is a meaningful but not crippling penalty.

## Balance Review
- Upside: none — pure negative trait, returns 3 points.
- Downside:
  - Hunger: +0.05 per 10 minutes. The baseline hunger drain in PZ is roughly 0.005–0.01 per minute at rest, or ~0.05–0.10 per 10 minutes. The trait adds approximately **50–100% more hunger drain** on top of baseline, depending on activity level. This is a meaningful food consumption increase.
  - Thirst: +0.03 per 10 minutes. Baseline thirst drain is roughly 0.003–0.006 per minute, or ~0.03–0.06 per 10 minutes. The trait adds approximately **50–100% more thirst drain** on top of baseline. Water management becomes notably more demanding.
  - Uptime: **100%** — no condition gates. The effect fires every 10 minutes regardless of what the player is doing. Unlike traits that only trigger when outside, active, or exposed to specific conditions, this one is always on.
- Peer comparison: UT_ravenous (hunger drain only, presumably stronger), UT_adaptivemetabolism (nearby in registries, metabolic counterpart — buffs the player when adapting to hunger conditions). At -3 cost this is cheaper than UT_fibromyalgia (-8) and more expensive than UT_cangrabless (-2). The constant dual drain (both hunger and thirst) with 100% uptime and no mitigation path is a relatively demanding downside for only 3 points returned.
- Stack or exclusion notes: no `MutuallyExclusiveTraits` in UT script block. Stacks freely with UT_ravenous, UT_adaptivemetabolism (which would partially offset hunger effects), and all other food/drink traits. The interaction with UT_adaptivemetabolism is particularly interesting — UT_adaptivemetabolism buffs the player when hungry, which could partially compensate for the increased hunger drain from UT_accmetabolism. This may be an intentional design pair.
- Cost verdict: **-3 is on the low side**. Constant dual drain (hunger + thirst) with no condition, no mitigation, and 100% uptime is a genuine quality-of-life cost. The hunger drain alone (~50–100% additive on baseline) pushes the player toward more frequent food sourcing. Combined with the thirst drain, resource consumption is noticeably elevated. **-4 or -5 would be more consistent** with the burden this imposes versus peers. However the current -3 is not egregious.

## Regression Proof
- Existing test: `UniversalTraits:UT_accmetabolism` appears in the Phase 3b smoke-test ID list at `test/run_tests.lua` line 287. This list is validated by two tests:
  1. `"all 198 trait IDs registered with CharacterTrait"` — confirms `CharacterTrait.register("UniversalTraits:UT_accmetabolism")` has been called and the ID resolves.
  2. `"script trait definitions resolve cleanly and preserve UT_MET coverage"` — confirms the script block exists, `CharacterTrait` field matches the block ID, and the registry entry resolves. Also validates that any `MutuallyExclusiveTraits` or `GrantedTraits` entries reference registered IDs (N/A for this trait as neither field is defined).
  3. `"script costs match the current balance decisions"` — this test checks specific named traits; `UT_accmetabolism` is not among the explicitly asserted traits (only `packmule`, `preparedpack`, `quickworker`, `slowworker` are), so the cost of -3 is not regression-locked by a test assertion.
- What these tests prove: ID registration and script-block structural integrity. Neither test exercises the Lua runtime handler.
- Missing proof: No moddata spot-check test for `UT_accmetabolism`. The `handler()` function — hunger/thirst increments, `math.min` clamping, guard behavior for nil player and missing trait — is entirely untested at runtime.
- Minimum next test if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_accmetabolism.lua")

  test("UT_accmetabolism: raises hunger by 0.05 and thirst by 0.03 every ten minutes", function()
      local p = MockPlayer({ "UniversalTraits:UT_accmetabolism" })
      -- start at 0 hunger and 0 thirst
      p:getStats():setHunger(0)
      p:getStats():setThirst(0)
      withActivePlayer(p, function()
          Events.EveryTenMinutes:fire()
      end)
      assert_true(math.abs(p:getStats():getHunger() - 0.05) < 0.0001, "expected hunger +0.05")
      assert_true(math.abs(p:getStats():getThirst() - 0.03) < 0.0001, "expected thirst +0.03")
  end)

  test("UT_accmetabolism: hunger and thirst are clamped at 1.0", function()
      local p = MockPlayer({ "UniversalTraits:UT_accmetabolism" })
      p:getStats():setHunger(0.98)
      p:getStats():setThirst(0.99)
      withActivePlayer(p, function()
          Events.EveryTenMinutes:fire()
      end)
      assert_eq(p:getStats():getHunger(), 1.0, "hunger should be clamped at 1.0")
      assert_eq(p:getStats():getThirst(), 1.0, "thirst should be clamped at 1.0")
  end)

  test("UT_accmetabolism: no stat change when player does not have trait", function()
      local p = MockPlayer({})  -- no traits
      p:getStats():setHunger(0.2)
      p:getStats():setThirst(0.1)
      withActivePlayer(p, function()
          Events.EveryTenMinutes:fire()
      end)
      assert_eq(p:getStats():getHunger(), 0.2, "hunger should not change without trait")
      assert_eq(p:getStats():getThirst(), 0.1, "thirst should not change without trait")
  end)
  ```

## Final Verdict
- Source origin: confirmed — MoreSimpleTraits `AccMetabolism` (present in both `MoreSimpleTraits` and `MoreSimpleTraitsVanilla` variants). Source behavior was an **XP bonus**: when hungry (`hunger < 0.249`), Fitness and Strength XP gains are boosted by 25% (`amount * 0.25` bonus grant via `Events.AddXP`). Source cost was **+2** (a positive trait in character creation). Source had conditional mutual exclusions with `Prodigy` and `LightEater` (variant-dependent, some commented out).
- UT implementation: **complete redesign**. UT discards the XP-bonus model entirely and replaces it with a **pure stat drain**: +0.05 hunger and +0.03 thirst per 10 minutes via `Events.EveryTenMinutes`, unconditional, always active. The cost is flipped from +2 (source benefit) to -3 (UT negative). The conceptual theme ("accelerated metabolism → burns resources faster") is plausible but the mechanical execution shares nothing with the source.
- Description: **partially misleading**. "Burns food quickly" is accurate. "Your weight shifts with your diet" describes a weight mechanic that does not exist in the code. Thirst drain is not mentioned at all. Needs a rewrite.
- Balance: **acceptable but underpriced**. The always-on dual drain (hunger + thirst, no condition, no mitigation) is a genuine cost. -3 feels light given 100% uptime and both stats being affected. -4 would be more appropriate; -3 is not wrong but errs on the cheap side.
- Regression proof: **weak**. ID registration and script-block structure are covered by the smoke tests. The runtime handler (stat increments, clamping, guard behavior) has zero runtime test coverage.
- Action needed:
  1. **Fix description** — remove the fabricated weight-shift claim; add thirst drain; give quantitative hints. Example: "Everything runs fast inside you. Your body burns through food and water faster than normal, demanding more frequent meals and drinks to stay functional."
  2. **Add moddata spot-check tests** per the minimum test block above — particularly the stat increment values and the `math.min` clamping behavior.
  3. **Consider cost increase to -4** — the always-on dual drain with no mitigation path is a stronger burden than -3 implies.
  4. **Optional**: migrate event registration to `UTCore.registerPeriodicHandler(TRAIT_ID, "EveryTenMinutes", handler)` for consistency with the UT pattern used by most other periodic traits.
- Open gaps:
  - No `stats` nil guard on `player:getStats()`. Low risk (PZ always provides stats for a valid live player) but inconsistent with defensive patterns used in sibling traits.
  - The UT implementation is so different from the source that "UT_accmetabolism" is effectively a new trait wearing a source name. The XP-bonus mechanic from the source (Fitness/Strength bonus when hungry) would be an interesting UT trait in its own right — consider whether that XP behavior should be captured in a separate trait entry.
  - No weight mechanic exists anywhere in the UT codebase for this trait. If a weight-shift behavior is intended for a future version, it needs a design decision and implementation before the description can legitimately reference it.
