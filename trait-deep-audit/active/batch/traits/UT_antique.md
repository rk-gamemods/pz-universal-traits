# Antique Enthusiast Deep Trace

## Contract

- Trait ID: `UniversalTraits:UT_antique`
- Display name: `Antique Enthusiast`
- Pre-campaign authority: UTMods `master`
- Cost: `6`
- XP boosts: none
- Granted traits: none
- Exclusions: none
- Multiplayer: disabled, with multiplayer support outside product scope
- Intended result: each eligible crate or metal shelf gets one `8 / 1000` chance per configured loot-respawn cycle to receive one uniformly selected item from the seven-item Antique reward table.

The current port deliberately uses a fixed seven-item reward table and fixed 0.8 percent chance. The larger historical More Traits table and its luck, dexterity, and sandbox-option modifiers are provenance only. They are not authority for changing the accepted UTMods behavior.

## Proven Failure

Pre-campaign `master` registered `onContainerUpdate(inventoryPage, state, player)` directly with `OnRefreshInventoryWindowContainers`. Current `ISInventoryPage.refreshBackpacks` emits only `(self, state)`. The third argument is therefore `nil`, so the first trait check rejects every real event before Antique can inspect a container.

The same handler called `inventoryPage.backpacks:size()` and `:get(index)`. Current `ISInventoryPage.addContainerButton` stores buttons with `self.backpacks[c] = button`, and vanilla traverses the collection with `ipairs`. It is a 1-based Lua table, not a Java list. Passing a synthetic third player argument in a mock would still leave the real Kahlua callback unable to traverse the collection.

The historical More Traits implementation confirms how this port lost the contract. Its `ContainerEvents(inventoryPage, state)` wrapper waited for `state == "end"`, resolved the player, and then called `ToadTraitAntique(page, state, player)`, whose backpack loop used `ipairs`. The UT port copied the inner handler but omitted the wrapper and replaced the Lua-table loop with Java-list operations.

## Corrected Runtime Trace

1. Project Zomboid loads the shared Antique module.
2. A reload-safe sentinel registers exactly one handler with `Events.OnRefreshInventoryWindowContainers`.
3. `ISInventoryPage.refreshBackpacks` rebuilds the page's Lua `backpacks` table and emits `begin`, `beforeFloor`, `buttonsAdded`, and `end` phases with exactly `(inventoryPage, state)`.
4. Antique rejects every phase except `end`, so one completed refresh causes one bounded scan.
5. The handler resolves the local player with `getSpecificPlayer(inventoryPage.player)` and checks the exact namespaced trait through `UTCore.hasTrait`.
6. The handler traverses `inventoryPage.backpacks` with `ipairs` and follows each button's `inventory` to its parent world object.
7. It rejects missing parents, non-`IsoObject` parents, dead bodies, missing containers, and container types other than `crate` or `metal_shelves`.
8. The world object's persistent modData stores `UT_antiqueRolled` and `UT_antiqueChecked`.
9. A never-checked eligible container can roll immediately. A checked container can roll again only when LootRespawn mode 2, 3, 4, or 5 reaches exactly 24, 168, 720, or 1440 elapsed world hours. Mode 1 never reopens the roll.
10. Before random selection, the handler marks the cycle complete, records current world age, and transmits the object modData. Success or failure therefore consumes exactly one chance for that cycle.
11. `ZombRand(1000) < 8` makes values 0 through 7 succeed and values 8 through 999 fail.
12. A successful chance uses `ZombRand(7) + 1` to select one of the seven Lua-table entries uniformly.
13. `ItemContainer.AddItem(String)` resolves the exact script item through `ScriptManager`, creates it, assigns the container, appends it to the container items, schedules processing, flags the parent for hot save, and returns the new item.
14. If insertion succeeds, the verified global `sendAddItemToContainer(container, item)` surface is called. In the single-player product scope, its current Java implementation performs no network work because `GameServer.server` is false.

## Reward Resolution

The seven exact full types are:

- `UniversalTraits.AntiqueAxe`
- `UniversalTraits.AntiqueKatana`
- `UniversalTraits.AntiqueSpear`
- `UniversalTraits.AntiqueHammer`
- `UniversalTraits.AntiqueJacket`
- `UniversalTraits.AntiqueVest`
- `UniversalTraits.AntiqueBoots`

Every short name has one current definition in `UniversalTraits/media/scripts/UT_items.txt`, and the source and 42.0 release item-definition files are byte-identical. Boundary tests prove item roll 0 selects Antique Axe and item roll 6 selects Antique Boots. A missing or obsolete script item makes native `AddItem` return `nil`; the handler does not attempt to sync that result, while the completed container cycle remains marked.

## Source, Release, and Description

The source and 42.0 release runtime files are byte-identical after correction. Both use the current global `sendAddItemToContainer` API. The stale package finding described an earlier source/release split in which one copy called the removed `ItemContainer.addItemOnServer` method. That divergence no longer exists.

The current English text preserves the accepted contract and uses the translator-safe word `percent`:

`Your eye for rare and exceptional craftsmanship gives you a chance to find antique weapons and clothing hidden in crates and metal shelves. These items are significantly better than anything else you can find. Roughly 0.8 percent chance per eligible container, once per loot cycle.`

The definition and English source/release pairs are byte-identical. The trait remains cost 6, grants no XP or traits, has no exclusions, and is disabled in multiplayer.

## Engine Evidence

- `PZCodebase/Lua/client/ISUI/ISInventoryPage.lua:1461-1510` creates container buttons and appends them to a 1-based Lua `backpacks` table.
- `ISInventoryPage.lua:1560,1794,1801,1902` emits the four exact event phases with `(self, state)`.
- `ISInventoryPage.lua:1558` resolves the page player through `getSpecificPlayer(self.player)`.
- `PZCodebase/Java/source/zombie/inventory/ItemContainer.java:534-570` proves the string `AddItem` creation and insertion path.
- `PZCodebase/Java/source/zombie/Lua/LuaManager.java:10223-10230` exposes `sendAddItemToContainer` globally and gates network work on `GameServer.server`.
- Current `UT_items.txt` source and release define every reward full type.

## Regression Coverage

Focused tests prove:

- the producer emits exactly two arguments;
- only the `end` phase can inspect or roll;
- page-player resolution and trait gating;
- 1-based Lua backpack traversal;
- live `IsoObject`, dead-body, empty-list, and container-type boundaries;
- exact chance values 0, 7, 8, and 999;
- one chance per cycle after both success and failure;
- LootRespawn modes 1 through 5 and exact elapsed-hour boundaries;
- first and last reward selection;
- nil insertion handling;
- reload-safe single registration;
- exact cost, grants, XP, exclusions, multiplayer flag, English text, reward definitions, and source-release parity.

## Interactions and Performance

The handler performs no polling or background work. It scans the already bounded inventory-page button table once at the `end` of a refresh, then exits early for absent players, absent traits, ineligible objects, and closed cycles.

Scrounger and Vagabond also consume the inventory refresh event and use separate modData keys. No direct state overwrite exists. If multiple loot traits are selected, handler order can affect whether another trait sees an Antique item added during the same refresh. This existing additive interaction was not changed and remains runtime-unproven rather than being guessed away.

## Remaining Proof

- Full desktop relaunch with current-build Kahlua.
- A live eligible crate and metal shelf, including both a success and a failed cycle.
- Current-version save-load proof for the persistent container markers and exact respawn-hour reopening.
- Repeated world entry and repeated module-load observation.
- Multi-trait live interaction with Scrounger and Vagabond.
- Rendered English observation.
- Gameplay balance telemetry and profiler capture.
- Non-English localization remains absent across UniversalTraits.
- The separately tracked missing source poster remains a packaging gap.

Multiplayer, backward save migration, deployment, changing the cost, chance, reward table, eligible types, or loot-respawn mapping are explicit non-goals for this correction.
