# UT_gourmand

## Trait Summary

- Exact trait id: `UniversalTraits:UT_gourmand`
- Batch: `batch_04`
- Cost: 4
- Status: accepted static/unit repair with live proof retained
- Accepted implementation: `984ec687b4096d57296bfee1cbc2872e83e31215`
- Accepted parent: `914efed64ed0d8af7e75d61ddb5df9331c96dbc1`
- PZ static authority: SVN revision 964

## Honest Pre-Campaign Intent

Gourmand provides exactly 50 percent extra beneficial hunger, boredom, and
unhappiness relief proportional to what native consumption actually changed.
It does not amplify harmful changes. The accepted repair preserves this
behavior and does not add the broader historical MoreTraits cooking,
freshness, temperature, or secondary-stat mechanics.

The English contract is:

> Food is one of life's great pleasures. Each meal grants +50 percent bonus
> hunger relief and reduces boredom and unhappiness by the same proportion.

## Accepted Runtime Contract

The shared consumption hook snapshots the current eater's hunger, boredom, and
unhappiness before native consumption. It runs the native action exactly once,
then adds half of each actual beneficial relief delta.

- Completed meals follow SVN 964 `ISEatFoodAction.complete`.
- Interrupted partial consumption follows SVN 964 `ISEatFoodAction.eat`.
- Repeated bites are evaluated independently without compounding.
- Trait state is evaluated on the current eater.
- Food objects and food modData remain unchanged.
- Player modData stores no Gourmand baseline or lifecycle state.
- Trait removal, transfer, replacement, death-like replacement, and save-load
  replacement do not depend on stale persistent state.
- Duplicate module evaluation remains single-application.
- Snapshot failure or a missing player cannot block native consumption.
- The obsolete inventory poll and retained Gourmand tick handler are absent.

## Accepted Evidence

- Focused Gourmand cases: 11/11
- Full UniversalTraits suite: 576/576
- Gourmand trait source/release pair: byte-identical
- Shared consumption hook source/release pair: byte-identical
- Independent review: ACCEPT at `984ec687`

The full 576/576 result is retained from the accepted repair and is not rerun
for this campaign-only cascade.

## Campaign Finding Disposition

- `B04-gourmand-RESET`: close from current static/unit evidence. The old
  item-mutation and stale-baseline mechanism no longer exists.
- `B04-gourmand-RUNTIME`: keep open as runtime-unproven. Static tracing and
  standard-Lua tests do not establish live B42 execution.
- `XTF0104-FOOD-ITEM-MUTATION`: remove only Gourmand from exact affected
  membership. Keep the finding open for Gordanite.
- `IR0104-GOURMAND-RECIPROCAL-EXCLUSION`: close from exact current
  definition/test evidence without changing trait semantics.

## Retained Open Proof

- actual B42/Kahlua completed and interrupted action execution
- full desktop relaunch and current-version save-load observation
- gameplay balance session
- profiler/performance capture
- non-English localization, if required
- package and live deployment
- missing root `poster.png`

No deployment, live-mod write, index mutation, PZCodebase change, runtime
process change, or remote operation belongs to this evidence cascade.
