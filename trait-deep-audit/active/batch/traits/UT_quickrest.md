# UT_quickrest

## Trait Summary
- UT trait id: UT_quickrest
- Source mod: More Traits (ToadTraits) — `ToadTraits:quickrest`
- Source trait id: `ToadTraits:quickrest` (script-block ID in ToadTraits.txt)
- Current cost: 3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (lines 789–797)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua` (line 91)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (lines 212–214)
  - `research/installed-mods/MoreTraits/mods/More Traits/42/media/lua/client/MoreTraits .lua` (lines 4182–4197, 4496, 4519–4520)
- Source trait definition (ToadTraits.txt lines 789–797):
  ```
  character_trait_definition ToadTraits:quickrest
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = false,
      CharacterTrait = ToadTraits:quickrest,
      Cost = 3,
      UIName = UI_trait_quickrest,
      UIDescription = UI_trait_quickrestdesc,
  }
  ```
- Source registry (registries.lua line 91):
  ```lua
  ToadTraitsRegistries.quickrest = CharacterTrait.register("ToadTraits:quickrest")
  ```
- Source translation (UI_EN.txt lines 212–214):
  - `UI_trait_quickrest = "Quick Rest"`
  - `UI_trait_quickrestdesc = "Your endurance recovery while sitting is doubled.<br>You are informed if your endurance is max while sitting."`
  - `UI_quickrestfullendurance = "Your endurance is full"` (halo text string)
- Source runtime (`MoreTraits .lua` B42 client, `QuickRest` function, lines 4182–4197):
  - The function is called every update tick.
  - It checks `player:HasTrait("quickrest")`.
  - If the player is seated (`player:isSitOnGround()` — inferred from state machine), it tracks the current endurance value in `playerdata.QuickRestEndurance`. The exact per-tick endurance boost mechanism is managed through `playerdata.QuickRestActive`; the function monitors rising endurance while sitting and triggers a state flip when endurance reaches 1.0.
  - When `QuickRestActive == true` and `player:getStats():getEndurance() == 1`, the `QuickRestFinished` flag is set to `true`.
  - When `QuickRestFinished == true` and the player is no longer sitting, all state is reset.
  - On completion (`QuickRestFinished == true`, line 4519–4520): `HaloTextHelper.addText(player, getText("UI_quickrestfullendurance"), "", HaloTextHelper.getColorGreen())` — the green "Your endurance is full" notification fires.
  - The actual endurance doubling mechanism is not a direct per-tick stat write visible in the grep output; the `QuickRestEndurance` tracking and `QuickRestActive` flag gate the halo notification. The source description states endurance recovery is doubled while sitting — the B42 client source uses the state machine pattern consistent with that effect.
- Source cost: 3 — matches UT.
- Source `DisabledInMultiplayer`: `false` — UT diverges to `true`.
- Source behavior summary: The MoreTraits `quickrest` is a per-tick, condition-gated trait: it activates while the player is seated, monitors endurance recovery, and fires a HUD notification when endurance reaches full. The doubled endurance recovery while sitting is the stated primary effect. The UT rewrite replaces this entirely with a single ModData write.

## Current UT Evidence

### Structure
- Registered in `media/registries.lua`: confirmed present in the Sleep & Rest phase block (verified via `run_tests.lua` expected_ids, which mirrors the registries block).
- Registered in `run_tests.lua` expected_ids: yes — line 257, Phase 2 — Sleep & Rest block
  ```lua
  "UniversalTraits:UT_restfulsleeper", "UniversalTraits:UT_quickrest",
  ```
- Defined in `UT_character_traits.txt`: yes (lines 1325–1333)
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_quickrest`
  - `Cost = 3`
  - `UIName = UI_UT_quickrest`
  - `UIDescription = UI_UT_quickrestDesc`
- MutuallyExclusiveTraits: none defined (source had none)
- GrantedTraits: none defined
- Translation strings present: yes (UI_EN.txt lines 401–402)
  - `UI_UT_quickrest = "Quick Rest"`
  - `UI_UT_quickrestDesc = "Your body bounces back from exhaustion fast. Sleep quality is increased by +30%."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_quickrest.lua`)

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_quickrest.lua`
  - `test/UTTestMocks.lua` (mock definition of `UTCore.applySleepQuality`, line 218)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` (production definition of `UTCore.applySleepQuality`, lines 65–68)
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` and `UTCore.applySleepQuality(player, 0.3)`
- Mock definition of `applySleepQuality` (UTTestMocks.lua line 218):
  ```lua
  UTCore.applySleepQuality = function(player, v) player:getModData()["UT_sleepQualMod"] = v end
  ```
- Production definition (UTCore_StatModifiers.lua lines 65–68):
  ```lua
  -- Stores "UT_sleepQualMod" = delta in moddata.
  function UTCore.applySleepQuality(player, delta)
      player:getModData()["UT_sleepQualMod"] = delta
  end
  ```
- Runtime chain (plain language):
  1. `Events.OnNewGame` fires once when a new game session starts.
  2. `UTCore.hasTrait` checks whether the player has `UniversalTraits:UT_quickrest`. If not, the handler returns immediately.
  3. If the trait is present, `UTCore.applySleepQuality(player, 0.3)` is called, which writes `player:getModData()["UT_sleepQualMod"] = 0.3`.
- Actual behavior (exact values):
  - Sets ModData key `UT_sleepQualMod` to `0.3` on new game if the trait is active.
  - The value `0.3` represents a +30% sleep quality modifier, as described in the UT translation.
  - **Critical gap**: The runtime only hooks `Events.OnNewGame`. There is no `OnLoad` / `OnGameBoot` hook to restore `UT_sleepQualMod` when loading an existing save. Any player who selects the trait, saves, and reloads will not have the flag re-applied.
  - **Critical gap**: No event handler in this file or in any other reviewed file consumes `UT_sleepQualMod` and applies it to the game's sleep or fatigue systems at runtime. The script only writes a ModData value; whether a downstream consumer reads and acts on it is not evidenced in the files available.
  - **Scope divergence vs. source**: The MoreTraits source implements endurance doubling while seated plus a HUD notification on full endurance, driven by per-tick callbacks. The UT version collapses the entire trait to a single ModData write of `UT_sleepQualMod = 0.3` on new game. The seated endurance doubling and the full-endurance notification behaviors are both absent.
  - **Semantic mismatch vs. source**: The source trait affects endurance recovery while sitting (a waking stamina mechanic). The UT description re-frames it as a sleep quality modifier ("Your body bounces back from exhaustion fast. Sleep quality is increased by +30%"), which is a different in-game system than the source's seated endurance mechanic. This is not a faithful port — it is a re-design of what the trait does.

## Description Integrity
- Display name check: "Quick Rest" — exact match to source name. No renaming concern.
- Description check: "Your body bounces back from exhaustion fast. Sleep quality is increased by +30%."
  - The "+30%" figure is consistent with the ModData write of `0.3` to `UT_sleepQualMod`. The number is internally coherent.
  - However, the description describes a *sleep quality* benefit ("bounces back from exhaustion fast" / "Sleep quality is increased"), while the source trait affects *seated endurance recovery* (a stamina mechanic active while awake and sitting). These are different game systems.
  - The UT description does not mention sitting, endurance, or waking activity recovery at all.
  - If `UT_sleepQualMod` is eventually wired to a sleep/fatigue consumer (consistent with the `UT_restfulsleeper` cluster pattern), the description would describe the UT implementation accurately — but would still not describe the source behavior.
- Missing or misleading details:
  - The description does not disclose that the effect only applies on new game start, not after loading a save.
  - The description does not clarify which system reads `UT_sleepQualMod`; if no consumer is implemented, the description is undeliverable.
  - No mention of `DisabledInMultiplayer = true`, consistent with other UT traits.
  - The source's seated endurance doubling and full-endurance HUD notification are entirely absent from the UT description, which is a deliberate scope change but silently drops the source's signature gameplay loop.

## Balance Review
- Upside: A +30% sleep quality modifier accelerates fatigue recovery during rest, shortening required sleep time. This is a passive quality-of-life benefit.
- Downside: None — pure positive trait with no stated drawback.
- Uptime: Intended as always-on after new game start; persistence across saves unconfirmed (see implementation gaps).
- Peer comparison within Sleep & Rest cluster:
  - `UT_restfulsleeper` (cost 6): +50% sleep quality via `applySleepQuality(player, 0.5)` — same mechanic, higher magnitude. Cost 6 is double the cost of `UT_quickrest` for +50% vs. +30%. The cost-to-benefit ratio within the cluster is coherent: `UT_quickrest` is the budget option.
  - `UT_snorer` (cost -2): negative sleep-related trait. Functions as the counterpart on the penalty side.
  - At cost 3, `UT_quickrest` is priced as the entry-level sleep trait. The 3-point cost for a +30% modifier is reasonable if the modifier is functional and persistent.
- Source cost: 3 — matches exactly.
- Stack or exclusion notes: No `MutuallyExclusiveTraits` defined in UT, and none were defined in the source. The source had no exclusion with `base:insomniac` either, unlike `ToadTraits:restfulsleeper`. In UT, both `UT_quickrest` and `UT_restfulsleeper` use the same ModData key (`UT_sleepQualMod`); if a player somehow takes both, the second `applySleepQuality` call would overwrite the first (last-registered wins), silently discarding one trait's effect. No mutual exclusion between the two UT sleep traits is defined.
- Cost verdict: 3 points is proportionate for a +30% sleep quality boost if the effect is fully functional and persistent. If implementation gaps prevent the effect from delivering (no consumer, or no OnLoad hook), the trait is a complete point sink with no delivered benefit.

## Regression Proof
- Existing test: `run_tests.lua` includes `"UniversalTraits:UT_quickrest"` in the `expected_ids` array (line 257, Phase 2 — Sleep & Rest block). The test verifies registration only — it confirms the trait ID is present in `CharacterTrait._registered` and that the string matches the definition block.
- What it proves: Trait ID correctly registered. Definition block, translation keys, and Lua file are all present and structurally consistent.
- Missing proof: No behavioral test exists. There is no test verifying:
  - That `onNewGame` correctly calls `UTCore.applySleepQuality` with `0.3` when the trait is present.
  - That the flag is not written when the trait is absent.
  - That `UT_sleepQualMod` is restored after a game load (an `OnLoad` hook test would be required).
  - That any downstream system reads `UT_sleepQualMod` and applies a +30% modifier to sleep/fatigue recovery.
  - That `UT_quickrest` and `UT_restfulsleeper` do not silently overwrite each other's `UT_sleepQualMod` when both are active.
- Minimum next tests if needed:
  1. Mock-based unit test for `onNewGame`: provide a fake player with the trait present; assert `modData["UT_sleepQualMod"] == 0.3` after the call. Provide a second fake player without the trait; assert the key is not written.
  2. A test simulating game-load to confirm the modifier is re-applied if an `OnLoad` hook is added.
  3. A stacking/overwrite test: player has both `UT_quickrest` and `UT_restfulsleeper`; assert final `UT_sleepQualMod` value and document which trait wins.
  4. An integration test (in-game or mock) verifying that a downstream system reads `UT_sleepQualMod` and reduces fatigue accumulation or increases fatigue recovery rate by the stated percentage.

## Final Verdict
- Source origin: name and cost match `ToadTraits:quickrest` (More Traits). The UT version is both a scope reduction and a semantic redesign: the source provides a waking, seated endurance-doubling mechanic with a HUD notification, implemented via per-tick callbacks. The UT version provides only a ModData write of `UT_sleepQualMod = 0.3` on new game, which is classified as a sleep quality modifier rather than an endurance modifier.
- UT implementation: incomplete — the `OnNewGame` hook writes `UT_sleepQualMod = 0.3`, but no `OnLoad` hook exists to restore the value after a save/load cycle, and no downstream consumer of `UT_sleepQualMod` is evidenced in the files reviewed. The stated "+30% sleep quality" effect may not be delivered to the player in practice.
- Description: internally consistent but semantically misaligned with the source — the "+30%" figure matches the ModData write, but the description reframes the trait as a sleep quality trait when the source was a seated endurance/stamina trait. The description is accurate to the UT design intent only if a `UT_sleepQualMod` consumer is wired.
- Balance: plausible at 3 points if fully implemented and persistent. Stacking risk with `UT_restfulsleeper` via shared `UT_sleepQualMod` key is an unguarded edge case.
- Regression proof: partially protected (registration confirmed; runtime behavior and persistence unproven)
- Action needed: implementation verification + fix
- Open gaps:
  - No `OnLoad` / `OnGameBoot` hook exists to re-apply `UT_sleepQualMod` after loading a save. Likely regression for any save-and-continue session.
  - No downstream consumer of `UT_sleepQualMod` was found. The actual sleep quality or fatigue benefit may not be wired into game systems.
  - Both `UT_quickrest` (0.3) and `UT_restfulsleeper` (0.5) write to the same `UT_sleepQualMod` key. If a player selects both traits, the second `OnNewGame` handler to fire overwrites the first, silently discarding one trait's effect. A mutual exclusion or additive-accumulation strategy is needed.
  - Source `DisabledInMultiplayer` was `false`; UT sets it `true`. This is a deliberate divergence but is undisclosed to the player.
  - The source's core mechanic (seated endurance doubling while awake, HUD notification on full endurance) is entirely absent. If the UT sleep-quality framing is retained, the trait's identity departs from its source inspiration. If the endurance-while-sitting mechanic is the preferred direction, the Lua, description, and ModData key would all need replacement.
  - No behavioral unit test for the `onNewGame` handler or for any consumer that applies the modifier.
