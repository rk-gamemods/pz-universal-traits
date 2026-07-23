# UT_sundayrunner

## Accepted contract

- Trait id: `UniversalTraits:UT_sundayrunner`
- Cost: `-1`
- Multiplayer: disabled
- XP boosts and grants: none
- Character-creation exclusion: reciprocal with `UniversalTraits:UT_sprintdemon`
- Runtime: on UTCore `EveryOneMinute`, resolve only `getPlayer()`. If that local registered player has Sunday Runner and `isSprinting()` is true, add exactly `2` to `CharacterStat.UNHAPPINESS`, capped by the native stat domain.
- Explicitly absent: stress, panic, boredom, Fitness or Sprinting level changes, XP changes, and legacy BodyDamage unhappiness writes.
- Reload behavior: one replacement periodic handler for this trait/event key.
- English description: `Sprinting increases unhappiness by 2 every in-game minute.`

This is the accepted post-review contract from commits
`23524ac` and `ec57b7f426c9b1376597064b840368bc5105348f`. The honest
pre-campaign behavior authority is `master` commit
`a32f251e7cebdc27b533907b6b16c7aa135eb882`.

## Source intent and disposition

The installed SomewhatTraits evidence establishes a negative sprinting-mood
trait at cost `-1` and a reciprocal Sunday Runner/Sprint Demon exclusion.
Some historical source variants mention or apply stress as well as
unhappiness, and one server variant applies unhappiness on `OnTick`. Those
variants establish origin, not the accepted UT cadence or effect set.

UTMods deliberately preserves the player-facing identity as a conditional
sprinting unhappiness penalty, but uses a bounded once-per-game-minute
application and no stress effect. This is an accepted intent resolution, not an
open request to restore source stress or tick cadence.

## Current structure

- `UniversalTraits/media/registries.lua` registers the exact namespaced id.
- `UniversalTraits/media/scripts/UT_character_traits.txt` defines cost `-1`,
  `DisabledInMultiplayer = true`, no `XPBoosts` or grants, and excludes
  `UniversalTraits:UT_sprintdemon`.
- The Sprint Demon definition reciprocally excludes Sunday Runner.
- Source and `42.0` release runtime, definition, registry, and English UI
  counterparts are byte-identical.
- No non-English UniversalTraits locale is present.

## Runtime trace

1. `UT_sundayrunner.lua` defines the exact trait id.
2. File load calls
   `UTCore.registerPeriodicHandler(TRAIT_ID, "EveryOneMinute", handler)`.
3. UTCore keys the registration by trait id and event. A duplicate module load
   removes the prior wrapper and installs one replacement.
4. The event wrapper ignores event arguments, calls `getPlayer()`, and passes
   only that local player to the trait handler.
5. The handler exits for nil, absent/removed trait, or non-sprinting states.
6. For a sprinting trait holder, it reads
   `player:getStats():get(CharacterStat.UNHAPPINESS)` and writes the current
   value plus `2`, capped at the native maximum.

SVN revision 964 anchors the relevant engine surface:

- `zombie/Lua/LuaEventManager.java` produces `EveryOneMinute` without a player
  argument.
- `zombie/characters/Stats.java` defines the generic character-stat storage and
  native domain used by `CharacterStat.UNHAPPINESS`.
- `IsoPlayer.isSprinting()` is the action-state predicate consumed by Lua.

The standard-Lua harness proves the mod-side chain. It does not prove current
Kahlua execution or current-build event production.

## Finding resolution

`B11-SUNDAY-001` is resolved by accepted commit `23524ac`:

- the English source and release descriptions now state the exact condition,
  amount, and cadence;
- the definition and reciprocal exclusion match the accepted contract;
- focused behavior tests cover exact addition, local-player/event-argument
  ownership, state and trait negatives, native clamping, absence of unrelated
  stat/XP/BodyDamage changes, and duplicate-load replacement;
- commit `ec57b7f` adds explicit event and metadata contract coverage.

The earlier audit claims about a Fitness penalty, missing Sprint Demon
exclusion, missing behavior tests, and unresolved design intent are superseded.

## Evidence confidence

High-confidence static plus standard-Lua evidence proves:

- exact registration, definition, exclusion, copy, and source/release bytes;
- local-player-only routing and exact `+2` unhappiness behavior;
- non-effects on stress, panic, boredom, Fitness, Sprinting, XP, and legacy
  BodyDamage unhappiness;
- native-domain cap behavior;
- one replacement periodic handler after duplicate module load.

## Retained proof gaps and non-goals

Still unobserved:

- live current-build Kahlua execution and current-build event production;
- full relaunch, new-game, current-version save-load, death, and repeated world
  entry;
- rendered English;
- any non-English locale;
- gameplay balance and profiler behavior.

Explicit non-goals are multiplayer support, backward save migration,
deployment, live mutation, and restoration of historical stress behavior.

## Verdict

The accepted Sunday Runner behavior, definition, reciprocal exclusion, English
copy, tests, and source/release package counterparts are statically reconciled.
The trait remains `runtime-unproven` until the retained live checks are run.
