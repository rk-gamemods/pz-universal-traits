# UT_superimmune

## Trait Summary

- UT trait id: UT_superimmune
- Source mod: MoreTraits (ToadTraits)
- Source trait id: ToadTraits:superimmune
- Current cost: 8
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (script definition, Cost = 10, lines 961–971)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/media/sandbox-options.txt` (Dynamic submod sandbox options, lines 814–828)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/media/lua/client/MoreTraits - Dynamic.lua` (Dynamic submod client runtime, lines 744–755)
  - `research/installed-mods/EvolvingTraitsWorld/mods/Evolving Traits World - Mark Dynamic Traits/media/lua/shared/NPCs/ETWSubmodCreationMethods.lua` (ETW alt-name registration, line 126)
- Source script definition (ToadTraits:superimmune, 42.15):
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = false`
  - `CharacterTrait = ToadTraits:superimmune`
  - `Cost = 10`
  - `UIName = UI_trait_superimmune`
  - `UIDescription = UI_trait_superimmunedesc`
  - `MutuallyExclusiveTraits = ToadTraits:immunocompromised;base:pronetoillness;base:resilient`
- Source behavior (base More Traits mod): the base trait definition carries no Lua runtime of its own; the core effect is passive and declared in the script block only. No `infectionLevel` manipulation was found in the base mod's Lua files.
- Source behavior (More Traits - Dynamic submod): the Dynamic submod adds a sandbox-configurable dynamic acquisition path (`SuperImmuneDynamic`). When enabled, it tracks total time the player's wounds have been infected across body parts (in 10-minute ticks, counting hours). When accumulated infection-hours reach the configured threshold (`SuperImmuneDynamicInfectionTime`), the trait `superimmune` is added to the player via `player:getTraits():add("superimmune")`. This is a dynamic-unlocking mechanic, not an active per-tick gameplay effect on infectionLevel.
- Source behavior (ETW): `altNames.superimmune = true` — the Evolving Traits World mod registers `superimmune` as a recognized alternate trait name for NPC trait handling. No additional gameplay effect.
- Source description (EN): not directly confirmed from source EN files in this grep pass; source script refers to `UI_trait_superimmuneDesc` key.
- Source cost: 10 (ToadTraits:superimmune, 42.15); no costs from Dynamic submod (that submod does not redefine the cost).
- Source multiplayer flag: `DisabledInMultiplayer = false` in source script definition.

## Current UT Evidence

### Structure

- Registered in registries.lua: confirmed — `run_tests.lua` line 112–113 asserts `UTTraitsRegistries.UT_superimmune == "UniversalTraits:UT_superimmune"`
- Defined in UT_character_traits.txt: yes — lines 2071–2080
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_superimmune`
  - `Cost = 8`
  - `UIName = UI_UT_superimmune`
  - `UIDescription = UI_UT_superimmuneDesc`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_immunocompromised`
- Translation strings present: yes
  - `UI_UT_superimmune = "Super Immune"` (UI_EN.txt line 641)
  - `UI_UT_superimmuneDesc = "Your immune system is exceptional. Infections that would lay others low barely register with your body."` (UI_EN.txt line 642)
- Mutual exclusion defined: yes — `UniversalTraits:UT_immunocompromised` only. Source also excluded `base:pronetoillness` and `base:resilient`; UT drops those two base-game exclusions.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_superimmune.lua`

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_superimmune.lua`
  - `media/scripts/UT_character_traits.txt` (lines 2071–2080)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 641–642)
  - `test/run_tests.lua` (lines 112–114, 304, 471, 1108–1117)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)`
  - `Events.EveryOneMinute.Add(onEveryOneMinute)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` — standard guard in both handlers
- Runtime chain (plain language):
  1. On new game, `onNewGame` fires with the new player object; if the player has the trait, sets `player:getModData()["UT_superimmune"] = true`.
  2. Every in-game minute, `onEveryOneMinute` fires.
  3. Gets the local player via `getPlayer()`; exits if no player.
  4. Checks if the player has `UniversalTraits:UT_superimmune` via `UTCore.hasTrait`; exits if not.
  5. Gets `player:getBodyDamage()`; if bodyDamage is non-nil and `getInfectionLevel()` is non-nil and greater than 0, sets infectionLevel to `math.max(0, infectionLevel - 0.02)`.
- Actual behavior (exact values):
  - ModData flag: `player:getModData()["UT_superimmune"] = true` stamped once on new game.
  - Infection reduction: −0.02 infectionLevel per in-game minute while infectionLevel > 0; floors at 0 (never goes negative).
  - No other stats are modified.
  - No fatigue, endurance, or Sickness moodle effects.
  - The infection drain fires at `EveryOneMinute` (6× more frequently than the `EveryTenMinutes` used by `UT_immuneresponse`); at infectionLevel = 1.0, infection reaches 0 after ~50 minutes of in-game time.

## Description Integrity

- Display name check: "Super Immune" — reasonable match to concept; source used "superimmune" (single word in trait ID).
- Description check (full text): "Your immune system is exceptional. Infections that would lay others low barely register with your body."
- Accuracy of description:
  - "Infections that would lay others low barely register" — directionally accurate; the trait actively drains infectionLevel by 0.02 per in-game minute, meaning the infection clears faster than it would without the trait.
  - The description implies a general resistance to infection, which aligns with the implemented mechanic.
  - No quantitative information is given (−0.02 per minute, reaching 0 from 1.0 in ~50 in-game minutes).
  - The description does not mention the modData flag (`UT_superimmune = true`), but this flag has no visible in-game effect beyond being a marker — omitting it from the description is acceptable.
- Missing or misleading details:
  - No mention of the drain rate or how quickly infections clear; the vagueness is acceptable for flavor but players cannot gauge the magnitude of the effect.
  - The description does not distinguish between zombie bite infection (which is always lethal in default settings) and wound bacteria infection (which UT's infectionLevel system targets); "infections" is ambiguous.

## Balance Review

- Upside: −0.02 infectionLevel per in-game minute while infectionLevel > 0; this drains a full infectionLevel of 1.0 to 0 in approximately 50 in-game minutes. Compared to `UT_immuneresponse` (−0.03 per ten in-game minutes, or 0.003 per in-game minute equivalent), `UT_superimmune` drains at ~6.7× the rate per real unit time at the same tick interval. This is a very powerful infection-clearing effect.
- Downside: none (positive trait with no penalty)
- Uptime: gated on infectionLevel > 0; inactive when healthy. The `EveryOneMinute` tick is always registered, but the drain itself only applies when infection is present.
- Magnitude assessment:
  - The drain rate of −0.02/minute is aggressive. Bacterial wound infection without traits rises slowly over many in-game hours; at −0.02/minute the trait effectively neutralizes almost any wound infection within less than an in-game hour regardless of how severe it becomes. This makes bacterial wound infection nearly irrelevant as a threat.
  - The trait costs 8 points. The source (ToadTraits) priced the base concept at 10 points with broader mutual exclusions and no active Lua drain — UT adds an explicit per-minute drain that the source never implemented in the base mod. Getting a more powerful mechanical implementation at a lower cost (8 vs. 10) is a favorable divergence for the player.
- Peer comparison:
  - `UT_immunocompromised` (Cost = −6, mutually exclusive with `UT_superimmune`) — the explicit counterpart.
  - `UT_immuneresponse` (Cost = 6, no mutual exclusion with `UT_superimmune`) — drains at −0.03 per ten in-game minutes (effectively −0.003/min), ~6.7× slower. A player can combine `UT_immuneresponse` and `UT_superimmune` for stacked infection drain (−0.023/min effective) since no exclusion prevents it. Whether this combination is intended is a design gap (noted in `UT_immuneresponse` audit; confirmed here from the other direction).
- Source cost vs. UT cost: source priced at 10 (no active Lua drain); UT at 8 (with active Lua drain added). UT is cheaper for a materially stronger implementation. Whether the cost reduction is intentional is unclear.
- Multiplayer flag: source had `DisabledInMultiplayer = false`; UT has `DisabledInMultiplayer = true`. The UT runtime uses `getPlayer()` (single-player API), so the multiplayer disable is mechanically necessary for correctness given the current implementation.
- Source mutual exclusions dropped: source excluded `base:pronetoillness` and `base:resilient` in addition to `immunocompromised`. UT drops those two base-game exclusions. A player with `base:resilient` (which gives vanilla infection resistance) could combine it with `UT_superimmune` (which provides an active drain on top), a combination the source author explicitly blocked.

## Regression Proof

- Existing tests:
  - `run_tests.lua` lines 112–114: named registration test — "UT_superimmune registered"; asserts `UTTraitsRegistries.UT_superimmune == "UniversalTraits:UT_superimmune"`. Proves the trait ID is in the registry.
  - `run_tests.lua` line 304: lists `"UniversalTraits:UT_superimmune"` in the Phase 3c — Event-Driven batch array used by the all-198-traits registration test. Confirms the trait is expected in the global registration sweep.
  - `run_tests.lua` line 471: `dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_superimmune.lua")` — confirms the Lua file loads without parse error.
  - `run_tests.lua` lines 1108–1117: named behavioral test — "superimmune marks the trait and reduces infection over time"
    - Calls `fireNewGame("UniversalTraits:UT_superimmune")` to construct a player with the trait and fire `OnNewGame`.
    - Sets `player:getBodyDamage():setInfectionLevel(0.5)`.
    - Calls `withActivePlayer(player, function() Events.EveryOneMinute:fire() end)`.
    - Asserts `player:getModData()["UT_superimmune"] == true` — confirms the modData flag is set by `onNewGame`.
    - Asserts `math.abs(player:getBodyDamage():getInfectionLevel() - 0.48) < 0.0001` — confirms the drain of −0.02 per fire is correct.
- What it proves: the modData flag is stamped on new game; the per-minute drain of −0.02 is arithmetically correct for a single fire with infectionLevel = 0.5.
- Missing proof:
  - No test verifies that the infectionLevel drain stops at 0 (floor behavior) — e.g., infectionLevel = 0.01 should produce 0, not a negative value.
  - No test verifies the `> 0` guard: when infectionLevel is exactly 0 on `EveryOneMinute`, the drain should not fire and infectionLevel should remain 0.
  - No test verifies the nil guard on `getInfectionLevel()`.
  - No test verifies that the handler exits cleanly when the player does not have the trait (infectionLevel unchanged).
  - No test verifies behavior when `getBodyDamage()` returns nil.
  - No test exercises multiple consecutive `EveryOneMinute` fires to confirm the drain accumulates correctly over time (integration-style test).
- Minimum next tests if needed:
  1. MockPlayer with `UT_superimmune`, `infectionLevel = 0.01`, fire `EveryOneMinute`; assert infectionLevel equals 0 (floor check).
  2. MockPlayer with `UT_superimmune`, `infectionLevel = 0`, fire `EveryOneMinute`; assert infectionLevel remains 0 (zero guard).
  3. MockPlayer without `UT_superimmune`, `infectionLevel = 0.5`, fire `EveryOneMinute`; assert infectionLevel unchanged at 0.5 (no-trait guard).

## Final Verdict

- Source origin: proven — ToadTraits:superimmune confirmed in script definition (42.15 ToadTraits.txt, lines 961–971). The base MoreTraits mod defines the trait as a passive script-declared trait with no active Lua infectionLevel drain; UT adds an explicit per-minute drain that is not present in the source.
- UT implementation: mechanically extended beyond source — source declared the trait passively (script block only, no active runtime drain); UT adds `Events.EveryOneMinute` with −0.02/min infectionLevel drain, a genuine new mechanism layered on top of the concept. The modData flag added by `OnNewGame` has no gameplay effect but is present and tested.
- Description: directionally accurate but vague — "infections barely register" is a fair high-level summary of the drain effect. The description omits quantitative detail and does not clarify whether the effect targets bacterial wound infection or zombie virus infection. No false claims are made. No hidden mechanics exist beyond the one the description alludes to.
- Balance: arguably underpriced given the mechanical power added — the source cost 10 with no active drain; UT costs 8 with an aggressive −0.02/min active drain. The combination with `UT_immuneresponse` (no mutual exclusion blocking it) stacks two infection-drain traits. The dropped source exclusions against `base:pronetoillness` and `base:resilient` allow further stacking with vanilla immune traits.
- Regression proof: partially protected — the core arithmetic path (modData flag + single drain fire) is covered. Floor behavior, zero-infection guard, no-trait guard, and nil-bodyDamage guard are untested.
- Action needed: design gap review + test additions
- Open gaps:
  - Decide whether `base:pronetoillness` and `base:resilient` should be added back to `MutuallyExclusiveTraits` to match source intent and prevent stacking with vanilla immune traits.
  - Decide whether `UniversalTraits:UT_immuneresponse` should be added to `MutuallyExclusiveTraits` to prevent dual-drain stacking, or document why the combination is acceptable.
  - Consider whether the cost (8) is correct given the power of the active drain; the source priced the passive concept at 10.
  - Add behavioral tests for floor behavior (infectionLevel → 0), zero-infection guard, and no-trait guard.
  - Optionally: clarify the description to distinguish bacterial wound infection from zombie virus infection, since the mechanic targets `bodyDamage:getInfectionLevel()` (bacterial) not the zombie virus infection system.
