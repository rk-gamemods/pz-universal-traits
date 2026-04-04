# UT_antigun

## Trait Summary

- UT trait id: UT_antigun
- Source mod: More Traits (ToadTraits)
- Source trait id: ToadTraits:antigun
- Current cost: -6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (trait definition, lines 45–54)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (translation strings, lines 151–152)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (runtime implementation — XP penalty, weapon stat mutation, and unhappiness hook)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42/media/lua/client/MoreTraits - Dynamic.lua` (dynamic removal logic, lines 544–559)
- Source trait definition (ToadTraits.txt, lines 45–54):
  - `Cost = -6`
  - `DisabledInMultiplayer = false`
  - `MutuallyExclusiveTraits = ToadTraits:noxpshooter; ToadTraits:progun; ToadTraits:specguns; ToadTraits:terminator`
- Source trigger paths:
  1. `Events.AddXP.Add(SpecializationAndAntiGun)` — fires on every XP gain event; if the player has `antigun` and the perk is `Perks.Aiming`, adds a 0.25 penalty multiplier (up to a cap of 0.95), then calls `MT_AddXP(player, perk, -xpToRemove)` to subtract that fraction of the earned XP. The net result is −25% Aiming XP only (not Reloading in source).
  2. `Events.OnEquipPrimary` / `Events.OnEquipSecondary` → `TerminatorGun(player)` — when a firearm is equipped, sets `item:setAimingTime(OGaimingtime * 0.8)` and `item:setMaxRange(math.max(5, OGrange - 5))` while the player holds `antigun`. State is cached in `itemdata.MTstate = "antigun"` and reversed when the trait is absent.
  3. `Events.OnPlayerUpdate` → same `TerminatorGun(player)` — while the player is in an aiming state (`PlayerAimState` or `PlayerStrafeState`) and holds a firearm with `antigun`, adds `+0.6` to `CharacterStat.UNHAPPINESS` each update tick (generates sadness while aiming).
- Source behavior:
  - Aiming XP: −25% (penalty added via XP subtraction on `Perks.Aiming` only; Reloading is not penalised in source).
  - Weapon stats (on equip): aiming time reduced to ×0.8 of base; max range reduced by 5 tiles (floored at 5).
  - Mood: +0.6 unhappiness per update tick while aiming a firearm.
  - Dynamic removal (More Traits - Dynamic): if enabled, the trait is removed at runtime when Aiming reaches a configurable skill threshold (default 6) and, optionally, a firearm kill count threshold (default 600).
- Source EN description: "You protest against guns and have no experience with them, making you worse at using them than others. You take longer to aim, can not shoot far and become sad while using guns. You receive 25% less aiming XP."
- Source cost: −6 points.

## Current UT Evidence

### Structure

- Registered in registries.lua: unknown — not verified in this audit; the trait ID is present in the `run_tests.lua` recognised-trait list (line 264).
- Defined in UT_character_traits.txt: yes (lines 1398–1407)
  - `Cost = -6`
  - `DisabledInMultiplayer = true`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_noxpshooter`
- Translation strings present: yes (UI_EN.txt lines 428–429)
  - `UI_UT_antigun = "Anti-Gun Activist"`
  - `UI_UT_antigunDesc = "You spent years campaigning against firearms and never touched one. XP gain in Aiming and Reloading is reduced to ×0.5 (−50%)."`
- Exclusions/grants correct: partial mismatch — source excluded `noxpshooter`, `progun`, `specguns`, and `terminator`; UT excludes only `UT_noxpshooter`. The omission of `UT_progun`, `UT_specguns`, and `UT_terminator` may or may not be intentional; those traits may not exist in UT.
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_antigun.lua`)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_antigun.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1398–1407)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 428–429)
  - `test/run_tests.lua` (line 264 — trait in recognised list only)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` (lines 41–43 — `applyXPMultiplier` implementation)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua` (lines 19–58 — XP hook logic)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)` — fires once at new game start
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — presence check
  - `UTCore.applyXPMultiplier(player, "Aiming", 0.5)` — writes `UT_xpMult_Aiming = 0.5` to player mod data
  - `UTCore.applyXPMultiplier(player, "Reloading", 0.5)` — writes `UT_xpMult_Reloading = 0.5` to player mod data
- Runtime chain (plain language):
  1. On new game, if the player has `UniversalTraits:UT_antigun`, `UTCore.applyXPMultiplier` is called twice: once for `"Aiming"` at multiplier `0.5`, once for `"Reloading"` at multiplier `0.5`.
  2. Each call writes `UT_xpMult_<perkName> = 0.5` into player mod data.
  3. `UTCore_XPHook.lua` intercepts every `Events.AddXP` event. For each XP gain on Aiming or Reloading, it reads the stored multiplier (0.5), computes `bonus = math.floor(amount * (0.5 - 1.0)) = math.floor(amount * -0.5)`, and calls `player:getXp():AddXP(perk, bonus, false, false, false)` to subtract half the earned XP. Net effective rate: ×0.5 (−50%).
- Actual behavior (exact values):
  - Aiming XP: ×0.5 (−50%) applied permanently from new game start.
  - Reloading XP: ×0.5 (−50%) applied permanently from new game start.
  - No weapon stat changes. No unhappiness effect. No dynamic removal.

## Description Integrity

- Display name check: "Anti-Gun Activist" — matches source ("Anti-Gun Activist" in More Traits EN); accurate.
- Description check: `UI_UT_antigunDesc` = "You spent years campaigning against firearms and never touched one. XP gain in Aiming and Reloading is reduced to ×0.5 (−50%)." — this correctly describes both runtime effects with exact values and correct sign language.
- Source description for comparison: "You protest against guns and have no experience with them, making you worse at using them than others. You take longer to aim, can not shoot far and become sad while using guns. You receive 25% less aiming XP."
- Missing or misleading details: The UT description is internally accurate for the UT implementation. It does not mention weapon stat changes or unhappiness because those source effects are not implemented in UT. No inaccuracy. However, the description does not clarify that Reloading XP is also penalised by the same amount; the single "×0.5 (−50%)" value covers both, which is correct but could be read as ambiguous. The grouped format is acceptable.

## Balance Review

- Upside: none — pure negative trait.
- Downside: −50% Aiming XP and −50% Reloading XP, applied permanently from new game start via the `UTCore_XPHook` subtraction path.
- Uptime: Both penalties are permanent; applied once at new game and active for the entire run.
- Peer comparison:
  - `UT_antigun` (−6 cost): −50% Aiming XP and −50% Reloading XP. Two skills, steeper multiplier.
  - `UT_flatearther` (−4 cost): −30% MetaGame XP and −30% reading speed. Two penalties, shallower rate.
  - `UT_luddite` (−4 cost): −40% Electrical XP. Single skill, one penalty.
  - `UT_noxpshooter` (+3 cost, positive): completely disables Aiming and Reloading XP (UT_xpDisable). Acquiring `UT_noxpshooter` is a masochistic positive trait — players who take it pay points for total lockout. `UT_antigun` at −6 gives half the penalty and is mutually exclusive with it, which is consistent.
- Source comparison: the source trait imposed −25% Aiming XP only (not Reloading), plus weapon stat nerfs (×0.8 aiming time, −5 range) and a mood penalty while aiming. UT applies a larger XP penalty (−50% vs. −25%) across two skills (Aiming and Reloading vs. Aiming only), but drops all the weapon-handling and mood effects. The UT version is narrower in scope but deeper on the XP penalty axis.
- Cost verdict: reasonable. Two permanent −50% XP penalties on the two combat marksmanship skills represent a meaningful long-game disadvantage. −6 points is consistent with the source cost and defensible relative to peers. No change needed.

## Regression Proof

- Existing test: `UT_antigun` appears in the recognised-trait list on line 264 of `run_tests.lua`. This confirms the trait ID is known to the test harness.
- The trait Lua file (`UT_antigun.lua`) is **not loaded** via `dofile` anywhere in `run_tests.lua`. No `dofile` call for `UT_antigun.lua` is present in the file.
- No `test(...)` block exists for `UT_antigun`. The `onNewGame` handler is never fired in the test suite.
- What is proven: the trait ID string is correctly formed and present in the harness's known-trait registry. Nothing else is proven.
- What is not proven:
  1. The `onNewGame` handler fires and executes without error.
  2. `UTCore.applyXPMultiplier(player, "Aiming", 0.5)` is called and writes `UT_xpMult_Aiming = 0.5` to mod data.
  3. `UTCore.applyXPMultiplier(player, "Reloading", 0.5)` is called and writes `UT_xpMult_Reloading = 0.5` to mod data.
  4. The XP hook correctly applies the −50% delta to Aiming and Reloading XP gains at runtime.
- Minimum tests needed:
  1. `dofile` the `UT_antigun.lua` trait file in `run_tests.lua`.
  2. Add a test that fires `OnNewGame` with `UniversalTraits:UT_antigun` and asserts `modData["UT_xpMult_Aiming"] == 0.5`.
  3. Add a second assertion in the same test that `modData["UT_xpMult_Reloading"] == 0.5`.
  4. Optionally, extend the UTCore_XPHook integration test (if one exists) to confirm the subtraction path fires correctly for a mocked Aiming XP gain.

## Final Verdict

- Source origin: proven — `ToadTraits:antigun` from More Traits confirmed. Definition (Cost = −6, four mutual exclusions), EN translation, and runtime implementation traced in More Traits 42.15 source.
- UT implementation: narrowed redesign — the source trait applied −25% Aiming XP only, plus weapon stat nerfs (×0.8 aiming time, −5 max range) and a per-tick unhappiness increase while aiming. UT replaces this with −50% Aiming XP and −50% Reloading XP via the `UTCore_XPHook` multiplier path. Weapon stat changes and the unhappiness effect are not implemented. The redesign increases XP penalty depth and extends it to Reloading while removing all non-XP effects. This is a deliberate scope reduction consistent with UT's XP-modifier trait category.
- Description: accurate — both UT effects (Aiming and Reloading at ×0.5) are correctly stated with exact values. The description does not misrepresent the implementation.
- Balance: reasonable — −6 points for two permanent −50% XP penalties on the primary firearm skills is proportionate. Consistent with source cost. No change recommended.
- Regression proof: absent — the `UT_antigun.lua` file is not loaded in `run_tests.lua` and no test block exercises the handler. The trait has zero runtime test coverage.
- Action needed: test gap — add `dofile` for `UT_antigun.lua` and write a `test(...)` block asserting `UT_xpMult_Aiming == 0.5` and `UT_xpMult_Reloading == 0.5` after firing `OnNewGame`.
- Open gaps:
  1. No test loads or fires the `UT_antigun.lua` `onNewGame` handler.
  2. No test asserts either XP multiplier key is written to mod data.
  3. The mutual exclusion list in UT (`UT_noxpshooter` only) is narrower than the source (four exclusions). Whether `UT_progun`, `UT_specguns`, and `UT_terminator` exist in UT and whether they should be excluded is not verified in this audit.
  4. The source's weapon stat nerfs and aiming-time unhappiness effect are not implemented in UT and are not documented as deliberate omissions anywhere in the trait files.
