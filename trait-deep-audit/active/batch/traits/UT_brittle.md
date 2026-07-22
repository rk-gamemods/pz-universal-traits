# UT_brittle

## Accepted Pre-Campaign Contract

- Authority: `master` immediately before the remediation campaign.
- Cost: -6.
- Multiplayer: disabled by the trait definition; multiplayer support is not a product goal.
- On new game, a player with `UniversalTraits:UT_brittle` receives `UT_fractureMult = 1.5` in mod data.
- The shared fracture hook rolls on `OnWeaponHitCharacter` with a base chance of 4 percent. The multiplier produces `floor(4 * 1.5) = 6` percent.
- A successful roll fractures one eligible unfractured leg or arm for fracture time 21.
- A successful fracture starts a 10 in-game-second cooldown.
- The historical SomewhatTraits fall and collision mechanic is source evidence only. It is not the accepted UTMods behavior and was not restored.

## Full Static Runtime Trace

1. SVN 964 `IsoGameCharacter.Hit` emits `OnWeaponHitCharacter(wielder, target, weapon, damageSplit)`.
2. `UTCore_FractureHook.lua` binds the same four positions as `(attacker, target, weapon, damage)`.
3. The hook reads `UT_fractureMult` from the emitted target. Values absent or at most 1 stop the path.
4. `GameTime.getWorldAgeHours()` supplies elapsed game time. A stored `UT_fractureCooldownUntil` blocks rolls until its absolute expiry.
5. `ZombRand(100)` is compared with `floor(4 * multiplier)`. Brittle therefore rolls at 6 percent.
6. The hook checks exactly six body parts. Parts whose `getFractureTime()` is above zero are excluded.
7. One eligible part is selected and receives `setFractureTime(21)`.
8. The hook stores a new expiry 10 in-game seconds after the current world age.
9. Same-process reload removes the previously stored callback before registering the replacement, leaving one handler.

## Resolved Defects

- `B02-UT_brittle-01`: the pre-campaign callback bound target and weapon in the wrong positions, so the player guard returned before any roll. Commit `2f98749` corrected the callback to the producer's four-argument order.
- `B02-UT_brittle-02`: the pre-campaign value 300 was decremented once per later hit, so the documented 10-second cooldown actually meant 300 hits. Commit `2f98749` replaced it with an absolute world-age expiry.
- The hook now uses `setFractureTime(21)`, which directly establishes the current SVN 964 fracture state.
- Source and 42.0 release copies are byte-identical.

## Regression Proof

- The UT_CORE suite fires the exact engine order and proves a successful fracture.
- It proves values at or below multiplier 1 do nothing.
- It proves 10 seconds elapse without requiring intervening hit callbacks.
- It proves already fractured parts are skipped.
- It proves same-process reload retains exactly one weapon-hit handler.
- The UniversalTraits suite proves the mod-data multiplier is written only for a player with Brittle.

## Open Proof And Decision Boundary

- Current-build Kahlua execution, full relaunch, current-version save/load, rendered English, balance telemetry, and profiler capture remain unobserved.
- SVN 964 emits the weapon-hit event before later hook cancellation, `avoidDamage`, `noDamage`, and final damage processing. The pre-campaign UTMods baseline deliberately attached Brittle to this event, and its description says bones snap under stress. Static evidence does not establish whether cancelled, avoided, or zero-final-damage contacts should be excluded. Changing that outcome requires user approval, so it remains a decision question rather than a silently changed mechanic or release blocker.
- Backward save migration and multiplayer are explicit non-goals.

## Verdict

The two confirmed pre-campaign implementation defects are corrected and protected by producer-faithful tests. The accepted Brittle outcome is statically coherent end to end. Runtime observation and the explicitly identified contact-policy decision remain open.
