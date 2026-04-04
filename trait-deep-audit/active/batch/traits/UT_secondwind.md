# UT_secondwind

## Trait Summary

- UT trait id: `UniversalTraits:UT_secondwind`
- Source mod: More Traits
- Source trait id: `ToadTraits:secondwind` (`secondwind`)
- Current cost: 6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (lines 855-864)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/client/MoreTraits.lua` (lines 3728-3785)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (lines 4556-4633)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (lines 147-158)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (lines 202-203)
- Source trigger path:
  - Source dispatcher calls `SecondWind(...)` for activation and `SecondWindRecharge(...)` for cooldown recovery.
- Source behavior:
  - Cost `10`, grants `Fitness=1` XP boost.
  - Triggers when the trait is active, cooldown is clear, and either `endurance < 0.5` or `fatigue > 0.8`.
  - Requires at least 3 zombies within distance 5.
  - Restores endurance to `1.0`, may reduce fatigue to `0.4`, and starts a long cooldown.
  - Source text says the cooldown is 14 days and is halved if no fatigue was recovered, but source code instead doubles recharge when fatigue recovery happened. Core intent is proven, cooldown nuance is only partially proven.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — `UTTraitsRegistries.UT_secondwind = CharacterTrait.register("UniversalTraits:UT_secondwind")` at line 303.
- Defined in UT_character_traits.txt: yes — lines 2166-2174 with `Cost = 6` and `MutuallyExclusiveTraits = UniversalTraits:UT_indefatigable;UniversalTraits:UT_hardy`.
- Translation strings present: yes — `UI_UT_secondwind = "Second Wind"` and `UI_UT_secondwindDesc = "Just when you think you are done, something kicks in. While sprinting with endurance at or below 0.1, endurance is instantly restored by +0.3. This triggers once per 10-minute cooldown."`
- Exclusions/grants correct: yes — symmetric with `UT_indefatigable` and `UT_hardy`.
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_secondwind.lua`.

### Runtime Trace

- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_secondwind.lua`
  - `UniversalTraits/media/scripts/UT_character_traits.txt`
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `UniversalTraits/test/run_tests.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua`
- Event registrations:
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)`
  - `Events.EveryOneMinute.Add(onEveryMinute)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)`
- Runtime chain (plain language):
  1. `onPlayerUpdate(player)` runs every update tick and exits if the player lacks the trait.
  2. A module-local `tickCounter` throttles execution to every 15 ticks.
  3. If `UT_secondwindTriggered` is already set, the burst cannot retrigger.
  4. While sprinting with endurance `<= 0.1`, the trait instantly adds `+0.3` endurance, capped at max.
  5. It stores `UT_secondwindCooldown = getGameTime():getWorldAgeHours()` and sets `UT_secondwindTriggered = true`.
  6. `onEveryMinute()` clears both cooldown flags once 10 in-game minutes have elapsed.
- Actual behavior (exact values):
  - Trigger: `player:isSprinting()` and endurance `<= 0.1`.
  - Cadence: every 15 `OnPlayerUpdate` ticks.
  - Effect: instant `+0.3` endurance.
  - Cooldown: 10 in-game minutes.
  - No fatigue recovery, no zombie check, no Fitness XP boost.
  - Cooldown state is persisted in modData, so it should survive save/load in SP.

## Description Integrity

- Display name check: accurate.
- Description check: accurate for the current UT behavior.
- Missing or misleading details:
  - Minor only: it omits the 15-tick throttle and internal cooldown-flag cleanup path, but these are implementation details, not player-facing defects.
  - Relative to source, this is a redesign rather than a misleading current description.

## Balance Review

- Upside:
  - Reliable `+0.3` emergency endurance burst.
  - Reusable every 10 in-game minutes.
- Downside:
  - No direct downside besides opportunity cost and mutual exclusion with the stronger stamina-cluster traits.
  - Requires sprinting and near-empty endurance.
- Uptime:
  - Low passive uptime, high burst usefulness.
- Peer comparison:
  - Source trait was costlier (`10`), stronger per activation (full endurance plus possible fatigue reduction), and danger-gated by nearby zombies.
  - UT version is cheaper (`6`), weaker per proc, but vastly more reusable.
  - Compared with current peers, it is a clean mid-tier burst option between `UT_hardy` and `UT_indefatigable`.
- Stack or exclusion notes:
  - Exclusion triangle with `UT_indefatigable` and `UT_hardy` is correct.
- Cost verdict: justified, but clearly a design change rather than a faithful port.

## Regression Proof

- Existing test: yes — `UniversalTraits/test/run_tests.lua` lines 1072-1084 (`secondwind triggers at low endurance and clears after cooldown`).
- What it proves:
  - Loads `UT_secondwind.lua`.
  - Uses the real `OnPlayerUpdate` path with 15 updates.
  - Confirms trigger at `endurance = 0.1` while sprinting.
  - Confirms endurance increases and cooldown flag clears after the real `EveryOneMinute` path.
- Missing proof:
  - No explicit no-trait guard test.
  - No explicit not-sprinting guard test.
  - No explicit no-retrigger-during-cooldown test.
- Minimum next test if needed:
  - Add a no-sprint guard test and a cooldown lockout test.

## Final Verdict

- Source origin: **partially proven**
- UT implementation: **drifted**
- Description: **accurate**
- Balance: **justified**
- Regression proof: **protected**
- Action needed: **none**
- Open gaps:
  - Confirm whether replacing the source danger/zombie fantasy with a pure stamina-management design was intentional.
  - Optional test hardening for no-sprint, no-trait, and cooldown-lockout guards.
