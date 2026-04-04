# UT_fasthands

## Trait Summary
- UT trait id: UT_fasthands
- Source mod: FillerTraits (UpgradeMainCreationMethods.lua / NPC trait factory)
- Source trait id: FastHands (TraitFactory string key, not a script-block ID)
- Current cost: 12
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/shared/NPCs/UpgradeMainCreationMethods.lua`
- Source trait registration (line 41):
  ```lua
  local FastHands = TraitFactory.addTrait("FastHands", getText("Fast Hands"), 12,
      getText("Incredibly good with make-shift weapons of all sorts. \n+4 Spear \n+1 Short Blade \n+1 Short Blunt"), false);
  FastHands:addXPBoost(Perks.SmallBlade, 1)
  FastHands:addXPBoost(Perks.SmallBlunt, 1)
  FastHands:addXPBoost(Perks.Spear, 4)
  TraitFactory.setMutualExclusive("Improviser", "FastHands");
  ```
- Source behavior: The FillerTraits `FastHands` trait grants XP boosts — +4 to Spear, +1 to Short Blade, +1 to Short Blunt — and is mutually exclusive with `Improviser`. The name "Fast Hands" and cost of 12 points are shared with the UT version, but the source mechanic is entirely skill-based (XPBoosts), not a speed multiplier. This is a name collision: UT_fasthands does not port the FillerTraits `FastHands` behavior.
- Source cost: 12 (matches UT)
- Source mutual exclusion: `Improviser` ↔ `FastHands` (not carried into UT)
- Note: No other installed-mod source was found in `research/installed-mods/` that implements a transfer-speed or reload-speed multiplier under the name "fast hands" or equivalent. The UT implementation is an original mechanic, not a faithful port of the FillerTraits source.

## Current UT Evidence

### Structure
- Registered in run_tests.lua expected_ids: yes — `"UniversalTraits:UT_fasthands"` appears on line 251 in the Phase 2 — Combat & Physical block
- Defined in UT_character_traits.txt: yes
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_fasthands`
  - `Cost = 12`
  - `UIName = UI_UT_fasthands`
  - `UIDescription = UI_UT_fasthandsDesc`
- MutuallyExclusiveTraits: none defined
- GrantedTraits: none defined
- Translation strings present: yes
  - `UI_UT_fasthands = "Fast Hands"`
  - `UI_UT_fasthandsDesc = "Your hands move with fluid precision. Item transfers and reload actions complete 40% faster (transfer time multiplier: ×0.6)."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_fasthands.lua`)

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_fasthands.lua`
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` — guard check only; no other UT_CORE hooks
- Runtime chain (plain language):
  1. `Events.OnNewGame` fires once when a new game session starts.
  2. `UTCore.hasTrait` is called to check whether the player has `UniversalTraits:UT_fasthands`. If not, the handler returns immediately.
  3. If the trait is present, `player:getModData()["UT_transferSpeedMult"]` is set to `0.6`.
- Actual behavior (exact values):
  - Sets ModData key `UT_transferSpeedMult` to `0.6` on new game if the trait is active.
  - The `0.6` multiplier is intended to represent a 40% reduction in transfer/reload time (i.e., actions take 60% of normal duration).
  - **Critical gap**: The runtime only hooks `OnNewGame`. There is no `OnLoad` / `OnGameBoot` hook to restore the ModData flag when loading an existing save. A player who picks the trait and saves, then loads the game, will not have `UT_transferSpeedMult` re-set by this script on load. Whether another system reads this ModData key and applies it is not evidenced in the files reviewed.
  - **Critical gap**: No event handler or game system is wired in this file to actually consume `UT_transferSpeedMult` and slow down transfer/reload actions at runtime. The script only writes a ModData value; whether any downstream system reads it is unknown from the evidence available.

## Description Integrity
- Display name check: "Fast Hands" — matches source name exactly; no renaming concern.
- Description check: "Your hands move with fluid precision. Item transfers and reload actions complete 40% faster (transfer time multiplier: ×0.6)."
  - The `×0.6` multiplier is confirmed by the runtime (`player:getModData()["UT_transferSpeedMult"] = 0.6`).
  - The "40% faster" claim is arithmetically consistent with a `×0.6` time multiplier (time reduced by 40%).
  - The description correctly exposes the raw multiplier parenthetically, which aids player understanding.
- Missing or misleading details:
  - The description does not disclose that the effect is only applied on new game start (not on load). If the ModData is never re-applied after a load, the description is misleading for any save/load session.
  - The description does not clarify which specific systems read `UT_transferSpeedMult`; if the consumer is not implemented, the description is undeliverable.
  - No mention of `DisabledInMultiplayer`, which is `true` — consistent with description scope (singleplayer only).

## Balance Review
- Upside: A 40% reduction in item transfer and reload time is a strong quality-of-life and combat efficiency benefit. Faster reloads in particular have direct survivability impact under pressure.
- Downside: None — pure positive trait with no stated drawback.
- Uptime: Intended as always-on after new game start; however, due to the `OnNewGame`-only hook, persistence across load sessions is unconfirmed.
- Peer comparison: Cost 12 is the highest tier in the UT trait set (same as `UT_analgesia`). A 40% speed gain on transfers and reloads is meaningful but narrower in scope than blanket combat or movement buffs. At 12 points this is borderline — legitimate if reloads are as impactful as the description implies, but steep if the benefit is limited to inventory management alone.
- Stack or exclusion notes: No `MutuallyExclusiveTraits` are defined. The source `FillerTraits` mutual exclusion with `Improviser` was not carried forward. No stacking conflict is defined with other speed-modifier traits.
- Cost verdict: plausible at 12 points if the reload component is confirmed functional and persistent — but the implementation gap (OnNewGame-only hook, no confirmed consumer) makes the effective cost-to-benefit ratio unverifiable. If the effect does not persist across loads, the trait is a partial refund trap.

## Regression Proof
- Existing test: `run_tests.lua` includes `"UniversalTraits:UT_fasthands"` in the `expected_ids` array (line 251, Phase 2 — Combat & Physical block). This confirms the trait ID is registered and the string matches the script definition.
- What it proves: Trait ID is correctly registered. The definition block, translation keys, and Lua file are all present and consistent.
- Missing proof: No behavioral test exists. There is no test verifying:
  - That `onNewGame` correctly calls `UTCore.hasTrait` and sets `UT_transferSpeedMult = 0.6` when the trait is present.
  - That `UT_transferSpeedMult` is restored or re-applied on game load (an `OnLoad` hook test would be needed).
  - That any downstream system reads `UT_transferSpeedMult` and applies it to actual transfer or reload timers.
- Minimum next test if needed: A mock-based unit test for `onNewGame` with a fake player whose `getModData()` returns a writable table. Assert that with the trait present, `modData["UT_transferSpeedMult"]` equals `0.6` after the call. Assert that without the trait, the key is not written. A second test should simulate a game-load event and verify the multiplier is re-established if an `OnLoad` hook is added.

## Final Verdict
- Source origin: name and cost borrowed from FillerTraits `FastHands`, but the mechanic (transfer/reload speed multiplier) is original to UT — not a port of the XPBoost-based source trait.
- UT implementation: incomplete — the `OnNewGame` hook sets `UT_transferSpeedMult = 0.6` in ModData, but there is no evidence of an `OnLoad` hook to restore the value after saving and reloading, and no evidence of a downstream consumer that reads this key and applies it to game systems. The described effect may not function in practice beyond new-game sessions.
- Description: overstated given the implementation gap — the "40% faster" claim and the `×0.6` multiplier are numerically consistent with the ModData write, but cannot be confirmed as delivered to the player if the consumer is missing or the value is lost on load.
- Balance: unresolvable until implementation is confirmed functional and persistent.
- Regression proof: partially protected (registration confirmed; runtime behavior and persistence unproven)
- Action needed: implementation verification + fix
- Open gaps:
  - No `OnLoad` / `OnGameBoot` hook exists to re-apply `UT_transferSpeedMult` after loading a save. This is a likely regression for any player who saves and reloads.
  - No downstream consumer of `UT_transferSpeedMult` was found in the files reviewed. The actual transfer/reload speed reduction may not be wired up.
  - The mutual exclusion with `Improviser` present in the FillerTraits source was not carried into UT. Intentional or oversight — unknown.
  - `DisabledInMultiplayer = true` is consistent with other UT traits but is a divergence from the FillerTraits source (which used `false` for its NPC-facing factory registration).
  - No behavioral unit test for the `onNewGame` handler or any consumer that applies the multiplier.
