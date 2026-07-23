# UT_gordanite

## Trait Summary

- Full id: `UniversalTraits:UT_gordanite`
- Pre-campaign authority: `a32f251e7cebdc27b533907b6b16c7aa135eb882`
- Accepted implementation commits: `5b8b28fd2cac6198dadeb3c703f24706967aac9f`,
  `6497d16ddc181cb387d069daa96c94ebcec2d549`
- Cost: `4`
- Cooking XP boost: `+2`
- Grants and exclusions: none
- Static state: corrected and independently accepted
- Retained state: runtime-unproven

## Historical Review

The campaign originally confirmed three defects:

- `IR0104-GORDANITE-DOUBLE-CALORIES`: the inventory mutation plus post-consumption
  correction produced 2.25 times base calories.
- `IR0104-GORDANITE-HOOK-STACK`: repeated startup could stack shared consumption wrappers.
- `IR0104-GORDANITE-ITEM-SCOPE`: the trait mutated transferable food state without
  reliable cook ownership.

Commit `5b8b28fd2cac6198dadeb3c703f24706967aac9f` removed those designs in favor of
native-delta accounting, but independent review rejected its chef-identity fallback when a
username getter failed. That rejection remains historical evidence. Commit
`6497d16ddc181cb387d069daa96c94ebcec2d549` made the exact three-file correction,
and the final independent review accepted it.

## Accepted Contract

- The trait file is declaration-only. It performs no tick scan or inventory scan.
- Gordanite owns no persistent item mutation, calorie mutation, or item modData.
- Completed and interrupted eating call the native action exactly once.
- The hook snapshots immutable pre-native and post-native meal state.
- A qualifying meal adds half of each independently positive native hunger-relief and
  calorie delta.
- Chef ownership matches either an independently protected non-empty username or an
  independently protected non-empty full name. Invalid identities fail closed.
- Gourmand and Gordanite are additive from the same immutable native hunger delta, for
  exactly 2.0 times native hunger relief.
- Wildsman behavior and food modData ownership remain unchanged.
- Native return values and native errors are preserved.
- Repeated loading preserves one wrapper identity and one effect.

## Accepted Evidence

- Focused Gordanite runtime cases: `13/13`.
- Full UniversalTraits suite: `586/586`.
- Final independent review: `ACCEPT` at `6497d16d`.
- Final review reported source/release hook SHA-256:
  `C4F91442FB1B0ACA042CA5311E5F986B061CD5702FEFC10739CAA1A0A8A0B6F9`.
- Source and release copies are exactly equal with no release drift.
- Read-only package verification reports only the unrelated
  `missing-source:poster.png`.

## Retained Runtime Proof

Actual current-build Kahlua/SVN 964 consumption remains unobserved. Closure still requires
a full exit-to-desktop relaunch, completed and interrupted real meal consumption, chef
identity variants, Gourmand composition, repeated world entry, and current-version
save/load. Rendered English, gameplay balance, and profiler observation also remain open.

The missing source poster is a separate package issue and is not Gordanite closure evidence.
Multiplayer, backward migration, deployment, and rebalance are not part of this milestone.
