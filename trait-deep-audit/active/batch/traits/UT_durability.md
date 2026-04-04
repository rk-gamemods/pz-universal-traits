# UT_durability

## Trait Summary

- UT trait id: UT_durability
- Source mod: More Simple Traits (Hea) — also integrated into Dynamic Traits Expanded Moodles (DTEM)
- Source trait id: `Durabile` (MST / DTEM use bare string key, no namespace prefix)
- Current cost: 3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/NPCs/MSTMainCreationMethods.lua` (trait registration)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/client/MSTPerksByLevel.lua` (dynamic unlock trigger)
  - `research/installed-mods/MoreSimpleTraits/mods/MoreSimpleTraits/media/lua/shared/Translate/EN/UI_EN.txt` (translation)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/42.0/media/lua/client/DTEMByPerkLevel.lua` (DTEM integration — `DTEMaddDurabileTrait`)
  - `research/installed-mods/DynamicTraitsExpandedMoodles/mods/Dynamic-Traits-main/changes.txt` (attribution note)
- Source registration:
  - MST registers `Durabile` via `TraitFactory.addTrait("Durabile", ..., 3, ...)` with `durabile:addXPBoost(Perks.Maintenance, 1)`. Cost is 3. The trait grants +1 to Maintenance XP rate.
  - MST dynamically awards the trait to any player who reaches Maintenance level 6: `if perkLevel >= 6 and not player:HasTrait("Durabile") then player:getTraits():add("Durabile")` (MSTPerksByLevel.lua line 184).
  - DTEM integrates the same unlock via `DTEMaddDurabileTrait(player, maintenanceExpectedLevel)`, which checks `Perks.Maintenance >= threshold` and calls `player:getTraits():add("Durabile")` plus `DTEMapplyXPBoost(player, Perks.Maintenance, 1)`. Thresholds across DTEM difficulty presets vary between level 4 and level 7.
- Source translation: `UI_trait_durabile = "Durability"` and `UI_trait_durabiledesc = ""` (empty description in source).
- Source behavior: The source trait is a pure XP-boost trait — it grants +1 to Maintenance XP gain. The name "Durability" and the trait being gated behind Maintenance skill implies a narrative connection to gear care, but the source mechanic is entirely an XP multiplier on Maintenance, not an item degradation modifier. The source description is blank; no explicit degradation slowdown is stated.
- Source cost: 3 points (consistent across MST, MST Mini, MST Vanilla, and DTEM).

## Current UT Evidence

### Structure

- Registered in run_tests.lua trait list: yes — line 276 (`"UniversalTraits:UT_durability"`, grouped under Phase 2 — Item / Consumption)
- Defined in UT_character_traits.txt: yes — lines 1568–1576
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `Cost = 3`
  - `UIName = UI_UT_durability`
  - `UIDescription = UI_UT_durabilityDesc`
  - No `MutuallyExclusiveTraits` field
- Translation strings present: yes
  - `UI_UT_durability = "Durability"` (line 488)
  - `UI_UT_durabilityDesc = "You treat your gear with care and know how to make it last. Items you use degrade 25% slower (durability multiplier: ×1.25)."` (line 489)
- Exclusions/grants: none declared
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_durability.lua`

### Runtime Trace

- Files reviewed:
  - `media/lua/shared/UniversalTraits/traits/UT_durability.lua`
  - `media/scripts/UT_character_traits.txt` (lines 1568–1576)
  - `media/lua/shared/Translate/EN/UI_EN.txt` (lines 488–489)
  - `test/run_tests.lua` (line 276)
- Event registrations: `Events.OnNewGame.Add(onNewGame)`
- UT_CORE hooks used: `UTCore.hasTrait(player, TRAIT_ID)`
- Runtime chain (plain language): On new game start, `onNewGame` fires. It checks whether the player has `UniversalTraits:UT_durability`. If yes, it writes the value `1.25` into `player:getModData()["UT_itemDurabilityMult"]`. That mod-data key is subsequently read by UT's item degradation interception layer to slow item wear.
- Actual behavior (exact values): Stores `UT_itemDurabilityMult = 1.25` in player mod data. By UT convention, a multiplier above 1.0 on this key means items last proportionally longer — in this case 25% slower degradation. The effect is permanent for the life of that save (set once on `OnNewGame`). No per-tick recalculation, no conditions, no randomness.

## Description Integrity

- Display name check: "Durability" — matches source name exactly and is unambiguous.
- Description check: "You treat your gear with care and know how to make it last. Items you use degrade 25% slower (durability multiplier: ×1.25)." — The 25% figure and the ×1.25 multiplier match the code exactly (`player:getModData()["UT_itemDurabilityMult"] = 1.25`). The parenthetical multiplier notation is transparent and correct.
- Missing or misleading details: None. The description does not mention the source's original XP-boost mechanic, but UT replaced that mechanic entirely with an item degradation system, so the omission is correct. The description does not mention the multiplayer restriction (`DisabledInMultiplayer = true`); this is acceptable per UT convention. The flavor text ("treat your gear with care") is thematically appropriate to both the name and the new mechanic.
- Divergence from source: The UT implementation substitutes a flat item-durability multiplier for the source's Maintenance XP boost. This is a deliberate mechanical redesign — the source name "Durability" did not match its XP-boost mechanic well; UT corrects that mismatch by implementing actual durability reduction. The cost of 3 is preserved from source.

## Balance Review

- Upside: All items used by the player degrade 25% slower, unconditionally, from the start of the game onward. This is a broad, always-active benefit applying to weapons, tools, and any other items routed through the UT degradation layer.
- Downside: None. Pure positive trait.
- Uptime: 100% — permanent from new-game initialization, no conditions, no cooldown, no resource cost.
- Peer comparison:
  - Source `Durabile` (cost 3): granted +1 Maintenance XP boost. In UT, Maintenance XP boosts of +1 are typically valued at 1–3 points depending on the context (see `UT_ironliver` neighbor at cost 3).
  - The UT redesign swaps an XP boost for an item-preservation multiplier. A permanent, unconditional 25% degradation reduction is qualitatively more impactful than a skill XP modifier — it directly extends the lifespan of every item the player uses with no skill dependency.
  - Cost of 3 is on the low end for a permanent, broad, unconditional item-preservation benefit.
- Stack or exclusion notes: No mutual exclusions declared. Can stack with any other UT trait. No anti-stack logic in the runtime code.
- Cost verdict: potentially underpriced — 3 points for a permanent, unconditional, broad 25% item degradation reduction is low. The source mechanic (XP boost) justified 3 points; the UT replacement mechanic (item preservation) is arguably stronger. However, without knowing the full UT economy and whether other item-affecting traits exist at similar costs, this is a flag rather than a definitive finding.

## Regression Proof

- Existing test: `UT_durability` appears in the registration smoke-test trait list at line 276 of `test/run_tests.lua`. This confirms the trait ID is recognized by the registry at test time.
- What it proves: The trait ID `UniversalTraits:UT_durability` is present in the UT trait registry. The test will fail if the trait is removed or misspelled.
- Missing proof:
  - No test verifies that `onNewGame` fires and writes `UT_itemDurabilityMult` into mod data.
  - No test asserts the exact value `1.25`.
  - No test verifies the cost is 3 (cost assertion by name is not visible in the examined test context for this trait).
  - No integration test confirms that item degradation is actually reduced in a game session.
- Minimum next test if needed: `assert_eq(p:getModData()["UT_itemDurabilityMult"], 1.25, "durability mult exact value")` — pin the exact multiplier so a regression is caught if the constant changes.

## Final Verdict

- Source origin: proven — `Durabile` from More Simple Traits (Hea); cost of 3 and display name "Durability" both match. DTEM independently confirms the trait's existence and Maintenance-skill association.
- UT implementation: redesigned — source used a `+1 Maintenance XP boost`; UT replaces this with a flat `UT_itemDurabilityMult = 1.25` item-degradation multiplier. The redesign is intentional and thematically superior (the name "Durability" now describes the actual mechanic). The cost of 3 is preserved from source.
- Description: accurate — the display name, the 25% figure, and the ×1.25 multiplier all match the code exactly. No misleading language.
- Balance: potentially underpriced — 3 points for a permanent, unconditional, broad 25% item-preservation benefit is low relative to the redesigned mechanic's actual value. The source cost was calibrated to an XP boost, not to item longevity. Flag for review.
- Regression proof: minimally protected — only a registry smoke test exists. No behavioral assertion for `UT_itemDurabilityMult` is present.
- Action needed: two items —
  1. (test fix) Add exact-value assertion for `UT_itemDurabilityMult = 1.25`.
  2. (balance review) Evaluate whether cost 3 remains appropriate for a permanent 25% item-degradation reduction given the full UT trait economy; consider whether cost 4 or 5 is more defensible.
- Open gaps:
  - No behavioral test for `UT_itemDurabilityMult` write on `OnNewGame`.
  - No exact-value assertion for the `1.25` constant.
  - Cost of 3 was inherited from a weaker source mechanic; the redesigned mechanic may warrant repricing.
  - Source description was blank (`UI_trait_durabiledesc = ""`); UT adds a substantive description, which is an improvement.
  - No mutual exclusion with any opposing trait (e.g., a hypothetical "fragile" negative trait). No peer negative exists in UT at time of audit, so this is not a gap but is noted for completeness.
