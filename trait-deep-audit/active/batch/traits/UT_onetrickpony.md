# UT_onetrickpony

## Trait Summary

- UT trait id: UT_onetrickpony
- Source mod: SomewhatTraits (SomewhatTraitsCore)
- Source trait id: SWTraits:SWOneTrickPony (trait key: "SWOneTrickPony")
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/scripts/SWTraits_character_traits.txt`
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/Translate/EN/UI_EN.txt`
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua`
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/client/SWTraitsCore_client.lua`
- Source cost: -4 (both legacy and 42.15 definition).
- Source multiplayer: `DisabledInMultiplayer = false` in source; UT sets `DisabledInMultiplayer = true`.
- Source trigger path: `Events.OnEquipPrimary.Add(SWOneTrickPony)` — fires whenever the player equips a weapon in the primary hand slot.
- Source behavior (legacy `SWSomewhatTraitsCore.lua`): On equip, if the equipped item is a melee weapon (not ranged), the function reads XP across six weapon skills (Axe, Blunt, SmallBlunt, LongBlade, SmallBlade, Spear) and identifies the highest-XP skill. If the equipped weapon's category string (with "Improvised, " stripped) does not contain `"[SkillName]"`, the item is immediately force-unequipped via `ISUnequipAction`. If all six weapon XP values are zero, `allowedCategory` remains nil and the check is skipped (no constraint enforced).
- Source behavior (42.15 `SWTraitsCore_client.lua`): Functionally identical mechanic but with a cleaner implementation — compares `primaryHandItem:getPerk()` as a string directly against `allowedCategory` (no bracket wrapping, no category-string manipulation). The nil-XP early exit is preserved.
- Source description: "The highest weapon skill is the only weapon type the player can equip. Doesn't affect ranged weapons."
- Source display name: "One Trick Pony"

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — listed in the Phase 2 XP Penalties block at line 265 of `run_tests.lua` (which also serves as the registries dofile list).
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_onetrickpony` at line 1429, cost -4, `DisabledInMultiplayer = true`.
- Translation strings present: yes — `UI_UT_onetrickpony = "One Trick Pony"` and `UI_UT_onetrickponyDesc` at lines 437–438 of `media/lua/shared/Translate/EN/UI_EN.txt`.
- Exclusions/grants: none declared in the script definition. No `MutuallyExclusiveTraits` field. No `XPBoost` entries.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_onetrickpony.lua`, dofile'd at line 445 of `run_tests.lua`.

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_onetrickpony.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1429–1437)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 437–438)
  - `test/run_tests.lua` (lines 265, 445, 475–478)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — trait check
- Runtime chain (plain language):
  1. On new game: if the player has the trait, writes `player:getModData()["UT_multiSkillPenalty"] = true`. That is the entire runtime action.
  2. No `OnEquipPrimary` event is registered. No weapon-enforcement logic exists in the UT Lua file.
- Actual behavior (exact values):
  - The UT implementation sets a single modData flag `UT_multiSkillPenalty = true` at game start and does nothing else. No weapon equip constraint is applied. No XP multiplier is applied. The flag is not consumed by any observable UT code in the reviewed files.
  - The source's core mechanic — forcing unequip of any melee weapon outside the player's highest-skill category — is entirely absent.

## Description Integrity

- Display name check: "One Trick Pony" — matches source name exactly.
- Description check: `UI_UT_onetrickponyDesc` reads: "You excel only in what you know best. Training multiple skills simultaneously applies an XP penalty across all skills being trained."
- Missing or misleading details:
  1. **Description does not match source behavior at all.** The source mechanic restricts weapon equipping based on highest melee skill. The UT description describes a multi-skill XP penalty, which is a completely different design with no implementation behind it in the Lua file.
  2. **Description does not match the UT implementation either.** The Lua file sets `UT_multiSkillPenalty = true` in modData, but no code in the reviewed files reads that flag or applies any XP penalty. The described XP penalty mechanic is not implemented.
  3. "Training multiple skills simultaneously applies an XP penalty" — this implies a dynamic per-skill XP reduction hook. No such hook is registered anywhere in `UT_onetrickpony.lua`.
  4. The source's ranged weapons exemption ("Doesn't affect ranged weapons") is not reflected anywhere, because the UT description describes a different mechanic entirely.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside (claimed in description): XP penalty when training multiple skills simultaneously.
- Downside (actually implemented): none. The modData flag is set but not consumed. No restriction, no penalty, no behavioral change occurs at runtime beyond writing a boolean to modData.
- Cost: -4 points. At this cost the player receives a meaningful character-creation refund for a trait that currently does nothing in-game.
- Peer comparison: `UT_flatearther` and `UT_luddite` both cost -4 and apply genuine runtime XP modifiers (read speed penalty and Electrical XP reduction respectively). `UT_onetrickpony` at -4 with no active effect is strictly better than both — it is a free 4-point refund.
- Stack or exclusion notes: no mutual exclusions declared. Could theoretically coexist with any other trait.
- Cost verdict: broken — the cost is unearned because no downside is delivered. This is the most severe balance failure possible for a negative trait.

## Regression Proof

- Existing test: "UT_onetrickpony sets UT_multiSkillPenalty=true" (`run_tests.lua` lines 475–478).
- What it proves: With the trait present, `Events.OnNewGame` fires, `UTCore.hasTrait` returns true, and `modData["UT_multiSkillPenalty"]` is set to `true`. The flag write path is confirmed end-to-end.
- Missing proof:
  1. No test confirms any effect of `UT_multiSkillPenalty = true` — no downstream consumer of the flag is exercised.
  2. No test for the scenario where the player does NOT have the trait (guard clause early return).
  3. No test for the source mechanic (weapon equip restriction) because the mechanic is not implemented.
  4. No test covering the described XP penalty behavior, because the behavior is not implemented.
- Assessment: the single existing test is passing but only validates a flag write that has no known effect. It is not evidence that the trait works as described or as sourced.

## Final Verdict

- Source origin: proven — SomewhatTraits `SWOneTrickPony` is the confirmed source. Source files (legacy and 42.15) located and read. Source mechanic is melee weapon equip restriction based on highest-XP weapon skill.
- UT implementation: critically incomplete — the UT Lua file does not port the source mechanic at all. It only sets a modData flag (`UT_multiSkillPenalty`) that is not consumed by any visible code. The `OnEquipPrimary` event hook present in both source versions is absent in UT. The trait is effectively inert at runtime.
- Description: doubly wrong — (1) it does not describe the source mechanic (weapon equip restriction), instead describing a different XP penalty concept; (2) the XP penalty concept it does describe is also not implemented. The description has no correspondence to either the source or the actual code.
- Balance: broken — negative trait with cost -4 delivers no in-game penalty. Players receive 4 free character-creation points.
- Regression proof: superficially present but proves only a dead flag write. Does not protect against the missing mechanic being absent.
- Action needed:
  1. Decide which design to implement: (a) port the source weapon-equip restriction via `Events.OnEquipPrimary`, or (b) implement the described multi-skill XP penalty via an XP hook. These are different features and the current state satisfies neither.
  2. If (a): add `Events.OnEquipPrimary` handler that reads highest melee skill XP and force-unequips mismatched weapons; update description to match; use the 42.15 source's cleaner `getPerk()` comparison rather than the legacy category-string approach.
  3. If (b): implement an XP event hook that applies a penalty when more than one skill gains XP within a window; this is a novel mechanic with no source reference; update cost based on measured impact.
  4. Remove or rename the modData flag `UT_multiSkillPenalty` once the actual mechanic is implemented, or document what is expected to consume it.
  5. Rewrite the description to match whichever mechanic is chosen.
  6. Add tests that exercise the active mechanic, not just the flag write.
- Open gaps:
  - No code found anywhere in the UT codebase that reads `modData["UT_multiSkillPenalty"]`. Confirm whether a consumer exists outside the reviewed files or whether the flag is dead data from an abandoned design sketch.
  - Source sets `DisabledInMultiplayer = false`; UT sets `DisabledInMultiplayer = true`. If the weapon-equip restriction is implemented, revisit multiplayer eligibility — the source considered it safe for multiplayer.
  - At zero XP in all six weapon skills, the source skips enforcement entirely (nil allowedCategory early return). If the UT port goes with option (a), this edge case must be explicitly handled and tested.
