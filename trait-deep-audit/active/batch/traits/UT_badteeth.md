# UT_badteeth

## Contract

- Trait id: `UniversalTraits:UT_badteeth`
- Accepted authority: pre-campaign `master`, upstream MoreTraits source, and pre-campaign Git history
- Cost: -3
- Honest intended outcome: eating that increases the engine food-healing timer adds head pain equal to 1 percent of that increase, only when the resulting timer is above 1000, capped at 100 pain
- Exclusion: reciprocal with `UniversalTraits:UT_albino`
- Multiplayer: disabled and outside product scope
- Save migration: outside product scope

## Intent Evidence

The implementation first entered UTMods in commit `1da8489b524403589d5f8c411bf50a8504516a09`. Its runtime formula was:

```lua
if timer > 1000 and timer > prev then
    head:setAdditionalPain(math.min(current + (timer - prev) * 0.01, 100))
end
```

The accepted English copy on pre-campaign `master` says:

> Dental problems make eating painful. Eating causes increasing head pain (proportional to food healing). Food effectiveness is not reduced - it just hurts.

Upstream MoreTraits 42.15 uses the same threshold, delta multiplier, head body part, and 100 cap in `badteethtrait`. Its creation source explicitly declares `badteeth` and `albino` mutually exclusive. Commit `be6eed180bc7f7ece046b84d2083c4bc6b7706e9` carried that exclusion into UTMods before this campaign. These sources agree on the intended effect and exclusion, so no design guess is required.

## Engine Trace

Current decompiled SVN 964 establishes the complete food-healing chain:

1. `ISEatFoodAction:complete()` calls `character:Eat(item, percentage, useUtensil)` for completed consumption.
2. `ISEatFoodAction:eat()` calls the same Java method with the effective partial fraction for interrupted consumption.
3. `IsoGameCharacter.Eat()` applies native food stats and calls `BodyDamage.JustAteFood(food, percentage, useUtensil)`.
4. `BodyDamage.JustAteFood()` increases `healthFromFoodTimer` from the food's hunger change when the character is fully fed, doubles that increase for cooked food, and caps the timer at 11000.
5. `BodyDamage.Update()` later spends that timer to heal the character and decrements it each update.
6. `IsoPlayer.update()` runs `BodyDamage.Update()` before firing `OnPlayerUpdate`.

Therefore the authoritative increase happens synchronously inside `character:Eat`. A later player-update poll is an indirect and slightly decayed observation of an already-completed change.

## Pre-Correction Defect

The pre-campaign port stored the last observed timer in player modData and polled it on every `OnPlayerUpdate`:

```lua
local prev = UTCore.getModData(player, "badteethTimer", 0)
UTCore.setModData(player, "badteethTimer", timer)
```

That path had four concrete problems:

1. It ran body, timer, and modData work every player update even though the relevant state changes only when food is consumed.
2. It observed the timer after the engine update path could already decrement it, rather than at the exact native mutation boundary.
3. Its result depended on persisted polling state and the timing of trait acquisition, reload, or re-entry instead of only on the current consumption call.
4. The tests fabricated a timer jump and fired `OnPlayerUpdate`; they did not prove completed or interrupted native consumption ordering.

The pain formula itself, threshold, cap, target body part, cost, description, and reciprocal exclusion were accepted and are preserved.

## Correction

`UT_ItemConsumptionHooks.lua` now owns Bad Teeth alongside the existing Anorexy and Competitive Eater consumption effects.

For both completed and interrupted positive consumption it:

1. reads the food-healing timer before native consumption;
2. calls the original engine-facing timed-action method exactly once;
3. reads the timer after native consumption;
4. if the player has Bad Teeth, the resulting timer is above 1000, and it increased, adds `(after - before) * 0.01` head pain;
5. caps head pain at 100.

The prior `OnPlayerUpdate` registration is removed during same-process reload. No Bad Teeth timer modData is read or written. A guarded pre-read cannot prevent the original consumption call if the body-damage bridge is unavailable.

## Definition and Player-Facing Contract

- Registration: exact `UniversalTraits:UT_badteeth`
- Definition: cost -3, no XP boosts, no granted traits, disabled in multiplayer
- Reciprocal exclusion: Bad Teeth excludes Albino and Albino excludes Bad Teeth
- English display: `Bad Teeth`
- English description: unchanged because it accurately states the accepted outcome
- Non-English UniversalTraits locales: absent, tracked as a coverage gap

## Regression Proof

The standard-Lua suite now proves:

- exact completed-consumption pain after native timer mutation;
- exact interrupted partial-consumption pain;
- the 1000 threshold;
- rising-edge, trait-presence, and positive-consumption guards;
- exact accumulation from later meal deltas;
- the 100 pain cap;
- no player-update polling or obsolete modData writes;
- no retained Bad Teeth periodic handler;
- body-damage read failure cannot block native consumption;
- one shared wrapper call composes Bad Teeth, Anorexy, and Competitive Eater without interference;
- reciprocal Albino exclusion;
- exact English copy and source/release parity.

Current result: 465 passed, 0 failed.

## Remaining Runtime Evidence

Static source, history, current decompiled engine code, and deterministic tests prove the implemented contract. The following remain runtime evidence, not confirmed defects:

- current-build Kahlua execution after a full relaunch;
- current-version repeated world entry and save/load observation;
- rendered English observation;
- gameplay balance telemetry;
- profiler capture;
- full package verification, currently blocked by the separately tracked missing source `poster.png`.

No deployment or live-copy mutation was performed.
