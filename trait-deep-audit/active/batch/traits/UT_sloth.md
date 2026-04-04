# UT_sloth

## Trait Summary

- UT trait id: `UniversalTraits:UT_sloth`
- Source mod: SomewhatTraits (`SomewhatTraitsCore` runtime + `SomewhatTraits` trait definition)
- Source trait id: `SWTraits:SWSloth` (`SWSloth`)
- Current cost: 2
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/scripts/SWTraits_character_traits.txt` lines 111-119 - B42 script definition
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/registries.lua` lines 23-25 - B42 registry list
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` lines 89, 116 - legacy trait registration + mutual exclusion
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/Translate/EN/UI.json` lines 26-27 - B42 display text
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/SWTraits_MET.lua` lines 70-73 - source mutual exclusion pairing
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` lines 31-53, 200-211 - canonical B42.15 server runtime
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.12/media/lua/client/SWSomewhatTraitsCore.lua` lines 332-348 - older client runtime with explicit clamping
- Source trigger path:
  - B42.15 source runtime wires `SWSloth()` through `Events.OnTick`, but the handler only runs for the current player slot selected by the shared staggered dispatcher every roughly 5 seconds per player.
- Source behavior:
  - B42 script definition registers `SWTraits:SWSloth` as a non-profession trait with cost `2`.
  - Source UI text is `Sloth` / `Slows down fatigue gain when walking or standing still.`
  - When the selected player has `SWSloth` and is not running or sprinting, the source removes fatigue by `dayLengthMultiplier * 0.0005`.
  - Source halves that fatigue reduction if the player has vanilla less-sleep or more-sleep traits.
  - Source declares `SWSloth` and `SWSquirrel` mutually exclusive in both legacy trait setup and B42 `SWTraits_MET.lua`.

## Current UT Evidence

### Structure

- Registered in `UniversalTraits/media/registries.lua`: yes - line 127 registers `CharacterTrait.register("UniversalTraits:UT_sloth")`.
- Defined in `UniversalTraits/media/scripts/UT_character_traits.txt`: yes - lines 971-979 define cost `2`, `IsProfessionTrait = false`, and `DisabledInMultiplayer = true`.
- Translation strings present: yes - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` lines 284-285 and `UniversalTraits/media/lua/shared/Translate/EN/UI.json` lines 152-153 both provide `UI_UT_sloth` / `UI_UT_slothDesc`.
- Runtime Lua file exists: yes - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_sloth.lua`.
- Release sync evidence: current source and `UniversalTraits/release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_sloth.lua` match; release `UI.json` also mirrors the same current description.
- Exclusions/grants correct: no.
  - `UT_character_traits.txt` has no `MutuallyExclusiveTraits` entry on `UT_sloth`.
  - `UniversalTraits/media/lua/shared/UniversalTraits/UT_MET.lua` has no `UT_sloth` / `UT_squirrel` grouping.
  - `UT_squirrel` currently excludes `UT_packmouse` and `UT_topheavy`, not `UT_sloth`.

### Runtime Trace

- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_sloth.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_Events.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua`
  - `UniversalTraits/test/UTTestMocks.lua` lines 255-290
- Current runtime:
  ```lua
  local function handler(player)
      if not UTCore.hasTrait(player, TRAIT_ID) then return end
      if player:isRunning() or player:isSprinting() then return end
      local stats = player:getStats()
      stats:remove(CharacterStat.FATIGUE, GameTime.getInstance():getMultiplier() * 0.0005)
  end

  UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)
  ```
- Event registrations:
  - `UTCore.registerPeriodicHandler("UniversalTraits:UT_sloth", "EveryOneMinute", handler)`
  - `UTCore.registerPeriodicHandler` is idempotent per `traitId .. "::" .. intervalEvent`, stores the wrapper in `UTCore._periodicHandlers`, and registers the wrapped callback with `Events.EveryOneMinute`.
- Runtime chain:
  1. UT loads `UT_sloth.lua` and registers one `EveryOneMinute` callback for `UniversalTraits:UT_sloth`.
  2. Each in-game minute, UTCore resolves `getPlayer()` and passes that player into `handler(player)`.
  3. Guard 1: exit if the player does not have `UniversalTraits:UT_sloth`.
  4. Guard 2: exit if `player:isRunning()` or `player:isSprinting()` is true.
  5. Otherwise call `player:getStats():remove(CharacterStat.FATIGUE, GameTime.getInstance():getMultiplier() * 0.0005)`.
- Actual behavior:
  - Active while idle, standing, or walking.
  - Inactive while running or sprinting.
  - No modData, no saved state, and no secondary UTCore hooks beyond periodic dispatch.
  - UT omits the source sleep-trait adjustment entirely.
  - UT also changes the source timing/scaling model: source uses the staggered `OnTick` path with `dayLengthMultiplier`; UT uses `EveryOneMinute` plus `GameTime.getInstance():getMultiplier()`. Broad intent is preserved, but exact magnitude parity is not proven.

## Description Integrity

- Display name: accurate - `Sloth` matches the source.
- Current description: misleading.
- Current UT text: `Extreme laziness has kept you from developing any physical fitness. Fitness is at its lowest.`
- Why it fails:
  1. UT runtime never changes Fitness, Fitness XP, endurance max, or any perk level.
  2. The actual trait effect is a conditional fatigue reduction benefit while the player is not running or sprinting.
  3. The source text is short and mechanically accurate; UT replaced it with a different trait concept entirely.
- Correct description should explicitly describe slower fatigue gain while walking or standing still, and should not claim any Fitness penalty.

## Balance Review

- Upside: passive fatigue reduction during low-intensity movement and idle time.
- Downside: no direct penalty beyond spending 2 character points.
- Source comparison:
  - Source also priced the trait at `+2`, so the current UT cost is not an obvious pricing error by itself.
  - However, source paired that benefit with a hard `Sloth <-> Squirrel` specialization split.
- Drift that affects balance:
  1. Missing `UT_squirrel` mutual exclusion allows both low-intensity and high-intensity fatigue-reduction traits to coexist.
  2. Source sleep-trait interaction is gone, making UT friendlier than the source for sleepy characters.
  3. UT changed cadence/scaling from the source dispatcher model, so exact strength parity is unclear without runtime measurement.
- Cost verdict: questionable. `+2` remains defensible only if the intended specialization tradeoff and player-facing description are restored; in the current state the trait is easier to exploit and easier to misunderstand than the source design intended.

## Regression Proof

- Existing proof:
  - `UniversalTraits/test/run_tests.lua` lines 232-233 include `UniversalTraits:UT_sloth` in the registration/script consistency sweep.
  - `UniversalTraits/test/UTTestMocks.lua` already provides working `UTCore.registerPeriodicHandler` stubs, so the runtime path is testable.
- What current proof covers:
  - The trait ID is expected to exist.
  - Registry/script wiring does not obviously drift out of sync.
- Missing proof:
  1. No behavior test proves fatigue is reduced while idle or walking.
  2. No behavior test proves running or sprinting suppresses the effect.
  3. No regression check proves the intended `UT_sloth <-> UT_squirrel` exclusion is present in script data.
- Minimum next tests if a fix pass happens:
  - Fire `Events.EveryOneMinute` with an active mock player holding `UT_sloth` and confirm fatigue decreases when not running.
  - Repeat with `player._running = true` and `player._sprinting = true` to prove both guards block the effect.
  - Add a script-level assertion that `UT_sloth` and `UT_squirrel` are mutually exclusive once the script definitions are corrected.

## Final Verdict

- Source origin: proven
- UT implementation: simplified
- Description: misleading
- Balance: questionable
- Regression proof: missing
- Action needed: code fix
