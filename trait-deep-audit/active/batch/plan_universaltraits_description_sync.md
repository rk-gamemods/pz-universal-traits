# Plan: UniversalTraits Description Sync

Fix player-facing trait text only. Do not change trait functionality. Edit `UniversalTraits/media/lua/shared/Translate/EN/UI.json` directly, then sync release and live copies and verify they match.

## Steps

1. Build a verified mapping table from `UniversalTraits/media/scripts/UT_character_traits.txt` for every trait whose current description still claims `Gain ×2 XP`, `Gain ×3 XP`, or `Gain ×5 XP` when the script effect is actually `XPBoosts`. Include mixed traits that also have other runtime effects.
2. In the same pass, identify player-facing skill-name mismatches between `UI.json` and the script data. Correct wording to match the actual perk names used by the script definitions.
3. Edit `UniversalTraits/media/lua/shared/Translate/EN/UI.json` directly. Replace XP-multiplier wording that is backed only by `XPBoosts` with accurate starting-level wording based on the script values.
4. Preserve real runtime-effect text on traits that actually change behavior in Lua or shared hooks. For mixed traits, change only the incorrect `XPBoosts` clause and keep the verified runtime description intact.
5. Update `UI_UT_terminatorDesc` to describe the verified starting-level effect and remove any exclusivity claim unless that claim is actually present in the script definition.
6. Update `UI_UT_staunchDesc` to reflect both verified effects: `Doctor=1` in `UT_character_traits.txt` and the bandaged-only bleed-decay effect in `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_staunch.lua` and `UT_CORE/media/lua/shared/UTCore/UTCore_BleedDecayHook.lua`. The text must explicitly say it affects only bandaged wounds and does not affect unbandaged wounds.
7. Verify the edited `UI.json` directly for the high-risk keys: `UI_UT_specweaponsDesc`, `UI_UT_specmoveDesc`, `UI_UT_terminatorDesc`, `UI_UT_staunchDesc`, and at least one early movement trait with a known mismatch such as `UI_UT_swiftDesc` or `UI_UT_quietDesc`.
8. Sync `UniversalTraits/media` to `UniversalTraits/release/UniversalTraits/42/media`, copy `UniversalTraits/mod.info` into `UniversalTraits/release/UniversalTraits/`, then deploy `UniversalTraits/release/UniversalTraits` to `C:/Users/Admin/Zomboid/mods/UniversalTraits` so the updated `UI.json` reaches the live game files.
9. Verify source, release, and live copies of `UI.json` match.
10. Do a focused in-game spot check after a full Exit to Desktop relaunch to confirm the updated descriptions appear in character creation.
11. Commit only the description change in `UI.json` plus any intentionally tracked release-sync artifacts. Do not change Lua trait behavior or script trait definitions unless a text fix requires a verified terminology correction.

## Relevant Files

- `UniversalTraits/media/lua/shared/Translate/EN/UI.json` — editable translation source used by the game and by this repo.
- `UniversalTraits/media/scripts/UT_character_traits.txt` — source of truth for `XPBoosts` and script-side mutual exclusivity.
- `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_staunch.lua` — verifies Staunch applies `UTCore.applyBleedDecayMult(player, 3.0, true)`.
- `UT_CORE/media/lua/shared/UTCore/UTCore_BleedDecayHook.lua` — confirms that `bandagedOnly=true` means the faster bleed-decay applies only to bandaged wounds.
- `UTMods/AGENTS.md` — project rule stating `UI.json` is the translation source and should be edited directly.

## Verification

- Diff-check every edited `UI_UT_*Desc` entry in `UI.json` against the corresponding `XPBoosts` value in `UT_character_traits.txt`.
- Inspect `UI.json` directly for corrected Terminator and Staunch strings plus one early movement trait and one Specialist trait.
- Sync source to release, then release to live, and hash-compare the three `UI.json` copies.
- Relaunch PZ with a full Exit to Desktop restart and spot-check the updated text in character creation.

## Decisions

- Included: description wording fixes, direct `UI.json` edits, release sync, live deploy, and verification.
- Excluded: any text-to-JSON regeneration workflow, trait functionality changes, cost changes, runtime exclusivity changes, or Lua/script behavior edits.
- Workflow rule going forward: `UI.json` is the editable runtime/source file here. A translation task is not complete until source, release, and live `UI.json` copies are all updated and verified.
- If any `XPBoosts` perk name is ambiguous from player-facing text alone, verify it before wording the string rather than guessing.
