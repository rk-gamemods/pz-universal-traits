# UT_physicallyactive
## Trait Summary
- UT trait id: UT_physicallyactive
- Source mod: Dynamic Traits / Dynamic Traits + Expanded Moodles (DynamicTraitsExpandedMoodles by Daimonic)
- Source trait id: PhysicallyActive (unnamespaced)
- Current cost: 4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/shared/NPCs/DTMainCreationMethods.lua` (B41 trait registration and mutual exclusions)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTexpandedActionsEffects.lua` (B41 runtime effect implementation)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTByOtherConditions.lua` (B41 dynamic gain/loss logic)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/NPCs/DTEMMainCreationMethods.lua` (B42 trait registration)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMexpandedActionsEffects.lua` (B42 runtime effect implementation)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMByOtherConditions.lua` (B42 dynamic gain/loss logic)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/shared/Translate/EN/UI_EN.txt` (B41 EN strings)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/Translate/EN/UI_EN.txt` (B42 EN strings)
- Source registration (B41, `DTMainCreationMethods.lua`):
  - `TraitFactory.addTrait("PhysicallyActive", ..., 10, ..., false)` — selectable positive trait, cost 10.
  - `TraitFactory.addTrait("PhysicallyActive2", ..., 0, ..., true)` — profession-granted hidden version, cost 0.
  - Mutual exclusions: `Sedentary` ↔ `PhysicallyActive`; `PhysicallyActive` ↔ `PhysicallyActive2`; `PhysicallyActive` ↔ `Overweight`; `PhysicallyActive` ↔ `Obese`. (Exclusions with `Underweight`, `VeryUnderweight`, `Feeble`, `Weak`, `OutOfShape`, `Unfit` were commented out.)
  - `PhysicallyActive2` is granted free to the Fitness Instructor profession.
  - The trait is dynamic — it can be gained or lost during play depending on physical activity score (`DTObtainLoseActiveSedentary`).
- Source behavior (B41 runtime, `DTexpandedActionsEffects.lua`):
  - When player has `PhysicallyActive`, physical actions reduce negative moodles (stress, boredom, unhappiness, anger):
    - **Chopping trees** (axe weapon hits tree): decreaseStress 0.03, decreaseBoredom 3, decreaseUnhappiness 3, decreaseAnger 0.03.
    - **Weapon swing**: decreaseStress 0.01, decreaseBoredom 1, decreaseUnhappiness 1, decreaseAnger 0.01.
    - **Walking**: decreaseStress 0.003, decreaseBoredom 0.3, decreaseUnhappiness 0.3, decreaseAnger 0.003.
    - **Running**: decreaseStress 0.01, decreaseBoredom 1, decreaseUnhappiness 1, decreaseAnger 0.01.
    - **Sprinting**: decreaseStress 0.015, decreaseBoredom 1.5, decreaseUnhappiness 1.5, decreaseAnger 0.015.
    - **Exercising** (ISFitnessAction loop): decreaseStress 0.05, decreaseBoredom 5, decreaseUnhappiness 5, decreaseAnger 0.05.
  - No XP multiplier or XP bonus is applied by the source implementation. No `addXPBoost` is called for `PhysicallyActive` at registration.
- Source dynamic trait system (`DTByOtherConditions.lua`, B41 — identical structure in B42):
  - Each physical action increments `DTObtainLoseActiveSedentary` modData key (axe hit tree +3, weapon swing varies by category 1–4, running +1, sprinting +2, exercise +10).
  - Every tick the counter decays by −0.5, bounded to [−70000, +70000].
  - Thresholds:
    - Counter ≤ −20000 and `Sedentary` not held → gain `Sedentary` trait (halo red).
    - Counter ≥ 40000 and `PhysicallyActive` not held → gain `PhysicallyActive` trait (halo green).
    - Counter in (−20000, 40000) and either trait held → lose that trait (halo red for `PhysicallyActive`, green for `Sedentary`).
  - Trait is therefore transient at runtime — it can be earned or stripped during play based on cumulative activity.
- Source EN strings:
  - B41: `UI_trait_PhysicallyActive = "Physically Active"` / `UI_trait_PhysicallyActiveDesc = "Energetic person. Spending energy makes you feel good."`
  - B42: identical strings.
- Source cost: 10 points (selectable version). UT uses 4.

## Current UT Evidence
### Structure
- Registered in run_tests.lua: yes — `"UniversalTraits:UT_physicallyactive"` appears at line 303, Phase 3c — Event-Driven block, alongside `UT_motionsickness`, `UT_vehophobic`, `UT_humanhamster`, and similar event-driven traits.
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_physicallyactive`, `IsProfessionTrait = false`, `DisabledInMultiplayer = true`, `Cost = 4`. No `MutuallyExclusiveTraits` field present.
- Translation strings present: yes — `UI_UT_physicallyactive = "Physically Active"` and `UI_UT_physicallyactiveDesc = "You have always pushed your body and it pays off. Exercise yields more fitness gains for you than it does for others."` in `media/lua/shared/Translate/EN/UI_EN.txt` (lines 635–636).
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_physicallyactive.lua`.

### Runtime Trace
- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_physicallyactive.lua`
  - `UniversalTraits/media/scripts/UT_character_traits.txt`
  - `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
  - `UniversalTraits/test/run_tests.lua`
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTexpandedActionsEffects.lua` (source for comparison)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMexpandedActionsEffects.lua` (source B42 for comparison)
- Event registrations: `Events.OnPlayerUpdate.Add(onPlayerUpdate)` — registered once at module load time.
- Runtime chain (plain language):
  1. Every game tick, `onPlayerUpdate(player)` fires.
  2. Checks `UTCore.hasTrait(player, "UniversalTraits:UT_physicallyactive")`. If not present, returns immediately.
  3. Reads `playerId = player:getPlayerNum()` and `currentTick = getGameTime():getTicks()`.
  4. Initializes `lastCheckTick[playerId]` to 0 if nil.
  5. If fewer than 600 ticks have elapsed since the last check for this player, returns (throttle).
  6. Otherwise, records `lastCheckTick[playerId] = currentTick`.
  7. Sets `player:getModData()["UT_physActiveBonus"] = true`.
- Actual behavior (UT implementation, exact from source):
  - Fires every 600 ticks while the player has the trait.
  - Sets a boolean modData flag `UT_physActiveBonus = true` on the player.
  - No other effect is applied within this file. The flag is set but **nothing in the reviewed files reads or acts on `UT_physActiveBonus`**. The runtime file does not award XP, does not modify moodles, does not call any XP boost function, and does not hook any exercise or movement event.
  - The flag writer is the entirety of the runtime implementation — the trait has no observable gameplay effect beyond setting a modData flag that nothing reads.

## UT Divergences from Source
1. **Mechanic**: Source grants mood relief (reduces stress, boredom, unhappiness, anger) on physical actions (movement, combat, exercise). UT sets a modData flag `UT_physActiveBonus = true` every 600 ticks and does nothing else. These are completely different mechanics.
2. **XP boost**: The UT description says "Exercise yields more fitness gains" — implying a fitness XP bonus. The source does not implement an XP bonus for `PhysicallyActive` (no `addXPBoost` call in registration). The UT runtime does not implement one either — the `UT_physActiveBonus` flag is never read by any XP-granting code in the reviewed files. The description advertises a feature that does not exist in either source or UT.
3. **Mood relief**: Source extensively reduces negative moodles during physical activity. UT has no moodle effects whatsoever.
4. **Dynamic trait system**: Source treats `PhysicallyActive` as a dynamic trait that can be earned or lost based on cumulative activity (counter-driven, threshold-gated). UT treats it as a static selectable trait — no dynamic gain/loss mechanic.
5. **Mutual exclusions**: Source defines `PhysicallyActive` ↔ `Sedentary`, `PhysicallyActive` ↔ `Overweight`, `PhysicallyActive` ↔ `Obese`, and the profession-version cross-exclusion. UT defines no `MutuallyExclusiveTraits` at all — nothing prevents simultaneously holding `UT_physicallyactive` with thematically contradictory traits.
6. **Cost**: Source cost is 10 (selectable). UT cost is 4. Given that the UT implementation has no active effect at all, even 4 is misaligned — any positive cost implies delivered value that does not exist.
7. **Throttle**: Source has no throttle (fires every tick on action events). UT throttles to once every 600 ticks on `OnPlayerUpdate` — but since the only action is setting a flag that nothing reads, the throttle is irrelevant.
8. **Trigger events**: Source hooks `OnHitTree`, `OnSwingWeapon`, `OnPlayerMoving`, `ISFitnessAction` (exercise timed action). UT hooks only `OnPlayerUpdate` with no action discrimination.
9. **Multiplayer**: Source is not flagged `DisabledInMultiplayer`. UT is `DisabledInMultiplayer = true`.

## Description Integrity
- Display name check: `"Physically Active"` — matches source name exactly; accurate.
- Description check: `"You have always pushed your body and it pays off. Exercise yields more fitness gains for you than it does for others."` — inaccurate on two counts:
  1. The description explicitly promises a fitness XP gain bonus. The implementation does not provide one. The `UT_physActiveBonus` modData flag is set, but no code anywhere reads it to apply an XP multiplier or additive bonus. The described effect is unimplemented.
  2. The flavor text ("you have always pushed your body") implies a static biographical trait, whereas the source concept is a dynamic trait earned by ongoing physical activity during play. The UT description misrepresents the source design intent.
- The description accurately matches neither the source behavior (moodle relief during activity) nor the UT behavior (flag set, no effect). It describes a third, entirely absent mechanic (fitness XP bonus).

## Balance Review
- Upside claimed: fitness XP bonus (per description). Upside actual: none — no code delivers any benefit.
- Downside: none.
- Severity assessment: zero effect positive trait. A player spending 4 character creation points on this trait receives no gameplay benefit. The modData flag `UT_physActiveBonus` is orphaned — either the consumer code was never written, was removed, or was never ported from a planned design.
- Cost: 4 points. For a trait with no active effect, this is an outright cost trap — players are paying points for nothing. Source cost was 10, which was supported by meaningful moodle relief on all physical actions. UT's implementation supports a cost of 0 by observable behavior.
- Peer comparison:
  - `UT_humanhamster` (cost -3): event-driven negative trait at the same registration tier. Has an active behavioral effect (hoarding compulsion).
  - `UT_motionsickness` (cost -4): event-driven negative trait. Has an active stress-increment effect, however mild.
  - `UT_physicallyactive` at cost +4 with zero delivered effect is uniquely broken among adjacent peers.
- Uptime: `UT_physActiveBonus` flag is set every 600 ticks unconditionally while the player holds the trait. Since nothing reads it, uptime of the actual effect is 0%.

## Regression Proof
- Existing tests (run_tests.lua): `"UniversalTraits:UT_physicallyactive"` appears at line 303 in the trait registration list — included in the batch registration test that verifies all trait IDs register without error at load time. No dedicated behavior test exists for this trait.
- What the registration test proves: the trait ID is registered with `CharacterTrait.register` without error. It does not test any runtime behavior.
- Missing proof:
  - No test verifies that any XP bonus is applied during exercise.
  - No test verifies that `UT_physActiveBonus` is read by any downstream system.
  - No test verifies that the 600-tick throttle fires correctly.
  - No test verifies that the flag is only set when the trait is held (not for players without the trait).
  - No test verifies that `lastCheckTick` is scoped correctly per player (even though `DisabledInMultiplayer = true`, the per-player indexing should be verified for the singleplayer case).
- Minimum next tests if a fix is implemented:
  - Test: player with trait, 600+ ticks elapse during exercise → fitness XP received above baseline (or whatever the intended effect becomes).
  - Test: player without trait, same conditions → no bonus applied.
  - Test: player with trait, fewer than 600 ticks elapse → no duplicate application.

## Final Verdict
- Source origin: confirmed — trait originates from Dynamic Traits (`PhysicallyActive`), originally cost 10 points. Name is preserved exactly.
- UT implementation: broken stub. The runtime file exists and registers an `OnPlayerUpdate` handler, but the handler's only action — setting `UT_physActiveBonus = true` in modData — is never consumed by any other code. The trait has zero gameplay effect.
- Description: factually incorrect — promises a fitness XP bonus that does not exist in either source or UT. A player cannot trust this description to predict actual behavior.
- Balance: broken — positive cost (4 points) with zero positive effect. Strictly a cost trap.
- Regression proof: registration only — no behavior tests exist.
- Action needed: implementation fix, description fix, balance review, test fix
- Open gaps:
  1. **Critical — implement the effect**: decide whether to implement the described fitness XP bonus (not present in source but described in UT), or port the source moodle-relief mechanic (not described), or some combination. The `UT_physActiveBonus` consumer code must either be written or the flag removed.
  2. **XP boost approach**: if the intent is a fitness XP bonus, the correct PZ mechanism is `addXPBoost(Perks.Fitness, N)` at trait registration (in the script definition or via `TraitFactory`), not a runtime modData flag. Evaluate whether a static XPBoost at registration is cleaner than a runtime flag approach.
  3. **Description rewrite required**: current description ("Exercise yields more fitness gains") must match whatever mechanic is actually implemented. If moodle relief is chosen, rewrite to describe that. If XP boost is chosen, use "+N to Fitness" phrasing per project convention (never "start at level N").
  4. **MutuallyExclusiveTraits**: add at minimum `UT_humanhamster` (sedentary hoarding compulsion) as a mutually exclusive trait; evaluate whether any "unfit" or negative-body-condition UT traits should also be excluded.
  5. **Dynamic trait consideration**: the source design is a dynamic trait earned and lost by activity. UT makes it static (selectable at character creation). This is an intentional design departure but should be documented; if the dynamic system is ever added to UT, this trait would need to be reconsidered.
  6. **Cost**: 4 points is unjustified until a real effect exists. Set cost only after the mechanic is determined and calibrated against peer traits.
  7. **No behavior tests** — add tests once the effect is implemented.
