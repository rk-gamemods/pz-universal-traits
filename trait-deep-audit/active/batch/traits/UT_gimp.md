# UT_gimp

## Trait Summary
- UT trait id: UT_gimp
- Source mod: MoreTraits (ToadTraits)
- Source trait id: ToadTraits:gimp ("Slowpoke")
- Current cost: -8
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/scripts/ToadTraits.txt` (trait definition, lines 284–293)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (trait definition, lines 284–293 — identical)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` (runtime implementation, lines 2442–2507, registered at line 4687 inside `OnPlayerUpdate`)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/Translate/EN/UI_EN.txt` (UI strings, lines 112–113)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/Translate/EN/Sandbox_EN.txt` (sandbox labels, lines 124–129)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42.13/media/lua/shared/MoreTraits - Dynamic.lua` (dynamic removal, line 269)
- Source registration:
  - `character_trait_definition ToadTraits:gimp { Cost = -6, MutuallyExclusiveTraits = ToadTraits:fast }`
  - UIName: "Slowpoke". UIDescription: "You've always been the last in line.<br>You move 15% more slowly."
- Source trigger path: `Events.OnPlayerUpdate.Add(OnPlayerUpdate)` (line 4850). `OnPlayerUpdate` calls `MT_FastGimpTraits(player)` (line 4687) on every player update tick.
- Source behavior (exact):
  - `MT_FastGimpTraits` (lines 2443–2507) fires every `OnPlayerUpdate`. Early exits if neither `fast` nor `gimp` is held, if the player is not moving, or if pathfinding with `timeMult > 1.1`.
  - When the player has `gimp` and is pathfinding, an additional obstacle check runs: if the current square is blocked or windowed toward the next square in the direction of travel, the function returns early to prevent the player getting stuck.
  - Movement modifier is selected by gait (values are sandbox-configurable, defaults used below):
    - Sprinting: `SandboxVars.MoreTraits.GimpSprint or -0.25` (i.e., −25% to the deferred movement vector)
    - Running: `SandboxVars.MoreTraits.GimpRunning or -0.5` (−50%)
    - Walking: `SandboxVars.MoreTraits.GimpWalking or -0.75` (−75%)
  - The modifier is applied via `player:getDeferredMovement(FastGimpVector)` → `FastGimpVector:setX(x * modifier)` / `setY(y * modifier)` → `player:Move(FastGimpVector)`. In multiplayer, the adjusted vector is sent via `sendClientCommand` to the `FastGimp` handler on the server (`MoreTraitsCC.lua` lines 253–258).
  - Dynamic addon (`MoreTraits - Dynamic`): if sandbox option `SlowpokeDynamic` is enabled, the trait is automatically removed when the sum of Sprinting + Lightfoot + Nimble + Sneak perk levels reaches the `SlowpokeDynamicSkill` threshold (line 269).
  - Source cost: −6. No XPBoosts. Mutually exclusive with `ToadTraits:fast` only.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_gimp = CharacterTrait.register("UniversalTraits:UT_gimp")` (line 122). Confirmed in both `media/registries.lua` and `release/UniversalTraits/42/media/registries.lua`.
- Defined in UT_character_traits.txt: yes — lines 919–927
  ```
  character_trait_definition UniversalTraits:UT_gimp
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_gimp,
      Cost = -8,
      UIName = UI_UT_gimp,
      UIDescription = UI_UT_gimpDesc,
  }
  ```
- Translation strings present: yes — `UI_UT_gimp = "Gimp"` and `UI_UT_gimpDesc = "An old injury slows you down. -50% movement speed."` (`UI_EN.txt` lines 269–270)
- Exclusions/grants: none — no `MutuallyExclusiveTraits` field is present in the UT definition. The source mutually excluded `ToadTraits:fast`; the UT definition has no exclusion against `UniversalTraits:UT_fast` or any other trait. `UT_fast`'s own definition (`UT_character_traits.txt` line 1127) excludes `UT_noodlelegs` and `UT_lurcher` but not `UT_gimp`. No XPBoosts.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_gimp.lua` (13 lines)

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_gimp.lua`
  - `media/scripts/UT_character_traits.txt` (lines 919–927)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 269–270)
  - `media/registries.lua` (line 122)
  - `test/run_tests.lua` (line 230)
  - `test/UTTestMocks.lua` (line 205)
- Event registrations: `Events.OnCreatePlayer.Add(onCreatePlayer)` (line 12)
- UTCore hooks used: `UTCore.hasTrait`, `UTCore.applySpeedModifier`
- Runtime chain (plain language):
  1. `Events.OnCreatePlayer` fires when a player object is created (new game or character load).
  2. `onCreatePlayer(playerIndex, player)` runs. If the player does not have `UniversalTraits:UT_gimp`, the function returns immediately.
  3. If the player has the trait, `UTCore.applySpeedModifier(player, -0.5)` is called once.
  4. Per the test mock (`UTTestMocks.lua` line 205): `UTCore.applySpeedModifier = function(player, v) player:getModData()["UT_speedMod"] = v end`. So the call writes `UT_speedMod = -0.5` into the player's mod data. This is a one-shot write on player creation only.
  5. No recurring event (`OnPlayerUpdate`, `OnEveryOneMinute`, etc.) is registered. The trait does not continuously apply movement reduction — it records a flag value of −0.5 once and relies on a downstream consuming system to read `UT_speedMod` and apply the movement penalty each frame.
- Header comment on line 3 states: `-- OnCreatePlayer: applySpeedModifier(-0.5). SpeedHook applies flat movement reduction.` This confirms the design intent that a separate "SpeedHook" system is expected to read `UT_speedMod` and enforce the penalty, but no such hook is visible within the `UT_gimp.lua` file itself. No `SpeedHook` file or function was found in the UniversalTraits repo during this audit.

## Description Integrity
- Display name check: "Gimp" — diverges from source name "Slowpoke". The UT name uses the trait ID as its display name rather than the source mod's chosen name. Not a functional issue, but a naming departure worth noting.
- Description check: "An old injury slows you down. -50% movement speed."
  - The source description states −15% movement speed (all gait types averaged by default sandbox: sprint −25%, run −50%, walk −75%; the source UI description said simply "15% more slowly" which is a rough single-figure summary). The UT description states a flat −50%, which matches the `UT_speedMod = -0.5` value written to mod data but is not a faithful representation of what the source actually implemented.
  - The UT description implies a flat, unconditional −50% movement speed penalty at all times. The source applied gait-dependent speed penalties via movement vector scaling on every update, not a flat stat modifier. The UT implementation records a flag value of −0.5 once at player creation; whether any actual movement reduction occurs depends entirely on an external consuming system reading `UT_speedMod` each frame.
  - The description is accurate only if the SpeedHook consuming system is present, loaded, and applies the value correctly. If the consuming system is absent, the trait silently does nothing at runtime despite the description promising a −50% movement penalty.
- Missing or misleading details:
  - Description does not disclose that the penalty is applied through a passive flag read by an external system rather than directly enforced by this trait's own code.
  - Description states a single flat penalty (−50%); the source applied gait-dependent penalties (sprint −25%, run −50%, walk −75%) with sandbox-configurable overrides. The UT penalty is both architecturally different and quantitatively different from the source.
  - No mention that the trait is disabled in multiplayer (`DisabledInMultiplayer = true`). Source had no such restriction.

## Balance Review
- Downside: −50% movement speed (flat, flag-based) per description; actual penalty depends on consuming system
- Upside: none stated — this is a pure negative trait
- Uptime: intended as always-on (100%), but actual uptime depends on whether the SpeedHook consuming system is present and polling each tick
- Cost: −8 (UT) vs. −6 (source). Source also had no multiplayer restriction.
- Peer comparison:
  - Source cost was −6 with a gait-dependent penalty ranging from −25% (sprint) to −75% (walk), with sandbox overrides and a dynamic removal path when agility skills reach a threshold. UT gives −8 for a flag-based flat −50% with no sandbox overrides and no dynamic removal.
  - `UT_noodlelegs` (cost −4): writes `UT_speedMod = -0.2` directly, no consuming system dependency noted in its file. `UT_lurcher` (cost not checked here): writes `UT_speedMod = -0.15`. `UT_sorelegs` (cost not checked): writes `UT_speedMod = -0.2` plus −2 carry weight.
  - `UT_gimp` at −8 points for a −50% speed modifier is the steepest speed penalty among peers reviewed. The −8 refund is plausible given the magnitude, but depends entirely on the SpeedHook system being present.
  - The source dynamic removal mechanic (trait removed automatically when agility skill sum meets threshold) is entirely absent in UT. This removes a gameplay progression path that the source provided.
- Stack or exclusion notes:
  - No `MutuallyExclusiveTraits` in the UT definition. A player could take both `UT_gimp` and `UT_fast` simultaneously, since neither excludes the other. The source mutually excluded `ToadTraits:gimp` and `ToadTraits:fast`. `UT_fast` excludes `UT_noodlelegs` and `UT_lurcher` but not `UT_gimp`. This is a functional regression: the intended opposition between "fast" and "gimp" (slow) is unenforced in UT.
  - No stated interaction with other speed-affecting traits (`UT_noodlelegs`, `UT_lurcher`, `UT_sorelegs`, `UT_pacer`). If multiple traits all write to the same `UT_speedMod` key, the last writer wins — values do not stack. This is an implicit architectural hazard across all `UT_speedMod` writers.
- Cost verdict: cost increase from −6 (source) to −8 (UT) is plausible given the stated −50% magnitude (greater than source −15% summary), but the actual penalty is entirely flag-dependent and the missing exclusion against `UT_fast` undermines the balance premise.

## Regression Proof
- Existing tests:
  - `run_tests.lua` line 230: `"UniversalTraits:UT_gimp"` appears in the `expected_ids` list used by the all-traits registration count test. Proves the trait ID is enumerable and registered.
- What the tests prove: The trait ID exists in the registry. Nothing more.
- Missing proof:
  - No test verifies that `onCreatePlayer` sets `UT_speedMod = -0.5` on a player with the trait.
  - No test verifies that a player without the trait does not receive `UT_speedMod`.
  - No test verifies that `UT_gimp` and `UT_fast` cannot be taken simultaneously (no exclusion is defined, so this would currently pass without error).
  - No test verifies behavior on save-reload (flag persistence in mod data across sessions).
  - No test verifies that the SpeedHook consuming system reads `UT_speedMod` and applies the movement penalty.
  - No test named `"UT_gimp registered"` or similar exists; the trait is only validated indirectly through the all-traits list count.
- Minimum next tests needed:
  1. `test("UT_gimp sets UT_speedMod = -0.5", function() local p = fireCreatePlayer("UniversalTraits:UT_gimp") assert_equal(p:getModData()["UT_speedMod"], -0.5) end)`
  2. `test("UT_gimp does not set UT_speedMod when not held", function() local p = fireCreatePlayer("UniversalTraits:UT_OTHER") assert_nil(p:getModData()["UT_speedMod"]) end)`

## Final Verdict
- Source origin: proven — `ToadTraits:gimp` ("Slowpoke") confirmed in `ToadTraits.txt` (42.13 and 42.15), runtime implementation in `MT_FastGimpTraits` (line 2443), event registration at line 4687/4850. Source cost −6, gait-dependent speed penalties (sprint −25%, run −50%, walk −75%, all sandbox-configurable), mutually exclusive with `ToadTraits:fast`, dynamic removal via MoreTraits-Dynamic addon when agility skill sum meets threshold.
- UT implementation: significantly simplified and architecturally different — the source applied gait-dependent movement vector scaling every `OnPlayerUpdate` tick via direct `player:Move()` calls; the UT version replaces this with a single mod-data flag (`UT_speedMod = -0.5`) written once at `OnCreatePlayer`, delegating all active penalty enforcement to an unverified SpeedHook consuming system. No SpeedHook file or function was located in the UniversalTraits repo during this audit.
- Description: partially misleading — the stated "−50% movement speed" corresponds to the written mod-data value but overstates what the UT code itself guarantees (it only writes a flag). The source description said "15% more slowly"; UT states "−50%", a significant magnitude divergence. The description does not disclose the consuming-system dependency.
- Balance: three issues — (1) cost raised from −6 to −8 without documented rationale; (2) `MutuallyExclusiveTraits` against `UT_fast` is absent, allowing the conceptual opposites to coexist; (3) dynamic removal mechanic (agility skill threshold) from source is absent.
- Regression proof: minimal — only indirect via all-traits list; no behavioral test exists.
- Action needed: exclusion fix, test fix, confirm SpeedHook consuming system, doc clarification
- Open gaps:
  1. **Missing mutual exclusion**: `UT_gimp` has no `MutuallyExclusiveTraits` field in `UT_character_traits.txt`. `UT_fast` does not exclude `UT_gimp`. A player can hold both simultaneously. Source excluded `ToadTraits:gimp` ↔ `ToadTraits:fast`. Fix: add `MutuallyExclusiveTraits = UniversalTraits:UT_fast` to the `UT_gimp` definition and add `UniversalTraits:UT_gimp` to the `UT_fast` exclusion list.
  2. **SpeedHook consuming system unconfirmed**: the header comment references "SpeedHook" applying the flat movement reduction, but no such hook was found in the UniversalTraits repo. If absent, `UT_speedMod = -0.5` is written and never read — the trait silently does nothing at runtime despite the description promising a −50% penalty. Locate or create the consuming system before shipping.
  3. **`UT_speedMod` last-write-wins collision**: multiple traits write to the same `UT_speedMod` key (`UT_gimp` −0.5, `UT_noodlelegs` −0.2, `UT_lurcher` −0.15, `UT_sorelegs` −0.2, `UT_fast` +0.3, `UT_pacer` +0.15). The last `OnCreatePlayer` handler to execute wins; values do not accumulate. If a player somehow holds two of these (e.g., if exclusions are missing), only one speed modifier takes effect. This is a systemic issue, but the missing `UT_gimp` ↔ `UT_fast` exclusion makes it directly exploitable here.
  4. **No behavioral test**: no test verifies `onCreatePlayer` writes `UT_speedMod = -0.5`. Add minimum tests described above.
  5. **`DisabledInMultiplayer = true`**: source had no multiplayer restriction. This is a deliberate UT decision (likely because the source's MP path used `sendClientCommand` / server-side `Move()` which UT does not replicate), but it should be confirmed intentional and documented.
  6. **Dynamic removal absent**: the source's MoreTraits-Dynamic addon removed `gimp` automatically when agility skill sum (Sprinting + Lightfoot + Nimble + Sneak) reached a sandbox-configurable threshold. UT has no equivalent progression path. If UT intends to be a permanent-trait mod, this is acceptable, but it should be a conscious decision.
  7. **Cost increase undocumented**: source −6 → UT −8. No rationale recorded. Confirm intentional given the magnitude difference (source UI said "15% slower"; UT says "−50%").
  8. **Display name divergence**: source name was "Slowpoke"; UT uses "Gimp". Not a functional issue, but the UT name matches the internal trait ID rather than the player-facing source name. Confirm intentional.
