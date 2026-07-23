# Paramedic accepted runtime resolution

Status: runtime-unproven after accepted static correction.

The accepted pre-campaign intent remains unchanged: cost 4, Doctor +2, no
exclusions, and an independent 0.5 duration multiplier for medical timed
actions. Commits `6929d4221ecf6b9a204a7438e13608fa6d9549a8` and
`6d6fb2758f0b1db8fc2d717a507f27bc3631c304` replace the invented
`Events.OnActionAdded` path with the shared work-duration hook.

The exact SVN 964 medical action `Type` allowlist is:

- `ISMedicalCheckAction`
- `ISApplyBandage`
- `ISCleanBurn`
- `ISComfreyCataplasm`
- `ISGarlicCataplasm`
- `ISPlantainCataplasm`
- `ISDisinfect`
- `ISRemoveBullet`
- `ISRemoveGlass`
- `ISSplint`
- `ISStitch`

`ISApplyComfrey`, `ISApplyGarlic`, and `ISApplyPlantain` are invented
identifiers and remain non-targets. Focused deterministic tests prove all
eleven accepted identifiers receive exactly the independent 0.5 multiplier,
ordinary actions and invented identifiers remain unchanged, repeated duration
queries do not compound, and constructor-only actions are patched once.

Historical evidence remains valid history: the first implementation review
correctly rejected the old nonexistent event and mock. The current accepted
resolution supersedes that implementation state without erasing the earlier
finding.

Still unproven at runtime:

- current-build Kahlua load after a full exit-to-desktop relaunch;
- representative real medical action exercise for all relevant constructor and
  duration paths;
- new game, current-version save/load, death, and repeated world entry;
- rendered English, gameplay balance, and profiler observation.

Multiplayer support and backward save migration remain explicit non-goals.
