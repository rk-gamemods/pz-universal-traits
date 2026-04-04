# UT_gunspecialist_III

## Trait Summary

- UT trait id: UT_gunspecialist_III
- Source mod: More Traits (ToadTraitsDynamic / hypnotoadtrance)
- Source trait id: `gunspecialist` (registry key: `ToadTraitsRegistries.gunspecialist`)
- Current cost: 10
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (lines 6–8) — trait registration with XPBoosts; B42.13 version
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (lines 6–8) — same, B42.15 version
  - `research/installed-mods/MoreTraits/mods/More Traits/42/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (lines 5–7) — same, legacy B42
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/registries.lua` (line 6) — `ToadTraitsRegistries.gunspecialist = CharacterTrait.register("ToadTraits:gunspecialist")`
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/Foraging/ToadTraitsforageDefinitions.lua` (lines 118–119) — forage definition entry for the trait

- Source trait registration (B42.13 `MoreTraitsMainCreationMethods.lua` lines 6–8):
  ```lua
  local gunspecialist = TraitFactory.addTrait("gunspecialist", getText("UI_trait_gunspecialist"), 8, getText("UI_trait_gunspecialistdesc"), false, false)
  gunspecialist:addXPBoost(Perks.Aiming, 2)
  gunspecialist:addXPBoost(Perks.Reloading, 2)
  ```
  - Cost: 8 points in source.
  - XPBoosts: +2 to Aiming, +2 to Reloading only.
  - No Nimble boost in source.
  - No runtime Lua script in source — the source trait is pure stat-boost only (registration + XPBoosts via `TraitFactory.addTrait`). There is no `OnPlayerUpdate`, `OnNewGame`, or any other event handler in the source.
  - No jam immunity in source.
  - No reload/aim speed bonus in source.

- Forage definition: the source registered a forage bonus entry for `gunspecialist` with `visionBonus = 0.5`, `weatherEffect = 0`, `darknessEffect = 0`. This adds a passive foraging vision bonus when the trait is active. This is entirely absent from the UT implementation.

- Source `DisabledInMultiplayer`: not flagged MP-disabled in the source scripts reviewed.

## Current UT Evidence

### Structure

- Registered in test harness: yes (`test/run_tests.lua` line 306, in the Phase 3c registration sweep array alongside `UT_gunspecialist_I` and `UT_gunspecialist_II`)
- Registered in `registries.lua`: yes (line 296)
  - `UTTraitsRegistries.UT_gunspecialist_I   = CharacterTrait.register("UniversalTraits:UT_gunspecialist_I")` (line 294)
  - `UTTraitsRegistries.UT_gunspecialist_II  = CharacterTrait.register("UniversalTraits:UT_gunspecialist_II")` (line 295)
  - `UTTraitsRegistries.UT_gunspecialist_III = CharacterTrait.register("UniversalTraits:UT_gunspecialist_III")` (line 296)
  - All three registered consecutively as a sibling group under the Phase 3c block (before Phase 3d — Complex State Traits).
- Defined in `UT_character_traits.txt`: yes (lines 2130–2140)
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_gunspecialist_III`
  - `Cost = 10`
  - `UIName = UI_UT_gunspecialist_III`
  - `UIDescription = UI_UT_gunspecialist_IIIDesc`
  - `XPBoosts = Aiming=2;Reloading=2;Nimble=1`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_gunspecialist_I;UniversalTraits:UT_gunspecialist_II;UniversalTraits:UT_specguns`
- Companion tiers defined for comparison:
  - `UT_gunspecialist_I` (lines 2106–2116): `Cost = 4`, `XPBoosts = Aiming=1;Reloading=1`, mutually exclusive with II, III, and `UT_specguns`.
  - `UT_gunspecialist_II` (lines 2118–2128): `Cost = 8`, `XPBoosts = Aiming=2;Reloading=2;Nimble=1`, mutually exclusive with I, III, and `UT_specguns`.
  - `UT_specguns` (lines 390–400): `Cost = 12`, `XPBoosts = Aiming=4;Reloading=4`, mutually exclusive with the entire gunspecialist series and all other spec traits.
- Translation strings present: yes (`media/lua/shared/Translate/EN/UI_EN.txt` lines 656–657)
  - `UI_UT_gunspecialist_III     = "Gun Specialist III"`
  - `UI_UT_gunspecialist_IIIDesc = "Firearms are an extension of yourself. Gain ×3 XP in Aiming and Reloading, and ×2 XP in Nimbleness. Also grants +10% reload speed, +10% aim speed, and equipped weapons never jam."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_gunspecialist_III.lua`, 38 lines)
- UT_MET.lua group membership: `UT_gunspecialist_III` is **not** listed in any group in `UT_MET.lua`. Mutual exclusion with the sibling gunspecialist tiers and `UT_specguns` is enforced only via the script `MutuallyExclusiveTraits` declarations; there is no UT_MET runtime group.

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_gunspecialist_III.lua` (full file, 38 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 11–16) — `UTCore.hasTrait` implementation
  - `media/scripts/UT_character_traits.txt` (lines 2130–2140)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 656–657)
  - `test/run_tests.lua` (line 306) — registration sweep only; no per-trait moddata tests

- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)` (line 36) — fires once when a new game is started.
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)` (line 37) — fires every game-engine update tick for the local player.

- Local constants and state:
  - `TRAIT_ID = "UniversalTraits:UT_gunspecialist_III"` (line 4) — the only trait ID checked; this file handles no other tier.
  - `tickCounter = 0` (line 6) — module-level tick counter; shared across all calls to `onPlayerUpdate` for this file's lifetime. Not stored in moddata or per-player; is a single Lua-side integer that increments on every call regardless of player.

- UTCore hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — called in both `onNewGame` (line 9) and `onPlayerUpdate` (line 17). Implementation: `player:getTraits():contains(traitId)` with nil guards on `player` and `traits` (UTCore_API.lua lines 11–16).

- **`onNewGame` chain (line 8–14):**
  1. Guard: `if not UTCore.hasTrait(player, TRAIT_ID) then return end`
  2. `local moddata = player:getModData()`
  3. Set `moddata["UT_gunspec3"] = true`
  4. Set `moddata["UT_reloadSpeedBonus"] = 0.1`
  5. Set `moddata["UT_aimSpeedBonus"] = 0.1`

- **`onPlayerUpdate` chain (lines 16–34):**
  1. Guard: `if not UTCore.hasTrait(player, TRAIT_ID) then return end`
  2. `tickCounter = tickCounter + 1`
  3. Guard: `if tickCounter % 30 ~= 0 then return end` — runs the body only every 30th tick.
  4. `local moddata = player:getModData()`
  5. Save-load re-hydration guard: `if not moddata["UT_gunspec3"] then` — if keys are missing (e.g., loaded save that missed `OnNewGame`), re-write all three moddata keys.
  6. Read `primary = player:getPrimaryHandItem()` and `secondary = player:getSecondaryHandItem()`.
  7. For each hand: if item exists, call `pcall(function() if item:isJammed() then item:setJammed(false) end end)` — clears the jammed state, wrapped in `pcall` to prevent errors if the item is not a firearm or the method is unavailable.

- Exact numerical parameters:
  - Moddata flag: `"UT_gunspec3"` = `true` (presence flag consumed by external systems or future hooks)
  - Reload speed bonus: `"UT_reloadSpeedBonus"` = `0.1` (10%)
  - Aim speed bonus: `"UT_aimSpeedBonus"` = `0.1` (10%)
  - Jam immunity cadence: every 30 ticks (not every tick)
  - Jam immunity scope: primary hand item and secondary hand item only; inventory items not checked
  - Error protection: `pcall` wraps both jam checks

- Cadence summary: moddata is written once at game start via `OnNewGame`. On every 30th update tick, equipped firearms are silently unjammed if jammed. At approximately 20 ticks/second, the jam-check runs roughly every 1.5 seconds. There is no cooldown or stochastic element in the jam removal — it is deterministic on the 30-tick interval.

- **Critical observation — moddata keys are signals only:** The `"UT_reloadSpeedBonus"` and `"UT_aimSpeedBonus"` keys are written to moddata but there is no code in this file that reads them and applies them to the player's actual reload or aim speed. These keys are promises to a consumer that does not exist in the audited codebase. Whether an external hook (e.g., a UTCore speed hook or a weapon-draw hook) reads these keys was not found in the UniversalTraits or UTMods repos. The speed bonus is declared in moddata and in the description, but its application mechanism is unverified.

## Description Integrity

- Display name check: "Gun Specialist III" — appropriate and consistent with the tier naming convention.
- Description check: `UI_UT_gunspecialist_IIIDesc` reads: "Firearms are an extension of yourself. Gain ×3 XP in Aiming and Reloading, and ×2 XP in Nimbleness. Also grants +10% reload speed, +10% aim speed, and equipped weapons never jam."
- Issues found:
  1. **XPBoost multiplier language is inaccurate.** The description claims "Gain ×3 XP in Aiming and Reloading, and ×2 XP in Nimbleness." The `UT_character_traits.txt` definition is `XPBoosts = Aiming=2;Reloading=2;Nimble=1`. In PZ B42, `XPBoosts` are additive bonuses to the XP multiplier — `Aiming=2` grants **+2 to the Aiming XP multiplier**, not a ×3 multiplier (which would imply the base ×1 plus a ×2 gain, but this framing is non-standard for PZ XPBoosts which stack additively). The description "×3 XP" implies a baseline of ×1 plus +2, which may be technically correct in net-effect terms if the base rate is ×1 — but this framing is inconsistent with the UT policy of writing "+N to SkillName" rather than "×N XP". Likewise "×2 XP in Nimbleness" corresponds to `Nimble=1` — the net rate is ×2 only if base is ×1, but it should be written "+1 to Nimbleness." The description should read "+2 to Aiming and Reloading, +1 to Nimbleness" per UT convention.
  2. **"+10% reload speed, +10% aim speed" — the application mechanism is unverified.** The moddata keys `"UT_reloadSpeedBonus"` and `"UT_aimSpeedBonus"` are written to 0.1, but no code in the audited files reads these keys and applies them to actual player speed. The description claims this bonus as a firm benefit, but it is a signal without a confirmed consumer in the audited codebase. If the consuming hook is missing or was never implemented, the described speed bonuses do not actually function in-game.
  3. **"equipped weapons never jam" — partially accurate.** The jam immunity fires every 30 ticks, not continuously. A weapon can be jammed for up to 30 ticks (~1.5 seconds) before it is cleared. "Never jam" implies instant prevention, but the implementation is periodic remediation. The correct phrasing is "equipped weapons are automatically unjammed" or "cannot remain jammed for long."
  4. **No mention of multiplayer restriction.** `DisabledInMultiplayer = true` means this trait cannot be taken in MP. The description gives no indication of this. This is consistent with the UT mod-wide convention (MP restriction is not called out in individual descriptions) but is a player-information gap.

## Balance Review

- Upside:
  - `XPBoosts = Aiming=2;Reloading=2;Nimble=1` — meaningful long-term XP acceleration in three relevant skills.
  - +10% reload speed and +10% aim speed written to moddata (if a consuming hook exists).
  - Periodic jam immunity on equipped weapons (every 30 ticks).

- Downside / cost: positive trait; costs 10 character creation points.

- Tier comparison within the gunspecialist series:
  | Tier | Cost | XPBoosts | Runtime |
  |---|---|---|---|
  | I | 4 | Aiming=1, Reloading=1 | none |
  | II | 8 | Aiming=2, Reloading=2, Nimble=1 | none |
  | III | 10 | Aiming=2, Reloading=2, Nimble=1 | +10% speed (moddata), jam immunity every 30 ticks |

  Tier III costs 2 more points than Tier II and gains identical XPBoosts but adds the runtime bonuses. The XPBoost profile of II and III is identical — the only differentiator is the runtime script. If the speed moddata keys are not consumed by any hook, Tier III's only actual runtime advantage over Tier II is jam immunity.

- Source divergences that affect balance:
  1. **Cost increase.** Source cost was 8. UT Tier III costs 10. The added 2 points nominally cover the runtime bonuses, but if the speed hook is missing the extra cost buys only jam immunity.
  2. **Nimble XP boost added.** Source had no Nimble boost (`+0`). UT Tier II and III both add `Nimble=1`. This is a meaningful expansion beyond source.
  3. **Jam immunity is an UT invention.** There is no jam immunity in the source trait. This is a novel bonus added by UT.
  4. **Speed bonuses are an UT invention.** There is no reload/aim speed modifier in the source trait.
  5. **Forage vision bonus dropped.** Source registered a forage definition with `visionBonus = 0.5`. UT does not replicate this bonus. Players who relied on the gunspecialist foraging bonus lose that benefit.
  6. **`DisabledInMultiplayer = true`.** Source was not MP-restricted.

- Cost verdict: 10 points is steep for this tier if the speed moddata keys have no consumer. If the speed hook works, the combined XP boosts plus speed improvement plus jam immunity justifies the cost premium over Tier II. Without the speed hook, Tier III is Tier II plus jam immunity for 2 extra points — which may be undervalued or correctly priced depending on how often players encounter jams in practice.

- Peer comparison:
  - `UT_specguns` at Cost 12 provides `Aiming=4;Reloading=4` (higher XP boosts) but no runtime. It is mutually exclusive with the gunspecialist series. The gunspecialist III + cost-10 XP profile is strictly weaker on XP boosts than specguns, but adds runtime behaviors not present in specguns. Players choosing between the two are trading higher raw XP acceleration (specguns) against runtime jam/speed utility (gunspecialist III).
  - `UT_antigun` is the XP-penalty counterpart (−50% Aiming and Reloading XP). It is not in the mutual exclusion list with gunspecialist; technically both could coexist, though that would be contradictory design. No mutual exclusion guard prevents this combination.

## Regression Proof

- Test location: `test/run_tests.lua` line 306 — `"UniversalTraits:UT_gunspecialist_III"` appears in the Phase 3c registration sweep array (`expected_ids`), which is consumed by the "all 198 trait IDs registered with CharacterTrait" test.
- Tests present:
  1. **Registration sweep** (line 306): verifies that `UTTraitsRegistries.UT_gunspecialist_III` resolves to `"UniversalTraits:UT_gunspecialist_III"` and that `CharacterTrait._registered` contains the ID. **Proves**: the registry line in `registries.lua` is syntactically correct and the ID string is well-formed.

- What the tests prove:
  - The trait ID is registered and resolves correctly.
  - Nothing else. There are no per-trait moddata tests for `UT_gunspecialist_III`.

- Missing proof:
  1. **No test for `onNewGame` moddata initialization.** No test fires `Events.OnNewGame` with a player holding `UT_gunspecialist_III` and asserts that `moddata["UT_gunspec3"] == true`, `moddata["UT_reloadSpeedBonus"] == 0.1`, and `moddata["UT_aimSpeedBonus"] == 0.1`.
  2. **No test for save-load re-hydration.** No test fires `Events.OnPlayerUpdate` 30 times with a player that has the trait but missing moddata keys, asserting that the keys are written on the 30th tick.
  3. **No test for jam immunity trigger.** No test provides a mock firearm with `_isJammed = true` as primary or secondary hand item, fires `Events.OnPlayerUpdate` 30 times, and asserts the item is unjammed.
  4. **No test for jam immunity cadence.** No test verifies that jam check is skipped on ticks 1–29 and runs on tick 30.
  5. **No test for the `pcall` protection path.** No test passes a non-firearm item (where `isJammed` does not exist) and verifies the handler does not error.
  6. **No test for non-trait player no-op.** No test confirms that a player without the trait passes through `onPlayerUpdate` without modifying their moddata.
  7. **No test that speed moddata keys are consumed.** This is a broader architectural gap — even if the keys are written correctly, there is no test proving the downstream speed effect is applied.
  8. **`tickCounter` shared-state risk is untested.** Because `tickCounter` is a module-level variable (not per-player), it is shared across all players in a multiplayer or co-op context. Since `DisabledInMultiplayer = true`, this is not currently a live risk, but no test verifies the variable resets correctly between game sessions or across multiple `dofile` loads in the test harness.

- Minimum next test if needed: "gunspecialist_III: OnNewGame writes moddata" — create a `MockPlayer` with `"UniversalTraits:UT_gunspecialist_III"`, `dofile` the trait file, fire `Events.OnNewGame`, assert `moddata["UT_gunspec3"] == true`, `moddata["UT_reloadSpeedBonus"] == 0.1`, `moddata["UT_aimSpeedBonus"] == 0.1`.

## Final Verdict

- Source origin: proven — More Traits `gunspecialist` (`ToadTraitsRegistries.gunspecialist`, `CharacterTrait.register("ToadTraits:gunspecialist")`) is the confirmed source. The source trait is pure XPBoost registration with no runtime Lua script.
- UT implementation: substantially expanded beyond source — the core XP acceleration concept is preserved, but UT adds a three-tier progression (I/II/III), adds Nimble XP boosts absent in source, and invents two runtime bonuses (speed moddata, jam immunity) that have no basis in the source trait. The forage vision bonus from source is dropped.
- Description: contains one convention violation and two accuracy issues:
  1. **Convention violation**: XPBoost description uses "×N XP" framing instead of the required "+N to SkillName" convention. Should read "+2 to Aiming and Reloading, +1 to Nimbleness."
  2. **Accuracy issue (critical)**: "+10% reload speed, +10% aim speed" may be non-functional. The moddata keys are written but no consuming hook was found in the audited codebase. If the speed hook does not exist or was never implemented, this description claim is false.
  3. **Accuracy issue (minor)**: "equipped weapons never jam" overstates the protection. The reality is periodic unjamming every ~1.5 seconds, not continuous jam prevention.
- Balance: reasonable tier structure at Cost 10 if all claimed runtime bonuses function. If the speed bonus is a dead moddata write, Tier III is effectively Tier II plus jam immunity for 2 extra points — still defensible but the cost premium is harder to justify.
- Regression proof: only registration is tested. All runtime behaviors (moddata initialization, save-load re-hydration, jam immunity, tick cadence) are completely untested.
- Action needed:
  1. **Verify or implement the speed hook.** Search the full UTMods codebase for any code reading `"UT_reloadSpeedBonus"` or `"UT_aimSpeedBonus"`. If no consumer exists, either implement the consuming hook or remove the speed bonus from the description and moddata.
  2. **Fix description XPBoost language** — replace "Gain ×3 XP in Aiming and Reloading, and ×2 XP in Nimbleness" with "+2 to Aiming and Reloading, +1 to Nimbleness" per UT convention.
  3. **Fix jam description** — replace "equipped weapons never jam" with "equipped weapons are automatically unjammed" or "jam state is cleared every few seconds."
  4. **Add `onNewGame` moddata test** — verify all three keys are written on new game start.
  5. **Add jam immunity test** — mock jammed primary/secondary item, fire 30 update ticks, assert unjammed.
  6. **Add cadence test** — verify tick 1–29 skip and tick 30 executes.
  7. **Consider foraging bonus** — the source trait's `visionBonus = 0.5` forage bonus was silently dropped. Decide whether to restore it or document the omission as intentional.
- Open gaps:
  - `tickCounter` is a module-level shared variable. In a single-player session this is harmless. In a co-op scenario (if MP restriction were ever lifted) multiple players with the trait would share one counter and jam-checks could desync. This is not a current risk but is a latent design flaw.
  - No `UT_MET.lua` group entry exists for the gunspecialist tier. This is correct — their mutual exclusion is enforced by the `.txt` definition. No UT_MET entry is needed unless the exclusion logic needs to be accessible at runtime for other purposes.
  - The `UT_gunspecialist_II` registered test (`test/run_tests.lua` line 108) exists as a standalone named test. No equivalent named test exists for `UT_gunspecialist_III`; it appears only in the bulk sweep. This asymmetry is harmless but worth noting.
