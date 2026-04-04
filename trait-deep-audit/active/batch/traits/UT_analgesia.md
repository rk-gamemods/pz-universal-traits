# UT_analgesia

## Trait Summary
- UT trait id: UT_analgesia
- Source mod: FillerTraits (UpgradeTraits)
- Source trait id: Analgesia (TraitFactory, no namespace prefix)
- Current cost: 12
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/FillerTraits/mods/FillerTraits/media/lua/shared/NPCs/UpgradeMainCreationMethods.lua` (trait registration, line 6)
  - `research/installed-mods/FillerTraits/mods/FillerTraits/media/lua/client/UpgradeTraits.lua` (runtime implementation, lines 118–127, 146)
  - `research/installed-mods/FillerTraits/mods/FillerTraits/common/lua/shared/NPCs/UpgradeMainCreationMethods.lua` (common copy, trait registration, line 7)
  - `research/installed-mods/FillerTraits/mods/FillerTraits/common/lua/client/UpgradeTraits.lua` (common copy, runtime implementation, lines 207–216, 236)
- Source registration:
  - `TraitFactory.addTrait("Analgesia", getText("Analgesia"), 8, getText("Does not reach states of physical pain."), false, false)`
  - `TraitFactory.setMutualExclusive("Analgesia", "Fibromyalgia")`
- Source trigger path: `Events.OnPlayerUpdate.Add(Analgesia)` fires the `Analgesia()` function on every player update tick.
- Source behavior: Each tick, the function calls `getPlayer()`, retrieves `player:getStats()`, then checks `player:HasTrait("Analgesia")`. If true, it calls `stats:setPain(0)`, zeroing the player's pain stat every update. This is a continuous suppression loop — pain is reset to zero on every game tick as long as the player has the trait. The source cost was 8 points. The source mutual exclusion was with "Fibromyalgia" (the pain-amplification counterpart trait), not with "GlassBody"/"glassbody".

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — `run_tests.lua` line 84 confirms `UTTraitsRegistries.UT_analgesia == "UniversalTraits:UT_analgesia"`; also appears in the expected_ids list at line 252
- Defined in UT_character_traits.txt: yes — lines 1269–1278
- Translation strings present: yes — `UI_UT_analgesia = "Analgesia"` and `UI_UT_analgesiaDesc = "You feel no pain. All pain is permanently suppressed regardless of injuries."`
- Exclusions/grants correct: partially — mutually exclusive with `UniversalTraits:UT_glassbody` (bidirectional, confirmed in both definitions). Source exclusion was with "Fibromyalgia"; UT has no "Fibromyalgia" equivalent, so the exclusion pivot to `UT_glassbody` is a deliberate design decision (thematic: glass body / pain immunity are conceptual opposites).
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_analgesia.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1269–1278)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 380–381)
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait`
- Runtime chain (plain language):
  1. On new game start, `onNewGame` fires.
  2. If the player has `UniversalTraits:UT_analgesia`, the function writes `player:getModData()["UT_painImmune"] = true` into the player's mod data.
  3. No further events are registered. The trait does not hook `OnPlayerUpdate` or any other recurring event.
- Actual behavior (exact values): Sets `UT_painImmune = true` in player mod data. One-shot write on new game start only. No continuous pain suppression loop. No call to `stats:setPain(0)`. The trait is entirely passive and depends on an external consuming system to read `UT_painImmune` and suppress pain each tick.

## Description Integrity
- Display name check: "Analgesia" — identical to source name. No issue.
- Description check: "You feel no pain. All pain is permanently suppressed regardless of injuries." — the word "permanently" and "suppressed" imply continuous active zeroing. The UT implementation does not continuously suppress pain; it writes a flag once at new-game start. Whether pain is actually suppressed depends entirely on whether a consuming system reads `UT_painImmune` each tick and calls `setPain(0)` or equivalent. If that consuming system is absent or not loaded, the description is false.
- Missing or misleading details:
  - The description does not disclose that the flag is written only once at new-game start and will not be present on characters loaded from a save after a restart unless the flag is already persisted in mod data.
  - The description does not warn that active pain suppression is conditional on a downstream system reading the flag.
  - The source implemented active suppression via `OnPlayerUpdate`; UT delegates this entirely to a consumer, which may or may not exist. This architectural divergence is invisible to the player.

## Balance Review
- Upside: complete pain immunity — all pain from any source is permanently suppressed (subject to consuming system)
- Downside: none stated; trait is purely positive
- Uptime: intended as always-on (100%), but actual uptime depends on whether the consuming system is present and polling each tick
- Cost: 12 points (UT) vs. 8 points (source FillerTraits)
- Peer comparison:
  - Source cost was 8; UT charges 12, a 50% premium over the source. No clear justification is documented.
  - `UT_glassbody` costs -10 and is mutually exclusive — pain immunity being the conceptual mirror of glass-body fragility is thematically coherent, but the asymmetry (+12 vs. -10) favors the player slightly less when taking Analgesia than when taking the downside.
  - Pain immunity is a significant quality-of-life benefit in PZ (pain causes combat penalties and morale impacts); 12 points is plausibly justified but is a divergence from the source that should be intentional.
- Stack or exclusion notes: Mutually exclusive with `UT_glassbody`. No exclusion from other pain-relevant traits is defined. No stated interaction with wound-severity traits (`UT_brittle`, `UT_heavilybleedingwounds`, etc.) that may indirectly generate pain.
- Cost verdict: plausible but undocumented — the +4 increase over the source (8 → 12) may reflect the UT cost calibration scale, but no rationale is recorded.

## Regression Proof
- Existing tests:
  - `run_tests.lua` line 83–85: `test("UT_analgesia registered", ...)` — asserts `UTTraitsRegistries.UT_analgesia == "UniversalTraits:UT_analgesia"`. Proves the registry entry exists.
  - `run_tests.lua` line 252: `UT_analgesia` appears in the `expected_ids` list used by the all-traits registration count test. Proves the trait ID is enumerable.
- What the tests prove: The trait is registered and discoverable. Nothing more.
- Missing proof:
  - No test verifies that `onNewGame` sets `UT_painImmune = true` on a player with the trait.
  - No test verifies that a player without the trait does not receive `UT_painImmune`.
  - No test verifies that the mutual exclusion with `UT_glassbody` is enforced at character creation.
  - No test verifies that a consuming system reads `UT_painImmune` and calls `setPain(0)` each tick.
  - No test verifies behavior on save-reload (flag persistence in mod data).
- Minimum next test if needed: Mock a player with `UT_analgesia`, call `onNewGame(player)`, assert `player:getModData()["UT_painImmune"] == true`. Mock a player without the trait and assert `UT_painImmune` is nil after the same call.

## Final Verdict
- Source origin: proven — FillerTraits "Analgesia" confirmed via `TraitFactory.addTrait("Analgesia", ...)` in both `UpgradeMainCreationMethods.lua` copies and the matching `OnPlayerUpdate`-driven `setPain(0)` loop in both `UpgradeTraits.lua` copies
- UT implementation: significantly simplified — the source applied active continuous pain suppression via `OnPlayerUpdate` calling `stats:setPain(0)` every tick; the UT version replaces this with a single mod-data flag (`UT_painImmune = true`) written once at new-game start, delegating all active suppression to an unverified consuming system
- Description: misleading — "permanently suppressed" implies continuous active zeroing; the UT implementation is a passive flag that only functions if a downstream consumer acts on it; the description makes a stronger promise than the implementation delivers
- Balance: plausible but undocumented — cost raised from source 8 to UT 12 without a recorded rationale; the mutual exclusion pivot from "Fibromyalgia" (source) to `UT_glassbody` (UT) is thematically reasonable but changes the exclusion semantics
- Regression proof: partially protected — registration proven; runtime behavior unproven
- Action needed: test fix, doc fix, confirm consuming system
- Open gaps:
  - No behavioral test for `onNewGame` setting `UT_painImmune`
  - No evidence of a consuming system that reads `UT_painImmune` and calls `setPain(0)` each tick — if absent, the trait silently does nothing at runtime despite the description claiming permanent suppression
  - Description should be revised to reflect flag-based architecture and dependency on a consuming system, or the implementation should be updated to add its own `OnPlayerUpdate` handler (matching the source approach)
  - `DisabledInMultiplayer` is `true` in UT; source had `false` (no multiplayer flag set) — this divergence should be a conscious decision
  - Cost increase from 8 (source) to 12 (UT) should be documented or confirmed intentional
  - Confirm whether `OnLoadedPlayer` or equivalent should re-apply the `UT_painImmune` flag for characters loaded from existing saves
