# UT_flatearther

## Trait Summary

- UT trait id: UT_flatearther
- Source mod: SomewhatTraits (SomewhatTraitsCore)
- Source trait id: SWTraits:SWFlatEarther
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/scripts/SWTraits_character_traits.txt_` (trait definition)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.12/media/lua/shared/Translate/EN/UI_EN.txt` (translation strings)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (runtime implementation — minimap suppression)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCoreOverrides.lua` (runtime implementation — map/minimap access overrides)
- Source trigger path (SomewhatTraits):
  - `Events.OnTick.Add(SWFlatEarther)` — fires every tick; removes the minimap widget from the UI manager if it is present.
  - `SWSomewhatTraitsCoreOverrides.lua` overrides `ISMiniMap.IsAllowed()`, `ISMiniMap.ToggleMiniMap()`, and `ISDPadWheels.onDisplayRight()` to return early or return `false` when the `flatEarther` flag is set.
  - The `flatEarther` flag is set at character load by checking `character:HasTrait("SWFlatEarther")`.
- Source behavior: The source trait blocks access to both the in-game minimap and world map UI elements through client-side override hooks. It does not impose any XP penalty or reading speed change. The effect is entirely navigational — the character cannot use map or minimap. Map items (physical in-world maps) can still be read. Cost in source: −4 points. No XP boosts defined. No mutually exclusive traits.
- Source EN description: "Can't use map and minimap. Can read map items."

## Current UT Evidence

### Structure

- Registered in registries.lua: unknown — not verified; only the trait definition file and runtime Lua were confirmed present
- Defined in UT_character_traits.txt: yes (lines 1409–1417)
- Translation strings present: yes
- Exclusions/grants correct: no exclusions defined in UT_character_traits.txt — consistent with source (source also had none)
- Runtime Lua file exists: yes

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_flatearther.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1409–1417)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 431–432)
  - `test/run_tests.lua` (lines 264, 446, 480–485)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)` — fires once at new game start
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — presence check in the handler
  - `UTCore.applyXPMultiplier(player, "MetaGame", 0.7)` — applies a 0.7 multiplier to the MetaGame XP category
  - `player:getModData()["UT_readSpeedMod"] = 0.3` — writes a positive read-speed penalty value directly into mod data
- Runtime chain (plain language):
  1. On new game, if the player has `UniversalTraits:UT_flatearther`, `UTCore.applyXPMultiplier` is called with skill `"MetaGame"` and multiplier `0.7`, applying a persistent −30% penalty to MetaGame XP gain.
  2. Immediately after, `UT_readSpeedMod = 0.3` is written to the player's mod data, signalling to downstream systems that reading speed is slowed by 30%.
- Actual behavior (exact values):
  - MetaGame XP: ×0.7 (−30%) applied once at new game start.
  - Reading speed: +0.3 read-speed penalty written to mod data (positive value = slower; convention confirmed by test comment on line 480 and contrast with `UT_photographicmemory` which writes −0.6666667 for a speed bonus).

## Description Integrity

- Display name check: "Flat Earther" — matches intent; accurate.
- Description check: `UI_UT_flateartherDesc` = "You distrust books, science, and anything written down. Reading speed is reduced by 30% and MetaGame XP is reduced to ×0.7 (−30%)." — this correctly describes both runtime effects with exact values and correct framing.
- Source description for comparison: "Can't use map and minimap. Can read map items." — the UT description covers entirely different effects; the UT trait does not replicate the map/minimap block at all.
- Missing or misleading details: The description is internally accurate for the UT implementation. However, it is worth noting that the "Flat Earther" theme was adapted: the source blocked map/minimap access (geographic denial), while UT re-interprets the concept as anti-intellectualism (reading and knowledge penalties). The description reflects the UT design choice and does not misrepresent it. No accuracy issues.

## Balance Review

- Upside: none — pure negative trait.
- Downside: −30% reading speed (written to `UT_readSpeedMod = 0.3`); −30% MetaGame XP (XP multiplier ×0.7).
- Uptime: Both penalties are permanent, applied once at new game start.
- Peer comparison:
  - `UT_antigun` (−6 cost): −50% Aiming and Reloading XP. Affects two combat skills with a steeper multiplier (×0.5).
  - `UT_luddite` (−4 cost): −40% Electrical XP. Single skill, −40% vs. flatearther's −30%.
  - `UT_flatearther` (−4 cost): −30% MetaGame XP and −30% reading speed. Two simultaneous penalties — one to a broad XP category, one to a gameplay activity.
  - `UT_onetrickpony` (−4 cost): sets `UT_multiSkillPenalty = true`, which presumably imposes broader skill XP restrictions.
- The MetaGame XP category is understood to cover meta-progression skills (e.g., skills learned from books and similar sources). Combined with the reading speed penalty, the two effects are thematically coherent and compounding: the character reads slower AND gains less XP from what they do read. This compounding interaction makes the trait stronger than the individual values suggest. At −4 points, this is potentially more punishing than `UT_luddite` (single skill, −40%) because it hits a broad XP category plus an activity rate, not just one skill.
- Cost verdict: plausible but worth flagging — −4 points may be slightly underpriced given the compounding nature of the two penalties. Reasonable at −4 but defensible at −5. No urgent change required; document the compounding interaction.

## Regression Proof

- Existing test (lines 480–485):
  - `"UT_flatearther sets UT_readSpeedMod > 0"` — fires `OnNewGame` with the trait active, reads `modData["UT_readSpeedMod"]`, and asserts it is a number greater than zero.
- What it proves: The `onNewGame` handler executes, the mod data key is written, and the value is correctly positive (i.e., a penalty, not a bonus).
- Missing proof:
  1. No test verifies the MetaGame XP multiplier. The call to `UTCore.applyXPMultiplier(player, "MetaGame", 0.7)` is not independently asserted. If the XP multiplier call were removed or the skill name changed, the test would still pass.
  2. No test verifies the exact value of `UT_readSpeedMod`. The assertion is only `v > 0`, not `v == 0.3`. A regression that changed `0.3` to any positive value would pass silently.
- Minimum next tests if needed:
  1. Assert `modData["UT_readSpeedMod"] == 0.3` (exact value check, not just sign).
  2. Assert that the MetaGame XP multiplier is applied — either by inspecting mod data for the XP multiplier key that `UTCore.applyXPMultiplier` writes, or by testing the UTCore function's output directly.

## Final Verdict

- Source origin: proven — `SWTraits:SWFlatEarther` from SomewhatTraits confirmed; definition (Cost = −4, no exclusions), translation, and runtime implementation all traced across 42.12 and 42.13 source versions.
- UT implementation: redesigned — the source blocked map and minimap access through client-side UI overrides with no XP effect. UT replaces this entirely with a −30% MetaGame XP multiplier and a −30% reading speed penalty. The "Flat Earther" theme is preserved but the mechanical interpretation is different. The redesign is coherent and intentional.
- Description: accurate — both UT effects are correctly documented with exact values and correct sign language (×0.7, −30%). The description does not misrepresent the source; it describes what UT actually does.
- Balance: plausible — −4 points for two compounding penalties (reading rate and reading XP) is reasonable but should be noted as potentially underpriced relative to single-penalty peers at the same cost.
- Regression proof: partially protected — `UT_readSpeedMod` presence and sign are tested; exact value and MetaGame XP multiplier application are not.
- Action needed: test fix — add exact-value assertion for `UT_readSpeedMod == 0.3`; add a test that verifies the MetaGame XP multiplier is applied.
- Open gaps:
  - No test asserts the exact value of `UT_readSpeedMod` (only that it is `> 0`).
  - No test verifies `UTCore.applyXPMultiplier(player, "MetaGame", 0.7)` was applied.
  - The compounding interaction between reading speed and MetaGame XP is not documented in the description — consider adding a sentence noting that the two effects stack (slower reading + less XP per read session).
  - The trait diverges mechanically from its source (map/minimap block vs. knowledge penalties); this design decision is undocumented in the trait files themselves.
