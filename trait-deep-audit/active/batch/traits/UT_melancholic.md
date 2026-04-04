# UT_melancholic

## Trait Summary
- UT trait id: UT_melancholic
- Source mod: Dynamic Traits Expanded Moodles (`DynamicTraitsExpandedMoodles` / `Dynamic-Traits-main`)
- Source trait id: `Melancholic` (referenced via `player:HasTrait("Melancholic")` and `player:getTraits():add("Melancholic")`)
- Current cost: -3
- PRD cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence
- Source files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTPillsTraits.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/media/lua/client/DTMainFile.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMPillsTraits.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMMainFile.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMplayerStats.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/Translate/EN/UI_EN.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/shared/Translate/EN/Sandbox_EN.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/research/installed-mods/EvolvingTraitsWorld/mods/Evolving Traits World - Mark Dynamic Traits/media/lua/shared/NPCs/ETWSubmodCreationMethods.lua`
- Source trigger path (B41/base DT): `Events.EveryHours.Add(DTEveryHoursMain)` — `DTEveryHoursMain()` calls `melancholicTrait(player)` if `player:getModData().DTisMelancholic == true`. `melancholicTrait` increments a counter `DTPillsAntiDep` by 1 per hour (max 240), adds the `"Melancholic"` trait to the player when the counter exceeds 48, and while the trait is active calls `DTincreaseUnhappyness(player, 0, 3)` per hour. The trait can be removed by consuming antidepressants (`PillsAntiDep`), which decrements the counter by 48; once counter ≤ 48 the trait is stripped. Separately, `DTincreaseUnhappyness` itself checks `player:HasTrait("Melancholic")` and scales any unhappiness increase by ×1.3 while the trait is held.
- Source trigger path (B42 DTEM): `Events.EveryTenMinutes.Add` → `DTEMmelancholicTrait(player)` called from `DTEMMainFile.lua`. The B42 version uses a similar counter (`DTEMmelancholicTrait`) with a cap of 720, adds/removes the `"Melancholic"` trait based on the counter crossing 0, and while the trait is active calls `DTEMincreaseUnhappiness(player, 0, 3)` every ten minutes. Antidepressant consumption via `DTEMhandleAntidepressantsConsumption` decrements the counter by 48 per dose. Sandbox option `Sandbox_DTEM_EnablePillsTraitsDevelopmentInGame` controls whether the trait can be earned in-game from sustained unhappiness after the first week of survival.
- Source behavior summary: in the source, Melancholic is a dynamic trait — it develops in-play from sustained unhappiness and is treated (reduced/removed) with antidepressants. When active it raises unhappiness by +3 per hour (B41) or per ten minutes (B42), and amplifies all other unhappiness gains by ×1.3. It is not intended as a fixed character-creation negative; it is an emergent mental health condition with a pharmaceutical treatment path.
- Source description: `"Feelings of hopelessness are constant. Sad situations affect you more strongly."` (DTEM B42 EN)

## Current UT Evidence
### Structure
- Registered in registries.lua: yes — `UTTraitsRegistries.UT_melancholic = CharacterTrait.register("UniversalTraits:UT_melancholic")` (line 249, both `media/registries.lua` and `release/` mirror)
- Defined in UT_character_traits.txt: yes — `character_trait_definition UniversalTraits:UT_melancholic`, `Cost = -3`, `IsProfessionTrait = false`, `DisabledInMultiplayer = true`
- Translation strings present: yes — `UI_UT_melancholic = "Melancholic"`, `UI_UT_melancholicDesc = "The world feels muted and grey. A quiet sadness colors everything you do."` (both `UI_EN.txt` and `UI.json`)
- Exclusions/grants: `MutuallyExclusiveTraits = UniversalTraits:UT_optimist` — asymmetric; UT_optimist lists melancholic in its exclusion set but melancholic only lists UT_optimist. The mutual exclusion report flags this trait and recommends replacing `MutuallyExclusiveTraits = UniversalTraits:UT_optimist,` with an empty entry, implying the exclusion is under revision.
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_melancholic.lua`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/scripts/UT_character_traits.txt`
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt`
- Event registrations: `Events.EveryTenMinutes.Add(handler)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` only
- Runtime chain (plain language):
  1. Every ten in-game minutes, `handler()` fires.
  2. `getPlayer()` is called; if nil, the function returns early.
  3. `UTCore.hasTrait(player, TRAIT_ID)` checks whether the player holds `"UniversalTraits:UT_melancholic"`.
  4. If yes, `player:getStats():setStress(math.min(1, stats:getStress() + 0.05))` adds +0.05 stress per ten minutes, capped at 1.0.
- Actual behavior (exact values): adds +0.05 stress per ten in-game minutes while the trait is held, capped at the maximum stress value of 1.0. No unhappiness effect. No antidepressant interaction. No ×1.3 amplification of other unhappiness sources. The trait is fixed at character creation and cannot be acquired or removed dynamically.

### Peer Comparison (UT_depressive)
- `UT_depressive.lua` is structurally identical: `Events.EveryTenMinutes.Add(handler)`, adds +0.08 stress per ten minutes, capped at 1.0, using the same UTCore.hasTrait guard. Cost is also a negative trait. The UT implementation of melancholic uses a smaller per-tick delta (+0.05 vs +0.08), consistent with it being the lighter mood trait. Both traits affect stress, not unhappiness, which diverges from the source in both cases.

## Description Integrity
- Display name check: "Melancholic" — matches the source name and concept; accurate.
- Description check: "The world feels muted and grey. A quiet sadness colors everything you do." — the description evokes a sadness/unhappiness theme (muted world, quiet sadness) but the actual mechanic is a stress increase, not a sadness/unhappiness increase. The source explicitly raised unhappiness (+3/tick) and amplified unhappiness gains (×1.3); the UT raises stress (+0.05/tick) instead.
- Mismatch: the description text implies an unhappiness or mood effect; the code delivers a stress effect. A player reading "quiet sadness colors everything you do" would not anticipate a stress penalty. The description does not mention stress at all.
- The file header comment reads "Melancholic: mild steady stress increase" — this internal note is accurate to the code, but the player-facing description does not match it.

## Balance Review
- Upside: none
- Downside: +0.05 stress per ten in-game minutes (continuous, capped at 1.0 stress). At a sustained rate this would bring a zero-stress character to maximum stress in approximately 200 in-game minutes (roughly 3.3 in-game hours) with no other stress sources, though in practice stress has natural relief from activities and sleep.
- Uptime: continuous — fires every ten minutes as long as the trait is held; no conditions other than the trait guard
- Peer comparison:
  - `UT_depressive` (cost also negative, periodic-check group): +0.08 stress per ten minutes — a heavier stress tick for what is framed as a more severe mood disorder; melancholic's +0.05 is proportionally lighter, which is reasonable.
  - Source DTEM Melancholic: +3 unhappiness per ten minutes (B42) plus ×1.3 amplification of all other unhappiness gains — substantially more punishing than the UT implementation and operates on a different stat (unhappiness vs. stress).
  - Cost verdict: cost is -3, PRD specifies -4. The implementation is a real, continuous, lightweight stress penalty. -3 is plausible but the PRD cost of -4 was intended — this is a one-point under-charge relative to plan. Given the stress tick is lighter than UT_depressive's and the description mismatch, the cost should be revisited after the description is corrected.
- Stack or exclusion notes:
  - Mutual exclusion with UT_optimist is one-directional: melancholic blocks UT_optimist, and UT_optimist blocks melancholic, but UT_depressive also blocks UT_optimist while melancholic does not block UT_depressive. A player could theoretically hold both UT_melancholic and UT_depressive simultaneously, receiving both stress ticks (+0.05 + 0.08 = +0.13 per ten minutes). No explicit exclusion between these two mood-negative traits is defined.
  - The mutual exclusion report recommends replacing the UT_melancholic exclusion entry with an empty string, suggesting the one-directional exclusion to UT_optimist is already considered wrong and flagged for removal.
  - UT_pessimist is not in melancholic's exclusion list, so they can stack.

## Regression Proof
- Existing test: `"UniversalTraits:UT_melancholic"` appears in the batch trait list in `run_tests.lua` (line 283), within the Phase 3b Periodic-Check group. This confirms the trait ID is included in the batch registration sweep.
- What it proves: the trait ID is registered in UTTraitsRegistries. Nothing about runtime behavior is verified.
- Missing proof: no test confirms that (a) when a player holds `UniversalTraits:UT_melancholic` and the `EveryTenMinutes` event fires, stress increases by exactly 0.05; (b) when the trait is absent, no stress change occurs; (c) stress is capped at 1.0 and does not exceed it; (d) the handler returns cleanly when `getPlayer()` returns nil.

## Final Verdict
- Source origin: Dynamic Traits Expanded Moodles — `Melancholic` trait; in source this is a dynamic in-game-earned condition (not a character-creation choice), cured by antidepressants, that raises unhappiness by +3 per ten minutes and amplifies all unhappiness gains by ×1.3
- UT implementation: simplified rewrite — the dynamic acquisition/removal system and the antidepressant treatment path were not ported; UT treats Melancholic as a fixed character-creation negative that raises stress (not unhappiness) by +0.05 every ten minutes via a direct periodic handler; the mechanic is functional and real
- Description: misleading — the text frames the trait around sadness and a muted emotional world, implying an unhappiness effect, while the actual mechanic is a stress increase; the stat targeted does not match the description's emotional register
- Balance: cost is -3 against a PRD target of -4; the stress penalty is lighter than UT_depressive (-4 for +0.08/tick) and the description mismatch makes it hard to evaluate fairly; cost should be revisited after description correction
- Regression proof: missing — batch sweep confirms registration only; no behavioral test exists
- Action needed:
  1. **Description fix (required):** rewrite the player-facing description to accurately name stress as the affected stat and quantify the penalty (e.g., "Stress builds on its own. Stress increases steadily over time (+0.05 per ten minutes).")
  2. **Cost alignment (recommended):** reconcile actual cost (-3) with the PRD target (-4); decide whether the lighter stress tick justifies -3 or whether the PRD value should be restored
  3. **Mutual exclusion audit (required):** the mutual exclusion report already flags this trait for revision; ensure UT_melancholic and UT_depressive have an explicit mutual exclusion between them, or document the design decision that they are allowed to stack
  4. **Test (required):** add a unit test that fires `EveryTenMinutes` with a player holding the trait and asserts a +0.05 stress delta, and a parallel test that asserts no delta when the trait is absent
- Open gaps:
  - The source's unhappiness mechanic (the defining feature of the source trait) was not ported at all; UT melancholic is effectively a lighter clone of UT_depressive operating on the same stat with a lower delta, rather than a trait with a distinct gameplay identity
  - No antidepressant interaction exists in UT; the source's full treatment pathway (earn via sustained unhappiness, cure via pills) was stripped; the UT trait is static
  - UT_melancholic and UT_depressive can stack; combined stress rate would be +0.13 per ten minutes, which may be unintended
  - The mutual exclusion report recommends removing the UT_optimist exclusion from this trait entirely, which would leave melancholic with no exclusions at all — the intent behind that recommendation needs confirmation before acting on it
  - `DisabledInMultiplayer = true` is consistent with other periodic-check traits in the batch but was not an explicit source behavior; worth confirming this is intentional for this trait specifically
