# UT_mundane

## Trait Summary

- UT trait id: UT_mundane
- Source mod: More Traits (ToadTraits)
- Source trait id: ToadTraits:mundane
- Current cost: −9
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42.13/media/lua/shared/MoreTraits - Dynamic.lua` (B42 dynamic runtime, lines 55–93 — `MTDMundane` function and `OnWeaponHitCharacter` hook)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42/media/lua/client/MoreTraits - Dynamic.lua` (B41 dynamic runtime, lines 55–69 — legacy `MTDMundane` function)
  - `research/installed-mods/EvolvingTraitsWorld/mods/Evolving Traits World - Mark Dynamic Traits/42/media/lua/shared/NPCs/ETWSubmodCreationMethods.lua` (line 114 — registers `mundane` as a known dynamic trait name)
- Source trait definition: not directly reviewed in this audit (More Traits script file not traced); cost and exclusions inferred from UT script definition and dynamic code only.
- Source trigger paths (More Traits - Dynamic B42 runtime):
  1. `Events.OnWeaponHitCharacter` fires `MTDWeaponHit(wielder, target, weapon)`. Inside that handler, if `SandboxVars.MoreTraitsDynamic.MundaneDynamic` is enabled and the player has trait `mundane`, `MTDMundane(wielder, damage)` is called.
  2. `MTDMundane` accumulates total damage dealt in `wielder:getModData().MoreTraitsDynamic.TotalDamageDone`. When that total reaches `SandboxVars.MoreTraitsDynamic.MundaneDynamicDamage` (a configurable sandbox threshold), the trait removes itself via `wielder:getCharacterTraits():remove(ToadTraitsRegistries.mundane)` (multiplayer) or `wielder:getTraits():remove("mundane")` (B41 singleplayer path), then fires a green halo text `getText("UI_trait_mundane")`.
  3. The B41 path divides the threshold by 10 when `getGameTime():getModData().MTModVersion == 1` to account for the old version scaling.
- Source behavior: `mundane` is a dynamic negative trait in More Traits. Its primary effect in source is dynamic removal — the player "earns their way out of" being mundane by dealing enough cumulative weapon damage. The core static penalty (what the player suffers before removal) is not reproduced in the dynamic Lua reviewed; the static XP/stat effects would reside in the base More Traits Lua file, which was not traced in the installed-mods index for this audit.
- Source EN description (UT_mundane display text from More Traits): `getText("UI_trait_mundane")` — the halo text shown on dynamic removal; the literal string is not present in the installed-mods index files reviewed here.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — `UTTraitsRegistries.UT_mundane = CharacterTrait.register("UniversalTraits:UT_mundane")` at line 192 of `media/registries.lua`, in the PHASE 2 — LUA-DRIVEN: PSYCHOLOGY & MODIFIERS block.
- Defined in UT_character_traits.txt: yes (lines 1369–1378)
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_mundane`
  - `Cost = -9`
  - `UIName = UI_UT_mundane`
  - `UIDescription = UI_UT_mundaneDesc`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_ascetic;UniversalTraits:UT_anorexy`
- Translation strings present: yes (UI_EN.txt lines 416–417)
  - `UI_UT_mundane = "Mundane"`
  - `UI_UT_mundaneDesc = "You were never exceptional at anything. XP gain in Carpentry, Cooking, First Aid, Mechanics, Electrical, Aiming, and Reloading is reduced to ×0.8 (−20%). Also disables special combat abilities from other traits (Martial Artist, Action Hero)."`
- Mutual exclusion cross-check:
  - `UT_mundane` excludes `UT_ascetic` and `UT_anorexy` (UT_character_traits.txt line 1377).
  - `UT_ascetic` (Cost = −4, line 1593–1602) lists its own exclusions including `UT_gourmand` and `UT_mundane` — consistent.
  - `UT_anorexy` (Cost = −6, lines 1948–1957) lists `UT_gourmand`, `UT_competitiveeater`, and `UT_mundane` — consistent.
  - The `UT_mundane` side correctly names both peers; both peers correctly name `UT_mundane`. Mutual exclusion declarations are symmetric and consistent.
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_mundane.lua`)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_mundane.lua` (full file, 18 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1369–1378 — script definition)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 416–417 — display strings)
  - `media/registries.lua` (line 192 — registry entry)
  - `test/run_tests.lua` (lines 261, 597–610 — recognised-trait list and actionhero/mundane suppression test)
  - `media/lua/shared/UniversalTraits/traits/UT_actionhero.lua` (lines 17–18 — mundane guard)
  - `media/lua/shared/UniversalTraits/traits/UT_martial.lua` (lines 19–20 — mundane guard in `applyBonusDamage`)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` (lines 41–43 — `applyXPMultiplier` implementation)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua` (lines 19–58 — XP interception logic)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (lines 11–16 — `hasTrait` implementation)

- Full Lua source (`UT_mundane.lua`):
  ```lua
  -- UT_mundane.lua
  -- -20% XP gain across common skills

  local TRAIT_ID = "UniversalTraits:UT_mundane"

  local function onNewGame(player)
      if not UTCore.hasTrait(player, TRAIT_ID) then return end
      UTCore.applyXPMultiplier(player, "Woodwork", 0.8)
      UTCore.applyXPMultiplier(player, "Cooking", 0.8)
      UTCore.applyXPMultiplier(player, "Doctor", 0.8)
      UTCore.applyXPMultiplier(player, "Mechanics", 0.8)
      UTCore.applyXPMultiplier(player, "Electrical", 0.8)
      UTCore.applyXPMultiplier(player, "Aiming", 0.8)
      UTCore.applyXPMultiplier(player, "Reloading", 0.8)
  end

  Events.OnNewGame.Add(onNewGame)
  ```

- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)` — fires once at new game start; no periodic or combat-event registrations.

- UTCore hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe check via `player:getTraits():contains(traitId)` (UTCore_API.lua line 15).
  - `UTCore.applyXPMultiplier(player, perkName, 0.8)` — writes `player:getModData()["UT_xpMult_" .. perkName] = 0.8` for each of the seven perks (UTCore_StatModifiers.lua line 42).

- XP hook interception chain (UTCore_XPHook.lua lines 19–58):
  1. `Events.AddXP.Add(onAddXP)` intercepts every XP gain game-wide.
  2. For a player who has `UT_mundane`, `UT_xpMult_<perk> = 0.8` is stored for the seven affected perks.
  3. On any XP gain for an affected perk: `mult = 1.0 * 0.8 = 0.8` (no global mult present). `bonus = math.floor(amount * (0.8 - 1.0)) = math.floor(amount * -0.2)`.
  4. If `bonus ~= 0` (true for any `amount >= 5` since `floor(5 * -0.2) = -1`), calls `player:getXp():AddXP(perk, bonus, false, false, false)` — subtracts that amount. Net effective XP rate: ×0.8 (−20%).
  5. Note: for small XP gains (`amount < 5`), `math.floor(amount * -0.2)` rounds to 0 and no subtraction is applied — the penalty is lost due to integer flooring. This is a precision artifact of the hook implementation, not specific to UT_mundane.

- Suppression of other traits (passive side-effect of UT_mundane, not coded in UT_mundane.lua itself):
  - `UT_actionhero.lua` (line 18): `if UTCore.hasTrait(player, "UniversalTraits:UT_mundane") then return end` — causes `onWeaponHitCharacter` to return early before any crit calculation when the player also has `UT_actionhero`. This is a hard suppression: no damage bonus, no crit roll, no spotted-enemy evaluation.
  - `UT_martial.lua` (`applyBonusDamage`, line 20): `if UTCore.hasTrait(player, "UniversalTraits:UT_mundane") then return 0 end` — causes `UT_martial.applyBonusDamage` to return `0` immediately. No crit roll, no SmallBlunt scaling, no health deduction on target, no XP grant. Any caller of `UT_martial.applyBonusDamage` (including `UT_actionhero` on BareHands paths) receives `0`.

- Actual behavior (exact values):
  - Woodwork XP: ×0.8 (−20%), permanent from new game start.
  - Cooking XP: ×0.8 (−20%), permanent from new game start.
  - Doctor (First Aid) XP: ×0.8 (−20%), permanent from new game start.
  - Mechanics XP: ×0.8 (−20%), permanent from new game start.
  - Electrical XP: ×0.8 (−20%), permanent from new game start.
  - Aiming XP: ×0.8 (−20%), permanent from new game start.
  - Reloading XP: ×0.8 (−20%), permanent from new game start.
  - Action Hero crit: suppressed entirely (hard guard in UT_actionhero.lua).
  - Martial Artist bonus damage / crits: suppressed entirely (hard guard in UT_martial.applyBonusDamage).
  - No mood, speed, bleed, weight, or other stat effects.
  - No dynamic removal or escalation path.

- Perk name discrepancy — Lua vs. description:
  - UT_mundane.lua calls `applyXPMultiplier(player, "Woodwork", 0.8)`. The description says "Carpentry". PZ B42 uses the perk key `"Woodwork"` for the Carpentry skill (via `Perks.Woodwork`). The description label "Carpentry" is the player-facing skill name; "Woodwork" is the engine key. This is cosmetic only — no functional issue.
  - UT_mundane.lua calls `applyXPMultiplier(player, "Doctor", 0.8)`. The description says "First Aid". PZ B42 uses `Perks.Doctor` for the First Aid skill. Same pattern — engine key vs. display name. No functional issue.
  - UT_mundane.lua calls `applyXPMultiplier(player, "Electrical", 0.8)`. The description says "Electrical". UTCore_XPHook key would be `"UT_xpMult_Electrical"`. UT_luddite.lua uses `applyXPMultiplier(player, "Electricity", 0.6)` — note the different spelling ("Electrical" vs. "Electricity"). If the PZ perk key for the Electrical skill is `"Electricity"` (as used by UT_luddite), then UT_mundane's `"Electrical"` key would write to a mod data key that the XP hook never matches, and the Electrical XP penalty would silently not apply. This is a potential bug requiring in-engine verification.

## Description Integrity

- Display name: `"Mundane"` — plain and appropriate.
- Description: `"You were never exceptional at anything. XP gain in Carpentry, Cooking, First Aid, Mechanics, Electrical, Aiming, and Reloading is reduced to ×0.8 (−20%). Also disables special combat abilities from other traits (Martial Artist, Action Hero)."`
- Accuracy check:
  - The seven listed skills map to the seven `applyXPMultiplier` calls in the Lua file. Labels match (with the cosmetic Woodwork/Carpentry and Doctor/First Aid differences noted above). Correct.
  - The ×0.8 (−20%) value matches the literal `0.8` multiplier in the Lua. Correct.
  - The statement "disables special combat abilities from other traits (Martial Artist, Action Hero)" accurately describes the hard guards in UT_actionhero.lua and UT_martial.lua. Both named traits are correctly identified. Correct.
- No misleading or missing information in the description relative to actual UT behavior.

## Balance Review

- Upside: none — pure negative trait.
- Downside:
  - Seven permanent −20% XP penalties covering Woodwork, Cooking, Doctor, Mechanics, Electrical, Aiming, and Reloading.
  - Full suppression of UT_actionhero crit mechanics.
  - Full suppression of UT_martial bonus damage and crit mechanics.
- Uptime: All penalties are permanent; applied once at new game via `Events.OnNewGame` and active for the entire run.
- Peer comparison (XP-penalty traits):
  - `UT_mundane` (−9 cost): seven skills at ×0.8 (−20%), plus cross-trait combat suppression.
  - `UT_antigun` (−6 cost): two skills (Aiming, Reloading) at ×0.5 (−50%).
  - `UT_flatearther` (−4 cost): one skill (MetaGame) at ×0.7 (−30%), plus read-speed penalty.
  - `UT_luddite` (−4 cost): one skill (Electricity) at ×0.6 (−40%).
  - `UT_incomprehensive` (−10 cost): unknown — not traced in this audit.
  - UT_mundane covers far more skills than any peer (seven vs. one or two) but at a shallower per-skill rate (−20% vs. −40% to −50%). The breadth-vs-depth tradeoff distinguishes it clearly. The −9 cost is the highest among traced XP-penalty peers and is justified by the number of skills affected plus the cross-trait suppression bonus.
- Combat suppression note: the suppression of UT_actionhero and UT_martial is a meaningful secondary cost for players who stack these traits. However, the UT_mundane Lua itself does not implement the suppression — it is entirely handled by guard checks in the other traits' Lua files. If new combat-buff traits are added to UT in the future, they must each add their own mundane guard or the suppression description becomes inaccurate.
- Cost verdict: reasonable. Seven broad −20% XP penalties plus full suppression of two combat trait classes at −9 points is proportionate and well-differentiated from peers. No change recommended.

## Regression Proof

- Recognised-trait list: `"UniversalTraits:UT_mundane"` appears on line 261 of `run_tests.lua` — the trait ID is known to the test harness.
- Existing test block: one test exists referencing UT_mundane — `"actionhero skipped when player has UT_mundane"` (run_tests.lua lines 597–610). This test:
  1. Builds a `MockActionPlayer` with both `UniversalTraits:UT_actionhero` and `UniversalTraits:UT_mundane`.
  2. Fires `Events.OnWeaponHitCharacter`.
  3. Asserts `target:getHealth() == 100` (unchanged), proving the mundane guard in UT_actionhero returns early.
- What the existing test proves:
  - The mundane guard in `UT_actionhero.lua` (line 18) fires and correctly suppresses the crit path when the player has `UT_mundane`.
  - `UTCore.hasTrait` correctly identifies the trait from the mock trait list.
- What the existing test does NOT prove:
  1. The `onNewGame` handler in `UT_mundane.lua` is ever loaded or fires without error.
  2. Any of the seven `UTCore.applyXPMultiplier` calls execute.
  3. Any of the seven `UT_xpMult_*` keys are written to mod data.
  4. The UTCore_XPHook correctly applies −20% on any of the seven affected perks.
  5. The martial suppression path (`UT_martial.applyBonusDamage` returning `0`) is exercised for a player with `UT_mundane`.
  6. The `UT_mundane.lua` file is loaded at all — there is no `dofile` for it in `run_tests.lua`.
- Minimum tests needed:
  1. Add `dofile` for `UT_mundane.lua` in `run_tests.lua`.
  2. Add a test that fires `OnNewGame` with `UniversalTraits:UT_mundane` and asserts all seven `UT_xpMult_*` keys are `0.8`:
     - `UT_xpMult_Woodwork == 0.8`
     - `UT_xpMult_Cooking == 0.8`
     - `UT_xpMult_Doctor == 0.8`
     - `UT_xpMult_Mechanics == 0.8`
     - `UT_xpMult_Electrical == 0.8`
     - `UT_xpMult_Aiming == 0.8`
     - `UT_xpMult_Reloading == 0.8`
  3. Add a test that fires `OnWeaponHitCharacter` with a player having both `UT_martial` and `UT_mundane` and asserts `UT_martial.applyBonusDamage` returns `0` (or that target health is unchanged).

## Final Verdict

- Source origin: partial — `ToadTraits:mundane` from More Traits confirmed as a dynamic removal trait via the More Traits Dynamic runtime. The base static penalty (static XP reduction or stat effects applied before dynamic removal) was not confirmed from source files in the installed-mods index. The UT implementation is a redesign to a pure static XP-penalty model; the dynamic removal mechanic is deliberately absent.
- UT implementation: redesign — source `mundane` in More Traits is primarily a dynamic trait removed by dealing cumulative damage. UT replaces this with seven permanent −20% XP multipliers across broad non-combat and combat skills, plus passive cross-trait suppression of UT_actionhero and UT_martial. There is no dynamic removal path in UT.
- Description: accurate — all seven skills are named, the multiplier value (×0.8, −20%) is correct, and the combat suppression of Martial Artist and Action Hero is called out explicitly. No inaccuracies found.
- Balance: reasonable — −9 cost for seven broad XP penalties plus cross-trait suppression is well-differentiated from narrower/deeper peers. No change recommended.
- Regression proof: partial — the actionhero/mundane suppression path has one test. The `UT_mundane.lua` onNewGame handler is never loaded or exercised in the test suite; all seven XP multiplier writes are unverified.
- Potential bug: the perk key `"Electrical"` used in `UT_mundane.lua` may not match the canonical PZ engine key for the Electrical skill. `UT_luddite.lua` uses `"Electricity"` for the same skill. If `"Electrical"` is not a valid perk key, the `UT_xpMult_Electrical` mod data key would be written but never read by the XP hook, silently dropping the Electrical XP penalty. This must be verified against the PZ perk enum (`Perks.Electrical` vs. `Perks.Electricity`) in the B42 codebase.
- Open gaps:
  1. No `dofile` for `UT_mundane.lua` in `run_tests.lua`; the onNewGame handler has zero test coverage.
  2. All seven `UT_xpMult_*` mod data writes are untested.
  3. The `"Electrical"` perk key in UT_mundane.lua is suspect — `UT_luddite.lua` uses `"Electricity"` for what appears to be the same skill. Verify the correct PZ B42 perk key name; if `"Electricity"` is correct, fix UT_mundane.lua to match.
  4. No test exercises the `UT_martial` + `UT_mundane` suppression path (`applyBonusDamage` returning `0`).
  5. The cross-trait suppression (actionhero, martial) is implemented in those traits' Lua files, not in UT_mundane.lua. Any future combat-buff trait that should be suppressed by mundane must add its own guard; there is no central suppression registry.
  6. Source static penalty for the original `ToadTraits:mundane` (before dynamic removal) was not verified from installed-mods files. The extent to which UT's XP model faithfully represents or diverges from the original static effect is unconfirmed.
