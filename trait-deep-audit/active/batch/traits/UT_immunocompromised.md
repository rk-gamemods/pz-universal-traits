# UT_immunocompromised

## Trait Summary

- UT trait id: UT_immunocompromised
- Source mod: MoreTraits (ToadTraits)
- Source trait id: `ToadTraits:immunocompromised`
- Current cost: -6
- Scripted: yes
- Owner: agent
- Status: complete

---

## Source Evidence

- Source files reviewed:
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/scripts/ToadTraits.txt` (script definition, lines 393–404)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.15/media/scripts/ToadTraits.txt` (script definition, confirmed identical)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/Translate/EN/UI_EN.txt` (source EN strings, lines 129–130)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/MoreTraits .lua` (shared runtime, lines 2914–2935)
  - `research/installed-mods/MoreTraits/mods/More Traits/42/media/lua/client/MoreTraits .lua` (legacy client runtime, lines 2772–2791)
  - `research/installed-mods/MoreTraits/mods/More Traits/42.13/media/lua/shared/NPCs/MoreTraitsMainCreationMethods.lua` (NPC creation, lines 266, 382–383)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42/media/lua/client/MoreTraits - Dynamic.lua` (Dynamic submod client runtime, lines 728–744)
  - `research/installed-mods/MoreTraits/mods/More Traits - Dynamic/42.13/media/lua/shared/MoreTraits - Dynamic.lua` (Dynamic submod shared runtime, lines 856–910)
  - `research/installed-mods/EvolvingTraitsWorld/mods/Evolving Traits World - Mark Dynamic Traits/42/media/lua/shared/NPCs/ETWSubmodCreationMethods.lua` (ETW alt-name registration, line 110)

- Source script definition (ToadTraits:immunocompromised, 42.13):
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = false`
  - `CharacterTrait = ToadTraits:immunocompromised`
  - `Cost = -10`
  - `UIName = UI_trait_immunocompromised`
  - `UIDescription = UI_trait_immunocompromiseddesc`
  - `MutuallyExclusiveTraits = base:resilient;ToadTraits:superimmune`

- Source description (EN): "Your immune system is vulnerable to infection. Your wounds tend to become infected. You have a 25% greater chance to become zombified. Note: This trait will still let you be infected by zombie injuries, even if you disable transmission in the sandbox."

- Source cost: -10 (42.13 and 42.15)

- Source multiplayer flag: `DisabledInMultiplayer = false`

- Source mutual exclusion: `base:resilient` and `ToadTraits:superimmune`. NPC creation code also calls `TraitFactory.setMutualExclusive("Resilient", "immunocompromised")` and `TraitFactory.setMutualExclusive("superimmune", "immunocompromised")`, confirming the intent.

- Source behavior (legacy client, B42 "42" branch — `function Immunocompromised`):
  - Guard: player must have trait `"immunocompromised"` (bare string, pre-namespacing era).
  - Per body part: if the part `HasInjury()`, is `isInfectedWound()`, and `getAlcoholLevel() <= 0` (no alcohol/disinfectant applied), sets `b:setWoundInfectionLevel(b:getWoundInfectionLevel() + 0.001)` per tick.
  - No body-level `infectionLevel` manipulation; operates at per-wound level only.
  - No early exit on maximum infection; can increment indefinitely past 10.0 in the old branch (no cap guard in this version).

- Source behavior (42.13 shared runtime — `local function Immunocompromised(player)`):
  - Guard: player must have `ToadTraitsRegistries.immunocompromised`; early-exits if not. Early-exits if `not bodyDamage:HasInjury()`.
  - `infectionIncrease = 0.05` (hardcoded local).
  - Network branch: if `isClient()`, sends client command `'ToadTraits', 'Immunocompromised'` with `{infectionIncrease = 0.05}` payload to the server.
  - Server branch: iterates body parts; for each part where `infectionValue >= 10.0` it returns immediately; for infected wounds with no alcohol applied, calls `b:setWoundInfectionLevel(infectionValue + 0.05)`.
  - Cap guard: exits the entire function (not just the part) when any part reaches infectionLevel >= 10.0.
  - Still operates at per-wound level, not the body-level `getInfectionLevel()`.

- Source behavior (42.13 shared runtime — zombie-hit infection chance, lines 745–765):
  - On `PlayerHitReactionState`, if the player has `immunocompromised` and has not already tried the immuno roll in this event, iterates injured body parts not already in the infection list; reads `SandboxVars.MoreTraits.ImmunoChance` (default 25); if the body is not already infected and `ZombRand(1, 101) <= immunoChance`, marks the body part for infection. This gives a sandbox-configurable (default 25%) extra wound-infection chance on zombie hit.

- Source behavior (Dynamic submod — B42 legacy client, lines 728–744):
  - Every ten minutes: if `SandboxVars.MoreTraitsDynamic.ImmunocompromisedDynamic == true` and player has `"immunocompromised"` and does not have `"superimmune"`, iterates body parts; for infected wounds, increments `player:getModData().MoreTraitsDynamic.totalInfectionTime` by 1/6 (counting hours) per infected part per tick. When `totalInfectionTime >= SandboxVars.MoreTraitsDynamic.ImmunocompromisedDynamicInfectionTime`, removes `"immunocompromised"` from the player's traits (dynamic removal — the trait cures itself after enough cumulative infection hours). This is the Dynamic submod feature only; not part of the base mod.

- Source behavior (ETW): `altNames.immunocompromised = true` — the Evolving Traits World mod registers `immunocompromised` as a recognized alternate trait name for NPC trait handling. No additional gameplay effect.

---

## Current UT Evidence

### Structure

- Registered in registries.lua: yes — `UTTraitsRegistries.UT_immunocompromised = CharacterTrait.register("UniversalTraits:UT_immunocompromised")` at line 270, placed at the end of the Phase 3b — Periodic-Check block (between `UT_addictedtocaffeine` and the Phase 3c — Event-Driven comment).
- Defined in UT_character_traits.txt: yes — lines 1896–1905
  - `IsProfessionTrait = false`
  - `DisabledInMultiplayer = true`
  - `CharacterTrait = UniversalTraits:UT_immunocompromised`
  - `Cost = -6`
  - `UIName = UI_UT_immunocompromised`
  - `UIDescription = UI_UT_immunocompromisedDesc`
  - `MutuallyExclusiveTraits = UniversalTraits:UT_superimmune`
- Translation strings present: yes
  - `UI_UT_immunocompromised = "Immunocompromised"` (UI_EN.txt line 587)
  - `UI_UT_immunocompromisedDesc = "Your immune system is not up to the task. Infections take hold more easily and your body struggles to fight back."` (UI_EN.txt line 588)
- Mutual exclusion defined: yes — `UniversalTraits:UT_superimmune` only. Source also excluded `base:resilient`; UT drops that base-game exclusion.
- Runtime Lua file exists: yes — `media/lua/shared/UniversalTraits/traits/UT_immunocompromised.lua`

### Runtime Trace

- Files reviewed:
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/UniversalTraits/traits/UT_immunocompromised.lua` (full file, 27 lines)
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/scripts/UT_character_traits.txt` (lines 1896–1905)
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt` (lines 587–588)
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UniversalTraits/test/run_tests.lua` (lines 294, 470, 1097–1106)
  - `c:/Users/Admin/Documents/GIT/GameMods/PZMods/UTMods/UT_CORE/media/lua/shared/UTCore/UTCore_API.lua` (full file, `UTCore.hasTrait` at line 11)

- Event registrations:
  - `Events.OnNewGame.Add(onNewGame)`
  - `Events.EveryOneMinute.Add(onEveryOneMinute)`

- UT_CORE hooks used:
  - `UTCore.hasTrait(player, TRAIT_ID)` — standard nil-safe guard used in both `onNewGame` and `onEveryOneMinute`
  - `UTCore.hasTrait` implementation: checks `player ~= nil`, gets `player:getTraits()`, returns `traits:contains(traitId)`. No side-effects.

- Runtime chain (plain language):

  **`onNewGame(player)`** — fires once on new game start:
  1. Receives `player` as argument (passed by the `OnNewGame` event).
  2. Calls `UTCore.hasTrait(player, "UniversalTraits:UT_immunocompromised")`. Exits if false.
  3. Sets `player:getModData()["UT_immunocompromised"] = true`.
  4. Returns. No further action.

  **`onEveryOneMinute()`** — fires every in-game minute (no player argument passed by event):
  1. Calls `getPlayer()` to get the local player. Exits if nil.
  2. Calls `UTCore.hasTrait(player, "UniversalTraits:UT_immunocompromised")`. Exits if false.
  3. Calls `player:getBodyDamage()`. Stores as `bodyDamage`.
  4. Guard: if `bodyDamage` is nil, does nothing further (implicit — but `if bodyDamage then` is the gate).
  5. Calls `bodyDamage:getInfectionLevel()`. Stores as `infectionLevel`.
  6. Guard: if `infectionLevel` is nil or `infectionLevel <= 0`, does nothing further.
  7. Calls `bodyDamage:setInfectionLevel(math.min(1, infectionLevel + 0.01))`. This clamps the result at 1.0 maximum.
  8. Returns.

- Actual behavior (exact values):
  - ModData flag: `player:getModData()["UT_immunocompromised"] = true` stamped once on new game.
  - Infection increase: +0.01 body-level `infectionLevel` per in-game minute, while `infectionLevel > 0`. Capped at 1.0 (cannot exceed).
  - The increase fires only when there is already an active body-level infection (`infectionLevel > 0`); the trait does not initiate infection from zero.
  - No per-wound `getWoundInfectionLevel()` / `setWoundInfectionLevel()` manipulation (contrast with both source branches that operated at the per-wound level).
  - No zombie-hit infection chance bonus (contrast with source's `ImmunoChance` sandbox-configurable hit-roll).
  - No Dynamic submod curation-removal mechanic.
  - No stat changes (fatigue, endurance, Sickness moodle).
  - The handler uses the single-player `getPlayer()` API; correct given `DisabledInMultiplayer = true`.

---

## Description Integrity

- Display name check: "Immunocompromised" — exact match to source display name; accurate.
- Description check (full text): "Your immune system is not up to the task. Infections take hold more easily and your body struggles to fight back."
- Accuracy assessment:
  - "Infections take hold more easily" — partially misleading. The UT implementation does **not** make infections take hold more easily; it only accelerates an infection that is already present (`infectionLevel > 0`). The +0.01/minute increase makes an existing infection worsen faster, but the trait does nothing to initiate infection where there was none, and it does not raise wound infection rates (which is what the source's per-wound mechanic did). The phrase "take hold more easily" implies a higher chance of initial infection, which is not the UT mechanic.
  - "Your body struggles to fight back" — directionally accurate; the trait worsens the body-level infection level each minute, so the body's defenses are effectively reduced. The framing is correct as flavor but imprecise as a mechanical description.
  - The source description explicitly mentions "25% greater chance to become zombified" and "wounds tend to become infected" — both of these mechanics are absent from UT. Neither is mentioned in the UT description, so no false claim is made about absent features. However, the UT description implies ("take hold more easily") a higher initial infection chance that also does not exist.
  - Missing quantitative detail: no indication of the +0.01/minute escalation rate.
- Missing or misleading details:
  - The phrase "take hold more easily" implies a higher infection initiation chance (source mechanic) that UT does not implement.
  - The description omits the key condition that the effect only fires when `infectionLevel > 0` — the trait is passive until some other mechanism initiates infection.
  - No mention of the infection escalation rate (+0.01 per in-game minute, reaching 1.0 from 0.01 in ~100 minutes once infection is initiated by any other means).

---

## Balance Review

- Upside: none (negative trait)
- Downside: +0.01 body-level `infectionLevel` per in-game minute while infected; caps at 1.0. At `infectionLevel = 0.01` (infection just triggered), reaches 1.0 in ~99 in-game minutes (~1 hour 39 in-game minutes) without any counteracting trait. Against an untreated infection this is significantly faster escalation.
- Uptime: gated on `infectionLevel > 0`. The trait is inert when healthy or when infection has been cleared. The `EveryOneMinute` tick runs continuously but the write only occurs when the guard passes.
- Peer comparison:
  - `UT_superimmune` (Cost = +8, mutually exclusive with `UT_immunocompromised`): drains infectionLevel by −0.02 per in-game minute. This is the explicit mechanical counterpart, operating on the same `bodyDamage:getInfectionLevel()` / `setInfectionLevel()` API and at the same cadence. The two traits are symmetrical on this axis: superimmune drains 0.02/min, immunocompromised raises 0.01/min — the drain rate is 2× the aggravation rate on the same tick frequency.
  - `UT_immuneresponse` (Cost = +6, no mutual exclusion with `UT_immunocompromised`): drains infectionLevel by −0.03 per ten in-game minutes (−0.003/min effective). A player with both `UT_immunocompromised` (+0.01/min) and `UT_immuneresponse` (−0.003/min) would net +0.007/min — the immunocompromised effect dominates. No mutual exclusion blocks this pairing. Whether a player is expected to hold both simultaneously is a design gap (no exclusion documented, combination is mechanically coherent but probably unintended).
  - Source priced the trait at -10; UT prices at -6. UT provides a weaker implementation (no hit-roll infection bonus, no per-wound escalation, no Dynamic removal arc) at a less punishing cost point. Whether this reflects an intentional scope reduction or an underpriced stub is ambiguous without documentation.
- Source cost vs. UT cost: source -10 (with per-wound escalation + hit-roll infection bonus + multiplayer enabled + Dynamic submod removal arc); UT -6 (body-level escalation only, no hit-roll, multiplayer disabled, no removal arc). The cost reduction is plausibly justified by the narrowed scope, but is not documented.
- Multiplayer flag: source `DisabledInMultiplayer = false`; UT `DisabledInMultiplayer = true`. The `getPlayer()` single-player API used in `onEveryOneMinute` makes the multiplayer disable mechanically necessary for correctness.
- Source mutual exclusions dropped: source excluded `base:resilient` in addition to `ToadTraits:superimmune`. UT retains only the counterpart-trait exclusion (`UT_superimmune`). A player can combine `UT_immunocompromised` with vanilla `base:resilient` (which gives built-in infection resistance), partially negating the UT trait's downside. The source author explicitly blocked this.

---

## Regression Proof

- Existing tests:
  - `run_tests.lua` line 294: lists `"UniversalTraits:UT_immunocompromised"` in the Phase 3b — Periodic-Check batch array used by the all-traits registration sweep. Confirms the trait ID is registered and known.
  - `run_tests.lua` line 470: `dofile(base .. "../media/lua/shared/UniversalTraits/traits/UT_immunocompromised.lua")` — confirms the Lua file loads without parse error.
  - `run_tests.lua` lines 1097–1106: named behavioral test — "immunocompromised marks the trait and increases infection over time"
    - Calls `fireNewGame("UniversalTraits:UT_immunocompromised")` — constructs a player with the trait and fires `OnNewGame`.
    - Sets `player:getBodyDamage():setInfectionLevel(0.5)`.
    - Calls `withActivePlayer(player, function() Events.EveryOneMinute:fire() end)`.
    - Asserts `player:getModData()["UT_immunocompromised"] == true` — confirms the modData flag is set by `onNewGame`.
    - Asserts `math.abs(player:getBodyDamage():getInfectionLevel() - 0.51) < 0.0001` — confirms the +0.01 increase per fire at infectionLevel = 0.5 is arithmetically correct.

- What it proves: the modData flag is stamped on new game; the per-minute escalation of +0.01 is arithmetically correct for a single fire with infectionLevel = 0.5 (non-zero, non-cap).

- Missing proof:
  - No test verifies the cap behavior: at `infectionLevel = 0.995`, the result should be `math.min(1, 1.005) = 1.0`, not 1.005. The `math.min(1, ...)` guard is present in code but untested.
  - No test verifies the `> 0` guard: when `infectionLevel` is exactly 0, no increase should occur. The guard is `infectionLevel and infectionLevel > 0`; at 0 this correctly exits, but it is untested.
  - No test verifies the nil guard on `getInfectionLevel()`: if `getInfectionLevel()` returns nil (mocked), the handler should exit cleanly without error.
  - No test verifies that the handler exits cleanly when the player does not have the trait (infectionLevel unchanged).
  - No test verifies that `onEveryOneMinute` does nothing when `getPlayer()` returns nil.
  - No test exercises multiple consecutive fires to confirm accumulation over time.

- Minimum next tests if needed:
  1. MockPlayer with `UT_immunocompromised`, `infectionLevel = 0.995`, fire `EveryOneMinute`; assert `infectionLevel == 1.0` (cap check).
  2. MockPlayer with `UT_immunocompromised`, `infectionLevel = 0`, fire `EveryOneMinute`; assert `infectionLevel` remains 0 (zero-guard check).
  3. MockPlayer without `UT_immunocompromised`, `infectionLevel = 0.5`, fire `EveryOneMinute`; assert `infectionLevel` remains 0.5 (no-trait guard).

---

## Final Verdict

- Source origin: proven — `ToadTraits:immunocompromised` confirmed in `ToadTraits.txt` (42.13 and 42.15, lines 393–404). Cost = -10. The source implements three distinct effects: (1) per-wound infection level escalation via `setWoundInfectionLevel` (+0.001/tick legacy, +0.05/tick in 42.13 server-authoritative version) on already-infected, non-disinfected wounds; (2) a sandbox-configurable zombie-hit extra infection chance roll (`ImmunoChance`, default 25%, bypasses sandbox transmission toggle); (3) a Dynamic-submod arc that removes the trait after enough cumulative infection-hours. Source is multiplayer-enabled. Source excludes both `base:resilient` and `ToadTraits:superimmune`.

- UT implementation: simplified and partially drifted — UT retains the core concept (infection worsens faster) but changes the mechanism from per-wound `setWoundInfectionLevel` to body-level `setInfectionLevel`. The +0.01/minute rate is a new design choice; the source rate was +0.05 per server-authoritative call in 42.13 (cadence of that call's caller was not traced, but the unit is per-call not per-minute). The zombie-hit infection chance roll is not ported. The Dynamic submod removal arc is not ported. The trait is passive until infection is already present; the source also primarily worked on existing infections but additionally raised the hit-roll chance. The modData flag (`UT_immunocompromised = true`) is written by `onNewGame` and confirmed by the test, but nothing in the production codebase reads this flag — it is a marker only.

- Description: mostly acceptable but contains one misleading phrase — "Infections take hold more easily" implies higher initiation chance (a source feature not ported to UT); the actual UT effect is that an existing infection escalates faster (+0.01/min). "Your body struggles to fight back" is accurate flavor. No false claims about mechanics that do not exist; description is imprecise rather than wrong.

- Balance: plausibly calibrated but under-documented — at -6 vs. source -10 the cost reduction aligns with the scope reduction (no hit-roll, no per-wound mechanic, no Dynamic arc, multiplayer disabled). The effect is genuine and non-trivial: +0.01/min from any non-zero infection is meaningful. The pairing with `UT_immuneresponse` (no exclusion) produces a net positive escalation (immunocompromised dominates at +0.01 vs. immuneresponse's -0.003/min effective rate) — this combination is mechanically coherent but probably unintended and unguarded. The dropped `base:resilient` exclusion allows partial negation of the trait's downside.

- Regression proof: partially covered — the core path (modData flag + single-fire arithmetic) is tested and correct. Cap behavior (floor at 1.0), zero-guard, no-trait guard, and nil guard are untested.

- Action needed: minor — description wording fix + optional test additions + design gap review on exclusions

- Open gaps:
  - Description phrase "take hold more easily" implies a higher infection initiation chance that UT does not implement; rephrase to describe escalation of existing infection (e.g., "Infections that take hold escalate more quickly — your body has little ability to hold the line.").
  - The modData flag `UT_immunocompromised = true` is written by `OnNewGame` and tested, but no production code reads it. It is currently a pure marker with no consumer. If future UT systems query it (e.g., interaction with other traits or a wound-treatment modifier), document the intent; otherwise it is dead weight.
  - `base:resilient` mutual exclusion is present in source but absent from UT — a player can hold `UT_immunocompromised` and vanilla `base:resilient` simultaneously, partially negating the trait's downside. Decide whether to restore the exclusion.
  - `UT_immuneresponse` has no exclusion from `UT_immunocompromised`; at +0.01/min (immunocompromised) vs. -0.003/min effective (immuneresponse at -0.03/ten-minutes), immunocompromised dominates. The combination is mechanically valid but probably unintended — consider whether an exclusion or note is warranted.
  - Source's zombie-hit extra infection chance (`ImmunoChance`, default 25%, sandbox-configurable) is not ported. This was the trait's most distinctive gameplay feature in the source (bypass of sandbox transmission settings). UT omits it entirely.
  - UT operates on body-level `getInfectionLevel()` / `setInfectionLevel()`; source operated on per-wound `getWoundInfectionLevel()` / `setWoundInfectionLevel()`. These are different APIs with different semantics: per-wound infection is what causes the wound to fester and can be treated with disinfectant; body-level infectionLevel is a global accumulator. Verify that the body-level API is the correct target for the intended gameplay effect. The source explicitly guarded against disinfected wounds (`getAlcoholLevel() <= 0`) — UT has no such guard because it does not touch per-wound state.
  - `DisabledInMultiplayer = true` in UT vs. `DisabledInMultiplayer = false` in source. The UT runtime uses `getPlayer()` (single-player API), so the disable is mechanically necessary, but it is a narrowing of the source design.
  - `OnNewGame` only fires for new saves; players who acquire the trait dynamically on an existing save (if ever supported) will not have `UT_immunocompromised = true` in modData. Whether this matters depends on whether the flag has any future consumer.
  - Add behavioral tests for: cap at 1.0 (infectionLevel = 0.995 → 1.0), zero-guard (infectionLevel = 0 → no change), no-trait guard (player without trait → no change).
