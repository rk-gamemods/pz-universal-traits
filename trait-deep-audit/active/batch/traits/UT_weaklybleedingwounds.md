# UT_weaklybleedingwounds

## Trait Summary

- UT trait id: UT_weaklybleedingwounds
- Source mod: MoreSimpleTraits (both `MoreSimpleTraits` and `MoreSimpleTraitsVanilla` variants)
- Source trait id: `WeaklyBleedingWounds` (registered via `TraitFactory.addTrait`)
- Current cost: 3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` (registration, cost, mutual exclusion)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/NPCs/MSTVanillaMainCreationMethods.lua` (registration, cost, mutual exclusion — Vanilla variant, identical)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTMainFile.lua` (runtime implementation)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/client/MSTMainFile.lua` (runtime implementation — Vanilla variant, identical)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt` (translation strings)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraitsVanilla/media/lua/shared/Translate/EN/UI_EN.txt` (translation strings — Vanilla variant, identical)
- Source display name: `UI_trait_wbwounds` = "Thick Blood"
- Source description: `UI_trait_wbwoundsdesc` = "Wounds bleed less. (-50% Bleeding damage)."
- Source cost: 3 points. Mutually exclusive with `HeavilyBleedingWounds`.
- Source trigger path: `Events.OnPlayerUpdate` → `wbwounds()` fires on every client player-update tick. Checks `player:HasTrait("WeaklyBleedingWounds")`. If the player has any bleeding body parts, iterates all body parts via `getBodyParts():get(i)`, checks `b:bleeding()` and `b:IsBleedingStemmed() == false`, and calls `b:AddHealth(0.0014)` on each qualifying part. Neck parts receive `damage * 6 = 0.0084` added health per tick as a special-case multiplier. The source implementation uses a frame-level polling loop that compensates for bleeding by continuously restoring health — it is not a bleed rate multiplier.
- Source behavior: On every player-update tick while the player is actively bleeding (unstemmed), the source adds 0.0014 health per affected body part (0.0084 for the neck), effectively counteracting the ongoing health drain from bleeding. This is a health-credit approach, not a stat modification. The source description claims "-50% Bleeding damage" which is a rough approximation of the net effect, not an exact match to the per-tick health credit implementation. The source name ("Thick Blood") differs from the UT display name ("Weakly Bleeding Wounds").

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — `UTTraitsRegistries.UT_weaklybleedingwounds = CharacterTrait.register("UniversalTraits:UT_weaklybleedingwounds")` at line 178 of `media/registries.lua`
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_weaklybleedingwounds` at line 1303, `Cost = 3`
- Translation strings present: yes — `UI_UT_weaklybleedingwounds` and `UI_UT_weaklybleedingwoundsDesc` in `UI_EN.txt` at lines 392–393
- Exclusions/grants correct: partially — the script definition at line 1311 excludes only `UniversalTraits:UT_heavilybleedingwounds`. No exclusion from `UniversalTraits:UT_thickblood` is present. `UT_thickblood` sets `UT_bleedDrainMult = 0.5` and `UT_bleedDecayMult = 1.5`; combining it with `UT_weaklybleedingwounds` (which sets `UT_bleedDrainMult = 0.6`) would result in whichever value is written last overwriting the other, producing an undefined combined state. The `UT_thickblood` definition does exclude `UT_heavilybleedingwounds` but does not exclude `UT_weaklybleedingwounds`.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_weaklybleedingwounds.lua`
- Release copy in sync: yes — `release/UniversalTraits/42/media/lua/shared/UniversalTraits/traits/UT_weaklybleedingwounds.lua` is identical

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_weaklybleedingwounds.lua` (full file, 14 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1303–1312)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 392–393)
  - `test/run_tests.lua` (line 255 — trait listed in registration manifest; lines 518–532 — sibling bleeding traits tested, no dedicated test for this trait)
  - `test/UTTestMocks.lua` (line 233 — mock implementation of `UTCore.applyBleedDrainMult`)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)` — fires once at new game start
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — guard check; returns early if the trait is absent
  - `UTCore.applyBleedDrainMult(player, 0.6)` — called once in `onNewGame`; mock writes `player:getModData()["UT_bleedDrainMult"] = 0.6`
- Runtime chain (plain language):
  1. On new game, if the player has `UT_weaklybleedingwounds`, `UTCore.applyBleedDrainMult` is called with `0.6`, writing `UT_bleedDrainMult = 0.6` into the player's mod data.
  2. The UT engine reads `UT_bleedDrainMult` at runtime to scale the active bleed drain rate. A value of 0.6 means the player loses health from bleeding at 60% of the normal rate, giving roughly 67% more time before bleeding out (1 / 0.6 ≈ 1.667x time, not 40% as stated in the file comment).
  3. No periodic event handler is registered. The effect is applied once and persisted via mod data.
- Actual behavior (exact values):
  - Bleed drain rate: multiplied by 0.6 (active bleeding drains health at 60% of baseline).
  - Wound healing speed once bandaged: not affected (no `UT_bleedDecayMult` is written).
  - Effect onset: applied once at new game start, persistent thereafter.
- Minor discrepancy in file comment: The Lua file header states "roughly 40% more time before bleeding out." The correct derivation is 1 / 0.6 = 1.667, so the player survives approximately 66.7% longer, not 40% longer. The 40% figure is the reduction in drain rate, not the gain in survival time. The comment conflates these two distinct quantities.

## Description Integrity

- Display name: `UI_UT_weaklybleedingwounds` = "Weakly Bleeding Wounds" — accurate; clearly communicates the trait concept.
- Description: `UI_UT_weaklybleedingwoundsDesc` = "Your wounds seal up almost before you notice them. Bleed rate is reduced to 60% of normal." — the flavour text ("seal up almost before you notice them") slightly overstates the effect; a 40% drain reduction is meaningful but wounds do not close instantly. However, this is acceptable flavour framing.
- Mechanical accuracy: The claim "Bleed rate is reduced to 60% of normal" correctly matches the runtime value `applyBleedDrainMult(player, 0.6)`. This is the most important claim and it is accurate.
- Missing detail: The description does not state that wound clotting speed (bandaged healing rate) is unaffected. This is correctly documented in the Lua file comment but absent from the player-facing description. For a trait that shares a category with `UT_thickblood` (which does affect clotting), the omission could cause confusion. It is not a hard error but warrants a note.
- Source description divergence: The source (MST) described the trait as "Thick Blood" with "-50% Bleeding damage." UT renamed the trait and uses a different mechanism (stat modifier at new game vs. per-tick health credits), so the descriptions are intentionally independent. The UT description is cleaner and more precise than the source.

## Balance Review

- Upside: Bleed drain rate reduced to 60% of normal — a substantial increase in bleeding survivability, especially relevant in the early game when bandages and medical supplies are scarce.
- Downside: none — pure positive trait.
- Uptime: 100% permanent once applied at new game. No conditions, no cooldowns.
- Peer comparison:
  - `UT_thickblood` (4 points): sets `UT_bleedDrainMult = 0.5` (50% drain rate, strictly better than weaklybleedingwounds on the drain axis) AND `UT_bleedDecayMult = 1.5` (wounds clot 50% faster). `UT_thickblood` is a superset of `UT_weaklybleedingwounds` in every mechanical dimension and costs only 1 point more (4 vs. 3).
  - `UT_heavilybleedingwounds` (−4 points): sets `UT_bleedDrainMult = 2.0` — the direct opposite, used as the inverse cost reference point.
- Cost verdict: questionable. `UT_thickblood` at 4 points delivers both a better drain reduction (0.5 vs. 0.6) and an additional clotting bonus. `UT_weaklybleedingwounds` at 3 points offers only the drain reduction at a weaker magnitude. The 1-point gap between them is plausible but thin — players who understand the mechanics will nearly always prefer `UT_thickblood`. The cost difference between the two positive bleeding traits (3 vs. 4) may be appropriate if the design intent is to have a budget option, but the lack of any exclusion between them (see below) erodes the design intent.
- Stack or exclusion notes:
  - `UT_weaklybleedingwounds` excludes `UT_heavilybleedingwounds` — correct and enforced.
  - `UT_weaklybleedingwounds` does NOT exclude `UT_thickblood`. Both traits write to `UT_bleedDrainMult` independently via `UTCore.applyBleedDrainMult`. Since both fire on `OnNewGame`, whichever fires last will overwrite the other. The combined value is non-deterministic (load order dependent) rather than additive. A player selecting both traits in character creation would pay 7 points and receive only one of the two drain reductions. This is a silent conflict, not a hard exclusion.
  - `UT_thickblood` in its own definition excludes `UT_heavilybleedingwounds` but not `UT_weaklybleedingwounds`, confirming the gap is bidirectional.

## Regression Proof

- Existing tests covering this trait:
  - Line 255 of `run_tests.lua`: `"UniversalTraits:UT_weaklybleedingwounds"` appears in the full trait registration manifest. This asserts that the trait ID is present in the known trait list, but does not fire any event or inspect mod data.
  - No dedicated functional test for `UT_weaklybleedingwounds` exists in `run_tests.lua`. The sibling traits `UT_thickblood` (lines 518–525) and `UT_heavilybleedingwounds` (lines 527–532) each have functional tests asserting the value written to `UT_bleedDrainMult`. `UT_weaklybleedingwounds` has no equivalent.
- What the existing coverage proves: the trait ID string is registered in the manifest. Nothing else.
- Missing proof:
  - No test fires `OnNewGame` with `UT_weaklybleedingwounds` active and asserts `modData["UT_bleedDrainMult"] == 0.6`.
  - No test confirms the value is strictly less than 1.0 (matching the pattern used for `UT_thickblood`).
  - No test verifies that `UT_bleedDecayMult` is NOT written (i.e., that clotting is correctly left unaffected).
- Minimum next test needed:

  ```lua
  -- UT_weaklybleedingwounds sets UT_bleedDrainMult = 0.6 (slower active bleed drain)
  test("UT_weaklybleedingwounds sets UT_bleedDrainMult to 0.6", function()
      local p = fireNewGame("UniversalTraits:UT_weaklybleedingwounds")
      local v = p:getModData()["UT_bleedDrainMult"]
      assert_eq(v, 0.6, "expected UT_bleedDrainMult == 0.6, got " .. tostring(v))
      local decay = p:getModData()["UT_bleedDecayMult"]
      assert_true(decay == nil, "expected UT_bleedDecayMult to be nil (clotting unaffected), got " .. tostring(decay))
  end)
  ```

## Final Verdict

- Source origin: proven — `WeaklyBleedingWounds` from MoreSimpleTraits confirmed; registration, cost (3), mutual exclusion with `HeavilyBleedingWounds`, and runtime behaviour all traced across both MST mod variants.
- UT implementation: redesigned — the source used a per-tick `AddHealth` credit loop (client-side, `OnPlayerUpdate`, polling every frame); UT replaces this with a single stat write (`UT_bleedDrainMult = 0.6`) applied once at `OnNewGame`. The UT approach is cleaner, engine-integrated, and avoids the frame-polling cost of the source. Behavioural equivalence is approximate, not exact (the source's per-tick health credit scaled with body part count; UT's multiplier is global).
- Description: accurate — "Bleed rate is reduced to 60% of normal" correctly reflects the runtime value. Minor flavour overstatement ("seal up almost before you notice") is acceptable. The Lua file comment's "40% more time" is arithmetically wrong (correct figure is ~67% more time); this is a dev-comment error, not a player-facing error.
- Balance: acceptable with a gap — cost of 3 is reasonable for a budget bleeding mitigation trait, but the missing mutual exclusion with `UT_thickblood` means the two can be selected together, producing a silent mod-data overwrite conflict. This should be resolved either by adding a mutual exclusion or by making `applyBleedDrainMult` multiplicative rather than overwriting.
- Regression proof: inadequate — no functional test fires `OnNewGame` for this trait. The sibling traits (`UT_thickblood`, `UT_heavilybleedingwounds`) both have functional tests; `UT_weaklybleedingwounds` should receive the same treatment.
- Action needed: test fix | exclusion fix | dev-comment fix
- Open gaps:
  1. No functional regression test for `onNewGame` (assert `UT_bleedDrainMult == 0.6` and `UT_bleedDecayMult == nil`).
  2. Missing mutual exclusion with `UT_thickblood` in `UT_character_traits.txt`. Both traits write the same mod data key; combined selection silently drops one effect. Either add `UniversalTraits:UT_thickblood` to `MutuallyExclusiveTraits` for this trait, or change `applyBleedDrainMult` to stack multiplicatively.
  3. Lua file header comment "roughly 40% more time before bleeding out" is wrong; the correct value is ~66.7% more time. Should read "roughly 67% more time before bleeding out (1 / 0.6)."
  4. Player-facing description could note that clotting speed (bandaged healing) is not affected, to differentiate clearly from `UT_thickblood` which does affect clotting.
