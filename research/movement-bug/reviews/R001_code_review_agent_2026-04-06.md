# R001: Code Review Agent Feedback (2026-04-06)

**Reviewer:** Code review subagent  
**Reviewed:** Initial Opus analysis of Findings 1, 2, 3

## Corrections Applied

### Finding 2 (SpeedHook setX/setY) — Strongest lead, overclaimed mechanism
- **Accepted:** SpeedHook calling setX/setY is dangerous. setX overwrites nextX/scriptNextX. PROVEN.
- **Corrected:** "setX kills engine deferred movement because deferred movement is stored as
  nextX minus x" is NOT proven. Deferred movement comes from `animPlayer.getDeferredMovement()`
  (IsoGameCharacter.java:1321), not a visible nextX-x calculation.
- **Corrected:** "Walk To works because OnPlayerMove never fires for it" is REFUTED.
  IsoPlayer.java:2370-2374 shows pathfinding sets justMoved=true, which triggers OnPlayerMove.
- **Resolution:** Hypothesis split. The hook is dangerous (proven). The specific kill mechanism
  and Walk To explanation need further work. See H001 + P005.

### Finding 1 (UT_natural) — Real bug, overclaimed severity
- **Accepted:** UT_natural caches derived speed, not raw base. Real bug. PROVEN.
- **Corrected:** "Permanent corruption" is overclaimed. Vanilla resets moveSpeed to 0.06F
  in BodyDamage.java:2529 during regular body-damage updates.
- **Corrected:** "Zero-speed pin" is hypothesis without evidence. No code path writes zero.
  All getMoveSpeed penalties are positive multipliers. Pcall fallback prevents nil.
- **Corrected:** Cannot explain keyboard-only symptom split — moveSpeed affects both paths equally.
- **Resolution:** Downgraded to confirmed-but-secondary bug. See H002 + P006.

### Finding 3 (TchernoLib conflict) — Structural risk, not proven active
- **Accepted:** Both systems use setX/setY position rewriting. Structural risk is real.
- **Corrected:** No active consumers of SetPlayerSpeed or WalkSpeedTuning.activate found.
  TchernoLib may be at default 1.0 (inactive). "This is happening" is not evidenced.
- **Resolution:** Conditional hypothesis. See H003.

## Open Questions Highlighted by Review

1. **The Walk To gap is the #1 unresolved question.** If SpeedHook's setX/setY is the cause,
   why does Walk To survive when OnPlayerMove fires for it too?
2. **Character trait inventory needed.** Does the bug reproduce with no speed-modifying UT traits?
3. **Premature fix recommendations.** Don't propose fixes until the mechanism is proven.
