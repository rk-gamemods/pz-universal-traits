# Trait Description Review Handoff

## Purpose

This document is for a low-context agent that needs to review trait description drift across UniversalTraits without getting lost.

The job is **review and document mismatches**, not fix them in this pass.

Primary question for each trait:

1. What does the trait actually do at runtime?
2. What does the player-facing text claim it does?
3. If this trait was ported from another mod, what did the original trait do?
4. Is the problem:
   - description is wrong
   - implementation is wrong
   - both are wrong
   - intended behavior is unknown and needs source recovery first

## Canonical Source Paths

Always start in the source repo, not the live mod copy.

- Repo root:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods`
- Trait change checklist:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\TRAIT_CHANGE_CHECKLIST.md`
- Trait registry:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\registries.lua`
- Trait script definitions:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\scripts\UT_character_traits.txt`
- Player-facing translation text:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\lua\shared\Translate\EN\UI_EN.txt`
- Generated translation JSON:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\lua\shared\Translate\EN\UI.json`
- Trait runtime Lua folder:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\lua\shared\UniversalTraits\traits`
- UniversalTraits tests:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\test\run_tests.lua`
- UT_CORE shared hooks/helpers:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UT_CORE\media\lua\shared\UTCore`

Use the live deployed copies only to verify what is currently installed in-game:

- `C:\Users\Admin\Zomboid\mods\UniversalTraits\42\media\...`
- `C:\Users\Admin\Zomboid\mods\UT_CORE\42\media\...`

## Review Procedure For Each Trait

1. Open `TRAIT_CHANGE_CHECKLIST.md` first.
2. Find the trait in `registries.lua`.
3. Find the script block in `UT_character_traits.txt`.
4. Find the display name and description in `UI_EN.txt`.
5. Check whether a dedicated runtime file exists in:
   `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\lua\shared\UniversalTraits\traits\UT_<trait>.lua`
6. If a runtime file exists, treat that file as the current behavior source of truth.
7. If no runtime file exists, check whether the trait is currently script-only or whether behavior appears to be missing.
8. Search `UT_CORE` for shared hooks or helper functions the trait may depend on.
9. Search `UniversalTraits\test\run_tests.lua` for trait-specific tests.
10. If the trait came from another mod, inspect the upstream mod files before writing any conclusion.
11. Record one verdict per trait:
    - `description drift`
    - `behavior drift`
    - `both drifted`
    - `source intent not yet recovered`

## What To Write Down For Each Trait

For every reviewed trait, produce a compact note with these fields:

- Trait id
- Current runtime source path
- Current script block path
- Current translation path
- Current tests path or `none found`
- Upstream/original mod source path or `not found locally`
- Plain-language summary of actual behavior
- Plain-language summary of current description text
- Verdict
- Recommended next action

## Example 1: UT_batteringram

### Current UniversalTraits Source

- Runtime implementation:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\lua\shared\UniversalTraits\traits\UT_batteringram.lua`
- Script block:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\scripts\UT_character_traits.txt`
  around the `character_trait_definition UniversalTraits:UT_batteringram` block
- Translation text:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\lua\shared\Translate\EN\UI_EN.txt`
  around `UI_UT_batteringram` and `UI_UT_batteringramDesc`
- Tests:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\test\run_tests.lua`
  around the `UT_batteringram collision tests` section
- Shared helper used by the trait:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UT_CORE\media\lua\shared\UTCore\UTCore_ZombieCollisionHook.lua`

### Current Reality

`UT_batteringram.lua` currently says the trait does this:

- only triggers when the player is sprinting or running
- cancels the native bump stagger/trip
- knocks the zombie down
- drains endurance per collision
- optionally delegates bonus damage to `UT_martial`

`UI_UT_batteringramDesc` currently says this:

- shove and knockback force are increased by `+50%`

Those are not the same mechanic. This is a clear example of description drift.

### Upstream Source To Compare Against

These local workshop files show that `Battering Ram` also exists in More Traits:

- Original trait script block:
  `C:\Steam\steamapps\workshop\content\108600\1299328280\mods\More Traits\42.15\media\scripts\ToadTraits.txt`
  around `character_trait_definition ToadTraits:batteringram`
- Original translation text:
  `C:\Steam\steamapps\workshop\content\108600\1299328280\mods\More Traits\42.15\media\lua\shared\Translate\EN\UI_EN.txt`
  around `UI_trait_batteringram` and `UI_trait_batteringramdesc`
- Registration / creation hookup:
  `C:\Steam\steamapps\workshop\content\108600\1299328280\mods\More Traits\42.15\media\lua\shared\NPCs\MoreTraitsMainCreationMethods.lua`

The More Traits description says, in plain language:

- while sprinting, you knock down zombies in your path
- each knockdown drains endurance
- it overrides the spear charge ability

That is much closer to the current UniversalTraits runtime implementation than the current UniversalTraits description text.

### Working Conclusion For UT_batteringram

Use `UT_batteringram` as the model example of a trait whose current runtime file is probably closer to the intended behavior than the current description text.

## Example 2: UT_antique

### Current UniversalTraits Source

- Registry entry:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\registries.lua`
  around `UTTraitsRegistries.UT_antique`
- Script block:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\scripts\UT_character_traits.txt`
  around `character_trait_definition UniversalTraits:UT_antique`
- Translation text:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\lua\shared\Translate\EN\UI_EN.txt`
  around `UI_UT_antique` and `UI_UT_antiqueDesc`

### Current Reality

The current script block for `UT_antique` is only:

- cost 6
- `XPBoosts = Scavenging=1`

The current description text says, in plain language:

- antique collecting gives practical knowledge
- gain extra scavenging XP

No dedicated runtime file was found at:

- `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\lua\shared\UniversalTraits\traits\UT_antique.lua`

So, based on the current local source tree, `UT_antique` is not presently implemented as a rare-special-loot trait.

### Important Intent Note

The intended behavior reported by the user is:

- `Antique Enthusiast` should rarely spawn certain stronger-than-vanilla items

That intent is not reflected in the current UniversalTraits implementation.

### Upstream Source Status

Local filesystem search checked these roots:

- `C:\Steam\steamapps\workshop\content\108600`
- `C:\Users\Admin\Zomboid\mods`

`Antique Enthusiast` was found locally only in UniversalTraits, not in the checked More Traits files.

That means one of these is true:

1. the original source mod is not installed on this machine
2. the trait came from a different mod, not the local More Traits copy
3. the remembered behavior exists under a different trait name or translation key

### Best Internal Reference Pattern For Future Implementation

If later work needs to restore rare bonus-loot behavior, use this existing UniversalTraits trait as the closest local implementation pattern:

- Loot injection runtime file:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\media\lua\shared\UniversalTraits\traits\UT_vagabond.lua`
- Loot tests:
  `C:\Users\Admin\Documents\GIT\GameMods\PZMods\UTMods\UniversalTraits\test\run_tests.lua`
  around the `UT_vagabond loot mechanic tests` section

`UT_vagabond` already does all of the following:

- hooks container inspection
- rolls a chance
- adds an item from a defined loot table
- marks the container so it cannot pay out repeatedly
- has focused unit tests

That makes it the best local pattern if `UT_antique` needs a rare-item spawn mechanic later.

### Working Conclusion For UT_antique

Treat `UT_antique` as a source-recovery problem first, not a wording-only cleanup.

Do not guess the item list or spawn odds until the original source is recovered or the desired behavior is explicitly re-specified.

## Output Standard For The Review Pass

For this handoff task, the smaller agent should produce a review document, not code changes.

Minimum output per trait:

- exact files checked
- plain-English actual behavior
- plain-English claimed behavior
- whether upstream source was found
- verdict
- short recommendation

## Explicit Non-Goals For This Pass

- do not edit trait code
- do not edit descriptions
- do not regenerate translations
- do not sync release
- do not deploy to live mods
- do not invent missing behavior from memory alone

The point of this pass is to make the later low-effort fix pass safe and obvious.