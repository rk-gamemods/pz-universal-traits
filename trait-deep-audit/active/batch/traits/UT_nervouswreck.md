# UT_nervouswreck

## Trait Summary
- UT trait id: UT_nervouswreck
- Source mod: Dynamic Traits Expanded Moodles (`DynamicTraitsExpandedMoodles` / `Dynamic-Traits-main`)
- Source trait id: `NervousWreck` (referenced via `player:HasTrait("NervousWreck")`, `player:getTraits():add("NervousWreck")`, `player:getTraits():remove("NervousWreck")`)
- Current cost: -4
- PRD cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMPillsTraits.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMMainFile.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/NPCs/DTEMMainCreationMethods.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/Translate/EN/UI_EN.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTPillsTraits.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/shared/NPCs/DTMainCreationMethods.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/shared/Translate/EN/UI_EN.txt`
- Source trigger path (B41/base DT): `Events.EveryTenMinutes` → `DTEveryTenMain()` → `DTnervousWreckTrait(player)`. The function tracks a counter `DTPillsBeta`; if that counter exceeds 48 and the player does not already hold `"NervousWreck"`, the trait is added. While the trait is active and beta-blockers have not been consumed recently, `DTincreaseStress(player, 0, 0.1)` is called every ten minutes — adding +0.1 stress per ten in-game minutes. Consuming beta-blocker pills decrements the counter; once the counter falls to ≤ 48 and the trait is held, it is removed.
- Source trigger path (B42 DTEM): `Events.EveryTenMinutes` → `DTEMMainFile.lua` calls `DTEMnervousWreckTrait(player)`. The B42 version uses a counter `DTEMnervousWreckTrait` (cap ±720); when `DTEMisNervousWreck == true` and beta-blockers have not been consumed recently, the counter increments by 1 per tick. When the counter exceeds 0 the `"NervousWreck"` trait is added; when beta-blockers are active the counter decrements by 1 per tick (or by 48 per dose consumed), and when it falls to ≤ 0 the trait is removed. While the trait is held and the player is in the `NervousWreck` path, `DTEMincreaseStress(player, 0, 0.1)` fires. The `DTEMisNervousWreck` flag is set probabilistically in `DTEMPillsTraits.lua` (random-chance evaluation), and the beta-blocker treatment counter is decremented by 48 per dose.
- Source behavior summary: in the source, NervousWreck is a dynamic in-play condition — not a fixed character-creation choice. It develops when a random anxiety-prone flag (`DTEMisNervousWreck`) is set, accumulates via a tick counter, and manifests by adding the `"NervousWreck"` trait when the counter crosses a threshold. While active it raises stress by +0.1 per ten in-game minutes. It is treated with beta-blockers, which decrement the counter and eventually remove the trait. The trait has no direct effect on `panicReductionValue`; its mechanic is a stress-rate increase combined with a pharmaceutical treatment path.
- Source cost: -4 (verified: `TraitFactory.addTrait("NervousWreck", ..., -4, ...)` in both `DTMainCreationMethods.lua` and `DTEMMainCreationMethods.lua`)
- Source description (B41 and B42, identical): `"You are anxious by nature. Stressful situations affect you more strongly."` (both `media/.../UI_EN.txt` and `42.0/.../UI_EN.txt`)

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_nervouswreck = CharacterTrait.register("UniversalTraits:UT_nervouswreck")` (line 276, both `media/registries.lua` and `release/` mirror, under the `-- PHASE 3c -- EVENT-DRIVEN TRAITS` block)
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_nervouswreck`, `Cost = -4`, `IsProfessionTrait = false`, `DisabledInMultiplayer = true`. No `MutuallyExclusiveTraits` field is present.
- Translation strings present: yes — `UI_UT_nervouswreck = "Nervous Wreck"`, `UI_UT_nervouswreckDesc = "Your nerves are always close to the edge. Each panic event adds +0.3 to panic. Additionally, every 10 in-game minutes while stress is above 0.7, panic increases by +0.05."` (both `UI_EN.txt` and `UI.json`)
- Exclusions/grants: none — no `MutuallyExclusiveTraits` field in the script definition
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_nervouswreck.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/scripts/UT_character_traits.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
- Event registrations: `Events.OnPlayerUpdate.Add(onPlayerUpdate)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` only
- Runtime chain (plain language):
  1. `Events.OnPlayerUpdate` fires once per game update tick (~60 times per real second at 1× speed).
  2. `onPlayerUpdate(player)` receives the player instance directly (not via `getPlayer()`).
  3. `player:getModData()` is retrieved into `bd`; `player:getBodyDamage()` into `bodyDamage`. If `bodyDamage` is nil the function returns early.
  4. `UTCore.hasTrait(player, TRAIT_ID)` checks whether the player holds `"UniversalTraits:UT_nervouswreck"`.
  5. `bd["UT_nervouswreck_applied"]` is checked to determine if the reduction has already been applied this session.
  6. **Acquisition branch** (`hasTrait and not isApplied`): reads `bodyDamage:getPanicReductionValue()`, stores it in `bd["UT_nervouswreck_base"]`, writes `current * 0.30` back via `bodyDamage:setPanicReductionValue(...)`, sets `bd["UT_nervouswreck_applied"] = true`. This branch runs exactly once per trait acquisition (until the trait is removed and re-added).
  7. **Removal branch** (`not hasTrait and isApplied`): reads `bd["UT_nervouswreck_base"]`; if not nil, restores it via `bodyDamage:setPanicReductionValue(base)`. Clears `bd["UT_nervouswreck_applied"]` and `bd["UT_nervouswreck_base"]`.
  8. No per-tick delta is applied on subsequent updates; after the one-shot acquisition the function falls through both branches and does nothing each tick.
- Actual behavior (exact values): on the first `OnPlayerUpdate` tick after the trait is acquired, `panicReductionValue` is reduced to 30% of whatever value was current at that moment. The reduction persists until the trait is removed, at which point the original snapshotted value is restored. The engine's `BodyDamage.ReducePanic()` call uses `panicReductionValue` as its per-tick decay multiplier, so a 70% reduction in that value produces a 70% reduction in the rate at which panic drains each tick. No per-event panic bonus, no stress threshold check, no periodic timer fires.
- Engine context (from Lua file header, verified against BodyDamage.java): default `panicReductionValue = 0.06`; decay per update ≈ `value × getThirtyFPSMultiplier() + value × monthsSurvived`; `BodyDamage.Update()` runs ~60× per real minute at 1× speed. With a 70% reduction from the default:
  - New player: ~0.54 panic/min (was ~1.8; full panic drain ~185 min vs. ~56 min)
  - 5-month veteran: ~5.94 panic/min (was ~19.8; full drain ~17 min vs. ~5 min)
  - Sleeping doubles the reduced rate (unchanged engine behavior)

## Description Integrity
- Display name check: "Nervous Wreck" — matches source name exactly; accurate.
- Description check: `"Your nerves are always close to the edge. Each panic event adds +0.3 to panic. Additionally, every 10 in-game minutes while stress is above 0.7, panic increases by +0.05."`
- Mismatch — **severe**: the description describes two mechanics that do not exist in the code:
  1. "Each panic event adds +0.3 to panic" — there is no `OnPlayerUpdate` or event handler that increments panic on any event trigger. No panic-event hook is registered anywhere in this file.
  2. "Every 10 in-game minutes while stress is above 0.7, panic increases by +0.05" — there is no `EveryTenMinutes` handler and no stress-threshold check anywhere in this file.
- The actual mechanic — scaling `panicReductionValue` to 30% of its current value, thereby slowing panic *recovery* by 70% — is not mentioned in the description at all. The description implies panic is actively increased; the code makes panic slower to drain. These are opposite in sign from a player's perspective: the description suggests an *additive panic source*, the code implements a *recovery rate penalty*.
- The source description (`"You are anxious by nature. Stressful situations affect you more strongly."`) does not match either — the source's mechanic was a +0.1 stress/10-min rate, which is also absent from the UT implementation.
- The file header comment (`"Nervous wreck: slows panic recovery by 70% by scaling down the engine's panicReductionValue"`) is accurate to the code; the player-facing description is not.

## Balance Review
- Upside: none
- Downside: panic recovery is permanently 70% slower for as long as the trait is held. Once panic is triggered, the character takes roughly 3.3× longer to calm down under all circumstances compared to an unmodified character.
- Uptime: continuous — the reduction is applied on first tick after acquisition and persists until trait removal; no condition gates the ongoing effect
- Severity by game phase:
  - Early game (new player, monthsSurvived ≈ 0): panic decay drops from ~1.8/min to ~0.54/min; reaching zero from full panic takes ~185 real seconds instead of ~56 — a material survival disadvantage in zombie encounters
  - Late game (5-month veteran): decay drops from ~19.8/min to ~5.94/min; slower but veterans rarely stay panicked long regardless; relative impact shrinks as months-survived term dominates
- Cost: -4, matching both the PRD target and the source cost. The source was a dynamic trait; the UT version is a permanent fixed penalty. The 70% recovery slowdown is a real and meaningful disadvantage, particularly early-game. -4 is defensible.
- Mod-compatibility concern: the snapshot-and-restore pattern means UT_nervouswreck is reasonably safe around other mods that also modify `panicReductionValue`, since it reads the current value rather than writing a hardcoded absolute. However, **SomewhatTraits** (`SomewhatTraitsCore`) completely replaces the vanilla panic system by setting `bodyDamage:setPanicReductionValue(0.0)` and reimplementing panic decay from scratch in its own `OnTick` handler. If SomewhatTraits is loaded alongside UT_nervouswreck:
  - SomewhatTraits zeroes `panicReductionValue` each tick; the UT snapshot would capture `0.0` and write back `0.0 × 0.30 = 0.0` — no change, trait effectively silenced.
  - Alternatively, whichever handler runs later each tick wins. The interaction is unresolved and the UT file contains no guard for this case.
- Stack or exclusion notes: no `MutuallyExclusiveTraits` defined. There are no panic-adjacent UT traits in the same exclusion group. `UT_fearful` and `UT_scardycat` are adjacent in the registry (Phase 3c) but neither excludes `UT_nervouswreck` in the script definition. Whether stacking all three is intentional is not documented.

## Regression Proof
- Existing test: `"UniversalTraits:UT_nervouswreck"` appears on line 296 of `run_tests.lua`, within the Phase 3c Event-Driven batch list. This confirms the trait ID is included in the batch registration sweep.
- What it proves: the trait ID is registered in UTTraitsRegistries. Nothing about runtime behavior is verified.
- Missing proof:
  - No test confirms that on the first `OnPlayerUpdate` tick after acquiring the trait, `panicReductionValue` is set to exactly 30% of the snapshotted baseline.
  - No test confirms that when the trait is absent and `isApplied == true`, the original value is restored on the next tick.
  - No test confirms that subsequent ticks after acquisition are no-ops (i.e., the value is not re-multiplied on every update, which would compound to near-zero within seconds).
  - No test confirms that `getBodyDamage()` returning nil is handled without error.
  - No test verifies behavior when another mod has already zeroed `panicReductionValue` before UT_nervouswreck applies.

## Final Verdict
- Source origin: Dynamic Traits Expanded Moodles — `NervousWreck` trait; in source this is a dynamic in-play condition (not a character-creation choice) that develops via a stress/anxiety counter, raises stress by +0.1 per ten in-game minutes while active, and is treated with beta-blockers; the source does not interact with `panicReductionValue` at all
- UT implementation: original mechanic — the source's stress-rate increase and dynamic acquisition/treatment system were not ported; instead UT implements a one-shot snapshot-and-scale on `panicReductionValue`, permanently reducing panic recovery rate by 70% for the life of the trait; the mechanic is functional and real, but it is a novel design rather than an adaptation of the source
- Description: **severely wrong** — the player-facing description claims two specific, quantified mechanics ("+0.3 panic per panic event" and "+0.05 panic per 10 min when stress > 0.7") that have no corresponding code; the actual mechanic (70% slower panic recovery via `panicReductionValue` scaling) is entirely absent from the description; this is the highest-priority defect in this trait
- Balance: cost -4 matches PRD and source; the 70% recovery slowdown is a genuine and meaningful disadvantage, most impactful early-game; cost is appropriate for the actual mechanic
- Regression proof: missing — batch sweep confirms registration only; no behavioral test exists
- Action needed:
  1. **Description fix (required — critical):** rewrite the player-facing description to accurately reflect the actual mechanic: panic fades significantly more slowly. Example: "Panic grips you and lets go slowly. Your panic recovery rate is reduced by 70%." Remove all references to panic-per-event bonuses and stress-threshold periodic triggers.
  2. **Test (required):** add a unit test that mocks `bodyDamage:getPanicReductionValue()` returning a known value, fires `OnPlayerUpdate` with a player holding the trait, and asserts that `getPanicReductionValue()` is then `0.30 × baseline`. Add a parallel removal test. Add a no-op test confirming the second tick does not re-multiply.
  3. **SomewhatTraits guard (recommended):** add a nil/zero guard on the snapshotted value before applying. If `current == 0`, skip or defer application; emit a warning log if possible. Document the incompatibility.
  4. **Exclusion review (recommended):** decide whether `UT_fearful` and `UT_scardycat` should be mutually exclusive with `UT_nervouswreck`. All three are Phase 3c panic-adjacent negative traits; stacking them is currently allowed and undocumented.
- Open gaps:
  - The description is the most dangerous defect: players selecting this trait based on the UI description will expect panic spikes on encounters and a stress-gated periodic penalty; they will receive neither. What they actually receive (slower panic drain) is a meaningfully different survival experience.
  - The snapshot pattern creates a latent re-application risk: if the trait is removed and re-added mid-session while another mod has changed `panicReductionValue` in the interim, the new snapshot captures the modified value, not the original baseline. This is noted in the file header as an intentional design choice ("if another trait has already modified panicReductionValue, we reduce *that* value by 70%"), but it means stacking order with other panic-modifying traits produces different results depending on which trait is acquired first.
  - `DisabledInMultiplayer = true` is consistent with other Phase 3c traits but was not an explicit source behavior; the source operated on `EveryTenMinutes` with a per-player counter, which would have been compatible with multiplayer in principle. The UT mechanic uses `OnPlayerUpdate` with `player:getBodyDamage()`, which is also per-player. Whether the multiplayer disable is intentional for this specific trait or inherited by convention should be confirmed.
  - No source analog for the `panicReductionValue` approach exists in the installed mods research corpus; this is an original UT design whose conceptual link to "nervous wreck" (anxious disposition → slower calming) is reasonable but distinct from both the DTEM source behavior and the stated description.
