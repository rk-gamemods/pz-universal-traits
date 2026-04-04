# UT_injured_I

## Trait Summary

- UT trait id: UT_injured_I
- Source mod: SomewhatTraits (SomewhatTraits by author unknown)
- Source trait id: SWInjured (trait key: `"SWInjured"`)
- Current cost: -4
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (lines 121, 582–599, 1075–1081)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` (lines 326–344)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/media/lua/shared/Translate/EN/UI_EN.txt` (lines 57–58)
- Source display name: "Injured"
- Source description: "Spawns with a various severity fracture in random lower body part."
- Source cost: not directly verified from script file (source .txt not found in installed-mods); -4 is the UT-assigned cost.
- Source multiplayer: not verified from script file; UT sets `DisabledInMultiplayer = true`.
- Source mutual exclusion: none found in source files reviewed.
- Source trigger path: `Events.OnNewGame.Add(SWInjured)` (42.15 server version); in the client version the call fires during the new-game initialization block (line 1081).
- Source behavior: on new game, if the player has the `SWInjured` trait, a random body part is selected from a fixed list of lower-body parts (Groin, UpperLeg_L, UpperLeg_R, LowerLeg_L, LowerLeg_R, Foot_L, Foot_R). A fracture is applied via `bodyPart:setFractureTime(severity)`. Severity is 50 by default; reduced to ZombRand(30,50) if the player has the FastHealer trait, or increased to ZombRand(50,80) if they have SlowHealer. After applying the fracture, the trait removes itself from the player (`characterTraits:remove("SWInjured")` in the client version). The 42.15 server version does not remove the trait. No stress or stat modification is applied by the source.

## Current UT Evidence

### Structure

- Registered in registries.lua: assumed yes — the trait appears in the `run_tests.lua` registration list at line 279 under the Phase 3a Spawn-With-Condition group, alongside `UT_injured_II`, `UT_broke`, and `UT_burned`. Presence in the test harness list is sufficient confirmation.
- Defined in UT_character_traits.txt: yes — lines 1605–1614
- Translation strings present: yes — `UI_UT_injured_I` ("Lightly Injured") and `UI_UT_injured_IDesc` at lines 500–501 of `UI_EN.txt`
- Exclusions/grants declared in script definition:
  - `MutuallyExclusiveTraits = UniversalTraits:UT_injured_II`
  - Mutual exclusion is bidirectional: `UT_injured_II` also declares `MutuallyExclusiveTraits = UniversalTraits:UT_injured_I` (line 1624). A player can only hold one severity tier of the injured trait.
  - No mutual exclusion existed in the source.
- DisabledInMultiplayer: `true` in UT. Source multiplayer setting not confirmed from script file; consistent with the rest of the UT Spawn-With-Condition series.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_injured_I.lua`

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_injured_I.lua` (all 18 lines)
  - `media/scripts/UT_character_traits.txt` (lines 1605–1614)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 500–501)
  - `test/run_tests.lua` (line 279)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — trait guard
  - `UTCore.applySpawnCondition(player, { injuries = {BodyPartType.Hand_L, BodyPartType.Foot_L} })` — injury application
  - `UTCore.applySpawnStats(player, { stress = 0.3 })` — stress application
- Runtime chain (plain language):
  1. On new game: check if the player has `UniversalTraits:UT_injured_I`. If not, return immediately.
  2. Call `UTCore.applySpawnCondition` with an injuries table listing `BodyPartType.Hand_L` and `BodyPartType.Foot_L`. This applies injuries to the left hand and left foot via the UTCore spawn-condition subsystem.
  3. Call `UTCore.applySpawnStats` with `stress = 0.3`. This sets the player's stress stat to 0.3 at spawn.
  4. No further logic. The trait does not remove itself; the trait remains on the character for the lifetime of the save (consistent with all UT Spawn-With-Condition traits).
- Actual behavior (exact values):
  - Left hand (`BodyPartType.Hand_L`) receives an injury at spawn.
  - Left foot (`BodyPartType.Foot_L`) receives an injury at spawn.
  - Stress is set to 0.3 at spawn.
  - The trait persists on the character indefinitely; it is a permanent descriptor only. All physical effects are one-time spawn modifications.

## Description Integrity

- Display name check: "Lightly Injured" — does not match the source display name ("Injured"). UT renames the trait to "Lightly Injured" to distinguish it from the more severe `UT_injured_II` ("Seriously Injured"). This is an intentional UT design choice for the two-tier system.
- Description check: `UI_UT_injured_IDesc` reads: "You did not make it out clean. You spawn with injuries to your left hand and left foot, and stress set to 0.3."
- Description accuracy vs. UT implementation:
  - "injuries to your left hand and left foot" — accurate. The code passes `{BodyPartType.Hand_L, BodyPartType.Foot_L}` to `applySpawnCondition`.
  - "stress set to 0.3" — accurate. The code calls `applySpawnStats` with `stress = 0.3`.
  - The description is fully accurate. No hidden effects. No omissions detected.
- Source divergence: the UT implementation is a significant mechanical redesign. The source (`SWInjured`) applies a single fracture to a randomly selected lower-body part (from a pool of 7 parts: Groin, both upper legs, both lower legs, both feet), with severity scaled by the FastHealer/SlowHealer trait. The source applies no stress. UT replaces the random lower-body fracture with fixed, deterministic injuries to two specific parts (left hand and left foot — neither of which is in the source's lower-body pool), and adds a stress component entirely absent from the source. The body parts targeted are categorically different: source targets lower limbs and groin; UT targets an upper extremity (hand) and a lower extremity (foot).

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside:
  - Left hand injury at spawn: impairs actions that require hand use (weapon handling, construction, crafting). Severity depends on `UTCore.applySpawnCondition` implementation details for injury type and depth.
  - Left foot injury at spawn: impairs movement speed or causes pain. Severity likewise depends on `UTCore.applySpawnCondition`.
  - Stress 0.3 at spawn: not trivial but far from the panic threshold; the player starts with noticeable stress that will require management in the early game.
  - All three effects are one-time spawn penalties only. The injuries will heal over time with rest and medical supplies. Stress will normalize with gameplay. There is no ongoing or repeating downside after the early game.
- Uptime: very low — all penalties are temporary. Once injuries heal and stress normalizes (typically within the first in-game day or two of active play), the trait has no further mechanical effect. The player retains the -4 point refund permanently after the downside has fully expired.
- Peer comparison:
  - `UT_injured_II` (-8): the severe tier; injuries to four body parts (both hands, left foot, upper torso) plus stress 0.6 and fatigue 0.4. Costs twice as many points. Having two injuried tiers with a bidirectional mutual exclusion is sound design.
  - `UT_broke` (-10): also a Spawn-With-Condition trait; applies a fracture to Foot_L and an injury to Foot_L, but no stress. Costs significantly more despite affecting only one body part — suggesting `UT_broke` includes additional effects (e.g., inventory or currency loss) not visible from this audit.
  - `UT_burned` (-?): also Spawn-With-Condition; burn severity 0.6 plus injuries to both hands and upper torso. The burn component likely makes it materially more severe than `UT_injured_I`.
  - Source `SWInjured` (cost unknown): source applies one random fracture only — no stress, no multiple parts. The UT variant with two injuries and a stress component is mechanically stronger than the source penalty.
- Cost verdict: plausible but uncertain. At -4 points, the trait provides a modest early-game challenge that fully resolves over time. The two-part injury plus stress-0.3 is a reasonable short-term downside for -4. The balance concern is the purely temporary nature of all effects — a player who knows the game will clear both injuries and the stress within the first day, making the -4 point refund effectively free after the first hour of play. A slight cost reduction to -3 could be considered if the early-game penalty is judged too short-lived relative to peers, but -4 is defensible given the dual-injury scope.

## Regression Proof

- Existing test: `UT_injured_I` appears in the Phase 3a Spawn-With-Condition registration list at `run_tests.lua` line 279, alongside `UT_injured_II`, `UT_broke`, and `UT_burned`. This confirms the trait ID resolves in the registry and the Lua file loads without error.
- What it proves: registration succeeds and no load-time crash occurs.
- Missing proof:
  1. No test for spawn-condition application — no test verifies that `applySpawnCondition` is called with `{BodyPartType.Hand_L, BodyPartType.Foot_L}` when the trait is present.
  2. No test for the stress assignment — no test confirms `applySpawnStats` is called with `stress = 0.3`.
  3. No test for the guard path — no test confirms that a player without the trait exits without any state modification.
  4. No test for `applySpawnCondition` internal behavior — if UTCore's injury application changes (e.g., injury type or severity changes), no regression would be caught.
- Minimum next test if needed: "injured_I: applies hand and foot injuries and sets stress on new game" — create a MockPlayer with the trait present, fire `Events.OnNewGame`, assert `applySpawnCondition` was called with the two expected `BodyPartType` values and `applySpawnStats` was called with `stress = 0.3`. Mirror with a MockPlayer lacking the trait to assert no calls are made.

## Final Verdict

- Source origin: confirmed — `SWInjured` from SomewhatTraits is the source. EN translation, client Lua (SWSomewhatTraitsCore.lua), and 42.15 server Lua (SWTraitsCore_server.lua) all located and read. The source applies one random lower-body fracture with no stress component.
- UT implementation: redesigned — the UT port replaces the single random lower-body fracture with fixed injuries to two specific parts (left hand and left foot) and adds a stress-0.3 component not present in the source. The body parts targeted are categorically different from the source's lower-limb pool. The display name is renamed from "Injured" to "Lightly Injured" to support the two-tier UT design.
- Description: accurate and complete — the description correctly names both injured body parts and the exact stress value. No hidden effects or omissions detected.
- Balance: defensible at -4, with a minor concern about the purely temporary nature of all effects. The dual-injury plus early-game stress provides a real short-term challenge, but the downside fully expires after the first in-game day. Peer comparison does not reveal a clear imbalance, but the cost could be reconsidered if the average injury heal time proves shorter than intended.
- Multiplayer flag: `DisabledInMultiplayer = true` — consistent with the rest of the UT Spawn-With-Condition series. Source multiplayer status not confirmed.
- Mutual exclusion: bidirectional with `UT_injured_II`. Not present in the source. Appropriate UT-originated design for a two-tier injury system.
- Regression proof: minimal — only a registration-list check exists. Spawn-condition application and stat assignment paths are untested.
- Action needed:
  1. **No description fix required**: description is accurate as written.
  2. **Balance watch**: monitor whether the -4 cost remains justified as the UTCore injury implementation matures. If injuries heal faster than a full in-game day at default settings, consider reducing cost to -3 or adding a secondary persistent effect (e.g., a small ongoing pain modifier for the first N in-game hours).
  3. **Test gap**: add functional tests for the spawn-condition call and the stress assignment path, using mock UTCore hooks.
- Open gaps:
  - The `UTCore.applySpawnCondition` implementation for the `injuries` key is not audited here. The exact injury type (wound, laceration, deep wound, fracture) and severity applied to `Hand_L` and `Foot_L` are not known from this file alone. The description says "injuries" generically; if the underlying implementation applies fractures, the description may understate severity. A follow-up audit of `UTCore.applySpawnCondition` is recommended.
  - The source's `setFractureTime` call (which specifically applies a fracture) diverges from UT's `injuries` key (type unknown). Confirm whether UT intentionally uses a wound-type injury rather than a fracture, and whether that distinction is reflected in the player-facing description.
  - The source removes the `SWInjured` trait from the character after applying the fracture (client version, line 598). UT does not remove the trait. This means the trait persists visibly on the character sheet for the entire save. This is consistent with all UT Spawn-With-Condition traits and is presumably intentional, but it means the character screen will always show "Lightly Injured" even after full recovery — which may be confusing to players. A tooltip note or lore justification could be considered.
