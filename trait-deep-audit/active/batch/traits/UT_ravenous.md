# UT_ravenous

## Trait Summary

- UT trait id: UT_ravenous
- Source mod: SomewhatTraits (SWTraits)
- Source trait id: SWTraits:SWRavenous
- Current cost: -6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/scripts/SWTraits_character_traits.txt` (script definition, Cost = -2)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/Translate/EN/UI_EN.txt` (legacy EN strings: "Hunger causes pain, based on Hunger moodle lvl.")
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (B42 EN strings: same description)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (legacy client runtime, lines 682–697)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/client/SWTraitsCore.lua_` (B42 client runtime, lines 483–493)
- Source trigger path (legacy client): `Events.OnTick.Add(SWRavenous)` — fires every game tick
- Source trigger path (B42 client): `Events.OnPlayerUpdate.Add(SWRavenous)` — fires every player update
- Source behavior (legacy client):
  - `SWRavenous()`: reads the Hungry moodle level; if level > 0 and lower-torso pain < 20, adds `timeMultiplier * moodleLevel` additional pain to `BodyPartType.Torso_Lower` (capped at `maxPain`)
- Source behavior (B42 client):
  - `SWRavenous(player)`: reads `MoodleType.HUNGRY` level; sets lower-torso additional pain to `timeMultiplier * moodleLevel` unconditionally (no pain-floor guard)
- Source description (EN): "Hunger causes pain, based on Hunger moodle lvl."
- Source cost: -2; multiplayer enabled (`DisabledInMultiplayer = false`)

## Current UT Evidence

### Structure

- Registered in registries.lua: not checked — trait appears in `test/run_tests.lua` Phase 3b — Periodic-Check batch list at line 284, confirming it is a known trait id
- Defined in UT_character_traits.txt: yes — lines 1700–1708
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_ravenous`
  - `Cost = -6`
  - `UIName = UI_UT_ravenous`
  - `UIDescription = UI_UT_ravenousDesc`
- Translation strings present: yes — `UI_UT_ravenous = "Ravenous"` and `UI_UT_ravenousDesc = "Your appetite is relentless. Every 10 in-game minutes, hunger increases by +0.1."` both present in `media/lua/shared/Translate/EN/UI_EN.txt` (lines 530–531)
- Exclusions/grants correct: no mutual exclusion defined in UT_character_traits.txt block; source also had no mutual exclusion
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_ravenous.lua`

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_ravenous.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1700–1708)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 530–531)
  - `test/run_tests.lua` (line 284)
- Event registrations:
  - `Events.EveryTenMinutes.Add(handler)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` — standard guard
- Runtime chain (plain language):
  1. Every 10 in-game minutes, fires `handler`.
  2. Gets the local player via `getPlayer()`; exits if no player.
  3. Checks if the player has `UniversalTraits:UT_ravenous`; exits if not.
  4. Reads current hunger via `stats:getHunger()`.
  5. Adds 0.1 to hunger, clamped to a maximum of 1.0 via `math.min(1, stats:getHunger() + 0.1)`.
  6. Writes the new hunger value back via `stats:setHunger(...)`.
- Actual behavior (exact values):
  - Hunger increase: +0.1 per 10 in-game minutes, unconditionally while the trait is held
  - Ceiling: hunger is clamped at 1.0; the trait cannot push hunger above the maximum
  - No pain mechanic — the source applied hunger-scaled pain to the lower torso; UT does not replicate this at all

## Description Integrity

- Display name check: "Ravenous" — matches source exactly; appropriate
- Description check (full text): "Your appetite is relentless. Every 10 in-game minutes, hunger increases by +0.1."
- Accuracy of description:
  - "Every 10 in-game minutes, hunger increases by +0.1" — technically accurate; the event is `EveryTenMinutes` and the delta is exactly +0.1, clamped at 1.0
  - The description says nothing about pain, which is correct because UT does not implement the pain mechanic
- Missing or misleading details:
  - The description does not mention the ceiling of 1.0; this is a minor omission but has no practical impact since 1.0 is the maximum hunger value
  - The description does not warn the player that this applies unconditionally regardless of current hunger level — hunger ticks up even at 0.9, potentially pushing the player to maximum hunger every 10 minutes if not eating

## Balance Review

- Upside: none — this is a negative trait (cost = -6); the player receives 6 points at character creation
- Downside: hunger increases by +0.1 every 10 in-game minutes unconditionally; at max hunger (1.0) the clamp prevents over-application but the player will be at maximum hunger after the first tick if starting near 0.9
- Uptime: Always active while the trait is held
- Magnitude assessment:
  - +0.1 per 10 in-game minutes = +0.6 per in-game hour; vanilla hunger accrual rate varies by activity but this is a substantial additional load requiring more frequent eating
  - The source trait instead applied pain proportional to the Hungry moodle level — a mechanically different penalty. UT's flat hunger-rate increase is simpler but diverges completely from the source concept (hunger-causes-pain vs. hunger-increases-faster)
- Peer comparison: No other UT trait in the Phase 3b batch directly manipulates raw hunger accrual rate. UT_adaptivemetabolism and UT_accmetabolism are thematically adjacent but operate differently. The -6 cost is three times the source -2 cost; the source penalty (pain) was arguably more severe in combat but situational; UT's penalty (faster starvation) is always-on and harder to ignore, which could justify the higher cost, but the design pivot from pain to hunger-rate is undocumented
- Stack or exclusion notes: No mutual exclusion defined. Could stack with any other metabolism or hunger-adjacent trait without restriction.
- Cost verdict: -6 may be appropriate given the always-on nature and the constant food pressure, but the cost tripling relative to source (-2) without documentation of intent is a design flag. The source's pain mechanic was a different and arguably more punishing combat penalty; UT's hunger-rate increase is consistently annoying but less acute. The cost should be confirmed as deliberate.

## Regression Proof

- Existing test: `run_tests.lua` line 284 lists `"UniversalTraits:UT_ravenous"` in the Phase 3b — Periodic-Check batch array. This is an existence/registration check only — it confirms the trait id is known to the test suite but does not exercise the runtime logic.
- What it proves: The trait id string is present in the batch list; no behavioral coverage
- Missing proof:
  - No test verifies that hunger increases by exactly +0.1 on a `EveryTenMinutes` fire
  - No test verifies that hunger at 1.0 is clamped and not pushed above 1.0
  - No test verifies that the handler exits cleanly when no player is present
  - No test verifies that the handler exits cleanly when the player does not have the trait
- Minimum next test if needed: Construct a mock player with `UT_ravenous`, set hunger to 0.5, fire `Events.EveryTenMinutes`, assert hunger equals 0.6. Add a second case with hunger = 1.0 and assert it remains 1.0 after firing (clamp proof).

## Final Verdict

- Source origin: proven — SomewhatTraits SWRavenous confirmed in script definitions (42.15), EN translations (legacy and B42), and runtime (legacy client `SWSomewhatTraitsCore.lua` and B42 client `SWTraitsCore.lua_`)
- UT implementation: redesigned — source applied hunger-moodle-scaled pain to the lower torso on every tick or player update; UT replaces this entirely with a flat +0.1 hunger increment every 10 in-game minutes. The concept (hunger is a burden) is preserved but the mechanism is completely different. This is a deliberate design departure, not a bug, but it is undocumented.
- Description: accurate for the UT implementation — the description correctly describes the UT behavior (+0.1 hunger per 10 in-game minutes) and makes no claims about the source pain mechanic. No false statements, no missing critical details.
- Balance: cost flag — the -6 cost is 3× the source -2, and the UT mechanic (always-on hunger pressure) differs from the source (situational combat pain). The higher cost may be intentional to reflect the constant food-supply pressure, but the rationale is not recorded.
- Regression proof: not protected — only an id-presence check exists; no behavioral test covers the hunger increment or clamp logic
- Action needed: cost review + test fix
- Open gaps:
  - Confirm whether the -6 cost (vs. source -2) is intentional and document the rationale; if the design intent was to make constant hunger pressure a meaningful survival penalty, the cost may be correct, but it should be recorded
  - Add behavioral tests: hunger-above-zero increment (+0.1 step), hunger-at-ceiling clamp (stays at 1.0), no-player early exit, and no-trait early exit
  - Consider whether `DisabledInMultiplayer = true` is appropriate — source was `DisabledInMultiplayer = false`; UT uses `getPlayer()` (single-player API) which justifies the flag, but if multiplayer support is ever desired the handler would need to be rearchitected around a player-parameter event
  - Consider whether the absence of any mutual exclusion is correct — source had none, so no action required, but note that combining with UT_adaptivemetabolism or UT_accmetabolism is currently unrestricted
