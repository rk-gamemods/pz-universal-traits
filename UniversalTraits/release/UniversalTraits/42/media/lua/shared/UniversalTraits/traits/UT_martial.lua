-- UT_martial.lua
-- Martial Arts: bonus barehands damage based on SmallBlunt skill.
-- Fires on every weapon hit. Only active when weapon type is "BareHands".
-- Skipped if player has UT_mundane (mundane disables crits).
--
-- Public API (callable by other traits):
--   UT_martial.applyBonusDamage(player, target, endurance)
--     Rolls for crit, scales by endurance, applies health deduction and XP grant.
--     Returns the damage dealt (0 if mundane suppressed it).
--     Includes mundane check — passes silently if UT_mundane is active.

UT_martial = UT_martial or {}

local TRAIT_ID = "UniversalTraits:UT_martial"

-- Shared damage calculation used by this trait and any synergy callers.
-- Does NOT drain endurance — callers manage that themselves.
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

    local critchance = (5 + (smallBluntLevel * 5)) * 0.01

    local damage
    if ZombRand(100) < (critchance * 100) then
        damage = 6 * 0.1  -- crit
    else
        damage = 2 * 0.1  -- normal
    end

    -- Scales from 0.35x at 0 endurance to 1.35x at full
    damage = damage * (endurance + 0.35)

    pcall(function() target:setHealth(target:getHealth() - damage) end)
    pcall(function()
        if Perks and Perks.SmallBlunt then
            player:getXp():AddXP(Perks.SmallBlunt, damage * 2)
        end
    end)

    return damage
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
