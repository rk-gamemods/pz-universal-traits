# UT_restfulsleeper

## Trait Summary
- UT trait id: UT_restfulsleeper
- Source mod: More Traits (ToadTraits) — `ToadTraits:restfulsleeper`
- Source trait id: `ToadTraits:restfulsleeper` (script-block ID in ToadTraits.txt)
- Current cost: 6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (lines 822–831)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (lines 4701–4743)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (lines 190–191)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua` (ToadTraitsRegistries table)
- Source trait definition (ToadTraits.txt lines 822–831):
  ```
  character_trait_definition ToadTraits:restfulsleeper
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = false,
      CharacterTrait = ToadTraits:restfulsleeper,
      Cost = 6,
      UIName = UI_trait_restfulsleeper,
      UIDescription = UI_trait_restfulsleeperdesc,
      MutuallyExclusiveTraits = base:insomniac,
  }
  ```
- Source translation (UI_EN.txt lines 190–191):
  - `UI_trait_restfulsleeper = "Restful Sleeper"`
  - `UI_trait_restfulsleeperdesc = "Fast gain of energy while sleeping.<br>Suffers no penalties from sleeping on bad furniture or on the ground.<br>Automatically wakes up when fully rested."`
- Source runtime (MoreTraits .lua lines 4701–4743):
  - `RestfulSleeper(player, playerdata)`: fires every update tick while the player is asleep. Reads current fatigue and applies a tiered fatigue reduction per tick:
    - fatigue >= 0.6 → subtract 0.20 per tick
    - fatigue >= 0.2 → subtract 0.10 per tick
    - fatigue < 0.2  → subtract 0.05 per tick
    - Result is clamped to 0 via `math.max(0, fatigue - reduction)`. In multiplayer the new value is sent to the server via `sendClientCommand`.
  - `RestfulSleeperWakeUp(player, playerdata)`: fires on update. If the player is asleep and fatigue has reached 0, calls `player:forceAwake()` — implementing the "automatically wakes up when fully rested" effect.
  - Also records `NeckHadPain` and `FatigueWhenSleeping` on `playerdata` — used elsewhere in MoreTraits for the "no penalties on bad furniture/ground" mechanic.
- Source cost: 6 (matches UT)
- Source mutual exclusion: `base:insomniac` — not carried into UT
- Source `DisabledInMultiplayer`: `false` — UT diverges to `true`
- Source behavior summary: The MoreTraits `restfulsleeper` is a rich multi-effect trait: tiered fatigue drain per tick while sleeping, automatic wake-on-full-rest, and immunity to neck/floor-sleep penalties. All three effects are driven by per-tick Lua callbacks.

## Current UT Evidence

### Structure
- Registered in `media/registries.lua`: yes — line 183, Phase 2 — LUA-DRIVEN: SLEEP & REST block
  ```lua
  UTTraitsRegistries.UT_restfulsleeper = CharacterTrait.register("UniversalTraits:UT_restfulsleeper")
  ```
- Registered in `run_tests.lua` expected_ids: yes — line 257, Phase 2 — Sleep & Rest block
  ```lua
  "UniversalTraits:UT_restfulsleeper", "UniversalTraits:UT_quickrest",
  ```
- Defined in `UT_character_traits.txt`: yes (lines 1315–1323)
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_restfulsleeper`
  - `Cost = 6`
  - `UIName = UI_UT_restfulsleeper`
  - `UIDescription = UI_UT_restfulsleeperDesc`
- MutuallyExclusiveTraits: none defined (source had `base:insomniac`)
- GrantedTraits: none defined
- Translation strings present: yes (UI_EN.txt lines 398–399)
  - `UI_UT_restfulsleeper = "Restful Sleeper"`
  - `UI_UT_restfulsleeperDesc = "You drop into a deep sleep the moment your head hits the pillow. Sleep quality is increased by +50%, allowing faster fatigue recovery from rest."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_restfulsleeper.lua`)

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_restfulsleeper.lua`
  - `test/UTTestMocks.lua` (mock definition of `UTCore.applySleepQuality`)
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` and `UTCore.applySleepQuality(player, 0.5)`
- Mock definition of `applySleepQuality` (UTTestMocks.lua line 218):
  ```lua
  UTCore.applySleepQuality = function(player, v) player:getModData()["UT_sleepQualMod"] = v end
  ```
- Runtime chain (plain language):
  1. `Events.OnNewGame` fires once when a new game session starts.
  2. `UTCore.hasTrait` checks whether the player has `UniversalTraits:UT_restfulsleeper`. If not, the handler returns immediately.
  3. If the trait is present, `UTCore.applySleepQuality(player, 0.5)` is called, which writes `player:getModData()["UT_sleepQualMod"] = 0.5`.
- Actual behavior (exact values):
  - Sets ModData key `UT_sleepQualMod` to `0.5` on new game if the trait is active.
  - The value `0.5` represents a +50% sleep quality modifier, as described.
  - **Critical gap**: The runtime only hooks `Events.OnNewGame`. There is no `OnLoad` / `OnGameBoot` hook to restore `UT_sleepQualMod` when loading an existing save. Any player who picks the trait, saves, and reloads will not have the flag re-applied.
  - **Critical gap**: No event handler in this file or in any other file reviewed consumes `UT_sleepQualMod` and applies it to the game's sleep/fatigue systems at runtime. The script only writes a ModData value; whether a downstream consumer reads it is not evidenced in the files available.
  - **Scope divergence vs. source**: The MoreTraits source implements three distinct effects (tiered per-tick fatigue drain, auto-wake, bad-surface immunity), all via per-tick callbacks. The UT version collapses the entire trait to a single ModData write of `UT_sleepQualMod = 0.5` on new game. The per-tick fatigue drain, auto-wake, and bad-surface penalty suppression behaviors present in the source are all absent.

## Description Integrity
- Display name check: "Restful Sleeper" — exact match to source. No renaming concern.
- Description check: "You drop into a deep sleep the moment your head hits the pillow. Sleep quality is increased by +50%, allowing faster fatigue recovery from rest."
  - The "+50%" figure is consistent with the ModData write of `0.5` to `UT_sleepQualMod`.
  - The "faster fatigue recovery from rest" claim accurately describes the intended effect.
  - The description does not mention auto-wake or bad-surface immunity — features present in the source. This is a scope reduction, not a false claim, but it narrows what players familiar with the original trait may expect.
- Missing or misleading details:
  - The description does not disclose that the effect is applied only on new game start (not on load). If `UT_sleepQualMod` is not restored after a save/load, the description is misleading for any save-and-continue session.
  - The description does not clarify which system reads `UT_sleepQualMod` and applies it; if no consumer is implemented, the description is undeliverable.
  - No mention of `DisabledInMultiplayer = true`, consistent with other UT traits and with the singleplayer-only scope of the description.
  - The source mutual exclusion (`base:insomniac`) was not carried into UT and is not mentioned.

## Balance Review
- Upside: A +50% sleep quality modifier accelerates fatigue recovery during rest, shortening the time the player must spend sleeping. This is a passive, always-on quality-of-life benefit for any survivor who relies on sleep mechanics.
- Downside: None — pure positive trait with no stated drawback.
- Uptime: Intended as always-on after new game start; persistence across saves unconfirmed (see implementation gaps).
- Peer comparison within Sleep & Rest cluster:
  - `UT_quickrest` (cost 3): +30% sleep quality via `applySleepQuality(player, 0.3)` — same mechanic, lower magnitude.
  - `UT_snorer` (cost unknown, negative): imposes a sleep-related penalty.
  - `UT_restfulsleeper` at cost 6 is exactly double the cost of `UT_quickrest` for a +50% vs. +30% modifier. The cost-to-benefit ratio is coherent within the cluster if both traits are linear in effect: +50% is 67% better than +30% but costs 100% more. This is slightly steep for the additional 20% gain, but defensible.
- Source cost: 6 — matches exactly.
- Stack or exclusion notes: No `MutuallyExclusiveTraits` defined in UT. The source excluded `base:insomniac` (the vanilla negative trait for poor sleep). Omitting this exclusion in UT means a player can technically combine `UT_restfulsleeper` with `base:insomniac`, which is a logical contradiction — the interaction outcome depends on how both modifiers stack in the underlying game engine.
- Cost verdict: 6 points is proportionate for a +50% sleep quality boost if the effect is fully functional and persistent. If implementation gaps prevent the effect from firing (no consumer) or from persisting (no OnLoad hook), the trait is a complete point sink with no delivered benefit.

## Regression Proof
- Existing test: `run_tests.lua` includes `"UniversalTraits:UT_restfulsleeper"` in the `expected_ids` array (line 257, Phase 2 — Sleep & Rest block). The test verifies registration only — it confirms the trait ID is registered in `CharacterTrait._registered` and that the string matches the definition block.
- What it proves: Trait ID correctly registered. Definition block, translation keys, and Lua file are all present and structurally consistent.
- Missing proof: No behavioral test exists. There is no test verifying:
  - That `onNewGame` correctly calls `UTCore.applySleepQuality` with `0.5` when the trait is present.
  - That the flag is not written when the trait is absent.
  - That `UT_sleepQualMod` is restored after a game load (an `OnLoad` hook test would be required).
  - That any downstream system reads `UT_sleepQualMod` and applies a +50% modifier to fatigue recovery.
- Minimum next tests if needed:
  1. Mock-based unit test for `onNewGame`: provide a fake player with the trait present; assert `modData["UT_sleepQualMod"] == 0.5` after the call. Provide a second fake player without the trait; assert the key is not written.
  2. A test simulating game-load to confirm the modifier is re-applied if an `OnLoad` hook is added.
  3. An integration test (in-game or mock) that verifies a downstream system reads `UT_sleepQualMod` and reduces fatigue accumulation or increases fatigue recovery rate by the stated percentage.

## Final Verdict
- Source origin: faithful name and cost port from `ToadTraits:restfulsleeper` (More Traits). The UT version is a substantial scope reduction: the source provides three runtime effects (tiered per-tick fatigue drain, auto-wake on full rest, bad-surface immunity), all implemented via per-tick callbacks. The UT version provides only a ModData write of `UT_sleepQualMod = 0.5` on new game.
- UT implementation: incomplete — the `OnNewGame` hook writes `UT_sleepQualMod = 0.5`, but no `OnLoad` hook exists to restore the value after a save/load cycle, and no downstream consumer of `UT_sleepQualMod` is evidenced in the files reviewed. The described "+50% sleep quality" effect may not be delivered to the player in practice.
- Description: narrower but not false — the "+50% sleep quality" claim is consistent with the ModData write. However, the description is overstated if no consumer reads the flag, and misleading for save/load sessions if no OnLoad hook exists. The three additional behaviors from the source (auto-wake, bad-surface immunity, tiered drain) are silently dropped without disclosure.
- Balance: plausible at 6 points if fully implemented and persistent — but unresolvable until the consumer and persistence are confirmed.
- Regression proof: partially protected (registration confirmed; runtime behavior and persistence unproven)
- Action needed: implementation verification + fix
- Open gaps:
  - No `OnLoad` / `OnGameBoot` hook exists to re-apply `UT_sleepQualMod` after loading a save. Likely regression for any save-and-continue session.
  - No downstream consumer of `UT_sleepQualMod` was found. The actual sleep quality increase may not be wired into game systems.
  - The source mutual exclusion with `base:insomniac` was not carried into UT. Combining Restful Sleeper with the vanilla Insomniac trait is logically incoherent and produces undefined interaction behavior.
  - Source `DisabledInMultiplayer` was `false`; UT sets it `true`. This is a deliberate divergence but is undisclosed.
  - Three source effects (tiered per-tick fatigue drain, auto-wake, bad-surface immunity) are entirely absent from the UT implementation. If the `UT_sleepQualMod` consumer is eventually wired, consider whether these additional effects should be incorporated at the stated cost of 6 points.
  - No behavioral unit test for the `onNewGame` handler or for any consumer that applies the modifier.
