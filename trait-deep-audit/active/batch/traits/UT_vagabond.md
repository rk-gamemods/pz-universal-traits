# UT_vagabond

## Trait Summary

- UT trait id: `UniversalTraits:UT_vagabond`
- Source mod: MoreTraits
- Source trait id: `ToadTraits:vagabond` (`vagabond`)
- Current cost: 3
- Scripted: yes
- Owner: agent
- Status: complete

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (lines 214-217) — source trait definition and conditional `Scavenging` XP boost
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/MoreTraits .lua` (lines 1348-1444) — live Vagabond runtime
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/lua/shared/Translate/EN/UI.json` (lines 166-167) — player-facing source text
- Source trigger path:
  - Source runtime is `ToadTraitVagabond(page, player)` inside MoreTraits' inventory-page refresh logic.
  - It scans `page.backpacks`, gets each container's parent object, and only runs on containers whose type is exactly `"bin"`.
- Source behavior:
  - Cost is 3.
  - Source text: `"You tend to find more food items in garbage containers. Chance affected by luck. +1 Scavenging if Scavenging Skill mod enabled"`.
  - If the player has Vagabond, each previously unrolled garbage bin gets marked immediately with `bVagbondRolled = true` on the container object's modData.
  - Base chance is `33`, increased by Lucky and decreased by Unlucky.
  - The source performs multiple food-roll attempts per bin: `iterations = ZombRand(0, 3) + extra`, where sandbox default `extra` is `1`.
  - Each successful roll adds one random food item from a large garbage-food table.
  - If the optional Scavenging Skill mod is active, the trait also grants `Perks.Scavenging +1`.

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — `UTTraitsRegistries.UT_vagabond = CharacterTrait.register("UniversalTraits:UT_vagabond")` at `UniversalTraits/media/registries.lua` line 101.
- Defined in UT_character_traits.txt: yes —
  ```
  character_trait_definition UniversalTraits:UT_vagabond
  {
      IsProfessionTrait = false,
      DisabledInMultiplayer = true,
      CharacterTrait = UniversalTraits:UT_vagabond,
      Cost = 3,
      UIName = UI_UT_vagabond,
      UIDescription = UI_UT_vagabondDesc,
  }
  ```
  at `UniversalTraits/media/scripts/UT_character_traits.txt` lines 775-783.
- Translation strings present: yes — `UI_UT_vagabond = "Vagabond"` and `UI_UT_vagabondDesc = "A life on the road taught you where to look and what to grab. Chance to find a bonus useful item when looting containers and corpses."` at `UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` lines 224-225.
- Exclusions/grants correct: N/A — no UT exclusions or grants are declared for this trait.
- Runtime Lua file exists: yes — `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_vagabond.lua`

### Runtime Trace

- Files reviewed:
  - `UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_vagabond.lua` (entire file)
  - `UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` — `UTCore.hasTrait`
  - `UniversalTraits/test/run_tests.lua` (lines 678-765) — existing helper-level regression tests
- Event registrations:
  - `Events.OnRefreshInventoryWindowContainers.Add(handleContainerInspect)` when that event exists
- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` only
- Runtime chain (plain language):
  1. `UT_vagabond.lua` defines `handleContainerInspect(player, container)` and registers it directly to `OnRefreshInventoryWindowContainers`.
  2. The handler exits if there is no player or the player lacks `UniversalTraits:UT_vagabond`.
  3. It builds a container key from `container:getObject():getUniqueId()` when available, otherwise `tostring(container)`.
  4. It checks player modData key `UT_vagabond_looted_<containerKey>`.
  5. If that key is already true, it does nothing.
  6. Otherwise it rolls `ZombRand(100) < 33`.
  7. On success it adds exactly one random item from the UT loot table to the container and then sets the player modData looted key to true.
  8. On failure it does not mark the container, so future inspections can reroll it.
- Actual behavior (exact values):
  - **Trigger:** inventory-window container refresh event; exact corpse coverage is not fully proven from static review.
  - **Chance:** flat `33%` per eligible refresh.
  - **Loot count per success:** exactly `1` item.
  - **UT loot table (9 items):** `Base.Tuna`, `Base.BakedBeans`, `Base.SoupCan`, `Base.Socks`, `Base.Tshirt`, `Base.RoadMap1`, `Base.RoadMap2`, `Base.Screwdriver`, `Base.WoodGlue`.
  - **Marking rule:** marked only after a success, not after the first attempt.
  - **Persistence:** the looted state is stored on `player:getModData()`, so successful marks persist with the character across save/load unless cleared elsewhere.
  - **No luck scaling exists in UT.**
  - **No Scavenging XP boost exists in UT.**
  - **No container-type restriction exists in UT code.** Unlike the source, the UT handler does not check for `bin` containers.

## Description Integrity

- Display name check: `Vagabond` matches source intent.
- Description check: UT text is only partially honest.
- Missing or misleading details:
  1. **Missing exact odds:** the real mechanic is a flat `33%` roll, but the description only says `chance`.
  2. **Missing one-item limit:** UT gives exactly one bonus item on success, not a vague amount.
  3. **Missing reroll behavior:** failed attempts do not consume the container; the same container can be retried until a success occurs.
  4. **Scope drift hidden:** source behavior was specifically garbage-bin food scavenging; UT code has no bin-only restriction and uses a mixed utility loot table instead.
  5. **Corpse claim not fully proven:** the text says `containers and corpses`, but the UT code does not explicitly mention corpses; that depends on what `OnRefreshInventoryWindowContainers` passes at runtime.
  6. **Source drift omitted:** source luck interaction and optional `+1 Scavenging` are gone, but the description does not signal the redesign.

## Balance Review

- Upside:
  - Repeated free-item generation tied to container inspection.
  - Because failed rolls are not consumed, many containers can be reopened until they eventually pay out.
  - Potentially broader than source if the event really covers all normal containers and corpses rather than only bins.
- Downside:
  - None beyond the 3-point positive-trait cost.
- Uptime:
  - Potentially high over a full run if players repeatedly inspect the same containers after failed rolls.
  - Exact real uptime depends on how often `OnRefreshInventoryWindowContainers` fires for the same target and whether corpse inventories participate.
- Peer comparison:
  - Source counterpart also cost 3, but source limited the effect to garbage bins, food items, luck-adjusted odds, and one first-roll opportunity per bin.
  - UT removes the optional Scavenging XP bonus, but in exchange appears much broader and more abusable because it is not bin-restricted and failed rolls are reusable.
- Stack or exclusion notes:
  - No exclusion issue found.
  - Trait strength may stack naturally with any playstyle that repeatedly refreshes loot windows.
- Cost verdict: **questionable** — if the event truly applies broadly, UT's retry-until-success behavior likely makes this stronger than the source 3-point version despite losing the optional Scavenging XP bonus.

## Regression Proof

- Existing test: yes — `UniversalTraits/test/run_tests.lua` lines 678-765.
- What it proves:
  - Successful roll adds one item from the UT loot table.
  - Successful roll marks the container as looted.
  - Already-looted containers are skipped.
  - Players without the trait are skipped.
  - Failed rolls do not mark the container.
- Missing proof:
  - No proof that `Events.OnRefreshInventoryWindowContainers` calls the handler with the expected `(player, container)` signature in live PZ.
  - No proof for actual corpse coverage.
  - No proof for unique-id vs fallback `tostring(container)` persistence across save/load boundaries.
  - No proof th
