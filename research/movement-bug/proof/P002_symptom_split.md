# P002: Symptom Split — Arrow Keys vs Walk To

**Proven on:** 2026-04-06  
**Proven by:** User live testing  
**Confidence:** Absolute — user-validated

## Fact

- Manual keyboard directional movement (arrow keys) is broken.
- Right-click "Walk To" (pathfinding) works normally.
- The character CAN move through the world via pathfinding.

## Implication

- This is NOT a total locomotion failure.
- The broken code path is specific to direct keyboard-driven movement.
- Anything that equally affects both pathfinding and keyboard movement is a weaker suspect.
