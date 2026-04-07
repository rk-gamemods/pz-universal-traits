# Universal Traits Movement Bug Handoff

Date: 2026-04-06
Project: UniversalTraits / UT_CORE
Scope: Project Zomboid Build 42.16.x single-player movement bug investigation
Status: Open, sharply narrowed

## Executive Summary

The current movement bug is now narrowed to the Universal Traits stack.

Latest user-validated finding:

- With `UniversalTraits` and `UT_CORE` both disabled, and all other mods left enabled, the bug disappears.
- Therefore the root cause is now constrained to one of two possibilities:
  1. a bug inside `UniversalTraits` or `UT_CORE` itself
  2. a conflict between `UniversalTraits` / `UT_CORE` and at least one other still-enabled mod

This is the strongest narrowing result obtained so far. It supersedes the earlier broad suspicion that the primary cause might be a third-party mod alone.

## Problem Statement

Observed symptom during recent live testing:

- Manual movement via keyboard directional arrows is broken.
- Right-click `Walk To` still works normally.
- This means the character can still pathfind and move through the world, but the direct input path is impaired.

That symptom pattern strongly suggests a problem in one of these areas:

- input handling
- manual movement translation / player position rewriting
- animation or player variable side effects that affect direct movement but not pathfinding
- a runtime conflict that only occurs when Universal Traits code is loaded

## Hard Evidence

### 1. Current active mod source of truth

- Project Zomboid uses `C:\Users\Admin\Zomboid\mods\default.txt` as the authoritative active mod list.
- The in-game preset file `pz_modlist_settings.cfg` is not the source of live mod activation.

Source:

- repo memory: `pz_mod_loading_source_code_analysis_20260404.md`

### 2. Full restart requirement for valid mod-toggle testing

- In this setup, `reload lua` is not enough to clear stale Kahlua module state.
- A full **Exit to Desktop** is required after changing active mods.

Implication:

- Any mod-enable / mod-disable test is only valid if the game was fully exited and relaunched afterward.

Source:

- repo memory: `pz_mod_loading_source_code_analysis_20260404.md`

### 3. Manual input is the broken path, not pathfinding

User-validated symptom split:

- directional arrow movement broken
- right-click `Walk To` works normally

Implication:

- generic world movement is not globally dead
- the problem is not well-described as “the player cannot move at all”
- this is narrower than a total locomotion failure

### 4. Latest decisive narrowing result

User-validated on 2026-04-06:

- `UniversalTraits` OFF
- `UT_CORE` OFF
- all other mods still ON
- bug goes away

Implication:

- the issue is now inside our stack or only appears when our stack is loaded
- third-party mods by themselves are no longer sufficient to explain the bug

## Investigation Timeline and Findings

### Phase A: Universal Traits bug fixing and deployment work

Before the movement issue was narrowed, the project already completed several Universal Traits fixes unrelated to movement.

Validated outcomes from that work:

- `UT_CORE` tests passed: `157 passed, 0 failed`
- `UniversalTraits` tests had already passed earlier in the session
- both mods were synced source -> release -> live

Relevant lesson from that earlier phase:

- “passing test suite” did not imply the movement issue was solved

### Phase B: Movement problem reframed from generic failure to input-path failure

The investigation changed direction when the symptom was clarified as:

- manual directional movement bad
- right-click `Walk To` normal

This was the key moment that eliminated many vague theories and shifted the search toward:

- manual input interception
- movement rewrite logic
- animation state or player-variable side effects

### Phase C: TchernoLib movement-library review

Earlier investigation found that the active run loaded `TchernoLib` movement overrides, including shared movement-related files.

Important findings from static review:

- `TchernoLib` contains movement-control and movement-speed logic
- its `SpeedFramework` path distinguishes pathfinding movement from manual movement
- it rewrites player position through `player:setX()`, `player:setY()`, and related state

Important Workshop-side finding:

- the active Workshop page in the loadout is `TchernoLib B41`
- the author explicitly says B42 users should use a different linked mod

Why this mattered then:

- it was a plausible third-party root cause or conflict source

Why it matters less now:

- with `UniversalTraits` and `UT_CORE` disabled, the bug goes away
- therefore `TchernoLib` alone is not sufficient
- it may still matter as a conflict partner, but not as the primary standalone explanation

### Phase D: Authentic Z animation-override hypothesis

Earlier investigation found:

- `Authentic Z - Current` overrides `media/AnimSets/player/movement/defaultwalk.xml`
- that made it a plausible suspect for “feet animate strangely / manual motion wrong” type failures

Direct retest result:

- user disabled `Authentic Z - Current`
- bug still reproduced

Conclusion:

- `Authentic Z` is not sufficient to explain the bug

### Phase E: Inventory/container/UI mod triage

This branch focused on mods such as:

- `TheShortcut`
- `Equipment UI`
- `Reorder Containers`
- `Reorder The Hotbar`
- `SwapHands42`
- `SwapIt`
- `TakeAnyAmount`
- `ProximityInventoryLocal`
- `WatchYourTrunk`
- `WatchYourStep`

Key results from code inspection and Workshop review:

- `ProximityInventoryLocal` does not touch directional keys and mostly handles inventory/container refresh plus internal debug/profiler hotkeys
- `WatchYourTrunk` is vehicle-only
- `Reorder Containers` is inventory/controller-oriented rather than keyboard walking oriented
- `SwapHands42` binds a specific swap key, not directional movement
- `TheShortcut` has a global keyboard hook, but Workshop comments were mostly healthy on latest unstable
- `Reorder The Hotbar` had fresher B42.16 complaints than `TheShortcut`
- `TakeAnyAmount` active Workshop page also points B42 users to a different item

Why this branch is now deprioritized:

- disabling only our mods removed the bug while the rest of this mod stack remained active
- that means this class of mods is not sufficient without our code loaded

## What Has Been Effectively Ruled Out

These are not absolute impossibilities, but they are no longer good primary explanations:

### 1. “Some unrelated third-party mod is solely responsible”

This is contradicted by the latest retest.

If all other mods stay on and the bug disappears only when `UniversalTraits` and `UT_CORE` are removed, then an unrelated third-party-only root cause is no longer consistent with the evidence.

### 2. “Authentic Z alone caused the bug”

The user disabled it and still reproduced the problem earlier.

### 3. “TheShortcut is the obvious next culprit by itself”

Earlier Workshop and code evidence already weakened that theory, and the latest Universal Traits isolation weakens it further.

## What Remains Plausible

### 1. Shared UT_CORE runtime logic

This is now a top-tier suspect category.

Reason:

- `UT_CORE` contains shared helpers and hooks used across the whole trait system
- shared code can affect all runs without depending on one specific trait implementation
- earlier inspection already confirmed a movement-adjacent file: `UTCore_SpeedHook.lua`

This is a particularly important lead if the bug can reproduce even with a character that has few or no movement-related traits selected.

### 2. One or more specific Universal Traits

Also highly plausible.

Reason:

- a trait could be indirectly modifying player state, stats, or variables in a way that impairs direct movement
- the effect may not look like “speed code” at all from the trait’s theme
- the user’s current interpretation is reasonable: a single broken trait or small trait subset could create the symptom

### 3. Conflict between our code and another still-enabled mod

Still plausible, but now constrained.

The correct form of this hypothesis is no longer:

- “some other mod is broken”

It is now:

- “our code becomes broken only when loaded alongside another mod”

Likely conflict partners, if conflict is involved at all, are still the mods closest to:

- movement control
- hotbar/equip state
- player variables / animation state
- movement library behavior

Examples already examined earlier:

- `TchernoLib`
- `CleanHotBar`
- `Reorder The Hotbar`
- `Equipment UI`
- `SwapIt`

## Most Relevant Files and Artifacts for the Next Agent Pass

### In our codebase

- `UT_CORE/media/lua/shared/UTCore/UTCore_SpeedHook.lua`
  - previously confirmed to rewrite player position during movement
- `UniversalTraits/media/lua/shared/UniversalTraits/UT_MET.lua`
  - shared runtime mutual-exclusivity and trait grouping table
- `UniversalTraits/media/lua/shared/UniversalTraits/traits/`
  - per-trait runtime effects
- `UniversalTraits/media/scripts/UT_character_traits.txt`
  - script definitions
- `UniversalTraits/media/registries.lua`
  - all registered trait ids

### Investigation artifacts already produced

- `C:\Users\Admin\Documents\GIT\GameMods\PZMods\WORKSHOP_TRIAGE_2026-04-06.md`
  - third-party workshop/comment triage
- repo memory: `pz_workshop_branch_mismatch_20260406.md`
- repo memory: `pz_mod_loading_source_code_analysis_20260404.md`

### Known recent run artifacts from prior investigation

- bad run log: `C:\Users\Admin\Zomboid\Logs\2026-04-05_23-36_DebugLog.txt`
- matching recent save: `C:\Users\Admin\Zomboid\Saves\Sandbox\2026-04-05_23-38-44`

These were the freshest known failing artifacts during the third-party branch of the investigation. They remain useful if the next agent wants to correlate UT hooks against a known bad run.

## Handoff Constraints and Testing Rules

1. Use `default.txt` as the source of truth for active mods.
2. After changing enabled mods for a retest, always do a full **Exit to Desktop** before relaunching.
3. Do not trust `reload lua` as a clean isolation step for this investigation.
4. Do not edit third-party Workshop mods in place unless explicitly approved.
5. Treat the latest “UT off = bug gone” finding as the current top-level truth unless a future retest disproves it.

## Recommended Next Debugging Lanes

This section is designed so multiple agents can work in parallel without duplicating effort.

### Lane 1: Shared-hook audit

Goal:

- enumerate every `UT_CORE` and `UniversalTraits` event handler that can affect movement, player variables, timed actions, or hand/equip state

Priority targets:

- `UTCore_SpeedHook.lua`
- any `OnPlayerMove`, `OnPlayerUpdate`, `OnTick`, `EveryOneMinute`, equip-action, or animation-adjacent hooks

Expected output:

- a ranked list of shared handlers by risk to manual movement

### Lane 2: Trait bisection strategy

Goal:

- determine whether the bug requires a specific selected trait or whether merely loading the mod stack is enough

Key question:

- does the bug reproduce with `UniversalTraits` and `UT_CORE` enabled but with a character built to avoid suspected movement-affecting traits?

Expected output:

- narrowed suspect trait subset or proof that the bug is shared-hook level rather than trait-specific

### Lane 3: Conflict intersection audit

Goal:

- identify which still-enabled mod(s), if any, meaningfully overlap with our remaining high-risk hooks

Priority conflict partners:

- `TchernoLib`
- `CleanHotBar`
- `Reorder The Hotbar`
- `Equipment UI`
- `SwapIt`

Expected output:

- ranked list of probable conflict partners with exact overlapping hook surfaces

### Lane 4: Live instrumentation plan

Goal:

- add temporary, high-signal debug logging to confirm whether our code is changing movement-related player state during a failing run

Examples of useful temporary probes:

- log when movement-related shared hooks fire
- log trait-gated code paths that adjust player position or variables
- log deltas written to player coordinates or movement multipliers

Expected output:

- one failing run with enough instrumentation to prove which code path is active when arrow-key movement breaks

## Current Best Working Theory

The most defensible working theory right now is:

- the bug is caused by either a `UT_CORE` shared movement/runtime hook or a selected Universal Trait runtime effect
- a third-party conflict may still exist, but our code is a required ingredient

That theory fits all current evidence better than any pure third-party explanation.

## Bottom Line

The investigation is no longer in broad mod-pack speculation mode.

It is now a focused Universal Traits debugging problem.

The next efficient step is not more Workshop searching. The next efficient step is systematic auditing and isolation inside `UT_CORE` and `UniversalTraits`, with conflict analysis treated as a secondary branch only where it overlaps our active hooks.
