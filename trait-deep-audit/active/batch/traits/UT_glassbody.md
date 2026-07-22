# UT_glassbody

## Accepted Contract

- Authority: pre-campaign UTMods `master`.
- Trait ID: `UniversalTraits:UT_glassbody`.
- Cost: -10.
- Exclusion: `UniversalTraits:UT_analgesia`, declared reciprocally.
- Intended outcome: all incoming damage reduces overall body health by 1.5 times the ordinary resolved loss.
- Setup: `Events.OnNewGame` writes `UT_damageMult = 1.5` to player mod data.
- Scope: single-player. Multiplayer and backward save migration are explicit non-goals.

The pre-campaign English description promises "All incoming damage" at a 1.5 multiplier. The pre-campaign shared implementation attempted to consume the same marker, so weapon-only behavior is not an accepted narrowing of intent.

## Historical Source Boundary

More Traits 42.15 is supporting lineage evidence, not the authority for this port. Its `glassbody` implementation observes overall body-health loss and its English copy says damage from all sources. It also adds probabilistic scratches and fractures. Pre-campaign UTMods deliberately replaced that larger mechanic with a flat +50 percent total-health penalty, so the extra wound behavior was not restored.

## Corrected Runtime Trace

1. `UT_glassbody.lua` handles `OnNewGame` and writes the exact multiplier `1.5` only for a player with the trait.
2. UT_CORE already owns one central `OnPlayerUpdate` dispatch. `UTCore_DamageMultHook.lua` installs one stored core-dispatch callback and does not add a second update loop.
3. If `UT_damageMult` is absent, non-finite, or at most 1.0, the callback clears its transient baseline and returns.
4. For an active multiplier, the callback reads `BodyDamage:getOverallBodyHealth()` and establishes a baseline for the current player object.
5. A later resolved health decrease is multiplied by applying `(previousHealth - currentHealth) * (multiplier - 1)` through `BodyDamage:ReduceGeneralHealth()`.
6. Extra damage is capped at the remaining health. Healing replaces the baseline and is never treated as damage.
7. The callback stores the expected post-reduction health because `ReduceGeneralHealth()` changes body parts immediately while `calculateOverallHealth()` refreshes the aggregate later. This prevents the hook from multiplying its own extra damage on the next update.
8. Player replacement, missing state, invalid health, and same-process Lua reload establish a fresh baseline instead of attributing old health to a new session.
9. Reload removes any obsolete pre-resolution `OnWeaponHitCharacter` listener left by an earlier version. A stable dispatcher wrapper swaps to the current callback without adding another core handler.

## Engine Contract

- SVN 964 `IsoPlayer.updateInternal2()` emits `OnPlayerUpdate` before `IsoPlayer.updateInternal1()` continues into `IsoGameCharacter.update()`.
- `IsoGameCharacter.update()` calls `BodyDamage.Update()`, which processes body damage and recalculates `overallBodyHealth` from the body parts.
- The following central update therefore observes the resolved aggregate loss. The correction is source-agnostic because it measures the resulting body-health change, not a source-specific event payload.
- SVN 964 emits `OnWeaponHitCharacter` and `OnPlayerGetDamage(..., "WEAPONHIT", ...)` before cancellation, avoidance, `noDamage`, and `processHitDamage`. Those events cannot safely supply resolved weapon damage.
- Other `OnPlayerGetDamage` producers use inconsistent timing and payload semantics. Avoiding them prevents weapon cancellation defects and covers sources that are represented only by body-health changes.
- `BodyDamage.ReduceGeneralHealth(float)` is public to Lua and distributes the extra loss across body parts. `BodyDamage.calculateOverallHealth()` later recomputes the aggregate from those parts.

## Corrected Defects

- The pre-campaign callback bound the weapon and target arguments in the wrong order, so real weapon hits returned without applying the trait.
- Correcting only that order was still insufficient because the weapon events occur before resolved damage and can fire for cancelled or avoided hits.
- The intermediate development implementation used pre-resolution `damageSplit`, so it could penalize cancelled contacts, ignored final armor and damage processing, and covered weapon hits only.
- The replacement measures resolved overall health and restores the promised all-source scope.
- The old tests simulated base damage before firing a pre-damage event. The corrected tests model resolved aggregate health, delayed `calculateOverallHealth()`, healing, lethal caps, player replacement, exact multiplier setup, and reload idempotence.

## Performance Contract

- No new event loop, process, timer, inventory scan, body-part scan, allocation-heavy queue, or background worker was added.
- The existing central update already obtains player mod data and the body-damage object once per frame for all UT_CORE handlers.
- An inactive player pays one Lua table lookup and simple validation. An active Glass Body player adds one `getOverallBodyHealth()` field read and performs a reduction only after actual health loss.
- Static bounds are small, but a current-build profiler capture remains required for empirical runtime proof.

## Regression Proof

- UT_CORE standard-Lua suite: 252 passed, 0 failed.
- UniversalTraits standard-Lua suite: 448 passed, 0 failed.
- Focused coverage proves exact +50 percent resolved loss, no recursive multiplication, multiplier-at-one no-op, healing baseline reset, lethal cap, player replacement, same-process reload idempotence, and exact `UT_damageMult = 1.5` setup.
- Source and 42.0 release copies of the shared hook are byte-identical.
- Source and 42.0 release copies of the trait runtime and English UI remain byte-identical.
- Read-only package verification reports no release-content drift. Both UniversalTraits and UT_CORE remain separately blocked by missing source `poster.png` assets that are also absent from pre-campaign `master`.

## Remaining Runtime Proof

- Execute under the current Kahlua runtime after a full Exit to Desktop and relaunch.
- Observe weapon damage, a cancelled or avoided weapon contact, falling, fire, bleeding, and one periodic survival-stat damage source.
- Confirm each resolved loss totals 1.5 times ordinary damage and that the hook never multiplies a cancelled or zero-health-loss contact.
- Save and reload a current-version Glass Body character, then verify that the transient baseline initializes without immediate damage and the next real loss is multiplied once.
- Capture a representative profiler sample. Rendered English and balance telemetry remain unobserved.

## Verdict

The accepted all-source +50 percent damage contract is statically reconciled and regression-protected. Current-build in-game behavior, save/load, rendering, and performance remain explicitly runtime-unproven. No deployment was performed.
