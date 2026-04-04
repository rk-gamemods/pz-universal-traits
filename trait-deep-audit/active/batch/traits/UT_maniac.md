# UT_maniac

## Trait Summary

- UT trait id: UT_maniac
- Source mod: SomewhatTraits (SomewhatTraitsCore)
- Source trait id: SWManiac (trait key: "SWManiac")
- Current cost: 4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.12/media/lua/shared/NPCs/SWSomewhatTraits_MainCreationMethods.lua` (line 86) — B42.12 trait registration (cost 4, `false` = positive trait)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.12/media/lua/client/SWSomewhatTraitsCore.lua` (lines 105, 291–312, 1063) — B42.12 legacy client implementation
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.13/media/lua/server/SWTraitsCore_server.lua` (lines 173–184) — B42.13 server implementation
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` (lines 173–184) — B42.15 server implementation (identical to 42.13)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/registries.lua` (line 18) — SWManiac listed at cost 4
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/registries.lua` (line 18) — SWManiac listed at cost 4
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (lines 105, 291–312, 1063) — legacy (non-versioned) client; identical to 42.12 client
- Source cost: 4 (positive trait; confirmed across all versions).
- Source description: not directly available in reviewed files; trait comment in MainCreationMethods reads "reduces unhappinnes and stress when bloody".
- Source trigger path:
  - Legacy client (SWSomewhatTraitsCore.lua): `Events.OnTick.Add(SWManiac)` — fires every game tick.
  - B42.13/42.15 server (SWTraitsCore_server.lua): `Events.OnTick.Add(SWManiac)` — fires every game tick.
- Source behavior (legacy client): On every tick, reads `totalBlood = character:getTotalBlood()`. Computes `extraStress = timeMultiplier * totalBlood * 0.00001` and `extraUnhappyness = timeMultiplier * totalBlood * 0.001`. If current stress (excluding cigarette stress) exceeds `minStress`, subtracts `extraStress` down to `minStress`. If current unhappiness exceeds `minUnhappynessLevel`, subtracts `extraUnhappyness` down to `minUnhappynessLevel`. Effect is proportional to the amount of blood on the character.
- Source behavior (B42.13/42.15 server): On every tick, reads `totalBlood = player:getTotalBlood()`. Computes `extraStress = totalBlood * 0.00001` and `extraUnhappyness = totalBlood * 0.001` (no `timeMultiplier` in B42 server path). Calls `stats:remove(CharacterStat.STRESS, extraStress)` and `stats:remove(CharacterStat.UNHAPPINESS, extraUnhappyness)` unconditionally (no floor clamp visible in the retrieved snippet). Effect scales with blood level.
- Source stats affected: **stress** and **unhappiness** — both reduced proportionally to blood on the character.
- Source trigger condition: blood-scaled; the more blood on the character, the stronger the reduction per tick.
- Source mutual exclusions: `Hemophobic` ↔ `SWManiac` (bidirectional) — confirmed in both legacy `SWSomewhatTraits_MainCreationMethods.lua` (line 123) and B42.13/42.15 `SWTraits_MET.lua` (lines 64–66).
- Source `DisabledInMultiplayer`: not directly confirmed from reviewed files (trait uses `false` as the fifth argument to `TraitFactory.addTrait`, which indicates a positive trait, not the multiplayer flag — that flag is set separately in the script definition, which was not retrieved for this trait).

## Current UT Evidence

### Structure

- Registered in test harness: yes (`run_tests.lua` line 297, grouped in "Phase 3c — Event-Driven (22)")
- Defined in UT_character_traits.txt: yes (lines 1938–1946)
  - `Cost = 4`
  - `DisabledInMultiplayer = true`
  - `IsProfessionTrait = false`
  - No `MutuallyExclusiveTraits` declared
- Translation strings present: yes
  - `UI_UT_maniac = "Maniac"`
  - `UI_UT_maniacDesc = "Combat wakes something up in you. Each time you kill a zombie, stress decreases by −0.15 and boredom decreases by −0.2."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_maniac.lua`)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_maniac.lua` (full file, 13 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1938–1946)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 602–603)
  - `test/run_tests.lua` (line 297)
- Event registrations:
  - `Events.OnZombieDead.Add(onKill)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — trait check inside the handler
- Runtime chain (plain language):
  1. Whenever a zombie dies: the `onKill(player, zombie)` handler fires.
  2. Checks `UTCore.hasTrait(player, TRAIT_ID)`. If the trait is absent, exits.
  3. Calls `player:getStats():setStress(math.max(0, player:getStats():getStress() - 0.15))` — reduces stress by 0.15, floored at 0.
  4. Calls `player:getStats():setBoredom(math.max(0, player:getStats():getBoredom() - 0.2))` — reduces boredom by 0.2, floored at 0.
- Actual behavior (exact values):
  - Trigger condition: `Events.OnZombieDead` — fires once per zombie kill by any means.
  - Stress reduction per kill: flat −0.15, floored at 0 (cannot go negative).
  - Boredom reduction per kill: flat −0.20, floored at 0 (cannot go negative).
  - No blood dependency: the UT implementation ignores blood level entirely — each kill produces the same flat reduction regardless of combat state, weapon, or gore.
  - No minimum floor above 0: stress and boredom are clamped only at 0 — no `minStress` or `minUnhappynessLevel` analogue.
  - Frequency: once per zombie death event — directly kill-triggered rather than tick-based.
  - Stats affected: **stress** and **boredom** — not unhappiness. This is a partial stat substitution from the source.

## Description Integrity

- Display name check: "Maniac" — matches source trait name exactly.
- Description check: `UI_UT_maniacDesc` reads: "Combat wakes something up in you. Each time you kill a zombie, stress decreases by −0.15 and boredom decreases by −0.2."
- Issues found:
  1. **Description is accurate for the UT implementation.** The trigger (kill a zombie), the stat (stress), the value (−0.15), the second stat (boredom), and its value (−0.2) all match the code exactly. No misleading claims are present.
  2. **Stat substitution from source is not disclosed, but is not the description's job.** The source reduced **unhappiness** (not boredom). The UT description names boredom explicitly, which is what the code does. Players not familiar with the source mod will read an accurate description.
  3. **Floor at 0 is not mentioned.** The description says "decreases by −0.15 / −0.2" without noting that neither stat can go below 0. This is a minor omission that is standard practice across the suite and unlikely to mislead players.
  4. **No mention of the absence of a blood condition.** The source's effect was blood-scaled (more blood = stronger reduction per tick). The UT implementation is unconditional per kill. The description does not allude to a blood condition, so there is no false claim — the description correctly describes what UT actually does.

## Balance Review

- Upside: −0.15 stress and −0.20 boredom per zombie kill.
- Downside: none (positive trait — cost paid at character creation only).
- Cost: 4 points.
- Trigger frequency: every zombie kill. In active combat (clearing a building, horde), a player may kill 10–50+ zombies in a session, producing a total stress reduction of 1.5–7.5 and boredom reduction of 2.0–10.0 from a single encounter. This makes the trait highly effective in combat-heavy playstyles, where stress and boredom are already managed naturally by the pace of play.
- Interaction with existing mechanics: stress and boredom each have a natural decay rate and moodle thresholds. The trait does not prevent stress from rising — it provides burst reduction on each kill. Against a background of continuous stress accumulation (e.g., from panic, injury, or trait interactions), the per-kill reduction may be negligible. Against a low-stress background, kills may hold both stats near zero indefinitely during combat.
- Comparison with source:
  - Source was tick-based and blood-proportional: it provided passive, continuous reduction that scaled with how bloody the character was. A maximally bloody character received more reduction per tick than a clean one.
  - UT is kill-triggered and flat: it provides discrete, burst reductions on each kill, independent of blood level.
  - The two designs measure different combat intensities. Source rewarded being bloodied (outcome of many past kills); UT rewards active killing (present-moment kills). Both fit the "Maniac" concept thematically.
  - The stat substitution (unhappiness → boredom) is notable. Boredom is generally a lower-stakes stat than unhappiness (unhappiness has stronger moodle consequences). The UT version may be slightly less valuable than the source in high-unhappiness scenarios.
- Peer comparison:
  - `UT_acrophobic`, `UT_fearful`, `UT_nervouswreck`, `UT_scardycat` — all raise negative stats (panic, stress). Maniac counteracts stress specifically, which can partially offset any of these if the player is actively killing.
  - No mutual exclusion with `Hemophobic` is declared in UT, despite the source enforcing a `Hemophobic ↔ SWManiac` mutual exclusion. This is a missing exclusion (see Action needed below).
- Cost verdict: 4 points is plausible. The trait is a combat-only benefit — it provides no value during crafting, foraging, or non-combat days. For players who engage in frequent combat, the accumulated stress and boredom relief is significant. For low-combat playstyles, the trait is worth very little for its 4-point cost. The cost is arguably high for players who avoid combat and low for combat-focused builds.

## Regression Proof

- Existing test: `UT_maniac` is listed in the Phase 3c registration sweep (`run_tests.lua` line 297), which confirms the trait ID `"UniversalTraits:UT_maniac"` is registered with `CharacterTrait`. This is the only observed test reference.
- What it proves: the trait ID exists in the CharacterTrait registry. It does not test runtime behavior.
- Missing proof:
  1. No test that `Events.OnZombieDead` fires `onKill` and reduces stress by exactly 0.15 when the player has the trait.
  2. No test that `Events.OnZombieDead` fires `onKill` and reduces boredom by exactly 0.20 when the player has the trait.
  3. No test that stress is floored at 0.0 (i.e., a player with stress = 0.1 ends up at 0.0, not −0.05).
  4. No test that boredom is floored at 0.0.
  5. No test that the handler exits cleanly when the player does not have the trait.
- Minimum next test if needed: "maniac: stress decreases by 0.15 on zombie kill" — mock `onKill` with a player possessing the trait and initial stress of 0.5, fire `OnZombieDead`, assert stress equals 0.35. Add parallel test for boredom.

## Final Verdict

- Source origin: proven — SomewhatTraits `SWManiac` is the confirmed source. Source cost (4) matches UT cost (4) exactly across all reviewed versions.
- UT implementation: intentionally redesigned — the core concept (mood improvement from killing) is preserved but the mechanism is substantially different:
  1. **Trigger substitution**: source fired on `OnTick` (every frame, blood-scaled); UT fires on `OnZombieDead` (once per kill, flat). This is a deliberate design simplification, not a drift — the kill-trigger is more intuitive and directly communicates the thematic intent.
  2. **Stat substitution (partial)**: source reduced **stress** and **unhappiness**; UT reduces **stress** and **boredom**. Stress is retained; unhappiness is replaced by boredom. Boredom is a lower-consequence stat than unhappiness (unhappiness triggers stronger moodle penalties), making the UT version slightly less impactful in that dimension.
  3. **Blood dependency removed**: source required the character to have blood on them to receive any benefit. UT removes this condition — every kill produces the same reduction regardless of gore state. This simplifies the mechanic at the cost of thematic depth.
  4. **Multiplayer**: UT disables in multiplayer (`DisabledInMultiplayer = true`); source multiplayer stance was not confirmed from retrieved files. This follows UT-wide policy.
- Description: accurate — the display name, trigger condition, affected stats, and numeric values all match the runtime code exactly. No false claims.
- Balance: conditionally acceptable at 4 points. The trait is combat-gated with no non-combat value, which makes it a poor investment for low-combat playstyles. For active combat builds, the per-kill stress/boredom relief is substantial and practically unlimited in density.
- Missing mutual exclusion: the source enforced `Hemophobic ↔ SWManiac` bidirectional exclusion. UT declares no `MutuallyExclusiveTraits` for `UT_maniac`. If `UT_hemophobic` exists or is planned, this exclusion should be added. Even absent a UT hemophobic trait, the design rationale (a blood-averse character cannot be a combat-craving maniac) is thematically sound and worth preserving.
- Regression proof: registration confirmed; zero behavioral tests exist for this trait.
- Action needed:
  1. **Evaluate the Hemophobic mutual exclusion.** The source enforced this across all versions. If `UT_hemophobic` exists or is planned, add a bidirectional `MutuallyExclusiveTraits` entry. Even if the blood condition was removed from the mechanic, the thematic conflict between blood-aversion and combat-mania is a valid design constraint.
  2. **Consider restoring unhappiness or noting the stat substitution.** Boredom is a softer stat than unhappiness. If the intent is to match the source's relief of **unhappiness** (which blocks recovery from depression/sadness moodles), switching from boredom to unhappiness would increase parity. If boredom is intentional (simpler, less punishing), document the decision.
  3. **Add behavioral tests** for: stress decrement per kill, boredom decrement per kill, floor at 0 for both stats, and handler guard when trait is absent.
- Open gaps:
  - Source `DisabledInMultiplayer` value for `SWManiac` was not confirmed in retrieved script definition files. This does not affect UT correctness but leaves the multiplayer policy comparison incomplete.
  - The `Hemophobic` trait does not appear in the current UT trait list based on reviewed registries; however, the exclusion gap should be noted for future compatibility.
