# Plan-Specific Loop Override

Loop Execution Profile: parallel-independent-checklist

Loop override: mandatory parallel trait-audit fan-out.

Use this file as the active execution contract for `/loop-run` in `trait-deep-audit`.

## Intent

Do not audit one trait and stop.
This work is a large independent research queue and should run in parallel.

## Active Backlog Source

- `trait-deep-audit/active/batch/00_batch_checklist.md`
- `trait-deep-audit/active/batch/traits/*.md`
- `trait-deep-audit/README.md`

## Work Unit Definition

One work unit is one trait audit file completed or materially advanced.

A trait is eligible for dispatch when it is not yet fully audited in the active batch.
Treat these as parallel-safe research tasks unless the checklist marks a shared blocker.

Eligible means any of the following:

- the trait is missing a file under `active/batch/traits/`
- the trait file exists but is incomplete or stale versus checklist findings
- the checklist status is not `done`
- the checklist references a correction gap not yet documented in the trait file

## Orchestration Rules

1. Fan out multiple trait audits in parallel immediately.
2. Treat every remaining eligible trait as an independent checklist item.
3. When one worker finishes, dispatch the next unaudited trait without waiting for the whole wave to finish.
4. Keep the worker pool busy until the active queue is exhausted, tool/model budget is hit, or a true blocker stops further dispatch.
5. Do not stop after a single trait unless only one trait remains executable.
6. Prefer broad queue depletion over deep work on one trait.
7. Use the checklist as the source of truth for what remains.
8. Default assumption: this is research/documentation work, so maximum safe parallelism is preferred.

## Worker Contract

Each worker should:

1. Claim exactly one trait.
2. Verify source intent.
3. Verify current UT structure and runtime behavior.
4. Compare description, balance, exclusions, and regression proof.
5. Write or update the corresponding file in `trait-deep-audit/active/batch/traits/`.
6. Return concise correction gaps and blocker notes.

Workers are doing research/documentation unless the checklist explicitly requests a fix pass.
Do not turn audit work into code changes by default.

## Coordinator Contract

After each completed wave:

1. Merge worker outputs into the active trait files.
2. Update `trait-deep-audit/active/batch/00_batch_checklist.md`.
3. Record newly discovered shared blockers or automation candidates.
4. Launch the next wave immediately if executable traits remain.
5. Do not wait for manual re-entry while executable traits remain.

## Completion Condition

The loop is complete only when one of these is true:

1. All traits intended for the active batch have audit files and checklist status is updated.
2. A true blocker prevents further trait dispatch and the blocker is documented in the checklist.
3. Tool/model budget is exhausted after maximal safe parallel progress; in that case return with the exact remaining queue.

## Preferred Dispatch Order

1. Traits missing an audit file entirely
2. Traits with partial or stale audit files
3. Traits whose checklist status is ambiguous versus file state

## Run Log Rule

Keep run-log updates brief.
Log completed waves and remaining queue count, not verbose per-file narration.
