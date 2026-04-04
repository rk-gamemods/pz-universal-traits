# UT_slack

## Trait Summary

- UT trait id: UT_slack
- Source mod: MoreSimpleTraits
- Source trait id: Slack
- Current cost: -6
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua`
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt`
- Source trigger path: `TraitFactory.addTrait("Slack", ...)` registers the trait at game startup; no event-driven runtime hook; effects are applied statically via XPBoost at character creation
- Source behavior: cost -6; `addXPBoost(Perks.Fitness, -1)` and `addXPBoost(Perks.Strength, -1)` (i.e. -1 to Fitness and -1 to Strength); no work-speed penalty in source; description string is empty (`""`)

## Current UT Evidence

### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: yes — mutually exclusive with UT_quickworker and UT_slowworker; UT_quickworker and UT_slowworker also exclude UT_slack
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_slack.lua`
  - `test/UTTestMocks.lua` (for applyWorkSpeed semantics)
  - `test/run_tests.lua` (registration list)
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait`, `UTCore.applyWorkSpeed`
- Runtime chain (plain language): When a new game starts, `onNewGame` fires; if the player has `UniversalTraits:UT_slack`, `UTCore.applyWorkSpeed(player, 0.4)` is called, writing `0.4` into `player:getModData()["UT_workSpeedMod"]`, which the UT engine reads to slow crafting and building actions.
- Actual behavior (exact values): +0.4 added to the work-speed modifier (positive value = slower; peer UT_slowworker uses +0.5, UT_quickworker uses -0.3); net effect is a -20% work-speed penalty on all crafting and building, applied once at new-game start and persistent.

## Description Integrity

- Display name check: "Slack" — matches intent; no issue.
- Description check: `UI_UT_slackDesc = "Effort was never really your thing. -20% work speed on all crafting and building actions."` — accurately describes the UT runtime behavior (applyWorkSpeed 0.4 = -20% speed).
- Missing or misleading details: The UT implementation replaced the source XPBoost penalties (−1 Fitness, −1 Strength) with a flat work-speed penalty. The description correctly reflects the UT behavior and does not falsely claim the source XPBoosts. No misleading content; the divergence from source is intentional and documented by behavior. The trait is disabled in multiplayer (`DisabledInMultiplayer = true`); the description does not call this out, but that is a structural concern rather than a description error.

## Balance Review

- Upside: −6 points returned at character creation (significant point refund).
- Downside: −20% work speed on all crafting and building, permanent from new-game start.
- Uptime: 100% — the penalty is always active; no conditional or timed element.
- Peer comparison: UT_slowworker costs −4 for −33% work speed (harsher penalty, smaller refund); UT_quickworker costs +6 for +30% speed. UT_slack at −6 for only −20% speed is a softer work-speed nerf than UT_slowworker at −4, while offering a larger point refund — this reads as more favorable than UT_slowworker on a per-point basis.
- Stack or exclusion notes: Mutually exclusive with UT_quickworker and UT_slowworker; no stacking of work-speed modifiers within this group. Can potentially stack with other unrelated modifiers that affect crafting time.
- Cost verdict: questionable — −6 points for a permanent −20% work-speed penalty is arguably too generous when UT_slowworker gives −4 for −33%. The point-per-penalty ratio favors UT_slack, making it a relatively easy point-grab.

## Regression Proof

- Existing test: UT_slack appears in the registration list in `run_tests.lua` (line 247) under "Phase 2 — Work Speed"; this confirms the trait id is registered and does not crash the loader.
- What it proves: The trait id resolves without error in the test harness; no behavioral assertion is made.
- Missing proof: No test asserts that `applyWorkSpeed` is called with `0.4` when the player has the trait; no test covers the `OnNewGame` handler behavior.
- Minimum next test if needed: Add a test that creates a mock player with `UniversalTraits:UT_slack`, fires `onNewGame`, and asserts `player:getModData()["UT_workSpeedMod"] == 0.4`.

## Final Verdict

- Source origin: partially proven — source trait "Slack" from MoreSimpleTraits confirmed; source behavior (XPBoosts) differs from UT implementation (work-speed); the rename from XPBoosts to work-speed is a deliberate UT redesign, not a bug, but the link is by name/cost match rather than by a documented migration record.
- UT implementation: drifted — UT replaced source XPBoost penalties with a work-speed modifier; the behavior is internally consistent but does not faithfully replicate the source.
- Description: accurate — the UI description correctly describes the UT runtime behavior.
- Balance: questionable — −6 points for −20% work speed is a softer penalty than peer UT_slowworker (−4 for −33%), making it potentially too cheap.
- Regression proof: partially protected — registration smoke-test exists; no behavioral assertion for the work-speed application.
- Action needed: test fix, doc fix (consider noting the multiplayer restriction in the description or release notes), balance review
- Open gaps:
  - No behavioral unit test for the `OnNewGame` handler applying `0.4` to work speed.
  - Cost relative to UT_slowworker should be reviewed; UT_slack may warrant a cost adjustment to −4 or −5, or UT_slowworker's cost should be re-examined for consistency.
  - Multiplayer flag (`DisabledInMultiplayer = true`) is set but not surfaced in the description; players in MP servers get no trait-selection feedback about unavailability.
  - No documented rationale for replacing source XPBoost penalties with a work-speed modifier.
