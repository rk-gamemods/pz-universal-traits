# Wood Splitter → Axeman New-Character Alias Note

Status: current implementation contract; validation pending  
Baseline: PZCodebase SVN 964 / Steam BuildID 23504596  
Trait: `UniversalTraits:UT_woodsplitter`

Wood Splitter no longer uses the nonexistent `OnTreeChopped` event or synthetic tree-HP subtraction. The supported contract is new-character creation only: selected Wood Splitter grants vanilla `base:Axeman` declaratively through `GrantedTraits = Axeman`.

Selection and grant are separate phases. Before grants, Wood Splitter must be mutually exclusive with Axeman, including Axeman supplied by a profession/job. After a valid Wood Splitter selection, the intentional Wood Splitter + granted-Axeman state is not a conflict and does not stack duplicate Axeman membership.

The inherited vanilla effects are inseparable:

- Axe-category tree damage uses `weapon.getTreeDamage() * 1.5`.
- The Axe-category attack-time result is multiplied by `0.95`.
- Chop speed is `1.0` with Axeman instead of `0.8` without it (25% faster).
- New characters are eligible for the rare pine-tree key ring when vanilla special key-ring generation runs.

Wood Splitter also retains `XPBoosts = Axe=1`. Its accepted cost is 4 points, based on the package and sensitivity analysis in `trait-deep-audit/campaign/change-impact/woodsplitter-axeman-balance.json`. `DisabledInMultiplayer = true` remains an exclusion guard only; multiplayer support is outside the product boundary.

## Existing saves — superseded non-goal

Existing saves may be invalidated. Earlier proposals and current artifacts involving `OnCreatePlayer`, migration markers/versioning, idempotence, legacy-state reconciliation, ownership preservation, retroactive key-ring behavior, migration tests, or migration runtime proof are explicitly superseded and must not be counted as coverage gaps, risks, or future requirements.

## Evidence boundary

No suite or in-game run has been executed under this documentation correction. Multiplayer and existing-save migration requirements are rejected by product scope. Do not claim the remaining new-character behavior as proven: pre-grant Wood Splitter/Axeman exclusion (including direct and profession/job Axeman), post-selection `GrantedTraits` application and key-ring eligibility, rendered localization, or key-ring occurrence/frequency. The 4-point balance decision is accepted rather than provisional. Generated audit, translation, API, smoke, package-report, and ledger artifacts remain deferred to their owning workflows after applicable guarded tests.
