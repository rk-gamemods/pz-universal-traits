# UT_bouncer_II

## Accepted contract

- Trait ID: `UniversalTraits:UT_bouncer_II`
- Display name: `Bouncer II`
- Cost: 6
- XP boosts: Strength 2 and Doctor 2
- Reciprocal exclusion: `UniversalTraits:UT_bouncer_I`
- Multiplayer: disabled by definition and outside product scope
- Runtime effect: after Bouncer II is ready, the next new qualifying injury is downgraded once, then a Strength-scaled real-time cooldown begins.
- Injury mapping: bite to deep wound, deep wound to scratch, fracture time halved.
- Infection rule: infection that existed in the ready-state snapshot is preserved; infection introduced with a new bite is cleared.
- Cooldown: `max(10, 220 - Strength * 20)` real-world seconds.
- Save migration and backward compatibility are outside product scope.

The accepted authority is pre-campaign UTMods `master`, not the original upstream stagger implementation. Commit `d10b240` deliberately repurposed both Bouncer tiers from crowd stagger to injury downgrade and explicitly described its timer as real-world seconds. Commit `7627f7e` established the accepted Tier II formula and infection behavior. Commits `9e730018` and `137afb9` changed the Build 42 medical perk token from `FirstAid` to `Doctor` in source and release respectively.

## Definition and translation trace

`UniversalTraits/media/scripts/UT_character_traits.txt` defines Bouncer II once with cost 6, `Strength=2;Doctor=2`, and exclusion of Bouncer I. The Bouncer I block declares the reverse exclusion. Source and release definitions are byte-identical.

`UniversalTraits/media/lua/shared/Translate/EN/UI.json` states the injury mappings, the 220-second base cooldown, the 20-second reduction per Strength level, and the pre-existing infection limitation. Source and release English files are byte-identical. The description matches the accepted Bouncer II path.

## Runtime call map

1. `IsoPlayer.update()` performs body-damage processing and then triggers `OnPlayerUpdate` for the player.
2. `UTCore_TickDispatch.lua` owns the single `OnPlayerUpdate` registration, builds one shared tick context, and calls the active Bouncer handler because the player has Bouncer II.
3. On its first active update, `UT_bouncer_I.lua` stores a complete injury snapshot and marks the trait ready.
4. While ready, the handler obtains the shared injury view through `UTCore.getInjuries(tick)` and compares every body part with the snapshot.
5. The first qualifying new injury by body-part index is selected. Within a body part, bite is checked before deep wound and fracture.
6. The handler obtains the matching Java `BodyPart`, applies one downgrade through the current setters, stores the Tier II cooldown in seconds, and logs the action.
7. While Tier II is cooling down, each player update subtracts `getGameTime():getRealworldSecondsSinceLastUpdate()`. `GameTime` defines this as the number of real seconds since the last tick and adjusts it for actual frame cadence.
8. On the update that reaches zero, the handler takes a new baseline snapshot and returns. Injuries that arose during cooldown therefore do not become delayed Bouncer activations. A later new injury is eligible.

## Defect and correction

The accepted Tier II cooldown was previously multiplied by 60 and decremented once per `OnPlayerUpdate`. That assumes player updates occur at exactly 60 Hz. `IsoPlayer.update()` supplies no such fixed-rate contract, so frame or update cadence changed the real cooldown duration.

The correction stores Tier II cooldown seconds directly and subtracts the engine's real-seconds delta. Tier I already used that elapsed-time contract before this pass, so both mutually exclusive tiers now share one time unit and one countdown path.

The older package-perk finding was stale before this correction. Current source and release both use the valid Build 42 `Doctor` perk token. Git history proves this was an already-completed source/release cascade, not a new intent decision.

## Java and Lua boundary evidence

- `PZCodebase/Java/source/zombie/characters/IsoPlayer.java:2241` triggers `OnPlayerUpdate` from the player update path.
- `PZCodebase/Java/source/zombie/GameTime.java:195-201` exposes `getRealworldSecondsSinceLastUpdate()` and defines it as real seconds since the last tick.
- `PZCodebase/Java/source/zombie/Lua/LuaManager.java:7840-7843` separately exposes wall-clock `getTimestampMs()`. It was not used because a persistent absolute timestamp would allow offline wall time to consume a saved cooldown.
- Current vanilla Lua uses `getGameTime():getRealworldSecondsSinceLastUpdate()` for real-time countdowns, including `ISRestAction.lua`.
- The standard-Lua Java API validation and injury mocks cover every BodyPart getter and setter on the Bouncer path.

## State and edge behavior

- First activation snapshots existing injuries and does not downgrade them.
- No injury scan occurs during cooldown.
- Cooldown expiry re-baselines current injuries and returns without a downgrade.
- One qualifying body part is changed per activation.
- Multiple simultaneous qualifying parts are deterministic by body-part index and are logged as `MULTI_NEW`.
- A bite created with a new infection has that infection cleared.
- Infection already present in the ready snapshot is preserved.
- A fracture is eligible only when fracture time is greater than 1.
- Bouncer I and II are selection-exclusive in both definition directions.

## Regression proof

The standard-Lua suite covers:

- first-update snapshot behavior;
- bite, deep wound, and fracture mappings;
- infection clearing and preservation;
- one-injury-per-cooldown behavior;
- simultaneous injury ordering;
- injury-at-expiry baseline behavior;
- Strength 5, 9, and 10 Tier II formulas;
- a quarter-second plus three-quarter-second oppositional timing case that expires after one total elapsed second rather than a fixed update count;
- retained Tier I elapsed-time behavior;
- source/release runtime parity;
- definition, English, and perk-token consistency.

## Remaining proof

The static path and standard-Lua regression suite prove the corrected contract. The following remain explicitly unobserved:

- current-build Kahlua execution after a full desktop relaunch;
- current-version repeated world entry and save/load behavior;
- rendered English in the live UI;
- representative in-game profiler capture;
- gameplay balance telemetry.

No multiplayer, backward save migration, deployment, or Bouncer I behavioral change is part of this trait pass.
