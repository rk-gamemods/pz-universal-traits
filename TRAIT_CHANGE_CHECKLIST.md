# Trait Change Checklist

Use this for any change to a trait's behavior, cost, description, or exclusivity.

## 1. Runtime Logic

- [ ] Update the trait Lua file under `UniversalTraits/media/lua/shared/UniversalTraits/traits/`
- [ ] If the change belongs in shared infrastructure, update the relevant `UT_CORE` hook/helper instead of duplicating logic in the trait
- [ ] Re-check event choice: `OnCreatePlayer` for ongoing/transient runtime setup, `OnNewGame` only for one-time spawn effects

## 2. Player-Facing Data

- [ ] Update the script block in `UniversalTraits/media/scripts/UT_character_traits.txt` if cost, namespace id, or `MutuallyExclusiveTraits` changed
- [ ] Update the translation text in `UniversalTraits/media/lua/shared/Translate/EN/UI.json`
- [ ] Make the description specific: exact values, exact conditions, exact disabled interactions

## 3. Mutual Exclusivity

- [ ] If the trait gained or lost incompatibilities, update `MutuallyExclusiveTraits` in `UT_character_traits.txt`
- [ ] Make intended character-creation exclusions explicit on both traits; script-side mutual exclusion is one-way for the pregame UI, so selecting either side should still hide the other side
- [ ] Treat `UniversalTraits/media/lua/shared/UniversalTraits/UT_MET.lua` as a reference table only; update it for UT runtime grouping or audits, but do not assume it drives character creation by itself
- [ ] Ensure every `UniversalTraits:` id used in `CharacterTrait`, `GrantedTraits`, and `MutuallyExclusiveTraits` is registered in `media/registries.lua`
- [ ] For cross-mod exclusions, only use a foreign trait id if that mod is a real hard dependency and you verified the exact namespaced id in that mod's `media/registries.lua`; unknown external ids are a known `isFree of non-table: null` crash path
- [ ] If the trait belongs to a runtime group table, also update `UniversalTraits/media/lua/shared/UniversalTraits/UT_MET.lua`
- [ ] If testing exclusivity with a changed mod list, verify `C:\Users\Admin\Zomboid\mods\default.txt` and do a full Exit to Desktop before retesting; `reloadlua` and menu-only reloads can leave stale modules or disabled mods confusing the result

## 4. Tests

- [ ] Update or add trait tests in `UniversalTraits/test/run_tests.lua`
- [ ] Update or add `UT_CORE/test/run_tests.lua` if shared hooks/helpers changed
- [ ] Update mocks if new PZ API methods or events were introduced
- [ ] Run both suites from repo root:

```bash
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UT_CORE/test/run_tests.lua
"C:\Users\Admin\AppData\Local\Programs\Lua\bin\lua.exe" UniversalTraits/test/run_tests.lua
```

## 5. Release And Deploy

- [ ] Sync `UT_CORE/release/UT_CORE/42/media/` from `UT_CORE/media/` if UT_CORE changed
- [ ] Sync `UniversalTraits/release/UniversalTraits/42/media/` from `UniversalTraits/media/`
- [ ] If translations changed, verify `UI.json` was synced into source, release, and live copies and that `UI_EN.txt` is absent
- [ ] Copy root `mod.info` into each release package root
- [ ] Deploy live to `C:\Users\Admin\Zomboid\mods\<ModName>\42\media\`
- [ ] Verify source, release, and live hashes match for any runtime file changed

## 6. Documentation And Commit

- [ ] Update `AGENTS.md` only when reusable project knowledge changed
- [ ] If the process itself changed, update this checklist
- [ ] Commit after tests, release sync, and deploy are complete
