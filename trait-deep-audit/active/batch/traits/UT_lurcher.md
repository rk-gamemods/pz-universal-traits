# UT_lurcher

## Trait Summary

- UT trait id: UT_lurcher
- Source mod: SomewhatTraits (SomewhatTraitsCore)
- Source trait id: SWTraits:SWLurcher (trait key: "SWLurcher")
- Current cost: -5
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/scripts/SWTraits_character_traits.txt`
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.15/media/lua/shared/Translate/EN/UI_EN.txt`
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/client/SWTraitsCore_client.lua`
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua`
- Source trigger path: `Events.OnTick.Add(SWLurcher)` (legacy client) and `Events.OnPlayerUpdate.Add(SWLurcher)` (42.13/42.15 client). Both fire every tick/update while the player is running or sprinting.
- Source behavior: When running or sprinting with endurance moodle level > 0, chance = `moodleLevel * (11 - nimbleLevel)` (out of 100). On a hit: bumps the player left or right (50/50), and with 50% probability sets `setBumpFall(true)` (full knockdown) vs `setBumpFall(false)` (stumble only). No movement speed penalty, no work speed penalty — pure stumble/knockdown mechanic only.

## Current UT Evidence

### Structure
- Registered in registries.lua: yes
- Defined in UT_character_traits.txt: yes
- Translation strings present: yes
- Exclusions/grants correct: yes — `MutuallyExclusiveTraits = UniversalTraits:UT_fast` matches intent (Lurcher and Fast are movement opposites; UT_fast also mutually excludes UT_lurcher)
- Runtime Lua file exists: yes

### Runtime Trace
- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_lurcher.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1152–1161)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 341–342)
  - `test/run_tests.lua` (lines 804, 846–855)
- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)`
  - `Events.OnPlayerUpdate.Add(onPlayerUpdate)`
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — trait check
  - `UTCore.applyWorkSpeed(player, -0.15)` — applies -15% work speed on new game
- Runtime chain (plain language):
  1. On new game: if player has the trait, applies -15% work speed via UTCore and stores `-0.15` in `modData["UT_speedMod"]`.
  2. On every player update: checks trait, manages a 30-tick cooldown stored in `modData["UT_lurcher_cooldown"]`. If cooldown > 0, decrements and exits. Otherwise checks that player is moving and endurance < 0.3. Calculates `chance = 3 - nimbleLevel`. If chance > 0 and `ZombRand(100) < chance`, fires `setBumpFallDown(true)` and sets cooldown to 30.
- Actual behavior (exact values):
  - Permanent: -15% work speed (via UTCore.applyWorkSpeed on OnNewGame); -15% movement speed declared in script comment but **not applied by any runtime code** (no movement speed modifier is set anywhere in UT_lurcher.lua).
  - Stumble condition: player must be moving AND endurance < 0.3 (raw stat, not moodle level).
  - Stumble chance per update tick: `max(0, 3 - nimbleLevel)` percent. At Nimble 0: 3%. At Nimble 1: 2%. At Nimble 2: 1%. At Nimble 3+: 0% (immune).
  - On stumble: `setBumpFallDown(true)` (full knockdown only — no side-bump, no 50/50 fall vs stumble). Cooldown: 30 ticks after each stumble.

## Description Integrity

- Display name check: "Lurcher" — appropriate, matches source name exactly.
- Description check: `UI_UT_lurcherDesc` reads: "You move with a lumbering, uncoordinated gait. -15% movement speed and -15% work speed. When exhausted and moving, you may lose your footing."
- Missing or misleading details:
  1. **Movement speed penalty is claimed but not implemented.** The Lua file comment notes "-15% movement speed" and the description repeats it, but no runtime code applies a movement speed modifier. Only work speed (-15%) is applied. This is a doc/code mismatch.
  2. "When exhausted" is vague. The actual trigger is endurance (raw stat) < 0.3, not a moodle level. The source used moodle level tiers; the UT port uses a raw endurance threshold, which is a behavioral difference.
  3. Nimble mitigation is not mentioned in the description. Players with Nimble 3+ are completely immune to stumbles — a significant interaction that is hidden from the player.
  4. UT uses `setBumpFallDown` (full knockdown) only; the source used a 50/50 fall vs. stumble split and also set bump direction. The UT version is strictly harder on the player.

## Balance Review

- Upside: none (negative trait — point refund only).
- Downside:
  - -15% work speed (permanent, always active).
  - Missing movement speed penalty means the movement cost is absent despite the -5 cost being set as if it were present.
  - Random full knockdown when endurance < 0.3 and moving, up to 3% per tick (not per second), with a 30-tick cooldown acting as a limiter. In practice: at Nimble 0 with low endurance, stumbles can occur roughly once every 30 ticks of being vulnerable while moving.
- Uptime: knockdown risk is conditional — requires endurance < 0.3 AND movement. In early game or after prolonged sprinting this window is meaningful. Late game with Nimble 3 the stumble is fully suppressed.
- Peer comparison: UT_noodlelegs costs -4 and applies -15% movement speed with no conditional runtime penalty. UT_lurcher costs -5 but delivers less consistent pain — its claimed -15% movement speed is missing, leaving a -15% work speed and an unreliable conditional stumble. At current cost it is arguably weaker than its -5 price implies, because one of its two advertised downsides is not implemented.
- Stack or exclusion notes: Mutually exclusive with `UniversalTraits:UT_fast` (both directions). No exclusion with UT_noodlelegs or UT_sorelegs — can stack work/movement penalties.
- Cost verdict: questionable — the -5 cost was set assuming both -15% movement speed and -15% work speed were active, but the movement speed penalty is not applied in code. If the movement speed modifier is intentionally absent, cost should be revisited downward. If it is a bug, it must be fixed.

## Regression Proof

- Existing test: "lurcher stumble fires when fatigued and moving" (`run_tests.lua` line 846)
- What it proves: With the trait present, moving=true, endurance=0.2, nimble=0, and ZombRand returning 0 (< 3), `Events.OnPlayerUpdate` fires the stumble and sets `_bumpFallDown=true`. Confirms the conditional stumble path works end-to-end.
- Missing proof:
  1. No test for the work speed application path (`onNewGame` handler).
  2. No test that Nimble >= 3 suppresses stumbles (chance <= 0 early return).
  3. No test that endurance >= 0.3 suppresses stumbles.
  4. No test that the 30-tick cooldown blocks a second stumble before it expires.
  5. No test confirming movement speed is **not** applied (or confirming it should be applied).
- Minimum next test if needed: "lurcher: nimble 3 suppresses stumble" — create a MockUpdatePlayer with the trait, moving=true, endurance=0.2, nimble=3, fire OnPlayerUpdate, assert `_bumpFallDown` remains nil/false.

## Final Verdict

- Source origin: proven — SomewhatTraits `SWLurcher` is the confirmed source; source files located and read.
- UT implementation: drifted — the stumble mechanic is ported but with significant differences: (1) movement speed penalty claimed but not implemented; (2) endurance threshold (< 0.3 raw) replaces moodle-level tiers; (3) stumble is always a full knockdown (`setBumpFallDown`) rather than the source's 50/50 fall vs. stumble split with directional bump; (4) UT fires on OnPlayerUpdate per-player while source used OnTick with a single-character reference.
- Description: misleading — claims -15% movement speed which is not applied in code; omits Nimble immunity; "exhausted" does not accurately describe the endurance < 0.3 threshold.
- Balance: questionable — one of two advertised stat penalties is absent from code, making the trait cheaper-feeling than its -5 cost warrants.
- Regression proof: partially protected — stumble happy path is covered; cooldown, suppression conditions, and new-game work speed application are not tested.
- Action needed: code fix (add movement speed application or remove the claim), doc fix (describe actual conditions accurately including Nimble immunity and exact endurance threshold), test fix (add suppression and cooldown tests).
- Open gaps:
  - Confirm whether the -15% movement speed omission is intentional or a bug; if intentional, reduce cost or document the rationale.
  - `UT_speedMod` stored in modData on OnNewGame is never read by any UT code visible in the reviewed files — confirm whether this value is consumed elsewhere or is dead data.
  - Source used `Events.OnTick` (fires every game tick, much faster than OnPlayerUpdate); UT uses OnPlayerUpdate. Stumble frequency and feel will differ — verify this is an acceptable deviation.
