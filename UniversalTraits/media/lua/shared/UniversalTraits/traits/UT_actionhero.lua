-- UT_actionhero.lua
-- Action Hero: bonus damage scaling with the number of spotted nearby enemies.
-- Fires on every weapon hit. Skipped for bare-hands unless player has UT_martial.
-- Skipped entirely if player has UT_mundane (mundane disables crits).

local TRAIT_ID = "UniversalTraits:UT_actionhero"

local function onWeaponHitCharacter(player, weapon, target)
    if not player then return end
    if not UTCore.hasTrait(player, TRAIT_ID) then return end

    -- Guard: only applies to zombies, not NPCs or other players
    if not instanceof(target, "IsoZombie") then return end

    -- Guard: bare-hands only works via UT_martial
    if weapon:getType() == "BareHands" then
        if not UTCore.hasTrait(player, "UniversalTraits:UT_martial") then return end
    end

    -- Guard: UT_mundane disables crits
    if UTCore.hasTrait(player, "UniversalTraits:UT_mundane") then return end

    local spottedList = player:getSpottedList()
    local critchance = 10
    local multiplier = 0.1

    for i = 0, spottedList:size() - 1 do
        local enemy = spottedList:get(i)
        local dist = player:DistTo(enemy)
        if dist <= 2 then
            critchance = critchance + 10
            multiplier = multiplier + 1.0
        elseif dist <= 5 then
            critchance = critchance + 5
            multiplier = multiplier + 0.4
        elseif dist <= 10 then
            critchance = critchance + 2
            multiplier = multiplier + 0.2
        end
    end

    if ZombRand(100) < critchance then
        local extraDamage = 5 * multiplier * 0.1
        target:setHealth(target:getHealth() - extraDamage)
    end
end

Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
