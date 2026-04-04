# UT_anemic

## Trait Summary
- UT trait id: `UniversalTraits:UT_anemic`
- Source mod: MoreTraits (ToadTraits)
- Source trait id: `ToadTraits:anemic`
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `MoreTraits/mods/More Traits/42.13/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` line 265 — `TraitFactory.addTrait("anemic", getText("UI_trait_anemic"), -4, getText("UI_trait_anemicdesc"), false, false)`
  - `MoreTraits/mods/More Traits/42.13/media/registries.lua` line 112 — `ToadTraitsRegistries.anemic = CharacterTrait.register("ToadTraits:anemic")`
  - `MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` lines 2511–2555 — `checkBloodTraits(player)` function wired to `Events.OnPlayerUpdate`
  - `MoreTraits/mods/More Traits/42.13/media/lua/shared/Translate/EN/UI_EN.txt` line 115–116 — source display name and description
  - `MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` lines 2844–2896 — updated version of same function (structurally identical)
- Source trigger path:
  - `checkBloodTraits(player)` is called inside the mod's `OnPlayerUpdate` handler, which is wired to `Events.OnPlayerUpdate`. Runs every tick. In multiplayer the handler has a 1000ms timestamp guard (present elsewhere in the file); `checkBloodTraits` itself has no additional throttle.
- Source mutual exclusion: `TraitFactory.setMutualExclusive("thickblood", "anemic")` — line 370 of MoreTraitsMainCreationMethods.lua. Source treated anemic and thickblood as mutually exclusive at character creation.
- Source behavior:
  - On every `OnPlayerUpdate` tick: checks `player:hasTrait(ToadTraitsRegistries.anemic)`.
  - If active and `player:getBodyDamage():getNumPartsBleeding() > 0`: iterates all body parts.
  - For each part that is `bleeding()` and NOT `IsBleedingStemmed()`: applies `adjust = 0.4`. If the part is Neck or Head: `adjust = 0.4 * 2 = 0.8`.
  - In singleplayer: calls `parts:get(i):ReduceHealth(adjust)` directly. In multiplayer: `sendClientCommand(player, 'ToadTraits', 'BodyPartMechanics', { bodyPart = data.part, partHealthReduce = data.amount })`.
  - After processing: calls `HaloTextHelper.addTextWithArrow(player, getText("UI_trait_anemic"), false, HaloTextHelper.getColorRed())` — fires a red halo text "Anemic" every tick that a bleed is active.
  - Source cost: **-4**. Source display name: "Anemic". Source description: "You bleed much more rapidly from wounds."
  - Note: the source description ("bleed much more rapidly") describes `ReduceHealth` on bleeding body parts — i.e., body-part local health damage is accelerated while actively bleeding. This does NOT directly accelerate the native general-health drain rate (which is driven by `bleedingTime`). The source mechanic reduces body-part HP, which feeds into overall health indirectly.

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_anemic = CharacterTrait.register("UniversalTraits:UT_anemic")` at line 123, in the Stat Modifiers block
- Defined in UT_character_traits.txt: yes — lines 929–937:
  ```
  character_trait_definition UniversalTraits:UT_anemic
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_anemic,
      Cost = -4,
      UIName = UI_UT_anemic,
      UIDescription = UI_UT_anemicDesc,
  }
  ```
  No `XPBoosts`, no `MutuallyExclusiveTraits`, no `GrantedTraits`.
- Translation strings present: yes — `UI_EN.txt` lines 272–273:
  - `UI_UT_anemic = "Anemic"`
  - `UI_UT_anemicDesc = "Low iron levels slow your healing. Wound bleed decay is 3× slower (wounds close much slower than normal)."`
- Exclusions/grants correct: The source enforced `MutuallyExclusive("thickblood", "anemic")`. The UT script block has no `MutuallyExclusiveTraits` entry for `UT_thickblood`. This is a deviation — see Balance Review.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_anemic.lua` (15 lines)

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_anemic.lua` (15 lines, complete)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait` definition (lines 11–15)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_StatModifiers.lua` — `UTCore.applyBleedDecayMult` definition (lines 108–112) and surrounding comments (lines 93–112)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_BleedDecayHook.lua` — the consuming hook (57 lines, complete)
  - `UniversalTraits/test/UTTestMocks.lua` line 126 — mock stub for `UTCore.applyBleedDecayMult`

- Event registrations:
  - `Events.OnCreatePlayer.Add(onCreatePlayer)` — fires once at character creation (new game or load)

- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — nil-safe wrapper calling `player:getTraits():contains(traitId)`; returns false if player or traits is nil
  - `UTCore.applyBleedDecayMult(player, 0.33, false)` — writes `player:getModData()["UT_bleedDecayMult"] = 0.33` and `player:getModData()["UT_bleedDecayBandagedOnly"] = false`

- Runtime chain (plain language):
  1. At character creation, PZ fires `Events.OnCreatePlayer(playerIndex, player)`.
  2. `onCreatePlayer(playerIndex, player)` runs. Guard: if player does not have `UniversalTraits:UT_anemic`, return immediately.
  3. Calls `UTCore.applyBleedDecayMult(player, 0.33, false)` — sets two moddata keys: `UT_bleedDecayMult = 0.33`, `UT_bleedDecayBandagedOnly = false`.
  4. From this point on, `UTCore_BleedDecayHook.lua`'s `onPlayerUpdate` handler (wired to `Events.OnPlayerUpdate`) reads these moddata keys every tick.
  5. BleedDecayHook: reads `mult = 0.33` and `bandagedOnly = false`. Since `mult != 1.0`, proceeds. Reads `GameTime.getInstance():getMultiplier()`.
  6. Iterates all body parts. For each part where `bleedingTime > 0`: since `bandagedOnly = false`, applies to ALL parts regardless of bandage state.
  7. Determines native decay rate: `isBandaged` → `NATIVE_BANDAGED = 0.0002`; else `NATIVE_UNBANDAGED = 0.00002`.
  8. Computes `extraDecay = nativeDecay * gameMultiplier * (0.33 - 1.0) = nativeDecay * gameMultiplier * (-0.67)`.
  9. Since `extraDecay` is negative, `newTime = bleedingTime - extraDecay = bleedingTime + |extraDecay|` — bleedingTime is INCREASED each tick, meaning decay is countered/reversed. Wait — re-reading the hook math:
     - The game has ALREADY applied its native decay this tick (reduced bleedingTime by nativeDecay).
     - The hook then applies `extraDecay = nativeDecay * gameMultiplier * (mult - 1.0)` as an additional delta.
     - At `mult = 0.33`: `(0.33 - 1.0) = -0.67`, so `extraDecay` is negative.
     - `newTime = bleedingTime - extraDecay = bleedingTime - (negative) = bleedingTime + 0.67 * nativeDecay * gameMultiplier`.
     - Net result: after the game's native decay, the hook ADDS back 0.67x the native rate. Net change per tick = `-(1.0 * nativeDecay) + (0.67 * nativeDecay) = -0.33 * nativeDecay`. Only 0.33x of the native decay survives — **bleedingTime decays 3x slower than normal.**
  10. `part:setBleedingTime(math.max(newTime, 0))` — clamps to zero floor.

- Actual behavior (exact values):
  - **Cadence**: every `OnPlayerUpdate` tick (no throttle in the BleedDecayHook itself; runs every frame while bleeding).
  - **Multiplier applied**: `0.33` (approximately 1/3). Native bleed decay is reduced to 33% of normal speed.
  - **bandagedOnly**: `false` — the 3x slowdown applies whether the wound is bandaged or not. Bandaged wounds still heal, but 3x more slowly than they would without the trait.
  - **Bandaged native rate**: `0.0002 * gameMultiplier` per tick. With anemic: effective rate = `0.0002 * 0.33 = 0.000066` per tick.
  - **Unbandaged native rate**: `0.00002 * gameMultiplier` per tick. With anemic: effective rate = `0.00002 * 0.33 = 0.0000066` per tick.
  - **Scope**: all body parts with `bleedingTime > 0`, regardless of bandage state or body part type. No neck multiplier — the hook does not distinguish body parts.
  - **No active bleed drain effect**: `UT_bleedMult` (the general-health drain rate key) is NOT set by this trait. The native general-health drain from bleeding (driven by `bleedingTime` magnitude) is unaffected. The trait slows how fast `bleedingTime` decays, keeping wounds at a higher severity for longer — indirectly sustaining the drain rate for longer — but does not directly multiply the drain itself.
  - **Effect summary**: wounds take 3x as long to close in all states. Bandaging is still the correct response, but bandaged healing is also 3x slower than normal. The infection window for open wounds is tripled. Bandage consumption rate is indirectly increased (must be bandaged for 3x longer).

## Description Integrity
- Display name check: "Anemic" — matches source exactly. Accurate to the biological condition.
- Description check: "Low iron levels slow your healing. Wound bleed decay is 3× slower (wounds close much slower than normal)."
  - The claim "wound bleed decay is 3× slower" accurately matches the `mult = 0.33` applied to `bleedingTime` decay.
  - "Wounds close much slower than normal" — correct.
  - "Low iron levels slow your healing" — the first clause frames it as a healing/recovery issue, which is accurate for the decay mechanic.
- Missing or misleading details:
  1. **No mention that this applies regardless of bandage state.** Bandaging still helps (bandaged decay is 10x faster than unbandaged natively), but the 3x slowdown still applies even when bandaged. A player might assume bandaging fully counteracts the trait; it does not.
  2. **No mention that active bleed death rate is unaffected.** The description could be read as implying you die faster from bleeding ("slow your healing"), but the death-rate mechanism (`UT_bleedMult`, general health drain) is untouched. The description sentence "Low iron levels slow your healing" is technically correct for the decay mechanic but the MoreTraits source description was "You bleed much more rapidly" — a different emphasis. UT's description is more accurate for what UT actually does.
  3. No mention of the tripled infection window, which is a practical downstream consequence.
  - Overall the description is accurate for its brevity. The most impactful missing detail is the bandage-state-agnostic nature of the slowdown.

## Balance Review
- Upside: none — pure negative trait, returns 4 points.
- Downside: all wounds (bandaged or unbandaged) have their `bleedingTime` decay reduced to 33% of normal speed — wounds take 3x longer to close. The infection window for open wounds is effectively tripled. Bandage replacement frequency is increased (must wear bandages for 3x longer). No effect on sprint speed, general health, or skills.
- Uptime: constant — applies from character creation via moddata write. The BleedDecayHook only does work when `bleedingTime > 0` on at least one part, so the effect is passive until the player receives a wound. Against the early-game zombie density, wounds are frequent; the trait has meaningful uptime in active play.
- Peer comparison within bleed family:
  - `UT_staunch` (positive): `mult = 3.0, bandagedOnly = true` — bandaged wounds heal 3x faster. The exact positive mirror of anemic on bandaged wounds.
  - `UT_thickblood` (positive): `mult = 1.5, bandagedOnly = false` — all wounds close 1.5x faster, PLUS `UT_bleedDrainMult = 0.5` (death rate halved). Thickblood costs +5 (positive trait).
  - `UT_heavilybleedingwounds` (negative): `UT_bleedDrainMult = 2.0` (death rate doubled). This addresses general-health drain directly. Does NOT affect `bleedingTime` decay. At -5 points.
  - Anemic (-4) is cheaper than heavilybleedingwounds (-5) but arguably less immediately dangerous — anemic drags out the wound state and tripled infection risk, while heavilybleedingwounds doubles the speed you die from active bleeds.
- Mutual exclusion gap: the source enforced `MutuallyExclusive("thickblood", "anemic")`. UT has no `MutuallyExclusiveTraits` between `UT_anemic` and `UT_thickblood`. If a player somehow has both, moddata is last-write-wins on `OnCreatePlayer`/`OnNewGame` — whichever fires last sets `UT_bleedDecayMult`, overwriting the other. Since `UT_anemic` uses `OnCreatePlayer` and `UT_thickblood` uses `OnNewGame`, and both fire at character creation, the final value depends on event firing order (undefined). The combination also makes no thematic sense.
- Cost verdict: -4 is defensible. The trait is a slow-burn survivability penalty with its strongest impact in the mid-game when wounds are common and infection is lethal. It never directly kills you faster (unlike heavilybleedingwounds) but extends every wound's danger window significantly. -4 is slightly generous compared to heavilybleedingwounds at -5; -5 would also be reasonable. **Acceptable at -4.**

## Regression Proof
- Existing test coverage:
  - `"UniversalTraits:UT_anemic"` appears in the Phase 1 smoke-test ID list at `test/run_tests.lua` line 230, in the `-- Stat Modifiers (20)` group. This list is iterated by the "all trait IDs registered with CharacterTrait" test and the "script trait definitions resolve cleanly" test.
  - A moddata spot-check test exists for `UT_thickblood` (line 519) that verifies `UT_bleedDecayMult > 1.0`. **No equivalent test exists for `UT_anemic`.**
- What existing tests prove:
  1. `CharacterTrait.register("UniversalTraits:UT_anemic")` was called and the registry entry is present.
  2. The script definition block exists, the `CharacterTrait` field matches the block ID, and the registered ID resolves.
  - Neither test exercises the Lua runtime handler or verifies moddata values.
- Missing proof: No moddata spot-check test for `UT_anemic`. The `onCreatePlayer` handler — including the `UTCore.hasTrait` guard, the `applyBleedDecayMult(0.33, false)` call, and both moddata values — is entirely untested.
- Minimum next test if needed:
  ```lua
  dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_anemic.lua")

  test("UT_anemic: OnCreatePlayer sets UT_bleedDecayMult=0.33 and bandagedOnly=false", function()
      local p = fireCreatePlayer("UniversalTraits:UT_anemic")
      assert_eq(p:getModData()["UT_bleedDecayMult"], 0.33,
          "expected UT_bleedDecayMult 0.33, got " .. tostring(p:getModData()["UT_bleedDecayMult"]))
      assert_eq(p:getModData()["UT_bleedDecayBandagedOnly"], false,
          "expected UT_bleedDecayBandagedOnly false, got " .. tostring(p:getModData()["UT_bleedDecayBandagedOnly"]))
  end)

  test("UT_anemic: no moddata written without trait", function()
      local p = fireCreatePlayer("UniversalTraits:UT_somethingelse")
      assert_eq(p:getModData()["UT_bleedDecayMult"], nil,
          "UT_bleedDecayMult should be nil when UT_anemic not present")
  end)
  ```

## Final Verdict
- Source origin: confirmed — MoreTraits `ToadTraits:anemic`. Source used a per-tick `OnPlayerUpdate` model: for each actively bleeding (and not stemmed) body part, called `part:ReduceHealth(0.4)` (0.8 for Neck/Head) and displayed a red halo text "Anemic" every tick. Source cost was -4. Source enforced mutual exclusion with `thickblood`. Source was multiplayer-capable via `sendClientCommand`.
- UT implementation: completely rewritten via the UTCore bleed decay infrastructure. Trades the active per-tick `ReduceHealth` punishment (body-part local health damage) for a passive `bleedingTime` decay slowdown (`mult = 0.33, bandagedOnly = false`), set once at `OnCreatePlayer` and then consumed every tick by `UTCore_BleedDecayHook`. This is a fundamentally different mechanic: source directly damaged body-part HP while bleeding; UT prolongs how long wounds remain at their current severity without touching body-part HP directly. UT's approach is mechanically cleaner, better integrated with UTCore infrastructure, and avoids the visual noise of per-tick halo text. `DisabledInMultiplayer = true` sidesteps the source's client command networking.
- Description: **accurate** for its brevity. States the 3x slowdown correctly. Missing the bandage-agnostic detail and the infection window consequence, but not misleading.
- Balance: **acceptable** at -4. The trait is a sustained wound-duration penalty with meaningful downstream effects (infection, bandage cost). No immediate lethality boost makes -4 feel slightly cheap versus -5, but not wrong.
- Regression proof: **weak**. ID registration and script-block structure are covered by the smoke-test list. The runtime handler and both moddata keys are entirely uncovered.
- Action needed:
  1. **Add MutuallyExclusiveTraits**: add `MutuallyExclusiveTraits = UniversalTraits:UT_thickblood` to the script definition block, mirroring the source exclusion. Without it, concurrent possession of both traits produces undefined `UT_bleedDecayMult` values depending on event ordering.
  2. **Add moddata spot-check test** per the minimum test block above — at minimum verify `UT_bleedDecayMult = 0.33` and `UT_bleedDecayBandagedOnly = false` after `OnCreatePlayer`.
  3. **Optional description addition**: consider appending "This applies whether or not wounds are bandaged." to clarify the bandage-agnostic nature.
- Open gaps:
  - No mutual exclusion with `UT_thickblood` in the UT script block. This is a functional correctness gap — not just a balance concern.
  - The source halo text mechanic ("Anemic" in red on each bleed tick) has no equivalent in UT. This is intentional simplification and does not affect game behavior, but the player receives no in-game feedback that the trait is actively affecting them.
  - `UT_bleedMult` (active death rate) is deliberately not set. The header comment in UT_anemic.lua states: "Does not affect active bleed death rate — combine with heavilybleedingwounds for that." This is correct and intentional design, not a gap.
