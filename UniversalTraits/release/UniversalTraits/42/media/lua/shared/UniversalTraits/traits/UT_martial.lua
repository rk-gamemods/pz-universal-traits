-- UT_martial.lua
-- Martial Arts: bonus barehands damage based on SmallBlunt skill.
-- Fires on every weapon hit. Only active when weapon type is "BareHands".
-- Skipped if player has UT_mundane (mundane disables crits).

local TRAIT_ID = "UniversalTraits:UT_martial"

local function onWeaponHitCharacter(player, weapon, target)
    if not player then return end

    -- Guard: bare-hands only
    if weapon:getType() ~= "BareHands" then return end

    -- Guard: must have martial trait
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    -- Get stats for endurance drain (always applies on bare-hand hit)
    local stats = player.getStats and player:getStats()
    local endurance = 1.0
    if stats and stats.getEndurance then
        endurance = stats:getEndurance()
    end

    -- Always drain endurance on bare-hand hit
    if stats and stats.setEndurance then
        stats:setEndurance(math.max(0, endurance - 0.002))
    end

    -- Guard: UT_mundane disables crits
    if UTCore.hasTrait(player, "UniversalTraits:UT_mundane") then return end

    -- Get SmallBlunt perk level
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

    -- Compute crit chance: (5 + smallBluntLevel) * 0.01
    local critchance = (5 + smallBluntLevel) * 0.01

    -- Roll for crit
    if ZombRand(100) < (critchance * 100) then
        -- Base damage: 4 * 0.1 = 0.4
        local martialDamage = 4 * 0.1

        -- Apply endurance scaling
        if endurance < 0.25 then
            martialDamage = martialDamage * 0.25
        elseif endurance < 0.50 then
            martialDamage = martialDamage * 0.5
        elseif endurance < 0.75 then
            martialDamage = martialDamage * 0.75
        -- else: multiply by 1.0 (no change)
        end

        -- Apply damage
        target:setHealth(target:getHealth() - martialDamage)

        -- Grant XP
        local xpOk = pcall(function()
            if Perks and Perks.SmallBlunt then
                player:getXp():AddXP(Perks.SmallBlunt, martialDamage * 2)
            end
        end)
    end
end

Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
