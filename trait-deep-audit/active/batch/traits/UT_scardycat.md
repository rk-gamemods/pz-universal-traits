# UT_scardycat

## Trait Summary

- UT trait id: UT_scardycat
- Source mod: SomewhatTraits (SomewhatTraitsCore)
- Source trait id: SWTraits:SWScaredycat (trait key: "SWScaredycat")
- Current cost: -3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/registries.lua` (line 42: `"SWScaredycat", -- -3`)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/registries.lua` (line 42: `"SWScaredycat", -- -3`)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/lua/shared/Translate/EN/UI_EN.txt` (lines 63–64)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/scripts/SWTraits_character_traits.txt` (lines 265–273 and 279–288) — B42.13 script definition
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/lua/shared/SWTraits_MET.lua` (lines 82–92) — mutual exclusions
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.12/media/lua/client/SWSomewhatTraitsCore.lua` (lines 126, 699–710, 1086) — legacy client
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.13/media/lua/client/SWTraitsCore_client.lua` (lines 167–179) — B42.13 client
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/client/SWTraitsCore_client.lua` (lines 167–179) — B42.15 client (identical to 42.13)
- Source cost: -3 (confirmed in registries.lua comment, both 42.13 and 42.15).
- Source display name: "Scaredy-cat" (EN translation: `UI_trait_SWScaredycat = "Scaredy-cat"`)
- Source description: "Chance to scream when surrounded, based on the amount of very close zombies."
- Source `DisabledInMultiplayer`: `false` in both B42.13 script definitions — the source supports multiplayer via `processShoutMessage`.
- Source trigger path:
  - Legacy (SWSomewhatTraitsCore.lua, 42.12): `Events.OnTick.Add(SWScardycat)` — fires every engine tick, no player argument.
  - B42.13 and B42.15 (SWTraitsCore_client.lua): `Events.OnPlayerUpdate.Add(SWScaredycat)` — fires per player update, receives `player` argument.
- Source behavior (B42.13 and B42.15, identical):
  1. Reads `player:getStats():getNumVeryCloseZombies()` — the count of zombies within a "very close" radius (a different API than `getSpottedList`).
  2. Caps the count at 10: `if closeZombies > 10 then closeZombies = 10 end`.
  3. Rolls `ZombRand(0, 200) < closeZombies` — at max cap of 10 zombies this is a 5% chance per update tick (10/200); at 1 very close zombie it is 0.5%.
  4. On a hit: calls `processShoutMessage` (multiplayer) or `player:SayShout` (singleplayer) with the localised "SWScream" string.
  5. Generates `AddWorldSound`: 30-unit radius outdoors, 15-unit radius indoors.
  6. No cooldown in source — fires on every tick the roll succeeds.
- Source mutual exclusions (B42.13 script and SWTraits_MET.lua):
  - `SWScaredycat` is mutually exclusive with `SWFlailer` (declared both ways in script definition and programmatically in MET.lua).
  - `SWScaredycat` is mutually exclusive with vanilla `Desensitized` (programmatically, if available).
  - `SWFlailer` script definition also lists `SWScaredycat` in its `MutuallyExclusiveTraits`.
  - `Desensitized` script definition lists both `SWFlailer` and `SWScaredycat`.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes (line 277, grouped under `-- PHASE 3c -- EVENT-DRIVEN TRAITS`)
  - `UTTraitsRegistries.UT_scardycat = CharacterTrait.register("UniversalTraits:UT_scardycat")`
- Defined in UT_character_traits.txt: yes (lines 1928–1936)
  - `Cost = -3`
  - `DisabledInMultiplayer = true`
  - `IsProfessionTrait = false`
  - No `MutuallyExclusiveTraits` declared
- Translation strings present: yes (UI_EN.txt lines 599–600)
  - `UI_UT_scardycat = "Scaredy Cat"`
  - `UI_UT_scardycatDesc = "You startle easily and panic often. Each time a panic event fires, panic is increased by an additional +0.15. When surrounded by many zombies, you may involuntarily scream and attract attention."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_scardycat.lua`, 40 lines)
- Loaded in test harness: yes (`test/run_tests.lua` line 736, under `-- Task 7: SomewhatTraits behavior ports`)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_scardycat.lua` (full file, 40 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1928–1936)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 599–600)
  - `media/registries.lua` (line 277)
  - `test/run_tests.lua` (lines 291, 736, 788–804)
- Event registrations:
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — trait check guard at top of handler
- Runtime chain (plain language):
  1. On every player update: checks `UTCore.hasTrait(player, TRAIT_ID)`; exits if false.
  2. Reads or initialises `modData["UT_scardycat_cooldown"]` to 0 if nil.
  3. If cooldown > 0: decrements by 1 and exits. (Cooldown is a per-update-tick counter, not wall-clock time.)
  4. Counts spotted zombies via `player:getSpottedList():size()` inside a `pcall` — defaults to 0 on error. Exits if `zombieCount <= 8`.
  5. Rolls `ZombRand(100) < 3` — flat 3% chance.
  6. On a hit: attempts `player:ShouldBeShouting(true)` via `pcall`; if that call errors, falls back to `player:Say("!")` via `pcall`. Sets `modData["UT_scardycat_cooldown"] = 120`.
- Actual behavior (exact values):
  - Zombie threshold: `> 8` spotted zombies required (i.e., 9 or more triggers eligibility).
  - Scream chance per eligible update tick: flat 3% (`ZombRand(100) < 3`), independent of zombie count.
  - Noise on scream: none — `ShouldBeShouting` signals an animation/shout flag but does not call `AddWorldSound`. The `player:Say("!")` fallback is a local chat bubble. Neither path generates a world-sound event.
  - Cooldown after scream: 120 update ticks.
  - No panic modifier is applied at runtime — the description's claim of "+0.15 panic per panic event" is not implemented in this Lua file.

## Description Integrity

- Display name check: "Scaredy Cat" — minor spelling divergence from source "Scaredy-cat" (hyphen absent); not a functional issue.
- Description check: `UI_UT_scardycatDesc` reads: "You startle easily and panic often. Each time a panic event fires, panic is increased by an additional +0.15. When surrounded by many zombies, you may involuntarily scream and attract attention."
- Issues found:
  1. **Panic modifier claim is unimplemented.** The description states "Each time a panic event fires, panic is increased by an additional +0.15." No such mechanic appears anywhere in `UT_scardycat.lua`. There is no `Events.OnPanicEvent`, no `OnMoodleChange`, and no modData key related to panic increment. If this modifier is applied by a different shared handler reading a modData flag, that consumer was not found in this file or in the registries. As written, this claim describes behavior that does not exist in the ported trait — it belongs to `UT_nervouswreck` or a similar panic-augmentation trait, not scardycat.
  2. **Zombie metric substitution.** The source reads `stats:getNumVeryCloseZombies()` — zombies within a tight proximity radius. The UT port reads `player:getSpottedList():size()` — the spotted list, which includes zombies the player has line-of-sight on at any range, potentially a much larger set. These are different APIs with different threat footprints. The threshold (> 8 spotted vs. > 10 very-close capped at 10 in source) is also different.
  3. **No world sound generated.** The source always fires `AddWorldSound` (30-unit radius outdoors, 15 indoors) when a scream triggers, creating a genuine noise event that attracts zombies. The UT port's `ShouldBeShouting(true)` call does not call `AddWorldSound`. The fallback `player:Say("!")` is a local text bubble. "Attract attention" in the description implies world-sound noise generation; the UT port does not produce it.
  4. **Scream API mismatch.** Source uses `SayShout` (which generates a shout audio event and text) or `processShoutMessage` in multiplayer. UT uses `ShouldBeShouting(true)` — a different call that sets an internal flag — then falls back to `Say("!")`. These produce different auditory and visual results.
  5. **No cooldown in source; UT adds 120-tick cooldown.** The source has no cooldown — every eligible tick is an independent roll. UT adds a 120-tick cooldown, significantly reducing scream frequency at the expense of source fidelity. This is a design addition not present in source.
  6. **UT set to `DisabledInMultiplayer = true`; source was `false`.** The source explicitly supported multiplayer via `processShoutMessage`. UT disables the trait in multiplayer entirely, losing the multiplayer-compatible scream path that the source provided.
  7. **No mutual exclusions.** Source excluded `SWScaredycat` from `SWFlailer` and vanilla `Desensitized`. UT declares no exclusions — `UT_scardycat` and `UT_flailer` can be combined, stacking two distinct panic/zombie-triggered event mechanics, which the source prevented.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside:
  - If the scream fires: an animation/shout flag is set (cosmetic) or a `Say("!")` text bubble appears. No real-world noise event is generated. The scream has no gameplay cost beyond the visual.
  - The panic modifier described ("+0.15 per panic event") does not exist in the runtime. If taken at face value the trait should compound panic accumulation — but it does not.
- Effective cost delivered: as implemented, the trait delivers a cosmetic scream animation with no world-sound consequence, gated behind ≥ 9 spotted zombies and a flat 3% roll with a 120-tick cooldown. There is no functional downside beyond the visual.
- Peer comparison:
  - `UT_nervouswreck` costs -4 and actually does modify panic accumulation with a real runtime hook.
  - `UT_fearful` costs -4 and has a documented panic-event hook.
  - `UT_scardycat` at -3 should deliver a meaningful scream mechanic with noise generation. As ported it delivers a cosmetic-only effect.
- Cost verdict: severely underdelivered. The -3 cost is defensible if the panic modifier and world-sound scream are both live. As implemented, neither is present. The trait is functionally near-inert and does not justify a point refund.
- Stack or exclusion notes: No exclusions declared. Can be combined with `UT_flailer` (source excluded these). Can be combined with `UT_nervouswreck` (both claim panic augmentation; only nervouswreck delivers it).

## Regression Proof

- Existing tests:
  1. **`UT_scardycat` listed in Phase 3c registration array** (`run_tests.lua` line 291) — confirms the trait ID is present in the known-traits registration sweep.
  2. **"scardycat screams when 10 zombies spotted"** (`run_tests.lua` lines 788–804) — creates a `MockUpdatePlayer` with the trait and `spottedSize = 10`, fires `Events.OnPlayerUpdate`, asserts `player._shouted == true` or `player._said ~= nil`. Confirms the happy-path scream fires when cooldown is nil and `ZombRand` returns 0 (< 3).
- What the existing test proves: with ≥ 9 spotted zombies, no cooldown, and a guaranteed roll, either `ShouldBeShouting` or `Say("!")` fires. End-to-end happy path for the scream branch is covered.
- Missing proof:
  1. No test that `zombieCount <= 8` (e.g., exactly 8) suppresses the scream.
  2. No test that `ZombRand` returning ≥ 3 (e.g., 5) suppresses the scream.
  3. No test that the 120-tick cooldown blocks a second scream before expiry — i.e., a second `Events.OnPlayerUpdate:fire` with cooldown at 119 should not re-scream.
  4. No test that cooldown decrements correctly (fires with cooldown = 1 → exits without scream; fires again with cooldown = 0 → eligible again).
  5. No test for the `pcall` guard around `getSpottedList` — a player mock with no `getSpottedList` should safely default to 0 and not crash.
  6. No test that a player without the trait is unaffected (though the registration sweep partially covers this conceptually).
  7. No test for the panic modifier described in the UI string (because no such code exists to test).
- Minimum next test if needed: "scardycat: 8 zombies spotted suppresses scream" — create MockUpdatePlayer with trait, `spottedSize = 8`, fire OnPlayerUpdate, assert `_shouted` is nil/false and `_said` is nil.

## Final Verdict

- Source origin: proven — SomewhatTraits `SWScaredycat` is the confirmed source. Source cost (-3) matches UT cost exactly. Source name "Scaredy-cat" is represented as "Scaredy Cat" (minor punctuation change only).
- UT implementation: significantly drifted with critical gaps:
  1. **Panic modifier in description does not exist in code.** The description's "+0.15 panic per panic event" clause has no runtime implementation in `UT_scardycat.lua` or in any visible shared hook — this is either dead description copy from a different trait or an unimplemented feature. It must be either implemented or removed.
  2. **Zombie API substitution changes trigger geometry.** Source uses `getNumVeryCloseZombies()` (proximity radius, capped at 10); UT uses `getSpottedList():size()` (spotted list, threshold > 8). These are meaningfully different trigger conditions.
  3. **World sound is absent.** Source always fires `AddWorldSound` on scream; UT does not. The core gameplay consequence — attracting zombies with noise — is missing. The UT scream is cosmetic only.
  4. **Scream API is weaker.** Source uses `SayShout` / `processShoutMessage`; UT uses `ShouldBeShouting(true)` with a `Say("!")` fallback. These do not produce equivalent audio or visual results.
  5. **UT adds a 120-tick cooldown absent from source.** This is a design addition that reduces scream frequency and deviates from source behavior without disclosure.
  6. **Multiplayer disabled in UT; source supported it.** The source explicitly handled the multiplayer case via `processShoutMessage`. UT sets `DisabledInMultiplayer = true`, removing multiplayer functionality the source provided.
  7. **No mutual exclusions.** Source excluded `SWScaredycat` from `SWFlailer` and `Desensitized`. UT declares none.
- Description: inaccurate in two material ways — (1) the panic modifier clause describes a mechanic that is not implemented; (2) "attract attention" implies world-sound noise generation that the implementation does not produce.
- Balance: the trait is near-inert as implemented. Without the world-sound scream and with the panic modifier absent, the trait delivers no meaningful gameplay downside for its -3 cost.
- Regression proof: happy path covered by one test; suppression conditions, cooldown behavior, and the non-existent panic modifier are not tested.
- Action needed:
  1. **Implement or remove the panic modifier.** Either add an `OnPanicEvent` (or equivalent) handler that adds +0.15 panic, or remove that sentence from the description entirely. This is the highest-priority fix — the description currently advertises behavior that does not exist.
  2. **Add `AddWorldSound` to the scream path.** When `ShouldBeShouting` fires (or its fallback), add `AddWorldSound(player, 30, 30)` outdoors and `AddWorldSound(player, 15, 15)` indoors, matching the source. Without this the trait has no gameplay consequence.
  3. **Reconsider the zombie API.** Decide whether `getSpottedList():size()` or `getNumVeryCloseZombies()` (if exposed in B42) better matches the intended "surrounded" trigger. If sticking with the spotted list, update the description to say "many zombies spotted" rather than "surrounded".
  4. **Reconsider `DisabledInMultiplayer`.** The source supported multiplayer. If the scream mechanic is safe in multiplayer (with a shared-Lua-friendly implementation), change to `false` and use an appropriate shout path.
  5. **Add mutual exclusion with `UT_flailer`** at minimum, matching source. Consider exclusion with vanilla Desensitized for logical consistency.
  6. **Fix description** to remove the unimplemented panic-modifier sentence and to accurately describe the zombie threshold (≥ 9 spotted) and the 3% flat chance with 120-tick cooldown.
  7. **Add tests** for the suppression conditions (≤ 8 zombies, roll ≥ 3, cooldown active), cooldown decrement behavior, and the pcall guard around `getSpottedList`.
- Open gaps:
  - Confirm whether `getNumVeryCloseZombies()` is accessible via `player:getStats()` in B42 shared Lua (it is a client-side API in source; if unavailable shared-side, the spotted-list substitution may be intentional for harness compatibility, but should still add world-sound).
  - Confirm whether a panic-event hook exists in UTCore's shared infrastructure that `UT_scardycat` was intended to plug into but never did.
  - The 120-tick cooldown is unacknowledged in the description — if kept, disclose it ("with a brief cooldown between screams" or similar).
