# Balance Review — 2026-03-28

Issues found by automated review. For each trait: current state, the problem, suggested cost fix, and ideas for non-skill-boost effects to make the trait more interesting.

Fill in your preferred direction in the **Decision** field, then apply with `update mod from planning file`.

---

## HOW TO USE THIS FILE

For each entry, fill in:

- **Decision:** `keep` / `change cost to X` / `change effect to: [description]` / `add effect: [description]`

Leave blank if you want to discuss first.

---

## CRITICAL — Strict duplicates / dominance reversals

---

### UT_bouncer_I

**Current:** Cost=4 · XP: ×2 in Axe, Long Blade, Long Blunt, Short Blade, Short Blunt, Spear
**Problem:** Identical XPBoosts to UT_actionhero (Cost=8). Same 6 melee skills, half the price.
**Note:** UT_bouncer_I and UT_bouncer_II are mutually exclusive with each other and represent a tier pair — I is the cheap entry tier.

**Effect ideas (non-XP):**

- Push/shove cooldown reduced — bouncers are trained in crowd control, shoving is faster
- Reduced panic when surrounded by multiple zombies (door control instinct)

**Decision:**

---

### UT_cruelty

**Current:** Cost=4 · XP: ×2 in Axe, Long Blade, Long Blunt, Short Blade, Short Blunt, Spear, Aiming, Reloading
**Problem:** Strict superset of UT_actionhero (Cost=8) — covers all 6 melee skills UT_actionhero has, plus Aiming and Reloading, at half the price.

**Effect ideas (non-XP):**

- Each kill has a chance to grant a brief (10s) minor berserk state — reduced pain, slightly increased attack speed
- Enemies you kill have increased chance of leaving usable weapons (fewer broken weapons on kill)

**Decision:**

---

### UT_prodigy

**Current:** Cost=6 · XP: ×2 in Cooking, Carpentry, Mechanics, First Aid, Fitness, Sprinting, Tailoring, Electrical, Aiming, Reloading (10 skills)
**Problem:** 10 skill-boosts for 6 points. At ~0.6 pts/boost it undercuts every specialist and multi-skill trait in the game. UT_terminator (Cost=14) covers 8 skills. UT_specmove (Cost=12) covers 4 skills.

**Effect ideas (non-XP):**

- Skills learned via books give an extra +1 level permanently (you absorb knowledge exceptionally well)
- Skill books are read 20% faster (broad curiosity, not just XP rate)

**Decision:**

---

### UT_axes (parent weapon trait)

**Current:** Cost=6 · XP: ×3 in Axe
**Problem:** The parent of the axe weapon tree costs MORE than its child UT_twohanded_axes (Cost=5, also ×3 Axe). Parent trait should be better value than its own child.

**Effect ideas (non-XP, to justify higher cost and differentiate from children):**

- Axes in your hands degrade 20% slower (you know how to use them efficiently)
- Trees felled with axes yield +1 log (efficient chopping technique)

**Decision:**

---

## HIGH — Exact duplicate pairs (same XPBoosts, different prices)

---

### UT_gymgoer vs UT_blissful

**Current:**

- UT_gymgoer: Cost=5 · XP: ×2 in Fitness
- UT_blissful: Cost=3 · XP: ×2 in Fitness
**Problem:** Identical effect, UT_gymgoer costs 2 more points.

**Effect ideas to differentiate UT_gymgoer (keep it at higher cost):**

- Start with +1 Fitness level (not just faster XP — actual starting stat)
- Slightly increased carry weight — gym training builds practical strength alongside cardio

**Decision:**

---

### UT_scrounger vs UT_scrapper

**Current:**

- UT_scrounger: Cost=5 · XP: ×2 in Scavenging
- UT_scrapper: Cost=3 · XP: ×2 in Scavenging
**Problem:** Identical effect, UT_scrounger costs 2 more points.

**Effect ideas to differentiate UT_scrounger:**

- Higher chance of finding rare/uncommon items in containers (not just XP, active luck effect)
- Loot containers that have already been looted have a second chance to yield 1 item

**Decision:**

---

### UT_antique

**Current:** Cost=6 · XP: ×2 in Scavenging
**Problem:** Three scavenging traits at Cost=3, 5, and 6 — all give the same ×2 Scavenging XP. UT_antique is the priciest of three identical effects.
**Note:** scrapper, scrounger, and antique are apparently not MET — a player could stack all three and get nothing extra.

**Effect ideas to differentiate UT_antique:**

- Antique/vintage firearms degrade 30% slower in your hands (you know how to maintain old things)
- Canned food with early expiry dates is still safe to eat for you (knowledge of real preservation vs printed dates)

**Decision:**

---

### UT_trekker vs UT_olympian

**Current:**

- UT_trekker: Cost=4 · XP: ×2 in Fitness and Sprinting
- UT_olympian: Cost=5 · XP: ×2 in Sprinting and Fitness
**Problem:** Identical XPBoosts. UT_trekker is 1 point cheaper.

**Effect ideas to differentiate UT_olympian (justify higher cost):**

- Start with +1 Fitness level
- Slightly extended stamina bar from athletic conditioning

**Decision:**

---

## WEAPON TREE — Child traits priced wrong relative to each other

---

### UT_onehanded_axes

**Current:** Cost=5 · XP: ×2 in Axe
**Problem:** UT_twohanded_axes (Cost=5) gives ×3 Axe. UT_onehanded_axes gives ×2 Axe for the same price. Lesser XP for identical cost.

**Effect ideas (to justify cost after fixing, or keep cheap and add flavor):**

- Hatchets and hand axes have slightly faster attack speed (one-handed agility)
- Hand axes can be thrown (if PZ supports thrown weapon mechanics — otherwise skip)

**Decision:**

---

### UT_long_blunts

**Current:** Cost=6 · XP: ×3 in Long Blunt
**Problem:** UT_twohanded_blunts (Cost=5) gives identical ×3 Long Blunt for 1 fewer point.

**Effect ideas to differentiate UT_long_blunts at higher cost:**

- Long blunt weapons have increased knockback distance on hit
- Slightly better chance of one-hit stagger on zombies with long blunt weapons

**Decision:**

---

### UT_long_blades

**Current:** Cost=6 · XP: ×3 in Long Blade
**Problem:** UT_twohanded_blades (Cost=5) gives identical ×3 Long Blade for 1 fewer point.

**Effect ideas to differentiate UT_long_blades at higher cost:**

- Long blade attacks have a small chance to hit multiple targets in arc (sweep technique)
- Machetes and long blades degrade slower in your hands

**Decision:**

---

### UT_onehanded_blunts

**Current:** Cost=5 · XP: ×3 in Short Blunt
**Problem:** UT_short_blunts (Cost=4) gives identical ×3 Short Blunt for 1 fewer point.

**Effect ideas to differentiate UT_onehanded_blunts at higher cost:**

- Short blunt attacks have faster swing recovery (you fight with precision, not brute force)
- Baseball bats and pipes can double as melee shields reducing incoming damage slightly

**Decision:**

---

### UT_onehanded_blades

**Current:** Cost=5 · XP: ×3 in Short Blade
**Problem:** UT_short_blades (Cost=4) gives identical ×3 Short Blade for 1 fewer point.

**Effect ideas to differentiate UT_onehanded_blades at higher cost:**

- Short blade weapons deal bonus damage when attacking from stealth
- Knives don't alert nearby zombies when used to kill (silent kill mechanic if PZ supports)

**Decision:**

---

## MEDIUM — Miscellaneous cost skews

---

### UT_noxpsneaky

**Current:** Cost=3 · Disables XP gain in Sneaking and Lightfoot (two skills)
**Problem:** Every other no-XP trait disables one skill. This disables two for the same price.

**Decision:**

---

### UT_noxpmaintenance

**Current:** Cost=3 · Disables Maintenance XP
**Problem:** Maintenance affects every melee weapon in the game — broader impact than most no-XP traits (Axe, First Aid, etc.).

**Decision:**

---

### UT_noxpaxe

**Current:** Cost=3 · Disables Axe XP
**Problem:** Axe is one weapon type — narrower than Maintenance (all melee weapons) or First Aid (healing). Should be cheaper.

**Decision:**

---

### UT_noxpfirstaid

**Current:** Cost=3 · Disables First Aid XP
**Problem:** Doctor/First Aid is one of the highest-value skills in survival (directly affects healing). Should be worth more than axe or maintenance.

**Decision:**

---

### UT_specaid

**Current:** Cost=12 · XP: ×9 in First Aid
**Problem:** Every other Specialist trait (Cost=12) covers 4–6 skills. UT_specaid gives extreme depth (×9) in a single skill. Same cost as specmove (4 skills) or speccrafting (5 skills).

**Effect ideas (to justify Cost=12 breadth disadvantage):**

- First Aid actions have a chance to not consume medical supplies (steady hands, minimal waste)
- Bandaging stops bleeding immediately instead of over time
- Applying medicine to others is 50% faster

**Decision:**

---

### UT_analgesia vs UT_staunch

**Current:**

- UT_analgesia: Cost=10 · Full pain immunity (pain flag permanently disabled)
- UT_staunch: Cost=10 · Reduced pain effects and injury penalties
**Problem:** Full immunity is strictly better than partial resistance for the same cost.

**Decision:**

---

### UT_sorelegs vs UT_noodlelegs

**Current:**

- UT_noodlelegs: Cost=-6 · -20% movement speed
- UT_sorelegs: Cost=-8 · -20% movement speed + reduced carry weight
**Problem:** UT_sorelegs has all of noodlelegs' penalty plus a carry penalty, but only refunds 2 more points.

**Decision:**

---

### UT_sprintdemon

**Current:** Cost=1 · XP: ×2 in Sprinting
**Problem:** UT_vagabond (Cost=3) gives identical ×2 Sprinting XP for 3× the price. UT_swift (Cost=2, ×2 Lightfoot) and UT_flexible (Cost=3, ×2 Nimble) establish that single movement XP traits run 2–3 points. Cost=1 is below the floor.

**Effect ideas to differentiate UT_sprintdemon at slightly higher cost:**

- Sprint stamina drains 10% slower (you are built for explosive bursts)
- Short sprints from a standing start are faster (acceleration bonus, not top speed)

**Decision:**

---

### UT_ingenuitive

**Current:** Cost=9 · XP: ×3 in Electrical + ×2 in Metalworking
**Problem:** Metalworking (MetalWelding) is a narrow/niche skill. Compare UT_tinkerer (Cost=5) which gives ×2 in Electrical + Mechanics + Tailoring + FlintKnapping (4 skills). UT_ingenuitive's 2-skill package at Cost=9 is expensive for what it offers.

**Effect ideas (to justify Cost=9 with better second component):**

- Electrical devices you repair have a chance to be repaired to full condition instead of partial (high-quality repair instinct)
- Generators you maintain use 10% less fuel

**Decision:**
