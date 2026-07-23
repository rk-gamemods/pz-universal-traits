# Wildsman deep audit

## Scope and authority

- Trait: `UniversalTraits:UT_wildsman`
- Accepted behavior baseline: pre-campaign `master`
- Engine baseline: PZCodebase SVN 964, Steam BuildID 23504596
- Product scope: single-player, current `42.0` package only
- Explicit non-goals: multiplayer, backward save migration, deployment

## Accepted contract

- Display name: Wildsman
- Cost: 4
- XP boosts: Plant Scavenging +1 and Fishing +1
- Grants: none
- Exclusions: none
- Multiplayer: disabled
- Foraging: 30 percent more item yield
- Fishing: caught fish are 50 percent larger, with the corresponding 50 percent increases to weight, hunger restoration, and nutrition

The corrected implementation preserves this net outcome. It does not restore the
larger current More Traits trait, which has a different cost, skill package,
recipes, and forage-visibility bonuses.

## Pre-campaign failure

`master` wrote `UT_wildsmanForageBoost = 1.3` and
`UT_wildsmanFishSizeBoost = 1.5` to player modData, but no UTMods code read either
value. It also attempted to mark caught fish through `Events.OnFishCaught`, an
event absent from the current engine. The shared food hook could consume
`UT_wildsmanFishHungerMult`, but the dead event was its only producer.

The inherited development checkpoint correctly replaced the dead fishing event
with a wrapper around `Fishing.Fish:createFish`, but it still had two defects:

1. No code implemented the promised foraging yield.
2. The fish wrapper called `InventoryItem:getWorldScale()`, which SVN 964 does
   not expose.

## Current foraging trace

1. `ISForageIcon:new` assigns the current character and forage definition.
2. `ISForageIcon:initialise` calls `ISBaseIcon:initItemCount`.
3. Vanilla `initItemCount` produces the integer count from `minCount` and
   `maxCount`.
4. `ISBaseIcon:getItemList` creates exactly `itemCount` item instances.
5. The Wildsman wrapper calls vanilla once, checks the live character trait,
   then applies the 1.3 multiplier at that exact integer-count boundary.

An integer result cannot represent every 1.3 multiplication exactly. The whole
part is guaranteed and the fractional part is an exact percentage roll. A base
count of 1 therefore yields 1 item plus a 30 percent chance of one more. A base
count of 4 yields 5 items plus a 20 percent chance of a sixth. A base count of
10 yields exactly 13 without a random roll. This preserves an exact 30 percent
expected yield without systematically rounding the effect away or inflating it.

## Current fishing trace

1. `Fishing.Fish:createFish` selects the fish size and creates the item.
2. Vanilla derives nutrition and hunger from fish weight.
3. Vanilla calls `setWorldScale(fishSizeData.length / 100.0)`.
4. Vanilla stores the same length in `item:getModData().fishing_FishSize`, sets
   `Fish.fishSize` and `Fish.fishSizeLen`, and returns the item.
5. The Wildsman wrapper receives that exact result and checks the live fishing
   character.
6. It multiplies calories, lipids, carbohydrates, proteins, base hunger,
   current hunger change, actual weight, stored length, and both Fish length
   fields by 1.5.
7. It derives world scale from the scaled stored length divided by 100, matching
   vanilla's formula without calling a nonexistent getter.
8. `UT_wildsmanFishScaled` prevents a second path from scaling the same item.
9. The original item is returned unchanged as the object identity used by fish
   pickup and inventory insertion.

`InventoryItem.java` exposes `setWorldScale(float)` but no InventoryItem
`getWorldScale()` method. Other `getWorldScale` methods belong to the world-map
renderer and are unrelated.

## Lifecycle and performance

One installer runs when the trait module loads and is retried once through
`OnGameStart` for class load order. A trait-local sentinel prevents duplicate
event registration. Each class stores its original method and rejects duplicate
wrapping.

There is no polling loop, player-update handler, object scan, or background
work. The forage wrapper adds constant work to the existing item-count call.
The fishing wrapper adds constant work only when a fish item is constructed.

## Regression evidence

The focused harness initially produced 0 passed and 4 failed:

- duplicate unused `OnNewGame` registrations;
- no forage-yield change;
- a missing `getWorldScale` crash on an ordinary caught fish;
- the same crash before same-item deduplication could be proven.

After correction, all 4 focused cases pass. They prove reload safety, exact
integer and fractional yield boundaries, no random roll for exact or control
counts, vanilla count execution exactly once, no-trait behavior, a current fish
surface with no world-scale getter, every 1.5 fish field, original object
identity, and same-item deduplication.

The complete UniversalTraits standard-Lua suite exits successfully after the
focused module is included. Source and `42.0` release Wildsman runtime files are
byte-identical.

## Remaining runtime proof

- Current-build Kahlua execution
- A live forage discovery at representative one-item and multi-item counts
- A live caught fish through pickup and consumption
- New game, full exit, save load, death, and repeated world entry
- Interaction with other forage and food traits in the target playset
- Rendered English, balance telemetry, and profiler capture

These are runtime evidence requirements, not unresolved static defects.
