# UT_leadfoot

## Trait Summary
- UT trait id: UT_leadfoot
- Source mod: More Traits (ToadTraits)
- Source trait id: ToadTraits:leadfoot
- Current cost: 2
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (lines 447–455)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (lines 4279–4304, `LeadFoot` function; line 5384, call site inside `EveryOneMinute`)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (lines 176–177)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/registries.lua` (line 74)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42.13/media/lua/shared/MoreTraits - Dynamic.lua` (lines 1–5, 51–106, 923–944 — dynamic earn-by-stomping path)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42.13/media/sandbox-options.txt` (lines 372–387)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42.13/media/lua/shared/Translate/EN/Sandbox_EN.txt` (lines 64–66)
- Source script definition: `ToadTraits:leadfoot`, `Cost = 2`, `DisabledInMultiplayer = false`, no mutual exclusions.
- Source description: "You've always had a heavy step and now it's time to put your foot down - on some zombies. Your stomps are considerably more powerful."
- Source trigger path: `EveryOneMinute` event → `LeadFoot(player)` called once per in-game minute.
- Source behavior:
  - Checks `player:hasTrait(ToadTraitsRegistries.leadfoot)`.
  - Gets the currently equipped footwear via `player:getClothingItem_Feet()`.
  - On first encounter with the shoes (moddata key `origStomp` is nil): snapshots the base stomp power into `itemdata.origStomp` and sets `itemdata.stompState = "Normal"`.
  - If `stompState ~= "LeadFoot"`: calls `shoes:setStompPower((itemdata.origStomp * 2) + 1)` and marks `stompState = "LeadFoot"`.
  - The transformation is idempotent — it only fires once per pair of shoes (the state flag prevents repeated calls from re-doubling the value).
  - No shoe-swap recovery: if the player changes footwear, the new shoes are treated as fresh (new nil check) and also receive the buff; the old shoes retain the modified stomp value permanently in their moddata.
- Source dynamic variant: `MoreTraits - Dynamic` adds an earn-the-trait path (`MTDLeadFoot` / `MTDLeadFootToggle`). When `SandboxVars.MoreTraitsDynamic.LeadFootDynamic` is true and the player does NOT already have `ToadTraits:leadfoot`, killing zombies via stomp (barehand weapon, target prone, player within 1 tile) increments `MTD.LeadFootCount`; when it reaches `LeadFootDynamicKill` (default 200), the trait is granted. This dynamic path is source-side only and not ported to UT.
- Source vehicle speed claim: none. The source trait has no vehicle speed mechanic. The stomp power buff is the only implemented effect.

## Current UT Evidence
### Structure
- Registered in registries.lua: unknown (no registries.lua was found for UT itself; registration is via the script definition and Lua filename convention)
- Defined in UT_character_traits.txt: yes — lines 1525–1533; `Cost = 2`, `DisabledInMultiplayer = true`, no `MutuallyExclusiveTraits` block
- Translation strings present: yes — `UI_UT_leadfoot = "Lead Foot"` and `UI_UT_leadfootDesc = "You always pushed vehicles past their limits. +20% vehicle top speed while driving."` (lines 473–474 of `Translate/EN/UI_EN.txt`)
- Exclusions/grants correct: N/A — source had none; UT has none
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_leadfoot.lua`

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_leadfoot.lua`
  - `test/run_tests.lua` (line 273 — trait appears in the Phase 2 Vehicle registration list; no dedicated test block found)
- Event registrations: `Events.EveryOneMinute.Add(onEveryOneMinute)` — registered unconditionally at file load time (not gated on player creation or trait presence at registration time; the trait check occurs inside the handler body).
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` inside the handler.
- Runtime chain (plain language):
  1. At file load, `onEveryOneMinute` is added to the `EveryOneMinute` event.
  2. Each in-game minute: `getPlayer()` is called; returns early if nil.
  3. `UTCore.hasTrait(player, TRAIT_ID)` is checked; returns early if trait absent.
  4. `player:getClothingItem_Feet()` is called; returns early if no shoes equipped.
  5. `shoes:getModData()` is called; returns early if nil.
  6. If `itemdata.UT_origStomp == nil`: snapshots current stomp power into `UT_origStomp` and sets `UT_stompState = "Normal"`.
  7. If `UT_stompState ~= "LeadFoot"`: applies `shoes:setStompPower((UT_origStomp * 2) + 1)` and sets `UT_stompState = "LeadFoot"`.
- Actual behavior (exact values): stomp power is set to `(baseStomp * 2) + 1`. For a shoe with base stomp 1.0 (typical default), the resulting stomp power is 3.0. The buff fires once per equipped shoe pair and is permanent in moddata. No shoe-swap cleanup. No unequip handler. No removal of the buff when the trait is lost mid-session (the event is always registered; trait check is inside the body, so removal only prevents future applications, not reverting already-buffed shoes).
- Divergences from source:
  - Moddata keys renamed: source uses `origStomp` / `stompState`; UT uses `UT_origStomp` / `UT_stompState` (appropriate namespace isolation).
  - Logic is otherwise a direct copy of the source `LeadFoot` function.
  - `DisabledInMultiplayer = true` in UT vs. `false` in source — UT explicitly disables multiplayer.

## Description Integrity
- Display name check: "Lead Foot" — matches source name exactly.
- Description check: "You always pushed vehicles past their limits. +20% vehicle top speed while driving." — this description is entirely wrong and describes a mechanic that does not exist anywhere in the UT Lua file.
  - The UT Lua file contains zero references to vehicles, vehicle speed, or any vehicle-related API.
  - The actual implemented behavior is: stomp power on equipped footwear is set to `(base * 2) + 1` once per pair of shoes, applied every in-game minute until the state flag is set.
  - The source description correctly described stomp enhancement; the UT description discards this and invents a vehicle speed bonus that has no code backing it.
- Missing or misleading details:
  1. "+20% vehicle top speed while driving" is not implemented — there is no vehicle speed hook anywhere in `UT_leadfoot.lua`.
  2. The actual stomp power buff (`(base * 2) + 1`) is not mentioned.
  3. The player-facing description gives no indication that the effect requires footwear to be equipped.
  4. The description does not warn that swapping shoes mid-session will also buff the new pair (no cleanup on swap or trait removal).

## Balance Review
- Upside: Stomp power is set to `(base * 2) + 1`. Assuming base stomp 1.0, the result is 3.0 — a 3× multiplier on stomp effectiveness. This meaningfully improves stomp finisher reliability against prone zombies.
- Downside: Requires footwear to be equipped. Buff is limited to the stomp action; all other combat parameters are unaffected. No additional active gameplay requirement.
- Uptime: 100% whenever footwear is equipped (the buff is permanent per shoe pair after the first eligible minute tick). No endurance cost, no cooldown.
- Peer comparison: Cost 2 points. The source `ToadTraits:leadfoot` was also 2 points and `DisabledInMultiplayer = false`. At 2 points, a permanent flat stomp buff is reasonable — stomping is already situational (requires prone zombies and kicking input). The buff enhances a niche action rather than a primary combat loop.
- Stack or exclusion notes: No mutual exclusions. Can coexist with any other trait. Stacks passively with armor/shoe item stats that also affect stomp.
- Cost verdict: justified (2-point cost for a permanent stomp-power buff on a niche mechanic is proportionate; however, the description mismatch means players purchasing this trait believe they are buying a vehicle speed trait, which is a serious mislabeling issue)

## Regression Proof
- Existing test: `UT_leadfoot` appears in the trait registration list in `test/run_tests.lua` at line 273 (inside the Phase 2 Vehicle group), confirming it is recognized by the test harness as a valid trait ID. No dedicated behavior tests for `UT_leadfoot` were found anywhere in the test file.
- What it proves: The trait ID is present and parseable; the registration list check verifies the string is not misspelled relative to the script definition.
- Missing proof:
  1. No test verifies that `onEveryOneMinute` applies the stomp buff when the trait is present.
  2. No test verifies that the handler returns early when the trait is absent.
  3. No test verifies that the idempotent state flag (`UT_stompState == "LeadFoot"`) prevents double-application.
  4. No test verifies the early-return path when no footwear is equipped.
  5. No test verifies behavior when `getModData()` returns nil.
  6. No test verifies that already-buffed shoes retain their buff after trait removal (i.e., no revert on loss).
- Minimum next tests needed:
  - `leadfoot: stomp power is doubled+1 after one minute tick when trait present and shoes equipped` — mock `getClothingItem_Feet()` with a shoe stub; assert `setStompPower` receives `(origStomp * 2) + 1`.
  - `leadfoot: buff not applied a second time when stompState is already LeadFoot` — run handler twice; assert `setStompPower` called exactly once.
  - `leadfoot: returns early when trait absent` — assert `setStompPower` never called.
  - `leadfoot: returns early when no footwear equipped` — assert `setStompPower` never called.

## Final Verdict
- Source origin: proven (ToadTraits:leadfoot from More Traits mod, cost 2, same display name; stomp-buff mechanic faithfully ported)
- UT implementation: faithful port with namespace-isolated moddata keys; `DisabledInMultiplayer` changed to `true`; dynamic earn-path not ported (expected for a static-trait mod)
- Description: wrong (claims "+20% vehicle top speed while driving" — this mechanic does not exist in the Lua; actual behavior is stomp power buff on equipped footwear)
- Balance: justified (2-point cost for a permanent stomp buff is proportionate; the niche nature of stomping limits its power ceiling)
- Regression proof: absent (trait ID is in the registration list only; no behavior tests exist)
- Action needed: doc fix, test fix
- Open gaps:
  - Description must be rewritten to reflect actual behavior: stomp power on equipped footwear is set to `(base * 2) + 1`; requires footwear; buff is permanent per shoe pair once applied.
  - The "+20% vehicle top speed" claim has no code backing and must be removed entirely.
  - A full behavior test suite (buff application, idempotency, early-return paths) is missing.
  - No unequip or trait-removal cleanup exists — buffed shoes remain buffed even if the trait is removed mid-session. Whether this is intentional should be documented or addressed.
  - The shoe-swap behavior (new shoes always get buffed while trait is active) is not documented anywhere and may surprise players who swap footwear frequently.
