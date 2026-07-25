# Trait Change Checklist

Use this checklist for one trait at a time. Shared-mechanism work may cover
multiple traits only when the mechanism itself is the explicit change.

## 1. Establish the Contract

- [ ] Read the trait's row in `trait_catalog.csv` or `trait_catalog.json`.
- [ ] Read existing audit, queue, blocker, and mechanism evidence.
- [ ] Record the pre-change baseline from the state before the current campaign
      touched the trait.
- [ ] State the intended player outcome in one testable sentence.
- [ ] Separate defect correction from any proposed intent or balance change.
- [ ] Obtain explicit user approval before changing intent.
- [ ] Set aside unresolved intent questions. Do not guess.

## 2. Plan the Smallest Closure

Run:

```powershell
py -3 tools\utmods_workflow.py plan `
  --changed-file UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_example.lua
```

- [ ] Identify the exact source, evidence nodes, tests, and package surfaces.
- [ ] Reuse a family proof only when its hash, lifecycle, API, state, and
      parameter contract match exactly.
- [ ] Avoid reopening already proven source paths without a freshness or scope
      reason.

## 3. Update Every Owning Surface

| Change | Owning source | Required dependent review |
| --- | --- | --- |
| Cost, XP, grants, exclusions | `UniversalTraits/media/scripts/UT_character_traits.txt` | Description, registration, catalog, tests |
| English name or description | `UniversalTraits/media/lua/shared/Translate/EN/UI.json` | Definition keys, behavior accuracy, catalog |
| Trait runtime behavior | Matching source Lua under `UniversalTraits/media/lua/` | UT_CORE contract, cadence, cleanup, tests, release |
| Shared hook or service | Source Lua under `UT_CORE/media/lua/` | Every consumer, composition, tests, release |
| Registration | `UniversalTraits/media/registries.lua` | Definition, UI pair, catalog |
| Mutual exclusion | Script-side `MutuallyExclusiveTraits` | Reverse edge, `UT_MET.lua` reference, grants |
| Audit state or proof | Owning batch/review/resolution evidence | Ledger, queue, blocker, catalog, manifest |

- [ ] Do not hand-edit `release/` or the live mod.
- [ ] Do not edit the generated catalog.
- [ ] Update documentation only when public behavior, intent, or an engineering
      contract changed.

## 4. Runtime Safety

- [ ] Use current PZCodebase or runtime evidence for every engine event and
      Java-Lua call.
- [ ] Preserve Kahlua behavior and Java collection indexing in mocks.
- [ ] For frequent events, prove bounded work and the slowest acceptable
      cadence.
- [ ] For wrappers and shared hooks, prove installation, idempotence,
      composition, reload, and teardown.
- [ ] Prove activation, deactivation, player change, and stale-state cleanup
      where applicable.
- [ ] Do not add multiplayer or old-save handling.

## 5. Focused Validation

- [ ] Run the changed trait or mechanism tests first.
- [ ] Run the dependency-selected campaign modules:

  ```powershell
  py -3 -B trait-deep-audit\campaign\tools\run_campaign_tests.py `
    --changed-file <repo-relative-path>
  ```

- [ ] Rebuild and verify the catalog:

  ```powershell
  py -3 tools\utmods_workflow.py catalog --write
  py -3 tools\utmods_workflow.py catalog --check
  ```

- [ ] Run the affected Lua suite.
- [ ] Run the full campaign suite only at an integration milestone, after
      shared compiler/runner changes, or before a release decision.

## 6. Package and Evidence Closure

- [ ] Refresh the owning audit evidence once, after the focused work is stable.
- [ ] Regenerate dependent ledgers, queue views, and the terminal campaign
      manifest in dependency order.
- [ ] Verify source and `42.0` release parity when release-affecting work is
      ready.
- [ ] Keep unresolved runtime proof visible with an exact validation
      requirement.
- [ ] Do not classify an item as proven because it is nonblocking.
- [ ] Deploy only with explicit authorization.

## 7. Milestone Commit

- [ ] Review the exact diff and `git status`.
- [ ] Confirm no unrelated or generated transient files are included.
- [ ] Commit the recoverable milestone on `development`.
- [ ] Record tests run, generated artifacts refreshed, and remaining risks.
