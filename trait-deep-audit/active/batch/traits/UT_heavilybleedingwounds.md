# UT_heavilybleedingwounds

## Trait Summary
- UT trait id: UT_heavilybleedingwounds
- Source mod: MoreSimpleTraits (MST)
- Source trait id: HeavilyBleedingWounds
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` (trait registration)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` (runtime implementation, both MST and MSTVanilla variants are identical)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt` (source strings)
- Source display name: "Liquid Blood"
- Source description: "Wounds bleed more. (+100% Bleeding damage)."
- Source cost: -4 (matches UT)
- Source mutual exclusions: `HeavilyBleedingWounds` ↔ `WeaklyBleedingWounds` (bidirectional; confirmed in both MST and MSTVanilla creation methods)
- Source trigger path: `Events.OnPlayerUpdate.Add(hbwounds)` — fires every player update tick.
- Source behavior: Each tick, if the player has the trait, the function counts actively bleeding body parts via `bodydamage:getNumPartsBleeding()`. For each part where `b:bleeding() == true` and `b:IsBleedingStemmed() == false`, it calls `b:ReduceHealth(0.0055)`. For the Neck part specifically, the damage is `0.0055 * 4 = 0.022` per tick. This is a raw per-tick additive health subtraction applied directly to the body part, independent of the native bleed drain formula. The source does not modulate the native bleeding rate; it stacks additional damage on top of it. The effective bleed acceleration is therefore partially dependent on native bleedingTime accumulation and partially on the per-tick flat damage applied by the hook. The source trait does not interact with `UT_thickblood` or any other bleeding trait — mutual exclusion is only enforced against `WeaklyBleedingWounds`.

## Current UT Evidence
### Structure
- Registered in registries.lua: yes (confirmed via test file line 254 which includes it in the expected ID list for the bleeding phase)
- Defined in UT_character_traits.txt: yes (lines 1292–1301)
- Translation strings present: yes (`UI_UT_heavilybleedingwounds` and `UI_UT_heavilybleedingwoundsDesc`)
- Exclusions/grants correct: yes — mutually exclusive with `UniversalTraits:UT_thickblood` (via thickblood's definition line 1289) and `UniversalTraits:UT_weaklybleedingwounds` (line 1300), bidirectional for weaklybleedingwounds; thickblood only declares the exclusion in its own definition, confirmed line 1300 covers the reverse direction on heavilybleedingwounds's side
- Runtime Lua file exists: yes — `UT_heavilybleedingwounds.lua`
- `DisabledInMultiplayer`: true (matches weaklybleedingwounds and thickblood peers; source had no explicit multiplayer restriction)

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_heavilybleedingwounds.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` (lines 114–127)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_BleedDrainHook.lua` (full file)
  - `media/scripts/UT_character_traits.txt` (lines 1281–1312)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 389–390)
  - `test/run_tests.lua` (lines 527–532)
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait`, `UTCore.applyBleedDrainMult`
- Runtime chain (plain language):
  1. On new game start, `onNewGame` fires.
  2. If the player has `UniversalTraits:UT_heavilybleedingwounds`, the function calls `UTCore.applyBleedDrainMult(player, 2.0)`.
  3. `applyBleedDrainMult` writes `player:getModData()["UT_bleedDrainMult"] = 2.0`.
  4. On every subsequent `OnPlayerUpdate` tick, `UTCore_BleedDrainHook.lua` reads `UT_bleedDrainMult`. If it is not nil and not 1.0, the hook proceeds (throttled every 30 ticks, approximately 1 real second).
  5. If any body part has `bleeding() == true` and `IsBleedingStemmed() == false`, the hook estimates the native drain for that tick window. For each such part it computes: `BLEED_COEFF (0.2857143) * damageScaler * gameMultiplier * (bleedingTime / 10.0) * THROTTLE (30)`. Standard parts use `damageScaler = 0.00571`; Neck uses `0.02857`.
  6. The total `estimatedDrain` is multiplied by `(1.0 - mult)` to get `offset`. With `mult = 2.0`, `offset = estimatedDrain * (1.0 - 2.0) = -estimatedDrain` — a negative health adjustment.
  7. `player:setHealth(math.max(currentHealth + offset, 0.0))` is called. The negative offset reduces `getHealth()` by an amount equal to the estimated native drain, effectively doubling the total health reduction from bleeding for that window (native drain + equal hook drain = 2× native drain).
  8. The hook is silent when no parts are bleeding. There is no load-game re-application; the mod data value persists in the save.
- Actual behavior (exact values): sets `UT_bleedDrainMult = 2.0`, which causes the BleedDrainHook to subtract an additional health amount equal to the estimated native bleed drain every 30 ticks while actively bleeding. Net result: effective bleed death rate is 2× normal — the player bleeds out in approximately half the normal time. Wound healing speed once bandaged is unaffected (the hook only fires for unstemmed bleeding parts). Neck wounds are treated with a 5× damage scaler both natively and in the hook estimate, so the relative 2× acceleration is preserved for neck wounds.

## Description Integrity
- Display name check: "Heavily Bleeding Wounds" — accurate and clearly communicates the penalty. Differs from the source name "Liquid Blood" but is more descriptive of the actual effect.
- Description check (UI_EN.txt line 390): "Even minor cuts refuse to close. Bleed rate is increased to 200% of normal — wounds bleed twice as fast."
- Accuracy assessment:
  - "200% of normal" and "twice as fast" accurately reflect `mult = 2.0` and the doubling behavior of the hook.
  - "Even minor cuts refuse to close" is flavour text, not a mechanical claim, and does not conflict with behavior.
  - The description does not mention that the effect is new-game-only (no re-application on save load). However, because `UT_bleedDrainMult` is stored in mod data which persists in the save, the effect does survive reloads without needing re-application. This is different from traits that rely on `OnNewGame` to set a value that is not persisted. No disclosure gap here.
  - The description does not mention that healing speed once bandaged is unaffected — this is an important clarifying detail (per the Lua comment at line 4 of the trait file) that is absent from the description.
  - The description does not mention mutual exclusion with thickblood or weaklybleedingwounds — this is acceptable as exclusions are shown in the character creation UI.
- Missing or misleading details: The description does not clarify that bleed-out acceleration only applies while wounds are actively bleeding (unstemmed). Once bandaged, there is no ongoing penalty. This distinction matters for player decision-making — the trait is less punishing than it appears if the player bandages quickly.

## Balance Review
- Upside: none — pure downside trait
- Downside: active bleed drain doubled (2× death rate from bleeding), permanent for the life of the character
- Uptime: conditional — only active while at least one body part has active unstemmed bleeding. Zero effect once all wounds are bandaged or stemmed.
- Peer comparison:
  - `UT_weaklybleedingwounds`: +3 cost, reduces bleed drain to 60% of normal (mirror positive)
  - `UT_thickblood`: +4 cost, reduces bleed drain to 50% of normal AND accelerates clot rate (bleedDecayMult), stronger than weaklybleedingwounds
  - `UT_heavilybleedingwounds`: -4 cost, increases bleed drain to 200% of normal (no clot penalty)
  - Asymmetry note: thickblood costs +4 for two benefits (50% drain reduction + faster clotting) while heavilybleedingwounds costs -4 for only one penalty (2× drain, no clot slowdown). The source trait similarly applied only additive per-tick health damage, not a clotting penalty. The absence of a clotting penalty is consistent with source behavior. Whether -4 fairly compensates for a potentially lethal doubling of bleed rate is a balance design decision; the lack of a bleed decay penalty means a player who bandages promptly suffers no effect at all.
- Stack or exclusion notes: Mutually exclusive with both `UT_thickblood` and `UT_weaklybleedingwounds`. Cannot be combined with other bleed-rate modifiers in this set. No stated exclusion from unrelated wound traits (e.g., `UT_glassbody`, `UT_brittle`).
- Cost verdict: plausible but soft — the -4 refund is fair for a bleeding penalty if the player is exposed to heavy combat. For a cautious player who bandages quickly, the trait costs almost nothing meaningful in practice, making -4 possibly generous. A clot-rate penalty (bleedDecayMult > 1.0) would make the trait more consistently punishing and closer to the symmetric mirror of thickblood.

## Regression Proof
- Existing test (run_tests.lua lines 527–532):
  ```
  -- UT_heavilybleedingwounds sets UT_bleedDrainMult=2.0 (faster death rate)
  test("UT_heavilybleedingwounds sets UT_bleedDrainMult > 1.0", function()
      local p = fireNewGame("UniversalTraits:UT_heavilybleedingwounds")
      local v = p:getModData()["UT_bleedDrainMult"]
      assert_true(type(v) == "number" and v > 1.0, "expected UT_bleedDrainMult > 1.0, got " .. tostring(v))
  end)
  ```
- What it proves: Calling `onNewGame` with a player who has the trait results in `UT_bleedDrainMult` being a number greater than 1.0. Confirms the trait file fires, `UTCore.applyBleedDrainMult` is called, and the mod data key is written.
- What it does not prove:
  - The exact value is 2.0 (the assert only checks `> 1.0`, not `== 2.0`).
  - A player without the trait does not receive `UT_bleedDrainMult`.
  - The BleedDrainHook correctly doubles effective drain when `UT_bleedDrainMult = 2.0`.
  - Mutual exclusions with thickblood and weaklybleedingwounds are enforced at the engine level.
  - The trait ID appears in the full registration test (confirmed separately via the expected_ids list at line 254 which includes this trait).
- Minimum next test if needed: Assert `v == 2.0` instead of `v > 1.0` to pin the exact multiplier. Add a negative test: mock a player without the trait, call `onNewGame`, assert `UT_bleedDrainMult` is nil.

## Final Verdict
- Source origin: proven — `MoreSimpleTraits:HeavilyBleedingWounds` confirmed with matching cost (-4), matching mutual exclusion with WeaklyBleedingWounds, and consistent description intent (+100% bleeding damage)
- UT implementation: re-architected — the source applied raw per-tick `ReduceHealth` calls directly to body parts via `OnPlayerUpdate`; the UT version replaces that with a mod data flag (`UT_bleedDrainMult = 2.0`) consumed by `UTCore_BleedDrainHook`, which estimates and doubles the native drain via `setHealth` offsets. The functional outcome (2× bleed death rate) matches the source intent. The UT approach is cleaner, frame-rate independent within its throttle window, and consistent with peer traits (thickblood, weaklybleedingwounds) using the same hook.
- Description: mostly accurate — "200% of normal" and "twice as fast" are correct. Missing: no mention that the penalty is zero once wounds are bandaged, which is a meaningful player-facing detail.
- Balance: plausible — cost matches source; the lack of a clot-rate penalty (unlike thickblood's symmetric double benefit) means the trait is less punishing for attentive players than the cost implies. Not a bug, but a balance note.
- Regression proof: partially protected — trait registration and `UT_bleedDrainMult > 1.0` are tested; exact value (2.0) is not pinned and hook behavior is untested.
- Action needed: doc fix, test tighten
- Open gaps:
  - Description should note that the penalty only applies while wounds are actively bleeding — once bandaged, the trait has no effect.
  - Test should assert exact value `== 2.0`, not just `> 1.0`.
  - No test for the negative case (player without trait should not receive the key).
  - Consider whether a bleed-decay penalty (slower clotting) is appropriate to make the trait symmetrically punishing relative to thickblood's dual benefit — design decision, not a bug.
  - `DisabledInMultiplayer = true` is a divergence from the source (MST had no explicit restriction); confirm this is intentional.
