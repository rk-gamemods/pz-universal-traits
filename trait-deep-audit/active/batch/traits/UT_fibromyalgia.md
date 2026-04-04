# UT_fibromyalgia

## Trait Summary
- UT trait id: UT_fibromyalgia
- Source mod: FillerTraits — one source analogue confirmed; DynamicTraitsExpandedMoodles has the trait commented out and is not active
- Source trait id: `Fibromyalgia` (FillerTraits, no namespace prefix)
- Current cost: -8
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/FillerTraits/mods/FillerTraits/media/lua/shared/NPCs/UpgradeMainCreationMethods.lua` (registration, lines 7–8, 20)
  - `research/installed-mods/FillerTraits/mods/FillerTraits/media/lua/client/UpgradeTraits.lua` (runtime implementation — `Fibromyalgia`, lines 129–137, 147)
  - `research/installed-mods/FillerTraits/mods/FillerTraits/common/lua/shared/NPCs/UpgradeMainCreationMethods.lua` (registration duplicate — common version, lines 8, 21)
  - `research/installed-mods/FillerTraits/mods/FillerTraits/common/lua/client/UpgradeTraits.lua` (runtime duplicate — common version, lines 218–237)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/NPCs/DTEMMainCreationMethods.lua` (line 481 — commented out, not active)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/shared/NPCs/DTMainCreationMethods.lua` (line 209 — commented out, not active)

- Source registration (FillerTraits):
  - `TraitFactory.addTrait("Fibromyalgia", getText("Fibromyalgia"), -6, getText("In constant states of moderate physical pain."), false, false)`
  - `TraitFactory.setMutualExclusive("Analgesia", "Fibromyalgia")` — bidirectional mutual exclusion with Analgesia

- Source trigger path:
  - Function `Fibromyalgia()` registered with `Events.OnPlayerUpdate.Add(Fibromyalgia)` — fires every player game-tick (not every 10 minutes)

- Source behavior (FillerTraits — `Fibromyalgia`, client/UpgradeTraits.lua lines 129–137):
  - Calls `getPlayer()`, `player:getStats()`, `player:getModData()`, `player:getBodyDamage()`
  - Reads `bodydamage:getOverallBodyHealth()`
  - `if player:HasTrait("Fibromyalgia") then stats:setPain(40)` — **sets pain to a flat 40, unconditionally, every player tick**
  - No gradual accumulation — it is a hard `setPain` override, not an increment
  - No sleep check, no health threshold

- Source display name: `getText("Fibromyalgia")` — no dedicated translation key; uses the raw string "Fibromyalgia" as the label
- Source description: `getText("In constant states of moderate physical pain.")` — raw string, no translation key
- Source cost: -6 (FillerTraits registration line)
- Source exclusions: `Analgesia` ↔ `Fibromyalgia` — bidirectional via `TraitFactory.setMutualExclusive`

- DynamicTraitsExpandedMoodles note: both B41 and B42 versions of DTEM have the Fibromyalgia `addTrait` call commented out (`--TraitFactory.addTrait(...)`). The trait does not exist in DTEM at runtime and provides no usable source evidence.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes
  - `UTTraitsRegistries.UT_fibromyalgia = CharacterTrait.register("UniversalTraits:UT_fibromyalgia")` at line 258
  - Neighbours in file: after `UT_albino`, before `UT_bigorexia`
- Defined in UT_character_traits.txt: yes — lines 1773–1781
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_fibromyalgia`
  - `Cost = -8`
  - `UIName = UI_UT_fibromyalgia`
  - `UIDescription = UI_UT_fibromyalgiaDesc`
  - No `XPBoosts` block
  - No `MutuallyExclusiveTraits` block — **no mutual exclusions declared in the script definition**
- Translation strings present: yes (UI_EN.txt lines 551–552)
  - `UI_UT_fibromyalgia = "Fibromyalgia"`
  - `UI_UT_fibromyalgiaDesc = "Chronic pain is your constant companion. Everyday exertion costs more than it should, and bad days can be genuinely debilitating."`
- Exclusions verified: **none** — the script definition for `UT_fibromyalgia` has no `MutuallyExclusiveTraits` entry, and no other UT trait's script definition references `UT_fibromyalgia` in its exclusion list. The source had `Fibromyalgia` ↔ `Analgesia` mutual exclusion; UT has `UT_analgesia` but it lists only `UT_glassbody` in its exclusion — fibromyalgia is absent. The mutual exclusion from source is not carried over.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_fibromyalgia.lua`

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_fibromyalgia.lua` (full file, 15 lines)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (UTCore.hasTrait definition)
  - `media/scripts/UT_character_traits.txt` (lines 1773–1781)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 551–552)
  - `test/run_tests.lua` (line 288 — expected_ids, Phase 3b)

- Full Lua file (15 lines):
  ```lua
  -- UT_fibromyalgia.lua
  -- Fibromyalgia: chronic pain causes persistent stress and fatigue

  local TRAIT_ID = "UniversalTraits:UT_fibromyalgia"

  local function handler()
      local player = getPlayer()
      if not player then return end
      if not UTCore.hasTrait(player, TRAIT_ID) then return end
      local stats = player:getStats()
      stats:setStress(math.min(1, stats:getStress() + 0.07))
      stats:setFatigue(math.min(1, stats:getFatigue() + 0.05))
  end

  Events.EveryTenMinutes.Add(handler)
  ```

- Event registrations: `Events.EveryTenMinutes.Add(handler)` — fires every 10 in-game minutes

- UTCore hooks used: `UTCore.hasTrait(player, TRAIT_ID)`
  - Defined in `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` lines 11–15
  - Implementation: calls `player:getTraits()`, returns `traits:contains(traitId)`
  - Nil-safe: guards `not player` and `not traits` before the contains call
  - No side effects — pure read-only predicate

- Runtime chain (plain language):
  1. `handler` fires every 10 in-game minutes via `Events.EveryTenMinutes`.
  2. `getPlayer()` is called; if nil, returns early (nil-guard).
  3. `UTCore.hasTrait(player, "UniversalTraits:UT_fibromyalgia")` is called; if the player does not have the trait, returns early (trait-guard).
  4. `player:getStats()` is called to retrieve the stats object.
  5. **Stress increment:** `stats:setStress(math.min(1, stats:getStress() + 0.07))` — stress increases by exactly **+0.07** per tick, hard-capped at 1.0.
  6. **Fatigue increment:** `stats:setFatigue(math.min(1, stats:getFatigue() + 0.05))` — fatigue increases by exactly **+0.05** per tick, hard-capped at 1.0.
  7. No sleep check — both increments fire unconditionally, including during sleep.
  8. No pain manipulation — despite the trait name and source implementation using `setPain`, the UT implementation never touches the pain stat.
  9. No randomness — all increments are flat and deterministic.
  10. No moddata reads or writes — stateless tick function.

- Exact per-tick values:
  - Stress: +0.07 / 10 min → from 0 to 1.0 in ~142.8 in-game minutes (~2 hours 23 minutes)
  - Fatigue: +0.05 / 10 min → from 0 to 1.0 in ~200 in-game minutes (~3 hours 20 minutes)

- Peer comparison (same EveryTenMinutes pattern):
  - `UT_depressive`: +0.08 stress only (single stat)
  - `UT_melancholic`: +0.05 stress only (single stat)
  - `UT_pessimist`: +0.05 stress only (single stat)
  - `UT_fibromyalgia`: +0.07 stress **and** +0.05 fatigue (two stats, higher aggregate pressure)

## Description Integrity
- Display name check: `"Fibromyalgia"` — matches source exactly. No issue.
- Description check: `"Chronic pain is your constant companion. Everyday exertion costs more than it should, and bad days can be genuinely debilitating."`
- Accuracy issues found:
  1. **Pain stat is never touched** — the description says "Chronic pain" and the source mod implements this via `setPain(40)`. The UT implementation instead raises stress and fatigue. The description uses pain-flavored language but the affected stats are stress and fatigue only. Players reading the description would reasonably expect the pain moodle to be engaged; it is not.
  2. **No mechanical disclosure** — unlike `UT_depressive` (whose description states "+0.08 stress per 10 minutes"), the fibromyalgia description contains no numerical claim about which stats are affected or at what rate. The phrase "everyday exertion costs more than it should" is ambiguous — it could imply fatigue, stamina, or pain. None of the three actually-affected stats (stress, fatigue) are named.
  3. **"Bad days can be genuinely debilitating"** — implies intermittent flare behaviour (random spikes on bad days), which is absent from the implementation. The handler is deterministic and fires uniformly every 10 minutes. There is no bad-day mechanic.
  4. **No sleep exemption** — handler fires during sleep; description does not mention this.
- Overall description verdict: the description is flavourful but mechanically opaque and partially misleading. It implies pain moodle involvement (none), implies random flare events ("bad days", none), and names no stats or values. The actual mechanical effect (periodic stress and fatigue accumulation) is entirely invisible to a player reading the description.

## Balance Review
- Downsides:
  - Stress: +0.07 per 10 minutes; max stress reached from floor in ~143 minutes of play
  - Fatigue: +0.05 per 10 minutes; max fatigue reached from floor in ~200 minutes of play
  - Both effects are unconditional, applying during sleep, looting, driving, and combat
  - Two simultaneous stat drains — the only EveryTenMinutes trait in the comparison set to affect two stats
- Upside: none (purely negative trait)
- Uptime: 100% — no conditions, no exemptions
- Cost: -8 points (UT)
- Source cost: -6 (FillerTraits)
- Cost delta analysis:
  - The UT implementation costs -8 vs. the source's -6. The UT version substitutes the source's pain override (flat `setPain(40)`) with two parallel accumulating stat drains (stress + fatigue). The aggregate pressure of two simultaneous drains is objectively heavier than a flat pain value that is merely maintained at 40, making the higher cost defensible.
  - However, the source's `setPain(40)` fired on `OnPlayerUpdate` (every tick), which is far more aggressive than `EveryTenMinutes` in terms of how quickly it restores after external healing. The UT implementation allows stress and fatigue to be temporarily suppressed by in-game mechanics between ticks; the source did not allow pain to drop below 40 at all.
  - Net balance judgement: -8 is plausible for dual-stat drain, but the description opacity means the player cannot make an informed purchase decision.
- Peer balance concerns:
  - `UT_depressive` (-4): +0.08 stress/tick (single stat, faster stress rise but only one stat)
  - `UT_melancholic` (-4): +0.05 stress/tick (single stat, slower)
  - `UT_pessimist` (-4): +0.05 stress/tick (single stat, slower)
  - `UT_fibromyalgia` (-8): +0.07 stress/tick + +0.05 fatigue/tick (two stats) — double the cost of the single-stat peers, reasonable given the dual pressure
- Missing mutual exclusion: the source explicitly blocked `Fibromyalgia` + `Analgesia` stacking. In UT, `UT_analgesia` (cost +12, a pain-suppression trait) has no exclusion against `UT_fibromyalgia`. A player can hold both simultaneously. Since UT fibromyalgia does not manipulate pain, the interaction is mechanically harmless but thematically incoherent — taking both "feels no pain" and "chronic pain" is logically contradictory with no gameplay consequence to reinforce it.

## Regression Proof
- Existing tests:
  - `run_tests.lua` line 288: `"UniversalTraits:UT_fibromyalgia"` appears in the `expected_ids` table (Phase 3b — Periodic-Check group). This is included in the `test("all 198 trait IDs registered with CharacterTrait", ...)` assertion (line 312–322) and the `test("total registration count is 198", ...)` assertion (line 341–345).
  - `run_tests.lua` line 324–339: `test("script costs match the current balance decisions", ...)` parses `UT_character_traits.txt` and spot-checks four named traits' costs. `UT_fibromyalgia` is **not** one of the four spot-checked traits — its cost of -8 is not verified by any test.
  - `run_tests.lua` line 347–384: `test("script trait definitions resolve cleanly and preserve UT_MET coverage", ...)` checks that every definition's `block_id == character_trait` and that all referenced IDs are registered. This test does pass through the `UT_fibromyalgia` block and validates that `CharacterTrait = UniversalTraits:UT_fibromyalgia` matches the block header and that the registry entry exists.
- What the tests prove:
  - The trait is registered in the registry (CharacterTrait.register called with the correct ID)
  - The script definition block is internally consistent (block_id == CharacterTrait field)
  - The total registration count includes fibromyalgia
- Missing proof:
  - No test verifies that the `handler` increments stress by exactly **+0.07** per call.
  - No test verifies that the `handler` increments fatigue by exactly **+0.05** per call.
  - No test verifies the `math.min(1, ...)` cap on stress (i.e., no overflow above 1.0).
  - No test verifies the `math.min(1, ...)` cap on fatigue.
  - No test verifies the nil-guard (`if not player then return end`).
  - No test verifies the trait-guard (`UTCore.hasTrait` returning false causes early exit).
  - No test verifies that the handler fires on `EveryTenMinutes` and not on a different event.
  - No test verifies the script cost of -8.
  - No test verifies the absence of `MutuallyExclusiveTraits` (or confirms that the missing exclusion with `UT_analgesia` is intentional).
- Minimum next test if needed: Mock `player:getStats()` returning a stats object with `getStress() == 0.96` and `getFatigue() == 0.97`. Invoke `handler` with the player holding `"UniversalTraits:UT_fibromyalgia"`. Assert `setStress` receives `1.0` (cap enforced at 0.96 + 0.07 = 1.03 → capped). Assert `setFatigue` receives `1.0` (cap enforced at 0.97 + 0.05 = 1.02 → capped). Then repeat with `getStress() == 0.5` and `getFatigue() == 0.5`; assert `setStress` receives `0.57` and `setFatigue` receives `0.55`.

## Final Verdict
- Source origin: FillerTraits `Fibromyalgia` confirmed as the sole active source. DynamicTraitsExpandedMoodles has the trait commented out in both B41 and B42 versions and contributes no active evidence.
- UT implementation: substantially redesigned relative to source. The FillerTraits source used `Events.OnPlayerUpdate` (per-tick) and `stats:setPain(40)` — a hard pain-floor override. The UT implementation uses `Events.EveryTenMinutes` and raises stress (+0.07) and fatigue (+0.05) instead of pain. This is a complete stat substitution and cadence change; the UT version shares only the trait name and the general concept of a chronic pain debuff.
- Description: flavourful but mechanically opaque and partially misleading. No stats or values are named. "Chronic pain" implies pain moodle involvement (none). "Bad days can be genuinely debilitating" implies random flare events (none — the handler is fully deterministic). The actual effects (stress and fatigue accumulation) are invisible to a player reading the UI description. This is the most significant quality gap in the trait.
- Balance: -8 cost is defensible for dual-stat unconditional drain and is directionally correct relative to the single-stat -4 peers. The missing `UT_analgesia` mutual exclusion is a thematic inconsistency (no gameplay breakage since pain is not touched) inherited from not carrying over the source's exclusion.
- Regression proof: partially protected — registration, definition consistency, and presence in the 198-count are proven. All runtime behavior (both increment values, both caps, both guards, event binding) is completely unproven.
- Action needed:
  1. **Description rewrite (high priority)** — the current description discloses nothing about which stats are affected, at what rate, or on what schedule. At minimum, name the stats and cadence (e.g. "Every 10 in-game minutes, stress increases by +0.07 and fatigue by +0.05"). Remove or qualify "bad days can be genuinely debilitating" since there is no flare mechanic.
  2. **Mutual exclusion decision (medium priority)** — confirm whether `UT_fibromyalgia` should exclude `UT_analgesia`. The source did; current UT does not. If the thematic contradiction is intentional (since pain is not the affected stat in UT), document the decision. If it is an oversight, add `MutuallyExclusiveTraits = UniversalTraits:UT_analgesia` to the fibromyalgia script definition and the reciprocal to analgesia.
  3. **Cost spot-check in tests (low priority)** — add `UT_fibromyalgia` to the script-cost verification test to protect the -8 value from accidental drift.
  4. **Behavioral unit tests (low priority)** — add handler tests covering stress increment, fatigue increment, both caps, nil-guard, and trait-guard.
- Open gaps:
  - The pain stat is never touched despite the trait name and description implying pain involvement — confirm this is an intentional design choice and consider whether the name/description should be adjusted to remove pain language, or whether a `stats:setPain` (or equivalent) effect should be added
  - `DisabledInMultiplayer = true` — the FillerTraits source used `TraitFactory.addTrait(..., false, false)` where the second `false` typically means `notRequireProfession`, not a multiplayer restriction; confirm that the UT `DisabledInMultiplayer = true` is the correct policy for this trait
  - No sleep exemption in the UT handler — confirm this is intentional; a player asleep accumulates stress and fatigue from fibromyalgia, which is a plausible design choice (chronic pain does not stop during sleep) but should be a deliberate decision
  - No mutual exclusion with `UT_analgesia` — see action item 2 above
