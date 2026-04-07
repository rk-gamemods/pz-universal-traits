# H004: WorkSpeedHook Global Monkeypatch Collateral Damage

**Status:** OPEN — low probability but not investigated  
**Probability:** Low

## Hypothesis

UTCore_WorkSpeedHook.lua:48-57 iterates ALL global variables at OnGameBoot and wraps
`getDuration()` on any table that has it:

```lua
local function patchTimedActions()
    for _, v in pairs(_G) do
        if type(v) == "table" and type(v.getDuration) == "function" then
            local orig = v.getDuration
            v.getDuration = function(self)
                local base = orig(self)
                return UTCore.applyWorkDuration(self, base)
            end
        end
    end
end
```

If any movement-related system happens to have a table in `_G` with a `getDuration` method,
this could accidentally wrap it and alter its behavior.

## What Supports This

- The pattern is aggressive — it patches ALL globals with getDuration, not just known TimedActions.
- `_G` in PZ contains many Java-bridged tables that could have unexpected getDuration methods.

## What Does NOT Support This

- getDuration is a TimedAction pattern; movement code doesn't typically use it.
- The wrapper only modifies the return value (duration), not movement state.
- No specific movement table with getDuration has been identified.

## What Would Confirm This

- Instrumentation: log which tables actually get patched. If any non-TimedAction table
  is patched, investigate whether it's movement-related.

## What Would Refute This

- All patched tables are confirmed TimedAction subclasses.
- Bug persists with the patchTimedActions function disabled.

## Priority

Low. Investigate only if H001 is refuted.
