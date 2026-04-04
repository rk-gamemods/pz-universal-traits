# UT_paranoia

## Trait Summary

- UT trait id: UT_paranoia
- Source mod: More Traits (ToadTraitParanoia)
- Source trait id: `paranoia` (vanilla-style string id, not namespaced)
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/client/MoreTraits.lua` (runtime implementation — `ToadTraitParanoia`, lines 805–834)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/shared/Translate/EN/UI_EN.txt` (source strings, lines 166–167)
- Source trigger path: `Events.EveryOneMinute.Add(EveryOneMinute)` — fires every real-time minute; `ToadTraitParanoia` is called inside that handler
- Source behavior:
  - Checks `player:HasTrait("paranoia")` and a cooldown counter `iParanoiaCooldown` (initialised to 10, stored in modData).
  - When cooldown is zero: if the player is moving, rolls `ZombRand(100)+1` against `basechance = 1`. On a hit (1-in-100 chance), adds **+25 panic** and **+0.1 stress**, plays a breath-panic sound, and resets the cooldown to 30.
  - When cooldown is non-zero: decrements the cooldown by 1.
  - Net effect: a rare, conditional random scare (1% chance per minute while moving, gated by a 30-minute cooldown) that applies a significant but one-off spike of panic and stress.
- Source description: "Periodically, you will get a false scare and panic. You will need to actively find ways to reduce your stress — it only gets worse after a paranoia attack."

## Current UT Evidence

### Structure

- Registered in registries.lua: yes (confirmed — `UniversalTraits:UT_paranoia` appears in the `expected_ids` list in `test/run_tests.lua` line 282, Phase 3b — Periodic-Check)
- Defined in UT_character_traits.txt: yes (lines 1659–1667)
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_paranoia`
  - `Cost = -4`
  - No `MutuallyExclusiveTraits` declared
  - No `GrantedTraits` declared
- Translation strings present: yes
  - `UI_UT_paranoia = "Paranoia"`
  - `UI_UT_paranoiaDesc = "Every shadow hides something. Every 10 in-game minutes, panic increases by +0.06."`
- Exclusions/grants correct: no exclusions declared; no grants declared — acceptable for a standalone negative trait
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_paranoia.lua`)

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_paranoia.lua` (full file, 14 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1659–1667)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 518–519)
  - `test/run_tests.lua` (line 282)
- Event registrations:
  - `Events.EveryTenMinutes.Add(handler)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` — the only UT_CORE call in the file
- Runtime chain (plain language):
  1. Every 10 in-game minutes, the handler fires.
  2. Guards: returns immediately if `getPlayer()` returns nil, or if the player does not have the trait.
  3. Reads the current panic value via `player:getStats():getPanic()`.
  4. Adds 0.06 to the current panic value, capped at 1.0 via `math.min(1, ...)`.
  5. Writes the result back with `stats:setPanic(...)`.
- Actual behavior (exact values):
  - Panic delta: +0.06 per 10 in-game minutes, applied unconditionally as long as the player is alive and has the trait
  - Panic ceiling: 1.0 (clamped by `math.min`)
  - No stress effect
  - No randomness — fires deterministically every 10 in-game minutes
  - No cooldown mechanism
  - No movement condition

## Description Integrity

- Display name check: "Paranoia" — matches the trait concept; acceptable
- Description check: "Every shadow hides something. Every 10 in-game minutes, panic increases by +0.06." — the description is factually accurate and complete. The period (10 in-game minutes), the stat affected (panic), and the magnitude (+0.06) all match the runtime exactly.
- Missing or misleading details:
  - The description does not mention the panic ceiling (1.0). A player could reasonably wonder whether panic accumulates without bound or caps somewhere.
  - The description does not state that the increment is unconditional (fires even indoors, while resting, regardless of activity). Contrast with the source's movement-gated and cooldown-gated design — the UT version is notably more punishing because it never stops accruing until the cap is reached.
  - No mention of `DisabledInMultiplayer = true`, which is unusual for a trait that only touches stats. This flag could surprise players in a co-op context.

## Balance Review

- Upside: none — this is a pure negative trait that returns -4 points at character creation
- Downside: panic increases by +0.06 per 10 in-game minutes, unconditionally. At this rate, panic reaches the 1.0 ceiling in approximately 167 in-game minutes (~2.8 in-game hours) of continuous play if no other panic reduction occurs
- Peer comparison within the Phase 3b Periodic-Check group:
  - `UT_depressive` (presumably degrades mood periodically) is the closest structural peer
  - At -4 points, `UT_paranoia` occupies the mid-tier negative cost range
- Severity assessment: the UT implementation is substantially harsher than the source. The More Traits source fires at most once per 30 minutes (due to cooldown), only while moving, at a 1-in-100 chance, for a spike of +25 panic (on a 0–100 scale). The UT version applies a guaranteed +0.06 every 10 in-game minutes on a 0–1 scale. Because the PZ panic scale is 0–1 internally, +0.06 per 10 minutes accumulates rapidly and cannot be outrun by ordinary gameplay unless panic is actively managed.
- The -4 point cost may undervalue the severity of a guaranteed, unconditional, continuous panic drain that reaches maximum in under 3 in-game hours. For comparison, traits with purely conditional downsides often carry lighter negative costs.
- Cost verdict: potentially under-priced given the unconditional and relentless nature of the panic accumulation; -4 is defensible only if the player has reliable access to panic-reduction mechanics

## Regression Proof

- Existing tests:
  - `run_tests.lua` line 282: `"UniversalTraits:UT_paranoia"` is included in the `expected_ids` registration list; the `"all 198 trait IDs registered with CharacterTrait"` test (line 312) confirms the trait ID is registered
  - `"script trait definitions resolve cleanly"` test (line 347) implicitly covers the script block (verifies `block_id == character_trait`, registry presence, and MutuallyExclusiveTraits/GrantedTraits validity)
- What the tests prove: the trait is registered, the script block is structurally valid, and no MutuallyExclusiveTraits or GrantedTraits entries are broken
- Missing proof:
  - No test verifies the runtime handler fires correctly on `Events.EveryTenMinutes`
  - No test verifies that panic is incremented by exactly 0.06
  - No test verifies the `math.min(1, ...)` ceiling clamp (i.e., panic cannot exceed 1.0)
  - No test verifies the early-return guard when `getPlayer()` returns nil
  - No test verifies that a player without the trait is unaffected (guard path)
- Minimum next test if needed: Construct a mock player with `TRAIT_ID` and `stats:getPanic() = 0.50`, fire the `EveryTenMinutes` handler once, assert `stats:getPanic() == 0.56`. Add a cap test: set panic to `0.97`, fire handler, assert result is `1.0` not `1.03`. Add a guard test: player without trait, fire handler, assert panic unchanged.

## Final Verdict

- Source origin: proven — More Traits `ToadTraitParanoia` confirmed in source runtime and translation
- UT implementation: redesigned — the source uses a random, movement-gated, cooldown-limited panic spike (+25 on a 0–100 scale, 1% chance per minute, 30-minute cooldown); the UT version replaces this entirely with a deterministic, unconditional, continuous panic drain (+0.06 per 10 in-game minutes on a 0–1 scale, no conditions, no cooldown). The spirit (paranoia causes recurring panic) is preserved, but the mechanics are fundamentally different
- Description: accurate but incomplete — correctly states the period and delta; omits the panic ceiling, the unconditional firing condition, and the multiplayer restriction
- Balance: potentially under-priced — the unconditional and relentless nature of the panic accumulation is more punishing than the -4 point cost suggests; review against peer negative traits in the same phase
- Regression proof: minimally protected — registration and script structure are verified; runtime behavior (increment, cap, guard) is completely untested
- Action needed: description fix + test fix + balance review
- Open gaps:
  - Add the panic ceiling (1.0) and the unconditional firing condition to `UI_UT_paranoiaDesc`
  - Consider noting `DisabledInMultiplayer` in the description or removing the flag if there is no design reason for it
  - Add runtime unit tests: increment accuracy, cap clamp, guard paths (nil player, no trait)
  - Re-evaluate the -4 cost against other Phase 3b traits; the unconditional nature may warrant -5 or -6
