# UT_ascetic

## Trait Summary

- UT trait id: UT_ascetic
- Source mod: MoreTraits (More Traits by Toad King)
- Source trait id: ToadTraits:ascetic (trait key: `ToadTraitsRegistries.ascetic`)
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (lines 67–76, 316–326)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI_EN.txt` (lines 139–140)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (lines 3780–4024)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42.13/media/lua/shared/MoreTraits - Dynamic.lua` (lines 598–606)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42.13/media/lua/shared/Translate/EN/Sandbox_EN.txt` (lines 10–11)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42.13/media/sandbox-options.txt` (lines 44–50)
- Source display name: "Ascetic"
- Source description: "You prefer to abstain from the unnecessary pleasures of the body and find spiritual fulfillment in simple things. You dislike cooked food. Pre-Packaged foods give no mood boost. Uncooked Meals are neutral. Very high chance to burn meals."
- Source cost: -4
- Source multiplayer: `DisabledInMultiplayer = false` (multiplayer allowed in the original)
- Source mutual exclusion: `ToadTraits:gourmand` only (one-sided mutual exclusion with gourmand)
- Source dynamic: the MoreTraits Dynamic submod removes `ToadTraits:ascetic` from the player when their Cooking skill reaches the configurable `AsceticDynamicSkill` threshold. At that point the trait disappears, and Gourmand can then be awarded.
- Source trigger path: `Events.OnPlayerUpdate.Add(FoodUpdate)` — fires every player update tick.
- Source behavior: `setFoodState` scans all Food items in the player's inventory. For items that are cookable and not yet cooked (stage 0), it modifies them in-place: cook time is multiplied by ×1.5, burn time is tightened, `unhappyChange` and `boredomChange` are set to 0, `goodHot` and `badCold` flags are cleared. Items are transitioned through two internal stages (iFoodStage 0→1→2). Once cooked (stage 2), additional penalties are applied to hunger, fat, and endurance values. The state machine mutually resets items to Normal if the player no longer holds the trait. There is no mood or stress penalty applied directly at eating time — the effect is entirely through item-level stat manipulation before the eat event.

## Current UT Evidence

### Structure

- Registered in registries.lua: assumed yes — the trait appears in the `run_tests.lua` registration list at line 277 under the Phase 2 Item/Consumption group, confirming it is present in the registry. (registries.lua not directly read; presence in the test harness list is sufficient confirmation.)
- Defined in UT_character_traits.txt: yes — lines 1589–1598
- Translation strings present: yes — `UI_UT_ascetic` ("Ascetic") and `UI_UT_asceticDesc` at lines 494–495 of `UI_EN.txt`
- Exclusions/grants declared in script definition:
  - `MutuallyExclusiveTraits = UniversalTraits:UT_gourmand;UniversalTraits:UT_mundane`
  - UT adds `UT_mundane` as a second mutual exclusion that does not exist in the source (source only excludes gourmand). `UT_mundane` also declares mutual exclusion with `UT_ascetic` (line 1374), making it bidirectional.
  - `UT_gourmand` also declares mutual exclusion with `UT_ascetic` (line 1586), making it bidirectional.
- DisabledInMultiplayer: `true` in UT vs. `false` in source — UT is more restrictive.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_ascetic.lua`

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_ascetic.lua` (all 35 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1589–1598)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 494–495)
  - `test/run_tests.lua` (line 277)
- Event registrations:
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — trait guard
  - `player:getModData()` — persistent per-player state storage
  - `player:getBodyDamage():getHealthFromFoodTimer()` — rising-edge food detection
  - `getGameTime():getWorldAgeHours()` — timestamp comparison
  - `player:getStats():add(CharacterStat.UNHAPPINESS, 10)` — mood penalty
  - `player:getStats():add(CharacterStat.STRESS, 5)` — stress penalty
- Runtime chain (plain language):
  1. Every player update tick: check if the player has `UT_ascetic`. If not, return immediately.
  2. Read the current `healthFromFoodTimer` from the player's body damage data.
  3. Compare to the stored previous timer value (`UT_ascetic_prevTimer` in mod data).
  4. If the timer has risen by more than 50 units since last tick (rising-edge detection: food was just eaten), check how many in-game hours have elapsed since the last recorded eat time (`UT_ascetic_lastAte`).
  5. If the gap is less than 5 in-game minutes (expressed as `5/60` hours), apply +10 Unhappiness and +5 Stress via `pcall`.
  6. Regardless of whether the penalty fired, update `UT_ascetic_lastAte` to the current world age in hours.
  7. Always update `UT_ascetic_prevTimer` to the current timer value.
- Actual behavior (exact values):
  - Eating within 5 in-game minutes of the previous meal triggers: +10 Unhappiness, +5 Stress (once per triggering eat event).
  - Eating more than 5 in-game minutes after the previous meal has no effect.
  - No item-level stat manipulation of any kind. No cook time, burn time, or food nutrition changes.
  - The `pcall` wrapper means a Java-side exception in `CharacterStat.add` will be silently swallowed without crashing the update loop.

## Description Integrity

- Display name check: "Ascetic" — matches source display name exactly.
- Description check: `UI_UT_asceticDesc` reads: "You subsist on the bare minimum. Eating within 5 minutes of your last meal triggers a mood penalty. Only one meal per 5-minute window is recommended."
- Description accuracy vs. UT implementation:
  - "Eating within 5 minutes of your last meal triggers a mood penalty" — accurate. The code checks for a sub-5-minute interval and applies +10 Unhappiness.
  - "Only one meal per 5-minute window is recommended" — accurate player-facing advice that correctly describes the trigger window.
  - Stress penalty (+5 Stress) is not mentioned in the description. The description says "mood penalty" (singular) but the code applies both Unhappiness and Stress. The Stress component is a hidden effect.
  - The description says "5 minutes" — the code uses `5/60` hours, which is 5 in-game minutes. This is accurate.
- Source divergence: the UT implementation is a complete mechanical redesign. The source trait (ToadTraits:ascetic) works by manipulating food item stats in the player's inventory — altering cook time, burn time, and cooked-food nutritional values. It has no direct at-eat mood or stress penalty. The UT version discards all item-level manipulation and instead applies a time-gap penalty when eating too frequently. The only shared elements are the display name, cost (−4), and the mutual exclusion with Gourmand.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside:
  - +10 Unhappiness and +5 Stress applied each time the player eats within 5 in-game minutes of the previous meal.
  - The penalty is conditional and entirely avoidable: the player must simply space meals at least 5 in-game minutes apart.
  - 5 in-game minutes is a very short real-time interval (approximately 12 seconds at default time scale of 1 in-game minute = 2.4 real seconds). At any non-trivial time acceleration, 5 in-game minutes passes almost instantly in real time.
  - The penalty fires at most once per eat event, and only when the player eats rapidly back-to-back — an uncommon occurrence in normal survival gameplay.
- Uptime: low — the vast majority of meals will be separated by far more than 5 in-game minutes. The penalty will rarely trigger during normal play.
- Peer comparison:
  - `UT_gourmand` (+4): mutual exclusion peer; provides food-related benefits at positive cost.
  - `UT_mundane` (−9): second mutual exclusion peer; much higher point refund, presumably stronger downside.
  - Source `ToadTraits:ascetic` (−4): the source mechanic is materially more punishing — it permanently degrades all food in the player's inventory for the entire run (higher burn chance, stripped mood bonuses, worse nutritional values on cooked food). The UT version applies only a conditional, easily-avoided per-eat penalty.
- Cost verdict: under-penalized relative to the stated cost. At −4 points, the penalty should be a meaningful persistent downside. The current implementation fires rarely and can be trivially avoided by any player who reads the description. The source's item-manipulation approach was meaningfully harder to bypass. The −4 cost is difficult to justify against this implementation; −1 or −2 would be more honest pricing unless the trigger window is widened or the penalty magnitude is increased significantly.

## Regression Proof

- Existing test: `UT_ascetic` appears in the Phase 2 Item/Consumption registration list at `run_tests.lua` line 277, alongside `UT_ironliver`, `UT_durability`, and `UT_gourmand`. This list is used by the harness to verify that all expected traits are registered and loadable without error.
- What it proves: the trait ID resolves in the registry and causes no load-time crash. The Lua file loads cleanly.
- Missing proof:
  1. No test for the rising-edge detection path — no test verifies that `healthFromFoodTimer` rising by >50 is correctly identified as a food-eaten event.
  2. No test for the 5-minute window logic — no test verifies that the `currentHours - lastAteHours < (5/60)` condition triggers correctly vs. does not trigger when the gap exceeds the window.
  3. No test for the penalty application — no test confirms that +10 Unhappiness and +5 Stress are applied when the window fires.
  4. No test for the guard path — no test confirms that a player without the trait exits without any mod data writes.
  5. No test for the `pcall` swallow path — if `CharacterStat.add` throws, there is no test or log confirming silent suppression does not mask a real bug.
- Minimum next test if needed: "ascetic: penalizes unhappiness and stress when eating within 5-minute window" — create a MockPlayer with the trait present, prime `UT_ascetic_prevTimer` in mod data, set `healthFromFoodTimer` to prevTimer+51, set `UT_ascetic_lastAte` to `currentHours - (3/60)` (3 in-game minutes ago), fire `Events.OnPlayerUpdate`, assert Unhappiness increased by 10 and Stress by 5. Mirror with a gap of `6/60` hours to confirm no penalty fires.

## Final Verdict

- Source origin: proven — `ToadTraits:ascetic` from MoreTraits (Toad King) is the confirmed source. Script definition, EN translation, Lua implementation, and Dynamic submod files all located and read.
- UT implementation: redesigned — the UT port does not replicate the source mechanic (inventory-level food stat manipulation, cook time and burn time changes, cooked-food nutritional penalties). Instead it implements a rising-edge eat detector that fires a fixed mood and stress penalty when the player eats within a 5-minute window. The display name, cost (−4), and Gourmand exclusion are preserved; everything else is new.
- Description: mostly accurate but incomplete — the description correctly describes the 5-minute trigger window and the mood penalty. It does not disclose the +5 Stress component. "Mood penalty" in the description implies only Unhappiness; the code also applies Stress. This is a minor but real omission.
- Balance: cost is not justified by implementation — at −4 points the mechanic is too easily avoided. The 5-minute window resolves in approximately 12 real-time seconds at default time scale, and normal survival play will almost never trigger back-to-back eating within that window. The source implementation was a durable, always-active penalty; the UT implementation is effectively a no-op for most sessions.
- Multiplayer flag: diverges from source — source allows multiplayer; UT disables it. This is consistent with the rest of the UT Item/Consumption series.
- Regression proof: minimal — only a registration-list check exists. The eat-detection and penalty-application paths are completely untested.
- Action needed:
  1. **Description fix (minor)**: add Stress to the description. Replace "triggers a mood penalty" with "triggers a mood and stress penalty (+10 Unhappiness, +5 Stress)" or equivalent plain language.
  2. **Balance review (significant)**: either reduce the cost to −1 or −2 to match the low actual impact, or strengthen the mechanic (e.g., widen the window, add a persistent food-quality debuff, or penalize on every meal rather than only rapid repeat meals) to justify −4.
  3. **Test gap**: add functional tests for the rising-edge detection, the 5-minute window branch, and the penalty application path.
- Open gaps:
  - The UT mutual exclusion adds `UT_mundane` (source did not exclude it). Confirm whether this is intentional design or accidental scope creep. If `UT_mundane` and `UT_ascetic` thematically overlap (both involve austere/minimal consumption behaviors), the exclusion is reasonable and should be documented as intentional.
  - The `pcall` wrapper on `CharacterStat.add` silently swallows all exceptions. If the Java API changes in a future PZ build and `CharacterStat.UNHAPPINESS` or `CharacterStat.STRESS` become invalid, the trait will silently stop working with no error output. Consider adding a logged fallback or removing the `pcall` if the API is stable.
  - `UT_ascetic_lastAte` is only written when the rising-edge fires. On a fresh save where the player has never eaten, `lastAteHours` will be nil and the 5-minute check will correctly skip the penalty. This nil-guard works correctly as written, but it is implicit — a brief comment in the code would improve clarity.
