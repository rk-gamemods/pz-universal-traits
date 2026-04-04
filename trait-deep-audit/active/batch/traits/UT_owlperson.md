# UT_owlperson

## Trait Summary
- UT trait id: UT_owlperson
- Source mods: MoreSimpleTraits (`mods/MoreSimpleTraits`, trait id `OwlPerson`); SomewhatTraits (`mods/SomewhatTraitsCore`, trait id `NightOwl`) — two independent analogues; UT concept is closer to MoreSimpleTraits (fatigue timing) but the UT mechanic was redesigned to use stress rather than fatigue
- Source trait ids: `OwlPerson` (MoreSimpleTraits); `NightOwl` (SomewhatTraits)
- Current cost: -1
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/Translate/EN/UI_EN.txt`

### MoreSimpleTraits — OwlPerson
- Trigger: `Events.EveryTenMinutes.Add(owlperson)` — fires every ten in-game minutes
- Guard: `player:HasTrait("OwlPerson") and not player:isAsleep()`
- Night benefit window (18:00–22:00): calls `MSTdecreaseFatigue(player, 0, 0.004)` — reduces fatigue by 0.004 per 10-minute tick
- Morning penalty window (05:00–09:00): calls `MSTincreaseFatigue(player, 0, 0.004)` — increases fatigue by 0.004 per 10-minute tick
- Stat affected: fatigue only; no stress modification
- Description: "Prefers to stay awake in the evenings. Drowsiness accumulates more slowly in the late evening (06:00 p.m.–11:00 p.m.), but faster in the early morning (05:00 a.m.–10:00 a.m.)."

### SomewhatTraits — NightOwl
- Trigger: `Events.OnTick.Add(SWNightOwl)` — fires every game tick
- Guard: `hasSWNightOwl` flag set on character build from `character:HasTrait("NightOwl")`
- Night benefit: reduces panic by `timeMultiplier * 5` per tick and reduces fatigue by `timeMultiplier * dayLengthMultiplier * 0.0001` per tick, but only when `night > 0`
- Stats affected: panic and fatigue (during night hours only); no stress modification
- Description: "Requires little sleep. Stays extra alert even when sleeping. At night improves panic loss, slows down fatigue gain."

### Design divergence in UT
- UT redesigned the mechanic from fatigue/panic to stress — neither source mod touches stress for this trait concept. This is a deliberate UT divergence, not a port.

## Current UT Evidence

### Structure
- Registered in character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_owlperson`, `Cost = -1`, `DisabledInMultiplayer = true`, `MutuallyExclusiveTraits = UniversalTraits:UT_larkperson`
- Mutual exclusion: `UT_owlperson` and `UT_larkperson` are mutually exclusive with each other — correct, these are paired circadian opposites
- Translation strings present: yes — `UI_UT_owlperson = "Night Owl"`, `UI_UT_owlpersonDesc = "You come alive after dark. Between 6pm and 6am stress decreases by 0.02 per minute. Between 6am and 6pm stress increases by 0.01 per minute."`
- Runtime Lua file exists: yes — `UT_owlperson.lua`

### Runtime Trace
- Files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_owlperson.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/scripts/UT_character_traits.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
- Event registrations: `Events.EveryOneMinute.Add(onEveryMinute)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` — no other UT_CORE helpers; stat manipulation is done directly via `stats:setStress()`
- Runtime chain (plain language):
  1. `onEveryMinute` fires once per in-game minute for the local player.
  2. `UTCore.hasTrait(player, "UniversalTraits:UT_owlperson")` — if false, returns immediately.
  3. Reads `getGameTime():getTimeOfDay()` — a float in [0, 1) where 0.0 = midnight, 0.25 = 06:00, 0.5 = noon, 0.75 = 18:00.
  4. Night window (`timeOfDay < 0.25` OR `timeOfDay > 0.75`, i.e. 18:00–06:00): calls `stats:setStress(math.max(0, stress - 0.02))` — reduces stress by 0.02, floored at 0.
  5. Day window (else, i.e. 06:00–18:00): calls `stats:setStress(math.min(1, stress + 0.01))` — increases stress by 0.01, capped at 1.
- Actual behavior (exact values):
  - Night (18:00–06:00, 12 hours): −0.02 stress/minute → up to −1.44 stress per night window (full range is 0–1, so the -0.02/min rate clears a full stress bar in 50 minutes under ideal conditions)
  - Day (06:00–18:00, 12 hours): +0.01 stress/minute → up to +0.72 stress per day window
  - Net daily swing: strong night recovery, moderate day accumulation; net is negative (beneficial) over a full day cycle if the player is active in both windows
  - Implementation is fully functional — reads live game time, applies clamped stat changes, no moddata dependency

## Description Integrity
- Display name check: "Night Owl" — accurate; consistent with both source names ("Owl" in MST, "NightOwl" in SW) and the circadian concept.
- Description check: "You come alive after dark. Between 6pm and 6am stress decreases by 0.02 per minute. Between 6am and 6pm stress increases by 0.01 per minute."
  - Time window accuracy: the code uses `timeOfDay < 0.25 or timeOfDay > 0.75`; converting: 0.75 * 24 = 18:00 (6pm), 0.25 * 24 = 06:00 (6am). The description states "6pm–6am" and "6am–6pm" — these match the code exactly.
  - Rate accuracy: night rate -0.02/min and day rate +0.01/min are stated explicitly and match the code exactly.
  - Stat accuracy: description says "stress" — code reads `stats:getStress()` and writes `stats:setStress()` — correct.
  - No missing details. No misleading claims. Description is accurate and complete.

## Balance Review
- Upside: -0.02 stress/min during a 12-hour night window; can fully clear maximum stress in ~50 minutes of nighttime play
- Downside: +0.01 stress/min during a 12-hour day window; will accumulate +0.72 stress over a full day window if uncountered
- Net daily effect: if both windows run their full 720 minutes, net stress delta = (720 × −0.02) + (720 × +0.01) = −14.4 + 7.2 = −7.2 (clamped at 0 floor/1 ceiling in practice); the trait is a net stress sink over a full day cycle, making it clearly positive at cost -1
- Cost verdict: -1 is defensible; the trait provides reliable passive stress relief during the longer productive/dangerous hours (night scavenging), with a smaller daytime penalty that most players will counteract through normal play. The net benefit is significant in a survival game where stress accumulates naturally — cost may be slightly underpriced (compare: stress management traits in vanilla are often 0 to +1), but is not egregiously wrong.
- Uptime: effect is unconditional while the player has the trait and the game clock is in the correct window; no guards for sleep, indoors/outdoors, or activity state
- Peer comparison (UT_larkperson, the mutual exclusive):
  - UT_larkperson is the daytime counterpart — the audit of UT_larkperson should confirm whether its rates are symmetric. Asymmetry here (night: -0.02, day: +0.01) means the owlperson is more powerful at its specialty than the larkperson may be at its specialty; this should be cross-checked.
  - Source mods used fatigue/panic rather than stress; the UT redesign is a clean divergence that interacts better with the PZ stress system
- Stack or exclusion notes: mutually exclusive with `UT_larkperson` (enforced in the script); can co-exist with any other stress-modifying traits, which could compound the night benefit significantly
- Multiplayer note: `DisabledInMultiplayer = true` — trait is unavailable in MP; appropriate given the time-of-day mechanic may behave differently with server-side time

## Regression Proof
- Existing test: `UniversalTraits:UT_owlperson` appears in the batch trait list in `run_tests.lua` (line 271, labeled Phase 2 — Timed / Circadian), confirming it is included in the batch registration sweep.
- What it proves: The trait ID is registered and can be found by the trait registry; the definition block parses without error; mutual exclusion with `UT_larkperson` is declared.
- Missing proof:
  1. No test confirms that `onEveryMinute` fires with the correct effect during the night window (stress decreases by 0.02).
  2. No test confirms the day window increases stress by 0.01.
  3. No test confirms the `math.max(0, ...)` and `math.min(1, ...)` clamps prevent out-of-range values.
  4. No test confirms early return when the player does not have the trait.
  5. No test verifies that `UT_owlperson` and `UT_larkperson` cannot be simultaneously held by the same character.
- Minimum next tests if needed:
  - Mock `getGameTime():getTimeOfDay()` returning a night value (e.g. 0.10) and a day value (e.g. 0.50); assert stress decreases and increases respectively by exact amounts.
  - Assert stress does not go below 0 or above 1 at boundary values.
  - Assert no effect when `UTCore.hasTrait` returns false.

## Final Verdict
- Source origin: dual — MoreSimpleTraits (`OwlPerson`, fatigue-based, EveryTenMinutes) and SomewhatTraits (`NightOwl`, fatigue + panic, OnTick); UT deliberately redesigned the mechanic to target stress instead of fatigue or panic
- UT implementation: correct and complete — the `onEveryMinute` handler reads game time accurately, applies clamped stress deltas of -0.02/min (night) and +0.01/min (day) with correct 18:00–06:00 / 06:00–18:00 windows, and uses a live guard check via `UTCore.hasTrait`; no moddata required; no inert or stub code found
- Description: accurate — time windows, stat affected, and rates are all stated correctly and match the code exactly
- Balance: acceptable — net stress sink over a full day cycle; -1 cost is slightly generous but not unreasonable for a trait with a real daytime penalty; larkperson symmetry should be cross-checked
- Regression proof: present (batch registration); behavioral proof absent — no unit test covers the per-minute stat deltas, clamping, or the early-return guard
- Action needed: no code fix required; add behavioral unit tests to cover the night and day delta values, boundary clamping, and the no-trait early-return path
- Open gaps:
  - No test coverage for the stress delta logic or time-window branching
  - Larkperson rate symmetry unverified in this audit — if larkperson applies the same asymmetric rates (-0.02 day / +0.01 night), the two traits are balance-equivalent; if rates differ, the pair is unbalanced and cost parity at -1 each may be incorrect
  - No sleep guard — if the player is asleep during night hours, the -0.02/min stress reduction still applies; whether this is intended is not documented
  - No outdoor/environmental guard — trait applies identically indoors and outdoors, which may be overly unconditional for a circadian-themed effect
  - Mutual exclusion with `UT_larkperson` is enforced at the script level; no runtime check confirms a player cannot acquire both traits through mod interaction or console commands
