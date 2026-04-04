# UT_sundayrunner

## Trait Summary

- UT trait id: `UniversalTraits:UT_sundayrunner`
- Source mod: SomewhatTraits (`SomewhatTraitsCore` runtime + `SomewhatTraits` trait definition)
- Source trait id: `SWTraits:SWSundayRunner` (`SWSundayRunner`)
- Current cost: -1
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` (lines 372-382) — B42.15 server runtime
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (lines 712-734) — earlier client runtime with fuller behavior
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/scripts/SWTraits_character_traits.txt` (lines 274-282) — script definition
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` (lines 109, 117) — legacy registration + mutual exclusion
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (lines 65-66) — current EN text
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/SWTraits_MET.lua` (lines 75-78) — source mutual exclusion
- Source trigger path:
  - B42.15 source runtime: `Events.OnTick.Add(SWSundayRunner)`.
  - Handler guards on player existence, trait presence, and active sprinting before applying the penalty.
- Source behavior:
  - B42.15 server runtime applies `stats:add(CharacterStat.UNHAPPINESS, 2)` every tick while sprinting.
  - Earlier client implementation was stronger and more explicit: while sprinting it added both stress (`timeMultiplier * 0.02`) and unhappiness (`timeMultiplier * 2`), clamped to max values.
  - Source EN description is concise and mechanically accurate: `"Sprinting increases stress and unhappiness."`
  - Source cost is `-1`.
  - Source declared `SWSprintDemon` and `SWSundayRunner` mutually exclusive in both legacy trait creation and B42 `SWTraits_MET.lua`.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — `UTTraitsRegistries.UT_sundayrunner = CharacterTrait.register("UniversalTraits:UT_sundayrunner")` at line 131.
- Defined in UT_character_traits.txt: yes —
  ```
  character_trait_definition UniversalTraits:UT_sundayrunner
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_sundayrunner,
      Cost = -1,
      UIName = UI_UT_sundayrunner,
      UIDescription = UI_UT_sundayrunnerDesc,
  }
  ```
- Translation strings present: yes —
  - `UI_UT_sundayrunner = "Sunday Runner"` (`UI_EN.txt` line 296; `UI.json` line 160)
  - `UI_UT_sundayrunnerDesc = "Occasional jogging has done little for your long-term endurance. Fitness is slightly below average."` (`UI_EN.txt` line 297; `UI.json` line 161)
- Exclusions/grants correct: **no** — UT declares no `MutuallyExclusiveTraits`, but the source made this trait mutually exclusive with the positive sprint trait (`SWSprintDemon`). UT has no equivalent `UniversalTraits:UT_sprintdemon` exclusion in either script data or runtime audit notes.
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_sundayrunner.lua`

### Runtime Trace

- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_sundayrunner.lua` (entire file)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua` — `UTCore.registerPeriodicHandler`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait`
- Event registrations:
  - `UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)`
  - Effective PZ event: `Events.EveryOneMinute`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe trait gate using `player:getTraits():contains(traitId)`.
  - `UTCore.registerPeriodicHandler` — idempotent wrapper keyed by `traitId .. "::" .. intervalEvent`; stores the handler and registers a wrapper that resolves `getPlayer()` at fire time.
- Runtime chain (plain language):
  1. At file load, `UTCore.registerPeriodicHandler("UniversalTraits:UT_sundayrunner", "EveryOneMinute", handler)` registers the trait handler.
  2. Every in-game minute, UTCore's wrapper calls `getPlayer()` and passes the active player to `handler(player)`.
  3. Guard 1: if the player does not have `UniversalTraits:UT_sundayrunner`, exit.
  4. Guard 2: if `player:isSprinting()` is false, exit.
  5. Otherwise read `player:getStats()` and call `stats:add(CharacterStat.UNHAPPINESS, 2.0)`.
- Actual behavior (exact values):
  - **Cadence:** once per in-game minute, not every tick.
  - **Trigger:** only while the player is actively sprinting at the moment of the minute tick.
  - **Penalty applied:** `+2.0` unhappiness per minute.
  - **No stress penalty exists in UT.**
  - **No Fitness penalty exists in UT.** No `XPBoosts`, no perk-level reduction, and no stamina/endurance effect are present.
  - Because the handler is minute-based, short sprint bursts between minute ticks can avoid the penalty entirely; conversely, continuous sprinting accrues a steady unhappiness increase.

## Description Integrity

- Display name check: `Sunday Runner` matches the source name.
- Description check: `"Occasional jogging has done little for your long-term endurance. Fitness is slightly below average."`
- Missing or misleading details:
  1. **False mechanic:** the description claims below-average Fitness, but UT never changes Fitness, endurance, sprint speed, or any perk level.
  2. **Missing real penalty:** the actual runtime effect is `+2` unhappiness every in-game minute while sprinting. The description never mentions unhappiness at all.
  3. **Source drift hidden from player:** source text said sprinting raises stress and unhappiness. UT removed the stress component but replaced the description with a fake passive Fitness penalty instead of describing the real active sprint penalty.
  4. **Missing cadence/condition:** the penalty only happens while sprinting; walking/running do nothing. The current description does not mention the sprint-only trigger.

## Balance Review

- Upside: none — negative trait worth `-1` point.
- Downside: adds `2` unhappiness per in-game minute while sprinting.
- Uptime: low-to-moderate. Only active during sprinting, and only sampled once per minute. Players who rarely sprint will barely feel it; players who rely on repeated sprint bursts may often dodge the tick entirely.
- Peer comparison:
  - Source counterpart was also `-1`, but earlier source code penalized both stress and unhappiness while sprinting, making it harsher than UT.
  - The natural positive opposite is `UT_sprintdemon` (cost `2`, `XPBoosts = Sprinting=1`), and the source explicitly prevented taking both together.
- Stack or exclusion notes:
  - Missing exclusion with `UT_sprintdemon` lets players combine a positive sprint perk bonus with this minor conditional downside for net point gain.
  - Because the trait only adds unhappiness, it can be countered by common mood-management traits/items more easily than a true Fitness penalty would be.
- Cost verdict: **questionable / mildly underpowered as a downside**. At `-1` the trait is not game-breaking, but the UT implementation is noticeably softer than both the old source intent and the player-facing implication. Missing the `UT_sprintdemon` exclusion makes it easier to exploit as a low-impact refund.

## Regression Proof

- Existing test: registration-only coverage in `UniversalTraits/test/run_tests.lua` line 234, where `"UniversalTraits:UT_sundayrunner"` appears in the all-IDs sweep.
- What it proves: only that the trait ID is registered and expected by the registry/script consistency test set.
- Missing proof:
  - No test that `EveryOneMinute` applies unhappiness while sprinting.
  - No test that the handler does nothing when not sprinting.
  - No test that trait absence blocks the penalty.
  - No test covering the minute-based cadence or the exact `+2` value.
- Minimum next test if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_sundayrunner.lua")

  test("UT_sundayrunner adds 2 unhappiness while sprinting", function()
      local body = {
          _u = 10,
          getUnhappinessLevel = function(self) return self._u end,
          setUnhappinessLevel = function(self, v) self._u = v end,
      }
      local stats = {
          add = function(_, stat, amount)
              assert_eq(stat, CharacterStat.UNHAPPINESS)
              body:setUnhappinessLevel(body:getUnhappinessLevel() + amount)
          end,
      }
      local p = MockPlayer({ "UniversalTraits:UT_sundayrunner" }, { bodyDamage = body, stats = stats })
      p:setSprinting(true)
      withActivePlayer(p, function() Events.EveryOneMinute:fire() end)
      assert_eq(body:getUnhappinessLevel(), 12)
  end)
  ```
  Add companion tests for not-sprinting and no-trait guards.

## Final Verdict

- Source origin: **proven** — confirmed in SomewhatTraits B42 files and earlier pre-B42 runtime/translation files.
- UT implementation: **simplified/drifted** — keeps the broad sprint-penalty concept but only applies unhappiness, at a much lower cadence, and drops the source's explicit `UT_sprintdemon`-equivalent exclusion.
- Description: **misleading** — describes a nonexistent Fitness penalty and omits the actual unhappiness-on-sprint behavior.
- Balance: **questionable** — small enough to be acceptable at `-1`, but currently easier to exploit than intended because the downside is conditional, minute-sampled, and missing a key exclusion.
- Regression proof: **missing** — registration only; no behavioral test for the actual handler.
- Action needed: **doc fix**, **test fix**, **code/design review**.
- Open gaps:
  - Need explicit design decision on whether UT intentionally removed the source stress penalty.
  - Need explicit decision on whether `UT_sundayrunner` should exclude `UT_sprintdemon` like the source did.
  - Test harness may need a tiny `stats:add(...)`/`CharacterStat.UNHAPPINESS` helper if no existing mock already covers this path.
