# UT_luddite

## Trait Summary

- UT trait id: UT_luddite
- Source mod: SomewhatTraits (SomewhatTraitsCore)
- Source trait id: SWTraits:SWLuddite (trait key: "SWLuddite")
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/scripts/SWTraits_character_traits.txt`
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua`
- Source display name: "Luddite"
- Source description: "Equipping guns causes stress, based on Aiming lvl."
- Source cost: -4
- Source multiplayer: `DisabledInMultiplayer = false` (allowed in multiplayer in the original)
- Source trigger path: `Events.OnTick.Add(SWLuddite)` — fires every game tick.
- Source behavior: When the player's primary hand item is a ranged weapon, adds stress per tick equal to `timeMultiplier * (11 - perkLevel) * 0.005`, where `perkLevel` is `Perks.Aiming`. Stress does not exceed `maxStress`. The stress gain decreases as Aiming level increases (at Aiming 10, the multiplier is 1; at Aiming 0, it is 11). This is a purely stress-based mechanic — no XP reduction of any kind.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — `UTTraitsRegistries.UT_luddite = CharacterTrait.register("UniversalTraits:UT_luddite")` (line 201)
- Defined in UT_character_traits.txt: yes — lines 1419–1427
- Translation strings present: yes — `UI_UT_luddite` and `UI_UT_ludditeDesc` at lines 434–435
- Exclusions/grants: none declared in the script definition
- Runtime Lua file exists: yes
- DisabledInMultiplayer: `true` in UT vs. `false` in source — UT is more restrictive

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_luddite.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1419–1427)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 434–435)
  - `test/run_tests.lua` (line 265)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — trait check
  - `UTCore.applyXPMultiplier(player, "Electricity", 0.6)` — applies ×0.6 multiplier to Electrical XP
- Runtime chain (plain language):
  1. On new game: if the player has the trait, calls `UTCore.applyXPMultiplier(player, "Electricity", 0.6)`.
  2. No other events are registered. No per-tick or per-update logic exists.
- Actual behavior (exact values):
  - On game start: Electrical XP gain is permanently multiplied by ×0.6 (−40%).
  - No stress effect. No aiming interaction. No ranged weapon detection.

## Description Integrity

- Display name check: "Luddite" — matches source name exactly.
- Description check: `UI_UT_ludditeDesc` reads: "Technology has always been your enemy. XP gain in Electrical is reduced to ×0.6 (−40%)."
- Description accuracy vs. UT implementation: the description accurately describes exactly what the UT Lua code does — Electrical XP at ×0.6. No misleading claims in the description itself.
- Source divergence: the UT implementation is a complete mechanical redesign relative to the source. The source trait (SWLuddite) applies stress when holding a ranged weapon, scaling with Aiming level — there is no XP reduction of any kind in the source. The UT version applies a static Electrical XP penalty and has no stress or ranged-weapon mechanic. The description does not acknowledge or reference the source mechanic in any way; it describes the UT mechanic correctly on its own terms.
- Missing details: none — the description is self-consistent with the code. No hidden interactions, no Aiming/stress mechanic to disclose, no suppression condition.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside:
  - Electrical XP gain permanently reduced to ×0.6 (−40%) from game start.
  - Applies to all Electrical XP earned throughout the run — no conditional trigger, no mitigation path once taken.
- Uptime: 100% — always active, no player action can suspend or bypass it.
- Peer comparison:
  - `UT_antigun` (−6): reduces Aiming and Reloading XP to ×0.5 (−50%) across two skills. Comparable structure, higher penalty, higher cost.
  - `UT_flatearther` (−4): reduces MetaGame XP to ×0.7 (−30%) and reading speed by 30%. Same cost, dual-penalty, but MetaGame XP is a lower-priority skill for most players.
  - `UT_luddite` (−4): single skill (Electrical) at ×0.6 (−40%). Electrical is a non-combat, mid-tier skill — useful for generator repair and some crafting, but not survival-critical in early game. The −4 cost is in the same tier as UT_flatearther, which penalizes a similarly niche skill. The cost is reasonable but slightly generous — Electrical is arguably more impactful than MetaGame, though both are non-combat.
- Stack or exclusion notes: no mutual exclusions declared. Can stack with other XP penalty traits freely. Stacking UT_luddite with any future Electrical-affecting trait would be unchecked.
- Cost verdict: reasonable — −4 for a permanent single-skill XP penalty of −40% is consistent with peer pricing in the XP penalty series.

## Regression Proof

- Existing test: `UT_luddite` appears in the Phase 2 XP Penalties registration list at `run_tests.lua` line 265. This list is used by the harness to verify that all expected traits are registered and loadable.
- What it proves: the trait ID is present in the registry and the harness can resolve it without error. Confirms the trait does not cause a load-time crash.
- Missing proof:
  1. No functional test for the `onNewGame` handler — no test verifies that `UTCore.applyXPMultiplier` is called with `"Electricity"` and `0.6` when the trait is present.
  2. No test that the handler exits cleanly when the player does not have the trait (guard path).
  3. No test confirming that a player without the trait receives no multiplier change.
- Minimum next test if needed: "luddite: applies Electricity XP multiplier on new game" — create a MockNewGamePlayer with the trait present, fire `Events.OnNewGame`, assert that `UTCore.applyXPMultiplier` was called with `("Electricity", 0.6)`. Mirror with a player lacking the trait to confirm the guard fires correctly.

## Final Verdict

- Source origin: proven — SomewhatTraits `SWLuddite` is the confirmed source; source Lua and script files located and read.
- UT implementation: redesigned — the UT port does not port the source mechanic (stress when holding ranged weapons, scaled by Aiming level). Instead it implements a static Electrical XP penalty (×0.6). The display name and cost (−4) are preserved from the source; everything else is new. This is a deliberate redesign, not a drift or bug.
- Description: accurate — the description correctly and completely describes the UT implementation. It does not reference the abandoned stress mechanic and does not make any claims that the code does not fulfill.
- Balance: reasonable — −4 for a permanent −40% single-skill XP penalty is consistent with peer traits in the XP penalty series. No mechanical concerns.
- Multiplayer flag: diverges from source — source allows multiplayer (`DisabledInMultiplayer = false`); UT disables it (`DisabledInMultiplayer = true`). The UT flag is the more conservative choice and is consistent with the rest of the XP penalty series in UT. No action required unless multiplayer support is a goal.
- Regression proof: minimal — only a registration-list check exists. The `onNewGame` application path is untested.
- Action needed: test fix only — add a functional test for the `onNewGame` handler confirming the XP multiplier is applied when the trait is present and skipped when absent. No code or description changes required.
- Open gaps:
  - Confirm whether the redesign away from the stress mechanic was intentional or accidental. The source mechanic (ranged weapon stress by Aiming level) would have been a richer implementation; if intentional, the rationale should be recorded.
  - No mutual exclusion is declared. Consider whether UT_luddite should exclude any future Electrical-boosting trait once one exists.
