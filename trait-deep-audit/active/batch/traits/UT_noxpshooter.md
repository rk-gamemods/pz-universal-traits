# UT_noxpshooter

## Trait Summary

- UT trait id: UT_noxpshooter
- Source mod: More Traits (ToadTraits)
- Source trait id: ToadTraits:noxpshooter
- Current cost: +3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (trait factory definition, line 225)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (trait factory definition, line 225 — identical)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/registries.lua` (CharacterTrait.register, line 82)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua` (CharacterTrait.register, line 82)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` (OnNewGame/OnCreatePlayer runtime, line 549)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (OnNewGame/OnCreatePlayer runtime, line 610)
  - `research/installed-mods/MoreTraits/mods/More Traits/42/media/lua/client/MoreTraits .lua` (B42 client runtime, line 563 — legacy perk-level assignment branch)
- Source trait definition (MoreTraitsMainCreationMethods.lua, line 225):
  - `TraitFactory.addTrait("noxpshooter", getText("UI_trait_noxpshooter"), 3, getText("UI_trait_noxpshooterdesc"), false, false)`
  - Positional parameters: id, display name, cost (+3), description, isNegative=false, isProfession=false
  - No `addXPBoost` calls; source grants no starting XP bonus via the trait factory.
- Source mutual exclusions (MoreTraitsMainCreationMethods.lua, lines 323, 327, 331, 332, 333, 396):
  - `noxpsneaky` ↔ `noxpshooter`
  - `noxptechnician` ↔ `noxpshooter`
  - `noxpshooter` ↔ `noxpaxe`
  - `noxpshooter` ↔ `noxpfirstaid`
  - `noxpshooter` ↔ `noxpmaintenance`
  - `antigun` ↔ `noxpshooter` (line 396)
- Source trigger paths:
  1. **B42.13 / B42.15 path** (`MoreTraits .lua`, lines 549–551 / 610–612): fires inside the OnNewGame/OnCreatePlayer handler. If `player:hasTrait(ToadTraitsRegistries.noxpshooter)`, calls `levelPerkByAmount(player, Perks.Aiming, 2)`. This sets Aiming to its current level +2 (a starting skill level grant), then sets XP to match the new level. No Reloading bonus is granted.
  2. **B42 legacy client path** (`42/media/lua/client/MoreTraits .lua`, line 563): if `player:HasTrait("noxpshooter")`, enters a loop to grant +2 Aiming levels using direct `LevelPerk` calls, guarded at a cap of level 9 (stops before 10). Same effect: +2 Aiming starting levels.
  3. No XP disable logic exists in the source — More Traits `noxpshooter` is purely a starting level grant, not an ongoing XP suppressor.
- Source behavior:
  - At character creation: +2 to Aiming starting level (via `levelPerkByAmount`). Reloading is not affected.
  - No ongoing hook. No XP suppression.
- Source EN description (UI_EN.txt, `UI_trait_noxpshooterdesc`): not directly read in this audit — the MoreTraits EN translation file was not opened; the description key `getText("UI_trait_noxpshooterdesc")` is referenced but its value is unknown from the files inspected.
- Source cost: +3 points.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes (`media/registries.lua`, line 207)
  - `UTTraitsRegistries.UT_noxpshooter = CharacterTrait.register("UniversalTraits:UT_noxpshooter")`
  - Positioned in the `-- PHASE 2 -- LUA-DRIVEN: NO-XP SERIES` block, first of six.
- Defined in UT_character_traits.txt: yes (lines 1443–1452)
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_noxpshooter`
  - `Cost = 3`
  - `UIName = UI_UT_noxpshooter`
  - `UIDescription = UI_UT_noxpshooterDesc`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_antigun`
- Translation strings present: yes (`media/lua/shared/Translate/EN/UI_EN.txt`, lines 443–444)
  - `UI_UT_noxpshooter = "No XP: Shooting"`
  - `UI_UT_noxpshooterDesc = "You have already mastered firearms and no longer learn from using them. Aiming and Reloading grant no XP."`
- Runtime Lua file exists: yes (`media/lua/shared/UniversalTraits/traits/UT_noxpshooter.lua`)
- Release copy exists: yes (`release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_noxpshooter.lua`; identical content confirmed by search)

### Mutual Exclusion Analysis

- UT definition declares: `MutuallyExclusiveTraits = UniversalTraits:UT_antigun` (one exclusion, in `UT_character_traits.txt` line 1451)
- `UT_antigun` definition reciprocates: `MutuallyExclusiveTraits = UniversalTraits:UT_noxpshooter` (line 1409) — symmetric.
- Source declared six mutual exclusions (all five other no-XP traits plus `antigun`). UT declares only one (`UT_antigun`). The other five no-XP series traits (`UT_noxptechnician`, `UT_noxpaxe`, `UT_noxpfirstaid`, `UT_noxpmaintenance`, `UT_noxpsneaky`) are **not** mutually exclusive with `UT_noxpshooter` in the UT script definition. Whether this omission is intentional (allowing stacking of no-XP traits) is not documented in the trait files.

### Runtime Trace

- Full Lua source of `UT_noxpshooter.lua` (11 lines):

  ```lua
  -- UT_noxpshooter.lua
  -- Disables XP gain for Aiming and Reloading

  local TRAIT_ID = "UniversalTraits:UT_noxpshooter"

  local function onNewGame(player)
      if not UTCore.hasTrait(player, TRAIT_ID) then return end
      UTCore.disableXP(player, "Aiming")
      UTCore.disableXP(player, "Reloading")
  end

  Events.OnNewGame.Add(onNewGame)
  ```

- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)` — fires once at new game start (not on load of a saved game).
- UT_CORE hooks used:
  1. `UTCore.hasTrait(player, TRAIT_ID)` — calls `player:getTraits():contains("UniversalTraits:UT_noxpshooter")`; returns false if player is nil or has no traits collection, returns true only if the exact trait ID string is present.
  2. `UTCore.disableXP(player, "Aiming")` — writes `player:getModData()["UT_xpDisable_Aiming"] = true`.
  3. `UTCore.disableXP(player, "Reloading")` — writes `player:getModData()["UT_xpDisable_Reloading"] = true`.
- Runtime chain (plain language):
  1. On new game start, `Events.OnNewGame` fires; `onNewGame(player)` is called.
  2. `UTCore.hasTrait` checks the player's trait list for `"UniversalTraits:UT_noxpshooter"`. If absent, the function exits immediately.
  3. If the trait is present, `UTCore.disableXP` is called for `"Aiming"`: sets `UT_xpDisable_Aiming = true` in mod data.
  4. `UTCore.disableXP` is called for `"Reloading"`: sets `UT_xpDisable_Reloading = true` in mod data.
  5. `UTCore_XPHook.lua` (`onAddXP`, line 19) intercepts every `Events.AddXP` event. Its first check (lines 24–27): if `md["UT_xpDisable_" .. perk]` is truthy, it calls `player:getXp():AddXP(perk, -amount, false, false, false)` and immediately returns, cancelling the full earned amount.
  6. Both mod data keys are permanent for the lifetime of that save — no removal or reset path exists in the trait file or in UTCore.
- Actual behavior (exact values):
  - Aiming XP: completely disabled; every `AddXP` event for Aiming is cancelled by a matching negative amount (net = 0).
  - Reloading XP: completely disabled; same mechanism.
  - No starting skill level grant. No stat changes. No ongoing timed effects.
  - Effect is permanent from new game start; no cadence, no cooldown, no periodic handler.

### Source vs. UT Behavioral Divergence

| Aspect | More Traits source | UT implementation |
|---|---|---|
| Trigger | OnNewGame/OnCreatePlayer (one-shot) | OnNewGame (one-shot) |
| Aiming effect | +2 starting levels granted | XP completely disabled (no levels granted) |
| Reloading effect | None | XP completely disabled |
| Ongoing XP suppression | None | Yes — via `UTCore_XPHook` |
| Mechanism | `levelPerkByAmount(player, Perks.Aiming, 2)` | `UT_xpDisable_Aiming = true` / `UT_xpDisable_Reloading = true` in mod data |

The UT implementation is a **full redesign** of the concept: the source trait grants starting skill levels (mastery-flavoured), while UT blocks all ongoing XP on two skills (lockout-flavoured). The flavour text in UT ("you have already mastered firearms and no longer learn from using them") attempts to bridge both interpretations, but the mechanical implementation in UT matches neither the +2 Aiming bonus from the source nor includes a starting level grant of any kind.

## Description Integrity

- Display name: `"No XP: Shooting"` — functional and accurate; consistent with the no-XP series naming convention.
- Description: `"You have already mastered firearms and no longer learn from using them. Aiming and Reloading grant no XP."` — accurate for the UT implementation. Both blocked skills are named. The phrase "grant no XP" correctly describes a full disable (not a reduction). No inaccuracy relative to what the code does.
- Source description comparison: the source description is unknown (translation key value not read in this audit). However, the source mechanic (+2 Aiming levels) differs fundamentally from UT's mechanic (XP disable), so the UT description is written for its own implementation rather than inherited text.
- Missing or misleading details: none. The description does not claim starting level grants (which UT does not provide), and it does not understate or overstate the XP effect.

## Balance Review

- Upside: +3 points in character creation.
- Downside: Aiming XP and Reloading XP are permanently disabled. Once a player reaches their starting skill level in Aiming/Reloading (which they set at character creation), they can never improve through play.
- Uptime: permanent; both disables are written once at new game start and never removed.
- Peer comparison:
  - `UT_antigun` (−6 cost): −50% Aiming XP and −50% Reloading XP. A penalty trait; players pay no points and receive 6 points back.
  - `UT_noxptechnician` (+3 cost): same structure — disables Electricity and Mechanics XP.
  - `UT_noxpaxe` (+3 cost): disables Axe XP only.
  - `UT_noxpfirstaid` (+3 cost): disables Doctor XP only.
  - `UT_noxpmaintenance` (+3 cost): disables Maintenance XP only.
  - `UT_noxpsneaky` (+3 cost): disables Sneaking and Lightfoot XP.
  - `UT_noxpshooter` (+3 cost) blocks two skills (Aiming, Reloading) for the same cost as `UT_noxpaxe` (+3), which blocks one. `UT_noxptechnician` also blocks two for +3. Within the series, two-skill disables are priced the same as one-skill disables; this is internally consistent but raises a question of relative value: Aiming and Reloading are tightly coupled combat skills, making a combined lockout on both arguably harsher than the same lockout on Electricity/Mechanics.
- Mutual exclusion note: `UT_antigun` (−6 cost, −50% XP) is mutually exclusive with `UT_noxpshooter` (+3 cost, 0% XP on same skills). This prevents a double-dip on the same skill set and is correct. However, the five other no-XP series traits are **not** mutually exclusive with `UT_noxpshooter`, so a player could theoretically take `UT_noxpshooter` (+3) alongside any or all of `UT_noxptechnician`, `UT_noxpaxe`, `UT_noxpfirstaid`, `UT_noxpmaintenance`, `UT_noxpsneaky` for a combined +15 to +18 points while locking out six or more skills simultaneously.
- Cost verdict: the +3 point value is consistent with source and with the rest of the no-XP series. The lack of inter-series mutual exclusions is an open design question — not a balance defect by itself, but it enables unrestricted stacking.

## Regression Proof

- Registry test: yes — `test("UT_noxpshooter registered", ...)` at `run_tests.lua` line 87–89 asserts `UTTraitsRegistries.UT_noxpshooter == "UniversalTraits:UT_noxpshooter"`. This confirms the registry string is well-formed and present.
- Recognised-trait list: yes — `"UniversalTraits:UT_noxpshooter"` appears in the harness's known-trait array at `run_tests.lua` line 261 (UTMods repo index) / line 267 (UniversalTraits repo index), within the `-- Phase 2 — No-XP Series (6)` group.
- Trait file loaded in test harness: yes — `dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_noxpshooter.lua")` is present at `test/run_tests.lua` line 457 (UTMods) / 457 (UniversalTraits). The XPHook is loaded immediately before this block (`dofile(... "UTCore_XPHook.lua")` at line 456), so the hook is active when the trait file is loaded.
- Runtime integration test: yes — `test("noxpshooter blocks Aiming and Reloading XP through the XP hook", ...)` at `run_tests.lua` lines 953–959:
  1. Calls `fireNewGame("UniversalTraits:UT_noxpshooter")` — fires `OnNewGame` with the trait present, which writes `UT_xpDisable_Aiming = true` and `UT_xpDisable_Reloading = true` to player mod data.
  2. Fires `Events.AddXP:fire(player, "Aiming", 10)` — XPHook intercepts, calls `AddXP(perk, -10)`.
  3. Fires `Events.AddXP:fire(player, "Reloading", 10)` — same path.
  4. Asserts `xpWasCancelled(player, "Aiming", 10)` — scans XP log for a −10 entry on Aiming; must return true.
  5. Asserts `xpWasCancelled(player, "Reloading", 10)` — same check on Reloading.
- `xpWasCancelled` helper (`run_tests.lua` lines 435–440): iterates `player:getXp()._log`; returns true if any entry matches `{perk = perk, amount = -(amount or 10)}`. This verifies the hook fired and issued the exact cancellation call.
- What is proven:
  1. The registry string is correct.
  2. The trait ID is in the harness known-trait list.
  3. The `onNewGame` handler fires without error.
  4. `UTCore.disableXP("Aiming")` and `UTCore.disableXP("Reloading")` write the expected mod data keys.
  5. The `UTCore_XPHook` cancels Aiming and Reloading XP events completely (via −amount correction) when those keys are set.
- What is not proven:
  1. Behaviour on save-game load — `Events.OnNewGame` does not fire on load; if mod data is not persisted across saves, the disables would not be re-applied. No `Events.OnCreatePlayer` or `Events.OnGameStart` backup handler exists in the trait file.
  2. Interaction with `UT_antigun`'s XP multiplier path if both were somehow active — mutual exclusion in the script definition prevents this at character creation, but no test verifies the hook ordering for edge cases.

## Final Verdict

- Source origin: proven — `ToadTraits:noxpshooter` from More Traits confirmed. Definition (Cost = +3, six mutual exclusions), registry entry, and runtime implementation (OnNewGame `levelPerkByAmount` for +2 Aiming) traced across More Traits 42.13 and 42.15.
- UT implementation: deliberate redesign — the source mechanic (+2 Aiming starting levels, no Reloading effect, no XP suppression) is entirely replaced in UT. UT disables all ongoing XP for both Aiming and Reloading via the `UTCore_xpDisable` mod data path and the `UTCore_XPHook` cancellation mechanism. No starting level bonus is granted. The flavour framing ("already mastered firearms") is preserved from the source concept but the mechanical expression is inverted: source rewards with levels up front; UT punishes all future growth.
- Description: accurate — `"Aiming and Reloading grant no XP"` correctly and completely describes the UT implementation. No inaccuracy, no missing effects, no misleading language.
- Balance: internally consistent with the no-XP series (+3 for two-skill disable). The `UT_antigun` mutual exclusion is symmetric and correct. The absence of mutual exclusions with other no-XP series traits is a design choice that permits unconstrained stacking within the series.
- Regression proof: strong — the trait has a dedicated integration test (`run_tests.lua` lines 953–959) that fires the full `onNewGame` → `disableXP` → `AddXP` → `XPHook` chain and asserts both skill disables are active. This is the best-covered trait in the no-XP series.
- Open gaps:
  1. No save-game load path — `Events.OnNewGame` does not fire on load of an existing save. If mod data is cleared or a save is loaded from before the trait was applied, the `UT_xpDisable_*` keys may not be present. No re-application handler (`OnCreatePlayer`, `OnGameStart`) exists in the trait file.
  2. Source mutual exclusions not preserved — More Traits excluded all five sibling no-XP traits plus `antigun` from `noxpshooter`. UT excludes only `antigun`. Players may freely combine all six no-XP traits for +15–18 points in exchange for locking out most major skill trees.
  3. Source starting level grant not implemented — More Traits `noxpshooter` granted +2 Aiming at character creation to justify the "already mastered" framing. UT provides no such compensation. A player taking this trait starts with the same Aiming level as one without it, then cannot improve. This may be intentional but is not documented.
