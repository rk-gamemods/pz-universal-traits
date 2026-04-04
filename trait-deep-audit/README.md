# Trait Deep Audit System

This folder is the entire audit system for verifying that **existing UT traits are correctly built**.
It is self-contained.
Do not require any other process document to use it.
Do not generate audit files at the UTMods root.

## What This Is

Every trait in UniversalTraits was ported from a source mod.
The porting is done.
This audit verifies the **current built trait** works correctly:

- Is it registered, defined, and translated properly?
- Does the runtime Lua actually do what the description says?
- Are the numbers, conditions, and interactions accurate?
- Is the description honest about what the trait does?
- Is the point cost reasonable?
- Is there a test that would catch a regression?

The source mod is consulted only to check for drift from original intent.
The unit of work is **one UT trait at a time**.

## Start Here

Follow this section top to bottom before reading anything else.

1. Create the batch folder at `trait-deep-audit/active/batch/` if it does not exist.
2. Create `00_batch_checklist.md` from the template below if it does not exist.
3. Pick one UT trait to audit.
4. Create `traits/<ut-trait-id>.md` from the template below.
5. Run the audit procedure on that one trait.
6. Mark the trait done in the checklist.
7. Pick the next trait. Repeat.

## Batch Folder Layout

```text
trait-deep-audit/
  active/
    batch/
      00_batch_checklist.md
      traits/
        UT_acrophobic.md
        UT_fast.md
        ...
      research/
        <topic>.md              (only when a question spans multiple traits)
      artifacts/
        <name>.<ext>            (raw logs, source excerpts, machine output)
  _archive/
    <yyyy-mm-dd>__<batch-name>/
```

## Division Of Labor

Use these lanes when subagents are available.

### Lane 1: Coordinator

- Owns batch setup and the checklist.
- Assigns traits to research agents.
- Reviews completed trait files for quality.
- Merges findings and updates checklist status.

### Lane 2: Source-Origin Lookup

- Owns Step 2 only.
- Finds the original source trait files and records what it was supposed to do.
- This is a lookup, not a deep investigation. The source research folder already exists at `research/installed-mods/`.

### Lane 3: UT Implementation Trace

- Owns Steps 3 and 4.
- Reads the current UT registration, definition, translation, and Lua runtime.
- Traces shared hooks into UT_CORE until the real behavior is known.
- This is the core of the audit.

### Lane 4: Test Review

- Owns Step 7.
- Checks whether a regression test exists and whether it actually proves the trait works.

### Lane 5: Synthesis And Verdict

- Owns Steps 5, 6, and 8.
- Writes the description check, balance review, and final verdict.
- Starts only after Lane 2 and Lane 3 findings are written.

## Parallel Rules

1. Coordinator work happens first (trait file must exist).
2. Source-Origin Lookup and UT Implementation Trace can run in parallel.
3. Test Review starts after the UT runtime chain is known.
4. Synthesis And Verdict starts only after source and UT findings are both written.
5. Different traits can be assigned to different agents, but each trait gets exactly one trait file.

## Evidence Model

Every trait audit must collect these evidence types:

1. Current UT registration (registries.lua entry).
2. Current UT script definition (UT_character_traits.txt block).
3. Current UT player-facing text (translation strings).
4. Current UT runtime implementation (per-trait Lua file, if scripted).
5. Shared UT_CORE hooks that affect the trait's behavior.
6. Source trait definition and behavior (from `research/installed-mods/`).
7. Regression test coverage.

## Trait Audit Procedure

Run these steps in this exact order for every trait.

### Step 1: Open The Trait File

Create `traits/<ut-trait-id>.md` from the template at the end of this file before doing any analysis.

### Step 2: Look Up The Source Trait

1. Find the original trait in `research/installed-mods/<source-mod>/`.
2. Record the original registration, definition, and runtime behavior.
3. Record the original trigger path and exact behavior (numbers, conditions, cadence, cooldowns, stack rules, hidden penalties, suppression rules).
4. If the source behavior cannot be proven from source files, mark it `partially proven` or `unknown`.

This step is a lookup. The source files are already in the research folder. Do not spend excessive time here.

### Step 3: Verify The Current UT Structure

1. Verify the UT trait id is registered in `registries.lua`.
2. Verify the trait definition exists in `UT_character_traits.txt`.
3. Verify translation strings exist (UIName and UIDescription).
4. Verify exclusion ids and granted ids are real and correctly namespaced.
5. Verify the per-trait runtime file exists when the trait is scripted.

### Step 4: Trace The Current UT Runtime Behavior

1. Read the entire current trait Lua file (if the trait has one).
2. List every event registration used by the trait.
3. Follow every helper call into UT_CORE shared code until the actual effect is known.
4. Record the real runtime chain in plain language.
5. Record the real behavior with exact values, cadence, reset behavior, save/load behavior, and interaction rules.
6. If any runtime hook exists at all, the trait is scripted. Do not classify it as simple from the script block alone.

### Step 5: Verify Description Integrity

1. Compare the current display name to the source intent.
2. Compare the current description to the real current behavior found in Step 4.
3. Flag missing numbers, missing conditions, missing exclusions, or missing suppression rules.
4. If UT intentionally changed the behavior from the source, label it as a design change, not a faithful port.

### Step 6: Review Balance

1. Quantify the real upside.
2. Quantify the real downside.
3. Record uptime and activation reliability.
4. Compare the trait to direct peers (similar cost, similar effect).
5. Compare it to mutually exclusive alternatives.
6. Compare it to obvious stack partners.
7. Decide whether the current point cost is `justified`, `questionable`, `wrong`, or `blocked`.

### Step 7: Verify Regression Proof

1. Find at least one automated test that proves the trait's core intended function.
2. Confirm that the test would fail if that real function broke.
3. Confirm that the test covers the actual event path or shared hook path used by the trait.
4. If no such proof exists, write the exact missing test, mock need, and expected assertion.

### Step 8: Write The Verdict And Action List

Every trait file must end with these fields:

- `Source origin:` proven | partially proven | unknown
- `UT implementation:` faithful | simplified | drifted | unknown
- `Description:` accurate | incomplete | misleading | stale
- `Balance:` justified | questionable | wrong | blocked
- `Regression proof:` protected | partially protected | missing
- `Action needed:` none | doc fix | test fix | code fix | research gap

## Review Failure Conditions

Do not mark a trait complete if any of these are true:

1. The trait file was never created.
2. The current trait Lua file was never read (for scripted traits).
3. Shared hooks were not traced even though the trait uses them.
4. The description verdict was written before the runtime numbers were known.
5. The balance verdict was written before the real upside, downside, and uptime were quantified.
6. A scripted trait has no regression proof and no missing-test entry.

## Useful Skills

If the skill system is available, these are the useful ones for this work:

1. `pz-trait-mods`
   Use for registration, script definitions, translations, mutual exclusivity, and trait parser gotchas.
2. `pz-lua-runtime`
   Use for Kahlua runtime behavior, event semantics, module cache rules, test harness behavior, and mock implications.
3. `pz-mod-structure`
   Use for source, release, and live layout checks when the audit includes post-update integrity or deployment verification.
4. `pz-debug-crash`
   Use when an audit hits parser failures, missing trait definitions, stale-cache behavior, or character-creation crashes.

## Templates

### Template: `00_batch_checklist.md`

```md
# UT Trait Deep Audit — Batch Checklist

- Batch folder: trait-deep-audit/active/batch/
- Coordinator:
- Status: in progress

## Trait Queue

| UT Trait ID | Source Mod | Scripted? | Owner | Status | Blockers |
|-------------|-----------|-----------|-------|--------|----------|

## Shared Blockers

-

## Automation Candidates Found

-
```

### Template: `traits/<ut-trait-id>.md`

```md
# <UT Trait ID>

## Trait Summary

- UT trait id:
- Source mod:
- Source trait id:
- Current cost:
- Scripted: yes | no
- Owner:
- Status:

## Source Evidence

- Source files reviewed:
- Source trigger path:
- Source behavior:

## Current UT Evidence

### Structure
- Registered in registries.lua: yes | no
- Defined in UT_character_traits.txt: yes | no
- Translation strings present: yes | no
- Exclusions/grants correct: yes | no | N/A
- Runtime Lua file exists: yes | no | N/A

### Runtime Trace
- Files reviewed:
- Event registrations:
- UT_CORE hooks used:
- Runtime chain (plain language):
- Actual behavior (exact values):

## Description Integrity

- Display name check:
- Description check:
- Missing or misleading details:

## Balance Review

- Upside:
- Downside:
- Uptime:
- Peer comparison:
- Stack or exclusion notes:
- Cost verdict:

## Regression Proof

- Existing test:
- What it proves:
- Missing proof:
- Minimum next test if needed:

## Final Verdict

- Source origin:
- UT implementation:
- Description:
- Balance:
- Regression proof:
- Action needed:
- Open gaps:
```

## Archive Rule

When a batch is complete, move the entire batch folder from `trait-deep-audit/active/` to `trait-deep-audit/_archive/` with a dated folder name.
Do not leave completed batches in `active/`.
