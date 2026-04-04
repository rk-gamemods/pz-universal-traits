# UT_fearful

## Trait Summary

- UT trait id: UT_fearful
- Source mod: MoreTraits (More Traits)
- Source trait id: ToadTraits:fearful (trait key: "fearful")
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (lines 239–248) — B42.15 script definition
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (lines 4026–4073, 5330–5331) — B42.15 runtime
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (lines 141–165) — source translation
- Source cost: -7 (B42.15 script definition, line 244).
- Source description: "You're easily scared and likely to scream aloud if panicked." (`UI_trait_fearfuldesc`)
- Source mutual exclusions: `base:brave; base:desensitized` (script definition, line 247).
- Source `DisabledInMultiplayer`: `false` (script definition, line 242).
- Source trigger path: `Events.OnPlayerUpdate.Add(OnPlayerUpdate)` — the global `OnPlayerUpdate` handler dispatches `FearfulUpdate(player, playerdata)` when the shared `internalTick` counter equals 20. `internalTick` increments by 1 per `OnPlayerUpdate` call and resets to 0 after 30 — so `FearfulUpdate` fires once every 30 player-update frames.
- Source behavior:
  1. If the player does not have `ToadTraits:fearful`, returns immediately.
  2. Reads `CharacterStat.PANIC` from `player:getStats()`.
  3. If `panic > 5`: computes `chance = 3 + (panic / 10)`.
  4. Adjusts `chance` upward by +1 if the player also has the vanilla `CharacterTrait.COWARDLY`, and by a `luckimpact` value if the player has the `unlucky` MoreTraits trait.
  5. Rolls `ZombRand(0, 1000) <= chance`. On success:
     - Selects a localized shout string and noise parameters based on panic tier:
       - `panic <= 25`: `"UI_fearful_slightpanic"` ("*Whimper*"), radius 5, volume 10
       - `panic <= 50`: `"UI_fearful_panic"` ("*Muffled Shriek*"), radius 10, volume 15
       - `panic <= 75`: `"UI_fearful_strongpanic"` ("*Panicked Screech*"), radius 20, volume 25
       - `panic > 75`: `"UI_fearful_extremepanic"` ("*Desperate Screaming*"), radius 25, volume 50
     - Calls `player:Say(getText(text))` — player speaks the localized string.
     - Calls `addSound(...)` with the tier's radius and volume.
     - Increments `playerdata.MTDFearfulCount` if the dynamic mod is active.
  6. **The source never modifies the panic stat.** It is a noise-generation mechanic triggered by panic level; it does not add to or subtract from panic.

## Current UT Evidence

### Structure

- Registered in test harness: yes (`run_tests.lua` line 296, grouped in "Phase 3c — Event-Driven")
- Defined in UT_character_traits.txt: yes (lines 1908–1916)
  - `Cost = -4`
  - `DisabledInMultiplayer = true`
  - `IsProfessionTrait = false`
  - No `MutuallyExclusiveTraits` declared
- Translation strings present: yes
  - `UI_UT_fearful = "Fearful"`
  - `UI_UT_fearfulDesc = "Fear comes quickly and hits hard. Each time a panic event fires, panic is increased by an additional +0.2."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_fearful.lua`)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_fearful.lua` (full file, 41 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1908–1916)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 593–594)
  - `test/run_tests.lua` (line 296)
- Event registrations:
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — trait check at handler entry
- Moddata keys written:
  - `md["UT_fearful_cooldown"]` — integer cooldown counter, initialized to 0 on first access, decremented each frame, reset to 60 on a successful trigger
- Runtime chain (plain language):
  1. Every player-update frame: checks `UTCore.hasTrait`. If the trait is absent, exits.
  2. Initializes `UT_fearful_cooldown` in moddata if nil. If cooldown > 0, decrements it and returns (skip this frame).
  3. Reads `CharacterStat.PANIC` from `player:getStats()`.
  4. If `panic > 5`: computes `chance = 3 + (panic / 10)`.
  5. Rolls `ZombRand(0, 1000) <= chance`. On success:
     - Selects radius and volume based on panic tier:
       - `panic > 75`: radius 25, volume 50
       - `panic > 50`: radius 20, volume 25
       - `panic > 25`: radius 10, volume 15
       - `panic > 5` (else): radius 5, volume 10
     - Calls `player:Say("!")` and `addSound(...)` inside a `pcall`.
     - Resets `UT_fearful_cooldown` to 60.
- Actual behavior (exact values):
  - Threshold: `panic > 5` (matches source).
  - Chance formula: `3 + (panic / 10)` out of 1000 (matches source, but UT does not apply the COWARDLY or unlucky modifiers that source did).
  - Cooldown: 60 player-update frames between eligible trigger checks. Source had no per-player cooldown; it used the global `internalTick == 20` gate (once per 30 frames shared across all handlers).
  - Shout text: hardcoded `"!"` regardless of panic tier. Source used four distinct localized strings.
  - Noise tiers: radius/volume values match source exactly.
  - Stat effect: **none**. The handler does not read, write, add to, or subtract from the panic stat or any other stat. The mechanic is purely noise generation.

## Description Integrity

- Display name check: "Fearful" — matches source trait name.
- Description check: `UI_UT_fearfulDesc` reads: "Fear comes quickly and hits hard. Each time a panic event fires, panic is increased by an additional +0.2."
- Issues found:
  1. **The description is factually wrong about what the trait does.** The description states that "panic is increased by an additional +0.2" each time a panic event fires. The runtime Lua does not add +0.2 (or any value) to the panic stat at any point. `CharacterStat.PANIC` is read but never written. The actual mechanic — randomly making the player shout and emit noise while panicked — is not mentioned anywhere in the description.
  2. **"Each time a panic event fires" describes a hook that does not exist in the UT implementation.** The code does not listen to a panic event; it polls the panic stat value on `OnPlayerUpdate` with a cooldown gate. "Panic event" is not a PZ engine event name and is not the trigger mechanism used here.
  3. **The description does not communicate the noise/zombie-attraction mechanic at all.** The entire gameplay consequence — that the character shouts and produces an `addSound` signal attracting zombies — is absent from the description. A player selecting this trait based on the description would believe it amplifies panic accumulation, not that it causes involuntary sound generation.
  4. **"+0.2 to panic" is the wrong framing even if that mechanic were present.** Per project convention, XPBoosts and stat bonuses use "+N to StatName" phrasing. The description appears to reference an additive panic increment, but the PZ panic stat is on a 0–100 scale (read via `stats:get(CharacterStat.PANIC)` without normalization in this file), so "+0.2" would be a trivially small value on that scale. The description is internally ambiguous even on its own terms.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside: while panicked above threshold (panic > 5 on the 0–100 scale), the player periodically produces an involuntary shout and noise event that can attract zombies.
- Trigger cadence: once every 60 player-update frames minimum, and only when the random roll `ZombRand(0, 1000) <= 3 + (panic/10)` succeeds. At panic = 5 (minimum threshold), chance = 3.5/1000 per eligible frame — extremely low. At panic = 100, chance = 13/1000 per eligible frame, still low in absolute terms but the 60-frame cooldown means maximum one trigger per ~60 frames.
- Noise parameters at maximum panic (> 75): radius 25, volume 50 — significant zombie attraction radius. At low panic (5–25): radius 5, volume 10 — minor.
- Source cost comparison: source charged -7. UT charges -4. UT removed the COWARDLY/unlucky synergy modifiers, removed the four localized shout strings in favour of a silent `"!"`, and added an explicit per-player cooldown. None of these changes reduces the actual noise-attraction risk enough to justify a 3-point cost reduction on their own; the base mechanic (noise at high panic) is identical.
- Source exclusions removed: source excluded `base:brave` and `base:desensitized`. UT declares no `MutuallyExclusiveTraits`. A player could now select UT_fearful alongside traits that would normally prevent being scared (brave, desensitized), creating a contradiction where the character shouts from panic that the other trait should suppress or prevent.
- Stack notes: no exclusions in UT. Can be combined with `UT_nervouswreck`, `UT_scardycat`, `UT_acrophobic`, and other panic-raising traits. Higher panic levels increase shout probability, so stacking panic-inflating traits increases exposure to the noise consequence.
- Cost verdict: -4 is too low given source cost of -7 and the retained core mechanic. Additionally, the description-code mismatch means players are not making informed selections. The cost cannot be properly evaluated while the description misrepresents the effect.

## Regression Proof

- Existing test: `UT_fearful` is listed in the Phase 3c registration sweep (`run_tests.lua` line 296), which confirms the trait ID is registered with `CharacterTrait`. This is the only observed test reference.
- What it proves: the trait ID `"UniversalTraits:UT_fearful"` exists in the CharacterTrait registry. It does not test runtime behavior.
- Missing proof:
  1. No test that `onPlayerUpdate` produces a `Say` call and `addSound` when panic > 5 and the random roll succeeds.
  2. No test that the cooldown gate suppresses calls for the 60 frames following a successful trigger.
  3. No test that no stat modification occurs (i.e., the description bug is not tested as a regression).
  4. No test that noise radius and volume match the expected tier thresholds (panic > 25, > 50, > 75).
  5. No test that the handler exits cleanly when `UTCore.hasTrait` returns false.
  6. No test that the `pcall` wrapper catches and swallows errors from `Say` or `addSound`.
- Minimum next test if needed: "fearful: emits noise when panicked above threshold" — mock a player with the trait and panic = 50, verify `Say` is called with `"!"` and `addSound` is called with radius 20, volume 25 after a single `onPlayerUpdate` fire with `ZombRand` stubbed to return 0.

## Final Verdict

- Source origin: proven — MoreTraits `ToadTraits:fearful` is the confirmed source; B42.15 script definition and runtime located and read. Source cost (-7) does not match UT cost (-4); UT reduced the cost by 3.
- UT implementation: drifted — the core concept (involuntary noise generation when panicked) is preserved, but with several divergences:
  1. **Cooldown mechanism changed**: source used a shared `internalTick == 20` gate (once per 30 frames); UT uses a per-player moddata cooldown of 60 frames reset on trigger. These produce similar spacing but are architecturally different and interact differently with multiple players.
  2. **Shout text stripped**: source played four tiered localized strings (`*Whimper*`, `*Muffled Shriek*`, `*Panicked Screech*`, `*Desperate Screaming*`). UT replaces all with a hardcoded `"!"`. This removes the flavor and the visual panic-level feedback for the player.
  3. **Synergy modifiers removed**: source added to `chance` when the player also had COWARDLY (+1) or unlucky (luckimpact). UT applies only the base `3 + (panic / 10)` formula.
  4. **Mutual exclusions removed**: source excluded `base:brave` and `base:desensitized`. UT declares none, allowing logically contradictory trait combinations.
  5. **pcall wrapper added**: UT wraps `Say` and `addSound` in a `pcall`. Source called them directly. The pcall silently swallows any errors from these calls.
  6. **Multiplayer**: source allowed multiplayer; UT sets `DisabledInMultiplayer = true`.
- Description: **critically wrong** — the description states the trait increases panic by +0.2 per panic event. The runtime does not modify the panic stat at any point. The actual mechanic (noise generation/zombie attraction) is not disclosed in the description. This is the most serious finding in this audit; players selecting the trait based on its description receive an entirely different mechanical effect than advertised.
- Balance: cost of -4 is undervalued relative to source (-7) even accounting for removed synergies; the noise-attraction mechanic at high panic (radius 25, volume 50) is a meaningful stealth liability. The evaluation is blocked by the description bug — the trait cannot be correctly priced while its stated and actual effects differ.
- Regression proof: registration confirmed; zero behavioral tests exist for this trait.
- Action needed:
  1. **Fix the description immediately.** The current text ("panic is increased by an additional +0.2") describes behavior that does not exist. The description must be replaced with one that accurately communicates the noise-generation mechanic. Suggested replacement (for reference, not mandatory): "Your panic breaks your silence. When fear spikes high enough, you may cry out involuntarily — attracting anything nearby."
  2. **Restore tiered shout strings.** The four localized shout strings from source (`*Whimper*`, `*Muffled Shriek*`, `*Panicked Screech*`, `*Desperate Screaming*`) provide player feedback and flavor. The current `"!"` is a silent placeholder that conveys nothing about panic severity.
  3. **Restore mutual exclusions** for `base:brave` and `base:desensitized`, or document a deliberate decision to allow the combination.
  4. **Re-evaluate cost** against the corrected description and with the source cost (-7) as a reference point. -4 is likely too cheap for a trait that imposes zombie-attracting shouts at high panic.
  5. **Restore COWARDLY and unlucky synergy** if the intent was a faithful port, or document the deliberate removal.
  6. **Add behavioral tests** covering: noise emission on valid panic threshold and successful roll, cooldown suppression for 60 frames post-trigger, tier-correct radius/volume values, handler guard exit when trait absent.
- Open gaps:
  - It is unknown whether the +0.2 panic mechanic in the description was an earlier planned implementation that was replaced by the noise mechanic without updating the description, or whether the description was written in error from the start.
  - The `pcall` swallowing errors from `Say`/`addSound` means any failure in those calls (e.g., nil player state, missing function) will be silent in production. This warrants a comment or logging at minimum.
  - No mutual exclusions means stacking with other panic-raising UT traits (`UT_nervouswreck`, `UT_scardycat`, `UT_acrophobic`) is unrestricted; high panic makes shout triggers more likely and more dangerous (higher radius/volume tiers).
