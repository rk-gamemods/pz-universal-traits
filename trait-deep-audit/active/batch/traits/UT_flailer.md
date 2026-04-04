# UT_flailer

## Trait Summary

- UT trait id: UT_flailer
- Source mod: SomewhatTraits (SomewhatTraitsCore)
- Source trait id: SWTraits:SWFlailer (trait key: "SWFlailer")
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/registries.lua` (line 33: `"SWFlailer", -- -4`)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/Translate/EN/UI_EN.txt` (lines 49–50)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (lines 117, 506–526, 1076) — legacy client
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/client/SWTraitsCore_client.lua` (lines 83–104) — B42.15 client
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/lua/shared/SWTraits_MET.lua` (lines 80–92) — mutual exclusions
- Source cost: -4 (confirmed in registries.lua comment).
- Source description: "Chance to trip and scream when running, based on Panic moodle lvl."
- Source trigger path:
  - Legacy (SWSomewhatTraitsCore.lua): `Events.OnTick.Add(SWFlailer)` — fires every game tick while player is running or sprinting.
  - B42.15 (SWTraitsCore_client.lua): `Events.OnPlayerUpdate.Add(SWFlailer)` — fires on player update while running or sprinting.
- Source behavior (legacy): When running or sprinting and panic moodle level > 0, calculates `chance = moodleLevel * 5`. On a hit: sets a random bump direction left or right (50/50), then with 50% probability sets `setBumpFall(true)` (full knockdown with a shout and world sound) or `setBumpFall(false)` (stumble only, no sound). Calls `reportEvent("wasBumped")` in both cases.
- Source behavior (B42.15): Identical chance formula and bump direction logic. Knockdown branch: `setBumpFall(true)`, conditional shout (client uses `processShoutMessage`, singleplayer uses `SayShout`), world sound. Non-knockdown branch: `setBumpFall(false)`. Always calls `reportEvent("wasBumped")`.
- Source mutual exclusions: SWFlailer is mutually exclusive with SWLurcher, SWScaredycat (panic overlap), and vanilla Desensitized (if available).
- No static stat penalty exists in any source version — the trait is purely a runtime stumble mechanic conditioned on Panic moodle.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes (confirmed via test/run_tests.lua line 251, grouped in "Phase 2 — Combat & Physical")
- Defined in UT_character_traits.txt: yes (lines 1249–1257)
  - `Cost = -4`
  - `DisabledInMultiplayer = true`
  - `IsProfessionTrait = false`
  - No `MutuallyExclusiveTraits` declared
- Translation strings present: yes
  - `UI_UT_flailer = "Flailer"`
  - `UI_UT_flailerDesc = "Your swings are wild and undisciplined. Combat accuracy is reduced by -15%. While panicking and running, you may stumble and fall."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_flailer.lua`)
- Loaded in test harness: yes (`run_tests.lua` line 803: `dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_flailer.lua")`)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_flailer.lua` (full file, 46 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1249–1257)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 374–375)
  - `test/run_tests.lua` (lines 251, 803, 835–843)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)`
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — trait check in both handlers
- Runtime chain (plain language):
  1. On new game: if player has the trait, sets `modData["UT_combatAccuracyMod"] = -0.15`. This is a static accuracy penalty applied once at character creation.
  2. On every player update: checks trait, reads or initialises `modData["UT_flailer_cooldown"]` to 0. If cooldown > 0, decrements by 1 and exits. Otherwise:
     - Checks `player:isSprinting()` via a guarded `pcall`; exits if not sprinting.
     - Reads `player:getBodyDamage():getPanicLevel()` via `pcall`; exits if `panicLevel <= 0`.
     - Rolls `ZombRand(100) < 5` (flat 5% chance, independent of panic level magnitude).
     - On hit: calls `player:setBumpFallDown(true)` and sets cooldown to 30.
- Actual behavior (exact values):
  - Permanent: `-0.15` stored in `modData["UT_combatAccuracyMod"]` on new game. This value is a passive modData entry — it is not applied by any visible UTCore stat function call in this file.
  - Stumble condition: player must be sprinting AND panic moodle level > 0 (any non-zero panic level qualifies).
  - Stumble chance per update tick: flat 5% (`ZombRand(100) < 5`), regardless of how high the panic level is.
  - On stumble: `setBumpFallDown(true)` only — always a full knockdown, no directional bump, no 50/50 fall vs. stumble split, no shout, no world sound. Cooldown: 30 ticks after each stumble.

## Description Integrity

- Display name check: "Flailer" — matches source name exactly.
- Description check: `UI_UT_flailerDesc` reads: "Your swings are wild and undisciplined. Combat accuracy is reduced by -15%. While panicking and running, you may stumble and fall."
- Issues found:
  1. **"Running" vs. sprinting mismatch.** The description says "running" but the runtime code gates on `player:isSprinting()` — not walking, jogging, or the source's broader `running or sprinting` check. Players who are running but not sprinting will not trigger stumbles.
  2. **Combat accuracy claim is unverified.** The description states "-15% combat accuracy" and the Lua sets `modData["UT_combatAccuracyMod"] = -0.15` on new game. However, no visible code in this file reads or applies that modData key to an actual game stat. If UTCore or another module consumes it, the claim is valid; if nothing reads it, the penalty is silently inert. Evidence is inconclusive without tracing `UT_combatAccuracyMod` consumers across the codebase.
  3. **Panic level is binary in UT, moodle-scaled in source.** The source scaled chance linearly by `moodleLevel * 5` (5%, 10%, 15%, 20% at panic levels 1–4). The UT port applies a flat 5% regardless of panic severity, removing the escalating pressure that made high panic genuinely dangerous.
  4. **No stumble variety.** The source produced a 50/50 directional stumble vs. full knockdown with an audible scream and noise generation. The UT port always uses `setBumpFallDown(true)` — always a hard knockdown, always silent, no world sound. This is both a behavioral divergence from source and missing information for the player.
  5. **No mutual exclusions.** The source excluded SWFlailer from SWLurcher, SWScaredycat, and Desensitized. UT declares no exclusions — `UT_flailer` and `UT_lurcher` can be combined, which double-stacks conditional stumble effects.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside:
  - -15% combat accuracy (if `UT_combatAccuracyMod` is consumed correctly — unverified).
  - Flat 5% stumble per update tick while sprinting with any panic, hard-capped by a 30-tick cooldown.
- Uptime: the stumble risk is conditional on both sprinting and any panic moodle level. In low-danger play the trait is dormant. In panic situations — which typically coincide with sprinting — the risk activates, but the flat 5% and 30-tick cooldown make it relatively mild in practice.
- Peer comparison:
  - `UT_lurcher` costs -5 and has a conditional stumble (endurance-gated) plus a declared work speed penalty.
  - `UT_noodlelegs` costs -4 and gives a permanent -15% movement speed with no conditional runtime penalty.
  - `UT_flailer` at -4 provides: an unverified -15% accuracy stat + a low-probability conditional knockdown. If the accuracy modifier is live, this is reasonable for -4. If it is dead data, the trait is significantly undercosted in effect.
- Stack or exclusion notes: No exclusions declared. Can stack with `UT_lurcher` (two stumble sources) and `UT_analgesia` (no natural exclusion). Source excluded from panic-linked traits — UT does not replicate this.
- Cost verdict: conditionally acceptable at -4 if the combat accuracy modifier is confirmed active. If the modifier is not consumed, the trait delivers only a mild conditional knockdown that is weaker than its -4 cost implies. Requires verification of `UT_combatAccuracyMod` consumers.

## Regression Proof

- Existing test: "flailer stumble fires when panicked and sprinting" (`run_tests.lua` line 835)
- What it proves: With the trait present, `sprinting = true`, `panicLevel = 2`, cooldown nil (initialises to 0), and `ZombRand` returning 0 (< 5), `Events.OnPlayerUpdate` fires the stumble path and sets `_bumpFallDown = true`. Confirms the happy-path stumble end-to-end.
- Missing proof:
  1. No test for `onNewGame` — that `modData["UT_combatAccuracyMod"]` is set to -0.15 at character creation.
  2. No test that non-sprinting (jogging/walking) suppresses stumbles.
  3. No test that `panicLevel == 0` (no panic) suppresses stumbles.
  4. No test that the 30-tick cooldown blocks a second stumble before expiry.
  5. No test that a ZombRand result >= 5 (e.g., 6) does not fire the stumble.
  6. No test confirming that the `pcall` guard around `isSprinting` handles a nil/erroring player gracefully.
- Minimum next test if needed: "flailer: panic level 0 suppresses stumble" — create a MockUpdatePlayer with the trait, sprinting=true, panicLevel=0, fire OnPlayerUpdate, assert `_bumpFallDown` remains nil/false.

## Final Verdict

- Source origin: proven — SomewhatTraits `SWFlailer` is the confirmed source; legacy and B42.15 client files located and read. Source cost (-4) matches UT cost exactly.
- UT implementation: drifted — the core panic-while-sprinting stumble concept is preserved but with significant divergences: (1) flat 5% chance replaces the source's moodle-scaled `moodleLevel * 5` formula; (2) UT gates on sprint-only vs. source's `running or sprinting`; (3) UT always fires `setBumpFallDown(true)` where source used a 50/50 fall/stumble split with directional bump, audible shout, and world sound; (4) UT adds a new -15% combat accuracy static penalty (`UT_combatAccuracyMod`) that does not exist in the source at all; (5) UT adds a 30-tick cooldown that the source did not have.
- Description: partially misleading — "running" should be "sprinting"; the 5% stumble chance is not disclosed; the escalating nature of panic (which UT no longer scales) is implied but absent; the always-knockdown behavior is not distinguished from a stumble.
- Balance: uncertain — hinges on whether `UT_combatAccuracyMod` is consumed by the runtime. If active, -4 is defensible. If not, the trait is weaker than its cost.
- Regression proof: happy path covered; suppression conditions, cooldown behavior, and new-game handler are not tested.
- Action needed:
  1. **Verify** that `UT_combatAccuracyMod` is read and applied by UTCore or another module. If not, either wire up the application or remove the claim from the description.
  2. **Fix description** to say "sprinting" rather than "running" and to accurately describe the 5% flat chance with cooldown.
  3. **Consider** whether source's moodle-scaled chance (`moodleLevel * 5`, capping at 20% at max panic) should replace the flat 5% to preserve the escalating-panic feel from SomewhatTraits.
  4. **Add mutual exclusion** with `UT_lurcher` at minimum to prevent double-stumble stacking; consider exclusion with `UT_analgesia` (panic immunity) for logical consistency.
  5. **Add tests** for suppression conditions (no sprint, no panic, cooldown blocking), the newgame accuracy handler, and edge cases around the pcall guard.
- Open gaps:
  - Confirm whether `UT_combatAccuracyMod` is consumed anywhere in UTCore or shared Lua — this is the single most important open question for balance validity.
  - The source B42.15 port moved to `Events.OnPlayerUpdate` (same as UT), so the event hook is aligned; the legacy client used `Events.OnTick` which fires much faster — the UT port correctly mirrors the modern source in this respect.
  - No mutual exclusions in script definition — assess whether `UT_flailer` + `UT_lurcher` combination is intentional or an oversight given source excluded these from one another.
