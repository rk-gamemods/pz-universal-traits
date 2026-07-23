# UT_humanhamster

## Trait Summary

- Full id: `UniversalTraits:UT_humanhamster`
- Accepted implementation commits: `a2e89918da843e8f45c0e65115713f7f2d1ed027`, `8141d1a4230d7dd23bd9cb79f537e5af8b45f77f`
- Cost: `-1`
- Multiplayer: disabled
- Static state: repaired and independently accepted
- Retained state: runtime-unproven

## Historical Source Evidence

SomewhatTraits contained a commented-out `SWHumanHamster` treadmill-XP concept. UTMods deliberately
owns a different established contract. This historical source evidence remains relevant provenance,
but it does not override the accepted UTMods behavior or reopen the balance decision.

The first campaign audit correctly found two defects:

- `B05-HAMSTER-001`: numeric `WornItems:getItem(i)` did not match the current Build 42 API.
- `B05-HAMSTER-002`: the selection copy did not disclose the implemented benefit, craving condition,
  exact stress tiers, cadence, or reset.

Those findings remain in the campaign history as closed, not deleted.

## Accepted Contract

- Carry contribution: exactly `+2`, owned by Human Hamster.
- Craving reset: inventory is at least 80 percent of capacity and the player wears an inventory
  container.
- Craving cadence: evaluated once per in-game minute.
- Stress tiers: `+0.02` per minute after 10 craving minutes, `+0.04` after 30, and `+0.08` after 60.
- Trait loss, player replacement, death, dispatcher deactivation, and duplicate module evaluation
  remove only Human Hamster-owned carry and craving state.
- External carry buckets and unrelated state must survive cleanup.
- No XP effect, grant, exclusion, multiplayer support, backward migration, deployment, or rebalance is
  part of this milestone.

## Current Build 42 API Evidence

The SVN 964 `WornItems` contract is `size()` plus zero-based `getItemByIndex(int)`, returning
`InventoryItem`. The previous numeric `getItem(i)` call was invalid. Accepted commit `a2e89918`
uses the current API and focused tests enforce zero-based traversal.

## Runtime And Ownership Trace

The trait registers through the UTCore dispatcher and owns one carry bucket plus its craving state.
On each owned minute callback it checks the local player, trait/death state, inventory load, and worn
containers. Teardown drains only its owned contribution.

The first accepted implementation snapshot cleaned up trait loss, replacement, death, and duplicate
evaluation, but independent review found that dispatcher deactivation could leave the owned state
behind. Commit `8141d1a4` added the production teardown path. The final independent review accepted
that correction.

Production teardown proof begins with capacity 14, including an external `+4` bucket and Human
Hamster's `+2`. Deactivation removes only the owned `+2`, recomputes capacity to 12, preserves the
external `+4`, and preserves unrelated state.

## Player-Facing Copy

The source and release English text are byte-identical and state the `+2` carry benefit, the 80
percent plus worn-container reset condition, all three timing and stress tiers, per-minute cadence,
and reset behavior.

## Regression Proof

- Focused Human Hamster suite: `13/13`.
- Full UniversalTraits suite: `570/570`.
- Independent final review: `ACCEPT` at `8141d1a4`.
- Covered paths: API indexing, exact cost/copy, carry ownership, craving reset and tiers, trait loss,
  replacement, death, dispatcher deactivation, duplicate evaluation, external carry composition,
  unrelated-state preservation, and source-release parity.

## Final Verdict

`B05-HAMSTER-001` and `B05-HAMSTER-002` are statically repaired and closed with regression proof.
Human Hamster remains `runtime-unproven` because live current-build Kahlua execution, a full desktop
relaunch, and current-version save-load have not been observed.

Known unrelated blockers remain separate and open: 152 broader API baseline issues,
`containerObj.getContainer` smoke coverage, and the missing root `poster.png`.
