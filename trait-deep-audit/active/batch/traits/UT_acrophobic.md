# UT_acrophobic

## Trait Summary

- UT trait id: UT_acrophobic
- Source mod: SomewhatTraits (SomewhatTraitsCore)
- Source trait id: SWTraits:SWAcrophobic (trait key: "SWAcrophobic")
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/scripts/SWTraits_character_traits.txt` (lines 157–165) — B42.15 script definition
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (lines 112, 413–431, 1070) — legacy client
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` (lines 254–267) — B42.15 server
- Source cost: -3 (B42.15 script definition; UT raised this to -4).
- Source description: not directly available in reviewed files; trait name is "SWAcrophobic".
- Source trigger path:
  - Legacy (SWSomewhatTraitsCore.lua): `Events.OnTick.Add(SWAcrophobic)` — fires every game tick.
  - B42.15 server (SWTraitsCore_server.lua): `Events.OnTick.Add(SWAcrophobic)` — fires every game tick.
- Source behavior (legacy): When `z > 0`, caps `z` at 5. Computes `extraStress = timeMultiplier * z * 0.01`. If the player is outside, doubles `extraStress`. Adds extraStress to current stress (excluding cigarette stress), capped at `maxStress`. Fires every tick, so the multiplier and time scaling govern the actual rate.
- Source behavior (B42.15 server): When `z > 0`, caps `z` at 5. Computes `extraStress = z * 0.01`. If the player is outside, doubles `extraStress` (max `z * 0.02`). Calls `stats:add(CharacterStat.STRESS, extraStress)` — adds to the **stress** stat, not panic.
- Source stat affected: **stress** (both legacy and B42.15). Neither source version touches panic.
- Source multipliers: height-scaled (floor 1–5 maps to 0.01–0.05 stress per tick, doubled outdoors). Effect is proportional to altitude and indoor/outdoor state.
- Source mutual exclusions: none observed in reviewed script files.
- Source `DisabledInMultiplayer`: `false` (B42.15 script definition, line 160).

## Current UT Evidence

### Structure

- Registered in test harness: yes (`run_tests.lua` line 301, grouped in "Phase 3c — Event-Driven")
- Defined in UT_character_traits.txt: yes (lines 2020–2028)
  - `Cost = -4`
  - `DisabledInMultiplayer = true`
  - `IsProfessionTrait = false`
  - No `MutuallyExclusiveTraits` declared
- Translation strings present: yes
  - `UI_UT_acrophobic = "Acrophobic"`
  - `UI_UT_acrophobicDesc = "Heights make your stomach drop and your hands shake. The higher up you are, the harder it is to function."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_acrophobic.lua`)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_acrophobic.lua` (full file, 17 lines)
  - `media/scripts/UT_character_traits.txt` (lines 2020–2028)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 626–627)
  - `test/run_tests.lua` (line 301)
- Event registrations:
  - `Events.EveryOneMinute.Add(onEveryOneMinute)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — trait check inside the handler
- Runtime chain (plain language):
  1. Once per in-game minute: retrieves the local player. If absent, exits.
  2. Checks `UTCore.hasTrait(player, TRAIT_ID)`. If the trait is absent, exits.
  3. If `player:getZ() > 0` (any floor above ground): calls `player:getStats():setPanic(math.min(1, stats:getPanic() + 0.05))`.
  4. Effect: adds +0.05 to the panic stat every in-game minute while above ground level, capped at the maximum value of 1.0.
- Actual behavior (exact values):
  - Trigger condition: `player:getZ() > 0` — any elevation above z=0 (first storey and above).
  - Panic increment per minute: flat +0.05, regardless of floor number.
  - Panic cap: `math.min(1, ...)` — panic cannot exceed 1.0.
  - No height scaling: z=1 and z=10 produce identical increments.
  - No indoor/outdoor distinction: the UT implementation ignores whether the player is outside or inside.
  - Stat affected: **panic** — not stress. This is a full divergence from both source versions.
  - Frequency: `EveryOneMinute` (once per real-time or game-time minute) versus source's `OnTick` (every frame).

## Description Integrity

- Display name check: "Acrophobic" — matches source trait name.
- Description check: `UI_UT_acrophobicDesc` reads: "Heights make your stomach drop and your hands shake. The higher up you are, the harder it is to function."
- Issues found:
  1. **"The higher up you are" is false.** The description implies altitude scaling. The runtime applies a flat +0.05 panic per minute at any `z > 0`, with no height multiplier. A player on the first storey accumulates panic at the same rate as one on the twentieth floor. The source scaled effect by altitude (z capped at 5 floors, doubled outdoors). The UT implementation does neither.
  2. **Stat mismatch between description and code.** The description says "your stomach drop and your hands shake" — flavour consistent with either panic or stress. However, the code raises **panic** while both source versions raised **stress**. The description does not name the affected stat, so this is not a textual lie, but it is a material behavioral divergence that players familiar with the source mod will not expect.
  3. **No indoor/outdoor distinction disclosed or implemented.** The source doubled the effect outdoors. The UT version does not distinguish. The description does not mention this either; since UT does not implement it, this is consistent but represents a removed design feature.
  4. **Panic as the chosen stat carries secondary consequences the description does not mention.** Panic in PZ triggers the Panic moodle, which impairs aiming accuracy. A trait that continuously raises panic while above ground is more mechanically impactful than one that raises stress, because panic directly penalises combat. This secondary effect (accuracy loss while elevated) is not communicated in the description.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside: +0.05 panic per in-game minute while `z > 0`, capped at 1.0.
- Uptime: active whenever the player occupies any floor above ground. In a building-heavy playthrough this is near-constant. In rural play it is negligible. There is no respite mechanic short of descending to ground level.
- Rate analysis: panic fills from 0 to 1.0 in 20 in-game minutes of continuous elevation. Panic decays naturally over time when stimuli are absent; the net effect depends on the game's natural panic decay rate, which is not governed by this file. If decay exceeds +0.05/min, the trait has no sustained effect at low floors; at high floors the same flat rate applies regardless.
- Source cost comparison: the source cost was -3. UT charges -4 despite implementing a mechanically stronger effect (panic vs. stress) with a flat height-blind increment on a much slower tick (once per minute vs. every frame — but the per-tick amounts are also smaller in source, so direct comparison requires the timeMultiplier value). The net magnitude shift is not established without knowing the source `timeMultiplier`, but switching to panic (which has combat consequences) rather than stress is a qualitative escalation.
- Peer comparison:
  - `UT_fearful` (if present) may also raise panic; stacking is not excluded since no mutual exclusions are declared.
  - `UT_nervouswreck` (if present) — same consideration.
  - `UT_acrophobic` has a purely conditional downside: it is inert at ground level. For players who avoid buildings or use single-storey structures, the trait provides nearly free points.
- Stack or exclusion notes: no `MutuallyExclusiveTraits` are declared. No natural conflicts are excluded.
- Cost verdict: -4 is plausible given the direct panic impact (which is more harmful than stress in combat contexts), but the flat height-blind rate and building-avoidance escape make the trait effectively zero-cost in certain playstyles. A cost of -3 (matching source) or -4 with height scaling would be more defensible.

## Regression Proof

- Existing test: `UT_acrophobic` is listed in the Phase 3c registration sweep (`run_tests.lua` line 301), which confirms the trait ID is registered with `CharacterTrait`. This is the only observed test reference.
- What it proves: the trait ID `"UniversalTraits:UT_acrophobic"` exists in the CharacterTrait registry. It does not test runtime behavior.
- Missing proof:
  1. No test that `EveryOneMinute` fires `onEveryOneMinute` and raises panic by exactly +0.05 when `z > 0`.
  2. No test that `z == 0` (ground level) suppresses the panic increment.
  3. No test that panic is capped at 1.0 when the pre-increment value is already >= 0.95.
  4. No test that the handler exits cleanly when `getPlayer()` returns nil.
  5. No test that the handler exits when the player does not have the trait.
- Minimum next test if needed: "acrophobic: panic increments by 0.05 when above ground" — mock `getPlayer()` returning a player with the trait and `getZ() = 1`, set initial panic to 0.0, fire `EveryOneMinute`, assert panic equals 0.05.

## Final Verdict

- Source origin: proven — SomewhatTraits `SWAcrophobic` is the confirmed source; legacy client and B42.15 server files located and read. Source cost (-3) does not match UT cost (-4); UT increased the cost by 1.
- UT implementation: drifted — the core concept (penalty while above ground level) is preserved, but with significant divergences:
  1. **Stat substitution**: source applied to **stress**; UT applies to **panic**. This changes the moodle triggered, the secondary gameplay consequences (panic impairs aiming; stress does not directly), and the player experience.
  2. **Height scaling removed**: source scaled the increment linearly by floor number (z, capped at 5), and doubled it outdoors. UT applies a flat +0.05 regardless of floor and ignores indoor/outdoor state.
  3. **Event frequency**: source fired on `OnTick` (every frame); UT fires on `EveryOneMinute`. The absolute rates are different; without the source `timeMultiplier` value the magnitudes cannot be directly compared, but the tick frequency difference is structural.
  4. **Multiplayer**: source allowed multiplayer (`DisabledInMultiplayer = false`); UT disables it (`DisabledInMultiplayer = true`). This is a UT-wide policy decision and may be intentional.
- Description: partially misleading — "the higher up you are" implies altitude scaling that does not exist in the code. The stat affected (panic vs. stress) and its secondary effects (aiming penalty) are not disclosed. The description is otherwise tonally appropriate and not factually incorrect about the trigger condition (`z > 0`).
- Balance: conditionally acceptable at -4, but the flat unscaled rate and the complete avoidability via ground-level play weaken the actual downside. The panic stat choice is a qualitative escalation over the source's stress choice, partially offsetting the removed height scaling. No mutual exclusions means it can stack with other panic-raising traits.
- Regression proof: registration confirmed; zero behavioral tests exist for this trait.
- Action needed:
  1. **Fix description** to remove "the higher up you are" (or implement height scaling to match the claim). Either change the code to scale by `z` or change the description to "any height above ground" with the flat rate disclosed.
  2. **Evaluate stat choice** — decide deliberately whether panic (with its combat aiming consequence) or stress (matching source) is the intended design. Document the decision. If panic is intentional, consider mentioning the aiming impact in the description.
  3. **Consider re-adding height scaling** — the source's `z * 0.01` formula (capped at z=5, doubled outdoors) produced a more nuanced and thematically accurate effect. The flat rate removes the design incentive to stay on lower floors rather than avoiding buildings entirely.
  4. **Review cost** — if height scaling is restored and the stat remains panic, -4 is reasonable. If the trait remains flat and height-blind with no indoor modifier, -3 (matching source) is more appropriate.
  5. **Add behavioral tests** for: panic increment at z > 0, suppression at z = 0, cap at 1.0, and handler guard conditions.
- Open gaps:
  - Source `timeMultiplier` value is not available in the reviewed files; the per-minute rate of the UT version cannot be quantitatively compared to the per-tick source rate without it.
  - No mutual exclusions exist in UT or source; consider whether stacking with other panic-raising traits (`UT_fearful`, `UT_nervouswreck`, `UT_scardycat`) is intentional given all share the panic stat.
