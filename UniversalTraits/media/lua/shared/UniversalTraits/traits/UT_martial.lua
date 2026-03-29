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
        stats:setEndurance(math.max(0, endurance - 0.001))
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

    -- Compute crit chance: (5 + (smallBluntLevel * 5)) * 0.01
    local critchance = (5 + (smallBluntLevel * 5)) * 0.01

    -- Roll for crit
    local martialDamage
    if ZombRand(100) < (critchance * 100) then
        -- Crit base damage: 6 * 0.1 = 0.6
        martialDamage = 6 * 0.1
    else
        -- Non-crit base damage: 2 * 0.1 = 0.2
        martialDamage = 2 * 0.1
    end

    -- Apply endurance scaling -- scales from 0.35x at 0 endurance to 1.35x at full endurance
    martialDamage = martialDamage * (endurance + 0.35)

    -- Apply damage
    target:setHealth(target:getHealth() - martialDamage)

    -- Grant XP
    local xpOk = pcall(function()
        if Perks and Perks.SmallBlunt then
            player:getXp():AddXP(Perks.SmallBlunt, martialDamage * 2)
        end
    end)
end

Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
