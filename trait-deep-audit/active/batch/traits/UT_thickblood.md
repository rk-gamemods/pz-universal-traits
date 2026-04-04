# UT_thickblood
## Trait Summary
- UT trait id: UT_thickblood
- Source mod: More Traits (ToadTraits / MoreTraits by Toad)
- Source trait id: ToadTraits:thickblood
- Current cost: 4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (trait definition)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/client/MoreTraits.lua` (old B41 implementation)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (B42 implementation)
  - `research/installed-mods/MoreTraits/mods/More Traits/media/lua/shared/Translate/EN/UI_EN.txt` (EN strings)
- Source trigger path: `Events.OnPlayerUpdate` (throttled) → `checkBloodTraits(player)` called each update tick; function checks `player:hasTrait(ToadTraitsRegistries.thickblood)` and iterates bleeding body parts.
- Source behavior: For each actively bleeding, non-stemmed body part: add `0.15` health per tick (B42 version). Neck and head parts receive `0.30` per tick (double). No decay-rate manipulation — source applies direct health restoration to offset blood loss. Old B41 version used `AddHealth(0.002)` per tick with the same neck doubling. Source cost is 4, mutually exclusive with `ToadTraits:anemic` (-4 cost).

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_thickblood = CharacterTrait.register("UniversalTraits:UT_thickblood")` at line 176
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_thickblood`, Cost = 4
- Translation strings present: yes — `UI_UT_thickblood = "Thick Blooded"` and `UI_UT_thickbloodDesc` present in UI_EN.txt
- Exclusions/grants correct: yes — `MutuallyExclusiveTraits = UniversalTraits:UT_heavilybleedingwounds` in UT script; `UT_heavilybleedingwounds` also lists `UT_thickblood` as mutual exclusion; `UT_weaklybleedingwounds` does not exclude `UT_thickblood` (consistent with source, which only excluded anemic)
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_thickblood.lua`

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_thickblood.lua`
  - `UniversalTraits/media/registries.lua`
  - `UniversalTraits/media/scripts/UT_character_traits.txt`
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `UniversalTraits/test/run_tests.lua`
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.applyBleedDecayMult(player, 1.5, false)`, `UTCore.applyBleedDrainMult(player, 0.5)`
- Runtime chain (plain language):
  1. On new game start, `onNewGame` fires.
  2. `UTCore.hasTrait` confirms the player has `UniversalTraits:UT_thickblood`.
  3. `UTCore.applyBleedDecayMult(player, 1.5, false)` writes `UT_bleedDecayMult = 1.5` and `UT_bleedDecayBandagedOnly = false` to player moddata.
  4. `UTCore.applyBleedDrainMult(player, 0.5)` writes `UT_bleedDrainMult = 0.5` to player moddata.
  5. `UTCore_BleedDecayHook` (registered on `Events.OnPlayerUpdate`, every tick) reads `UT_bleedDecayMult` and multiplies the native bleed-time decay rate on all body parts by 1.5×, regardless of bandage state (`bandagedOnly = false`).
  6. `UTCore_BleedDrainHook` (registered on `Events.OnPlayerUpdate`, throttled every 30 ticks) reads `UT_bleedDrainMult = 0.5` and applies a health offset each cycle to scale effective bleed death rate to 50% of normal.
- Actual behavior (exact values):
  - Bleed decay multiplier: 1.5× (wounds close 1.5× faster than normal, on all parts, bandaged or not)
  - Bleed drain multiplier: 0.5× (bleed death rate reduced to 50% of normal)
  - Stack note (from Lua comment): stacks additively with `UT_staunch` while bandaged — combined decay = 1.5 (thickblood) + 2.0 extra (staunch) = 4.5× total
  - No neck/head doubling in UT implementation (divergence from source, which doubled the effect on neck/head)

## Description Integrity
- Display name check: "Thick Blooded" — matches source name exactly; matches intent.
- Description check: `UI_UT_thickbloodDesc = "Your blood clots unusually fast. Bleed rate is reduced to 50% of normal — wounds stop bleeding twice as quickly."` — partially accurate. The 50% drain reduction is correct. However, the description says "wounds stop bleeding twice as quickly" as if there is only one effect (drain), when the implementation applies two distinct effects: 1.5× faster bleed-time decay (clot rate) and 0.5× bleed drain reduction (death rate). The clotting-speed improvement is 1.5×, not 2×; the 2× figure in the description conflates the two effects or misstates the clot speed.
- Missing or misleading details: The description does not mention the bleed decay multiplier (1.5×) separately from the drain reduction. Saying "twice as quickly" for wound closure is incorrect — the clot multiplier is 1.5×, not 2×. The drain reduction is 2× improvement (0.5× rate), but wound closure and bleed death are different mechanics. The description collapses both into one inaccurate claim.

## Balance Review
- Upside: Wounds clot 1.5× faster (all parts, all states) AND bleed death rate halved (0.5× drain). Both effects are always-on from game start. Stacks with UT_staunch for 4.5× clot rate while bandaged.
- Downside: None (pure positive trait).
- Uptime: 100% — moddata is written at OnNewGame and persists; both UTCore hooks run continuously.
- Peer comparison: `UT_weaklybleedingwounds` costs 3 for only a bleed decay improvement (no drain reduction). `UT_staunch` (unknown cost from this audit) provides a bandaged-only bleed decay boost. At cost 4, `UT_thickblood` provides two always-on effects covering both bleed mechanics, which is strong relative to single-effect peers at similar cost.
- Stack or exclusion notes: Mutually exclusive with `UT_heavilybleedingwounds` (-4). Compatible with `UT_weaklybleedingwounds` and `UT_staunch` — stacks with `UT_staunch` decay bonus to reach 4.5× while bandaged.
- Cost verdict: questionable — the dual always-on effect (1.5× clot + 0.5× drain) for 4 points is strong, especially when `UT_weaklybleedingwounds` costs 3 for a single weaker bleed effect. The stacking ceiling with `UT_staunch` at 4.5× further amplifies value. Cost may be one point low.

## Regression Proof
- Existing test: yes — in `run_tests.lua` lines 518-525: `"UT_thickblood sets UT_bleedDecayMult > 1.0 and UT_bleedDrainMult < 1.0"` — fires `OnNewGame` with the trait and asserts both moddata keys are numeric and on the correct side of 1.0.
- What it proves: The trait's OnNewGame handler writes both multipliers in the correct direction (decay > 1.0, drain < 1.0). Proves the moddata wiring is not broken.
- Missing proof: The test does not assert exact values (1.5 and 0.5). It would not catch a regression where the values are set to 1.01 and 0.99 (directionally correct but functionally negligible). It also does not test the UTCore hook behavior — that the decay/drain hooks actually apply the multipliers during a simulated tick.
- Minimum next test if needed: Add exact-value assertions — `assert_eq(decay, 1.5, ...)` and `assert_eq(drain, 0.5, ...)` — to lock the specific multipliers against accidental change.

## Final Verdict
- Source origin: proven — trait originates from More Traits (ToadTraits:thickblood), cost 4, mutually exclusive with anemic. Name and cost are preserved exactly.
- UT implementation: simplified — source applied direct per-tick `AddHealth` to bleeding parts (with neck/head doubling). UT rewrites this as persistent moddata multipliers consumed by UTCore's bleed hooks, eliminating per-tick direct health additions and the neck/head doubling. The replacement model is architecturally cleaner but mechanically diverges: no location-specific amplification, and the two-axis split (clot rate vs. drain rate) is a UT design choice not present in source.
- Description: incomplete — says "twice as quickly" for wound closure, but the clot multiplier is 1.5×, not 2×. The 2× figure correctly describes the drain improvement (0.5× rate = 2× improvement) but is applied to the wrong mechanic in the description. The dual-effect nature is not surfaced at all.
- Balance: questionable — dual always-on effects for 4 points; single-effect peer (UT_weaklybleedingwounds) costs 3.
- Regression proof: partially protected — direction of both multipliers is tested; exact values and hook behavior are not.
- Action needed: doc fix, test fix
- Open gaps:
  - Description conflates clot-rate and drain-rate improvements; "twice as quickly" is inaccurate for the 1.5× clot effect. Needs rewrite to state both effects with correct numbers.
  - Test asserts direction only; exact values (1.5 and 0.5) should be pinned with `assert_eq`.
  - No neck/head amplification in UT vs. source — this is a documented simplification but is not noted anywhere in the trait files or description.
  - Balance flag: consider whether cost 4 is appropriate given dual always-on effects vs. single-effect peers.
