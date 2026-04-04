# UT_photographicmemory

## Trait Summary

- UT trait id: `UniversalTraits:UT_photographicmemory`
- Source mod: FillerTraits
- Source trait id: `PhotographicMemory`
- Current cost: 16
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/shared/NPCs/UpgradeMainCreationMethods.lua` line 15 - `TraitFactory.addTrait("PhotographicMemory", ..., 20, ..., false, false)` - source cost is **20** and the trait is a normal selectable trait.
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/shared/NPCs/UpgradeMainCreationMethods.lua` lines 55-56 - source mutual exclusions are `SlowLearner` and `Illiterate`.
  - `research/installed-mods/FillerTraits/mods/FillerTraits/42/media/lua/shared/ISReadABookFT.lua` lines 33-72 - source runtime implementation inside `ISReadABook:update()`.
- Source trigger path:
  - FillerTraits overrides `ISReadABook:update()` directly. While a player is reading a skill book and `player:HasTrait("PhotographicMemory")` is true, the trait logic runs on every update where `pagesRead` advances beyond `item:getAlreadyReadPages()`.
- Source behavior:
  - The source trait is book-specific. It does not grant a global XP multiplier and does not change read duration.
  - On each page-progress step for a valid skill book, it awards flat XP directly to the trained perk instead of relying on the vanilla book multiplier path.
  - Exact per-page bonus values from `ISReadABookFT.lua` are tied to `item:getMaxLevelTrained()`: level-2 books `2.6 * 1.6 = 4.16`, level-4 books `9 * 1.9 = 17.1`, level-6 books `15 * 4.2 = 63`, level-8 books `25 * 5.1 = 127.5`, level-10 books `45 * 4.5 = 202.5`.
  - If the book is already obsolete for the character (`maxLevelTrained < current perk level + 1`), the source resets read pages to 0 and force-stops reading.
  - Source exclusions are explicit: `PhotographicMemory` cannot be combined with `SlowLearner` or `Illiterate`.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes - `UTTraitsRegistries.UT_photographicmemory = CharacterTrait.register("UniversalTraits:UT_photographicmemory")` in `UniversalTraits/media/registries.lua` line 194.
- Defined in UT_character_traits.txt: yes - `UniversalTraits/media/scripts/UT_character_traits.txt` lines 1392-1400 define a valid block with `Cost = 16`, correct `CharacterTrait`, and no `XPBoosts`, `MutuallyExclusiveTraits`, or `GrantedTraits`.
- Translation strings present: yes - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` lines 422-423 define both `UI_UT_photographicmemory` and `UI_UT_photographicmemoryDesc`; `UI.json` mirrors the same text.
- Exclusions/grants correct: no - the source trait excludes `SlowLearner` and `Illiterate`, but the UT script block has no exclusions at all. `UT_MET.lua` also contains no corresponding runtime grouping for this trait.
- Runtime Lua file exists: yes - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_photographicmemory.lua` exists and is 20 lines long.

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_photographicmemory.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_XPHook.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_WorkSpeedHook.lua`
  - `UT_CORE/media/lua/shared/UTCore/UTCore_ReadingHook.lua`
- Event registrations:
  - `UT_photographicmemory.lua` registers `Events.OnCreatePlayer.Add(onCreatePlayer)`.
  - `UTCore_XPHook.lua` registers `Events.AddXP.Add(onAddXP)` and `Events.EveryOneMinute.Add(resetXPTracking)`.
  - `UTCore_WorkSpeedHook.lua` registers `Events.OnGameBoot.Add(patchTimedActions)`.
  - `UTCore_ReadingHook.lua` registers `Events.OnGameBoot.Add(tryPatchReadAction)`.
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` gates trait setup in `UT_photographicmemory.lua`.
  - `UTCore_XPHook` consumes `UT_xpMult_All` and adds the bonus XP delta on every `Events.AddXP` call.
  - `UTCore.applyWorkDuration()` consumes `UT_readSpeedMod` for `ISReadABook` timed actions only.
  - `UTCore.applyReadingMoodEffects()` consumes `UT_readCalm` and `UT_readMoodBonus` while `ISReadABook:update()` runs.
  - `UTCore.tryAwardSkillBookCompletionXP()` awards the one-time skill-book completion bonus used by this trait.
- Runtime chain (plain language):
  1. On new game and save load, `OnCreatePlayer` fires and `UT_photographicmemory.lua` runs `applyTrait(player)`.
  2. If the player has `UniversalTraits:UT_photographicmemory`, the trait writes four moddata flags: `UT_xpMult_All = 1.5`, `UT_readSpeedMod = -0.6666667`, `UT_readCalm = true`, and `UT_readMoodBonus = 5`.
  3. Whenever any XP is awarded, `UTCore_XPHook` reads `UT_xpMult_All` and adds `floor(amount * 0.5)` bonus XP to the same perk.
  4. On game boot, `UTCore_WorkSpeedHook` patches timed actions. For `ISReadABook`, `UT_readSpeedMod = -0.6666667` turns the duration into `floor(base * 0.3333333)`, with a minimum of 1 tick.
  5. Also on game boot, `UTCore_ReadingHook` patches `ISReadABook.start`, `update`, `stop`, and `perform`.
  6. During each `ISReadABook:update()` call, if the reader has the trait, `UTCore.applyReadingMoodEffects()` forces panic and stress to 0 and reduces boredom/unhappiness by `5 * tickScale`, clamped at 0.
  7. When the book crosses from incomplete to fully read, `UTCore.tryAwardSkillBookCompletionXP()` adds a one-time flat XP bonus on `stop()` or `perform()`.
- Actual behavior (exact values):
  - Global XP: `UT_xpMult_All = 1.5` means the shared XP hook adds `floor(base XP * 0.5)` bonus on each XP event. This applies to all perks, not just book reading.
  - Reading speed: `UT_readSpeedMod = -0.6666667` makes `ISReadABook` take about one third of normal time, i.e. roughly 3x faster reading.
  - Reading calm: while reading, panic is repeatedly set to 0 and stress is repeatedly set to 0.
  - Reading mood: boredom and unhappiness each drop by 5 per patched `ISReadABook:update()` call at `tickScale = 1.0`; the reduction scales with `GameTime:getMultiplier()` and cannot go below 0.
  - Skill-book completion XP: one-time bonus by book tier is exactly `+12 / +30 / +65 / +120 / +200` for max-level `2 / 4 / 6 / 8 / 10` books.
  - Save/load behavior: strong. Because the trait initializes from `OnCreatePlayer`, its moddata is re-applied on both fresh spawn and save load. The shared hook patches initialize once at `OnGameBoot`.
  - Removal behavior: no cleanup path exists if the trait were removed dynamically mid-save; the moddata stays until something else overwrites it. For character-creation traits this is low risk, but it is still worth noting.

## Description Integrity

- Display name check:
  - UT uses `Photographic Memory`, which matches the source name and still fits the current redesign.
- Description check:
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` says: `You learn everything faster. All XP gain is increased to x1.5 (+50%). Reading is 3x faster. While reading, panic and stress are forced to 0 and boredom/unhappiness drop rapidly. Finishing a skill book grants a flat XP bonus by tier: +12 / +30 / +65 / +120 / +200.`
  - That description matches the current UT behavior closely: global XP multiplier, 3x reading speed, reading calm, reading mood gain, and tiered completion XP are all real.
  - The description is intentionally describing the UT redesign, not the FillerTraits source behavior. That is acceptable, but it means this is not a faithful port.
- Missing or misleading details:
  1. It does not mention that the `+50%` XP bonus is implemented as `floor(amount * 0.5)`, so very small XP gains may round down.
  2. It does not mention that the flat skill-book XP bonus is awarded once on full completion, not continuously while reading.
  3. It does not mention the missing source exclusions against `SlowLearner` and `Illiterate`, so the player text does not warn about currently allowed but source-incompatible stacks.

## Balance Review

- Upside:
  - Very large. The trait grants a permanent global XP boost to every perk, roughly 3x faster reading, full panic/stress suppression while reading, rapid boredom/unhappiness recovery while reading, and one-time completion XP bonuses for every skill book tier.
  - These benefits stack across different progression loops: combat XP, crafting XP, book completion, and morale while reading.
- Downside:
  - None in the current UT implementation. This is a pure positive trait.
- Uptime:
  - Global XP bonus uptime is effectively 100% because it applies to every `Events.AddXP` call after `OnCreatePlayer` initialization.
  - Reading speed and mood effects are 100% reliable whenever the player is inside `ISReadABook` and the shared patches are active.
  - Completion XP is one-shot per finished book but reliable because it is checked on both `stop()` and `perform()`.
- Peer comparison:
  - Compared to the source FillerTraits version, UT is broader in scope. The source was a reading-only perk with book-specific XP behavior and cost 20. UT turns it into a general progression powerhouse with extra reading comfort, yet costs 16.
  - Compared to UT negative XP traits such as `UT_mundane` and `UT_incomprehensive`, this is the obvious premium positive counterpart and is much more than a narrow niche buff.
- Stack or exclusion notes:
  - Source exclusions `SlowLearner` and `Illiterate` are missing, so the UT trait can currently stack with those vanilla drawbacks unless another system blocks it elsewhere.
  - Because the XP multiplier is global, it also stacks multiplicatively with any perk-specific UT XP modifiers in `UTCore_XPHook`.
  - No `UT_MET` group membership exists, so there is no runtime reference coverage for intended incompatibilities.
- Cost verdict:
  - `questionable`. Cost 16 is still expensive, but the trait is one of the strongest positive packages in the mod and it lost the source exclusions while gaining a permanent global XP multiplier and reading comfort effects. Relative to the source cost 20 and the broadened UT scope, 16 looks a bit cheap.

## Regression Proof

- Existing test:
  - `UniversalTraits/test/run_tests.lua` lines 91-93 prove registration.
  - `UniversalTraits/test/run_tests.lua` lines 534-542 prove that `OnCreatePlayer` writes `UT_xpMult_All`, `UT_readSpeedMod`, `UT_readCalm`, and `UT_readMoodBonus` for this trait.
  - `UT_CORE/test/run_tests.lua` lines 355-362 prove `UTCore.applyWorkDuration()` respects `UT_readSpeedMod` for `ISReadABook`.
  - `UT_CORE/test/run_tests.lua` lines 388-409 prove `UTCore.applyReadingMoodEffects()` clears panic/stress and improves mood.
  - `UT_CORE/test/run_tests.lua` lines 411-425 prove `UTCore.tryAwardSkillBookCompletionXP()` awards the tiered flat XP bonus.
- What it proves:
  - The trait's moddata initialization is covered.
  - The shared helper functions used by this trait are covered in isolation.
  - Registration and script-definition presence are covered by the existing trait suite.
- Missing proof:
  - There is no integrated test that fires the actual `Events.AddXP` path after `UT_photographicmemory` initializes and proves the trait really grants bonus XP through `UTCore_XPHook`.
  - There is no integrated test that patches a mock `ISReadABook`, applies the trait, and proves the real patched `update()/stop()/perform()` chain triggers calm, mood reduction, and one-time completion XP only for players with the trait.
  - There is no regression proof for the missing exclusions.
- Minimum next test if needed:
  ```lua
  test("UT_photographicmemory boosts XP through Events.AddXP", function()
      local p = fireCreatePlayer("UniversalTraits:UT_photographicmemory")
      Events.AddXP:fire(p, "Mechanics", 10)
      local calls = p:getXpCalls()
      assert_eq(calls[#calls].perk, "Mechanics")
      assert_eq(calls[#calls].amount, 5)
  end)

  test("UT_photographicmemory reading hooks apply calm and completion XP only for the trait", function()
      local p = fireCreatePlayer("UniversalTraits:UT_photographicmemory")
      -- Build a mock ISReadABook action, run patched update/perform, and assert
      -- panic/stress are zeroed and the tier bonus is awarded exactly once.
  end)

  test("UT_photographicmemory defines intended mutual exclusions", function()
      -- Parse UT_character_traits.txt and assert the trait block contains the
      -- verified exclusion ids once the vanilla ids are confirmed.
  end)
  ```

## Final Verdict

- Source origin: proven
- UT implementation: drifted
- Description: accurate
- Balance: questionable
- Regression proof: partially protected
- Action needed: code fix, test fix
- Open gaps:
  1. Missing source-style exclusions for `SlowLearner` and `Illiterate`; the exact vanilla script ids still need verification before fixing.
  2. No end-to-end regression test covers the real shared-hook chain from `UT_photographicmemory` moddata setup into `Events.AddXP` and patched `ISReadABook` behavior.
  3. UT is a deliberate redesign rather than a faithful port: source behavior was reading-only flat XP on page progress, while UT adds permanent global XP gain, 3x reading speed, and reading comfort effects.
