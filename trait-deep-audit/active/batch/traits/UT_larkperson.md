# UT_larkperson

## Trait Summary
- UT trait id: UT_larkperson
- Source mod: MoreSimpleTraits (`mods/MoreSimpleTraits` and `mods/MoreSimpleTraitsVanilla`)
- Source trait id: `LarkPerson` (registered via `TraitFactory.addTrait("LarkPerson", ...)`)
- Current cost: -1
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt`
- Source trigger path: `Events.EveryTenMinutes.Add(larkperson)` — `larkperson()` fires every ten in-game minutes; if the player has trait `"LarkPerson"` and is not asleep, it calls `MSTdecreaseFatigue(player, 0, 0.004)` during hours 5–9, and `MSTincreaseFatigue(player, 0, 0.004)` during hours 18–22.
- Source behavior: circadian fatigue modifier — fatigue decreases slightly during early morning (05:00–09:00) and increases slightly during late evening (18:00–22:00); only applies while the player is awake; the affected stat is **fatigue/drowsiness**, not stress. Mutual exclusion with `OwlPerson` enforced via `TraitFactory.setMutualExclusive`. Trait is disabled when sleep is globally off (`not SleepEnabled`).
- Source EN description: "Prefers to be awake in the morning. (Drowsiness accumulates more slowly in the early morning (05:00 a.m. – 10:00 a.m.), but faster in the late evening (06:00 p.m. – 11:00 p.m.))."

## Current UT Evidence

### Structure
- Registered in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_larkperson`, `Cost = -1`, `DisabledInMultiplayer = true`, `MutuallyExclusiveTraits = UniversalTraits:UT_owlperson`
- Translation strings present: yes — `UI_UT_larkperson = "Early Bird"`, `UI_UT_larkpersonDesc = "You rise with the sun and hit the ground running. Between 6am and 6pm stress decreases by 0.02 per minute. Between 6pm and 6am stress increases by 0.01 per minute."`
- Mutual exclusion defined: yes — `MutuallyExclusiveTraits = UniversalTraits:UT_owlperson` (symmetric; owlperson also excludes larkperson)
- Runtime Lua file exists: yes — `UT_larkperson.lua`

### Runtime Trace
- Files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_larkperson.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/scripts/UT_character_traits.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
- Event registration: `Events.EveryOneMinute.Add(onEveryMinute)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`; no UT_CORE stat-modifier wrapper; direct `stats:setStress()` calls
- Runtime chain (plain language):
  1. Every in-game minute, `onEveryMinute` fires.
  2. `UTCore.hasTrait` checks whether the player has `UniversalTraits:UT_larkperson`; exits early if not.
  3. `getGameTime():getTimeOfDay()` returns a float in [0, 1] where 0.25 = 06:00 and 0.75 = 18:00.
  4. If `timeOfDay >= 0.25 and timeOfDay <= 0.75` (day window, 06:00–18:00): `stats:setStress(math.max(0, stress - 0.02))` — stress decreases by 0.02 per minute, floor 0.
  5. Otherwise (night window, 18:00–06:00): `stats:setStress(math.min(1, stress + 0.01))` — stress increases by 0.01 per minute, ceiling 1.
- Actual behavior (exact values): stress –0.02/minute during daytime (06:00–18:00), stress +0.01/minute during nighttime (18:00–06:00). The effect fires every real minute unconditionally while the player is alive and has the trait. Sleep state is not checked.

## Description Integrity
- Display name check: "Early Bird" — conceptually accurate for a morning-person trait; matches the lark/circadian theme. The source uses "Lark"; "Early Bird" is a reasonable UT rename.
- Description check: "You rise with the sun and hit the ground running. Between 6am and 6pm stress decreases by 0.02 per minute. Between 6pm and 6am stress increases by 0.01 per minute." — the time windows (6am–6pm / 6pm–6am) and exact values (–0.02 day, +0.01 night) match the Lua code precisely. The description is mechanically accurate.
- Missing or misleading details: one divergence from source — the source mod affected **fatigue/drowsiness** (sleep readiness), while the UT implementation affects **stress**. The description makes no mention of fatigue and does not claim fatigue is affected, so it is internally consistent with the UT implementation. However, the stat targeted is a deliberate departure from the source concept. Additionally, the description does not note that sleep state has no effect on the tick (the bonus applies even while the player is asleep, because no `isAsleep()` guard exists in the Lua).

## Balance Review
- Upside: stress –0.02 per minute for 12 in-game hours (06:00–18:00). Over a full 12-hour daytime window that is up to 720 minutes × 0.02 = 14.4 stress points removed (capped at 0). In practice this is a very strong passive stress drain during the main activity window.
- Downside: stress +0.01 per minute for 12 in-game hours (18:00–06:00). Up to 720 minutes × 0.01 = 7.2 stress points added (capped at 1). The upside rate is double the downside rate, so over a balanced 24-hour cycle the trait is net-positive by 2:1.
- Uptime: always active while the player has the trait; no conditional guard on sleep state, action state, or location.
- Peer comparison:
  - `UT_owlperson` (mirror trait, cost –1): identical mechanics inverted — stress –0.02/minute at night, +0.01/minute during day. The pairing is perfectly symmetric; costs, rates, and windows are mirrored. Both provide the same net benefit over 24 hours.
  - Source `LarkPerson` (cost –1): affected fatigue ±0.004 every 10 minutes in narrower windows (05:00–09:00 / 18:00–22:00), only while awake. The UT version broadens the active windows to 12 hours each, doubles the per-event tick frequency (every minute vs. every 10 minutes), and switches the affected stat from fatigue to stress. The UT effect is substantially more powerful than the source.
- Stack or exclusion notes: mutual exclusion with `UT_owlperson` is enforced in the script definition. No exclusion with stress-reducing or stress-increasing traits (e.g., psychology tier traits); these can stack freely.
- Cost verdict: plausible but possibly underpriced — the daytime stress drain is very aggressive (–0.02/min), and the trait is net-positive by 2:1 over a full day. At cost –1 it grants more per point than most passive psychology traits. The source cost of –1 was for a weaker, narrower fatigue effect; the broadened stress implementation may warrant re-evaluation.

## Regression Proof
- Existing test: `UniversalTraits:UT_larkperson` appears in the batch trait list in `run_tests.lua` (line 271) under "Phase 2 — Timed / Circadian (2)", confirming it is included in the batch registration sweep alongside `UT_owlperson`.
- What it proves: the trait ID is registered and can be instantiated without error. Nothing about runtime behavior is verified.
- Missing proof:
  - No test confirms that the `onEveryMinute` handler correctly decreases stress during the day window and increases it at night.
  - No test verifies the boundary conditions: `timeOfDay == 0.25` (exactly 06:00) should trigger the day branch; `timeOfDay == 0.75` (exactly 18:00) should also trigger the day branch (inclusive `<=` comparison).
  - No test confirms that a player without the trait is unaffected.
  - No test verifies the math.max/math.min clamping (stress cannot go below 0 or above 1).
  - No test confirms mutual exclusion with `UT_owlperson` is enforced at the script-definition level.
- Minimum next test if needed: mock `getGameTime():getTimeOfDay()` to return a daytime value (e.g., 0.5); mock player stress at 0.5; fire the handler; assert stress == 0.48. Repeat with a nighttime value (e.g., 0.1); assert stress == 0.51. Then assert no change occurs when the player does not have the trait.

## Final Verdict
- Source origin: MoreSimpleTraits — `LarkPerson` trait; cost –1, mutual exclusion with `OwlPerson`, disabled when sleep is off; source affected fatigue ±0.004 every 10 minutes in narrow windows (05:00–09:00 morning benefit, 18:00–22:00 evening penalty), only while the player is awake.
- UT implementation: functional but intentionally diverged — the UT version switches the affected stat from fatigue to stress, widens the active windows from 4 hours each to 12 hours each, increases tick frequency from every 10 minutes to every 1 minute, and removes the awake-only guard. The implementation is internally consistent and has no broken plumbing (all paths execute, no unread mod data keys, no missing consumers). The mutual exclusion with `UT_owlperson` is correctly defined and the owlperson/larkperson pair is symmetric.
- Description: accurate to the UT implementation — time windows, stat, and values in the description match the code exactly. No misleading claims. Minor omission: the description does not note that the effect applies during sleep, which is a behavioral difference from the source.
- Balance: net-positive by 2:1 over 24 hours; the daytime drain (–0.02/min) is aggressive relative to the –1 cost. The broadened windows and higher frequency make this substantially more impactful than the source warrant; cost re-evaluation is advisable.
- Regression proof: missing — only batch-registration coverage exists; no behavioral unit tests.
- Action needed: low urgency — no broken mechanics or dead code. Recommended follow-ups:
  1. Consider adding an `isAsleep()` guard to match source intent and prevent stress changes from firing while the player is sleeping (or document explicitly that sleep state is intentionally ignored).
  2. Evaluate whether cost –1 is appropriate given the 2:1 net-positive stress economy over a full day.
  3. Add behavioral unit tests for the day/night branch logic and the stress floor/ceiling clamps.
- Open gaps:
  - Source mod disabled the trait when sleep was globally off (`not SleepEnabled`); UT uses `DisabledInMultiplayer = true` — these are not equivalent; single-player games with sleep disabled are not covered by the UT guard, same issue shared with `UT_owlperson`.
  - No sleep-state guard in the Lua means the trait continues to apply stress changes while the player is asleep; the source explicitly checked `not player:isAsleep()`.
  - The symmetric design with `UT_owlperson` is good, but neither trait interacts with any sleep or fatigue system — the original circadian fatigue concept has been fully replaced by a pure stress model with no documentation of the design decision.
