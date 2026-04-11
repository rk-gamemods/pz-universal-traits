-- UT_martial.lua
-- Martial Arts: bonus barehands damage based on SmallBlunt skill.
-- Fires on every weapon hit. Only active when weapon type is "BareHands".
-- Skipped if player has UT_mundane (mundane disables crits).
--
-- Public API (callable by other traits):
--   UT_martial.applyBonusDamage(player, target, endurance)
--     Rolls for crit, scales by endurance, applies health deduction and XP grant.
--     Returns damage dealt (0 if mundane) and isCrit boolean.
--     Plays hit feedback (blood splatter on crits, punch sound on all hits).
--     Includes mundane check — passes silently if UT_mundane is active.

UT_martial = UT_martial or {}

local TRAIT_ID = "UniversalTraits:UT_martial"

-- Shared damage calculation used by this trait and any synergy callers.
-- Does NOT drain endurance — callers manage that themselves.
--
-- Damage tuning (zombie HP is typically 1.6–3.0):
--   Normal hit: 0.5 + (level * 0.05)  → 0.5 at L0, 1.0 at L10  (2–6 hits to kill)
--   Crit hit:   3.0 + (level * 0.3)   → 3.0 at L0, 6.0 at L10  (1-hit KO)
--   Crit chance: 5% + (level * 8%)    → 5% at L0, 85% at L10
--   Endurance scaling: damage * (endurance + 0.35) — 0.35x at empty, 1.35x at full
function UT_martial.applyBonusDamage(player, target, endurance)
    -- Mundane suppresses crits and bonus damage
    if UTCore.hasTrait(player, "UniversalTraits:UT_mundane") then return 0 end

    local smallBluntLevel = 0
    local ok, level = pcall(function()
        if Perks and Perks.SmallBlunt then
            return player:getPerkLevel(Perks.SmallBlunt)
        end
        return 0
    end)
    if ok and type(level) == "number" then
        smallBluntLevel = level
    end

    local critChance = (5 + (smallBluntLevel * 8)) * 0.01

    local damage
    local isCrit = false
    if ZombRand(100) < (critChance * 100) then
        damage = 3.0 + (smallBluntLevel * 0.3)  -- crit: 1-hit KO range
        isCrit = true
    else
        damage = 0.5 + (smallBluntLevel * 0.05)  -- normal: 2-6 hits to kill
    end

    -- Scales from 0.35x at 0 endurance to 1.35x at full
    damage = damage * (endurance + 0.35)

    pcall(function() target:setHealth(target:getHealth() - damage) end)
    pcall(function()
        if Perks and Perks.SmallBlunt then
            player:getXp():AddXP(Perks.SmallBlunt, damage * 2)
        end
    end)

    -- Visual/audio feedback so the player knows damage is being dealt
    pcall(function()
        if isCrit then
            -- Blood splatter on crit: the circle splash effect
            target:splatBlood(1, 0.3)
        end
        -- Play a short blunt impact sound on every hit
        player:playSound("PunchImpact")
    end)

    return damage, isCrit
end

local function onWeaponHitCharacter(player, weapon, target)
    if not player then return end

    -- Guard: bare-hands only
    if weapon:getType() ~= "BareHands" then return end

    -- Guard: must have martial trait
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    local stats = player.getStats and player:getStats()
    local endurance = 1.0
    if stats then
        endurance = stats:get(CharacterStat.ENDURANCE)
    end

    -- Always drain endurance on bare-hand hit
    if stats then
        stats:set(CharacterStat.ENDURANCE, math.max(0, endurance - 0.001))
    end

    UT_martial.applyBonusDamage(player, target, endurance)
end

Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
