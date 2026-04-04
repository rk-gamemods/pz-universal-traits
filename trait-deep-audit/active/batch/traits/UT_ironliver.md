# UT_ironliver

## Trait Summary

- UT trait id: UT_ironliver
- Source mod: SomewhatTraits (SWTraits)
- Source trait id: SWTraits:SWIronLiver
- Current cost: 3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/scripts/SWTraits_character_traits.txt` (script definition, Cost = 3)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraits/42.13/media/lua/shared/Translate/EN/UI_EN.txt` (source EN strings)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/media/lua/client/SWSomewhatTraitsCore.lua` (legacy client runtime, lines 282–289, 1013–1023, 1062)
  - `research/installed-mods/SomewhatTraits/mods/SomewhatTraitsCore/42.15/media/lua/server/SWTraitsCore_server.lua` (B42 server runtime, lines 159–171)
- Source trigger path (legacy client): `Events.OnTick.Add(SWIronLiver)` and `Events.OnTick.Add(SWDrunkReductionValue)` — two separate tick handlers
- Source trigger path (B42 server): `Events.OnTick.Add(SWIronLiver)` — server-side tick
- Source behavior (legacy client):
  - `SWIronLiver()`: if drunkenness > 20, calls `character:setSleepingTabletEffect(0)` (suppresses sleeping-tablet sedation while heavily drunk)
  - `SWDrunkReductionValue()`: multiplies the base drunk-reduction rate by ×4 via `bodyDamage:setDrunkReductionValue(newDrunkReductionValue * 4)` — the player sobers up four times faster than vanilla
- Source behavior (B42 server):
  - `SWIronLiver()`: reads `CharacterStat.INTOXICATION`; if > 20, removes 1.0 intoxication per tick and calls `player:setSleepingTabletEffect(0)`
- Source description (EN): "Stays drunk for less time and doesn't get fatigue from alcohol."
- Source cost: 3; mutually exclusive with SWDrunkard

## Current UT Evidence

### Structure

- Registered in registries.lua: unknown (not checked — registries.lua not searched; trait appears in `test/run_tests.lua` Phase 2 batch list at line 276, which confirms it is a known trait id)
- Defined in UT_character_traits.txt: yes — lines 1558–1566
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_ironliver`
  - `Cost = 3`
  - `UIName = UI_UT_ironliver`
  - `UIDescription = UI_UT_ironliverDesc`
- Translation strings present: yes — `UI_UT_ironliver = "Iron Liver"` and `UI_UT_ironliverDesc` both present in `media/lua/shared/Translate/EN/UI_EN.txt` (lines 485–486)
- Exclusions/grants correct: no mutual exclusion defined in UT_character_traits.txt block; source excluded SWDrunkard — UT_ironliver does not replicate this exclusion
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_ironliver.lua`

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_ironliver.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1558–1566)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 485–486)
  - `test/run_tests.lua` (line 276)
- Event registrations:
  - `Events.EveryOneMinute.Add(onEveryMinute)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)` — standard guard
- Runtime chain (plain language):
  1. Every real-world minute, fires `onEveryMinute`.
  2. Gets the local player; exits if no player.
  3. Checks if the player has `UniversalTraits:UT_ironliver`; exits if not.
  4. Reads current drunkenness via `stats:getDrunkenness()`.
  5. If drunkenness > 0.1, multiplies it by 0.9 (reduces by 10%) and writes the new value back via `stats:setDrunkenness(...)`.
  6. Sets `player:getModData()["UT_drunkReductionApplied"] = true` as a marker.
- Actual behavior (exact values):
  - Drunkenness reduction: ×0.9 per real-world minute while drunkenness > 0.1 (geometric decay — each minute removes 10% of whatever remains)
  - Floor: reduction stops when drunkenness reaches 0.1 or below (the trait does not force drunkenness to zero)
  - No sleeping-tablet suppression (present in source, absent in UT)
  - No anti-fatigue mechanic (referenced in source description and translations, absent in UT)

## Description Integrity

- Display name check: "Iron Liver" — matches source exactly; appropriate
- Description check (full text): "Alcohol affects you about as much as water. Each real-world minute, drunkenness above 0.1 is reduced by 10% (multiplied by ×0.9)."
- Accuracy of description:
  - "Each real-world minute, drunkenness above 0.1 is reduced by 10% (multiplied by ×0.9)" — technically accurate; the ×0.9 parenthetical correctly describes the multiplicative decay
  - "Alcohol affects you about as much as water" — misleading; the trait only accelerates sobering (10%/min geometric decay); it does not suppress drunkenness from accruing, nor does it nullify alcohol's effects while drunk
- Missing or misleading details:
  - The description implies near-immunity to alcohol ("as much as water"), but the runtime only applies a slow geometric drain on an already-existing drunkenness value
  - The floor at 0.1 means the player can remain slightly drunk indefinitely; the description does not acknowledge this
  - The source trait also suppressed the sleeping-tablet sedation effect and prevented alcohol fatigue — neither is implemented in UT; the UT description makes no claim about fatigue, which is good, but the "as much as water" framing overstates the immunity
  - `UT_drunkReductionApplied` modData flag is written but never used within this file; its downstream consumer (if any) is unknown

## Balance Review

- Upside: Geometric 10% drunkenness drain per real-world minute; passive and always-on while drunk
- Downside: none (positive trait with no penalty)
- Uptime: Active only when drunkenness > 0.1; dormant otherwise
- Magnitude assessment:
  - At drunkenness = 1.0: after 10 minutes → 0.9^10 ≈ 0.35; after 20 minutes → 0.9^20 ≈ 0.12; after 22 minutes → just below 0.1 floor and decay stops. Sobering is notably faster than vanilla but not instant.
  - Compare to source SomewhatTraits: source applied ×4 to the continuous vanilla drunk-reduction rate (per tick); UT instead fires once per real-world minute and applies a fixed 10% geometric step. These are different cadences with broadly similar orders of magnitude, but UT's approach is tick-independent and clock-based.
- Peer comparison: No directly comparable UT trait in Phase 2 — Item/Consumption batch. The only other member, UT_durability, is a separate mechanic. Source SWDrunkard was the natural counterpart (slow to sober, 0.25× reduction rate); UT_ironliver has no mutual exclusion with any negative drinking trait in UT.
- Stack or exclusion notes: No mutual exclusion defined. A player could theoretically combine UT_ironliver with any other trait. The absence of a mutual exclusion with UT_durability or a hypothetical UT_drunkard equivalent is a design gap inherited from the UT definition block.
- Cost verdict: 3 points is justified — the effect is meaningful (roughly halves sobering time over 20 minutes) and matches the source cost, but the "water" framing in the description exaggerates the power of the trait.

## Regression Proof

- Existing test: `run_tests.lua` line 276 lists `"UniversalTraits:UT_ironliver"` in the Phase 2 — Item/Consumption batch array. This is an existence/registration check only — it confirms the trait id is known to the test suite but does not exercise the runtime logic.
- What it proves: The trait id string is present in the batch list; no behavioral coverage
- Missing proof:
  - No test verifies that drunkenness is reduced by ×0.9 per minute when above 0.1
  - No test verifies that drunkenness at exactly 0.1 or below is left unchanged (floor behavior)
  - No test verifies that `UT_drunkReductionApplied` modData flag is written on a reduction tick
  - No test verifies that the event handler exits cleanly when drunkenness is 0 (no player, or no trait)
- Minimum next test if needed: Construct a mock player with `UT_ironliver`, set drunkenness to 0.5, fire `Events.EveryOneMinute`, assert drunkenness equals 0.45. Add a second case with drunkenness = 0.05 and assert it is unchanged after firing.

## Final Verdict

- Source origin: proven — SomewhatTraits SWIronLiver confirmed in script definitions, EN translations, and runtime (both legacy client and B42 server versions)
- UT implementation: drifted — source used a per-tick drunk-reduction multiplier (×4 vanilla rate) plus sleeping-tablet suppression; UT replaces this with a once-per-real-world-minute geometric ×0.9 step and drops the sleeping-tablet mechanic entirely. The net effect is directionally the same (faster sobering) but the mechanism, cadence, and secondary effects differ materially.
- Description: partially accurate but overstated — the ×0.9 per minute detail is correct; the "as much as water" framing overclaims immunity to alcohol and should be revised to describe accelerated sobering
- Balance: justified — 3 points for a passive sobering accelerator with no downside is reasonable; however, the missing mutual exclusion with any heavy-drinker negative trait (as existed in source with SWDrunkard) is a gap
- Regression proof: not protected — only an id-presence check exists; no behavioral test covers the core drunkenness reduction logic
- Action needed: doc fix + test fix + design gap
- Open gaps:
  - Rewrite `UI_UT_ironliverDesc` to replace "affects you about as much as water" with accurate language (e.g., "Sobers up ~10% faster per real-world minute while drunk; reduction stops below 0.1 drunkenness")
  - Determine whether `UT_drunkReductionApplied` modData flag has any downstream reader; if not, remove the write or document its intended purpose
  - Consider adding a mutual exclusion against a complementary negative drinking trait (mirrors source SWDrunkard exclusion)
  - Add behavioral tests: drunkenness-above-threshold reduction, at-threshold no-op, and modData flag write
  - Confirm whether `DisabledInMultiplayer = true` is intentional given the trait uses `getPlayer()` (single-player API) rather than a player-parameter event — this is consistent, but the flag should be reviewed if multiplayer support is ever desired
