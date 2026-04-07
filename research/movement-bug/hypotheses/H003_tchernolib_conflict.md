# H003: External Movement-Library Conflict Class (TchernoLib + Similar Mods)

**Status:** OPEN — structurally plausible, not proven as the current co-cause  
**Probability:** Medium (conditional on H001)  
**Depends on:** P003, P004, P013

## Hypothesis

UT's SpeedHook is one instance of a broader conflict class: external movement systems that
continuously derive deltas from live position and then rewrite absolute position with
`setX()` / `setY()`. TchernoLib is one concrete example, but not the only one.

When two such systems are active with non-identity modifiers, each system can compute deltas
from positions the other has already rewritten, creating compounding errors, oscillation, or
movement cancellation.

## What Supports This

1. UT Core and TchernoLib both use the same setX/setY position-rewrite approach — proven from source.
2. Lifestyle contains an active non-UT movement helper that also derives deltas from last position
   and rewrites position during `OnPlayerUpdate` — proven in P013.
3. TchernoLib stores its own `SpeedFrameworkPos` in moddata; UT stores `UT_prevX`/`UT_prevY`.
   Neither is aware of the other's writes.
4. TchernoLib's author documented the fragility of setX in comments.

## What Does NOT Support This

1. **No active TchernoLib consumers found locally:** A search for `SetPlayerSpeed` and
   `WalkSpeedTuning.activate` call sites across installed mods found only definitions, not consumers.
   So TchernoLib's speed modifier may be at its default 1.0 (inactive) in the current loadout.
2. **TchernoLib early-exit:** When speedModifier is ~1.0, SpeedFramework.isSpeedFrameworkActive
   returns false (line 68) and the position-rewrite code does not execute.
3. **Current reproduction still points to UT alone:** P001 already shows disabling UT removes the bug
   while other mods remain. That proves UT is sufficient for the observed failure.
4. **Isolation gap remains for future stacks:** We have not tested every future mod combination that
   could activate another member of this conflict class.

## What Would Confirm This

- Bug disappears when a second movement-rewrite system is disabled while UT remains enabled.
- Instrumentation shows TchernoLib or another movement helper is active with a non-identity modifier
   during a failing run.
- A future stack reproduces worse or different movement failure only when UT is combined with another
   continuous position-rewrite mod.

## What Would Refute This

- Every external movement library in the tested stack is confirmed inactive or absent, and UT alone
   fully explains the behavior.
- A replacement UT implementation that avoids absolute position rewriting eliminates the failure even
   when other movement mods remain active.

## Note on TchernoLib Version

The handoff noted the active Workshop subscription is "TchernoLib B41" and the author
says B42 users should use a different linked mod. That remains worth noting, but the more
important research update is that TchernoLib is only one member of a broader compatibility
class. The fix should be robust against the class, not narrowly against that one library.
