# P001: UT Stack Isolation Test

**Proven on:** 2026-04-06  
**Proven by:** User live testing  
**Confidence:** Absolute — user-validated

## Fact

With `UniversalTraits` and `UT_CORE` both disabled in `default.txt`, and ALL other mods left enabled, the keyboard movement bug disappears.

## Implication

- The root cause requires the UT stack to be loaded.
- Third-party mods alone (including TchernoLib, Authentic Z, etc.) are not sufficient to produce the bug.
- The cause is either:
  1. A bug inside UT/UT_CORE code
  2. A conflict that only manifests when UT/UT_CORE code is loaded alongside another mod

## Testing Constraints

- Valid tests require full Exit to Desktop between mod changes (not `reload lua`).
- `C:\Users\Admin\Zomboid\mods\default.txt` is the authoritative active mod list.
