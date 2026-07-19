# UTMods Whole-Product Audit — Master Coverage Ledger

## Authority and scope

This is the coordinator-owned ledger for the first comprehensive UTMods audit. It covers
`UT_CORE`, `UniversalTraits`, their integration, translations, tests, mocks, tools,
documentation, packaging, generated artifacts, audit records, and relevant reusable skills.

Current source and machine evidence outrank this ledger. Trait, translation, and UT_CORE source
membership is in [`source_inventory.json`](source_inventory.json); the exact documentation and
campaign-artifact inventories are in the independent documentation review and final campaign
manifest. Worker reports and batch artifacts are evidence inputs; they do not become accepted
findings until reconciled here.

Product behavior, balance, translations, source/release/live copies, the PZCodebase baseline,
and deployment state are outside the authorized write boundary. Audit artifacts, QA tests and
fixtures, deterministic analysis helpers, and relevant durable skills are the only authorized
writes.

## Classification vocabulary

Every required inventory item must end in exactly one state:

- `proven-correct`: current evidence proves the stated contract within an explicit boundary.
- `confirmed-defect`: current evidence reproduces a failure or contract violation.
- `coverage-gap`: required proof, assertion, mapping, or negative case is absent or unreliable.
- `runtime-unproven`: static/mock evidence exists, but exact in-game validation is still required.
- `user-approved-non-goal`: excluded only by an explicit user decision recorded with evidence.
- `pending`: not yet audited; never a terminal campaign state.

Every finding must record path and symbol/section anchors, severity, confidence, affected
traits/tools, reproduction evidence, missing proof, recommended correction, and the smallest
test that would prevent recurrence.

## Machine identity

| Surface | Current evidence | State |
| --- | --- | --- |
| PZCodebase snapshot | `PZCodebase/VERSION.json` proves SVN revision `964` and layer hashes; Steam appmanifest independently proves BuildID `23504596` | `proven-correct` |
| Operator label | `42.19` is not encoded as a machine-verified version in `VERSION.json` | `runtime-unproven` |
| Compatibility layout | Current project policy targets only `42.0` | `proven-correct` |

## Source-derived inventory

| Inventory | Count | Evidence | State |
| --- | ---: | --- | --- |
| Registered `UniversalTraits:UT_*` traits | 198 | `source_inventory.json` complete-file parse | `proven-correct` |
| Script definitions | 198 | complete `UT_character_traits.txt`; SHA-256 and parser provenance in inventory | `proven-correct` |
| Per-trait runtime Lua files | 148 | exact runtime tree inventory | `proven-correct` |
| Traits without per-trait runtime files | 50 | canonical registration/runtime set difference; every item classified through script-only or shared runtime paths in the 198-row ledger | `proven-correct` |
| English display/description pairs | 198 | parsed `Translate/EN/UI.json` | `proven-correct` |
| Locale directories | 1 (`EN`) | exact translation-tree inventory | `coverage-gap` |
| `UT_MET` referenced trait IDs | 40 | normalized source parse and per-trait/shared-path reconciliation | `proven-correct` |
| `UT_CORE` Lua files | 24 | exact source-tree inventory | `proven-correct` |
| UTMods Markdown documents | 166 | filesystem/manifest/index three-way reconciliation | `proven-correct` |
| Canonical PZMods documentation corpus | 201 docs / 2,526 sections | `local/PZMods`, embeddings disabled | `proven-correct` |

The inventory invariants currently pass for registrations, definitions, UI names,
descriptions, and English translation pairs. The 50 traits without per-trait Lua are not defects
by count alone; each must be classified as script-only, shared-path, missing behavior, or another
evidence-backed state during the trait batches.

## Campaign task registry

| Task ID | Scope | Model / effort | Writes | Outcome |
| --- | --- | --- | --- | --- |
| `019f789c-c5d8-76e1-a1df-4d2b28a6a0bb` | Canonical UTMods documentation-index repair | Luna / high | JDoc manifest + canonical index only | Completed and archived; remount child also archived |
| `019f789c-cbb0-72e1-b437-935c69303537` | Independent source inventory | Luna / medium | `source_inventory.json` only | Completed after coordinator-caught parser correction; archived |
| `019f789c-d4a3-7461-8323-787751607db1` | Version identity and packaging | Luna / medium | None | Completed and archived |
| `019f789c-dd98-70b3-8d5e-8d98d196596c` | Every UT_CORE Lua surface and caller family | Sol / low | None | Completed and archived |
| `019f789c-e5a8-7cf2-8656-a1fce9437e9f` | QA/test/toolchain trust audit | Sol / low | Temp files only | Completed and archived |
| `019f78a7-fbec-7782-9d1a-5ecad9ed2846` | All UTMods documentation and audit artifacts | Sol / low | None | Completed; all 166 docs accounted; archived |
| `019f78aa-8b34-7262-bd95-db3675239464` | Trait batch 01 (`UT_accmetabolism`–`UT_antivaxxer`) | Sol / low | `trait_batches/batch_01.jsonl` | 17/17 schema-validated; archived |
| `019f78aa-9273-7b50-b911-855ad21a2706` | Trait batch 02 (`UT_ascetic`–`UT_butterfingers`) | Sol / low | `trait_batches/batch_02.jsonl` | 17/17 schema-validated after `UT_brittle` correction; archived |
| `019f78aa-9b97-70d1-83de-33b193d202c8` | Trait batch 03 (`UT_cangrabless`–`UT_fearful`) | Sol / low | `trait_batches/batch_03.jsonl` | 17/17 schema-validated; archived |
| `019f78aa-a5a2-77d3-bd89-ccacf33ec9c9` | Trait batch 04 (`UT_fearofthedark`–`UT_gunspecialist_III`) | Sol / low | `trait_batches/batch_04.jsonl` | 17/17 schema-validated after `UT_glassbody` correction; archived |
| `019f78af-c0d1-7283-b3cc-ba1b039777fc` | Trait batch 05 (`UT_gymgoer`–`UT_ironliver`) | Sol / low | `trait_batches/batch_05.jsonl` | 17/17 schema-validated; archived |
| `019f78b0-ddfe-7500-9e13-56c645c148f7` | Trait batch 06 (`UT_larkperson`–`UT_nervouswreck`) | Sol / low | `trait_batches/batch_06.jsonl` | 17/17 schema-validated after severity normalization; archived |
| `019f78b1-bbbf-70e0-8ec0-e00df1dd17d0` | Trait batch 07 (`UT_ninjaway`–`UT_owlperson`) | Sol / low | `trait_batches/batch_07.jsonl` | 16/16 schema-validated after severity normalization; archived |
| `019f78b7-098b-7310-adc6-d3ffb8fecd57` | Trait batch 08 (`UT_pacer`–`UT_preparedcars`) | Configured default | `trait_batches/batch_08.jsonl` | 16/16 schema-validated; archived |
| `019f78b8-bc0c-7461-9af9-97d31c3ef34f` | Trait batch 09 (`UT_preparedfood`–`UT_scrapper`) | Configured default | `trait_batches/batch_09.jsonl` | 16/16 schema-validated after dimension normalization; archived |
| `019f78bb-e9d4-7220-8ef2-54fcf3ef1e99` | Trait batch 10 (`UT_scrounger`–`UT_specaid`) | Configured default | `trait_batches/batch_10.jsonl` | 16/16 schema-validated after dimension normalization; archived |
| `019f78c8-0c65-7882-a132-72e9e1e23994` | Trait batch 11 (`UT_speccrafting`–`UT_thickblood`) | Configured default | `trait_batches/batch_11.jsonl` | 16/16 schema-validated after dimension/finding-ID normalization; archived |
| `019f78d1-3b35-7980-82d0-63a6c05dd377` | Trait batch 12 (`UT_tinkerer`–`UT_woodsplitter`) | Configured default | `trait_batches/batch_12.jsonl` | 16/16 schema-validated; archived |
| `019f78bc-5fee-7991-a971-c6440b5ab9fa` | Global localization/display/description reconciliation | Configured default | `translation_audit.json` | Completed; 198/198 traits and 396/396 canonical EN keys reconciled; archived |
| `019f78d6-053d-70c3-8c20-7e152e524c52` | Independent trait review, batches 01–04 (68 traits) | Configured default | `independent_reviews/traits_01_04.json` | Completed; 38 accepted, 30 need correction, 48 new/cross-trait findings; archived |
| `019f78dd-e2fc-75c2-bf58-59f3d4eb86d5` | Independent trait review, batches 05–08 (66 traits) | Configured default | `independent_reviews/traits_05_08.json` | Completed; 33 accepted, 33 need correction, 43 new/cross-trait findings; archived |
| `019f78ea-6c1a-78b0-9e62-77bfda38777f` | Independent trait review, batches 09–12 (64 traits) | Configured default | `independent_reviews/traits_09_12.json` | Completed; 41 defect, 19 gap, 4 runtime-unproven; 27 new/cross-trait findings; archived |
| `019f78f9-9d20-7f03-8a5f-2c048e152c7f` | Independent UT_CORE and UniversalTraits integration review (24 source files) | Configured default | `independent_reviews/ut_core_integration.json` | Completed; 24/24 exact files, 27 unique findings/proofs, no unexamined static surface, 5 explicit runtime proofs; archived |
| `019f78fe-8420-7971-b1ca-e5a486db50e3` | Independent toolchain, package-verification, version-identity, and semantic-impact review | Configured default | `independent_reviews/toolchain_semantic_impact.json` | Completed; 158/158 inventory/review rows, 26 unique findings, no unexamined required surface; archived |
| `019f7904-f88c-78c3-8173-24eedc9d44f5` | Independent documentation, localization, campaign-artifact, and skill no-gap review | Configured default | `independent_reviews/documentation_localization_skills.json` | Completed; 166 exact documents, 29 pre-manifest artifacts, 7 corrected skills, and 28 findings/blockers; archived |
| `019f78ab-30a3-74d1-8296-a7ab79e1bfb2` | Relevant reusable-skill audit | Luna / medium | None | Completed read-only; archived |

## Accepted initial findings

### F-CORE-001 — Weapon-hit callback argument order disables two traits

- State: `confirmed-defect`
- Severity / confidence: High / high
- Anchors: `UTCore_DamageMultHook.lua:29`, `UTCore_FractureHook.lua:32`,
  `PZCodebase/Java/source/zombie/characters/IsoGameCharacter.java:6768`
- Affected traits: `UniversalTraits:UT_glassbody`, `UniversalTraits:UT_brittle`
- Evidence: UTCore declares `(attacker, weapon, target)`; current PZ fires
  `(wielder, target, weapon, damageSplit)`. The real target is therefore misbound and both hooks
  return early. Mocks reproduce the incorrect order, explaining the passing suites.
- Missing proof: corrected real-order regression plus in-game event confirmation.
- Recommended correction: align both callbacks and mocks with the current engine signature.
- Smallest regression: fire `OnWeaponHitCharacter(attacker, player, weapon, damage)` and assert
  both hooks affect the player.

### F-CORE-002 — Fracture cooldown is hit-count based, not elapsed-time based

- State: `confirmed-defect`
- Severity / confidence: Medium / high
- Anchor: `UTCore_FractureHook.lua:41`
- Affected trait: `UniversalTraits:UT_brittle`
- Evidence: `UT_fractureCooldown` decrements only inside the weapon-hit callback, so `300` means
  300 later hits rather than ticks or seconds.
- Missing proof: intended duration must be reconciled with trait copy and source-mod intent.
- Recommended correction: use a persistent world-age timestamp if elapsed time is intended.
- Smallest regression: advance mock game time beyond the intended cooldown without hits, then
  verify the next eligible hit can roll.

### F-CORE-003 — Heavy-handler staggering guarantee is not enforced

- State: `confirmed-defect`
- Severity / confidence: Medium / high
- Anchor: `UTCore_TickDispatch.lua:130`
- Affected surface: every heavy tick handler
- Evidence: offsets derive from the smallest throttle while each handler evaluates its own
  throttle; mixed throttles can coincide and throttle `0` runs every tick.
- Missing proof: exhaustive mixed-throttle schedule test.
- Recommended correction: define and enforce an actual collision-free schedule or weaken the
  documented guarantee.
- Smallest regression: simulate the least-common-multiple window for heavy handlers at 30 and
  60 ticks and assert no coincident execution.

### F-TOOL-001 — API baseline shape changes do not fail the gate

- State: `confirmed-defect`
- Severity / confidence: High / high
- Anchors: `tools/verify_pz_api.py:1173`, `tools/run_update_safe_gate.py:184`
- Evidence: verifier exited `0` with `shape_change_with_mod_surface_change`.
- Current result: 912 calls, 296 unique APIs, 240 OK, 0 WARN, 0 FAIL, 56 SKIP.
- Recommended correction: require explicit acceptance for every changed baseline status.
- Smallest regression: one new mod surface must fail until explicitly accepted.

### F-TOOL-002 — Unknown receivers and skips become success

- State: `confirmed-defect`
- Severity / confidence: High / high
- Anchors: `tools/verify_pz_api.py:497`, `tools/verify_pz_api.py:1173`
- Evidence: 56 unresolved/skipped calls do not affect exit status; historical evidence reported 52.
- Recommended correction: distinguish intentional exclusions from unresolved receivers and fail
  unresolved items unless allowlisted with rationale.
- Smallest regression: `mysteryReceiver:removedMethod()` must produce a precise nonzero result.

### F-TOOL-003 — Smoke generation and log scan are not runtime gates

- State: `coverage-gap`
- Severity / confidence: High / high
- Anchors: `tools/generate_smoke_pings.py:212`, `tools/run_update_safe_gate.py:145`,
  `tools/check_smoke_log.py:137`
- Evidence: generation covers only safe zero-argument known receivers, generated pings are not
  executed, generation failure is non-blocking, and every log outcome exits `0`.
- Exact runtime validation: full game start after desktop exit, executed-ping attestation, and a
  strict log mode with stale-log detection.

### F-PKG-001 — UniversalTraits release differs from source

- State: `confirmed-defect`
- Severity / confidence: High / high
- Evidence: 294 source and 294 release paths with no missing/extra files, but content differs for
  `UT_antique.lua`, `UT_scrounger.lua`, `UT_SmokePings.lua`, and
  `media/scripts/UT_character_traits.txt`.
- Recommended correction: source/release reconciliation requires separate authorization.
- Smallest regression: read-only byte-parity check over all expected package mappings.

### F-PKG-002 — Deployment verification can falsely pass

- State: `confirmed-defect`
- Severity / confidence: High / high
- Anchors: `deploy.py`, `deploy.sh:14`
- Evidence: a temporary fixture with matching media but missing `mod.info` returned success;
  `deploy.sh` targets `42` rather than `42.0` and does not remove stale release files.
- Recommended correction: add non-mutating full-package verification and retire or repair the
  stale shell helper.
- Smallest regression: missing metadata, stale files, or wrong version directory must fail.

### F-DOC-001 — Project runtime documentation is stale

- State: `confirmed-defect`
- Severity / confidence: Medium / high
- Anchor: `UTMods/AGENTS.md` UTCore API/event sections
- Evidence: documented BleedDecay cadence, MeleeDelay reset, and ZombieCollision algorithm do not
  match current code. Documentation cannot serve as acceptance evidence until reconciled.
- Smallest recurrence check: compare documented UTCore file/event/cadence claims against the
  source-derived surface manifest.

### F-DOC-002 — Active audit silently excludes 77 registered traits

- State: `confirmed-defect`
- Severity / confidence: Critical / certain
- Anchors: `trait-deep-audit/active/batch/00_batch_checklist.md` “Trait Queue” and
  “Session Run Log”; 121 files under `active/batch/traits/`
- Evidence: the checklist self-certifies `121/121 current Lua traits`, while the corrected
  inventory proves 198 registered/defined/localized traits. Exactly 121 per-trait records exist.
- Affected traits: 77 registered traits, including script-only and shared-path traits that still
  require cost, XP/grant/exclusion, description, origin, and character-creation validation.
- Missing proof: no reviewed classification or explicit non-goal exists for the 77 omitted IDs.
- Recommended correction: bind the backlog to the canonical 198-registration set and classify
  every trait as runtime-file, shared-hook, script-only, or explicit user-approved non-goal.
- Smallest recurrence check: sorted registration IDs must equal sorted record IDs plus a reviewed
  explicit-non-goal list.

### F-DOC-003 — “Complete” is not coupled to regression proof

- State: `confirmed-defect`
- Severity / confidence: Critical / high
- Anchors: `trait-deep-audit/README.md` “Step 7” and “Review Failure Conditions”; all 121
  active trait records; checklist P4
- Evidence: among 118 normal-form records, 112 are marked complete while 111 contain
  missing-test or missing-proof language.
- Missing proof: a suite name or file reference does not show that a test exercises the real
  shared-hook/event path or fails under a representative break.
- Recommended correction: separate documentation, static-trace, automated-regression, and
  runtime-proof states. Completion requires an executable test ID, event path, assertion, and
  negative control, or remains explicitly unproven.
- Smallest recurrence check: reject complete status when missing-proof is non-empty or no
  executable test/asserted behavior is present.

### F-DOC-004 — Campaign completion condition is circular

- State: `confirmed-defect`
- Severity / confidence: High / certain
- Anchor: `trait-deep-audit/plan-parallel-trait-audit.prompt.md` “Work Unit Definition” and
  “Completion Condition”
- Evidence: completion applies only to traits “intended for the active batch” without binding
  intended membership to registrations, allowing a selected subset to self-certify.
- Recommended correction: derive every campaign batch from `source_inventory.json` and require
  an empty unexplained registration/record difference.
- Smallest recurrence check: startup emits registered, records, explicit non-goals, and unexplained
  difference counts; the last must be zero.

### F-DOC-005 — Operational documents mix stale and current contracts

- State: `confirmed-defect`
- Severity / confidence: High / high
- Affected surfaces: `PRD.md`, the 2026-03-27 implementation plan,
  `TRAIT_CHANGE_CHECKLIST.md`, description-sync plan, historical QA checklist, and many
  per-trait records
- Evidence: current-looking instructions still reference `42/`, `UI_EN.txt`, obsolete counts
  and test totals, or direct media-to-live deployment, conflicting with current `42.0`,
  `UI.json`, and source→release→live policy.
- Recommended correction: add lifecycle metadata (`current`, `historical`, `superseded`,
  `proposal`) and lint only current operational documents against canonical contracts.
- Smallest recurrence check: reject current operational references to `/42/`, `UI_EN.txt`, or
  non-canonical inventory totals.

## Localization and display reconciliation

`translation_audit.json` independently reconciles all 198 registered traits, 198 script
definitions, and 396 canonical English display/description keys. Its 198 sorted per-trait rows
classify 65 as `confirmed-defect` and 133 as `coverage-gap`; no row is treated as an approved
non-goal. The artifact passed coordinator schema validation with seven complete finding records and
SHA-256 `BC16195EDEA83B435C2A005F01C2940F5EB25C4AF21F7E142AC501AC462DFD8B`.

Accepted localization/package findings include:

- `F-UT-TR-001` (`high`): Translator processing doubles literal percent signs in 56 no-argument
  descriptions.
- `F-UT-TR-002` (`high`): 14 English descriptions contain lookalike Unicode rejected by the
  development Translator guard.
- `F-UT-PKG-001` (`high`): release Bouncer I/II definitions drift from source and reference the
  nonexistent `FirstAid` perk instead of `Doctor`.
- `F-UT-DOC-001` (`medium`): the original translation artifact's 186-section/114-document count is
  superseded by the independent canonical-document pass: 256 sections across 121 documents and
  282 literal `UI_EN.txt` occurrences.
- `F-UT-LOC-001` (`medium`): absence of all 26 non-English locale directories is confirmed; the
  supported-locale policy remains a `coverage-gap` and actual fallback remains `runtime-unproven`.

Registry and canonical English key membership are proven structurally correct; semantic truth of
all descriptions and non-English runtime fallback remain separately classified rather than inferred
from key parity.

## UT_CORE surface coverage

All 24 current files received both initial and independent review. The accepted integration
artifact reconciles the exact source inventory, 24/24 release counterparts, all 151 UniversalTraits
Lua callers, and 30 caller families without an unexamined static surface. Its 27 unique
findings/proofs include five explicit in-game runtime proofs that remain `runtime-unproven` rather
than being inferred from the 218/218 UT_CORE and 374/374 UniversalTraits off-game test results.

## Reusable-skill coverage

The read-only skill review accounted for all directly relevant durable guidance. Narrow revisions
are justified for `pz-workspace-orientation`, `pz-trait-mods`, `pz-lua-runtime`,
`pz-static-mod-analysis`, `pz-mod-structure`, `qa-deep-review`, and
`documentation-standards`. The required additions are closed-world inventory reconciliation,
real-engine signature versus mock checks, elapsed-time versus hit-count fixtures, strict
unknown/skip and negative-gate semantics, read-only full-package parity, and source-derived
documentation drift checks. No UTMods monolithic skill or split is justified.

`top-level-thread-orchestration`, `safe-headroom-compression`, `skill-review`,
`skill-improvement`, and `engineering-standards` are adequate as written. Conditional PZ skills
for vanilla change impact, crashes, profiling, inventory UI, and baseline refresh remain outside
the present evidence unless their specific triggers arise. The seven justified skills were revised
with closed-world reconciliation, producer-versus-mock event contracts, negative-gate semantics,
complete read-only package parity, and source-derived documentation completion rules.
`skill_contract_check.py` reports zero errors and zero warnings for all seven, and the durable lesson
was captured in Open Brain with retrieval metadata. The final independent pass also corrected the
`pz-trait-mods` reference from the obsolete `UI_EN = { ... }` Lua table to current Build 42
`Translate/<locale>/UI.json` guidance with processed percent/Unicode validation.

## Deterministic normalization and recurring-pattern checks

The twelve source batch artifacts retain their original evidence vocabulary. The coordinator-owned
`tools/build_final_trait_ledger.py` maps their combined/split labels into one canonical 24-dimension
schema and conservatively normalizes legacy states without changing source records. The generated
`final_trait_ledger.json` reconciles 198 unique traits, 163 unique first-pass finding IDs, and all
198 independent review rows with 118 unique omission/cross-trait finding records; its current
SHA-256 is `CF9E7883195407ABA182C958361AC6AA1CF60DB0027AFAB0AB5ADA88B92999C6`.
The equivalent 198-row JData-ready `final_trait_ledger_rows.jsonl` has SHA-256
`829A08A7DD22AC22A59E93E41C99574D739ABE91CB79980F91BF3087FBDD0973`.
The normalizer now preserves all three observed missing-proof field spellings; a coordinator
regression verified all 211 non-empty Batch 01 proof strings survive in both normalized outputs.

`tools/check_recurring_patterns.py` adds five deterministic source-level checks: engine-event
membership, `OnWeaponHitCharacter` argument order, `getTimeOfDay` scale, Translator percent
preprocessing, and complete source/release media parity. Its current report contains 15 unique,
schema-complete high-severity findings and SHA-256
`D187FBCF3136C24119AF1CB6B73AFCD16E48C5B7622A6C0027F687AD48AB8619`.
Representative detections include all three inverted weapon-hit handlers, the three 0..1 clock
comparisons, seven unavailable event names (including `OnVehicleEnter`/`OnVehicleExit` instead of
the current engine names), 56 deterministically mutated description keys, and four
UniversalTraits source/release drift files. Fifteen regression tests prove deterministic output and
negative behavior for missing/duplicate membership, unknown states/dimensions, event argument
inversion, clock scale, legacy proof-field preservation, stale/missing generated artifacts,
closed-world manifest membership, and non-mutating help/invalid-argument behavior. All four
single-purpose commands now fail closed on unsupported arguments.

`tools/build_campaign_manifest.py` adds a closed-world content manifest for every stable campaign
file, excluding only its self-referential output and Python bytecode caches. Required artifacts are
explicit, missing inputs fail closed, and the validator rejects a missing or stale manifest. The
198-row sidecar is indexed as JDataMunch dataset `utmods-final-trait-ledger`; index validation is
clean, `count(*) = count_distinct(trait_id) = 198`, and state aggregation is 81 defect, 11 gap, 25
proven-correct, and 81 runtime-unproven.

## Trait coverage

Exact membership comes from `source_inventory.json`. Twelve exact, disjoint batches cover all 198
registration IDs. Accepted batch artifacts are JSONL, must match their assigned sorted ID set, and
must satisfy the full per-dimension/finding schema before contributing to the counts below. Each
of the 198
traits must record registration, script/parser, namespace, exclusions/grants, source-mod intent,
UT_CORE/runtime path, numerical behavior, cadence/cooldown/reset/save-load, Java–Lua/Kahlua,
event lifecycle, stacking/interactions, multiplayer restriction, display/description/localization,
balance/performance, tests/mocks, release parity, packaging, terminal classification, and findings.

| Required traits | Audited | Independently reviewed | Terminally classified |
| ---: | ---: | ---: | ---: |
| 198 | 198 | 198 | 198 |

| Accepted batch | Traits | Proven-correct | Confirmed defect | Coverage gap | Runtime-unproven | Artifact SHA-256 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 01 | 17 | 1 | 7 | 0 | 9 | `4FA9A60E8D86362B22C33D2BD2DC334565EB564071514576AAD0E90F7FF4BB81` |
| 02 | 17 | 0 | 4 | 3 | 10 | `8B1EAD1B3C9B6C33F0A40B0A78455432E3604F5C5023ECF1585CCE5CC18AAE4D` |
| 03 | 17 | 0 | 9 | 2 | 6 | `33481D2A1F6227C331C16BA8B5CCB006099D07A15649099B8EC0627887679337` |
| 04 | 17 | 0 | 2 | 6 | 9 | `2A7857094C09D1CAD329C8DC2BDA2B96DE56FD6A6AF0866F323D7D6B3C377217` |
| 05 | 17 | 3 | 7 | 0 | 7 | `2146BF05002A28EC9D01FD93F1DE4E0532F4769896EF382652E6A02167F3CF6A` |
| 06 | 17 | 1 | 9 | 0 | 7 | `5B8992F62051687AEB85158F9D498E7AAF130443609881BC1DFE1C77C25BB3D3` |
| 07 | 16 | 0 | 5 | 0 | 11 | `6BFC2D4966C29749BFF856067ABD0EB3B3F3E6E53E37E72A4A4FE271BE9E892C` |
| 08 | 16 | 0 | 4 | 0 | 12 | `58722C1E8C681AAB2E4631E00092436A62058F339414859A66B2AFE10B8A326A` |
| 09 | 16 | 8 | 4 | 0 | 4 | `FFB64ADB79BEDD95F4F340F169A2BEB7A1158BF4C1E1602538AC75BA65F7D759` |
| 10 | 16 | 1 | 12 | 0 | 3 | `2FFE37D42F2DC928789EAE78A16880F4A283BAFB1D735113BB8D25ADE3A90F10` |
| 11 | 16 | 9 | 7 | 0 | 0 | `46B75AB40DF0F1939D1B381E7AC16710C8F3C3A793A26B2F9249799150A43362` |
| 12 | 16 | 2 | 11 | 0 | 3 | `807C099B09F2B4E23BBF3EEB6BF40C05F7AD0C81EA5A438CD7903AD463FEEC12` |

## Independent trait review reconciliation

Three disjoint independent-review artifacts cover all 198 traits exactly. They add 118 unique
schema-complete omission/cross-trait findings: 109 `confirmed-defect`, seven `coverage-gap`, and two
`runtime-unproven`; severities are one critical, 61 high, 55 medium, and one low. Reviewers verified
161 first-pass finding links and explicitly rejected two unsupported prior findings. The normalized
ledger preserves raw review dispositions (`accepted`, `needs-correction`, or the four-state
classification) rather than converting green suites into semantic acceptance.

## Remaining supporting surfaces

| Category | Required inventory | Current status |
| --- | ---: | --- |
| UT_CORE Lua files | 24 | Initial and independent review complete; 24/24 exact source/release parity and no unexamined static surface |
| Traits | 198 | 198 accepted in 12 exact batches and 198 independently reviewed; normalized reconciliation passes |
| Locale directories | 1 present plus 26 absent locales | Initial and independent reconciliation complete; absence confirmed, policy gap and runtime fallback separately classified |
| Markdown documents | 166 | Exact filesystem/manifest/JDoc inventory and independent lifecycle review complete: 5 current, 34 historical, 1 proposal, 126 superseded |
| QA/test/tool helpers | 158 independent-review inventory rows | Independent exact inventory/review complete; deterministic normalizer, pattern checker, manifest, and 15 regression tests added |
| Package trees | 2 mods | Independent review complete; destructive `deploy.sh` layout defect and incomplete verification paths classified |
| Relevant durable skills | 12 core review surfaces plus 5 conditional PZ workflows | Read-only review and 7 narrow revisions complete; 7/7 contract checks clean; representative campaign fixtures pass |

## Completion gate

The final coordinator pass satisfies the campaign gate as follows:

1. Exact source inventories reconcile bidirectionally with all batch and final ledger entries.
2. Every trait and UT_CORE path is terminally classified with evidence.
3. Every translation, tool, test, document, package surface, audit artifact, and relevant skill is
   reviewed.
4. All executable checks are run and their failure/negative/determinism behavior is validated.
5. Every finding and unknown is classified; runtime-only unknowns name an exact validation.
6. Independent reviewers find no required unexamined surface.
7. Recurring-pattern detection is implemented and proven against representative real defects.
8. All managed tasks are terminal, unpinned, and archived, with no unauthorized project or
   deployment mutation.

Evidence: the campaign suite passes 15/15 and the fail-closed validator reports 198 traits, 296
globally unique trait/independent/pattern IDs, and no errors; UT_CORE passes 218/218; UniversalTraits
passes 374/374; all seven skill contracts report zero errors and warnings. JCodeMunch was refreshed
to 406 files/1,981 symbols and JDataMunch validates 198 exact ledger rows. Every independent review
reports no unexamined required static surface; remaining in-game, multiplayer, save/load, render,
locale-fallback, and profiler proofs retain exact `runtime-unproven` validation instructions.

No product source, balance, translation, release, live mod, PZCodebase baseline, deployment, game
runtime, commit, push, or publication was changed by this campaign.
